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
	story._apply_script_object("stageeff", {
		"class": "stageeff",
		"name": "stageeff_フレア右",
		"showmode": 1,
		"action": [["xpos", 640], ["ypos", 360], ["order", 1]],
		"redraw": {"imageFile": {"file": "fure_r", "options": {"afx": "right", "afy": 0}}},
	})
	var node: TextureRect = story.auxiliary_visual_nodes.get("stageeff_フレア右")
	if node == null or node.get_parent() != story.stage_effect_layer:
		_fail("stageeff was not placed in the original background/effect layer")
		return
	var material := node.material as CanvasItemMaterial
	if material == null or material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("stageeff did not preserve original ltAdditive blending")
		return
	var descriptor: Dictionary = story.stage_effect_animations.get("stageeff_フレア右", {})
	var frames: Array = descriptor.get("frames", [])
	if frames.size() < 2 or float(Dictionary(frames[0]).get("duration_ms", 0.0)) <= 0.0:
		_fail("stageeff did not parse the original ASD frame schedule")
		return
	var first_index := int(descriptor.get("frame_index", -1))
	story._update_stage_effect_animations(float(Dictionary(frames[0]).get("duration_ms", 0.0)) / 1000.0 + 0.01)
	descriptor = story.stage_effect_animations.get("stageeff_フレア右", {})
	if int(descriptor.get("frame_index", -1)) == first_index:
		_fail("stageeff animation did not advance to the next original frame")
		return
	print("OK: original ASD stage effect timing, layer order, and additive blend verified")
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
