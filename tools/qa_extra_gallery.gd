extends SceneTree

## Extra gallery list regression (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §3):
## the CG / music / scene lists come from the authored CSVs, honour gallery
## unlock progress, and page through the 16-cell / 7-row layouts.
##
## Run: godot --headless --script res://tools/qa_extra_gallery.gd

const GalleryLists := preload("res://scripts/story/gallery_lists.gd")
const GalleryProgress := preload("res://scripts/story/gallery_progress.gd")


func _initialize() -> void:
	var failures := 0

	# --- List sources ---
	var cg: Array = GalleryLists.cg_entries()
	var sound: Array = GalleryLists.sound_entries()
	var scene: Array = GalleryLists.scene_entries()
	var expect_cg := 65
	var expect_sound := 40
	var expect_scene := 8
	if cg.size() != expect_cg:
		push_error("  FAIL: cglist entries = %d (expected %d)" % [cg.size(), expect_cg])
		failures += 1
	else:
		print("  ok: cglist yields %d CG groups" % cg.size())
	if sound.size() != expect_sound:
		push_error("  FAIL: soundlist entries = %d (expected %d)" % [sound.size(), expect_sound])
		failures += 1
	else:
		print("  ok: soundlist yields %d tracks" % sound.size())
	if scene.size() != expect_scene:
		push_error("  FAIL: scenelist entries = %d (expected %d)" % [scene.size(), expect_scene])
		failures += 1
	else:
		print("  ok: scenelist yields %d replay entries" % scene.size())

	# Spot-check parsed fields (the CSV has decorative tabs inside fields).
	var first_cg: Dictionary = cg[0] if not cg.is_empty() else {}
	if str(first_cg.get("thumb", "")) != "thum_EV0102A":
		push_error("  FAIL: first CG thumb = %r" % str(first_cg.get("thumb", "")))
		failures += 1
	elif str(first_cg.get("group", "")) != "EV0102A":
		push_error("  FAIL: first CG group = %r" % str(first_cg.get("group", "")))
		failures += 1
	else:
		print("  ok: CG rows parse thumb/group independently")

	var first_sound: Dictionary = sound[0] if not sound.is_empty() else {}
	if not str(first_sound.get("title", "")).begins_with("メチャ恋"):
		push_error("  FAIL: first sound title = %r" % str(first_sound.get("title", "")))
		failures += 1
	else:
		print("  ok: soundlist row carries file + title")

	var first_scene: Dictionary = scene[0] if not scene.is_empty() else {}
	if str(first_scene.get("movie", "")) != "OP":
		push_error("  FAIL: first scene movie = %r" % str(first_scene.get("movie", "")))
		failures += 1
	else:
		print("  ok: scenelist row carries movie name")

	# --- Unlock gating ---
	var gallery = GalleryProgress.new()
	gallery.clear_all()
	var locked_group := str(first_cg.get("group", ""))
	if gallery.is_unlocked("cg", locked_group):
		push_error("  FAIL: fresh gallery must start locked")
		failures += 1
	gallery.unlock("cg", locked_group)
	if not gallery.is_unlocked("cg", locked_group):
		push_error("  FAIL: unlock did not apply")
		failures += 1
	else:
		print("  ok: CG entries gate on unlock progress")

	# --- Pagination arithmetic (16 cells / 7 rows) ---
	var cg_pages: int = (cg.size() + 15) / 16
	var sound_pages: int = (sound.size() + 6) / 7
	if cg_pages != 5:
		push_error("  FAIL: CG page count = %d (expected 5 for %d groups)" % [cg_pages, cg.size()])
		failures += 1
	else:
		print("  ok: CG grid needs %d pages of 16 cells" % cg_pages)
	if sound_pages != 6:
		push_error("  FAIL: sound page count = %d (expected 6 for %d tracks)" % [sound_pages, sound.size()])
		failures += 1
	else:
		print("  ok: music list needs %d pages of 7 rows" % sound_pages)

	# --- Extra screen builds with the runtime lists (headless scene test) ---
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_static_ui_screen("extra")
	await process_frame
	var screen = _find_screen(main_scene, "extra")
	if screen == null:
		push_error("  FAIL: extra screen was not created")
		failures += 1
	else:
		var grid_cells := 0
		var sound_rows := 0
		var scene_rows := 0
		for child in screen.get_children():
			var child_name := str(child.name)
			if child_name.begins_with("extra_cg_cell_"):
				grid_cells += 1
			elif child_name.begins_with("extra_sound_row_"):
				sound_rows += 1
			elif child_name.begins_with("extra_scene_row_"):
				scene_rows += 1
		if grid_cells != 16:
			push_error("  FAIL: CG grid built %d cells (expected 16)" % grid_cells)
			failures += 1
		else:
			print("  ok: CG grid built %d cells" % grid_cells)
		if sound_rows <= 0:
			push_error("  FAIL: music list built no rows")
			failures += 1
		else:
			print("  ok: music list built %d rows" % sound_rows)
		if scene_rows <= 0:
			push_error("  FAIL: scene list built no rows")
			failures += 1
		else:
			print("  ok: scene list built %d rows" % scene_rows)

	if failures == 0:
		print("OK: qa_extra_gallery passed all checks")
		quit(0)
	else:
		push_error("qa_extra_gallery had %d failures" % failures)
		quit(1)


func _find_screen(main_scene: Node, name: String) -> Node:
	var script := load("res://scripts/ui/hgl_static_screen.gd")
	for child in main_scene.get_node("ScreenRoot").get_children():
		if child.get_script() == script and str(child.get("screen_name")) == name:
			return child
	return null
