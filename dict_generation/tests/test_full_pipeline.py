"""End-to-end smoke test against the real built DAWG.

Skipped if dict/el_CY.dawg doesn't exist yet (e.g., on a clean checkout
before `make dawg` has run).

Run explicitly:
    python3 -m unittest dict_generation.tests.test_full_pipeline -v
"""
import os
import random
import unittest

from dict_generation.aff_parse import parse_aff
from dict_generation.affix_expand import expand_dic_file
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DAWG_PATH = os.path.join(REPO, "dict", "el_CY.dawg")
DIC_PATH = os.path.join(REPO, "dict", "el_CY.dic")
AFF_PATH = os.path.join(REPO, "dict", "el_CY.aff")


@unittest.skipUnless(os.path.exists(DAWG_PATH), f"{DAWG_PATH} not built; run `make dawg` first")
class FullPipelineTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.reader = DawgReader(open(DAWG_PATH, "rb").read())
        cls.fold = load_default_folder()
        aff = parse_aff(open(AFF_PATH, encoding="utf-8").read())
        # Sample 1000 random surface forms — full enumeration is slow.
        all_forms = list(expand_dic_file(DIC_PATH, aff))
        random.seed(42)
        cls.sample = random.sample(all_forms, k=min(1000, len(all_forms)))

    def test_every_sampled_surface_form_resolves(self):
        misses = []
        for form in self.sample:
            # Runtime always lowercases before fold lookup; the build keys the
            # DAWG under fold(form.lower()), so this test must mirror that path.
            key = self.fold.fold(form.lower())
            payload = self.reader.payload_for(key)
            if payload is None:
                misses.append((form, key))
            else:
                # The canonical-form list for this key must contain `form`.
                forms_in_payload = [s for s, _f in self.reader.canonical_forms(payload)]
                if form not in forms_in_payload:
                    misses.append((form, key))
        self.assertEqual(misses, [], f"{len(misses)} surface forms missing from DAWG; first 10: {misses[:10]}")

    def test_phonetic_collisions_share_a_payload(self):
        # 'καλημέρα' and 'καλιμερα' fold to the same key by design.
        # If both are in the dict, they should resolve to the same payload index.
        key1 = self.fold.fold("καλημέρα")
        p1 = self.reader.payload_for(key1)
        # We don't assert that 'καλιμερα' is in the dict — but if it is,
        # it must point to the same payload.
        key2 = self.fold.fold("καλιμερα")
        self.assertEqual(key1, key2, "These two should fold identically")
        p2 = self.reader.payload_for(key2)
        if p2 is not None:
            self.assertEqual(p1, p2, "Phonetic collision did not share payload")
