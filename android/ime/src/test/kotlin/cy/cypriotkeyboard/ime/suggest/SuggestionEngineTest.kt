package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SuggestionEngineTest {

    private fun engine(): SuggestionEngine {
        val dawg = File("src/main/assets/el_CY.dawg")
        val fold = File("src/main/assets/phonetic_fold.json")
        val reader = DawgReader.from(ByteBuffer.wrap(dawg.readBytes()).order(ByteOrder.LITTLE_ENDIAN))
        val folder = PhoneticFolder.fromJson(fold.readText())
        return SuggestionEngine(reader, folder)
    }

    @Test fun `empty input returns empty list`() {
        assertEquals(emptyList<Suggestion>(), engine().suggest(""))
    }

    @Test fun `slot 0 is always verbatim user input`() {
        val res = engine().suggest("καλημερα")
        assertTrue(res.isNotEmpty())
        assertEquals("καλημερα", res[0].text)
        assertTrue(res[0].isVerbatim)
        assertEquals(false, res[0].willReplace)
    }

    @Test fun `slot 1 (when present) is willReplace top candidate`() {
        val res = engine().suggest("καλημερα")
        if (res.size >= 2) {
            assertEquals(true, res[1].willReplace)
            assertEquals(false, res[1].isVerbatim)
        }
    }

    @Test fun `firstLetterCap input yields capitalized suggestions`() {
        val res = engine().suggest("Καλημερα")
        if (res.size >= 2) {
            assertTrue("expected uppercase first letter, got ${res[1].text}",
                res[1].text.isNotEmpty() && res[1].text.first().isUpperCase())
        }
    }

    @Test fun `allCaps input yields uppercase suggestions`() {
        val res = engine().suggest("ΚΑΛΗΜΕΡΑ")
        if (res.size >= 2) {
            assertEquals(res[1].text, res[1].text.uppercase())
        }
    }

    // -- Behavioral parity with the Hunspell provider (commits bb056fb, be45200)
    // Mirrors the four iOS XCTests in DawgIntegrationTests.swift.

    @Test fun `common-word fast path returns only verbatim`() {
        // "νερό" is in CommonWords.SET. Pure-Greek input matches the
        // greekified form (greekify is a no-op for already-Greek text), so
        // the fast path fires: verbatim only, no autocorrect candidates.
        val res = engine().suggest("νερό")
        assertEquals("common word should return verbatim only; got ${res.map { it.text }}",
            1, res.size)
        assertEquals("νερό", res[0].text)
        assertTrue(res[0].isVerbatim)
    }

    @Test fun `Greeklish common word is not short-circuited`() {
        // The fast path requires text == greek (pure-Greek input). Greeklish
        // input that happens to greekify to a common word should still go
        // through the lookup pipeline so the user sees the canonical form.
        val res = engine().suggest("nero")
        assertTrue("Greeklish input should produce a candidate; got ${res.map { it.text }}",
            res.size >= 2)
    }

    @Test fun `random Greek does not force-replace`() {
        // shouldReplace gate: an input with no vowels can't produce a valid
        // diacritic-only replacement (countSyllables < 2), so no slot can
        // get willReplace=true. Spacebar must not yank the user's input.
        val res = engine().suggest("ξψδγ")
        if (res.size >= 2) {
            assertFalse("random Greek input must not force-replace; got willReplace on ${res[1].text}",
                res[1].willReplace)
        }
    }

    @Test fun `punctuation prefix is preserved on suggestion`() {
        // Hunspell parity: leading punct gets stripped before lookup and
        // re-prepended to each suggestion so the user's surface form is kept.
        val res = engine().suggest(".καλος")
        assertTrue("expected ≥ 2 slots for .καλος; got ${res.size}", res.size >= 2)
        assertEquals("verbatim slot must echo the input as typed",
            ".καλος", res[0].text)
        assertTrue("candidate must keep the leading '.' prefix; got ${res[1].text}",
            res[1].text.startsWith("."))
    }

    @Test fun `single digit returns no suggestions`() {
        // Regression: typing "8" used to greekify to "" and then the
        // suggester returned single-character Greek letters as edit-1
        // neighbors. Number-only / punctuation-only tokens should suppress
        // autocomplete entirely.
        val eng = engine()
        assertTrue(eng.suggest("8").isEmpty())
        assertTrue(eng.suggest("30").isEmpty())
        assertTrue(eng.suggest(".").isEmpty())
        assertTrue(eng.suggest("8!").isEmpty())
    }

    @Test fun `long input caps at three slots`() {
        // Inputs over 5 chars get at most 2 candidates → 3 slots total
        // (verbatim + 2). Mirrors the Hunspell provider's length-aware
        // sizing so suggestions stay readable when each slot is narrow.
        val res = engine().suggest("αυτοκίνητο")
        assertTrue("long input should cap at 3 slots; got ${res.size}",
            res.size <= 3)
    }

    @Test fun `short input caps at four slots`() {
        // Inputs ≤5 chars get up to 3 candidates → 4 slots total.
        val res = engine().suggest("καλος")
        assertTrue("short input should cap at 4 slots; got ${res.size}",
            res.size <= 4)
    }
}
