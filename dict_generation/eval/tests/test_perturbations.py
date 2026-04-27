import unittest
from dict_generation.eval.perturbations import (
    identity, unaccented, vowel_swap, greekified_latin,
    _greekify_python,
)


class IdentityTests(unittest.TestCase):
    def test_yields_word_once(self):
        self.assertEqual(list(identity("καλημέρα")), [("καλημέρα", "identity")])


class UnaccentedTests(unittest.TestCase):
    def test_strips_acute_accent(self):
        self.assertEqual(list(unaccented("καλημέρα")), [("καλημερα", "unaccented")])

    def test_strips_diaeresis(self):
        self.assertEqual(list(unaccented("προϋπόθεση")), [("προυποθεση", "unaccented")])

    def test_unchanged_when_no_accents(self):
        self.assertEqual(list(unaccented("νερο")), [("νερο", "unaccented")])


class VowelSwapTests(unittest.TestCase):
    def test_single_eta_word_emits_swaps_to_iota_and_upsilon(self):
        # "καλημερα" has η at position 3. Swaps: ι, υ.
        results = list(vowel_swap("καλημερα"))
        words = [w for w, _ in results]
        self.assertIn("καλιμερα", words)
        self.assertIn("καλυμερα", words)
        # Original η should NOT be in the output (we want a swap, not identity).
        self.assertNotIn("καλημερα", words)

    def test_no_i_class_vowels_emits_nothing(self):
        # "νερο" has no η/ι/υ — we don't synthesize i-class vowels from nowhere.
        self.assertEqual(list(vowel_swap("νερο")), [])

    def test_class_label(self):
        for _, label in vowel_swap("καλημερα"):
            self.assertEqual(label, "vowel_swap")


class GreekifiedLatinTests(unittest.TestCase):
    def test_yields_one_pair(self):
        results = list(greekified_latin("καλημέρα"))
        self.assertEqual(len(results), 1)
        word, label = results[0]
        self.assertEqual(label, "greekified_latin")
        # The output is the result of inverse_greekify then re-greekify.
        # Greek input is preserved in the i-position (η→i→ι), but vowels
        # collapse, so we expect the result to differ from the original.
        self.assertNotEqual(word, "καλημέρα")
        # The result must be all-Greek (the re-greekify wraps Latin back in Greek).
        self.assertTrue(all(not ch.isascii() or not ch.isalpha() for ch in word),
                        f"unexpected Latin in output: {word!r}")


class GreekifyPythonTests(unittest.TestCase):
    def test_basic_kalimera(self):
        self.assertEqual(_greekify_python("kalimera"), "καλιμερα")

    def test_digraph_th(self):
        self.assertEqual(_greekify_python("theos"), "θεοσ")

    def test_b_becomes_mp(self):
        self.assertEqual(_greekify_python("b"), "μπ")

    def test_pass_through_greek(self):
        # Greek input passes through unchanged — none of the rules match.
        self.assertEqual(_greekify_python("καλιμερα"), "καλιμερα")


if __name__ == "__main__":
    unittest.main()
