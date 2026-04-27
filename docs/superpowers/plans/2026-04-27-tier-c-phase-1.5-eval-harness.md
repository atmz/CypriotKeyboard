# Tier-c Phase 1.5: DAWG Eval Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a synthetic Greeklish/Greek perturbation corpus and a recall-evaluation harness, run it across all six DAWG variants and the Hunspell baseline, and use the results to pick the variant that ships as Phase 1's final `dict/el_CY.dawg`.

**Architecture:** A new Python package under `dict_generation/eval/` that (1) generates a ground-truth list of canonical Greek words from `corpus_freq.json` + curated `commonWords`, (2) emits four perturbation classes per word (identity / unaccented / vowel-swap / greekified-Latin), (3) builds each candidate DAWG variant on demand, (4) runs every (input, expected) pair through every variant + Hunspell via subprocess, (5) emits a recall-by-perturbation comparison table to `dict_generation/eval/results.md`. Hooked into the existing `dict_generation/Makefile` as `make eval`.

**Tech Stack:** Python 3.9+ (already required), `unittest` + `subprocess` from stdlib, `unicodedata` for NFD/NFC. **Hunspell binary** must be on `PATH` (already a build-pipeline dependency — `affixcompress` lives in the same package). **No new third-party Python dependencies.**

**Working directory:** `/Users/alext/CypriotKeyboard.tier-c/` (the `tier-c-dawg` worktree).

**Reference spec:** [`docs/superpowers/specs/2026-04-27-tier-c-phase-1.5-eval-harness.md`](../specs/2026-04-27-tier-c-phase-1.5-eval-harness.md) (commit `aac6536` on `main`).

**Sync note:** Before starting, the worktree should `git fetch && git rebase origin/main` so this plan is visible at `docs/superpowers/plans/...` inside the worktree. Without that, the plan content has to come from the orchestrator's prompt directly.

---

## File Structure

All new files live under `dict_generation/eval/`. Existing modules (`aff_parse`, `affix_expand`, `phonetic_fold`, `dawg`, `build_dawg`) are imported but not modified, except for a small refactor in Task 6 to extract a parameterized builder function from `build_dawg.py`.

```
dict_generation/
├── eval/
│   ├── __init__.py             # NEW: empty
│   ├── common_words.json       # NEW: extracted from CypriotKeyboardUtil.swift (Task 2)
│   ├── ground_truth.py         # NEW: build canonical-word list (Task 3)
│   ├── inverse_greekify.py     # NEW: heuristic Greek → Greeklish (Task 4)
│   ├── perturbations.py        # NEW: 4 perturbation generators (Task 5)
│   ├── variants.py             # NEW: build any of 6 variants on demand (Task 6)
│   ├── hunspell_runner.py      # NEW: subprocess wrapper + parser (Task 7)
│   ├── recall.py               # NEW: recall computation per (variant, class) (Task 8)
│   ├── main.py                 # NEW: orchestrator → results.md (Task 9)
│   ├── results.md              # GENERATED & COMMITTED: comparison table
│   └── tests/
│       ├── __init__.py         # NEW
│       ├── test_ground_truth.py
│       ├── test_inverse_greekify.py
│       ├── test_perturbations.py
│       ├── test_variants.py
│       ├── test_hunspell_runner.py
│       └── test_recall.py
├── build_dawg.py               # MODIFY (Task 6): factor out a parameterized helper
└── Makefile                    # MODIFY (Task 10): add `eval` target
```

Tests run with `python3 -m unittest discover dict_generation` (the runner picks up both the existing `tests/` and the new `eval/tests/` packages automatically).

---

## Task 1: Eval scaffolding

**Files:**
- Create: `dict_generation/eval/__init__.py`
- Create: `dict_generation/eval/tests/__init__.py`
- Create: `dict_generation/eval/tests/test_smoke.py`

- [ ] **Step 1: Create empty package markers**

```bash
mkdir -p dict_generation/eval/tests
touch dict_generation/eval/__init__.py dict_generation/eval/tests/__init__.py
```

- [ ] **Step 2: Add a smoke test**

Write `dict_generation/eval/tests/test_smoke.py`:

```python
import unittest


class EvalSmokeTest(unittest.TestCase):
    def test_runner_works(self):
        self.assertEqual(1 + 1, 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run combined test discovery**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 -m unittest discover dict_generation -v 2>&1 | tail -5
```

Expected: existing tests pass, plus `EvalSmokeTest.test_runner_works ... ok`.

- [ ] **Step 4: Commit**

```bash
git add dict_generation/eval/__init__.py \
        dict_generation/eval/tests/__init__.py \
        dict_generation/eval/tests/test_smoke.py
git commit -m "tier-c-eval: bootstrap eval/ package + smoke test"
```

---

## Task 2: Extract `commonWords` from Swift to JSON

**Files:**
- Create: `dict_generation/eval/common_words.json`

The Swift source `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` (note the **two spaces** in the folder name) contains `static let commonWords: Set<String> = ["άλλα", "άλλες", …]` — ~550 hand-curated Cypriot Greek words. We extract them to JSON once so the Python harness can read them. The Swift source remains the runtime source of truth; this is a one-time data dump for offline tooling.

- [ ] **Step 1: Pull the words out via a one-off Python script**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 - <<'PY'
import re
import json
import os

src = open("Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift", encoding="utf-8").read()

# Find the Set<String> literal that opens with '["άλλα"' and runs to the closing ']'.
# We anchor on `static let commonWords` to avoid catching unrelated arrays.
match = re.search(
    r"static let commonWords:\s*Set<String>\s*=\s*\[(.*?)\]",
    src,
    re.DOTALL,
)
assert match, "couldn't locate commonWords declaration in CypriotKeyboardUtil.swift"

body = match.group(1)
# Each entry is a quoted string. Pull every "..." literal.
entries = re.findall(r'"([^"]*)"', body)
assert entries, "no entries extracted — pattern probably wrong"
# Sanity: a known entry must be present.
assert "άλλα" in entries, "smoke check failed: 'άλλα' not extracted"

os.makedirs("dict_generation/eval", exist_ok=True)
with open("dict_generation/eval/common_words.json", "w", encoding="utf-8") as f:
    json.dump(sorted(set(entries)), f, ensure_ascii=False, indent=2)

print(f"extracted {len(entries)} words ({len(set(entries))} unique)")
PY
```

Expected output: `extracted ~550 words (~550 unique)`. If the count is way off (e.g., < 100 or > 2000), the regex broke — investigate before continuing.

- [ ] **Step 2: Spot-check the JSON**

```bash
python3 -c "
import json
data = json.load(open('dict_generation/eval/common_words.json'))
print(f'count: {len(data)}')
print(f'first 5: {data[:5]}')
print(f'last 5: {data[-5:]}')
assert 'άλλα' in data and 'και' in data, 'spot-check failed'
print('OK')
"
```

Expected: count around 550, first entries are alphabetic-Greek-sorted, `'άλλα'` and `'και'` both present.

- [ ] **Step 3: Commit**

```bash
git add dict_generation/eval/common_words.json
git commit -m "tier-c-eval: extract commonWords from Swift to JSON for offline tooling

One-time data dump. The Swift source in CypriotKeyboardUtil.swift remains
the runtime source of truth; this JSON is read by the Phase 1.5 eval
harness's ground-truth generator."
```

---

## Task 3: Ground-truth corpus generator

**Files:**
- Create: `dict_generation/eval/ground_truth.py`
- Create: `dict_generation/eval/tests/test_ground_truth.py`

- [ ] **Step 1: Write failing tests**

Write `dict_generation/eval/tests/test_ground_truth.py`:

```python
import json
import os
import tempfile
import unittest
from dict_generation.eval.ground_truth import build_ground_truth


class GroundTruthTests(unittest.TestCase):

    def test_top_n_sorted_by_count_descending(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100, "που": 50, "rare": 1}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=2)
            self.assertEqual(set(words), {"και", "που"})

    def test_includes_common_words_even_if_outside_top_n(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100, "που": 50}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump(["ίντα", "και"], f)  # ίντα isn't in the top-N
            words = build_ground_truth(freq_path, common_path, top_n=1)
            self.assertEqual(set(words), {"και", "ίντα"})

    def test_dedupes(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump(["και"], f)
            words = build_ground_truth(freq_path, common_path, top_n=10)
            self.assertEqual(words.count("και"), 1)

    def test_output_is_sorted_for_determinism(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"γ": 1, "α": 2, "β": 3}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=3)
            self.assertEqual(words, ["α", "β", "γ"])  # sorted alphabetically

    def test_filters_short_or_garbage(self):
        # Single-letter words don't make useful eval targets.
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"α": 1000, "και": 100, "β": 500}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=10)
            self.assertEqual(set(words), {"και"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run, verify failure**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 -m unittest dict_generation.eval.tests.test_ground_truth -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.ground_truth`.

- [ ] **Step 3: Implement**

Write `dict_generation/eval/ground_truth.py`:

```python
"""Build the synthetic-corpus ground-truth list of canonical Greek words.

Combines:
- Top-N entries from corpus_freq.json (real Cypriot dialect frequencies)
- The hand-curated commonWords set (from common_words.json)

Filters out single-character words; dedupes; returns alphabetically sorted
for determinism.
"""
import json
from typing import List


def build_ground_truth(freq_path: str, common_path: str, top_n: int = 500) -> List[str]:
    """Return a deterministic list of canonical Greek words to evaluate."""
    with open(freq_path, encoding="utf-8") as f:
        freq = json.load(f)
    with open(common_path, encoding="utf-8") as f:
        common = json.load(f)

    # Top-N by count descending (ties broken alphabetically for determinism).
    top = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))[:top_n]
    top_words = {w for w, _ in top}

    combined = top_words | set(common)
    # Drop single-letter or empty entries — they're not useful eval targets.
    combined = {w for w in combined if len(w) >= 2}
    return sorted(combined)
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.eval.tests.test_ground_truth -v
```

Expected: all 5 tests pass.

- [ ] **Step 5: Sanity-run on real data**

```bash
python3 -c "
from dict_generation.eval.ground_truth import build_ground_truth
words = build_ground_truth(
    'dict_generation/corpus_freq.json',
    'dict_generation/eval/common_words.json',
    top_n=500,
)
print(f'ground-truth size: {len(words)}')
print(f'sample: {words[:5]}, {words[len(words)//2:len(words)//2+5]}, {words[-5:]}')
"
```

Expected: size between **500 and 1500** (top-N + curated, deduped). Sample lines should look like normal Greek words.

- [ ] **Step 6: Commit**

```bash
git add dict_generation/eval/ground_truth.py \
        dict_generation/eval/tests/test_ground_truth.py
git commit -m "tier-c-eval: add ground_truth builder (top-N corpus + commonWords)"
```

---

## Task 4: Heuristic inverse-greekify (Greek → Greeklish)

**Files:**
- Create: `dict_generation/eval/inverse_greekify.py`
- Create: `dict_generation/eval/tests/test_inverse_greekify.py`

This is the heuristic Greek-to-Latin transliterator that the greekified-Latin perturbation uses. It's *deliberately lossy* — η, ι, υ all become `i`; ω and ο both become `o`; etc. — because that mirrors how users actually transliterate when typing.

The goal isn't a pretty round-trip; it's to produce a Latin string that, when fed through `greekify`, lands on the SAME fold key as the source Greek word. That's how we test the Greeklish→Greek path.

- [ ] **Step 1: Write failing tests**

Write `dict_generation/eval/tests/test_inverse_greekify.py`:

```python
import unittest
from dict_generation.eval.inverse_greekify import inverse_greekify


class InverseGreekifyTests(unittest.TestCase):

    def test_basic_letters(self):
        self.assertEqual(inverse_greekify("καλημερα"), "kalimera")
        self.assertEqual(inverse_greekify("νερο"), "nero")

    def test_diacritics_dropped(self):
        self.assertEqual(inverse_greekify("καλημέρα"), "kalimera")
        self.assertEqual(inverse_greekify("ώρα"), "ora")

    def test_eta_iota_collapse_to_i(self):
        # η and ι both map to "i" in Greeklish convention.
        self.assertEqual(inverse_greekify("ηλικια"), "ilikia")

    def test_upsilon_maps_to_y(self):
        # υ uses "y" (so the output is parseable by greekify, which has y → υ).
        self.assertEqual(inverse_greekify("υπερ"), "yper")

    def test_omega_collapses_to_o(self):
        self.assertEqual(inverse_greekify("ωρα"), "ora")

    def test_digraphs_handled(self):
        # ει, οι, υι are i-sound digraphs; ου is the /u/ digraph; αι is /e/.
        self.assertEqual(inverse_greekify("ειδος"), "eidos")  # let greekify rebuild ει
        self.assertEqual(inverse_greekify("ουρα"), "oura")
        self.assertEqual(inverse_greekify("αιμα"), "aima")

    def test_special_consonants(self):
        # The Latin spellings are chosen for round-trip safety with greekify:
        # greekify has ks → ξ and x → χ, so we must invert in matching shape.
        self.assertEqual(inverse_greekify("θεος"), "theos")
        self.assertEqual(inverse_greekify("χωρα"), "xora")     # χ → x (so x → χ rebuilds it)
        self.assertEqual(inverse_greekify("ψυχη"), "psyxi")    # ψ→ps, υ→y, χ→x, η→i
        self.assertEqual(inverse_greekify("ξενος"), "ksenos")  # ξ → ks (so ks → ξ rebuilds it)

    def test_final_sigma(self):
        self.assertEqual(inverse_greekify("καλος"), "kalos")
        self.assertEqual(inverse_greekify("καλώς"), "kalos")

    def test_empty_input(self):
        self.assertEqual(inverse_greekify(""), "")

    def test_output_is_ascii_lowercase(self):
        # Sanity: the function should never emit Greek characters or uppercase.
        for word in ["καλημέρα", "ώρα", "θεός", "ψυχή"]:
            out = inverse_greekify(word)
            self.assertTrue(out.isascii(), f"non-ASCII output for {word!r}: {out!r}")
            self.assertEqual(out, out.lower(), f"uppercase in output for {word!r}: {out!r}")


if __name__ == "__main__":
    unittest.main()
```

Note: full round-trip property (inverse_greekify → re-greekify → fold key matches the original's fold key) is exercised in Task 5's test suite, where `_greekify_python` lands and can be composed with `inverse_greekify`.

- [ ] **Step 2: Run, verify failure**

```bash
python3 -m unittest dict_generation.eval.tests.test_inverse_greekify -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.inverse_greekify`.

- [ ] **Step 3: Implement**

Write `dict_generation/eval/inverse_greekify.py`:

```python
"""Heuristic Greek → Greeklish (Latin) transliteration.

Lossy by design: η/ι/υ all become "i", ω/ο both become "o", etc. The
output, when fed through the existing greekify(), should land on the same
*phonetic fold key* as the input — that's the property we use to test the
Greeklish→Greek path in eval.

Diacritics drop. Final sigma normalizes to "s".
"""
from typing import List, Tuple


# Longest-first match table. Greek source → Latin target.
# Order matters: digraphs and accented forms first.
#
# Rule choices are constrained by ROUND-TRIP SAFETY through greekify(). Where
# greekify has a multi-char Latin → Greek rule, inverse_greekify must invert
# in matching shape so a Greek word and its inverse-then-re-greekified form
# fold to the same phonetic key.
#
# Critical mappings (round-trip rationale):
#   ξ → "ks" (greekify has "ks" → ξ; "x" alone in greekify means χ)
#   χ → "x"  (greekify has "x" → χ; "ch" in greekify means τσ̆)
#   υι → "ui" (greekify has "yi" → γι, so we can't use "yi" for υι)
_RULES: List[Tuple[str, str]] = sorted(
    [
        # Digraphs / diphthongs
        ("αι", "ai"), ("αί", "ai"),
        ("ει", "ei"), ("εί", "ei"),
        ("οι", "oi"), ("οί", "oi"),
        ("υι", "ui"), ("υί", "ui"),
        ("ου", "ou"), ("ού", "ou"),
        # Special consonant clusters that take multi-char Latin
        ("θ", "th"), ("Θ", "Th"),
        ("ψ", "ps"), ("Ψ", "Ps"),
        # ξ and χ — note the ks/x assignment for round-trip safety
        ("ξ", "ks"), ("Ξ", "Ks"),
        ("χ", "x"),  ("Χ", "X"),
        # i-class single vowels (all collapse to i in Greeklish)
        ("η", "i"), ("ή", "i"),
        ("ι", "i"), ("ί", "i"), ("ϊ", "i"), ("ΐ", "i"),
        ("υ", "y"), ("ύ", "y"), ("ϋ", "y"), ("ΰ", "y"),
        # e-class
        ("ε", "e"), ("έ", "e"),
        # o-class (ω and ο both → "o")
        ("ο", "o"), ("ό", "o"),
        ("ω", "o"), ("ώ", "o"),
        # a-class (preserved)
        ("α", "a"), ("ά", "a"),
        # Other consonants
        ("β", "v"), ("Β", "V"),
        ("γ", "g"), ("Γ", "G"),
        ("δ", "d"), ("Δ", "D"),
        ("ζ", "z"), ("Ζ", "Z"),
        ("κ", "k"), ("Κ", "K"),
        ("λ", "l"), ("Λ", "L"),
        ("μ", "m"), ("Μ", "M"),
        ("ν", "n"), ("Ν", "N"),
        ("π", "p"), ("Π", "P"),
        ("ρ", "r"), ("Ρ", "R"),
        ("σ", "s"), ("Σ", "S"),
        ("ς", "s"),
        ("τ", "t"), ("Τ", "T"),
        ("φ", "f"), ("Φ", "F"),
    ],
    key=lambda r: -len(r[0]),
)


def inverse_greekify(text: str) -> str:
    """Greek → heuristic Greeklish. Lossy by design."""
    out: List[str] = []
    i = 0
    n = len(text)
    while i < n:
        matched = False
        for src, dst in _RULES:
            if i + len(src) <= n and text[i : i + len(src)] == src:
                out.append(dst)
                i += len(src)
                matched = True
                break
        if not matched:
            out.append(text[i])
            i += 1
    return "".join(out)
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.eval.tests.test_inverse_greekify -v
```

Expected: all 9 tests pass. (The two round-trip placeholder tests just check ASCII-ness; they'll be expanded in Task 5.)

- [ ] **Step 5: Commit**

```bash
git add dict_generation/eval/inverse_greekify.py \
        dict_generation/eval/tests/test_inverse_greekify.py
git commit -m "tier-c-eval: add inverse_greekify (heuristic Greek → Greeklish)"
```

---

## Task 5: Perturbation generators

**Files:**
- Create: `dict_generation/eval/perturbations.py`
- Create: `dict_generation/eval/tests/test_perturbations.py`

Four perturbation classes, each as a function that takes a Greek word and yields zero or more `(input, perturbation_class_name)` pairs. The classes:

1. `identity(w)` — yield `(w, "identity")` once.
2. `unaccented(w)` — yield `(w_without_diacritics, "unaccented")` once.
3. `vowel_swap(w)` — for each i-class vowel position in `w`, yield variants where that single position is replaced by other i-class members.
4. `greekified_latin(w)` — yield `(greekify(inverse_greekify(w)), "greekified_latin")`. We need to import the existing Phase 1 `greekify` — but there isn't a Python implementation yet (only Swift). For Phase 1.5 we approximate it by leveraging the existing `phonetic_fold` rules in reverse-of-reverse — see implementation.

For class 4, we don't have a Python `greekify`. The simplest workable approach: feed `inverse_greekify(w)` directly into the **phonetic fold's** matcher for an approximate round trip. That's what runtime evaluation will eventually do anyway: the Swift runtime calls `greekify` first then `phonetic_fold`. Folding the Latin form via the same rules in `phonetic_fold.json` produces a comparable fold key.

Actually a cleaner approach: just emit the greekified-Latin string AS-IS as the eval input. The eval pipeline (Task 8) folds whatever input we give it — so we can pass the raw Latin string. The fold rules pass through unmapped chars unchanged, so Latin chars reach the recall comparison as-is. Whether the variant returns the expected Greek word depends on whether its DAWG also stores the Latin string as a key — which it doesn't, because the DAWG is keyed by folded Greek. So this perturbation class effectively measures "does folding the Latin input land on a known Greek key?" — which is the wrong thing.

**Correct approach:** simulate the runtime pipeline. The Swift runtime does `phonetic_fold(greekify(input))` for Latin input. We mirror this in Python by:

```
greeklish = inverse_greekify(word)
# Re-greekify by reversing the fold target back into Greek-ish (but lossy).
# Easier: bake a small Python greekify into perturbations.py that mirrors
# the *order-sensitive* digraph logic from CypriotKeyboardHelper.greekify
# in CypriotKeyboardUtil.swift.
```

We add a small `_greekify_python` helper inside `perturbations.py` that ports the Swift `greekify` switch table to Python. This is duplicated logic, but it's tightly scoped to eval, and Phase 2 will provide a Swift-side test that the two implementations agree.

- [ ] **Step 1: Write failing tests**

Write `dict_generation/eval/tests/test_perturbations.py`:

```python
import unittest
from dict_generation.eval.perturbations import (
    identity, unaccented, vowel_swap, greekified_latin,
    _greekify_python,
)


class IdentityTests(unittest.TestCase):
    def test_yields_word_once(self):
        self.assertEqual(list(identity("καλημέρα")), [("καλημέρα", "identity")])


class UnaccentedTests(unittest.TestCase):
    def test_strips_acute_accent(self):
        self.assertEqual(list(unaccented("καλημέρα")), [("καλημερα", "unaccented")])

    def test_strips_diaeresis(self):
        self.assertEqual(list(unaccented("προϋπόθεση")), [("προυποθεση", "unaccented")])

    def test_unchanged_when_no_accents(self):
        self.assertEqual(list(unaccented("νερο")), [("νερο", "unaccented")])


class VowelSwapTests(unittest.TestCase):
    def test_single_eta_word_emits_swaps_to_iota_and_upsilon(self):
        # "καλημερα" has η at position 3. Swaps: ι, υ.
        results = list(vowel_swap("καλημερα"))
        # Each result is (perturbed_word, "vowel_swap").
        words = [w for w, _ in results]
        self.assertIn("καλιμερα", words)
        self.assertIn("καλυμερα", words)
        # Original η should NOT be in the output (we want a *swap*, not identity).
        self.assertNotIn("καλημερα", words)

    def test_no_i_class_vowels_emits_nothing(self):
        # "νερο" has no η/ι/υ — we don't synthesize i-class vowels from nowhere.
        self.assertEqual(list(vowel_swap("νερο")), [])

    def test_class_label(self):
        for _, label in vowel_swap("καλημερα"):
            self.assertEqual(label, "vowel_swap")


class GreekifiedLatinTests(unittest.TestCase):
    def test_yields_one_pair(self):
        results = list(greekified_latin("καλημέρα"))
        self.assertEqual(len(results), 1)
        word, label = results[0]
        self.assertEqual(label, "greekified_latin")
        # The output is the result of inverse_greekify then re-greekify.
        # Greek input is preserved in the i-position (η→i→ι), but vowels
        # collapse, so we expect the result to differ from the original.
        self.assertNotEqual(word, "καλημέρα")
        # The result must be all-Greek (the re-greekify wraps Latin back in Greek).
        self.assertTrue(all(not ch.isascii() or not ch.isalpha() for ch in word),
                        f"unexpected Latin in output: {word!r}")


class GreekifyPythonTests(unittest.TestCase):
    def test_basic_kalimera(self):
        self.assertEqual(_greekify_python("kalimera"), "καλιμερα")

    def test_digraph_th(self):
        self.assertEqual(_greekify_python("theos"), "θεοσ")

    def test_b_becomes_mp(self):
        self.assertEqual(_greekify_python("b"), "μπ")

    def test_pass_through_greek(self):
        # Greek input passes through unchanged — none of the rules match.
        self.assertEqual(_greekify_python("καλιμερα"), "καλιμερα")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run, verify failure**

```bash
python3 -m unittest dict_generation.eval.tests.test_perturbations -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.perturbations`.

- [ ] **Step 3: Implement**

Write `dict_generation/eval/perturbations.py`:

```python
"""Perturbation generators for the eval harness.

Four classes:
- identity: word as-is
- unaccented: combining diacritics stripped
- vowel_swap: each i-class vowel position swapped with another i-class member
- greekified_latin: word → inverse_greekify → _greekify_python (simulates the
  Swift runtime's Greeklish → Greek transliteration before phonetic fold)

Each yields (perturbed_word, perturbation_class_name) tuples.
"""
import unicodedata
from typing import Iterator, Tuple

from dict_generation.eval.inverse_greekify import inverse_greekify


# ---- identity -------------------------------------------------------------

def identity(word: str) -> Iterator[Tuple[str, str]]:
    yield (word, "identity")


# ---- unaccented -----------------------------------------------------------

def unaccented(word: str) -> Iterator[Tuple[str, str]]:
    """Strip combining diacritics; emit the bare-bones form."""
    nfd = unicodedata.normalize("NFD", word)
    stripped = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    nfc = unicodedata.normalize("NFC", stripped)
    yield (nfc, "unaccented")


# ---- vowel_swap -----------------------------------------------------------

_I_CLASS = ["η", "ι", "υ"]  # single-char i-class vowels we swap among


def vowel_swap(word: str) -> Iterator[Tuple[str, str]]:
    """For each i-class vowel position, yield a variant with that position
    replaced by each other i-class member."""
    for i, ch in enumerate(word):
        if ch in _I_CLASS:
            for replacement in _I_CLASS:
                if replacement != ch:
                    yield (word[:i] + replacement + word[i + 1:], "vowel_swap")


# ---- greekified_latin -----------------------------------------------------

# Port of CypriotKeyboardHelper.greekify() in
# Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift. Mirrors that switch
# table EXACTLY — including its quirks (e.g. NGK → γκ outputs lowercase Greek).
#
# Phase 2 will add a cross-language test that this port and the Swift original
# agree on a corpus of inputs. Until then, any discrepancy is a bug here.
_GREEKIFY_RULES = [
    # Trigraphs first
    ("ngk", "γκ"), ("NGK", "γκ"),  # both produce lowercase γκ per Swift
    ("ths", "τησ"),
    ("Ths", "Τησ"), ("THS", "Τησ"),
    # 2-char digraphs
    ("sh", "σ̆"),
    ("Sh", "Σ̆"), ("SH", "Σ̆"),
    ("ch", "τσ̆"),
    ("Ch", "Τσ̆"), ("CH", "Τσ̆"),
    ("ps", "ψ"),
    ("Ps", "Ψ"), ("PS", "Ψ"),
    ("ks", "ξ"),
    ("Ks", "Ξ"), ("KS", "Ξ"),
    ("Th", "Θ"), ("TH", "Θ"),
    ("th", "θ"),
    ("yi", "γι"),
    ("Yi", "Γι"), ("YI", "Γι"),
    ("ng", "γκ"), ("NG", "γκ"),  # both lowercase γκ per Swift
    # Single-char fallback (Swift: greekifySingle)
    ("a", "α"), ("A", "Α"),
    ("i", "ι"), ("I", "Ι"),
    ("e", "ε"), ("E", "Ε"),
    ("o", "ο"), ("O", "Ο"),
    ("u", "υ"), ("U", "Υ"),
    ("y", "υ"), ("Y", "Υ"),
    ("w", "ω"), ("W", "Ω"),
    ("r", "ρ"), ("R", "Ρ"),
    ("t", "τ"), ("T", "Τ"),
    ("p", "π"), ("P", "Π"),
    ("s", "σ"), ("S", "Σ"),
    ("d", "δ"), ("D", "Δ"),
    ("f", "φ"), ("F", "Φ"),
    ("g", "γ"), ("G", "Γ"),
    ("h", "η"), ("H", "Η"),
    ("k", "κ"), ("K", "Κ"),
    ("l", "λ"), ("L", "Λ"),
    ("z", "ζ"), ("Z", "Ζ"),
    ("x", "χ"), ("X", "Χ"),
    ("c", "κ"), ("C", "Κ"),
    ("v", "β"), ("V", "Β"),
    ("b", "μπ"), ("B", "Μπ"),
    ("n", "ν"), ("N", "Ν"),
    ("m", "μ"), ("M", "Μ"),
    ("j", "τζ̆"), ("J", "Τζ̆"),
    ("3", "ξ"),
]
_GREEKIFY_RULES.sort(key=lambda r: -len(r[0]))


def _greekify_python(text: str) -> str:
    """Port of CypriotKeyboardHelper.greekify(). Used only for eval.
    Phase 2 will add a Swift-side test that the two implementations agree."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        matched = False
        for src, dst in _GREEKIFY_RULES:
            if i + len(src) <= n and text[i:i + len(src)] == src:
                out.append(dst)
                i += len(src)
                matched = True
                break
        if not matched:
            out.append(text[i])
            i += 1
    return "".join(out)


def greekified_latin(word: str) -> Iterator[Tuple[str, str]]:
    """word → inverse_greekify → _greekify_python. Simulates the user typing
    in Latin and the Swift greekify() converting it to Greek."""
    latin = inverse_greekify(word)
    re_greek = _greekify_python(latin)
    yield (re_greek, "greekified_latin")
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.eval.tests.test_perturbations -v
```

Expected: 13 tests pass (1 identity + 3 unaccented + 3 vowel_swap + 1 greekified_latin + 4 greekify_python). If `test_b_becomes_mp` fails because of `b` → `μπ` ordering, the trigraph/digraph table is wrong — re-check.

- [ ] **Step 5: Sanity-spot the four classes on a real word**

```bash
python3 -c "
from dict_generation.eval.perturbations import identity, unaccented, vowel_swap, greekified_latin
for fn in (identity, unaccented, vowel_swap, greekified_latin):
    print(fn.__name__, '->', list(fn('καλημέρα')))
"
```

Expected output (approximate):
```
identity -> [('καλημέρα', 'identity')]
unaccented -> [('καλημερα', 'unaccented')]
vowel_swap -> [('καλιμέρα', 'vowel_swap'), ('καλυμέρα', 'vowel_swap')]
greekified_latin -> [('καλιμερα', 'greekified_latin')]
```

(`vowel_swap` operates on the original word with its accent intact — accented vowels aren't swapped because they're in the `_I_CLASS` list as bare characters and `έ` doesn't match `η/ι/υ`. That's a known limitation; it's still useful — we get vowel-swap variants for unaccented sources.)

- [ ] **Step 6: Commit**

```bash
git add dict_generation/eval/perturbations.py \
        dict_generation/eval/tests/test_perturbations.py
git commit -m "tier-c-eval: add 4 perturbation generators (identity / unaccented / vowel-swap / greekified-Latin)"
```

---

## Task 6: Variant builders

**Files:**
- Modify: `dict_generation/build_dawg.py` (extract a parameterized helper)
- Create: `dict_generation/eval/variants.py`
- Create: `dict_generation/eval/tests/test_variants.py`

We refactor `build_dawg.py` so its core logic lives in a single function `build_dawg_to(out_path, ...)` that takes parameters controlling each variant's behavior. The CLI entry point keeps working unchanged. The eval `variants.py` module imports that helper and exposes a function to materialize each of the 6 variants on demand, caching outputs in `/tmp/eval_dawg/<variant>.bin` so re-runs are fast.

- [ ] **Step 1: Read the existing `build_dawg.py`**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
cat dict_generation/build_dawg.py
```

Note the structure: argparse-driven `main()` calls `build(dic, aff, freq, out)`, which expands surface forms, folds, groups, ranks, builds the DAWG, serializes.

- [ ] **Step 2: Refactor `build_dawg.py` to expose a parameterized helper**

Replace `dict_generation/build_dawg.py` with:

```python
#!/usr/bin/env python3
"""Build dict/el_CY.dawg from dict/el_CY.{dic,aff} + corpus_freq.json.

Run from the repo root:
    python3 dict_generation/build_dawg.py
"""
import argparse
import json
import os
import sys
from collections import defaultdict
from typing import Callable, Dict, Iterable, Optional

# Allow running as a script regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import Dawg
from dict_generation.phonetic_fold import load_default_folder


DEFAULT_FREQ = 1


def yield_stems_only(dic_path: str, encoding: str = "UTF-8") -> Iterable[str]:
    """Yield every stem in the .dic, ignoring its flags. Used by V2."""
    with open(dic_path, encoding=encoding) as f:
        seen_count = False
        for raw in f:
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            if not seen_count and s.isdigit():
                seen_count = True
                continue
            seen_count = True
            stem = s.split("/", 1)[0].strip()
            if stem:
                yield stem


def build_dawg_to(
    out_path: str,
    *,
    dic_path: str = "dict/el_CY.dic",
    aff_path: str = "dict/el_CY.aff",
    freq_path: str = "dict_generation/corpus_freq.json",
    surface_form_source: Optional[Callable[..., Iterable[str]]] = None,
    freq_threshold: int = 0,
    top_canonical_only: bool = False,
    quiet: bool = False,
) -> Dict[str, int]:
    """Build a DAWG and write to out_path. Returns a small stats dict.

    Parameters control the variants:
    - surface_form_source: callable returning an iterable of canonical
      strings to insert. Defaults to expanding all surface forms via
      affix application. V2 passes a stems-only yielder.
    - freq_threshold: drop forms whose corpus_freq < this. 0 keeps all.
      1 keeps only forms seen in the corpus. Higher values filter more.
    - top_canonical_only: if True, retain only the highest-frequency
      canonical per fold key (V1, V4 use this).
    """
    def log(msg):
        if not quiet:
            print(msg)

    aff = parse_aff(open(aff_path, encoding="utf-8").read())

    try:
        with open(freq_path, encoding="utf-8") as f:
            corpus_freq: Dict[str, int] = json.load(f)
    except FileNotFoundError:
        log(f"[build_dawg] WARNING: {freq_path} not found; freqs default to {DEFAULT_FREQ}")
        corpus_freq = {}

    if surface_form_source is None:
        def _default_source():
            return expand_dic_file(dic_path, aff)
        surface_form_source = _default_source

    folder = load_default_folder()
    grouped: Dict[str, Dict[str, int]] = defaultdict(dict)
    n_in = 0
    n_kept = 0
    for surface in surface_form_source():
        n_in += 1
        freq = corpus_freq.get(surface.lower(), DEFAULT_FREQ)
        if freq < freq_threshold:
            continue
        n_kept += 1
        key = folder.fold(surface)
        prev = grouped[key].get(surface, 0)
        if freq > prev:
            grouped[key][surface] = freq

    log(f"[build_dawg] {n_in} input forms, {n_kept} kept after threshold, {len(grouped)} unique fold keys")

    string_index: Dict[str, int] = {}
    strings = []
    payloads = []
    sorted_keys = sorted(grouped.keys())
    payload_for_key: Dict[str, int] = {}
    for key in sorted_keys:
        canonical_forms = grouped[key]
        ranked = sorted(canonical_forms.items(), key=lambda kv: (-kv[1], kv[0]))
        if top_canonical_only:
            ranked = ranked[:1]
        entry = []
        for form, freq in ranked:
            idx = string_index.get(form)
            if idx is None:
                idx = len(strings)
                string_index[form] = idx
                strings.append(form)
            entry.append((idx, freq))
        payload_for_key[key] = len(payloads)
        payloads.append(entry)

    dawg = Dawg()
    for key in sorted_keys:
        dawg.insert_sorted(key, payload=payload_for_key[key])
    dawg.finalize()

    with open(out_path, "wb") as out:
        dawg.serialize(out, payloads=payloads, strings=strings)
    size = os.path.getsize(out_path)
    log(f"[build_dawg] {out_path}: {size:,} bytes ({size/1024/1024:.2f} MB), {dawg.node_count()} nodes")

    return {
        "input_forms": n_in,
        "kept_forms": n_kept,
        "fold_keys": len(grouped),
        "dawg_nodes": dawg.node_count(),
        "bytes": size,
    }


def build(dic_path: str, aff_path: str, freq_path: str, out_path: str) -> None:
    """Default-variant build (used by the CLI). Equivalent to baseline."""
    build_dawg_to(
        out_path,
        dic_path=dic_path,
        aff_path=aff_path,
        freq_path=freq_path,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dic", default="dict/el_CY.dic")
    parser.add_argument("--aff", default="dict/el_CY.aff")
    parser.add_argument("--freq", default="dict_generation/corpus_freq.json")
    parser.add_argument("--out", default="dict/el_CY.dawg")
    args = parser.parse_args()
    build(args.dic, args.aff, args.freq, args.out)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Verify the CLI entry point still works**

```bash
python3 dict_generation/build_dawg.py --out /tmp/dawg_smoke.bin 2>&1 | tail -5
ls -lh /tmp/dawg_smoke.bin
```

Expected: same output as before — ~47 MB. Cleanup: `rm /tmp/dawg_smoke.bin`.

- [ ] **Step 4: Write failing tests for variants.py**

Write `dict_generation/eval/tests/test_variants.py`:

```python
import os
import unittest
from dict_generation.eval.variants import build_variant, VARIANT_NAMES


class VariantsTests(unittest.TestCase):

    def test_known_variant_names(self):
        self.assertEqual(
            set(VARIANT_NAMES),
            {"baseline", "v1_top1", "v2_stems", "v3_freq1", "v3_freq2", "v4_top1_freq1"},
        )

    def test_build_baseline_produces_file(self):
        path, stats = build_variant("baseline", cache_dir="/tmp/eval_dawg")
        self.assertTrue(os.path.exists(path))
        self.assertGreater(stats["bytes"], 0)
        self.assertGreater(stats["dawg_nodes"], 0)

    def test_build_v3_freq2_produces_smaller_file_than_baseline(self):
        baseline_path, baseline_stats = build_variant("baseline", cache_dir="/tmp/eval_dawg")
        v3_path, v3_stats = build_variant("v3_freq2", cache_dir="/tmp/eval_dawg")
        self.assertLess(v3_stats["bytes"], baseline_stats["bytes"])

    def test_unknown_variant_raises(self):
        with self.assertRaises(KeyError):
            build_variant("nonsense", cache_dir="/tmp/eval_dawg")


if __name__ == "__main__":
    unittest.main()
```

(These tests are slow — they actually build DAWGs. Run them once at the end of the task; don't expect them to be part of the inner-loop.)

- [ ] **Step 5: Run, verify failure**

```bash
python3 -m unittest dict_generation.eval.tests.test_variants -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.variants`.

- [ ] **Step 6: Implement variants.py**

Write `dict_generation/eval/variants.py`:

```python
"""Build any of the 6 candidate DAWG variants on demand.

Variants:
- baseline    : full pipeline, all surface forms, all canonicals per key
- v1_top1     : full pipeline, top-1 canonical per key
- v2_stems    : stems only (skip affix expansion); each stem is its own canonical
- v3_freq1    : drop forms with corpus_freq < 1 (i.e. corpus-attested only)
- v3_freq2    : drop forms with corpus_freq < 2 (drop singletons)
- v4_top1_freq1: combine v1 + v3@1

Each variant is cached in <cache_dir>/<variant>.bin so repeated runs are fast.
"""
import os
from typing import Tuple, Dict

from dict_generation.build_dawg import build_dawg_to, yield_stems_only


VARIANT_NAMES = (
    "baseline",
    "v1_top1",
    "v2_stems",
    "v3_freq1",
    "v3_freq2",
    "v4_top1_freq1",
)


_VARIANT_CONFIGS: Dict[str, dict] = {
    "baseline":       dict(freq_threshold=0,          top_canonical_only=False),
    "v1_top1":        dict(freq_threshold=0,          top_canonical_only=True),
    "v2_stems":       dict(freq_threshold=0,          top_canonical_only=False, stems_only=True),
    "v3_freq1":       dict(freq_threshold=1,          top_canonical_only=False),
    "v3_freq2":       dict(freq_threshold=2,          top_canonical_only=False),
    "v4_top1_freq1":  dict(freq_threshold=1,          top_canonical_only=True),
}


def build_variant(name: str, cache_dir: str = "/tmp/eval_dawg",
                  dic_path: str = "dict/el_CY.dic",
                  aff_path: str = "dict/el_CY.aff",
                  freq_path: str = "dict_generation/corpus_freq.json",
                  force: bool = False) -> Tuple[str, dict]:
    """Build (or reuse cached) variant. Returns (path_to_dawg_file, stats_dict)."""
    if name not in _VARIANT_CONFIGS:
        raise KeyError(f"unknown variant {name!r}; valid: {VARIANT_NAMES}")
    os.makedirs(cache_dir, exist_ok=True)
    out_path = os.path.join(cache_dir, f"{name}.bin")
    stats_path = out_path + ".stats.json"

    cfg = dict(_VARIANT_CONFIGS[name])  # copy
    stems_only = cfg.pop("stems_only", False)

    if not force and os.path.exists(out_path) and os.path.exists(stats_path):
        import json
        with open(stats_path, encoding="utf-8") as f:
            return out_path, json.load(f)

    surface_form_source = None
    if stems_only:
        def surface_form_source():
            return yield_stems_only(dic_path)

    stats = build_dawg_to(
        out_path,
        dic_path=dic_path,
        aff_path=aff_path,
        freq_path=freq_path,
        surface_form_source=surface_form_source,
        quiet=True,
        **cfg,
    )

    import json
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)
    return out_path, stats
```

- [ ] **Step 7: Run, verify all variants build (slow — 5-10 min total)**

```bash
python3 -c "
from dict_generation.eval.variants import VARIANT_NAMES, build_variant
for name in VARIANT_NAMES:
    path, stats = build_variant(name)
    print(f'{name:18s} {stats[\"bytes\"]:>12,} bytes  {stats[\"dawg_nodes\"]:>10,} nodes')
"
```

Expected: all 6 variants build successfully. Sizes should match the previous experiment table approximately:
- baseline: ~47 MB, ~1.4M nodes
- v1_top1: ~45 MB
- v2_stems: ~38 MB
- v3_freq1: ~2.7 MB
- v3_freq2: ~1.5 MB
- v4_top1_freq1: ~2.65 MB

If any variant fails to build or sizes diverge wildly from those numbers, investigate before moving on.

- [ ] **Step 8: Run unit tests**

```bash
python3 -m unittest dict_generation.eval.tests.test_variants -v
```

Expected: 4 tests pass (cached results are reused, so this is fast after Step 7).

- [ ] **Step 9: Commit**

```bash
git add dict_generation/build_dawg.py \
        dict_generation/eval/variants.py \
        dict_generation/eval/tests/test_variants.py
git commit -m "tier-c-eval: add variant builder; refactor build_dawg.py for parameterization"
```

---

## Task 7: Hunspell baseline runner

**Files:**
- Create: `dict_generation/eval/hunspell_runner.py`
- Create: `dict_generation/eval/tests/test_hunspell_runner.py`

Wraps the system `hunspell` binary as a subprocess. Hunspell's pipe-mode output (`hunspell -d el_CY -a`) is the standard "ispell" format documented in `man hunspell`:

```
*               # correctly spelled, no suggestions
+ <stem>        # correctly spelled, here's the stem
& <word> <count> <offset>: <sugg1>, <sugg2>, ...
# <word> <offset>     # misspelled, no suggestions
```

We parse this format. The dict at `dict/el_CY.{dic,aff}` is fed to `hunspell` directly via the `-d` flag (which expects a basename to lookup; we point it at our actual files via the `DICPATH` env var).

- [ ] **Step 1: Verify Hunspell is available**

```bash
which hunspell || echo "MISSING: install hunspell"
hunspell --version 2>&1 | head -2
```

Expected: hunspell binary on PATH. If missing: install via `brew install hunspell` (macOS) and re-try.

- [ ] **Step 2: Write failing tests**

Write `dict_generation/eval/tests/test_hunspell_runner.py`:

```python
import shutil
import unittest
from dict_generation.eval.hunspell_runner import suggest_via_hunspell, HunspellNotAvailable


@unittest.skipIf(shutil.which("hunspell") is None, "hunspell binary not on PATH")
class HunspellRunnerTests(unittest.TestCase):

    def test_known_correct_word_returns_no_suggestions_or_self(self):
        # 'και' is a high-frequency Greek word and should be correctly
        # spelled per the dict.
        suggestions = suggest_via_hunspell("και")
        # Either Hunspell says "correct" (empty list), or it returns 'και'
        # in its suggestions. Both are valid.
        self.assertTrue(len(suggestions) == 0 or "και" in suggestions)

    def test_misspelled_word_returns_suggestions(self):
        # 'καλιμερα' (using ι instead of η) should suggest 'καλημέρα'.
        suggestions = suggest_via_hunspell("καλιμερα")
        # We can't pin the exact list, but the expected correction must be in it.
        self.assertIn("καλημέρα", suggestions,
                      f"expected 'καλημέρα' in suggestions, got: {suggestions[:5]}")

    def test_garbage_returns_few_or_no_suggestions(self):
        suggestions = suggest_via_hunspell("zzzzzzzz")
        # No assertion on count — just that the function doesn't crash.
        self.assertIsInstance(suggestions, list)


class HunspellMissingTests(unittest.TestCase):

    def test_helpful_error_when_binary_absent(self):
        # We can't actually remove hunspell for this test, but we can test
        # the error type is exported and importable.
        self.assertTrue(issubclass(HunspellNotAvailable, RuntimeError))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run, verify failure**

```bash
python3 -m unittest dict_generation.eval.tests.test_hunspell_runner -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.hunspell_runner`.

- [ ] **Step 4: Implement**

Write `dict_generation/eval/hunspell_runner.py`:

```python
"""Subprocess wrapper for the system `hunspell` binary.

Used by the Phase 1.5 eval harness to compare Hunspell's suggestion output
against each DAWG variant's. Hunspell loads dict/el_CY.{dic,aff}; we point
it there via the DICPATH environment variable.

Output format reference: `man 5 hunspell` (ispell pipe protocol).
"""
import os
import shutil
import subprocess
from typing import List


class HunspellNotAvailable(RuntimeError):
    pass


_DICT_BASE = "el_CY"  # picks up el_CY.dic + el_CY.aff in DICPATH


def _dictpath() -> str:
    """Return an absolute path to the directory holding el_CY.dic/aff."""
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dict"))


def suggest_via_hunspell(word: str) -> List[str]:
    """Return the list of Hunspell suggestions for `word`.

    If the word is correctly spelled, returns []. (Caller can compare
    word == expected separately for the identity case.)
    """
    if shutil.which("hunspell") is None:
        raise HunspellNotAvailable("hunspell binary not on PATH")

    env = os.environ.copy()
    env["DICPATH"] = _dictpath()

    proc = subprocess.run(
        ["hunspell", "-d", _DICT_BASE, "-a"],
        input=word + "\n",
        capture_output=True,
        text=True,
        env=env,
        encoding="utf-8",
    )
    return _parse_pipe_output(proc.stdout)


def _parse_pipe_output(output: str) -> List[str]:
    """Parse hunspell -a's pipe output and return the suggestion list."""
    # Skip the banner ('@(#) International Ispell ...'), find the first
    # non-empty line that's a result indicator, parse its suggestions.
    for raw in output.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("@"):
            continue  # banner
        if line.startswith("*") or line.startswith("+"):
            return []  # correctly spelled
        if line.startswith("#"):
            return []  # misspelled, no suggestions
        if line.startswith("&"):
            # Format: "& <word> <count> <offset>: <sugg1>, <sugg2>, ..."
            _, _, after_colon = line.partition(":")
            return [s.strip() for s in after_colon.split(",") if s.strip()]
    return []
```

- [ ] **Step 5: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.eval.tests.test_hunspell_runner -v
```

Expected: 4 tests pass (3 + 1 skip-aware error test). If `test_misspelled_word_returns_suggestions` fails, hunspell can't find the dict — confirm `DICPATH` is correct and `dict/el_CY.dic` exists.

- [ ] **Step 6: Commit**

```bash
git add dict_generation/eval/hunspell_runner.py \
        dict_generation/eval/tests/test_hunspell_runner.py
git commit -m "tier-c-eval: add Hunspell subprocess runner + pipe-output parser"
```

---

## Task 8: Recall evaluator

**Files:**
- Create: `dict_generation/eval/recall.py`
- Create: `dict_generation/eval/tests/test_recall.py`

Two evaluators: one for DAWG variants (`recall_for_dawg`), one for Hunspell (`recall_for_hunspell`). Both consume `(input, expected_canonical)` pairs and report whether `expected_canonical` is found in the lookup result.

- [ ] **Step 1: Write failing tests**

Write `dict_generation/eval/tests/test_recall.py`:

```python
import os
import shutil
import unittest

from dict_generation.eval.recall import (
    found_in_dawg,
    found_in_hunspell,
    compute_recall,
)
from dict_generation.eval.variants import build_variant


class FoundInDawgTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.path, _ = build_variant("baseline")

    def test_known_word_found(self):
        self.assertTrue(found_in_dawg(self.path, "καλημέρα", "καλημέρα"))

    def test_phonetic_alternate_found(self):
        # 'καλιμερα' folds to the same key as 'καλημέρα'; the canonical
        # 'καλημέρα' is in the canonical-form list for that key.
        self.assertTrue(found_in_dawg(self.path, "καλιμερα", "καλημέρα"))

    def test_unrelated_input_not_found(self):
        self.assertFalse(found_in_dawg(self.path, "καλημέρα", "νερό"))


@unittest.skipIf(shutil.which("hunspell") is None, "hunspell binary not on PATH")
class FoundInHunspellTests(unittest.TestCase):

    def test_correct_word_when_input_equals_expected(self):
        # 'καλημέρα' is a known correct word; expected = input → found.
        self.assertTrue(found_in_hunspell("καλημέρα", "καλημέρα"))

    def test_misspelled_finds_correction(self):
        # 'καλιμερα' should produce 'καλημέρα' in the suggestion list.
        self.assertTrue(found_in_hunspell("καλιμερα", "καλημέρα"))


class ComputeRecallTests(unittest.TestCase):

    def test_recall_basic(self):
        pairs = [("a", "x"), ("b", "x"), ("c", "x")]
        # found_fn returns True iff input is "a" or "b"
        recall = compute_recall(pairs, lambda inp, exp: inp in {"a", "b"})
        self.assertEqual(recall, 2 / 3)

    def test_recall_empty(self):
        recall = compute_recall([], lambda inp, exp: True)
        self.assertEqual(recall, 0.0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run, verify failure**

```bash
python3 -m unittest dict_generation.eval.tests.test_recall -v 2>&1 | head -10
```

Expected: ImportError on `dict_generation.eval.recall`.

- [ ] **Step 3: Implement**

Write `dict_generation/eval/recall.py`:

```python
"""Recall computation per (variant, perturbation_class).

Two backends:
- found_in_dawg(variant_path, input, expected): folds input, looks up
  in the DAWG, returns True if expected is among the canonical forms.
- found_in_hunspell(input, expected): runs hunspell, returns True if
  expected is among suggestions (or input itself when correctly spelled).
"""
from typing import Callable, Iterable, Tuple

from dict_generation.dawg import DawgReader
from dict_generation.eval.hunspell_runner import suggest_via_hunspell
from dict_generation.phonetic_fold import load_default_folder


_FOLDER = None
_DAWG_CACHE = {}  # path -> DawgReader (so we don't re-mmap per call)


def _get_folder():
    global _FOLDER
    if _FOLDER is None:
        _FOLDER = load_default_folder()
    return _FOLDER


def _get_reader(path: str) -> DawgReader:
    reader = _DAWG_CACHE.get(path)
    if reader is None:
        with open(path, "rb") as f:
            reader = DawgReader(f.read())
        _DAWG_CACHE[path] = reader
    return reader


def found_in_dawg(variant_path: str, input_word: str, expected: str) -> bool:
    folder = _get_folder()
    reader = _get_reader(variant_path)
    key = folder.fold(input_word)
    pidx = reader.payload_for(key)
    if pidx is None:
        return False
    canonicals = [c for c, _f in reader.canonical_forms(pidx)]
    return expected in canonicals


def found_in_hunspell(input_word: str, expected: str) -> bool:
    suggestions = suggest_via_hunspell(input_word)
    if not suggestions:
        # No suggestions: hunspell either said "correct" or had nothing to offer.
        # We treat input == expected as a hit in the "correct" case.
        return input_word == expected
    return expected in suggestions


def compute_recall(pairs: Iterable[Tuple[str, str]],
                   found_fn: Callable[[str, str], bool]) -> float:
    pairs = list(pairs)
    if not pairs:
        return 0.0
    hits = sum(1 for inp, exp in pairs if found_fn(inp, exp))
    return hits / len(pairs)
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.eval.tests.test_recall -v
```

Expected: all tests pass. The Hunspell tests may be skipped if hunspell is missing.

- [ ] **Step 5: Commit**

```bash
git add dict_generation/eval/recall.py \
        dict_generation/eval/tests/test_recall.py
git commit -m "tier-c-eval: add recall computation (DAWG + Hunspell evaluators)"
```

---

## Task 9: Orchestrator + report generator

**Files:**
- Create: `dict_generation/eval/main.py`

The orchestrator wires everything: ground-truth → perturbations → for each variant + Hunspell → for each perturbation class → recall. Emits a markdown table to `dict_generation/eval/results.md`.

This task is a one-off integration script; we skip a full TDD test suite and verify by running the script end-to-end.

- [ ] **Step 1: Write the orchestrator**

Write `dict_generation/eval/main.py`:

```python
#!/usr/bin/env python3
"""Run the full eval pipeline and emit results.md.

Usage (from the repo root):
    python3 dict_generation/eval/main.py
    python3 dict_generation/eval/main.py --top-n 1000 --skip-hunspell
"""
import argparse
import os
import shutil
import sys
from collections import defaultdict
from typing import List, Tuple

# Allow running as a script regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dict_generation.eval.ground_truth import build_ground_truth
from dict_generation.eval.perturbations import (
    identity, unaccented, vowel_swap, greekified_latin,
)
from dict_generation.eval.variants import VARIANT_NAMES, build_variant
from dict_generation.eval.recall import found_in_dawg, found_in_hunspell, compute_recall


PERTURBATION_FNS = [
    ("identity", identity),
    ("unaccented", unaccented),
    ("vowel_swap", vowel_swap),
    ("greekified_latin", greekified_latin),
]


def generate_pairs(words: List[str]) -> List[Tuple[str, str, str]]:
    """For each ground-truth word, generate (input, expected, perturbation_class) tuples."""
    pairs = []
    for w in words:
        for class_name, fn in PERTURBATION_FNS:
            for perturbed, label in fn(w):
                assert label == class_name, f"perturbation label mismatch: {label} vs {class_name}"
                pairs.append((perturbed, w, class_name))
    return pairs


def run_eval(top_n: int, skip_hunspell: bool, out_path: str) -> None:
    print(f"[eval] building ground truth (top_n={top_n})")
    words = build_ground_truth(
        "dict_generation/corpus_freq.json",
        "dict_generation/eval/common_words.json",
        top_n=top_n,
    )
    print(f"[eval] {len(words)} ground-truth words")

    pairs = generate_pairs(words)
    print(f"[eval] {len(pairs)} (input, expected, class) tuples")
    by_class = defaultdict(list)
    for inp, exp, cls in pairs:
        by_class[cls].append((inp, exp))
    for cls, items in by_class.items():
        print(f"[eval]   {cls}: {len(items)}")

    print(f"[eval] building all variants")
    variant_paths = {}
    variant_stats = {}
    for name in VARIANT_NAMES:
        path, stats = build_variant(name)
        variant_paths[name] = path
        variant_stats[name] = stats
        size_mb = stats["bytes"] / (1024 * 1024)
        print(f"[eval]   {name:18s} {size_mb:6.2f} MB")

    print(f"[eval] computing DAWG variant recall")
    results = {}  # results[variant_name][perturbation_class] = recall
    for name in VARIANT_NAMES:
        path = variant_paths[name]
        results[name] = {}
        for cls, items in by_class.items():
            recall = compute_recall(items, lambda inp, exp: found_in_dawg(path, inp, exp))
            results[name][cls] = recall
            print(f"[eval]   {name:18s} {cls:18s} {recall:.3f}")

    if not skip_hunspell and shutil.which("hunspell"):
        print(f"[eval] computing Hunspell baseline recall (slow — subprocess per input)")
        results["hunspell"] = {}
        for cls, items in by_class.items():
            recall = compute_recall(items, lambda inp, exp: found_in_hunspell(inp, exp))
            results["hunspell"][cls] = recall
            print(f"[eval]   hunspell           {cls:18s} {recall:.3f}")
    else:
        print(f"[eval] Hunspell skipped")

    print(f"[eval] writing {out_path}")
    write_report(out_path, results, variant_stats, len(words), len(pairs))
    print(f"[eval] done")


def write_report(out_path: str, results: dict, variant_stats: dict,
                 n_words: int, n_pairs: int) -> None:
    classes = ["identity", "unaccented", "vowel_swap", "greekified_latin"]
    lines = []
    lines.append("# Phase 1.5 eval results\n")
    lines.append(f"Auto-generated by `dict_generation/eval/main.py`. Do not edit by hand.\n")
    lines.append(f"\nGround-truth words: **{n_words}**.  Total (input, expected) pairs: **{n_pairs}**.\n")
    lines.append("\n## Recall by variant × perturbation class\n")
    lines.append("\n| Variant | Size (MB) | " + " | ".join(classes) + " | average |")
    lines.append("|---|---:|" + "|".join(["---:"] * (len(classes) + 1)) + "|")

    for name in list(results.keys()):
        if name == "hunspell":
            size_str = "—"
        else:
            stats = variant_stats.get(name, {})
            size_mb = stats.get("bytes", 0) / (1024 * 1024)
            size_str = f"{size_mb:.2f}"
        cells = []
        recalls = []
        for cls in classes:
            r = results[name].get(cls)
            if r is None:
                cells.append("—")
            else:
                cells.append(f"{r*100:.1f}%")
                recalls.append(r)
        avg = sum(recalls) / len(recalls) if recalls else 0
        cells.append(f"{avg*100:.1f}%")
        lines.append(f"| `{name}` | {size_str} | " + " | ".join(cells) + " |")

    lines.append("\n## Variant build stats\n")
    lines.append("\n| Variant | Input forms | Kept | Fold keys | Nodes | Bytes |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for name in VARIANT_NAMES:
        s = variant_stats.get(name, {})
        lines.append(
            f"| `{name}` | {s.get('input_forms', 0):,} | {s.get('kept_forms', 0):,} | "
            f"{s.get('fold_keys', 0):,} | {s.get('dawg_nodes', 0):,} | {s.get('bytes', 0):,} |"
        )

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--top-n", type=int, default=500)
    parser.add_argument("--skip-hunspell", action="store_true")
    parser.add_argument("--out", default="dict_generation/eval/results.md")
    args = parser.parse_args()
    run_eval(args.top_n, args.skip_hunspell, args.out)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run end-to-end (slow — 5–15 minutes)**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 dict_generation/eval/main.py 2>&1 | tail -40
```

Expected: variants build (cached after Task 6), recall numbers print per (variant, class), Hunspell baseline runs, `results.md` is written.

- [ ] **Step 3: Spot-check the report**

```bash
cat dict_generation/eval/results.md
```

Expected: a markdown table showing recall per variant per class, plus a build-stats table. Recall numbers should be plausible (identity ≥ 90% for variants that contain the words; greekified_latin lower).

- [ ] **Step 4: Commit**

```bash
git add dict_generation/eval/main.py dict_generation/eval/results.md
git commit -m "tier-c-eval: add orchestrator + first results.md

Runs ground-truth → perturbations → all 6 variants + Hunspell baseline,
emits a recall-by-perturbation comparison table. results.md is committed
so future re-runs can be diffed in PR review."
```

---

## Task 10: Makefile target

**Files:**
- Modify: `dict_generation/Makefile`

Add an `eval` target that runs the orchestrator. The Makefile uses cwd-relative paths (it `cd`s into `dict_generation/` for its existing recipes), so the `eval` target needs to call out to the repo root.

- [ ] **Step 1: Read existing Makefile structure**

```bash
cat dict_generation/Makefile
```

Note: existing recipes run from `dict_generation/` and use paths like `corpus/`, `el_GR/`, `../dict/`.

- [ ] **Step 2: Append the `eval` and `clean_eval` targets**

Edit `dict_generation/Makefile`. **Append** at the end (don't disturb existing recipes):

```makefile

# tier-c Phase 1.5: run the DAWG variant recall eval.
eval:
	cd .. && python3 dict_generation/eval/main.py

eval-no-hunspell:
	cd .. && python3 dict_generation/eval/main.py --skip-hunspell

clean_eval:
	rm -rf /tmp/eval_dawg
	rm -f dict_generation/eval/results.md
```

- [ ] **Step 3: Verify the target works**

```bash
cd dict_generation && make eval-no-hunspell 2>&1 | tail -20
```

Expected: variants get rebuilt (or use cached `/tmp/eval_dawg/*.bin`), recall computed, `results.md` regenerated. With `--skip-hunspell` this should take 1–3 minutes after the first run.

- [ ] **Step 4: Commit**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
git add dict_generation/Makefile
git commit -m "tier-c-eval: add Makefile targets (eval, eval-no-hunspell, clean_eval)"
```

---

## Task 11: Variant decision + final DAWG regeneration

**Files:**
- Modify: `dict/el_CY.dawg` (regenerate with chosen variant)

This isn't a code task — it's the *decision* the Phase 1.5 work was designed to inform. After Task 10, `dict_generation/eval/results.md` contains the recall table. Apply the spec's decision criterion and regenerate `dict/el_CY.dawg` with the chosen variant.

- [ ] **Step 1: Open the report and apply the decision criterion**

```bash
cat dict_generation/eval/results.md
```

Decision criterion (from the spec):
> Pick the smallest variant whose recall on identity + unaccented + vowel-swap + greekified-Latin is within 5 percentage points of baseline.

Identify the chosen variant. If multiple variants tie, prefer the smaller. Document the choice + rationale (a sentence per variant ruled out).

- [ ] **Step 2: Regenerate `dict/el_CY.dawg` with the chosen variant**

If the chosen variant is `baseline` (no win), no regeneration needed. Otherwise:

```bash
# Replace <chosen> with the actual variant name, e.g. v3_freq2
python3 -c "
from dict_generation.eval.variants import build_variant
import shutil
src, _ = build_variant('<chosen>', cache_dir='/tmp/eval_dawg', force=True)
shutil.copy(src, 'dict/el_CY.dawg')
print('regenerated dict/el_CY.dawg from', src)
"
ls -lh dict/el_CY.dawg
```

- [ ] **Step 3: Update the round-trip Phase 1 cross-check** (preview — Task 12 of the Phase 1 plan)

The Phase 1 plan's Task 12 (`test_full_pipeline.py`) will sample-verify the dict against the DAWG. With a filtered variant, some surface forms won't be in the DAWG by design — that test needs adjusting. **Don't fix it here**; just note the implication for the Phase 1 Task 12 plan.

- [ ] **Step 4: Commit the regenerated DAWG**

```bash
git add dict/el_CY.dawg
git commit -m "tier-c: regenerate dict/el_CY.dawg with variant <chosen>

Phase 1.5 eval (see dict_generation/eval/results.md) showed:
- <chosen> recall: X% identity, Y% unaccented, Z% vowel-swap, W% greekified-Latin
- baseline recall: A%, B%, C%, D% (within 5pp on every class)
- size: <chosen> is N MB vs baseline 47 MB

<one-sentence rationale>"
```

(Replace placeholders with the actual numbers from `results.md` and the actual variant name.)

---

## Phase 1.5 done

After Task 11, the build pipeline ships a real, eval-justified `dict/el_CY.dawg`, and the eval harness is checked in for re-running after Phase 2. Phase 1's remaining Tasks 11–12 (Makefile integration for the Phase 1 dawg target — separate from this Phase 1.5 Makefile work — and end-to-end cross-check) can resume from here, with the cross-check adjusted for the chosen variant's expected coverage.

**Final sanity check:**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 -m unittest discover dict_generation -v 2>&1 | tail -5
ls -lh dict/el_CY.dawg
git log --oneline tier-c-dawg --not 1853ec9
```

Expected: all unit tests pass; `dict/el_CY.dawg` size matches the chosen variant; commit history shows Phase 1 (8 commits) + Phase 1.5 (~11 commits) cleanly stacked.
