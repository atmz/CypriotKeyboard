import unittest
from dict_generation.dawg import Dawg


class DawgTrieTests(unittest.TestCase):
    """Phase-1 tests: build behaves like a plain trie. Minimization is
    added in the next task; lookup behavior must hold either way."""

    def test_empty_dawg_contains_nothing(self):
        d = Dawg()
        self.assertFalse(d.contains("foo"))

    def test_insert_and_lookup_single_word(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=0)
        self.assertTrue(d.contains("καλο"))
        self.assertFalse(d.contains("καλ"))   # prefix not terminal
        self.assertFalse(d.contains("καλος")) # extension not terminal

    def test_insert_sorted_two_words(self):
        d = Dawg()
        d.insert_sorted("κα", payload=0)
        d.insert_sorted("καλο", payload=1)
        self.assertTrue(d.contains("κα"))
        self.assertTrue(d.contains("καλο"))

    def test_unsorted_input_raises(self):
        d = Dawg()
        d.insert_sorted("β", payload=0)
        with self.assertRaises(ValueError):
            d.insert_sorted("α", payload=1)  # α < β

    def test_payload_retrieval(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=42)
        d.insert_sorted("νερο", payload=43)
        self.assertEqual(d.payload_for("καλο"), 42)
        self.assertEqual(d.payload_for("νερο"), 43)
        self.assertIsNone(d.payload_for("σπιτι"))


if __name__ == "__main__":
    unittest.main()
