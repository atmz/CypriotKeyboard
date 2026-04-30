# Decision: add χ ⇄ ξ branching for Greeklish `x` (revised)

**Date:** 2026-04-30 (revised; original SKIP decision dated 2026-04-29)
**Context:** Task 7 of `2026-04-29-dawg-suggester-quality.md` (after Tasks 1–6 landed at `500696a`), revisited after expanding `greeklish_corpus.txt` to 121 rows with explicit χ↔ξ probes.

## Question

Should `DawgAutocompleteSuggestionProvider.altRules` add a `("χ", ["χ", "ξ"])`
branch (analogous to `αφ↔αυ`, `θ↔τη`, `8↔θ`) so that Greeklish input `x`
also tries the ξ interpretation?

## Decision

**Add the branch.** With the expanded corpus driving the analysis, the
measured outcome is net positive: one clear improvement, one ambiguity
flipped toward modern usage, zero regressions on legitimate χ words.

## Why we revised

The original SKIP decision rested on:
- **Hypothetical probes I made up** (`xeri`, `xeira`, `xaira`, `xairo`)
  showing the branch *would* break χ words, without measurable corpus data.
- A phonetic argument that χ and ξ are distinct phonemes, so branching
  is "phonetically unjustified."

Both turned out to be weaker than I thought:

1. **The hypothetical regressions don't materialise in the actual corpus.**
   I added 9 explicit χ-rooted Greeklish inputs (`exo`, `xara`, `xronos`,
   `xilies`, `xoris`, `xreiazomai`, `xairetismata`, `mexri`, `xronia`).
   With the branch on, all 9 still resolve to their χ canonicals — the
   ξ-substituted fold keys mostly have no DAWG payload, so the branch
   produces a no-op alternative and the χ candidate wins on its own merits.

2. **Source-position tracking is implicit, not extra work.** Greekify maps
   `ch` → τσ̆ (not χ) and `kh` → `κη` (split chars). So every χ that
   appears in greekify output came from Latin `x`. Branching at every χ
   when `isGreeklish` is true is therefore equivalent to source-position-
   tracked branching — no extra plumbing needed.

3. **The phonetic argument was the wrong frame.** Modern Greeklish
   convention frequently uses `x` for ξ ("axia", "praxh", "taxi"). The
   ambiguity isn't phonetic — it's that one Latin letter encodes two
   different Greek phonemes depending on the user's spelling habit. The
   branch surfaces both interpretations and lets ranking pick.

## Data

Re-running `dict_generation/eval/run_corpus.py` after adding the branch.
Five rows differed from the no-branch baseline:

| # | Input | Before | After | Verdict |
|---|---|---|---|---|
| 67 | `xerw` | χαίρω | ξέρω | improvement (modern usage favors ξέρω; χαίρω is formal/archaic, used in fixed phrase "χαίρω πολύ") |
| 69 | `to taxi kanei 25 evro` | τάχει | τάξη | neutral (still wrong; ταξί doesn't surface either way — the right fix is ranking, not branching) |
| 79 | `to taxi ekane mpoxa` | τάχει | τάξη | neutral |
| 83 | `arkheia kai axia` | …άδεια | …**αξία** | clear improvement |
| 107 | `8a me pareis ena taxi` | τάχει | τάξη | neutral |

No row regressed. The 9 χ-rooted inputs (rows 86–94, 100, 112) and the
chat shorthand (`xronia polla`, `xairetismata stin oikogeneia`,
`xronia polla agapi mou`) all stayed correct.

## Files touched

- `Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift`
  — added `("χ", ["χ", "ξ"])` and `("Χ", ["Χ", "Ξ"])` to `altRules`.
- `dict_generation/eval/run_corpus.py` — mirrored in `_ALT_RULES`.
- `Cypriot KeyboardTests/DawgIntegrationTests.swift` —
  `testGreekifyAlternativesBranchesOnChiAsXi`.
- `dict_generation/eval/corpus_baseline.md` — regenerated with the five
  rows above.

## Open follow-up

The `taxi → ταξί` case is still unsolved. With the branch, the wrong
answer changed from τάχει to τάξη, but the right answer (ταξί) still
loses on frequency. This is a ranking problem, not a branching problem:
the suggester finds ταξί but it ranks below higher-freq distractors.
A fix here probably needs either (a) a "common short word" boost, or
(b) some morphological prior that recognises -ι endings as more typical
of nouns than -η.
