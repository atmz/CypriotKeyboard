package cy.cypriotkeyboard.ime.input

/**
 * Result of an accent-key tap. The IME caller must delete the just-inserted
 * accent character from the input buffer regardless of result; only when
 * [Combine] does it then commit the combining-diacritic string.
 */
sealed class AccentResult {
    object Reject : AccentResult()
    data class Combine(val combining: String) : AccentResult()
}

/**
 * Mirrors `triggerAccent` in CypriotKeyboardActionHandler.swift (lines 86-124).
 * Allowed-base-letter checks per accent must match the Swift sets exactly.
 */
fun applyAccent(accentKey: String, lastChar: String): AccentResult {
    if (lastChar.isEmpty()) return AccentResult.Reject
    val lastLower = lastChar.lowercase()
    return when (accentKey) {
        "˘" -> if (lastLower in setOf("σ", "ζ", "ξ", "ψ", "ς"))
            AccentResult.Combine("̆") else AccentResult.Reject
        " ̈" -> if (lastLower in setOf("ι", "ί", "υ", "ύ"))
            AccentResult.Combine("̈") else AccentResult.Reject
        "΅" -> when (lastLower) {
            "ι", "υ" -> AccentResult.Combine("̈́")
            "ϊ", "ϋ" -> AccentResult.Combine("́")
            "ί", "ύ" -> AccentResult.Combine("̈")
            else -> AccentResult.Reject
        }
        "΄" -> if (lastLower in setOf("α", "ε", "ι", "η", "υ", "ο", "ω", "ϋ", "ϊ", "ὀ"))
            AccentResult.Combine("́") else AccentResult.Reject
        else -> AccentResult.Reject
    }
}
