#!/usr/bin/env python3
"""Run the Greeklish corpus through the iOS-equivalent autocorrect logic.

For each sentence in the corpus, every word is passed through:
  greekify → casing-aware lowercase → fold_variants → greekify_alternatives →
  DamerauLevenshtein suggester (budget=1) → shouldReplace gate → recapitalize.

If `shouldReplace` would be true, the word is substituted with the top
canonical; otherwise it stays verbatim. The result is the sentence the iOS
app would have produced if the user typed the line and tapped space after
each word.

Output is a markdown table you can paste into a review prompt.

Usage:
    python3 dict_generation/eval/run_corpus.py
    python3 dict_generation/eval/run_corpus.py --corpus my_samples.txt
    python3 dict_generation/eval/run_corpus.py --no-hunspell
    python3 dict_generation/eval/run_corpus.py --output-md /tmp/eval.md

Mirrors:
    Cypriot  Custom Keyboard/DAWG/DawgAutocompleteSuggestionProvider.swift
    Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift (shouldReplace)
"""
import argparse
import os
import re
import sys
import unicodedata
from typing import List, Optional

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dict_generation.eval.repl import (
    preprocess_input, postprocess_suggestion, load_engines, _Casing,
)
from dict_generation.eval.hunspell_runner import (
    analyze_via_hunspell, suggest_via_hunspell,
)


# Mirror of DawgAutocompleteSuggestionProvider.altRules (Swift). Keep in sync.
_ALT_RULES = [
    ("αφ", ["αφ", "αυ"]),
    ("Αφ", ["Αφ", "Αυ"]),
    ("εφ", ["εφ", "ευ"]),
    ("Εφ", ["Εφ", "Ευ"]),
    ("αβ", ["αβ", "αυ"]),
    ("Αβ", ["Αβ", "Αυ"]),
    ("εβ", ["εβ", "ευ"]),
    ("Εβ", ["Εβ", "Ευ"]),
    ("θ",  ["θ",  "τη"]),
    ("Θ",  ["Θ",  "Τη"]),
    ("8",  ["8",  "θ"]),
]


def greekify_alternatives(greek: str, max_variants: int = 8) -> List[str]:
    """Branch on Greeklish → Greek ambiguities (αφ↔αυ, εφ↔ευ, αβ↔αυ, εβ↔ευ,
    θ↔τη, 8↔θ). Mirrors the Swift static of the same name."""
    chars = list(greek)
    out: List[str] = []
    seen = set()

    def helper(i: int, acc: str):
        if len(out) >= max_variants:
            return
        if i >= len(chars):
            if acc not in seen:
                seen.add(acc)
                out.append(acc)
            return
        for src, alts in _ALT_RULES:
            src_chars = list(src)
            if i + len(src_chars) > len(chars):
                continue
            if all(chars[i + k] == src_chars[k] for k in range(len(src_chars))):
                for alt in alts:
                    helper(i + len(src_chars), acc + alt)
                return
        helper(i + 1, acc + chars[i])

    helper(0, "")
    return out


# --- shouldReplace (mirror of CypriotKeyboardHelper.shouldReplace) ---

_GREEK_VOWELS = set("αειυηοωaeiouy")


def _strip_diacritics(s: str) -> str:
    nfd = unicodedata.normalize("NFD", s)
    return "".join(c for c in nfd if unicodedata.category(c) != "Mn")


def _count_syllables(text: str) -> int:
    folded = _strip_diacritics(text.lower())
    count = 0
    last_was_vowel = False
    for c in folded:
        is_vowel = c in _GREEK_VOWELS
        if is_vowel and not last_was_vowel:
            count += 1
        last_was_vowel = is_vowel
    return count


def _levenshtein(a: str, b: str) -> int:
    if not a: return len(b)
    if not b: return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, start=1):
        curr = [i] + [0] * len(b)
        for j, cb in enumerate(b, start=1):
            curr[j] = prev[j - 1] if ca == cb else 1 + min(prev[j], curr[j - 1], prev[j - 1])
        prev = curr
    return prev[-1]


def _normalize_final_sigma(s: str) -> str:
    """Collapse final ς onto medial σ for distance comparison. Greekify
    outputs σ at word-end; canonicals use ς. See shouldReplace in the Swift
    side for rationale."""
    return s.replace("ς", "σ")


def should_replace(text: str, greek_text: str, guess: str) -> bool:
    """Mirror of CypriotKeyboardHelper.shouldReplace."""
    if text == greek_text:
        # Pure-Greek input: diacritic-only diff, ≥2 syllables.
        if _count_syllables(text) < 2:
            return False
        aw = _strip_diacritics(text)
        ag = _strip_diacritics(guess)
        if guess != guess.lower():
            return (aw.lower() == ag.lower()
                    and ag != guess
                    and aw.lower() == text.lower())
        return aw == ag and ag != guess and aw == text
    # Greeklish branch: Levenshtein < 3 on accent-folded, σ↔ς-normalised
    # lowercase. Without the σ↔ς fold, every short Greeklish word with one
    # other-character mismatch pays a +1 distance tax that pushes legitimate
    # corrections past the gate.
    a = _normalize_final_sigma(_strip_diacritics(greek_text.lower()))
    b = _normalize_final_sigma(_strip_diacritics(guess.lower()))
    return _levenshtein(a, b) < 3


def should_replace_any(text: str, greek_variants: list, guess: str) -> bool:
    """Mirror of CypriotKeyboardHelper.shouldReplace(text:greekVariants:guess:).
    Passes if ANY of the supplied greekify interpretations would gate true,
    so greekify-shortening cases (th → θ where the user meant τη) don't get
    rejected by the distance check."""
    return any(should_replace(text, gv, guess) for gv in greek_variants)


# --- token-level autocorrect ---

# Whitespace-separated tokens. Trailing punct is peeled off so the lookup
# isn't poisoned by attached commas/periods. Leading punct stays attached
# because preprocess_input handles it (isPunctFirst path).
def _peel_trailing_punct(token: str):
    trailing = ""
    while token and not token[-1].isalpha() and not token[-1].isdigit():
        trailing = token[-1] + trailing
        token = token[:-1]
    return token, trailing


def correct_token_dawg(token: str, folder, suggester) -> str:
    body, trailing = _peel_trailing_punct(token)
    if not body:
        return token
    greekified, lookup_form, casing, leading_punct = preprocess_input(body)
    if not lookup_form:
        return token

    # Multi-fold + greekify alternatives, mirror the iOS DAWG provider.
    is_greeklish = greekified != body and greekified != ""
    greek_variants = greekify_alternatives(lookup_form) if is_greeklish else [lookup_form]
    seen = set()
    fold_keys: List[str] = []
    for variant in greek_variants:
        for key in folder.fold_variants(variant):
            if key not in seen:
                seen.add(key)
                fold_keys.append(key)
    # Casing-aware ranking: pass the input casing through so cap-first
    # inputs prefer cap-first canonicals at the same edit distance.
    # Mirrors DawgAutocompleteSuggestionProvider.swift.
    candidates = suggester.suggest_multi(fold_keys, budget=1, limit=1,
                                         input_casing=casing)
    if not candidates:
        return token
    top = candidates[0]
    displayed = postprocess_suggestion(top.canonical, casing, leading_punct)
    # Multi-variant gating: pass every greekify alternative so greekify-
    # shortening cases (th → θ where the user meant τη, e.g. "afth" → αυτή)
    # aren't rejected by the distance check against the first interpretation.
    # Variants are rooted at `greekified` (case-preserving, post-strip) so
    # the pure-Greek diacritic-only path still matches uppercase Greek input.
    gate_variants = (greekify_alternatives(greekified)
                     if is_greeklish else [greekified])
    if not should_replace_any(body, gate_variants, displayed):
        return token
    return displayed + trailing


def correct_token_hunspell(token: str) -> str:
    body, trailing = _peel_trailing_punct(token)
    if not body:
        return token
    greekified, lookup_form, casing, leading_punct = preprocess_input(body)
    if not lookup_form:
        return token
    # Hunspell: ask if the word is correct. If yes, echo. If no, take its
    # first suggestion only when shouldReplace agrees.
    res = analyze_via_hunspell(lookup_form)
    if res.is_correct:
        return token
    if not res.suggestions:
        return token
    top = res.suggestions[0]
    displayed = postprocess_suggestion(top, casing, leading_punct)
    if not should_replace(body, greekified, displayed):
        return token
    return displayed + trailing


_TOKEN_RE = re.compile(r'\S+')


def autocorrect_line(line: str, folder, suggester, have_hunspell: bool) -> dict:
    """Returns {"input", "dawg", "hunspell" (or None)}."""
    def rebuild(corrector):
        out = []
        last = 0
        for m in _TOKEN_RE.finditer(line):
            out.append(line[last:m.start()])
            out.append(corrector(m.group()))
            last = m.end()
        out.append(line[last:])
        return "".join(out)

    return {
        "input": line,
        "dawg": rebuild(lambda t: correct_token_dawg(t, folder, suggester)),
        "hunspell": rebuild(correct_token_hunspell) if have_hunspell else None,
    }


# --- corpus reader ---

def read_corpus(path: str):
    """Yield (lineno, line) for non-blank, non-comment lines."""
    with open(path, "r", encoding="utf-8") as f:
        for lineno, raw in enumerate(f, start=1):
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            yield lineno, line


# --- output ---

def emit_markdown(rows, have_hunspell: bool, out=sys.stdout):
    if have_hunspell:
        out.write("| # | Input | DAWG | Hunspell |\n")
        out.write("|---|---|---|---|\n")
    else:
        out.write("| # | Input | DAWG |\n")
        out.write("|---|---|---|\n")
    for i, row in enumerate(rows, start=1):
        ip = row["input"].replace("|", "\\|")
        dw = row["dawg"].replace("|", "\\|")
        if have_hunspell:
            hs = (row["hunspell"] or "").replace("|", "\\|")
            out.write(f"| {i} | `{ip}` | {dw} | {hs} |\n")
        else:
            out.write(f"| {i} | `{ip}` | {dw} |\n")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_corpus = os.path.join(here, "greeklish_corpus.txt")

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--corpus", default=default_corpus,
                        help=f"path to corpus file (default: {default_corpus})")
    parser.add_argument("--no-hunspell", action="store_true",
                        help="skip Hunspell column even if hunspell-cli is available")
    parser.add_argument("--output-md", default=None,
                        help="write markdown to this path instead of stdout")
    args = parser.parse_args()

    folder, readers, baseline_suggester, have_hunspell = load_engines()
    if args.no_hunspell:
        have_hunspell = False

    rows = []
    for lineno, line in read_corpus(args.corpus):
        rows.append(autocorrect_line(line, folder, baseline_suggester, have_hunspell))

    if args.output_md:
        with open(args.output_md, "w", encoding="utf-8") as f:
            emit_markdown(rows, have_hunspell, out=f)
        print(f"[run_corpus] wrote {len(rows)} rows to {args.output_md}", file=sys.stderr)
    else:
        emit_markdown(rows, have_hunspell)


if __name__ == "__main__":
    main()
