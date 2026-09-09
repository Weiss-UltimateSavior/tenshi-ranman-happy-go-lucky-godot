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
	var linked := Control.new()
	linked.name = "神様"
	linked.position = Vector2(420, 120)
	story.character_layer.add_child(linked)
	story.character_nodes["神様"] = linked
	story._apply_script_object("emotion", {
		"class": "emotion",
		"name": "emo_神様",
		"link": "神様",
		"action": [["xpos", -196], ["ypos", 16], ["order", 3]],
		"redraw": {"imageFile": {"file": "emotion_heart"}},
		"showmode": 1,
	})
	var node: TextureRect = story.auxiliary_visual_nodes.get("emo_神様")
	if node == null or not is_instance_valid(node):
		_fail("emotion node was not created")
		return
	if node.get_parent() != story.script_effect_layer:
		_fail("emotion was not attached to the script effect layer")
		return
	if node.z_index != 3:
		_fail("emotion default order was not preserved")
		return
	var expected: Vector2 = linked.position + Vector2(-196, -16) * story.SOURCE_SCALE
	if not node.position.is_equal_approx(expected):
		_fail("emotion link-relative position was not applied")
		return
	story._apply_script_object("emotion", {"name": "emo_神様", "showmode": 2})
	if story.auxiliary_visual_nodes.has("emo_神様"):
		_fail("emotion hide did not remove the linked node")
		return
	print("OK: linked emotion layer, source coordinates, order, and hide verified")
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
