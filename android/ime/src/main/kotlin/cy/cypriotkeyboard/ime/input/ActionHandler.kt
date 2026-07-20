package cy.cypriotkeyboard.ime.input

import android.view.inputmethod.InputConnection
import cy.cypriotkeyboard.ime.layout.KeyAction
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.suggest.Suggestion

/** Hooks the action handler invokes on the IME service. */
interface KeyboardController {
    fun ic(): InputConnection?
    fun toggleLayoutGreekLatin()
    fun switchToNextIme()
    fun setMode(mode: KeyboardMode)
    fun requestSuggestions(currentWord: String)
    /** Toggle single-shift state. Letter keys uppercase for ONE keystroke,
     *  then auto-reset back to lowercase. */
    fun toggleShift()
    /** Called by the action handler after a Character-producing key fires
     *  so the controller can clear single-shift state. */
    fun consumeShift()
    /** Re-render the layout from current state (breve context, armed prefix
     *  accent) without touching the suggestion pipeline. */
    fun refreshLayout()
}

enum class KeyboardMode { ALPHABETIC, NUMERIC, SYMBOLIC }

/**
 * Mirrors `CypriotKeyboardActionHandler.swift`. Sequenced:
 *   1) commit text
 *   2) trigger space-replace if applicable
 *   3) final-sigma rule
 *   4) accent combiner
 *   5) request suggestions
 *
 * Holds [currentGuess] and [lastAction] state mirroring the iOS handler.
 *
 * Deviation from the plan: the accent keys (΄ ˘ ¨ ΅) come through as
 * `KeyAction.Character(...)` per `Layouts.greekAlphabetic()`. We intercept
 * those inside [handleCharacter] and re-route to [handleAccentKey] BEFORE
 * committing the literal accent glyph. This matches the iOS code path
 * (`triggerAccent` deletes the just-committed accent char then re-emits a
 * combining diacritic) but skips the commit-then-delete dance because we
 * have full control before commitText runs.
 */
class ActionHandler(private val controller: KeyboardController) {

    /** Top suggestion with willReplace=true, if any. Mutated by IME on pipeline ticks. */
    @Volatile var currentGuess: Suggestion? = null

    /** Last user action — used by space-replace to detect "user just hit backspace". */
    @Volatile var lastAction: LastAction? = null

    /**
     * Armed prefix dead-key, set when the user taps tonos / dialytika /
     * tonos+dialytika and waiting for the vowel to compose with. Cleared on
     * the next character (whether or not the composition succeeds) and on
     * any non-character action.
     */
    @Volatile var pendingAccent: PrefixAccent? = null

    fun handle(spec: KeySpec) {
        val ic = controller.ic() ?: return
        when (val a = spec.action) {
            is KeyAction.Character -> handleCharacter(ic, a.text)
            // (KeyAction.Accent was removed — accent keys come through Character
            //  with the dead-key text, intercepted by ACCENT_DEAD_KEYS below.)
            KeyAction.Space -> {
                pendingAccent = null
                handleSpaceLike(ic, " ")
            }
            KeyAction.Return -> {
                pendingAccent = null
                handleSpaceLike(ic, "\n")
            }
            KeyAction.Backspace -> {
                // If a prefix dead-key is armed, backspace just disarms it
                // (matches Windows/Android dead-key UX) — no buffer change.
                if (pendingAccent != null) {
                    pendingAccent = null
                    controller.refreshLayout()
                    return
                }
                ic.deleteSurroundingText(1, 0)
                lastAction = LastAction.Backspace
                controller.requestSuggestions(currentWord(ic))
            }
            KeyAction.Shift -> {
                controller.toggleShift()
                lastAction = LastAction.NonInput
            }
            KeyAction.SwitchLayout -> {
                controller.toggleLayoutGreekLatin()
                lastAction = LastAction.NonInput
            }
            KeyAction.SwitchIme -> {
                controller.switchToNextIme()
                lastAction = LastAction.NonInput
            }
            KeyAction.NumericMode -> {
                controller.setMode(KeyboardMode.NUMERIC)
                lastAction = LastAction.NonInput
            }
            KeyAction.SymbolicMode -> {
                controller.setMode(KeyboardMode.SYMBOLIC)
                lastAction = LastAction.NonInput
            }
            KeyAction.AlphabeticMode -> {
                controller.setMode(KeyboardMode.ALPHABETIC)
                lastAction = LastAction.NonInput
            }
        }
    }

    private fun handleCharacter(ic: InputConnection, text: String) {
        // 1. Accent dead-keys must be intercepted BEFORE the pending-accent
        //    consumption below: tapping an accent key while one is armed is a
        //    toggle/re-arm, and handleAccentKey needs to see the still-armed
        //    state to decide which. (Consuming first would clear the state and
        //    make every second tap silently re-arm — the key could never
        //    disarm.)
        if (text in ACCENT_DEAD_KEYS) {
            handleAccentKey(ic, text)
            return
        }

        // 2. Armed prefix dead-key (tonos/dialytika)? Try to compose with the
        //    typed character and emit a single precomposed glyph. If the
        //    combination has no Unicode precomposed form (e.g. tonos on a
        //    consonant), fall through and commit the char unchanged. Either
        //    way, disarm.
        val pending = pendingAccent
        if (pending != null) {
            pendingAccent = null
            val precomposed = precomposeAccent(pending, text)
            if (precomposed != null) {
                ic.commitText(precomposed, 1)
                applyFinalSigmaRule(ic)
                lastAction = LastAction.Character
                controller.consumeShift()
                controller.requestSuggestions(currentWord(ic))
                return
            }
            // No precomposition; fall through to normal handling for `text`.
        }

        val isPunctOrTrigger = text in PUNCT_TRIGGERS
        if (isPunctOrTrigger) {
            handleSpaceLike(ic, text)
            return
        }
        // Standard insert.
        ic.commitText(text, 1)
        // Final-sigma rule on the now-current word.
        applyFinalSigmaRule(ic)
        lastAction = LastAction.Character
        // Single-shift consumes itself after the letter that follows it.
        controller.consumeShift()
        controller.requestSuggestions(currentWord(ic))
    }

    private fun handleSpaceLike(ic: InputConnection, trigger: String) {
        // Mirror iOS `triggerSpaceAutocomplete`: if a willReplace guess is queued
        // and the previous action was NOT a backspace, replace the typed word
        // with the suggestion before inserting the trigger character.
        val guess = currentGuess
        if (guess != null && guess.willReplace && lastAction != LastAction.Backspace) {
            replaceCurrentWord(ic, guess.text)
        }
        ic.commitText(trigger, 1)
        currentGuess = null
        lastAction = LastAction.Character
        controller.consumeShift()
        controller.requestSuggestions(currentWord(ic))
    }

    private fun applyFinalSigmaRule(ic: InputConnection) {
        val word = currentWord(ic)
        val postEmpty = textAfterCursor(ic).isEmpty()
        when (val r = applyFinalSigma(word, postCursorEmpty = postEmpty)) {
            SigmaResult.None -> Unit
            is SigmaResult.PromoteMedial -> {
                // The "ς" or "ς̆" is at position word.length - 1 - r.from.length
                // (i.e. just-typed letter is at the very end; the fragment to demote
                // sits immediately before it).
                // Delete: typed letter + "ς"/"ς̆", reinsert: "σ"/"σ̆" + typed letter.
                val typedLast = word.last().toString()
                val deleteCount = 1 + r.from.length
                ic.deleteSurroundingText(deleteCount, 0)
                ic.commitText(r.to + typedLast, 1)
            }
            is SigmaResult.ReplaceTrailing -> {
                ic.deleteSurroundingText(r.from.length, 0)
                ic.commitText(r.to, 1)
            }
        }
    }

    private fun handleAccentKey(ic: InputConnection, accentKey: String) {
        // Tonos / dialytika / tonos-dialytika are PREFIX dead keys: arm
        // state, commit nothing. The next handleCharacter call composes
        // them with the typed vowel into a single precomposed glyph.
        // Breve stays POST-FIX (consonant first, then breve, emits a
        // combining mark) — that's how Cypriots type it on Windows too.
        // Tapping the same armed accent again disarms it (toggle); tapping a
        // different one re-arms with the new accent. Both re-render the
        // keycaps so the vowel previews track the armed state.
        val prefix = when (accentKey) {
            "΄" -> PrefixAccent.TONOS
            " ̈" -> PrefixAccent.DIALYTIKA
            "΅" -> PrefixAccent.TONOS_DIALYTIKA
            else -> null
        }
        if (prefix != null) {
            pendingAccent = if (pendingAccent == prefix) null else prefix
            controller.refreshLayout()
            return
        }

        // Post-fix path (breve only, here): read the previous cluster and
        // emit the combining mark if it's a valid base for this accent.
        val before = textBeforeCursor(ic, 2)
        val lastChar = if (before.isEmpty()) "" else takeLastCluster(before)
        when (val r = applyAccent(accentKey, lastChar)) {
            AccentResult.Reject -> { /* drop the dead-key tap */ }
            is AccentResult.Combine -> ic.commitText(r.combining, 1)
        }
        lastAction = LastAction.Character
        controller.requestSuggestions(currentWord(ic))
    }

    /** Replace the current word (whatever cluster precedes the cursor that's letters). */
    private fun replaceCurrentWord(ic: InputConnection, replacement: String) {
        val word = currentWord(ic)
        if (word.isEmpty()) {
            ic.commitText(replacement, 1)
            return
        }
        ic.deleteSurroundingText(word.length, 0)
        ic.commitText(replacement, 1)
    }

    private fun currentWord(ic: InputConnection): String {
        val before = textBeforeCursor(ic, 64) // 64 chars is plenty for a word.
        return WORD_TAIL.find(before)?.value ?: ""
    }

    private fun textBeforeCursor(ic: InputConnection, n: Int): String =
        ic.getTextBeforeCursor(n, 0)?.toString() ?: ""

    private fun textAfterCursor(ic: InputConnection): String =
        ic.getTextAfterCursor(1, 0)?.toString() ?: ""

    private fun takeLastCluster(s: String): String {
        // "σ̆" and "ς̆" are 2-codepoint clusters (σ + U+0306 etc.). We treat
        // any combining mark as part of the cluster.
        if (s.isEmpty()) return ""
        val last = s[s.length - 1]
        if (s.length >= 2 && last.code in 0x0300..0x036F) {
            return s.substring(s.length - 2)
        }
        return last.toString()
    }

    enum class LastAction { Character, Backspace, NonInput }

    companion object {
        // Punctuation that triggers the same "replace-and-insert" behavior as space.
        // Mirrors iOS `triggerSpaceAutocomplete` punctuation set; "·" is U+00B7
        // (Greek middle-dot). Space/return are separate KeyAction branches.
        private val PUNCT_TRIGGERS = setOf(".", ",", ";", ":", "·", "!", "?", "]", ")", "\"")
        private val WORD_TAIL = Regex("[\\p{L}\\p{M}]+$")

        // Accent dead-keys that route into handleAccentKey instead of commitText.
        // Keys must match those produced by Layouts.greekAlphabetic() exactly
        // (note the iOS dialytika spelling is " ̈" — leading space + U+0308).
        private val ACCENT_DEAD_KEYS = setOf("΄", "˘", " ̈", "΅")
    }
}
