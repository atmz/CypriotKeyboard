package cy.cypriotkeyboard.ime.layout

/**
 * Pure data describing one keyboard layout (e.g. Greek alpha, numeric).
 * Mirrors the iOS InputSetProvider rows + the iPhoneLayoutProvider's
 * bottomActions(). Width is in 0.0..1.0 units of one column-of-9.
 */
data class KeySpec(
    val action: KeyAction,
    val label: String,
    val widthUnits: Float = 1.0f,
    val popupChars: List<String> = emptyList(),
    /**
     * Disabled keys render greyed-out and ignore taps and long-presses.
     * Used by the contextual breve key — visible always so users can find
     * it, tappable only when the previous letter is one that takes breve.
     */
    val enabled: Boolean = true
)

sealed class KeyAction {
    data class Character(val text: String) : KeyAction()
    object Space : KeyAction()
    object Return : KeyAction()
    object Backspace : KeyAction()
    object Shift : KeyAction()
    /** Switches Greek ↔ Latin layouts (iOS 🔄 key). */
    object SwitchLayout : KeyAction()
    /** System next-keyboard (Android 🌐). */
    object SwitchIme : KeyAction()
    object NumericMode : KeyAction()
    object SymbolicMode : KeyAction()
    object AlphabeticMode : KeyAction()
}

data class LayoutSpec(
    val rows: List<List<KeySpec>>
)
