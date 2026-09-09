#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
import shutil
from pathlib import Path


PROJECT = Path(r"F:\Galgame\天神乱漫 Happy GO Lucky!!_godot")
WORK = Path(r"C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl")
PIMG_JSON_DIR = WORK / "decompiled_pimg" / "uipsd"
PIMG_PNG_DIR = WORK / "pimg_png" / "uipsd"
INI_DIR = WORK / "restored" / "uipsd" / "ini"
FUNC_DIR = WORK / "restored" / "uipsd" / "func"
OUT_DIR = PROJECT / "assets" / "ui" / "compiled" / "screens"
EXPORT_DIR = PROJECT / "assets" / "ui" / "exported"

UI_RE = re.compile(r"^\s*ui\s*,\s*([^,]+?)\s*,\s*(.+?)\s*$")
FUNC_RE = re.compile(r"^\s*func\s*,\s*([^,]+)\s*,\s*(.*?)\s*$")
TARGET_SLOT_RE = re.compile(r"^@([^/:]+):(.+)$")
TARGET_PREFIXED_SLOT_RE = re.compile(r"^[#$][^@]*@([^/:]+):(.+)$")
TARGET_COPY_RE = re.compile(r"^@([^/:]+)/cp:([^,\s]+)$")
TARGET_PREFIXED_COPY_RE = re.compile(r"^[#$][^@]*@([^/:]+)/cp:([^,\s]+)$")
TARGET_AREA_RE = re.compile(r"^@([^/:]+)/area$")
TARGET_TYPED_RE = re.compile(r"^<([^>]+)>(.+)$")
MACRO_RE = re.compile(r"^(DSSLIDER|RTX|CTX|BTX|BDS|TTX|RDS)\s*,\s*(.+?)\s*$")
LOCAL_MACRO_BEGIN_RE = re.compile(r"^\s*begin\s*,\s*([^,\s]+)\s*$")
LOCAL_MACRO_END_RE = re.compile(r"^\s*end\s*,\s*([^,\s]+)\s*$")
LOCAL_MACRO_CALL_RE = re.compile(r"^\s*([^,\s]+)\s*,(.*)$")

EXTRA_INI_BY_SCREEN = {
    "option_5sound": ["option_5sound1"],
}

SCREEN_WHITELIST = {
    "window",
    "window_h",
    "backlog",
    "btncustom",
    "cgviewlist",
    "quickmenu",
    "extra",
    "extra_stand",
    "file",
    "file_data",
    "mapsel",
    "select",
    "option",
    "option_0simple",
    "option_1display",
    "option_2game1",
    "option_3game2",
    "option_4text",
    "option_5sound",
    "option_6dialog",
    "option_7mouse",
    "option_8keyboard1",
    "option_8keyboard2",
    "option_9gamepad",
    "dialog",
    "chapter",
    "gesture_help",
    "keyboard_jp109",
    "qconf_popup",
    "scnchart",
    "touchuibar",
    "voicebar",
}


def read_text(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        return data.decode("utf-16")
    if len(data) > 4 and data[:512].count(b"\x00") > len(data[:512]) // 4:
        return data.decode("utf-16le")
    for enc in ("utf-8-sig", "cp932", "utf-16", "utf-16le"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="ignore")


def ini_paths_for_screen(screen: str) -> list[Path]:
    names = [screen] + EXTRA_INI_BY_SCREEN.get(screen, [])
    return [INI_DIR / f"{name}.ini" for name in names if (INI_DIR / f"{name}.ini").exists()]


def expand_local_macros(paths: list[Path]) -> list[str]:
    macro_defs = {}
    expanded = []
    collecting_name = None
    collecting_body = []

    def flush_macro_call(name: str, args: list[str], source_line: str) -> None:
        body = macro_defs.get(name)
        if body is None:
            expanded.append(source_line)
            return
        values = {f"${{_{index + 1}}}": arg for index, arg in enumerate(args)}
        for raw_body_line in body:
            line = raw_body_line
            for key, value in values.items():
                line = line.replace(key, value)
            expanded.append(line)

    for path in paths:
        for raw in read_text(path).splitlines():
            line = raw.strip()
            if collecting_name is not None:
                end_match = LOCAL_MACRO_END_RE.match(line)
                if end_match and end_match.group(1) == collecting_name:
                    macro_defs[collecting_name] = collecting_body
                    collecting_name = None
                    collecting_body = []
                    continue
                collecting_body.append(raw.strip())
                continue

            begin_match = LOCAL_MACRO_BEGIN_RE.match(line)
            if begin_match:
                collecting_name = begin_match.group(1)
                collecting_body = []
                continue

            call_match = LOCAL_MACRO_CALL_RE.match(line)
            if call_match:
                name, args_text = call_match.groups()
                args = [arg.strip() for arg in args_text.split(",")]
                flush_macro_call(name, args, raw.strip())
                continue

            expanded.append(raw.strip())
    return expanded


def rect(layer: dict) -> dict:
    return {
        "x": layer.get("left", 0),
        "y": layer.get("top", 0),
        "w": layer.get("width", 0),
        "h": layer.get("height", 0),
    }


def load_pimg(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    groups = {}
    leaves = []
    by_id = {}
    for raw_layer in data["layers"]:
        layer = dict(raw_layer)
        layer_id = layer.get("layer_id")
        if layer.get("layer_type") == 2:
            groups[layer_id] = layer
        else:
            leaves.append(layer)
        by_id[layer_id] = layer

    def group_path(group_id):
        if group_id is None:
            return []
        group = groups.get(group_id)
        if not group:
            return []
        return group_path(group.get("group_layer_id")) + [group.get("name", "")]

    path_map = {}
    ordered_layers = []
    for layer in leaves:
        parts = group_path(layer.get("group_layer_id")) + [layer.get("name", "")]
        ui_path = "/".join(str(part) for part in parts if part != "")
        item = {
            "id": layer.get("layer_id"),
            "name": layer.get("name", ""),
            "path": ui_path,
            "rect": rect(layer),
            "visible": bool(layer.get("visible", True)),
            "opacity": layer.get("opacity", 255),
            "type": layer.get("layer_type"),
        }
        ordered_layers.append(item)
        path_map[ui_path] = item

    return {
        "width": data["width"],
        "height": data["height"],
        "layers": ordered_layers,
        "path_map": path_map,
    }


def parse_ini(screen: str, path_map: dict) -> dict:
    ini_paths = ini_paths_for_screen(screen)
    if not ini_paths:
        return {"path": None, "bindings": [], "unresolved": []}
    bindings = []
    unresolved = []
    objects = {}
    typed_controls = []
    macros = []

    def obj(name: str) -> dict:
        if name not in objects:
            objects[name] = {
                "name": name,
                "slots": {},
                "copies": [],
                "areas": [],
                "source_lines": [],
            }
        return objects[name]

    for raw in expand_local_macros(ini_paths):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        macro_match = MACRO_RE.match(line)
        if macro_match:
            macro, args = macro_match.groups()
            macros.append({
                "macro": macro,
                "args": [arg.strip() for arg in args.split(",")],
                "line": line,
            })
            continue
        match = UI_RE.match(line)
        if not match:
            continue
        source, target = [part.strip() for part in match.groups()]
        layer = path_map.get(source)
        entry = {
            "source": source,
            "target": target,
            "line": line,
        }
        if layer:
            entry["layer_id"] = layer["id"]
            entry["rect"] = layer["rect"]
            bindings.append(entry)
        else:
            unresolved.append(entry)

        copy_match = TARGET_COPY_RE.match(target) or TARGET_PREFIXED_COPY_RE.match(target)
        if copy_match:
            name, prototype = copy_match.groups()
            target_obj = obj(name)
            target_obj["prototype"] = prototype
            target_obj["rect"] = entry.get("rect")
            target_obj["source"] = source
            target_obj["source_lines"].append(line)
            obj(prototype)["copies"].append(name)
            continue

        area_match = TARGET_AREA_RE.match(target)
        if area_match:
            name = area_match.group(1)
            target_obj = obj(name)
            target_obj["areas"].append({
                "source": source,
                "rect": entry.get("rect"),
                "line": line,
            })
            target_obj["source_lines"].append(line)
            continue

        slot_match = TARGET_SLOT_RE.match(target) or TARGET_PREFIXED_SLOT_RE.match(target)
        if slot_match:
            name, slot = slot_match.groups()
            target_obj = obj(name)
            target_obj["slots"][slot] = {
                "source": source,
                "layer_id": entry.get("layer_id"),
                "rect": entry.get("rect"),
            }
            target_obj["source_lines"].append(line)
            continue

        typed_match = TARGET_TYPED_RE.match(target)
        if typed_match:
            control_type, name = [part.strip() for part in typed_match.groups()]
            record = {
                "type": control_type,
                "name": name,
                "source": source,
                "rect": entry.get("rect"),
                "line": line,
            }
            typed_controls.append(record)
            target_obj = obj(name)
            target_obj["control_type"] = control_type
            target_obj["rect"] = entry.get("rect")
            target_obj["source_lines"].append(line)
            continue
    return {
        "path": [str(path) for path in ini_paths],
        "bindings": bindings,
        "unresolved": unresolved,
        "objects": list(objects.values()),
        "typed_controls": typed_controls,
        "macros": macros,
    }


def parse_func(screen: str) -> dict:
    func_path = FUNC_DIR / f"{screen}.func"
    if not func_path.exists():
        return {"path": None, "actions": []}
    actions = []
    for raw in read_text(func_path).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = FUNC_RE.match(line)
        if not match:
            continue
        name, body = [part.strip() for part in match.groups()]
        actions.append({"name": name, "body": body, "line": line})
    return {"path": str(func_path), "actions": actions}


def copy_png_layers(screen: str) -> dict:
    src = PIMG_PNG_DIR / screen
    dst = EXPORT_DIR / screen / "layers"
    if not src.exists():
        return {"copied": 0, "src": str(src), "dst": str(dst)}
    dst.mkdir(parents=True, exist_ok=True)
    copied = 0
    for png in src.glob("*.png"):
        shutil.copy2(png, dst / png.name)
        copied += 1
    return {"copied": copied, "src": str(src), "dst": str(dst)}


def compile_screen(screen: str) -> dict:
    pimg = load_pimg(PIMG_JSON_DIR / f"{screen}.json")
    copied = copy_png_layers(screen)
    ini = parse_ini(screen, pimg["path_map"])
    func = parse_func(screen)
    compiled = {
        "screen": screen,
        "source_size": {"w": pimg["width"], "h": pimg["height"]},
        "target_size": {"w": 1280, "h": 720},
        "layer_dir": f"res://assets/ui/exported/{screen}/layers/",
        "layers": pimg["layers"],
        "ini": ini,
        "func": func,
        "asset_copy": copied,
        "stats": {
            "layers": len(pimg["layers"]),
            "bindings": len(ini["bindings"]),
            "unresolved_bindings": len(ini["unresolved"]),
            "objects": len(ini["objects"]),
            "typed_controls": len(ini["typed_controls"]),
            "macros": len(ini["macros"]),
            "actions": len(func["actions"]),
            "png_layers": copied["copied"],
        },
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"{screen}.json"
    out.write_text(json.dumps(compiled, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"screen": screen, "out": str(out), **compiled["stats"]}


def main() -> None:
    results = []
    for path in sorted(PIMG_JSON_DIR.glob("*.json")):
        if path.name.endswith(".resx.json"):
            continue
        screen = path.stem
        if screen not in SCREEN_WHITELIST:
            continue
        results.append(compile_screen(screen))
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
