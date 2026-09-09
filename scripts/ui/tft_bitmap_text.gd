extends Control
class_name TftBitmapText

# Kirikiri's font1_39.tft is the original MessageDefault face.  The layout
# and decoder below follow krkrZ/visual/PrerenderedFont.cpp directly.
const FONT_PATH := "res://assets/data/font/original_font1_39.tft"
const FONT_CELL_HEIGHT := 39
const LINE_STEP := 51
const FONT_ASCENT_OFFSET := 49
const EDGE_RADIUS := 2
const QUOTE_HANG_SOURCE := 36

static var font_bytes := PackedByteArray()
static var glyphs: Dictionary = {}
static var glyph_pixels: Dictionary = {}
static var glyph_textures: Dictionary = {}
static var transparent_texture: ImageTexture

var texture: Texture2D
var source_rect := Rect2()
var content := ""
var text_alignment := HORIZONTAL_ALIGNMENT_LEFT
var render_padding_x := 0
var wrapped_lines: Array = []


func _ready() -> void:
	# Backlog rows configure their text before being attached to the runtime
	# layer. A redraw queued while outside the scene tree is discarded by Godot,
	# so request it once this CanvasItem can actually draw. Deferring one turn
	# also places the request after Control's first layout pass.
	call_deferred("queue_redraw")


func configure(text_value: String, rect: Rect2, alignment: HorizontalAlignment) -> void:
	content = text_value
	source_rect = rect
	text_alignment = alignment
	render_padding_x = QUOTE_HANG_SOURCE if text_value.contains("「") else 0
	position = rect.position * Vector2(2.0 / 3.0, 2.0 / 3.0) - Vector2(render_padding_x * 2.0 / 3.0, 0.0)
	size = Vector2(rect.size.x + render_padding_x, rect.size.y) * Vector2(2.0 / 3.0, 2.0 / 3.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	_ensure_font_loaded()
	if glyphs.is_empty() or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	# Keep a transparent TextureRect surface for compatibility with callers,
	# but draw cached glyph textures directly through CanvasItem. The previous
	# implementation rebuilt a whole RGBA image and blended every glyph pixel
	# on the main thread for each Backlog row.
	if transparent_texture == null:
		var blank := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		blank.fill(Color.TRANSPARENT)
		transparent_texture = ImageTexture.create_from_image(blank)
	texture = transparent_texture
	# Wrapping is deterministic for this control. Keeping the layout avoids
	# rebuilding UTF-32 buffers while a Backlog row moves every frame.
	wrapped_lines = _wrap_lines(content, int(source_rect.size.x))
	# _draw intentionally never creates GPU textures. Ensure this text has its
	# glyphs before the first visible frame; repeated Backlog rows are cache hits.
	for codepoint in codepoints_in_text(content):
		prewarm_codepoint(codepoint)
	queue_redraw()


func _draw() -> void:
	if glyphs.is_empty() or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var scale := Vector2(2.0 / 3.0, 2.0 / 3.0)
	for line_info in wrapped_lines:
		var line: Dictionary = line_info
		var line_codes: PackedInt32Array = line.get("codes", PackedInt32Array())
		var line_y := int(line.get("y", 0))
		if line_y >= int(source_rect.size.y):
			break
		var width := int(line.get("width", 0))
		var cursor_x := render_padding_x
		if text_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			cursor_x = render_padding_x + maxi(0, int(source_rect.size.x) - width)
		elif text_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			cursor_x = render_padding_x + maxi(0, (int(source_rect.size.x) - width) / 2)
		var line_index := 0
		for codepoint in line_codes:
			var glyph: Dictionary = glyphs.get(codepoint, {})
			if glyph.is_empty():
				cursor_x += FONT_CELL_HEIGHT
				line_index += 1
				continue
			var glyph_x := cursor_x
			if line_index == 0 and codepoint == 0x300C:
				glyph_x -= QUOTE_HANG_SOURCE
			# Glyph allocation deliberately happens outside _draw(). Rendering may
			# be called in the same frame as wheel input; allocating a texture here
			# used to turn a scroll tick into a visible stall.
			var glyph_texture: Texture2D = glyph_textures.get(codepoint, null)
			if glyph_texture != null:
				var draw_position := Vector2(
					glyph_x + int(glyph.get("origin_x", 0)),
					line_y + FONT_ASCENT_OFFSET - int(glyph.get("origin_y", 33))
				) * scale
				var draw_size := glyph_texture.get_size() * scale
				# TextRender's outline is a circular two-pixel dilation. Submit the
				# repeated samples to the GPU instead of composing an RGBA outline on
				# the main thread when each glyph first appears in Backlog.
				for edge_offset_y in range(-EDGE_RADIUS, EDGE_RADIUS + 1):
					for edge_offset_x in range(-EDGE_RADIUS, EDGE_RADIUS + 1):
						if (edge_offset_x == 0 and edge_offset_y == 0) or edge_offset_x * edge_offset_x + edge_offset_y * edge_offset_y > EDGE_RADIUS * EDGE_RADIUS:
							continue
						draw_texture_rect(glyph_texture, Rect2(draw_position + Vector2(edge_offset_x, edge_offset_y) * scale, draw_size), false, Color.BLACK)
				draw_texture_rect(glyph_texture, Rect2(draw_position, draw_size), false)
			cursor_x += _glyph_advance(codepoint, line_index, glyph)
			line_index += 1


static func _glyph_texture(codepoint: int, glyph: Dictionary) -> Texture2D:
	if glyph_textures.has(codepoint):
		return glyph_textures[codepoint]
	var width := int(glyph.get("width", 0))
	var height := int(glyph.get("height", 0))
	if width <= 0 or height <= 0:
		return null
	# Keep only original glyph coverage in the cache. The circular outline is
	# emitted by _draw(), which avoids CPU alpha blending for every glyph.
	var rgba := PackedByteArray()
	rgba.resize(width * height * 4)
	var pixels := _glyph_pixels(codepoint, glyph)
	for pixel_index in range(pixels.size()):
		var rgba_index := pixel_index * 4
		rgba[rgba_index] = 255
		rgba[rgba_index + 1] = 255
		rgba[rgba_index + 2] = 255
		rgba[rgba_index + 3] = pixels[pixel_index]
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	var result := ImageTexture.create_from_image(image)
	glyph_textures[codepoint] = result
	return result


static func prewarm_codepoint(codepoint: int) -> bool:
	_ensure_font_loaded()
	if glyph_textures.has(codepoint):
		return true
	var glyph: Dictionary = glyphs.get(codepoint, {})
	if glyph.is_empty():
		return false
	return _glyph_texture(codepoint, glyph) != null


static func codepoints_in_text(text_value: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	var known: Dictionary = {}
	var utf32 := text_value.to_utf32_buffer()
	for byte_offset in range(0, utf32.size(), 4):
		var codepoint := int(utf32.decode_u32(byte_offset))
		if codepoint == 10 or known.has(codepoint):
			continue
		known[codepoint] = true
		result.append(codepoint)
	return result


func _wrap_lines(text_value: String, max_width: int) -> Array:
	var lines: Array = []
	var current := PackedInt32Array()
	var width := 0
	# TextRender stores a baseline and applies each TFT glyph's OriginY while
	# drawing. 49 source pixels reproduces the original first-line inset.
	var line_y := 0
	# Godot exposes the UTF-32 buffer as raw bytes. Decode one little-endian
	# codepoint at a time; iterating the buffer directly splits Japanese UTF-32
	# values into visible ASCII low/high bytes.
	var utf32 := text_value.to_utf32_buffer()
	for byte_offset in range(0, utf32.size(), 4):
		var codepoint := int(utf32.decode_u32(byte_offset))
		if codepoint == 10:
			lines.append({"codes": current.duplicate(), "width": width, "y": line_y})
			current = PackedInt32Array()
			width = 0
			line_y += LINE_STEP
			continue
		var glyph: Dictionary = glyphs.get(codepoint, {})
		# Wrapping uses the full TFT advance. The renderer applies the special
		# hanging-quote compression only when placing pixels, after line breaks
		# have already been decided.
		var advance := int(glyph.get("inc_x", FONT_CELL_HEIGHT))
		if not current.is_empty() and width + advance > max_width:
			lines.append({"codes": current.duplicate(), "width": width, "y": line_y})
			current = PackedInt32Array()
			width = 0
			line_y += LINE_STEP
		current.append(codepoint)
		width += advance
	if not current.is_empty() or lines.is_empty():
		lines.append({"codes": current.duplicate(), "width": width, "y": line_y})
	return lines


func _glyph_advance(codepoint: int, line_index: int, glyph: Dictionary) -> int:
	# The original TextRender treats an opening quote at line start as a
	# hanging mark: it is drawn to the left, while consuming only the small
	# punctuation gap before the first regular glyph.
	if line_index == 0 and codepoint == 0x300C:
		return 3
	return int(glyph.get("inc_x", FONT_CELL_HEIGHT))


static func _draw_glyph(image: Image, glyph: Dictionary, cursor_x: int, cursor_y: int) -> void:
	var width := int(glyph.get("width", 0))
	var height := int(glyph.get("height", 0))
	if width <= 0 or height <= 0:
		return
	var pixels: PackedByteArray = glyph.get("pixels", PackedByteArray())
	var draw_x := cursor_x + int(glyph.get("origin_x", 0))
	# TVP's OriginY is measured upward from the baseline. TextRender's first
	# baseline in this UI is 49px below the slot top, yielding a 16px top inset.
	var draw_y := cursor_y + FONT_ASCENT_OFFSET - int(glyph.get("origin_y", 33))
	for y in range(height):
		for x in range(width):
			var alpha := int(pixels[y * width + x])
			if alpha <= 0:
				continue
			_draw_edge(image, draw_x + x, draw_y + y, alpha)
	for y in range(height):
		for x in range(width):
			var alpha := int(pixels[y * width + x])
			if alpha > 0:
				_blend_pixel(image, draw_x + x, draw_y + y, Color(1.0, 1.0, 1.0, float(alpha) / 255.0))


static func _draw_edge(image: Image, x: int, y: int, alpha: int) -> void:
	var edge_alpha := float(alpha) / 255.0
	for offset_y in range(-EDGE_RADIUS, EDGE_RADIUS + 1):
		for offset_x in range(-EDGE_RADIUS, EDGE_RADIUS + 1):
			if offset_x == 0 and offset_y == 0:
				continue
			if offset_x * offset_x + offset_y * offset_y > EDGE_RADIUS * EDGE_RADIUS:
				continue
			_blend_pixel(image, x + offset_x, y + offset_y, Color(0.0, 0.0, 0.0, edge_alpha))


static func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var background := image.get_pixel(x, y)
	var output_alpha := color.a + background.a * (1.0 - color.a)
	if output_alpha <= 0.0:
		return
	var factor := 1.0 - color.a
	image.set_pixel(x, y, Color(
		(color.r * color.a + background.r * background.a * factor) / output_alpha,
		(color.g * color.a + background.g * background.a * factor) / output_alpha,
		(color.b * color.a + background.b * background.a * factor) / output_alpha,
		output_alpha
	))


static func _ensure_font_loaded() -> void:
	if not glyphs.is_empty():
		return
	font_bytes = FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(FONT_PATH))
	if font_bytes.size() < 36 or font_bytes.slice(0, 22).get_string_from_ascii() != "TVP pre-rendered font\u001a":
		push_error("Unable to load original TFT font: " + FONT_PATH)
		return
	if font_bytes[23] != 2:
		push_error("Unsupported original TFT encoding")
		return
	var count := int(font_bytes.decode_u32(24))
	var character_offset := int(font_bytes.decode_u32(28))
	var index_offset := int(font_bytes.decode_u32(32))
	for index in range(count):
		var character_position := character_offset + index * 2
		var item_position := index_offset + index * 20
		if item_position + 20 > font_bytes.size() or character_position + 2 > font_bytes.size():
			break
		var codepoint := int(font_bytes.decode_u16(character_position))
		var glyph_width := int(font_bytes.decode_u16(item_position + 4))
		var glyph_height := int(font_bytes.decode_u16(item_position + 6))
		glyphs[codepoint] = {
			"width": glyph_width,
			"height": glyph_height,
			"origin_x": int(font_bytes.decode_s16(item_position + 8)),
			"origin_y": int(font_bytes.decode_s16(item_position + 10)),
			"inc_x": int(font_bytes.decode_s16(item_position + 12)),
			"pixels_offset": int(font_bytes.decode_u32(item_position)),
		}


static func _decode_glyph(offset: int, width: int, height: int) -> PackedByteArray:
	var decoded := PackedByteArray()
	decoded.resize(maxi(0, width * height))
	if decoded.is_empty():
		return decoded
	var source := offset
	var destination := 0
	var last := 0
	while destination < decoded.size() and source < font_bytes.size():
		var value := int(font_bytes[source])
		source += 1
		if value >= 0x41:
			var repeat_count := value - 0x40
			for ignored in range(repeat_count):
				if destination >= decoded.size():
					break
				decoded[destination] = mini(255, last * 4)
				destination += 1
		else:
			last = value
			decoded[destination] = mini(255, value * 4)
			destination += 1
	return decoded


static func _glyph_pixels(codepoint: int, glyph: Dictionary) -> PackedByteArray:
	if glyph_pixels.has(codepoint):
		return glyph_pixels[codepoint]
	var pixels := _decode_glyph(
		int(glyph.get("pixels_offset", 0)),
		int(glyph.get("width", 0)),
		int(glyph.get("height", 0))
	)
	glyph_pixels[codepoint] = pixels
	return pixels
