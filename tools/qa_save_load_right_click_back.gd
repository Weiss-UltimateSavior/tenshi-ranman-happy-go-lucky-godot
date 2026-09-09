extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame

	await _assert_return_to_story(main_scene)
	await _assert_return_to_title(main_scene)
	await _assert_return_to_static_screen(main_scene)
	print("OK: save/load right click restores the previous screen")
	quit(0)


func _assert_return_to_story(main_scene: Node) -> void:
	main_scene.show_story_screen()
	await process_frame
	var story := _first_screen_with_script(main_scene, "res://scripts/story/story_player.gd")
	main_scene.show_save_load_screen("save")
	await process_frame
	_send_right_release(main_scene)
	await process_frame
	await process_frame
	if _first_screen_with_script(main_scene, "res://scripts/story/story_player.gd") != story:
		_fail("Right click did not return from save/load to the original story screen.")


func _assert_return_to_title(main_scene: Node) -> void:
	main_scene.show_title_screen()
	await process_frame
	var title := _first_screen_with_script(main_scene, "res://scripts/ui/title_screen.gd")
	main_scene.show_save_load_screen("load")
	await process_frame
	_send_right_release(main_scene)
	await process_frame
	await process_frame
	if _first_screen_with_script(main_scene, "res://scripts/ui/title_screen.gd") != title:
		_fail("Right click did not return from save/load to the original title screen.")


func _assert_return_to_static_screen(main_scene: Node) -> void:
	main_scene.show_static_ui_screen("scnchart")
	await process_frame
	var chart := _first_screen_with_script(main_scene, "res://scripts/ui/hgl_static_screen.gd")
	main_scene.show_save_load_screen("save")
	await process_frame
	_send_right_release(main_scene)
	await process_frame
	await process_frame
	if _first_screen_with_script(main_scene, "res://scripts/ui/hgl_static_screen.gd") != chart:
		_fail("Right click did not return from save/load to the original static screen.")


func _send_right_release(main_scene: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = false
	main_scene.get_viewport().push_input(event)


func _first_screen_with_script(main_scene: Node, script_path: String) -> Node:
	var target_script := load(script_path)
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == target_script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
