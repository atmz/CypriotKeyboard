package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class GreekifyTest {

    @Test fun `single letters map to greek`() {
        assertEquals("καλημερα", greekify("kalhmera"))
        assertEquals("αυτο", greekify("auto"))
    }

    @Test fun `digraphs win over single-letter rules`() {
        // "th" must become "θ" before "t"/"h" map individually
        assertEquals("θεοσ", greekify("theos"))
        // "ps" → "ψ" (not π+σ)
        assertEquals("ψυχη", greekify("psuxh"))
        // "ks" → "ξ" (not κ+σ)
        assertEquals("ξανα", greekify("ksana"))
        // "sh" → "σ̆" (cypriot)
        assertEquals("σ̆ιερι", greekify("shieri"))
        // "ch" → "τσ̆"
        assertEquals("τσ̆αι", greekify("chai"))
        // "yi" → "γι"
        assertEquals("γιοσ", greekify("yios"))
        // "ng" → "γκ"
        assertEquals("γκολ", greekify("ngol"))
    }

    @Test fun `trigraphs win over digraphs`() {
        // "ngk" → "γκ" (not γκ + κ; trigraph beats digraph)
        assertEquals("γκολ", greekify("ngkol"))
        // "ths" → "τησ" (lowercase trigraph)
        assertEquals("τησ", greekify("ths"))
        // "Ths"/"THS" → "Τησ"
        assertEquals("Τησ", greekify("Ths"))
        assertEquals("Τησ", greekify("THS"))
    }

    @Test fun `uppercase variants map`() {
        assertEquals("ΨΥΧΗ", greekify("PSYXH"))  // P→Ψ via digraph PS, Y→Υ, X→Χ, H→Η
        assertEquals("ΘΕΟΣ", greekify("THEOS"))
    }

    @Test fun `b becomes mu-pi digraph`() {
        // single-char b → "μπ"
        assertEquals("μπιρα", greekify("bira"))
        assertEquals("Μπιρα", greekify("Bira"))
    }

    @Test fun `j becomes tzeta digraph`() {
        assertEquals("τζ̆αι", greekify("jai"))
        assertEquals("Τζ̆αι", greekify("Jai"))
    }

    @Test fun `digit 3 maps to xi`() {
        assertEquals("ξενα", greekify("3ena"))
    }

    @Test fun `non-mapped chars pass through`() {
        assertEquals("καλη!", greekify("kalh!"))
        assertEquals(" ", greekify(" "))
        assertEquals("", greekify(""))
    }
}
