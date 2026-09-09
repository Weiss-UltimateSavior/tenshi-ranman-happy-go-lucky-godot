extends SceneTree

const TARGET_TEXT := "駅前からちょっと離れた位置にある学園は、住宅地のど真ん中にあるため、電車通学してない人間も多い。"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)
	story.call("start", "st01_02.ks", "*0408_start")

	var entry := _find_target_entry(story)
	if entry.is_empty():
		_fail("The target school-gate narration was not found in st01_02.ks.")
		return
	# The preceding SCN shot moves and zooms the environment camera. The target
	# state's plain { name = env } must restore the original camera before the
	# school gate is drawn.
	story.call("_apply_environment_camera", {"action": [["camerax", 350.0], ["cameray", 40.0], ["camerazoom", 200.0]]})
	story.call("_apply_state", Dictionary(entry.get("state", {})))
	story.call("_show_text", entry)
	await process_frame

	var stage := story.get("stage_layer") as TextureRect
	if stage == null or stage.texture == null or not str(stage.get_path()).contains("Stage"):
		_fail("The target narration did not produce a stage layer.")
		return
	var viewport := root.get_viewport().get_visible_rect()
	if not stage.get_global_rect().encloses(viewport):
		_fail("The exact SCN state leaves uncovered canvas: %s" % stage.get_global_rect())
		return
	var camera := story.get("scene_camera_layer") as Control
	if camera == null or not is_equal_approx(camera.scale.x, 1.0) or not is_equal_approx(camera.scale.y, 1.0):
		_fail("The target SCN state retained a previous environment camera zoom.")
		return
	if DisplayServer.get_name() != "headless":
		var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
		DirAccess.make_dir_recursive_absolute(output_dir)
		root.get_viewport().get_texture().get_image().save_png(output_dir + "/school_gate_story_frame.png")
	print("OK: exact st01_02 school-gate text state covers the viewport")
	quit(0)


func _find_target_entry(story: Node) -> Dictionary:
	var scenario: Dictionary = story.get("scenario")
	for scene_value in scenario.get("scenes", []):
		var scene: Dictionary = scene_value
		var texts: Array = scene.get("texts", [])
		for index in texts.size():
			var entry: Dictionary = story.call("_text_entry", scene, index + 1)
			if str(entry.get("text", "")).contains(TARGET_TEXT):
				return entry
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
