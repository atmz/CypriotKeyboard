package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SuggestionHelpersTest {

    // -- shouldAttemptAutocomplete --

    @Test fun `pure letters allowed`() {
        assertTrue(shouldAttemptAutocomplete("kalimera"))
        assertTrue(shouldAttemptAutocomplete("καλημέρα"))
    }

    @Test fun `mix of letters and digits allowed`() {
        assertTrue(shouldAttemptAutocomplete("k4limera"))
    }

    @Test fun `digits only blocked`() {
        assertFalse(shouldAttemptAutocomplete("8"))
        assertFalse(shouldAttemptAutocomplete("30"))
        assertFalse(shouldAttemptAutocomplete("8!"))
    }

    @Test fun `punctuation only blocked`() {
        assertFalse(shouldAttemptAutocomplete("."))
        assertFalse(shouldAttemptAutocomplete("()"))
    }

    @Test fun `empty input blocked`() {
        assertFalse(shouldAttemptAutocomplete(""))
    }

    // -- countSyllables --

    @Test fun `vowel runs count once`() {
        assertEquals(2, countSyllables("καλος"))     // κα-λος
        assertEquals(2, countSyllables("καλός"))     // diacritics stripped first
        assertEquals(4, countSyllables("καλημερα"))  // κα-λη-με-ρα
    }

    @Test fun `adjacent vowels count once`() {
        // αι is a single vowel cluster (one syllable break).
        assertEquals(1, countSyllables("αι"))
        // αιμα is one vowel cluster αι, then α → 2 syllables.
        assertEquals(2, countSyllables("αιμα"))
    }

    @Test fun `single-vowel words count one`() {
        assertEquals(1, countSyllables("σε"))
        assertEquals(1, countSyllables("το"))
    }

    @Test fun `no vowels counts zero`() {
        assertEquals(0, countSyllables("ξψδγ"))
    }

    // -- stripDiacritics --

    @Test fun `tonos is stripped`() {
        // stripDiacritics removes combining marks only; it does NOT
        // normalise ς → σ (that's the phonetic folder's job). Mirrors
        // iOS's folding(options: .diacriticInsensitive) behaviour.
        assertEquals("καλος", stripDiacritics("καλός"))
        assertEquals("καλως", stripDiacritics("καλώς"))
    }

    @Test fun `no diacritics is no-op`() {
        assertEquals("καλος", stripDiacritics("καλος"))
    }

    // -- levenshtein --

    @Test fun `levenshtein basic distances`() {
        assertEquals(0, levenshtein("kalos", "kalos"))
        assertEquals(1, levenshtein("kalos", "kales"))   // sub
        assertEquals(1, levenshtein("kalos", "kalo"))    // del
        assertEquals(1, levenshtein("kalo", "kalos"))    // ins
        assertEquals(2, levenshtein("kalos", "kxlys"))
        assertEquals(5, levenshtein("kalos", "abcde"))
    }

    // -- shouldReplace pure-Greek --

    @Test fun `shouldReplace pure-Greek diacritic-only multi-syllable returns true`() {
        // text == greek, ≥2 syllables, candidate differs only by accents
        assertTrue(shouldReplace(text = "καλος", greekText = "καλος", guess = "καλός"))
    }

    @Test fun `shouldReplace pure-Greek single-syllable returns false`() {
        // ≥2 syllable rule — single-syllable Greek doesn't carry accents
        assertFalse(shouldReplace(text = "σε", greekText = "σε", guess = "σέ"))
    }

    @Test fun `shouldReplace pure-Greek non-diacritic difference returns false`() {
        // Differs by more than diacritics — guess has different letters
        assertFalse(shouldReplace(text = "καλος", greekText = "καλος", guess = "καλιο"))
    }

    @Test fun `shouldReplace pure-Greek identical returns false`() {
        // accentlessGuess == guess means the candidate has no diacritics to
        // contribute; nothing to replace.
        assertFalse(shouldReplace(text = "καλος", greekText = "καλος", guess = "καλος"))
    }

    // -- shouldReplace Greeklish --

    @Test fun `shouldReplace Greeklish low-Levenshtein returns true`() {
        // text != greek (Greeklish input). Candidate within Levenshtein 3
        // of the greekified form (all lowercase + diacritic-stripped).
        assertTrue(shouldReplace(text = "kalos", greekText = "καλος", guess = "καλός"))
    }

    @Test fun `shouldReplace Greeklish far candidate returns false`() {
        assertFalse(shouldReplace(text = "kalos", greekText = "καλος", guess = "ξψδγψ"))
    }
}
