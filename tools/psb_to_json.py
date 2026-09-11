#!/usr/bin/env python3
"""PSB v3 -> SCN JSON converter for Kirikiri/Emote scenario files.

Pure Python, zero third-party dependencies. The format implementation follows
the FreeMote reference decoder (FreeMote.Psb/Psb.cs, PsbValues.cs,
PsbHeader.cs) which was read directly from the upstream sources; the output
shape matches the existing 75 scenario JSONs in assets/scn so StoryPlayer can
load the result without any change.

Usage:
  python3 tools/psb_to_json.py <input.ks.scn> [output.ks.json]
  python3 tools/psb_to_json.py --batch <dir> [--pattern "*.ks.scn"]

Notes:
- Only plain (unencrypted) PSB v3 scenario files are supported. Encrypted
  files must be decompiled on Windows with FreeMote's PsbDecompile.
- Resource/chunk (image) payloads are intentionally ignored: scenario JSON
  only needs the structure, and StoryPlayer never reads scenario chunks.
- Any structural error fails loudly with file + offset information.
"""

from __future__ import annotations

import argparse
import json
import mmap
import os
import struct
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# PSB object type tags (FreeMote.Psb.PsbObjType)
# ---------------------------------------------------------------------------

T_NULL = 0x01
T_FALSE = 0x02
T_TRUE = 0x03
T_NUMBER_N0 = 0x04          # .. 0x0C (NumberN0..NumberN8)
T_NUMBER_N8 = 0x0C
T_ARRAY_N1 = 0x0D           # .. 0x14 (ArrayN1..ArrayN8)
T_ARRAY_N8 = 0x14
T_STRING_N1 = 0x15          # .. 0x18
T_STRING_N4 = 0x18
T_RESOURCE_N1 = 0x19        # .. 0x1C
T_RESOURCE_N4 = 0x1C
T_FLOAT0 = 0x1D
T_FLOAT = 0x1E
T_DOUBLE = 0x1F
T_LIST = 0x20
T_OBJECTS = 0x21
T_EXTRA_CHUNK_N1 = 0x22     # .. 0x25
T_EXTRA_CHUNK_N4 = 0x25

RESOURCE_IDENTIFIER = "#resource#"
EXTRA_RESOURCE_IDENTIFIER = "#resource@"

MAX_ARRAY_WIDTH = 8


class PsbError(Exception):
    """Structural failure with a human-readable position hint."""


# ---------------------------------------------------------------------------
# Little-endian primitive arrays ("PsbArray" in FreeMote)
# ---------------------------------------------------------------------------

class Reader:
    def __init__(self, data: bytes | mmap.mmap):
        self.data = data
        self.pos = 0

    def seek(self, pos: int) -> None:
        if pos < 0 or pos > len(self.data):
            raise PsbError(f"seek out of range: {pos} (size {len(self.data)})")
        self.pos = pos

    def read(self, n: int) -> bytes:
        if n < 0 or self.pos + n > len(self.data):
            raise PsbError(f"read out of range: need {n} at {self.pos} (size {len(self.data)})")
        out = bytes(self.data[self.pos:self.pos + n])
        self.pos += n
        return out

    def u8(self) -> int:
        return self.read(1)[0]

    def u16(self) -> int:
        return struct.unpack("<H", self.read(2))[0]

    def u32(self) -> int:
        return struct.unpack("<I", self.read(4))[0]

    def uint_n(self, n: int) -> int:
        return int.from_bytes(self.read(n), "little")


def unpack_uint(raw: bytes) -> int:
    """FreeMote's UnzipUInt: little-endian read (MemoryMarshal.Read<uint>)."""
    return int.from_bytes(raw, "little")


class PsbArray:
    """count-prefixed array of fixed-width little-endian integers.

    Layout (FreeMote.Psb.PsbArray): width-byte count, then one byte for the
    entry width (`byte - NumberN8`), then count * entry-width LE values.
    Some writers (the Chinese-localization PSB tooling) encode EMPTY arrays
    with entry width 0 (`0d 00 0c`); FreeMote tolerates that by reading
    `entryLen * count == 0` bytes, so this decoder mirrors it.
    """

    def __init__(self, reader: Reader, width: int):
        if not 1 <= width <= MAX_ARRAY_WIDTH:
            raise PsbError(f"invalid array width {width}")
        self.width = width
        self.count = unpack_uint(reader.read(width))
        entry_len = reader.u8() - T_NUMBER_N8
        if not 0 <= entry_len <= MAX_ARRAY_WIDTH:
            raise PsbError(f"invalid array entry length {entry_len}")
        self.entry_length = entry_len
        if entry_len == 0:
            # Empty-array encoding: no payload bytes at all.
            self.values = [0] * self.count
            return
        blob = reader.read(entry_len * self.count)
        self.values = [
            int.from_bytes(blob[i * entry_len:(i + 1) * entry_len], "little")
            for i in range(self.count)
        ]


def array_width_from_tag(tag: int) -> int:
    return tag - T_ARRAY_N1 + 1


# ---------------------------------------------------------------------------
# PSB container
# ---------------------------------------------------------------------------

class PsbFile:
    def __init__(self, data: bytes):
        self.raw = data
        self.reader = Reader(data)
        self._parse_header()
        self._load_names()
        self._load_strings()
        self._load_chunks()
        self.reader.seek(self.offset_entries)
        self.root = self._unpack()

    # -- header ------------------------------------------------------------

    def _parse_header(self) -> None:
        r = self.reader
        if len(r.data) < 44:
            raise PsbError("file too small for a PSB header")
        signature = r.read(4)
        if signature[:3] != b"PSB":
            raise PsbError(
                f"not a plain PSB file (signature {signature!r}); "
                "encrypted files need Windows FreeMote PsbDecompile"
            )
        self.version = r.u16()
        self.header_encrypt = r.u16()
        self.header_length = r.u32()
        self.offset_names = r.u32()
        self.offset_strings = r.u32()
        self.offset_strings_data = r.u32()
        self.offset_chunk_offsets = r.u32()
        self.offset_chunk_lengths = r.u32()
        self.offset_chunk_data = r.u32()
        self.offset_entries = r.u32()
        if self.version > 2:
            self.checksum = r.u32()
        else:
            self.checksum = 0
        if self.version > 3:
            # v4 adds extra-chunk tables which scenario files do not use; the
            # offsets themselves are still read for completeness.
            self.offset_extra_chunk_offsets = r.u32()
            self.offset_extra_chunk_lengths = r.u32()
            self.offset_extra_chunk_data = r.u32()
        if self.version not in (2, 3):
            raise PsbError(f"unsupported PSB version {self.version} (need 2 or 3)")
        size = len(self.reader.data)
        for name in ("offset_names", "offset_strings", "offset_strings_data",
                     "offset_chunk_offsets", "offset_chunk_lengths",
                     "offset_chunk_data", "offset_entries"):
            value = getattr(self, name)
            if value > size:
                raise PsbError(f"header {name}={value} exceeds file size {size}")

    # -- names -------------------------------------------------------------

    def _load_names(self) -> None:
        r = self.reader
        r.seek(self.offset_names)
        charset = PsbArray(r, array_width_from_tag(r.u8()))
        names_data = PsbArray(r, array_width_from_tag(r.u8()))
        name_indexes = PsbArray(r, array_width_from_tag(r.u8()))
        self.names: list[str] = []
        for index in name_indexes.values:
            # Suffix-sharing chain (FreeMote.LoadNames): walk from the tail node
            # to the root; each node stores the delta from its parent's charset
            # entry. The loop terminator is the CURRENT node being 0 — the root
            # itself carries no character.
            blob = bytearray()
            node = names_data.values[index]
            while node != 0:
                parent = names_data.values[node]
                delta = charset.values[parent]
                blob.append((node - delta) & 0xFF)
                node = parent
            blob.reverse()
            self.names.append(blob.decode("utf-8", errors="replace"))

    # -- strings -----------------------------------------------------------

    def _load_strings(self) -> None:
        r = self.reader
        r.seek(self.offset_strings)
        self.string_offsets = PsbArray(r, array_width_from_tag(r.u8()))
        self._string_cache: dict[int, str] = {}
        self._strings_data = self.reader.data

    def string_at(self, index: int) -> str:
        if index in self._string_cache:
            return self._string_cache[index]
        if index >= len(self.string_offsets.values):
            raise PsbError(f"string index {index} out of range "
                           f"({len(self.string_offsets.values)} strings)")
        start = self.offset_strings_data + self.string_offsets.values[index]
        end = self._strings_data.find(b"\x00", start)
        if end < 0:
            raise PsbError(f"unterminated string at {start}")
        value = bytes(self._strings_data[start:end]).decode("utf-8", errors="replace")
        self._string_cache[index] = value
        return value

    # -- chunks (ignored, only their table offsets matter for skipping) -----

    def _load_chunks(self) -> None:
        r = self.reader
        r.seek(self.offset_chunk_offsets)
        self.chunk_offsets = PsbArray(r, array_width_from_tag(r.u8()))
        r.seek(self.offset_chunk_lengths)
        self.chunk_lengths = PsbArray(r, array_width_from_tag(r.u8()))

    # -- object tree -------------------------------------------------------

    def _unpack(self):
        r = self.reader
        tag = r.u8()

        if tag == 0x00 or tag == T_NULL:
            return None
        if tag == T_FALSE:
            return False
        if tag == T_TRUE:
            return True
        if T_NUMBER_N0 <= tag <= T_NUMBER_N8 or tag in (T_FLOAT0, T_FLOAT, T_DOUBLE):
            return self._read_number(tag)
        if T_ARRAY_N1 <= tag <= T_ARRAY_N8:
            return self._read_array(tag)
        if T_STRING_N1 <= tag <= T_STRING_N4:
            width = tag - T_STRING_N1 + 1
            return self.string_at(unpack_uint(r.read(width)))
        if T_RESOURCE_N1 <= tag <= T_RESOURCE_N4:
            width = tag - T_RESOURCE_N1 + 1
            index = unpack_uint(r.read(width))
            return f"{RESOURCE_IDENTIFIER}{index}"
        if T_EXTRA_CHUNK_N1 <= tag <= T_EXTRA_CHUNK_N4:
            width = tag - T_EXTRA_CHUNK_N1 + 1
            index = unpack_uint(r.read(width))
            return f"{EXTRA_RESOURCE_IDENTIFIER}{index}"
        if tag == T_LIST:
            return self._read_list()
        if tag == T_OBJECTS:
            return self._read_dictionary()
        raise PsbError(f"unknown type tag 0x{tag:02X} at offset {r.pos - 1}")

    def _read_number(self, tag: int):
        r = self.reader
        if tag == T_NUMBER_N0:
            return 0
        if tag == T_FLOAT0:
            return 0.0
        if tag == T_FLOAT:
            return struct.unpack("<f", r.read(4))[0]
        if tag == T_DOUBLE:
            return struct.unpack("<d", r.read(8))[0]
        width = tag - T_NUMBER_N0
        raw = r.read(width)
        value = int.from_bytes(raw, "little")
        # Values shorter than 8 bytes are signed (FreeMote IntValue/32-bit path).
        if width < 8 and value >= 1 << (width * 8 - 1):
            value -= 1 << (width * 8)
        return value

    def _read_array(self, tag: int) -> list:
        # ArrayN is an INLINE numeric array (FreeMote: `new PsbArray(width, br)`),
        # not an offset list — offsets belong to List/Objects containers.
        width = array_width_from_tag(tag)
        return PsbArray(self.reader, width).values

    def _read_list(self) -> list:
        # List: array-of-offsets then values at base + offset.
        width = array_width_from_tag(self.reader.u8())
        offsets = PsbArray(self.reader, width)
        base = self.reader.pos
        out = []
        for offset in offsets.values:
            self.reader.seek(base + offset)
            out.append(self._unpack())
        return out

    def _read_dictionary(self) -> dict:
        r = self.reader
        name_width = array_width_from_tag(r.u8())
        names = PsbArray(r, name_width)
        offset_width = array_width_from_tag(r.u8())
        offsets = PsbArray(r, offset_width)
        base = r.pos
        out: dict = {}
        for i, name_index in enumerate(names.values):
            if i >= len(offsets.values):
                raise PsbError(f"dictionary at {base} has {len(names.values)} names "
                               f"but {len(offsets.values)} offsets")
            name = self.names[name_index] if name_index < len(self.names) \
                else f"<bad-name-{name_index}>"
            r.seek(base + offsets.values[i])
            out[name] = self._unpack()
        return out


# ---------------------------------------------------------------------------
# CLI / batch driver
# ---------------------------------------------------------------------------

def convert_file(source: Path, target: Path) -> dict:
    data = source.read_bytes()
    if data[:4] in (b"MDF\x00", b"MFL\x00"):
        raise PsbError("MDF-compressed PSB wrappers are not supported for "
                       "scenario files (none are expected in assets/scn)")
    psb = PsbFile(data)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as handle:
        json.dump(psb.root, handle, ensure_ascii=False, indent=1, sort_keys=True)
        handle.write("\n")
    return psb.root


def main() -> int:
    parser = argparse.ArgumentParser(description="PSB v3 -> SCN JSON")
    parser.add_argument("input", help="input .ks.scn (or directory with --batch)")
    parser.add_argument("output", nargs="?", help="output .json path")
    parser.add_argument("--batch", action="store_true",
                        help="convert every *.ks.scn under the input directory")
    parser.add_argument("--pattern", default="*.ks.scn",
                        help="batch glob pattern (default: *.ks.scn)")
    parser.add_argument("--skip-existing", action="store_true",
                        help="skip files whose JSON already exists")
    args = parser.parse_args()

    if args.batch:
        root = Path(args.input)
        if not root.is_dir():
            print(f"FAIL: not a directory: {root}", file=sys.stderr)
            return 1
        sources = sorted(root.glob(args.pattern))
        ok = 0
        failures: list[tuple[str, str]] = []
        for source in sources:
            target = source.with_name(source.name[:-4] + ".json")  # .scn -> .json
            if args.skip_existing and target.exists():
                continue
            try:
                tree = convert_file(source, target)
                scenes = len(tree.get("scenes", [])) if isinstance(tree, dict) else 0
                print(f"  ok   {source.name}  scenes={scenes}")
                ok += 1
            except PsbError as error:
                failures.append((source.name, str(error)))
                print(f"  FAIL {source.name}: {error}")
        print(f"\nbatch: {ok} converted, {len(failures)} failed, "
              f"{len(sources)} total")
        return 0 if not failures else 2

    source = Path(args.input)
    target = Path(args.output) if args.output else source.with_name(source.name[:-4] + ".json")
    try:
        tree = convert_file(source, target)
    except PsbError as error:
        print(f"FAIL: {source}: {error}", file=sys.stderr)
        return 1
    scenes = tree.get("scenes", []) if isinstance(tree, dict) else []
    texts = sum(len(scene.get("texts", [])) for scene in scenes if isinstance(scene, dict))
    print(f"OK: {source.name} -> {target}  scenes={len(scenes)} texts={texts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
