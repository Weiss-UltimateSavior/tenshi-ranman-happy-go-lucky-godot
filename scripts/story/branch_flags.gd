extends RefCounted

## Branch flag state machine, mirroring the original scnchart.tjs semantics:
## SetBranchFlags(key, value) writes a scene-selection value, and
## CheckBranchFlags("a && b") expands each name through the compiled flag
## table (assets/ui/compiled/branch_flags.json) into a sum of weights over
## `scene_values[tag] == value` comparisons. An unknown or never-set name
## evaluates to false, matching the original's void-truthiness.

const DEFAULT_TABLE_PATH := "res://assets/ui/compiled/branch_flags.json"

var scene_values: Dictionary = {}
var flag_table: Dictionary = {}
var table_source := ""


func _init() -> void:
	load_default_table()


## Load the compiled expansion table produced by tools/compile_branch_flags.py.
## Failure keeps an empty table: every check() then reports false loudly via
## push_warning instead of silently routing the story.
func load_default_table() -> bool:
	return load_table_dictionary(_read_table_file(DEFAULT_TABLE_PATH), DEFAULT_TABLE_PATH)


func load_table_dictionary(table: Dictionary, source: String) -> bool:
	var flags: Variant = table.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY or Dictionary(flags).is_empty():
		push_warning("Branch flag table has no flags section: " + source)
		return false
	flag_table = {}
	for name_value in Dictionary(flags):
		var entries: Array = []
		for triple in Dictionary(flags)[name_value]:
			if typeof(triple) != TYPE_ARRAY or Array(triple).size() < 3:
				push_warning("Branch flag %s has a malformed triple" % str(name_value))
				continue
			entries.append({
				"tag": str(Array(triple)[0]),
				"value": int(Array(triple)[1]),
				"weight": int(Array(triple)[2]),
			})
		flag_table[str(name_value)] = entries
	table_source = source
	return true


func set_branch(key: String, value: int) -> void:
	scene_values[key] = value


## Evaluate a CheckBranchFlags expression. Accepts both the bare inner form
## (`name && name`) and the full call form as stored in SCN JSON
## (`CheckBranchFlags("name && name")`). Every name must resolve to a nonzero
## sum; unknown names count as zero (false), matching the original runtime.
func check(expression: String) -> bool:
	var expression_clean := expression.strip_edges()
	if expression_clean == "":
		return true
	var wrapper := RegEx.create_from_string('^CheckBranchFlags\\("(.*)"\\)$')
	var wrapped := wrapper.search(expression_clean)
	if wrapped != null:
		expression_clean = wrapped.get_string(1).strip_edges()
	if expression_clean == "":
		return true
	for raw_name in expression_clean.split("&&", false):
		if flag_value(raw_name.strip_edges()) <= 0:
			return false
	return true


func flag_value(name: String) -> int:
	var entries: Array = flag_table.get(name, [])
	if entries.is_empty():
		push_warning("CheckBranchFlags: unknown flag name: " + name)
		return 0
	var total := 0
	for entry_value in entries:
		var entry: Dictionary = entry_value
		if scene_values.has(entry["tag"]) and int(scene_values[entry["tag"]]) == int(entry["value"]):
			total += int(entry["weight"])
	return total


func to_dict() -> Dictionary:
	return scene_values.duplicate(true)


func from_dict(values: Dictionary) -> void:
	scene_values.clear()
	for key in values:
		scene_values[str(key)] = int(values[key])


func _read_table_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Branch flag table missing: " + path + " (run tools/compile_branch_flags.py)")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Branch flag table invalid JSON: " + path)
		return {}
	return parsed
