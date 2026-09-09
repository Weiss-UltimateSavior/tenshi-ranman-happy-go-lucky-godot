extends Control


func _ready() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.call_deferred("add_child", main_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	main_scene.show_story_screen()
	await get_tree().process_frame

	var story: Control = main_scene.get_node("ScreenRoot").get_child(0)
	for i in range(31):
		story.advance()
		await get_tree().process_frame
	await get_tree().process_frame

	var output_dir := "res://qa/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not DisplayServer.get_name().to_lower().contains("headless"):
		_save(output_dir + "/story_character_01.png")

	var bgm: AudioStreamPlayer = story.get_node("StoryBGM")
	var voice: AudioStreamPlayer = story.get_node("StoryVoice")
	var stage: TextureRect = story.get_node("Stage")
	print("stage position=", stage.position, " scale=", stage.scale, " size=", stage.size)
	var characters: Control = story.get_node("Characters")
	for character in characters.get_children():
		print("character node=", character.name, " position=", character.position, " scale=", character.scale, " size=", character.size)
		for part in character.get_children():
			print("character part=", part.name, " position=", part.position, " size=", part.size)
	var face_layer: Control = story.get_node("MessageWindow/MessageFace")
	for face in face_layer.get_children():
		print("message face=", face.name, " position=", face.position, " scale=", face.scale, " size=", face.size)
	print("story storage=", story.storage, " scene=", story.scene_index, " line=", story.line_index)
	print("bgm playing=", bgm.playing, " stream=", bgm.stream)
	print("voice playing=", voice.playing, " stream=", voice.stream)
	get_tree().quit(0)


func _save(path: String) -> void:
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
