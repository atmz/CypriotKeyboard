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
from dict_generation.eval.hunspell_runner import (
    suggest_via_hunspell, HUNSPELL_CLI_PATH,
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
    have_hunspell = os.path.exists(HUNSPELL_CLI_PATH)
    if not have_hunspell:
        print(
            f"[repl] hunspell-cli missing at {HUNSPELL_CLI_PATH}; "
            f"run `cd dict_generation && make hunspell-cli`",
            file=sys.stderr,
        )
    return folder, readers, have_hunspell


def lookup_one(word: str, folder, readers, have_hunspell, quiet: bool) -> str:
    lines = []
    greekified = _greekify_python(word)
    fold_key = folder.fold(greekified)

    if not quiet:
        if greekified != word:
            lines.append(f"  greekified:      {greekified}")
        lines.append(f"  fold key:        {fold_key}")

    if have_hunspell:
        h = suggest_via_hunspell(word)
        if h:
            lines.append(f"  Hunspell:        {', '.join(h)}")
        else:
            lines.append(f"  Hunspell:        (correct)")

    for name, label in VARIANTS_TO_LOAD:
        _, reader = readers[name]
        pidx = reader.payload_for(fold_key)
        if pidx is None:
            lines.append(f"  {label:16s} (no payload — fold key not present)")
        else:
            forms = reader.canonical_forms(pidx)
            rendered = ", ".join(f"{c} ({f})" for c, f in forms)
            lines.append(f"  {label:16s} {rendered}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", action="store_true",
                        help="no prompt or banner; suitable for piping")
    parser.add_argument("--quiet", action="store_true",
                        help="suppress greekified/fold-key lines")
    args = parser.parse_args()

    folder, readers, have_hunspell = load_engines()

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
        print(lookup_one(word, folder, readers, have_hunspell, quiet=args.quiet))
        print()


if __name__ == "__main__":
    main()
