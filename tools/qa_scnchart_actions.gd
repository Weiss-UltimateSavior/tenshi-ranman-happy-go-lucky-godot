extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.show_static_ui_screen("scnchart")
	await process_frame
	var screen: Node = main_scene.screen_root.get_child(0)
	screen._handle_local_static_action("page3")
	await process_frame
	if int(screen.scnchart_page) != 3:
		push_error("Route page did not change to page3")
		quit(1)
		return
	screen._handle_local_static_action("pagedown")
	await process_frame
	if int(screen.scnchart_scroll) <= 0:
		push_error("Flowchart scroll did not advance")
		quit(1)
		return
	screen._handle_local_static_action("jump")
	await process_frame
	await process_frame
	if not _has_story_player(main_scene):
		push_error("Flowchart jump did not enter story")
		quit(1)
		return
	print("OK: scnchart route, scroll, and jump actions work")
	quit(0)


func _has_story_player(main_scene: Node) -> bool:
	for child in main_scene.screen_root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == "res://scripts/story/story_player.gd":
			return true
	return false
