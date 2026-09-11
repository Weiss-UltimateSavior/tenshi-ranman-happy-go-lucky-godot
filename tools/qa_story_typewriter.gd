extends SceneTree

## Typewriter regression (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §1):
## live playback reveals text progressively and a click completes the line;
## trace/instant mode and save replay always present the full line.
##
## Run: godot --headless --script res://tools/qa_story_typewriter.gd

const STORAGE := "st01_01.ks"
const TARGET := "*0408"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_story(main_scene)
	if story == null:
		_fail("Could not create StoryPlayer")
		return

	# --- Live mode: progressive reveal ---
	# Use instant mode to land on a text line deterministically, then switch to
	# live mode and replay that same line so the reveal can be observed.
	story.set_trace_instant_mode(true)
	story.start(STORAGE, TARGET)
	await process_frame
	if story.text_label.text.length() <= 0:
		_fail("instant mode did not present the opening line")
		return
	story.set_trace_instant_mode(false)
	# Replay the same entry: _show_text starts the typewriter from zero.
	story._show_text(story.current_entry.duplicate(true))
	await process_frame
	var total: int = story.text_label.text.length()
	if total <= 0:
		_fail("no text was presented after re-showing the entry")
		return
	if not story.reveal_active:
		_fail("live text did not start revealing (reveal_active=false)")
		return
	# _process may already have revealed a frame's worth of characters.
	var first_seen: int = story.text_label.visible_characters
	if first_seen < 0 or first_seen >= total:
		_fail("reveal should be partial right after starting, got %d/%d" % [first_seen, total])
		return
	# Let a few frames pass: more characters must become visible.
	var progressed := false
	for _i in range(30):
		await process_frame
		if story.text_label.visible_characters > first_seen:
			progressed = true
			break
	if not progressed:
		_fail("visible_characters stalled at %d" % first_seen)
		return
	if story.text_label.visible_characters >= total:
		_fail("text completed instantly in live mode (%d/%d)" % [story.text_label.visible_characters, total])
		return
	print("  ok: live reveal progressed %d -> %d of %d" % [first_seen, story.text_label.visible_characters, total])

	# --- Click semantics: first completes, second advances ---
	var before_text: String = story.text_label.text
	story.advance()
	if story.reveal_active:
		_fail("advance() did not complete the reveal")
		return
	if story.text_label.visible_characters != -1:
		_fail("completing should set visible_characters to -1, got %d" % story.text_label.visible_characters)
		return
	if story.text_label.text != before_text:
		_fail("completing the line must not change the text")
		return
	print("  ok: first click completes the line at %d chars" % total)
	story.advance()
	await process_frame
	if story.text_label.text == before_text and story.current_entry.get("text", "") == before_text:
		_fail("second click did not advance to the next line")
		return
	print("  ok: second click advanced to the next line")

	# --- Speed mapping is monotonic (needs the SystemSettings autoload) ---
	var settings := root.get_node_or_null("/root/SystemSettings")
	if settings == null:
		print("  skip: SystemSettings autoload unavailable")
	else:
		var slow: float = story._text_reveal_chars_per_second()
		settings.set_slider("textspeed", 1.0)
		var fast: float = story._text_reveal_chars_per_second()
		settings.set_slider("textspeed", 0.0)
		var slowest: float = story._text_reveal_chars_per_second()
		if not (slowest < slow and slow < fast):
			_fail("reveal rate is not monotonic: slowest=%f slow=%f fast=%f" % [slowest, slow, fast])
			return
		print("  ok: reveal rate monotonic (%.1f < %.1f < %.1f cps)" % [slowest, slow, fast])
		settings.set_slider("textspeed", 0.5)

	# --- Instant mode always presents the full line ---
	story.set_trace_instant_mode(true)
	story.start(STORAGE, TARGET)
	await process_frame
	if story.reveal_active:
		_fail("instant mode must not leave a reveal in progress")
		return
	if story.text_label.visible_characters != -1:
		_fail("instant mode must show all characters, got %d" % story.text_label.visible_characters)
		return
	print("  ok: instant mode presents the complete line")

	# --- Save while revealing resumes at the recorded character ---
	# Ensure live mode, then start a fresh reveal of the current entry and take
	# the snapshot mid-reveal.  Headless frames are very short, so wait until a
	# whole character is on screen: resuming from a *sub*-character progress
	# legitimately shows zero characters and would make this check flaky.
	story.set_trace_instant_mode(false)
	story._show_text(story.current_entry.duplicate(true))
	await process_frame
	if not story.reveal_active:
		_fail("could not start a live reveal for the save test")
		return
	var snapshot := {}
	for _i in range(4000):
		await process_frame
		if not story.reveal_active:
			break
		if story.reveal_progress >= 2.0:
			snapshot = story.export_save_state()
			break
	if snapshot.is_empty():
		_fail("could not capture a mid-reveal save")
		return
	if float(snapshot.get("reveal_progress", -1.0)) <= 0.0:
		_fail("save did not record reveal progress")
		return
	var state := snapshot

	main_scene.show_story_screen()
	await process_frame
	var restored := _find_story(main_scene)
	if restored == null:
		_fail("could not create a second StoryPlayer")
		return
	restored.import_save_state(state)
	await process_frame
	if not restored.reveal_active:
		_fail("import did not resume the reveal")
		return
	if restored.text_label.visible_characters <= 0:
		_fail("resumed reveal has no visible characters")
		return
	if restored.text_label.visible_characters > int(float(state.get("reveal_progress", 0.0))):
		_fail("resumed reveal shows more characters than the save recorded")
		return
	print("  ok: save/load resumed the reveal at %d chars" % restored.text_label.visible_characters)

	# --- Legacy save (no field) presents the full line ---
	var legacy := state.duplicate(true)
	legacy.erase("reveal_progress")
	main_scene.show_story_screen()
	await process_frame
	var legacy_story := _find_story(main_scene)
	legacy_story.set_trace_instant_mode(false)
	legacy_story.import_save_state(legacy)
	await process_frame
	if legacy_story.reveal_active or legacy_story.text_label.visible_characters != -1:
		_fail("legacy save without reveal_progress must show the full line")
		return
	print("  ok: legacy save presents the complete line")

	print("OK: qa_story_typewriter passed all checks")
	quit(0)


func _find_story(main_scene: Node) -> Node:
	var script := load("res://scripts/story/story_player.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
