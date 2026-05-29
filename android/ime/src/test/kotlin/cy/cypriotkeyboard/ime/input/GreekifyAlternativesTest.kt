package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GreekifyAlternativesTest {

    @Test fun `no branchable chars returns single variant`() {
        assertEquals(listOf("καλος"), greekifyAlternatives("καλος"))
    }

    @Test fun `theta branches to tau-eta`() {
        // "θελω" → ["θελω", "τηελω"]
        val variants = greekifyAlternatives("θελω")
        assertTrue("expected θελω in $variants", variants.contains("θελω"))
        assertTrue("expected τηελω in $variants", variants.contains("τηελω"))
    }

    @Test fun `digraph alpha-phi branches to alpha-upsilon`() {
        // Greeklish "afth" → "αφθ"; should also explore "αυθ" + "αυτη".
        val variants = greekifyAlternatives("αφθ")
        assertTrue("expected αυθ in $variants", variants.contains("αυθ"))
        assertTrue("expected αυτη in $variants", variants.contains("αυτη"))
    }

    @Test fun `chi branches to xi`() {
        // Greeklish "x" maps greedily to χ in greekify, but in modern
        // Greeklish convention "x" often means ξ (e.g. "axia" → αξία).
        // Branch every χ in the post-greekify output to also try ξ.
        val variants = greekifyAlternatives("αχια")
        assertTrue("expected αχια in $variants", variants.contains("αχια"))
        assertTrue("expected αξια in $variants", variants.contains("αξια"))
    }

    @Test fun `capital chi branches to capital xi`() {
        val variants = greekifyAlternatives("Χαρα")
        assertTrue("expected Χαρα in $variants", variants.contains("Χαρα"))
        assertTrue("expected Ξαρα in $variants", variants.contains("Ξαρα"))
    }

    @Test fun `digit 8 branches to theta`() {
        val variants = greekifyAlternatives("8α")
        assertTrue("expected θα in $variants", variants.contains("θα"))
        assertTrue("expected 8α in $variants", variants.contains("8α"))
    }

    @Test fun `8 then theta both expand`() {
        // 8 → 8/θ; θ → θ/τη. Across both: 8θ, 8τη, θθ, θτη.
        val variants = greekifyAlternatives("8θ")
        assertTrue("expected 8θ in $variants", variants.contains("8θ"))
        assertTrue("expected θθ in $variants", variants.contains("θθ"))
    }

    @Test fun `capitalised forms branch`() {
        // Capital theta should branch to "Τη"
        val variants = greekifyAlternatives("Θελω")
        assertTrue("expected Τηελω in $variants", variants.contains("Τηελω"))
    }

    @Test fun `digraph wins over single-char`() {
        // "αφ" is matched as a digraph (αφ ⇄ αυ); the single-char α and φ
        // rules don't fire. So variants are exactly αφ and αυ, no extra
        // single-char alternatives.
        val variants = greekifyAlternatives("αφ")
        assertEquals(setOf("αφ", "αυ"), variants.toSet())
    }

    @Test fun `maxVariants caps growth`() {
        // 4 thetas → 2^4 = 16 raw combinations; cap at 4.
        val variants = greekifyAlternatives("θθθθ", maxVariants = 4)
        assertEquals(4, variants.size)
    }

    @Test fun `output preserves input order with first variant matching greedy`() {
        // The greedy reading (first slot of each rule) must come out first
        // so callers that just want one fold key can take .first().
        val variants = greekifyAlternatives("θα")
        assertEquals("θα", variants.first())
    }
}
