# Cypriot Keyboard — perf/memory tier-c design

**Date:** 2026-04-27
**Author:** Claude (Opus 4.7) on behalf of Alex
**Status:** Draft, awaiting user review
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

Offline tool, written in Swift (so it can share the phonetic-fold code with the runtime). Run manually; commit the artifact.

```
input:  dict/el_CY.dic, dict/el_CY.aff, freq/wiki_el_2026.tsv (see §Frequency)
        → tools/build-dawg/main.swift

steps:
  1. Parse el_CY.aff (suffix/prefix rules), apply over each stem in
     el_CY.dic → ~3–8M surface forms.
  2. For each surface form: compute phonetic key, lookup frequency,
     accumulate (folded_key → [(canonical, freq)]) map.
  3. Sort entries; build minimized DAWG (Daciuk algorithm — ~200 lines
     of well-known prior art).
  4. Serialize DAWG to a compact binary (uint32 transitions, varint
     deltas; reference: marisa-trie's format is a good template).
  5. Emit dict/el_CY.dawg + a small dict/el_CY.dawg.meta header.

output: a single ~3–5 MB binary that replaces el_CY.dic + el_CY.aff +
        the entire hunspell_src/ tree.
```

The build tool is **not** part of Xcode's build phases — running it is a manual step (likely once per dict revision). The output binary is checked in. This keeps the iOS build simple and avoids pbxproj surgery for build phases. Re-run only when:
- The source dict changes.
- The fold rules change.
- The DAWG format changes (rare).

## Frequency data

Frequency only matters at **build time**, to disambiguate canonical-form collisions on the same folded key (`καλημέρα` vs `καλομάρα` both fold to `kalımera` — frequency picks which is suggested first). The runtime is unaware of how frequencies were obtained.

### Sources, ranked by effort

**1. Wikipedia el dump** *(few hours of compute, no humans needed)*

Download `elwiki-latest-pages-articles.xml.bz2`, strip MediaWiki markup, tokenize, count. ~70M tokens of Standard Modern Greek. Reliable rank ordering for ~90–95% of dict word forms. **Gap:** Cypriot dialect words ("ίντα", "ένι", "έσιει", "πλάστιχα") underweighted or absent because they don't appear in SMG Wikipedia.

**2. OpenSubtitles Greek subset** *(few hours, complements #1)*

OPUS hosts the OpenSubtitles corpus split by language; `el` is several hundred million tokens of *spoken* Greek (subtitles), heavy on conversational/informal words. Different distribution than Wikipedia — more representative of how people actually type. Combine with #1 via weighted average.

**3. Re-tier the existing `commonWords` set** *(an hour by hand, fills the Cypriot gap)*

The ~550 entries Alex already curated are by definition "common Cypriot." Manually split into 3 buckets:
- *very common* (~50 entries): function words ("και", "που", "εν", "ίντα")
- *common* (~200)
- *moderately common* (rest)

Assign each bucket a synthetic frequency that slots into the SMG ranking. Cheapest way to fix the SMG-undercounts-Cypriot bias.

**4. Cypriot-specific corpus** *(weekend project)*

Public sources with real Cypriot dialect content:
- r/cyprus archives via the Reddit API
- Cypriot YouTube comment dumps (yt-dlp + `--write-comments`)
- Public Cypriot blog/op-ed content (politis.com.cy archives, etc.)

Probably 1–10M tokens after dedup and English-code-switching filtering. Specifically captures words SMG corpora miss. Higher signal-to-noise issue, but worth it for dialect-heavy curation.

**5. LLM-bootstrapped frequencies** *(half a day)*

For dict entries not in the corpus, batch-prompt Claude/GPT: "rate how common this word is in everyday Cypriot Greek, 1–5." Probably $5–10 in API calls for the whole long tail. Crude backstop, not primary.

**6. Crowdsourced study** *(weeks)*

Recruit native Cypriot speakers to rank a few thousand candidate words. Highest quality, slowest path. Overkill for this iteration.

### Recommended pipeline

**Do (1) + (3) for the v1 ship.** Wikipedia gives the SMG distribution for the 90% of the dict that's standard Greek; manual tiering of `commonWords` patches the Cypriot-specific gap. Total effort: one afternoon. If quality eval shows gaps, layer (2) on top in a v2.

Final frequency function (per surface form):

```
freq(w) = max(
  log(wiki_count(w) + 1),           // tier 1
  commonWords_bucket_score(w),       // tier 3 — boosts Cypriot-specific
  default_floor                      // unknown words still appear in suggestions
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

## Rollout plan

Best done as a long-lived feature branch with intermediate verification.

**Phase 1: build pipeline.** Pure offline work. Write `tools/build-dawg`, generate a first DAWG from `el_CY.dic` + `el_CY.aff`. Validate by spot-checking that lookups return the expected canonical forms.

**Phase 2: runtime.** Implement DAWG loader + Levenshtein-automaton suggester in Swift, behind a feature flag (`useDAWG = false` by default). Both Hunspell and DAWG paths run side-by-side in dev builds; an integration test compares suggestions for a corpus of typos and reports diffs.

**Phase 3: switchover.** When the dev-build comparison shows acceptable parity, flip `useDAWG = true` for release. Hunspell still loaded for one release as a safety net.

**Phase 4: removal.** Following release, delete `hunspell_src/`, the modulemap, the bridging headers, the dict bundling, the dual-target source compilation entries for hunspell `.cxx` files. Big cleanup commit.

This staged approach means no flag day; each phase is independently shippable.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Suggestion quality regression worse than predicted | Phase 2 runs both engines in parallel with corpus diffing; we don't ship until parity is measured. |
| DAWG file format incompatibility across iOS versions | DAWG file is byte-stable (no architecture-specific layout). Versioned magic header; runtime refuses to load mismatched versions. |
| Build tool drifts from runtime fold rules | Both share the same Swift source for the fold function (build tool imports `CypriotKeyboardUtil.swift` — or a leaner shared file). |
| Long-word memory regression in suggester | Levenshtein-automaton state is bounded by edit budget × DAWG fanout; budget=1 keeps state tiny even for long inputs. |
| Frequency data wrong, suggestions feel weird | Ship-time evaluation against a held-out typo set; iterate on frequency sources before flipping the flag. |

## Open questions

1. **Damerau-Levenshtein in v1, or v2?** Adds maybe 30% implementation cost for one more important error class (transpositions). Recommendation: include in v1 unless the build/runtime cost is surprising.
2. **Frequency for affix forms that don't appear in any corpus.** When affix expansion produces "καλημέρων" but no corpus has counted that exact form, do we inherit the stem's frequency (`καλημέρα`'s count) or default-floor? Recommendation: inherit, divided by some affix-rarity factor.
3. **Stem the dict during expansion, or expand fully?** Full expansion is simpler and the DAWG compresses well; on-the-fly affix application would shrink the artifact further but adds runtime complexity. Recommendation: full expansion. Re-evaluate if the DAWG is unexpectedly large.
4. **Format for the DAWG binary.** Roll our own (small, ~200 LOC, no deps) vs. depend on a Swift port of marisa-trie or similar (maybe 50 LOC of glue but adds a dep). Recommendation: roll our own — the format is simple and we want zero new runtime dependencies.

## Estimated scope

- Build tool: ~3–5 days. Affix expansion + DAWG construction + frequency ingest.
- Runtime: ~3–4 days. DAWG loader, Levenshtein-automaton suggester, integration with the existing suggestion provider behind a flag.
- Evaluation harness: ~2 days. Typo corpus, parallel-engine diffing.
- Cleanup (post-flip): ~1 day. Hunspell removal, pbxproj surgery.

Total: ~2 calendar weeks of focused work, not overnight.

## What this does *not* solve

- The 10-letter cap is *probably* liftable but not guaranteed — empirical answer comes from running the suggester on long inputs in phase 2.
- Real-time learning ("the user typed 'foo' instead of the suggestion 5 times, learn it as a word") is still out of scope — the dict is read-only at runtime, just like with Hunspell.
- Multi-language support. The fold and frequency data are Greek-specific.
