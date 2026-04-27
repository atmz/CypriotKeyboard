# Tier-c Phase 1.5 — DAWG eval harness & variant selection

**Date:** 2026-04-27
**Author:** Claude (Opus 4.7) on behalf of Alex
**Status:** **Phase 1.5 complete (2026-04-27).** Eval harness shipped, all 6 variants measured against synthetic Greeklish/Greek perturbation corpus + Hunspell baseline. **Decision: retain `dict/el_CY.dawg` at the 47 MB baseline pending Phase 2 evaluation.** Optimization variants are characterized and ready; revisit after Phase 2's Levenshtein-automaton suggester lands and we can re-run the harness with edit-distance recovery factored into the recall numbers.

### Phase 1.5 findings worth remembering

Recall summary on the 585-word top-N + commonWords ground-truth (~2,357 perturbation pairs):

| Variant | Size | identity | unaccented | vowel-swap | greekified-Latin | avg |
|---|---|---|---|---|---|---|
| baseline | 47 MB | 95.0% | 93.3% | 54.3% | 94.2% | 84.2% |
| v3_freq1 + passthrough (proposed) | ~2.7 MB | (would match v3_freq1) | | | | |
| v3_freq1 | 2.72 MB | 93.5% | 93.3% | 53.5% | 92.6% | 83.2% |
| v3_freq2 | 1.47 MB | 93.5% | 93.3% | 53.5% | 92.6% | 83.2% |
| hunspell | — | 95.0% | 94.0% | 86.4% | 92.6% | 92.0% |

Key qualitative findings the eval surfaced:

1. **The vowel-swap recall gap (DAWG ~54% vs Hunspell 86%)** is the Phase-1-caveat realised: when a swap breaks a digraph (e.g. `και` → `καη`), exact-fold-match misses. Phase 2's Levenshtein-automaton is the intended fix.

2. **v3_freq2 (1.47 MB) drops 23,547 freq=1 corpus singletons** that include real, common Greek inflections (άκυρη, ενήλικοι, σύμμαχοι, στεναχωρημένη, μπερδεύτηκε). v3_freq1 (2.72 MB) covers these at 100% identity recall.

3. **9 high-frequency Cypriot dialect words drop from v3_freq1/v3_freq2 due to a corpus/canonical spelling mismatch:** the corpus stores τζαι/τζιαι (no breve), but the canonical curated form is τζ̆αι (with breve), so its corpus_freq is 0. Solution when we revisit: `build_dawg.py` exempts the curated word lists (`magic_words.dic`, `spyros_list.dic`, `commonWords` JSON) from the freq filter.

4. **The freq=0 cliff: 852,089 surface forms (94% of the dict) have no corpus presence at all.** Random sampling shows these are mostly archaic / formal / complex-derivational forms (αποχαυνωνόμενος, παραφουσκώθηκα, υαλογραφημένα). Low priority for autocorrect coverage; safe to drop in any optimization.

5. **The recommended optimization when we revisit: v3_freq1 + curated-passthrough.** ~2.7 MB final (17× smaller than baseline), covers all corpus-attested words, restores the τζ̆- forms via passthrough. Strictly dominates v3_freq2 on coverage; pays only +1.25 MB over it.

### What we're waiting for before flipping

Phase 2's Levenshtein-automaton suggester. If it closes the vowel-swap gap (DAWG 54% → ≥80% expected), the variant comparison shifts: rare-word lookups can also benefit from edit-distance walking, which materially changes how much we lose by shipping a smaller variant. Re-run `make eval` after Phase 2 lands and re-evaluate.
**Predecessor:** [Phase 1 plan](../plans/2026-04-27-tier-c-phase-1-build-pipeline.md)

## Goal

Build a synthetic Greeklish/Greek perturbation corpus and a recall-evaluation harness that measures how often each candidate DAWG variant — and the Hunspell baseline — finds the expected canonical Greek word. Use the results to **pick the variant that ships as Phase 1's final `dict/el_CY.dawg`**, with eyes-open trade-offs rather than gut-feel.

## Why now

Phase 1 Task 10 produced a 47 MB DAWG — about 10× the spec target. Sizing experiments showed the bulk comes from morphological surface forms whose phonetic-fold collapse rate is only ~12%. Several smaller variants exist:

| Variant | Size | What it gives up |
|---|---|---|
| Baseline | 47 MB | nothing |
| V1: top-1 canonical | 45 MB | multi-canonical lists per fold key |
| V2: stems only | 38 MB | runtime affix application required (Phase 2 work) |
| V3@1: corpus-attested only | 2.7 MB | 93% of expanded forms (those never seen in scraped corpus) |
| V3@2: freq ≥ 2 | 1.5 MB | + corpus singletons |
| V4: V1+V3@1 | 2.65 MB | both losses combined |

A 4-word smoke-check passes for every variant — useless for picking among them. The harness is the missing piece.

The user-facing reframe (per discussion): **lifting the 10-letter cap and getting clean phonetic-fold suggestion behavior is itself a win, even at memory parity with Hunspell.** So variant selection isn't gated on a 5× memory reduction; it's gated on whether suggestion quality holds.

## Scope

**In:**
- A reproducible synthetic ground-truth corpus, derived from the existing `dict_generation/corpus_freq.json` (top-N words) plus the curated `commonWords` set (extracted from `CypriotKeyboardUtil.swift`).
- Four perturbation classes per ground-truth word (identity / unaccented / vowel-swap / greekified-Latin).
- An evaluator that runs each (input, expected) pair through (a) every DAWG variant and (b) Hunspell, computes recall, and emits a comparison table.
- A `make eval` target wired into the existing `dict_generation/Makefile`.
- The variant decision: regenerate `dict/el_CY.dawg` with the chosen variant once the table is in.

**Out:**
- The Phase 2 Swift runtime — separate plan.
- The Levenshtein-automaton suggester — Phase 2.
- User-facing UI for evaluations.
- Latency benchmarking — separate concern, not gating variant choice.

## Architecture

### Data flow

```
ground-truth Greek words      perturbation classes
       │                              │
       └──────────┬───────────────────┘
                  ▼
       (input, expected) pairs   ───►  evaluator runs each pair against:
                                         • baseline DAWG
                                         • V1, V2, V3@1, V3@2, V4
                                         • Hunspell (via subprocess)
                                       ──► recall(variant, perturbation_class)
                                                 │
                                                 ▼
                                       comparison table → decision
```

### Modules (proposed; final names per the plan)

```
dict_generation/eval/
├── __init__.py
├── ground_truth.py     # build the canonical Greek-word list from corpus + commonWords
├── inverse_greekify.py # heuristic Greek → Greeklish for the greekified-Latin perturbation
├── perturbations.py    # identity / unaccented / vowel-swap / greekified-latin generators
├── variants.py         # build each DAWG variant on demand (caches outputs in /tmp/eval/)
├── hunspell_runner.py  # subprocess Hunspell wrapper
├── recall.py           # recall computation per (variant, perturbation)
├── main.py             # orchestrator: runs everything, emits results.md
├── results.md          # generated output (committed for git-history visibility)
└── tests/              # unit tests for each module (extend existing test discovery)
```

`commonWords` lives in Swift today. We extract it once into `dict_generation/eval/common_words.json` so the Python harness can read it. This is a one-time data dump; the Swift source remains the runtime source of truth.

### Perturbation classes

For each ground-truth word `w`:

1. **identity** — `w` itself. Recall here measures "does the variant know about real words at all?"
2. **unaccented** — `w` with combining diacritics stripped (NFD → filter `Mn` category). Measures "user types without accents."
3. **vowel-swap** — for each i-class vowel (η/ι/υ/ει/οι/υι) in `w`, generate a copy with that vowel replaced by a different i-class member. Multiple swaps emit multiple inputs. Measures "user picked the wrong i-spelling."
4. **greekified-Latin** — apply heuristic Greek-to-Greeklish (`inverse_greekify`), then re-apply existing `greekify`. The result is a "user typed in Latin" version. Lossy by design (η→i→ι). Measures the dominant Greeklish typing case.

Total inputs per ground-truth: typically 1 + 1 + 1–3 + 1 = 4–6. With ~1000 ground-truth words → ~4000–6000 evaluation inputs.

### Recall metric

For a given (variant, perturbation_class), recall = `# inputs where the expected word appeared in the variant's returned canonical-form list / total inputs`.

For DAWG variants: lookup is `phonetic_fold(input) → DawgReader.payload_for → canonical_forms`. The expected word "appears" if it's in that list.

For Hunspell: lookup is `hunspell -d el_CY -a` parse, take the suggestion list. Expected word "appears" if it's in that list (or if Hunspell says the input is already correct AND the input ≡ expected).

### Phase 1 caveat (load-bearing)

The DAWG-variant evaluator only does *exact-fold-match* lookup right now — there's no Levenshtein-automaton walk yet (that's Phase 2). So the absolute recall numbers for DAWG variants will be lower than what users will actually see post-Phase-2.

**This is fine for Phase 1.5's purpose**: variant *ordering* (does V3@2 lose recall vs baseline?) is preserved regardless of whether the runtime adds edit-distance walking on top, because the same "+/-1 edit walk" applies to every variant equally.

The Hunspell baseline column will look better than DAWG variants because Hunspell already does heuristic suggestion. That's expected; once Phase 2 lands the Levenshtein-automaton, we'll re-run this harness and the DAWG variants should narrow the gap.

## Decision criterion

After eval, pick the **smallest variant whose recall on identity + unaccented + vowel-swap + greekified-Latin is within 5 percentage points of baseline**.

If V3@2 (1.5 MB) is within 5pp of baseline (47 MB) on every perturbation class → ship V3@2. Massive size win, negligible quality loss.

If V3@2 craters on some class → fall back to V3@1, V4, or V2 in that order. Document the reasoning in the commit message that regenerates `dict/el_CY.dawg`.

If *all* small variants crater → reconsider Phase 1's approach (likely option 6 from the variant menu: ship the 47 MB and reframe the value prop).

## Reuse for Phase 2

The harness is permanent infrastructure. After Phase 2 lands the Levenshtein-automaton suggester:
1. Re-run `make eval`.
2. Two new columns appear: "DAWG with edit-1 walk" and "DAWG with edit-2 walk."
3. The same recall-by-perturbation comparison shows whether the suggester closed the gap to Hunspell, and whether the variant choice from Phase 1.5 still makes sense.

This means the work here pays for itself twice.

## What this design does *not* solve

- Doesn't measure latency. The 47 MB vs 1.5 MB difference will show up in mmap performance and lookup speed; that needs its own benchmark. Out of scope here.
- Doesn't measure *suggestion ranking quality* (top-1 accuracy). Recall is a coarser metric — "did the right word appear at all?" — which is what variant selection actually needs. Top-1 accuracy is a Phase 2 evaluation once the suggester ranks results.
- Doesn't account for words that aren't in any of {top-N corpus, commonWords}. Coverage of rare-but-real words is implicit in the V3 thresholds and isn't directly measured here.

## Open questions

1. **Top-N corpus size.** 500 vs 1000 vs 2000? More inputs = better stats but slower runs. Plan defaults to 500; bump if results look noisy.
2. **vowel-swap density.** Generate one swap per i-class vowel position (could be 0–3 inputs), or every-pair-of-i-class-vowels (up to ~15 per word)? Plan defaults to one-swap-per-position.
3. **Greekified-Latin determinism.** `inverse_greekify` is heuristic — should it produce one Greeklish per Greek word, or sample from multiple plausible Latin spellings (e.g. both "kalimera" and "kalymera")? Plan defaults to one canonical Greeklish per word; revisit if results look brittle.
4. **Hunspell baseline cost.** ~100 ms per subprocess call × ~5000 inputs = ~8 minutes. Acceptable for a `make eval` run; cache results between runs by input hash if it becomes painful.
