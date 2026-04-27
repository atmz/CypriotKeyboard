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


import struct
from typing import BinaryIO, List, Tuple


# --- Serializer ---

_MAGIC = b"DAWG"
_VERSION = 1
_NULL_PAYLOAD = 0xFFFFFFFF


def _walk_nodes(root: "_Node") -> List["_Node"]:
    """Return all reachable nodes in deterministic order. Root last."""
    seen: Dict[int, "_Node"] = {}
    order: List["_Node"] = []
    stack = [root]
    while stack:
        node = stack.pop()
        if node.id in seen:
            continue
        seen[node.id] = node
        order.append(node)
        for _, child in sorted(node.edges.items()):
            stack.append(child)
    # Sort so root is last (per format spec). Within ids, stable.
    order.sort(key=lambda n: n.id)
    return order


# Defined as a free function and attached to Dawg via assignment below
# (Python "monkey-patch as method"). This keeps Task 9's diff isolated
# from Task 8's class body.
def _dawg_serialize(self, out: BinaryIO, payloads: List[List[Tuple[int, int]]], strings: List[str]) -> None:
    """Write self to `out` in the v1 binary format.

    payloads: list indexed by terminal payload id; each entry is a list of
              (string_idx, freq) tuples for that key's canonical forms.
    strings:  list of canonical form strings; payload tuples reference by index.
    """
    if not self._finalized:
        raise RuntimeError("DAWG must be finalized before serialization")

    nodes = _walk_nodes(self._root)
    # Re-number nodes so root is last (matches format spec).
    id_map = {n.id: i for i, n in enumerate(nodes)}

    # ---- Build node bytes
    node_bytes = bytearray()
    for node in nodes:
        edges = sorted(node.edges.items())
        node_bytes += struct.pack("<H", len(edges))
        node_bytes += struct.pack("<I", node.terminal_payload if node.terminal_payload is not None else _NULL_PAYLOAD)
        for ch, child in edges:
            cp = ord(ch) if len(ch) == 1 else 0  # multi-codepoint chars not supported in keys
            node_bytes += struct.pack("<II", cp, id_map[child.id])

    # ---- Build string table bytes
    str_bytes = bytearray()
    str_offsets: List[int] = []
    for s in strings:
        encoded = s.encode("utf-8")
        if len(encoded) > 0xFFFF:
            raise ValueError(f"string too long for v1 format: {len(encoded)} bytes")
        str_offsets.append(len(str_bytes))
        str_bytes += struct.pack("<H", len(encoded))
        str_bytes += encoded

    # ---- Build payload bytes
    payload_bytes = bytearray()
    payload_offsets: List[int] = []
    for entry in payloads:
        payload_offsets.append(len(payload_bytes))
        payload_bytes += struct.pack("<H", len(entry))
        for str_idx, freq in entry:
            payload_bytes += struct.pack("<II", str_idx, freq)

    # ---- Compute offsets and write header
    HEADER_SIZE = 32
    node_section_offset = HEADER_SIZE
    payload_section_offset = node_section_offset + len(node_bytes)
    string_table_offset = payload_section_offset + len(payload_bytes)

    out.write(_MAGIC)
    out.write(struct.pack("<HH", _VERSION, 0))
    out.write(struct.pack("<III", len(nodes), len(payloads), len(strings)))
    out.write(struct.pack("<III", node_section_offset, payload_section_offset, string_table_offset))
    out.write(node_bytes)
    out.write(payload_bytes)
    out.write(str_bytes)


# Wire the method into the Dawg class.
Dawg.serialize = _dawg_serialize


# --- Reader ---

class DawgReader:
    """Reads the v1 binary format. Mirrors the Swift Phase 2 reader's
    contract — used in tests to round-trip the writer."""

    def __init__(self, data: bytes):
        if data[:4] != _MAGIC:
            raise ValueError("not a DAWG file (bad magic)")
        version = struct.unpack_from("<H", data, 4)[0]
        if version != _VERSION:
            raise ValueError(f"unsupported DAWG version {version}")
        self._data = data
        self._node_count = struct.unpack_from("<I", data, 8)[0]
        self._payload_count = struct.unpack_from("<I", data, 12)[0]
        self._string_count = struct.unpack_from("<I", data, 16)[0]
        self._node_off = struct.unpack_from("<I", data, 20)[0]
        self._payload_off = struct.unpack_from("<I", data, 24)[0]
        self._string_off = struct.unpack_from("<I", data, 28)[0]
        # Pre-index node offsets within the node section since records vary in size.
        self._node_offsets = self._index_nodes()
        self._payload_offsets = self._index_payloads()
        self._string_offsets = self._index_strings()

    def _index_nodes(self) -> List[int]:
        offs = []
        cursor = self._node_off
        for _ in range(self._node_count):
            offs.append(cursor)
            edge_count = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + 4 + edge_count * 8
        return offs

    def _index_payloads(self) -> List[int]:
        offs = []
        cursor = self._payload_off
        for _ in range(self._payload_count):
            offs.append(cursor)
            cf_count = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + cf_count * 8
        return offs

    def _index_strings(self) -> List[int]:
        offs = []
        cursor = self._string_off
        for _ in range(self._string_count):
            offs.append(cursor)
            ln = struct.unpack_from("<H", self._data, cursor)[0]
            cursor += 2 + ln
        return offs

    def _root_idx(self) -> int:
        # Root is the last node (per format spec).
        return self._node_count - 1

    def contains(self, word: str) -> bool:
        return self.payload_for(word) is not None

    def payload_for(self, word: str) -> Optional[int]:
        idx = self._root_idx()
        for ch in word:
            idx = self._step(idx, ord(ch))
            if idx is None:
                return None
        return self._terminal_payload(idx)

    def _step(self, node_idx: int, char_code: int) -> Optional[int]:
        off = self._node_offsets[node_idx]
        edge_count = struct.unpack_from("<H", self._data, off)[0]
        edge_off = off + 2 + 4
        # Linear scan; edges are sorted, but for the python tests this is fine.
        for i in range(edge_count):
            cp, tgt = struct.unpack_from("<II", self._data, edge_off + i * 8)
            if cp == char_code:
                return tgt
            if cp > char_code:
                return None
        return None

    def _terminal_payload(self, node_idx: int) -> Optional[int]:
        off = self._node_offsets[node_idx]
        payload = struct.unpack_from("<I", self._data, off + 2)[0]
        return None if payload == _NULL_PAYLOAD else payload

    def canonical_forms(self, payload_idx: int) -> List[Tuple[str, int]]:
        off = self._payload_offsets[payload_idx]
        cf_count = struct.unpack_from("<H", self._data, off)[0]
        records = []
        for i in range(cf_count):
            str_idx, freq = struct.unpack_from("<II", self._data, off + 2 + i * 8)
            s_off = self._string_offsets[str_idx]
            ln = struct.unpack_from("<H", self._data, s_off)[0]
            s = self._data[s_off + 2 : s_off + 2 + ln].decode("utf-8")
            records.append((s, freq))
        return records
