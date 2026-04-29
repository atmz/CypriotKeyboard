package cy.cypriotkeyboard.ime.suggest

import cy.cypriotkeyboard.ime.input.CommonWords
import cy.cypriotkeyboard.ime.input.greekify
import cy.cypriotkeyboard.ime.input.shouldAttemptAutocomplete
import cy.cypriotkeyboard.ime.input.shouldReplace

/** Public suggestion model. Mirrors slot semantics of iOS provider. */
data class Suggestion(
    val text: String,
    val isVerbatim: Boolean,
    val willReplace: Boolean
)

/**
 * Mirrors `DawgAutocompleteSuggestionProvider.swift`. Pipeline:
 *   raw user input → guard non-letter tokens → strip leading punct →
 *   greekify → common-word fast path → casing detection → fold → DAWG
 *   suggest → recapitalize + re-prepend punct → list with verbatim slot 0
 *   and willReplace-gated slot 1.
 */
class SuggestionEngine(
    private val reader: DawgReader,
    private val folder: PhoneticFolder,
    suggester: DamerauSuggester? = null
) {

    private val suggester: DamerauSuggester = suggester ?: DamerauSuggester(reader)

    /**
     * Length-aware candidate cap so the suggestion bar stays readable. Long
     * input → less width per slot → fewer alternatives shown. Total bar
     * slots = 1 verbatim + N candidates, so:
     *   - input.length > 5 → 2 candidates → 3 slots
     *   - input.length ≤ 5 → 3 candidates → 4 slots
     * Mirrors the Hunspell provider's identical sizing.
     */
    private fun candidateLimitFor(input: String): Int =
        if (input.length > 5) 2 else 3

    private enum class Casing { LOWERCASE, FIRST_LETTER_CAP, ALL_CAPS }

    fun suggest(input: String): List<Suggestion> {
        if (input.isEmpty()) return emptyList()

        // 1. Skip purely-numeric / punctuation tokens. Otherwise typing "8"
        //    greekifies to "" and the suggester returns single-character
        //    Greek letters (η, ο, …) as edit-1 neighbors of the empty fold
        //    key. Mirrors the Hunspell provider's identical guard.
        if (!shouldAttemptAutocomplete(input)) return emptyList()

        // 2. Strip a leading non-letter (".", "(", etc.) before greekify so
        //    e.g. ".kalimera" looks up "kalimera" and the punct gets re-
        //    prepended on the way out. Matches the Hunspell isPunctFirst
        //    handling.
        val isPunctFirst = !(input.firstOrNull()?.isLetter() ?: true)
        val textForGreekify = if (isPunctFirst) input.drop(1) else input
        val greek = greekify(textForGreekify)

        // 3. Common-word fast path: if the input is pure-Greek (greekify is
        //    a no-op) and a known common word, return verbatim only — no
        //    autocorrect alternatives. Matches the Hunspell provider's
        //    identical short-circuit so users aren't pestered with
        //    candidates for words they typed correctly.
        if (!isPunctFirst && input == greek && CommonWords.isCommon(input)) {
            return listOf(Suggestion(text = input, isVerbatim = true, willReplace = false))
        }

        val (casing, lookup) = detectCasing(greek)
        // Multi-fold lookup: digraphs like ει/οι/αι can be intentional or
        // accidental; folding both branches and merging by canonical avoids
        // ranking a rare exact-match (νήμα for "noima") above the user's
        // likely intent (νόημα).
        val keys = folder.foldVariants(lookup)
        val candidates = suggester.suggestMulti(keys, limit = candidateLimitFor(input))

        val out = ArrayList<Suggestion>(1 + candidates.size)
        out += Suggestion(text = input, isVerbatim = true, willReplace = false)
        if (candidates.isNotEmpty()) {
            val displayed = display(candidates[0].canonical, casing, isPunctFirst, input)
            // 4. Gate willReplace through shouldReplace so spacebar only
            //    replaces the typed word when the candidate is a close
            //    diacritics-only or low-Levenshtein match. Without this,
            //    every edit-1 candidate would force-replace user input.
            val willReplace = shouldReplace(text = input, greekText = greek, guess = displayed)
            out += Suggestion(
                text = displayed,
                isVerbatim = false,
                willReplace = willReplace
            )
            for (i in 1 until candidates.size) {
                out += Suggestion(
                    text = display(candidates[i].canonical, casing, isPunctFirst, input),
                    isVerbatim = false,
                    willReplace = false
                )
            }
        }
        return out
    }

    private fun detectCasing(greek: String): Pair<Casing, String> {
        if (greek.isEmpty()) return Casing.LOWERCASE to greek
        val upper = greek.uppercase()
        val lower = greek.lowercase()
        if (greek == upper && greek != lower) {
            return Casing.ALL_CAPS to lower
        }
        if (greek.first().isUpperCase()) {
            val rest = greek.substring(1)
            return Casing.FIRST_LETTER_CAP to (greek.first().lowercaseChar() + rest)
        }
        return Casing.LOWERCASE to greek
    }

    private fun display(
        canonical: String,
        casing: Casing,
        isPunctFirst: Boolean,
        originalInput: String
    ): String {
        val cased = when (casing) {
            Casing.LOWERCASE -> canonical
            Casing.FIRST_LETTER_CAP -> if (canonical.isEmpty()) canonical
                else canonical.first().uppercaseChar() + canonical.substring(1)
            Casing.ALL_CAPS -> canonical.uppercase()
        }
        // Re-prepend the leading punct stripped for lookup so the suggestion
        // appears with the same surface form the user typed.
        return if (isPunctFirst && originalInput.isNotEmpty())
            originalInput.first() + cased else cased
    }
}
