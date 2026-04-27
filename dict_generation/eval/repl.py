#!/usr/bin/env python3
"""Interactive REPL: type a word, see what each engine returns.

Compares Hunspell baseline + DAWG baseline + DAWG v3_freq1 side-by-side.
Useful for hands-on quality assessment without re-running the full eval.

Usage:
    python3 dict_generation/eval/repl.py            # interactive
    python3 dict_generation/eval/repl.py --batch    # no prompt/banner, for piping
    python3 dict_generation/eval/repl.py --quiet    # suggestions only, no fold-key
"""
import argparse
import os
import sys
from enum import Enum

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dict_generation.dawg import DawgReader
from dict_generation.eval.dawg_suggester import DawgSuggester
from dict_generation.eval.hunspell_runner import (
    analyze_via_hunspell, suggest_via_hunspell, HUNSPELL_CLI_PATH,
)
from dict_generation.eval.perturbations import _greekify_python
from dict_generation.eval.variants import build_variant
from dict_generation.phonetic_fold import load_default_folder


class _Casing(Enum):
    LOWERCASE = 1
    FIRST_LETTER_CAP = 2
    ALL_CAPS = 3


def preprocess_input(text: str) -> tuple:
    """Mirror the iOS providers' input pipeline.

    Returns (greekified, lookup_form, casing, leading_punct):
      - greekified: text after CypriotKeyboardHelper.greekify (Latin → Greek)
      - lookup_form: what to actually feed the engines (lowercased per casing)
      - casing: how to recapitalize results for display
      - leading_punct: any non-letter prefix stripped before processing
    """
    # Strip leading punct (mirrors isPunctFirst handling in iOS Hunspell path).
    leading_punct = ""
    body = text
    while body and not body[0].isalpha():
        leading_punct += body[0]
        body = body[1:]

    if not body:
        return ("", "", _Casing.LOWERCASE, leading_punct)

    greek = _greekify_python(body)

    # Three-state casing detection (mirrors iOS DAWG provider).
    if greek == greek.upper() and greek != greek.lower():
        # All-caps with at least one cased letter.
        return (greek, greek.lower(), _Casing.ALL_CAPS, leading_punct)
    if greek[:1].isupper():
        return (greek, greek[:1].lower() + greek[1:], _Casing.FIRST_LETTER_CAP, leading_punct)
    return (greek, greek, _Casing.LOWERCASE, leading_punct)


def postprocess_suggestion(canonical: str, casing: _Casing, leading_punct: str) -> str:
    """Mirror the iOS providers' output recapitalization."""
    if not canonical:
        return leading_punct
    if casing == _Casing.ALL_CAPS:
        out = canonical.upper()
    elif casing == _Casing.FIRST_LETTER_CAP:
        out = canonical[:1].upper() + canonical[1:]
    else:
        out = canonical
    return leading_punct + out


# Variants we expose. Order is the print order.
VARIANTS_TO_LOAD = [
    ("baseline",  "DAWG baseline"),
    ("v3_freq1",  "DAWG v3_freq1"),
]


def load_engines():
    print("[repl] loading engines (variants are cached)", file=sys.stderr)
    folder = load_default_folder()
    readers = {}
    for name, label in VARIANTS_TO_LOAD:
        path, _stats = build_variant(name)
        with open(path, "rb") as f:
            readers[name] = (label, DawgReader(f.read()))
    # Damerau-Levenshtein suggester for the baseline (the variant we ship).
    baseline_reader = readers["baseline"][1]
    baseline_suggester = DawgSuggester(baseline_reader)
    have_hunspell = os.path.exists(HUNSPELL_CLI_PATH)
    if not have_hunspell:
        print(
            f"[repl] hunspell-cli missing at {HUNSPELL_CLI_PATH}; "
            f"run `cd dict_generation && make hunspell-cli`",
            file=sys.stderr,
        )
    return folder, readers, baseline_suggester, have_hunspell


def lookup_one(word: str, folder, readers, baseline_suggester, have_hunspell, quiet: bool) -> str:
    lines = []
    greekified, lookup_form, casing, leading_punct = preprocess_input(word)
    fold_key = folder.fold(lookup_form)

    if not quiet:
        if greekified and greekified != word:
            lines.append(f"  greekified:      {leading_punct}{greekified}")
        if lookup_form != greekified:
            lines.append(f"  lookup form:     {lookup_form}  (case-folded for engine lookup)")
        lines.append(f"  fold key:        {fold_key}")

    if have_hunspell:
        result = analyze_via_hunspell(lookup_form) if lookup_form else analyze_via_hunspell(word)
        if result.is_correct:
            display = postprocess_suggestion(lookup_form, casing, leading_punct)
            if result.root and result.root != lookup_form:
                lines.append(f"  Hunspell:        {display} (correct, root={result.root})")
            else:
                lines.append(f"  Hunspell:        {display} (correct)")
        elif result.suggestions:
            displayed = [postprocess_suggestion(s, casing, leading_punct) for s in result.suggestions]
            lines.append(f"  Hunspell:        {', '.join(displayed)}")
        else:
            lines.append(f"  Hunspell:        (misspelled, no suggestions)")

    # DAWG baseline (exact match) + edit-distance walks at budget=1 / budget=2.
    baseline_reader = readers["baseline"][1]
    pidx = baseline_reader.payload_for(fold_key)
    if pidx is None:
        lines.append(f"  DAWG baseline    (no payload — fold key not present)")
    else:
        forms = baseline_reader.canonical_forms(pidx)
        rendered = ", ".join(
            f"{postprocess_suggestion(c, casing, leading_punct)} ({f})"
            for c, f in forms
        )
        lines.append(f"  DAWG baseline    {rendered}")

    for budget in (1, 2):
        suggestions = baseline_suggester.suggest(fold_key, budget=budget, limit=5)
        if not suggestions:
            lines.append(f"  DAWG <=edit-{budget}     (none within edit-{budget})")
        else:
            rendered = ", ".join(
                f"{postprocess_suggestion(s.canonical, casing, leading_punct)} ({s.frequency}, d={s.edit_distance})"
                for s in suggestions
            )
            lines.append(f"  DAWG <=edit-{budget}     {rendered}")

    # Other variants (currently just v3_freq1) — exact-match only.
    for name, label in VARIANTS_TO_LOAD:
        if name == "baseline":
            continue
        _, reader = readers[name]
        pidx = reader.payload_for(fold_key)
        if pidx is None:
            lines.append(f"  {label:16s} (no payload — fold key not present)")
        else:
            forms = reader.canonical_forms(pidx)
            rendered = ", ".join(
                f"{postprocess_suggestion(c, casing, leading_punct)} ({f})"
                for c, f in forms
            )
            lines.append(f"  {label:16s} {rendered}")

    return "\n".join(lines)


def lookup_input(text: str, folder, readers, baseline_suggester, have_hunspell, quiet: bool) -> str:
    """Process `text`. Single-word inputs go straight through `lookup_one`.
    Multi-word inputs split on whitespace and process each word with a header."""
    words = text.split()
    if not words:
        return ""
    if len(words) == 1:
        return lookup_one(words[0], folder, readers, baseline_suggester, have_hunspell, quiet)
    blocks = []
    for i, word in enumerate(words, start=1):
        if i > 1:
            blocks.append("")  # blank separator between word blocks
        blocks.append(f"  --- word {i}/{len(words)}: {word!r} ---")
        blocks.append(lookup_one(word, folder, readers, baseline_suggester, have_hunspell, quiet))
    return "\n".join(blocks)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", action="store_true",
                        help="no prompt or banner; suitable for piping")
    parser.add_argument("--quiet", action="store_true",
                        help="suppress greekified/fold-key lines")
    args = parser.parse_args()

    folder, readers, baseline_suggester, have_hunspell = load_engines()

    if not args.batch:
        print("[repl] type a word, ^D to exit", file=sys.stderr)

    while True:
        try:
            if args.batch:
                line = sys.stdin.readline()
                if not line:
                    break
                word = line.rstrip("\n")
            else:
                sys.stdout.write("> ")
                sys.stdout.flush()
                line = sys.stdin.readline()
                if not line:
                    print()  # newline after the ^D
                    break
                word = line.rstrip("\n")
        except KeyboardInterrupt:
            print()
            break

        if not word.strip():
            continue
        if args.batch:
            print(f"> {word}")
        print(lookup_input(word, folder, readers, baseline_suggester, have_hunspell,
                           quiet=args.quiet))
        print()


if __name__ == "__main__":
    main()
