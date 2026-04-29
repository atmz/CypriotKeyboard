# Decision: skip χ ⇄ ξ branching for Greeklish `x`

**Date:** 2026-04-29
**Context:** Task 7 of `2026-04-29-dawg-suggester-quality.md` (after Tasks 1–6 landed at `500696a`).

## Question

Should `DawgAutocompleteSuggestionProvider.altRules` add a `("χ", ["χ", "ξ"])`
branch (analogous to `αφ↔αυ`, `θ↔τη`, `8↔θ`) so that Greeklish input `x`
also tries the ξ interpretation?

## Decision

**Skip.** The current pipeline (greekify, multi-fold lookup, casing-aware
ranking, frequency tiebreak) already handles every legitimate χ↔ξ corpus
case at edit-1, and adding the branch causes net regressions on real
χ-rooted Greeklish input.

## Data

Re-running `dict_generation/eval/run_corpus.py` against every x/ks-containing
input in `greeklish_corpus.txt`:

| Input | Current DAWG | With χ⇄ξ branch | Right answer | Verdict |
|---|---|---|---|---|
| `taxi` | τάχει | τάξη | ταξί | both wrong; branch picks τάξη (freq=35) over ταξί (freq=16); branch does NOT fix it |
| `taxidi` | ταξίδι | ταξίδι | ταξίδι | already correct via edit-1 (`χι→ξι`) |
| `xara` | χαρά | χαρά | χαρά | already correct |
| `xarta` | χάρτα | χάρτα | χάρτα | already correct |
| `xerw` | χαίρω | ξέρω | χαίρω (rejoice) or ξέρω (know) | branch flips to ξέρω; ambiguous intent — user wrote `w`/`ω` ending |
| `ksero` | ξέρω | ξέρω | ξέρω | already correct (Greeklish `ks`→ξ) |
| `kserei` | ξέρει | ξέρει | ξέρει | already correct |
| `Ammoxostos` | Αμμόχωστος | Αμμόχωστος | Αμμόχωστος | already correct |
| `sintagmatarxis` | συνταγματάρχης | συνταγματάρχης | συνταγματάρχης | already correct |
| `xartin` | χαρτίν | χαρτίν | χαρτίν | already correct |
| `xairo` (off-corpus probe) | χαίρω | (no replace) | χαίρω | REGRESSION: branch fails the gate |
| `xeri` (off-corpus probe) | χέρι | ξέρει | χέρι | REGRESSION: branch flips meaning hand→knows |
| `xeira` (off-corpus probe) | χήρα | ξηρά | χήρα/χείρα | REGRESSION: widow → dry |
| `xaira` (off-corpus probe) | χέρα | ξερά | (legitimate χ word) | REGRESSION |

Sentence-level diff: only **two** corpus rows change with the branch (#67
`xerw` and #69 `to taxi kanei 25 evro`); neither is a clear win. #67 swaps
χαίρω→ξέρω (debatable). #69 swaps τάχει→τάξη — both wrong.

## Reasoning

1. **Greek χ and ξ are distinct phonemes** ("ch" vs "ks"). Unlike αφ↔αυ or
   εφ↔ευ — which are the **same** morpheme written two ways depending on
   the following consonant — χ and ξ are never alternative spellings of the
   same word. Branching at every χ in greekify output is phonetically
   unjustified.
2. **The branch fires too broadly.** Greeklish convention strongly maps `x`
   → χ. ξ is normally written as `ks` or `3`. A χ⇄ξ branch promotes the
   ranking of high-frequency ξ words (ξέρω freq=1000, ξέρει freq=259) and
   lets them dominate at d=0/d=1, crowding out the user's intended χ word.
3. **Edit-1 already covers single-x→ξ cases.** `taxidi` → ταξίδι works
   today via a single substitution+insertion (`ταχιδι` → `ταξίδι`). The
   only corpus case that *isn't* solved by edit-1 (`taxi` → ταξί) also
   isn't solved by the branch — `τάξη` outranks `ταξί` on frequency.
4. **`ks` → ξ already lives in greekify.** Users who want ξ have a direct,
   unambiguous spelling (`ks`), and those tokens already round-trip
   correctly. The cases left are real ambiguities the system can't resolve
   without context.

## What would re-open this question

- Telemetry or user reports showing systematic complaints that `x`-typed
  inputs aren't reaching ξ canonicals. Today's corpus doesn't show this
  pattern — every Greeklish `ks` user who wanted ξ is already served, and
  every `x` user is served if they meant χ.
- A way to scope the branch to *positions where Greeklish `x` appeared*
  rather than every greekify-output χ. That would require carrying source
  positions through greekify, which the current pipeline doesn't do.
- A frequency-aware ranking that demotes ξ-words when the input character
  was Latin `x` rather than `ks`. Same source-tracking problem.

## Files touched

This decision doc only. No code change. No test change.
