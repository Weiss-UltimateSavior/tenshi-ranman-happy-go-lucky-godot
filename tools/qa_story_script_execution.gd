extends SceneTree

const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/st01_02.ks.json"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var player: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var date_card_path := str(player.call("_resolve_script_image", "0408"))
	if date_card_path == "" or not FileAccess.file_exists(date_card_path):
		_fail("Original date_full image could not be resolved from the data package.")
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Could not parse the original scenario JSON.")
		return
	var scenario: Dictionary = parsed
	var saw_date := false
	var saw_effect := false
	var saw_loop_sound := false
	for scene_value in scenario.get("scenes", []):
		if typeof(scene_value) != TYPE_DICTIONARY:
			continue
		for line_value in Dictionary(scene_value).get("lines", []):
			player.call("_apply_line_state", line_value)
			var visuals: Dictionary = player.get("auxiliary_visual_nodes")
			var sounds: Dictionary = player.get("sound_players")
			saw_date = saw_date or visuals.has("day")
			saw_effect = saw_effect or visuals.has("stageeff_フレア右") or visuals.has("stageeff_フレア左")
			saw_loop_sound = saw_loop_sound or sounds.has("_se0") or sounds.has("_lse0")
			if saw_date and saw_effect and saw_loop_sound:
				break
		if saw_date and saw_effect and saw_loop_sound:
			break

	if not saw_date:
		_fail("Original day_full script object was not executed.")
		return
	if not saw_effect:
		_fail("Original stage effect script object was not executed.")
		return
	if not saw_loop_sound:
		_fail("Original loop SE command was not executed.")
		return

	print("OK: original envupdate commands create visual and sound runtime objects")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
