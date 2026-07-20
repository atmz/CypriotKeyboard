package cy.cypriotkeyboard.ime.layout

import cy.cypriotkeyboard.ime.input.PrefixAccent
import cy.cypriotkeyboard.ime.input.precomposeAccent

/**
 * Concrete layout instances.
 *
 * Row 1 ends with TWO accent keys: a tonos key (΄) that's always tappable,
 * and a breve key (˘) that's only tappable when the previous letter is one
 * of σ ζ ξ ψ ς (the consonants Cypriot puts a breve on). The IME passes
 * `breveEnabled` per keystroke; when false, the breve key renders greyed
 * out and ignores taps.
 *
 * Tonos behaves as a PREFIX dead key (tap accent, then vowel → precomposed
 * single char). Breve stays POST-FIX (tap consonant first, then breve →
 * combining mark cluster). See ActionHandler for the mechanics.
 */
object Layouts {

    private fun ch(s: String, popups: List<String> = emptyList()): KeySpec =
        KeySpec(action = KeyAction.Character(s), label = s, popupChars = popups)

    fun greekAlphabetic(
        breveEnabled: Boolean = false,
        pendingAccent: PrefixAccent? = null
    ): LayoutSpec {
        // Both accent keys are always present; only the breve key's enabled
        // state changes with context. Width 0.5 each so the pair occupies
        // the same horizontal slot as a single full-width key (1.0 unit).
        //
        // When a prefix dead-key is armed (pendingAccent != null), the tonos
        // key highlights and every vowel keycap that composes with the armed
        // accent relabels to its precomposed form (ά έ ή … / ϊ ϋ / ΐ ΰ) —
        // shift-style feedback so the dead key never feels dead. Labels only:
        // the actions keep the base vowel, and ActionHandler's pendingAccent
        // path does the actual composition, so keycaps and committed text
        // can't drift apart (both go through precomposeAccent).
        val tonosKey = KeySpec(
            action = KeyAction.Character("΄"),
            label = "΄",
            widthUnits = 0.5f,
            popupChars = listOf("΄", " ̈", "΅"),
            highlighted = pendingAccent != null
        )
        val breveKey = KeySpec(
            action = KeyAction.Character("˘"),
            label = "˘",
            widthUnits = 0.5f,
            enabled = breveEnabled
        )
        val spec = LayoutSpec(
            rows = listOf(
                listOf(
                    ch("ε", listOf("ε", "έ")),
                    ch("ρ"),
                    ch("τ"),
                    ch("υ", listOf("υ", "ύ", "ϋ", "ΰ")),
                    ch("θ"),
                    ch("ι", listOf("ι", "ί", "ϊ", "ΐ", "ι-")),
                    ch("ο", listOf("ο", "ό", "ὀ", "ὄ")),
                    ch("π"),
                    tonosKey,
                    breveKey
                ),
                listOf(
                    ch("α", listOf("α", "ά")),
                    ch("σ", listOf("σ", "ς", "σ̆", "σ̆σ̆", "ς̆")),
                    ch("δ"),
                    ch("φ"),
                    ch("γ"),
                    ch("η", listOf("η", "ή")),
                    ch("ξ", listOf("ξ", "ξ̌")),
                    ch("κ"),
                    ch("λ")
                ),
                listOf(
                    KeySpec(KeyAction.Shift, "⇧", widthUnits = 1.5f),
                    ch("ζ", listOf("ζ", "ζ̆")),
                    ch("χ"),
                    ch("ψ", listOf("ψ", "ψ̆")),
                    ch("ω", listOf("ω", "ώ")),
                    ch("β"),
                    ch("ν"),
                    ch("μ"),
                    KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f)
                ),
                listOf(
                    KeySpec(KeyAction.NumericMode, "?123", widthUnits = 1.5f),
                    KeySpec(KeyAction.SwitchLayout, "🔄", widthUnits = 1.25f),
                    KeySpec(KeyAction.Space, "διάστημα", widthUnits = 4.75f),
                    KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
                )
            )
        )
        if (pendingAccent == null) return spec
        return LayoutSpec(
            rows = spec.rows.map { row ->
                row.map { key ->
                    val a = key.action
                    if (a is KeyAction.Character) {
                        val composed = precomposeAccent(pendingAccent, a.text)
                        if (composed != null) key.copy(label = composed) else key
                    } else {
                        key
                    }
                }
            }
        )
    }

    fun latinAlphabetic(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "qwertyuiop".map { ch(it.toString()) },
            "asdfghjkl".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.Shift, "⇧", widthUnits = 1.5f))
                addAll("zxcvbnm".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.NumericMode, "?123", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchLayout, "🔄", widthUnits = 1.25f),
                KeySpec(KeyAction.Space, "space", widthUnits = 4.75f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )

    fun numeric(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "1234567890".map { ch(it.toString()) },
            "-/:·()€&@\"".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.SymbolicMode, "#+=", widthUnits = 1.5f))
                addAll(".,;!’".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.AlphabeticMode, "ABC", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchLayout, "🔄", widthUnits = 1.25f),
                KeySpec(KeyAction.Space, " ", widthUnits = 4.75f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )

    fun symbolic(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "[]{}#%^*+=".map { ch(it.toString()) },
            "_\\?~<>$£¥·".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.NumericMode, "123", widthUnits = 1.5f))
                addAll(".,;!’".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.AlphabeticMode, "ABC", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchLayout, "🔄", widthUnits = 1.25f),
                KeySpec(KeyAction.Space, " ", widthUnits = 4.75f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )
}

/**
 * Return a copy of the layout with every Character key uppercased. Used
 * when single-shift is active. .uppercase() on punctuation, digits, and
 * the accent dead-keys is a no-op, so this transform is safe across all
 * layouts without per-layout exemptions.
 */
fun LayoutSpec.shifted(): LayoutSpec = LayoutSpec(
    rows = rows.map { row ->
        row.map { key ->
            val action = key.action
            if (action is KeyAction.Character) {
                // Uppercase label and action independently: when a prefix
                // dead-key is armed the label is the accented preview (ά)
                // while the action stays the base vowel (α) — both must
                // uppercase without one clobbering the other.
                key.copy(
                    action = KeyAction.Character(action.text.uppercase()),
                    label = key.label.uppercase()
                )
            } else {
                key
            }
        }
    }
)
