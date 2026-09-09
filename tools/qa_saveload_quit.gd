extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	print("Step 1: show_save_load_screen")
	main_scene.show_save_load_screen("save")
	await process_frame
	await process_frame
	print("Step 2: tree quit")
	quit(0)
