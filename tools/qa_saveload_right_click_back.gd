extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame

	main_scene.show_save_load_screen("save")
	await process_frame
	await process_frame

	var screen_root: Control = main_scene.get_node("ScreenRoot")
	var save_screen = null
	for child in screen_root.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == "SaveLoadScreen":
			save_screen = child
			break
	if save_screen == null:
		push_error("SaveLoadScreen not found")
		quit(1)
		return

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = Vector2(640, 360)
	event.global_position = Vector2(640, 360)
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

	var still_present := false
	for child in screen_root.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == "SaveLoadScreen":
			still_present = true
			break
	if still_present:
		push_error("Right click did not close SaveLoadScreen")
		quit(1)
		return
	print("OK: right click on SaveLoadScreen returns to caller")
	quit(0)
