#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compose the *static* layers of a compiled UI screen into a 1280x720 preview.

This mirrors `hgl_static_screen.gd::_build_layers` (visible layers only, drawn in
reverse list order, stretched to their `rect`) but with a chosen scale basis so we
can diff "what the PSD design looks like" against a runtime screenshot and see
exactly which design elements the runtime drops or misplaces.

Usage:
  python3 tools/qa_compose_ui_preview.py scnchart [--scale=uniform|compiled]
  python3 tools/qa_compose_ui_preview.py extra_stand --all
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
SCREEN_DIR = PROJECT / "assets" / "ui" / "compiled" / "screens"
EXPORT_DIR = PROJECT / "assets" / "ui" / "exported"
OUT_DIR = PROJECT / "qa" / "screenshots"

# Paths redrawn at runtime by hgl_static_screen.gd (see _runtime_resource_layer_path
# and _hidden_static_layer_path). Kept in sync manually for the preview.
SCNCHART_RUNTIME_PREFIXES = ["chara_btn/", "btn/", "bottom_button/", "menu_button/", "scrollbar/knob/"]
SCNCHART_RUNTIME_EXACT = ["#curselected", "#scroll"]

EXTRA_STAND_HIDDEN_PREFIXES = [
    "system_menu_btn/",
    "preview/",
    "character_choice_window/",
    "choice_field/",
    "choice_of_background/",
    "choice_of_face/",
    "btn_arrow/",
    "#btn_arrow",
    # _extra_stand_multistate_layer
    "bottom_button/text/on",
    "bottom_button/text/over",
    "bottom_button/bt/on",
    "bottom_button/bt/over",
    "btn_control/",
    "character_add_btn/text/on",
    "character_add_btn/text/over",
    "character_add_btn/btn_bg/on",
    "character_add_btn/btn_bg/over",
    "order_btn/text/on",
    "order_btn/text/over",
    "order_btn/bg/on",
    "order_btn/bg/over",
    "radio_btn/text/on",
    "radio_btn/text/over-push",
    "radio_btn/bg/push",
    "radio_btn/bg/on",
    "radio_btn/bg/over",
    "btn_close/on",
    "btn_close/over",
    "btn_lock/bg/on",
    "btn_lock/bg/over",
    "btn_lock/icon/lock",
    "menu_button/icon/on",
    "menu_button/icon/off-over",
    "menu_button/bg/on",
    "menu_button/bg/over",
    "control_menu/btn_back/on",
    "control_menu/btn_back/over",
    "control_menu/btn_prev/on",
    "control_menu/btn_prev/over",
    "control_menu/btn_layer/on",
    "control_menu/btn_layer/over",
    "control_menu/radio_btn/text/on",
    "control_menu/radio_btn/text/over-push",
    "control_menu/radio_btn/bg/push",
    "control_menu/radio_btn/bg/on",
    "control_menu/radio_btn/bg/over",
    "control_menu/knob/on",
    "control_menu/knob/over",
]
EXTRA_STAND_HIDDEN_EXACT = ["bg_ex/nodrag"]


def func_template_sources(data: dict) -> set:
    """Layer source paths that belong to a `visible,false` .func template.

    Mirrors `hgl_static_screen.gd::_func_template_layer_path`: a `.func`
    declaration of `visible,false` marks a design sample the runtime clones per
    item instead of drawing (scnchart.func does this for every chart item type).
    """
    hidden_objects = {
        str(a.get("name", ""))
        for a in data.get("func", {}).get("actions", [])
        if isinstance(a, dict) and str(a.get("body", "")).strip() == "visible,false"
    }
    sources = set()
    for obj in data.get("ini", {}).get("objects", []):
        if not isinstance(obj, dict) or str(obj.get("name", "")) not in hidden_objects:
            continue
        for slot in (obj.get("slots") or {}).values():
            if isinstance(slot, dict) and slot.get("source"):
                sources.add(str(slot["source"]))
    return sources


def skip_layer(screen: str, path: str, data: dict) -> bool:
    if path in func_template_sources(data):
        return True
    if screen == "scnchart":
        if path in SCNCHART_RUNTIME_EXACT:
            return True
        return any(path.startswith(p) for p in SCNCHART_RUNTIME_PREFIXES)
    if screen == "extra_stand":
        if path in EXTRA_STAND_HIDDEN_EXACT:
            return True
        return any(path.startswith(p) for p in EXTRA_STAND_HIDDEN_PREFIXES)
    return False


def scale_for(screen: str, mode: str, data: dict) -> tuple:
    if mode == "uniform":
        # The original presents the 1920x1080 screen (config.tjs scWidth/scHeight)
        # onto 1280x720 regardless of the PSD canvas height (exHeight).
        return (1280.0 / 1920.0, 720.0 / 1080.0)
    src = data.get("source_size", {})
    dst = data.get("target_size", {})
    return (dst.get("w", 1280) / src.get("w", 1920), dst.get("h", 720) / src.get("h", 1080))


def compose(screen: str, scale_mode: str, show_all: bool) -> Image.Image:
    data = json.loads((SCREEN_DIR / f"{screen}.json").read_text(encoding="utf-8"))
    sx, sy = scale_for(screen, scale_mode, data)
    canvas = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    layer_dir = EXPORT_DIR / screen / "layers"
    layers = [l for l in data.get("layers", []) if isinstance(l, dict)]
    drawn = skipped_vis = missing_png = 0
    report = []
    for layer in reversed(layers):  # reverse: later children draw on top
        path = str(layer.get("path", ""))
        visible = bool(layer.get("visible", True))
        if not visible and not show_all:
            skipped_vis += 1
            continue
        if skip_layer(screen, path, data) and not show_all:
            report.append(("runtime", path, layer.get("rect")))
            continue
        png = layer_dir / f"{layer.get('id')}.png"
        rect = layer.get("rect", {})
        if not png.exists():
            if layer.get("id", -1) != -1:
                missing_png += 1
                report.append(("missing-png", path, rect))
            continue
        try:
            img = Image.open(png).convert("RGBA")
        except Exception as exc:  # pragma: no cover
            report.append(("error", f"{path}: {exc}", rect))
            continue
        w = max(1, int(round(float(rect.get("w", img.width)) * sx)))
        h = max(1, int(round(float(rect.get("h", img.height)) * sy)))
        if (w, h) != img.size:
            img = img.resize((w, h), Image.BILINEAR)
        x = int(round(float(rect.get("x", 0)) * sx))
        y = int(round(float(rect.get("y", 0)) * sy))
        canvas.alpha_composite(img, (x, y))
        drawn += 1
    print(f"[{screen}] scale=({sx:.4f},{sy:.4f}) drawn={drawn} hidden={skipped_vis} missing_png={missing_png}")
    for kind, path, rect in report:
        print(f"   {kind:11s} {path} {rect}")
    return canvas


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("screen")
    ap.add_argument("--scale", choices=["uniform", "compiled"], default="uniform")
    ap.add_argument("--all", action="store_true", help="include layers the runtime hides")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    canvas = compose(args.screen, args.scale, args.all)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = Path(args.out) if args.out else OUT_DIR / f"{args.screen}_expected.png"
    bg = Image.new("RGB", canvas.size, (0, 0, 0))
    bg.paste(canvas, (0, 0), canvas)
    bg.save(out)
    print("saved", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
