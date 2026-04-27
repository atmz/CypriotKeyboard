import os
import unittest
from dict_generation.phonetic_fold import PhoneticFolder, load_default_folder


class PhoneticFoldTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.fold = load_default_folder()

    def test_single_i_sound_vowels_collapse(self):
        # Different i-sound spellings (η, ι, υ) all collapse to the same key.
        # ε also folds to canonical Latin "e".
        self.assertEqual(self.fold.fold("καλημερα"), "καλıμeρα")
        self.assertEqual(self.fold.fold("καλιμερα"), "καλıμeρα")
        self.assertEqual(self.fold.fold("καλυμερα"), "καλıμeρα")

    def test_digraphs_win_over_singles(self):
        # ει must collapse to ı (single key), not to ε + ı
        self.assertEqual(self.fold.fold("ειδος"), "ıδoσ")
        self.assertEqual(self.fold.fold("οικος"), "ıκoσ")
        self.assertEqual(self.fold.fold("αιμα"), "eμα")

    def test_diacritics_drop(self):
        self.assertEqual(self.fold.fold("καλημέρα"), "καλıμeρα")
        self.assertEqual(self.fold.fold("ώρα"), "oρα")

    def test_final_sigma_normalizes(self):
        self.assertEqual(self.fold.fold("καλος"), "καλoσ")
        self.assertEqual(self.fold.fold("καλός"), "καλoσ")

    def test_empty_input(self):
        self.assertEqual(self.fold.fold(""), "")

    def test_passes_through_unmapped(self):
        # Latin letters and punctuation are not part of the Greek fold and pass through.
        self.assertEqual(self.fold.fold("hello"), "hello")
        self.assertEqual(self.fold.fold(" "), " ")

    def test_collisions_within_phonetic_class(self):
        # Different spellings of the same i-sound (in the η-position of καλημέρα)
        # all fold identically to one canonical key.
        for inp in ["καλημερα", "καλιμερα", "καλυμερα", "καλημέρα", "καλείμερα"]:
            self.assertEqual(self.fold.fold(inp), "καλıμeρα", f"failed for {inp!r}")

    def test_e_sound_class_collisions(self):
        # ε and αι are both pronounced /e/ in Modern Greek; both must
        # produce the same fold key for an otherwise-equivalent word.
        self.assertEqual(self.fold.fold("εμα"), self.fold.fold("αιμα"))


class FoldVariantsTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.fold = load_default_folder()

    def test_no_digraph_returns_one_variant(self):
        # "νερό" has no digraph rule matches — single variant only.
        variants = self.fold.fold_variants("νερό")
        self.assertEqual(variants, ["νeρo"])

    def test_one_digraph_returns_two_variants(self):
        # "νοιμα" has οι at position 1. Two variants:
        #   (a) digraph fires: ν + (οι→ı) + μ + α = "νıμα"
        #   (b) digraph doesn't fire: ν + ο + ι + μ + α = "νoıμα"
        variants = self.fold.fold_variants("νοιμα")
        self.assertIn("νıμα", variants)
        self.assertIn("νoıμα", variants)
        self.assertEqual(len(variants), 2)

    def test_first_variant_matches_primary_fold(self):
        # The first variant should equal what self.fold.fold(text) returns.
        for word in ["καλημέρα", "νοιμα", "ποικιλία", "αιθέρας", "νερό"]:
            variants = self.fold.fold_variants(word)
            self.assertEqual(variants[0], self.fold.fold(word),
                             f"first variant must match primary fold for {word!r}")

    def test_two_digraphs_returns_up_to_four_variants(self):
        # "ποικιλεια" has οι at 1 and ει at 7. Should produce up to 4 variants
        # depending on how each digraph chooses to fire.
        variants = self.fold.fold_variants("ποικιλεια")
        self.assertGreaterEqual(len(variants), 2)
        self.assertLessEqual(len(variants), 4)

    def test_max_variants_caps_growth(self):
        # Even with many digraphs, the cap holds.
        # Construct a string with several digraphs.
        text = "οι" * 8  # 8 οι digraphs
        variants = self.fold.fold_variants(text, max_variants=4)
        self.assertEqual(len(variants), 4)


if __name__ == "__main__":
    unittest.main()
