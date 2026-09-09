extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_system_screen(0)
	await process_frame

	var screen_root: Control = main_scene.get_node("ScreenRoot")
	var hit_buttons: Control = screen_root.get_node("SystemHitButtons")
	var sound_button: Button = hit_buttons.get_child(5)
	sound_button.pressed.emit()
	await process_frame
	await process_frame

	var found_sound_page := false
	for child in screen_root.get_children():
		if child.get("screen_name") == "option_5sound":
			found_sound_page = true

	if not found_sound_page:
		push_error("System tab click did not switch to option_5sound.")
		quit(1)
		return

	print("OK: system tab click switched to option_5sound")
	quit(0)
