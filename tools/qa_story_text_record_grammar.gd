extends SceneTree


const SCENARIO_ROOT := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn"

var scenario_count := 0
var scene_count := 0
var text_record_count := 0
var state_checkpoint_count := 0


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
			_fail("Invalid SCN JSON: " + file_name)
			return
		scenario_count += 1
		for scene_value in Dictionary(parsed).get("scenes", []):
			if typeof(scene_value) != TYPE_DICTIONARY:
				continue
			if not _verify_scene(file_name, Dictionary(scene_value)):
				return
	print("OK: verified ", text_record_count, " standalone text records and ", state_checkpoint_count, " array-form state checkpoints across ", scenario_count, " scenarios / ", scene_count, " scenes")
	quit(0)


func _verify_scene(file_name: String, scene: Dictionary) -> bool:
	scene_count += 1
	var texts: Array = scene.get("texts", [])
	var used_ids: Dictionary = {}
	for line_value in scene.get("lines", []):
		if _is_number(line_value):
			var text_id := int(line_value)
			if text_id < 1 or text_id > texts.size():
				_fail("Standalone text ID is outside the scene texts array: %s %s id=%d texts=%d" % [file_name, str(scene.get("label", "")), text_id, texts.size()])
				return false
			used_ids[text_id] = true
			text_record_count += 1
		elif line_value is Array:
			var row: Array = line_value
			if not row.is_empty() and _is_number(row[0]):
				state_checkpoint_count += 1
	for text_id in range(1, texts.size() + 1):
		if not used_ids.has(text_id):
			_fail("SCN text entry has no standalone playback record: %s %s id=%d" % [file_name, str(scene.get("label", "")), text_id])
			return false
	return true


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
