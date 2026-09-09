extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.show_title_screen()
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_01.png")

	main_scene._on_title_action("load")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_02_load.png")

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("flowchart")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_03_flowchart.png")

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("extra")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_04_extra.png")

	main_scene._on_static_ui_action("to_stand")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_05_extra_stand.png")

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("system")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_06_system.png")

	main_scene.show_title_screen()
	await process_frame
	main_scene._on_title_action("exit")
	await process_frame
	await process_frame
	_save("res://qa/screenshots/title_07_exit_confirm.png")

	print("OK: title flow screenshots captured")
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
