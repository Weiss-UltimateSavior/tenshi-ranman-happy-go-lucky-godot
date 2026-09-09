extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		push_error("StoryPlayer was not created")
		quit(1)
		return
	# Reproduce the playable entry path instead of a hand-selected later scene.
	# The reported black block occurs during this opening composition.
	story.start("st01_01.ks", "*0408")
	for ignored in range(31):
		story.advance()
		await process_frame
	print("entry=", story.current_entry)
	_dump_tree(story, "")
	if DisplayServer.get_name() != "headless":
		_save("res://qa/screenshots/debug_story_with_face.png")
	story._clear_message_face()
	await process_frame
	if DisplayServer.get_name() != "headless":
		_save("res://qa/screenshots/debug_story_without_face.png")
	print("OK: story layer diagnostics captured")
	quit(0)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _dump_tree(node: Node, indent: String) -> void:
	if node is CanvasItem:
		var canvas := node as CanvasItem
		var details := ""
		if node is Control:
			var control := node as Control
			details = " rect=" + str(control.get_global_rect())
		print(indent, node.name, " visible=", canvas.visible, " modulate=", canvas.modulate, details)
	for child in node.get_children():
		_dump_tree(child, indent + "  ")


func _save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
