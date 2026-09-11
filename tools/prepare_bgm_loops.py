#!/usr/bin/env python3
"""Prepare loop-ready BGM copies from the WaveLoopManager `.sli` sidecars.

The original engine loops BGM over the sample range [To, From] (play the intro
once, then repeat the sabi segment forever). Godot's AudioStreamOggVorbis can
only express "loop from loop_offset to the end of the stream", so the tail is
cut off here: each derived file is truncated at `From`, and the runtime sets
`loop_offset = To`. The result is the exact original loop range.

The cut uses ffmpeg stream copy (`-c:a copy`), so the audio is NOT re-encoded
and stays bit-identical up to the cut point.

Outputs:
  assets/audio/bgm/<name>.ogg     loop-ready (truncated) copy
  assets/audio/bgm/loops.json     loop points per file (seconds), for QA/docs

Usage: python3 tools/prepare_bgm_loops.py [--source assets/bgm] [--out assets/audio/bgm]
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "assets/bgm"
DEFAULT_OUT = ROOT / "assets/audio/bgm"
SAMPLE_RATE = 44100.0

LINK_RE = re.compile(r"Link\s*\{([^}]*)\}")
FROM_RE = re.compile(r"From\s*=\s*(\d+)")
TO_RE = re.compile(r"To\s*=\s*(\d+)")


def read_link(sli_path: Path) -> dict | None:
    text = sli_path.read_text(encoding="utf-8", errors="replace")
    match = LINK_RE.search(text)
    if not match:
        return None
    body = match.group(1)
    frm = FROM_RE.search(body)
    to = TO_RE.search(body)
    if not frm or not to:
        return None
    return {"from_samples": int(frm.group(1)), "to_samples": int(to.group(1))}


def truncate(source: Path, target: Path, seconds: float) -> bool:
    target.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(source),
         "-t", f"{seconds:.6f}", "-c:a", "copy", str(target)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"  FAIL {source.name}: {result.stderr.strip()[:120]}", file=sys.stderr)
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args()

    source_dir = Path(args.source)
    out_dir = Path(args.out)
    if not source_dir.is_dir():
        print(f"FAIL: source dir missing: {source_dir}", file=sys.stderr)
        return 1

    manifest: dict[str, dict] = {}
    prepared = copied = failed = 0
    for ogg in sorted(source_dir.glob("*.ogg")):
        sli = ogg.with_name(ogg.name + ".sli")
        stem = ogg.stem
        target = out_dir / ogg.name
        link = read_link(sli) if sli.exists() else None
        if link is None:
            # No sidecar: the whole track loops. Copy verbatim.
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ogg, target)
            manifest[stem] = {"loop_begin": 0.0, "loop_end": None, "source": "copy"}
            copied += 1
            continue
        from_s = link["from_samples"] / SAMPLE_RATE
        to_s = link["to_samples"] / SAMPLE_RATE
        if truncate(ogg, target, from_s):
            manifest[stem] = {
                "loop_begin": round(to_s, 6),
                "loop_end": round(from_s, 6),
                "source": "sli",
            }
            prepared += 1
            print(f"  ok {stem}: loop [{to_s:.2f}s, {from_s:.2f}s]")
        else:
            failed += 1

    (out_dir / "loops.json").write_text(
        json.dumps({"format": "tenshin-bgm-loops-v1", "sample_rate": SAMPLE_RATE,
                    "tracks": manifest}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    print(f"\nprepared={prepared} copied={copied} failed={failed} "
          f"-> {out_dir} (+loops.json)")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
