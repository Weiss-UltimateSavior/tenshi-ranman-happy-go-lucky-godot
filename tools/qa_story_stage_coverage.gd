extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("_on_title_action", "start")
	await process_frame

	var story := _story(main_scene)
	if story == null:
		_fail("StoryPlayer was not created.")
		return
	for i in range(31):
		story.advance()
		await process_frame

	var stage: TextureRect = story.get("stage_layer")
	if stage == null or stage.texture == null:
		_fail("The story stage is not visible after the opening scene transition.")
		return
	var stage_rect := stage.get_global_rect()
	var viewport_rect := root.get_viewport().get_visible_rect()
	if not stage_rect.encloses(viewport_rect):
		_fail("Stage leaves the viewport uncovered: %s versus %s" % [stage_rect, viewport_rect])
		return
	print("OK: stage camera transform covers the complete viewport")
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
