extends SceneTree


func _initialize() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	await process_frame
	var story := _story(main_scene)
	if story == null:
		_fail("StoryPlayer was not created.")
		return
	var event: TextureRect = story.get_node_or_null("SceneCamera/Event")
	var stage: TextureRect = story.get_node_or_null("SceneCamera/Stage")
	var report := PackedStringArray([
		"viewport=%s" % str(root.get_viewport().get_visible_rect()),
		"main pos=%s size=%s scale=%s" % [main_scene.position, main_scene.size, main_scene.scale],
		"story pos=%s size=%s scale=%s" % [story.position, story.size, story.scale],
		"stage pos=%s size=%s scale=%s texture=%s" % [stage.position, stage.size, stage.scale, stage.texture.get_size() if stage.texture != null else Vector2.ZERO],
		"event pos=%s size=%s scale=%s texture=%s" % [event.position, event.size, event.scale, event.texture.get_size() if event.texture != null else Vector2.ZERO],
	])
	var output := FileAccess.open("user://story_layout.txt", FileAccess.WRITE)
	output.store_string("\n".join(report))
	output.close()
	print("\n".join(report))
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
