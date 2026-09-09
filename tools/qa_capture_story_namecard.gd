extends SceneTree


const SCENARIO := "E:/Galgame/天神乱漫 Happy GO Lucky!!/Extractor_Output/scn/st01_02.ks.json"
const EXPECTED_EFFECT := "name_sana"


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
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse the original scenario JSON.")
		quit(1)
		return

	var source_scene: Dictionary = Dictionary(parsed).get("scenes", [])[0]
	var expected_text := str(player.call("_text_entry", source_scene, 24).get("text", ""))
	for index in range(80):
		var current: Dictionary = player.get("current_entry")
		if str(current.get("text", "")) == expected_text:
			await create_timer(0.35).timeout
			var nodes: Dictionary = player.get("auxiliary_visual_nodes")
			var effect := nodes.get("effect") as TextureRect
			if effect == null or effect.texture == null or effect.texture.get_size() != Vector2(543, 180):
				push_error("The target name_sana effect was not active with the original line.")
				quit(1)
				return
			var expected_position := Vector2(1172, 562) * (1280.0 / 1920.0)
			if not effect.position.is_equal_approx(expected_position):
				push_error("name_sana position mismatch: expected %s, got %s" % [expected_position, effect.position])
				quit(1)
				return
			_save_capture()
			print("namecard position=", effect.position, " size=", effect.size, " scale=", effect.scale, " z=", effect.z_index, " alpha=", effect.modulate.a)
			print("stage position=", player.get_node("Stage").position, " size=", player.get_node("Stage").size, " scale=", player.get_node("Stage").scale)
			var characters: Control = player.get_node("Characters")
			if characters.get_child_count() != 1:
				push_error("The original target line did not create exactly one stand character.")
				quit(1)
				return
			for character in characters.get_children():
				# `100%` in envinit.tjs maps to zorder=133. The JSON carries the
				# equivalent zpos, so character zorderZoom changes the 0.5 base
				# stand scale to 0.5 * 1.33 = 0.665 on the 1280 canvas.
				if not character.scale.is_equal_approx(Vector2(0.665, 0.665)):
					push_error("KAG zorderZoom was not applied to the stand: %s" % character.scale)
					quit(1)
					return
				print("character name=", character.name, " position=", character.position, " size=", character.size, " scale=", character.scale)
				for part in character.get_children():
					print("character part=", part.name, " position=", part.position, " size=", part.size)
			quit(0)
			return
		player.call("advance")
		await process_frame

	push_error("The original name_sana effect was not reached.")
	quit(1)


func _save_capture() -> void:
	var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.get_viewport().get_texture().get_image().save_png(output_dir + "/story_namecard.png")
	print("saved ", output_dir + "/story_namecard.png")
