package cy.cypriotkeyboard.ime.suggest

import java.nio.ByteBuffer
import java.nio.ByteOrder

class DawgReaderException(message: String) : RuntimeException(message)

/**
 * Reads the v1 binary DAWG format. See dict_generation/DAWG_FORMAT.md.
 * Mirror of `DawgReader.swift`. The buffer must be little-endian.
 *
 * Lookups are O(input length) jumps into the buffer — node/payload/string
 * offsets are computed once at construction.
 */
class DawgReader private constructor(
    private val buf: ByteBuffer,
    val version: Int,
    val nodeCount: Int,
    val payloadCount: Int,
    val stringCount: Int,
    private val nodeOffsets: IntArray,
    private val payloadOffsets: IntArray,
    private val stringOffsets: IntArray
) {

    val rootNodeIdx: Int get() = nodeCount - 1

    /** Walks from root following `key`'s code points. Returns terminal payload index, or null. */
    fun payloadForKey(key: String): Int? {
        var nodeIdx = rootNodeIdx
        var i = 0
        while (i < key.length) {
            val cp = key.codePointAt(i)
            i += Character.charCount(cp)
            nodeIdx = step(nodeIdx, cp) ?: return null
        }
        return terminalPayload(nodeIdx)
    }

    /** Returns next-node index for the given char codepoint, or null. */
    fun step(nodeIdx: Int, char: Int): Int? {
        val off = nodeOffsets[nodeIdx]
        val edgeCount = buf.getShort(off).toInt() and 0xFFFF
        val edgesStart = off + 2 + 4
        // Edges sorted ascending by codepoint. Linear scan with early exit.
        for (i in 0 until edgeCount) {
            val recordOff = edgesStart + i * 8
            val cp = buf.getInt(recordOff)
            val cpUnsigned = cp.toLong() and 0xFFFFFFFFL
            val charLong = char.toLong() and 0xFFFFFFFFL
            if (cpUnsigned == charLong) return buf.getInt(recordOff + 4)
            if (cpUnsigned > charLong) return null
        }
        return null
    }

    /** All `(codepoint, target_node_idx)` edges from a node. */
    fun edges(nodeIdx: Int): List<Pair<Int, Int>> {
        val off = nodeOffsets[nodeIdx]
        val edgeCount = buf.getShort(off).toInt() and 0xFFFF
        val edgesStart = off + 2 + 4
        val out = ArrayList<Pair<Int, Int>>(edgeCount)
        for (i in 0 until edgeCount) {
            val recordOff = edgesStart + i * 8
            val cp = buf.getInt(recordOff)
            val target = buf.getInt(recordOff + 4)
            out.add(cp to target)
        }
        return out
    }

    /** Terminal payload index for a node, or null if non-terminal. */
    fun terminalPayload(nodeIdx: Int): Int? {
        val off = nodeOffsets[nodeIdx]
        val payload = buf.getInt(off + 2)
        return if (payload == NULL_PAYLOAD) null else payload
    }

    /** All canonical-form (string, frequency) pairs for a payload index. */
    fun canonicalForms(payloadIdx: Int): List<Pair<String, Long>> {
        val off = payloadOffsets[payloadIdx]
        val count = buf.getShort(off).toInt() and 0xFFFF
        val out = ArrayList<Pair<String, Long>>(count)
        for (i in 0 until count) {
            val recordOff = off + 2 + i * 8
            val strIdx = buf.getInt(recordOff)
            val freq = buf.getInt(recordOff + 4).toLong() and 0xFFFFFFFFL
            out.add(readString(strIdx) to freq)
        }
        return out
    }

    private fun readString(idx: Int): String {
        val off = stringOffsets[idx]
        val len = buf.getShort(off).toInt() and 0xFFFF
        val bytes = ByteArray(len)
        // ByteBuffer.get(int, byte[], ...) is API 31+, so use a duplicate to be
        // safe with min-sdk 24.
        val dup = buf.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        dup.position(off + 2)
        dup.get(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    companion object {
        private const val HEADER_SIZE = 32
        // 0x47574144 == "DAWG" little-endian
        private const val MAGIC_LE: Int = 0x47574144
        private const val NULL_PAYLOAD: Int = -1  // 0xFFFFFFFF as signed int

        fun from(rawBuf: ByteBuffer): DawgReader {
            val buf = rawBuf.duplicate().order(ByteOrder.LITTLE_ENDIAN)
            if (buf.capacity() < HEADER_SIZE) throw DawgReaderException("file too short")
            // Magic: bytes 0..3 must be 'D','A','W','G' (0x44,0x41,0x57,0x47)
            // Read as a little-endian int32 → 0x47574144.
            val magic = buf.getInt(0)
            if (magic != MAGIC_LE) throw DawgReaderException("bad magic 0x${magic.toString(16)}")
            val version = buf.getShort(4).toInt() and 0xFFFF
            if (version != 1) throw DawgReaderException("unsupported version $version")
            val nodeCount = buf.getInt(8)
            val payloadCount = buf.getInt(12)
            val stringCount = buf.getInt(16)
            val nodeSectionOff = buf.getInt(20)
            val payloadSectionOff = buf.getInt(24)
            val stringTableOff = buf.getInt(28)

            val nodeOffsets = indexNodes(buf, nodeSectionOff, nodeCount)
            val payloadOffsets = indexPayloads(buf, payloadSectionOff, payloadCount)
            val stringOffsets = indexStrings(buf, stringTableOff, stringCount)

            return DawgReader(
                buf, version, nodeCount, payloadCount, stringCount,
                nodeOffsets, payloadOffsets, stringOffsets
            )
        }

        private fun indexNodes(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val edgeCount = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + 4 + edgeCount * 8
            }
            return offs
        }

        private fun indexPayloads(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val cfCount = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + cfCount * 8
            }
            return offs
        }

        private fun indexStrings(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val len = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + len
            }
            return offs
        }
    }
}
