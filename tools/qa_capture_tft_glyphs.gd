extends SceneTree

const TftBitmapText := preload("res://scripts/ui/tft_bitmap_text.gd")


func _initialize() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("41272e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var text := TftBitmapText.new()
	text.name = "tft_probe"
	text.configure("【春樹】「別にどうでもいいとは思ってないけど、しょうがないだろ。" , Rect2(72, 72, 1600, 240), HORIZONTAL_ALIGNMENT_LEFT)
	canvas.add_child(text)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("TFT probe: glyphs=", TftBitmapText.glyphs.size(), " lines=", text.wrapped_lines.size())
	var image := root.get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://qa/screenshots/tft_glyph_probe.png")
	image.save_png(output)
	print("saved ", output)
	quit(0)
