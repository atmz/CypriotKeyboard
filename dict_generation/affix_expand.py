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
