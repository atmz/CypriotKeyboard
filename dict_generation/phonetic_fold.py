"""Phonetic-equivalence-class folding for Cypriot Greek.

Loads rules from phonetic_fold.json. Folds an input string by greedily
matching the longest source pattern at each position, emitting the
canonical key character, and advancing past the matched length.

The Swift runtime in Phase 2 implements the same algorithm against
the same JSON file.
"""
import json
import os
from typing import Iterator, List, Tuple


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

    def fold_variants(self, text: str, max_variants: int = 16) -> List[str]:
        """Return all fold variants by branching at digraph-matching positions.

        At each position, if a multi-char rule matches, we explore TWO branches:
          (a) take the multi-char rule (collapses to one fold char)
          (b) take the single-char rule for text[i] and recurse from i+1
              (so the "digraph" gets folded as two separate single-char fold steps)

        The first returned variant equals the greedy longest-match fold (i.e.,
        the same string self.fold(text) would return). Subsequent variants
        explore alternatives.

        Single-char-only positions don't branch — only digraph rules introduce
        ambiguity worth exploring.

        Capped at max_variants to prevent pathological blowup. Typical Greek
        words have 0-2 digraphs, so 1-4 variants is normal.
        """
        n = len(text)

        def helper(i: int) -> Iterator[str]:
            if i >= n:
                yield ""
                return
            # Find longest-match multi-char rule at position i (if any).
            digraph = None
            for src, dst in self._rules:
                if len(src) >= 2 and i + len(src) <= n:
                    if all(text[i + k] == src[k] for k in range(len(src))):
                        digraph = (src, dst)
                        break
            # Find single-char rule for text[i] (if any).
            single = None
            for src, dst in self._rules:
                if len(src) == 1 and text[i] == src[0]:
                    single = (src, dst)
                    break

            if digraph is not None:
                src, dst = digraph
                for tail in helper(i + len(src)):
                    yield dst + tail
            if single is not None:
                src, dst = single
                for tail in helper(i + 1):
                    yield dst + tail
            elif digraph is None:
                # No rule fires — pass char through.
                for tail in helper(i + 1):
                    yield text[i] + tail

        seen = set()
        out = []
        for variant in helper(0):
            if variant not in seen:
                seen.add(variant)
                out.append(variant)
                if len(out) >= max_variants:
                    break
        return out


def load_default_folder() -> PhoneticFolder:
    path = os.path.join(os.path.dirname(__file__), "phonetic_fold.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return PhoneticFolder([(r["from"], r["to"]) for r in data["rules"]])
