extends SceneTree


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	await create_timer(8.0).timeout

	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	var max_ms := 0.0
	var total_ms := 0.0
	var max_call_ms := 0.0
	var total_call_ms := 0.0
	var slow_steps: Array[String] = []
	var count := 80
	for i in range(count):
		var started := Time.get_ticks_usec()
		story.advance()
		var call_elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		max_ms = maxf(max_ms, elapsed)
		total_ms += elapsed
		max_call_ms = maxf(max_call_ms, call_elapsed)
		total_call_ms += call_elapsed
		if elapsed > 120.0:
			slow_steps.append(str(i) + ":" + str(call_elapsed) + "/" + str(elapsed) + "ms@" + str(story.storage) + ":" + str(story.scene_index) + ":" + str(story.line_index))
	print("story_perf count=", count, " avg_ms=", total_ms / count, " max_ms=", max_ms)
	print("story_perf_call avg_ms=", total_call_ms / count, " max_ms=", max_call_ms)
	print("story_perf slow=", slow_steps)
	print("story storage=", story.storage, " scene=", story.scene_index, " line=", story.line_index)
	quit(0)
