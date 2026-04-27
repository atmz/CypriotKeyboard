# Cypriot Keyboard — perf/memory tier-c design

**Date:** 2026-04-27
**Author:** Claude (Opus 4.7) on behalf of Alex
**Status:** Draft, revision 2 (reflects existing `dict_generation/` pipeline)
**Predecessor:** [`2026-04-26-keyboard-perf-tier-b-design.md`](./2026-04-26-keyboard-perf-tier-b-design.md)

## Goal

Replace Hunspell + the bundled `el_CY.dic`/`el_CY.aff` with a phonetic-folded DAWG (directed acyclic word graph) plus a custom suggester. Targets:

- **Resident memory**: drop from Hunspell's ~50 MB hash to ~10 MB DAWG-resident. Roughly 5× headroom.
- **Install size**: drop from `el_CY.dic` 16 MB + Hunspell `.cxx` to ~3–5 MB DAWG.
- **Long-word handling**: lift the 10-letter input cap. A Levenshtein-automaton over a DAWG scales linearly with input length, unlike Hunspell's heuristic suggester which blows up on long words.
- **Suggestion quality**: maintain ≥99% parity with Hunspell on the dominant typo classes (vowel/diacritic substitution), with explicit, smaller losses on the long tail (transpositions, compounds).

## Non-goals

- Improving suggestion quality *beyond* what Hunspell currently produces. The bar is parity-or-close-to-parity with a much smaller resource footprint.
- Supporting languages other than Cypriot Greek. The phonetic fold is Greek-specific.
- Lifting the iOS keyboard-extension memory budget itself. We work within Apple's constraints, just with more headroom.

## The crux: why replace, not augment

Tier (b) bypassed Hunspell for ~550 common words. To save *resident* memory, Hunspell has to be *unloaded* — keeping it alongside a trie doesn't help, because both sit in RAM. So tier (c) = full replacement.

## Architecture

### 1. Phonetic-folded keyspace

The dominant typo class in Greek input is **vowel / diacritic substitution** within the same phonetic class:

| Sound | Spellings (any of)              |
|-------|----------------------------------|
| /i/   | ι η υ ει οι υι, plus accented forms ή ί ύ ϊ ϋ |
| /e/   | ε αι, plus έ αί                  |
| /o/   | ο ω, plus ό ώ                    |

Naive edit-distance ≤ 2 over the canonical spelling fails for words with multiple vowel mistakes ("καλιμερα" → "καλημέρα" already costs 2 edits before any *real* typo budget remains). Hunspell handles this internally via `phonet.cxx`. We replicate it explicitly:

**Fold rules (illustrative; need linguistic review before shipping):**

```
Phonetic class                                       → canonical key char
──────────────────────────────────────────────────────────────────────
ι, η, υ, ει, οι, υι, ή, ί, ύ, ϊ, ϋ, ΐ, ΰ              → "ı" (any i-sound)
ε, αι, έ, αί                                          → "e"
ο, ω, ό, ώ                                            → "o"
combining diacritics (U+0301, U+0306, U+0308, U+0344) → dropped
final ς                                               → σ (handle position-insensitively)
```

Conservative scope: do **not** fold consonant doublings (νν↔ν, λλ↔λ) initially — wait for evidence users typo those. We can extend the fold incrementally without re-shipping the runtime.

### 2. DAWG over folded keys

Each entry in the dict (after affix expansion) is folded to its phonetic key. A minimized DAWG is built over the **fold space**, not the canonical space. Each leaf carries:

```
{
  canonical_forms: [(spelling, freq), …]
  // multiple canonical spellings can share one folded key.
  // e.g. "καλημέρα" and "καλομάρα" both fold to "kalımera".
}
```

**Why a DAWG over a plain trie:** suffix-sharing across stems gives 5–10× compression for languages with rich morphology. Greek has plenty of suffix overlap (`-ος` `-ου` `-ων` `-ους` etc.). Estimate: ~3–5 MB on disk after minimization, ~10 MB resident after mmap and on-demand decoding.

**The folded keyspace is *smaller* than the canonical** — many words collapse onto one key, so the trie shrinks. Slight memory win on top of the architectural win.

### 3. Suggester

Per keystroke:

```
1. Take user input → run greekify() (already exists, tier-b refactored to scanner).
2. Phonetic-fold the result.
3. Trie lookup, in priority order:
   a. exact match on folded key   → return canonical_forms ranked by freq.
   b. Levenshtein-automaton walk over the DAWG with edit budget ≤ 1
      (over the *folded* keyspace — not canonical) → collect candidates,
      rank by (edit distance, frequency).
4. If word is in the curated commonWords set, short-circuit at step 3a.
   (carries forward tier-b's fast path for free).
```

The "edit distance ≤ 1 in folded space" is roughly equivalent to "edit distance ≤ 2–3 in canonical space" for typical Greek typos, because the dominant class (vowel substitution) costs zero in folded space.

### 4. What this catches vs. what it misses

**Catches well (parity or better with Hunspell):**
- Wrong vowel within the same phonetic class — *zero* edits in folded space.
- Missing or wrong diacritics — folded out.
- Greeklish inputs that misspell vowels — handled because greekify+fold both run.
- Most one-letter substitutions, insertions, deletions — edit distance ≤ 1 in folded space.

**Misses (regression vs. Hunspell):**
- **Adjacent transpositions** (`καμηλερα` ↔ `καλημέρα`). Levenshtein counts transposition as 2 edits; Hunspell handles it as 1. *Mitigation:* upgrade to **Damerau-Levenshtein automaton** (handles single-position swaps). Modest implementation cost; closes most of this gap.
- **Compound word splitting** (`αυτοκίνητο` → `αυτο` + `κίνητο` if only stems are in dict). Rare with a curated dict where common compounds are present as full forms.
- **Phonetic-similarity ranking on consonants** (χ↔κ, β↔φ in some dialects). Could be added to the fold if there's evidence users typo these.
- **Edit budget > 1 on weird typos.** `kalimerax` → `καλημέρα` would need budget ≥ 2 to find. Hunspell's heuristic suggester goes farther for free.

**Net estimate:** ~99% parity for the common path; ~95% parity overall. With Damerau-Levenshtein, ~99% overall.

## Build pipeline

The repo already has a working dict-generation pipeline at `dict_generation/` (Python + Makefile, runs `affixcompress` to produce today's `el_CY.dic` + `el_CY.aff`). Tier-c **extends** this — does not replace it. The DAWG build sits downstream of the existing pipeline, consuming the same source word lists.

### Existing pipeline (unchanged, recap)

```
inputs:  el_GR/el_GR.dic (SMG base, iconv'd to UTF-8)
         spyros_list.dic, magic_words.dic, place_words.dic (curated Cypriot)
         corpus/*.csv (scraped Cypriot blogs — aceras, drprasinada, …)
         el_CY.aff_prefix
         list_words.py (tokenizes corpus → emits el_CY_words.v3.dic)
output:  ../dict/el_CY.dic + ../dict/el_CY.aff (Hunspell-formatted)
```

### New tier-c additions

Add a Makefile target `el_CY.dawg` that depends on `el_CY.dic` + a frequency map. Implement in Python to fit the existing pipeline; no Swift CLI.

```
new inputs:  el_CY.dic + el_CY.aff (existing pipeline output)
             corpus_freq.json (NEW — emitted by list_words.py as a side-output;
                               see §Frequency. Free to produce, currently thrown away.)
new tool:    dict_generation/build_dawg.py
new output:  ../dict/el_CY.dawg

steps inside build_dawg.py:
  1. Parse el_CY.aff (suffix/prefix rules), apply over each stem in
     el_CY.dic → ~3–8M surface forms.
  2. For each surface form: compute phonetic key, attach freq from
     corpus_freq.json (default-floor for unmatched), accumulate
     (folded_key → [(canonical, freq)]) map.
  3. Sort entries; build minimized DAWG via the Daciuk incremental
     algorithm (~200 LOC, well-known prior art).
  4. Serialize DAWG to a compact binary (uint32 transitions, varint
     deltas; marisa-trie's on-disk format is a reasonable template).
  5. Emit ../dict/el_CY.dawg with a versioned magic header.
```

The DAWG build is part of `make install` — same workflow as today, just one extra file gets copied into `../dict/`. Re-run only when:
- A source word list changes.
- The fold rules change.
- The DAWG format changes (rare).

### Phonetic-fold rules: cross-language sharing

Fold rules live in **`dict_generation/phonetic_fold.json`** — a single source of truth read by:
- `build_dawg.py` (Python) at build time.
- `CypriotKeyboardUtil.swift` (Swift) at runtime, loaded from the bundled JSON resource at app start.

~10 LOC of glue per side; rules edit in one place; no risk of build/runtime drift. JSON is overkill for the data volume but avoids any custom format.

### What `dict/` looks like during the transition

```
dict/
├── el_CY.aff      # kept for one release, fallback safety net (Hunspell still loaded)
├── el_CY.dic      # ditto
└── el_CY.dawg     # new
```

After the post-flip cleanup phase, only `el_CY.dawg` (and possibly `phonetic_fold.json` if not embedded) remains in `dict/`.

## Frequency data

Frequency only matters at **build time**, to disambiguate canonical-form collisions on the same folded key (`καλημέρα` vs `καλομάρα` both fold to `kalımera` — frequency picks which is suggested first). The runtime is unaware of how frequencies were obtained.

### What we already have

`dict_generation/list_words.py` already tokenizes the entire `corpus/` (~150K lines across 8+ Cypriot blog scrapes — aceras, beatrixcrisis, drprasinada, erykini, kaisitree, oof, …) and computes per-word counts in `words_abs`. **The counts are currently thrown away** — only the filtered word list ships forward. Preserving them is a one-line change: emit `corpus_freq.json` alongside `el_CY_words.v3.dic`.

This single change makes Cypriot-corpus frequencies available for free, and they're better-targeted than any external corpus would be (real Cypriot dialect text, not SMG wiki).

### Sources, ranked

**1. Existing `corpus/` tokenization counts** *(a few lines of glue — primary)*

Already-collected, dialect-correct, free to extract. Coverage gap: corpus is small (~hundreds of thousands of tokens after dedup), so the long tail of standard-Greek-only words gets default-floor frequency. Acceptable; suggestions still appear, just unranked at the bottom.

**2. Re-tier the curated `commonWords` set** *(an hour by hand, plugs known-common-Cypriot holes)*

The ~550 entries in `CypriotKeyboardUtil.swift` are by definition "common Cypriot." Manually split into 3 buckets:
- *very common* (~50 entries): function words ("και", "που", "εν", "ίντα")
- *common* (~200)
- *moderately common* (rest)

Assign each bucket a synthetic frequency that slots in above the corpus floor. Plugs the gap for words that may be common in speech but underrepresented in the blog corpus.

**3. Wikipedia el dump** *(few hours, fallback for SMG long tail)*

Download `elwiki-latest-pages-articles.xml.bz2`, strip MediaWiki markup, tokenize, count. ~70M tokens of Standard Modern Greek. Useful for *standard* Greek words that aren't well-represented in the Cypriot corpus (e.g., formal/technical vocabulary). Demoted from "primary" to "fallback" now that the dialect corpus exists.

**4. OpenSubtitles Greek subset** *(only if 1+2+3 leave gaps)*

OPUS `el` subtitles corpus, ~hundreds of millions of tokens, conversational. Worth adding if the Wikipedia distribution feels too formal in practice.

**5. LLM-bootstrapped frequencies** *(half a day, long-tail only)*

For dict entries not in any of the above, batch-prompt Claude/GPT: "rate how common this word is in everyday Cypriot Greek, 1–5." ~$5–10 in API calls. Crude backstop for words affix-expanded into existence with no corpus evidence.

**6. Crowdsourced study** *(weeks; not in scope for v1)*

### Recommended pipeline

**v1 ship: (1) + (2).** Extract corpus counts, manually tier `commonWords`. Total effort: one afternoon. Layer (3) on if the long-tail SMG ranking feels off after evaluation.

Final frequency function (per surface form, evaluated at build time):

```
freq(w) = max(
  log(corpus_count(w) + 1),         // tier 1 — Cypriot dialect corpus
  commonWords_bucket_score(w),      // tier 2 — manual curation
  log(wiki_count(w) + 1) * 0.5,     // tier 3 — SMG fallback, weighted lower
  default_floor                     // unknown words still appear, ranked last
)
```

## Memory and size estimates

| Component                    | Today (Hunspell) | After tier-c     |
|------------------------------|------------------|------------------|
| Bundled resources (.dic etc) | 16 MB            | ~3–5 MB DAWG     |
| Compiled C++ (hunspell_src/) | ~1 MB            | 0                |
| Resident hash / DAWG runtime | ~50 MB           | ~10 MB           |
| Per-suggest heap blowup      | grows with len^k | linear with len  |

These are rough — actual numbers come out of the build tool's first real run.

## User-facing setting (opt-in initially)

The new engine ships behind a UserDefaults toggle, **defaulting OFF**. Hunspell is the default for at least one release after the DAWG path is shippable. Users opt in explicitly while we gather field reports.

### Where the setting lives

Constraint: the extension has `RequestsOpenAccess = false` and cannot share UserDefaults with the container app. The toggle has to be readable from the extension's own sandbox.

Pattern from the existing codebase: `isLatinKeyboard` is stored in `UserDefaults.standard` of the extension and read at startup in `KeyboardViewController.viewDidLoad`. We use the same shape:

```swift
// In KeyboardViewController.viewDidLoad
let useDAWG = UserDefaults.standard.bool(forKey: "useDAWGSuggester")  // default false
```

The suggestion provider receives this flag at construction time and dispatches between Hunspell and DAWG paths.

### How users flip it

Two-phase UI rollout to keep the initial implementation small:

**Phase A — internal/tester only.** No keyboard UI surface. The setting is set via a debug command in the container app's `ContentView` (a hidden long-press, or a build-flagged toggle button visible only in DEBUG builds). Documented in CLAUDE.md so testers can find it. This keeps the v1 implementation focused on correctness, not UX.

**Phase B — user-visible toggle.** Once parity is measured and confidence is high, surface the setting in the keyboard itself. Options:

- A long-press secondary action on the existing `🔄` key (currently it just toggles Greek/Latin; long-press could open a small "engine" callout).
- A new `⚙` key in the layout — costs real estate, probably overkill.
- A row of engine pills above the autocomplete bar for one release after the flip — nudges discovery. Removed once the new engine is the default.

Recommendation: lean toward (A) — long-press on `🔄`. Reuses the convention. No new keys.

### Default-flip strategy

After measured field stability (one App Store release with the toggle off-by-default + N weeks of feedback), flip the default to ON. Hunspell still loads as fallback for one more release. Then the cleanup phase removes Hunspell entirely.

This means the `useDAWG` setting goes through three states over time:

| State                           | UserDefaults default | Hunspell loaded? |
|---------------------------------|----------------------|------------------|
| 1. Initial ship (opt-in)        | `false`              | Always           |
| 2. Default-on, opt-out remains  | `true`               | Always (fallback)|
| 3. Cleanup release              | (setting removed)    | No               |

## Rollout plan

Best done as a long-lived feature branch with intermediate verification.

**Phase 1: build pipeline.** Pure offline work in `dict_generation/`. Add `build_dawg.py`, modify `list_words.py` to emit `corpus_freq.json`, add Makefile target `el_CY.dawg`. Validate by spot-checking lookups.

**Phase 2: runtime, opt-in via setting.** Implement DAWG loader + Damerau-Levenshtein-automaton suggester in Swift. The suggestion provider reads `UserDefaults.standard.bool(forKey: "useDAWGSuggester")` (default `false`) and dispatches between Hunspell and DAWG paths. Both engines compiled into the binary; both loadable. Dev-build evaluation harness diffs the two for a typo corpus.

**Phase 3: ship opt-in.** App Store release with the setting off by default. Hunspell stays the default; testers and curious users opt in via the Phase A toggle (debug-build button or hidden combo). Gather field reports. Hunspell still always loaded.

**Phase 4: flip default.** Surface the setting as a user-visible UI element (long-press on `🔄`). Default flips to `true`. Hunspell still loaded as opt-out fallback for one release.

**Phase 5: removal.** Once feedback confirms parity, delete `hunspell_src/`, the modulemap, the bridging headers, the dict bundling, the dual-target `.cxx` Sources entries, and the toggle itself. Big cleanup commit.

This staged approach means no flag day; each phase is independently shippable, and Hunspell remains the safety net through Phase 4.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Suggestion quality regression worse than predicted | Phase 2 runs both engines in parallel with corpus diffing; we don't ship until parity is measured. |
| DAWG file format incompatibility across iOS versions | DAWG file is byte-stable (no architecture-specific layout). Versioned magic header; runtime refuses to load mismatched versions. |
| Build tool drifts from runtime fold rules | Single source of truth: `dict_generation/phonetic_fold.json`, loaded by both Python build tool and Swift runtime. ~10 LOC of glue per side. |
| Long-word memory regression in suggester | Levenshtein-automaton state is bounded by edit budget × DAWG fanout; budget=1 keeps state tiny even for long inputs. |
| Frequency data wrong, suggestions feel weird | Ship-time evaluation against a held-out typo set; iterate on frequency sources before flipping the flag. |

## Open questions

1. **Damerau-Levenshtein in v1, or v2?** Adds maybe 30% implementation cost for one more important error class (transpositions). Recommendation: include in v1 unless the build/runtime cost is surprising.
2. **Frequency for affix forms that don't appear in any corpus.** When affix expansion produces "καλημέρων" but no corpus has counted that exact form, do we inherit the stem's frequency (`καλημέρα`'s count) or default-floor? Recommendation: inherit, divided by some affix-rarity factor.
3. **Stem the dict during expansion, or expand fully?** Full expansion is simpler and the DAWG compresses well; on-the-fly affix application would shrink the artifact further but adds runtime complexity. Recommendation: full expansion. Re-evaluate if the DAWG is unexpectedly large.
4. **Format for the DAWG binary.** Roll our own (small, ~200 LOC, no deps) vs. depend on a Swift port of marisa-trie or similar (maybe 50 LOC of glue but adds a dep). Recommendation: roll our own — the format is simple and we want zero new runtime dependencies.

## Estimated scope

- **Frequency extraction: ~1 day.** Modify `list_words.py` to emit `corpus_freq.json`; manually tier `commonWords`.
- **Build tool: ~2–4 days.** `build_dawg.py`: affix expansion (consumes existing `el_CY.aff`), Daciuk DAWG construction, frequency ingest, binary serializer. Smaller than original estimate because no Swift CLI scaffolding and corpus already collected.
- **Runtime: ~3–4 days.** DAWG loader, Damerau-Levenshtein automaton suggester, fold-from-JSON, integration with the existing suggestion provider behind a `useDAWG` flag.
- **Evaluation harness: ~2 days.** Typo corpus, parallel-engine diffing of Hunspell vs DAWG suggestions.
- **Cleanup (post-flip): ~1 day.** Remove `hunspell_src/`, the modulemap, the bridging headers, the dual-target `.cxx` Sources entries, the `el_CY.dic`/`el_CY.aff` resource bundling. pbxproj surgery happens here.

Total: ~1.5 calendar weeks of focused work, not overnight. Scope is somewhat smaller than originally estimated because the existing `dict_generation/` pipeline gives us frequency data and an established build entry point for free.

## What this does *not* solve

- The 10-letter cap is *probably* liftable but not guaranteed — empirical answer comes from running the suggester on long inputs in phase 2.
- Real-time learning ("the user typed 'foo' instead of the suggestion 5 times, learn it as a word") is still out of scope — the dict is read-only at runtime, just like with Hunspell.
- Multi-language support. The fold and frequency data are Greek-specific.
