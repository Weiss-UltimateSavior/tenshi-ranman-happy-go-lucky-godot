extends SceneTree

## Message-window face (msgwin / facemask) regression
## (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §5): the face window must be
## clipped to the PBD `顔領域` region rather than showing a miniature stand.
##
## Run: godot --headless --script res://tools/qa_message_face.gd

const CHARACTER := "佐奈"


func _initialize() -> void:
	var story_script := load("res://scripts/story/story_player.gd")
	var story = story_script.new()
	root.add_child(story)
	await process_frame

	# The face window is a clipped Control inside the message window.
	var face_layer: Control = story.message_face_layer
	if face_layer == null:
		_fail("message_face_layer was not created")
		return
	if not face_layer.clip_contents:
		_fail("message face layer must clip its contents (facemask semantics)")
		return
	print("  ok: face layer clips at %s size %s" % [str(face_layer.position), str(face_layer.size)])

	# PBD declares the authoritative face region; compare against a real file.
	var pbd_path := "res://assets/fgimage/%s/%s_ポーズa_3.pbd.json" % [CHARACTER, CHARACTER]
	if not FileAccess.file_exists(pbd_path):
		print("  skip: %s not found (PBD decode output missing)" % pbd_path)
		_ok()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pbd_path))
	if typeof(parsed) != TYPE_ARRAY:
		_fail("cannot parse " + pbd_path)
		return
	var region := {}
	for entry in Array(parsed):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(Dictionary(entry).get("name", "")) == "顔領域":
			region = entry
			break
	if region.is_empty():
		_fail("PBD has no 顔領域 entry")
		return
	var w := float(region.get("width", 0.0))
	var h := float(region.get("height", 0.0))
	print("  ok: PBD 顔領域 = %dx%d at (%s,%s)" % [
		int(w), int(h), str(region.get("left")), str(region.get("top"))])
	if w <= 0.0 or h <= 0.0:
		_fail("PBD 顔領域 has non-positive size")
		return

	# The _3 assets are 2x source; the placed stand uses a 0.25 factor, so the
	# visible face window should be within a sane range of the declared region.
	var expected_w := w * 0.25
	var expected_h := h * 0.25
	if face_layer.size.x < expected_w * 0.4 or face_layer.size.x > expected_w * 2.5:
		_fail("face window width %f is far from the declared region (%f)" % [face_layer.size.x, expected_w])
		return
	if face_layer.size.y < expected_h * 0.4 or face_layer.size.y > expected_h * 2.5:
		_fail("face window height %f is far from the declared region (%f)" % [face_layer.size.y, expected_h])
		return
	print("  ok: face window %s is consistent with 0.25x of the declared region" % str(face_layer.size))
	_ok()


func _ok() -> void:
	print("OK: qa_message_face passed all checks")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
