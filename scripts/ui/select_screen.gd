extends "res://scripts/ui/hgl_ui_screen.gd"

## Selection overlay for SCN `scenes[].selects`. Two visual modes:
## - dialog choices (options carry `text`/`render`): stacked buttons reusing the
##   dialog.json tri-state background layers with dynamically rendered text;
## - map choices (`selectInfo._type == 2`): full-screen background image with
##   name+place buttons in a placeholder layout (pixel calibration is P3).
## Pixel-perfect placement is deliberately out of scope for P0
## (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 4).

signal selected(index: int)

const DIALOG_LAYERS := "res://assets/ui/exported/dialog/layers/"
const BUTTON_BG := {"off": 5884, "over": 5887, "on": 5890}
const BUTTON_SOURCE_SIZE := Vector2(247, 49)
const DIALOG_FONT_SIZE := 17
const MAP_BUTTON_SIZE := Vector2(400, 72)

var _options: Array = []
var _info: Dictionary = {}
var _bg_path := ""
var _button_visuals: Array[NinePatchRect] = []
var _buttons: Array[Button] = []


func setup(options: Array, info: Dictionary, bg_path: String) -> void:
	_options = options
	_info = info
	_bg_path = bg_path


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dialog_mode: bool = not _options.is_empty() and Dictionary(_options[0]).has("text")
	if dialog_mode:
		_build_dialog()
	else:
		_build_map()


func _build_background_layer() -> void:
	var background := TextureRect.new()
	background.name = "MapBackground"
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := _resolve_background()
	if texture != null:
		background.texture = texture
	else:
		# Placeholder surface keeps the choice functional when the named
		# background cannot be resolved (P3 will calibrate real art).
		var fallback := ColorRect.new()
		fallback.color = Color(0.05, 0.05, 0.07)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)
	add_child(background)


func _resolve_background() -> Texture2D:
	if _bg_path == "":
		return null
	if _bg_path.begins_with("res://"):
		return load_texture(_bg_path)
	return _load_absolute(_bg_path)


func _load_absolute(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("Select background failed to load: " + path)
		return null
	return ImageTexture.create_from_image(image)


func _build_dialog() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Original behaviour: every choice button widens to the longest text so no
	# label ever spills past the pill background.
	var button_size := _dialog_button_size()
	var spacing := 12.0
	var total_height := _options.size() * button_size.y + (_options.size() - 1) * spacing
	var start_y := (size.y - total_height) * 0.5
	for index in range(_options.size()):
		var option: Dictionary = _options[index]
		_add_select_button(index, str(option.get("text", "")), "", Vector2(
			(size.x - button_size.x) * 0.5,
			start_y + index * (button_size.y + spacing)
		), button_size)


func _dialog_button_size() -> Vector2:
	var height := BUTTON_SOURCE_SIZE.y * ui_scale().y
	var font := _message_font()
	var text_width := 0.0
	for option_value in _options:
		var text := str(Dictionary(option_value).get("text", ""))
		if font != null:
			text_width = maxf(text_width, font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, DIALOG_FONT_SIZE).x)
		else:
			text_width = maxf(text_width, text.length() * DIALOG_FONT_SIZE)
	# Keep the source pill width as the minimum and add breathing room.
	return Vector2(maxf(BUTTON_SOURCE_SIZE.x * ui_scale().x, text_width + 64.0), height)


func _build_map() -> void:
	_build_background_layer()
	var button_size := MAP_BUTTON_SIZE * ui_scale()
	var spacing := 10.0
	var total_height := _options.size() * button_size.y + (_options.size() - 1) * spacing
	var start_y := (size.y - total_height) * 0.5
	for index in range(_options.size()):
		var option: Dictionary = _options[index]
		var caption := str(option.get("name", ""))
		var place := str(option.get("place", ""))
		_add_select_button(index, caption, place, Vector2(
			(size.x - button_size.x) * 0.5,
			start_y + index * (button_size.y + spacing)
		), button_size)


func _add_select_button(index: int, caption: String, subcaption: String, position: Vector2, button_size: Vector2) -> void:
	var button := Button.new()
	button.name = "Select%d" % index
	button.position = position
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.mouse_entered.connect(func() -> void:
		AudioManager.play_sysse("sel1")
		_set_button_state(index, "over")
	)
	button.mouse_exited.connect(func() -> void: _set_button_state(index, "off"))
	button.button_down.connect(func() -> void: _set_button_state(index, "on"))
	button.button_up.connect(func() -> void: _set_button_state(index, "over"))
	button.pressed.connect(func() -> void:
		AudioManager.play_sysse("ok1")
		selected.emit(index)
	)
	add_child(button)
	_buttons.append(button)

	var visual := NinePatchRect.new()
	visual.name = "Visual%d" % index
	visual.texture = load_texture(DIALOG_LAYERS + str(BUTTON_BG["off"]) + ".png")
	# The pill art has rounded ends; nine-patch keeps them intact while the
	# middle stretches to the measured text width.
	visual.patch_margin_left = 36
	visual.patch_margin_right = 36
	visual.patch_margin_top = 18
	visual.patch_margin_bottom = 18
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.size = button_size
	button.add_child(visual)
	_button_visuals.append(visual)

	if caption != "":
		var label := Label.new()
		label.text = caption
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", _message_font())
		label.add_theme_font_size_override("font_size", DIALOG_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.16, 0.1, 0.12))
		if subcaption == "":
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			button.add_child(label)
		else:
			label.position = Vector2(0, button_size.y * 0.12)
			label.size = Vector2(button_size.x, button_size.y * 0.48)
			button.add_child(label)
	if subcaption != "":
		var sublabel := Label.new()
		sublabel.text = subcaption
		sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sublabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sublabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sublabel.add_theme_font_override("font", _message_font())
		sublabel.add_theme_font_size_override("font_size", 13)
		sublabel.add_theme_color_override("font_color", Color(0.32, 0.24, 0.28))
		sublabel.position = Vector2(0, button_size.y * 0.55)
		sublabel.size = Vector2(button_size.x, button_size.y * 0.4)
		button.add_child(sublabel)


func _set_button_state(index: int, state: String) -> void:
	if index < 0 or index >= _button_visuals.size():
		return
	var key: String = BUTTON_BG.get(state, BUTTON_BG["off"])
	_button_visuals[index].texture = load_texture(DIALOG_LAYERS + str(key) + ".png")


func _message_font() -> Font:
	if SystemSettings != null:
		var font := SystemSettings.get_message_font()
		if font != null:
			return font
	return null
