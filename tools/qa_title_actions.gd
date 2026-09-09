extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.show_story_screen()
	await process_frame
	await process_frame
	var story := _first_child_with_script(main_scene, "res://scripts/story/story_player.gd")
	if story == null:
		push_error("Could not prepare story state for continue")
		quit(1)
		return
	_write_test_save(story.export_save_state())

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("continue")
	await process_frame
	await process_frame
	if _first_child_with_script(main_scene, "res://scripts/story/story_player.gd") == null:
		push_error("Continue did not load story")
		quit(1)
		return

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("load")
	await process_frame
	if _first_child_with_script(main_scene, "res://scripts/ui/save_load_screen.gd") == null:
		push_error("Load did not open SaveLoadScreen")
		quit(1)
		return

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("flowchart")
	await process_frame
	if _static_screen_named(main_scene, "scnchart") == null:
		push_error("Flowchart did not open scnchart")
		quit(1)
		return

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("extra")
	await process_frame
	if _static_screen_named(main_scene, "extra") == null:
		push_error("Extra did not open extra screen")
		quit(1)
		return

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("system")
	await process_frame
	if main_scene.get_node("ScreenRoot").get_node_or_null("SystemHitButtons") == null:
		push_error("System did not open option screen")
		quit(1)
		return

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("exit")
	await process_frame
	if main_scene._exit_confirm_dialog() == null:
		push_error("Exit did not open confirmation dialog")
		quit(1)
		return
	var dialog: Node = main_scene._exit_confirm_dialog()
	var no_button := dialog.get_node_or_null("NoButton") as Button
	if no_button == null:
		push_error("Exit confirmation cancel button was not created")
		quit(1)
		return
	# The button's signal is the same path invoked after Godot GUI hit testing;
	# invoke it directly so this title routing QA remains deterministic headless.
	no_button.pressed.emit()
	await process_frame
	await process_frame
	if main_scene._exit_confirm_dialog() != null:
		push_error("Exit confirmation cancel button did not close dialog")
		quit(1)
		return

	print("OK: all title actions route to functional screens")
	quit(0)


func _send_mouse_button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _write_test_save(state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var data := {
		"slot": 998,
		"timestamp": Time.get_datetime_string_from_system(false, true).replace("T", " "),
		"text": str(state.get("text", "")),
		"state": state,
	}
	var file := FileAccess.open("user://saves/slot_998.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))


func _first_child_with_script(main_scene: Node, script_path: String) -> Node:
	var script := load(script_path)
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _static_screen_named(main_scene: Node, screen_name: String) -> Node:
	var static_script := load("res://scripts/ui/hgl_static_screen.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == static_script and str(child.screen_name) == screen_name:
			return child
	return null
