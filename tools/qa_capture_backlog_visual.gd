extends SceneTree

func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await process_frame
	var story := _find_script_node(main_scene.get_node("ScreenRoot"), load("res://scripts/story/story_player.gd"))
	if story == null:
		quit(1)
		return
	for _index in range(10):
		story.advance()
		await process_frame
	main_scene.show_backlog_screen()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://qa/screenshots/backlog_visual.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	image.save_png(output)
	print("saved ", output)
	quit(0)


func _find_script_node(parent: Node, script_resource: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script_resource:
			return child
	return null
