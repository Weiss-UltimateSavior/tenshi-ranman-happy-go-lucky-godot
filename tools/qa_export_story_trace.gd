extends SceneTree

## Story trace exporter. Defaults reproduce the opening baseline; user args
## select an alternate route (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 6):
##   --storage=st04_04.ks --target=*0429_4 --output=res://qa/traces/x.json
##   --entry-count=400 --select-index=1
## --select-index injects apply_selection() once, exactly when the story
## reaches a pending selection, so fixtures never need real clicks.

const DEFAULT_STORAGE := "st01_01.ks"
const DEFAULT_TARGET := "*0408"
const DEFAULT_ENTRY_COUNT := 32
const DEFAULT_OUTPUT := "res://qa/traces/godot_opening_trace.json"


func _initialize() -> void:
	var args := _user_args()
	var storage: String = args.get("storage", DEFAULT_STORAGE)
	var target: String = args.get("target", DEFAULT_TARGET)
	var entry_count: int = int(args.get("entry-count", str(DEFAULT_ENTRY_COUNT)))
	var output: String = args.get("output", DEFAULT_OUTPUT)
	var select_index := int(args.get("select-index", "-1"))

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		push_error("Could not create StoryPlayer for trace export")
		quit(1)
		return
	story.set_trace_instant_mode(true)
	story.start(storage, target)
	await process_frame
	var frames: Array = []
	var injected := false
	for index in range(entry_count):
		var frame: Dictionary = story.export_trace_frame()
		frame["sequence"] = index
		frames.append(frame)
		if _is_terminal(frame) or _is_error_text(story):
			break
		if not injected and select_index >= 0 and story.selection_pending:
			story.apply_selection(select_index)
			injected = true
		story.advance()
		await process_frame
	var report := {
		"format": "tenshin-godot-story-trace-v1",
		"source": {"storage": storage, "target": target, "select_index": select_index},
		"frames": frames,
	}
	var output_path := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write story trace: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("OK: exported ", frames.size(), " story trace frames to ", output_path)
	if not story.last_branch_decision.is_empty():
		print("OK: last branch decision: ", JSON.stringify(story.last_branch_decision))
	quit(0)


func _is_terminal(frame: Dictionary) -> bool:
	var text := str(frame.get("entry", {}).get("text", ""))
	if text.begins_with("End of playable scenario."):
		return true
	if text.begins_with("Scenario not found"):
		return true
	return bool(frame.get("branch", {}).get("game_ended", false))


func _is_error_text(story: Node) -> bool:
	# _show_error writes the message box directly without touching
	# current_entry, so the terminal check must read the live label too.
	var text := str(story.text_label.text)
	return text.begins_with("Scenario not found") or text.begins_with("End of playable scenario.")


func _user_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.trim_prefix("--")
		var eq := body.find("=")
		if eq >= 0:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
