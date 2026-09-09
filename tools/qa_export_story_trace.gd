extends SceneTree

const STORAGE := "st01_01.ks"
const TARGET := "*0408"
const ENTRY_COUNT := 32
const OUTPUT := "res://qa/traces/godot_opening_trace.json"


func _initialize() -> void:
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
	story.start(STORAGE, TARGET)
	await process_frame
	var frames: Array = []
	for index in range(ENTRY_COUNT):
		var frame: Dictionary = story.export_trace_frame()
		frame["sequence"] = index
		frames.append(frame)
		if str(frame.get("entry", {}).get("text", "")).begins_with("End of playable scenario."):
			break
		story.advance()
		await process_frame
	var report := {
		"format": "tenshin-godot-story-trace-v1",
		"source": {"storage": STORAGE, "target": TARGET},
		"frames": frames,
	}
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write story trace: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("OK: exported ", frames.size(), " story trace frames to ", output_path)
	quit(0)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null
