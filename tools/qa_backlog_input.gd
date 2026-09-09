extends SceneTree

func _initialize() -> void:
	var story_script: Script = load("res://scripts/story/story_player.gd")
	var backlog_script: Script = load("res://scripts/ui/hgl_static_screen.gd")
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await process_frame
	var story := _find_script_node(main_scene.get_node("ScreenRoot"), story_script)
	if story == null:
		_fail("StoryPlayer was not created")
		return
	story.set_trace_instant_mode(true)
	story.start("st01_01.ks", "*0408")
	for _index in range(14):
		story.advance()
		await process_frame
	if story.history_entries.size() < 6:
		_fail("Expected enough history entries")
		return

	# Mouse-wheel-up from the story canvas opens the modal Backlog without
	# changing the script cursor. A second wheel event while it is open is
	# consumed by the modal and must not create another overlay.
	var story_scene_before := int(story.scene_index)
	var story_line_before := int(story.line_index)
	_send_story_mouse_button(story, Vector2(800, 320), MOUSE_BUTTON_WHEEL_UP, true)
	await process_frame
	await process_frame
	var screen_root: Node = main_scene.get_node("ScreenRoot")
	var opened_from_story := _find_script_node(screen_root, backlog_script)
	if opened_from_story == null:
		_fail("Story mouse-wheel-up did not open Backlog")
		return
	if int(story.scene_index) != story_scene_before or int(story.line_index) != story_line_before:
		_fail("Story advanced while opening Backlog from mouse wheel")
		return
	_send_story_mouse_button(story, Vector2(800, 320), MOUSE_BUTTON_WHEEL_UP, true)
	await process_frame
	if _find_script_node(screen_root, backlog_script) != opened_from_story:
		_fail("Mouse wheel created a duplicate Backlog overlay")
		return
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_RIGHT, true)
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_RIGHT, false)
	await process_frame
	await process_frame
	if _find_script_node(screen_root, backlog_script) != null:
		_fail("Right-click did not close mouse-wheel Backlog")
		return

	main_scene.show_backlog_screen()
	await process_frame
	await process_frame
	var backlog := _find_script_node(screen_root, backlog_script)
	if backlog == null:
		_fail("Backlog screen was not created")
		return
	var runtime: Control = backlog.backlog_runtime_layer
	if runtime == null:
		_fail("Backlog runtime layer was not created")
		return

	# The full-screen overlay must stop an ordinary story click.
	var scene_before := int(story.scene_index)
	var line_before := int(story.line_index)
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_LEFT, true)
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_LEFT, false)
	await process_frame
	if int(story.scene_index) != scene_before or int(story.line_index) != line_before:
		_fail("Story advanced through the Backlog overlay")
		return

	# Wheel input changes the visible history window.
	var start_before := int(backlog.backlog_start)
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_WHEEL_UP, true)
	await process_frame
	await process_frame
	if int(backlog.backlog_start) >= start_before:
		_fail("Mouse wheel did not scroll Backlog")
		return

	# A real pointer motion must select the hover artwork for the return button.
	var back_button: Button = runtime.find_child("backlog_bottom_back", true, false) as Button
	if back_button == null:
		_fail("Backlog return button was not created")
		return
	var back_position := back_button.global_position + back_button.size * 0.5
	# Headless DisplayServer applies desktop DPI coordinates to warp_mouse().
	# Exercise the same Backlog hit-test in the authored source coordinate
	# system, keeping this regression test independent of a real desktop.
	await process_frame
	backlog._update_backlog_hover(back_position / backlog.ui_scale())
	var back_normal: CanvasItem = back_button.get_node("background_normal")
	var back_hover: CanvasItem = back_button.get_node("background_hover")
	if back_normal.visible or not back_hover.visible:
		print("hover state: normal=", back_normal.visible, " hover=", back_hover.visible, " mouse=", root.get_viewport().get_mouse_position())
		_fail("Backlog return button did not enter hover state")
		return

	# Leave this screen with the actual button click, then verify right-click
	# return on a newly opened screen as well.
	_backlog_click(backlog, back_button.global_position + back_button.size * 0.5)
	await process_frame
	await process_frame
	if _find_script_node(main_scene.get_node("ScreenRoot"), backlog_script) != null:
		_fail("Return-to-game button did not close Backlog")
		return

	main_scene.show_backlog_screen()
	await process_frame
	await process_frame
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_RIGHT, true)
	_send_mouse_button(Vector2(800, 320), MOUSE_BUTTON_RIGHT, false)
	await process_frame
	await process_frame
	if _find_script_node(main_scene.get_node("ScreenRoot"), backlog_script) != null:
		_fail("Right-click did not close Backlog")
		return

	# Exercise the scrollbar track and its drag path on a fresh screen.
	main_scene.show_backlog_screen()
	await process_frame
	await process_frame
	backlog = _find_script_node(main_scene.get_node("ScreenRoot"), backlog_script)
	runtime = backlog.backlog_runtime_layer
	var track_start := int(backlog.backlog_start)
	_backlog_drag(backlog, Vector2(1110, 300), Vector2(1110, 470))
	await process_frame
	if int(backlog.backlog_start) == track_start:
		_fail("Scrollbar track/drag did not change position")
		return

	# Jump through the actual row action button and check both cursor and text.
	var animated_before := float(backlog.backlog_visual_start)
	backlog._handle_backlog_scroll("top")
	backlog._process(0.05)
	if absf(float(backlog.backlog_visual_start) - float(backlog.backlog_scroll_target)) >= absf(animated_before - float(backlog.backlog_scroll_target)):
		_fail("Backlog scroll did not move smoothly toward its target")
		return
	backlog.backlog_visual_start = backlog.backlog_scroll_target
	backlog.backlog_draw_start = 0
	backlog._redraw_backlog_entries_only()
	runtime = backlog.backlog_runtime_layer
	var first_entry: Dictionary = Dictionary(story.history_entries[0])
	var jump_button := runtime.find_child("backlog_action_0_323", true, false) as Button
	if jump_button == null:
		# Redraw is deferred after the top operation.
		await process_frame
		runtime = backlog.backlog_runtime_layer
		jump_button = runtime.find_child("backlog_action_0_323", true, false) as Button
	if jump_button == null:
		_fail("History jump button was not created")
		return
	var jump_position := jump_button.global_position + jump_button.size * 0.5
	await process_frame
	backlog._update_backlog_hover(jump_position / backlog.ui_scale())
	var jump_normal: CanvasItem = jump_button.get_node("background_normal")
	var jump_hover: CanvasItem = jump_button.get_node("background_hover")
	if jump_normal.visible or not jump_hover.visible:
		_fail("History jump button did not enter hover state")
		return
	_backlog_click(backlog, jump_button.global_position + jump_button.size * 0.5)
	await process_frame
	await process_frame
	if _find_script_node(main_scene.get_node("ScreenRoot"), backlog_script) != null:
		_fail("History jump did not close Backlog")
		return
	var text_label: Label = story.text_label
	if story.history_entries.size() != 1 or text_label == null or text_label.text != str(first_entry.get("text", "")):
		_fail("History jump restored the wrong progress/text")
		return

	# Reopening Backlog must show only the selected history prefix; future rows
	# from the old timeline must not return.
	main_scene.show_backlog_screen()
	await process_frame
	await process_frame
	var reopened_backlog := _find_script_node(main_scene.get_node("ScreenRoot"), backlog_script)
	if reopened_backlog == null or reopened_backlog.backlog_entries.size() != 1:
		_fail("Backlog retained future entries after history jump")
		return

	print("OK: Backlog modal input, hover, wheel, scrollbar drag, return and jump verified")
	quit(0)


func _backlog_click(backlog: Node, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		backlog._handle_backlog_pointer_input(event)


func _backlog_drag(backlog: Node, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = from
	press.global_position = from
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	backlog._handle_backlog_pointer_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	backlog._handle_backlog_pointer_input(motion)
	var release := InputEventMouseButton.new()
	release.position = to
	release.global_position = to
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	backlog._handle_backlog_pointer_input(release)


func _send_mouse_button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_story_mouse_button(story: Control, position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	story._gui_input(event)


func _send_mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _find_script_node(parent: Node, script_resource: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script_resource:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
