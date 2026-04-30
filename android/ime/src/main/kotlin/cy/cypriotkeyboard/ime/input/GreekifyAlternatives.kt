package cy.cypriotkeyboard.ime.input

/**
 * Generate alternative Greek interpretations for ambiguous Greeklish
 * transliterations. Returns at least the input itself; capped at
 * [maxVariants] to keep combinatorial explosion in check when many
 * branchable positions appear in one word.
 *
 * 1:1 port of `DawgAutocompleteSuggestionProvider.greekifyAlternatives`
 * in the iOS Swift source.
 */
fun greekifyAlternatives(greek: String, maxVariants: Int = 8): List<String> {
    val chars = greek.toCharArray()
    val out = ArrayList<String>()
    val seen = HashSet<String>()

    fun helper(i: Int, acc: String) {
        if (out.size >= maxVariants) return
        if (i >= chars.size) {
            if (seen.add(acc)) out.add(acc)
            return
        }
        for ((src, alts) in ALT_RULES) {
            if (i + src.length > chars.size) continue
            var match = true
            for (k in src.indices) {
                if (chars[i + k] != src[k]) { match = false; break }
            }
            if (match) {
                for (alt in alts) helper(i + src.length, acc + alt)
                return
            }
        }
        helper(i + 1, acc + chars[i])
    }
    helper(0, "")
    return out
}

/**
 * Rules for branching ambiguous Greeklish transliterations into multiple
 * Greek interpretations. Listed longest-first so digraphs win over
 * single-char rules.
 *
 * - αφ/εφ/αβ/εβ ⇄ αυ/ευ: Greek's αυ/ευ diphthong sounds like "af/ef"
 *   before voiceless consonants and "av/ev" before voiced — but greekify
 *   maps the consonant char-by-char (φ/β), so we branch back to the
 *   diphthong here. Without this, "Lefkosia" → Λεφκοσια only reaches
 *   Λευκωσία at edit-2, outside the suggester's edit-1 budget.
 * - θ ⇄ τη: Greeklish "th" maps greedily to θ but might mean τη
 *   (e.g. "afth" → αυτή).
 * - 8 ⇄ θ: Greeklish convention treats the digit 8 as θ (visual
 *   resemblance), e.g. "8a" → θα, "8elw" → θέλω. Bare-numeric tokens
 *   ("8") get filtered upstream by shouldAttemptAutocomplete; this rule
 *   only fires when the token mixes digits and letters.
 */
private val ALT_RULES: List<Pair<String, List<String>>> = listOf(
    "αφ" to listOf("αφ", "αυ"),
    "Αφ" to listOf("Αφ", "Αυ"),
    "εφ" to listOf("εφ", "ευ"),
    "Εφ" to listOf("Εφ", "Ευ"),
    "αβ" to listOf("αβ", "αυ"),
    "Αβ" to listOf("Αβ", "Αυ"),
    "εβ" to listOf("εβ", "ευ"),
    "Εβ" to listOf("Εβ", "Ευ"),
    "θ" to listOf("θ", "τη"),
    "Θ" to listOf("Θ", "Τη"),
    "8" to listOf("8", "θ"),
)
