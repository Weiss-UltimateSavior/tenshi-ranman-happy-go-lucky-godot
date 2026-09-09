extends SceneTree

const NAME_RECT := Rect2(450, 822, 792, 53)
const TEXT_RECT := Rect2(468, 867, 1154, 160)
const SCALE := 1280.0 / 1920.0
const BASELINE_COMPENSATION := 5.0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var name_label := story.get_node_or_null("MessageWindow/Name") as Label
	var text_label := story.get_node_or_null("MessageWindow/Text") as Label
	if name_label == null or text_label == null:
		_fail("Story message labels were not constructed.")
		return
	if not name_label.position.is_equal_approx(NAME_RECT.position * SCALE):
		_fail("Name rectangle no longer matches the original window.pimg position.")
		return
	var expected_text_position := (TEXT_RECT.position + Vector2(0, BASELINE_COMPENSATION)) * SCALE
	if not text_label.position.is_equal_approx(expected_text_position):
		_fail("Text baseline compensation is missing or has drifted.")
		return
	story.call("_show_text", {"name": "佐奈", "text": "本文"})
	if name_label.text != "【佐奈】":
		_fail("Japanese speaker-name formatting does not match the original display path.")
		return
	print("OK: original nameplate format and message baseline layout are preserved")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
