package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AccentPrecomposeTest {

    @Test fun `tonos on lowercase vowels`() {
        assertEquals("ά", precomposeAccent(PrefixAccent.TONOS, "α"))
        assertEquals("έ", precomposeAccent(PrefixAccent.TONOS, "ε"))
        assertEquals("ή", precomposeAccent(PrefixAccent.TONOS, "η"))
        assertEquals("ί", precomposeAccent(PrefixAccent.TONOS, "ι"))
        assertEquals("ό", precomposeAccent(PrefixAccent.TONOS, "ο"))
        assertEquals("ύ", precomposeAccent(PrefixAccent.TONOS, "υ"))
        assertEquals("ώ", precomposeAccent(PrefixAccent.TONOS, "ω"))
    }

    @Test fun `tonos on uppercase vowels`() {
        assertEquals("Ά", precomposeAccent(PrefixAccent.TONOS, "Α"))
        assertEquals("Έ", precomposeAccent(PrefixAccent.TONOS, "Ε"))
        assertEquals("Ή", precomposeAccent(PrefixAccent.TONOS, "Η"))
        assertEquals("Ί", precomposeAccent(PrefixAccent.TONOS, "Ι"))
        assertEquals("Ό", precomposeAccent(PrefixAccent.TONOS, "Ο"))
        assertEquals("Ύ", precomposeAccent(PrefixAccent.TONOS, "Υ"))
        assertEquals("Ώ", precomposeAccent(PrefixAccent.TONOS, "Ω"))
    }

    @Test fun `tonos on already-dialytika vowel returns combined form`() {
        assertEquals("ΐ", precomposeAccent(PrefixAccent.TONOS, "ϊ"))
        assertEquals("ΰ", precomposeAccent(PrefixAccent.TONOS, "ϋ"))
    }

    @Test fun `tonos on consonant returns null`() {
        assertNull(precomposeAccent(PrefixAccent.TONOS, "κ"))
        assertNull(precomposeAccent(PrefixAccent.TONOS, "σ"))
    }

    @Test fun `dialytika on iota and upsilon`() {
        assertEquals("ϊ", precomposeAccent(PrefixAccent.DIALYTIKA, "ι"))
        assertEquals("ϋ", precomposeAccent(PrefixAccent.DIALYTIKA, "υ"))
        assertEquals("Ϊ", precomposeAccent(PrefixAccent.DIALYTIKA, "Ι"))
        assertEquals("Ϋ", precomposeAccent(PrefixAccent.DIALYTIKA, "Υ"))
    }

    @Test fun `dialytika on already-tonos vowel returns combined form`() {
        assertEquals("ΐ", precomposeAccent(PrefixAccent.DIALYTIKA, "ί"))
        assertEquals("ΰ", precomposeAccent(PrefixAccent.DIALYTIKA, "ύ"))
    }

    @Test fun `dialytika on non-iota-upsilon vowel returns null`() {
        assertNull(precomposeAccent(PrefixAccent.DIALYTIKA, "α"))
        assertNull(precomposeAccent(PrefixAccent.DIALYTIKA, "ε"))
    }

    @Test fun `tonos-dialytika on iota and upsilon`() {
        assertEquals("ΐ", precomposeAccent(PrefixAccent.TONOS_DIALYTIKA, "ι"))
        assertEquals("ΰ", precomposeAccent(PrefixAccent.TONOS_DIALYTIKA, "υ"))
    }

    @Test fun `tonos-dialytika on other vowels returns null`() {
        assertNull(precomposeAccent(PrefixAccent.TONOS_DIALYTIKA, "α"))
        assertNull(precomposeAccent(PrefixAccent.TONOS_DIALYTIKA, "η"))
    }

    @Test fun `tonos returns single-codepoint precomposed character`() {
        // Sanity: ά must be one codepoint (U+03AC), not α + U+0301.
        val result = precomposeAccent(PrefixAccent.TONOS, "α")!!
        assertEquals(1, result.codePointCount(0, result.length))
        assertEquals(0x03AC, result.codePointAt(0))
    }
}
