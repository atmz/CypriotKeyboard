package cy.cypriotkeyboard.ime.input

import java.text.Normalizer

/**
 * Helpers used by the autocomplete pipeline to decide:
 *  - whether a token is even worth running through the suggester
 *    ([shouldAttemptAutocomplete]);
 *  - whether a candidate is close enough to the user's input that the
 *    spacebar should auto-replace it ([shouldReplace]).
 *
 * 1:1 ports of `CypriotKeyboardHelper` static functions in
 * `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`.
 */

/**
 * Skip tokens with no letters (digits, bare punctuation). Otherwise the
 * engine returns single-character Greek letters as edit-1 neighbors of the
 * empty fold key — bogus suggestions for "8", "30", ".", "8!".
 */
fun shouldAttemptAutocomplete(text: String): Boolean =
    text.any { it.isLetter() }

/**
 * Auto-replace gate for the willReplace flag on slot 1.
 *
 * Two cases:
 *  - Pure-Greek input (`text == greekText`): only true when the candidate
 *    differs from the input by diacritics only AND the input is at least
 *    two syllables (single-syllable Greek words conventionally don't carry
 *    accents, so a "fix" that adds one is presumptuous).
 *  - Greeklish input: only true when the Levenshtein distance between the
 *    diacritic-stripped lowercased candidate and the diacritic-stripped
 *    lowercased greekified input is < 3.
 */
fun shouldReplace(text: String, greekText: String, guess: String): Boolean {
    if (text == greekText) {
        // Pure-Greek branch.
        if (countSyllables(text) < 2) return false
        val accentlessWord = stripDiacritics(text)
        val accentlessGuess = stripDiacritics(guess)
        return if (guess != guess.lowercase()) {
            accentlessWord.lowercase() == accentlessGuess.lowercase() &&
                accentlessGuess != guess &&
                accentlessWord.lowercase() == text.lowercase()
        } else {
            accentlessWord == accentlessGuess &&
                accentlessGuess != guess &&
                accentlessWord == text
        }
    }
    // Greeklish branch. Normalise σ ↔ ς before measuring: greekify outputs
    // medial σ at word-end, but canonicals use final ς. Without this, every
    // short Greeklish word with a single other-character mismatch pays a
    // +1 distance tax that pushes legitimate corrections past the gate.
    val normalizedGreek = normalizeFinalSigma(stripDiacritics(greekText.lowercase()))
    val normalizedGuess = normalizeFinalSigma(stripDiacritics(guess.lowercase()))
    return levenshtein(normalizedGreek, normalizedGuess) < 3
}

/**
 * Multi-variant gate: returns true if [shouldReplace] would return true for
 * ANY of the passed [greekVariants]. Used when the caller has multiple
 * plausible greekify interpretations (digit/digraph branchings) and wants
 * the gate measured against the closest one rather than just the greedy
 * first reading.
 *
 * Mirrors `CypriotKeyboardHelper.shouldReplace(text:greekVariants:guess:)`
 * on iOS.
 */
fun shouldReplace(text: String, greekVariants: List<String>, guess: String): Boolean =
    greekVariants.any { shouldReplace(text = text, greekText = it, guess = guess) }

/** Collapse final ς onto medial σ so they're treated as equal during edit-distance. */
private fun normalizeFinalSigma(s: String): String = s.replace('ς', 'σ')

/**
 * Count syllables by walking the diacritic-stripped lowercase form and
 * counting vowel runs. A vowel cluster (e.g. "αι") counts as one syllable.
 *
 * Vowel inventory matches the iOS port: `αειυηοω` plus Latin `aeiouy` so
 * Greeklish input gets the same syllable count as its Greek transliteration.
 */
fun countSyllables(text: String): Int {
    var count = 0
    val vowels = "αειυηοωaeiouy"
    var last: Char? = null
    val folded = stripDiacritics(text.lowercase())
    for (letter in folded) {
        val lastWasVowel = last?.let { vowels.contains(it) } ?: false
        if (vowels.contains(letter) && !lastWasVowel) count += 1
        last = letter
    }
    return count
}

/**
 * Edit-distance between the lowercased + diacritic-stripped forms of two
 * strings. Used by the Greeklish branch of [shouldReplace].
 */
fun distanceMeasure(transliteratedWord: String, greekWord: String): Double {
    val a = stripDiacritics(greekWord.lowercase())
    val b = stripDiacritics(transliteratedWord.lowercase())
    return levenshtein(a, b).toDouble()
}

/**
 * Strip combining marks (U+0300–U+036F) after NFD decomposition. Equivalent
 * to iOS's `String.folding(options: .diacriticInsensitive, locale: el_GR)`
 * for the Greek alphabet.
 */
fun stripDiacritics(text: String): String =
    Normalizer.normalize(text, Normalizer.Form.NFD)
        .replace(COMBINING_MARKS_REGEX, "")

private val COMBINING_MARKS_REGEX = Regex("\\p{InCombiningDiacriticalMarks}+")

/**
 * Classic Levenshtein with a rolling two-row buffer (O(min(n,m)) extra
 * memory). 1:1 port of the Swift extension.
 */
fun levenshtein(a: String, b: String): Int {
    val ac = a.toCharArray()
    val bc = b.toCharArray()
    if (ac.isEmpty()) return bc.size
    if (bc.isEmpty()) return ac.size

    var prev = IntArray(bc.size + 1) { it }
    var curr = IntArray(bc.size + 1)

    for (i in 1..ac.size) {
        curr[0] = i
        val ai = ac[i - 1]
        for (j in 1..bc.size) {
            curr[j] = if (ai == bc[j - 1]) {
                prev[j - 1]
            } else {
                minOf(prev[j], curr[j - 1], prev[j - 1]) + 1
            }
        }
        val tmp = prev
        prev = curr
        curr = tmp
    }
    return prev[bc.size]
}
