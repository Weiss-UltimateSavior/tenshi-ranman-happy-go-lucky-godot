extends SceneTree

## Story trace verifier. Replays a route and compares every structural frame
## against a committed baseline. Supports multiple baselines via user args
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 6):
##   --reference=res://qa/traces/godot_opening_trace.json
##   --storage=st01_01.ks --target=*0408 --select-index=-1
## The --select-index injection mirrors qa_export_story_trace.gd so selection
## baselines replay deterministically without real clicks.

const DEFAULT_STORAGE := "st01_01.ks"
const DEFAULT_TARGET := "*0408"
const DEFAULT_REFERENCE := "res://qa/traces/godot_opening_trace.json"


func _initialize() -> void:
	var args := _user_args()
	var storage: String = args.get("storage", DEFAULT_STORAGE)
	var target: String = args.get("target", DEFAULT_TARGET)
	var reference_path: String = args.get("reference", DEFAULT_REFERENCE)
	var select_index := int(args.get("select-index", "-1"))

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(reference_path)))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Story trace reference is missing or invalid: " + reference_path)
		return
	var expected_frames: Array = Dictionary(parsed).get("frames", [])
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		_fail("Could not create StoryPlayer for trace verification")
		return
	story.set_trace_instant_mode(true)
	# Match the exporter's cache warm-up so character layers are present the
	# same way in both runs (see qa_export_story_trace.gd).
	await _warm_stand_cache(story, storage)
	story.start(storage, target)
	await process_frame
	var injected := false
	for index in range(expected_frames.size()):
		var actual: Dictionary = story.export_trace_frame()
		var expected: Dictionary = Dictionary(expected_frames[index])
		if not _same_frame(expected, actual):
			_fail("Story trace mismatch at frame %d cursor=%s difference=%s" % [index, JSON.stringify(actual.get("cursor", {})), _first_difference(_comparable_frame(expected), _comparable_frame(actual))])
			return
		if index + 1 < expected_frames.size():
			if not injected and select_index >= 0 and story.selection_pending:
				story.apply_selection(select_index)
				injected = true
			story.advance()
			await process_frame
	print("OK: ", expected_frames.size(), " story trace frames match baseline ", reference_path)
	quit(0)


func _warm_stand_cache(story: Node, storage: String) -> void:
	# Convert every `.stand` character's part directory up front so the trace
	# does not depend on cache temperature (shared logic with the exporter).
	var names: Array = []
	var json_path := "res://assets/scn/" + storage + ".json"
	if not FileAccess.file_exists(json_path):
		json_path = "res://assets/scn/" + storage.trim_suffix(".scn") + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) == TYPE_DICTIONARY:
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
	for character in names:
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
		for character in names:
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


func _same_frame(expected: Dictionary, actual: Dictionary) -> bool:
	# Playback state can differ by one audio processing frame. The resource and
	# command identities are deterministic, while AudioStreamPlayer.playing is
	# deliberately excluded from this structural trace comparison.
	return _first_difference(_comparable_frame(expected), _comparable_frame(actual)) == ""


func _comparable_frame(frame: Dictionary) -> Dictionary:
	var audio: Dictionary = Dictionary(frame.get("audio", {})).duplicate(true)
	# Wall-clock playback state is deliberately excluded: one-frame audio
	# processing differences must not fail a structural trace. Resource and
	# command identities (paths, voice names) are still compared.
	audio.erase("bgm_playing")
	audio.erase("voice_playing")
	audio.erase("active_sounds")
	var result := frame.duplicate(true)
	result.erase("sequence")
	result["audio"] = audio
	return result


func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> String:
	if (typeof(expected) == TYPE_INT or typeof(expected) == TYPE_FLOAT) and (typeof(actual) == TYPE_INT or typeof(actual) == TYPE_FLOAT):
		if is_equal_approx(float(expected), float(actual)):
			return ""
		return path + " expected=" + str(expected) + " actual=" + str(actual)
	if typeof(expected) != typeof(actual):
		return path + " type expected=" + type_string(typeof(expected)) + " actual=" + type_string(typeof(actual))
	if expected is Dictionary:
		var expected_dict: Dictionary = expected
		var actual_dict: Dictionary = actual
		var keys: Array = expected_dict.keys()
		keys.sort()
		for key in keys:
			if not actual_dict.has(key):
				return path + "." + str(key) + " missing"
			var difference := _first_difference(expected_dict[key], actual_dict[key], path + "." + str(key))
			if difference != "":
				return difference
		for key in actual_dict.keys():
			if not expected_dict.has(key):
				return path + "." + str(key) + " unexpected"
		return ""
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return path + " length expected=" + str(expected_array.size()) + " actual=" + str(actual_array.size())
		for index in range(expected_array.size()):
			var difference := _first_difference(expected_array[index], actual_array[index], path + "[" + str(index) + "]")
			if difference != "":
				return difference
		return ""
	if expected != actual:
		return path + " expected=" + str(expected) + " actual=" + str(actual)
	return ""


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


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
