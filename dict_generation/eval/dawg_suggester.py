"""Python port of the Swift DamerauLevenshteinSuggester.

Edit-distance-N candidate enumeration over a DAWG. Used by the eval REPL
and any future Python-side eval that wants to see what edit-1 / edit-2
walking adds to plain exact-fold-match.

Algorithm: enumerate all edit-distance-≤N variants of the input fold-key
(deletions, substitutions, insertions, transpositions), look each up in
the DAWG, collect canonicals, dedupe by canonical, rank by
(edit_distance asc, freq desc).

Phase 2.x may switch to a single-pass DAWG-walking automaton for
efficiency. Candidate enumeration is fast enough for typical inputs
and far easier to verify correct.
"""
from typing import List, NamedTuple, Set

from dict_generation.dawg import DawgReader


class DawgSuggestion(NamedTuple):
    canonical: str
    frequency: int
    edit_distance: int


class DawgSuggester:
    def __init__(self, reader: DawgReader):
        self.reader = reader
        self.alphabet = self._collect_alphabet()

    def suggest(self, key: str, budget: int = 1, limit: int = 5) -> List[DawgSuggestion]:
        """Return up to `limit` ranked candidates within edit distance <= budget."""
        results = []  # (canonical, freq, distance)
        seen = set()

        # Distance 0
        pidx = self.reader.payload_for(key)
        if pidx is not None:
            for canonical, freq in self.reader.canonical_forms(pidx):
                if canonical not in seen:
                    seen.add(canonical)
                    results.append((canonical, freq, 0))

        if budget >= 1:
            for variant in self._edit1_variants(key):
                pidx = self.reader.payload_for(variant)
                if pidx is None:
                    continue
                for canonical, freq in self.reader.canonical_forms(pidx):
                    if canonical not in seen:
                        seen.add(canonical)
                        results.append((canonical, freq, 1))

        if budget >= 2:
            edit1_set = set(self._edit1_variants(key))
            edit2_set: Set[str] = set()
            for v1 in edit1_set:
                for v2 in self._edit1_variants(v1):
                    if v2 != key and v2 not in edit1_set:
                        edit2_set.add(v2)
            for variant in edit2_set:
                pidx = self.reader.payload_for(variant)
                if pidx is None:
                    continue
                for canonical, freq in self.reader.canonical_forms(pidx):
                    if canonical not in seen:
                        seen.add(canonical)
                        results.append((canonical, freq, 2))

        # Sort by (distance asc, freq desc)
        results.sort(key=lambda r: (r[2], -r[1]))
        return [DawgSuggestion(canonical=c, frequency=f, edit_distance=d)
                for c, f, d in results[:limit]]

    def suggest_multi(self, keys: List[str], budget: int = 1, limit: int = 5,
                      input_casing_hint: str = "lowercase") -> List[DawgSuggestion]:
        """Look up multiple fold-key variants, dedupe canonicals by min edit
        distance, rank by (distance asc, casing-match desc, freq desc).

        Used when the input has multiple plausible fold interpretations
        (e.g., digraph that may or may not be intended as a digraph by the user).

        `input_casing_hint` is the casing of the user's input ("lowercase",
        "first_letter_cap", or "all_caps"). Mirrors the Swift
        DamerauLevenshteinSuggester.InputCasingHint enum: it's a TIEBREAKER
        only — edit distance still dominates. Cap-first / all-caps inputs
        prefer canonicals whose first letter is uppercase; lowercase inputs
        prefer canonicals whose first letter is lowercase.
        """
        by_canonical = {}  # canonical -> DawgSuggestion (with min distance)
        for key in keys:
            # Over-fetch since we'll dedupe across variants.
            for s in self.suggest(key, budget=budget, limit=limit * 4):
                existing = by_canonical.get(s.canonical)
                if existing is None or s.edit_distance < existing.edit_distance:
                    by_canonical[s.canonical] = s

        def casing_boost(canonical: str) -> int:
            if not canonical:
                return 0
            first = canonical[0]
            if input_casing_hint == "lowercase":
                return 1 if first.islower() else 0
            # "first_letter_cap" and "all_caps" both prefer cap-first canonicals.
            return 1 if first.isupper() else 0

        merged = sorted(
            by_canonical.values(),
            key=lambda s: (s.edit_distance, -casing_boost(s.canonical), -s.frequency),
        )
        return merged[:limit]

    def _edit1_variants(self, key: str) -> List[str]:
        chars = list(key)
        n = len(chars)
        out: List[str] = []
        # Deletions
        for i in range(n):
            out.append("".join(chars[:i] + chars[i + 1:]))
        # Substitutions
        for i in range(n):
            existing = ord(chars[i])
            for cp in self.alphabet:
                if cp == existing:
                    continue
                out.append("".join(chars[:i] + [chr(cp)] + chars[i + 1:]))
        # Insertions (n+1 positions)
        for i in range(n + 1):
            for cp in self.alphabet:
                out.append("".join(chars[:i] + [chr(cp)] + chars[i:]))
        # Adjacent transpositions
        for i in range(n - 1):
            if chars[i] == chars[i + 1]:
                continue
            out.append("".join(chars[:i] + [chars[i + 1], chars[i]] + chars[i + 2:]))
        return out

    def _collect_alphabet(self) -> List[int]:
        seen: Set[int] = set()
        visited: Set[int] = set()
        stack = [self.reader.root_idx()]
        while stack:
            node_idx = stack.pop()
            if node_idx in visited:
                continue
            visited.add(node_idx)
            for cp, target in self.reader.edges_at(node_idx):
                seen.add(cp)
                stack.append(target)
        return sorted(seen)
