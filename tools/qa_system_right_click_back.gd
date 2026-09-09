extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_system_screen(0)
	await process_frame

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = false
	main_scene._input(event)
	await process_frame

	var screen_root: Control = main_scene.get_node("ScreenRoot")
	if screen_root.has_node("SystemHitButtons"):
		push_error("Right click did not leave the system settings screen.")
		quit(1)
		return

	print("OK: right click leaves system settings screen")
	quit(0)
