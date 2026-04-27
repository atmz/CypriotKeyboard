package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class AccentCombinerTest {

    @Test fun `tonos applies to vowel`() {
        // Last char before the accent key is "α" → emit "́" (combining tonos)
        assertEquals(AccentResult.Combine("́"), applyAccent("΄", "α"))
    }

    @Test fun `tonos rejected on consonant`() {
        assertEquals(AccentResult.Reject, applyAccent("΄", "κ"))
    }

    @Test fun `breve applies to sigma family`() {
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "σ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ζ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ξ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ψ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ς"))
    }

    @Test fun `breve rejected on vowel`() {
        assertEquals(AccentResult.Reject, applyAccent("˘", "α"))
    }

    @Test fun `dialytika applies to iota or upsilon`() {
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ι"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "υ"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ί"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ύ"))
    }

    @Test fun `tonos-dialytika cases`() {
        // ι/υ → emit ¨ + tonos
        assertEquals(AccentResult.Combine("̈́"), applyAccent("΅", "ι"))
        assertEquals(AccentResult.Combine("̈́"), applyAccent("΅", "υ"))
        // already-dialytika ϊ/ϋ → emit just tonos
        assertEquals(AccentResult.Combine("́"), applyAccent("΅", "ϊ"))
        assertEquals(AccentResult.Combine("́"), applyAccent("΅", "ϋ"))
        // already-tonos ί/ύ → emit dialytika
        assertEquals(AccentResult.Combine("̈"), applyAccent("΅", "ί"))
        assertEquals(AccentResult.Combine("̈"), applyAccent("΅", "ύ"))
    }

    @Test fun `unknown accent is rejected`() {
        assertEquals(AccentResult.Reject, applyAccent("x", "α"))
    }

    @Test fun `empty preceding char is rejected`() {
        assertEquals(AccentResult.Reject, applyAccent("΄", ""))
    }
}
