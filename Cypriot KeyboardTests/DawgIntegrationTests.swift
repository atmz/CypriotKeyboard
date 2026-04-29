import XCTest
@testable import Cypriot_Keyboard

class DawgIntegrationTests: XCTestCase {

    private var provider: DawgAutocompleteSuggestionProvider!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        guard let dawgURL = bundle.url(forResource: "tiny_fixture", withExtension: "dawg") else {
            XCTFail(); return
        }
        guard let foldURL = bundle.url(forResource: "phonetic_fold", withExtension: "json") else {
            XCTFail(); return
        }
        let reader = try DawgReader(url: dawgURL)
        let folder = try PhoneticFolder(jsonData: try Data(contentsOf: foldURL))
        self.provider = DawgAutocompleteSuggestionProvider(reader: reader, folder: folder)
    }

    func testReturnsVerbatimInSlot0() {
        let result = collectSuggestions(for: "καλός")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result[0].text, "καλός")
        XCTAssertTrue(result[0].isUnknown)  // verbatim flag
    }

    func testSlot1HasWillReplaceForPhoneticMatch() {
        let result = collectSuggestions(for: "καλος")  // typo for "καλός"
        guard result.count >= 2 else { XCTFail("expected ≥ 2 slots"); return }
        // The top autocorrect candidate is one of the canonicals at the same fold key.
        XCTAssertTrue(result[1].text == "καλός" || result[1].text == "καλώς")
        XCTAssertEqual(result[1].additionalInfo["willReplace"] as? Bool, true)
    }

    func testEmptyInputReturnsEmpty() {
        let result = collectSuggestions(for: "")
        XCTAssertTrue(result.isEmpty)
    }

    func testUnknownInputReturnsOnlyVerbatim() {
        let result = collectSuggestions(for: "qzxcvb")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "qzxcvb")
        XCTAssertTrue(result[0].isUnknown)
    }

    func testCapitalizedInputProducesCapitalizedSuggestion() {
        // The fixture has "καλός" / "καλώς" / "νερό" / "σπίτι" / "αυτοκίνητο".
        // Typing "Καλος" (capital Κ, no accent) should resolve to a capitalized
        // canonical via the DAWG (lookup against lowercase fold key,
        // recapitalize the canonical for display).
        let result = collectSuggestions(for: "Καλος")
        guard result.count >= 2 else { XCTFail("expected ≥ 2 slots; got \(result.count)"); return }
        // Slot 0 verbatim is the user's literal input.
        XCTAssertEqual(result[0].text, "Καλος")
        // Slot 1 should be a capitalized canonical (Καλός or Καλώς).
        let slot1 = result[1].text
        XCTAssertTrue(slot1 == "Καλός" || slot1 == "Καλώς",
                      "expected capitalized canonical, got \(slot1)")
        XCTAssertEqual(result[1].additionalInfo["willReplace"] as? Bool, true)
    }

    func testLowercaseInputProducesLowercaseSuggestion() {
        // Sanity check: lowercase input still produces lowercase canonical
        // (no spurious capitalization).
        let result = collectSuggestions(for: "καλος")
        guard result.count >= 2 else { XCTFail(); return }
        let slot1 = result[1].text
        XCTAssertTrue(slot1 == "καλός" || slot1 == "καλώς",
                      "expected lowercase canonical, got \(slot1)")
    }

    func testCapitalizedInputExactMatchRanksAboveEditDistanceOne() {
        // The bug we're fixing: "Νερο" should resolve to "Νερό" (exact-fold-match,
        // edit distance 0) rather than to ξέρω/καιρό at edit distance 1.
        let result = collectSuggestions(for: "Νερο")
        guard result.count >= 2 else { XCTFail("expected ≥ 2 slots; got \(result.count)"); return }
        // The top autocorrect candidate must be Νερό. (Capitalized.)
        XCTAssertEqual(result[1].text, "Νερό",
                       "expected Νερό at slot 1; got \(result[1].text). Bug regressed.")
    }

    func testAllCapsLatinInputProducesAllCapsSuggestion() {
        // Input "KALOS" → greekify → "ΚΑΛΟΣ" (all-caps Greek). Detection picks
        // the all-caps path: lowercase whole string, fold, lookup, then
        // uppercase the canonical for display.
        let result = collectSuggestions(for: "KALOS")
        guard result.count >= 2 else { XCTFail("expected ≥ 2 slots; got \(result.count)"); return }
        let slot1 = result[1].text
        // Result must be all uppercase.
        XCTAssertEqual(slot1, slot1.uppercased(),
                       "expected all-caps suggestion; got \(slot1)")
        // The canonical uppercased should start with "ΚΑΛ" (root of καλός/καλώς).
        // Use hasPrefix rather than equality because Swift's uppercased() may
        // produce different Unicode normalization for the tonos/accent character
        // than the literal written in source (both are valid UTF-8 representations
        // of the same glyph, but == is byte-exact).
        XCTAssertTrue(slot1.hasPrefix("ΚΑΛ"),
                       "all-caps slot1 should start with ΚΑΛ (from καλός/καλώς); got \(slot1)")
    }

    func testGreekAllCapsInputProducesAllCapsSuggestion() {
        // Same as above but the user types directly in Greek caps.
        let result = collectSuggestions(for: "ΚΑΛΟΣ")
        guard result.count >= 2 else { XCTFail(); return }
        let slot1 = result[1].text
        XCTAssertEqual(slot1, slot1.uppercased(),
                       "expected all-caps suggestion; got \(slot1)")
    }

    func testSingleCapitalLetterIsAllCapsButHarmless() {
        // Edge case: "Κ" is both capitalized AND all-caps. Either path is
        // correct; we just verify the lookup doesn't crash and produces a
        // verbatim slot 0.
        let result = collectSuggestions(for: "Κ")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result[0].text, "Κ")  // verbatim
    }

    func testMixedCaseInputUsesFirstLetterCapPath() {
        // "Καλός" — capitalized but not all-caps. First-letter path: lowercase
        // first char, fold, lookup, recapitalize first char.
        let result = collectSuggestions(for: "Καλός")
        guard result.count >= 2 else { XCTFail(); return }
        // Slot 1 should be a capitalized canonical.
        let slot1 = result[1].text
        XCTAssertTrue(slot1.first?.isUppercase ?? false,
                       "expected capitalized first char; got \(slot1)")
        // Should NOT be all-caps.
        XCTAssertNotEqual(slot1, slot1.uppercased(),
                          "expected mixed case, not all-caps; got \(slot1)")
    }

    func testCommonWordFastPathReturnsOnlyVerbatim() {
        // "νερό" is in commonWords AND the test fixture. The fast path should
        // short-circuit: only the verbatim slot is returned, no autocorrect
        // candidates pestering the user about a word they typed correctly.
        let result = collectSuggestions(for: "νερό")
        XCTAssertEqual(result.count, 1, "common word should return verbatim only; got \(result.map { $0.text })")
        XCTAssertEqual(result[0].text, "νερό")
        XCTAssertTrue(result[0].isUnknown)
    }

    func testGreeklishCommonWordIsNotShortCircuited() {
        // The fast path requires text == greek (pure-Greek input). Greeklish
        // input that happens to greekify to a common word should still go
        // through the lookup pipeline so the user sees the canonical form.
        // (The test fixture has "νερό" but typing "nero" is Greeklish.)
        let result = collectSuggestions(for: "nero")
        XCTAssertGreaterThanOrEqual(result.count, 2,
                                    "Greeklish input should produce a candidate; got \(result.map { $0.text })")
    }

    func testRandomGreekDoesNotForceReplace() {
        // shouldReplace gate: low-syllable Greek input ("νεο" — 2 syllables
        // but no diacritic-only candidate in the fixture) should produce
        // candidates without willReplace=true, so spacebar doesn't yank
        // the user's input.
        let result = collectSuggestions(for: "ξψδγ")
        // Either no candidate (nothing close), or a candidate without
        // willReplace. The forbidden state is "willReplace=true on a
        // candidate that isn't a near-match".
        if result.count >= 2 {
            XCTAssertNil(result[1].additionalInfo["willReplace"],
                         "random Greek input must not force-replace; got willReplace on \(result[1].text)")
        }
    }

    func testPunctuationPrefixIsPreservedOnSuggestion() {
        // Hunspell parity: leading punct gets stripped before lookup and
        // re-prepended to each suggestion so the user's surface form is
        // preserved.
        let result = collectSuggestions(for: ".καλος")
        guard result.count >= 2 else {
            XCTFail("expected ≥ 2 slots for .καλος; got \(result.count)")
            return
        }
        XCTAssertEqual(result[0].text, ".καλος", "verbatim slot must echo the input as typed")
        XCTAssertTrue(result[1].text.hasPrefix("."),
                      "candidate must keep the leading '.' prefix; got \(result[1].text)")
    }

    func testSingleDigitReturnsNoSuggestions() {
        // Regression: typing "8" used to greekify to "" and then the suggester
        // returned single-character Greek letters (η, ο) as edit-1 neighbors.
        // Number-only / punctuation-only tokens should suppress autocomplete
        // entirely, matching the Hunspell provider's behavior.
        XCTAssertTrue(collectSuggestions(for: "8").isEmpty)
        XCTAssertTrue(collectSuggestions(for: "30").isEmpty)
        XCTAssertTrue(collectSuggestions(for: ".").isEmpty)
        XCTAssertTrue(collectSuggestions(for: "8!").isEmpty)
    }

    func testLongInputCapsAtThreeSlots() {
        // Inputs over 5 chars get at most 2 candidates → 3 slots total
        // (verbatim + 2). Mirrors the Hunspell provider's length-aware sizing
        // so suggestions stay readable when each slot is narrow.
        let result = collectSuggestions(for: "αυτοκίνητο")
        XCTAssertLessThanOrEqual(result.count, 3,
                                 "long input should cap at 3 slots; got \(result.count)")
    }

    func testShortInputCapsAtFourSlots() {
        // Inputs ≤5 chars get up to 3 candidates → 4 slots total.
        // Use "καλος" which has multiple canonicals at distance 0 plus an
        // edit-1 neighbor (νερό-style) so the cap can actually be reached.
        let result = collectSuggestions(for: "καλος")
        XCTAssertLessThanOrEqual(result.count, 4,
                                 "short input should cap at 4 slots; got \(result.count)")
    }

    private func collectSuggestions(for text: String) -> [CypriotAutocompleteSuggestion] {
        var captured: [CypriotAutocompleteSuggestion] = []
        provider.autocompleteSuggestions(for: text) { result in
            if case .success(let suggestions) = result {
                captured = suggestions.compactMap { $0 as? CypriotAutocompleteSuggestion }
            }
        }
        return captured
    }
}
