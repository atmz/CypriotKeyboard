import unittest
from dict_generation.eval.repl import preprocess_input, postprocess_suggestion, _Casing


class PreprocessInputTests(unittest.TestCase):

    def test_lowercase_input_passes_through(self):
        greekified, lookup, casing, punct = preprocess_input("νερό")
        self.assertEqual(greekified, "νερό")
        self.assertEqual(lookup, "νερό")
        self.assertEqual(casing, _Casing.LOWERCASE)
        self.assertEqual(punct, "")

    def test_capital_first_letter_lowercased(self):
        greekified, lookup, casing, punct = preprocess_input("Νερό")
        self.assertEqual(greekified, "Νερό")
        self.assertEqual(lookup, "νερό")  # lowercased first
        self.assertEqual(casing, _Casing.FIRST_LETTER_CAP)
        self.assertEqual(punct, "")

    def test_all_caps_lowercased(self):
        greekified, lookup, casing, punct = preprocess_input("ΝΕΡΟ")
        self.assertEqual(greekified, "ΝΕΡΟ")
        self.assertEqual(lookup, "νερο")
        self.assertEqual(casing, _Casing.ALL_CAPS)

    def test_latin_input_greekified(self):
        greekified, lookup, casing, punct = preprocess_input("Nero")
        self.assertEqual(greekified, "Νερο")  # Latin → Greek
        self.assertEqual(lookup, "νερο")  # then lowercased per FIRST_LETTER_CAP
        self.assertEqual(casing, _Casing.FIRST_LETTER_CAP)

    def test_leading_punct_stripped(self):
        greekified, lookup, casing, punct = preprocess_input("(νερό)")
        self.assertEqual(greekified, "νερό)")  # trailing ) is part of the body
        self.assertEqual(lookup, "νερό)")
        self.assertEqual(punct, "(")

    def test_empty_after_punct_strip(self):
        greekified, lookup, casing, punct = preprocess_input("(((")
        self.assertEqual(greekified, "")
        self.assertEqual(lookup, "")


class PostprocessSuggestionTests(unittest.TestCase):

    def test_lowercase_canonical_unchanged(self):
        result = postprocess_suggestion("νερό", _Casing.LOWERCASE, "")
        self.assertEqual(result, "νερό")

    def test_first_letter_cap_recapitalized(self):
        result = postprocess_suggestion("νερό", _Casing.FIRST_LETTER_CAP, "")
        self.assertEqual(result, "Νερό")

    def test_all_caps_uppercased(self):
        result = postprocess_suggestion("νερό", _Casing.ALL_CAPS, "")
        # Greek uppercase may or may not preserve tonos depending on locale,
        # so check that the result is fully uppercase.
        self.assertEqual(result, result.upper())
        # And lowercased it should be one of the two canonical forms.
        self.assertIn(result.lower(), ("νερό", "νερο"))

    def test_leading_punct_preserved(self):
        result = postprocess_suggestion("νερό", _Casing.FIRST_LETTER_CAP, "(")
        self.assertEqual(result, "(Νερό")


if __name__ == "__main__":
    unittest.main()
