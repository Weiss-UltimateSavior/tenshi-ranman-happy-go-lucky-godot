extends SceneTree

## Gallery unlock regression (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §3):
## first-time CG/BGM presentation marks the entry unlocked, repeats do not,
## and the state round-trips through to_dict/from_dict (save payload).
##
## Run: godot --headless --script res://tools/qa_gallery_progress.gd

const GalleryProgress := preload("res://scripts/story/gallery_progress.gd")


func _initialize() -> void:
	var failures := 0
	var gallery = GalleryProgress.new()
	gallery.clear_all()

	# --- First unlock changes state; repeat does not ---
	if not gallery.unlock("cg", "ev0101a"):
		push_error("  FAIL: first unlock should report a change")
		failures += 1
	else:
		print("  ok: first CG unlock reports a change")
	if gallery.unlock("cg", "ev0101a"):
		push_error("  FAIL: repeat unlock should report no change")
		failures += 1
	else:
		print("  ok: repeat unlock is a no-op")

	# --- Queries ---
	if not gallery.is_unlocked("cg", "ev0101a"):
		push_error("  FAIL: unlocked CG not reported")
		failures += 1
	if gallery.is_unlocked("cg", "ev9999z"):
		push_error("  FAIL: unknown CG reported as unlocked")
		failures += 1
	if gallery.unlock_count("cg") != 1:
		push_error("  FAIL: unlock_count = %d (expected 1)" % gallery.unlock_count("cg"))
		failures += 1
	else:
		print("  ok: queries reflect exactly one unlocked CG")

	# --- Invalid kinds are ignored, not crashing ---
	if gallery.unlock("nonsense", "x"):
		push_error("  FAIL: unknown kind must not unlock")
		failures += 1
	if gallery.unlocked_keys("nonsense").size() != 0:
		push_error("  FAIL: unknown kind must have no keys")
		failures += 1
	else:
		print("  ok: unknown kinds are ignored")

	# --- Case-insensitive keys (SCN lowercase vs cglist uppercase) ---
	var cased = GalleryProgress.new()
	cased.clear_all()
	cased.unlock("cg", "EV0102A")          # authored casing
	if not cased.is_unlocked("cg", "ev0102a"):
		push_error("  FAIL: lowercase query must see an uppercase unlock")
		failures += 1
	else:
		print("  ok: unlock keys are case-insensitive")
	cased.unlock("cg", "ev0102f")          # same entry, different case
	if cased.unlock_count("cg") != 1:
		push_error("  FAIL: case variants created %d entries (expected 1)" % cased.unlock_count("cg"))
		failures += 1
	else:
		print("  ok: case variants collapse to one entry")
	cased.clear_all()

	# --- BGM and scene sections are independent ---
	gallery.unlock("bgm", "bgm54")
	gallery.unlock("scene", "st01_02")
	if gallery.is_unlocked("cg", "bgm54") or not gallery.is_unlocked("bgm", "bgm54"):
		push_error("  FAIL: sections are not independent")
		failures += 1
	else:
		print("  ok: cg/bgm/scene sections are independent")

	# --- Persistence across instances (save payload) ---
	var payload: Dictionary = gallery.to_dict()
	var restored = GalleryProgress.new()
	restored.from_dict(payload)
	if not restored.is_unlocked("cg", "ev0101a") \
			or not restored.is_unlocked("bgm", "bgm54") \
			or not restored.is_unlocked("scene", "st01_02"):
		push_error("  FAIL: from_dict did not restore all sections")
		failures += 1
	else:
		print("  ok: to_dict/from_dict round-trips all sections")

	# --- File persistence ---
	var reloaded = GalleryProgress.new()
	reloaded.load_progress()
	if not reloaded.is_unlocked("cg", "ev0101a"):
		push_error("  FAIL: progress did not persist to user://gallery.cfg")
		failures += 1
	else:
		print("  ok: progress persists to gallery.cfg")

	# Restore a clean state for the real game.
	gallery.clear_all()

	if failures == 0:
		print("OK: qa_gallery_progress passed all checks")
		quit(0)
	else:
		push_error("qa_gallery_progress had %d failures" % failures)
		quit(1)
