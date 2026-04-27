package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class FinalSigmaRuleTest {

    @Test fun `lone sigma at end-of-word becomes final sigma`() {
        val r = applyFinalSigma("καλοσ", postCursorEmpty = true)
        assertEquals(SigmaResult.ReplaceTrailing("σ", "ς"), r)
    }

    @Test fun `lone sigma-breve at end-of-word becomes final sigma-breve`() {
        val r = applyFinalSigma("κασ̆", postCursorEmpty = true)
        assertEquals(SigmaResult.ReplaceTrailing("σ̆", "ς̆"), r)
    }

    @Test fun `final sigma followed by another letter becomes medial sigma`() {
        // The user typed "ς" thinking they were ending the word, then kept typing.
        // Per iOS rule: the next-to-last char is "ς", last char is a letter →
        // demote the "ς" back to "σ".
        val r = applyFinalSigma("καλςα", postCursorEmpty = true)
        // ς is at index 3, then α at index 4. Replace ς with σ.
        assertEquals(SigmaResult.PromoteMedial("ς", "σ"), r)
    }

    @Test fun `no rule fires on non-sigma terminal`() {
        assertEquals(SigmaResult.None, applyFinalSigma("καλο", postCursorEmpty = true))
    }

    @Test fun `mid-cursor (postCursorEmpty=false) does not run end-of-word promotion`() {
        // Last letter is σ, but cursor is mid-word → no end-of-word promotion.
        // The medial-promotion rule still fires if applicable; here it isn't.
        assertEquals(SigmaResult.None, applyFinalSigma("καλοσ", postCursorEmpty = false))
    }
}
