import json
import os
import unittest
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder
from dict_generation.eval.dawg_suggester import DawgSuggester


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
TINY_DAWG = os.path.join(REPO, "Cypriot KeyboardTests", "Resources", "tiny_fixture.dawg")


@unittest.skipUnless(os.path.exists(TINY_DAWG), f"{TINY_DAWG} missing")
class DawgSuggesterTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(TINY_DAWG, "rb") as f:
            cls.reader = DawgReader(f.read())
        cls.folder = load_default_folder()
        cls.suggester = DawgSuggester(cls.reader)

    def test_exact_match_distance_zero(self):
        key = self.folder.fold("καλός")
        suggestions = self.suggester.suggest(key, budget=1, limit=5)
        self.assertTrue(len(suggestions) > 0)
        self.assertEqual(suggestions[0].edit_distance, 0)
        self.assertIn("καλός", [s.canonical for s in suggestions])

    def test_substitution_at_budget_1(self):
        key = self.folder.fold("καλός")
        # Substitute first character with 'x' — should still find καλός at distance 1.
        perturbed = "x" + key[1:]
        suggestions = self.suggester.suggest(perturbed, budget=1, limit=5)
        self.assertTrue(any(s.canonical == "καλός" and s.edit_distance == 1
                            for s in suggestions))

    def test_transposition_at_budget_1(self):
        key = self.folder.fold("νερό")
        if len(key) >= 2:
            chars = list(key)
            chars[0], chars[1] = chars[1], chars[0]
            transposed = "".join(chars)
            suggestions = self.suggester.suggest(transposed, budget=1, limit=5)
            self.assertTrue(any(s.canonical == "νερό" and s.edit_distance == 1
                                for s in suggestions))

    def test_two_edits_misses_at_budget_1(self):
        # Two unrelated chars -> no edit-1 candidate.
        suggestions = self.suggester.suggest("qzxc", budget=1, limit=5)
        self.assertEqual(suggestions, [])

    def test_two_edits_finds_at_budget_2(self):
        key = self.folder.fold("καλός")
        # Substitute 2 characters at positions 0 and 1 — should find καλός at distance 2.
        chars = list(key)
        chars[0] = "x"; chars[1] = "y"
        perturbed = "".join(chars)
        suggestions = self.suggester.suggest(perturbed, budget=2, limit=10)
        self.assertTrue(any(s.canonical == "καλός" and s.edit_distance == 2
                            for s in suggestions),
                        f"expected καλός at d=2; got {[(s.canonical, s.edit_distance) for s in suggestions]}")

    def test_distance_zero_ranks_above_distance_one(self):
        key = self.folder.fold("καλός")
        suggestions = self.suggester.suggest(key, budget=2, limit=10)
        for i in range(1, len(suggestions)):
            self.assertGreaterEqual(suggestions[i].edit_distance,
                                    suggestions[i - 1].edit_distance)

    def test_suggest_multi_returns_min_distance(self):
        # If a canonical appears at d=0 via one fold key and d=1 via another,
        # the merged result should record d=0.
        key_exact = self.folder.fold("καλός")  # exact match for "καλός"
        # Construct a perturbed key that's edit-1 from "καλoσ".
        chars = list(key_exact)
        chars[0] = "x"
        perturbed = "".join(chars)
        # First key: exact match (distance 0). Second: edit-1.
        merged = self.suggester.suggest_multi([key_exact, perturbed], budget=1, limit=5)
        # Find καλός in the merged output.
        kalos = [s for s in merged if s.canonical == "καλός"]
        self.assertEqual(len(kalos), 1)
        self.assertEqual(kalos[0].edit_distance, 0,
                         "suggest_multi must take min distance across keys")

    def test_suggest_multi_dedupes_canonicals(self):
        # The same canonical reachable via multiple keys should appear once.
        key = self.folder.fold("καλός")
        merged = self.suggester.suggest_multi([key, key], budget=1, limit=10)
        canonicals = [s.canonical for s in merged]
        self.assertEqual(len(canonicals), len(set(canonicals)),
                         "suggest_multi must dedupe canonicals across keys")


if __name__ == "__main__":
    unittest.main()
