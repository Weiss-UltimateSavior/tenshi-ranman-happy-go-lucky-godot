extends SceneTree

const STORAGE := "st01_01.ks"
const TARGET := "*0408"
const REFERENCE := "res://qa/traces/godot_opening_trace.json"


func _initialize() -> void:
	var reference_path := ProjectSettings.globalize_path(REFERENCE)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Story trace reference is missing or invalid")
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
	story.start(STORAGE, TARGET)
	await process_frame
	for index in range(expected_frames.size()):
		var actual: Dictionary = story.export_trace_frame()
		var expected: Dictionary = Dictionary(expected_frames[index])
		if not _same_frame(expected, actual):
			_fail("Story trace mismatch at frame %d cursor=%s difference=%s" % [index, JSON.stringify(actual.get("cursor", {})), _first_difference(_comparable_frame(expected), _comparable_frame(actual))])
			return
		if index + 1 < expected_frames.size():
			story.advance()
			await process_frame
	print("OK: ", expected_frames.size(), " story trace frames match the opening baseline")
	quit(0)


func _same_frame(expected: Dictionary, actual: Dictionary) -> bool:
	# Playback state can differ by one audio processing frame. The resource and
	# command identities are deterministic, while AudioStreamPlayer.playing is
	# deliberately excluded from this structural trace comparison.
	return _first_difference(_comparable_frame(expected), _comparable_frame(actual)) == ""


func _comparable_frame(frame: Dictionary) -> Dictionary:
	var audio: Dictionary = Dictionary(frame.get("audio", {})).duplicate(true)
	audio.erase("bgm_playing")
	audio.erase("voice_playing")
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


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
