extends SceneTree

## Stand composition regression (docs/plan/PLAN_P1_SCN_JSON_AND_STANDS.md §3):
## the PBD layer tables decoded by tools/pbd_to_json.py must drive
## `_make_stand_character` to a real, textured node. Before the decoder
## existed the chain returned null (no layer metadata) — this fixture fails
## loudly if that regresses.
##
## Run: godot --headless --script res://tools/qa_stand_render.gd
## The TLG parts are converted on demand into user://godot_cache, so the first
## run waits for the preload worker; subsequent runs hit the cache.

const CHARACTER := "佐奈"
const STAND_FILE := "佐奈.stand"
const PROBE_PART := "佐奈_ポーズa_3_25.png"


func _initialize() -> void:
	var story_script := load("res://scripts/story/story_player.gd")
	var story = story_script.new()
	root.add_child(story)
	await process_frame

	# Warm the character directory so the parts exist in the cache.
	story._queue_stand_directory_preload(CHARACTER, true)
	var probe := ProjectSettings.globalize_path("user://godot_cache/fgimage/" + CHARACTER + "/" + PROBE_PART)
	var ready := false
	for _i in range(60):
		await create_timer(0.4).timeout
		if FileAccess.file_exists(probe):
			ready = true
			break
	if not ready:
		_fail("TLG parts were not converted into the cache (probe: %s)" % probe)
		return

	# The PBD layer table must resolve to real parts.
	var layers: Array = story._stand_layer_pngs(CHARACTER, "佐奈_ポーズa", 3, ["制服春ポーズＡ"])
	if layers.is_empty():
		_fail("PBD layer table produced no parts for 佐奈_ポーズa variant 3")
		return
	var first: Dictionary = layers[0]
	print("  resolved part: name=%s layer_id=%d path=%s" % [
		str(first.get("name", "")), int(first.get("layer_id", -1)), str(first.get("path", ""))])

	# Full composition: the stand node must carry textured parts.
	var node = story._make_stand_character(CHARACTER, STAND_FILE, {"options": {}}, {"action": []})
	if node == null:
		_fail("_make_stand_character returned null for " + STAND_FILE)
		return
	var textured := 0
	for child in node.get_children():
		if child is TextureRect and child.texture != null:
			textured += 1
	if textured <= 0:
		_fail("stand node has no textured parts (children=%d)" % node.get_child_count())
		return
	print("OK: stand composed with %d textured parts (canvas %s)" % [textured, str(node.size)])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
