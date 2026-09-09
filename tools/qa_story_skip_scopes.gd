extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)
	story.set("scenario", {
		"scenes": [{
			"label": "*skip_fixture",
			"lines": [["beginskip"], 1, ["endskip"], 2],
			"texts": [_text("hidden during original beginskip"), _text("shown after original endskip")],
		}],
	})
	story.set("scene_index", 0)
	story.set("line_index", 0)
	story.set("script_skip_scope", false)
	story.call("_continue_until_text")
	var current: Dictionary = story.get("current_entry")
	if str(current.get("text", "")) != "shown after original endskip":
		_fail("beginskip did not advance through hidden source text to endskip.")
		return
	var history: Array = story.get("history_entries")
	if history.is_empty() or str(Dictionary(history.back()).get("text", "")) != "shown after original endskip":
		_fail("beginskip text was retained in the visible backlog.")
		return
	if bool(story.get("script_skip_scope")):
		_fail("endskip did not close the source skip scope.")
		return

	# Exercise the real ru_map02 skip scope as well. The source span is composed
	# of state-only records, so this validates its boundaries and completion
	# instead of assuming all numeric SCN line IDs have visible text entries.
	story.call("start", "ru_map02.ks", "*rur_map2")
	await process_frame
	var source_scene := _find_scene(Dictionary(story.get("scenario")), "*rur_map2")
	if source_scene.is_empty():
		_fail("Original ru_map02 skip-scope scene was not loaded.")
		return
	var skip_range := _find_skip_range(source_scene)
	if skip_range.x < 0 or skip_range.y <= skip_range.x:
		_fail("Original ru_map02 beginskip/endskip range could not be resolved.")
		return
	var visible_history_before := Array(story.get("history_entries")).size()
	for _index in range(96):
		story.call("advance")
		await process_frame
	if bool(story.get("script_skip_scope")):
		_fail("Original ru_map02 endskip did not close the source skip scope.")
		return
	if Array(story.get("history_entries")).size() < visible_history_before:
		_fail("Original ru_map02 skip scope corrupted visible backlog state.")
		return
	print("OK: original beginskip/endskip scopes execute correctly")
	quit(0)


func _text(value: String) -> Array:
	return [null, [[null, value]], null, null, {"data": []}]


func _find_scene(scenario: Dictionary, label: String) -> Dictionary:
	for scene_value in scenario.get("scenes", []):
		if scene_value is Dictionary and str(Dictionary(scene_value).get("label", "")) == label:
			return Dictionary(scene_value)
	return {}


func _find_skip_range(scene: Dictionary) -> Vector2i:
	var begin := -1
	var lines: Array = scene.get("lines", [])
	for index in lines.size():
		var line: Variant = lines[index]
		if typeof(line) != TYPE_ARRAY:
			continue
		var row: Array = line
		if row.is_empty() or typeof(row[0]) != TYPE_STRING:
			continue
		if str(row[0]) == "beginskip":
			begin = index
		elif str(row[0]) == "endskip" and begin >= 0:
			return Vector2i(begin, index)
	return Vector2i(-1, -1)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
