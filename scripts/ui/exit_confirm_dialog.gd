extends "res://scripts/ui/hgl_ui_screen.gd"
class_name ExitConfirmDialog

signal confirmed(skip_next_time: bool)
signal cancelled

const DIALOG_UI := "res://assets/ui/compiled/screens/dialog.json"
const LAYER_DIR := "res://assets/ui/exported/dialog/layers/"
const SCALE := Vector2(1280.0 / 1920.0, 720.0 / 1080.0)
const WINDOW_RECT := Rect2(622, 299, 683, 404)
const MESSAGE_RECT := Rect2(808, 449, 300, 30)
const BUTTON_RECTS := {
	"yes": Rect2(703, 522, 247, 49),
	"no": Rect2(971, 522, 247, 49),
}
const BUTTON_BG := {
	"off": 5884,
	"over": 5887,
	"on": 5890,
}
const BUTTON_TEXT := {
	"yes": {"off": 5936, "over": 5936, "on": 5940},
	"no": {"off": 5937, "over": 5937, "on": 5941},
}
const CHECK_RECT := Rect2(853, 593, 214, 40)
const CHECK_BG := {
	"off": 5960,
	"over": 5960,
	"on": 5960,
	"push": 5964,
}
const CHECK_MARKER := {
	"on": 5961,
	"push": 5965,
}
const CHECK_TEXT := {
	"off": 5970,
	"over": 5976,
	"on": 5982,
	"push": 5976,
}

var skip_next_time := false
var button_visuals: Dictionary = {}
var check_visual: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# StoryPlayer's message window uses an absolute z index, while this dialog
	# is hosted by Main's higher-priority CanvasLayer. Keep the Control
	# z-index within Godot's CanvasItem range; 10000 is invalid and
	# prevents the dialog from being rendered reliably.
	z_index = 0
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	compiled_ui = load_json(DIALOG_UI)
	_build_dialog()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_sysse("cancel")
		cancelled.emit()


func _build_dialog() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_add_layer(5732, WINDOW_RECT, Vector2.ZERO, self)
	_add_layer(6003, MESSAGE_RECT, Vector2.ZERO, self)

	_build_button("yes")
	_build_button("no")
	_build_checkbox()
	_add_layer(5936, Rect2(793, 532, 69, 29), Vector2.ZERO, self)


func _build_button(button_name: String) -> void:
	var rect: Rect2 = BUTTON_RECTS[button_name]
	var visual := Control.new()
	visual.name = "ButtonVisual_" + button_name
	visual.position = rect.position * SCALE
	visual.size = rect.size * SCALE
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	button_visuals[button_name] = visual
	_update_button_visual(button_name, "off")
	_add_hit_button(rect, func() -> void:
		if button_name == "yes":
			AudioManager.play_sysse("ok3")
			confirmed.emit(skip_next_time)
		else:
			AudioManager.play_sysse("cancel")
			cancelled.emit()
	, func(state: String) -> void:
		_update_button_visual(button_name, state)
	, button_name.capitalize() + "Button")


func _build_checkbox() -> void:
	check_visual = Control.new()
	check_visual.name = "CheckVisual"
	check_visual.position = CHECK_RECT.position * SCALE
	check_visual.size = CHECK_RECT.size * SCALE
	check_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(check_visual)
	_update_checkbox_visual("off")
	_add_hit_button(CHECK_RECT, func() -> void:
		skip_next_time = not skip_next_time
		AudioManager.play_sysse("chg1")
		_update_checkbox_visual("over")
	, func(state: String) -> void:
		_update_checkbox_visual(state)
	, "SkipCheckbox")


func _update_button_visual(button_name: String, state: String) -> void:
	var visual: Control = button_visuals.get(button_name)
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var rect: Rect2 = BUTTON_RECTS[button_name]
	_add_layer(int(BUTTON_BG[state]), Rect2(703, 522, 247, 49), rect.position, visual)
	var text_id := int(Dictionary(BUTTON_TEXT[button_name])[state])
	var text_layer := _layer_by_id(text_id)
	_add_layer(text_id, rect_from_dict(text_layer.get("rect", {})), Vector2(703, 522), visual)
	if button_name == "yes":
		_add_yes_fallback_texture(visual)


func _add_yes_fallback_texture(parent: Control) -> void:
	var tex := TextureRect.new()
	tex.texture = load_texture(LAYER_DIR + "5936.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size = Vector2(69, 29) * SCALE
	tex.position = Vector2(90, 10) * SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)


func _update_checkbox_visual(state: String) -> void:
	if check_visual == null:
		return
	for child in check_visual.get_children():
		child.queue_free()
	var visual_state := "push" if skip_next_time and state == "on" else ("on" if skip_next_time else state)
	if not CHECK_BG.has(visual_state):
		visual_state = "off"
	_add_layer(int(CHECK_BG[visual_state]), Rect2(859, 599, 29, 29), CHECK_RECT.position, check_visual)
	if skip_next_time:
		var marker_state := "push" if state == "on" else "on"
		_add_layer(int(CHECK_MARKER[marker_state]), Rect2(866, 607, 17, 17), CHECK_RECT.position, check_visual)
	var text_state := "push" if skip_next_time and state == "on" else ("on" if skip_next_time else state)
	if not CHECK_TEXT.has(text_state):
		text_state = "off"
	var text_id := int(CHECK_TEXT[text_state])
	var text_layer := _layer_by_id(text_id)
	_add_layer(text_id, rect_from_dict(text_layer.get("rect", {})), CHECK_RECT.position, check_visual)


func _add_hit_button(source_rect: Rect2, pressed_callback: Callable, visual_callback: Callable, button_name: String = "") -> void:
	var button := Button.new()
	if button_name != "":
		button.name = button_name
	button.text = ""
	button.position = source_rect.position * SCALE
	button.size = source_rect.size * SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.mouse_entered.connect(func() -> void:
		visual_callback.call("over")
	)
	button.mouse_exited.connect(func() -> void:
		visual_callback.call("off")
	)
	button.button_down.connect(func() -> void:
		visual_callback.call("on")
	)
	button.button_up.connect(func() -> void:
		visual_callback.call("over" if button.is_hovered() else "off")
	)
	button.pressed.connect(func() -> void:
		pressed_callback.call()
	)
	add_child(button)


func _add_layer(layer_id: int, source_rect: Rect2, origin: Vector2, parent: Control) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = load_texture(LAYER_DIR + str(layer_id) + ".png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = (source_rect.position - origin) * SCALE
	tex.size = source_rect.size * SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)
	return tex


func _layer_by_id(layer_id: int) -> Dictionary:
	for layer in compiled_ui.get("layers", []):
		if int(layer.get("id", -999999)) == layer_id:
			return layer
	return {}
