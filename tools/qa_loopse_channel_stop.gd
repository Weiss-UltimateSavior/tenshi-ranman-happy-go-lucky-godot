extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)

	# Verbatim shape from st01_02: LoopSE has a logical _lse0 declaration but
	# the actual audio channel is _se0. The next script line stops _se0.
	story.call("_apply_env_update", ["envupdate", "update", [
		["new", "_lse0", "loopse"],
		{"name": "_se0", "replay": {"filename": "コミカル１.ogg", "volume": 100.0}},
	]])
	await process_frame
	var players: Dictionary = story.get("sound_players")
	var loop_player := players.get("_se0") as AudioStreamPlayer
	if loop_player == null or not loop_player.playing:
		_fail("LoopSE did not start on its original _se0 playback channel.")
		return
	if players.has("_lse0"):
		_fail("LoopSE wrapper name was incorrectly used as an audio channel.")
		return

	story.call("_apply_env_update", ["envupdate", "update", [{"name": "_se0", "stop": 1}]])
	await process_frame
	if loop_player.playing:
		_fail("The following SCN stop _se0 did not stop the LoopSE channel.")
		return
	print("OK: LoopSE preserves its _se0 channel and subsequent stop terminates it")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
