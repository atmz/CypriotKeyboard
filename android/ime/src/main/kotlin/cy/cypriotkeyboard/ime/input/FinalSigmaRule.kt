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
    val last = wordPreCursor.last()
    if (!last.isLetter()) return SigmaResult.None

    // Promote-medial: look at the substring before the last char and inspect
    // whether IT ended in "ς" or "ς̆".
    val before = wordPreCursor.substring(0, wordPreCursor.length - 1)
    if (before.endsWith("ς̆")) {
        return SigmaResult.PromoteMedial(from = "ς̆", to = "σ̆")
    }
    if (before.endsWith("ς")) {
        return SigmaResult.PromoteMedial(from = "ς", to = "σ")
    }

    // End-of-word promotion: only fires when cursor is truly at end-of-word.
    if (postCursorEmpty) {
        // Check σ̆ (compound) before plain σ — longest match wins.
        if (wordPreCursor.endsWith("σ̆")) {
            return SigmaResult.ReplaceTrailing(from = "σ̆", to = "ς̆")
        }
        if (last == 'σ') {
            return SigmaResult.ReplaceTrailing(from = "σ", to = "ς")
        }
    }
    return SigmaResult.None
}
