extends SceneTree

## End-to-end map-selection regression (docs/plan/PLAN_P1_SCN_JSON_AND_STANDS.md §1):
## st02_03 map choice → 佐奈 → sn_map01.ks must load and play its own text.
## Before the PSB conversion this path stopped with "Scenario not found".
## Run: godot --headless --script res://tools/qa_story_map_route.gd

const EXPECTED_STORAGE := "sn_map01.ks"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		_fail("Could not create StoryPlayer")
		return
	story.set_trace_instant_mode(true)
	story.start("st02_03.ks", "*dummyselect1")
	await process_frame

	if not story.selection_pending:
		_fail("st02_03 *dummyselect1 did not present a selection")
		return
	var option_index := -1
	for index in range(story._pending_selects.size()):
		if str(Dictionary(story._pending_selects[index]).get("name", "")) == "佐奈":
			option_index = index
	if option_index < 0:
		_fail("佐奈 option missing from the st02_03 map selection")
		return

	story.apply_selection(option_index)
	await process_frame
	var decision: Dictionary = story.last_branch_decision
	if str(decision.get("storage", "")) != EXPECTED_STORAGE:
		_fail("decision storage = %s (expected %s)" % [str(decision.get("storage", "")), EXPECTED_STORAGE])
		return
	if story._decision_load_failed:
		_fail("loading " + EXPECTED_STORAGE + " failed (scenario JSON missing?)")
		return

	# Advance a few beats: the new storage must play its own script, not an error.
	for _i in range(5):
		story.advance()
		await process_frame
	if story.storage != EXPECTED_STORAGE:
		_fail("storage drifted to " + story.storage)
		return
	var text := str(story.text_label.text)
	if text.begins_with("Scenario not found"):
		_fail("story reported a missing scenario: " + text)
		return
	if text.strip_edges() == "":
		_fail("no text displayed inside " + EXPECTED_STORAGE)
		return
	print("OK: map selection routed to %s and played \"%s\"" % [EXPECTED_STORAGE, text.substr(0, 24)])
	quit(0)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
