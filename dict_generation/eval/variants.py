"""Build any of the 6 candidate DAWG variants on demand.

Variants:
- baseline    : full pipeline, all surface forms, all canonicals per key
- v1_top1     : full pipeline, top-1 canonical per key
- v2_stems    : stems only (skip affix expansion); each stem is its own canonical
- v3_freq1    : drop forms with corpus_freq < 1 (i.e. corpus-attested only)
- v3_freq2    : drop forms with corpus_freq < 2 (drop singletons)
- v4_top1_freq1: combine v1 + v3@1

Each variant is cached in <cache_dir>/<variant>.bin so repeated runs are fast.
"""
import os
from typing import Tuple, Dict

from dict_generation.build_dawg import build_dawg_to, yield_stems_only


VARIANT_NAMES = (
    "baseline",
    "v1_top1",
    "v2_stems",
    "v3_freq1",
    "v3_freq2",
    "v4_top1_freq1",
)


_VARIANT_CONFIGS: Dict[str, dict] = {
    "baseline":       dict(freq_threshold=0,          top_canonical_only=False),
    "v1_top1":        dict(freq_threshold=0,          top_canonical_only=True),
    "v2_stems":       dict(freq_threshold=0,          top_canonical_only=False, stems_only=True),
    "v3_freq1":       dict(freq_threshold=1,          top_canonical_only=False),
    "v3_freq2":       dict(freq_threshold=2,          top_canonical_only=False),
    "v4_top1_freq1":  dict(freq_threshold=1,          top_canonical_only=True),
}


def build_variant(name: str, cache_dir: str = "/tmp/eval_dawg",
                  dic_path: str = "dict/el_CY.dic",
                  aff_path: str = "dict/el_CY.aff",
                  freq_path: str = "dict_generation/corpus_freq.json",
                  force: bool = False) -> Tuple[str, dict]:
    """Build (or reuse cached) variant. Returns (path_to_dawg_file, stats_dict)."""
    if name not in _VARIANT_CONFIGS:
        raise KeyError(f"unknown variant {name!r}; valid: {VARIANT_NAMES}")
    os.makedirs(cache_dir, exist_ok=True)
    out_path = os.path.join(cache_dir, f"{name}.bin")
    stats_path = out_path + ".stats.json"

    cfg = dict(_VARIANT_CONFIGS[name])  # copy
    stems_only = cfg.pop("stems_only", False)

    if not force and os.path.exists(out_path) and os.path.exists(stats_path):
        import json
        with open(stats_path, encoding="utf-8") as f:
            return out_path, json.load(f)

    surface_form_source = None
    if stems_only:
        def surface_form_source():
            return yield_stems_only(dic_path)

    stats = build_dawg_to(
        out_path,
        dic_path=dic_path,
        aff_path=aff_path,
        freq_path=freq_path,
        surface_form_source=surface_form_source,
        quiet=True,
        **cfg,
    )

    import json
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)
    return out_path, stats
