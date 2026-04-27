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
