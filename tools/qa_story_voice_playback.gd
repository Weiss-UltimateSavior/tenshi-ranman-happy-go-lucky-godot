extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame

	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	# The production player now honors the source transition wait before the
	# opening text. This fixture audits voice resolution, so traverse the JSON
	# trace instantly rather than treating a pending visual transition as text.
	story.call("set_trace_instant_mode", true)
	var expected_voice := "san001_003"
	for i in range(64):
		story.call("advance")
		await process_frame
		if str(story.get("last_voice_name")) == expected_voice:
			break
	var current_voice := str(story.get("last_voice_name"))
	var player: AudioStreamPlayer = story.get_node_or_null("StoryVoice")
	if current_voice != expected_voice:
		_fail("Expected %s but reached %s." % [expected_voice, current_voice])
		return
	if player == null or player.stream == null or not player.playing:
		_fail("Story voice was not loaded and playing for %s." % expected_voice)
		return
	print("OK: %s resolves to a playable voice stream" % expected_voice)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
