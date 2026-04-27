"""Perturbation generators for the eval harness.

Four classes:
- identity: word as-is
- unaccented: combining diacritics stripped
- vowel_swap: each i-class vowel position swapped with another i-class member
- greekified_latin: word → inverse_greekify → _greekify_python (simulates the
  Swift runtime's Greeklish → Greek transliteration before phonetic fold)

Each yields (perturbed_word, perturbation_class_name) tuples.
"""
import unicodedata
from typing import Iterator, Tuple

from dict_generation.eval.inverse_greekify import inverse_greekify


# ---- identity -------------------------------------------------------------

def identity(word: str) -> Iterator[Tuple[str, str]]:
    yield (word, "identity")


# ---- unaccented -----------------------------------------------------------

def unaccented(word: str) -> Iterator[Tuple[str, str]]:
    """Strip combining diacritics; emit the bare-bones form."""
    nfd = unicodedata.normalize("NFD", word)
    stripped = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    nfc = unicodedata.normalize("NFC", stripped)
    yield (nfc, "unaccented")


# ---- vowel_swap -----------------------------------------------------------

_I_CLASS = ["η", "ι", "υ"]  # single-char i-class vowels we swap among


def vowel_swap(word: str) -> Iterator[Tuple[str, str]]:
    """For each i-class vowel position, yield a variant with that position
    replaced by each other i-class member."""
    for i, ch in enumerate(word):
        if ch in _I_CLASS:
            for replacement in _I_CLASS:
                if replacement != ch:
                    yield (word[:i] + replacement + word[i + 1:], "vowel_swap")


# ---- greekified_latin -----------------------------------------------------

# Port of CypriotKeyboardHelper.greekify() in
# Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift. Mirrors that switch
# table EXACTLY — including its quirks (e.g. NGK → γκ outputs lowercase Greek).
#
# Phase 2 will add a cross-language test that this port and the Swift original
# agree on a corpus of inputs. Until then, any discrepancy is a bug here.
_GREEKIFY_RULES = [
    # Trigraphs first
    ("ngk", "γκ"), ("NGK", "γκ"),  # both produce lowercase γκ per Swift
    ("ths", "τησ"),
    ("Ths", "Τησ"), ("THS", "Τησ"),
    # 2-char digraphs
    ("sh", "σ̆"),
    ("Sh", "Σ̆"), ("SH", "Σ̆"),
    ("ch", "τσ̆"),
    ("Ch", "Τσ̆"), ("CH", "Τσ̆"),
    ("ps", "ψ"),
    ("Ps", "Ψ"), ("PS", "Ψ"),
    ("ks", "ξ"),
    ("Ks", "Ξ"), ("KS", "Ξ"),
    ("Th", "Θ"), ("TH", "Θ"),
    ("th", "θ"),
    ("yi", "γι"),
    ("Yi", "Γι"), ("YI", "Γι"),
    ("ng", "γκ"), ("NG", "γκ"),  # both lowercase γκ per Swift
    # Single-char fallback (Swift: greekifySingle)
    ("a", "α"), ("A", "Α"),
    ("i", "ι"), ("I", "Ι"),
    ("e", "ε"), ("E", "Ε"),
    ("o", "ο"), ("O", "Ο"),
    ("u", "υ"), ("U", "Υ"),
    ("y", "υ"), ("Y", "Υ"),
    ("w", "ω"), ("W", "Ω"),
    ("r", "ρ"), ("R", "Ρ"),
    ("t", "τ"), ("T", "Τ"),
    ("p", "π"), ("P", "Π"),
    ("s", "σ"), ("S", "Σ"),
    ("d", "δ"), ("D", "Δ"),
    ("f", "φ"), ("F", "Φ"),
    ("g", "γ"), ("G", "Γ"),
    ("h", "η"), ("H", "Η"),
    ("k", "κ"), ("K", "Κ"),
    ("l", "λ"), ("L", "Λ"),
    ("z", "ζ"), ("Z", "Ζ"),
    ("x", "χ"), ("X", "Χ"),
    ("c", "κ"), ("C", "Κ"),
    ("v", "β"), ("V", "Β"),
    ("b", "μπ"), ("B", "Μπ"),
    ("n", "ν"), ("N", "Ν"),
    ("m", "μ"), ("M", "Μ"),
    ("j", "τζ̆"), ("J", "Τζ̆"),
    ("3", "ξ"),
]
_GREEKIFY_RULES.sort(key=lambda r: -len(r[0]))


def _greekify_python(text: str) -> str:
    """Port of CypriotKeyboardHelper.greekify(). Used only for eval.
    Phase 2 will add a Swift-side test that the two implementations agree."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        matched = False
        for src, dst in _GREEKIFY_RULES:
            if i + len(src) <= n and text[i:i + len(src)] == src:
                out.append(dst)
                i += len(src)
                matched = True
                break
        if not matched:
            out.append(text[i])
            i += 1
    return "".join(out)


def greekified_latin(word: str) -> Iterator[Tuple[str, str]]:
    """word → inverse_greekify → _greekify_python. Simulates the user typing
    in Latin and the Swift greekify() converting it to Greek."""
    latin = inverse_greekify(word)
    re_greek = _greekify_python(latin)
    yield (re_greek, "greekified_latin")
