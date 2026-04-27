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
