extends SceneTree

## Regression for branch-point evaluation in StoryPlayer
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 2): eval-gated nexts, error
## sentinel skipping, unconditional fallback, and the missing-json decision
## report. Run:
##   godot --headless --script res://tools/qa_story_nexts_eval.gd

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
	story.start("st04_05.ks", "*0429_branch2")
	await process_frame

	# With no flags set, both evals fail and the unconditional *0429_ano edge
	# (0429_sel.ks) wins; its json is absent on disk, so the decision is
	# reported together with the missing-json error.
	_expect(story.last_branch_decision.get("storage", "") == "0429_sel.ks"
		and story.last_branch_decision.get("target", "") == "*0429_ano",
		"empty flags fall through to unconditional *0429_ano", story.last_branch_decision)

	# acc_san: eval-gated edge wins over the fallback; the error.ks sentinel
	# after it must be skipped, and the missing 0429_sel.ks json surfaces as a
	# decision report instead of a hard stop.
	story.branch_flags.set_branch("ST04_04*0429_select", 2)
	story._select_scene("*0429_branch2")
	story.advance()
	await process_frame
	_advance_until_decision(story, "0429_sel.ks", "*0429_san")
	_expect(story.last_branch_decision.get("storage", "") == "0429_sel.ks"
		and story.last_branch_decision.get("target", "") == "*0429_san",
		"acc_san routes to 0429_sel.ks *0429_san", story.last_branch_decision)
	_expect(str(story.text_label.text).begins_with("Scenario not found: 0429_sel.ks"),
		"missing scn json reported for the branch target")

	# acc_sak beats acc_san when its value matches first in priority order.
	story.branch_flags.set_branch("ST04_04*0429_select", 1)
	story._select_scene("*0429_branch2")
	story.advance()
	await process_frame
	_advance_until_decision(story, "0429_sel.ks", "*0429_sak")
	_expect(story.last_branch_decision.get("target", "") == "*0429_sak",
		"acc_sak routes to 0429_sel.ks *0429_sak", story.last_branch_decision)

	# A value matching neither eval falls back to the unconditional edge again.
	story.branch_flags.set_branch("ST04_04*0429_select", 3)
	story._select_scene("*0429_branch2")
	story.advance()
	await process_frame
	_advance_until_decision(story, "0429_sel.ks", "*0429_ano")
	_expect(story.last_branch_decision.get("target", "") == "*0429_ano",
		"unmatched evals fall back to *0429_ano", story.last_branch_decision)

	# --- branch1: acc_aoi edge and the 不买 (skip) fallback ---
	story.branch_flags.set_branch("ST04_04*0429_select", 3)
	story._select_scene("*0429_branch1")
	story.advance()
	await process_frame
	_advance_until_decision(story, "0429_sel.ks", "*0429_aoi")
	_expect(story.last_branch_decision.get("target", "") == "*0429_aoi",
		"acc_aoi routes to 0429_sel.ks *0429_aoi", story.last_branch_decision)

	story.branch_flags.set_branch("ST04_04*0429_select", 4)
	story._select_scene("*0429_branch1")
	story.advance()
	await process_frame
	_advance_until_decision(story, "st04_05.ks", "*0429_5_part2")
	_expect(story.last_branch_decision.get("storage", "") == "st04_05.ks"
		and story.last_branch_decision.get("target", "") == "*0429_5_part2",
		"不买 (value 4) falls back to *0429_5_part2", story.last_branch_decision)

	if failures == 0:
		print("OK: qa_story_nexts_eval passed all checks")
		quit(0)
	else:
		push_error("qa_story_nexts_eval had %d failures" % failures)
		quit(1)


func _advance_until_decision(story: Node, expected_storage: String, expected_target: String) -> void:
	for i in range(300):
		var decision: Dictionary = story.last_branch_decision
		if str(decision.get("storage", "")) == expected_storage \
				and str(decision.get("target", "")) == expected_target:
			return
		if str(story.text_label.text).begins_with("End of playable scenario"):
			return
		story.advance()
		await process_frame


func _expect(condition: bool, label: String, decision: Dictionary = {}) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		push_error("  FAIL: %s decision=%s" % [label, JSON.stringify(decision)])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
