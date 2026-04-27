//
//  DawgReader.swift
//  Cypriot  Custom Keyboard
//
//  Reads the v1 binary DAWG format (see dict_generation/DAWG_FORMAT.md).
//  Mmap-backed; lookups are O(input length) jumps into the mapped region.
//

import Foundation


enum DawgReaderError: Error {
    case fileTooShort
    case badMagic
    case unsupportedVersion(UInt16)
}


final class DawgReader {

    let data: Data            // mmap-backed
    let version: UInt16
    let nodeCount: Int
    let payloadCount: Int
    let stringCount: Int

    private let nodeSectionOffset: Int
    private let payloadSectionOffset: Int
    private let stringTableOffset: Int

    private let nodeOffsets: [Int]
    private let payloadOffsets: [Int]
    private let stringOffsets: [Int]

    var rootNodeIdx: Int { nodeCount - 1 }

    private static let magic: [UInt8] = [0x44, 0x41, 0x57, 0x47]  // "DAWG"
    private static let nullPayload: UInt32 = 0xFFFFFFFF
    private static let headerSize = 32

    init(url: URL) throws {
        // mmap the file (lazy paging — pages fault in as we read).
        self.data = try Data(contentsOf: url, options: .alwaysMapped)
        guard data.count >= DawgReader.headerSize else {
            throw DawgReaderError.fileTooShort
        }
        // Magic check
        for (i, b) in DawgReader.magic.enumerated() {
            if data[i] != b { throw DawgReaderError.badMagic }
        }
        self.version = data.readU16(at: 4)
        guard version == 1 else { throw DawgReaderError.unsupportedVersion(version) }
        self.nodeCount = Int(data.readU32(at: 8))
        self.payloadCount = Int(data.readU32(at: 12))
        self.stringCount = Int(data.readU32(at: 16))
        self.nodeSectionOffset = Int(data.readU32(at: 20))
        self.payloadSectionOffset = Int(data.readU32(at: 24))
        self.stringTableOffset = Int(data.readU32(at: 28))

        self.nodeOffsets = DawgReader.indexNodes(data: data, start: nodeSectionOffset, count: nodeCount)
        self.payloadOffsets = DawgReader.indexPayloads(data: data, start: payloadSectionOffset, count: payloadCount)
        self.stringOffsets = DawgReader.indexStrings(data: data, start: stringTableOffset, count: stringCount)
    }

    // MARK: - Public API

    /// Walks from root following `key`'s characters. Returns the terminal
    /// payload index, or nil if no path or non-terminal.
    func payloadForKey(_ key: String) -> Int? {
        var nodeIdx = rootNodeIdx
        for ch in key.unicodeScalars {
            guard let next = step(from: nodeIdx, char: ch.value) else { return nil }
            nodeIdx = next
        }
        return terminalPayload(at: nodeIdx)
    }

    /// Returns the canonical-form list for a given payload index.
    func canonicalForms(payloadIdx: Int) -> [(String, UInt32)] {
        let off = payloadOffsets[payloadIdx]
        let count = Int(data.readU16(at: off))
        var out: [(String, UInt32)] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let recordOff = off + 2 + i * 8
            let strIdx = Int(data.readU32(at: recordOff))
            let freq = data.readU32(at: recordOff + 4)
            out.append((readString(idx: strIdx), freq))
        }
        return out
    }

    /// Used by DamerauLevenshteinSuggester for DAWG-walking algorithms.
    func terminalPayload(at nodeIdx: Int) -> Int? {
        let off = nodeOffsets[nodeIdx]
        let payload = data.readU32(at: off + 2)
        return payload == DawgReader.nullPayload ? nil : Int(payload)
    }

    /// Returns next-node-index for the given character, or nil if no edge.
    func step(from nodeIdx: Int, char: UInt32) -> Int? {
        let off = nodeOffsets[nodeIdx]
        let edgeCount = Int(data.readU16(at: off))
        let edgesStart = off + 2 + 4
        // Edges are stored sorted by char_codepoint ascending.
        // Linear scan with early-exit (binary search would help on pathological
        // alphabets, but our fold-keyspace alphabet is small; linear is fine).
        for i in 0..<edgeCount {
            let recordOff = edgesStart + i * 8
            let cp = data.readU32(at: recordOff)
            if cp == char {
                return Int(data.readU32(at: recordOff + 4))
            }
            if cp > char { return nil }
        }
        return nil
    }

    /// Returns all (char_codepoint, target_node_idx) edges from a node.
    /// Used by the suggester's DAWG-walking algorithms.
    func edges(from nodeIdx: Int) -> [(UInt32, Int)] {
        let off = nodeOffsets[nodeIdx]
        let edgeCount = Int(data.readU16(at: off))
        let edgesStart = off + 2 + 4
        var out: [(UInt32, Int)] = []
        out.reserveCapacity(edgeCount)
        for i in 0..<edgeCount {
            let recordOff = edgesStart + i * 8
            let cp = data.readU32(at: recordOff)
            let target = Int(data.readU32(at: recordOff + 4))
            out.append((cp, target))
        }
        return out
    }

    // MARK: - Section indexing

    private static func indexNodes(data: Data, start: Int, count: Int) -> [Int] {
        var offs = [Int]()
        offs.reserveCapacity(count)
        var cursor = start
        for _ in 0..<count {
            offs.append(cursor)
            let edgeCount = Int(data.readU16(at: cursor))
            cursor += 2 + 4 + edgeCount * 8
        }
        return offs
    }

    private static func indexPayloads(data: Data, start: Int, count: Int) -> [Int] {
        var offs = [Int]()
        offs.reserveCapacity(count)
        var cursor = start
        for _ in 0..<count {
            offs.append(cursor)
            let cfCount = Int(data.readU16(at: cursor))
            cursor += 2 + cfCount * 8
        }
        return offs
    }

    private static func indexStrings(data: Data, start: Int, count: Int) -> [Int] {
        var offs = [Int]()
        offs.reserveCapacity(count)
        var cursor = start
        for _ in 0..<count {
            offs.append(cursor)
            let len = Int(data.readU16(at: cursor))
            cursor += 2 + len
        }
        return offs
    }

    private func readString(idx: Int) -> String {
        let off = stringOffsets[idx]
        let len = Int(data.readU16(at: off))
        return String(data: data.subdata(in: (off + 2)..<(off + 2 + len)), encoding: .utf8) ?? ""
    }
}


// MARK: - Little-endian read helpers on Data

private extension Data {
    func readU16(at offset: Int) -> UInt16 {
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readU32(at offset: Int) -> UInt32 {
        return UInt32(self[offset])
             | (UInt32(self[offset + 1]) << 8)
             | (UInt32(self[offset + 2]) << 16)
             | (UInt32(self[offset + 3]) << 24)
    }
}
