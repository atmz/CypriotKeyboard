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
