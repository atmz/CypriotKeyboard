# Cypriot Keyboard — perf/memory tier-b design

**Date:** 2026-04-26
**Author:** Claude (Opus 4.7) on behalf of Alex
**Status:** Approved (user picked tier b in /init brainstorm; authorized autonomous execution overnight)

## Goal

Cut autocomplete latency and reduce per-keystroke allocation churn in the keyboard extension, without replacing Hunspell or trimming the bundled dictionary. Memory savings come as a side effect of cheaper hot-path code; the dominant memory consumer (Hunspell's in-RAM hash) is out of scope for this pass — that's tier (c).

## Non-goals

- Replacing Hunspell with a trie/DAWG (deferred to tier c).
- Shrinking `dict/el_CY.dic` itself (user maintains the cap upstream during dict creation).
- Touching `project.pbxproj` or `*.xcscheme` (the user has unrelated WIP edits there).

## Hot-path inventory

The autocomplete pipeline runs end-to-end on **every keystroke**. The path is:

`KeyboardViewController.performAutocomplete` → `CypriotAutocompleteSuggestionProvider.asyncAutocompleteSuggestions` → `suggestions(for:speller:isFirstWordInSentence:)`.

Inside `suggestions(...)`:
1. `CypriotKeyboardHelper.greekify(text:)` — ~30 chained `replacingOccurrences` allocations.
2. `Hunspell_suggest(...)` — C call; cost grows with word length.
3. Result ranking: `shouldReplace`, `isCommonWord`, `distanceMeasure` (Levenshtein), `countSyllables`.
4. `print(...)` debug logging — fires on every call in release builds today.
5. Suggestion array construction.

Plus, in `CypriotKeyboardActionHandler.handle(_:on:)`, several helpers run on every input action (`triggerSpaceAutocomplete`, `handleS`, `triggerAccent`, `handleSwitch`).

## Changes

### 1. `commonWords: [String]` → `Set<String>`

**File:** `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`.

`isCommonWord(word:)` currently does an O(n) linear scan over ~550 entries on every Greeklish suggestion. Trivial fix: declare as `static let commonWords: Set<String>`. Swift's set-literal syntax accepts the same array literal.

Expected gain: small but per-keystroke; mostly an allocation/code-cleanliness win.

### 2. `String.levenshtein(_:)` rewrite

**File:** `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`.

Current implementation:
- Allocates a full `[[Int]]` matrix of size `(n+1) × (m+1)`.
- Inner loop uses `self[i-1]`, where the custom `subscript(Int)` walks `String.Index` via `index(self.startIndex, offsetBy:)` — that's O(i) per access, making the algorithm effectively O(n²·m) instead of O(n·m).

New implementation:
- `let a = Array(self); let b = Array(other)` once at top — O(n+m) cached `[Character]`.
- Two `[Int]` rows (`prev`, `curr`), `swap` between iterations.
- Custom `subscript(Int)` extension on String stays put for any other callers, but `levenshtein` no longer uses it.

### 3. `greekify(text:)` single-pass scanner

**File:** `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`.

Replace the chained `replacingOccurrences` block (~30 calls × ~N character string copies) with one pass over `[Character]`, longest-match-first against a static digraph table.

**Behavior preservation contract:** for every input string, the new implementation must return the same `String` as the old one. Longest-match-first priority:

- 3-char: `ngk`/`NGK` → `γκ`; `ths`/`Ths`/`THS` → `τησ`/`Τησ`/`Τησ`.
- 2-char: `sh`/`Sh`/`SH`, `ch`/`Ch`/`CH`, `ps`/`Ps`/`PS`, `ks`/`Ks`/`KS`, `Th`/`TH`/`th`, `yi`/`Yi`/`YI`, `ng`/`NG`.
- 1-char fallback: every other letter goes through the single-character map (including `b` → `μπ`, `B` → `Μπ`, `j` → `τζ̆`, `J` → `Τζ̆`, `c`/`C` → `κ`/`Κ`, `y`/`Y` → `υ`/`Υ`, `h`/`H` → `η`/`Η`, `3` → `ξ`).
- Non-mapped characters pass through unchanged.

**Risk mitigation:** unit tests run a corpus through both implementations and assert byte-equivalence before the old impl is removed. The old implementation lives on briefly as `greekifyLegacy` during the rollout, then deletes once tests pass.

### 4. DEBUG-gate `print(...)` calls in hot path

**Files:**
- `Cypriot  Custom Keyboard/CypriotAutocompleteSuggestionProvider.swift` (5+ prints per call)
- `Cypriot  Custom Keyboard/CypriotKeyboardActionHandler.swift` (per repo convention, intentional debug logging)

Wrap each in `#if DEBUG ... #endif`. Release builds (App Store / TestFlight) will compile them out, eliminating the per-keystroke `String` interpolation cost. Debug builds keep them for Console.app inspection per existing convention noted in CLAUDE.md.

### 5. Common-word fast path

**File:** `Cypriot  Custom Keyboard/CypriotAutocompleteSuggestionProvider.swift`.

If the user's current word is pure-Greek (`text == greekText`) and `text.lowercased()` is in `commonWords`, the word is by definition correctly spelled — return early with `[suggestion(text, verbatim: true)]` and skip Hunspell entirely.

**Why this is safe:** `commonWords` is hand-curated; every entry is by definition a valid, common Cypriot Greek word. There's no risk of suppressing a useful suggestion for a misspelling that *happens* to match — the typed text is identical to the dictionary entry, modulo case.

**Why it pays off:** Hunspell's `suggest()` cost dominates the per-keystroke pipeline. The bar fills with the verbatim word + (potentially) other suggestions today. For correctly-typed common words ("και", "που", "μου", etc.), we don't need any of those alternates — the user is going to keep this word. Skipping Hunspell shaves the largest single cost off the most-frequent keystroke pattern.

### 6. Debounce `performAutocomplete`

**File:** `Cypriot  Custom Keyboard/KeyboardViewController.swift`.

Today: every keystroke immediately dispatches Hunspell on a global queue. A user typing 5 chars/sec generates 5 Hunspell calls/sec, and `autocompleteCount` only drops out-of-order *results* — the work itself still happens, fighting for cores.

New: maintain a `pendingAutocomplete: DispatchWorkItem?`. On each call:
1. Cancel the pending item.
2. Schedule a new one on the main queue with ~40 ms delay.
3. The work item, when it fires, executes the existing `suggestions(...)` flow.

Result: during fast typing, only the *last* keystroke per ~40 ms window actually runs Hunspell. The existing `autocompleteCount` lock token stays as a defense-in-depth against races between the main-queue debounce and the global-queue Hunspell call.

40 ms feels imperceptible (well under the ~100 ms threshold for "instant"). If field testing shows it feels laggy, it's a one-line tweak.

## Tests

All new test methods are added to the existing `Cypriot_KeyboardTests` class in `Cypriot KeyboardTests/Cypriot_KeyboardTests.swift`. No new files, no pbxproj edits — the file is already in the test target's Sources phase.

Coverage:

- `greekify`: ≥30 inputs covering each digraph rule, 1-char fallback, mixed input, empty string, all-uppercase, capitalized first letter, numeric `3`. Plus a **golden-master fuzz test**: a deterministic random-input loop that compares new `greekify` output against `greekifyLegacy` output, asserting equality. Runs ≥1000 iterations.
- `levenshtein`: classic cases (`"" / "abc"`, `"kitten" / "sitting" → 3`, identical strings → 0, single insertion, single deletion, transposition) plus a property-style symmetry check on random pairs.
- `isCommonWord` / `commonWords`: spot-check known members and known non-members.
- `countSyllables`: 0-syllable bare punctuation, 1-syllable monosyllable, 2-syllable example, accented vowels, mixed-case.
- `getOverrideMatch`: known overrides (`me` → `με`, `gia` → `για`), unknown input → `nil`.
- `shouldAttemptAutocomplete`: pure-numeric → false, pure-letter → true, letter-with-trailing-punctuation → true.

Out of test scope (would need integration / UI tests): debounce timing, common-word fast path. These are verified manually + by codepath inspection.

## Rollout

One feature branch's worth of edits, all in the keyboard extension target's Swift sources. Two commits:

1. **Now (checkpoint):** CLAUDE.md + this design doc only. Lets the user revert cleanly if anything below goes sideways overnight.
2. **End of work (when complete):** all source changes + new tests, with a passing `xcodebuild test` run logged in the commit message.

The user's existing `*.xcscheme` and `Breakpoints_v2.xcbkptlist` modifications are not touched — `git add` uses explicit paths.

## What this does *not* solve

- Hunspell's resident-memory hash. That's tier (c).
- Long-word memory blowups during `Hunspell_suggest`. The current 10-letter cap stays meaningful.
