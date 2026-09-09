extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var settings := root.get_node_or_null("SystemSettings")
	if settings != null:
		settings.set_confirm("cf_exit", true)
	main_scene.show_save_load_screen("save")
	await process_frame
	await process_frame
	main_scene._request_exit()
	await process_frame
	await process_frame
	if main_scene._exit_confirm_dialog() == null:
		push_error("Exit confirmation dialog was not shown")
		quit(1)
		return
	_save("res://qa/screenshots/exit_confirm_dialog.png")
	print("OK: exit confirmation dialog captured")
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
