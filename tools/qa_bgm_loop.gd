extends SceneTree

## BGM loop regression (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §2):
## `.sli` sidecars must yield the original loop range, and the loop-ready
## BGM copies must be truncated at `From` so loop_offset = To reproduces it.
##
## Run: godot --headless --script res://tools/qa_bgm_loop.gd

const PARSER := preload("res://scripts/story/sli_parser.gd")
const LOOPS_JSON := "res://assets/audio/bgm/loops.json"
const SAMPLE_RATE := 44100.0


func _initialize() -> void:
	var failures := 0

	# --- 1. Parser on the shipped sidecar ---
	var parser = PARSER.new()
	var ok: bool = parser.load_for_audio("res://assets/bgm/bgm54.ogg")
	if not ok:
		push_error("  FAIL: bgm54.ogg.sli did not parse")
		failures += 1
	else:
		var loop: Dictionary = parser.loop_seconds(SAMPLE_RATE)
		# From=4917760 To=1268096 @44100
		var expect_begin := 1268096.0 / SAMPLE_RATE
		var expect_end := 4917760.0 / SAMPLE_RATE
		if absf(float(loop.get("begin", 0.0)) - expect_begin) > 0.01:
			push_error("  FAIL: loop begin %.4f != %.4f" % [float(loop.get("begin", 0.0)), expect_begin])
			failures += 1
		elif absf(float(loop.get("end", 0.0)) - expect_end) > 0.01:
			push_error("  FAIL: loop end %.4f != %.4f" % [float(loop.get("end", 0.0)), expect_end])
			failures += 1
		else:
			print("  ok: bgm54 sli loop = [%.2fs, %.2fs]" % [float(loop["begin"]), float(loop["end"])])

	# --- 2. Every shipped loop-ready copy matches loops.json ---
	var loops_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(LOOPS_JSON))
	var loops: Variant = JSON.parse_string(loops_text)
	if typeof(loops) != TYPE_DICTIONARY:
		push_error("  FAIL: loops.json missing or invalid (run tools/prepare_bgm_loops.py)")
		_finish(failures)
		return
	var tracks: Dictionary = Dictionary(loops).get("tracks", {})
	print("  ok: loops.json covers %d tracks" % tracks.size())

	var checked := 0
	for track_name in tracks.keys():
		var entry: Dictionary = tracks[track_name]
		if str(entry.get("source", "")) != "sli":
			continue
		var ogg_path := "res://assets/audio/bgm/%s.ogg" % str(track_name)
		if not FileAccess.file_exists(ogg_path):
			push_error("  FAIL: loop-ready copy missing: " + ogg_path)
			failures += 1
			continue
		var stream := AudioStreamOggVorbis.load_from_file(
			ProjectSettings.globalize_path(ogg_path))
		if stream == null:
			push_error("  FAIL: cannot load " + ogg_path)
			failures += 1
			continue
		# The truncated copy must be at least as long as loop_end (From) and the
		# loop range must be positive.
		var length := stream.get_length()
		var loop_end := float(entry.get("loop_end", 0.0))
		if length + 0.05 < loop_end:
			push_error("  FAIL: %s length %.2fs < loop_end %.2fs" % [track_name, length, loop_end])
			failures += 1
		checked += 1
		if checked >= 8:
			break
	if failures == 0:
		print("  ok: sampled %d loop-ready copies have the expected length" % checked)

	_finish(failures)


func _finish(failures: int) -> void:
	if failures == 0:
		print("OK: qa_bgm_loop passed all checks")
		quit(0)
	else:
		push_error("qa_bgm_loop had %d failures" % failures)
		quit(1)
