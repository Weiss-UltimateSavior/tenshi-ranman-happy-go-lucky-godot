extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var name_label := story.get_node_or_null("MessageWindow/Name") as Label
	var text_label := story.get_node_or_null("MessageWindow/Text") as Label
	for index in range(96):
		if name_label != null and not name_label.text.is_empty() and text_label != null and not text_label.text.is_empty():
			break
		story.call("advance")
		await process_frame
	if name_label == null or text_label == null or name_label.text.is_empty() or text_label.text.is_empty():
		push_error("No voiced/nameplate story line was reached for layout capture.")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output := output_dir + "/story_message_layout.png"
	root.get_viewport().get_texture().get_image().save_png(output)
	print("saved ", output)
	print("name=", name_label.text, " name_position=", name_label.position, " text_position=", text_label.position)
	quit(0)
