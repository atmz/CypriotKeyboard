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


class DawgMinimizationTests(unittest.TestCase):

    def test_shared_suffix_collapses_to_one_node(self):
        # Three words sharing a common suffix "ος" must produce exactly
        # one shared subgraph for that suffix after finalization.
        d = Dawg()
        for w in ["αλος", "βελος", "γελος"]:
            d.insert_sorted(w, payload=0)
        d.finalize()
        # All three words still resolve.
        for w in ["αλος", "βελος", "γελος"]:
            self.assertTrue(d.contains(w))
        # Node count should be much less than the naïve 3×3 = 9 unique
        # suffix nodes a plain trie would produce. We don't pin an exact
        # number (depends on implementation), but it must drop.
        self.assertLess(d.node_count(), 9)

    def test_finalize_is_idempotent(self):
        d = Dawg()
        d.insert_sorted("καλο", payload=0)
        d.finalize()
        d.finalize()  # second call must not blow up
        self.assertTrue(d.contains("καλο"))

    def test_insert_after_finalize_raises(self):
        d = Dawg()
        d.insert_sorted("α", payload=0)
        d.finalize()
        with self.assertRaises(RuntimeError):
            d.insert_sorted("β", payload=1)

    def test_real_word_set_node_count_drops(self):
        # Fixture: a subset of inflections that share Greek suffixes.
        words = sorted({
            "καλο", "καλος", "καλον", "καλου", "καλους",
            "νεο", "νεος", "νεον", "νεου", "νεους",
            "μικρο", "μικρος", "μικρον", "μικρου", "μικρους",
        })
        d = Dawg()
        for w in words:
            d.insert_sorted(w, payload=0)
        d.finalize()
        for w in words:
            self.assertTrue(d.contains(w))
        # Plain trie would be sum-of-distinct-paths nodes. The DAWG
        # should compress meaningfully — fewer nodes than the trie
        # would have.
        trie_nodes_upper_bound = sum(len(w) for w in words)
        self.assertLess(d.node_count(), trie_nodes_upper_bound // 2)


if __name__ == "__main__":
    unittest.main()
