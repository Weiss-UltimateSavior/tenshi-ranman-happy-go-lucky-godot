extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_system_screen(0)
	await process_frame

	var output_dir := "res://qa/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var hit_buttons: Control = main_scene.get_node("ScreenRoot/SystemHitButtons")
	var names := ["reset", "title", "back"]
	for index in names.size():
		var button: Button = hit_buttons.get_child(10 + index * 2 + 1)
		button.mouse_entered.emit()
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/system_bottom_%s_hover.png" % [output_dir, names[index]]
		image.save_png(ProjectSettings.globalize_path(path))
		print("saved ", path)
		button.mouse_exited.emit()
		await process_frame
	quit(0)
