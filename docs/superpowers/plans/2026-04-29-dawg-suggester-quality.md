# DAWG suggester quality fixes — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gap between the DAWG suggester and the Hunspell baseline on inputs surfaced by `dict_generation/eval/run_corpus.py`. After this plan, "Pafos", "afth", "8a", and Cypriot dialect markers should autocorrect at parity with Hunspell or better.

**Architecture:** Fixes split between (a) the DAWG build pipeline (Python, in `dict_generation/`), (b) the iOS extension (Swift, in `Cypriot  Custom Keyboard/DAWG/` and `CypriotKeyboardUtil.swift`), and (c) the Python eval shadow at `dict_generation/eval/run_corpus.py`. Every Swift change has a Python mirror so `run_corpus.py` keeps tracking iOS behaviour.

**Tech Stack:** Swift 5 / SwiftUI / KeyboardKit 4.5 (iOS extension); Python 3 / Hunspell C++ vendored (eval/build pipeline); xcodebuild test for iOS validation.

---

## File structure

The fixes touch a small set of files. New files in *italics*; modified files are repeated across tasks.

```
Cypriot  Custom Keyboard/
├── CypriotKeyboardUtil.swift                       # shouldReplace + sigma normalization
└── DAWG/
    ├── DamerauLevenshteinSuggester.swift           # ranking changes
    └── DawgAutocompleteSuggestionProvider.swift    # 8↔θ, x↔ξ, shouldReplace caller

Cypriot KeyboardTests/
├── CypriotKeyboardUtilTests.swift                  # NEW — shouldReplace unit tests
├── DamerauLevenshteinSuggesterTests.swift          # add ranking tests
└── DawgIntegrationTests.swift                      # add proper-noun + 8↔θ tests

dict_generation/
├── build_dawg.py                                    # lowercase before fold
├── spyros_list.dic                                  # Cypriot dialect additions
└── eval/
    ├── run_corpus.py                                # mirror Swift fixes
    ├── greeklish_corpus.txt                         # add regression cases
    └── corpus_baseline.md                           # NEW — committed reference output
```

---

## Task 1: DAWG build — lowercase fold keys

**Why this task is first:** every other ranking and lookup task downstream is observed against the DAWG. Rebuilding now gives later tasks a stable reference point.

**Files:**
- Modify: `dict_generation/build_dawg.py:98`
- Regenerate: `dict/el_CY.dawg` via `make dawg`
- Test: `dict_generation/tests/test_build_dawg.py` (extend if exists, else create)
- iOS test fixture: `Cypriot KeyboardTests/Resources/tiny_fixture.dawg` (regenerate via `dict_generation/generate_swift_test_fixtures.py` only if its source dict has cap-first proper nouns — most likely no change needed)

- [ ] **Step 1: Write the failing test**

`dict_generation/tests/test_build_dawg.py`:

```python
"""Lowercased-fold-key proper-noun lookup test."""
import os
import tempfile
from dict_generation.build_dawg import build_dawg_to
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder


def test_proper_noun_reachable_via_lowercase_fold_key():
    """Πάφος should be retrievable from the lowercase fold key 'παφoσ',
    matching the runtime which always lowercases before lookup."""
    folder = load_default_folder()

    def source():
        # Just one cap-first proper noun.
        yield "Πάφος"

    with tempfile.NamedTemporaryFile(suffix=".dawg", delete=False) as f:
        out_path = f.name
    try:
        build_dawg_to(out_path=out_path, surface_form_source=source,
                      corpus_freq={}, freq_threshold=0)
        with open(out_path, "rb") as f:
            r = DawgReader(f.read())
        # Lowercase fold key — what the runtime would actually look up.
        lowercase_key = folder.fold("πάφος")
        pidx = r.payload_for(lowercase_key)
        assert pidx is not None, f"no payload at lowercase fold key {lowercase_key!r}"
        canonicals = list(r.canonical_forms(pidx))
        assert any(c == "Πάφος" for c, _ in canonicals), \
            f"Πάφος not under lowercase key; got {canonicals}"
    finally:
        os.unlink(out_path)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd dict_generation && python3 -m pytest tests/test_build_dawg.py::test_proper_noun_reachable_via_lowercase_fold_key -v`
Expected: FAIL — no payload at the lowercase fold key (current build stores under capital-first key).

- [ ] **Step 3: Implement the lowercase fold**

In `dict_generation/build_dawg.py`, change line 98:

```python
        key = folder.fold(surface.lower())
```

The canonical (display form) is still stored as `surface` so output preserves capitalisation; only the **key** lowercases. Verify by reading the surrounding code:

```python
        # ...
        key = folder.fold(surface.lower())  # ← lookup key, lowercase only
        stored_freq = freq if freq > 0 else DEFAULT_FREQ
        prev = grouped[key].get(surface, 0)  # ← display form unchanged
        if stored_freq > prev:
            grouped[key][surface] = stored_freq
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd dict_generation && python3 -m pytest tests/test_build_dawg.py::test_proper_noun_reachable_via_lowercase_fold_key -v`
Expected: PASS

- [ ] **Step 5: Run the existing build_dawg test suite**

Run: `cd dict_generation && python3 -m pytest tests/ -v`
Expected: all green. Particularly check fold/eval tests don't regress.

- [ ] **Step 6: Regenerate dict/el_CY.dawg**

Run: `cd dict_generation && make clean_dawg && make dawg`
Expected: `dict/el_CY.dawg` written, ~47 MB. Check `make eval` baseline doesn't crater on identity recall (should stay ≥ 95%).

- [ ] **Step 7: Verify Πάφος via REPL**

Run: `echo "Pafos" | python3 dict_generation/eval/repl.py --batch`
Expected: `DAWG baseline` line shows `Πάφος` (or close) at the lookup, not `(no payload)`.

- [ ] **Step 8: Run iOS tests against the new bundle**

The iOS test fixture (`tiny_fixture.dawg`) is hand-built with lowercase canonicals, so it shouldn't need regeneration. Run xcodebuild to confirm:

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Cypriot KeyboardTests" test
```

Expected: all DAWG tests pass.

- [ ] **Step 9: Re-run the corpus and diff**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t1.md
diff /tmp/corpus_baseline_before.md /tmp/corpus_after_t1.md  # if you stashed a pre-change copy
```

Expected: `Pafos` row shows `Πάφος` in the DAWG column. No regressions on `Lefkosia`, `Lemesos`, `Larnaka`, `Ammoxostos`.

- [ ] **Step 10: Commit**

```bash
git add dict_generation/build_dawg.py dict_generation/tests/test_build_dawg.py dict/el_CY.dawg
git commit -m "build_dawg: lowercase surface forms before fold so proper nouns are reachable"
```

---

## Task 2: σ/ς normalization in shouldReplace

**Why:** Greekify outputs medial σ at word-end; canonicals use ς. Levenshtein in `shouldReplace`'s Greeklish branch counts σ vs ς as +1, pushing valid matches over the `< 3` threshold.

**Files:**
- Modify: `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` (shouldReplace + add a private helper)
- Modify: `dict_generation/eval/run_corpus.py` (mirror in `should_replace`)
- Test: `Cypriot KeyboardTests/CypriotKeyboardUtilTests.swift` (NEW)

- [ ] **Step 1: Write the failing test**

`Cypriot KeyboardTests/CypriotKeyboardUtilTests.swift` (create):

```swift
import XCTest
@testable import Cypriot_Keyboard

class CypriotKeyboardUtilTests: XCTestCase {

    func testShouldReplaceTreatsFinalSigmaAndMedialSigmaAsEqual() {
        // Greekify outputs medial σ at word-end; canonicals use ς. The
        // Levenshtein gate must not penalise that one-character normalisation
        // difference, otherwise short proper-noun candidates get rejected.
        let text = "Pafos"
        let greekText = "Παφος"   // greekify output (medial σ)
        let guess = "Πάθος"        // canonical (final ς) — should pass at edit-1
        XCTAssertTrue(
            CypriotKeyboardHelper.shouldReplace(text: text, greekText: greekText, guess: guess),
            "σ vs ς should not be counted as a Levenshtein edit"
        )
    }

    func testShouldReplaceStillRejectsTrueDistance3() {
        // Sanity: a real distance-3 difference still gets rejected.
        XCTAssertFalse(
            CypriotKeyboardHelper.shouldReplace(text: "Pafos", greekText: "Παφος", guess: "Ποιος")
        )
    }
}
```

Add the test file to the `Cypriot KeyboardTests` target in `Cypriot Keyboard.xcodeproj/project.pbxproj`.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Cypriot KeyboardTests/CypriotKeyboardUtilTests/testShouldReplaceTreatsFinalSigmaAndMedialSigmaAsEqual" test
```

Expected: FAIL — current shouldReplace returns false because levenshtein("παφοσ", "παθος") = 2 (φ→θ AND σ→ς).

- [ ] **Step 3: Implement σ/ς normalization**

In `CypriotKeyboardUtil.swift`, add a helper near the other private helpers and use it in shouldReplace's Greeklish branch:

```swift
    /// Greek normalises medial σ ↔ final ς for the purpose of distance
    /// comparison. Greekify outputs σ at word-end; canonicals use ς.
    /// Without this, every short Greeklish word pays a +1 distance tax.
    private static func normalizeFinalSigma(_ s: String) -> String {
        s.replacingOccurrences(of: "ς", with: "σ")
    }

    static func shouldReplace(text: String, greekText: String, guess: String) -> Bool {
        if text == greekText {
            // ... existing Greek branch unchanged ...
        }
        // Greeklish input: bias toward auto-replace within Levenshtein distance.
        let normalizedGreek = normalizeFinalSigma(greekText.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR")))
        let normalizedGuess = normalizeFinalSigma(guess.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR")))
        return normalizedGreek.levenshtein(normalizedGuess) < 3
    }
```

(The `distanceMeasure` helper duplicated this work; replace its body or inline as above. Remove `distanceMeasure` if no other caller — verify with `grep -n "distanceMeasure" "Cypriot  Custom Keyboard"/*.swift`.)

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild ... -only-testing:"Cypriot KeyboardTests/CypriotKeyboardUtilTests" test
```

Expected: both new tests PASS.

- [ ] **Step 5: Mirror in Python**

In `dict_generation/eval/run_corpus.py`, modify `should_replace`:

```python
def _normalize_final_sigma(s: str) -> str:
    return s.replace("ς", "σ")


def should_replace(text: str, greek_text: str, guess: str) -> bool:
    if text == greek_text:
        # ... existing Greek branch unchanged ...
        pass
    a = _normalize_final_sigma(_strip_diacritics(greek_text.lower()))
    b = _normalize_final_sigma(_strip_diacritics(guess.lower()))
    return _levenshtein(a, b) < 3
```

- [ ] **Step 6: Re-run corpus**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t2.md
```

Expected: `Pafos` and similar short proper-noun cases now show non-verbatim DAWG output.

- [ ] **Step 7: Commit**

```bash
git add "Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift" \
        "Cypriot KeyboardTests/CypriotKeyboardUtilTests.swift" \
        "Cypriot Keyboard.xcodeproj/project.pbxproj" \
        dict_generation/eval/run_corpus.py
git commit -m "shouldReplace: normalize final ς ↔ medial σ in the Levenshtein gate"
```

---

## Task 3: shouldReplace against greekify variants

**Why:** "afth" → greekify "αφθ"; the DAWG finds αυτή at d=0 via greekify_alternatives ("αυτη" path), but shouldReplace gates with `levenshtein("αφθ", "αυτη") = 3`, fails `< 3`, and αυτή gets dropped. The fix is to consider every greekify alternative when computing the gate distance.

**Files:**
- Modify: `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` (add overload taking variants)
- Modify: `Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift` (caller passes variants)
- Modify: `dict_generation/eval/run_corpus.py` (mirror)
- Test: `Cypriot KeyboardTests/CypriotKeyboardUtilTests.swift` (extend)

- [ ] **Step 1: Write the failing test**

Add to `CypriotKeyboardUtilTests.swift`:

```swift
    func testShouldReplaceUsesMinimumDistanceAcrossVariants() {
        // "afth" greekifies to αφθ. The αυτή candidate is distance 3 from
        // αφθ but distance 0 from the αυτη greekify-alternative. The gate
        // must use the minimum across alternatives, otherwise valid Greek
        // candidates get rejected for greekify-shortening cases.
        XCTAssertTrue(
            CypriotKeyboardHelper.shouldReplace(
                text: "afth",
                greekVariants: ["αφθ", "αυτη"],
                guess: "αυτή"
            )
        )
    }
```

- [ ] **Step 2: Run test to verify it fails (compilation error: method not yet defined)**

Expected: build fails — `shouldReplace(text:greekVariants:guess:)` doesn't exist.

- [ ] **Step 3: Implement the variants overload**

In `CypriotKeyboardUtil.swift`, alongside the existing `shouldReplace`:

```swift
    /// Variants overload: passes if ANY of the supplied greekify
    /// interpretations would gate true. Used by the DAWG provider so that
    /// greekify-shortening cases (th → θ where the user meant τη) don't
    /// get rejected by the distance check.
    static func shouldReplace(text: String, greekVariants: [String], guess: String) -> Bool {
        for variant in greekVariants {
            if shouldReplace(text: text, greekText: variant, guess: guess) {
                return true
            }
        }
        return false
    }
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Wire into the DAWG provider**

In `DawgAutocompleteSuggestionProvider.swift`'s `buildSuggestions`, replace the single-variant call with the multi-variant one. The greek variants are already computed:

```swift
        // ... existing greekifyAlternatives + foldVariants computation ...

        if let top = candidates.first {
            let displayed = displayForm(top.canonical)
            let willReplace = CypriotKeyboardHelper.shouldReplace(
                text: text, greekVariants: greekVariants, guess: displayed
            )
            // ...
        }
```

- [ ] **Step 6: Mirror in Python**

In `run_corpus.py`'s `correct_token_dawg`, replace the single-variant `should_replace` call with one that walks `greek_variants`:

```python
def _should_replace_any(text: str, greek_variants: list, guess: str) -> bool:
    return any(should_replace(text, gv, guess) for gv in greek_variants)
```

Use it in `correct_token_dawg`:

```python
    if not _should_replace_any(body, greek_variants, displayed):
        return token
```

- [ ] **Step 7: Run iOS test suite end-to-end**

```bash
xcodebuild ... -only-testing:"Cypriot KeyboardTests/DawgIntegrationTests" \
              -only-testing:"Cypriot KeyboardTests/CypriotKeyboardUtilTests" test
```

Expected: green. Particularly check `testRandomGreekDoesNotForceReplace` and `testSlot1HasWillReplaceForPhoneticMatch` still pass — the multi-variant path should not relax the gate for unrelated input.

- [ ] **Step 8: Re-run corpus**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t3.md
```

Expected: `afth → αυτή`, `auth → αυτή` (already passing), `8a → θα` (after Task 6 — flagged here).

- [ ] **Step 9: Commit**

```bash
git add "Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift" \
        "Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift" \
        "Cypriot KeyboardTests/CypriotKeyboardUtilTests.swift" \
        dict_generation/eval/run_corpus.py
git commit -m "shouldReplace: gate against the closest greekify variant, not just the first"
```

---

## Task 4: Better tiebreaking when multiple distance-1 hits

**Why:** Πάφος (freq 3) loses to ποιος (freq 266) at edit-1 even though the input was capitalised "Pafos". The first-letter case of the input is a strong signal we're throwing away.

**Files:**
- Modify: `Cypriot  Custom Keyboard/DAWG/DamerauLevenshteinSuggester.swift`
- Test: `Cypriot KeyboardTests/DamerauLevenshteinSuggesterTests.swift`

- [ ] **Step 1: Write the failing test**

In `DamerauLevenshteinSuggesterTests.swift`:

```swift
    func testCapInputBoostsCapCanonicalAtSameDistance() {
        // Build two near-misses at the same edit distance, one cap-first
        // (matching the input's casing) and one not. The cap-matching one
        // must rank higher even when it has lower frequency.
        // Uses tiny_fixture which has both Καλός and καλώς at distance 0.
        // (We provide a synthetic fixture for this case if needed.)
        let suggestions = suggester.suggest(forKeys: [/* fold key */], limit: 5,
                                            inputCasingHint: .firstLetterCap)
        // First result should be cap-first canonical
        XCTAssertTrue(suggestions.first?.canonical.first?.isUppercase ?? false)
    }
```

(The exact test fixture and assertion will need a real cap-vs-lowercase pair sharing a fold key. If `tiny_fixture` doesn't have one, add one to `dict_generation/generate_swift_test_fixtures.py`'s tiny dict — e.g. add "Καλός" alongside "καλός" — and regenerate.)

- [ ] **Step 2: Run test to verify it fails**

Expected: signature `suggest(forKeys:limit:inputCasingHint:)` doesn't exist; build fails.

- [ ] **Step 3: Add the casing-aware suggest signature**

In `DamerauLevenshteinSuggester.swift`:

```swift
    enum InputCasingHint {
        case lowercase
        case firstLetterCap
        case allCaps
    }

    /// Casing-aware ranking: when the input is cap-first or all-caps, prefer
    /// canonicals whose first letter matches that casing. Tiebreaker only —
    /// edit distance still dominates.
    func suggest(forKeys keys: [String],
                 limit: Int = 5,
                 inputCasingHint: InputCasingHint = .lowercase) -> [DawgSuggestion] {
        let raw = self.suggest(forKeys: keys, limit: limit * 4)  // overfetch for re-rank
        let reranked = raw.sorted { lhs, rhs in
            if lhs.editDistance != rhs.editDistance { return lhs.editDistance < rhs.editDistance }
            // Within same distance, prefer canonicals whose first letter case
            // matches the input casing hint.
            let lhsBoost = casingBoost(canonical: lhs.canonical, hint: inputCasingHint)
            let rhsBoost = casingBoost(canonical: rhs.canonical, hint: inputCasingHint)
            if lhsBoost != rhsBoost { return lhsBoost > rhsBoost }
            return lhs.frequency > rhs.frequency
        }
        return Array(reranked.prefix(limit))
    }

    private func casingBoost(canonical: String, hint: InputCasingHint) -> Int {
        guard let first = canonical.first else { return 0 }
        switch hint {
        case .lowercase:
            return first.isLowercase ? 1 : 0
        case .firstLetterCap, .allCaps:
            return first.isUppercase ? 1 : 0
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Wire into DAWG provider**

In `DawgAutocompleteSuggestionProvider.swift`, pass the casing through:

```swift
        let casingHint: DamerauLevenshteinSuggester.InputCasingHint
        switch casing {
        case .lowercase:       casingHint = .lowercase
        case .firstLetterCap:  casingHint = .firstLetterCap
        case .allCaps:         casingHint = .allCaps
        }
        let candidates = suggester.suggest(forKeys: foldKeys,
                                           limit: candidateLimit,
                                           inputCasingHint: casingHint)
```

- [ ] **Step 6: Mirror in Python (run_corpus.py)**

The Python suggester `DawgSuggester.suggest_multi` lives in `dict_generation/eval/dawg_suggester.py`. Add the same casing hint:

```python
def suggest_multi(self, keys, budget=1, limit=5, input_casing_hint="lowercase"):
    raw = ...  # existing logic, overfetch limit*4
    def casing_boost(canonical):
        if not canonical: return 0
        if input_casing_hint == "lowercase":
            return 1 if canonical[0].islower() else 0
        return 1 if canonical[0].isupper() else 0
    raw.sort(key=lambda s: (s.edit_distance, -casing_boost(s.canonical), -s.frequency))
    return raw[:limit]
```

Then in `run_corpus.py`, pass the hint:

```python
hint = "first_letter_cap" if casing == _Casing.FIRST_LETTER_CAP else (
       "all_caps" if casing == _Casing.ALL_CAPS else "lowercase")
candidates = suggester.suggest_multi(fold_keys, budget=1, limit=1,
                                     input_casing_hint=hint)
```

- [ ] **Step 7: Run all DAWG-related iOS tests + corpus diff**

```bash
xcodebuild ... -only-testing:"Cypriot KeyboardTests" test
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t4.md
diff /tmp/corpus_after_t3.md /tmp/corpus_after_t4.md
```

Expected: cap-first words like Pafos, yiannis, Lemesos, Larnaka, Ammoxostos rank correctly. No regressions on lowercase inputs.

- [ ] **Step 8: Commit**

```bash
git add "Cypriot  Custom Keyboard/DAWG/DamerauLevenshteinSuggester.swift" \
        "Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift" \
        "Cypriot KeyboardTests/DamerauLevenshteinSuggesterTests.swift" \
        dict_generation/eval/dawg_suggester.py \
        dict_generation/eval/run_corpus.py
git commit -m "DAWG suggester: casing-aware tiebreak so cap-input prefers cap-canonical"
```

---

## Task 5: Cypriot dialect coverage audit

**Why:** corpus run shows tziame, intalos, essiei, dame, kamno, lalei, mashalla, ishalla mostly miss in both DAWG and Hunspell. Some are present in the dict but under unexpected forms (`τζ̆ιαμέ` with breve vs `τζιαμέ` without); some are genuinely missing.

**Files:**
- Audit: `dict/el_CY.dic`
- Modify: `dict_generation/spyros_list.dic` (curated additions)
- Modify: `dict_generation/eval/greeklish_corpus.txt` (annotate findings)
- Rebuild: `dict/el_CY.dawg` via `make dawg`

- [ ] **Step 1: List Cypriot markers and grep their canonical Greek forms**

Targets (all the ones that the corpus failed):

```
τζιαμέ τζ̆ιαμέ      (tziame)
ίνταλως ίντα          (intalos)
έσσιει έσ̆ει          (essiei / esh)
δαμέ                   (dame)
κάμνω κάμνεις         (kamno)
λαλεί λαλώ            (lalei)
μάσ̌σ̌αλλα μασ̆αλλα   (mashalla)
ίσ̌σ̌αλλα ισ̆αλλα     (ishalla)
σιόρ                   (shor)
παττίχα                (pattixa)
βορκάς                 (vorkas)
```

For each, run:

```bash
grep -n "<word>" dict/el_CY.dic
```

Capture which forms exist as-is, which exist with different diacritics/breves, and which are entirely absent.

- [ ] **Step 2: Decide handling per word**

Three buckets:

1. **Present already**: leave alone, but add a regression test to corpus.
2. **Present in different form** (e.g. with breve `τζ̆` vs without `τζ`): add the alternate spelling to `spyros_list.dic` so both fold to the same key and either spelling is reachable.
3. **Genuinely absent**: add to `spyros_list.dic`. Note in the file's commit comment which dialect/source.

- [ ] **Step 3: Append findings to spyros_list.dic**

Format follows existing entries (one word per line, optional `/flags` for affix expansion). Example:

```
τζιαμέ
ίνταλως
ίνταλος
έσσιει
δαμέ
κάμνω
λαλεί
μάσσαλλα
ίσσαλλα
```

- [ ] **Step 4: Rebuild dict**

```bash
cd dict_generation && make clean && make dawg
```

- [ ] **Step 5: Re-run corpus**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t5.md
```

Expected: `tziame → τζιαμέ`, `intalos → ίνταλος`, `essiei → έσσιει`, `dame → δαμέ`, `kamno → κάμνω`, `lalei → λαλεί`.

- [ ] **Step 6: Commit**

```bash
git add dict_generation/spyros_list.dic dict/el_CY.dawg dict/el_CY.dic
git commit -m "dict: add Cypriot dialect markers (τζιαμέ, ίνταλως, έσσιει, δαμέ, κάμνω, λαλεί)"
```

---

## Task 6: 8↔θ Greeklish convention

**Why:** Very common ("8a" = θα, "8elw" = θέλω, "Aei8alassa" — proper noun). Currently treated as a literal digit, killing autocorrect.

**Files:**
- Modify: `Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift` (add to `altRules`)
- Modify: `dict_generation/eval/run_corpus.py` (mirror)
- Test: `Cypriot KeyboardTests/DawgIntegrationTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `DawgIntegrationTests.swift`:

```swift
    func testGreekifyAlternativesBranchesOn8AsTheta() {
        let variants = DawgAutocompleteSuggestionProvider.greekifyAlternatives("8α")
        XCTAssertTrue(variants.contains("8α"))
        XCTAssertTrue(variants.contains("θα"))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — current rules don't include 8.

- [ ] **Step 3: Add the rule**

In `DawgAutocompleteSuggestionProvider.swift`'s `altRules`:

```swift
    private static let altRules: [(src: String, alts: [String])] = [
        // ... existing rules ...
        ("8", ["8", "θ"]),
    ]
```

8 has no case variant — keep it as a single rule. The shouldAttemptAutocomplete gate already returns `false` for tokens with no letters, so a bare "8" never enters this path.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Mirror in Python**

In `run_corpus.py`'s `_ALT_RULES`, add `("8", ["8", "θ"])`.

- [ ] **Step 6: Re-run corpus**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t6.md
```

Expected: `8a → θα`, `8elw → θέλω`, `Aei8alassa → ?` (depends on dict coverage; at minimum the digit no longer blocks autocorrect of the rest).

- [ ] **Step 7: Commit**

```bash
git add "Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift" \
        "Cypriot KeyboardTests/DawgIntegrationTests.swift" \
        dict_generation/eval/run_corpus.py
git commit -m "DAWG suggester: branch 8 ⇄ θ for Greeklish digit-as-letter convention"
```

---

## Task 7: Decision pass on x→ξ branching

**Why:** Earlier we tabled this since edit-1 covers single-x cases. With Tasks 1, 4, 6 landed, the ranking and lookup landscape is materially different. Re-evaluate.

**Files:** none yet — this task starts as analysis.

- [ ] **Step 1: Re-run corpus**

```bash
python3 dict_generation/eval/run_corpus.py --output-md /tmp/corpus_after_t7_pre.md
```

- [ ] **Step 2: Inspect every x-token row**

Rows to focus on: `taxi`, `xara`, `xerw`, `xarta`, `ksero`, and any x-words from `praxh`/`praxis` style. Note which produce wrong DAWG output and whether the right answer is at edit-1 vs edit-2.

- [ ] **Step 3: Decide one of**

- (a) **Add the branch.** If ≥ 2 cases consistently fail, add `("x", ["x", "ξ"])` style to `altRules` (note: x is Latin so this rule operates on the input pre-greekify — needs careful placement). Or add it as a greekify rule alternative.
- (b) **Skip, document reasoning.** If ranking + lookup fixes already handle the cases, close as resolved with a note in `docs/superpowers/specs/` capturing the decision.

- [ ] **Step 4: Commit (or close as no-op)**

```bash
git commit -m "x→ξ: <decision>"
```

---

## Task 8: Commit a corpus baseline + regression process

**Why:** Each fix above generates a markdown diff. Locking in a baseline lets future PRs run the corpus and `diff` instead of re-evaluating manually.

**Files:**
- Create: `dict_generation/eval/corpus_baseline.md`
- Modify: `dict_generation/Makefile` (add an `eval-corpus` target)

- [ ] **Step 1: Generate the baseline**

```bash
python3 dict_generation/eval/run_corpus.py --output-md dict_generation/eval/corpus_baseline.md
```

- [ ] **Step 2: Add a Makefile target**

In `dict_generation/Makefile`:

```makefile
eval-corpus:
	python3 eval/run_corpus.py --output-md /tmp/corpus_current.md
	diff eval/corpus_baseline.md /tmp/corpus_current.md && \
	  echo "[eval-corpus] baseline matches" || \
	  (echo "[eval-corpus] DIFF — review and update corpus_baseline.md if intentional"; exit 1)

eval-corpus-update:
	python3 eval/run_corpus.py --output-md eval/corpus_baseline.md
```

- [ ] **Step 3: Document in CLAUDE.md / README**

Brief note: "After any DAWG-suggester change, run `cd dict_generation && make eval-corpus`. If the diff is intentional, run `make eval-corpus-update` and commit the new baseline."

- [ ] **Step 4: Commit**

```bash
git add dict_generation/eval/corpus_baseline.md dict_generation/Makefile
git commit -m "eval: commit corpus baseline + Makefile targets for regression tracking"
```

---

## Order of execution

Tasks should land roughly in this order to minimize re-runs:

1. **Task 1** (lowercase fold keys) — touches the dict; do first so all later observations are against the new DAWG.
2. **Task 2** (σ/ς normalization) — small, independent.
3. **Task 3** (shouldReplace via greekify variants) — independent.
4. **Task 4** (casing-aware ranking) — depends on Task 1 (the candidate set has shifted).
5. **Task 5** (Cypriot dialect audit) — independent, partly content work.
6. **Task 6** (8↔θ) — independent.
7. **Task 7** (x→ξ decision) — needs Tasks 1, 4 to evaluate properly.
8. **Task 8** (baseline + Makefile) — last, locks in everything.

After each task, run `python3 dict_generation/eval/run_corpus.py` and inspect the diff against the previous run. The corpus is the integration test for this whole plan.
