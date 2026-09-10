#!/usr/bin/env python3
"""Structural integrity check for assets/scn/*.json scenario files.

Guards the P1 conversion output (tools/psb_to_json.py): every scenario must
carry the keys StoryPlayer relies on, scenes must be well-formed, and every
cross-storage `nexts` target must either exist as JSON or be a known
outstanding file. Empty optional collections (texts/nexts) are legal and
match the original converter output.

Usage: python3 tools/qa_scn_json_integrity.py [--scn-dir assets/scn]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Encrypted scenarios pending a Windows FreeMote pass, plus the KAG system
# script that legitimately has no .ks.json (StoryPlayer special-cases gameend).
ALLOWED_MISSING_TARGETS = {"0429_sel.ks", "0604_sel.ks", "start.ks", "error.ks"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scn-dir", default="assets/scn")
    args = parser.parse_args()

    root = Path(args.scn_dir)
    files = sorted(root.glob("*.json"))
    if not files:
        print("FAIL: no scenario JSON found in", root, file=sys.stderr)
        return 1

    names = {f.name[:-5] for f in files}  # strip ".json"
    failures: list[str] = []
    scene_total = 0
    select_files = 0
    branch_scenes = 0

    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as error:  # noqa: BLE001 - report and continue
            failures.append(f"{path.name}: invalid JSON ({error})")
            continue
        if not isinstance(data, dict):
            failures.append(f"{path.name}: top level is not an object")
            continue
        for key in ("hash", "name", "outlines", "scenes"):
            if key not in data:
                failures.append(f"{path.name}: missing top-level key {key!r}")
        scenes = data.get("scenes")
        if not isinstance(scenes, list) or not scenes:
            failures.append(f"{path.name}: scenes must be a non-empty list")
            continue
        if '"selects"' in path.read_text(encoding="utf-8"):
            select_files += 1
        for index, scene in enumerate(scenes):
            scene_total += 1
            if not isinstance(scene, dict):
                failures.append(f"{path.name} scene {index}: not an object")
                continue
            for key in ("label", "lines"):
                if key not in scene:
                    failures.append(f"{path.name} scene {index}: missing {key!r}")
            if not isinstance(scene.get("lines"), list):
                failures.append(f"{path.name} scene {index}: lines is not a list")
            if scene.get("selects") is not None:
                branch_scenes += 1
                if not isinstance(scene["selects"], list):
                    failures.append(f"{path.name} scene {index}: selects not a list")
                else:
                    for option in scene["selects"]:
                        if not isinstance(option, dict) or "exp" not in option \
                                or "selidx" not in option or "storage" not in option:
                            failures.append(
                                f"{path.name} scene {index}: select entry missing "
                                "exp/selidx/storage")
            for edge in scene.get("nexts", []) or []:
                if not isinstance(edge, dict):
                    continue
                target = str(edge.get("storage", "")).lower()
                if not target.endswith(".ks"):
                    continue
                if target not in names and target not in ALLOWED_MISSING_TARGETS:
                    failures.append(
                        f"{path.name} scene {index}: nexts target {target!r} has no JSON")

    print(f"scanned {len(files)} scenario JSON, {scene_total} scenes")
    print(f"  files with selects: {select_files}, select scenes: {branch_scenes}")
    if failures:
        print(f"\nFAIL: {len(failures)} integrity problems", file=sys.stderr)
        for line in failures[:40]:
            print("  " + line, file=sys.stderr)
        return 1
    print("OK: all scenario JSON structurally valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
