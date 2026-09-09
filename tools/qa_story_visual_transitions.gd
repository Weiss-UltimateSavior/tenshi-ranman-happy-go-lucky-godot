extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.call("show_story_screen")
	await process_frame
	var story: Node = main_scene.get_node("ScreenRoot").get_child(0)
	story.call("set_trace_instant_mode", false)
	var stage: TextureRect = story.get("stage_layer")

	# showdate.tjs displays date_full assets as straight-white alpha masks over
	# kokuban. Its universal rule must reveal opaque portions progressively; a
	# uniform fade makes the source chalk drawing visibly grey.
	story.call("_apply_script_object", "day_full", _date_object("0408", {
		"method": "universal",
		"rule": "rule_9",
		"sync": 1,
		"time": 1000,
	}))
	await process_frame
	var date_nodes: Dictionary = story.get("auxiliary_visual_nodes")
	var date_card := date_nodes.get("date_qa") as TextureRect
	if date_card == null or date_card.texture == null:
		_fail("Date-card transition did not create the source alpha texture.")
		return
	if date_card.modulate.r != 1.0 or date_card.modulate.g != 1.0 or date_card.modulate.b != 1.0:
		_fail("Date-card RGB modulation changed the authored chalk colour.")
		return
	var date_material := date_card.material as ShaderMaterial
	if date_material == null or date_material.get_shader_parameter("rule_texture") == null:
		_fail("Date-card transition did not use the original universal rule.")
		return
	await create_timer(0.55).timeout
	if float(date_material.get_shader_parameter("progress")) <= 0.0:
		_fail("Date-card universal reveal did not advance.")
		return
	await create_timer(0.60).timeout
	await process_frame
	if date_card.material != null:
		_fail("Date-card universal reveal retained a colour-altering material after completion.")
		return

	# ru_map01 uses this same rule/time shape when changing school_way_a to black.
	story.call("_apply_script_object", "stage", _stage_object("school_way_a", {}))
	await process_frame
	story.call("_apply_script_object", "stage", _stage_object("black", {
		"method": "universal",
		"rule": "rule_9",
		"sync": 1,
		"time": 1000,
	}))
	await process_frame
	var universal_overlay := _transition_overlay(stage)
	if universal_overlay == null:
		_fail("Universal transition did not retain the previous visual layer.")
		return
	var universal_material := universal_overlay.material as ShaderMaterial
	if universal_material == null:
		_fail("Universal transition did not attach a rule shader.")
		return
	if universal_material.get_shader_parameter("rule_texture") == null:
		_fail("Universal transition rule_9 was not loaded.")
		return
	if universal_material.shader == null or universal_material.shader.code.contains("source_color"):
		_fail("Universal transition rule image is not sampled as raw threshold data.")
		return
	var initial_progress := float(universal_material.get_shader_parameter("progress"))
	if initial_progress > 0.15:
		_fail("Universal transition did not begin from the authored source image.")
		return
	await create_timer(0.55).timeout
	var midway_progress := float(universal_material.get_shader_parameter("progress"))
	if midway_progress <= initial_progress or midway_progress >= 1.0:
		_fail("Universal transition rule progress did not animate through its duration.")
		return
	await create_timer(0.60).timeout
	await process_frame
	if _transition_overlay(stage) != null:
		_fail("Universal transition retained its previous visual after completion.")
		return

	story.call("_apply_script_object", "stage", _stage_object("blue_sky", {}))
	await process_frame
	story.call("_apply_script_object", "stage", _stage_object("black", {
		"method": "crossfade",
		"time": 180,
	}))
	await process_frame
	var crossfade_overlay := _transition_overlay(stage)
	if crossfade_overlay == null or crossfade_overlay.material is ShaderMaterial:
		_fail("Crossfade did not create an unshaded previous-image overlay.")
		return
	if crossfade_overlay.modulate.a >= 1.0:
		await create_timer(0.08).timeout
	if crossfade_overlay.modulate.a >= 1.0:
		_fail("Crossfade previous image alpha did not decrease.")
		return
	await create_timer(0.22).timeout
	await process_frame
	if _transition_overlay(stage) != null:
		_fail("Crossfade retained its previous visual after completion.")
		return

	story.call("_set_window_hidden", false)
	story.call("_apply_script_object", "stage", _stage_object("blue_sky", {}))
	story.call("_apply_script_object", "stage", _stage_object("black", {
		"method": "crossfade",
		"msgoff": "true",
		"time": 180,
	}))
	await process_frame
	var message_window: Control = story.get("window_layer")
	if message_window.visible:
		_fail("SCN msgoff did not hide the message layer during its transition.")
		return
	await create_timer(0.22).timeout
	if not message_window.visible:
		_fail("SCN msgoff did not restore the message layer after its transition.")
		return
	var first_hide: Variant = story.call("_hide_message_for_visual_transition", {"msgoff": true})
	var second_hide: Variant = story.call("_hide_message_for_visual_transition", {"msgoff": 1})
	if first_hide != true or second_hide != true:
		_fail("Concurrent SCN msgoff transitions were not registered.")
		return
	story.call("_finish_transition_message_hide", first_hide)
	if message_window.visible:
		_fail("The first concurrent SCN transition restored the message layer too early.")
		return
	story.call("_finish_transition_message_hide", second_hide)
	if not message_window.visible:
		_fail("The last concurrent SCN transition did not restore the message layer.")
		return

	story.call("_set_window_hidden", true)
	story.call("_apply_script_object", "stage", _stage_object("blue_sky", {}))
	story.call("_apply_script_object", "stage", _stage_object("black", {
		"method": "crossfade",
		"msgoff": "true",
		"time": 100,
	}))
	await create_timer(0.14).timeout
	if message_window.visible:
		_fail("SCN msgoff overrode a player-hidden message layer.")
		return
	story.call("_set_window_hidden", false)

	# Leaving a route while a transition is in flight must not leave its old
	# image above the newly started scenario.
	story.call("_apply_script_object", "stage", _stage_object("blue_sky", {}))
	story.call("_apply_script_object", "stage", _stage_object("black", {
		"method": "universal",
		"rule": "rule_9",
		"time": 1000,
	}))
	await process_frame
	if _transition_overlay(stage) == null:
		_fail("Restart-cleanup fixture did not create a transition overlay.")
		return
	story.call("start", "st01_01.ks", "")
	await process_frame
	if _transition_overlay(stage) != null:
		_fail("Starting a new scenario retained an old transition overlay.")
		return
	print("OK: source-shaped universal and crossfade visual transitions animate and clean up")
	quit(0)


func _stage_object(image_name: String, transition: Dictionary) -> Dictionary:
	var object := {
		"class": "stage",
		"name": "stage",
		"redraw": {"imageFile": {"file": image_name}},
		"showmode": 3,
	}
	if not transition.is_empty():
		object["trans"] = transition
	return object


func _date_object(image_name: String, transition: Dictionary) -> Dictionary:
	return {
		"class": "day_full",
		"name": "date_qa",
		"redraw": {"imageFile": {"file": image_name}},
		"showmode": 3,
		"trans": transition,
	}


func _transition_overlay(stage: TextureRect) -> TextureRect:
	var parent := stage.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(stage.name + "_TransitionPrevious") as TextureRect


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
