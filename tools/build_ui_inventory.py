#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
from pathlib import Path


PROJECT = Path(r"F:\Galgame\天神乱漫 Happy GO Lucky!!_godot")
WORK = Path(r"C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl")
RESTORED_UIPSD = WORK / "restored" / "uipsd"
PIMG_PNG = WORK / "pimg_png" / "uipsd"
PIMG_EXTRACT = WORK / "pimg_extract"
UNKNOWN_PSB = WORK / "unknown_psb_decompile_round2"


def item(path: Path, root: Path) -> dict:
    return {
        "name": path.name,
        "relative": path.relative_to(root).as_posix(),
        "size": path.stat().st_size,
    }


def collect_files(root: Path, pattern: str) -> list[dict]:
    if not root.exists():
        return []
    return [item(path, root) for path in sorted(root.rglob(pattern)) if path.is_file()]


def main() -> None:
    inv = {
        "source_roots": {
            "restored_uipsd": str(RESTORED_UIPSD),
            "pimg_png": str(PIMG_PNG),
            "pimg_extract": str(PIMG_EXTRACT),
            "unknown_psb": str(UNKNOWN_PSB),
        },
        "pimg": collect_files(RESTORED_UIPSD, "*.pimg"),
        "ini": collect_files(RESTORED_UIPSD / "ini", "*.ini"),
        "func": collect_files(RESTORED_UIPSD / "func", "*.func"),
        "csv": collect_files(RESTORED_UIPSD, "*.csv"),
        "exported_png": collect_files(PIMG_PNG, "*.png") + collect_files(PIMG_EXTRACT, "*.png"),
        "decompiled_unknown_uipsd": [
            item(path, UNKNOWN_PSB)
            for path in sorted(UNKNOWN_PSB.glob("uipsd__*/*"))
            if path.is_file()
        ] if UNKNOWN_PSB.exists() else [],
    }

    docs = PROJECT / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "ui_asset_inventory.json").write_text(
        json.dumps(inv, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    lines = [
        "# HGL UI 资产清单",
        "",
        f"- restored uipsd: `{RESTORED_UIPSD}`",
        f"- pimg png: `{PIMG_PNG}`",
        f"- pimg extract: `{PIMG_EXTRACT}`",
        "",
        "## 数量",
        "",
        f"- PIMG: {len(inv['pimg'])}",
        f"- INI: {len(inv['ini'])}",
        f"- FUNC: {len(inv['func'])}",
        f"- CSV: {len(inv['csv'])}",
        f"- exported PNG candidates: {len(inv['exported_png'])}",
        f"- unknown uipsd decompile files: {len(inv['decompiled_unknown_uipsd'])}",
        "",
        "## 关键屏幕",
        "",
    ]
    key_names = [
        "title", "window", "backlog", "file", "option", "quickmenu",
        "cgviewlist", "extra", "scnchart", "mapsel", "select",
    ]
    all_names = {x["name"] for group in ("pimg", "ini", "func") for x in inv[group]}
    for key in key_names:
        matches = sorted(name for name in all_names if name.startswith(key))
        lines.append(f"- {key}: " + (", ".join(matches) if matches else "未找到"))
    lines.append("")

    (docs / "ui_asset_inventory.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({
        "pimg": len(inv["pimg"]),
        "ini": len(inv["ini"]),
        "func": len(inv["func"]),
        "exported_png": len(inv["exported_png"]),
        "unknown_uipsd": len(inv["decompiled_unknown_uipsd"]),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
