"""Incremental DAWG construction (Daciuk algorithm) for sorted input.

Two-phase: this file currently builds a plain trie (each word gets its
own path). The next task adds suffix-sharing minimization. The public
interface (insert_sorted, contains, payload_for) is the same after
minimization is added — only the internal node sharing changes.

Reference: Daciuk, Mihov, Watson, Watson, "Incremental Construction
of Minimal Acyclic Finite-State Automata", Computational Linguistics
26(1), 2000.
"""
from typing import Dict, List, Optional


class _Node:
    __slots__ = ("edges", "terminal_payload", "id")

    def __init__(self):
        self.edges: Dict[str, "_Node"] = {}
        self.terminal_payload: Optional[int] = None  # None = not a terminal
        self.id: int = -1  # assigned during finalization


class Dawg:
    def __init__(self):
        self._root = _Node()
        self._last_word: Optional[str] = None

    def insert_sorted(self, word: str, payload: int) -> None:
        """Insert a word with an associated terminal payload index. Words must arrive in sorted order."""
        if self._last_word is not None and word <= self._last_word:
            raise ValueError(
                f"insert_sorted requires strictly increasing input; got {word!r} after {self._last_word!r}"
            )
        self._last_word = word
        node = self._root
        for ch in word:
            nxt = node.edges.get(ch)
            if nxt is None:
                nxt = _Node()
                node.edges[ch] = nxt
            node = nxt
        node.terminal_payload = payload

    def contains(self, word: str) -> bool:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return False
        return node.terminal_payload is not None

    def payload_for(self, word: str) -> Optional[int]:
        node = self._root
        for ch in word:
            node = node.edges.get(ch)
            if node is None:
                return None
        return node.terminal_payload
