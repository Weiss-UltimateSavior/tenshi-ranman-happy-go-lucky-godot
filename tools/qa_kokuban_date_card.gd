extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)

	# This is the exact pair emitted by showdate.tjs through the SCN JSON state:
	# a full-screen blackboard slayer followed by the date's white alpha texture.
	story.call("_apply_script_object", "slayer", {
		"class": "slayer",
		"name": "black_bord",
		"redraw": {"imageFile": {"file": "kokuban"}},
		"showmode": 3,
		"action": [["zpos", 100.0]],
	})
	story.call("_apply_script_object", "day_full", {
		"class": "day_full",
		"name": "day",
		"redraw": {"imageFile": {"file": "0408"}},
		"showmode": 3,
		"action": [["zoomx", 150.0], ["zoomy", 150.0], ["zpos", 33.3333333333]],
	})
	await process_frame

	var visuals: Dictionary = story.get("auxiliary_visual_nodes")
	var board := visuals.get("black_bord") as TextureRect
	var date := visuals.get("day") as TextureRect
	if board == null or board.texture == null:
		_fail("The showdate blackboard source was not loaded.")
		return
	if board.position != Vector2.ZERO or board.size != Vector2(1280.0, 720.0):
		_fail("The blackboard did not retain its full source-canvas geometry.")
		return
	if board.texture.get_width() != 1920 or board.texture.get_height() != 1080:
		_fail("kokuban.png is not the recovered full-colour original resource.")
		return
	if date == null or date.texture == null or date.texture.get_width() != 1280:
		_fail("The date chalk texture was not layered over the blackboard.")
		return
	if DisplayServer.get_name() != "headless":
		var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
		DirAccess.make_dir_recursive_absolute(output_dir)
		root.get_viewport().get_texture().get_image().save_png(output_dir + "/kokuban_date_card.png")

	story.call("_apply_script_object", "slayer", {"class": "slayer", "name": "black_bord", "showmode": 2})
	await process_frame
	if visuals.has("black_bord"):
		_fail("Removing the showdate blackboard left an orphaned visual node.")
		return
	print("OK: recovered kokuban background and date layer use original source geometry")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
