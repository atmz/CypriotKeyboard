import os
import unittest
from dict_generation.eval.variants import build_variant, VARIANT_NAMES


class VariantsTests(unittest.TestCase):

    def test_known_variant_names(self):
        self.assertEqual(
            set(VARIANT_NAMES),
            {"baseline", "v1_top1", "v2_stems", "v3_freq1", "v3_freq2", "v4_top1_freq1"},
        )

    def test_build_baseline_produces_file(self):
        path, stats = build_variant("baseline", cache_dir="/tmp/eval_dawg")
        self.assertTrue(os.path.exists(path))
        self.assertGreater(stats["bytes"], 0)
        self.assertGreater(stats["dawg_nodes"], 0)

    def test_build_v3_freq2_produces_smaller_file_than_baseline(self):
        baseline_path, baseline_stats = build_variant("baseline", cache_dir="/tmp/eval_dawg")
        v3_path, v3_stats = build_variant("v3_freq2", cache_dir="/tmp/eval_dawg")
        self.assertLess(v3_stats["bytes"], baseline_stats["bytes"])

    def test_unknown_variant_raises(self):
        with self.assertRaises(KeyError):
            build_variant("nonsense", cache_dir="/tmp/eval_dawg")


if __name__ == "__main__":
    unittest.main()
