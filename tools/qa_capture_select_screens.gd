extends SceneTree

## Captures both selection UI modes for manual comparison against the original
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 4). Requires a windowed run:
##   godot --script res://tools/qa_capture_select_screens.gd
## In headless mode this fixture exits cleanly (no viewport to capture).

const OUTPUT_DIR := "res://qa/screenshots/"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: qa_capture_select_screens requires a windowed run (viewport capture)")
		quit(0)
		return
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		push_error("Could not create StoryPlayer")
		quit(1)
		return

	# Dialog selection (st04_04, text options).
	story.set_trace_instant_mode(true)
	story.start("st04_04.ks", "*dummyselect1")
	for i in range(8):
		await process_frame
		if story.selection_pending:
			break
	await process_frame
	_capture("select_dialog_current.png")

	# Map selection (st07_01, name+place options over a background).
	story.start("st07_01.ks", "*dummyselect1")
	for i in range(8):
		await process_frame
		if story.selection_pending:
			break
	await process_frame
	_capture("select_map_current.png")

	print("OK: selection screenshots captured to ", OUTPUT_DIR)
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + file_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("  captured: ", path)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
