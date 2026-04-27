package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
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
        // "ει" must fold to "ı", not "ε"+"ı"
        assertEquals("κıμε", folder.fold("ειμε"))
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
}
