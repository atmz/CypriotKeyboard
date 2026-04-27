package cy.cypriotkeyboard.ime.input

/**
 * Greeklish → Greek single-pass scanner. Mirrors
 * iOS `CypriotKeyboardHelper.greekify` (CypriotKeyboardUtil.swift). Longest-
 * match-first: trigraph → digraph → single. Order of disambiguation is
 * load-bearing: "th" must dispatch before "t"/"h" individually.
 */
fun greekify(text: String): String {
    if (text.isEmpty()) return text
    val sb = StringBuilder(text.length * 2)
    var i = 0
    val n = text.length
    while (i < n) {
        val c0 = text[i]
        if (i + 2 < n) {
            val tri = greekifyTrigraph(c0, text[i + 1], text[i + 2])
            if (tri != null) {
                sb.append(tri)
                i += 3
                continue
            }
        }
        if (i + 1 < n) {
            val di = greekifyDigraph(c0, text[i + 1])
            if (di != null) {
                sb.append(di)
                i += 2
                continue
            }
        }
        val single = greekifySingle(c0)
        if (single != null) sb.append(single) else sb.append(c0)
        i += 1
    }
    return sb.toString()
}

private fun greekifyTrigraph(a: Char, b: Char, c: Char): String? = when {
    (a == 'n' && b == 'g' && c == 'k') || (a == 'N' && b == 'G' && c == 'K') -> "γκ"
    a == 't' && b == 'h' && c == 's' -> "τησ"
    (a == 'T' && b == 'h' && c == 's') || (a == 'T' && b == 'H' && c == 'S') -> "Τησ"
    else -> null
}

private fun greekifyDigraph(a: Char, b: Char): String? = when {
    a == 's' && b == 'h' -> "σ̆"
    (a == 'S' && b == 'h') || (a == 'S' && b == 'H') -> "Σ̆"
    a == 'c' && b == 'h' -> "τσ̆"
    (a == 'C' && b == 'h') || (a == 'C' && b == 'H') -> "Τσ̆"
    a == 'p' && b == 's' -> "ψ"
    (a == 'P' && b == 's') || (a == 'P' && b == 'S') -> "Ψ"
    a == 'k' && b == 's' -> "ξ"
    (a == 'K' && b == 's') || (a == 'K' && b == 'S') -> "Ξ"
    (a == 'T' && b == 'h') || (a == 'T' && b == 'H') -> "Θ"
    a == 't' && b == 'h' -> "θ"
    a == 'y' && b == 'i' -> "γι"
    (a == 'Y' && b == 'i') || (a == 'Y' && b == 'I') -> "Γι"
    (a == 'n' && b == 'g') || (a == 'N' && b == 'G') -> "γκ"
    else -> null
}

private fun greekifySingle(c: Char): String? = when (c) {
    'a' -> "α"; 'A' -> "Α"
    'i' -> "ι"; 'I' -> "Ι"
    'e' -> "ε"; 'E' -> "Ε"
    'o' -> "ο"; 'O' -> "Ο"
    'u' -> "υ"; 'U' -> "Υ"
    'y' -> "υ"; 'Y' -> "Υ"
    'w' -> "ω"; 'W' -> "Ω"
    'r' -> "ρ"; 'R' -> "Ρ"
    't' -> "τ"; 'T' -> "Τ"
    'p' -> "π"; 'P' -> "Π"
    's' -> "σ"; 'S' -> "Σ"
    'd' -> "δ"; 'D' -> "Δ"
    'f' -> "φ"; 'F' -> "Φ"
    'g' -> "γ"; 'G' -> "Γ"
    'h' -> "η"; 'H' -> "Η"
    'k' -> "κ"; 'K' -> "Κ"
    'l' -> "λ"; 'L' -> "Λ"
    'z' -> "ζ"; 'Z' -> "Ζ"
    'x' -> "χ"; 'X' -> "Χ"
    'c' -> "κ"; 'C' -> "Κ"
    'v' -> "β"; 'V' -> "Β"
    'b' -> "μπ"; 'B' -> "Μπ"
    'n' -> "ν"; 'N' -> "Ν"
    'm' -> "μ"; 'M' -> "Μ"
    'j' -> "τζ̆"; 'J' -> "Τζ̆"
    '3' -> "ξ"
    else -> null
}
