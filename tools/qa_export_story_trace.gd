extends SceneTree

## Story trace exporter. Defaults reproduce the opening baseline; user args
## select an alternate route (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 6):
##   --storage=st04_04.ks --target=*0429_4 --output=res://qa/traces/x.json
##   --entry-count=400 --select-index=1
## --select-index injects apply_selection() once, exactly when the story
## reaches a pending selection, so fixtures never need real clicks.

const DEFAULT_STORAGE := "st01_01.ks"
const DEFAULT_TARGET := "*0408"
const DEFAULT_ENTRY_COUNT := 32
const DEFAULT_OUTPUT := "res://qa/traces/godot_opening_trace.json"


func _initialize() -> void:
	var args := _user_args()
	var storage: String = args.get("storage", DEFAULT_STORAGE)
	var target: String = args.get("target", DEFAULT_TARGET)
	var entry_count: int = int(args.get("entry-count", str(DEFAULT_ENTRY_COUNT)))
	var output: String = args.get("output", DEFAULT_OUTPUT)
	var select_index := int(args.get("select-index", "-1"))

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		push_error("Could not create StoryPlayer for trace export")
		quit(1)
		return
	story.set_trace_instant_mode(true)
	# Stand parts are converted to PNG on demand by the preload worker. A cold
	# cache would make the first frames lack characters, so wait for the route's
	# characters to be available before recording — the baseline must not
	# depend on cache temperature.
	await _warm_stand_cache(story, storage)
	story.start(storage, target)
	await process_frame
	var frames: Array = []
	var injected := false
	for index in range(entry_count):
		var frame: Dictionary = story.export_trace_frame()
		frame["sequence"] = index
		frames.append(frame)
		if _is_terminal(frame) or _is_error_text(story):
			break
		if not injected and select_index >= 0 and story.selection_pending:
			story.apply_selection(select_index)
			injected = true
		story.advance()
		await process_frame
	var report := {
		"format": "tenshin-godot-story-trace-v1",
		"source": {"storage": storage, "target": target, "select_index": select_index},
		"frames": frames,
	}
	var output_path := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write story trace: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("OK: exported ", frames.size(), " story trace frames to ", output_path)
	if not story.last_branch_decision.is_empty():
		print("OK: last branch decision: ", JSON.stringify(story.last_branch_decision))
	quit(0)


func _is_terminal(frame: Dictionary) -> bool:
	var text := str(frame.get("entry", {}).get("text", ""))
	if text.begins_with("End of playable scenario."):
		return true
	if text.begins_with("Scenario not found"):
		return true
	return bool(frame.get("branch", {}).get("game_ended", false))


func _is_error_text(story: Node) -> bool:
	# _show_error writes the message box directly without touching
	# current_entry, so the terminal check must read the live label too.
	var text := str(story.text_label.text)
	return text.begins_with("Scenario not found") or text.begins_with("End of playable scenario.")


func _user_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.trim_prefix("--")
		var eq := body.find("=")
		if eq >= 0:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


func _warm_stand_cache(story: Node, storage: String) -> void:
	# Scan the scenario for `.stand` character names and convert their part
	# directories up front. This mirrors what a player session does lazily.
	var characters := _stand_characters(story, storage)
	if characters.is_empty():
		return
	for character in characters:
		story._queue_stand_directory_preload(str(character), true)
	# Wait until each character's converted part count covers its source TLG
	# count. The `.complete` marker alone is not enough: an earlier failed run
	# can leave a stale marker with no (or the wrong) PNGs behind it.
	var deadline := 300.0
	var elapsed := 0.0
	while elapsed < deadline:
		await create_timer(0.5).timeout
		elapsed += 0.5
		var all_ready := true
		for character in characters:
			if not _stand_cache_ready(str(character)):
				all_ready = false
				break
		if all_ready:
			break
	await create_timer(1.0).timeout


func _stand_cache_ready(character: String) -> bool:
	var source_dir := ProjectSettings.globalize_path("res://assets/fgimage/" + character)
	var cache_dir := ProjectSettings.globalize_path("user://godot_cache/fgimage/" + character)
	if not DirAccess.dir_exists_absolute(source_dir):
		return true
	var source_count := _count_files(source_dir, ".tlg")
	if source_count == 0:
		return true
	return _count_files(cache_dir, ".png") >= source_count


func _count_files(dir_path: String, suffix: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if not dir.current_is_dir() and file_name.ends_with(suffix):
			count += 1
	dir.list_dir_end()
	return count


func _stand_characters(story: Node, storage: String) -> Array:
	var names: Array = []
	var json_path := "res://assets/scn/" + storage.trim_suffix(".scn") + ".json"
	if not FileAccess.file_exists(json_path):
		json_path = "res://assets/scn/" + storage + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return names
	for scene in Dictionary(parsed).get("scenes", []):
		if typeof(scene) != TYPE_DICTIONARY:
			continue
		for entry in Dictionary(scene).get("texts", []):
			if typeof(entry) != TYPE_ARRAY or Array(entry).size() < 5:
				continue
			var state: Variant = Array(entry)[4]
			if typeof(state) != TYPE_DICTIONARY:
				continue
			for item in Dictionary(state).get("data", []):
				if typeof(item) != TYPE_ARRAY or Array(item).size() < 3:
					continue
				var object: Dictionary = Dictionary(Array(item)[2])
				var file_name := str(Dictionary(object.get("redraw", {})).get("imageFile", {}).get("file", ""))
				if not file_name.to_lower().ends_with(".stand"):
					continue
				var character := str(Array(item)[0])
				if character != "" and not names.has(character):
					names.append(character)
	return names


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
