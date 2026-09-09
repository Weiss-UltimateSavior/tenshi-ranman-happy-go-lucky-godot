extends SceneTree

const TftBitmapText := preload("res://scripts/ui/tft_bitmap_text.gd")


func _initialize() -> void:
	var sample := "【佐奈】おはようございます、葵さん。大丈夫なの？兄さん、怪我はありませんか。"
	var checked: Dictionary = {}
	for codepoint in TftBitmapText.codepoints_in_text(sample):
		if checked.has(codepoint):
			continue
		checked[codepoint] = true
		if not TftBitmapText.prewarm_codepoint(codepoint):
			_fail("Missing TFT glyph U+%04X" % codepoint)
			return
		var glyph_texture: Texture2D = TftBitmapText.glyph_textures.get(codepoint, null)
		if glyph_texture == null:
			_fail("TFT texture was not created for U+%04X" % codepoint)
			return
		var image := glyph_texture.get_image()
		var visible_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.0:
					visible_pixels += 1
		if visible_pixels == 0:
			_fail("TFT glyph has no visible pixels: U+%04X" % codepoint)
			return
	print("OK: validated ", checked.size(), " original TFT glyph textures")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
