extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var story_text := story.get_node_or_null("MessageWindow/Text") as Label
	if story_text == null:
		push_error("story text label was not found.")
		quit(1)
		return
	var story_font_before := story_text.get_theme_font("font")
	main_scene.show_system_screen(4)
	await process_frame
	await process_frame

	var page := _find_option4_page(main_scene)
	if page == null:
		push_error("option_4text page was not found.")
		quit(1)
		return

	var settings: Node = root.get_node("/root/SystemSettings")
	var original_target := str(settings.call("get_color_target"))
	var original_text_color: Color = settings.call("get_color_for_target", "color_text", Color.WHITE)
	var original_winopac := float(settings.call("get_slider", "winopac", 0.9))
	var original_font := str(settings.call("get_font_name"))
	var color_button: Control = page.get("runtime_widgets").get("color_win", {}).get("node")
	if color_button == null:
		push_error("color_win widget was not found.")
		quit(1)
		return
	_emit_left_release(color_button)
	await process_frame
	if str(settings.call("get_color_target")) != "color_win":
		push_error("color selector did not update the active color target.")
		quit(1)
		return

	settings.call("set_color_for_target", "color_text", Color(0.2, 0.45, 0.8, 1.0))
	settings.call("set_slider", "winopac", 0.37)
	page.call("_update_window_sample_preview")
	await process_frame
	var sample_window := page.get_node_or_null("runtime_window_sample_window") as TextureRect
	if sample_window == null or absf(sample_window.modulate.a - 0.37) > 0.02:
		push_error("winopac did not update the preview window opacity.")
		quit(1)
		return
	var sample_text := page.get_node_or_null("runtime_window_sample_text") as Label
	if sample_text == null:
		push_error("sample text label was not found.")
		quit(1)
		return
	var applied := sample_text.get_theme_color("font_color")
	if absf(applied.b - 0.8) > 0.05:
		push_error("color palette value did not update sample text color.")
		quit(1)
		return

	var font_button: Control = page.get("runtime_widgets").get("fontselect", {}).get("node")
	if font_button == null:
		push_error("fontselect widget was not found.")
		quit(1)
		return
	_emit_left_release(font_button)
	await process_frame
	var dialog := page.get_node_or_null("FontSelectionDialog") as Control
	if dialog == null:
		push_error("fontselect did not open its modal selection dialog.")
		quit(1)
		return
	var list := dialog.get_node_or_null("FontSelectionPanel/FontList") as ItemList
	if list == null or list.item_count < 2:
		push_error("font selection dialog did not populate packaged fonts.")
		quit(1)
		return
	var selected_index := 1 if list.get_selected_items().is_empty() or list.get_selected_items()[0] == 0 else 0
	list.select(selected_index)
	list.item_selected.emit(selected_index)
	var accept := dialog.get_node_or_null("FontSelectionPanel/Accept") as Button
	if accept == null:
		push_error("font selection dialog has no confirmation button.")
		quit(1)
		return
	accept.pressed.emit()
	await process_frame
	var sample_font_after := sample_text.get_theme_font("font")
	var story_font_after := story_text.get_theme_font("font")
	if str(settings.call("get_font_name")) == original_font:
		push_error("fontselect did not choose the next packaged font.")
		quit(1)
		return
	if sample_font_after == null or sample_font_after == story_font_before:
		push_error("fontselect did not update the settings preview font.")
		quit(1)
		return
	if story_font_after == null or story_font_after == story_font_before:
		push_error("fontselect did not update the active story font.")
		quit(1)
		return
	settings.call("set_color_target", original_target)
	settings.call("set_color_for_target", "color_text", original_text_color)
	settings.call("set_slider", "winopac", original_winopac)
	settings.call("set_font_name", original_font)

	print("OK: option_4text color, opacity, and font controls update runtime state")
	quit(0)


func _find_option4_page(main_scene: Node) -> Node:
	var screen_root: Control = main_scene.get_node("ScreenRoot")
	for child in screen_root.get_children():
		if child.get("screen_name") == "option_4text":
			return child
	return null


func _emit_left_release(node: Control) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	node.emit_signal("gui_input", release)
