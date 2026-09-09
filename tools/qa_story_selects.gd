extends SceneTree

## Regression for the selection data path in StoryPlayer
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 3): pending presentation, eval
## filtering, selidx ordering, flag application, and the resulting branch
## decision. Run:
##   godot --headless --script res://tools/qa_story_selects.gd

var failures := 0


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

	# --- st04_04 dialog selection (no eval gates, text options) ---
	story.start("st04_04.ks", "*dummyselect1")
	await process_frame
	_expect(story.selection_pending, "st04_04 selection pending after scene end")
	_expect(story._pending_selects.size() == 4, "st04_04 exposes 4 options")
	_expect(story._select_screen != null and is_instance_valid(story._select_screen),
		"select overlay instantiated")
	var first: Dictionary = story._pending_selects[0]
	_expect(str(first.get("text", "")) == "卯ノ花に似合いそうなアクセサリー",
		"options sorted by selidx (first is the 卯ノ花 choice)")
	_expect(int(first.get("selidx", -1)) == 0, "first option selidx 0")

	# Export while pending: v2 save keeps the open choice.
	var pending_state: Dictionary = story.export_save_state()
	_expect(int(pending_state.get("v", 0)) == 2, "save state marked v2")
	_expect(Array(pending_state.get("pending_selects", [])).size() == 4,
		"pending selection captured in save state")

	# Choosing 佐奈 applies its SetBranchFlags value and routes in-file.
	story.apply_selection(1)
	await process_frame
	_expect(not story.selection_pending, "selection resolves the pending wait")
	_expect(int(story.branch_flags.scene_values.get("ST04_04*0429_select", -1)) == 2,
		"佐奈 selection sets ST04_04*0429_select=2")
	_expect(story.selection_history.size() == 1, "selection recorded in history")
	_expect(story.last_branch_decision.get("storage", "") == "st04_04.ks"
		and story.last_branch_decision.get("target", "") == "*0429_select_buy_san",
		"佐奈 decision routes to *0429_select_buy_san (decision=%s)" % JSON.stringify(story.last_branch_decision))
	story.advance()
	await process_frame
	_expect(story.storage == "st04_04.ks", "buy_san continues in the same storage")

	# --- st07_01 map selection (eval-filtered options) ---
	story.start("st07_01.ks", "*dummyselect1")
	await process_frame
	_expect(story.selection_pending, "st07_01 map selection pending")
	var visible_without_flags: int = story._pending_selects.size()
	_expect(visible_without_flags == 3, "3 unconditional options visible before any flags, got %d" % visible_without_flags)
	var gated_names := {}
	for option_value in story._pending_selects:
		gated_names[str(Dictionary(option_value).get("name", ""))] = true
	_expect(not gated_names.has("咲夜"), "咲夜 hidden until map1/2/3+acc flags")

	# Granting 咲夜's exact map chain (tags per compiled branch_flags.json)
	# makes her option visible. The scene is still pending from the start, so
	# drop the stale overlay and replay the scene to re-run the filter.
	story.branch_flags.set_branch("ST04_04*0429_select", 1)
	story.branch_flags.set_branch("ST02_03*MAP_move_1", 1)
	story.branch_flags.set_branch("ST03_03*MAP_move_2", 1)
	story.branch_flags.set_branch("ST05_02*MAP_move_3", 1)
	story._close_select_screen()
	story.selection_pending = false
	story._select_scene("*dummyselect1")
	story.advance()
	await process_frame
	var sakuya_visible := false
	for option_value in story._pending_selects:
		if str(Dictionary(option_value).get("name", "")) == "咲夜":
			sakuya_visible = true
	_expect(sakuya_visible, "咲夜 appears when map1/2/3+acc_sak all pass")

	# Choosing 佐奈 on the map sets its flag and reports the map jump decision.
	var map_option_index := -1
	for index in range(story._pending_selects.size()):
		if str(Dictionary(story._pending_selects[index]).get("name", "")) == "佐奈":
			map_option_index = index
	_expect(map_option_index >= 0, "佐奈 map option present")
	story.apply_selection(map_option_index)
	await process_frame
	_expect(story.branch_flags.scene_values.get("ST07_01*MAP_move_4", 0) == 2,
		"佐奈 map choice sets ST07_01*MAP_move_4=2")
	_expect(story.last_branch_decision.get("storage", "") == "sn_map04.ks",
		"佐奈 map decision routes to sn_map04.ks (decision=%s)" % JSON.stringify(story.last_branch_decision))

	if failures == 0:
		print("OK: qa_story_selects passed all checks")
		quit(0)
	else:
		push_error("qa_story_selects had %d failures" % failures)
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
