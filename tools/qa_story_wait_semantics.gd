extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		_fail("StoryPlayer was not created")
		return
	# Discard a real opening-route wait before isolating this synthetic tag.
	story.set_trace_instant_mode(true)
	story.set_trace_instant_mode(false)
	story._apply_line_state(["wait", "time", "80"])
	if story.wait_deadline_ms < 0:
		_fail("wait time did not block the scenario")
		return
	await create_timer(0.025).timeout
	if story.wait_deadline_ms < 0:
		_fail("wait time ended before the original delay elapsed")
		return
	await create_timer(0.10).timeout
	if story.wait_deadline_ms >= 0:
		_fail("wait time did not resume after its delay")
		return
	var motion_node := Control.new()
	story.add_child(motion_node)
	story._apply_script_motion(motion_node, [["visvalue", [{"handler": "MoveAction", "start": 0, "value": 100, "time": 80}]]], true)
	story._request_action_wait()
	if not story.waiting_for_actions:
		_fail("wact did not observe an active MoveAction")
		return
	await create_timer(0.025).timeout
	if not story.waiting_for_actions:
		_fail("wact released before the MoveAction completed")
		return
	await create_timer(0.10).timeout
	if story.active_action_count != 0 or not is_equal_approx(motion_node.modulate.a, 1.0):
		_fail("MoveAction did not complete before wact resumed the scenario")
		return
	story.set_trace_instant_mode(true)
	story._apply_line_state(["wait", "time", "1000"])
	if story._is_script_waiting():
		_fail("trace mode retained a wall-clock scenario wait")
		return
	print("OK: KAG wait timing and trace instant mode verified")
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
