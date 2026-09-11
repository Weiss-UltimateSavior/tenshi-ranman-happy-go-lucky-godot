extends RefCounted

## Gallery unlock progress for the Extra screens
## (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §3). The original marks a CG, BGM
## or scene as unlocked the first time the story presents it; the Extra screens
## then show only what the player has already seen. Stored separately from
## system settings because it is per-playthrough save data.

const GalleryLists := preload("res://scripts/story/gallery_lists.gd")
const CONFIG_PATH := "user://gallery.cfg"
const SECTIONS := ["cg", "bgm", "scene"]

var unlocked: Dictionary = {"cg": {}, "bgm": {}, "scene": {}}


func _init() -> void:
	load_progress()


func unlock(kind: String, key: String) -> bool:
	# Returns true when this call changed the state (first-time unlock).
	# Keys are case-insensitive: SCN references are lowercase (ev0102f) while the
	# authored cglist/soundlist use uppercase (EV0102A / BGM52).
	if key == "" or not unlocked.has(kind):
		return false
	var normalized := _canonical_key(kind, key.to_lower())
	var section: Dictionary = unlocked[kind]
	for existing in section.keys():
		if str(existing).to_lower() == normalized:
			return false   # already unlocked under some casing
	section[normalized] = true
	save_progress()
	return true


func is_unlocked(kind: String, key: String) -> bool:
	if not unlocked.has(kind) or key == "":
		return false
	var normalized := _canonical_key(kind, key.to_lower())
	for existing in Dictionary(unlocked[kind]).keys():
		if str(existing).to_lower() == normalized:
			return true
	return false


## Collapse CG variant names onto their authored cglist group key (ev0102f and
## EV0102A both belong to the "EV0102A" group); other kinds only need lowercasing.
func _canonical_key(kind: String, lower_key: String) -> String:
	if kind != "cg":
		return lower_key
	var group := GalleryLists.cg_group_for(lower_key)
	return group.to_lower() if group != "" else lower_key


func unlocked_keys(kind: String) -> Array:
	if not unlocked.has(kind):
		return []
	var keys: Array = Dictionary(unlocked[kind]).keys()
	keys.sort()
	return keys


func unlock_count(kind: String) -> int:
	if not unlocked.has(kind):
		return 0
	return Dictionary(unlocked[kind]).size()


func clear_all() -> void:
	for kind in SECTIONS:
		unlocked[kind] = {}
	save_progress()


func to_dict() -> Dictionary:
	return unlocked.duplicate(true)


func from_dict(data: Dictionary) -> void:
	for kind in SECTIONS:
		unlocked[kind] = {}
		var section: Variant = data.get(kind, {})
		if typeof(section) == TYPE_DICTIONARY:
			for key in Dictionary(section).keys():
				unlocked[kind][str(key)] = true


func save_progress() -> void:
	var config := ConfigFile.new()
	# Reuse the existing file's unrelated sections when present.
	config.load(CONFIG_PATH)
	for kind in SECTIONS:
		var section: Dictionary = unlocked[kind]
		for key in section.keys():
			config.set_value(kind, str(key), true)
	config.save(CONFIG_PATH)


func load_progress() -> void:
	unlocked = {"cg": {}, "bgm": {}, "scene": {}}
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for kind in SECTIONS:
		if not config.has_section(kind):
			continue
		for key in config.get_section_keys(kind):
			if bool(config.get_value(kind, str(key), false)):
				unlocked[kind][str(key)] = true
