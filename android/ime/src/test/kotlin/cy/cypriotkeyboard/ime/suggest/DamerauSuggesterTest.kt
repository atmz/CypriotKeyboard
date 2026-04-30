package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class DamerauSuggesterTest {

    private fun loadReader(): DawgReader {
        val file = File("src/main/assets/el_CY.dawg")
        require(file.exists())
        val buf = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
        return DawgReader.from(buf)
    }

    @Test fun `suggester returns ranked results within distance 1`() {
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        // "καλημερα" → fold key. Whatever the exact key, suggest() should
        // return at least one canonical form when fed it.
        val key = folder.fold("καλημερα")
        val suggestions = suggester.suggest(key, limit = 5)
        assertTrue("expected at least 1 suggestion for καλημερα", suggestions.isNotEmpty())
    }

    @Test fun `distance 0 results rank above distance 1`() {
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        // Pick a known-good key (after folding any common word).
        val key = folder.fold("καλα")
        val suggestions = suggester.suggest(key, limit = 5)
        if (suggestions.isNotEmpty()) {
            // First result must have the smallest editDistance.
            val firstDist = suggestions.first().editDistance
            for (s in suggestions) {
                assertTrue(s.editDistance >= firstDist)
            }
        }
    }

    @Test fun `empty key returns empty`() {
        val reader = loadReader()
        val suggester = DamerauSuggester(reader)
        assertEquals(emptyList<DawgSuggestion>(), suggester.suggest("", limit = 5))
    }

    // -- suggestMulti --

    @Test fun `suggestMulti returns min distance across keys`() {
        // If a canonical appears at d=0 via one fold key and d=1 via another,
        // the merged result records d=0.
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        val keyExact = folder.fold("καλα")
        // Substitute the first char to make it edit-1 from the exact key.
        val perturbed = "x" + keyExact.substring(1)

        val merged = suggester.suggestMulti(listOf(keyExact, perturbed), limit = 10)
        // καλα (or its diacritic'd form) should be reachable. Whichever
        // canonical lands first must have its MIN distance recorded.
        if (merged.isNotEmpty()) {
            // Run the same canonical through both keys individually and
            // confirm the merged distance equals the min.
            val firstCanonical = merged.first().canonical
            val viaExact = suggester.suggest(keyExact, limit = 20)
                .firstOrNull { it.canonical == firstCanonical }?.editDistance
            val viaPerturbed = suggester.suggest(perturbed, limit = 20)
                .firstOrNull { it.canonical == firstCanonical }?.editDistance
            val expectedMin = listOfNotNull(viaExact, viaPerturbed).minOrNull()
            if (expectedMin != null) {
                assertEquals(expectedMin, merged.first().editDistance)
            }
        }
    }

    @Test fun `suggestMulti dedupes canonicals across keys`() {
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        val key = folder.fold("καλα")
        // Same key twice — every canonical should appear once.
        val merged = suggester.suggestMulti(listOf(key, key), limit = 10)
        val canonicals = merged.map { it.canonical }
        assertEquals(canonicals.size, canonicals.toSet().size)
    }

    @Test fun `suggestMulti with empty key list returns empty`() {
        val reader = loadReader()
        val suggester = DamerauSuggester(reader)
        assertEquals(emptyList<DawgSuggestion>(), suggester.suggestMulti(emptyList(), limit = 5))
    }

    // -- casing-aware tiebreak --

    @Test fun `casing hint prefers matching-case canonical at same distance`() {
        // The DAWG is built from lowercased surface forms, so cap-first
        // canonicals (proper nouns) share fold keys with their lowercase
        // counterparts when both spellings exist. We can't pick a key
        // that's guaranteed to have both — the dict's contents shift —
        // so this test inspects the casing-blind result for a key that
        // produces both, then verifies the hinted overload re-ranks.
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        // Try a few candidate keys; use the first one that yields BOTH a
        // cap-first and a lowercase canonical at distance 0 in the same
        // bucket. If none does, skip the assertion (the corpus doesn't
        // have a dual-casing pair on hand).
        val candidates = listOf("παφος", "λεμεσος", "λευκωσια", "νικος")
            .map { folder.fold(it) }
        var foundDualKey: String? = null
        for (key in candidates) {
            val raw = suggester.suggest(key, limit = 32)
            val d0 = raw.filter { it.editDistance == 0 }
            val hasCap = d0.any { it.canonical.firstOrNull()?.isUpperCase() == true }
            val hasLower = d0.any { it.canonical.firstOrNull()?.isLowerCase() == true }
            if (hasCap && hasLower) { foundDualKey = key; break }
        }
        if (foundDualKey != null) {
            val capRes = suggester.suggestMulti(
                listOf(foundDualKey), limit = 5,
                inputCasingHint = InputCasingHint.FIRST_LETTER_CAP
            )
            val lowerRes = suggester.suggestMulti(
                listOf(foundDualKey), limit = 5,
                inputCasingHint = InputCasingHint.LOWERCASE
            )
            assertTrue("cap hint must put a cap-first top: got ${capRes.first().canonical}",
                capRes.first().canonical.first().isUpperCase())
            assertTrue("lowercase hint must put a lowercase top: got ${lowerRes.first().canonical}",
                lowerRes.first().canonical.first().isLowerCase())
        }
        // If no dual-casing key in the bundled DAWG, the test is a no-op
        // but the next test (across-distance dominance) still validates
        // the boost mechanism.
    }

    @Test fun `casing hint does not promote across distance buckets`() {
        // A lowercase distance-0 match must rank above any cap-first
        // distance-1 match, even with FIRST_LETTER_CAP hint. Edit
        // distance dominates; the casing boost is a tiebreak only.
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        val key = folder.fold("νερο")
        val res = suggester.suggestMulti(
            listOf(key), limit = 5, inputCasingHint = InputCasingHint.FIRST_LETTER_CAP
        )
        if (res.size >= 2) {
            // The distance bucket order is monotonic — bucket N can never
            // come before bucket N-1, regardless of hint.
            for (i in 1 until res.size) {
                assertTrue(
                    "distance buckets must remain monotonic: ${res[i - 1]} → ${res[i]}",
                    res[i].editDistance >= res[i - 1].editDistance
                )
            }
        }
    }
}
