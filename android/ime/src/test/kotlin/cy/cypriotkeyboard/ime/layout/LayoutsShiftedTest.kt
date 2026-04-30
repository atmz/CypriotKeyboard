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

    @Test fun `shifted preserves widthUnits and popupChars`() {
        val base = Layouts.greekAlphabetic()
        val shifted = base.shifted()
        for ((row, shiftedRow) in base.rows.zip(shifted.rows)) {
            for ((k, sk) in row.zip(shiftedRow)) {
                assertEquals(k.widthUnits, sk.widthUnits, 0.0001f)
                assertEquals(k.popupChars, sk.popupChars)
            }
        }
    }
}
