"""Minimal parser for the Hunspell .aff format used by el_CY.aff.

Supports only what we need: SET, FLAG, and SFX rule blocks.
Other directives (TRY, REP, MAP, NAME, …) are silently ignored.
"""
from dataclasses import dataclass, field
from typing import Dict, List


@dataclass
class SfxEntry:
    strip: str       # chars to strip from end of stem before appending; "" if "0"
    append: str      # chars to append; "" if "0"
    condition: str   # regex-like condition on the stem suffix; "." matches anything

    def applies_to(self, stem: str) -> bool:
        # The condition is a Hunspell-flavored regex on the END of the stem.
        # For el_CY.aff every SFX condition is "." — match any stem. We
        # implement only that case here; extend if a future .aff uses real
        # conditions.
        if self.condition == ".":
            return True
        # Conservatively reject anything we don't model.
        raise NotImplementedError(
            f"SfxEntry.applies_to: unsupported condition {self.condition!r}; extend the parser."
        )

    def apply(self, stem: str) -> str:
        if self.strip and stem.endswith(self.strip):
            stem = stem[: -len(self.strip)]
        return stem + self.append


@dataclass
class SfxRule:
    flag: str
    cross_product: bool
    entries: List[SfxEntry] = field(default_factory=list)


@dataclass
class AffFile:
    encoding: str = "UTF-8"
    flag_type: str = "num"
    sfx_rules: Dict[str, SfxRule] = field(default_factory=dict)


def parse_aff(text: str) -> AffFile:
    aff = AffFile()
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 3)
        if not parts:
            continue
        directive = parts[0]
        if directive == "SET" and len(parts) >= 2:
            aff.encoding = parts[1]
        elif directive == "FLAG" and len(parts) >= 2:
            aff.flag_type = parts[1]
        elif directive == "SFX":
            # Header form:  SFX <flag> <Y|N> <count>
            # Entry form:   SFX <flag> <strip> <append> <condition> [morph...]
            if len(parts) >= 4 and parts[2] in ("Y", "N"):
                # Header line
                flag, cross, _count = parts[1], parts[2] == "Y", parts[3]
                aff.sfx_rules[flag] = SfxRule(flag=flag, cross_product=cross)
            else:
                # Entry line; re-split with maxsplit=4 to capture the condition properly
                fields_ = line.split(None, 4)
                if len(fields_) < 5:
                    continue  # malformed — skip
                _, flag, strip, append, condition_and_rest = fields_
                condition = condition_and_rest.split(None, 1)[0]
                strip = "" if strip == "0" else strip
                append = "" if append == "0" else append
                rule = aff.sfx_rules.get(flag)
                if rule is None:
                    # Entry without a header — synthesize an open rule
                    rule = SfxRule(flag=flag, cross_product=True)
                    aff.sfx_rules[flag] = rule
                rule.entries.append(SfxEntry(strip=strip, append=append, condition=condition))
    return aff
