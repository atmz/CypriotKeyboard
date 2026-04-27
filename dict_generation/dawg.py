"""Incremental DAWG construction (Daciuk algorithm) for sorted input.

Builds a minimal acyclic deterministic finite automaton (DAWG/MADFA) by
processing sorted words and sharing suffix subgraphs via an equivalence
registry. As each new word arrives, the previous word's tail (the chain of
nodes that diverge from the new word's common prefix) is finalized and
registered; duplicate signatures are replaced with the canonical instance.

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
        self._unchecked: List[tuple] = []   # (parent, char, child) trail of nodes still mutable
        # Registry maps a node's signature (tuple of (char, child_id) pairs + terminal payload)
        # to the canonical _Node already in the DAWG.
        self._registry: Dict[tuple, _Node] = {}
        self._next_node_id = 0
        self._finalized = False

    def insert_sorted(self, word: str, payload: int) -> None:
        if self._finalized:
            raise RuntimeError("Cannot insert into a finalized DAWG")
        if self._last_word is not None and word <= self._last_word:
            raise ValueError(
                f"insert_sorted requires strictly increasing input; got {word!r} after {self._last_word!r}"
            )

        # Find the longest common prefix between word and last_word.
        common_prefix_len = 0
        if self._last_word is not None:
            for a, b in zip(self._last_word, word):
                if a != b:
                    break
                common_prefix_len += 1

        # The unchecked trail beyond the common prefix is now finalized
        # (no future word can extend into it because words come sorted).
        self._minimize(common_prefix_len)

        # Walk to the prefix node along the unchecked trail (still mutable).
        if common_prefix_len == 0:
            node = self._root
        else:
            # After _minimize, _unchecked has exactly common_prefix_len entries.
            node = self._unchecked[-1][2] if self._unchecked else self._root

        # Add the suffix as fresh nodes.
        for ch in word[common_prefix_len:]:
            child = _Node()
            node.edges[ch] = child
            self._unchecked.append((node, ch, child))
            node = child
        node.terminal_payload = payload

        self._last_word = word

    def _minimize(self, down_to: int) -> None:
        """Register any unchecked nodes deeper than `down_to` into the canonical registry,
        sharing suffixes with previously-registered nodes where possible."""
        while len(self._unchecked) > down_to:
            parent, ch, child = self._unchecked.pop()
            sig = self._signature(child)
            existing = self._registry.get(sig)
            if existing is not None:
                parent.edges[ch] = existing
            else:
                child.id = self._next_node_id
                self._next_node_id += 1
                self._registry[sig] = child

    def _signature(self, node: _Node) -> tuple:
        # A node's identity for sharing: terminal payload + sorted edges keyed by child id.
        # Children must already be registered (have an assigned id) at this point.
        edges_sig = tuple(sorted((ch, c.id) for ch, c in node.edges.items()))
        return (node.terminal_payload, edges_sig)

    def finalize(self) -> None:
        if self._finalized:
            return
        self._minimize(0)
        # Assign id to root (it doesn't go through _minimize).
        self._root.id = self._next_node_id
        self._next_node_id += 1
        self._finalized = True

    def node_count(self) -> int:
        return self._next_node_id

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

    def root(self) -> "_Node":
        return self._root
