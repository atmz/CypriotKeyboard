package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneticFolderTest {

    private val sampleJson = """
        {
          "version": 1,
          "rules": [
            {"from": "ει", "to": "ı"},
            {"from": "οι", "to": "ı"},
            {"from": "αι", "to": "e"},
            {"from": "ι", "to": "ı"},
            {"from": "η", "to": "ı"},
            {"from": "υ", "to": "ı"},
            {"from": "ε", "to": "e"},
            {"from": "ο", "to": "o"},
            {"from": "ω", "to": "o"},
            {"from": "ά", "to": "α"},
            {"from": "ς", "to": "σ"}
          ]
        }
    """.trimIndent()

    private val folder = PhoneticFolder.fromJson(sampleJson)

    @Test fun `digraph wins over single-letter rule`() {
        // "ει" must fold to "ı" as a single rule, not via the "ε"+"ι"
        // single-letter rules. Verify by feeding plain "ειμε" — if the
        // greedy match worked, the leading "ει" → "ı" (one char), not
        // "ε" → "e" plus "ι" → "ı" (two chars).
        assertEquals("ıμe", folder.fold("ειμε"))
    }

    @Test fun `iota-equivalents collapse to dotless-i`() {
        assertEquals("κıλo", folder.fold("κηλω"))
        assertEquals("κıσσ", folder.fold("κυσς"))
    }

    @Test fun `accented vowels fold to base`() {
        assertEquals("καλα", folder.fold("κάλα"))
    }

    @Test fun `pass-through for unmapped chars`() {
        assertEquals("xyz", folder.fold("xyz"))
        assertEquals("", folder.fold(""))
    }

    @Test fun `final-sigma folds to medial sigma`() {
        assertEquals("φıσ", folder.fold("φησ"))
        assertEquals("φıσ", folder.fold("φης"))   // ς → σ rule
    }

    // -- foldVariants --

    @Test fun `foldVariants no digraph returns one variant`() {
        // "νερα" — ν passes through, ε→e, ρ passes through, α passes through.
        // No multi-char rule fires. Single variant only.
        val variants = folder.foldVariants("νερα")
        assertEquals(listOf("νeρα"), variants)
    }

    @Test fun `foldVariants one digraph returns two variants`() {
        // "νοιμα" has οι at position 1. Two branches:
        //   (a) digraph fires: ν + (οι→ı) + μ + α = "νıμα"
        //   (b) digraph skipped, single-char rules apply: ν + (ο→o) + (ι→ı) + μ + α = "νoıμα"
        val variants = folder.foldVariants("νοιμα")
        assertTrue("expected νıμα in $variants", variants.contains("νıμα"))
        assertTrue("expected νoıμα in $variants", variants.contains("νoıμα"))
        assertEquals(2, variants.size)
    }

    @Test fun `foldVariants first variant matches greedy fold`() {
        for (word in listOf("καλημερα", "νοιμα", "ποικιλια", "αιθερα", "νερα")) {
            val variants = folder.foldVariants(word)
            assertEquals(
                "first variant must match greedy fold for '$word'",
                folder.fold(word),
                variants.first()
            )
        }
    }

    @Test fun `foldVariants two digraphs returns up to four variants`() {
        // "ποικιλεια" has οι at 1 and ει at 6. 2 × 2 = up to 4 variants.
        val variants = folder.foldVariants("ποικιλεια")
        assertTrue("expected at least 2 variants, got ${variants.size}", variants.size >= 2)
        assertTrue("expected at most 4 variants, got ${variants.size}", variants.size <= 4)
    }

    @Test fun `foldVariants caps growth at maxVariants`() {
        val text = "οι".repeat(8)  // 8 digraphs → up to 256 raw variants
        val variants = folder.foldVariants(text, maxVariants = 4)
        assertEquals(4, variants.size)
    }
}
