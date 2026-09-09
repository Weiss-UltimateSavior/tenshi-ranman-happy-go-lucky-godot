extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	var player := AudioStreamPlayer.new()
	story.add_child(player)
	player.stream = AudioStreamGenerator.new()
	player.play()
	var sounds: Dictionary = story.get("sound_players")
	sounds["_loopse_qa"] = player

	# Restarting a story previously dropped this dictionary without stopping the
	# node, leaving every historical loopse audible beneath the next route.
	story.call("start", "st01_01.ks", "*0408")
	await process_frame
	if is_instance_valid(player):
		_fail("Story reset retained a script sound player from the previous route.")
		return
	if not Dictionary(story.get("sound_players")).is_empty():
		_fail("Story reset retained stale script sound registrations.")
		return
	print("OK: story reset stops and releases old loopse players")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
