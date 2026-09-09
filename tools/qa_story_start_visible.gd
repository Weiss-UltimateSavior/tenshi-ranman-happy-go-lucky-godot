extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("_on_title_action", "start")
	await process_frame
	await process_frame
	var story := _story(main_scene)
	if story == null:
		_fail("Start did not create StoryPlayer.")
		return
	# ST01_01 begins with the source crossfade(time=1000) plus a wait barrier.
	# Verify the first line after that authored opening transition completes.
	await create_timer(1.2).timeout
	var text: Label = story.get_node_or_null("MessageWindow/Text")
	if text == null or text.text.strip_edges() == "":
		_fail("StoryPlayer reached the start screen without a visible first line: %s" % str(story.get("current_entry")))
		return
	var stage: TextureRect = story.get_node_or_null("SceneCamera/Stage")
	var event: TextureRect = story.get_node_or_null("SceneCamera/Event")
	if (stage == null or not stage.visible) and (event == null or not event.visible):
		_fail("StoryPlayer reached the first line without a visible stage or event layer.")
		return
	print("OK: start reaches visible story text and visual layer")
	quit(0)


func _story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
