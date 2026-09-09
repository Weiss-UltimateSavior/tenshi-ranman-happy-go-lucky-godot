extends SceneTree

## Unit regression for scripts/story/branch_flags.gd
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 1). Run:
##   godot --headless --script res://tools/qa_branch_flags.gd

var failures := 0


func _initialize() -> void:
	var script := load("res://scripts/story/branch_flags.gd")
	var flags = script.new()

	# Synthetic table: single, chained, and multi-triple weights.
	var loaded: bool = flags.load_table_dictionary({
		"flags": {
			"acc_sak": [["ST04_04*0429_select", 1, 1]],
			"map1_sak": [["ST02_03*MAP_move_1", 1, 1]],
			"weighted": [["A", 1, 1], ["B", 2, 2]],
		},
	}, "synthetic")
	_expect(loaded, "synthetic table loads")
	_expect(not flags.flag_table.is_empty(), "table populated")

	# Unset flags evaluate false (original void-truthiness).
	_expect(not flags.check("acc_sak"), "unset flag is false")
	_expect(flags.flag_value("acc_sak") == 0, "unset flag sums to 0")

	# Matching value -> true; wrong value -> false.
	flags.set_branch("ST04_04*0429_select", 1)
	_expect(flags.check("acc_sak"), "matching value is true")
	flags.set_branch("ST04_04*0429_select", 2)
	_expect(not flags.check("acc_sak"), "overwritten value flips the flag false")

	# && chains require every name.
	flags.set_branch("ST02_03*MAP_move_1", 1)
	flags.set_branch("ST04_04*0429_select", 1)
	_expect(flags.check("map1_sak && acc_sak"), "&& chain true when all match")
	flags.set_branch("ST02_03*MAP_move_1", 3)
	_expect(not flags.check("map1_sak && acc_sak"), "&& chain false when one fails")

	# Unknown names are false with a warning, never an error.
	_expect(not flags.check("totally_unknown_name"), "unknown name is false")

	# Multi-triple weights: sum of matching weights must exceed zero.
	_expect(not flags.check("weighted"), "weighted unset is false")
	flags.set_branch("A", 1)
	_expect(flags.check("weighted"), "weighted partial match sums > 0")
	flags.set_branch("B", 9)
	_expect(flags.check("weighted"), "weighted stays true on non-matching second triple")

	# Real compiled table (tools/compile_branch_flags.py output) must load and
	# contain the five eval names used by the shipped scenarios.
	var real = script.new()
	_expect(not real.flag_table.is_empty(), "compiled branch_flags.json loads")
	for required in ["acc_aoi", "acc_sak", "acc_san", "map2_rur", "map4_wak"]:
		_expect(real.flag_table.has(required), "compiled table has %s" % required)

	# Round trip through the save-state representation must stay JSON-safe.
	flags.set_branch("ST02_03*MAP_move_1", 1)
	var snapshot: Dictionary = flags.to_dict()
	var round_trip = script.new()
	round_trip.from_dict(snapshot)
	_expect(int(round_trip.scene_values.get("ST02_03*MAP_move_1", -1)) == 1, "to/from_dict round trip")
	var encoded := JSON.stringify(round_trip.to_dict())
	_expect(not encoded.is_empty(), "snapshot is JSON-safe")

	if failures == 0:
		print("OK: qa_branch_flags passed all checks")
		quit(0)
	else:
		push_error("qa_branch_flags had %d failures" % failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
