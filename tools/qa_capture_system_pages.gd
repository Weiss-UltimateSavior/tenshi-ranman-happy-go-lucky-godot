extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var output_dir := "res://qa/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for page_index in [4, 6, 7, 8, 9]:
		main_scene.show_system_screen(page_index)
		await process_frame
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/system_page_%d.png" % [output_dir, page_index]
		image.save_png(ProjectSettings.globalize_path(path))
		print("saved ", path)
	quit(0)
