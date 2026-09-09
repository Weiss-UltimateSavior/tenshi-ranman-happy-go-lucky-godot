extends SceneTree

func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var story_script: Script = load("res://scripts/story/story_player.gd")
	var backlog_script: Script = load("res://scripts/ui/hgl_static_screen.gd")
	main_scene.show_story_screen()
	await process_frame
	await process_frame

	var story: Node = _find_script_node(main_scene.get_node("ScreenRoot"), story_script)
	if story == null:
		push_error("StoryPlayer was not created")
		quit(1)
		return
	for _index in range(10):
		story.advance()
		await process_frame

	var history: Array = story.get("history_entries")
	if history.size() < 5:
		push_error("Expected at least 5 backlog entries, got %d" % history.size())
		quit(1)
		return
	main_scene.show_backlog_screen()
	await process_frame
	await process_frame

	var screen_root: Node = main_scene.get_node("ScreenRoot")
	var backlog: Node = _find_script_node(screen_root, backlog_script)
	if backlog == null:
		push_error("Backlog screen was not created")
		quit(1)
		return
	var runtime: Node = backlog.get("backlog_runtime_layer")
	if runtime == null:
		push_error("Backlog runtime layer was not created")
		quit(1)
		return
	var date_layer := runtime.get_node_or_null("backlog_date") as Control
	var has_date_widget := date_layer != null and (date_layer.get_node_or_null("date_text") != null or date_layer.get_node_or_null("date_0408_exact") != null)
	if not has_date_widget:
		push_error("Backlog date widget was not built")
		quit(1)
		return
	var date_text := date_layer.get_node_or_null("date_text")
	print("date widget: ", date_layer.position, " ", date_layer.size, " ", date_text.text if date_text != null else "exact raster")
	var row_count := 0
	for child in runtime.get_children():
		if str(child.name).begins_with("backlog_entry_"):
			row_count += 1
	if row_count != 5:
		push_error("Expected 5 visible backlog rows, got %d" % row_count)
		quit(1)
		return
	for button_name in ["backlog_bottom_flowchart", "backlog_bottom_title", "backlog_bottom_back"]:
		if runtime.get_node_or_null(button_name) == null:
			push_error("Missing backlog button: " + button_name)
			quit(1)
			return
	if _find_script_node(screen_root, story_script) == null:
		push_error("Backlog destroyed the underlying StoryPlayer")
		quit(1)
		return
	var story_before_input_scene := int(story.get("scene_index"))
	var story_before_input_line := int(story.get("line_index"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	story._gui_input(click)
	if int(story.get("scene_index")) != story_before_input_scene or int(story.get("line_index")) != story_before_input_line:
		push_error("StoryPlayer advanced while Backlog was active")
		quit(1)
		return
	var old_history_size := history.size()
	var first_history_entry: Dictionary = Dictionary(history[0])
	if not story.jump_to_history_entry(first_history_entry):
		push_error("History jump was rejected")
		quit(1)
		return
	var story_text_label: Label = story.get("text_label")
	if story.history_entries.size() != old_history_size or story_text_label == null or str(story_text_label.text) != str(first_history_entry.get("text", "")):
		push_error("History jump changed history or restored the wrong text")
		quit(1)
		return

	_save("res://qa/screenshots/backlog_with_history.png")
	backlog._handle_backlog_scroll("top")
	await process_frame
	backlog._handle_backlog_scroll("end")
	await process_frame
	main_scene._on_static_ui_action("back")
	await process_frame
	if _find_script_node(screen_root, story_script) == null:
		push_error("Backlog back action did not restore the StoryPlayer")
		quit(1)
		return
	print("OK: backlog rows, controls, scrolling, overlay and return verified")
	quit(0)


func _find_script_node(parent: Node, script_resource: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script_resource:
			return child
	return null


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := root.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(path))
		print("saved ", path)
