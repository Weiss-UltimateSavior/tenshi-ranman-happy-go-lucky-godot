extends "res://scripts/ui/hgl_ui_screen.gd"
class_name SaveLoadScreen

signal action_requested(action: String, data: Dictionary)

const FILE_UI := "res://assets/ui/compiled/screens/file.json"
const FILE_DATA_UI := "res://assets/ui/compiled/screens/file_data.json"
const SAVE_ROOT := "user://saves"
const TOTAL_PAGES := 10
const SLOTS_PER_PAGE := 12
const FILE_LAYER_DIR := "res://assets/ui/exported/file/layers/"
const DATA_LAYER_DIR := "res://assets/ui/exported/file_data/layers/"
const SCALE := Vector2(1280.0 / 1920.0, 720.0 / 1080.0)

const MODE_BACKGROUNDS := {
	"save": 4673,
	"load": 8394,
	"quickload": 8483,
}
const MODE_HEADLINES := {
	"save": [8341, 8338],
	"load": [8465, 8462],
	"quickload": [8554, 8551],
}
const TAB_TEXT := {
	"save": {"off": 7526, "over": 7540, "on": 7554},
	"load": {"off": 7528, "over": 7544, "on": 7558},
	"quickload": {"off": 7532, "over": 7548, "on": 7562},
}
const TAB_RECTS := {
	"save": Rect2(96, 99, 315, 73),
	"load": Rect2(412, 99, 315, 73),
	"quickload": Rect2(728, 99, 315, 73),
}
const TAB_BG := {
	"off": {"id": 4738, "rect": Rect2(97, 99, 313, 53)},
	"over": {"id": 7504, "rect": Rect2(96, 99, 315, 57)},
	"on": {"id": 4751, "rect": Rect2(97, 99, 313, 73)},
}
const TAB_ORIGIN := Vector2(96, 99)
const SIDE_BUTTONS := {
	"copy": {"y": 270, "text": 7822, "icon": {"off": 8649, "over": 8649, "on": 8653}},
	"swap": {"y": 443, "text": 7837, "icon": {"off": 8659, "over": 8659, "on": 8663}},
	"comment": {"y": 615, "text": 7855, "icon": {"off": 8669, "over": 8669, "on": 8673}},
	"delete": {"y": 788, "text": 7868, "icon": {"off": 8679, "over": 8679, "on": 8683}},
}
const SIDE_BG := {"off": 7777, "over": 7785, "on": 7792}
const BOTTOM_BUTTONS := {
	"title": {"rect": Rect2(1272, 998, 276, 56), "text": {"off": 5456, "over": 5460, "on": 5467}},
	"back": {"rect": Rect2(1553, 998, 276, 56), "text": {"off": 5409, "over": 5458, "on": 5465}},
}
const BOTTOM_BG := {"off": 5412, "over": 5422, "on": 5427}
const BOTTOM_ORIGIN := Vector2(1553, 998)
const PAGE_BUTTONS := {
	"first": {"x": 1068, "off": 8119, "over": 8235, "on": 8235},
	"prev_page": {"x": 1118, "off": 8124, "over": 8239, "on": 8239},
	"prev": {"x": 1168, "off": 8122, "over": 8238, "on": 8238},
	"next": {"x": 1495, "off": 8121, "over": 8237, "on": 8237},
	"next_page": {"x": 1545, "off": 8120, "over": 8236, "on": 8236},
	"last": {"x": 1595, "off": 8125, "over": 8240, "on": 8240},
	"minus": {"x": 1675, "off": 8244, "over": 8247, "on": 8249},
	"plus": {"x": 1830, "off": 8242, "over": 8246, "on": 8248},
}
const SLOT_RECTS := [
	Rect2(775, 208, 253, 248), Rect2(1041, 208, 253, 248), Rect2(1307, 208, 253, 248), Rect2(1573, 208, 253, 248),
	Rect2(775, 469, 253, 248), Rect2(1041, 469, 253, 248), Rect2(1307, 469, 253, 248), Rect2(1573, 469, 253, 248),
	Rect2(775, 730, 253, 248), Rect2(1041, 730, 253, 248), Rect2(1307, 730, 253, 248), Rect2(1573, 730, 253, 248),
]
const CARD_OFF := {"save": 6, "load": 29, "quickload": 56}
const CARD_OVER := {"save": 13, "load": 36, "quickload": 63}

var mode := "save"
var page := 0
var story_state: Dictionary = {}
var source_thumbnail: Image = null
var copied_slot: Dictionary = {}
var selected_slot := -1
var file_data: Dictionary = {}
var slots_layer: Control
var detail_layer: Control
var page_label: Label
var tab_visuals: Dictionary = {}
var side_visuals: Dictionary = {}
var bottom_visuals: Dictionary = {}
var page_visuals: Dictionary = {}
var slot_visuals: Array[Control] = []


func setup(start_mode: String, current_state: Dictionary = {}, thumbnail: Image = null) -> void:
	mode = _normalize_mode(start_mode)
	story_state = current_state.duplicate(true)
	source_thumbnail = thumbnail


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	compiled_ui = load_json(FILE_UI)
	file_data = load_json(FILE_DATA_UI)
	_build_static()
	_build_tabs()
	_build_page_controls()
	_build_slots()
	_build_side_buttons()
	_build_bottom_buttons()
	_build_detail_layer()
	_refresh_all()


func _input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed:
		get_viewport().set_input_as_handled()
		action_requested.emit("back", {})


func _build_static() -> void:
	_add_file_layer(MODE_BACKGROUNDS.get(mode, 4673), Rect2(0, 0, 1920, 1080), self, Vector2.ZERO)
	for layer_id in MODE_HEADLINES.get(mode, MODE_HEADLINES["save"]):
		var layer := _layer_by_id(layer_id)
		_add_file_layer(layer_id, rect_from_dict(layer.get("rect", {})), self, Vector2.ZERO)
	_add_file_layer(6863, Rect2(95, 270, 510, 668), self, Vector2.ZERO)
	_add_file_layer(6715, Rect2(123, 298, 454, 279), self, Vector2.ZERO)
	_add_file_layer(7612, Rect2(125, 595, 450, 202), self, Vector2.ZERO)
	_add_file_layer(8865, Rect2(160, 603, 88, 188), self, Vector2.ZERO)


func _build_tabs() -> void:
	for tab_name in ["save", "load", "quickload"]:
		var current_tab := str(tab_name)
		var visual := Control.new()
		var tab_rect: Rect2 = TAB_RECTS[current_tab]
		visual.name = "TabVisual_" + current_tab
		visual.position = tab_rect.position * SCALE
		visual.size = tab_rect.size * SCALE
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		tab_visuals[current_tab] = visual
		_add_hit_button(tab_rect, func() -> void:
			_set_mode(current_tab)
		, func(state: String) -> void:
			_update_tab_visual(current_tab, state)
		)


func _build_page_controls() -> void:
	for button_name in PAGE_BUTTONS.keys():
		var current_button := str(button_name)
		var data: Dictionary = PAGE_BUTTONS[current_button]
		var rect := Rect2(float(data["x"]), 84, 49, 48)
		var visual := Control.new()
		visual.name = "PageVisual_" + current_button
		visual.position = rect.position * SCALE
		visual.size = rect.size * SCALE
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		page_visuals[current_button] = visual
		_update_page_button_visual(current_button, "off")
		_add_hit_button(rect, func() -> void:
			_on_page_button(current_button)
		, func(state: String) -> void:
			_update_page_button_visual(current_button, state)
		)
	page_label = Label.new()
	page_label.position = Vector2(1706, 93) * SCALE
	page_label.size = Vector2(104, 28) * SCALE
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_label.add_theme_font_size_override("font_size", 15)
	page_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.94, 1.0))
	page_label.add_theme_color_override("font_shadow_color", Color(0.52, 0.22, 0.36, 0.85))
	page_label.add_theme_constant_override("shadow_offset_x", 1)
	page_label.add_theme_constant_override("shadow_offset_y", 1)
	page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page_label)


func _build_slots() -> void:
	slots_layer = Control.new()
	slots_layer.name = "Slots"
	slots_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slots_layer)
	for i in range(SLOTS_PER_PAGE):
		var slot_index := i
		var holder := Control.new()
		var slot_rect: Rect2 = SLOT_RECTS[slot_index]
		holder.name = "Slot_%02d" % slot_index
		holder.position = slot_rect.position * SCALE
		holder.size = slot_rect.size * SCALE
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots_layer.add_child(holder)
		slot_visuals.append(holder)
		_add_hit_button(slot_rect, func() -> void:
			_on_slot_pressed(slot_index)
		, func(state: String) -> void:
			_draw_slot(slot_index, state != "off")
		)


func _build_side_buttons() -> void:
	for button_name in SIDE_BUTTONS.keys():
		var current_button := str(button_name)
		var info: Dictionary = SIDE_BUTTONS[current_button]
		var rect := Rect2(632, float(info["y"]), 112, 152)
		var visual := Control.new()
		visual.name = "SideVisual_" + current_button
		visual.position = rect.position * SCALE
		visual.size = rect.size * SCALE
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		side_visuals[current_button] = visual
		_update_side_visual(current_button, "off")
		_add_hit_button(rect, func() -> void:
			_on_side_button(current_button)
		, func(state: String) -> void:
			_update_side_visual(current_button, state)
		)


func _build_bottom_buttons() -> void:
	for button_name in BOTTOM_BUTTONS.keys():
		var current_button := str(button_name)
		var info: Dictionary = BOTTOM_BUTTONS[current_button]
		var rect: Rect2 = info["rect"]
		var visual := Control.new()
		visual.name = "BottomVisual_" + current_button
		visual.position = rect.position * SCALE
		visual.size = rect.size * SCALE
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		bottom_visuals[current_button] = visual
		_update_bottom_visual(current_button, "off")
		_add_hit_button(rect, func() -> void:
			action_requested.emit(current_button, {})
		, func(state: String) -> void:
			_update_bottom_visual(current_button, state)
		)


func _build_detail_layer() -> void:
	detail_layer = Control.new()
	detail_layer.name = "Detail"
	detail_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_layer)


func _refresh_all() -> void:
	page_label.text = "%04d/%04d" % [page + 1, TOTAL_PAGES]
	for tab_name in tab_visuals.keys():
		_update_tab_visual(str(tab_name), "on" if tab_name == mode else "off")
	for i in range(SLOTS_PER_PAGE):
		_draw_slot(i, false)
	_draw_detail()


func _draw_slot(local_index: int, hover: bool) -> void:
	var holder := slot_visuals[local_index]
	for child in holder.get_children():
		child.queue_free()
	var global_slot := page * SLOTS_PER_PAGE + local_index + 1
	var save := _read_slot(global_slot)
	_add_data_layer(holder, 121, Rect2(4, 4, 255, 249), Vector2.ZERO)
	_add_data_layer(holder, CARD_OFF.get(mode, 6), Rect2(5, 4, 251, 245), Vector2.ZERO)
	if hover:
		_add_data_layer(holder, CARD_OVER.get(mode, 13), Rect2(5, 4, 251, 245), Vector2.ZERO)
	if selected_slot == global_slot:
		_add_data_layer(holder, 70, Rect2(5, 4, 251, 245), Vector2.ZERO)
	if save.is_empty():
		_add_data_layer(holder, 128, Rect2(73, 82, 112, 27), Vector2.ZERO)
	else:
		_add_slot_thumbnail(holder, save, Rect2(19, 36, 219, 123))
	_add_card_label(holder, "No.%04d-%02d" % [page + 1, local_index + 1], Rect2(16, 4, 104, 27), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_add_card_label(holder, str(save.get("chapter", "")), Rect2(143, 4, 104, 27), 13, Color(0.48, 0.24, 0.36), HORIZONTAL_ALIGNMENT_CENTER)
	if not save.is_empty():
		_add_card_label(holder, str(save.get("text", "")), Rect2(22, 162, 225, 58), 15, Color(0.42, 0.18, 0.31), HORIZONTAL_ALIGNMENT_LEFT)
		_add_card_label(holder, str(save.get("timestamp", "")), Rect2(61, 222, 185, 27), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_detail() -> void:
	for child in detail_layer.get_children():
		child.queue_free()
	var save := _read_slot(selected_slot)
	if save.is_empty():
		_add_file_layer(6715, Rect2(123, 298, 454, 279), detail_layer, Vector2.ZERO)
		_add_detail_text("No Image", Rect2(150, 338, 400, 190), 24, Color(0.95, 0.45, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
		return
	_add_detail_thumbnail(save, Rect2(150, 325, 400, 225))
	_add_detail_text(str(save.get("play_date", "")), Rect2(142, 620, 420, 40), 15, Color(0.60, 0.23, 0.40), HORIZONTAL_ALIGNMENT_LEFT)
	_add_detail_text(str(save.get("timestamp", "")), Rect2(142, 706, 420, 40), 15, Color(0.60, 0.23, 0.40), HORIZONTAL_ALIGNMENT_LEFT)
	_add_detail_text(str(save.get("text", "")), Rect2(142, 807, 420, 112), 16, Color(0.48, 0.18, 0.34), HORIZONTAL_ALIGNMENT_LEFT)


func _on_slot_pressed(local_index: int) -> void:
	var global_slot := page * SLOTS_PER_PAGE + local_index + 1
	selected_slot = global_slot
	match mode:
		"save":
			_save_slot(global_slot)
		"load", "quickload":
			var data := _read_slot(global_slot)
			if not data.is_empty():
				AudioManager.play_sysse("ok3")
				action_requested.emit("load_slot", data)
	_refresh_all()


func _on_side_button(button_name: String) -> void:
	match button_name:
		"copy":
			copied_slot = _read_slot(selected_slot)
		"swap":
			if not copied_slot.is_empty() and selected_slot > 0:
				_write_slot(selected_slot, copied_slot)
		"comment":
			var save := _read_slot(selected_slot)
			if not save.is_empty():
				save["text"] = "[Comment] " + str(save.get("text", "")).trim_prefix("[Comment] ")
				_write_slot(selected_slot, save)
		"delete":
			if selected_slot > 0:
				_delete_slot(selected_slot)
	_refresh_all()


func _on_page_button(button_name: String) -> void:
	match button_name:
		"first":
			page = 0
		"prev_page", "prev", "minus":
			page = maxi(0, page - 1)
		"next_page", "next", "plus":
			page = mini(TOTAL_PAGES - 1, page + 1)
		"last":
			page = TOTAL_PAGES - 1
	_refresh_all()


func _set_mode(next_mode: String) -> void:
	mode = _normalize_mode(next_mode)
	for child in get_children():
		child.queue_free()
	tab_visuals.clear()
	side_visuals.clear()
	bottom_visuals.clear()
	page_visuals.clear()
	slot_visuals.clear()
	_build_static()
	_build_tabs()
	_build_page_controls()
	_build_slots()
	_build_side_buttons()
	_build_bottom_buttons()
	_build_detail_layer()
	_refresh_all()


func _save_slot(slot: int) -> void:
	if story_state.is_empty():
		return
	var stamp := Time.get_datetime_string_from_system(false, true)
	var thumb_path := _slot_thumb_path(slot)
	if source_thumbnail != null:
		source_thumbnail.save_png(ProjectSettings.globalize_path(thumb_path))
	var entry: Dictionary = story_state.get("current_entry", {})
	var text := str(story_state.get("text", ""))
	if entry.has("text"):
		text = str(entry.get("text", text))
	var data := {
		"slot": slot,
		"mode": mode,
		"timestamp": stamp.replace("T", " "),
		"play_date": Time.get_date_string_from_system(),
		"chapter": _chapter_label(story_state),
		"text": text,
		"name": str(story_state.get("name", "")),
		"thumbnail": thumb_path,
		"state": story_state.duplicate(true),
	}
	_write_slot(slot, data)
	AudioManager.play_sysse("ok3")


func _write_slot(slot: int, data: Dictionary) -> void:
	var file := FileAccess.open(_slot_json_path(slot), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))


func _read_slot(slot: int) -> Dictionary:
	if slot <= 0:
		return {}
	var path := _slot_json_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _delete_slot(slot: int) -> void:
	var json_path := ProjectSettings.globalize_path(_slot_json_path(slot))
	var thumb_path := ProjectSettings.globalize_path(_slot_thumb_path(slot))
	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)
	if FileAccess.file_exists(thumb_path):
		DirAccess.remove_absolute(thumb_path)
	AudioManager.play_sysse("cancel")


func _slot_json_path(slot: int) -> String:
	return SAVE_ROOT + "/slot_%03d.json" % slot


func _slot_thumb_path(slot: int) -> String:
	return SAVE_ROOT + "/slot_%03d.png" % slot


func _chapter_label(state: Dictionary) -> String:
	var storage_name := str(state.get("storage", "")).get_basename()
	if storage_name == "":
		return ""
	return storage_name


func _add_slot_thumbnail(parent: Control, save: Dictionary, source_rect: Rect2) -> void:
	var path := str(save.get("thumbnail", ""))
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		_add_data_layer(parent, 39, Rect2(17, 34, 223, 127), Vector2.ZERO)
		return
	var tex := TextureRect.new()
	tex.texture = load_texture(path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.position = source_rect.position * SCALE
	tex.size = source_rect.size * SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)


func _add_detail_thumbnail(save: Dictionary, source_rect: Rect2) -> void:
	var path := str(save.get("thumbnail", ""))
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		_add_detail_text("No Image", source_rect, 24, Color(0.95, 0.45, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var tex := TextureRect.new()
	tex.texture = load_texture(path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.position = source_rect.position * SCALE
	tex.size = source_rect.size * SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(tex)


func _add_card_label(parent: Control, text: String, source_rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := Label.new()
	label.text = text
	label.position = source_rect.position * SCALE
	label.size = source_rect.size * SCALE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _add_detail_text(text: String, source_rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := Label.new()
	label.text = text
	label.position = source_rect.position * SCALE
	label.size = source_rect.size * SCALE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(label)


func _add_hit_button(source_rect: Rect2, pressed_callback: Callable, visual_callback: Callable) -> void:
	var button := Button.new()
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
		if visual_callback.is_valid():
			visual_callback.call("over")
	)
	button.mouse_exited.connect(func() -> void:
		if visual_callback.is_valid():
			visual_callback.call("off")
	)
	button.button_down.connect(func() -> void:
		if visual_callback.is_valid():
			visual_callback.call("on")
	)
	button.button_up.connect(func() -> void:
		if visual_callback.is_valid():
			visual_callback.call("over" if button.is_hovered() else "off")
	)
	button.pressed.connect(func() -> void:
		AudioManager.play_sysse("chg1")
		pressed_callback.call()
	)
	add_child(button)


func _update_tab_visual(tab_name: String, state: String) -> void:
	if tab_name == mode and state == "off":
		state = "on"
	var visual: Control = tab_visuals.get(tab_name)
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var rect: Rect2 = TAB_RECTS[tab_name]
	var bg_slot: Dictionary = TAB_BG[state]
	var bg_rect: Rect2 = bg_slot["rect"]
	_add_file_layer(int(bg_slot["id"]), bg_rect, visual, TAB_ORIGIN)
	var text_id := int(TAB_TEXT[tab_name][state])
	var text_layer := _layer_by_id(text_id)
	_add_file_layer(text_id, rect_from_dict(text_layer.get("rect", {})), visual, TAB_ORIGIN)


func _update_side_visual(button_name: String, state: String) -> void:
	var visual: Control = side_visuals.get(button_name)
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var origin := Vector2(632, float(SIDE_BUTTONS[button_name]["y"]))
	_add_file_layer(int(SIDE_BG[state]), Rect2(632, 270, 112, 152), visual, Vector2(632, 270))
	var icon_data: Dictionary = SIDE_BUTTONS[button_name]["icon"]
	var icon_id := int(icon_data[state])
	var icon_layer := _layer_by_id(icon_id)
	_add_file_layer(icon_id, rect_from_dict(icon_layer.get("rect", {})), visual, Vector2(632, 270))
	var text_id := int(SIDE_BUTTONS[button_name]["text"])
	var text_layer := _layer_by_id(text_id)
	_add_file_layer(text_id, rect_from_dict(text_layer.get("rect", {})), visual, Vector2(632, 270))
	visual.position = origin * SCALE


func _update_bottom_visual(button_name: String, state: String) -> void:
	var visual: Control = bottom_visuals.get(button_name)
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var info: Dictionary = BOTTOM_BUTTONS[button_name]
	var bg_layer := _layer_by_id(int(BOTTOM_BG[state]))
	_add_file_layer(int(BOTTOM_BG[state]), rect_from_dict(bg_layer.get("rect", {})), visual, BOTTOM_ORIGIN)
	var text_id := int(Dictionary(info["text"])[state])
	var text_layer := _layer_by_id(text_id)
	_add_file_layer(text_id, rect_from_dict(text_layer.get("rect", {})), visual, BOTTOM_ORIGIN)


func _update_page_button_visual(button_name: String, state: String) -> void:
	var visual: Control = page_visuals.get(button_name)
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var data: Dictionary = PAGE_BUTTONS[button_name]
	var origin := Vector2(float(data["x"]), 84)
	_add_file_layer(int({"off": 8030, "over": 8055, "on": 8080}[state]), Rect2(1068, 84, 49, 48), visual, Vector2(1068, 84))
	var icon_id := int(data[state])
	var icon_layer := _layer_by_id(icon_id)
	_add_file_layer(icon_id, rect_from_dict(icon_layer.get("rect", {})), visual, Vector2(1068, 84))
	visual.position = origin * SCALE


func _add_file_layer(layer_id: int, source_rect: Rect2, parent: Control, origin: Vector2) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = load_texture(FILE_LAYER_DIR + str(layer_id) + ".png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = (source_rect.position - origin) * SCALE
	tex.size = source_rect.size * SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)
	return tex


func _add_data_layer(parent: Control, layer_id: int, source_rect: Rect2, origin: Vector2) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = load_texture(DATA_LAYER_DIR + str(layer_id) + ".png")
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
	for layer in file_data.get("layers", []):
		if int(layer.get("id", -999999)) == layer_id:
			return layer
	return {}


func _normalize_mode(value: String) -> String:
	if value == "qload" or value == "quick":
		return "quickload"
	if value == "load":
		return "load"
	return "save"
