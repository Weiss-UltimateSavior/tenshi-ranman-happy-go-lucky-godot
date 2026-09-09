extends SceneTree

const REFERENCE_ENTRIES := [

	{"name": "春樹", "text": "「別にどうでもいいとは思ってないけど、しょうがないだろ。気にしてたら胃に穴が開くぞ」", "voice": ""},
	{"name": "女の子", "text": "「もう！　またそんなことを言って」", "voice": ""},
	{"name": "春樹", "text": "「それより佐奈、ハンカチとか持ってるか？　とりあえず、拭けるところだけでも拭いておきたいんだけど」", "voice": ""},
	{"name": "女の子", "text": "「あ、はい。持ってますけど……どうしてもって、兄さんがどうしてもって言うなら拭いてあげないこともないですよ」", "voice": ""},
	{"name": "", "text": "一歩近づいて、取り出したハンカチで濡れた顔を拭おうとする我が妹、千歳佐奈。", "voice": ""},
]

func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.show_story_screen()
	await process_frame
	var story := _find_script_node(main_scene.get_node("ScreenRoot"), load("res://scripts/story/story_player.gd"))
	if story == null:
		quit(1)
		return
	main_scene.show_backlog_screen()
	await process_frame
	var backlog := _find_backlog(main_scene.get_node("ScreenRoot"))
	if backlog == null:
		quit(1)
		return
	# The reference capture is at the end of a longer history. Keep five
	# preceding records so the visible rows and the scrollbar state match it.
	var test_entries: Array = []
	for index in range(5):
		test_entries.append({"name": "", "text": "test history %d" % index, "voice": ""})
	test_entries.append_array(REFERENCE_ENTRIES)
	backlog.set_backlog_entries(test_entries)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://qa/screenshots/backlog_reference_visual.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	image.save_png(output)
	print("saved ", output)
	quit(0)


func _find_script_node(parent: Node, script_resource: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script_resource:
			return child
	return null


func _find_backlog(parent: Node) -> Node:
	for child in parent.get_children():
		if child.get("screen_name") == "backlog":
			return child
	return null
