//
//  Cypriot_KeyboardTests.swift
//  Cypriot KeyboardTests
//
//  Created by Alex Toumazis on 2/4/21.
//

import XCTest
@testable import Cypriot_Keyboard

// MARK: - shouldAttemptAutocomplete

class ShouldAttemptAutocompleteTests: XCTestCase {

    func testSkipsPureNumbers() {
        // Regression: typing "30" was being autocorrected to "3η" because the
        // Greeklish branch ran on numeric tokens.
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "30"))
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "1234"))
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "0"))
    }

    func testSkipsBarePunctuation() {
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "("))
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "..."))
        XCTAssertFalse(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: ""))
    }

    func testRunsOnLetters() {
        XCTAssertTrue(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "hello"))
        XCTAssertTrue(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "γεια"))
        XCTAssertTrue(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "(hello"))
        XCTAssertTrue(CypriotKeyboardHelper.shouldAttemptAutocomplete(text: "iPad2"))
    }
}

// MARK: - greekify

class GreekifyTests: XCTestCase {

    func testEmpty() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: ""), "")
    }

    func testSingleLetters() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "a"), "α")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "e"), "ε")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "i"), "ι")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "o"), "ο")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "u"), "υ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "y"), "υ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "w"), "ω")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "h"), "η")
    }

    func testConsonants() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "k"), "κ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "c"), "κ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "v"), "β")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "f"), "φ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "x"), "χ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "z"), "ζ")
    }

    func testB_becomes_mp() {
        // 'b' is two characters in Greek (μπ), since standalone /b/ is absent.
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "b"), "μπ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "B"), "Μπ")
    }

    func testCapitals() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "A"), "Α")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Hello"), "Ηελλο")
    }

    func testDigraphs_sh_ch() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "sh"), "σ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Sh"), "Σ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ch"), "τσ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Ch"), "Τσ̆")
    }

    func testDigraphs_psKsTh() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ps"), "ψ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ks"), "ξ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "th"), "θ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Th"), "Θ")
    }

    func testThs_takesPriorityOverTh() {
        // "ths" represents "της" (genitive feminine article), distinct from
        // standalone "th" (θ).
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ths"), "τησ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Ths"), "Τησ")
    }

    func testYi_takesPriorityOverY() {
        // "yi" is a single sound /ji/, written γι in Greek; the standalone
        // y/i mappings would otherwise produce "υι".
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "yi"), "γι")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "Yi"), "Γι")
    }

    func testJ() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "j"), "τζ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "J"), "Τζ̆")
    }

    func testNgAndNgk_bothBecome_gk() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ng"), "γκ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "ngk"), "γκ")
    }

    func testAllCapsDigraphs() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "PSALMOS"), "ΨΑΛΜΟΣ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "SH"), "Σ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "CH"), "Τσ̆")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "KS"), "Ξ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "TH"), "Θ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "THS"), "Τησ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "YI"), "Γι")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "NG"), "γκ")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "NGK"), "γκ")
    }

    func testDigit3_becomesXi() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "3"), "ξ")
    }

    func testNumbers_passThroughExcept3() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "0"), "0")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "30"), "ξ0")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "100"), "100")
    }

    func testWords() {
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "hello"), "ηελλο")
        // "yiasou" = informal Cypriot greeting. yi → γι, then a/s/o/u.
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "yiasou"), "γιασου")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "kalos"), "καλοσ")
    }

    func testAlreadyGreek_unchanged() {
        // greekify only rewrites Latin → Greek; existing Greek chars (including
        // accents and final sigma ς) pass through untouched.
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "για"), "για")
        XCTAssertEqual(CypriotKeyboardHelper.greekify(text: "καλός"), "καλός")
    }
}

// MARK: - countSyllables

class CountSyllablesTests: XCTestCase {

    func testEmpty() {
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: ""), 0)
    }

    func testSingleVowel() {
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "α"), 1)
    }

    func testConsecutiveVowels_countAsOne() {
        // "και" → only 'α' counts because 'ι' immediately follows another vowel.
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "και"), 1)
    }

    func testTwoSyllables() {
        // "ξανα" → ξ no, α yes, ν no, α yes → 2.
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "ξανα"), 2)
    }

    func testAccentedVowels_areCounted() {
        // Accented vowels (ά έ ή ί ό ύ ώ) must count as syllables — otherwise
        // shouldReplace's "skip 1-syllable words" check misclassifies common
        // 2-syllable accented words like "καλός" as monosyllabic.
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "καλός"), 2)
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "ή"), 1)
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "γιατί"), 2)
    }

    func testGreeklishVowels() {
        // "yiasou" lowercased: y(syllable), i(consec, skip), a(consec, skip), s, o(syllable), u(consec, skip) → 2.
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "yiasou"), 2)
        XCTAssertEqual(CypriotKeyboardHelper.countSyllables(text: "kalos"), 2)
    }
}

// MARK: - distanceMeasure

class DistanceMeasureTests: XCTestCase {

    func testIdentical() {
        XCTAssertEqual(CypriotKeyboardHelper.distanceMeasure(transliteratedWord: "hello", greekWord: "hello"), 0.0)
    }

    func testSingleEdit() {
        XCTAssertEqual(CypriotKeyboardHelper.distanceMeasure(transliteratedWord: "a", greekWord: "b"), 1.0)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(CypriotKeyboardHelper.distanceMeasure(transliteratedWord: "HELLO", greekWord: "hello"), 0.0)
    }

    func testAccentInsensitive() {
        // Diacritics are folded before comparing.
        XCTAssertEqual(CypriotKeyboardHelper.distanceMeasure(transliteratedWord: "καλος", greekWord: "καλός"), 0.0)
    }

    func testEmptyVsLetter() {
        XCTAssertEqual(CypriotKeyboardHelper.distanceMeasure(transliteratedWord: "", greekWord: "α"), 1.0)
    }
}

// MARK: - shouldReplace

class ShouldReplaceTests: XCTestCase {

    // Pure-Greek branch (text == greekText): replace ONLY when accent-only diff and ≥2 syllables.

    func testGreek_singleSyllable_neverReplaces() {
        // Even though "δω" → "δώ" is an accent-only diff, single-syllable words
        // don't carry accents in convention, so we don't auto-correct.
        XCTAssertFalse(CypriotKeyboardHelper.shouldReplace(text: "δω", greekText: "δω", guess: "δώ"))
    }

    func testGreek_multiSyllable_accentOnly_replaces() {
        XCTAssertTrue(CypriotKeyboardHelper.shouldReplace(text: "καλος", greekText: "καλος", guess: "καλός"))
    }

    func testGreek_multiSyllable_nonAccentDiff_doesNotReplace() {
        XCTAssertFalse(CypriotKeyboardHelper.shouldReplace(text: "καλος", greekText: "καλος", guess: "ξύλο"))
    }

    func testGreek_alreadyAccented_doesNotReplaceWithSelf() {
        // accentlessWord == text fails because text already has accents.
        XCTAssertFalse(CypriotKeyboardHelper.shouldReplace(text: "καλός", greekText: "καλός", guess: "καλός"))
    }

    func testGreek_capitalized_accentOnly_replaces() {
        XCTAssertTrue(CypriotKeyboardHelper.shouldReplace(text: "Καλος", greekText: "Καλος", guess: "Καλός"))
    }

    // Greeklish branch (text != greekText): replace when Levenshtein < 3.

    func testGreeklish_closeMatch_replaces() {
        XCTAssertTrue(CypriotKeyboardHelper.shouldReplace(text: "kalos", greekText: "καλος", guess: "καλός"))
    }

    func testGreeklish_farMatch_doesNotReplace() {
        // greekText "α" vs guess folded "καλος" → distance 4, ≥ 3.
        XCTAssertFalse(CypriotKeyboardHelper.shouldReplace(text: "a", greekText: "α", guess: "καλός"))
    }
}

// MARK: - isCommonWord

class IsCommonWordTests: XCTestCase {

    func testKnown() {
        XCTAssertTrue(CypriotKeyboardHelper.isCommonWord(word: "για"))
        XCTAssertTrue(CypriotKeyboardHelper.isCommonWord(word: "και"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(CypriotKeyboardHelper.isCommonWord(word: "Για"))
    }

    func testUnknown() {
        XCTAssertFalse(CypriotKeyboardHelper.isCommonWord(word: "xyz"))
        XCTAssertFalse(CypriotKeyboardHelper.isCommonWord(word: ""))
    }
}

// MARK: - levenshtein

class LevenshteinTests: XCTestCase {

    func testIdentical() {
        XCTAssertEqual("kitten".levenshtein("kitten"), 0)
        XCTAssertEqual("".levenshtein(""), 0)
    }

    func testEmptyVsNonEmpty() {
        XCTAssertEqual("".levenshtein("abc"), 3)
        XCTAssertEqual("abc".levenshtein(""), 3)
    }

    func testClassicCases() {
        XCTAssertEqual("kitten".levenshtein("sitting"), 3)
        XCTAssertEqual("flaw".levenshtein("lawn"), 2)
        XCTAssertEqual("intention".levenshtein("execution"), 5)
    }

    func testSymmetric() {
        XCTAssertEqual("foo".levenshtein("bar"), "bar".levenshtein("foo"))
        XCTAssertEqual("καλη".levenshtein("καλι"), "καλι".levenshtein("καλη"))
    }

    func testGraphemeClusters() {
        // σ̆ is a single grapheme cluster (σ + U+0306) — counts as one Character.
        XCTAssertEqual("σ̆".levenshtein("σ"), 1)
        XCTAssertEqual("καλημέρα".levenshtein("καλημερα"), 1)
    }

    func testTriangleInequality() {
        // d(a,c) ≤ d(a,b) + d(b,c) for any a,b,c
        let a = "kalimera", b = "καλημερα", c = "καλημέρα"
        XCTAssertLessThanOrEqual(a.levenshtein(c), a.levenshtein(b) + b.levenshtein(c))
    }
}

// MARK: - End-to-end autocomplete (real Hunspell)

class SuggestionsE2ETests: XCTestCase {

    static var provider: CypriotAutocompleteSuggestionProvider!

    override class func setUp() {
        super.setUp()
        provider = CypriotAutocompleteSuggestionProvider()
        // Hunspell init runs on a background queue; poll until ready.
        let deadline = Date().addingTimeInterval(5.0)
        while provider.speller == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    override func setUpWithError() throws {
        try XCTSkipIf(Self.provider.speller == nil, "Hunspell speller failed to initialize")
    }

    private func suggestions(for text: String) -> [CypriotAutocompleteSuggestion] {
        var captured: [CypriotAutocompleteSuggestion] = []
        Self.provider.autocompleteSuggestions(for: text) { result in
            if case .success(let s) = result {
                captured = s.compactMap { $0 as? CypriotAutocompleteSuggestion }
            }
        }
        return captured
    }

    private func willReplaceText(in suggestions: [CypriotAutocompleteSuggestion]) -> String? {
        return suggestions.first { $0.additionalInfo["willReplace"] as? Bool == true }?.text
    }

    func testNumber_doesNotAutoreplace() {
        // Original bug: typing "30" produced "3η" via the Greeklish branch.
        XCTAssertNil(willReplaceText(in: suggestions(for: "30")))
    }

    func testGreek_accentOnly_correction() {
        // Multi-syllable Greek without the accent should suggest an accented form.
        // Don't pin the exact word — Hunspell may rank "κάλος" (callus) above
        // "καλός" (good); both are valid accent-only corrections of "καλος".
        let candidate = willReplaceText(in: suggestions(for: "καλος"))
        XCTAssertNotNil(candidate)
        let folded = candidate?.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
        XCTAssertEqual(folded, "καλος", "Candidate must differ from input only in accents")
        XCTAssertNotEqual(candidate, "καλος", "Candidate must actually add accents")
    }

    func testGreeklish_producesGreekCandidate() {
        // Don't pin the exact word — dict ordering can change. Just confirm a
        // Greek (non-ASCII) candidate is offered.
        let candidate = willReplaceText(in: suggestions(for: "kalos"))
        XCTAssertNotNil(candidate)
        XCTAssertTrue(candidate?.contains(where: { !$0.isASCII }) ?? false,
                      "Expected a Greek candidate for 'kalos', got \(candidate ?? "nil")")
    }
}
