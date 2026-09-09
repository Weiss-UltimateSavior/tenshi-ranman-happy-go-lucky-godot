extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		_fail("StoryPlayer was not created")
		return
	story._apply_line_state(["msgoff"])
	if story.window_layer.visible:
		_fail("msgoff did not hide the message window")
		return
	story._apply_line_state(["msgon"])
	if not story.window_layer.visible:
		_fail("msgon did not restore the message window")
		return
	story._apply_line_state(["_meswinchange", "type", "another"])
	if story.message_window_mode != "another":
		_fail("_meswinchange did not select the alternate window")
		return
	story._apply_line_state(["chapter", "0717", "true", "hide", "true"])
	story._apply_line_state(["scnchart", "enter", "RU01_01*0717"])
	if story.current_chapter != "0717" or story.current_scnchart != "enter":
		_fail("chapter/scnchart metadata was not retained")
		return
	story._apply_line_state(["quickmenu", "fadeout", "true"])
	if story.quickmenu_layer.visible:
		_fail("quickmenu fadeout was not applied")
		return
	print("OK: direct SCN message, metadata, and quickmenu commands verified")
	quit(0)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
