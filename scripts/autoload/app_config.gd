extends Node

const DESIGN_WIDTH := 1280
const DESIGN_HEIGHT := 720
const GAME_ROOT := "E:/Galgame/天神乱漫 Happy GO Lucky!!"
const CODEX_WORK_ROOT := "C:/Users/羽濑川小鸢/Documents/Codex/2026-06-20/new-chat/work/tenshin_hgl"
const RESTORED_ROOT := CODEX_WORK_ROOT + "/restored"
const STRUCTURED_ROOT := "F:/Galgame/天神乱漫 Happy GO Lucky!!/XP3_Extracted_Restored_Structured_Clean_v3"
const HASH_MANIFEST := CODEX_WORK_ROOT + "/hash_manifest.json"
const HASH_STATS := CODEX_WORK_ROOT + "/hash_manifest_stats.json"


func configure_window() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 540))


func design_size() -> Vector2i:
	return Vector2i(DESIGN_WIDTH, DESIGN_HEIGHT)
