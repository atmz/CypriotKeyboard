"""Lowercased-fold-key proper-noun lookup test."""
import json
import os
import tempfile
import unittest

from dict_generation.build_dawg import build_dawg_to
from dict_generation.dawg import DawgReader
from dict_generation.phonetic_fold import load_default_folder


class BuildDawgTests(unittest.TestCase):

    def test_proper_noun_reachable_via_lowercase_fold_key(self):
        """Πάφος should be retrievable from the lowercase fold key 'παφoσ',
        matching the runtime which always lowercases before lookup."""
        folder = load_default_folder()

        def source():
            # Just one cap-first proper noun.
            yield "Πάφος"

        with tempfile.NamedTemporaryFile(suffix=".dawg", delete=False) as f:
            out_path = f.name
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode="w") as f:
            json.dump({}, f)
            empty_freq_path = f.name
        try:
            build_dawg_to(out_path=out_path, surface_form_source=source,
                          freq_path=empty_freq_path, freq_threshold=0,
                          quiet=True)
            with open(out_path, "rb") as f:
                r = DawgReader(f.read())
            # Lowercase fold key — what the runtime would actually look up.
            lowercase_key = folder.fold("πάφος")
            pidx = r.payload_for(lowercase_key)
            self.assertIsNotNone(
                pidx, f"no payload at lowercase fold key {lowercase_key!r}")
            canonicals = list(r.canonical_forms(pidx))
            self.assertTrue(
                any(c == "Πάφος" for c, _ in canonicals),
                f"Πάφος not under lowercase key; got {canonicals}")
        finally:
            os.unlink(out_path)
            os.unlink(empty_freq_path)
