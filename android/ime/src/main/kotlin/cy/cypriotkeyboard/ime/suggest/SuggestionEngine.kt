package cy.cypriotkeyboard.ime.suggest

import cy.cypriotkeyboard.ime.input.greekify

/** Public suggestion model. Mirrors slot semantics of iOS provider. */
data class Suggestion(
    val text: String,
    val isVerbatim: Boolean,
    val willReplace: Boolean
)

/**
 * Mirrors `DawgAutocompleteSuggestionProvider.swift`. Pipeline:
 *   raw user input → greekify → casing detection → fold → DAWG suggest →
 *   recapitalize → list with verbatim slot 0 and willReplace slot 1.
 *
 * The Android engine ALWAYS Greekifies the input (matching the iOS DAWG path)
 * — even pure-Greek input passes through greekify, which is a no-op for
 * already-Greek characters.
 */
class SuggestionEngine(
    private val reader: DawgReader,
    private val folder: PhoneticFolder,
    suggester: DamerauSuggester? = null,
    private val limit: Int = 4
) {

    private val suggester: DamerauSuggester = suggester ?: DamerauSuggester(reader)

    private enum class Casing { LOWERCASE, FIRST_LETTER_CAP, ALL_CAPS }

    fun suggest(input: String): List<Suggestion> {
        if (input.isEmpty()) return emptyList()

        val greek = greekify(input)
        val (casing, lookup) = detectCasing(greek)
        val key = folder.fold(lookup)
        val candidates = suggester.suggest(key, limit = limit)

        val out = ArrayList<Suggestion>(1 + candidates.size)
        out += Suggestion(text = input, isVerbatim = true, willReplace = false)
        if (candidates.isNotEmpty()) {
            out += Suggestion(
                text = display(candidates[0].canonical, casing),
                isVerbatim = false,
                willReplace = true
            )
            for (i in 1 until candidates.size) {
                out += Suggestion(
                    text = display(candidates[i].canonical, casing),
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

    private fun display(canonical: String, casing: Casing): String = when (casing) {
        Casing.LOWERCASE -> canonical
        Casing.FIRST_LETTER_CAP -> if (canonical.isEmpty()) canonical
            else canonical.first().uppercaseChar() + canonical.substring(1)
        Casing.ALL_CAPS -> canonical.uppercase()
    }
}
