extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("_on_title_action", "start")
	await process_frame
	var story := _story(main_scene)
	if story == null:
		_fail("Start did not create StoryPlayer.")
		return
	story.call("set_trace_instant_mode", true)
	story.call("advance")

	for _step in range(28):
		story.call("advance")
		await process_frame
		var text: Label = story.get_node_or_null("MessageWindow/Text")
		if text != null and text.text.contains("本日の降水確率"):
			var event: TextureRect = story.get_node_or_null("SceneCamera/Event")
			if event == null or event.texture == null or not event.visible:
				_fail("Weather forecast line did not render its blue_sky event background.")
				return
			print("OK: weather forecast line renders blue_sky background")
			quit(0)
			return
	_fail("Could not reach the weather forecast line from the initial scenario.")


func _story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
