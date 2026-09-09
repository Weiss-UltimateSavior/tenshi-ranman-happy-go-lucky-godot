extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_system_screen(0)
	await process_frame

	var screen_root: Control = main_scene.get_node("ScreenRoot")
	var hit_buttons: Control = screen_root.get_node("SystemHitButtons")
	var help_layer: Control = screen_root.get_node("SystemHelpLayer")
	if help_layer.visible:
		push_error("System help layer should be hidden by default.")
		quit(1)
		return

	var simple_button: Button = hit_buttons.get_child(0)
	simple_button.mouse_entered.emit()
	await process_frame
	if not help_layer.visible:
		push_error("System help layer did not show on hover.")
		quit(1)
		return
	simple_button.mouse_exited.emit()
	await process_frame
	if help_layer.visible:
		push_error("System help layer did not hide after hover.")
		quit(1)
		return

	simple_button.pressed.emit()
	await process_frame
	if int(main_scene.get("current_system_page")) != 0:
		push_error("Clicking the current system tab should not switch pages.")
		quit(1)
		return

	var page: Node = null
	for child in screen_root.get_children():
		if child.get("screen_name") == "option_0simple":
			page = child
			break
	if page == null:
		push_error("Simple option page was not found.")
		quit(1)
		return

	var settings: Node = root.get_node("/root/SystemSettings")
	settings.call("set_bool", "skipall", false)
	var record: Dictionary = page.get("runtime_widgets").get("skipall_on", {})
	var node: Control = record.get("node")
	if node == null:
		push_error("skipall_on widget was not found.")
		quit(1)
		return
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	node.emit_signal("gui_input", release)
	await process_frame
	if not bool(settings.call("get_bool", "skipall", false)):
		push_error("skipall_on did not update SystemSettings.")
		quit(1)
		return

	print("OK: system settings UI hover and setting actions work")
	quit(0)
