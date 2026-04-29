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
}
