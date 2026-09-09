extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await process_frame

	var output_dir := "res://qa/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	_save(output_dir + "/story_start_01.png")

	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	for i in range(8):
		story.advance()
		await process_frame
	_save(output_dir + "/story_start_cg.png")

	print("OK: story start screenshots captured")
	quit(0)


func _save(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
