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
from typing import Dict

# Allow running as a script regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import Dawg
from dict_generation.phonetic_fold import load_default_folder


DEFAULT_FREQ = 1


def build(dic_path: str, aff_path: str, freq_path: str, out_path: str) -> None:
    print(f"[build_dawg] parsing {aff_path}")
    aff = parse_aff(open(aff_path, encoding="utf-8").read())

    print(f"[build_dawg] loading frequency table from {freq_path}")
    try:
        with open(freq_path, encoding="utf-8") as f:
            corpus_freq: Dict[str, int] = json.load(f)
    except FileNotFoundError:
        print(f"[build_dawg] WARNING: {freq_path} not found; all freqs default to {DEFAULT_FREQ}")
        corpus_freq = {}

    print(f"[build_dawg] expanding {dic_path} → surface forms")
    folder = load_default_folder()
    grouped: Dict[str, Dict[str, int]] = defaultdict(dict)
    n_forms = 0
    for surface in expand_dic_file(dic_path, aff):
        n_forms += 1
        key = folder.fold(surface)
        freq = corpus_freq.get(surface.lower(), DEFAULT_FREQ)
        # If multiple paths produce the same canonical+key, take the max freq.
        prev = grouped[key].get(surface, 0)
        if freq > prev:
            grouped[key][surface] = freq
        if n_forms % 100000 == 0:
            print(f"[build_dawg]   {n_forms} surface forms processed")

    print(f"[build_dawg] {n_forms} surface forms → {len(grouped)} unique fold keys")

    # Build a string table (deduped canonical forms) and a payload table (per fold key).
    string_index: Dict[str, int] = {}
    strings = []
    payloads = []
    sorted_keys = sorted(grouped.keys())
    payload_for_key: Dict[str, int] = {}
    for key in sorted_keys:
        canonical_forms = grouped[key]
        # Sort canonical forms within a key by freq descending then alphabetical
        ranked = sorted(canonical_forms.items(), key=lambda kv: (-kv[1], kv[0]))
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

    print(f"[build_dawg] inserting into DAWG (this may take a minute)")
    dawg = Dawg()
    for key in sorted_keys:
        dawg.insert_sorted(key, payload=payload_for_key[key])
    dawg.finalize()
    print(f"[build_dawg] DAWG nodes: {dawg.node_count()}")

    print(f"[build_dawg] serializing → {out_path}")
    with open(out_path, "wb") as out:
        dawg.serialize(out, payloads=payloads, strings=strings)
    size = os.path.getsize(out_path)
    print(f"[build_dawg] wrote {size:,} bytes ({size/1024/1024:.2f} MB)")


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
