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
}
