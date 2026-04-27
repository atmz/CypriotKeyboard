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
