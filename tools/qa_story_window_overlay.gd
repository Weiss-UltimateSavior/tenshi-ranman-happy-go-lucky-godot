extends SceneTree


const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/st01_02.ks.json"
const SAMPLE_POINT := Vector2i(100, 650)


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var player: Control = main_scene.get_node("ScreenRoot").get_child(0)
	player.call("start", "st01_02.ks", "*0408_start")
	await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO))
	var source_scene: Dictionary = Array(Dictionary(parsed).get("scenes", []))[0]
	var expected_text := str(player.call("_text_entry", source_scene, 24).get("text", ""))
	for index in range(80):
		if str(Dictionary(player.get("current_entry")).get("text", "")) == expected_text:
			break
		player.call("advance")
		await process_frame
	await create_timer(0.15).timeout
	var window: TextureRect = player.get_node("MessageWindow/WindowBase")
	var expected_top := 750.0 * (1280.0 / 1920.0)
	if not is_equal_approx(window.position.y, expected_top) or not is_equal_approx(window.size.y, 420.0 * (1280.0 / 1920.0)):
		push_error("Window base PIMG geometry drifted: rect=%s" % Rect2(window.position, window.size))
		quit(1)
		return
	var material := window.material as ShaderMaterial
	if material == null or material.shader == null:
		push_error("Message window does not have the original Overlay shader material.")
		quit(1)
		return
	var color: Color = material.get_shader_parameter("overlay_color")
	var opacity := window.modulate.a
	if DisplayServer.get_name() == "headless":
		if color.is_equal_approx(Color.WHITE) or opacity <= 0.0:
			push_error("Message window Overlay parameters were not applied.")
			quit(1)
			return
		print("OK: message window has original Overlay composition parameters")
		quit(0)
		return
	window.visible = false
	await RenderingServer.frame_post_draw
	var background := root.get_viewport().get_texture().get_image().get_pixelv(SAMPLE_POINT)
	window.visible = true
	await RenderingServer.frame_post_draw
	var composited := root.get_viewport().get_texture().get_image().get_pixelv(SAMPLE_POINT)
	for layer_name in ["Stage", "Event", "ScriptEffects", "Characters"]:
		player.get_node("SceneCamera/" + layer_name).visible = false
	await RenderingServer.frame_post_draw
	var on_black := root.get_viewport().get_texture().get_image().get_pixelv(SAMPLE_POINT)
	var asset_pixel := window.texture.get_image().get_pixelv(Vector2i(150, 225))
	var expected_tint := _overlay(asset_pixel, color)
	var expected := expected_tint.lerp(background, 1.0 - opacity)
	print("window sample background=", background, " asset=", asset_pixel, " expected_tint=", expected_tint, " expected=", expected, " composited=", composited, " on_black=", on_black)
	quit(0)


func _overlay(base: Color, tint: Color) -> Color:
	return Color(
		_overlay_channel(base.r, tint.r),
		_overlay_channel(base.g, tint.g),
		_overlay_channel(base.b, tint.b),
		base.a
	)


func _overlay_channel(base_value: float, tint_value: float) -> float:
	return 2.0 * base_value * tint_value if base_value < 0.5 else 1.0 - 2.0 * (1.0 - base_value) * (1.0 - tint_value)
