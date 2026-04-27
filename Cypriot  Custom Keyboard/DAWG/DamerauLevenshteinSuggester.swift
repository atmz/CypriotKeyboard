//
//  DamerauLevenshteinSuggester.swift
//  Cypriot  Custom Keyboard
//
//  Edit-distance-1 candidate enumeration over the folded keyspace.
//  Generates all single-edit variants of the input, looks each up,
//  collects canonicals, dedupes, ranks by (edit_distance asc, freq desc).
//
//  Phase 2.x may switch to a single-pass DAWG-walking automaton for
//  efficiency. The current candidate-enumeration approach is fast
//  enough for typical inputs (<100 chars, alphabet ~30) and is far
//  easier to verify correct.
//

import Foundation


struct DawgSuggestion {
    let canonical: String
    let frequency: UInt32
    let editDistance: Int
}


final class DamerauLevenshteinSuggester {

    let reader: DawgReader
    private let alphabet: [UInt32]

    init(reader: DawgReader) {
        self.reader = reader
        self.alphabet = DamerauLevenshteinSuggester.collectAlphabet(reader: reader)
    }

    /// Returns up to `limit` ranked candidates within Damerau-Levenshtein
    /// distance ≤ 1 of `key` (in the folded keyspace).
    func suggest(forKey key: String, limit: Int = 5) -> [DawgSuggestion] {
        var results: [(canonical: String, freq: UInt32, distance: Int)] = []
        var seenCanonicals = Set<String>()

        // Distance 0: exact match.
        if let pidx = reader.payloadForKey(key) {
            for (canonical, freq) in reader.canonicalForms(payloadIdx: pidx) {
                if seenCanonicals.insert(canonical).inserted {
                    results.append((canonical, freq, 0))
                }
            }
        }

        // Distance 1: enumerate edited variants, look each up.
        for variant in editDistance1Variants(of: key) {
            guard let pidx = reader.payloadForKey(variant) else { continue }
            for (canonical, freq) in reader.canonicalForms(payloadIdx: pidx) {
                if seenCanonicals.insert(canonical).inserted {
                    results.append((canonical, freq, 1))
                }
            }
        }

        // Sort by (distance asc, freq desc).
        results.sort { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.freq > rhs.freq
        }

        return results.prefix(limit).map {
            DawgSuggestion(canonical: $0.canonical, frequency: $0.freq, editDistance: $0.distance)
        }
    }

    // MARK: - Edit-distance-1 candidate enumeration

    private func editDistance1Variants(of key: String) -> [String] {
        let chars = Array(key.unicodeScalars)
        var out: [String] = []
        let n = chars.count

        // Deletions
        for i in 0..<n {
            var copy = chars
            copy.remove(at: i)
            out.append(String(String.UnicodeScalarView(copy)))
        }

        // Substitutions
        for i in 0..<n {
            for cp in alphabet {
                if cp == chars[i].value { continue }
                guard let scalar = Unicode.Scalar(cp) else { continue }
                var copy = chars
                copy[i] = scalar
                out.append(String(String.UnicodeScalarView(copy)))
            }
        }

        // Insertions (n+1 positions including beginning and end)
        for i in 0...n {
            for cp in alphabet {
                guard let scalar = Unicode.Scalar(cp) else { continue }
                var copy = chars
                copy.insert(scalar, at: i)
                out.append(String(String.UnicodeScalarView(copy)))
            }
        }

        // Adjacent transpositions (Damerau extension)
        if n >= 2 {
            for i in 0..<(n - 1) {
                if chars[i] == chars[i + 1] { continue }
                var copy = chars
                copy.swapAt(i, i + 1)
                out.append(String(String.UnicodeScalarView(copy)))
            }
        }

        return out
    }

    // MARK: - Alphabet discovery

    /// Walk the DAWG once, collect all distinct edge characters. Used for
    /// substitution and insertion variants.
    private static func collectAlphabet(reader: DawgReader) -> [UInt32] {
        var seen = Set<UInt32>()
        var stack: [Int] = [reader.rootNodeIdx]
        var visited = Set<Int>()
        while let nodeIdx = stack.popLast() {
            if !visited.insert(nodeIdx).inserted { continue }
            for (cp, target) in reader.edges(from: nodeIdx) {
                seen.insert(cp)
                stack.append(target)
            }
        }
        return Array(seen).sorted()
    }
}
