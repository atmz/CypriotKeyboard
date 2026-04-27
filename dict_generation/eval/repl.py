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

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dict_generation.dawg import DawgReader
from dict_generation.eval.dawg_suggester import DawgSuggester
from dict_generation.eval.hunspell_runner import (
    analyze_via_hunspell, suggest_via_hunspell, HUNSPELL_CLI_PATH,
)
from dict_generation.eval.perturbations import _greekify_python
from dict_generation.eval.variants import build_variant
from dict_generation.phonetic_fold import load_default_folder


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
    greekified = _greekify_python(word)
    fold_key = folder.fold(greekified)

    if not quiet:
        if greekified != word:
            lines.append(f"  greekified:      {greekified}")
        lines.append(f"  fold key:        {fold_key}")

    if have_hunspell:
        result = analyze_via_hunspell(word)
        if result.is_correct:
            if result.root and result.root != word:
                lines.append(f"  Hunspell:        {word} (correct, root={result.root})")
            else:
                lines.append(f"  Hunspell:        {word} (correct)")
        elif result.suggestions:
            lines.append(f"  Hunspell:        {', '.join(result.suggestions)}")
        else:
            lines.append(f"  Hunspell:        (misspelled, no suggestions)")

    # DAWG baseline (exact match) + edit-distance walks at budget=1 / budget=2.
    baseline_reader = readers["baseline"][1]
    pidx = baseline_reader.payload_for(fold_key)
    if pidx is None:
        lines.append(f"  DAWG baseline    (no payload — fold key not present)")
    else:
        forms = baseline_reader.canonical_forms(pidx)
        rendered = ", ".join(f"{c} ({f})" for c, f in forms)
        lines.append(f"  DAWG baseline    {rendered}")

    for budget in (1, 2):
        suggestions = baseline_suggester.suggest(fold_key, budget=budget, limit=5)
        if not suggestions:
            lines.append(f"  DAWG <=edit-{budget}    (none within edit-{budget})")
        else:
            rendered = ", ".join(
                f"{s.canonical} ({s.frequency}, d={s.edit_distance})"
                for s in suggestions
            )
            lines.append(f"  DAWG <=edit-{budget}    {rendered}")

    # Other variants (currently just v3_freq1) — exact-match only.
    for name, label in VARIANTS_TO_LOAD:
        if name == "baseline":
            continue  # already handled above
        _, reader = readers[name]
        pidx = reader.payload_for(fold_key)
        if pidx is None:
            lines.append(f"  {label:16s} (no payload — fold key not present)")
        else:
            forms = reader.canonical_forms(pidx)
            rendered = ", ".join(f"{c} ({f})" for c, f in forms)
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
