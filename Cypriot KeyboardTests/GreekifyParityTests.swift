import XCTest
@testable import Cypriot_Keyboard

class GreekifyParityTests: XCTestCase {

    func testCorpusParityWithPython() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "greekify_corpus", withExtension: "json") else {
            XCTFail("greekify_corpus.json not in test bundle")
            return
        }
        struct Pair: Decodable { let input: String; let expected: String }
        struct Corpus: Decodable { let pairs: [Pair] }
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        var failures: [(String, String, String)] = []
        for p in corpus.pairs {
            let got = CypriotKeyboardHelper.greekify(text: p.input)
            if got != p.expected {
                failures.append((p.input, p.expected, got))
            }
        }
        if !failures.isEmpty {
            let msg = failures.prefix(5).map {
                "input=\($0.0) expected=\($0.1) got=\($0.2)"
            }.joined(separator: "; ")
            XCTFail("\(failures.count)/\(corpus.pairs.count) parity failures; first 5: \(msg)")
        }
    }
}
