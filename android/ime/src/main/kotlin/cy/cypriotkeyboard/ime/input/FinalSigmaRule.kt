package cy.cypriotkeyboard.ime.input

/** Result of applying the final-sigma rule to the current word. */
sealed class SigmaResult {
    object None : SigmaResult()
    /** The trailing [from] should be replaced with [to] (e.g. σ → ς). */
    data class ReplaceTrailing(val from: String, val to: String) : SigmaResult()
    /** The character before the just-typed letter is [from]; demote it to [to]. */
    data class PromoteMedial(val from: String, val to: String) : SigmaResult()
}

/**
 * Mirrors `CypriotKeyboardActionHandler.handleS` (Swift, lines 140-177).
 *
 * Inputs:
 *   wordPreCursor   — current word from start-of-word to cursor (inclusive of the
 *                     just-typed letter).
 *   postCursorEmpty — true iff the cursor is at end-of-word (no chars after).
 *
 * The rule looks at:
 *   last        = wordPreCursor.lastChar
 *   secondLast  = wordPreCursor.takeLast 1 char before that (could be "ς" or "ς̆")
 *
 * If `last` is a letter and `secondLast` is "ς", demote → "σ". Same for "ς̆"/"σ̆".
 * Else if cursor at end-of-word and `last` is "σ" or "σ̆", promote → "ς"/"ς̆".
 * Otherwise no-op.
 *
 * The result is interpreted by the IME's ActionHandler, which performs the
 * actual InputConnection replace.
 */
fun applyFinalSigma(wordPreCursor: String, postCursorEmpty: Boolean): SigmaResult {
    if (wordPreCursor.isEmpty()) return SigmaResult.None

    // Kotlin `String.last` is a UTF-16 Char, NOT a grapheme cluster. The
    // sigma-breve cluster "σ̆" is two Chars: σ + U+0306. Special-case the
    // combining-mark trailing case before the .isLetter() guard, otherwise
    // we'd bail out for "κασ̆" because U+0306 isn't a letter.
    val lastChar = wordPreCursor.last()
    val isCombiningMark = lastChar.code in 0x0300..0x036F
    if (isCombiningMark) {
        if (postCursorEmpty && wordPreCursor.endsWith("σ̆")) {
            return SigmaResult.ReplaceTrailing(from = "σ̆", to = "ς̆")
        }
        // Other combining-mark situations don't trigger the rule. (E.g. typing
        // an accent over a vowel — handled elsewhere by AccentCombiner.)
        return SigmaResult.None
    }

    if (!lastChar.isLetter()) return SigmaResult.None

    // Promote-medial: if the cluster before the just-typed letter is "ς"
    // or "ς̆", demote it back to medial sigma. Check the longer cluster
    // first because endsWith("ς̆") implies endsWith("ς̆"[1]) which is a
    // combining mark, not "ς".
    val before = wordPreCursor.substring(0, wordPreCursor.length - 1)
    if (before.endsWith("ς̆")) {
        return SigmaResult.PromoteMedial(from = "ς̆", to = "σ̆")
    }
    if (before.endsWith("ς")) {
        return SigmaResult.PromoteMedial(from = "ς", to = "σ")
    }

    // End-of-word promotion of plain σ → ς.
    if (postCursorEmpty && lastChar == 'σ') {
        return SigmaResult.ReplaceTrailing(from = "σ", to = "ς")
    }
    return SigmaResult.None
}
