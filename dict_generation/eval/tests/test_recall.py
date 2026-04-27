import os
import unittest

from dict_generation.eval.recall import (
    found_in_dawg,
    found_in_hunspell,
    compute_recall,
)
from dict_generation.eval.variants import build_variant
from dict_generation.eval.hunspell_runner import HUNSPELL_CLI_PATH


class FoundInDawgTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.path, _ = build_variant("baseline")

    def test_known_word_found(self):
        self.assertTrue(found_in_dawg(self.path, "καλημέρα", "καλημέρα"))

    def test_phonetic_alternate_found(self):
        # 'καλιμερα' folds to the same key as 'καλημέρα'; the canonical
        # 'καλημέρα' is in the canonical-form list for that key.
        self.assertTrue(found_in_dawg(self.path, "καλιμερα", "καλημέρα"))

    def test_unrelated_input_not_found(self):
        self.assertFalse(found_in_dawg(self.path, "καλημέρα", "νερό"))


@unittest.skipUnless(
    os.path.exists(HUNSPELL_CLI_PATH),
    f"hunspell-cli not built; skipping Hunspell recall tests",
)
class FoundInHunspellTests(unittest.TestCase):

    def test_correct_word_when_input_equals_expected(self):
        # 'καλημέρα' is correctly spelled; expected = input → found.
        self.assertTrue(found_in_hunspell("καλημέρα", "καλημέρα"))

    def test_misspelled_finds_correction(self):
        # 'καλιμερα' should produce 'καλημέρα' in the suggestion list.
        self.assertTrue(found_in_hunspell("καλιμερα", "καλημέρα"))


class ComputeRecallTests(unittest.TestCase):

    def test_recall_basic(self):
        pairs = [("a", "x"), ("b", "x"), ("c", "x")]
        # found_fn returns True iff input is "a" or "b"
        recall = compute_recall(pairs, lambda inp, exp: inp in {"a", "b"})
        self.assertEqual(recall, 2 / 3)

    def test_recall_empty(self):
        recall = compute_recall([], lambda inp, exp: True)
        self.assertEqual(recall, 0.0)


if __name__ == "__main__":
    unittest.main()
