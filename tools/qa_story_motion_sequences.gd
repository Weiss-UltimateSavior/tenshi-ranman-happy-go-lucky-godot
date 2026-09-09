extends SceneTree

const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru02_03.ks.json"
const SOURCE_SCALE := 1280.0 / 1920.0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)
	var actions := _source_exit_actions()
	if actions.is_empty():
		_fail("Could not locate the original ru02_03 multi-step character action.")
		return
	var stand := Control.new()
	stand.position = Vector2(100, 200)
	stand.modulate.a = 1.0
	story.call("_apply_script_motion", stand, actions, false, false, Vector2.ZERO)
	var expected_position := Vector2(100 + 75 * SOURCE_SCALE, 200 + 9 * SOURCE_SCALE)
	if not stand.position.is_equal_approx(expected_position):
		_fail("Sequential @+ source offsets did not resolve against the original stand position.")
		return
	if not is_zero_approx(stand.modulate.a):
		_fail("Source opacity action did not use the original 0..255 range.")
		return
	stand.free()
	print("OK: original sequential MoveAction offsets and opacity fade reach their authored endpoint")
	quit(0)


func _source_exit_actions() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
	return _find_actions(parsed)


func _find_actions(value: Variant) -> Array:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if str(dictionary.get("name", "")) == "ルリ":
			var actions: Array = dictionary.get("action", [])
			if _has_property(actions, "xpos") and _has_property(actions, "ypos") and _has_property(actions, "opacity"):
				return actions
		for nested in dictionary.values():
			var result := _find_actions(nested)
			if not result.is_empty():
				return result
	elif value is Array:
		for nested in Array(value):
			var result := _find_actions(nested)
			if not result.is_empty():
				return result
	return []


func _has_property(actions: Array, property_name: String) -> bool:
	for action in actions:
		if action is Array and Array(action).size() >= 2 and str(Array(action)[0]) == property_name and Array(action)[1] is Array:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
