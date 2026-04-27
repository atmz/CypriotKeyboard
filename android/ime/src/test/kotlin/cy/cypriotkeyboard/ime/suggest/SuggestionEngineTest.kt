package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SuggestionEngineTest {

    private fun engine(): SuggestionEngine {
        val dawg = File("src/main/assets/el_CY.dawg")
        val fold = File("src/main/assets/phonetic_fold.json")
        val reader = DawgReader.from(ByteBuffer.wrap(dawg.readBytes()).order(ByteOrder.LITTLE_ENDIAN))
        val folder = PhoneticFolder.fromJson(fold.readText())
        return SuggestionEngine(reader, folder)
    }

    @Test fun `empty input returns empty list`() {
        assertEquals(emptyList<Suggestion>(), engine().suggest(""))
    }

    @Test fun `slot 0 is always verbatim user input`() {
        val res = engine().suggest("καλημερα")
        assertTrue(res.isNotEmpty())
        assertEquals("καλημερα", res[0].text)
        assertTrue(res[0].isVerbatim)
        assertEquals(false, res[0].willReplace)
    }

    @Test fun `slot 1 (when present) is willReplace top candidate`() {
        val res = engine().suggest("καλημερα")
        if (res.size >= 2) {
            assertEquals(true, res[1].willReplace)
            assertEquals(false, res[1].isVerbatim)
        }
    }

    @Test fun `firstLetterCap input yields capitalized suggestions`() {
        val res = engine().suggest("Καλημερα")
        if (res.size >= 2) {
            assertTrue("expected uppercase first letter, got ${res[1].text}",
                res[1].text.isNotEmpty() && res[1].text.first().isUpperCase())
        }
    }

    @Test fun `allCaps input yields uppercase suggestions`() {
        val res = engine().suggest("ΚΑΛΗΜΕΡΑ")
        if (res.size >= 2) {
            assertEquals(res[1].text, res[1].text.uppercase())
        }
    }
}
