extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.show_static_ui_screen("extra_stand")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/extra_stand_default.png")

	var screen: Node = main_scene.screen_root.get_child(0)
	screen._handle_local_static_action("chadd")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/extra_stand_chadd_popup.png")

	print("OK: extra stand popup screenshots captured")
	quit(0)


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
