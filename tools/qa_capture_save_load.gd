extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await process_frame
	main_scene.show_save_load_screen("save")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/save_load_save_empty.png")

	var save_screen: Node = _save_load_screen(main_scene)
	if save_screen != null:
		save_screen._on_slot_pressed(0)
		await process_frame
		await process_frame
	_save("res://qa/screenshots/save_load_save_slot01.png")
	main_scene.show_save_load_screen("load")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/save_load_load_slot01.png")
	save_screen = _save_load_screen(main_scene)
	if save_screen != null:
		save_screen._on_slot_pressed(0)
		await process_frame
		await process_frame
	var story_found := false
	var root_node: Node = main_scene.get_node("ScreenRoot")
	for child in root_node.get_children():
		if child.get_script() == load("res://scripts/story/story_player.gd"):
			story_found = true
	if not story_found:
		push_error("Load slot did not return to StoryPlayer")
		quit(1)
		return

	var save_path := "user://saves/slot_001.json"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(save_path)):
		push_error("Save file was not written: " + save_path)
		quit(1)
		return
	print("OK: SAVE/LOAD screenshots captured and slot_001.json exists")
	quit(0)


func _save_load_screen(main_scene: Node) -> Node:
	var root_node: Node = main_scene.get_node("ScreenRoot")
	for child in root_node.get_children():
		if child.get_script() == load("res://scripts/ui/save_load_screen.gd"):
			return child
	return null


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("skip screenshot in headless: ", path)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		print("skip screenshot with null viewport image: ", path)
		return
	image.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
