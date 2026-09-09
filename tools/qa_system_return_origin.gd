extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame

	main_scene.show_story_screen()
	await process_frame
	var story := _first_story(main_scene)
	if story == null:
		push_error("Could not create the story screen.")
		quit(1)
		return

	main_scene.show_system_screen(0)
	await process_frame
	main_scene._unhandled_input(_right_release())
	await process_frame
	if _first_story(main_scene) != story:
		push_error("Right-click did not restore the original story screen instance.")
		quit(1)
		return

	main_scene.show_system_screen(0)
	await process_frame
	var hit_layer: Control = main_scene.get_node("ScreenRoot/SystemHitButtons")
	var back_button: Button = hit_layer.get_child(hit_layer.get_child_count() - 1)
	back_button.pressed.emit()
	await process_frame
	if _first_story(main_scene) != story:
		push_error("The game-screen button did not restore the original story screen instance.")
		quit(1)
		return

	print("OK: system right-click and game-screen button restore the previous screen")
	quit(0)


func _right_release() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = false
	return event


func _first_story(main_scene: Node) -> Node:
	var story_script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == story_script:
			return child
	return null
