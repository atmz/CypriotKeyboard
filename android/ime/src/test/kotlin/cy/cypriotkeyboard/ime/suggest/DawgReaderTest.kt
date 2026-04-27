package cy.cypriotkeyboard.ime.suggest

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

    @Test fun `root node has at least one edge`() {
        // Smoke test: any non-empty DAWG must have at least one edge from root.
        // We don't probe a specific codepoint because exact fold-key shapes
        // depend on the bundled dictionary and are exercised in the suggester
        // tests instead.
        val reader = loadBundled()
        assertTrue(reader.edges(reader.rootNodeIdx).isNotEmpty())
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
