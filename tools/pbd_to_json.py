#!/usr/bin/env python3
"""PBD (Yuzusoft stand metadata) -> JSON decoder, pure Python.

`<role>/<prefix>_<variant>.pbd` files under fgimage carry the authoritative
layer table for stand composition: layer name -> layer_id + left/top/width/
height. The container is Yuzusoft's own format, not PSB:

    offset  size  field
    0       4     magic  "TJS/" (LE) or "TJS\\" (BE)
    4       4     compression selector: byte0 in {0x6E, 0x34}, then "s0\\0"
    8       4     seed (u32)
    12      2     crypto mode (1..6)
    14      2     IV length
    16      n     IV (n = IV length)

Payload after the header is ChaCha20-variant encrypted, optionally LZ4-block
compressed, and holds a TJS variant binary tree.

Algorithm references (read directly from the upstream sources):
  UlyssesWu/GalgameReverse 3.Wamsoft/PbdDecoder/PbdStatic/
    PbdInformation.cs, PbdCryptoFilter.cs, PbdChacha20.cs,
    PbdBinary.cs, TJSDeserializer.cs, PbdByteChecker.cs, PbdSHA256.cs

Usage:
  python3 tools/pbd_to_json.py <file.pbd> [output.json]
  python3 tools/pbd_to_json.py --batch <dir>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants (GalgameReverse sources)
# ---------------------------------------------------------------------------

# GameInformationBase.CryptoSmallTable — the shared 16-byte table.
CRYPTO_SMALL_TABLE = bytes([
    0x9A, 0x87, 0x8F, 0x9E, 0x91, 0x9B, 0xDF, 0xCC,
    0xCD, 0xD2, 0x9D, 0x86, 0x8B, 0x9A, 0xDF, 0x94,
])

COMPRESSION_SELECTORS = (0x6E, 0x34)   # check[0] -> index = compress flag

# Crypto mode -> (rounds, block count); from PbdCryptoFilter.InitializeFilter
CRYPTO_MODES = {
    1: (8, 16),
    2: (12, 8),
    3: (20, 4),
    4: (8, 1),
    5: (12, 1),
    6: (20, 1),
}

# TJSVariantType (PbdStatic/TJS.cs)
T_EMPTY = 0x00
T_OBJECT = 0x01
T_STRING = 0x02
T_BYTES = 0x03
T_SIGN_INT64 = 0x04
T_DOUBLE = 0x05
T_ARRAY = 0x81
T_DICTIONARY = 0xC1

MASK32 = 0xFFFFFFFF


class PbdError(Exception):
    """Structural failure with a human-readable reason."""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def rol32(value: int, bits: int) -> int:
    value &= MASK32
    return ((value << bits) | (value >> (32 - bits))) & MASK32


def sha256_key(seed: int, iv: bytes) -> bytes:
    """PbdChacha20.Initialize key derivation: sha256(salt + seed(u32) + iv).

    The salt is a 32-byte buffer whose first four bytes are 20 04 01 01 and
    the rest zero; the seed is written as a u32 into a 64-byte zero buffer.
    """
    salt = bytearray(32)
    salt[0], salt[1], salt[2], salt[3] = 0x20, 0x04, 0x01, 0x01
    seed_buffer = bytearray(64)
    struct.pack_into("<I", seed_buffer, 0, seed)
    digest = hashlib.sha256()
    digest.update(bytes(salt))
    digest.update(bytes(seed_buffer))
    digest.update(iv)
    return digest.digest()


# ---------------------------------------------------------------------------
# PBD's custom 20-round hash (PbdSHA256.cs — misnamed upstream; it is a
# BLAKE2s-style construction, NOT SHA-256). The round message schedule is
# transcribed programmatically from the reference source; see
# docs/pbd_decoder.md for the extraction procedure.
# ---------------------------------------------------------------------------

PBD_MAGIC = [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
             0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]

# Rounds 3..20: (data_x, data_y, ctx_s1, ctx_s2, ctx_s3, ctx_s4)
PBD_ROUND_TABLE = {
    3: [(14, 10, 15, 0, 5, 10), (4, 8, 3, 4, 9, 14), (9, 15, 7, 8, 13, 2), (13, 6, 11, 12, 1, 6)],
    4: [(1, 12, 7, 0, 13, 10), (0, 2, 11, 4, 1, 14), (11, 7, 15, 8, 5, 2), (5, 3, 3, 12, 9, 6)],
    5: [(11, 8, 15, 0, 5, 10), (12, 0, 3, 4, 9, 14), (5, 2, 7, 8, 13, 2), (15, 13, 11, 12, 1, 6)],
    6: [(10, 14, 7, 0, 13, 10), (3, 6, 11, 4, 1, 14), (7, 1, 15, 8, 5, 2), (9, 4, 3, 12, 9, 6)],
    7: [(7, 9, 15, 0, 5, 10), (3, 1, 3, 4, 9, 14), (13, 12, 7, 8, 13, 2), (11, 14, 11, 12, 1, 6)],
    8: [(2, 6, 7, 0, 13, 10), (5, 10, 11, 4, 1, 14), (4, 0, 15, 8, 5, 2), (15, 8, 3, 12, 9, 6)],
    9: [(9, 0, 15, 0, 5, 10), (5, 7, 3, 4, 9, 14), (2, 4, 7, 8, 13, 2), (10, 15, 11, 12, 1, 6)],
    10: [(14, 1, 7, 0, 13, 10), (11, 12, 11, 4, 1, 14), (6, 8, 15, 8, 5, 2), (3, 13, 3, 12, 9, 6)],
    11: [(2, 12, 15, 0, 5, 10), (6, 10, 3, 4, 9, 14), (0, 11, 7, 8, 13, 2), (8, 3, 11, 12, 1, 6)],
    12: [(4, 13, 7, 0, 13, 10), (7, 5, 11, 4, 1, 14), (15, 14, 15, 8, 5, 2), (1, 9, 3, 12, 9, 6)],
    13: [(12, 5, 15, 0, 5, 10), (1, 15, 3, 4, 9, 14), (14, 13, 7, 8, 13, 2), (4, 10, 11, 12, 1, 6)],
    14: [(0, 7, 7, 0, 13, 10), (6, 3, 11, 4, 1, 14), (9, 2, 15, 8, 5, 2), (8, 11, 3, 12, 9, 6)],
    15: [(13, 11, 15, 0, 5, 10), (7, 14, 3, 4, 9, 14), (12, 1, 7, 8, 13, 2), (3, 9, 11, 12, 1, 6)],
    16: [(5, 0, 7, 0, 13, 10), (15, 4, 11, 4, 1, 14), (8, 6, 15, 8, 5, 2), (2, 10, 3, 12, 9, 6)],
    17: [(6, 15, 15, 0, 5, 10), (14, 9, 3, 4, 9, 14), (11, 3, 7, 8, 13, 2), (0, 8, 11, 12, 1, 6)],
    18: [(12, 2, 7, 0, 13, 10), (13, 7, 11, 4, 1, 14), (1, 4, 15, 8, 5, 2), (10, 5, 3, 12, 9, 6)],
    19: [(10, 2, 15, 0, 5, 10), (8, 4, 3, 4, 9, 14), (7, 6, 7, 8, 13, 2), (1, 5, 11, 12, 1, 6)],
    20: [(15, 11, 7, 0, 13, 10), (9, 14, 11, 4, 1, 14), (3, 12, 15, 8, 5, 2), (13, 0, 3, 12, 9, 6)],
}

PBD_STATE_XOR = [(0, 10, 0), (1, 14, 4), (2, 2, 8), (3, 6, 12),
                 (4, 5, 15), (5, 9, 3), (6, 13, 7), (7, 1, 11)]


def _pbd_round(data1: int, data2: int, s1: int, s2: int, s3: int, s4: int) -> list:
    """PbdSHA256.CalculateRound — BLAKE2s-style quarter round."""
    t0 = (data1 + s1 + s2) & MASK32
    t1 = rol32(t0 ^ s3, 16)
    t2 = (t1 + s4) & MASK32
    t3 = ((t2 ^ s1) >> 12 | (t2 ^ s1) << 20) & MASK32
    t4 = (t3 + data2 + t0) & MASK32
    t5 = ((t4 ^ t1) >> 8 | (t4 ^ t1) << 24) & MASK32
    t6 = (t5 + t2) & MASK32
    t7 = ((t3 ^ t6) >> 7 | (t3 ^ t6) << 25) & MASK32
    return [t4, t5, t6, t7]


def _pbd_transform(data: bytes, state: list, extra: list) -> list:
    """PbdSHA256.Transform: 20 rounds over one 64-byte block."""
    dw = list(struct.unpack("<16I", data))
    st = list(state)
    ctx_s = [0] * 16
    ctx_d = [0] * 16
    for i in range(4):
        ctx_d[4 * i:4 * i + 4] = _pbd_round(
            dw[2 * i], dw[2 * i + 1], st[i + 4], st[i],
            extra[i] ^ PBD_MAGIC[i + 4], PBD_MAGIC[i])
    ctx_s = list(ctx_d)
    ctx_d = [0] * 16
    for i in range(4):
        ctx_d[4 * i:4 * i + 4] = _pbd_round(
            dw[2 * i + 8], dw[2 * i + 9],
            ctx_s[(4 * (i + 1) + 3) % 16], ctx_s[(4 * i + 0) % 16],
            ctx_s[(4 * (i + 3) + 1) % 16], ctx_s[(4 * (i + 2) + 2) % 16])
    ctx_s = list(ctx_d)
    for r in range(3, 21):
        ctx_d = [0] * 16
        for slot, (x, y, a, b, c, d) in enumerate(PBD_ROUND_TABLE[r]):
            ctx_d[4 * slot:4 * slot + 4] = _pbd_round(
                dw[x], dw[y], ctx_s[a], ctx_s[b], ctx_s[c], ctx_s[d])
        ctx_s = list(ctx_d)
    out = list(st)
    for si, a, b in PBD_STATE_XOR:
        out[si] = (out[si] ^ ctx_s[a] ^ ctx_s[b]) & MASK32
    return out


def pbd_hash_key(seed: int, iv: bytes) -> bytes:
    """PbdSHA256(salt 20 04 01 01) .Update(seed64) .Update(iv) .Final(32).

    Reference control flow for the PBD key derivation (ivLen is 0 in every
    shipped file): `Update(seed64)` takes the UNALIGNED path because the
    condition `dataLength > 64 - mUnAlignDataSize` is `64 > 64` = false, so
    the seed block is only buffered; `Update(iv)` with an empty span returns
    immediately; `Final()` then runs a single `Transform` with
    extra = [calculatedSize=64, lessDataBlockTimes=0, finalFlag=~0, seed=0].
    `salt[0]` = 0x20 sets mNeedLength = 32.
    """
    salt = bytearray(32)
    salt[0], salt[1], salt[2], salt[3] = 0x20, 0x04, 0x01, 0x01
    salt_words = struct.unpack("<8I", bytes(salt))
    state = [PBD_MAGIC[i] ^ salt_words[i] for i in range(8)]

    pending = bytearray(64)
    struct.pack_into("<I", pending, 0, seed)
    pending_size = 4
    # Update(iv): appended to the pending block (iv is empty in practice; a
    # 4-byte remainder means any ivLen <= 60 simply extends the same block).
    if iv:
        take = min(len(iv), 64 - pending_size)
        pending[pending_size:pending_size + take] = iv[:take]
        pending_size += take
        if len(iv) > take:  # longer IVs would need a second transform
            raise PbdError("IV longer than 60 bytes is not supported")
    extra = [64, 0, 0xFFFFFFFF, 0]   # calculatedSize=64, lessTimes=0, final, seed=0
    state = _pbd_transform(bytes(pending), state, extra)
    return struct.pack("<8I", *state)


def generate_seed(iv: bytes, seed: int) -> int:
    """PbdChacha20.GenerateSeed for iv length < 16 (our files have ivLen=0)."""
    iv_len = len(iv)
    pos = 0
    if iv_len < 16:
        key = (seed + 0x165667B1) & MASK32
    else:
        a = seed
        b = (seed + 0x24234428) & MASK32
        c = (seed - 0x7A143589) & MASK32
        d = (seed + 0x61C8864F) & MASK32
        while pos <= iv_len - 16:
            w0, w1, w2, w3 = struct.unpack_from("<4I", iv, pos)
            b = (0x9E3779B1 * rol32((b - 0x7A143589 * w0) & MASK32, 13)) & MASK32
            c = (0x9E3779B1 * rol32((c - 0x7A143589 * w1) & MASK32, 13)) & MASK32
            a = (0x9E3779B1 * rol32((a - 0x7A143589 * w2) & MASK32, 13)) & MASK32
            d = (0x9E3779B1 * rol32((d - 0x7A143589 * w3) & MASK32, 13)) & MASK32
            pos += 16
        key = (rol32(b, 1) + rol32(c, 7) + rol32(a, 12) + rol32(d, 18)) & MASK32
    key = (key + iv_len) & MASK32
    while pos <= iv_len - 4:
        word = struct.unpack_from("<I", iv, pos)[0]
        key = (0x27D4EB2F * rol32((key - 0x3D4D51C3 * word) & MASK32, 17)) & MASK32
        pos += 4
    while pos < iv_len:
        key = (0x9E3779B1 * rol32((key + 0x165667B1 * iv[pos]) & MASK32, 11)) & MASK32
        pos += 1
    mixed = (0x85EBCA77 * (key ^ (key >> 15))) & MASK32
    key = (0xC2B2AE3D * (mixed ^ (mixed >> 13))) & MASK32
    return (key ^ (key >> 16)) & MASK32


# ---------------------------------------------------------------------------
# ChaCha20 variant (PbdChacha20)
# ---------------------------------------------------------------------------

class PbdCipher:
    """The PBD ChaCha20 variant: 4x4 state from smallTable + ~key + ~seeds,
    with the standard quarter-round schedule but input inverted and the
    transformed state added back to ~input."""

    def __init__(self, seed: int, iv: bytes, rounds: int, block_count: int):
        salt_key = pbd_hash_key(seed, iv)
        generated = generate_seed(iv, seed)
        self.rounds = rounds
        self.block_count = block_count
        self.key = 0
        self.expand_seed = 0xFFFFFFFF
        if block_count > 1:
            if generated != seed:
                self.expand_seed = generated ^ seed
            elif seed != 0:
                self.expand_seed = seed
        self.state = self._initialize_state(salt_key, generated, seed)
        # PbdChacha20.InitializeBlock sets mBlockPosition to the buffer length
        # so the keystream is generated lazily on the first Decrypt() call
        # (and can be dumped before use, as the reference probe does).
        self.block = b""
        self.block_pos = 0   # >= len(block) -> refresh on first use

    @staticmethod
    def _initialize_state(key: bytes, seed1: int, seed2: int) -> bytes:
        """PbdChacha20.InitializeState: smallTable | ~key | ~s1,~s2,~s3,~s4
        with s3 = s4 = 0 (the reference passes 0, 0 for those two)."""
        state = bytearray(64)
        state[0:16] = CRYPTO_SMALL_TABLE
        for i in range(32):
            state[16 + i] = (~key[i]) & 0xFF
        struct.pack_into("<4I", state, 48,
                         (~0) & MASK32, (~0) & MASK32,
                         (~seed1) & MASK32, (~seed2) & MASK32)
        return bytes(state)

    def _transform_block(self, state: bytes, rounds: int) -> bytes:
        """PbdChacha20.TransformState(output=block, input=ctxS).

        `state` here is ctxS (the base state with the block counter written
        into words 6-7). The final step adds `~input` back, and `input` is
        the SAME ctxS — not the unmodified base state.
        """
        inverted = bytes((~b) & 0xFF for b in state)
        z = list(struct.unpack("<16I", inverted))

        for _ in range(((rounds - 1) >> 1) + 1):
            z[0] = (z[0] + z[4]) & MASK32; z[12] = rol32(z[12] ^ z[0], 16)
            z[8] = (z[8] + z[12]) & MASK32; z[4] = rol32(z[4] ^ z[8], 12)
            z[0] = (z[0] + z[4]) & MASK32; z[12] = rol32(z[12] ^ z[0], 8)
            z[8] = (z[8] + z[12]) & MASK32; z[4] = rol32(z[4] ^ z[8], 7)

            z[1] = (z[1] + z[5]) & MASK32; z[13] = rol32(z[13] ^ z[1], 16)
            z[9] = (z[9] + z[13]) & MASK32; z[5] = rol32(z[5] ^ z[9], 12)
            z[1] = (z[1] + z[5]) & MASK32; z[13] = rol32(z[13] ^ z[1], 8)
            z[9] = (z[9] + z[13]) & MASK32; z[5] = rol32(z[5] ^ z[9], 7)

            z[2] = (z[2] + z[6]) & MASK32; z[14] = rol32(z[14] ^ z[2], 16)
            z[10] = (z[10] + z[14]) & MASK32; z[6] = rol32(z[6] ^ z[10], 12)
            z[2] = (z[2] + z[6]) & MASK32; z[14] = rol32(z[14] ^ z[2], 8)
            z[10] = (z[10] + z[14]) & MASK32; z[6] = rol32(z[6] ^ z[10], 7)

            z[3] = (z[3] + z[7]) & MASK32; z[15] = rol32(z[15] ^ z[3], 16)
            z[11] = (z[11] + z[15]) & MASK32; z[7] = rol32(z[7] ^ z[11], 12)
            z[3] = (z[3] + z[7]) & MASK32; z[15] = rol32(z[15] ^ z[3], 8)
            z[11] = (z[11] + z[15]) & MASK32; z[7] = rol32(z[7] ^ z[11], 7)

            z[0] = (z[0] + z[5]) & MASK32; z[15] = rol32(z[15] ^ z[0], 16)
            z[10] = (z[10] + z[15]) & MASK32; z[5] = rol32(z[5] ^ z[10], 12)
            z[0] = (z[0] + z[5]) & MASK32; z[15] = rol32(z[15] ^ z[0], 8)
            z[10] = (z[10] + z[15]) & MASK32; z[5] = rol32(z[5] ^ z[10], 7)

            z[1] = (z[1] + z[6]) & MASK32; z[12] = rol32(z[12] ^ z[1], 16)
            z[11] = (z[11] + z[12]) & MASK32; z[6] = rol32(z[6] ^ z[11], 12)
            z[1] = (z[1] + z[6]) & MASK32; z[12] = rol32(z[12] ^ z[1], 8)
            z[11] = (z[11] + z[12]) & MASK32; z[6] = rol32(z[6] ^ z[11], 7)

            z[2] = (z[2] + z[7]) & MASK32; z[13] = rol32(z[13] ^ z[2], 16)
            z[8] = (z[8] + z[13]) & MASK32; z[7] = rol32(z[7] ^ z[8], 12)
            z[2] = (z[2] + z[7]) & MASK32; z[13] = rol32(z[13] ^ z[2], 8)
            z[8] = (z[8] + z[13]) & MASK32; z[7] = rol32(z[7] ^ z[8], 7)

            z[3] = (z[3] + z[4]) & MASK32; z[14] = rol32(z[14] ^ z[3], 16)
            z[9] = (z[9] + z[14]) & MASK32; z[4] = rol32(z[4] ^ z[9], 12)
            z[3] = (z[3] + z[4]) & MASK32; z[14] = rol32(z[14] ^ z[3], 8)
            z[9] = (z[9] + z[14]) & MASK32; z[4] = rol32(z[4] ^ z[9], 7)

        original = list(struct.unpack("<16I", state))
        out = [(z[i] + ((~original[i]) & MASK32)) & MASK32 for i in range(16)]
        return struct.pack("<16I", *out)

    def refresh_block(self) -> None:
        """PbdChacha20.TransformBlock: one 64-byte block, expanded to
        block_count * 64 bytes via the seed-mixing recurrence."""
        state = bytearray(self.state)
        struct.pack_into("<Q", state, 48, (~self.key) & 0xFFFFFFFFFFFFFFFF)
        self.key = (self.key + 1) & 0xFFFFFFFFFFFFFFFF
        block = bytearray(self._transform_block(bytes(state), self.rounds))

        if self.block_count > 1:
            # Block extension (PbdChacha20.TransformBlock). The reference reads
            # and writes the SAME 1024-byte buffer: blockPack4[i] for i < 16 is
            # the freshly transformed keystream, and for i >= 16 it is an
            # already-extended word — so each step is self-referential. The
            # shift/xor steps rely on 32-bit wrapping, hence the masks.
            total = self.block_count * 64
            block = bytearray(block) + bytearray(total - 64)
            words = list(struct.unpack_from(f"<{total // 4}I", block))
            for i in range((self.block_count - 1) * 16):
                s = words[i]
                shifted = (s << 13) & MASK32
                s = ((((shifted ^ s) & MASK32) >> 17) ^ shifted ^ s) & MASK32
                s = (((32 * s) & MASK32) ^ s) & MASK32
                if s == 0:
                    s = self.expand_seed
                words[16 + i] = s          # write in place: later steps read it
            struct.pack_into(f"<{total // 4}I", block, 0, *words)
        self.block = bytes(block)
        self.block_pos = 0

    def decrypt(self, data: bytes) -> bytes:
        out = bytearray(len(data))
        for i in range(len(data)):
            if self.block_pos >= len(self.block):
                self.refresh_block()
            out[i] = data[i] ^ self.block[self.block_pos]
            self.block_pos += 1
        return bytes(out)


# ---------------------------------------------------------------------------
# LZ4 block decode with external dictionary (K4os LZ4Codec.Decode)
# ---------------------------------------------------------------------------

def lz4_decompress_all(data: bytes) -> bytes:
    """PbdBinary.Lz4Decompress: u16-length-prefixed LZ4 blocks.

    Each block decodes into a fixed 4096-byte buffer (K4os.LZ4Codec.Decode
    with a 1 MB rented target reports exactly the block's written length,
    4096 for every PBD block we ship). Matches may reference the previous
    block's output as a dictionary; when the offset reaches further back than
    the decoded data, K4os reads the zero-initialised target buffer, which
    the decoder below reproduces literally.
    """
    out = bytearray()
    pos = 0
    while pos < len(data):
        if pos + 2 > len(data):
            raise PbdError("truncated LZ4 block length")
        compress_length = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        block = data[pos:pos + compress_length]
        if len(block) != compress_length:
            raise PbdError("truncated LZ4 block payload")
        pos += compress_length
        decoded = lz4_block_decode(block, bytes(out))
        out += decoded
    return bytes(out)


def lz4_block_decode(src: bytes, dictionary: bytes) -> bytes:
    """One LZ4 block. `dictionary` is the previous block's output.

    The reference decodes into a 4096-byte buffer; the PBD writer never emits
    a block that expands beyond that, so we decode into a growable buffer and
    resolve back-references against (dictionary + output), falling back to
    zero bytes when a reference reaches before the dictionary start — exactly
    what K4os does with its zero-initialised rented buffer.
    """
    buffer = bytearray(dictionary)
    base = len(buffer)
    pos = 0
    n = len(src)

    while pos < n:
        token = src[pos]
        pos += 1
        literal_len = token >> 4
        if literal_len == 15:
            while True:
                extra = src[pos]
                pos += 1
                literal_len += extra
                if extra != 255:
                    break
        if literal_len:
            if pos + literal_len > n:
                raise PbdError("LZ4 literal run exceeds input")
            buffer += src[pos:pos + literal_len]
            pos += literal_len

        # A block ends after its final literal run; only continue when at
        # least the 2-byte match offset remains.
        if pos + 2 > n:
            break
        offset = src[pos] | (src[pos + 1] << 8)
        pos += 2
        if offset == 0:
            raise PbdError("LZ4 zero match offset")

        match_len = token & 0x0F
        if match_len == 15:
            while True:
                extra = src[pos]
                pos += 1
                match_len += extra
                if extra != 255:
                    break
        match_len += 4

        start = len(buffer) - offset
        for i in range(match_len):
            index = start + i
            if index >= 0:
                buffer.append(buffer[index])
            else:
                buffer.append(0)   # K4os zero-filled target fallback
    return bytes(buffer[base:])


# ---------------------------------------------------------------------------
# Container + TJS tree
# ---------------------------------------------------------------------------

class PbdFile:
    def __init__(self, data: bytes):
        self.raw = data
        self._parse_header()
        self._decrypt_and_decompress()
        # PbdByteChecker.Create: seed' = seed with byte0 ^= byte3, byte3 = 0.
        seed_bytes = bytearray(struct.pack("<I", self.seed))
        seed_bytes[0] ^= seed_bytes[3]
        seed_bytes[3] = 0
        self._checker_seed = struct.unpack("<I", bytes(seed_bytes))[0]
        self._check_flag = 1
        self.reader_pos = 0
        self.root = self._read_object()

    # -- container ---------------------------------------------------------

    def _parse_header(self) -> None:
        if len(self.raw) < 16:
            raise PbdError("file too small for a PBD header")
        magic = struct.unpack_from("<I", self.raw, 0)[0]
        if magic == 0x5C534A54:
            self.big_endian = True
        elif magic == 0x2F534A54:
            self.big_endian = False
        else:
            raise PbdError(f"not a PBD file (magic {self.raw[:4]!r})")
        check = self.raw[4:8]
        if check[1] != 0x73 or check[2] != 0x30 or check[3] != 0x00:
            raise PbdError(f"unexpected PBD check bytes {check!r}")
        self.compress_flag = 0
        for index, selector in enumerate(COMPRESSION_SELECTORS):
            if check[0] == selector:
                self.compress_flag = index
        order = ">" if self.big_endian else "<"
        self.seed = struct.unpack_from(order + "I", self.raw, 8)[0]
        self.crypto_mode = struct.unpack_from(order + "H", self.raw, 12)[0]
        iv_len = struct.unpack_from(order + "h", self.raw, 14)[0]
        if iv_len < 0 or 16 + iv_len > len(self.raw):
            raise PbdError(f"invalid IV length {iv_len}")
        self.iv = self.raw[16:16 + iv_len]
        self.header_size = 16 + iv_len
        if self.crypto_mode not in CRYPTO_MODES:
            raise PbdError(f"unsupported crypto mode {self.crypto_mode}")
        self.rounds, self.block_count = CRYPTO_MODES[self.crypto_mode]

    def _decrypt_and_decompress(self) -> None:
        payload = self.raw[self.header_size:]
        cipher = PbdCipher(self.seed, self.iv, self.rounds, self.block_count)
        plain = cipher.decrypt(payload)
        self.payload = lz4_decompress_all(plain) if self.compress_flag else plain

    # -- TJS byte checker --------------------------------------------------

    def _calculate_round(self, seed: bytearray) -> None:
        a = (seed[0] ^ ((seed[0] * 2) & 0xFF)) & 0xFF
        b = a
        b >>= 2
        b ^= seed[2]
        b >>= 3
        b ^= seed[2]
        b ^= a
        seed[0], seed[1], seed[2] = seed[1], seed[2], b

    def _final_transform(self) -> None:
        s = bytearray(struct.pack("<I", self._checker_seed))
        for _ in range(3):
            self._calculate_round(s)
        s[0], s[1], s[2] = s[2], s[1], s[0]
        self._checker_seed = struct.unpack("<I", bytes(s))[0]

    def _get_check_seed(self, type_code: int) -> int:
        if self._check_flag == 0:
            return 0
        s = bytearray(struct.pack("<I", self._checker_seed))
        if type_code == 0:
            return s[2]
        self._calculate_round(s)
        self._checker_seed = struct.unpack("<I", bytes(s))[0]
        return s[2]

    # -- TJS deserialization ----------------------------------------------

    def _read(self, count: int) -> bytes:
        end = self.reader_pos + count
        if end > len(self.payload):
            raise PbdError(f"read out of range at {self.reader_pos} (+{count})")
        chunk = self.payload[self.reader_pos:end]
        self.reader_pos = end
        return chunk

    def _read_type(self) -> int:
        type_code = self._read(1)[0]
        # Every type byte is followed by a checker byte derived from the seed.
        check_byte = self._read(1)[0]
        if self._check_flag != 0:
            expected = self._get_check_seed(type_code)
            if check_byte != expected:
                self._check_flag = -1
                raise PbdError(
                    f"TJS check byte mismatch at {self.reader_pos - 2}: "
                    f"{check_byte:#x} != {expected:#x}")
        return type_code

    def _read_int32(self) -> int:
        raw = self._read(4)
        return struct.unpack(">i" if self.big_endian else "<i", raw)[0]

    def _read_int64(self) -> int:
        raw = self._read(8)
        return struct.unpack(">q" if self.big_endian else "<q", raw)[0]

    def _read_double(self) -> float:
        raw = self._read(8)
        return struct.unpack(">d" if self.big_endian else "<d", raw)[0]

    def _read_string(self) -> str:
        length = self._read_int32()
        if length < 0 or length > 1 << 20:
            raise PbdError(f"implausible string length {length}")
        raw = self._read(length * 2)
        return raw.decode("utf-16-le" if not self.big_endian else "utf-16-be",
                          errors="replace")

    def _read_object(self):
        type_code = self._read_type()
        if type_code in (T_EMPTY, T_OBJECT):
            return self._read_object()
        if type_code == T_STRING:
            return self._read_string()
        if type_code == T_BYTES:
            length = self._read_int32()
            return {"__bytes__": self._read(length).hex()}
        if type_code == T_SIGN_INT64:
            return self._read_int64()
        if type_code == T_DOUBLE:
            return self._read_double()
        if type_code == T_ARRAY:
            count = self._read_int32()
            return [self._read_object() for _ in range(count)]
        if type_code == T_DICTIONARY:
            count = self._read_int32()
            out = {}
            for _ in range(count):
                key = self._read_string()
                out[key] = self._read_object()
            return out
        raise PbdError(f"unknown TJS type {type_code:#x} at {self.reader_pos - 2}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _normalize_numbers(value):
    """The TJS writer stores integer fields as doubles; emit them as ints so
    the JSON matches the reference decoder's output exactly."""
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, list):
        return [_normalize_numbers(item) for item in value]
    if isinstance(value, dict):
        return {key: _normalize_numbers(item) for key, item in value.items()}
    return value


def convert_file(source: Path, target: Path) -> dict:
    pbd = PbdFile(source.read_bytes())
    root = pbd.root
    if isinstance(root, list) and len(root) == 1 and isinstance(root[0], list):
        # Stand tables are a single array wrapped by the TJS root object.
        root = root[0]
    root = _normalize_numbers(root)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(root, ensure_ascii=False, indent=1) + "\n",
                      encoding="utf-8")
    return root


def main() -> int:
    parser = argparse.ArgumentParser(description="PBD -> JSON (stand layer table)")
    parser.add_argument("input")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--batch", action="store_true")
    parser.add_argument("--pattern", default="*.pbd")
    parser.add_argument("--suffix", default=".pbd.json",
                        help="output suffix in batch mode")
    args = parser.parse_args()

    if args.batch:
        root = Path(args.input)
        if not root.is_dir():
            print(f"FAIL: not a directory: {root}", file=sys.stderr)
            return 1
        ok = 0
        failures = []
        for source in sorted(root.rglob(args.pattern)):
            target = source.with_name(source.name + args.suffix)
            try:
                layers = convert_file(source, target)
                count = len(layers) if isinstance(layers, list) else 1
                print(f"  ok   {source.name}  layers={count}")
                ok += 1
            except PbdError as error:
                failures.append((source.name, str(error)))
                print(f"  FAIL {source.name}: {error}")
        print(f"\nbatch: {ok} converted, {len(failures)} failed")
        return 0 if not failures else 2

    source = Path(args.input)
    target = Path(args.output) if args.output else source.with_name(source.name + ".pbd.json")
    try:
        layers = convert_file(source, target)
    except PbdError as error:
        print(f"FAIL: {source}: {error}", file=sys.stderr)
        return 1
    count = len(layers) if isinstance(layers, list) else 1
    print(f"OK: {source.name} -> {target}  layers={count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
