package cy.cypriotkeyboard.ime.suggest

import org.json.JSONObject

/**
 * Mirrors `PhoneticFolder.swift`. Loads a longest-match-first ruleset and
 * applies it greedily across the input. The Android port does NOT use
 * Gson/Moshi — `org.json` is in the platform and zero-dependency.
 */
class PhoneticFolder private constructor(
    private val rules: List<Pair<String, String>>
) {

    /** Identical algorithm to the Python reference and the Swift port. */
    fun fold(text: String): String {
        if (text.isEmpty()) return text
        val sb = StringBuilder(text.length)
        var i = 0
        val n = text.length
        while (i < n) {
            var matched = false
            for ((src, dst) in rules) {
                if (i + src.length <= n && text.regionMatches(i, src, 0, src.length)) {
                    sb.append(dst)
                    i += src.length
                    matched = true
                    break
                }
            }
            if (!matched) {
                sb.append(text[i])
                i += 1
            }
        }
        return sb.toString()
    }

    /**
     * Return all fold variants by branching at digraph-matching positions.
     *
     * At each position, if a multi-char rule matches we explore TWO branches:
     *   (a) take the multi-char rule (collapses to one fold char)
     *   (b) take the single-char rule for `text[i]` and recurse from `i+1`
     *       (so the "digraph" gets folded as two separate single-char steps)
     *
     * The first returned variant equals the greedy longest-match fold
     * (i.e., what [fold] returns). Subsequent variants explore alternatives.
     *
     * Single-char-only positions don't branch — only digraph rules introduce
     * ambiguity worth exploring.
     *
     * Capped at [maxVariants] to prevent pathological blowup. Typical Greek
     * words have 0–2 digraphs, so 1–4 variants is normal.
     *
     * Mirrors `PhoneticFolder.fold_variants` in the Python reference
     * (`dict_generation/phonetic_fold.py`).
     */
    fun foldVariants(text: String, maxVariants: Int = 16): List<String> {
        if (text.isEmpty()) return listOf("")
        val n = text.length
        val seen = LinkedHashSet<String>()  // preserves insertion order

        fun helper(i: Int, acc: StringBuilder) {
            if (seen.size >= maxVariants) return
            if (i >= n) {
                seen.add(acc.toString())
                return
            }
            // Find longest-match multi-char rule at position i (if any).
            var digraphSrc: String? = null
            var digraphDst: String? = null
            for ((src, dst) in rules) {
                if (src.length >= 2 && i + src.length <= n &&
                    text.regionMatches(i, src, 0, src.length)
                ) {
                    digraphSrc = src
                    digraphDst = dst
                    break
                }
            }
            // Find single-char rule for text[i] (if any).
            var singleDst: String? = null
            for ((src, dst) in rules) {
                if (src.length == 1 && text[i] == src[0]) {
                    singleDst = dst
                    break
                }
            }

            if (digraphSrc != null) {
                val savedLen = acc.length
                acc.append(digraphDst)
                helper(i + digraphSrc.length, acc)
                acc.setLength(savedLen)
            }
            if (singleDst != null) {
                val savedLen = acc.length
                acc.append(singleDst)
                helper(i + 1, acc)
                acc.setLength(savedLen)
            } else if (digraphSrc == null) {
                // No rule fires — pass char through.
                val savedLen = acc.length
                acc.append(text[i])
                helper(i + 1, acc)
                acc.setLength(savedLen)
            }
        }

        helper(0, StringBuilder(n))
        return seen.toList()
    }

    companion object {

        fun fromJson(json: String): PhoneticFolder {
            val root = JSONObject(json)
            val rulesArr = root.getJSONArray("rules")
            val pairs = mutableListOf<Pair<String, String>>()
            for (idx in 0 until rulesArr.length()) {
                val r = rulesArr.getJSONObject(idx)
                pairs += r.getString("from") to r.getString("to")
            }
            // Stable sort longest-first (matches Swift sort behavior).
            pairs.sortByDescending { it.first.length }
            return PhoneticFolder(pairs)
        }
    }
}
