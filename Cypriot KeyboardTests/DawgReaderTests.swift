import XCTest
@testable import Cypriot_Keyboard

class DawgReaderTests: XCTestCase {

    private var reader: DawgReader!
    private var oracle: [String: Any]!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        guard let dawgURL = bundle.url(forResource: "tiny_fixture", withExtension: "dawg") else {
            XCTFail("missing tiny_fixture.dawg in test bundle")
            return
        }
        guard let oracleURL = bundle.url(forResource: "tiny_fixture", withExtension: "json") else {
            XCTFail("missing tiny_fixture.json in test bundle")
            return
        }
        self.reader = try DawgReader(url: dawgURL)
        self.oracle = try JSONSerialization.jsonObject(with: Data(contentsOf: oracleURL)) as? [String: Any]
    }

    func testHeaderMagicAndVersion() {
        XCTAssertEqual(reader.version, 1)
        XCTAssertGreaterThan(reader.nodeCount, 0)
    }

    func testKnownLookupsResolveToExpectedCanonicals() throws {
        let lookups = oracle["lookups"] as! [[String: Any]]
        for lookup in lookups {
            let input = lookup["input"] as! String
            let foldKey = lookup["fold_key"] as! String
            let expected = lookup["expect_canonicals"] as! [String]
            let pidx = reader.payloadForKey(foldKey)
            if expected.isEmpty {
                XCTAssertNil(pidx, "expected no payload for fold_key=\(foldKey) (input=\(input))")
            } else {
                XCTAssertNotNil(pidx, "expected a payload for fold_key=\(foldKey) (input=\(input))")
                let canonicals = reader.canonicalForms(payloadIdx: pidx!).map { $0.0 }
                for ec in expected {
                    XCTAssertTrue(canonicals.contains(ec),
                                  "expected \(ec) in \(canonicals) for input=\(input)")
                }
            }
        }
    }

    func testCanonicalFormsReturnFrequenciesInDescendingOrder() {
        let foldKeys = oracle["fold_keys"] as! [String: Any]
        for (key, payloadInfoAny) in foldKeys {
            guard let pidx = reader.payloadForKey(key) else {
                XCTFail("missing payload for key \(key)")
                continue
            }
            let actual = reader.canonicalForms(payloadIdx: pidx)
            for i in 1..<actual.count {
                XCTAssertGreaterThanOrEqual(actual[i - 1].1, actual[i].1,
                                            "canonical_forms not descending in freq for \(key)")
            }
            let expectedList = payloadInfoAny as! [[String: Any]]
            XCTAssertEqual(actual.count, expectedList.count, "canonical count mismatch for \(key)")
        }
    }

    func testRootNodeIsLastNode() {
        XCTAssertEqual(reader.rootNodeIdx, reader.nodeCount - 1)
    }

    func testInvalidMagicThrows() throws {
        let bogusData = Data(repeating: 0xFF, count: 64)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bogus.dawg")
        try bogusData.write(to: url)
        XCTAssertThrowsError(try DawgReader(url: url))
        try? FileManager.default.removeItem(at: url)
    }
}
