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


import io
import struct


class DawgSerializationTests(unittest.TestCase):

    def _build_fixture(self):
        d = Dawg()
        for word in ["αβ", "αγ", "βα"]:
            d.insert_sorted(word, payload=0)  # all share payload 0 for this fixture
        d.finalize()
        # Single payload entry for the fixture.
        payloads = [
            [(0, 100)],  # canonical form #0, freq 100
        ]
        strings = ["καλημέρα"]
        return d, payloads, strings

    def test_serialize_writes_magic_header(self):
        d, payloads, strings = self._build_fixture()
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        data = buf.getvalue()
        self.assertEqual(data[:4], b"DAWG")
        version = struct.unpack_from("<H", data, 4)[0]
        self.assertEqual(version, 1)

    def test_round_trip_through_dawg_reader(self):
        d, payloads, strings = self._build_fixture()
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        from dict_generation.dawg import DawgReader
        reader = DawgReader(buf.getvalue())
        # Same words must be findable.
        for word in ["αβ", "αγ", "βα"]:
            self.assertTrue(reader.contains(word), f"missing: {word}")
        # Non-members not found.
        self.assertFalse(reader.contains("γγ"))
        # Payload retrieval round-trips.
        idx = reader.payload_for("αβ")
        self.assertEqual(idx, 0)
        canonical_form_records = reader.canonical_forms(idx)
        self.assertEqual(canonical_form_records, [("καλημέρα", 100)])

    def test_round_trip_with_realistic_size(self):
        # Insert a few hundred sorted folded keys + payloads, round-trip,
        # confirm every key is still findable.
        words = sorted({f"a{i:04d}" for i in range(200)})  # 200 lexicographically-sorted strings
        d = Dawg()
        for i, w in enumerate(words):
            d.insert_sorted(w, payload=i)
        d.finalize()
        payloads = [[(0, 1)] for _ in words]
        strings = ["x"]
        buf = io.BytesIO()
        d.serialize(buf, payloads=payloads, strings=strings)
        from dict_generation.dawg import DawgReader
        reader = DawgReader(buf.getvalue())
        for i, w in enumerate(words):
            self.assertEqual(reader.payload_for(w), i, f"payload mismatch for {w!r}")


if __name__ == "__main__":
    unittest.main()
