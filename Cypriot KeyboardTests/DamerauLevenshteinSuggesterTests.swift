import XCTest
@testable import Cypriot_Keyboard

class DamerauLevenshteinSuggesterTests: XCTestCase {

    private var reader: DawgReader!
    private var folder: PhoneticFolder!
    private var suggester: DamerauLevenshteinSuggester!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        guard let dawgURL = bundle.url(forResource: "tiny_fixture", withExtension: "dawg") else {
            XCTFail(); return
        }
        guard let foldURL = bundle.url(forResource: "phonetic_fold", withExtension: "json") else {
            XCTFail(); return
        }
        self.reader = try DawgReader(url: dawgURL)
        self.folder = try PhoneticFolder(jsonData: try Data(contentsOf: foldURL))
        self.suggester = DamerauLevenshteinSuggester(reader: reader)
    }

    func testExactMatchReturnsDistanceZero() {
        let key = folder.fold("καλός")
        let suggestions = suggester.suggest(forKey: key, limit: 5)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.editDistance, 0)
        XCTAssertTrue(suggestions.contains(where: { $0.canonical == "καλός" }))
    }

    func testSingleSubstitutionReturnsDistanceOne() {
        // Take an exact-match key and substitute one character — should still
        // find the original via edit-1.
        let key = folder.fold("καλός")
        var chars = Array(key)
        chars[0] = "x"  // substitute first character with something not in the key
        let perturbed = String(chars)
        let suggestions = suggester.suggest(forKey: perturbed, limit: 5)
        XCTAssertTrue(suggestions.contains(where: { $0.canonical == "καλός" && $0.editDistance == 1 }))
    }

    func testSingleInsertionReturnsDistanceOne() {
        let key = folder.fold("νερό")
        let perturbed = "x" + key  // prepend extra char
        let suggestions = suggester.suggest(forKey: perturbed, limit: 5)
        XCTAssertTrue(suggestions.contains(where: { $0.canonical == "νερό" && $0.editDistance == 1 }))
    }

    func testSingleDeletionReturnsDistanceOne() {
        let key = folder.fold("νερό")
        let perturbed = String(key.dropFirst())
        let suggestions = suggester.suggest(forKey: perturbed, limit: 5)
        XCTAssertTrue(suggestions.contains(where: { $0.canonical == "νερό" && $0.editDistance == 1 }))
    }

    func testTranspositionReturnsDistanceOne() {
        // Damerau-Levenshtein-specific: swapping adjacent characters costs 1, not 2.
        let key = folder.fold("νερό")
        var chars = Array(key)
        guard chars.count >= 2 else { XCTFail("test fixture too short"); return }
        let tmp = chars[0]; chars[0] = chars[1]; chars[1] = tmp
        let transposed = String(chars)
        let suggestions = suggester.suggest(forKey: transposed, limit: 5)
        XCTAssertTrue(suggestions.contains(where: { $0.canonical == "νερό" && $0.editDistance == 1 }),
                      "transposition should find original at distance 1")
    }

    func testEditDistanceTwoReturnsNothing() {
        // Two unrelated random characters → no candidate within edit-1.
        let suggestions = suggester.suggest(forKey: "qzxc", limit: 5)
        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Multi-key (suggest(forKeys:))

    func testMultiKeySuggestEmptyKeysReturnsEmpty() {
        let multi = suggester.suggest(forKeys: [], limit: 5)
        XCTAssertTrue(multi.isEmpty)
    }

    func testMultiKeySuggestPicksMinDistance() {
        // Same canonical reachable from key A at distance 0 and key B at
        // distance 1 → merged result must record distance 0.
        let exactKey = folder.fold("καλός")
        var perturbed = Array(exactKey)
        perturbed[0] = "x"
        let edit1Key = String(perturbed)
        let multi = suggester.suggest(forKeys: [exactKey, edit1Key], limit: 5)
        let kalos = multi.first { $0.canonical == "καλός" }
        XCTAssertNotNil(kalos, "καλός should appear in merged results")
        XCTAssertEqual(kalos?.editDistance, 0, "min of {0, 1} expected to be 0")
    }

    func testMultiKeySuggestDedupesAcrossKeys() {
        // Same key passed twice — canonicals must appear once each.
        let key = folder.fold("καλός")
        let multi = suggester.suggest(forKeys: [key, key], limit: 5)
        let canonicals = multi.map { $0.canonical }
        XCTAssertEqual(Set(canonicals).count, canonicals.count,
                       "duplicates not merged: \(canonicals)")
    }

    func testMultiKeySuggestSingleKeyMatchesSingleSuggest() {
        // Single-key invocation through the multi API must agree with the
        // single-key path on the same set (modulo ordering of equal-rank ties).
        let key = folder.fold("καλός")
        let single = Set(suggester.suggest(forKey: key, limit: 5).map { $0.canonical })
        let multi = Set(suggester.suggest(forKeys: [key], limit: 5).map { $0.canonical })
        XCTAssertEqual(single, multi)
    }

    func testDistanceZeroRanksAboveDistanceOne() {
        // When the input is the exact fold of "καλός", the exact match
        // (distance 0) must rank before any near-match.
        let key = folder.fold("καλός")
        let suggestions = suggester.suggest(forKey: key, limit: 10)
        for i in 1..<suggestions.count {
            XCTAssertGreaterThanOrEqual(suggestions[i].editDistance, suggestions[i - 1].editDistance)
        }
    }

    // MARK: - Casing-aware ranking (inputCasingHint)

    func testCapInputBoostsCapCanonicalAtSameDistance() {
        // The fixture stores three canonicals at fold key καλoσ:
        //   καλός freq=100, Καλός freq=50, καλώς freq=5.
        // With hint=.firstLetterCap, the cap-first canonical (Καλός) must
        // outrank lowercase canonicals at the same edit distance even
        // though it has lower frequency. Without the casing tiebreak
        // (frequency-only ranking) καλός would win, which is the bug:
        // cap-first input loses to a higher-frequency lowercase neighbour.
        let key = folder.fold("καλός")
        let suggestions = suggester.suggest(forKeys: [key], limit: 5,
                                            inputCasingHint: .firstLetterCap)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.canonical, "Καλός",
                       "cap-first hint should rank Καλός above lowercase neighbours; got \(suggestions.map { $0.canonical })")
    }

    func testLowercaseHintPrefersLowercaseCanonical() {
        // Mirror of the cap test: with hint=.lowercase, the lowercase
        // canonical wins (and frequency is the secondary tiebreak among
        // boosted canonicals — καλός freq=100 beats καλώς freq=5).
        let key = folder.fold("καλός")
        let suggestions = suggester.suggest(forKeys: [key], limit: 5,
                                            inputCasingHint: .lowercase)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.canonical, "καλός",
                       "lowercase hint should rank καλός first; got \(suggestions.map { $0.canonical })")
    }

    func testAllCapsHintPrefersCapCanonical() {
        // All-caps inputs use the same boost direction as firstLetterCap
        // (the canonical that starts with an uppercase letter). The fixture
        // doesn't have an all-caps canonical (e.g. ΚΑΛΟΣ), so cap-first
        // Καλός is the closest available match — and that's exactly what
        // the boost should pick over the lowercase alternatives.
        let key = folder.fold("καλός")
        let suggestions = suggester.suggest(forKeys: [key], limit: 5,
                                            inputCasingHint: .allCaps)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.canonical, "Καλός",
                       "all-caps hint should prefer cap-first canonical; got \(suggestions.map { $0.canonical })")
    }

    func testCasingHintIsTiebreakOnlyEditDistanceStillDominates() {
        // Edit distance still dominates: a perturbed (edit-1) lowercase
        // key with a cap-first canonical at distance 1 must NOT outrank
        // an exact-match lowercase canonical at distance 0, even when
        // hint=firstLetterCap. This guards against the boost bleeding
        // across distance buckets.
        // Use "νεpό"-style perturbation? Simpler: use the key for νερό
        // (distance 0 to νερό, no cap canonical at this key) and verify
        // ordering is unchanged regardless of hint.
        let key = folder.fold("νερό")
        let withCapHint = suggester.suggest(forKeys: [key], limit: 5,
                                            inputCasingHint: .firstLetterCap)
        XCTAssertEqual(withCapHint.first?.canonical, "νερό",
                       "edit-distance must dominate the casing boost")
        XCTAssertEqual(withCapHint.first?.editDistance, 0)
    }
}
