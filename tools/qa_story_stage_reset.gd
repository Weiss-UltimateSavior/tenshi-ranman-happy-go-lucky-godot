extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)

	# Reproduce a same-path state update after a camera-mutated version of the
	# stage. This is the fast path used by the affected narration's stored state.
	story.call("_apply_script_object", "stage", _stage("school_gate_cherry_go_a", [["zoomx", 55.0], ["zoomy", 55.0], ["xpos", 420.0]]))
	story.call("_apply_script_object", "stage", _stage("school_gate_cherry_go_a", [["zpos", 233.3333333333]]))
	await process_frame
	var stage := story.get("stage_layer") as TextureRect
	if stage == null or stage.texture == null:
		_fail("The replacement school-gate stage was not loaded.")
		return
	if not is_equal_approx(stage.scale.x, 1.0) or not is_equal_approx(stage.scale.y, 1.0):
		_fail("A new stage inherited the previous background zoom.")
		return
	var viewport_rect := root.get_viewport().get_visible_rect()
	if not stage.get_global_rect().encloses(viewport_rect):
		_fail("The reset stage left the viewport uncovered: %s" % stage.get_global_rect())
		return
	if DisplayServer.get_name() != "headless":
		var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
		DirAccess.make_dir_recursive_absolute(output_dir)
		root.get_viewport().get_texture().get_image().save_png(output_dir + "/school_gate_stage_reset.png")
	print("OK: new stage redraw clears stale camera position and zoom")
	quit(0)


func _stage(image_name: String, actions: Array) -> Dictionary:
	return {
		"class": "stage",
		"name": "stage",
		"redraw": {"imageFile": {"file": image_name}},
		"showmode": 3,
		"action": actions,
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
