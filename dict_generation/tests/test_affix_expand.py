import unittest
from dict_generation.aff_parse import AffFile, SfxRule, SfxEntry
from dict_generation.affix_expand import expand_dic, expand_line


def _aff_with_simple_sfx() -> AffFile:
    aff = AffFile()
    aff.sfx_rules["1"] = SfxRule(flag="1", cross_product=True, entries=[
        SfxEntry(strip="", append="ς", condition="."),
    ])
    aff.sfx_rules["2"] = SfxRule(flag="2", cross_product=True, entries=[
        SfxEntry(strip="", append="ν", condition="."),
    ])
    return aff


class ExpandLineTests(unittest.TestCase):

    def setUp(self):
        self.aff = _aff_with_simple_sfx()

    def test_stem_with_no_flags_yields_only_stem(self):
        self.assertEqual(list(expand_line("καλημέρα", self.aff)), ["καλημέρα"])

    def test_stem_with_one_flag_yields_stem_plus_appended(self):
        result = list(expand_line("καλο/1", self.aff))
        self.assertEqual(set(result), {"καλο", "καλος"})

    def test_stem_with_multiple_flags_yields_each_application(self):
        result = list(expand_line("καλο/1,2", self.aff))
        self.assertEqual(set(result), {"καλο", "καλος", "καλον"})

    def test_unknown_flag_is_skipped(self):
        # /Υ is in the dic but not in any SFX rule — should yield only the stem.
        result = list(expand_line("Η/Υ", self.aff))
        self.assertEqual(result, ["Η"])

    def test_blank_line_yields_nothing(self):
        self.assertEqual(list(expand_line("", self.aff)), [])

    def test_comment_line_yields_nothing(self):
        self.assertEqual(list(expand_line("# this is a comment", self.aff)), [])


class ExpandDicTests(unittest.TestCase):

    def setUp(self):
        self.aff = _aff_with_simple_sfx()

    def test_skips_count_header(self):
        text = "3\nκαλημέρα\nώρα\nώραια\n"
        result = list(expand_dic(text, self.aff))
        self.assertEqual(set(result), {"καλημέρα", "ώρα", "ώραια"})

    def test_full_pipeline_with_flags(self):
        text = "2\nκαλο/1\nώρα\n"
        result = list(expand_dic(text, self.aff))
        self.assertEqual(set(result), {"καλο", "καλος", "ώρα"})


if __name__ == "__main__":
    unittest.main()
