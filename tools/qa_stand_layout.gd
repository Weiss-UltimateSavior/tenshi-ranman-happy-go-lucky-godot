extends SceneTree

const STORAGE := "st01_02.ks"
const TARGET := "*0408_start"
const TARGET_TEXT := "兄さん、大丈夫"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story := _story(main_scene)
	if story == null:
		_fail("StoryPlayer was not created.")
		return
	story.set_trace_instant_mode(true)
	story.start(STORAGE, TARGET)
	await process_frame
	for step in range(300):
		var text_label := story.get_node_or_null("MessageWindow/Text") as Label
		if text_label != null and text_label.text.contains(TARGET_TEXT):
			_validate_sana(story, step)
			return
		story.advance()
		await process_frame
	_fail("Target dialogue was not reached within 300 visible entries.")


func _validate_sana(story: Control, step: int) -> void:
	var sana := story.get_node_or_null("SceneCamera/Characters/Character_佐奈") as Control
	if sana == null:
		var names := PackedStringArray()
		var characters := story.get_node_or_null("SceneCamera/Characters")
		if characters != null:
			for child in characters.get_children():
				if child is Control:
					var control := child as Control
					names.append("%s pos=%s scale=%s size=%s" % [control.name, control.position, control.scale, control.size])
		_fail("Target dialogue did not produce Sana's stand node. Active characters: " + "; ".join(names))
		return
	if sana.size.x < 3000.0 or sana.size.y < 5000.0:
		_fail("The 100 percent stand canvas was not selected: %s" % sana.size)
		return
	var visible_parts: Array[Rect2] = []
	for child in sana.get_children():
		if child is Control:
			var part := child as Control
			visible_parts.append(Rect2(part.position * sana.scale, part.size * sana.scale))
	if visible_parts.is_empty():
		_fail("Sana stand has no drawable parts.")
		return
	var content := visible_parts[0]
	for part_rect in visible_parts.slice(1):
		content = content.merge(part_rect)
	var expected_content := Rect2(692.5, 902.0, 423.0, 1598.0)
	if not content.position.is_equal_approx(expected_content.position) or not content.size.is_equal_approx(expected_content.size):
		_fail("Sana's composed PBD bounds drifted: expected %s, actual %s" % [expected_content, content])
		return
	var global_content := Rect2(sana.position + content.position, content.size)
	var expected_global := Rect2(398.3333, 140.0, 423.0, 1598.0)
	if not global_content.position.is_equal_approx(expected_global.position) or not global_content.size.is_equal_approx(expected_global.size):
		_fail("Sana's source-derived stand anchor drifted: expected %s, actual %s" % [expected_global, global_content])
		return
	var message_window := story.get_node_or_null("MessageWindow") as Control
	if message_window == null or message_window.z_index <= sana.z_index:
		_fail("MessageWindow must remain above character z-order: message=%s, Sana=%s" % [message_window.z_index if message_window != null else -1, sana.z_index])
		return
	print("stand_layout step=", step, " cursor=", story.storage, ":", story.scene_index, ":", story.line_index)
	print("stand_layout holder pos=", sana.position, " scale=", sana.scale, " canvas=", sana.size)
	print("stand_layout content_local=", content, " content_global=", global_content)
	if not DisplayServer.get_name().to_lower().contains("headless"):
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://qa/screenshots/stand_layout_st01_02.png")
		root.get_viewport().get_texture().get_image().save_png(output)
		print("stand_layout screenshot=", output)
	print("OK: target Sana stand uses internally consistent 100 percent PBD geometry")
	quit(0)


func _story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
