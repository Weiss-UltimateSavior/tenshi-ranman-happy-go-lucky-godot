extends SceneTree

const TftBitmapText := preload("res://scripts/ui/tft_bitmap_text.gd")


func _initialize() -> void:
	var sample := "【佐奈】おはようございます、葵さん。大丈夫なの？兄さん、怪我はありませんか。"
	var codes := TftBitmapText.codepoints_in_text(sample)
	var start := Time.get_ticks_usec()
	for codepoint in codes:
		TftBitmapText.prewarm_codepoint(codepoint)
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	print("TFT warmup: glyphs=", codes.size(), " elapsed_ms=", snappedf(elapsed_ms, 0.01))
	quit(0)
