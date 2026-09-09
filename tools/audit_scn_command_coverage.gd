extends SceneTree

const SCENARIO_ROOT := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn"
const OUTPUT := "res://qa/reports/scn_command_coverage.json"
const DIRECT_COMMANDS := ["envupdate", "delayrun"]
const DIRECT_CLASSES := ["bgm", "se", "loopse", "stage", "event", "character", "msgwin", "env"]

var commands: Dictionary = {}
var line_commands: Dictionary = {}
var line_samples: Dictionary = {}
var classes: Dictionary = {}
var lifecycle_classes: Dictionary = {}
var scenario_count := 0


func _initialize() -> void:
	var directory := DirAccess.open(SCENARIO_ROOT)
	if directory == null:
		_fail("SCN JSON directory was not found: " + SCENARIO_ROOT)
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_ROOT + "/" + file_name))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		scenario_count += 1
		_collect_line_commands(Dictionary(parsed))
		_walk(parsed)
	var report := {
		"format": "tenshin-scn-command-audit-v1",
		"scenario_count": scenario_count,
		"directly_interpreted_commands": DIRECT_COMMANDS,
		"directly_interpreted_classes": DIRECT_CLASSES,
		"array_leads": _sorted_counts(commands),
		"line_commands": _sorted_counts(line_commands),
		"line_samples": _sorted_values(line_samples),
		"object_classes": _sorted_counts(classes),
		"lifecycle_declared_classes": _sorted_counts(lifecycle_classes),
		"review_candidates": _review_candidates(),
	}
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write command audit: " + output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("OK: audited ", scenario_count, " scenario files; commands=", commands.size(), " classes=", classes.size())
	quit(0)


func _walk(value: Variant) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var object_class := str(dictionary.get("class", ""))
		if object_class != "":
			_count(classes, object_class)
		for nested in dictionary.values():
			_walk(nested)
		return
	if value is Array:
		var array: Array = value
		if not array.is_empty() and typeof(array[0]) == TYPE_STRING:
			var command := str(array[0])
			_count(commands, command)
			if command == "new" and array.size() >= 3:
				_count(lifecycle_classes, str(array[2]))
		for nested in array:
			_walk(nested)


func _collect_line_commands(scenario: Dictionary) -> void:
	for scene_value in scenario.get("scenes", []):
		if typeof(scene_value) != TYPE_DICTIONARY:
			continue
		for line_value in Dictionary(scene_value).get("lines", []):
			if line_value is Array:
				var line: Array = line_value
				if not line.is_empty() and typeof(line[0]) == TYPE_STRING:
					var command := str(line[0])
					_count(line_commands, command)
					if not line_samples.has(command):
						line_samples[command] = line.duplicate(true)


func _count(target: Dictionary, key: String) -> void:
	if key == "":
		return
	target[key] = int(target.get(key, 0)) + 1


func _sorted_counts(source: Dictionary) -> Dictionary:
	var keys: Array = source.keys()
	keys.sort()
	var result := {}
	for key_value in keys:
		var key := str(key_value)
		result[key] = source[key]
	return result


func _sorted_values(source: Dictionary) -> Dictionary:
	var keys: Array = source.keys()
	keys.sort()
	var result := {}
	for key_value in keys:
		var key := str(key_value)
		result[key] = source[key]
	return result


func _review_candidates() -> Dictionary:
	var unhandled_commands: Dictionary = {}
	for command_value in line_commands.keys():
		var command := str(command_value)
		if not DIRECT_COMMANDS.has(command) and command not in ["new", "del", "ren"]:
			unhandled_commands[command] = line_commands[command]
	var generic_visual_classes: Dictionary = {}
	for class_value in classes.keys():
		var object_class := str(class_value)
		if not DIRECT_CLASSES.has(object_class):
			generic_visual_classes[object_class] = classes[object_class]
	return {
		"commands_not_directly_interpreted": _sorted_counts(unhandled_commands),
		"classes_using_generic_visual_path": _sorted_counts(generic_visual_classes),
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
