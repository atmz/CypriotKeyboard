package cy.cypriotkeyboard.ime.suggest

data class DawgSuggestion(
    val canonical: String,
    val frequency: Long,
    val editDistance: Int
)

/**
 * Mirrors `DamerauLevenshteinSuggester.swift`. Enumerates all single-edit
 * variants of the input key, looks each one up in the DAWG, collects
 * canonicals, dedupes, ranks by (distance asc, frequency desc).
 */
class DamerauSuggester(private val reader: DawgReader) {

    private val alphabet: IntArray = collectAlphabet()

    fun suggest(key: String, limit: Int = 5): List<DawgSuggestion> {
        if (key.isEmpty()) return emptyList()

        data class Hit(val canonical: String, val freq: Long, val distance: Int)
        val hits = ArrayList<Hit>()
        val seen = HashSet<String>()

        // Distance 0: exact match.
        reader.payloadForKey(key)?.let { pidx ->
            for ((canonical, freq) in reader.canonicalForms(pidx)) {
                if (seen.add(canonical)) hits += Hit(canonical, freq, 0)
            }
        }

        // Distance 1: enumerate edited variants.
        for (variant in editDistance1Variants(key)) {
            val pidx = reader.payloadForKey(variant) ?: continue
            for ((canonical, freq) in reader.canonicalForms(pidx)) {
                if (seen.add(canonical)) hits += Hit(canonical, freq, 1)
            }
        }

        hits.sortWith(compareBy({ it.distance }, { -it.freq }))
        return hits.take(limit).map { DawgSuggestion(it.canonical, it.freq, it.distance) }
    }

    private fun editDistance1Variants(key: String): List<String> {
        val cps = key.codePoints().toArray()
        val n = cps.size
        val out = ArrayList<String>()

        // Deletions
        for (i in 0 until n) {
            val copy = IntArray(n - 1)
            System.arraycopy(cps, 0, copy, 0, i)
            System.arraycopy(cps, i + 1, copy, i, n - i - 1)
            out += String(copy, 0, copy.size)
        }
        // Substitutions
        for (i in 0 until n) {
            for (cp in alphabet) {
                if (cp == cps[i]) continue
                val copy = cps.copyOf()
                copy[i] = cp
                out += String(copy, 0, copy.size)
            }
        }
        // Insertions (n+1 positions)
        for (i in 0..n) {
            for (cp in alphabet) {
                val copy = IntArray(n + 1)
                System.arraycopy(cps, 0, copy, 0, i)
                copy[i] = cp
                System.arraycopy(cps, i, copy, i + 1, n - i)
                out += String(copy, 0, copy.size)
            }
        }
        // Adjacent transpositions
        if (n >= 2) {
            for (i in 0 until n - 1) {
                if (cps[i] == cps[i + 1]) continue
                val copy = cps.copyOf()
                val tmp = copy[i]
                copy[i] = copy[i + 1]
                copy[i + 1] = tmp
                out += String(copy, 0, copy.size)
            }
        }
        return out
    }

    private fun collectAlphabet(): IntArray {
        val seen = HashSet<Int>()
        val visited = HashSet<Int>()
        val stack = ArrayDeque<Int>()
        stack.addLast(reader.rootNodeIdx)
        while (stack.isNotEmpty()) {
            val nodeIdx = stack.removeLast()
            if (!visited.add(nodeIdx)) continue
            for ((cp, target) in reader.edges(nodeIdx)) {
                seen += cp
                stack.addLast(target)
            }
        }
        return seen.sorted().toIntArray()
    }
}
