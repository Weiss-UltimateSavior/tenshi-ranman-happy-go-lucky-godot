extends Control

const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const HglStaticScreen := preload("res://scripts/ui/hgl_static_screen.gd")
const SaveLoadScreenScene := preload("res://scripts/ui/save_load_screen.gd")
const ExitConfirmDialogScene := preload("res://scripts/ui/exit_confirm_dialog.gd")
const StoryPlayer := preload("res://scripts/story/story_player.gd")

const OPTION_PAGES := [
	"option_0simple",
	"option_1display",
	"option_2game1",
	"option_3game2",
	"option_4text",
	"option_5sound",
	"option_6dialog",
	"option_7mouse",
	"option_8keyboard1",
	"option_9gamepad",
]
const UI_SCALE := 2.0 / 3.0
const SYSTEM_BUTTON_ORIGIN := Vector2(1553, 998)
const SYSTEM_BUTTON_BG_SLOTS := {
	"off": {"id": 5412, "rect": Rect2(1554, 998, 275, 56)},
	"over": {"id": 5422, "rect": Rect2(1555, 998, 272, 62)},
	"on": {"id": 5427, "rect": Rect2(1555, 998, 272, 62)},
}
const SYSTEM_BUTTON_TEXT_SLOTS := {
	"reset": {
		"off": {"id": 5455, "rect": Rect2(1621, 1013, 142, 23)},
		"over": {"id": 5459, "rect": Rect2(1620, 1012, 144, 25)},
		"on": {"id": 5466, "rect": Rect2(1620, 1012, 144, 25)},
	},
	"title": {
		"off": {"id": 5456, "rect": Rect2(1601, 1014, 181, 22)},
		"over": {"id": 5460, "rect": Rect2(1600, 1013, 183, 24)},
		"on": {"id": 5467, "rect": Rect2(1600, 1013, 183, 24)},
	},
	"back": {
		"off": {"id": 5409, "rect": Rect2(1610, 1012, 163, 25)},
		"over": {"id": 5458, "rect": Rect2(1610, 1012, 163, 25)},
		"on": {"id": 5465, "rect": Rect2(1610, 1012, 163, 25)},
	},
}

@onready var screen_root: Control = $ScreenRoot
@onready var modal_layer: CanvasLayer = $ModalLayer

var current_system_page := 0
var system_help_layer: Control = null
var system_help_label: Label = null
var system_origin := "title"
var system_origin_data: Dictionary = {}
var system_screen_nodes: Array[Node] = []


func _ready() -> void:
	get_tree().auto_accept_quit = false
	AppConfig.configure_window()
	var preview := _preview_screen_arg()
	if preview != "":
		show_static_ui_screen(preview)
		return
	var action := _title_action_arg()
	if action != "":
		_on_title_action(action)
		return
	show_title_screen()


func show_title_screen() -> void:
	system_screen_nodes.clear()
	for child in screen_root.get_children():
		child.queue_free()
	var title := TitleScreen.new()
	title.action_requested.connect(_on_title_action)
	screen_root.add_child(title)


func show_static_ui_screen(screen_name: String) -> void:
	system_screen_nodes.clear()
	for child in screen_root.get_children():
		child.queue_free()
	for name in screen_name.split("+", false):
		var screen := HglStaticScreen.new()
		screen.setup(name)
		screen.action_requested.connect(_on_static_ui_action)
		screen_root.add_child(screen)


func show_save_load_screen(start_mode: String = "load") -> void:
	_remove_save_load_screen()
	var story: Variant = _current_story_player()
	var state := {}
	var thumbnail: Image = null
	if story != null:
		state = story.export_save_state()
		if DisplayServer.get_name() != "headless":
			thumbnail = get_viewport().get_texture().get_image()
		# The message layer deliberately uses an absolute high Z index so stands
		# cannot cover it. The file screen is a separate sibling, therefore it
		# must hide the complete story subtree or the message frame, face, text,
		# and quick menu draw above the Save/Load UI.
		story.visible = false
	var screen := SaveLoadScreenScene.new()
	screen.setup(start_mode, state, thumbnail)
	screen.action_requested.connect(_on_save_load_action)
	screen_root.add_child(screen)


func show_backlog_screen() -> void:
	var story: Variant = _current_story_player()
	if story == null:
		show_static_ui_screen("backlog")
		return
	for child in screen_root.get_children():
		child.visible = true
	var screen := HglStaticScreen.new()
	screen.setup("backlog")
	screen.set_backlog_entries(Array(story.get("history_entries")))
	story.set_backlog_mode(true)
	screen.action_requested.connect(_on_static_ui_action)
	screen_root.add_child(screen)


func show_story_screen() -> void:
	system_screen_nodes.clear()
	for child in screen_root.get_children():
		child.queue_free()
	var story := StoryPlayer.new()
	story.action_requested.connect(_on_static_ui_action)
	screen_root.add_child(story)


func show_story_from_state(state: Dictionary) -> void:
	system_screen_nodes.clear()
	for child in screen_root.get_children():
		child.queue_free()
	var story := StoryPlayer.new()
	story.action_requested.connect(_on_static_ui_action)
	screen_root.add_child(story)
	story.call_deferred("import_save_state", state)


func show_system_screen(page_index: int = 0, origin: String = "", origin_data: Dictionary = {}) -> void:
	page_index = clampi(page_index, 0, OPTION_PAGES.size() - 1)
	current_system_page = page_index
	var already_open := _is_system_screen_active()
	if already_open:
		# Page changes and reset stay inside the same settings overlay.
		_clear_system_screen_nodes()
	else:
		system_origin = origin if origin != "" else _current_top_origin()
		system_origin_data = origin_data
		# Preserve the underlying title/game/page instance for an exact return.
		for child in screen_root.get_children():
			child.visible = false
	var frame := HglStaticScreen.new()
	frame.setup("option")
	frame.set_option_page(page_index)
	frame.set_runtime_input_enabled(false)
	frame.action_requested.connect(_on_static_ui_action)
	frame.help_requested.connect(_on_system_help_requested)
	screen_root.add_child(frame)
	var page := HglStaticScreen.new()
	page.setup(OPTION_PAGES[page_index])
	page.action_requested.connect(_on_static_ui_action)
	page.help_requested.connect(_on_system_help_requested)
	screen_root.add_child(page)
	var overlay := HglStaticScreen.new()
	overlay.setup("option")
	overlay.set_option_page(page_index)
	overlay.set_option_overlay_only(true)
	overlay.set_runtime_input_enabled(false)
	overlay.action_requested.connect(_on_static_ui_action)
	overlay.help_requested.connect(_on_system_help_requested)
	screen_root.add_child(overlay)
	system_screen_nodes = [frame, page, overlay]
	_add_system_hit_buttons()
	_add_system_help_layer()
	system_screen_nodes.append(screen_root.get_node("SystemHitButtons"))
	system_screen_nodes.append(screen_root.get_node("SystemHelpLayer"))


func _preview_screen_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-screen="):
			return arg.trim_prefix("--ui-screen=")
	return ""


func _title_action_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--title-action="):
			return arg.trim_prefix("--title-action=")
	return ""


func _input(event: InputEvent) -> void:
	if _exit_confirm_dialog() != null:
		return
	if _is_system_back_click(event):
		get_viewport().set_input_as_handled()
		AudioManager.play_sysse("chg1")
		_pop_system_screen()
		return


func _unhandled_input(event: InputEvent) -> void:
	if _exit_confirm_dialog() != null:
		return
	if event.is_action_pressed("ui_cancel"):
		if _is_system_screen_active():
			_pop_system_screen()
			get_viewport().set_input_as_handled()
			return
		if _is_static_screen_active():
			show_title_screen()
			get_viewport().set_input_as_handled()
			return


func _is_system_back_click(event: InputEvent) -> bool:
	if not _is_system_screen_active():
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return false
	return mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed


func _is_system_screen_active() -> bool:
	return screen_root.has_node("SystemHitButtons")


func _is_static_screen_active() -> bool:
	if _is_system_screen_active():
		return false
	for child in screen_root.get_children():
		if child.get_script() == HglStaticScreen:
			return true
	return false


func _current_top_origin() -> String:
	for child in screen_root.get_children():
		if child.get_script() == StoryPlayer:
			return "story"
		if child.get_script() == SaveLoadScreenScene:
			var mode: Variant = child.get("_start_mode")
			return "save_load:" + str(mode if mode != null else "load")
		if child.get_script() == HglStaticScreen:
			var name: Variant = child.get("screen_name")
			return "static:" + str(name if name != null else "")
		if child.get_script() == TitleScreen:
			return "title"
	return "title"


func _clear_system_screen_nodes() -> void:
	for node in system_screen_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		# This can be called by a system Button's pressed signal. Removing the
		# node now keeps the next page's names unambiguous; deferred deletion lets
		# the active signal finish without freeing its emitter mid-dispatch.
		node.call_deferred("free")
	system_screen_nodes.clear()
	system_help_layer = null
	system_help_label = null


func _pop_system_screen() -> void:
	if not _is_system_screen_active():
		return
	_clear_system_screen_nodes()
	for child in screen_root.get_children():
		child.visible = true
	system_origin = "title"
	system_origin_data = {}


func _on_title_action(action: String) -> void:
	match action:
		"start":
			show_story_screen()
		"load":
			show_save_load_screen("load")
		"continue":
			_continue_from_latest_save()
		"flowchart":
			show_static_ui_screen("scnchart")
		"extra":
			show_static_ui_screen("extra")
		"system":
			show_system_screen(0, "title")
		"exit":
			_request_exit()
		_:
			pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit()


func _request_exit() -> void:
	if _exit_confirm_dialog() != null:
		return
	if not SystemSettings.get_bool("cf_exit", true):
		get_tree().quit()
		return
	_show_exit_confirm_dialog()


func _show_exit_confirm_dialog() -> void:
	_set_background_input_enabled(false)
	var dialog := ExitConfirmDialogScene.new()
	dialog.confirmed.connect(func(skip_next_time: bool) -> void:
		if skip_next_time:
			SystemSettings.set_confirm("cf_exit", false)
		get_tree().quit()
	)
	dialog.cancelled.connect(func() -> void:
		if is_instance_valid(dialog):
			dialog.queue_free()
		_set_background_input_enabled(true)
	)
	# A CanvasLayer is required here because the story message window uses an
	# absolute CanvasItem z-index.  A normal Main child can still be drawn below
	# that layer even with a larger relative z-index.
	modal_layer.add_child(dialog)


func _set_background_input_enabled(enabled: bool) -> void:
	# Modal confirmation must stop screen `_input()` handlers as well as GUI
	# hit-testing. Backlog handles input in `_input`, before dialog buttons get
	# their `_gui_input` callbacks.
	for child in screen_root.get_children():
		child.set_process_input(enabled)
		child.set_process_unhandled_input(enabled)


func _exit_confirm_dialog():
	for child in modal_layer.get_children():
		if child.get_script() == ExitConfirmDialogScene:
			return child
	return null


func _on_static_ui_action(action: String) -> void:
	if action.begins_with("backlog_voice:"):
		var story: Variant = _current_story_player()
		if story != null:
			story.play_history_voice(action.trim_prefix("backlog_voice:"))
		return
	if action.begins_with("backlog_favorite:"):
		var favorite_story: Variant = _current_story_player()
		if favorite_story != null:
			favorite_story.toggle_history_favorite(int(action.trim_prefix("backlog_favorite:")))
			var favorite_screen: Node = _backlog_screen()
			if favorite_screen != null:
				favorite_screen.set_backlog_entries(Array(favorite_story.get("history_entries")))
		return
	if action.begins_with("backlog_jump:"):
		var jump_story: Variant = _current_story_player()
		if jump_story != null:
			var history: Array = jump_story.get("history_entries")
			var history_index: int = int(action.trim_prefix("backlog_jump:"))
			if history_index >= 0 and history_index < history.size():
				var history_entry: Dictionary = Dictionary(history[history_index])
				if not Dictionary(history_entry.get("state", {})).is_empty():
					_remove_backlog_screen()
					jump_story.jump_to_history_entry(history_entry, history_index)
		return
	if action.begins_with("option_page:"):
		_switch_system_page(int(action.trim_prefix("option_page:")), false)
		return
	match action:
		"back":
			if _is_backlog_screen_active():
				_remove_backlog_screen()
			else:
				show_title_screen()
		"title":
			show_title_screen()
		"system":
			show_system_screen(0)
		"file":
			show_save_load_screen("save")
		"save", "dsave":
			show_save_load_screen("save")
		"qsave":
			show_save_load_screen("save")
		"load":
			show_save_load_screen("load")
		"qload":
			show_save_load_screen("quickload")
		"backlog":
			show_backlog_screen()
		"flowchart":
			show_static_ui_screen("scnchart")
		"to_cg":
			show_static_ui_screen("extra")
		"to_scene":
			show_static_ui_screen("scnchart")
		"to_voice":
			show_static_ui_screen("extra")
		"to_stand":
			show_static_ui_screen("extra_stand")
		"jump":
			show_story_screen()
		"gameend":
			# Scenario-finale edge (e.g. ru05_04 → start.ks *gameend_title):
			# the story runtime stops and control returns to the title.
			show_title_screen()
		"top", "pageup", "pagedown", "end":
			var backlog := _backlog_screen()
			if backlog != null:
				backlog.call("_handle_backlog_scroll", action)
		"reset":
			SystemSettings.reset_defaults()
			show_system_screen(current_system_page)
		_:
			pass


func _backlog_screen() -> Node:
	for child in screen_root.get_children():
		if child.get_script() == HglStaticScreen and child.get("screen_name") == "backlog":
			return child
	return null


func _is_backlog_screen_active() -> bool:
	return _backlog_screen() != null


func _remove_backlog_screen() -> void:
	var screen := _backlog_screen()
	if screen != null:
		screen.queue_free()
	var story: Variant = _current_story_player()
	if story != null:
		story.set_backlog_mode(false)


func _on_save_load_action(action: String, data: Dictionary) -> void:
	match action:
		"back":
			_remove_save_load_screen()
			if screen_root.get_child_count() == 0:
				show_title_screen()
		"title":
			show_title_screen()
		"load_slot":
			var state: Dictionary = data.get("state", {})
			if state.is_empty():
				return
			var story: Variant = _current_story_player()
			_remove_save_load_screen()
			if story != null:
				story.import_save_state(state)
			else:
				show_story_from_state(state)
		_:
			pass


func _remove_save_load_screen() -> void:
	for child in screen_root.get_children():
		if child.get_script() == SaveLoadScreenScene:
			child.queue_free()
	var story: Variant = _current_story_player()
	if story != null:
		story.visible = true


func _current_story_player():
	for child in screen_root.get_children():
		if child.get_script() == StoryPlayer:
			return child
	return null


func _continue_from_latest_save() -> void:
	var data := _latest_save_data()
	if data.is_empty():
		show_save_load_screen("load")
		return
	var state: Dictionary = data.get("state", {})
	if state.is_empty():
		show_save_load_screen("load")
		return
	show_story_from_state(state)


func _latest_save_data() -> Dictionary:
	var save_dir := DirAccess.open("user://saves")
	if save_dir == null:
		return {}
	var candidates := []
	save_dir.list_dir_begin()
	while true:
		var file_name := save_dir.get_next()
		if file_name == "":
			break
		if save_dir.current_is_dir():
			continue
		if not (file_name.begins_with("slot_") and file_name.ends_with(".json")):
			continue
		var path := "user://saves/" + file_name
		var modified := FileAccess.get_modified_time(path)
		candidates.append({"path": path, "modified": modified})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("modified", 0)) > int(b.get("modified", 0))
	)
	for candidate in candidates:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(candidate.get("path", ""))))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		if not data.get("state", {}).is_empty():
			return data
	return {}


func _switch_system_page(page_index: int, play_sound: bool = true) -> bool:
	page_index = clampi(page_index, 0, OPTION_PAGES.size() - 1)
	if page_index == current_system_page:
		return false
	if play_sound:
		AudioManager.play_sysse("chg1")
	show_system_screen(page_index)
	return true


func _add_system_hit_buttons() -> void:
	var hit_layer := Control.new()
	hit_layer.name = "SystemHitButtons"
	hit_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(hit_layer)
	for index in OPTION_PAGES.size():
		var page_index := index
		_add_system_hit_button(
			hit_layer,
			Rect2(Vector2(96 + 173 * page_index, 99) * UI_SCALE, Vector2(172, 73) * UI_SCALE),
			func() -> bool: return _switch_system_page(page_index, false),
			_system_tab_help(page_index)
		)
	_add_system_bottom_button(hit_layer, "reset", Rect2(Vector2(991, 998) * UI_SCALE, Vector2(276, 56) * UI_SCALE), func() -> bool:
		SystemSettings.reset_defaults()
		show_system_screen(current_system_page)
		return true
	, "設定を初期設定に戻します。")
	_add_system_bottom_button(hit_layer, "title", Rect2(Vector2(1272, 998) * UI_SCALE, Vector2(276, 56) * UI_SCALE), func() -> bool:
		show_title_screen()
		return true
	, "タイトル画面に戻ります。")
	_add_system_bottom_button(hit_layer, "back", Rect2(Vector2(1553, 998) * UI_SCALE, Vector2(276, 56) * UI_SCALE), func() -> bool:
		var returned := _is_system_screen_active()
		_pop_system_screen()
		return returned
	, "ゲーム画面に戻ります。")


func _add_system_bottom_button(parent: Control, button_name: String, rect: Rect2, callback: Callable, help_text: String) -> void:
	var visual := Control.new()
	visual.name = "Visual_" + button_name
	visual.position = rect.position
	visual.size = rect.size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(visual)
	_update_system_bottom_button_visual(visual, button_name, "off")
	_add_system_hit_button_with_visual(parent, rect, callback, help_text, func(state: String) -> void:
		_update_system_bottom_button_visual(visual, button_name, state)
	)


func _add_system_hit_button(parent: Control, rect: Rect2, callback: Callable, help_text: String) -> void:
	_add_system_hit_button_with_visual(parent, rect, callback, help_text, Callable())


func _add_system_hit_button_with_visual(parent: Control, rect: Rect2, callback: Callable, help_text: String, visual_callback: Callable) -> void:
	var button := Button.new()
	button.text = ""
	button.position = rect.position
	button.size = rect.size
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
		_on_system_help_requested(help_text, true)
	)
	button.mouse_exited.connect(func() -> void:
		if visual_callback.is_valid():
			visual_callback.call("off")
		_on_system_help_requested("", false)
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
		var changed := bool(callback.call())
		if changed:
			AudioManager.play_sysse("chg1")
	)
	parent.add_child(button)


func _update_system_bottom_button_visual(visual: Control, button_name: String, state: String) -> void:
	for child in visual.get_children():
		child.queue_free()
	_add_system_button_texture(visual, SYSTEM_BUTTON_BG_SLOTS[state])
	var text_states: Dictionary = SYSTEM_BUTTON_TEXT_SLOTS.get(button_name, {})
	_add_system_button_texture(visual, text_states.get(state, {}))


func _add_system_button_texture(parent: Control, slot: Dictionary) -> void:
	if slot.is_empty():
		return
	var tex := TextureRect.new()
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture = _load_texture("res://assets/ui/exported/option/layers/%d.png" % int(slot.get("id", 0)))
	var rect: Rect2 = slot.get("rect", Rect2())
	tex.position = (rect.position - SYSTEM_BUTTON_ORIGIN) * UI_SCALE
	tex.size = rect.size * UI_SCALE
	parent.add_child(tex)


func _add_system_help_layer() -> void:
	system_help_layer = Control.new()
	system_help_layer.name = "SystemHelpLayer"
	system_help_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	system_help_layer.visible = false
	screen_root.add_child(system_help_layer)

	var base := TextureRect.new()
	base.name = "HelpBase"
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.texture = _load_texture("res://assets/ui/exported/option/layers/4866.png")
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.position = Vector2(21, 980) * UI_SCALE
	base.size = Vector2(685, 80) * UI_SCALE
	system_help_layer.add_child(base)

	system_help_label = Label.new()
	system_help_label.name = "HelpText"
	system_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	system_help_label.position = Vector2(44, 990) * UI_SCALE
	system_help_label.size = Vector2(628, 58) * UI_SCALE
	system_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	system_help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	system_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	system_help_label.add_theme_font_size_override("font_size", 15)
	system_help_label.add_theme_color_override("font_color", Color(0.67, 0.33, 0.48, 0.96))
	system_help_layer.add_child(system_help_label)


func _on_system_help_requested(text: String, visible: bool) -> void:
	if system_help_layer == null or system_help_label == null:
		return
	system_help_label.text = text
	system_help_layer.visible = visible and text != ""


func _system_tab_help(page_index: int) -> String:
	var help := [
		"簡易設定を表示します。",
		"画面表示の設定を表示します。",
		"ゲーム進行１の設定を表示します。",
		"ゲーム進行２の設定を表示します。",
		"テキスト表示の設定を表示します。",
		"サウンドの設定を表示します。",
		"確認ダイアログの設定を表示します。",
		"マウス操作の設定を表示します。",
		"キーボード操作の設定を表示します。",
		"ゲームパッド操作の設定を表示します。",
	]
	return help[clampi(page_index, 0, help.size() - 1)]


func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)
