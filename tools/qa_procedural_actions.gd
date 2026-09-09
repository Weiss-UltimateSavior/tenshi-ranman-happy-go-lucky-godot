extends SceneTree

const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru01_01.ks.json"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var directives := _source_directives()
	if directives.is_empty():
		_fail("Original scenario did not contain both procedural action directives.")
		return
	var stage: Control = story.get("stage_layer")
	story.set("backlog_mode", true)
	story.call("_clear_procedural_script_actions")
	stage.position = Vector2(180, 90)
	story.call("_start_procedural_script_actions", stage, [["xpos", [directives["random"]]]])
	if int(story.get("active_action_count")) != 1:
		_fail("RandomAction was not registered as a source action.")
		return
	_step_actions(story, 0.35)
	if int(story.get("active_action_count")) != 0 or not stage.position.is_equal_approx(Vector2(180, 90)):
		_fail("RandomAction did not restore its original transform at its source duration.")
		return
	stage.position = Vector2(180, 90)
	story.call("_start_procedural_script_actions", stage, [["ypos", [directives["sin"]]]])
	_step_actions(story, 0.18)
	if int(story.get("active_action_count")) != 0 or not stage.position.is_equal_approx(Vector2(180, 90)):
		_fail("SinAction did not complete and restore its original transform.")
		return
	print("OK: original SinAction and RandomAction directives animate and restore")
	quit(0)


func _step_actions(story: Control, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var delta := minf(1.0 / 120.0, seconds - elapsed)
		story.call("_update_procedural_script_actions", delta)
		elapsed += delta


func _source_directives() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _find_directives(parsed, {})


func _find_directives(value: Variant, found: Dictionary) -> Dictionary:
	if found.has("random") and found.has("sin"):
		return found
	if value is Dictionary:
		for nested in Dictionary(value).values():
			_find_directives(nested, found)
	elif value is Array:
		var array: Array = value
		if array.size() >= 2 and typeof(array[0]) == TYPE_STRING and typeof(array[1]) == TYPE_ARRAY:
			var entries: Array = array[1]
			if not entries.is_empty() and typeof(entries[0]) == TYPE_DICTIONARY:
				var directive: Dictionary = entries[0]
				var handler := str(directive.get("handler", ""))
				var duration: Variant = directive.get("time", null)
				if handler == "RandomAction" and not found.has("random") and (typeof(duration) == TYPE_INT or typeof(duration) == TYPE_FLOAT) and float(duration) > 0.0:
					found["random"] = directive
				elif handler == "SinAction" and not found.has("sin") and (typeof(duration) == TYPE_INT or typeof(duration) == TYPE_FLOAT) and float(duration) > 0.0:
					found["sin"] = directive
		for nested in array:
			_find_directives(nested, found)
	return found


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
