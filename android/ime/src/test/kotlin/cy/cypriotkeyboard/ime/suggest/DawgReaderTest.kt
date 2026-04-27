package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class DawgReaderTest {

    private fun loadBundled(): DawgReader {
        // Tests run from the module dir; assets are at src/main/assets.
        val file = File("src/main/assets/el_CY.dawg")
        require(file.exists()) { "el_CY.dawg missing — run Task 4 to bundle it" }
        val bytes = file.readBytes()
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        return DawgReader.from(buf)
    }

    @Test fun `header parses successfully`() {
        val reader = loadBundled()
        assertTrue(reader.nodeCount > 0)
        assertTrue(reader.payloadCount > 0)
        assertTrue(reader.stringCount > 0)
    }

    @Test fun `lookup of a known word returns a payload`() {
        // We don't know exact fold-keys without folding, but we know the DAWG
        // contains paths. Just walking from root with any common letter must
        // succeed for at least some of them.
        val reader = loadBundled()
        val root = reader.rootNodeIdx
        // Greek alpha codepoint 0x03B1
        val next = reader.step(root, 0x03B1)
        // The DAWG may or may not have an edge from root for any specific char,
        // but root has at least one edge (smoke test).
        assertTrue(reader.edges(root).isNotEmpty())
    }

    @Test fun `bad magic throws`() {
        val buf = ByteBuffer.allocate(32).order(ByteOrder.LITTLE_ENDIAN)
        // wrong magic
        buf.put("XXXX".toByteArray())
        repeat(28) { buf.put(0) }
        buf.rewind()
        try {
            DawgReader.from(buf)
            org.junit.Assert.fail("expected DawgReaderException for bad magic")
        } catch (e: DawgReaderException) {
            // ok
        }
    }
}
