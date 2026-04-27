"""Build the synthetic-corpus ground-truth list of canonical Greek words.

Combines:
- Top-N entries from corpus_freq.json (real Cypriot dialect frequencies)
- The hand-curated commonWords set (from common_words.json)

Filters out single-character words; dedupes; returns alphabetically sorted
for determinism.
"""
import json
from typing import List


def build_ground_truth(freq_path: str, common_path: str, top_n: int = 500) -> List[str]:
    """Return a deterministic list of canonical Greek words to evaluate."""
    with open(freq_path, encoding="utf-8") as f:
        freq = json.load(f)
    with open(common_path, encoding="utf-8") as f:
        common = json.load(f)

    # Top-N by count descending (ties broken alphabetically for determinism).
    top = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))[:top_n]
    top_words = {w for w, _ in top}

    combined = top_words | set(common)
    # Drop single-letter or empty entries — they're not useful eval targets.
    combined = {w for w in combined if len(w) >= 2}
    return sorted(combined)
