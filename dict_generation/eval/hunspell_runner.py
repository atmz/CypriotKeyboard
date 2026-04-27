"""Wrapper around our vendored Hunspell CLI (built from hunspell_src/).

The CLI matches the iOS extension's runtime Hunspell behavior exactly,
since it's compiled from the same vendored sources. Output is the
ispell pipe protocol.

Build the CLI once with: `cd dict_generation && make hunspell-cli`.
Then this module subprocesses into it for each lookup.
"""
import os
import subprocess
from typing import List, NamedTuple, Optional


class HunspellCliNotBuilt(RuntimeError):
    pass


_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HUNSPELL_CLI_PATH = os.path.join(
    _REPO, "dict_generation", "eval", "hunspell_cli", "hunspell-cli"
)
AFF_PATH = os.path.join(_REPO, "dict", "el_CY.aff")
DIC_PATH = os.path.join(_REPO, "dict", "el_CY.dic")


class HunspellResult(NamedTuple):
    """Structured result of one hunspell-cli analysis.

    - is_correct: True if Hunspell reports the word as recognized
      (line started with `*` or `+`).
    - suggestions: only nonempty when Hunspell returned an `&` line
      (misspelled, with suggestions).
    - root: only set when Hunspell returned `+ <root>` (the analyzed
      root form, useful for inflected words).
    """
    is_correct: bool
    suggestions: List[str]
    root: Optional[str]


def analyze_via_hunspell(word: str) -> HunspellResult:
    """Run hunspell-cli on `word` and return its structured result."""
    if not os.path.exists(HUNSPELL_CLI_PATH):
        raise HunspellCliNotBuilt(
            f"hunspell-cli not built at {HUNSPELL_CLI_PATH}; "
            f"run `cd dict_generation && make hunspell-cli`"
        )

    proc = subprocess.run(
        [HUNSPELL_CLI_PATH, AFF_PATH, DIC_PATH],
        input=word + "\n",
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return _parse_pipe_output_full(proc.stdout)


def _parse_pipe_output_full(output: str) -> HunspellResult:
    """Parse hunspell pipe protocol output into a HunspellResult."""
    for raw in output.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("@"):
            continue  # banner
        if line.startswith("*"):
            return HunspellResult(is_correct=True, suggestions=[], root=None)
        if line.startswith("+"):
            # Format: "+ <root>"
            parts = line.split(None, 1)
            root = parts[1].strip() if len(parts) >= 2 else None
            return HunspellResult(is_correct=True, suggestions=[], root=root)
        if line.startswith("#"):
            # Misspelled, no suggestions.
            return HunspellResult(is_correct=False, suggestions=[], root=None)
        if line.startswith("&"):
            # "& <word> <count> <offset>: <sugg1>, <sugg2>, ..."
            _, _, after_colon = line.partition(":")
            suggestions = [s.strip() for s in after_colon.split(",") if s.strip()]
            return HunspellResult(is_correct=False, suggestions=suggestions, root=None)
    return HunspellResult(is_correct=False, suggestions=[], root=None)


def suggest_via_hunspell(word: str) -> List[str]:
    """Return the list of Hunspell suggestions for `word`. Backwards-compatible
    shape: returns `[]` if the word is correctly spelled or has no suggestions.
    Use `analyze_via_hunspell` for structured output."""
    return analyze_via_hunspell(word).suggestions
