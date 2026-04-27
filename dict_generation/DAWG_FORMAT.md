# DAWG binary format v1

Used by tier-c. Produced by `dict_generation/dawg.py`'s `Dawg.serialize`,
consumed by the Phase 2 Swift runtime reader.

## Header (32 bytes)

| offset | size | field                  |
|--------|------|------------------------|
| 0      | 4    | magic = `b"DAWG"`      |
| 4      | 2    | version (uint16 LE)    |
| 6      | 2    | reserved = 0           |
| 8      | 4    | node_count             |
| 12     | 4    | payload_count          |
| 16     | 4    | string_table_count     |
| 20     | 4    | node_section_offset    |
| 24     | 4    | payload_section_offset |
| 28     | 4    | string_table_offset    |

All multi-byte integers little-endian.

## Node section

`node_count` variable-length records. Each node:

| size | field                                                |
|------|------------------------------------------------------|
| 2    | edge_count (uint16 LE)                               |
| 4    | terminal_payload_idx (uint32 LE; `0xFFFFFFFF` = none)|
| ...  | edge_count × edge record (8 bytes each)              |

Edge record:

| size | field                  |
|------|------------------------|
| 4    | char_codepoint (uint32 LE) |
| 4    | target_node_idx (uint32 LE) |

Edges within a node are stored sorted ascending by `char_codepoint`.
Readers may binary-search.

The **root** is the last node (`node_idx = node_count - 1`).

## Payload section

`payload_count` variable-length records. Each payload entry:

| size | field                                  |
|------|----------------------------------------|
| 2    | canonical_form_count (uint16 LE)       |
| ...  | canonical_form_count × 8-byte records  |

Each canonical-form record:

| size | field            |
|------|------------------|
| 4    | string_idx (uint32 LE) |
| 4    | freq       (uint32 LE) |

## String table

`string_table_count` variable-length records. Each:

| size | field                              |
|------|------------------------------------|
| 2    | length_in_utf8_bytes (uint16 LE)   |
| ...  | UTF-8 bytes                        |

Strings are referenced by their position (0-based index) in this table.
The encoder dedupes; multiple payloads can share a string index.

## Versioning

Readers MUST verify magic + version. Unknown versions = reject.

Future format extensions go in version 2+. Version 1 will not be
mutated after Phase 1 ships.
