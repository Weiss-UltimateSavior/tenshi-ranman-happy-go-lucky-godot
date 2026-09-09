extends "res://scripts/ui/hgl_ui_screen.gd"

signal action_requested(action: String)

const COMPILED_TITLE := "res://assets/ui/compiled/title_screen.json"
const TITLE_LAYER_DIR := "res://assets/ui/exported/title/layers/"
const TITLE_BG_LAYER_DIR := "res://assets/ui/exported/title_bg/layers/"


func _init() -> void:
	name = "TitleScreen"
	super()


func _ready() -> void:
	compiled_ui = load_json(COMPILED_TITLE)
	_build_placeholder()
	AudioManager.play_bgm("bgm54")


func _build_placeholder() -> void:
	var bg := ColorRect.new()
	bg.name = "ReferencePlaceholder"
	bg.color = Color(0.06, 0.07, 0.075, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_add_title_background()
	_add_title_buttons()


func _add_title_background() -> void:
	for layer in compiled_ui.get("background", []):
		var path := layer_path(TITLE_BG_LAYER_DIR, layer["id"])
		if file_exists(path):
			add_texture(self, path, rect_from_dict(layer["rect"]), "bg_" + str(layer["name"]))


func _add_title_buttons() -> void:
	var title_ui: Dictionary = compiled_ui.get("title_ui", {})
	for button in title_ui.get("buttons", []):
		_add_title_button(button)


func _add_title_button(data: Dictionary) -> void:
	var action := str(data.get("name", ""))
	var area := scaled_rect(rect_from_dict(data["area"]))
	var button := TextureButton.new()
	button.name = "btn_" + action
	button.position = area.position
	button.size = area.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = action
	button.disabled = not _title_action_enabled(action)
	add_child(button)

	var bg := TextureRect.new()
	bg.name = "bg"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var bg_slots: Dictionary = data.get("bg", {})
	var bg_off: Dictionary = bg_slots.get("off", {})
	var bg_rect := scaled_rect(rect_from_dict(bg_off.get("rect", {})))
	bg.position = _slot_position(bg_rect)
	bg.size = bg_rect.size
	button.add_child(bg)

	var text := TextureRect.new()
	text.name = "text"
	text.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	text.stretch_mode = TextureRect.STRETCH_SCALE
	var text_slots: Dictionary = data.get("text", {})
	var text_off: Dictionary = text_slots.get("off", {})
	var text_rect := scaled_rect(rect_from_dict(text_off.get("rect", {})))
	text.position = _slot_position(text_rect)
	text.size = text_rect.size
	button.add_child(text)

	_set_button_state(button, data, "off")
	_set_disabled_visual(button, button.disabled)
	if not button.disabled:
		button.mouse_entered.connect(func() -> void:
			AudioManager.play_title_enter(action)
			_set_button_state(button, data, "over")
		)
		button.mouse_exited.connect(func() -> void: _set_button_state(button, data, "off"))
		button.button_down.connect(func() -> void: _set_button_state(button, data, "on"))
		button.button_up.connect(func() -> void: _set_button_state(button, data, "over"))
		button.pressed.connect(func() -> void: _on_title_action(action))


func _set_button_state(button: TextureButton, data: Dictionary, state: String) -> void:
	var bg: TextureRect = button.get_node("bg")
	var text: TextureRect = button.get_node("text")
	var bg_slots: Dictionary = data.get("bg", {})
	var text_slots: Dictionary = data.get("text", {})
	var bg_state: Dictionary = bg_slots.get(state, bg_slots.get("off", {}))
	var text_state: Dictionary = text_slots.get(state, text_slots.get("off", {}))
	var bg_rect := scaled_rect(rect_from_dict(bg_state.get("rect", {})))
	var text_rect := scaled_rect(rect_from_dict(text_state.get("rect", {})))
	bg.texture = load_texture(layer_path(TITLE_LAYER_DIR, bg_state.get("id", "")))
	bg.position = _slot_position(bg_rect)
	bg.size = bg_rect.size
	text.texture = load_texture(layer_path(TITLE_LAYER_DIR, text_state.get("id", "")))
	text.position = _slot_position(text_rect)
	text.size = text_rect.size


func _slot_position(slot_rect: Rect2) -> Vector2:
	var title_ui: Dictionary = compiled_ui.get("title_ui", {})
	return slot_position(title_ui, slot_rect)


func _on_title_action(action: String) -> void:
	AudioManager.play_title_click(action)
	action_requested.emit(action)


func _title_action_enabled(action: String) -> bool:
	if action == "continue":
		return _has_save_data()
	return true


func _set_disabled_visual(button: TextureButton, disabled: bool) -> void:
	if not disabled:
		button.modulate = Color.WHITE
		return
	button.modulate = Color(0.48, 0.48, 0.62, 0.72)


func _has_save_data() -> bool:
	var save_dir := DirAccess.open("user://saves")
	if save_dir == null:
		return false
	save_dir.list_dir_begin()
	while true:
		var file_name := save_dir.get_next()
		if file_name == "":
			break
		if save_dir.current_is_dir():
			continue
		if file_name.begins_with("slot_") and file_name.ends_with(".json"):
			return true
	return false
