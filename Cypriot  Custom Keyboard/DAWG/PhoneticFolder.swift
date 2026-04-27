//
//  PhoneticFolder.swift
//  Cypriot  Custom Keyboard
//
//  Mirrors dict_generation/phonetic_fold.py. Loads phonetic_fold.json
//  and applies longest-match-first folding to map phonetically-equivalent
//  Greek spellings (η/ι/υ/ει/οι/υι etc.) to canonical fold-key characters.
//

import Foundation


enum PhoneticFolderError: Error {
    case malformedJSON
    case missingResource
}


final class PhoneticFolder {

    /// (source-string, destination-string) pairs sorted longest-first.
    private let rules: [(source: [Character], dest: String)]
    private let maxSourceLen: Int

    init(jsonData: Data) throws {
        struct RawRule: Decodable {
            let from: String
            let to: String
        }
        struct RawFile: Decodable {
            let version: Int
            let rules: [RawRule]
        }
        let raw = try JSONDecoder().decode(RawFile.self, from: jsonData)
        // Sort longest-first so 2-char digraphs win over 1-char rules.
        let sorted = raw.rules.sorted { $0.from.count > $1.from.count }
        self.rules = sorted.map { (Array($0.from), $0.to) }
        self.maxSourceLen = sorted.first?.from.count ?? 1
    }

    /// Fold input by greedily matching the longest source pattern at each
    /// position, emitting the canonical key character, and advancing past
    /// the matched length. Identical algorithm to the Python implementation.
    func fold(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        out.reserveCapacity(text.count)
        var i = 0
        let n = chars.count
        while i < n {
            var matched = false
            for (src, dst) in rules {
                if i + src.count <= n {
                    var ok = true
                    for k in 0..<src.count {
                        if chars[i + k] != src[k] { ok = false; break }
                    }
                    if ok {
                        out.append(dst)
                        i += src.count
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }

    /// Loads the bundled phonetic_fold.json. Used by the runtime.
    static func loadDefault() throws -> PhoneticFolder {
        guard let url = Bundle.main.url(forResource: "phonetic_fold", withExtension: "json") else {
            throw PhoneticFolderError.missingResource
        }
        return try PhoneticFolder(jsonData: try Data(contentsOf: url))
    }
}
