# Tier-c Phase 1: Build Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the offline Python build pipeline that takes the existing `dict/el_CY.dic` + `dict/el_CY.aff` and emits a phonetic-folded, frequency-ranked DAWG to `dict/el_CY.dawg`. iOS code is untouched in this phase.

**Architecture:** A new Python package under `dict_generation/` that (1) loads shared phonetic-fold rules from JSON, (2) parses Hunspell `.aff`/`.dic` and expands all surface forms, (3) folds each form to a phonetic key, groups canonical forms by key, attaches frequencies extracted from the existing corpus, (4) builds a minimized DAWG via the Daciuk incremental algorithm, (5) serializes to a documented compact binary. Hooked into the existing `dict_generation/Makefile`.

**Tech Stack:** Python 3.9+ (already required by repo), `unittest` from stdlib, `json`/`struct` from stdlib. **No third-party dependencies** — pip-free build pipeline keeps the repo simple and avoids version drift on contributor machines.

**Working directory:** `/Users/alext/CypriotKeyboard.tier-c/` (the `tier-c-dawg` worktree). All paths in this plan are relative to that root unless absolute.

**Reference spec:** [`docs/superpowers/specs/2026-04-27-keyboard-perf-tier-c-design.md`](../specs/2026-04-27-keyboard-perf-tier-c-design.md) (commit `1853ec9` on `main`).

**Verification anchor:** when this phase is done, `make el_CY.dawg` from `dict_generation/` produces a binary in `dict/el_CY.dawg` that round-trips through the Phase 1 read APIs (deserialize, dump entries, compare to expanded source). Phase 2 (Swift runtime) is the consumer; Phase 1 just produces and validates the artifact.

---

## File Structure

All new files live under `dict_generation/`. iOS targets are not touched.

```
dict_generation/
├── Makefile                     # MODIFY: add el_CY.dawg target
├── list_words.py                # MODIFY: emit corpus_freq.json side-output
├── phonetic_fold.json           # NEW: shared fold rules (data only)
├── phonetic_fold.py             # NEW: load + apply fold rules
├── aff_parse.py                 # NEW: parse Hunspell .aff (FLAG num scheme, SFX rules)
├── affix_expand.py              # NEW: apply parsed rules to .dic stems → surface forms
├── dawg.py                      # NEW: Daciuk incremental DAWG + serializer
├── build_dawg.py                # NEW: orchestrator (read inputs, expand, fold, build, serialize)
├── DAWG_FORMAT.md               # NEW: binary format spec for Phase 2 (Swift) reader
└── tests/
    ├── __init__.py              # NEW: empty
    ├── test_phonetic_fold.py    # NEW
    ├── test_aff_parse.py        # NEW
    ├── test_affix_expand.py     # NEW
    └── test_dawg.py             # NEW
```

Each module is single-responsibility and importable in isolation. Tests use `unittest` and run with `python3 -m unittest discover dict_generation/tests`.

---

## Task 1: Bootstrap test scaffolding

**Files:**
- Create: `dict_generation/tests/__init__.py`
- Create: `dict_generation/tests/test_smoke.py`

- [ ] **Step 1: Create empty package init**

```bash
touch dict_generation/tests/__init__.py
```

- [ ] **Step 2: Add a smoke test to verify the test runner works**

Write `dict_generation/tests/test_smoke.py`:

```python
import unittest

class SmokeTest(unittest.TestCase):
    def test_runner_works(self):
        self.assertEqual(1 + 1, 2)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the test**

```bash
cd dict_generation && python3 -m unittest discover tests -v
```

Expected: `test_runner_works ... ok` and `OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
git add dict_generation/tests/__init__.py dict_generation/tests/test_smoke.py
git commit -m "tier-c: add unittest scaffolding for build pipeline"
```

---

## Task 2: Phonetic fold rules JSON

**Files:**
- Create: `dict_generation/phonetic_fold.json`

The fold rules are *data*, not code. They live in JSON so both the Python build tool and the Swift runtime can read the same file. Phase 2 will add a Swift loader. This task only writes the data file.

- [ ] **Step 1: Write the fold rules JSON**

Write `dict_generation/phonetic_fold.json`:

```json
{
  "version": 1,
  "description": "Cypriot Greek phonetic equivalence classes for tier-c spellchecker. Each entry maps a source string to a canonical key character. Longest source strings are tried first by the matcher. Diacritics on i/e/o-sound vowels collapse into the base sound.",
  "rules": [
    {"from": "ει", "to": "ı"},
    {"from": "οι", "to": "ı"},
    {"from": "υι", "to": "ı"},
    {"from": "αι", "to": "e"},
    {"from": "αί", "to": "e"},
    {"from": "ι", "to": "ı"},
    {"from": "η", "to": "ı"},
    {"from": "υ", "to": "ı"},
    {"from": "ή", "to": "ı"},
    {"from": "ί", "to": "ı"},
    {"from": "ύ", "to": "ı"},
    {"from": "ϊ", "to": "ı"},
    {"from": "ϋ", "to": "ı"},
    {"from": "ΐ", "to": "ı"},
    {"from": "ΰ", "to": "ı"},
    {"from": "ε", "to": "e"},
    {"from": "έ", "to": "e"},
    {"from": "ο", "to": "o"},
    {"from": "ω", "to": "o"},
    {"from": "ό", "to": "o"},
    {"from": "ώ", "to": "o"},
    {"from": "ά", "to": "α"},
    {"from": "ς", "to": "σ"}
  ]
}
```

The marker character `ı` (U+0131, dotless i) is used as the i-sound canonical key because it's a single Unicode scalar that won't collide with any letter actually appearing in Greek text. Same shape for `e` and `o` — they're canonical lowercase Latin letters not present in Greek corpus, so collisions are impossible.

- [ ] **Step 2: Verify it's valid JSON**

```bash
python3 -c "import json; print('OK,', len(json.load(open('dict_generation/phonetic_fold.json'))['rules']), 'rules')"
```

Expected: `OK, 23 rules`.

- [ ] **Step 3: Commit**

```bash
git add dict_generation/phonetic_fold.json
git commit -m "tier-c: add phonetic fold rules JSON (shared by build tool + runtime)"
```

---

## Task 3: Phonetic fold module + tests

**Files:**
- Create: `dict_generation/phonetic_fold.py`
- Create: `dict_generation/tests/test_phonetic_fold.py`

- [ ] **Step 1: Write failing tests**

Write `dict_generation/tests/test_phonetic_fold.py`:

```python
import os
import unittest
from dict_generation.phonetic_fold import PhoneticFolder, load_default_folder


class PhoneticFoldTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.fold = load_default_folder()

    def test_single_i_sound_vowels_collapse(self):
        self.assertEqual(self.fold.fold("καλημερα"), "kalımera".replace("k", "κ").replace("a", "α").replace("l", "λ").replace("m", "μ").replace("r", "ρ").replace("e", "ε"))
        # easier readable form:
        self.assertEqual(self.fold.fold("καλημερα"), "καλıμερα")
        self.assertEqual(self.fold.fold("καλιμερα"), "καλıμερα")
        self.assertEqual(self.fold.fold("καλυμερα"), "καλıμερα")

    def test_digraphs_win_over_singles(self):
        # ει must collapse to ı (single key), not to ε + ı
        self.assertEqual(self.fold.fold("ειδος"), "ıδoσ")
        self.assertEqual(self.fold.fold("οικος"), "ıκoσ")
        self.assertEqual(self.fold.fold("αιμα"), "eμα")

    def test_diacritics_drop(self):
        self.assertEqual(self.fold.fold("καλημέρα"), "καλıμερα")
        self.assertEqual(self.fold.fold("ώρα"), "oρα")

    def test_final_sigma_normalizes(self):
        self.assertEqual(self.fold.fold("καλος"), "καλoσ")
        self.assertEqual(self.fold.fold("καλός"), "καλoσ")

    def test_empty_input(self):
        self.assertEqual(self.fold.fold(""), "")

    def test_passes_through_unmapped(self):
        # Latin letters and punctuation are not part of the Greek fold and pass through.
        self.assertEqual(self.fold.fold("hello"), "hello")
        self.assertEqual(self.fold.fold(" "), " ")

    def test_collisions_within_phonetic_class(self):
        # Different spellings of the same sound class fold identically.
        for inp in ["καλημερα", "καλιμερα", "καλυμερα", "καλημέρα", "καλείμερα"]:
            self.assertEqual(self.fold.fold(inp), "καλıμερα", f"failed for {inp!r}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 -m unittest dict_generation.tests.test_phonetic_fold -v 2>&1 | head -30
```

Expected: ImportError for `dict_generation.phonetic_fold`.

- [ ] **Step 3: Implement the module**

Write `dict_generation/phonetic_fold.py`:

```python
"""Phonetic-equivalence-class folding for Cypriot Greek.

Loads rules from phonetic_fold.json. Folds an input string by greedily
matching the longest source pattern at each position, emitting the
canonical key character, and advancing past the matched length.

The Swift runtime in Phase 2 implements the same algorithm against
the same JSON file.
"""
import json
import os
from typing import List, Tuple


class PhoneticFolder:
    def __init__(self, rules: List[Tuple[str, str]]):
        # Sort longest-first so 2-char digraphs (ει, οι, αι) win over 1-char rules.
        self._rules = sorted(rules, key=lambda r: -len(r[0]))
        self._max_source_len = max((len(s) for s, _ in self._rules), default=1)

    def fold(self, text: str) -> str:
        out = []
        i = 0
        n = len(text)
        while i < n:
            matched = False
            # Try longest patterns first.
            for src, dst in self._rules:
                if i + len(src) <= n and text[i:i + len(src)] == src:
                    out.append(dst)
                    i += len(src)
                    matched = True
                    break
            if not matched:
                out.append(text[i])
                i += 1
        return "".join(out)


def load_default_folder() -> PhoneticFolder:
    path = os.path.join(os.path.dirname(__file__), "phonetic_fold.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return PhoneticFolder([(r["from"], r["to"]) for r in data["rules"]])
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.tests.test_phonetic_fold -v
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add dict_generation/phonetic_fold.py dict_generation/tests/test_phonetic_fold.py
git commit -m "tier-c: add phonetic_fold module with longest-match folding"
```

---

## Task 4: Frequency extraction from corpus

**Files:**
- Modify: `dict_generation/list_words.py:86-99` (the bottom of the file where words are written out)

The existing `list_words.py` already counts word frequencies in `words_abs` (line 41) but throws them away. We add an emit step that writes a JSON dictionary keyed by word with raw counts.

- [ ] **Step 1: Read the existing tail of list_words.py**

```bash
sed -n '85,99p' dict_generation/list_words.py
```

Expected (paraphrased): a block that writes `el_CY_words.v3.dic` from `words` and prints char counts.

- [ ] **Step 2: Add corpus_freq.json emit alongside the existing dic write**

Modify `dict_generation/list_words.py`. Replace the final block (everything from `words = generate_cy_list_2(files)` to the end) with:

```python
words = generate_cy_list_2(files)

# Re-tokenize the corpus to capture absolute frequencies for ALL observed
# tokens, not just the filtered ones above. This output is used by the
# tier-c DAWG build to rank canonical-form collisions.
import json
from collections import defaultdict

corpus_freq = defaultdict(int)
for fname in files:
    with open('corpus/' + fname, encoding="utf-8") as f:
        for line in f:
            for raw in line.split():
                cleaned = ''.join(e for e in raw if e.isalpha())
                if not cleaned:
                    continue
                # Lowercase per the same heuristic used above
                cleaned = cleaned.lower()
                # Skip Latin tokens (English code-switching in blogs)
                if (cleaned[0] >= 'A' and cleaned[0] <= 'Z') or (cleaned[0] >= 'a' and cleaned[0] <= 'z'):
                    continue
                corpus_freq[cleaned] += 1

with open("corpus_freq.json", "w", encoding="utf-8") as f:
    json.dump(corpus_freq, f, ensure_ascii=False)
print(f"corpus_freq.json: {len(corpus_freq)} unique tokens")

# (existing) char count dump and word list write
char_counts = defaultdict(lambda: 0)
for w in words:
    for l in w:
        char_counts[l] += 1
cs = [(k, v) for k, v in char_counts.items()]
cs.sort(key=lambda a: a[1], reverse=False)
print([a[0] for a in cs])
word_list = "el_CY_words.v3.dic"
with open(word_list, "w", encoding="utf-8") as data:
    data.write(str(len(words)) + "\n")
    data.write("\n".join(words))
```

- [ ] **Step 3: Run list_words.py to produce both outputs**

```bash
cd dict_generation
python3 list_words.py 2>&1 | tail -5
```

Expected: `corpus_freq.json: <some number, expect 50000–200000> unique tokens` plus the existing char-counts dump.

- [ ] **Step 4: Spot-check that high-frequency entries look right**

```bash
python3 -c "
import json
freq = json.load(open('dict_generation/corpus_freq.json'))
top = sorted(freq.items(), key=lambda x: -x[1])[:20]
for word, count in top: print(f'{count:6d}  {word}')
"
```

Expected: top words include common Greek function words like `και`, `να`, `μου`, `είναι`, `που`, `στο`, etc., with counts in the hundreds-to-thousands. If the top is full of unexpected garbage tokens, investigate before continuing.

- [ ] **Step 5: Commit**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
git add dict_generation/list_words.py
git commit -m "tier-c: emit corpus_freq.json side-output from list_words.py

Frequency counts were already computed by generate_cy_list_2 then
discarded. Persist them as a JSON dump that tier-c's DAWG builder
will consume to rank canonical-form collisions on the same fold key."
```

---

## Task 5: Hunspell .aff parser

**Files:**
- Create: `dict_generation/aff_parse.py`
- Create: `dict_generation/tests/test_aff_parse.py`

The .aff file uses `FLAG num` (numeric flags 1-N), `SET UTF-8`, and SFX rules of the form:

```
SFX 1 Y 1
SFX 1 0 ς .
```

Header line: `SFX <flag> <cross-product> <count>`.
Body lines: `SFX <flag> <strip> <append> <condition>`.

For our purposes (simple suffix appending, no prefix rules in el_CY.aff), each SFX rule says: "for stems matching `<condition>`, add `<append>` to the end (after stripping `<strip>` chars if present)." `0` means "strip nothing" or "append nothing." `.` as condition means "always."

- [ ] **Step 1: Write failing tests**

Write `dict_generation/tests/test_aff_parse.py`:

```python
import unittest
from dict_generation.aff_parse import parse_aff, SfxRule


class AffParseTests(unittest.TestCase):

    def test_parses_set_utf8(self):
        aff = parse_aff("SET UTF-8\n")
        self.assertEqual(aff.encoding, "UTF-8")

    def test_parses_flag_num(self):
        aff = parse_aff("FLAG num\n")
        self.assertEqual(aff.flag_type, "num")

    def test_parses_simple_sfx_rule(self):
        text = """\
SET UTF-8
FLAG num
SFX 1 Y 1
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)
        rule = aff.sfx_rules["1"]
        self.assertEqual(rule.flag, "1")
        self.assertEqual(len(rule.entries), 1)
        entry = rule.entries[0]
        self.assertEqual(entry.strip, "")
        self.assertEqual(entry.append, "ς")
        self.assertEqual(entry.condition, ".")

    def test_zero_strip_normalizes_to_empty_string(self):
        text = """\
FLAG num
SFX 2 Y 1
SFX 2 0 ν .
"""
        aff = parse_aff(text)
        rule = aff.sfx_rules["2"]
        self.assertEqual(rule.entries[0].strip, "")
        self.assertEqual(rule.entries[0].append, "ν")

    def test_multiple_rules(self):
        text = """\
FLAG num
SFX 1 Y 1
SFX 1 0 ς .
SFX 4 Y 1
SFX 4 0 υ .
"""
        aff = parse_aff(text)
        self.assertEqual(set(aff.sfx_rules.keys()), {"1", "4"})

    def test_ignores_comments_and_blank_lines(self):
        text = """\
# comment
FLAG num

SFX 1 Y 1
# nested comment
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)

    def test_ignores_unsupported_directives(self):
        # TRY, REP, MAP etc. should be parsed-and-discarded without errors.
        text = """\
SET UTF-8
FLAG num
TRY άόίϊΐέήύϋΰώσ̆
REP 488
REP σ ς
SFX 1 Y 1
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
python3 -m unittest dict_generation.tests.test_aff_parse -v 2>&1 | head -10
```

Expected: ImportError.

- [ ] **Step 3: Implement the parser**

Write `dict_generation/aff_parse.py`:

```python
"""Minimal parser for the Hunspell .aff format used by el_CY.aff.

Supports only what we need: SET, FLAG, and SFX rule blocks.
Other directives (TRY, REP, MAP, NAME, …) are silently ignored.
"""
from dataclasses import dataclass, field
from typing import Dict, List


@dataclass
class SfxEntry:
    strip: str       # chars to strip from end of stem before appending; "" if "0"
    append: str      # chars to append; "" if "0"
    condition: str   # regex-like condition on the stem suffix; "." matches anything

    def applies_to(self, stem: str) -> bool:
        # The condition is a Hunspell-flavored regex on the END of the stem.
        # For el_CY.aff every SFX condition is "." — match any stem. We
        # implement only that case here; extend if a future .aff uses real
        # conditions.
        if self.condition == ".":
            return True
        # Conservatively reject anything we don't model.
        raise NotImplementedError(
            f"SfxEntry.applies_to: unsupported condition {self.condition!r}; extend the parser."
        )

    def apply(self, stem: str) -> str:
        if self.strip and stem.endswith(self.strip):
            stem = stem[: -len(self.strip)]
        return stem + self.append


@dataclass
class SfxRule:
    flag: str
    cross_product: bool
    entries: List[SfxEntry] = field(default_factory=list)


@dataclass
class AffFile:
    encoding: str = "UTF-8"
    flag_type: str = "num"
    sfx_rules: Dict[str, SfxRule] = field(default_factory=dict)


def parse_aff(text: str) -> AffFile:
    aff = AffFile()
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 3)
        if not parts:
            continue
        directive = parts[0]
        if directive == "SET" and len(parts) >= 2:
            aff.encoding = parts[1]
        elif directive == "FLAG" and len(parts) >= 2:
            aff.flag_type = parts[1]
        elif directive == "SFX":
            # Header form:  SFX <flag> <Y|N> <count>
            # Entry form:   SFX <flag> <strip> <append> <condition> [morph...]
            if len(parts) >= 4 and parts[2] in ("Y", "N"):
                # Header line
                flag, cross, _count = parts[1], parts[2] == "Y", parts[3]
                aff.sfx_rules[flag] = SfxRule(flag=flag, cross_product=cross)
            else:
                # Entry line; re-split with maxsplit=4 to capture the condition properly
                fields_ = line.split(None, 4)
                if len(fields_) < 5:
                    continue  # malformed — skip
                _, flag, strip, append, condition_and_rest = fields_
                condition = condition_and_rest.split(None, 1)[0]
                strip = "" if strip == "0" else strip
                append = "" if append == "0" else append
                rule = aff.sfx_rules.get(flag)
                if rule is None:
                    # Entry without a header — synthesize an open rule
                    rule = SfxRule(flag=flag, cross_product=True)
                    aff.sfx_rules[flag] = rule
                rule.entries.append(SfxEntry(strip=strip, append=append, condition=condition))
    return aff
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.tests.test_aff_parse -v
```

Expected: all 6 tests pass.

- [ ] **Step 5: Sanity-run on real el_CY.aff**

```bash
python3 -c "
from dict_generation.aff_parse import parse_aff
aff = parse_aff(open('dict/el_CY.aff', encoding='utf-8').read())
print(f'encoding={aff.encoding} flag_type={aff.flag_type}')
print(f'sfx rules: {list(aff.sfx_rules.keys())}')
for flag, rule in aff.sfx_rules.items():
    for e in rule.entries:
        print(f'  flag={flag} strip={e.strip!r} append={e.append!r} cond={e.condition}')
"
```

Expected output approximately:
```
encoding=UTF-8 flag_type=num
sfx rules: ['1', '4', '3', '2']
  flag=1 strip='' append='ς' cond=.
  flag=4 strip='' append='υ' cond=.
  flag=3 strip='' append='ι' cond=.
  flag=2 strip='' append='ν' cond=.
```

- [ ] **Step 6: Commit**

```bash
git add dict_generation/aff_parse.py dict_generation/tests/test_aff_parse.py
git commit -m "tier-c: add Hunspell .aff parser (SET / FLAG num / SFX rules)"
```

---

## Task 6: Affix expansion (.dic → surface forms)

**Files:**
- Create: `dict_generation/affix_expand.py`
- Create: `dict_generation/tests/test_affix_expand.py`

A `.dic` line is `<stem>` or `<stem>/<flag1,flag2,…>`. For each flag listed, look up the corresponding SFX rule, apply each of its entries to the stem, yield the resulting surface form. The original stem is always yielded too.

The first line of the .dic file is a count (we ignore it; it's just metadata).

Some real-world entries have non-numeric flags (e.g. `Η/Υ`, `α/α`) that don't match any SFX rule — these are noise from the source data. We log-and-skip them rather than crash.

- [ ] **Step 1: Write failing tests**

Write `dict_generation/tests/test_affix_expand.py`:

```python
import unittest
from dict_generation.aff_parse import AffFile, SfxRule, SfxEntry
from dict_generation.affix_expand import expand_dic, expand_line


def _aff_with_simple_sfx() -> AffFile:
    aff = AffFile()
    aff.sfx_rules["1"] = SfxRule(flag="1", cross_product=True, entries=[
        SfxEntry(strip="", append="ς", condition="."),
    ])
    aff.sfx_rules["2"] = SfxRule(flag="2", cross_product=True, entries=[
        SfxEntry(strip="", append="ν", condition="."),
    ])
    return aff


class ExpandLineTests(unittest.TestCase):

    def setUp(self):
        self.aff = _aff_with_simple_sfx()

    def test_stem_with_no_flags_yields_only_stem(self):
        self.assertEqual(list(expand_line("καλημέρα", self.aff)), ["καλημέρα"])

    def test_stem_with_one_flag_yields_stem_plus_appended(self):
        result = list(expand_line("καλο/1", self.aff))
        self.assertEqual(set(result), {"καλο", "καλος"})

    def test_stem_with_multiple_flags_yields_each_application(self):
        result = list(expand_line("καλο/1,2", self.aff))
        self.assertEqual(set(result), {"καλο", "καλος", "καλον"})

    def test_unknown_flag_is_skipped(self):
        # /Υ is in the dic but not in any SFX rule — should yield only the stem.
        result = list(expand_line("Η/Υ", self.aff))
        self.assertEqual(result, ["Η"])

    def test_blank_line_yields_nothing(self):
        self.assertEqual(list(expand_line("", self.aff)), [])

    def test_comment_line_yields_nothing(self):
        self.assertEqual(list(expand_line("# this is a comment", self.aff)), [])


class ExpandDicTests(unittest.TestCase):

    def setUp(self):
        self.aff = _aff_with_simple_sfx()

    def test_skips_count_header(self):
        text = "3\nκαλημέρα\nώρα\nώραια\n"
        result = list(expand_dic(text, self.aff))
        self.assertEqual(set(result), {"καλημέρα", "ώρα", "ώραια"})

    def test_full_pipeline_with_flags(self):
        text = "2\nκαλο/1\nώρα\n"
        result = list(expand_dic(text, self.aff))
        self.assertEqual(set(result), {"καλο", "καλος", "ώρα"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
python3 -m unittest dict_generation.tests.test_affix_expand -v 2>&1 | head -10
```

Expected: ImportError.

- [ ] **Step 3: Implement the expander**

Write `dict_generation/affix_expand.py`:

```python
"""Expand a Hunspell .dic file into all surface forms by applying SFX
rules referenced via FLAG num.

Yields strings (surface forms) one at a time so callers can stream
through millions of entries without holding them all in memory.
"""
from typing import Iterable, Iterator
from .aff_parse import AffFile


def expand_line(line: str, aff: AffFile) -> Iterator[str]:
    """Yield the stem and every surface form derivable via its flags."""
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return
    if "/" in stripped:
        stem, flag_part = stripped.split("/", 1)
    else:
        stem, flag_part = stripped, ""
    if not stem:
        return
    yield stem
    if not flag_part:
        return
    # Numeric flags are comma-separated under FLAG num.
    flags = [f.strip() for f in flag_part.split(",") if f.strip()]
    for flag in flags:
        rule = aff.sfx_rules.get(flag)
        if rule is None:
            # Non-numeric or unmapped flags appear in the data (e.g. /Υ, /α).
            # These are source-data noise; skip silently.
            continue
        for entry in rule.entries:
            if entry.applies_to(stem):
                yield entry.apply(stem)


def expand_dic(text: str, aff: AffFile) -> Iterator[str]:
    """Yield every surface form across the whole .dic.

    The first non-blank, non-comment line is the count header (per
    Hunspell convention); we skip it.
    """
    seen_count = False
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        if not seen_count and s.isdigit():
            seen_count = True
            continue
        seen_count = True  # tolerate a missing count header
        yield from expand_line(raw, aff)


def expand_dic_file(dic_path: str, aff: AffFile) -> Iterator[str]:
    with open(dic_path, encoding=aff.encoding) as f:
        text = f.read()
    yield from expand_dic(text, aff)
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.tests.test_affix_expand -v
```

Expected: all 8 tests pass.

- [ ] **Step 5: Run on real el_CY.dic; report total surface form count**

```bash
python3 -c "
from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
aff = parse_aff(open('dict/el_CY.aff', encoding='utf-8').read())
count = 0
for _ in expand_dic_file('dict/el_CY.dic', aff):
    count += 1
print(f'total surface forms: {count}')
"
```

Expected: somewhere between **800k and 1.5M** surface forms (677k stems + ~28% expanded). If you get fewer than 700k or more than 3M, something is wrong — investigate before continuing.

- [ ] **Step 6: Commit**

```bash
git add dict_generation/affix_expand.py dict_generation/tests/test_affix_expand.py
git commit -m "tier-c: add affix expansion (.dic stems × SFX rules → surface forms)"
```

---

## Task 7: DAWG data model + naïve insertion (no minimization yet)

**Files:**
- Create: `dict_generation/dawg.py`
- Create: `dict_generation/tests/test_dawg.py`

We build the DAWG in two TDD passes: this task gets a working trie (no suffix sharing) and lookup, the next task adds the minimization that actually makes it a DAWG. Splitting it makes the algorithm tractable and each pass independently verifiable.

The Daciuk incremental construction algorithm requires input words to be sorted. We assume the caller sorts.

- [ ] **Step 1: Write failing tests for the trie phase**

Write `dict_generation/tests/test_dawg.py`:

```python
import unittest
from dict_generation.dawg import Dawg


class DawgTrieTests(unittest.TestCase):
    """Phase-1 tests: build behaves like a plain trie. Minimization is
    added in the next task; lookup behavior must hold either way."""

    def test_empty_dawg_contains_nothing(self):
        d = Dawg()
        self.assertFalse(d.contains("foo"))

    def test_insert_and_lookup_single_word(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=0)
        self.assertTrue(d.contains("καλο"))
        self.assertFalse(d.contains("καλ"))   # prefix not terminal
        self.assertFalse(d.contains("καλος")) # extension not terminal

    def test_insert_sorted_two_words(self):
        d = Dawg()
        d.insert_sorted("κα", payload=0)
        d.insert_sorted("καλο", payload=1)
        self.assertTrue(d.contains("κα"))
        self.assertTrue(d.contains("καλο"))

    def test_unsorted_input_raises(self):
        d = Dawg()
        d.insert_sorted("β", payload=0)
        with self.assertRaises(ValueError):
            d.insert_sorted("α", payload=1)  # α < β

    def test_payload_retrieval(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=42)
        d.insert_sorted("νερο", payload=43)
        self.assertEqual(d.payload_for("καλο"), 42)
        self.assertEqual(d.payload_for("νερο"), 43)
        self.assertIsNone(d.payload_for("σπιτι"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run, verify failure**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v 2>&1 | head -10
```

Expected: ImportError.

- [ ] **Step 3: Implement the trie skeleton**

Write `dict_generation/dawg.py`:

```python
"""Incremental DAWG construction (Daciuk algorithm) for sorted input.

Two-phase: this file currently builds a plain trie (each word gets its
own path). The next task adds suffix-sharing minimization. The public
interface (insert_sorted, contains, payload_for) is the same after
minimization is added — only the internal node sharing changes.

Reference: Daciuk, Mihov, Watson, Watson, "Incremental Construction
of Minimal Acyclic Finite-State Automata", Computational Linguistics
26(1), 2000.
"""
from typing import Dict, List, Optional


class _Node:
    __slots__ = ("edges", "terminal_payload", "id")

    def __init__(self):
        self.edges: Dict[str, "_Node"] = {}
        self.terminal_payload: Optional[int] = None  # None = not a terminal
        self.id: int = -1  # assigned during finalization


class Dawg:
    def __init__(self):
        self._root = _Node()
        self._last_word: Optional[str] = None

    def insert_sorted(self, word: str, payload: int) -> None:
        """Insert a word with an associated terminal payload index. Words must arrive in sorted order."""
        if self._last_word is not None and word <= self._last_word:
            raise ValueError(
                f"insert_sorted requires strictly increasing input; got {word!r} after {self._last_word!r}"
            )
        self._last_word = word
        node = self._root
        for ch in word:
            nxt = node.edges.get(ch)
            if nxt is None:
                nxt = _Node()
                node.edges[ch] = nxt
            node = nxt
        node.terminal_payload = payload

    def contains(self, word: str) -> bool:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return False
        return node.terminal_payload is not None

    def payload_for(self, word: str) -> Optional[int]:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return None
        return node.terminal_payload
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add dict_generation/dawg.py dict_generation/tests/test_dawg.py
git commit -m "tier-c: add DAWG skeleton with sorted-input trie insertion + lookup"
```

---

## Task 8: DAWG minimization (Daciuk incremental)

**Files:**
- Modify: `dict_generation/dawg.py`
- Modify: `dict_generation/tests/test_dawg.py` (add minimization tests)

Daciuk's incremental algorithm: as we insert each new sorted word, the previous word's "tail" (the chain of nodes that diverge from the new word's prefix) is now finalized — no future insertion can change it. We register those finalized nodes in an equivalence map (keyed by `(terminal_payload, sorted_edges_tuple)`) and replace duplicates with the canonical instance. Suffix sharing.

- [ ] **Step 1: Add minimization-effectiveness tests**

Append to `dict_generation/tests/test_dawg.py`:

```python
class DawgMinimizationTests(unittest.TestCase):

    def test_shared_suffix_collapses_to_one_node(self):
        # Three words sharing a common suffix "ος" must produce exactly
        # one shared subgraph for that suffix after finalization.
        d = Dawg()
        for w in ["αλος", "βελος", "γελος"]:
            d.insert_sorted(w, payload=0)
        d.finalize()
        # All three words still resolve.
        for w in ["αλος", "βελος", "γελος"]:
            self.assertTrue(d.contains(w))
        # Node count should be much less than the naïve 3×3 = 9 unique
        # suffix nodes a plain trie would produce. We don't pin an exact
        # number (depends on implementation), but it must drop.
        self.assertLess(d.node_count(), 9)

    def test_finalize_is_idempotent(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=0)
        d.finalize()
        d.finalize()  # second call must not blow up
        self.assertTrue(d.contains("καλο"))

    def test_insert_after_finalize_raises(self):
        d = Dawg()
        d.insert_sorted("α", payload=0)
        d.finalize()
        with self.assertRaises(RuntimeError):
            d.insert_sorted("β", payload=1)

    def test_real_word_set_node_count_drops(self):
        # Fixture: a subset of inflections that share Greek suffixes.
        words = sorted({
            "καλο", "καλος", "καλον", "καλου", "καλους",
            "νεο", "νεος", "νεον", "νεου", "νεους",
            "μικρο", "μικρος", "μικρον", "μικρου", "μικρους",
        })
        d = Dawg()
        for w in words:
            d.insert_sorted(w, payload=0)
        d.finalize()
        for w in words:
            self.assertTrue(d.contains(w))
        # Plain trie would be sum-of-distinct-paths nodes. The DAWG
        # should compress meaningfully — fewer nodes than the trie
        # would have.
        trie_nodes_upper_bound = sum(len(w) for w in words)
        self.assertLess(d.node_count(), trie_nodes_upper_bound // 2)
```

- [ ] **Step 2: Run new tests, verify they fail**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v 2>&1 | tail -20
```

Expected: failures referencing missing `finalize()` and `node_count()`.

- [ ] **Step 3: Implement minimization**

Modify `dict_generation/dawg.py`. Replace the `Dawg` class with:

```python
class Dawg:
    def __init__(self):
        self._root = _Node()
        self._last_word: Optional[str] = None
        self._unchecked: List[tuple] = []   # (parent, char, child) trail of nodes still mutable
        # Registry maps a node's signature (tuple of (char, child_id) pairs + terminal payload)
        # to the canonical _Node already in the DAWG.
        self._registry: Dict[tuple, _Node] = {}
        self._next_node_id = 0
        self._finalized = False

    def insert_sorted(self, word: str, payload: int) -> None:
        if self._finalized:
            raise RuntimeError("Cannot insert into a finalized DAWG")
        if self._last_word is not None and word <= self._last_word:
            raise ValueError(
                f"insert_sorted requires strictly increasing input; got {word!r} after {self._last_word!r}"
            )

        # Find the longest common prefix between word and last_word.
        common_prefix_len = 0
        if self._last_word is not None:
            for a, b in zip(self._last_word, word):
                if a != b:
                    break
                common_prefix_len += 1

        # The unchecked trail beyond the common prefix is now finalized
        # (no future word can extend into it because words come sorted).
        self._minimize(common_prefix_len)

        # Walk to the prefix node along the unchecked trail (still mutable).
        if common_prefix_len == 0:
            node = self._root
        else:
            # After _minimize, _unchecked has exactly common_prefix_len entries.
            node = self._unchecked[-1][2] if self._unchecked else self._root

        # Add the suffix as fresh nodes.
        for ch in word[common_prefix_len:]:
            child = _Node()
            node.edges[ch] = child
            self._unchecked.append((node, ch, child))
            node = child
        node.terminal_payload = payload

        self._last_word = word

    def _minimize(self, down_to: int) -> None:
        """Register any unchecked nodes deeper than `down_to` into the canonical registry,
        sharing suffixes with previously-registered nodes where possible."""
        while len(self._unchecked) > down_to:
            parent, ch, child = self._unchecked.pop()
            sig = self._signature(child)
            existing = self._registry.get(sig)
            if existing is not None:
                parent.edges[ch] = existing
            else:
                child.id = self._next_node_id
                self._next_node_id += 1
                self._registry[sig] = child

    def _signature(self, node: _Node) -> tuple:
        # A node's identity for sharing: terminal payload + sorted edges keyed by child id.
        # Children must already be registered (have an assigned id) at this point.
        edges_sig = tuple(sorted((ch, c.id) for ch, c in node.edges.items()))
        return (node.terminal_payload, edges_sig)

    def finalize(self) -> None:
        if self._finalized:
            return
        self._minimize(0)
        # Assign id to root (it doesn't go through _minimize).
        self._root.id = self._next_node_id
        self._next_node_id += 1
        self._finalized = True

    def node_count(self) -> int:
        return self._next_node_id

    def contains(self, word: str) -> bool:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return False
        return node.terminal_payload is not None

    def payload_for(self, word: str) -> Optional[int]:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return None
        return node.terminal_payload

    def root(self) -> "_Node":
        return self._root
```

- [ ] **Step 4: Run all DAWG tests, verify they pass**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v
```

Expected: all 9 tests pass (5 trie + 4 minimization).

- [ ] **Step 5: Sanity-check on a 1k-word slice of the real dict**

```bash
python3 -c "
from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.phonetic_fold import load_default_folder
from dict_generation.dawg import Dawg

aff = parse_aff(open('dict/el_CY.aff', encoding='utf-8').read())
fold = load_default_folder()
forms = list(expand_dic_file('dict/el_CY.dic', aff))[:5000]
folded = sorted(set(fold.fold(f) for f in forms))
d = Dawg()
for i, k in enumerate(folded):
    d.insert_sorted(k, payload=i)
d.finalize()
print(f'unique folded keys: {len(folded)}, dawg nodes: {d.node_count()}')
"
```

Expected: dawg nodes is 30-70% of the total characters in the input set. Print the ratio. If the ratio is >100% something is wrong.

- [ ] **Step 6: Commit**

```bash
git add dict_generation/dawg.py dict_generation/tests/test_dawg.py
git commit -m "tier-c: add DAWG suffix-sharing minimization (Daciuk incremental)"
```

---

## Task 9: DAWG serialization to binary format

**Files:**
- Modify: `dict_generation/dawg.py`
- Modify: `dict_generation/tests/test_dawg.py`
- Create: `dict_generation/DAWG_FORMAT.md`

We define a versioned binary format that the Phase 2 Swift reader will consume. Goals: little-endian (matches iOS), self-describing header, simple enough that the Swift reader is also <200 LOC.

**Format spec (v1):**

```
[0..3]   magic = b"DAWG" (4 bytes)
[4..5]   version = 1 (uint16 LE)
[6..7]   reserved = 0 (uint16 LE)
[8..11]  node_count (uint32 LE)
[12..15] payload_count (uint32 LE)
[16..19] string_table_count (uint32 LE)
[20..23] node_section_offset (uint32 LE)
[24..27] payload_section_offset (uint32 LE)
[28..31] string_table_offset (uint32 LE)

Node section: node_count records. Each node:
  [0..1]   edge_count (uint16 LE)
  [2..5]   terminal_payload_idx (uint32 LE; 0xFFFFFFFF = not terminal)
  [6..]    edges, sorted by character: edge_count * (
              char_utf32 (uint32 LE),    # the character code point
              target_node_idx (uint32 LE),
           ) = edge_count * 8 bytes

Nodes are stored in arbitrary order; child references use node indices
into this section. The root is the LAST node (highest index) — assigned
during finalize() after all children.

Payload section: payload_count records. Each:
  [0..1]   canonical_form_count (uint16 LE)
  [2..]    canonical_form_count * (string_table_idx: uint32 LE, freq: uint32 LE) = count * 8 bytes

String table: string_table_count records, each:
  [0..1]   length_in_utf8_bytes (uint16 LE)
  [2..]    utf8_bytes (length_in_utf8_bytes bytes)

Strings are referenced by their index in the table (0-based). The
encoder dedupes strings; multiple payloads pointing at the same
canonical form share an index.
```

For Phase 1, payloads carry only `payload_idx → list[(canonical_string_idx, freq)]`. The build orchestrator (Task 10) produces these tuples; Task 9 just serializes them.

- [ ] **Step 1: Add serialization tests**

Append to `dict_generation/tests/test_dawg.py`:

```python
import io
import struct


class DawgSerializationTests(unittest.TestCase):

    def _build_fixture(self):
        d = Dawg()
        for word in ["αβ", "αγ", "βα"]:
            d.insert_sorted(word, payload=0)  # all share payload 0 for this fixture
        d.finalize()
        # Single payload entry for the fixture.
        payloads = [
            [(0, 100)],  # canonical form #0, freq 100
        ]
        strings = ["καλημέρα"]
        return d, payloads, strings

    def test_serialize_writes_magic_header(self):
        d, payloads, strings = self._build_fixture()
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        data = buf.getvalue()
        self.assertEqual(data[:4], b"DAWG")
        version = struct.unpack_from("<H", data, 4)[0]
        self.assertEqual(version, 1)

    def test_round_trip_through_dawg_reader(self):
        d, payloads, strings = self._build_fixture()
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        from dict_generation.dawg import DawgReader
        reader = DawgReader(buf.getvalue())
        # Same words must be findable.
        for word in ["αβ", "αγ", "βα"]:
            self.assertTrue(reader.contains(word), f"missing: {word}")
        # Non-members not found.
        self.assertFalse(reader.contains("γγ"))
        # Payload retrieval round-trips.
        idx = reader.payload_for("αβ")
        self.assertEqual(idx, 0)
        canonical_form_records = reader.canonical_forms(idx)
        self.assertEqual(canonical_form_records, [("καλημέρα", 100)])

    def test_round_trip_with_realistic_size(self):
        # Insert a few hundred sorted folded keys + payloads, round-trip,
        # confirm every key is still findable.
        words = sorted({f"a{i:04d}" for i in range(200)})  # 200 lexicographically-sorted strings
        d = Dawg()
        for i, w in enumerate(words):
            d.insert_sorted(w, payload=i)
        d.finalize()
        payloads = [[(0, 1)] for _ in words]
        strings = ["x"]
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        from dict_generation.dawg import DawgReader
        reader = DawgReader(buf.getvalue())
        for i, w in enumerate(words):
            self.assertEqual(reader.payload_for(w), i, f"payload mismatch for {w!r}")
```

- [ ] **Step 2: Run, verify failure**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v 2>&1 | tail -10
```

Expected: AttributeError on `serialize` and ImportError on `DawgReader`.

- [ ] **Step 3: Implement serializer + reader**

Append to the end of `dict_generation/dawg.py` (after the existing `class Dawg`):

```python
import struct
from typing import BinaryIO, List, Tuple


# --- Serializer ---

_MAGIC = b"DAWG"
_VERSION = 1
_NULL_PAYLOAD = 0xFFFFFFFF


def _walk_nodes(root: "_Node") -> List["_Node"]:
    """Return all reachable nodes in deterministic order. Root last."""
    seen: Dict[int, "_Node"] = {}
    order: List["_Node"] = []
    stack = [root]
    while stack:
        node = stack.pop()
        if node.id in seen:
            continue
        seen[node.id] = node
        order.append(node)
        for _, child in sorted(node.edges.items()):
            stack.append(child)
    # Sort so root is last (per format spec). Within ids, stable.
    order.sort(key=lambda n: n.id)
    return order


# Defined as a free function and attached to Dawg via assignment below
# (Python "monkey-patch as method"). This keeps Task 9's diff isolated
# from Task 8's class body.
def _dawg_serialize(self, out: BinaryIO, payloads: List[List[Tuple[int, int]]], strings: List[str]) -> None:
    """Write self to `out` in the v1 binary format.

    payloads: list indexed by terminal payload id; each entry is a list of
              (string_idx, freq) tuples for that key's canonical forms.
    strings:  list of canonical form strings; payload tuples reference by index.
    """
    if not self._finalized:
        raise RuntimeError("DAWG must be finalized before serialization")

    nodes = _walk_nodes(self._root)
    # Re-number nodes so root is last (matches format spec).
    id_map = {n.id: i for i, n in enumerate(nodes)}

    # ---- Build node bytes
    node_bytes = bytearray()
    for node in nodes:
        edges = sorted(node.edges.items())
        node_bytes += struct.pack("<H", len(edges))
        node_bytes += struct.pack("<I", node.terminal_payload if node.terminal_payload is not None else _NULL_PAYLOAD)
        for ch, child in edges:
            cp = ord(ch) if len(ch) == 1 else 0  # multi-codepoint chars not supported in keys
            node_bytes += struct.pack("<II", cp, id_map[child.id])

    # ---- Build string table bytes
    str_bytes = bytearray()
    str_offsets: List[int] = []
    for s in strings:
        encoded = s.encode("utf-8")
        if len(encoded) > 0xFFFF:
            raise ValueError(f"string too long for v1 format: {len(encoded)} bytes")
        str_offsets.append(len(str_bytes))
        str_bytes += struct.pack("<H", len(encoded))
        str_bytes += encoded

    # ---- Build payload bytes
    payload_bytes = bytearray()
    payload_offsets: List[int] = []
    for entry in payloads:
        payload_offsets.append(len(payload_bytes))
        payload_bytes += struct.pack("<H", len(entry))
        for str_idx, freq in entry:
            payload_bytes += struct.pack("<II", str_idx, freq)

    # ---- Compute offsets and write header
    HEADER_SIZE = 32
    node_section_offset = HEADER_SIZE
    payload_section_offset = node_section_offset + len(node_bytes)
    string_table_offset = payload_section_offset + len(payload_bytes)

    out.write(_MAGIC)
    out.write(struct.pack("<HH", _VERSION, 0))
    out.write(struct.pack("<III", len(nodes), len(payloads), len(strings)))
    out.write(struct.pack("<III", node_section_offset, payload_section_offset, string_table_offset))
    out.write(node_bytes)
    out.write(payload_bytes)
    out.write(str_bytes)


# Wire the method into the Dawg class.
Dawg.serialize = _dawg_serialize


# --- Reader ---

class DawgReader:
    """Reads the v1 binary format. Mirrors the Swift Phase 2 reader's
    contract — used in tests to round-trip the writer."""

    def __init__(self, data: bytes):
        if data[:4] != _MAGIC:
            raise ValueError("not a DAWG file (bad magic)")
        version = struct.unpack_from("<H", data, 4)[0]
        if version != _VERSION:
            raise ValueError(f"unsupported DAWG version {version}")
        self._data = data
        self._node_count = struct.unpack_from("<I", data, 8)[0]
        self._payload_count = struct.unpack_from("<I", data, 12)[0]
        self._string_count = struct.unpack_from("<I", data, 16)[0]
        self._node_off = struct.unpack_from("<I", data, 20)[0]
        self._payload_off = struct.unpack_from("<I", data, 24)[0]
        self._string_off = struct.unpack_from("<I", data, 28)[0]
        # Pre-index node offsets within the node section since records vary in size.
        self._node_offsets = self._index_nodes()
        self._payload_offsets = self._index_payloads()
        self._string_offsets = self._index_strings()

    def _index_nodes(self) -> List[int]:
        offs = []
        cursor = self._node_off
        for _ in range(self._node_count):
            offs.append(cursor)
            edge_count = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + 4 + edge_count * 8
        return offs

    def _index_payloads(self) -> List[int]:
        offs = []
        cursor = self._payload_off
        for _ in range(self._payload_count):
            offs.append(cursor)
            cf_count = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + cf_count * 8
        return offs

    def _index_strings(self) -> List[int]:
        offs = []
        cursor = self._string_off
        for _ in range(self._string_count):
            offs.append(cursor)
            ln = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + ln
        return offs

    def _root_idx(self) -> int:
        # Root is the last node (per format spec).
        return self._node_count - 1

    def contains(self, word: str) -> bool:
        return self.payload_for(word) is not None

    def payload_for(self, word: str) -> Optional[int]:
        idx = self._root_idx()
        for ch in word:
            idx = self._step(idx, ord(ch))
            if idx is None:
                return None
        return self._terminal_payload(idx)

    def _step(self, node_idx: int, char_code: int) -> Optional[int]:
        off = self._node_offsets[node_idx]
        edge_count = struct.unpack_from("<H", self._data, off)[0]
        edge_off = off + 2 + 4
        # Linear scan; edges are sorted, but for the python tests this is fine.
        for i in range(edge_count):
            cp, tgt = struct.unpack_from("<II", self._data, edge_off + i * 8)
            if cp == char_code:
                return tgt
            if cp > char_code:
                return None
        return None

    def _terminal_payload(self, node_idx: int) -> Optional[int]:
        off = self._node_offsets[node_idx]
        payload = struct.unpack_from("<I", self._data, off + 2)[0]
        return None if payload == _NULL_PAYLOAD else payload

    def canonical_forms(self, payload_idx: int) -> List[Tuple[str, int]]:
        off = self._payload_offsets[payload_idx]
        cf_count = struct.unpack_from("<H", self._data, off)[0]
        records = []
        for i in range(cf_count):
            str_idx, freq = struct.unpack_from("<II", self._data, off + 2 + i * 8)
            s_off = self._string_offsets[str_idx]
            ln = struct.unpack_from("<H", self._data, s_off)[0]
            s = self._data[s_off + 2 : s_off + 2 + ln].decode("utf-8")
            records.append((s, freq))
        return records
```

- [ ] **Step 4: Run, verify all tests pass**

```bash
python3 -m unittest dict_generation.tests.test_dawg -v
```

Expected: all 12 tests pass (5 trie + 4 minimization + 3 serialization).

- [ ] **Step 5: Document the format**

Write `dict_generation/DAWG_FORMAT.md`:

```markdown
# DAWG binary format v1

Used by tier-c. Produced by `dict_generation/dawg.py`'s `Dawg.serialize`,
consumed by the Phase 2 Swift runtime reader.

## Header (32 bytes)

| offset | size | field                  |
|--------|------|------------------------|
| 0      | 4    | magic = `b"DAWG"`      |
| 4      | 2    | version (uint16 LE)    |
| 6      | 2    | reserved = 0           |
| 8      | 4    | node_count             |
| 12     | 4    | payload_count          |
| 16     | 4    | string_table_count     |
| 20     | 4    | node_section_offset    |
| 24     | 4    | payload_section_offset |
| 28     | 4    | string_table_offset    |

All multi-byte integers little-endian.

## Node section

`node_count` variable-length records. Each node:

| size | field                                                |
|------|------------------------------------------------------|
| 2    | edge_count (uint16 LE)                               |
| 4    | terminal_payload_idx (uint32 LE; `0xFFFFFFFF` = none)|
| ...  | edge_count × edge record (8 bytes each)              |

Edge record:

| size | field                  |
|------|------------------------|
| 4    | char_codepoint (uint32 LE) |
| 4    | target_node_idx (uint32 LE) |

Edges within a node are stored sorted ascending by `char_codepoint`.
Readers may binary-search.

The **root** is the last node (`node_idx = node_count - 1`).

## Payload section

`payload_count` variable-length records. Each payload entry:

| size | field                                  |
|------|----------------------------------------|
| 2    | canonical_form_count (uint16 LE)       |
| ...  | canonical_form_count × 8-byte records  |

Each canonical-form record:

| size | field            |
|------|------------------|
| 4    | string_idx (uint32 LE) |
| 4    | freq       (uint32 LE) |

## String table

`string_table_count` variable-length records. Each:

| size | field                              |
|------|------------------------------------|
| 2    | length_in_utf8_bytes (uint16 LE)   |
| ...  | UTF-8 bytes                        |

Strings are referenced by their position (0-based index) in this table.
The encoder dedupes; multiple payloads can share a string index.

## Versioning

Readers MUST verify magic + version. Unknown versions = reject.

Future format extensions go in version 2+. Version 1 will not be
mutated after Phase 1 ships.
```

- [ ] **Step 6: Commit**

```bash
git add dict_generation/dawg.py dict_generation/tests/test_dawg.py dict_generation/DAWG_FORMAT.md
git commit -m "tier-c: add DAWG v1 binary serializer + reader + format spec"
```

---

## Task 10: Build orchestrator

**Files:**
- Create: `dict_generation/build_dawg.py`

Wires together aff_parse, affix_expand, phonetic_fold, frequency lookup, and DAWG construction. Single entry point: `python3 build_dawg.py` reads `dict/el_CY.dic`, `dict/el_CY.aff`, `dict_generation/corpus_freq.json`, writes `dict/el_CY.dawg`.

- [ ] **Step 1: Write the orchestrator**

Write `dict_generation/build_dawg.py`:

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
from typing import Dict

# Allow running as a script regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import Dawg
from dict_generation.phonetic_fold import load_default_folder


DEFAULT_FREQ = 1


def build(dic_path: str, aff_path: str, freq_path: str, out_path: str) -> None:
    print(f"[build_dawg] parsing {aff_path}")
    aff = parse_aff(open(aff_path, encoding="utf-8").read())

    print(f"[build_dawg] loading frequency table from {freq_path}")
    try:
        with open(freq_path, encoding="utf-8") as f:
            corpus_freq: Dict[str, int] = json.load(f)
    except FileNotFoundError:
        print(f"[build_dawg] WARNING: {freq_path} not found; all freqs default to {DEFAULT_FREQ}")
        corpus_freq = {}

    print(f"[build_dawg] expanding {dic_path} → surface forms")
    folder = load_default_folder()
    grouped: Dict[str, Dict[str, int]] = defaultdict(dict)
    n_forms = 0
    for surface in expand_dic_file(dic_path, aff):
        n_forms += 1
        key = folder.fold(surface)
        freq = corpus_freq.get(surface.lower(), DEFAULT_FREQ)
        # If multiple paths produce the same canonical+key, take the max freq.
        prev = grouped[key].get(surface, 0)
        if freq > prev:
            grouped[key][surface] = freq
        if n_forms % 100000 == 0:
            print(f"[build_dawg]   {n_forms} surface forms processed")

    print(f"[build_dawg] {n_forms} surface forms → {len(grouped)} unique fold keys")

    # Build a string table (deduped canonical forms) and a payload table (per fold key).
    string_index: Dict[str, int] = {}
    strings = []
    payloads = []
    sorted_keys = sorted(grouped.keys())
    payload_for_key: Dict[str, int] = {}
    for key in sorted_keys:
        canonical_forms = grouped[key]
        # Sort canonical forms within a key by freq descending then alphabetical
        ranked = sorted(canonical_forms.items(), key=lambda kv: (-kv[1], kv[0]))
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

    print(f"[build_dawg] inserting into DAWG (this may take a minute)")
    dawg = Dawg()
    for key in sorted_keys:
        dawg.insert_sorted(key, payload=payload_for_key[key])
    dawg.finalize()
    print(f"[build_dawg] DAWG nodes: {dawg.node_count()}")

    print(f"[build_dawg] serializing → {out_path}")
    with open(out_path, "wb") as out:
        dawg.serialize(out, payloads=payloads, strings=strings)
    size = os.path.getsize(out_path)
    print(f"[build_dawg] wrote {size:,} bytes ({size/1024/1024:.2f} MB)")


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

- [ ] **Step 2: Smoke-run end-to-end**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
# Make sure corpus_freq.json exists from Task 4
ls dict_generation/corpus_freq.json
# Run build
python3 dict_generation/build_dawg.py 2>&1 | tail -20
ls -lh dict/el_CY.dawg
```

Expected:
- runs to completion in <2 minutes,
- prints `surface forms processed` and `unique fold keys` and `DAWG nodes`,
- emits `dict/el_CY.dawg` between **2 MB and 8 MB**.

If output size is outside that range, investigate. Bigger than 10 MB likely means minimization isn't triggering — re-check Task 8 tests.

- [ ] **Step 3: Round-trip a few sample lookups**

```bash
python3 -c "
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder
fold = load_default_folder()
reader = DawgReader(open('dict/el_CY.dawg', 'rb').read())
for word in ['καλημέρα', 'καλιμερα', 'kalimera_unicode_test', 'αυτοκίνητο', 'και', 'unknownxyzword']:
    key = fold.fold(word)
    pidx = reader.payload_for(key)
    if pidx is None:
        print(f'  {word!r:25s} key={key!r:20s} -> NOT FOUND')
    else:
        forms = reader.canonical_forms(pidx)[:3]
        print(f'  {word!r:25s} key={key!r:20s} -> {forms}')
"
```

Expected: known Greek words round-trip to a list of canonical forms with non-zero frequencies; unknown words return NOT FOUND. `'καλημέρα'` and `'καλιμερα'` should map to the same payload (the phonetic fold is doing its job).

- [ ] **Step 4: Commit**

```bash
git add dict_generation/build_dawg.py dict/el_CY.dawg
git commit -m "tier-c: add build_dawg.py orchestrator + first generated dict/el_CY.dawg

Reads dict/el_CY.{dic,aff} + dict_generation/corpus_freq.json,
phonetic-folds + groups + ranks surface forms, builds a minimized
DAWG, serializes to dict/el_CY.dawg in the v1 binary format.
First generated artifact committed for Phase 2's Swift reader to
consume during runtime development."
```

---

## Task 11: Makefile integration

**Files:**
- Modify: `dict_generation/Makefile`

Add an `el_CY.dawg` target so `make el_CY.dawg` and `make install` produce the artifact alongside the existing `.dic`/`.aff` outputs.

- [ ] **Step 1: Read the existing Makefile**

```bash
cat dict_generation/Makefile
```

Note the existing structure:
- `el_CY.dic` target depends on `sorted_worldlist.tmp` and runs `affixcompress`.
- `install` copies `el_CY.dic` and `el_CY.aff` to both `~/Library/Spelling` and `../dict/`.

- [ ] **Step 2: Add new targets**

Modify `dict_generation/Makefile`. Insert these targets after the existing `install:` target (preserve all existing rules verbatim — don't disturb `el_CY.dic` or `install`):

```makefile

# tier-c: build the phonetic-folded DAWG from the existing .dic + .aff
# plus the corpus-derived frequency table.
corpus_freq.json:
	python3 list_words.py
	# list_words.py emits both el_CY_words.v3.dic AND corpus_freq.json
	# in the same run; the latter is what this target produces.

../dict/el_CY.dawg: corpus_freq.json
	python3 build_dawg.py \
	  --dic ../dict/el_CY.dic \
	  --aff ../dict/el_CY.aff \
	  --freq corpus_freq.json \
	  --out ../dict/el_CY.dawg

dawg: ../dict/el_CY.dawg

clean_dawg:
	rm -f ../dict/el_CY.dawg
	rm -f corpus_freq.json
```

Also extend the existing `install:` target to depend on the dawg:

```makefile
# was:    install: el_CY.dic el_CY.aff
install: el_CY.dic el_CY.aff ../dict/el_CY.dawg
	cp el_CY.dic ~/Library/Spelling
	cp el_CY.aff ~/Library/Spelling
	cp el_CY.dic ../dict/
	cp el_CY.aff ../dict/
```

(The dawg writes directly to `../dict/` so no cp needed in install.)

- [ ] **Step 3: Verify the new target works from a clean state**

```bash
cd dict_generation
make clean_dawg
make dawg 2>&1 | tail -20
ls -lh ../dict/el_CY.dawg
```

Expected: `make dawg` runs `list_words.py` then `build_dawg.py`, produces `../dict/el_CY.dawg`. Size should match Task 10's output.

- [ ] **Step 4: Commit**

```bash
cd /Users/alext/CypriotKeyboard.tier-c
git add dict_generation/Makefile
git commit -m "tier-c: add Makefile targets for DAWG build (dawg, clean_dawg)"
```

---

## Task 12: Cross-check the DAWG against the source dict

**Files:**
- Create: `dict_generation/tests/test_full_pipeline.py`

End-to-end correctness check: every surface form in `el_CY.dic` should be findable in the DAWG via its phonetic-folded key. Catches whole categories of bugs (lost entries during expansion, miscompressed nodes, frequency-lookup failures).

This test takes a few seconds to run — it's a slow integration test, not part of the unit suite.

- [ ] **Step 1: Write the cross-check test**

Write `dict_generation/tests/test_full_pipeline.py`:

```python
"""End-to-end smoke test against the real built DAWG.

Skipped if dict/el_CY.dawg doesn't exist yet (e.g., on a clean checkout
before `make dawg` has run).

Run explicitly:
    python3 -m unittest dict_generation.tests.test_full_pipeline -v
"""
import os
import random
import unittest

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DAWG_PATH = os.path.join(REPO, "dict", "el_CY.dawg")
DIC_PATH = os.path.join(REPO, "dict", "el_CY.dic")
AFF_PATH = os.path.join(REPO, "dict", "el_CY.aff")


@unittest.skipUnless(os.path.exists(DAWG_PATH), f"{DAWG_PATH} not built; run `make dawg` first")
class FullPipelineTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.reader = DawgReader(open(DAWG_PATH, "rb").read())
        cls.fold = load_default_folder()
        aff = parse_aff(open(AFF_PATH, encoding="utf-8").read())
        # Sample 1000 random surface forms — full enumeration is slow.
        all_forms = list(expand_dic_file(DIC_PATH, aff))
        random.seed(42)
        cls.sample = random.sample(all_forms, k=min(1000, len(all_forms)))

    def test_every_sampled_surface_form_resolves(self):
        misses = []
        for form in self.sample:
            key = self.fold.fold(form)
            payload = self.reader.payload_for(key)
            if payload is None:
                misses.append((form, key))
            else:
                # The canonical-form list for this key must contain `form`.
                forms_in_payload = [s for s, _f in self.reader.canonical_forms(payload)]
                if form not in forms_in_payload:
                    misses.append((form, key))
        self.assertEqual(misses, [], f"{len(misses)} surface forms missing from DAWG; first 10: {misses[:10]}")

    def test_phonetic_collisions_share_a_payload(self):
        # 'καλημέρα' and 'καλιμερα' fold to the same key by design.
        # If both are in the dict, they should resolve to the same payload index.
        key1 = self.fold.fold("καλημέρα")
        p1 = self.reader.payload_for(key1)
        # We don't assert that 'καλιμερα' is in the dict — but if it is,
        # it must point to the same payload.
        key2 = self.fold.fold("καλιμερα")
        self.assertEqual(key1, key2, "These two should fold identically")
        p2 = self.reader.payload_for(key2)
        if p2 is not None:
            self.assertEqual(p1, p2, "Phonetic collision did not share payload")
```

- [ ] **Step 2: Run the cross-check**

```bash
python3 -m unittest dict_generation.tests.test_full_pipeline -v 2>&1 | tail -10
```

Expected: both tests pass. If `test_every_sampled_surface_form_resolves` fails with N misses, look at the first 10 — common causes: a surface form contains an unsupported character that broke serialization; the affix expansion produced something the fold then didn't handle.

- [ ] **Step 3: Commit**

```bash
git add dict_generation/tests/test_full_pipeline.py
git commit -m "tier-c: add end-to-end test cross-checking DAWG against source dict"
```

---

## Phase 1 done

After Task 12, the build pipeline is complete and verified. The artifact at `dict/el_CY.dawg` is ready for Phase 2 (the Swift runtime reader + suggester) to consume. No iOS code has been touched.

**Final sanity check:**

```bash
cd /Users/alext/CypriotKeyboard.tier-c

# All unit tests pass
python3 -m unittest discover dict_generation/tests -v 2>&1 | tail -5

# Makefile rebuilds cleanly
cd dict_generation && make clean_dawg && make dawg
ls -lh ../dict/el_CY.dawg

# Existing iOS tests still pass (Phase 1 didn't touch iOS)
cd ..
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Cypriot KeyboardTests" test 2>&1 | grep -E "Executed|TEST"
```

Expected: ~30+ Python unit tests pass, `el_CY.dawg` weighs 2-8 MB, all 49 iOS unit tests still pass.

**Final commit (if anything is uncommitted):**

```bash
git status
git log --oneline tier-c-dawg --not main
```

Confirm only Phase 1 commits are on the branch. Push when ready:

```bash
git push -u origin tier-c-dawg
```

Phase 2 (Swift runtime, suggester, opt-in setting) is a separate plan, written after Phase 1 lands.
