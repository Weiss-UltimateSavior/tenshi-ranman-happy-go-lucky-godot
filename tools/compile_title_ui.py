#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
from pathlib import Path


PROJECT = Path(r"F:\Galgame\天神乱漫 Happy GO Lucky!!_godot")
WORK = Path(r"C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl")
TITLE_JSON = WORK / "decompiled_pimg" / "uipsd" / "title.json"
TITLE_BG_JSON = WORK / "decompiled_pimg" / "data" / "image" / "sys" / "title_bg.json"
TITLE_INI = WORK / "restored" / "uipsd" / "ini" / "title.ini"
OUT = PROJECT / "assets" / "ui" / "compiled" / "title_screen.json"

UI_RE = re.compile(r"^\s*ui\s*,\s*([^,]+?)\s*,\s*@(.+?)\s*$")
BDS_RE = re.compile(r"^\s*BDS\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,\s]+)")


def read_text(path: Path) -> str:
    data = path.read_bytes()
    for enc in ("utf-8-sig", "cp932", "utf-16", "utf-16le"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="ignore")


def load_pimg(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    groups = {}
    leaves = []
    by_id = {}
    for layer in data["layers"]:
        layer = dict(layer)
        lid = layer.get("layer_id")
        if layer.get("layer_type") == 2:
            groups[lid] = layer
        else:
            leaves.append(layer)
        by_id[lid] = layer

    def group_path(group_id):
        if group_id is None:
            return []
        group = groups.get(group_id)
        if not group:
            return []
        return group_path(group.get("group_layer_id")) + [group.get("name", "")]

    path_map = {}
    for layer in leaves:
        parts = group_path(layer.get("group_layer_id")) + [layer.get("name", "")]
        ui_path = "/".join(str(p) for p in parts if p != "")
        layer["path"] = ui_path
        path_map[ui_path] = layer

    return {
        "width": data["width"],
        "height": data["height"],
        "layers": leaves,
        "path_map": path_map,
    }


def rect(layer: dict) -> dict:
    return {
        "x": layer.get("left", 0),
        "y": layer.get("top", 0),
        "w": layer.get("width", 0),
        "h": layer.get("height", 0),
    }


def parse_ini(path_map: dict) -> dict:
    prototype = {}
    buttons = {}
    bds = {}

    for raw in read_text(TITLE_INI).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        ui_match = UI_RE.match(line)
        if ui_match:
            source, target = ui_match.groups()
            source = source.strip()
            target = target.strip()
            layer = path_map.get(source)
            if not layer:
                continue
            if target.startswith("_btn:"):
                slot = target.split(":", 1)[1]
                prototype[slot] = layer
            elif "/cp:" in target:
                name, proto = target.split("/cp:", 1)
                buttons[name] = {
                    "name": name,
                    "prototype": proto,
                    "area": rect(layer),
                    "source_path": source,
                }
            continue
        bds_match = BDS_RE.match(line)
        if bds_match:
            obj, state_name, proto = [x.strip() for x in bds_match.groups()]
            bds[obj] = {
                "state_name": state_name,
                "prototype": proto,
                "overlay": {
                    "off": f"f_{state_name}",
                    "over": f"v_{state_name}",
                    "on": f"n_{state_name}",
                    "disabled": f"d_{state_name}",
                },
            }

    for name, button in buttons.items():
        rule = bds.get(name)
        if not rule:
            continue
        bg = {
            "off": prototype.get("off"),
            "over": prototype.get("over"),
            "on": prototype.get("on"),
        }
        text = {
            state: prototype.get(slot)
            for state, slot in rule["overlay"].items()
        }
        button["bg"] = {
            state: {"id": layer["layer_id"], "rect": rect(layer)}
            for state, layer in bg.items()
            if layer
        }
        button["text"] = {
            state: {"id": layer["layer_id"], "rect": rect(layer)}
            for state, layer in text.items()
            if layer
        }

    return {
        "prototype_slots": {
            slot: {"id": layer["layer_id"], "path": layer["path"], "rect": rect(layer)}
            for slot, layer in prototype.items()
        },
        "buttons": list(buttons.values()),
        "bds": bds,
    }


def compile_bg() -> list[dict]:
    bg = load_pimg(TITLE_BG_JSON)
    wanted = ["base", "waka", "aoisana", "ruri", "hime", "logo"]
    by_name = {layer["name"]: layer for layer in bg["layers"]}
    return [
        {
            "name": name,
            "id": by_name[name]["layer_id"],
            "rect": rect(by_name[name]),
        }
        for name in wanted
        if name in by_name
    ]


def main() -> None:
    title = load_pimg(TITLE_JSON)
    compiled = {
        "source_size": {"w": title["width"], "h": title["height"]},
        "target_size": {"w": 1280, "h": 720},
        "scale": 1280 / title["width"],
        "background": compile_bg(),
        "title_ui": parse_ini(title["path_map"]),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(compiled, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({
        "out": str(OUT),
        "background_layers": len(compiled["background"]),
        "buttons": len(compiled["title_ui"]["buttons"]),
        "prototype_slots": len(compiled["title_ui"]["prototype_slots"]),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
