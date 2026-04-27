import unittest
from dict_generation.eval.inverse_greekify import inverse_greekify


class InverseGreekifyTests(unittest.TestCase):

    def test_basic_letters(self):
        self.assertEqual(inverse_greekify("καλημερα"), "kalimera")
        self.assertEqual(inverse_greekify("νερο"), "nero")

    def test_diacritics_dropped(self):
        self.assertEqual(inverse_greekify("καλημέρα"), "kalimera")
        self.assertEqual(inverse_greekify("ώρα"), "ora")

    def test_eta_iota_collapse_to_i(self):
        # η and ι both map to "i" in Greeklish convention.
        self.assertEqual(inverse_greekify("ηλικια"), "ilikia")

    def test_upsilon_maps_to_y(self):
        # υ uses "y" (so the output is parseable by greekify, which has y → υ).
        self.assertEqual(inverse_greekify("υπερ"), "yper")

    def test_omega_collapses_to_o(self):
        self.assertEqual(inverse_greekify("ωρα"), "ora")

    def test_digraphs_handled(self):
        # ει, οι, υι are i-sound digraphs; ου is the /u/ digraph; αι is /e/.
        self.assertEqual(inverse_greekify("ειδος"), "eidos")  # let greekify rebuild ει
        self.assertEqual(inverse_greekify("ουρα"), "oura")
        self.assertEqual(inverse_greekify("αιμα"), "aima")

    def test_special_consonants(self):
        # The Latin spellings are chosen for round-trip safety with greekify:
        # greekify has ks → ξ and x → χ, so we must invert in matching shape.
        self.assertEqual(inverse_greekify("θεος"), "theos")
        self.assertEqual(inverse_greekify("χωρα"), "xora")     # χ → x (so x → χ rebuilds it)
        self.assertEqual(inverse_greekify("ψυχη"), "psyxi")    # ψ→ps, υ→y, χ→x, η→i
        self.assertEqual(inverse_greekify("ξενος"), "ksenos")  # ξ → ks (so ks → ξ rebuilds it)

    def test_final_sigma(self):
        self.assertEqual(inverse_greekify("καλος"), "kalos")
        self.assertEqual(inverse_greekify("καλώς"), "kalos")

    def test_empty_input(self):
        self.assertEqual(inverse_greekify(""), "")

    def test_output_is_ascii_lowercase(self):
        # Sanity: the function should never emit Greek characters or uppercase.
        for word in ["καλημέρα", "ώρα", "θεός", "ψυχή"]:
            out = inverse_greekify(word)
            self.assertTrue(out.isascii(), f"non-ASCII output for {word!r}: {out!r}")
            self.assertEqual(out, out.lower(), f"uppercase in output for {word!r}: {out!r}")


if __name__ == "__main__":
    unittest.main()
