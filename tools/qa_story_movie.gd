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
	story.set_trace_instant_mode(true)
	story._apply_line_state(["sysmovie", "storage", "るりコムローイ", "color", "0xFFFFFF", "canskip", "true"])
	await process_frame
	var player: VideoStreamPlayer = story.get("movie_player")
	var overlay: Control = story.get("movie_overlay")
	if player == null or player.stream == null:
		_fail("sysmovie did not resolve the converted OGV stream")
		return
	if overlay == null or not overlay.visible:
		_fail("sysmovie did not reveal the full-canvas movie overlay")
		return
	if not overlay.color.is_equal_approx(Color.WHITE):
		_fail("sysmovie did not retain the original color=0xFFFFFF movie background")
		return
	if not bool(story.get("movie_playing")) or not story._is_script_waiting():
		_fail("sysmovie did not block scenario execution during playback")
		return
	story._finish_movie()
	await process_frame
	if bool(story.get("movie_playing")) or overlay.visible or story._is_script_waiting():
		_fail("skippable sysmovie did not restore scenario execution")
		return
	print("OK: sysmovie resolves OGV, blocks execution, and restores on skip")
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
