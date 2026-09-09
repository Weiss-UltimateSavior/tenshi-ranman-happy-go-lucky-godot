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
	story._apply_particle_object({
		"name": "rise1",
		"class": "particle",
		"showmode": 3,
		"redraw": {"imageFile": {"file": "particle_white_ball_1"}},
		"action": [["zoomx", 150], ["zoomy", 150], ["zpos", -75]],
	})
	await process_frame
	var emitters: Dictionary = story.get("particle_emitters")
	var emitter: Node = emitters.get("rise1")
	if emitter == null or not is_instance_valid(emitter):
		_fail("particle_white_ball_1 did not create an emitter")
		return
	if int(emitter.get("profile_index")) != 1 or emitter.z_index != -75:
		_fail("particle emitter did not retain its original profile or layer order")
		return
	if (emitter.get("particles") as Array).is_empty():
		_fail("particle emitter did not seed original immediate particles")
		return
	await create_timer(0.35).timeout
	if (emitter.get("particles") as Array).size() < 3:
		_fail("particle emitter did not continuously generate particles")
		return
	story._apply_particle_object({"name": "rise1", "showmode": 0})
	if not (story.get("particle_emitters") as Dictionary).is_empty():
		_fail("particle hide did not remove the emitter")
		return
	print("OK: original white-ball profiles generate, animate, layer, and remove")
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
