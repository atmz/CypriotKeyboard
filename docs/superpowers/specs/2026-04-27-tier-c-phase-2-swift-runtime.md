# Tier-c Phase 2 — Swift runtime, Damerau-L suggester, opt-in setting

**Date:** 2026-04-27
**Author:** Claude (Opus 4.7) on behalf of Alex
**Status:** Draft — design choices baked in per [conversation 2026-04-27 design Q's]; awaiting user review.
**Predecessors:**
- [tier-c design (rev 2)](./2026-04-27-keyboard-perf-tier-c-design.md)
- [Phase 1 plan](../plans/2026-04-27-tier-c-phase-1-build-pipeline.md)
- [Phase 1.5 spec](./2026-04-27-tier-c-phase-1.5-eval-harness.md)

## Goal

Implement the Swift-side runtime for tier-c. After this phase, the keyboard extension can switch between today's Hunspell suggester and a new DAWG-based suggester via a `UserDefaults` flag. The new path:

1. Loads the bundled `dict/el_CY.dawg` artifact (47 MB baseline; smaller variants once Phase 1.5's optimization decision flips).
2. Folds user input via the same `phonetic_fold.json` rules the Python build pipeline uses.
3. Walks the DAWG with a **Damerau-Levenshtein automaton** at edit-budget 1 to find candidate fold keys.
4. Returns ranked canonical forms from each candidate fold key's payload.

The flag defaults OFF for the first ship. Hunspell remains the default for ≥1 release while we gather field reports.

## Non-goals

- The full UI rollout (Phase B in the rollout plan — long-press on `🔄` to surface the toggle). Phase 2 ships **Phase A only**: hidden/debug-only toggle. Phase B is a follow-up after field stability.
- Removing Hunspell. Hunspell stays compiled and loadable; only one engine loads at a time per the memory plan below.
- Edit-budget > 1 in the suggester. Reserved for a Phase 2.x follow-up if recall numbers warrant it.
- Re-running the Phase 1.5 eval. That happens after Phase 2 ships, with the new Levenshtein-automaton results as a new column.

## Design decisions (locked per discussion)

| # | Question | Choice | Rationale |
|---|---|---|---|
| 1 | Edit-distance algorithm | **Damerau-Levenshtein, budget=1** | Closes the dominant typo class plain Levenshtein misses (transpositions). +30% impl effort but Phase 1.5 vowel-swap recall (54%) needs this to climb meaningfully. |
| 2 | UI rollout depth | **Phase A only this iteration** | Hidden/debug-only toggle. Smaller surface, faster ship, less to test. Phase B (long-press on `🔄`) lands after field reports validate Phase A. |
| 3 | Engine flag dispatch | **Read once at `viewDidLoad`** | Mirrors existing `isLatinKeyboard` pattern. Live-flipping isn't a real user need. Toggle takes effect on next keyboard open. |
| 4 | Suggestion-bar layout | **Unchanged** | Slot 1 stays verbatim user input; slot 2 stays the autocorrect candidate. Phase 2 replaces *only* slot 2's candidate-generation, not the bar layout. |
| 5 | Cross-language parity | **Add a Swift-side parity test** | Run a corpus of inputs through both the Python `_greekify_python` and the Swift `greekify`, assert byte-identical output. Phase 1.5 caught two real bugs via similar parity checks; expect this to catch fold-rule drift. |
| 6 | Memory budget | **Load only the chosen engine** | iOS keyboard-extension memory budget is tight (~30–60 MB historically). Loading both Hunspell (~50 MB hash) AND the DAWG (mmap'd 47 MB) on the same launch would blow it. Static engine selection at `viewDidLoad` lets us load only one. |

## Architecture

### Engine dispatch

`KeyboardViewController.viewDidLoad` reads the flag once:

```swift
let useDAWG = UserDefaults.standard.bool(forKey: "useDAWGSuggester")  // default false
```

Then constructs ONE of two `AutocompleteSuggestionProvider` implementations:

- `false` (current default) → existing `CypriotAutocompleteSuggestionProvider` (Hunspell).
- `true` → new `DawgAutocompleteSuggestionProvider`.

Both conform to `KeyboardKit.AutocompleteSuggestionProvider`; the rest of the keyboard plumbing is unchanged. **Hunspell isn't initialized when `useDAWG == true`**; the DAWG path doesn't link Hunspell out of the binary, just doesn't construct an instance. This keeps memory usage comparable to today regardless of flag.

### Swift module layout

```
Cypriot  Custom Keyboard/
├── DAWG/                          # NEW directory, all DAWG runtime code
│   ├── DawgReader.swift           # mmap + parse v1 binary format
│   ├── DawgNode.swift             # in-memory node representation if needed
│   ├── PhoneticFolder.swift       # loads phonetic_fold.json, applies rules
│   ├── DamerauLevenshteinSuggester.swift  # the automaton walk
│   └── DawgAutocompleteSuggestionProvider.swift  # KeyboardKit integration
└── (existing files unchanged except for KeyboardViewController.swift)
```

Tests live in the existing `Cypriot KeyboardTests/` target alongside the helper tests already there. New file: `Cypriot KeyboardTests/DAWGTests.swift`.

### Runtime flow

```
keystroke
   │
   ▼
KeyboardViewController.performAutocomplete()  (debounced 40ms, unchanged from tier-b)
   │
   ▼
[engine dispatch via the provider chosen at viewDidLoad]
   │
   ├── Hunspell path (default): existing, unchanged
   │
   └── DAWG path:
          ├─ greekify(text)                   (existing logic, unchanged)
          ├─ phoneticFold.fold(greekifiedText)
          ├─ DAWG: exact match on folded key
          │       → if hit: return canonical forms for that key, ranked by frequency
          │       → if miss: continue to step below
          ├─ DAWG: Damerau-Levenshtein automaton walk, budget=1
          │       → enumerates fold keys within edit-distance 1 of input fold
          │       → for each, return its canonical forms
          │       → merge across keys, rank by (edit-distance, frequency)
          └─ Pack into AutocompleteSuggestion[] (slot 1 verbatim, slot 2 willReplace, etc.)
```

The slot-1-verbatim and slot-2-willReplace contract from the existing autocomplete pipeline is preserved exactly. The `additionalInfo["willReplace"]` mechanism (used by the action handler's `triggerSpaceAutocomplete`) keeps working.

### DAWG format reader

The format spec is locked at `dict_generation/DAWG_FORMAT.md`:

- 32-byte header: magic `"DAWG"`, version 1, reserved 0, node_count, payload_count, string_table_count, three section offsets.
- Node section: variable-length records `(edge_count: u16, terminal_payload_idx: u32, edges...)` where each edge is `(char_codepoint: u32, target_node_idx: u32)`.
- Payload section: variable-length records `(canonical_form_count: u16, records...)` where each is `(string_idx: u32, freq: u32)`.
- String table: variable-length UTF-8 strings prefixed by `length: u16`.
- Root node = last node (highest index).
- All multi-byte ints little-endian.

The Swift reader **mmap's** the file, then maintains pre-computed offset tables (one for nodes, one for payloads, one for strings) so all lookups are O(1) jumps into the mapped region. No copy from `Bundle.main` to NSData; we rely on the OS to page the file in on demand. For the 47 MB baseline, resident memory grows as the user types more diverse inputs and pages get touched; in practice it tops out well below the file size.

```swift
final class DawgReader {
    let data: Data  // backed by mmap(2)
    private let nodeOffsets: [UInt32]
    private let payloadOffsets: [UInt32]
    private let stringOffsets: [UInt32]

    init(url: URL) throws { /* mmap + parse header + index sections */ }

    func payloadForKey(_ key: String) -> Int? { /* walk from root */ }
    func canonicalForms(payloadIdx: Int) -> [(String, UInt32)] { /* parse payload */ }

    /// Used by the Damerau-Levenshtein automaton.
    func edgesAt(nodeIdx: Int) -> EdgeIterator { /* parse the node's edges */ }
    func terminalPayload(at nodeIdx: Int) -> Int? { /* nil if 0xFFFFFFFF */ }
    var rootNodeIdx: Int { nodeCount - 1 }
}
```

### Phonetic folder

```swift
final class PhoneticFolder {
    private let rules: [(source: String, dest: String)]
    private let maxSourceLen: Int

    init(jsonData: Data) throws { /* parse phonetic_fold.json, sort longest-first */ }

    func fold(_ text: String) -> String { /* longest-match scanner over chars */ }

    static func loadDefault() throws -> PhoneticFolder {
        guard let url = Bundle.main.url(forResource: "phonetic_fold", withExtension: "json") else {
            throw FolderError.missingResource
        }
        return try PhoneticFolder(jsonData: Data(contentsOf: url))
    }
}
```

Algorithm is the same longest-match-first scanner as the Python `PhoneticFolder` from Phase 1. The cross-language parity test (decision #5) verifies these stay byte-identical.

### Damerau-Levenshtein automaton suggester

The classic Levenshtein automaton (Schulz & Mihov 2002) walks a deterministic finite automaton in lockstep with a trie/DAWG, accepting any path whose edit-distance from the input is ≤ k. We extend the standard automaton with adjacent-transposition handling — Damerau-Levenshtein.

Implementation reference: the basic idea is to track, at each step of the DAWG walk, the set of possible "edit states" the input could be in. For budget=1, the state is a small triple `(input_position, edits_used, last_char_for_transposition)` — the universe is bounded.

```swift
final class DamerauLevenshteinSuggester {
    let reader: DawgReader
    let maxEditDistance: Int = 1

    init(reader: DawgReader) {
        self.reader = reader
    }

    /// Returns up to `limit` ranked candidates within Damerau-Levenshtein
    /// distance ≤ maxEditDistance of `key` (in the folded keyspace).
    func suggest(forKey key: String, limit: Int = 5) -> [Suggestion] {
        // … walk reader.edgesAt(rootNodeIdx) recursively, tracking edit state,
        // accumulate terminal payloads at each accepting state, return ranked
    }
}

struct Suggestion {
    let canonical: String
    let frequency: UInt32
    let editDistance: Int
}
```

Ranking: primary key is `editDistance` ascending, secondary key is `-frequency` (so within the same edit class, common forms come first). Phase 2 plan task: pin this ranking in tests.

### Resource bundling

`dict/el_CY.dawg` and `dict_generation/phonetic_fold.json` need to be added to the **extension target's** Resources build phase (and possibly the app target, though the app doesn't use them — extension is what matters).

This is the most fragile part of Phase 2: pbxproj surgery for two new resource files plus 5 new Swift sources (added to both the app target and the extension target, per the existing dual-compilation convention from Phase 1's CLAUDE.md).

The plan task for this is explicit and step-by-step. Tested in the worktree before merging.

## Test strategy

### Unit tests (Swift, in `Cypriot KeyboardTests/`)

1. **DawgReader round-trip**: build a tiny DAWG via the Python serializer with known fixture words, ship as a test resource, verify Swift reader's `payloadForKey` returns the expected canonicals.
2. **PhoneticFolder rules**: a corpus of ~30 inputs with expected fold output; mirror the cases from the Phase 1 `test_phonetic_fold.py`.
3. **PhoneticFolder cross-language parity**: read the same `phonetic_fold.json` resource Python uses, run a fixed list of inputs through both the Python and Swift implementations, assert identical output. Implementation: ship a `phonetic_fold_corpus.json` with `[(input, expected_output), …]` pre-generated by the Python side; the Swift test asserts each pair.
4. **DamerauLevenshteinSuggester correctness**: a fixture DAWG with 5–10 known words, exercise:
   - Exact match (edit distance 0)
   - Single substitution
   - Single insertion
   - Single deletion
   - **Single adjacent transposition** (the load-bearing Damerau test)
   - Edit distance > 1 returns no result (budget=1 is honored)
5. **Greekify cross-language parity**: ship a `greekify_corpus.json` (input/output pairs from `_greekify_python`), assert Swift `CypriotKeyboardHelper.greekify` matches every pair. This catches drift between the two greekify implementations.
6. **DawgAutocompleteSuggestionProvider end-to-end**: instantiate against `dict/el_CY.dawg`, type "καλιμερα", assert "καλημέρα" is in the returned suggestions with `willReplace == true`.

### Integration tests

7. **Engine dispatch**: with `useDAWGSuggester = true`, verify `KeyboardViewController` constructs a `DawgAutocompleteSuggestionProvider`. With `false`, verify it constructs the existing Hunspell one. Verify Hunspell isn't loaded when `useDAWG == true` (heap-allocation test).

### Manual verification (recorded in commit messages)

8. Build for an iOS Simulator, type "καλιμερα" with the DAWG flag enabled, screenshot the suggestion bar showing "καλημέρα" highlighted.
9. Same input with the flag disabled, screenshot the existing Hunspell behavior. Compare.

## Implementation order

Per the rollout-phase taxonomy:

| Plan task | Component | Depends on |
|---|---|---|
| 1 | Test fixture: tiny DAWG + greekify-parity corpus + fold-parity corpus, generated by Python helper | — |
| 2 | `DawgReader.swift` + tests (unit test #1) | Task 1 |
| 3 | `PhoneticFolder.swift` + parity tests (unit tests #2, #3) | Task 1, 2 |
| 4 | `DamerauLevenshteinSuggester.swift` + tests (unit test #4) | Tasks 1–3 |
| 5 | `DawgAutocompleteSuggestionProvider.swift` + integration test (unit test #6) | Tasks 1–4 |
| 6 | Greekify parity test (unit test #5) | Task 1 |
| 7 | `KeyboardViewController.swift` engine dispatch (integration test #7) | Tasks 1–5 |
| 8 | pbxproj surgery: add resources + Swift sources to both targets | Tasks 1–7 |
| 9 | Smoke build for iOS Simulator + manual verification (#8, #9) | Task 8 |
| 10 | Phase A toggle UI: debug-only button in `ContentView.swift` | Task 7 (orthogonal) |
| 11 | Final commit: regenerate `dict/el_CY.dawg` from main per-Phase-1.5 decision (currently 47 MB baseline; if revisited then retrigger) | All |

## Memory and size estimates

| Component | Size on disk | Resident at runtime |
|---|---|---|
| Hunspell `.cxx` compiled into binary | ~1 MB | n/a |
| `dict/el_CY.{dic,aff}` resources | ~16 MB | ~50 MB (when Hunspell init'd) |
| `dict/el_CY.dawg` resource | ~47 MB (baseline) | mmap'd, paged-in subset typically ~10–20 MB |
| `phonetic_fold.json` resource | ~2 KB | ~2 KB |
| Swift runtime code | ~1 MB | negligible |

**Net runtime memory:** with `useDAWG == true`, expect ~10–20 MB resident from the DAWG (mmap, paged-in only). With `useDAWG == false`, today's ~50 MB Hunspell hash. **The DAWG path is potentially 3–5× lighter on RAM** even at the 47 MB baseline file size, which is a nice surprise — mmap means we don't pay for unused pages.

## Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| pbxproj surgery breaks the build | high | Make the changes in small commits; verify each with `xcodebuild` in the worktree before moving on. The dual-target source convention from Phase 1 (CLAUDE.md notes new Swift files need to be added to BOTH `Cypriot Keyboard` and `Cypriot  Custom Keyboard` Sources phases) applies. |
| DAWG mmap fails in the keyboard-extension sandbox | medium | Verify on simulator early; the extension can read its own bundle resources without open access. If mmap is restricted, fall back to `Data(contentsOf:)` and pay the memory cost. |
| Damerau-Levenshtein automaton has off-by-one bugs | medium | Unit test #4 has explicit transposition cases. Reference: well-trodden algorithm; lots of prior art. |
| `phonetic_fold.json` Swift loader drifts from Python | medium | Cross-language parity test (#3) catches this on every Swift test run. |
| Greekify Swift port drifts from Python `_greekify_python` | medium | Cross-language parity test (#5). The existing Swift `greekify` is the reference; Python is the port. |
| User installs Phase 2 with stale UserDefaults | low | Fresh installs default to `false` (Hunspell). Existing users from Phase 1 don't have the key set; `bool(forKey:)` returns false. No migration needed. |
| Toggle UI is too hidden, no testers find it | low | Phase A is intentionally hidden for the first ship. Document the path in CLAUDE.md so the user can find it; users opt in at a later release via Phase B. |

## Open questions

1. **Toggle UI implementation in ContentView.** The container app has minimal UI today (installation instructions). Where does the debug-only toggle live? Options: (a) always-visible button at the bottom of `ContentView` labeled "Use DAWG suggester (experimental)"; (b) hidden behind a debug long-press on the title; (c) `#if DEBUG` only, only visible in dev builds. Recommendation: (c) for the initial Phase 2 ship — testers run dev builds anyway, end-users don't see it.

2. **DAWG resource — single-target or both?** Today's resources (`el_CY.dic`/`aff`) are in both the app and extension targets. The DAWG is only used by the extension; bundling in the app target is wasted disk. Recommendation: extension only. Saves ~47 MB of app-bundle bloat.

3. **Edit-distance ranking ties.** When two candidates have the same edit distance from the input, frequency wins. But what about edit-distance-0 (exact fold match) vs edit-distance-1 (close match)? Current plan: edit-distance-0 always ranks above edit-distance-1. So if "και" is exact-match in the DAWG and "καί" is edit-distance-1, "και" wins.

4. **Is the existing tier-b debounce (40ms) still right for the DAWG path?** Levenshtein-automaton walks are fast (microseconds), faster than Hunspell's heuristic suggester. We could potentially drop the debounce. **Recommendation: keep 40ms unchanged.** Even if the engine is fast, debouncing prevents flicker as the user types and reduces work on slower devices. Re-evaluate if telemetry shows lag.

## Estimated scope

- Test fixtures + parity corpora generation: 1 day
- DawgReader: 1.5 days
- PhoneticFolder: 0.5 days
- DamerauLevenshteinSuggester: 2 days (the algorithm itself is the longest piece)
- DawgAutocompleteSuggestionProvider integration: 1 day
- KeyboardViewController dispatch + ContentView debug toggle: 0.5 days
- pbxproj surgery + xcodebuild verification: 1 day
- Manual simulator testing + commit-attached screenshots: 0.5 days

**Total: ~8–10 days of focused work.** Comparable to Phase 1.

## What this does *not* solve

- The Phase 1.5 "vowel_swap recall is 54%" finding will improve, but won't fully close the gap to Hunspell's 86%. Reasons: budget=1 catches single transpositions but multi-edit typos still miss; the Damerau-L automaton over a fold-keyed DAWG still requires the candidate's fold key to be ≤ 1 edit away from the input's fold. Words whose only issue is one mid-digraph swap (like the original `και` ↔ `καη` example) might still miss because the digraph break isn't a single edit in folded space.
- DAWG variant decision. We retain the 47 MB baseline through Phase 2; revisit in Phase 1.5-redux after the eval is re-run with the Levenshtein-automaton in the loop.
- Phase B UI rollout. Long-press on `🔄`, default-flip, Hunspell removal — all follow-ups after Phase 2 stabilizes.
