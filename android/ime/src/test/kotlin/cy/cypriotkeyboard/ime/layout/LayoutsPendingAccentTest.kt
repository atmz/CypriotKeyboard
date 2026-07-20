package cy.cypriotkeyboard.ime.layout

import cy.cypriotkeyboard.ime.input.PrefixAccent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LayoutsPendingAccentTest {

    private fun LayoutSpec.charKeys(): List<KeySpec> =
        rows.flatten().filter { it.action is KeyAction.Character }

    private fun LayoutSpec.keyFor(base: String): KeySpec =
        charKeys().first { (it.action as KeyAction.Character).text == base }

    @Test fun `armed tonos relabels vowel keycaps but keeps base actions`() {
        val layout = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.TONOS)
        val expected = mapOf(
            "α" to "ά", "ε" to "έ", "η" to "ή", "ι" to "ί",
            "ο" to "ό", "υ" to "ύ", "ω" to "ώ"
        )
        for ((base, accented) in expected) {
            val key = layout.keyFor(base)
            assertEquals(accented, key.label)
            assertEquals(base, (key.action as KeyAction.Character).text)
        }
    }

    @Test fun `armed tonos leaves consonant keycaps unchanged`() {
        val layout = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.TONOS)
        for (c in listOf("ρ", "τ", "θ", "π", "σ", "δ", "κ", "λ", "ζ", "ν", "μ")) {
            assertEquals(c, layout.keyFor(c).label)
        }
    }

    @Test fun `armed tonos highlights the tonos key`() {
        val armed = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.TONOS)
        val idle = Layouts.greekAlphabetic()
        val armedTonos = armed.rows[0].first { it.label == "΄" || it.highlighted }
        assertTrue(armedTonos.highlighted)
        assertFalse(idle.rows[0].first { it.label == "΄" }.highlighted)
    }

    @Test fun `armed dialytika relabels only iota and upsilon`() {
        val layout = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.DIALYTIKA)
        assertEquals("ϊ", layout.keyFor("ι").label)
        assertEquals("ϋ", layout.keyFor("υ").label)
        assertEquals("α", layout.keyFor("α").label)
        assertEquals("ε", layout.keyFor("ε").label)
    }

    @Test fun `armed tonos-dialytika relabels only iota and upsilon`() {
        val layout = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.TONOS_DIALYTIKA)
        assertEquals("ΐ", layout.keyFor("ι").label)
        assertEquals("ΰ", layout.keyFor("υ").label)
        assertEquals("α", layout.keyFor("α").label)
    }

    @Test fun `no pending accent leaves all keycaps as their base characters`() {
        val layout = Layouts.greekAlphabetic()
        for (key in layout.charKeys()) {
            assertEquals((key.action as KeyAction.Character).text, key.label)
            assertFalse(key.highlighted)
        }
    }

    @Test fun `shifted armed layout shows uppercase accented keycaps`() {
        val layout = Layouts.greekAlphabetic(pendingAccent = PrefixAccent.TONOS).shifted()
        val alpha = layout.charKeys().first { (it.action as KeyAction.Character).text == "Α" }
        assertEquals("Ά", alpha.label)
    }
}
