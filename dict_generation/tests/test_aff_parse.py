import unittest
from dict_generation.aff_parse import parse_aff, SfxRule


class AffParseTests(unittest.TestCase):

    def test_parses_set_utf8(self):
        aff = parse_aff("SET UTF-8\n")
        self.assertEqual(aff.encoding, "UTF-8")

    def test_parses_flag_num(self):
        aff = parse_aff("FLAG num\n")
        self.assertEqual(aff.flag_type, "num")

    def test_parses_simple_sfx_rule(self):
        text = """\
SET UTF-8
FLAG num
SFX 1 Y 1
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)
        rule = aff.sfx_rules["1"]
        self.assertEqual(rule.flag, "1")
        self.assertEqual(len(rule.entries), 1)
        entry = rule.entries[0]
        self.assertEqual(entry.strip, "")
        self.assertEqual(entry.append, "ς")
        self.assertEqual(entry.condition, ".")

    def test_zero_strip_normalizes_to_empty_string(self):
        text = """\
FLAG num
SFX 2 Y 1
SFX 2 0 ν .
"""
        aff = parse_aff(text)
        rule = aff.sfx_rules["2"]
        self.assertEqual(rule.entries[0].strip, "")
        self.assertEqual(rule.entries[0].append, "ν")

    def test_multiple_rules(self):
        text = """\
FLAG num
SFX 1 Y 1
SFX 1 0 ς .
SFX 4 Y 1
SFX 4 0 υ .
"""
        aff = parse_aff(text)
        self.assertEqual(set(aff.sfx_rules.keys()), {"1", "4"})

    def test_ignores_comments_and_blank_lines(self):
        text = """\
# comment
FLAG num

SFX 1 Y 1
# nested comment
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)

    def test_ignores_unsupported_directives(self):
        # TRY, REP, MAP etc. should be parsed-and-discarded without errors.
        text = """\
SET UTF-8
FLAG num
TRY άόίϊΐέήύϋΰώσ̆
REP 488
REP σ ς
SFX 1 Y 1
SFX 1 0 ς .
"""
        aff = parse_aff(text)
        self.assertEqual(len(aff.sfx_rules), 1)


if __name__ == "__main__":
    unittest.main()
