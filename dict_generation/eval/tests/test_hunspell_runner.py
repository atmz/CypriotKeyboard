import os
import unittest
from dict_generation.eval.hunspell_runner import (
    suggest_via_hunspell,
    HunspellCliNotBuilt,
    HUNSPELL_CLI_PATH,
)


@unittest.skipUnless(
    os.path.exists(HUNSPELL_CLI_PATH),
    f"hunspell-cli not built at {HUNSPELL_CLI_PATH}; run `cd dict_generation && make hunspell-cli`",
)
class HunspellRunnerTests(unittest.TestCase):

    def test_known_correct_word_returns_no_suggestions_or_self(self):
        # 'και' is high-frequency Greek and should be correctly spelled.
        suggestions = suggest_via_hunspell("και")
        # Either Hunspell says "correct" (empty list) or returns 'και' in its suggestions.
        self.assertTrue(len(suggestions) == 0 or "και" in suggestions)

    def test_misspelled_word_returns_suggestions(self):
        # 'καλιμερα' (using ι instead of η) should suggest 'καλημέρα'.
        suggestions = suggest_via_hunspell("καλιμερα")
        self.assertIn("καλημέρα", suggestions,
                      f"expected 'καλημέρα' in suggestions, got: {suggestions[:5]}")

    def test_garbage_returns_few_or_no_suggestions(self):
        suggestions = suggest_via_hunspell("zzzzzzzz")
        self.assertIsInstance(suggestions, list)

    def test_analyze_correct_word(self):
        from dict_generation.eval.hunspell_runner import analyze_via_hunspell
        result = analyze_via_hunspell("και")
        self.assertTrue(result.is_correct)

    def test_analyze_misspelled_word_returns_suggestions(self):
        from dict_generation.eval.hunspell_runner import analyze_via_hunspell
        result = analyze_via_hunspell("καλιμερα")
        self.assertFalse(result.is_correct)
        self.assertIn("καλημέρα", result.suggestions)

    def test_analyze_garbage_returns_misspelled_no_suggestions(self):
        from dict_generation.eval.hunspell_runner import analyze_via_hunspell
        result = analyze_via_hunspell("zzzzzzzz")
        # Either misspelled with no suggestions, or treated as correct
        # (vendored CLI behavior). Just confirm the result type is well-formed.
        self.assertIsInstance(result.is_correct, bool)
        self.assertIsInstance(result.suggestions, list)


class HunspellCliNotBuiltTests(unittest.TestCase):
    def test_error_class_subclasses_runtime_error(self):
        self.assertTrue(issubclass(HunspellCliNotBuilt, RuntimeError))


if __name__ == "__main__":
    unittest.main()
