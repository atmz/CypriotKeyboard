"""Wrapper around our vendored Hunspell CLI (built from hunspell_src/).

The CLI matches the iOS extension's runtime Hunspell behavior exactly,
since it's compiled from the same vendored sources. Output is the
ispell pipe protocol.

Build the CLI once with: `cd dict_generation && make hunspell-cli`.
Then this module subprocesses into it for each lookup.
"""
import os
import subprocess
from typing import List


class HunspellCliNotBuilt(RuntimeError):
    pass


_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HUNSPELL_CLI_PATH = os.path.join(
    _REPO, "dict_generation", "eval", "hunspell_cli", "hunspell-cli"
)
AFF_PATH = os.path.join(_REPO, "dict", "el_CY.aff")
DIC_PATH = os.path.join(_REPO, "dict", "el_CY.dic")


def suggest_via_hunspell(word: str) -> List[str]:
    """Return the list of Hunspell suggestions for `word`.

    Returns [] if the word is correctly spelled. The caller can compare
    word == expected separately for the identity case.
    """
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
    return _parse_pipe_output(proc.stdout)


def _parse_pipe_output(output: str) -> List[str]:
    """Parse the ispell pipe protocol output and return the suggestion list."""
    for raw in output.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("@"):
            continue  # banner
        if line.startswith("*") or line.startswith("+"):
            return []  # correctly spelled
        if line.startswith("#"):
            return []  # misspelled, no suggestions
        if line.startswith("&"):
            # Format: "& <word> <count> <offset>: <sugg1>, <sugg2>, ..."
            _, _, after_colon = line.partition(":")
            return [s.strip() for s in after_colon.split(",") if s.strip()]
    return []
