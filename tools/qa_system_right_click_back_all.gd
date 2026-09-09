extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame

	var page_names := [
		"option_0simple", "option_1display", "option_2game1", "option_3game2",
		"option_4text", "option_5sound", "option_6dialog", "option_7mouse",
		"option_8keyboard1", "option_8keyboard2", "option_9gamepad",
	]
	var failed_pages := []
	for page_index in range(page_names.size()):
		main_scene.show_system_screen(page_index)
		await process_frame
		await process_frame
		await process_frame

		# Inject a real mouse right-click event via the Viewport input pump.
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

		var screen_root: Control = main_scene.get_node("ScreenRoot")
		if screen_root.has_node("SystemHitButtons"):
			failed_pages.append(page_names[page_index])
			print("FAIL: page %d (%s) did not respond to real right click" % [page_index, page_names[page_index]])
		else:
			print("OK: page %d (%s) responds to real right click" % [page_index, page_names[page_index]])

	if not failed_pages.is_empty():
		push_error("Pages failed: %s" % str(failed_pages))
		quit(1)
		return
	print("ALL OK: real right click returns to title on all system pages")
	quit(0)
