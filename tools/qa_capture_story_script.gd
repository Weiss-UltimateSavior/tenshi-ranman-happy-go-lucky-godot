extends SceneTree

const StoryPlayer := preload("res://scripts/story/story_player.gd")


func _initialize() -> void:
	var story := StoryPlayer.new()
	root.add_child(story)
	await process_frame
	story.start("st01_02.ks", "*0408_start")
	for index in range(42):
		story.advance()
		await process_frame
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		var image := root.get_viewport().get_texture().get_image()
		var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
		DirAccess.make_dir_recursive_absolute(output_dir)
		image.save_png(output_dir + "/story_script_st01_02.png")
	print("OK: story script screenshot captured")
	quit(0)
