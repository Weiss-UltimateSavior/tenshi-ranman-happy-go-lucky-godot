extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_system_screen(0)
	await process_frame
	var hit_buttons: Control = main_scene.get_node("ScreenRoot/SystemHitButtons")
	var text_tab: Button = hit_buttons.get_child(4)
	text_tab.mouse_entered.emit()
	await process_frame
	var output_dir := "res://qa/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(output_dir + "/system_help_hover.png"))
	print("saved ", output_dir + "/system_help_hover.png")
	quit(0)
