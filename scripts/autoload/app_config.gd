extends Node

const DESIGN_WIDTH := 1280
const DESIGN_HEIGHT := 720

# The game root points at the project's own assets directory. The extracted
# original resources (scn JSON, restored fgimage TLG/PBD, hash manifest) all
# live inside assets/, so no absolute per-machine path is required anymore.
const GAME_ROOT := "res://assets"
const ASSETS_ROOT := "res://assets"

# Legacy helper roots from the Windows development machine. They are resolved
# through the project assets first; the original absolute roots are only
# consulted as a fallback so the toolchain keeps working on the old setup.
const CODEX_WORK_ROOT := "C:/Users/羽濑川小鸢/Documents/Codex/2026-06-20/new-chat/work/tenshin_hgl"
const RESTORED_ROOT := ASSETS_ROOT
const STRUCTURED_ROOT := ASSETS_ROOT
const HASH_MANIFEST := ASSETS_ROOT + "/hash_manifest.json"
const HASH_STATS := CODEX_WORK_ROOT + "/hash_manifest_stats.json"


func configure_window() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 540))


func design_size() -> Vector2i:
	return Vector2i(DESIGN_WIDTH, DESIGN_HEIGHT)
