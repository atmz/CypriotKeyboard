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

    /// Branches at each position where a digraph rule matches: emits both
    /// the digraph fold AND the single-char fold of the leading character.
    /// Where no digraph applies, behaves identically to `fold`.
    ///
    /// Used by multi-fold lookup so an input like `noima` ("νοιμα") produces
    /// both `νoıμα` (treating οι as a digraph) and `νoıμα` via the
    /// alternate single-char path — letting the suggester find both `νόημα`
    /// and `νήμα` and rank them correctly.
    func foldVariants(_ text: String, maxVariants: Int = 16) -> [String] {
        let chars = Array(text)
        let n = chars.count
        var seen = Set<String>()
        var out: [String] = []

        func helper(_ i: Int, _ acc: String) {
            if out.count >= maxVariants { return }
            if i >= n {
                if seen.insert(acc).inserted {
                    out.append(acc)
                }
                return
            }
            // Find longest digraph match (rules are sorted longest-first).
            var digraph: (src: [Character], dst: String)? = nil
            for (src, dst) in rules where src.count >= 2 {
                if i + src.count <= n {
                    var ok = true
                    for k in 0..<src.count {
                        if chars[i + k] != src[k] { ok = false; break }
                    }
                    if ok { digraph = (src, dst); break }
                }
            }
            // Find single-char rule for chars[i] (if any).
            var single: (src: [Character], dst: String)? = nil
            for (src, dst) in rules where src.count == 1 {
                if chars[i] == src[0] { single = (src, dst); break }
            }
            if let d = digraph {
                helper(i + d.src.count, acc + d.dst)
            }
            if let s = single {
                helper(i + 1, acc + s.dst)
            } else if digraph == nil {
                helper(i + 1, acc + String(chars[i]))
            }
        }

        helper(0, "")
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
