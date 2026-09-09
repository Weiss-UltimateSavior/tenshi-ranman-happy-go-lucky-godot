extends SceneTree

const GRAYSCALE_SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru03_04.ks.json"
const GAMMA_SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru03_05.ks.json"
const TONE_SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/ru01_03.ks.json"
const OVERLAY_SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/st01_04.ks.json"


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)

	var grayscale := _find_object(GRAYSCALE_SCENARIO, "stage", "doGrayScale")
	var gamma := _find_object(GAMMA_SCENARIO, "event", "adjustGamma")
	var tone := _find_object(TONE_SCENARIO, "character", "tc_overcolor")
	var overlay := _find_object(OVERLAY_SCENARIO, "stage", "overcolor")
	if grayscale.is_empty() or gamma.is_empty() or tone.is_empty() or overlay.is_empty():
		_fail("Could not locate source redraw-effect samples.")
		return

	story.call("_apply_script_object", "stage", grayscale)
	var stage: TextureRect = story.get("stage_layer")
	if not _shader_bool(stage.material, "apply_grayscale"):
		_fail("Original doGrayScale did not reach the stage shader.")
		return

	story.call("_apply_script_object", "event", gamma)
	var event_layer: TextureRect = story.get("event_layer")
	var gamma_value: Vector3 = _shader_vector(event_layer.material, "gamma_value")
	if not gamma_value.is_equal_approx(Vector3(2.1, 1.2, 1.0)):
		_fail("Original adjustGamma RGB values were not preserved.")
		return

	story.call("_apply_script_object", "stage", overlay)
	if not is_equal_approx(float((stage.material as ShaderMaterial).get_shader_parameter("overlay_strength")), 0.28):
		_fail("Original overcolor strength was not preserved.")
		return

	# Validate the PSD-part path directly from the source character's imageFile
	# payload. Resource composition is asynchronous and is outside this shader
	# parameter test.
	var character := Control.new()
	var textured_part := TextureRect.new()
	character.add_child(textured_part)
	var tone_file: Dictionary = Dictionary(Dictionary(tone.get("redraw", {})).get("imageFile", {}))
	story.call("_apply_character_redraw_effects", character, tone_file)
	if not (textured_part.material is ShaderMaterial):
		_fail("Character redraw material was not attached to PSD image parts.")
		return
	if not is_equal_approx(float((textured_part.material as ShaderMaterial).get_shader_parameter("overlay_strength")), 0.2):
		_fail("Original tc_overcolor strength was not preserved.")
		return
	if not is_equal_approx(float((textured_part.material as ShaderMaterial).get_shader_parameter("light_brightness")), -32.0 / 255.0):
		_fail("Original tc_light brightness was not preserved.")
		return
	character.free()
	print("OK: SCN grayscale, gamma, overcolor, and light redraw operations reach story layers")
	quit(0)


func _find_object(path: String, expected_class: String, command_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _find_nested(parsed, expected_class, command_name)


func _find_nested(value: Variant, expected_class: String, command_name: String) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if str(dictionary.get("class", "")) == expected_class:
			var image_file: Dictionary = Dictionary(Dictionary(dictionary.get("redraw", {})).get("imageFile", {}))
			for operation in image_file.get("redraw", []):
				if operation is Array and not Array(operation).is_empty() and str(Array(operation)[0]) == command_name:
					return dictionary
		for nested in dictionary.values():
			var result := _find_nested(nested, expected_class, command_name)
			if not result.is_empty():
				return result
	elif value is Array:
		for nested in Array(value):
			var result := _find_nested(nested, expected_class, command_name)
			if not result.is_empty():
				return result
	return {}


func _shader_bool(material: Material, parameter: String) -> bool:
	return material is ShaderMaterial and bool((material as ShaderMaterial).get_shader_parameter(parameter))


func _shader_vector(material: Material, parameter: String) -> Vector3:
	if material is ShaderMaterial:
		var value: Variant = (material as ShaderMaterial).get_shader_parameter(parameter)
		if value is Vector3:
			return value
	return Vector3.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
