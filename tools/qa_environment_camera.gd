extends SceneTree

const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru01_02.ks.json"
const SOURCE_SCALE := 1280.0 / 1920.0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)
	var camera_object := _first_camera_object()
	if camera_object.is_empty():
		_fail("Original ru01_02 SCN has no env camera action.")
		return
	story.call("_apply_script_object", "env", camera_object)
	var camera_layer: Control = story.get("scene_camera_layer")
	var stage: Control = story.get("stage_layer")
	var window_layer: Control = story.get("window_layer")
	if camera_layer == null or stage == null or window_layer == null:
		_fail("Story camera layers were not created.")
		return
	if stage.get_parent() != camera_layer:
		_fail("Stage is outside the camera composition.")
		return
	if window_layer.get_parent() != story:
		_fail("Message UI is incorrectly inside the camera composition.")
		return
	if not is_equal_approx(float(story.get("environment_camera_x")), -100.0):
		_fail("Original camerax action was not applied.")
		return
	if not is_equal_approx(camera_layer.position.x, 100.0 * SOURCE_SCALE):
		_fail("Camera x sign or source scale differs from the original stage transform.")
		return
	print("OK: original env camera moves scene layers and keeps message UI fixed")
	quit(0)


func _first_camera_object() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _find_camera_object(parsed)


func _find_camera_object(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if str(dictionary.get("name", "")) == "env":
			for action_value in dictionary.get("action", []):
				if action_value is Array and not Array(action_value).is_empty() and str(Array(action_value)[0]) == "camerax":
					return dictionary
		for nested in dictionary.values():
			var result := _find_camera_object(nested)
			if not result.is_empty():
				return result
	elif value is Array:
		for nested in Array(value):
			var result := _find_camera_object(nested)
			if not result.is_empty():
				return result
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
