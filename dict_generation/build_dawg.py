#!/usr/bin/env python3
"""Build dict/el_CY.dawg from dict/el_CY.{dic,aff} + corpus_freq.json.

Run from the repo root:
    python3 dict_generation/build_dawg.py
"""
import argparse
import json
import os
import sys
from collections import defaultdict
from typing import Callable, Dict, Iterable, Optional

# Allow running as a script regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import Dawg
from dict_generation.phonetic_fold import load_default_folder


DEFAULT_FREQ = 1


def yield_stems_only(dic_path: str, encoding: str = "UTF-8") -> Iterable[str]:
    """Yield every stem in the .dic, ignoring its flags. Used by V2."""
    with open(dic_path, encoding=encoding) as f:
        seen_count = False
        for raw in f:
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            if not seen_count and s.isdigit():
                seen_count = True
                continue
            seen_count = True
            stem = s.split("/", 1)[0].strip()
            if stem:
                yield stem


def build_dawg_to(
    out_path: str,
    *,
    dic_path: str = "dict/el_CY.dic",
    aff_path: str = "dict/el_CY.aff",
    freq_path: str = "dict_generation/corpus_freq.json",
    surface_form_source: Optional[Callable[..., Iterable[str]]] = None,
    freq_threshold: int = 0,
    top_canonical_only: bool = False,
    quiet: bool = False,
) -> Dict[str, int]:
    """Build a DAWG and write to out_path. Returns a small stats dict.

    Parameters control the variants:
    - surface_form_source: callable returning an iterable of canonical
      strings to insert. Defaults to expanding all surface forms via
      affix application. V2 passes a stems-only yielder.
    - freq_threshold: drop forms whose corpus_freq < this. 0 keeps all.
      1 keeps only forms seen in the corpus. Higher values filter more.
    - top_canonical_only: if True, retain only the highest-frequency
      canonical per fold key (V1, V4 use this).
    """
    def log(msg):
        if not quiet:
            print(msg)

    aff = parse_aff(open(aff_path, encoding="utf-8").read())

    try:
        with open(freq_path, encoding="utf-8") as f:
            corpus_freq: Dict[str, int] = json.load(f)
    except FileNotFoundError:
        log(f"[build_dawg] WARNING: {freq_path} not found; freqs default to {DEFAULT_FREQ}")
        corpus_freq = {}

    if surface_form_source is None:
        def _default_source():
            return expand_dic_file(dic_path, aff)
        surface_form_source = _default_source

    folder = load_default_folder()
    grouped: Dict[str, Dict[str, int]] = defaultdict(dict)
    n_in = 0
    n_kept = 0
    # When a freq_threshold is active, words absent from the corpus should be
    # treated as freq=0 so they are correctly filtered out.  When no threshold
    # is applied (freq_threshold==0), use DEFAULT_FREQ so unattested forms
    # still participate in ranking (preserving baseline behaviour).
    default_for_missing = 0 if freq_threshold > 0 else DEFAULT_FREQ
    for surface in surface_form_source():
        n_in += 1
        freq = corpus_freq.get(surface.lower(), default_for_missing)
        if freq < freq_threshold:
            continue
        n_kept += 1
        key = folder.fold(surface.lower())
        # Use DEFAULT_FREQ as the stored frequency for unattested forms so
        # they still appear in ranked output when threshold==0.
        stored_freq = freq if freq > 0 else DEFAULT_FREQ
        prev = grouped[key].get(surface, 0)
        if stored_freq > prev:
            grouped[key][surface] = stored_freq

    log(f"[build_dawg] {n_in} input forms, {n_kept} kept after threshold, {len(grouped)} unique fold keys")

    string_index: Dict[str, int] = {}
    strings = []
    payloads = []
    sorted_keys = sorted(grouped.keys())
    payload_for_key: Dict[str, int] = {}
    for key in sorted_keys:
        canonical_forms = grouped[key]
        ranked = sorted(canonical_forms.items(), key=lambda kv: (-kv[1], kv[0]))
        if top_canonical_only:
            ranked = ranked[:1]
        entry = []
        for form, freq in ranked:
            idx = string_index.get(form)
            if idx is None:
                idx = len(strings)
                string_index[form] = idx
                strings.append(form)
            entry.append((idx, freq))
        payload_for_key[key] = len(payloads)
        payloads.append(entry)

    dawg = Dawg()
    for key in sorted_keys:
        dawg.insert_sorted(key, payload=payload_for_key[key])
    dawg.finalize()

    with open(out_path, "wb") as out:
        dawg.serialize(out, payloads=payloads, strings=strings)
    size = os.path.getsize(out_path)
    log(f"[build_dawg] {out_path}: {size:,} bytes ({size/1024/1024:.2f} MB), {dawg.node_count()} nodes")

    return {
        "input_forms": n_in,
        "kept_forms": n_kept,
        "fold_keys": len(grouped),
        "dawg_nodes": dawg.node_count(),
        "bytes": size,
    }


def build(dic_path: str, aff_path: str, freq_path: str, out_path: str) -> None:
    """Default-variant build (used by the CLI). Equivalent to baseline."""
    build_dawg_to(
        out_path,
        dic_path=dic_path,
        aff_path=aff_path,
        freq_path=freq_path,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dic", default="dict/el_CY.dic")
    parser.add_argument("--aff", default="dict/el_CY.aff")
    parser.add_argument("--freq", default="dict_generation/corpus_freq.json")
    parser.add_argument("--out", default="dict/el_CY.dawg")
    args = parser.parse_args()
    build(args.dic, args.aff, args.freq, args.out)


if __name__ == "__main__":
    main()
