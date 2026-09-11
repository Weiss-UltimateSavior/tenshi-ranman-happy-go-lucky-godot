#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Materialize PIMG layers that share another layer's pixels (`same_image`).

FreeMote's PIMG->PSD pass turns a layer that reuses another layer's image into a
layer carrying only `same_image: <other layer_id>`; the companion PNG extractor
writes one PNG for the *source* layer and none for the alias.  The compiled UI
then has a slot whose `layer_id` has no PNG on disk, so the Godot runtime draws
that button/icon with no background at all.

This script reads `assets/ui/uipsd/<screen>.pimg` (a plain PSB container), finds
every `same_image` alias, and copies the referenced PNG inside
`assets/ui/exported/<screen>/layers/`.  Idempotent: existing files are left
alone.

Usage:
  python3 tools/export_pimg_shared_images.py            # copy aliases
  python3 tools/export_pimg_shared_images.py --check     # report only (exit 1 if any alias PNG is missing)
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import psb_to_json as psb  # noqa: E402


def alias_pairs(screen: str) -> list[tuple[int, int]]:
    pimg = PROJECT / "assets" / "ui" / "uipsd" / f"{screen}.pimg"
    if not pimg.exists():
        return []
    data = pimg.read_bytes()
    if data[:3] != b"PSB":
        return []
    root = psb.PsbFile(data).root
    pairs = []
    for layer in root.get("layers", []):
        if not isinstance(layer, dict):
            continue
        source = layer.get("same_image")
        if source is None:
            continue
        pairs.append((int(layer.get("layer_id", -1)), int(source)))
    return pairs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="report missing alias PNGs without copying")
    args = ap.parse_args()

    uipsd = PROJECT / "assets" / "ui" / "uipsd"
    exported = PROJECT / "assets" / "ui" / "exported"
    copied = missing = scanned = 0
    for pimg in sorted(uipsd.glob("*.pimg")):
        screen = pimg.stem
        pairs = alias_pairs(screen)
        if not pairs:
            continue
        scanned += 1
        layer_dir = exported / screen / "layers"
        for alias_id, source_id in pairs:
            src = layer_dir / f"{source_id}.png"
            dst = layer_dir / f"{alias_id}.png"
            if dst.exists():
                continue
            if not src.exists():
                print(f"  ! {screen}: alias {alias_id} -> {source_id} but source PNG is missing")
                missing += 1
                continue
            if args.check:
                print(f"  - {screen}: {alias_id}.png missing (source {source_id}.png)")
                missing += 1
                continue
            shutil.copy2(src, dst)
            copied += 1
    verb = "would copy" if args.check else "copied"
    print(f"scanned {scanned} screens with shared images: {verb} {copied}, unresolved {missing}")
    if args.check and missing:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
