import json
import os
import tempfile
import unittest
from dict_generation.eval.ground_truth import build_ground_truth


class GroundTruthTests(unittest.TestCase):

    def test_top_n_sorted_by_count_descending(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100, "που": 50, "rare": 1}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=2)
            self.assertEqual(set(words), {"και", "που"})

    def test_includes_common_words_even_if_outside_top_n(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100, "που": 50}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump(["ίντα", "και"], f)  # ίντα isn't in the top-N
            words = build_ground_truth(freq_path, common_path, top_n=1)
            self.assertEqual(set(words), {"και", "ίντα"})

    def test_dedupes(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"και": 100}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump(["και"], f)
            words = build_ground_truth(freq_path, common_path, top_n=10)
            self.assertEqual(words.count("και"), 1)

    def test_output_is_sorted_for_determinism(self):
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"γγ": 1, "αα": 2, "ββ": 3}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=3)
            self.assertEqual(words, ["αα", "ββ", "γγ"])  # sorted alphabetically

    def test_filters_short_or_garbage(self):
        # Single-letter words don't make useful eval targets.
        with tempfile.TemporaryDirectory() as d:
            freq_path = os.path.join(d, "freq.json")
            common_path = os.path.join(d, "common.json")
            with open(freq_path, "w", encoding="utf-8") as f:
                json.dump({"α": 1000, "και": 100, "β": 500}, f)
            with open(common_path, "w", encoding="utf-8") as f:
                json.dump([], f)
            words = build_ground_truth(freq_path, common_path, top_n=10)
            self.assertEqual(set(words), {"και"})


if __name__ == "__main__":
    unittest.main()
