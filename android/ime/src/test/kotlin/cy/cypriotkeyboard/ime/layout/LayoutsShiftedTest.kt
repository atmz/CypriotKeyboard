package cy.cypriotkeyboard.ime.layout

import org.junit.Assert.assertEquals
import org.junit.Test

class LayoutsShiftedTest {

    @Test fun `shifted uppercases all Character keys`() {
        val base = Layouts.greekAlphabetic()
        val shifted = base.shifted()
        for ((row, shiftedRow) in base.rows.zip(shifted.rows)) {
            for ((k, sk) in row.zip(shiftedRow)) {
                val a = k.action
                if (a is KeyAction.Character) {
                    val expected = a.text.uppercase()
                    val actual = (sk.action as KeyAction.Character).text
                    assertEquals(expected, actual)
                    assertEquals(expected, sk.label)
                }
            }
        }
    }

    @Test fun `shifted leaves non-Character keys unchanged`() {
        val base = Layouts.greekAlphabetic()
        val shifted = base.shifted()
        for ((row, shiftedRow) in base.rows.zip(shifted.rows)) {
            for ((k, sk) in row.zip(shiftedRow)) {
                if (k.action !is KeyAction.Character) {
                    assertEquals(k, sk)
                }
            }
        }
    }

    @Test fun `shifted preserves widthUnits, popupChars, and enabled`() {
        val base = Layouts.greekAlphabetic(breveEnabled = false)
        val shifted = base.shifted()
        for ((row, shiftedRow) in base.rows.zip(shifted.rows)) {
            for ((k, sk) in row.zip(shiftedRow)) {
                assertEquals(k.widthUnits, sk.widthUnits, 0.0001f)
                assertEquals(k.popupChars, sk.popupChars)
                assertEquals(k.enabled, sk.enabled)
            }
        }
    }

    @Test fun `breve key is disabled when context says so`() {
        val noBreve = Layouts.greekAlphabetic(breveEnabled = false)
        val withBreve = Layouts.greekAlphabetic(breveEnabled = true)
        // The last key in row 1 is the breve key.
        val noBreveKey = noBreve.rows[0].last()
        val withBreveKey = withBreve.rows[0].last()
        assertEquals("˘", noBreveKey.label)
        assertEquals("˘", withBreveKey.label)
        assertEquals(false, noBreveKey.enabled)
        assertEquals(true, withBreveKey.enabled)
    }
}
