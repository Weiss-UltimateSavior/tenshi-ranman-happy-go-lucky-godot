extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", true)
	story.call("_apply_script_object", "event", {
		"name": "ev",
		"showmode": 3,
		"redraw": {"imageFile": {"file": "blue_sky"}},
		"action": [["raster", 10], ["rastercycle", 5000], ["rasterlines", 200]],
	})
	var event_layer: TextureRect = story.get("event_layer")
	var raster: Variant = event_layer.get_meta("script_raster", {})
	if not (raster is Dictionary):
		_fail("Raster script properties were not recorded on the event layer.")
		return
	var settings: Dictionary = raster
	if not is_equal_approx(float(settings.get("amount", -1.0)), 10.0) or not is_equal_approx(float(settings.get("cycle_ms", -1.0)), 5000.0) or not is_equal_approx(float(settings.get("lines", -1.0)), 200.0):
		_fail("Original raster/rastercycle/rasterlines values changed before reaching the shader.")
		return
	var material := event_layer.material as ShaderMaterial
	if material == null or not is_equal_approx(float(material.get_shader_parameter("raster_amount_px")), 10.0):
		_fail("Raster-enabled event did not receive a raster shader material.")
		return
	print("OK: original event raster directives reach the visual shader unchanged")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
