extends SceneTree

## Regression for save-state v2 branch fields
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 5): flags, selection history, and
## a pending selection must survive export/import. Run:
##   godot --headless --script res://tools/qa_saveload_branch.gd

var failures := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame

	# --- Story A: choose 佐奈, play two beats, export ---
	main_scene.show_story_screen()
	await process_frame
	var story_a := _find_story(main_scene)
	if story_a == null:
		_fail("Could not create StoryPlayer A")
		return
	story_a.set_trace_instant_mode(true)
	story_a.start("st04_04.ks", "*dummyselect1")
	await process_frame
	story_a.apply_selection(1)
	await process_frame
	story_a.advance()
	await process_frame
	story_a.advance()
	await process_frame
	var state: Dictionary = story_a.export_save_state()
	_expect(int(state.get("v", 0)) == 2, "save state marked v2")
	_expect(int(Dictionary(state.get("branch_flags", {})).get("ST04_04*0429_select", -1)) == 2,
		"branch flags captured in save state")
	_expect(Array(state.get("selection_history", [])).size() == 1, "selection history captured")
	_expect(Array(state.get("pending_selects", [])).is_empty(), "no pending selection after choosing")
	var saved_text := str(state.get("text", ""))

	# --- Story B: import and verify the restored branch state ---
	main_scene.show_story_screen()
	await process_frame
	var story_b := _find_story(main_scene)
	if story_b == null:
		_fail("Could not create StoryPlayer B")
		return
	story_b.set_trace_instant_mode(true)
	story_b.import_save_state(state)
	await process_frame
	_expect(int(story_b.branch_flags.scene_values.get("ST04_04*0429_select", -1)) == 2,
		"branch flags restored")
	_expect(story_b.selection_history.size() == 1, "selection history restored")
	_expect(story_b.storage == "st04_04.ks", "storage restored")
	_expect(story_b.last_branch_decision.get("target", "") == str(Dictionary(state.get("last_branch_decision", {})).get("target", "")),
		"branch decision round-trips through the save")
	_expect(str(story_b.text_label.text) == saved_text, "displayed text restored")
	_expect(not story_b.selection_pending, "no stale selection pending after import")

	# --- Pending-selection save: the open choice must survive too ---
	main_scene.show_story_screen()
	await process_frame
	var story_c := _find_story(main_scene)
	story_c.set_trace_instant_mode(true)
	story_c.start("st04_04.ks", "*dummyselect1")
	await process_frame
	var pending_state: Dictionary = story_c.export_save_state()
	_expect(Array(pending_state.get("pending_selects", [])).size() == 4,
		"open choice captured in pending_selects")

	main_scene.show_story_screen()
	await process_frame
	var story_d := _find_story(main_scene)
	story_d.set_trace_instant_mode(true)
	story_d.import_save_state(pending_state)
	await process_frame
	_expect(story_d.selection_pending, "pending selection restored as pending")
	_expect(story_d._pending_selects.size() == 4, "restored pending options")
	_expect(story_d._select_screen != null and is_instance_valid(story_d._select_screen),
		"select overlay rebuilt after import")
	story_d.apply_selection(1)
	await process_frame
	_expect(int(story_d.branch_flags.scene_values.get("ST04_04*0429_select", -1)) == 2,
		"restored pending selection can be resolved")

	if failures == 0:
		print("OK: qa_saveload_branch passed all checks")
		quit(0)
	else:
		push_error("qa_saveload_branch had %d failures" % failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		push_error("  FAIL: " + label)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
