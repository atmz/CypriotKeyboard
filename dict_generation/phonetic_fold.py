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
