extends "res://scripts/ui/hgl_ui_screen.gd"

signal action_requested(action: String)
signal help_requested(text: String, visible: bool)

const COMPILED_SCREEN_DIR := "res://assets/ui/compiled/screens/"
const OPTION_PAGE_HELP := [
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

const HELP_TEXT := {
	"reset": "設定を初期設定に戻します。",
	"title": "タイトル画面に戻ります。",
	"back": "ゲーム画面に戻ります。",
	"fullscreen": "フルスクリーン表示を切り替えます。",
	"sqscr": "画面比率の補正表示を切り替えます。",
	"skipall": "未読部分もスキップするかを切り替えます。",
	"readskip": "既読部分のスキップ動作を切り替えます。",
	"readjump": "既読ジャンプ動作を切り替えます。",
	"textspeed": "メッセージの表示速度を調整します。",
	"autospeed": "オートモードの待ち時間を調整します。",
	"wave": "全体音量を調整します。",
	"bgm": "BGM音量を調整します。",
	"se": "効果音音量を調整します。",
	"sysse": "システム効果音音量を調整します。",
	"voice": "音声音量を調整します。",
	"movie": "ムービー音量を調整します。",
	"chv": "キャラクター別音声音量を調整します。",
	"se_test": "効果音を試聴します。",
	"chv_test": "選択中のキャラクターボイスを試聴します。",
	"voicecut": "クリック時に音声を停止するかを切り替えます。",
	"cfall_on": "すべての確認ダイアログを表示します。",
	"cfall_off": "すべての確認ダイアログを表示しない設定にします。",
	"color_win": "通常時のウインドウ色を変更します。",
	"color_owin": "視点変更時のウインドウ色を変更します。",
	"color_text": "未読文字の色を変更します。",
	"color_read": "既読文字の色を変更します。",
	"hsv_reset": "選択中の色を初期設定に戻します。",
	"fontselect": "サンプルに使用するフォントを切り替えます。",
}

const COLOR_TARGETS := ["color_win", "color_owin", "color_text", "color_read"]
const BACKLOG_FONT := "res://assets/data/font/sourcehansansjp-bold.otf"
const TftBitmapText := preload("res://scripts/ui/tft_bitmap_text.gd")
const GalleryLists := preload("res://scripts/story/gallery_lists.gd")
const GalleryProgress := preload("res://scripts/story/gallery_progress.gd")
const BACKLOG_VISIBLE_ROWS := 5
const BACKLOG_ROW_SOURCE_HEIGHT := 180.0
const BACKLOG_SCROLL_TIME := 0.20
const BACKLOG_GLYPH_WARMUP_PER_FRAME := 2
const BACKLOG_TEXT_COLOR := Color.WHITE
const TOUCH_UI_SCREEN := "res://assets/ui/compiled/screens/touchuibar.json"
const COMMAND_LABELS := {
	"save": "セーブ画面",
	"dsave": "ダイレクトセーブ",
	"load": "ロード画面",
	"qsave": "クイックセーブ",
	"qload": "クイックロード",
	"option": "システム画面",
	"prev": "前の選択肢へ",
	"prevscn": "前のシーンへ",
	"backskip": "バックスキップ",
	"backone": "前のテキストへ",
	"log": "バックログ画面",
	"auto": "オートモード",
	"skip": "スキップモード",
	"nextscn": "次のシーンへ",
	"next": "次の選択肢へ",
	"scnchart": "フローチャート",
	"vreplay": "音声再生",
	"qvsave": "お気に入りボイス登録",
	"vsave": "お気に入りボイス画面",
	"rclick": "右クリック",
	"click": "左クリック",
	"title": "タイトル画面",
	"screen": "画面サイズ切り替え",
	"snapshot": "スクリーンショット",
	"panic": "スクランブル",
	"none": "機能無効",
	"volume": "ボリューム調整",
	"key_ctrl": "Ｃｔｒｌスキップ",
	"key_pageup": "バックログ/上スクロール",
	"key_pagedown": "下スクロール",
}
const MOUSE_COMMAND_ORDER := [
	"save", "dsave", "load", "qsave", "qload",
	"option", "prev", "prevscn", "backskip", "backone",
	"log", "auto", "skip", "nextscn", "next",
	"scnchart", "vreplay", "qvsave", "vsave", "rclick",
	"title", "screen", "snapshot", "panic", "none",
]
const GAMEPAD_COMMAND_ORDER := [
	"save", "dsave", "load", "qsave", "qload", "key_pageup",
	"option", "prev", "prevscn", "backskip", "backone", "key_pagedown",
	"log", "auto", "skip", "nextscn", "next", "key_ctrl",
	"scnchart", "vreplay", "qvsave", "vsave", "click", "rclick",
	"title", "screen", "snapshot", "panic", "volume", "none",
]
const MOUSE_COMMAND_OBJECTS := [
	"gsicon0", "gsicon1", "gsicon2", "gsicon3", "gsicon4",
	"gsicon5", "gsicon6", "gsicon7", "gsicon8", "gsicon9",
	"gsicon10", "gsicon11", "gsicon12", "gsicon13", "gsicon14",
	"gsicon15", "gsicon16", "gsicon17", "gsicon18", "gsicon19",
	"gsicon20", "gsicon21", "gsicon22", "gsicon23", "gsicon24",
]
const GAMEPAD_COMMAND_OBJECTS := [
	"gsicon0", "gsicon1", "gsicon2", "gsicon3", "gsicon4", "gsicon25",
	"gsicon5", "gsicon6", "gsicon7", "gsicon8", "gsicon9", "gsicon26",
	"gsicon10", "gsicon11", "gsicon12", "gsicon13", "gsicon14", "gsicon27",
	"gsicon15", "gsicon16", "gsicon17", "gsicon18", "gsicon19", "gsicon28",
	"gsicon20", "gsicon21", "gsicon22", "gsicon23", "gsicon29", "gsicon24",
]
const MOUSE_HOLDER_COMMANDS := {
	"holder0": "auto",
	"holder2": "backskip",
	"holder3": "skip",
	"holder6": "save",
	"holder1": "option",
	"holder4": "vreplay",
	"holder5": "snapshot",
}
const GAMEPAD_HOLDER_COMMANDS := {
	"holder0": "key_ctrl",
	"holder1": "auto",
	"holder2": "vreplay",
	"holder3": "option",
	"holder4": "backskip",
	"holder5": "skip",
	"holder6": "save",
	"holder7": "volume",
	"holder8": "click",
	"holder9": "rclick",
	"holder10": "key_pageup",
	"holder11": "key_pagedown",
}
const STATIC_ACTION_OBJECTS := [
	"back", "title", "backlog",
	"to_cg", "to_scene", "to_voice", "to_stand",
	"jump", "pageup", "pagedown", "top", "end",
	"page0", "page1", "page2", "page3", "page4", "page5", "page6", "page7",
	"chadd", "chsort", "edit_hide", "edit_init", "edit_capt", "edit_mybg", "edit_save", "edit_load",
]
const EXTRA_TAB_RECTS := {
	"to_cg": Rect2(96, 99, 236, 73),
	"to_scene": Rect2(333, 99, 236, 73),
	"to_voice": Rect2(570, 99, 236, 73),
	"to_stand": Rect2(807, 99, 236, 73),
}
const EXTRA_TAB_TEXT := {
	"to_cg": {"off": "system_menu_btn/text/off/ＣＧ鑑賞", "over": "system_menu_btn/text/over/ＣＧ鑑賞", "on": "system_menu_btn/text/on/ＣＧ鑑賞"},
	"to_scene": {"off": "system_menu_btn/text/off/シーン鑑賞", "over": "system_menu_btn/text/over/シーン鑑賞", "on": "system_menu_btn/text/on/シーン鑑賞"},
	"to_voice": {"off": "system_menu_btn/text/off/お気に入りボイス", "over": "system_menu_btn/text/over/お気に入りボイス", "on": "system_menu_btn/text/on/お気に入りボイス"},
	"to_stand": {"off": "system_menu_btn/text/off/立ち絵鑑賞", "over": "system_menu_btn/text/over/立ち絵鑑賞", "on": "system_menu_btn/text/on/立ち絵鑑賞"},
}
const EXTRA_TAB_ORIGIN := Vector2(96, 99)
const SCNCHART_ROUTES := ["共通", "咲夜", "ルリ", "佐奈", "葵", "まひろ", "紫", "若葉"]
# `default.tjs` `.scnchartUiItemConsts` lays the chart out on its own axis:
# `firstofs step:(80)` then `section/subsection step:(100)`.  Rows are placed at
# (template + step * index) on that axis, so the on-screen pitch is
# SCNCHART_ITEM_STEP * ui_scale().y.
const SCNCHART_ITEM_STEP := 100.0
const SCNCHART_VISIBLE_NODES := 7
const SCNCHART_SECTION_FALLBACK := Rect2(889, 459, 435, 74)
const SCNCHART_SUBSECTION_FALLBACK := Rect2(889, 459, 274, 74)
const SCNCHART_SCROLL_FALLBACK := Rect2(576, 0, 896, 982)
# `scnchartUiLineConsts`: normal 0xFFa987c8, query 0xFF6eb6c3, minimap 0xFFa987c8.
const SCNCHART_LINE_COLOR := Color8(169, 135, 200)
const SCNCHART_LINE_QUERY_COLOR := Color8(110, 182, 195)
const SCNCHART_MINIMAP_COLOR := Color8(169, 135, 200)
const SCNCHART_MINIMAP_SELECTED_COLOR := Color8(255, 88, 123)
const SCNCHART_NODE_TITLES := [
	"プロローグ",
	"神様との出会い",
	"商店街の朝",
	"昼休みの相談",
	"放課後イベント",
	"分岐選択",
	"個別ルート開始",
	"約束",
	"すれ違い",
	"告白",
	"クライマックス",
	"エピローグ",
]

var screen_name := ""
var option_page_index := 0
var option_overlay_only := false
var runtime_input_enabled := true
var object_map: Dictionary = {}
var runtime_widgets: Dictionary = {}
var touch_ui_cache: Dictionary = {}
var radio_groups: Dictionary = {
	"fullscreen": "fullscreen_off",
	"sqscr": "sqscr_off",
	"skipall": "skipall_off",
}
var check_states: Dictionary = {}
var slider_values: Dictionary = {
	"textspeed": 0.5,
	"autospeed": 0.5,
	"wave": 1.0,
	"bgm": 1.0,
	"down": 1.0,
	"se": 1.0,
	"sysse": 1.0,
	"voice": 1.0,
	"movie": 1.0,
	"bgv": 1.0,
	"chv": 1.0,
	"atextwait": 0.5,
	"autotime": 0.5,
	"winopac": 0.75,
}
var dragging_slider := ""
var dragging_color_picker := false
var selected_chvoice := "chv0"
var character_preview: Control = null
var _gallery_cache = null
var extra_cg_page := 0
var extra_sound_page := 0
var extra_scene_page := 0
var scnchart_page := 0
var scnchart_scroll := 0
var scnchart_selected := 0
var scnchart_runtime_layer: Control = null
var _func_template_sources: Variant = null
var font_dialog: Control = null
var font_dialog_list: ItemList = null
var font_dialog_selection := ""
var backlog_entries: Array = []
var backlog_start: int = 0
var backlog_runtime_layer: Control = null
var backlog_content_layer: Control = null
var dragging_backlog_scrollbar := false
var backlog_scrollbar_grab_offset := 0.0
var backlog_visual_start := 0.0
var backlog_scroll_target := 0.0
var backlog_scroll_origin := 0.0
var backlog_scroll_elapsed := 0.0
var backlog_draw_start := 0
var backlog_row_nodes: Array[Control] = []
var backlog_row_cache: Dictionary = {}
var backlog_glyph_warmup: PackedInt32Array = []
var backlog_glyph_warmup_index := 0
var key_labels: Dictionary = {
	"key_save": "F2",
	"key_load": "F3",
	"key_dsave": "S",
	"key_qsave": "F11",
	"key_qload": "F12",
	"key_option": "F8",
	"key_screen": "F4",
	"key_click": "Enter",
	"key_auto": "F6",
	"key_skip": "F7",
	"key_ctrl": "Control",
	"key_nextscn": "N",
	"key_next": "Q",
	"key_log": "F5",
	"key_pageup": "PgUp",
	"key_pagedown": "PgDn",
	"key_backone": "BkSpc",
	"key_backskip": "D",
	"key_prevscn": "P",
	"key_prev": "B",
	"key_scnchart": "W",
	"key_title": "F10",
	"key_volume": "Home",
	"key_hide": "Delete",
	"key_vreplay": "F9",
	"key_qvsave": "V",
	"key_vsave": "SFT+V",
	"key_snapshot": "PrtSc",
	"key_panic": "(ESC)",
	"key_save_alt": "SFT+S",
	"key_load_alt": "L",
	"key_dsave_alt": "未設定",
	"key_qsave_alt": "未設定",
	"key_qload_alt": "未設定",
	"key_option_alt": "未設定",
	"key_screen_alt": "未設定",
	"key_click_alt": "Space",
	"key_auto_alt": "A",
	"key_skip_alt": "F",
	"key_ctrl_alt": "未設定",
	"key_nextscn_alt": "未設定",
	"key_next_alt": "未設定",
	"key_log_alt": "R",
	"key_pageup_alt": "未設定",
	"key_pagedown_alt": "未設定",
	"key_backone_alt": "未設定",
	"key_backskip_alt": "未設定",
	"key_prevscn_alt": "未設定",
	"key_prev_alt": "未設定",
	"key_scnchart_alt": "未設定",
	"key_title_alt": "未設定",
	"key_volume_alt": "未設定",
	"key_hide_alt": "未設定",
	"key_vreplay_alt": "未設定",
	"key_qvsave_alt": "未設定",
	"key_vsave_alt": "未設定",
	"key_snapshot_alt": "未設定",
	"key_panic_alt": "未設定",
}


func setup(name: String) -> void:
	screen_name = name


func set_backlog_entries(entries: Array) -> void:
	var had_entries := not backlog_entries.is_empty()
	backlog_entries = entries.duplicate(true)
	if not had_entries or backlog_runtime_layer == null:
		backlog_start = maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	else:
		backlog_start = clampi(backlog_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	backlog_visual_start = float(backlog_start)
	backlog_scroll_target = float(backlog_start)
	backlog_scroll_origin = float(backlog_start)
	backlog_scroll_elapsed = BACKLOG_SCROLL_TIME
	backlog_draw_start = backlog_start
	_queue_backlog_glyph_warmup()
	if backlog_runtime_layer != null:
		_redraw_backlog_runtime()


func set_option_page(index: int) -> void:
	option_page_index = clampi(index, 0, 9)
	radio_groups["option_pages"] = "page" + str(option_page_index)


func set_option_overlay_only(enabled: bool) -> void:
	option_overlay_only = enabled


func set_runtime_input_enabled(enabled: bool) -> void:
	runtime_input_enabled = enabled


func _ready() -> void:
	if screen_name == "":
		return
	# The history screen is an overlay over StoryPlayer.  It must own the
	# complete pointer surface so a click in an empty part of the screen cannot
	# reach StoryPlayer and advance the scenario underneath it.
	if screen_name == "backlog":
		mouse_filter = Control.MOUSE_FILTER_STOP
	if screen_name == "option":
		radio_groups["option_pages"] = "page" + str(option_page_index)
	compiled_ui = load_json(COMPILED_SCREEN_DIR + screen_name + ".json")
	_index_objects()
	_sync_settings_state()
	_build_layers()
	_build_runtime_widgets()
	_build_extra_nav_visuals()
	_build_extra_cg_grid()
	_build_extra_sound_list()
	_build_extra_scene_list()
	_build_extra_stand_controls()
	_build_scnchart_runtime()
	_build_backlog_runtime()
	_build_static_action_widgets()


func _process(delta: float) -> void:
	if screen_name != "backlog" or backlog_runtime_layer == null:
		return
	_warm_backlog_glyphs()
	if dragging_backlog_scrollbar:
		# Slider dragging is direct manipulation. Do not make the thumb chase a
		# second animated target while the pointer is already moving it.
		backlog_visual_start = backlog_scroll_target
	elif backlog_scroll_elapsed >= BACKLOG_SCROLL_TIME or is_equal_approx(backlog_visual_start, backlog_scroll_target):
		backlog_visual_start = backlog_scroll_target
	else:
		# backlog.tjs's getScrollTime() returns 200ms and MoveAction is stopped
		# and restarted from the current value for repeated input. Finish at the
		# exact target instead of using an exponential tail that lingers.
		backlog_scroll_elapsed = minf(backlog_scroll_elapsed + delta, BACKLOG_SCROLL_TIME)
		var progress := backlog_scroll_elapsed / BACKLOG_SCROLL_TIME
		var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
		backlog_visual_start = lerpf(backlog_scroll_origin, backlog_scroll_target, eased)
	var next_draw_start := clampi(int(floor(backlog_visual_start)), 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	if next_draw_start != backlog_draw_start:
		backlog_draw_start = next_draw_start
		_redraw_backlog_entries_only()
	_update_backlog_content_position()
	_update_backlog_scrollbar_visual()
	# A stationary pointer can move over a newly redrawn row while the list is
	# animating. Refresh all custom states so hover artwork never lags behind.
	_update_backlog_hover(get_viewport().get_mouse_position() / ui_scale())


func _input(event: InputEvent) -> void:
	if screen_name == "backlog" and runtime_input_enabled:
		_handle_backlog_pointer_input(event)
		return
	if screen_name != "option" or not runtime_input_enabled:
		return
	if not _is_left_release(event):
		return
	var mouse_event := event as InputEventMouseButton
	var widget_name := _option_widget_at(mouse_event.position)
	if widget_name == "":
		return
	if widget_name.begins_with("page"):
		var group_name := _group_name_for_radio(widget_name)
		radio_groups[group_name] = widget_name
		_update_radio_group(group_name)
	AudioManager.play_sysse("chg1")
	_emit_widget_action(widget_name)


func _option_widget_at(global_position: Vector2) -> String:
	var names := runtime_widgets.keys()
	names.reverse()
	for widget_name in names:
		var name_text := str(widget_name)
		if not (name_text.begins_with("page") or name_text in ["back", "title", "reset"]):
			continue
		var record: Dictionary = runtime_widgets[widget_name]
		var node: Control = record.get("node")
		if node == null:
			continue
		var rect := Rect2(node.global_position, node.size)
		if rect.has_point(global_position):
			return name_text
	return ""


func _build_layers() -> void:
	var layer_dir := str(compiled_ui.get("layer_dir", ""))
	var skipped_layer_ids := _runtime_resource_layer_ids()
	for layer in _static_layer_draw_list():
		if not bool(layer.get("visible", true)):
			continue
		var layer_id: Variant = layer.get("id", "")
		if skipped_layer_ids.has(str(layer_id)):
			continue
		if _hidden_static_layer_path(str(layer.get("path", ""))):
			continue
		if _runtime_resource_layer_path(str(layer.get("path", ""))):
			continue
		var path := layer_path(layer_dir, layer_id)
		if not file_exists(path):
			continue
		var node := add_texture(self, path, rect_from_dict(layer.get("rect", {})), "layer_" + str(layer_id))
		node.modulate.a = float(layer.get("opacity", 255.0)) / 255.0


func _static_layer_draw_list() -> Array:
	var layers: Array = compiled_ui.get("layers", [])
	var reversed := layers.duplicate()
	reversed.reverse()
	return reversed


func _build_runtime_widgets() -> void:
	if not _uses_runtime_widgets():
		return
	_build_copied_buttons()
	_cover_inactive_simple_tab_underline()
	_build_decorator_copy_widgets()
	_build_checkbox_widgets()
	_build_slider_widgets()
	_build_holder_icon_widgets()
	_build_command_palette_widgets()
	_build_onoff_widgets()
	_build_key_widgets()
	_build_value_widgets()
	_build_character_preview()
	_build_character_voice_widgets()
	_build_option4_runtime_widgets()


func _build_static_action_widgets() -> void:
	if _uses_runtime_widgets():
		return
	for object_name in STATIC_ACTION_OBJECTS:
		# The chart screen draws its own route tabs and up/down buttons from the
		# same objects; a second hitbox on top would double-fire the sound and
		# could steal the press.
		if screen_name == "scnchart" and (str(object_name).begins_with("page") or str(object_name) in ["top", "pageup", "pagedown", "end"]):
			continue
		var object := _find_object(str(object_name))
		if object.is_empty():
			continue
		var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
		if rect.size == Vector2.ZERO:
			continue
		var button := Button.new()
		button.name = "static_action_" + str(object_name)
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
		var action_name := str(object_name)
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			if not _handle_local_static_action(action_name):
				action_requested.emit(action_name)
		)
		add_child(button)


func _handle_local_static_action(action_name: String) -> bool:
	if screen_name == "scnchart":
		return _handle_scnchart_action(action_name)
	if screen_name == "extra":
		return _handle_extra_action(action_name)
	if screen_name != "extra_stand":
		return false
	match action_name:
		"chadd":
			_show_extra_stand_character_popup()
			return true
		"edit_hide":
			_toggle_extra_stand_controls()
			return true
		_:
			return false


## CG gallery paging (the authored list exceeds one grid page).
func _handle_extra_action(action_name: String) -> bool:
	var per_page := _extra_cg_grid_positions().size()
	if per_page <= 0:
		return false
	var total := GalleryLists.cg_entries().size()
	var max_page: int = maxi(0, (total - 1) / per_page)
	match action_name:
		"cg_prev":
			if extra_cg_page <= 0:
				return false
			extra_cg_page -= 1
		"cg_next":
			if extra_cg_page >= max_page:
				return false
			extra_cg_page += 1
		_:
			return false
	# Rebuild just the grid by reloading this screen's runtime layer.
	_rebuild_extra_cg_grid()
	return true


func _rebuild_extra_cg_grid() -> void:
	for child in get_children():
		if str(child.name).begins_with("extra_cg_cell_"):
			remove_child(child)
			child.queue_free()
	_build_extra_cg_grid()
	action_requested.emit("cg_page_changed:%d" % extra_cg_page)


## Music gallery list (assets/main/soundlist.csv) with the original
## list/contents slot traffic: seven rows per page, unlocked tracks only.
func _build_extra_sound_list() -> void:
	if screen_name != "extra":
		return
	var gallery: Variant = _gallery_progress()
	var rows := _extra_content_row_rects()
	if rows.is_empty():
		return
	var entries := GalleryLists.sound_entries()
	var page_start := extra_sound_page * rows.size()
	for row_index in range(rows.size()):
		var entry_index := page_start + row_index
		if entry_index >= entries.size():
			break
		var entry: Dictionary = entries[entry_index]
		var unlocked: bool = gallery == null or gallery.is_unlocked("bgm", str(entry.get("key", "")))
		var row_rect: Rect2 = rows[row_index]
		var label := Label.new()
		label.name = "extra_sound_row_%d" % row_index
		label.text = str(entry.get("title", "")) if unlocked else "？？？"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = (row_rect.position + Vector2(8, 0)) * ui_scale()
		label.size = Vector2(row_rect.size.x - 16, row_rect.size.y) * ui_scale()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.10))
		if not unlocked:
			label.modulate = Color(1, 1, 1, 0.55)
		add_child(label)


## Scene replay list (assets/main/scenelist.csv): each row replays a movie.
func _build_extra_scene_list() -> void:
	if screen_name != "extra":
		return
	var gallery: Variant = _gallery_progress()
	var rows := _extra_content_row_rects()
	if rows.is_empty():
		return
	var entries := GalleryLists.scene_entries()
	var page_start := extra_scene_page * rows.size()
	for row_index in range(rows.size()):
		var entry_index := page_start + row_index
		if entry_index >= entries.size():
			break
		var entry: Dictionary = entries[entry_index]
		var unlocked: bool = gallery == null or gallery.is_unlocked("scene", str(entry.get("key", "")))
		var row_rect: Rect2 = rows[row_index]
		var label := Label.new()
		label.name = "extra_scene_row_%d" % row_index
		label.text = str(entry.get("movie", entry.get("key", ""))) if unlocked else "？？？"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = (row_rect.position + Vector2(8, 0)) * ui_scale()
		label.size = Vector2(row_rect.size.x - 16, row_rect.size.y) * ui_scale()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.10))
		if not unlocked:
			label.modulate = Color(1, 1, 1, 0.55)
		add_child(label)


## Row rectangles for the content list (every third ##rects/ entry is the text
## slot row; the layout repeats per entry).
func _extra_content_row_rects() -> Array:
	var rows := []
	var layers: Array = compiled_ui.get("layers", [])
	var index := 0
	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue
		var layer: Dictionary = layer_value
		var path: String = str(layer.get("path", ""))
		if not path.begins_with("list/contents/##rects/"):
			continue
		index += 1
		# Entries repeat as [number, title, underline]; the title slot is the
		# second of each triple.
		if index % 3 != 2:
			continue
		rows.append(rect_from_dict(layer.get("rect", {})))
		if rows.size() >= 7:
			break
	return rows


func _cover_inactive_simple_tab_underline() -> void:
	if screen_name != "option" or option_page_index == 0:
		return
	var cover := ColorRect.new()
	cover.name = "runtime_page0_underline_cover"
	var rect := scaled_rect(Rect2(97, 156, 170, 16))
	cover.position = rect.position
	cover.size = rect.size
	cover.color = Color8(246, 233, 235, 255)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)


func _build_decorator_copy_widgets() -> void:
	for object_name in object_map.keys():
		var object: Dictionary = object_map[object_name]
		var prototype_name := str(object.get("prototype", ""))
		if prototype_name != "_headline":
			continue
		var prototype := _find_object(prototype_name)
		if prototype.is_empty():
			continue
		var slots: Dictionary = prototype.get("slots", {})
		var base_slot := _slot(slots, ["base/layer"])
		if base_slot.is_empty():
			continue
		var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
		if rect.size == Vector2.ZERO:
			continue
		var copy := Control.new()
		copy.name = "decorator_" + str(object_name)
		copy.position = rect.position
		copy.size = rect.size
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(copy)
		_add_slot_texture(copy, base_slot, _prototype_origin(prototype, object))
	var text_slot := _slot_from_layer_path("headline/text")
	if not text_slot.is_empty():
		_add_slot_texture(self, text_slot, Vector2.ZERO)


func _index_objects() -> void:
	object_map.clear()
	var ini: Dictionary = compiled_ui.get("ini", {})
	for object in ini.get("objects", []):
		object_map[str(object.get("name", ""))] = object


func _sync_settings_state() -> void:
	for key in slider_values.keys():
		slider_values[key] = SystemSettings.get_slider(str(key), float(slider_values[key]))
	for key in key_labels.keys():
		key_labels[key] = SystemSettings.get_key_label(str(key), str(key_labels[key]))
	for group_name in ["fullscreen", "sqscr", "skipall"]:
		radio_groups[group_name] = SystemSettings.get_radio(group_name, str(radio_groups.get(group_name, group_name + "_off")))
	if screen_name == "option_4text":
		radio_groups["color"] = SystemSettings.get_radio("color", SystemSettings.get_color_target())
		SystemSettings.set_color_target(str(radio_groups["color"]))


func _runtime_resource_layer_ids() -> Dictionary:
	var skipped := {}
	if not _uses_runtime_widgets():
		return skipped
	for binding in compiled_ui.get("ini", {}).get("bindings", []):
		var source := str(binding.get("source", ""))
		if not _runtime_resource_layer_path(source):
			continue
		var layer_id: Variant = binding.get("layer_id", null)
		if layer_id != null and str(layer_id) != "-1":
			skipped[str(layer_id)] = true
	return skipped


func _runtime_resource_layer_path(path: String) -> bool:
	if not _uses_runtime_widgets():
		return false
	if screen_name == "option" and option_overlay_only and path == "bg/base":
		return true
	if screen_name == "option" and path.begins_with("system_menu_btn/"):
		return true
	if screen_name.begins_with("option_") and path == "#option.psd":
		return true
	if screen_name == "option_4text" and path in ["window", "window_back"]:
		return true
	var prefixes := [
		"advancedsetting_botton/",
		"btn/",
		"btn2/",
		"btn3/",
		"btn4/",
		"btn5/",
		"btn_Voice/",
		"btn_Volume/",
		"bottom_button/",
		"bg/character_window_bg",
		"bg/icon",
		"character_window/",
		"radio_btn/",
		"radio_btn2/",
		"seekbar/bg/",
		"seekbar/knob/",
		"seekbar/L1",
		"seekbar/Lbg1",
		"seekbar/R1",
		"seekbar/Rbg1",
		"system_menu_btn/",
		"touchvolume/",
	]
	return _starts_with_any(path, prefixes)


func _hidden_static_layer_path(path: String) -> bool:
	if _func_template_layer_path(path):
		return true
	if screen_name == "backlog":
		if path == "bg/captipn/search":
			return true
		if path.begins_with("bottom_button/") or path.begins_with("menu_button1/"):
			return true
		if path.begins_with("scrollbar/knob/"):
			return true
	if screen_name == "option" and path in ["bg/Description", "bg/#help"]:
		return true
	if screen_name.begins_with("option_") and path in ["bg/help2", "bg/#help2"]:
		return true
	if screen_name.begins_with("option_") and path == "headline/text":
		return true
	if screen_name == "option_9gamepad" and path.begins_with("assign/"):
		return true
	if screen_name == "extra":
		if path.begins_with("system_menu_btn/"):
			return true
		if _extra_cg_mode_hidden_layer(path):
			return true
	if screen_name == "extra_stand":
		if path.begins_with("system_menu_btn/"):
			return true
		if path in ["bg_ex/nodrag"]:
			return true
		if path.begins_with("preview/"):
			return true
		if path.begins_with("character_choice_window/"):
			return true
		if path.begins_with("choice_field/"):
			return true
		if path.begins_with("choice_of_background/"):
			return true
		if path.begins_with("choice_of_face/"):
			return true
		if path.begins_with("btn_arrow/") or path.begins_with("#btn_arrow"):
			return true
		if _extra_stand_multistate_layer(path):
			return true
	if screen_name == "scnchart":
		if _scnchart_runtime_layer_path(path):
			return true
	return false


## A `.func` declaration of `visible,false` marks a *design sample*: the PSD keeps
## the artwork visible so the designer can lay it out, but the runtime clones it
## per item and never shows the original.  `scnchart.func` does this for every
## chart item type (`section`, `subsection`, `branch`, `select`, `update`, ...),
## which `scnchart_ui.tjs` instantiates from `scnchartUiItemConsts`.  Without this
## rule the templates would be drawn on top of the live items.
func _func_template_layer_path(path: String) -> bool:
	if _func_template_sources == null:
		_func_template_sources = _collect_func_template_sources()
	return _func_template_sources.has(path)


func _collect_func_template_sources() -> Dictionary:
	var sources := {}
	for object_name in _func_hidden_objects():
		var object := _find_object(str(object_name))
		if object.is_empty():
			continue
		for slot_value in Dictionary(object.get("slots", {})).values():
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var source := str(Dictionary(slot_value).get("source", ""))
			if source != "":
				sources[source] = true
	return sources


func _func_hidden_objects() -> Array:
	var hidden: Array = []
	for action_value in compiled_ui.get("func", {}).get("actions", []):
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		if str(action.get("body", "")).strip_edges() == "visible,false":
			hidden.append(str(action.get("name", "")))
	return hidden


func _extra_cg_mode_hidden_layer(path: String) -> bool:
	var hidden_prefixes := [
		"list/",
		"movie_thumbnail/",
		"btn_Volume/",
		"_seekbar/",
		"radio_btn/",
	]
	if _starts_with_any(path, hidden_prefixes):
		return true
	if path in [
		"headline/text/ムービー鑑賞",
		"headline/音楽鑑賞",
		"scrollbar/knob/on",
		"scrollbar/knob/over",
		"scrollbar/knob/off",
		"scrollbar/arrow/1",
		"cg_thumbnail/CG_220x124",
		"cg_thumbnail/on",
		"cg_thumbnail/over",
		"cg_thumbnail/off",
	]:
		return true
	if path.begins_with("btn1/"):
		return true
	if path.begins_with("chara_select/text/on/") or path.begins_with("chara_select/text/over/"):
		return true
	if path in ["chara_select/bg/on", "chara_select/bg/over"]:
		return true
	return false


func _build_extra_nav_visuals() -> void:
	if not screen_name in ["extra", "extra_stand"]:
		return
	var active_tab := "to_stand" if screen_name == "extra_stand" else "to_cg"
	var prototype_origin := Vector2(952, 4) if screen_name == "extra_stand" else EXTRA_TAB_ORIGIN
	for tab_name in EXTRA_TAB_RECTS.keys():
		var object := _find_object(str(tab_name))
		var tab_rect: Rect2 = EXTRA_TAB_RECTS[tab_name]
		if not object.is_empty():
			tab_rect = rect_from_dict(object.get("rect", {}))
		var visual := Control.new()
		visual.name = "extra_nav_" + str(tab_name)
		visual.position = tab_rect.position * ui_scale()
		visual.size = tab_rect.size * ui_scale()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		_draw_extra_tab(visual, str(tab_name), "on" if tab_name == active_tab else "off", prototype_origin * ui_scale())


func _draw_extra_tab(parent: Control, tab_name: String, state: String, origin: Vector2) -> void:
	for child in parent.get_children():
		child.queue_free()
	var bg_path := "system_menu_btn/" + state
	_add_extra_nav_layer(parent, bg_path, origin)
	var text_paths: Dictionary = EXTRA_TAB_TEXT[tab_name]
	_add_extra_nav_layer(parent, str(text_paths[state]), origin)


func _add_extra_nav_layer(parent: Control, source_path: String, origin: Vector2) -> void:
	var slot := _slot_from_layer_path(source_path)
	if slot.is_empty():
		return
	_add_slot_texture(parent, slot, origin)


func _build_extra_cg_grid() -> void:
	if screen_name != "extra":
		return
	var frame_slot := _slot_from_layer_path("cg_thumbnail/off")
	if frame_slot.is_empty():
		return
	var thumb_paths := _extra_cg_thumbnail_paths()
	var positions := _extra_cg_grid_positions()
	var frame_origin := scaled_rect(rect_from_dict(frame_slot.get("rect", {}))).position
	# The grid shows one page (16 cells); the authored list has 65 CG groups, so
	# page flips come through the extra nav actions below.
	var page_start := extra_cg_page * positions.size()
	for index in range(positions.size()):
		var cell_rect: Rect2 = positions[index]
		var cell := Control.new()
		cell.name = "extra_cg_cell_" + str(index)
		cell.position = cell_rect.position * ui_scale()
		cell.size = cell_rect.size * ui_scale()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		_add_slot_texture(cell, frame_slot, frame_origin)
		var entry_index := page_start + index
		if entry_index < thumb_paths.size():
			_add_extra_cg_thumbnail(cell, str(thumb_paths[entry_index]))


func _extra_cg_grid_positions() -> Array:
	var positions := []
	var layers: Array = compiled_ui.get("layers", [])
	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue
		var path := str(Dictionary(layer_value).get("path", ""))
		if not path.begins_with("cg_thumbnail/##cg_thumbnail/"):
			continue
		positions.append(rect_from_dict(Dictionary(layer_value).get("rect", {})))
	positions.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if is_equal_approx(a.position.y, b.position.y):
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)
	return positions


## CG grid entries in authored list order (assets/main/cglist.csv), filtered by
## gallery unlock progress. A locked group yields an empty string so the cell
## keeps only the empty frame; an unlocked group yields its first image path.
func _extra_cg_thumbnail_paths() -> Array:
	var result := []
	var gallery: Variant = _gallery_progress()
	for entry in GalleryLists.cg_entries():
		var names: Array = entry.get("names", [])
		var group := str(entry.get("group", ""))
		if group == "":
			continue
		if gallery != null and not bool(gallery.is_unlocked("cg", group)):
			result.append("")
			continue
		var first := str(names[0]) if not names.is_empty() else group
		result.append(_resolve_cg_image(first))
	return result


## Resolve a CG image name (e.g. "EV0102A") to a real file path. The extracted
## tree lowercases most evimage names, so try common casings before the index.
func _resolve_cg_image(image_name: String) -> String:
	if image_name == "":
		return ""
	var roots: Array[String] = ["res://assets/evimage", "res://assets/bgimage"]
	var casings: Array[String] = [image_name, image_name.to_lower(), image_name.to_upper()]
	for root in roots:
		for candidate in casings:
			var path := root + "/" + candidate + ".png"
			if FileAccess.file_exists(path):
				return ProjectSettings.globalize_path(path)
	var resolved := ResourceIndex.resolve_basename("evimage", image_name.to_lower() + ".png")
	if resolved == "":
		resolved = ResourceIndex.resolve_basename("evimage", image_name.to_lower())
	return resolved


func _gallery_progress():
	if _gallery_cache == null:
		_gallery_cache = GalleryProgress.new()
	return _gallery_cache


func _add_extra_cg_thumbnail(parent: Control, image_path: String) -> void:
	if image_path == "":
		# Locked entry: the empty frame from _build_extra_cg_grid stays visible.
		return
	var texture := _load_absolute_texture(image_path)
	if texture == null:
		return
	var thumb := TextureRect.new()
	thumb.name = "thumb"
	thumb.texture = texture
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var rect := scaled_rect(Rect2(16, 15, 220, 124))
	thumb.position = rect.position
	thumb.size = rect.size
	parent.add_child(thumb)


func _load_absolute_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture


func _build_extra_stand_controls() -> void:
	if screen_name != "extra_stand":
		return
	var edit_text_slots := {
		"edit_hide": "f_hide",
		"edit_init": "f_init",
		"edit_capt": "f_snapshot",
		"edit_mybg": "f_userbg",
		"edit_save": "f_save",
		"edit_load": "f_load",
	}
	for object_name in edit_text_slots.keys():
		_add_extra_stand_cmd_button(str(object_name), str(edit_text_slots[object_name]))


func _add_extra_stand_cmd_button(object_name: String, text_slot_name: String) -> void:
	var object := _find_object(object_name)
	var prototype := _find_object("_cmd")
	if object.is_empty() or prototype.is_empty():
		return
	var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
	if rect.size == Vector2.ZERO:
		return
	var holder := Control.new()
	holder.name = "stand_cmd_" + object_name
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var slots: Dictionary = prototype.get("slots", {})
	var origin := _prototype_origin(prototype, object)
	_add_slot_texture(holder, _slot(slots, ["off"]), origin)
	_add_slot_texture(holder, _slot(slots, [text_slot_name]), origin)


func _show_extra_stand_character_popup() -> void:
	var existing := get_node_or_null("stand_character_popup")
	if existing != null:
		existing.queue_free()
		return
	var popup := Control.new()
	popup.name = "stand_character_popup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup)
	for source_path in ["character_choice_window/bg", "character_choice_window/キャラクターを選択して下さい"]:
		var slot := _slot_from_layer_path(source_path)
		if not slot.is_empty():
			_add_slot_texture(popup, slot, Vector2.ZERO)
	_build_extra_stand_character_cards(popup)
	_add_extra_stand_popup_close_button(popup)


func _build_extra_stand_character_cards(parent: Control) -> void:
	var names := [
		"卯花之佐久夜姫", "竜胆 ルリ", "千歳 佐奈", "山吹 葵", "常盤 まひろ",
		"烏羽 紫", "木賊 朋花", "山吹 渉", "東雲 庵", "浅葱 虎太郎",
		"千歳 眞一郎", "老竹 幹雄", "蘇芳", "市杵宍姫命", "千歳春樹",
	]
	var positions := _extra_stand_character_card_positions()
	var bg_slot := _slot_from_layer_path("character_choice_window/bnt_chara_choice/bg/off")
	var name_bg_slot := _slot_from_layer_path("character_choice_window/bnt_chara_choice/namebg/off")
	var prototype_origin := scaled_rect(Rect2(329, 431, 142, 166)).position
	for index in range(mini(names.size(), positions.size())):
		var rect: Rect2 = positions[index]
		var holder := Control.new()
		holder.name = "stand_character_card_" + str(index)
		holder.position = rect.position * ui_scale()
		holder.size = rect.size * ui_scale()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(holder)
		_add_slot_texture(holder, bg_slot, prototype_origin)
		var chara_slot := _slot_from_layer_path("character_choice_window/bnt_chara_choice/chara/" + str(names[index]))
		var name_slot := _slot_from_layer_path("character_choice_window/bnt_chara_choice/name/off/" + str(names[index]))
		_add_slot_texture(holder, chara_slot, prototype_origin)
		_add_slot_texture(holder, name_bg_slot, prototype_origin)
		_add_slot_texture(holder, name_slot, prototype_origin)


func _extra_stand_character_card_positions() -> Array:
	var positions := []
	var layers: Array = compiled_ui.get("layers", [])
	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue
		var path := str(Dictionary(layer_value).get("path", ""))
		if not path.begins_with("character_choice_window/##bnt_chara_choice/"):
			continue
		positions.append(rect_from_dict(Dictionary(layer_value).get("rect", {})))
	positions.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if is_equal_approx(a.position.y, b.position.y):
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)
	return positions


func _add_extra_stand_popup_close_button(parent: Control) -> void:
	var close_rect := scaled_rect(Rect2(1638, 283, 49, 48))
	var button := Button.new()
	button.name = "stand_character_popup_close"
	button.text = ""
	button.position = close_rect.position
	button.size = close_rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.pressed.connect(func() -> void:
		AudioManager.play_sysse("chg1")
		parent.queue_free()
	)
	parent.add_child(button)


func _toggle_extra_stand_controls() -> void:
	for child in get_children():
		var child_name := str(child.name)
		if child_name.begins_with("stand_cmd_") or child_name.begins_with("static_action_edit_"):
			child.visible = not child.visible


func _scnchart_runtime_layer_path(path: String) -> bool:
	var prefixes := [
		"chara_btn/",
		"btn/",
		"bottom_button/",
		"menu_button/",
		"scrollbar/knob/",
	]
	if _starts_with_any(path, prefixes):
		return true
	if path in ["#curselected", "#scroll"]:
		return true
	return false


func _build_scnchart_runtime() -> void:
	if screen_name != "scnchart":
		return
	scnchart_runtime_layer = Control.new()
	scnchart_runtime_layer.name = "scnchart_runtime"
	scnchart_runtime_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	scnchart_runtime_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scnchart_runtime_layer)
	_redraw_scnchart_runtime()


func _build_backlog_runtime() -> void:
	if screen_name != "backlog":
		return
	backlog_runtime_layer = Control.new()
	backlog_runtime_layer.name = "backlog_runtime"
	backlog_runtime_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# This layer is above the story and owns all unused pixels between the
	# interactive controls.  Child Buttons retain their own STOP filters, so
	# hover/pressed states still arrive at the button first.
	backlog_runtime_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	backlog_runtime_layer.gui_input.connect(_on_backlog_gui_input)
	add_child(backlog_runtime_layer)
	# The first displayed page must be complete on the first render. Later rows
	# stay incrementally warmed so scrolling cannot stall on a newly encountered
	# Japanese glyph.
	_warm_visible_backlog_glyphs()
	_redraw_backlog_runtime()


func _on_backlog_gui_input(event: InputEvent) -> void:
	if not runtime_input_enabled:
		return
	# The full-screen layer consumes clicks in empty regions, while actual
	# Buttons receive their own gui_input and pressed/hover signals.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()


func _handle_backlog_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_backlog_hover(event.position / ui_scale())
		if dragging_backlog_scrollbar:
			_set_backlog_scrollbar_position(event.position.y / ui_scale().y, backlog_scrollbar_grab_offset, true)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	var source_position := mouse_event.position / ui_scale()
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if not mouse_event.pressed:
			action_requested.emit("back")
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
		_handle_backlog_scroll_rows(-1)
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
		_handle_backlog_scroll_rows(1)
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if _backlog_scrollbar_contains(mouse_event.position):
			dragging_backlog_scrollbar = true
			var max_start := maxi(1, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
			var thumb_y := lerpf(211.0, 773.0, clampf(backlog_visual_start / float(max_start), 0.0, 1.0))
			# Preserve the point grabbed inside the thumb. A track click keeps the
			# original behavior and places the thumb at the pointer position.
			backlog_scrollbar_grab_offset = source_position.y - thumb_y if absf(source_position.y - thumb_y) <= 75.0 else 0.0
			_set_backlog_scrollbar_position(source_position.y, backlog_scrollbar_grab_offset, true)
		get_viewport().set_input_as_handled()
		return
	if dragging_backlog_scrollbar:
		dragging_backlog_scrollbar = false
		backlog_scrollbar_grab_offset = 0.0
		get_viewport().set_input_as_handled()
		return
	var action := _backlog_action_at(source_position)
	if action != "":
		AudioManager.play_sysse("chg1")
		action_requested.emit(action)
	get_viewport().set_input_as_handled()


func _backlog_action_at(source_position: Vector2) -> String:
	for item in [
		{"rect": Rect2(991, 998, 276, 56), "action": "flowchart"},
		{"rect": Rect2(1272, 998, 276, 56), "action": "title"},
		{"rect": Rect2(1553, 998, 276, 56), "action": "back"},
		{"rect": Rect2(1652, 104, 49, 48), "action": "top"},
		{"rect": Rect2(1652, 157, 49, 48), "action": "pageup"},
		{"rect": Rect2(1652, 879, 49, 48), "action": "pagedown"},
		{"rect": Rect2(1652, 932, 49, 48), "action": "end"},
	]:
		if Rect2(item["rect"]).has_point(source_position):
			return str(item["action"])
	var first := clampi(backlog_draw_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	for row in range(BACKLOG_VISIBLE_ROWS):
		var entry_index := first + row
		if entry_index >= backlog_entries.size():
			continue
		var y := 172.0 + row * BACKLOG_ROW_SOURCE_HEIGHT
		var items := [{"x": 323.0, "action": "backlog_jump:%d" % entry_index}]
		var voice := str(Dictionary(backlog_entries[entry_index]).get("voice", ""))
		if voice != "":
			items.append({"x": 380.0, "action": "backlog_favorite:%d" % entry_index})
			items.append({"x": 437.0, "action": "backlog_voice:%s" % voice})
		for item in items:
			if Rect2(float(item["x"]), y, 49, 48).has_point(source_position):
				return str(item["action"])
	return ""


func _update_backlog_hover(source_position: Vector2) -> void:
	if backlog_runtime_layer == null:
		return
	for node in backlog_runtime_layer.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		# event.position is viewport-space while the generated controls may be
		# nested under the animated content layer. Comparing against the actual
		# global rect keeps hover exact at every scale and scroll offset.
		var hovered := button.get_global_rect().has_point(source_position * ui_scale())
		_set_backlog_button_state(button, "hover" if hovered else "normal")


func _set_backlog_button_state(button: Button, state: String) -> void:
	if button == null or not is_instance_valid(button):
		return
	for state_name in ["normal", "hover", "pressed"]:
		var background := button.get_node_or_null("background_" + state_name) as CanvasItem
		if background != null:
			background.visible = state_name == state
		var text_node := button.get_node_or_null("text_" + state_name) as CanvasItem
		if text_node != null:
			text_node.visible = state_name == state
	var normal_icon := button.get_node_or_null("icon_normal") as CanvasItem
	var pressed_icon := button.get_node_or_null("icon_pressed") as CanvasItem
	if normal_icon != null:
		normal_icon.visible = state != "pressed"
	if pressed_icon != null:
		pressed_icon.visible = state == "pressed"


func _backlog_scrollbar_contains(viewport_position: Vector2) -> bool:
	var source_position := viewport_position / ui_scale()
	return Rect2(1652, 211, 49, 662).has_point(source_position)


func _set_backlog_scrollbar_position(source_y: float, grab_offset: float = 0.0, direct: bool = false) -> void:
	var max_start := maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	if max_start <= 0:
		return
	var ratio := clampf((source_y - grab_offset - 211.0) / (773.0 - 211.0), 0.0, 1.0)
	var next_position := ratio * float(max_start)
	var next_start := clampi(int(round(next_position)), 0, max_start)
	if direct:
		backlog_start = next_start
		backlog_scroll_target = next_position
		backlog_visual_start = next_position
		backlog_scroll_origin = next_position
		backlog_scroll_elapsed = BACKLOG_SCROLL_TIME
		var next_draw_start := clampi(int(floor(next_position)), 0, max_start)
		if next_draw_start != backlog_draw_start:
			backlog_draw_start = next_draw_start
			_redraw_backlog_entries_only()
		_update_backlog_content_position()
		_update_backlog_scrollbar_visual()
		return
	if next_start != backlog_start:
		_request_backlog_scroll(next_start)


func _handle_backlog_scroll_rows(rows: int) -> void:
	var max_start := maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	var next_start := clampi(backlog_start + rows, 0, max_start)
	if next_start == backlog_start:
		return
	_request_backlog_scroll(next_start)


func _request_backlog_scroll(next_start: int) -> void:
	backlog_start = clampi(next_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	backlog_scroll_origin = backlog_visual_start
	backlog_scroll_target = float(backlog_start)
	backlog_scroll_elapsed = 0.0
	_prioritize_backlog_glyphs(backlog_start)
	_update_backlog_scrollbar_visual()


func _queue_backlog_glyph_warmup() -> void:
	var queued: Dictionary = {}
	backlog_glyph_warmup = PackedInt32Array()
	backlog_glyph_warmup_index = 0
	for entry_value in backlog_entries:
		var entry: Dictionary = Dictionary(entry_value)
		for codepoint in TftBitmapText.codepoints_in_text("【%s】%s" % [str(entry.get("name", "")), str(entry.get("text", ""))]):
			if queued.has(codepoint):
				continue
			queued[codepoint] = true
			backlog_glyph_warmup.append(codepoint)


func _prioritize_backlog_glyphs(first_entry: int) -> void:
	if backlog_glyph_warmup_index >= backlog_glyph_warmup.size():
		return
	var priority := PackedInt32Array()
	var seen: Dictionary = {}
	for entry_index in range(first_entry, mini(first_entry + BACKLOG_VISIBLE_ROWS + 2, backlog_entries.size())):
		var entry: Dictionary = Dictionary(backlog_entries[entry_index])
		for codepoint in TftBitmapText.codepoints_in_text("【%s】%s" % [str(entry.get("name", "")), str(entry.get("text", ""))]):
			if not seen.has(codepoint):
				seen[codepoint] = true
				priority.append(codepoint)
	for index in range(backlog_glyph_warmup_index, backlog_glyph_warmup.size()):
		var codepoint := backlog_glyph_warmup[index]
		if not seen.has(codepoint):
			priority.append(codepoint)
	backlog_glyph_warmup = priority
	backlog_glyph_warmup_index = 0


func _warm_backlog_glyphs() -> void:
	var remaining := BACKLOG_GLYPH_WARMUP_PER_FRAME
	while remaining > 0 and backlog_glyph_warmup_index < backlog_glyph_warmup.size():
		TftBitmapText.prewarm_codepoint(backlog_glyph_warmup[backlog_glyph_warmup_index])
		backlog_glyph_warmup_index += 1
		remaining -= 1
	if remaining < BACKLOG_GLYPH_WARMUP_PER_FRAME:
		for row in backlog_row_cache.values():
			if is_instance_valid(row):
				for text_node in row.find_children("*", "TftBitmapText", true, false):
					text_node.queue_redraw()


func _warm_visible_backlog_glyphs() -> void:
	var first := clampi(backlog_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	var seen: Dictionary = {}
	for entry_index in range(first, mini(first + BACKLOG_VISIBLE_ROWS, backlog_entries.size())):
		var entry: Dictionary = Dictionary(backlog_entries[entry_index])
		for codepoint in TftBitmapText.codepoints_in_text("【%s】%s" % [str(entry.get("name", "")), str(entry.get("text", ""))]):
			if seen.has(codepoint):
				continue
			seen[codepoint] = true
			TftBitmapText.prewarm_codepoint(codepoint)


func _redraw_backlog_runtime() -> void:
	if backlog_runtime_layer == null:
		return
	for child in backlog_runtime_layer.get_children():
		# Redraws happen on every scroll step.  Deferred destruction leaves the
		# previous buttons in the hit-test tree and makes new controls receive
		# generated names, so free this short-lived runtime tree synchronously.
		child.free()
	backlog_row_cache.clear()
	backlog_content_layer = Control.new()
	backlog_content_layer.name = "backlog_content"
	backlog_content_layer.position = Vector2.ZERO
	backlog_content_layer.size = Vector2(1920, 998) * ui_scale()
	backlog_content_layer.clip_contents = true
	backlog_content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backlog_runtime_layer.add_child(backlog_content_layer)
	backlog_draw_start = clampi(int(floor(backlog_visual_start)), 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	backlog_row_nodes.clear()
	_draw_backlog_entries()
	_draw_backlog_date()
	_draw_backlog_scrollbar()
	_draw_backlog_bottom_buttons()
	_update_backlog_content_position()


func _redraw_backlog_entries_only() -> void:
	if backlog_content_layer == null:
		return
	# Keep the four rows that remain visible. Rebuilding all five TFT text
	# textures here was the source of the long input stalls.
	var first := clampi(backlog_draw_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	var desired: Dictionary = {}
	for row in range(BACKLOG_VISIBLE_ROWS):
		var entry_index := first + row
		if entry_index < backlog_entries.size():
			desired[entry_index] = true
	for entry_key in backlog_row_cache.keys():
		if desired.has(entry_key):
			continue
		var stale := backlog_row_cache[entry_key] as Control
		if stale != null and is_instance_valid(stale):
			stale.free()
		backlog_row_cache.erase(entry_key)
	backlog_row_nodes.clear()
	_draw_backlog_entries()
	_update_backlog_content_position()


func _update_backlog_content_position() -> void:
	if backlog_content_layer == null:
		return
	backlog_content_layer.position.y = (float(backlog_draw_start) - backlog_visual_start) * BACKLOG_ROW_SOURCE_HEIGHT * ui_scale().y


func _update_backlog_scrollbar_visual() -> void:
	if backlog_runtime_layer == null:
		return
	var knob := backlog_runtime_layer.find_child("knob", true, false) as Control
	if knob == null:
		return
	var max_start := maxi(1, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	var ratio := clampf(backlog_visual_start / float(max_start), 0.0, 1.0)
	knob.position = Vector2(1667.0, lerpf(211.0, 773.0, ratio)) * ui_scale()


func _draw_backlog_entries() -> void:
	# `backlog_start` is the index of the first visible entry in the full
	# history. Newest entries are kept at the bottom, matching HistoryLayer.
	var first: int = clampi(backlog_draw_start, 0, maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS))
	var backlog_font: Font = SystemSettings.get_message_font()
	for row in range(BACKLOG_VISIBLE_ROWS):
		var entry_index: int = first + row
		if entry_index >= backlog_entries.size():
			continue
		var row_origin := scaled_rect(Rect2(0, row * BACKLOG_ROW_SOURCE_HEIGHT, 1920, BACKLOG_ROW_SOURCE_HEIGHT))
		var holder := backlog_row_cache.get(entry_index) as Control
		if holder == null or not is_instance_valid(holder):
			var entry: Dictionary = Dictionary(backlog_entries[entry_index])
			holder = Control.new()
			holder.name = "backlog_entry_" + str(entry_index)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var content_parent := backlog_content_layer if backlog_content_layer != null else backlog_runtime_layer
			content_parent.add_child(holder)
			# TextRender and its action buttons are local to one 180px history
			# row. The holder supplies the row offset while it is recycled.
			holder.position = row_origin.position
			holder.size = row_origin.size
			var speaker := str(entry.get("name", "")).strip_edges()
			var message := str(entry.get("text", "")).replace("\\n", "\n")
			# backlog.tjs renders these as two independent TextRender areas.
			# Their Y coordinates are row-local; applying the row number here as
			# well would double the scroll offset after the first line.
			var row_y := 104.0
			if speaker != "":
				_make_backlog_text("name", "【%s】" % speaker, Rect2(47, row_y, 457, 158), holder, HORIZONTAL_ALIGNMENT_RIGHT, backlog_font)
			_make_backlog_text("message", message, Rect2(524, row_y, 1115, 158), holder, HORIZONTAL_ALIGNMENT_LEFT, backlog_font)
			_draw_backlog_action_icons(holder, entry, entry_index)
			backlog_row_cache[entry_index] = holder
		holder.position = row_origin.position
		holder.size = row_origin.size
		backlog_row_nodes.append(holder)


func _draw_backlog_date() -> void:
	if backlog_entries.is_empty():
		return
	# `#date` is ShowDateLayer in the original system script. It is a
	# runtime flower/date widget; date_full is a full-screen scene card and
	# must not be scaled into this 219x155 slot.
	var date_layer := Control.new()
	date_layer.name = "backlog_date"
	var code := _backlog_date_code()
	# 0408 is the title-screen opening date used by the reference capture. Its
	# original ShowDateLayer decoration is a raster flower composite, not a
	# five-ellipse approximation. Keep the procedural fallback for dates for
	# which no extracted composite is available.
	var exact_date := code == "0408" and file_exists("res://assets/ui/exported/backlog/date_0408.png")
	var rect := Rect2(1137, 0, 143, 130) if exact_date else scaled_rect(Rect2(1701, 6, 219, 155))
	date_layer.position = rect.position
	date_layer.size = rect.size
	date_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_layer.z_index = 10
	backlog_runtime_layer.add_child(date_layer)
	if exact_date:
		var date_texture := TextureRect.new()
		date_texture.name = "date_0408_exact"
		date_texture.texture = load_texture("res://assets/ui/exported/backlog/date_0408.png")
		date_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		date_texture.stretch_mode = TextureRect.STRETCH_SCALE
		date_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		date_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		date_layer.add_child(date_texture)
		return
	var flower_center := Vector2(date_layer.size.x * 0.52, date_layer.size.y * 0.60)
	var petal_specs := [
		[Vector2(0.0, -1.0), -0.10],
		[Vector2(0.92, -0.28), 0.86],
		[Vector2(0.54, 0.82), 2.05],
		[Vector2(-0.54, 0.82), 3.17],
		[Vector2(-0.92, -0.28), 4.28],
	]
	var petal_radius := Vector2(date_layer.size.x * 0.15, date_layer.size.y * 0.25)
	for index in range(petal_specs.size()):
		var spec: Array = petal_specs[index]
		var center: Vector2 = flower_center + Vector2(spec[0]) * Vector2(date_layer.size.x * 0.17, date_layer.size.y * 0.20)
		var angle := float(spec[1])
		_add_date_petal(date_layer, center + Vector2(1.5, 2.0), petal_radius, angle, Color(0.36, 0.12, 0.20, 0.55), "shadow_%d" % index)
		_add_date_petal(date_layer, center, petal_radius, angle, Color(1.0, 0.76, 0.84, 0.94), "petal_%d" % index)
		_add_date_petal(date_layer, center, petal_radius * 0.78, angle, Color(1.0, 0.56, 0.70, 0.34), "inner_%d" % index)
	_add_date_petal(date_layer, flower_center + Vector2(1.5, 2.0), Vector2(date_layer.size.x * 0.06, date_layer.size.y * 0.075), 0.0, Color(0.36, 0.12, 0.20, 0.52), "center_shadow")
	_add_date_petal(date_layer, flower_center, Vector2(date_layer.size.x * 0.06, date_layer.size.y * 0.075), 0.0, Color(1.0, 0.46, 0.62, 0.95), "center")
	var month := int(code.substr(0, 2)) if code.length() >= 4 else 4
	var day := int(code.substr(2, 2)) if code.length() >= 4 else 8
	var date_text := "%d/%d" % [month, day]
	var date_label := Label.new()
	date_label.name = "date_text"
	date_label.text = date_text
	date_label.position = Vector2(date_layer.size.x * 0.08, date_layer.size.y * 0.16)
	date_label.size = Vector2(date_layer.size.x * 0.68, date_layer.size.y * 0.47)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_label.add_theme_font_override("font", SystemSettings.get_message_font())
	date_label.add_theme_font_size_override("font_size", maxi(20, int(date_layer.size.y * 0.38)))
	date_label.add_theme_color_override("font_color", Color("f04e82"))
	date_label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.91, 0.95))
	date_label.add_theme_constant_override("outline_size", 3)
	date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_layer.add_child(date_label)
	var weekday := _backlog_weekday(month, day)
	var weekday_label := Label.new()
	weekday_label.name = "weekday"
	weekday_label.text = "(%s)" % weekday
	weekday_label.position = Vector2(date_layer.size.x * 0.57, date_layer.size.y * 0.53)
	weekday_label.size = Vector2(date_layer.size.x * 0.30, date_layer.size.y * 0.25)
	weekday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekday_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weekday_label.add_theme_font_override("font", SystemSettings.get_message_font())
	weekday_label.add_theme_font_size_override("font_size", maxi(11, int(date_layer.size.y * 0.16)))
	weekday_label.add_theme_color_override("font_color", Color("f04e82"))
	weekday_label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.91, 0.95))
	weekday_label.add_theme_constant_override("outline_size", 2)
	weekday_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_layer.add_child(weekday_label)


func _add_date_petal(parent: Control, center: Vector2, radius: Vector2, angle: float, color: Color, node_name: String) -> void:
	var petal := Polygon2D.new()
	petal.name = node_name
	var points := PackedVector2Array()
	for index in range(32):
		var theta := TAU * float(index) / 32.0
		var point := Vector2(cos(theta) * radius.x, sin(theta) * radius.y).rotated(angle)
		points.append(point)
	petal.polygon = points
	petal.position = center
	petal.color = color
	parent.add_child(petal)


func _backlog_weekday(month: int, day: int) -> String:
	# The original widget prints the Japanese weekday next to the date.
	# The game timeline is a 200x calendar and these dates use the real
	# 2010 calendar represented by the original date cards.
	var date := Time.get_datetime_dict_from_system()
	date["year"] = 2010
	date["month"] = month
	date["day"] = day
	var unix := Time.get_unix_time_from_datetime_dict(date)
	return ["日", "月", "火", "水", "木", "金", "土"][int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))]


func _backlog_date_code() -> String:
	var pattern := RegEx.new()
	if pattern.compile("(?<![0-9])[0-9]{4}(?![0-9])") != OK:
		return "0408"
	for index in range(backlog_entries.size() - 1, -1, -1):
		var entry: Variant = backlog_entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var state: Variant = Dictionary(entry).get("state", {})
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var target := str(Dictionary(state).get("target", ""))
		var match := pattern.search(target)
		if match != null:
			return match.get_string()
	return "0408"


func _make_backlog_label(node_name: String, label_text: String, source_rect: Rect2, parent: Control, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = label_text
	label.position = scaled_rect(source_rect).position
	label.size = scaled_rect(source_rect).size
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", -7)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", BACKLOG_TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _make_backlog_text(node_name: String, label_text: String, source_rect: Rect2, parent: Control, alignment: HorizontalAlignment, fallback_font: Font) -> Control:
	var bitmap_text := TftBitmapText.new()
	bitmap_text.name = node_name
	bitmap_text.configure(label_text, source_rect, alignment)
	# TFTBitmapText receives the source-space rectangle so it can reproduce the
	# original text metrics. The rectangle is row-local, matching the fallback.
	parent.add_child(bitmap_text)
	if bitmap_text.texture != null:
		return bitmap_text
	var fallback := _make_backlog_label(node_name + "_fallback", label_text, source_rect, parent, fallback_font)
	fallback.horizontal_alignment = alignment
	return fallback


func _draw_backlog_action_icons(parent: Control, entry: Dictionary, entry_index: int) -> void:
	var icon_ids := [
		{"x": 323.0, "normal": 6641, "pressed": 6651, "ox": 9.0, "oy": 14.0, "w": 30.0, "h": 19.0, "px": 10.0, "py": 15.0, "pw": 28.0, "ph": 17.0},
	]
	if str(entry.get("voice", "")) != "":
		icon_ids.append({"x": 380.0, "normal": 6649 if bool(entry.get("favorite", false)) else 6639, "pressed": 6649, "ox": 11.0, "oy": 12.0, "w": 25.0, "h": 23.0, "px": 12.0, "py": 13.0, "pw": 23.0, "ph": 21.0})
		icon_ids.append({"x": 437.0, "normal": 6638, "pressed": 6648, "ox": 10.0, "oy": 13.0, "w": 28.0, "h": 21.0, "px": 11.0, "py": 14.0, "pw": 26.0, "ph": 19.0})
	for item in icon_ids:
		var button := Button.new()
		button.name = "backlog_action_%d_%d" % [entry_index, int(item["x"])]
		var source_rect := Rect2(float(item["x"]), 172, 49, 48)
		button.position = scaled_rect(source_rect).position
		button.size = scaled_rect(source_rect).size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var bg := TextureRect.new()
		bg.name = "background_normal"
		bg.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), 6430))
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(bg)
		for state in ["hover", "pressed"]:
			var state_bg := TextureRect.new()
			state_bg.name = "background_" + state
			state_bg.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), 6455 if state == "hover" else 6480))
			state_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			state_bg.stretch_mode = TextureRect.STRETCH_SCALE
			state_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			state_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			state_bg.visible = false
			button.add_child(state_bg)
		var content := TextureRect.new()
		content.name = "icon_normal"
		content.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), int(item["normal"])))
		content.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		content.stretch_mode = TextureRect.STRETCH_SCALE
		content.position = scaled_rect(Rect2(float(item["ox"]), float(item["oy"]), float(item["w"]), float(item["h"]))).position
		content.size = scaled_rect(Rect2(Vector2.ZERO, Vector2(float(item["w"]), float(item["h"])))).size
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		var content_pressed := TextureRect.new()
		content_pressed.name = "icon_pressed"
		content_pressed.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), int(item["pressed"])))
		content_pressed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		content_pressed.stretch_mode = TextureRect.STRETCH_SCALE
		content_pressed.position = scaled_rect(Rect2(float(item["px"]), float(item["py"]), float(item["pw"]), float(item["ph"]))).position
		content_pressed.size = scaled_rect(Rect2(Vector2.ZERO, Vector2(float(item["pw"]), float(item["ph"])))).size
		content_pressed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_pressed.visible = false
		button.add_child(content_pressed)
		button.mouse_entered.connect(func() -> void: _set_backlog_button_state(button, "hover"))
		button.mouse_exited.connect(func() -> void: _set_backlog_button_state(button, "normal"))
		button.button_down.connect(func() -> void: _set_backlog_button_state(button, "pressed"))
		button.button_up.connect(func() -> void: _set_backlog_button_state(button, "hover" if button.is_hovered() else "normal"))
		var content_id: int = int(item["normal"])
		var voice_name := str(entry.get("voice", ""))
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			if content_id == 6641:
				action_requested.emit("backlog_jump:%d" % entry_index)
			elif content_id == 6639 or content_id == 6649:
				action_requested.emit("backlog_favorite:%d" % entry_index)
			elif content_id == 6638 and voice_name != "":
				action_requested.emit("backlog_voice:" + voice_name)
		)
		parent.add_child(button)


func _draw_backlog_scrollbar() -> void:
	var rail := _slot_from_layer_path("scrollbar/scrollbar")
	var knob := _slot_from_layer_path("scrollbar/knob/off")
	if rail.is_empty() or knob.is_empty():
		return
	# `add_texture()` accepts source-space rectangles and performs the only
	# source-to-viewport conversion. Passing an already scaled rectangle here
	# shifts the rail to the middle of the screen.
	var rail_rect := rect_from_dict(rail.get("rect", {}))
	# The rectangle passed to add_texture is source-space; scaling its size a
	# second time makes the thumb 2/3 too small in both axes.
	var knob_rect := rect_from_dict(knob.get("rect", {}))
	var max_start: int = maxi(1, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	var ratio := clampf(backlog_visual_start / float(max_start), 0.0, 1.0)
	# The slider thumb is the 20x100 inner asset. Its travel follows the
	# scrollbar track's usable range, leaving one thumb height at the bottom.
	var y := lerpf(211.0, 773.0, ratio)
	var holder := Control.new()
	holder.name = "backlog_scrollbar_runtime"
	holder.position = Vector2.ZERO
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backlog_runtime_layer.add_child(holder)
	var rail_node := add_texture(holder, layer_path(str(compiled_ui.get("layer_dir", "")), rail.get("layer_id", "")), rail_rect, "rail")
	rail_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_node := add_texture(holder, layer_path(str(compiled_ui.get("layer_dir", "")), knob.get("layer_id", "")), Rect2(Vector2(1667, y), knob_rect.size), "knob")
	knob_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in [
		{"name":"top", "off":6634, "on":6647, "y":104, "ox":12.0, "oy":11.0, "w":23.0, "h":25.0, "onx":13.0, "ony":12.0, "onw":21.0, "onh":23.0},
		{"name":"pageup", "off":6635, "on":6646, "y":157, "ox":12.0, "oy":12.0, "w":23.0, "h":20.0, "onx":13.0, "ony":13.0, "onw":21.0, "onh":18.0},
		{"name":"pagedown", "off":6521, "on":6645, "y":879, "ox":12.0, "oy":14.0, "w":23.0, "h":20.0, "onx":13.0, "ony":15.0, "onw":21.0, "onh":18.0},
		{"name":"end", "off":6519, "on":6644, "y":932, "ox":12.0, "oy":11.0, "w":23.0, "h":25.0, "onx":13.0, "ony":12.0, "onw":21.0, "onh":23.0},
	]:
		var button := Button.new()
		button.name = "backlog_" + str(item["name"])
		button.position = scaled_rect(Rect2(1652, float(item["y"]), 49, 48)).position
		button.size = scaled_rect(Rect2(1652, float(item["y"]), 49, 48)).size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for state in ["normal", "hover", "pressed"]:
			var bg := TextureRect.new()
			bg.name = "background_" + state
			bg.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), 6430 if state == "normal" else (6455 if state == "hover" else 6480)))
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.visible = state == "normal"
			button.add_child(bg)
		var icon_normal := TextureRect.new()
		icon_normal.name = "icon_normal"
		icon_normal.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), int(item["off"])))
		icon_normal.position = scaled_rect(Rect2(float(item["ox"]), float(item["oy"]), float(item["w"]), float(item["h"]))).position
		icon_normal.size = scaled_rect(Rect2(Vector2.ZERO, Vector2(float(item["w"]), float(item["h"])))).size
		icon_normal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon_normal)
		var icon_pressed := TextureRect.new()
		icon_pressed.name = "icon_pressed"
		icon_pressed.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), int(item["on"])))
		icon_pressed.position = scaled_rect(Rect2(float(item["onx"]), float(item["ony"]), float(item["onw"]), float(item["onh"]))).position
		icon_pressed.size = scaled_rect(Rect2(Vector2.ZERO, Vector2(float(item["onw"]), float(item["onh"])))).size
		icon_pressed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_pressed.visible = false
		button.add_child(icon_pressed)
		button.mouse_entered.connect(func() -> void: _set_backlog_button_state(button, "hover"))
		button.mouse_exited.connect(func() -> void: _set_backlog_button_state(button, "normal"))
		button.button_down.connect(func() -> void: _set_backlog_button_state(button, "pressed"))
		button.button_up.connect(func() -> void: _set_backlog_button_state(button, "hover" if button.is_hovered() else "normal"))
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			_handle_backlog_scroll(str(item["name"]))
		)
		holder.add_child(button)


func _handle_backlog_scroll(action: String) -> void:
	var max_start: int = maxi(0, backlog_entries.size() - BACKLOG_VISIBLE_ROWS)
	match action:
		"top": _request_backlog_scroll(0)
		"pageup": _request_backlog_scroll(max(0, backlog_start - BACKLOG_VISIBLE_ROWS))
		"pagedown": _request_backlog_scroll(min(max_start, backlog_start + BACKLOG_VISIBLE_ROWS))
		"end": _request_backlog_scroll(max_start)


func _draw_backlog_menu_buttons() -> void:
	var items := [
		{"name":"jump", "x":323.0, "content":6651},
		{"name":"vsave", "x":380.0, "content":6649},
		{"name":"vreplay", "x":437.0, "content":6650},
	]
	for item in items:
		var button := Button.new()
		button.name = "backlog_menu_" + str(item["name"])
		button.position = scaled_rect(Rect2(float(item["x"]), 172, 49, 48)).position
		button.size = scaled_rect(Rect2(float(item["x"]), 172, 49, 48)).size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var bg := TextureRect.new()
		bg.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), 6430))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(bg)
		var icon := TextureRect.new()
		icon.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), int(item["content"])))
		icon.position = scaled_rect(Rect2(10, 12, 30, 25)).position
		icon.size = scaled_rect(Rect2(10, 12, 30, 25)).size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			if str(item["name"]) == "jump":
				action_requested.emit("jump")
		)
		backlog_runtime_layer.add_child(button)


func _draw_backlog_bottom_buttons() -> void:
	var items := [
		{"name":"flowchart", "text":6756, "x":991.0, "action":"flowchart"},
		{"name":"title", "text":6737, "x":1272.0, "action":"title"},
		{"name":"back", "text":6755, "x":1553.0, "action":"back"},
	]
	for item in items:
		var button := Button.new()
		button.name = "backlog_bottom_" + str(item["name"])
		button.position = scaled_rect(Rect2(float(item["x"]), 998, 276, 56)).position
		button.size = scaled_rect(Rect2(float(item["x"]), 998, 276, 56)).size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_style := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty_style)
		button.add_theme_stylebox_override("hover", empty_style)
		button.add_theme_stylebox_override("pressed", empty_style)
		button.add_theme_stylebox_override("focus", empty_style)
		for state in ["normal", "hover", "pressed"]:
			var background := TextureRect.new()
			background.name = "background_" + state
			var background_id := 6729 if state == "normal" else (6730 if state == "hover" else 6731)
			background.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), background_id))
			background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			background.stretch_mode = TextureRect.STRETCH_SCALE
			var background_rect := Rect2(float(item["x"]) + (1.0 if state == "normal" else 2.0), 998.0, 275.0 if state == "normal" else 272.0, 56.0 if state == "normal" else 62.0)
			background.position = scaled_rect(background_rect).position - button.position
			background.size = scaled_rect(Rect2(Vector2.ZERO, background_rect.size)).size
			background.mouse_filter = Control.MOUSE_FILTER_IGNORE
			background.visible = state == "normal"
			button.add_child(background)
		var text_states := {
			"normal": 6756 if str(item["name"]) == "flowchart" else (6737 if str(item["name"]) == "title" else 6755),
			"hover": 6760 if str(item["name"]) == "flowchart" else (6742 if str(item["name"]) == "title" else 6759),
			"pressed": 6764 if str(item["name"]) == "flowchart" else (6747 if str(item["name"]) == "title" else 6763),
		}
		var text_sizes := {
			"flowchart": {"normal": Vector2(141, 22), "hover": Vector2(143, 24), "pressed": Vector2(143, 24)},
			"title": {"normal": Vector2(181, 22), "hover": Vector2(183, 24), "pressed": Vector2(183, 24)},
			"back": {"normal": Vector2(163, 25), "hover": Vector2(163, 25), "pressed": Vector2(163, 25)},
		}
		var text_nodes: Dictionary = {}
		var background_nodes: Dictionary = {}
		for state_name in ["normal", "hover", "pressed"]:
			for child in button.get_children():
				if str(child.name) == "background_" + state_name:
					background_nodes[state_name] = child
		for state_name in text_states.keys():
			var text_node := TextureRect.new()
			text_node.name = "text_" + str(state_name)
			text_node.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), text_states[state_name]))
			text_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			text_node.stretch_mode = TextureRect.STRETCH_SCALE
			var text_size: Vector2 = text_sizes[str(item["name"])][state_name]
			var text_source_position := Vector2(float(item["x"]) + (276.0 - text_size.x) * 0.5, 998.0 + (56.0 - text_size.y) * 0.5)
			text_node.position = scaled_rect(Rect2(text_source_position, text_size)).position - button.position
			text_node.size = scaled_rect(Rect2(Vector2.ZERO, text_size)).size
			text_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_node.visible = state_name == "normal"
			button.add_child(text_node)
			text_nodes[state_name] = text_node
		button.mouse_entered.connect(func() -> void:
			background_nodes["normal"].visible = false
			background_nodes["hover"].visible = true
			text_nodes["normal"].visible = false
			text_nodes["hover"].visible = true
		)
		button.mouse_exited.connect(func() -> void:
			background_nodes["normal"].visible = true
			background_nodes["hover"].visible = false
			background_nodes["pressed"].visible = false
			text_nodes["normal"].visible = true
			text_nodes["hover"].visible = false
		)
		button.button_down.connect(func() -> void:
			background_nodes["normal"].visible = false
			background_nodes["hover"].visible = false
			background_nodes["pressed"].visible = true
			text_nodes["hover"].visible = false
			text_nodes["pressed"].visible = true
		)
		button.button_up.connect(func() -> void:
			background_nodes["pressed"].visible = false
			background_nodes["hover"].visible = button.is_hovered()
			background_nodes["normal"].visible = not button.is_hovered()
			text_nodes["pressed"].visible = false
			text_nodes["hover"].visible = button.is_hovered()
			text_nodes["normal"].visible = not button.is_hovered()
		)
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			action_requested.emit(str(item["action"]))
		)
		backlog_runtime_layer.add_child(button)


func _style_texture(layer_id: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), layer_id))
	style.texture_margin_left = 0
	style.texture_margin_top = 0
	style.texture_margin_right = 0
	style.texture_margin_bottom = 0
	return style


func _redraw_scnchart_runtime() -> void:
	if scnchart_runtime_layer == null:
		return
	for child in scnchart_runtime_layer.get_children():
		child.queue_free()
	_draw_scnchart_route_buttons()
	_draw_scnchart_nodes()
	_draw_scnchart_scroll_controls()
	_draw_scnchart_bottom_buttons()
	_draw_scnchart_preview()


func _draw_scnchart_route_buttons() -> void:
	var prototype := _find_object("_route")
	if prototype.is_empty():
		return
	var slots: Dictionary = prototype.get("slots", {})
	# The `_route` slots are authored against page0's box; every other page is
	# that design sample shifted onto its `##chara_btn/N` marker.
	var prototype_origin := scaled_rect(rect_from_dict(_find_object("page0").get("rect", {}))).position
	if prototype_origin == Vector2.ZERO:
		prototype_origin = scaled_rect(Rect2(1580, 75, 137, 86)).position
	for index in range(SCNCHART_ROUTES.size()):
		var object := _find_object("page" + str(index))
		if object.is_empty():
			continue
		var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
		if rect.size == Vector2.ZERO:
			continue
		var is_active := index == scnchart_page
		var holder := Control.new()
		holder.name = "scnchart_route_" + str(index)
		holder.position = rect.position
		holder.size = rect.size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scnchart_runtime_layer.add_child(holder)
		_add_slot_texture(holder, _slot(slots, ["on" if is_active else "off"]), prototype_origin)
		_add_slot_texture(holder, _slot(slots, ["n_ipage" + str(index) if is_active else "f_ipage" + str(index)]), prototype_origin)
		_add_slot_texture(holder, _slot(slots, ["n_tpage" + str(index) if is_active else "f_tpage" + str(index)]), prototype_origin)
		_add_scnchart_route_hitbox(rect, index)


func _add_scnchart_route_hitbox(target_rect: Rect2, page_index: int) -> void:
	var button := Button.new()
	button.name = "scnchart_route_hit_" + str(page_index)
	button.text = ""
	button.position = target_rect.position
	button.size = target_rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.pressed.connect(func() -> void:
		AudioManager.play_sysse("chg1")
		scnchart_page = page_index
		scnchart_scroll = 0
		scnchart_selected = 0
		_redraw_scnchart_runtime()
	)
	scnchart_runtime_layer.add_child(button)


func _draw_scnchart_nodes() -> void:
	var visible_count := SCNCHART_VISIBLE_NODES
	var start_index := clampi(scnchart_scroll, 0, max(0, SCNCHART_NODE_TITLES.size() - visible_count))
	var viewport := _scnchart_chart_viewport()
	var holder := Control.new()
	holder.name = "scnchart_node_list"
	holder.position = viewport.position
	holder.size = viewport.size
	# The original chart lives inside the `#scroll` layer, which clips whatever
	# scrolled past its bounds (scnchart_ui.tjs `updateScrollView`).
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scnchart_runtime_layer.add_child(holder)
	var step := scaled_rect(Rect2(0, 0, 0, SCNCHART_ITEM_STEP)).size.y
	# The row templates are single design samples anchored at the vertical centre
	# of the chart: a 7-row stack centred in `#scroll` puts its middle row back on
	# the template's own y (982/2 - 74/2 ~= 454 vs the authored 459).
	var template_probe := scaled_rect(_scnchart_template_rect(true))
	var stack_height := step * float(visible_count - 1) + template_probe.size.y
	var stack_top := viewport.position.y + maxf(0.0, (viewport.size.y - stack_height) * 0.5) - step * float(start_index)
	var previous_local := Rect2()
	for i in range(visible_count):
		var row_index := start_index + i
		if row_index >= SCNCHART_NODE_TITLES.size():
			break
		var is_section := row_index == 0
		# A row is the authored template texture translated along the chart's own
		# scroll axis; the template keeps its design coordinates so every slot
		# texture still lines up with its own `rect`.
		var template := scaled_rect(_scnchart_template_rect(is_section))
		var local := Rect2(
			Vector2(template.position.x - viewport.position.x, stack_top - viewport.position.y + step * float(i)),
			template.size
		)
		if i > 0:
			_add_scnchart_connector(holder, previous_local, local)
		previous_local = local
		var is_selected := row_index == scnchart_selected
		var row := Control.new()
		row.name = "scnchart_node_" + str(row_index)
		row.position = local.position
		row.size = local.size
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(row)
		var slots: Dictionary = _find_object("section" if is_section else "subsection").get("slots", {})
		var origin := template.position
		_add_slot_texture(row, _slot(slots, ["over" if is_selected else "off/toggle", "off"]), origin)
		var text_slot: Dictionary = slots.get("text:rect", {})
		var label_rect := Rect2(0.0, 8.0, template.size.x, template.size.y - 16.0)
		if not text_slot.is_empty():
			var text_rect := scaled_rect(rect_from_dict(text_slot.get("rect", {})))
			if text_rect.size != Vector2.ZERO:
				label_rect = Rect2(text_rect.position - origin, text_rect.size)
		var prefix := "★ " if is_selected else ""
		_add_centered_label(row, prefix + str(SCNCHART_NODE_TITLES[row_index]), label_rect, 16, Color8(125, 71, 103), false)
		if row_index == 5:
			_draw_scnchart_branch_marker(holder, local)
	_add_scnchart_node_reveal_buttons(start_index, visible_count, step, stack_top)


## The chart's scroll-axis step and the PSD template anchor come from the
## original data, not from hand-tuned numbers: `default.tjs`
## `.scnchartUiItemConsts` gives `section/subsection step:(100)` (with
## `firstofs step:(80)`), and the `section`/`subsection` objects in
## `scnchart.ini` are the designer's templates for a node row.
func _scnchart_template_rect(is_section: bool) -> Rect2:
	var object := _find_object("section" if is_section else "subsection")
	var slots: Dictionary = object.get("slots", {})
	var slot: Dictionary = slots.get("rect", {})
	var rect := rect_from_dict(slot.get("rect", {}))
	if rect.size == Vector2.ZERO:
		rect = SCNCHART_SECTION_FALLBACK if is_section else SCNCHART_SUBSECTION_FALLBACK
	return rect


func _scnchart_chart_viewport() -> Rect2:
	var object := _find_object("scroll")
	var rect := rect_from_dict(object.get("rect", {}))
	if rect.size == Vector2.ZERO:
		rect = SCNCHART_SCROLL_FALLBACK
	return scaled_rect(rect)


func _add_scnchart_connector(parent: Control, from_local: Rect2, to_local: Rect2) -> void:
	var gap_top := from_local.position.y + from_local.size.y
	var gap_bottom := to_local.position.y
	if gap_bottom <= gap_top:
		return
	var line := ColorRect.new()
	line.name = "scnchart_connector"
	line.color = SCNCHART_LINE_COLOR
	line.position = Vector2(from_local.position.x + 16.0, gap_top)
	line.size = Vector2(3.0, gap_bottom - gap_top)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _draw_scnchart_branch_marker(parent: Control, row_local: Rect2) -> void:
	var branch := _find_object("branch")
	var slot: Dictionary = branch.get("slots", {}).get("rect", {})
	if slot.is_empty():
		slot = _slot_from_layer_path("btn/branch")
	if slot.is_empty():
		return
	var design := rect_from_dict(slot.get("rect", {}))
	if design.size == Vector2.ZERO:
		return
	# `branch` is a chart item of its own in `scnchart_ui.tjs` (`spread`, its own
	# `step`), sized 65x62 against a 274-wide row.  The PSD parks its single
	# sample overlapping the row's left third purely as a layout sample, so draw
	# it as a badge beside the row instead of over the label.
	var size := scaled_rect(design).size
	var marker := Control.new()
	marker.name = "scnchart_branch_marker"
	marker.position = Vector2(row_local.position.x + row_local.size.x + 8.0, row_local.position.y + (row_local.size.y - size.y) * 0.5)
	marker.size = size
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(marker)
	# origin = the slot's own scaled position: the texture then fills `marker`
	# exactly, independent of the scrolled row's coordinates.
	_add_slot_texture(marker, slot, scaled_rect(design).position)


func _add_scnchart_node_reveal_buttons(start_index: int, visible_count: int, step: float, stack_top: float) -> void:
	var viewport := _scnchart_chart_viewport()
	for i in range(visible_count):
		var row_index := start_index + i
		if row_index >= SCNCHART_NODE_TITLES.size():
			break
		var template := scaled_rect(_scnchart_template_rect(row_index == 0))
		var local := Rect2(
			Vector2(template.position.x - viewport.position.x, stack_top - viewport.position.y + step * float(i)),
			template.size
		)
		# Clip to the chart viewport: a row scrolled past the panel must not stay
		# clickable outside it.
		var visible := local.intersection(Rect2(Vector2.ZERO, viewport.size))
		if visible.size.x <= 1.0 or visible.size.y <= 1.0:
			continue
		var button := Button.new()
		button.name = "scnchart_node_hit_" + str(row_index)
		button.text = ""
		button.position = viewport.position + visible.position
		button.size = visible.size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.pressed.connect(func() -> void:
			AudioManager.play_sysse("chg1")
			scnchart_selected = row_index
			_redraw_scnchart_runtime()
		)
		scnchart_runtime_layer.add_child(button)


func _draw_scnchart_scroll_controls() -> void:
	for item in [
		{"name": "top", "slot": "f_top"},
		{"name": "pageup", "slot": "f_up"},
		{"name": "pagedown", "slot": "f_down"},
		{"name": "end", "slot": "f_end"},
	]:
		_add_scnchart_updown_button(str(item["name"]), str(item["slot"]))
	var knob_slot := _slot_from_layer_path("scrollbar/knob/off")
	if knob_slot.is_empty():
		return
	var knob_rect := scaled_rect(rect_from_dict(knob_slot.get("rect", {})))
	# `slider:rect` is the authored travel of the knob inside the rail
	# (scnchart.ini: `ui,scrollbar/#arrow, @slider:rect`).
	var slider := _find_object("slider")
	var rail_slot: Dictionary = slider.get("slots", {}).get("rect", {})
	var rail := scaled_rect(rect_from_dict(rail_slot.get("rect", {})))
	if rail.size == Vector2.ZERO:
		rail = Rect2(994.0, 92.7, 13.3, 488.7)
	var max_scroll: int = max(1, SCNCHART_NODE_TITLES.size() - SCNCHART_VISIBLE_NODES)
	var travel := maxf(0.0, rail.size.y - knob_rect.size.y)
	var y := rail.position.y + travel * (float(scnchart_scroll) / float(max_scroll))
	var knob := Control.new()
	knob.name = "scnchart_scroll_knob"
	knob.position = Vector2(rail.position.x, y)
	knob.size = knob_rect.size
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scnchart_runtime_layer.add_child(knob)
	_add_slot_texture(knob, knob_slot, knob.position)


func _add_scnchart_updown_button(object_name: String, icon_slot_name: String) -> void:
	var object := _find_object(object_name)
	var prototype := _find_object("_updown")
	if object.is_empty() or prototype.is_empty():
		return
	var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
	var holder := Control.new()
	holder.name = "scnchart_updown_" + object_name
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scnchart_runtime_layer.add_child(holder)
	var slots: Dictionary = prototype.get("slots", {})
	var origin := _prototype_origin(prototype, object)
	_add_slot_texture(holder, _slot(slots, ["off"]), origin)
	_add_slot_texture(holder, _slot(slots, [icon_slot_name]), origin)


func _draw_scnchart_bottom_buttons() -> void:
	var text_slots := {
		"jump": "f_jump",
		"backlog": "f_backlog",
		"title": "f_title",
		"back": "f_back",
	}
	for object_name in text_slots.keys():
		_add_scnchart_nav_button(str(object_name), str(text_slots[object_name]))


func _add_scnchart_nav_button(object_name: String, text_slot_name: String) -> void:
	var object := _find_object(object_name)
	var prototype := _find_object("_navibtn")
	if object.is_empty() or prototype.is_empty():
		return
	var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
	var holder := Control.new()
	holder.name = "scnchart_nav_" + object_name
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scnchart_runtime_layer.add_child(holder)
	var slots: Dictionary = prototype.get("slots", {})
	var origin := _prototype_origin(prototype, object)
	_add_slot_texture(holder, _slot(slots, ["off/button"]), origin)
	_add_slot_texture(holder, _slot(slots, [text_slot_name]), origin)


func _draw_scnchart_preview() -> void:
	var route := str(SCNCHART_ROUTES[scnchart_page])
	var node := str(SCNCHART_NODE_TITLES[scnchart_selected])
	var text := route + "ルート\n" + node + "\n\n選択中の分岐地点です。\nJUMPで再開します。"
	# `playback:text:rect` is the authored text box inside the preview panel
	# (scnchart.ini: `ui,bg/#previewtext, @playback:text:rect`).
	var playback := _find_object("playback")
	var text_slot: Dictionary = playback.get("slots", {}).get("text:rect", {})
	var preview_rect := scaled_rect(rect_from_dict(text_slot.get("rect", {})))
	if preview_rect.size == Vector2.ZERO:
		preview_rect = scaled_rect(Rect2(79, 560, 458, 302))
	var preview_label := _add_runtime_label(scnchart_runtime_layer, text, preview_rect, 18, Color8(176, 104, 136), HORIZONTAL_ALIGNMENT_LEFT)
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var separator := _find_object("separator")
	var title_slot: Dictionary = separator.get("slots", {}).get("text:rect", {})
	var title_rect := scaled_rect(rect_from_dict(title_slot.get("rect", {})))
	if title_rect.size == Vector2.ZERO:
		title_rect = scaled_rect(Rect2(791, 73, 494, 45))
	_add_centered_label(scnchart_runtime_layer, route + " Chapter", title_rect, 25, Color8(205, 70, 118), true)


## The minimap is drawn, not authored: `#minimap` is `rect/layer` with no PNG and
## `scnchartUiLineConsts` supplies its palette (miniline 0x80a987c8,
## minichapt 0xC0eddbe6, minimap brush 0xFFa987c8).  It shows the whole route with
## the rows the scroll view is currently showing.
func _draw_scnchart_minimap() -> void:
	var object := _find_object("minimap")
	var slot: Dictionary = object.get("slots", {}).get("rect/layer", {})
	var minimap := scaled_rect(rect_from_dict(slot.get("rect", {})))
	if minimap.size == Vector2.ZERO:
		minimap = scaled_rect(Rect2(1604, 506, 242, 377))
	var holder := Control.new()
	holder.name = "scnchart_minimap"
	holder.position = minimap.position
	holder.size = minimap.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scnchart_runtime_layer.add_child(holder)
	var count := SCNCHART_NODE_TITLES.size()
	if count <= 0:
		return
	var row_height := 6.0
	var pitch := (minimap.size.y - row_height) / maxf(1.0, float(count - 1))
	var view := ColorRect.new()
	view.name = "scnchart_minimap_view"
	view.color = Color(1.0, 1.0, 1.0, 0.22)
	view.position = Vector2(0.0, float(scnchart_scroll) * pitch - 4.0)
	view.size = Vector2(minimap.size.x, pitch * float(SCNCHART_VISIBLE_NODES - 1) + row_height + 8.0)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(view)
	for index in range(count):
		var bar := ColorRect.new()
		bar.name = "scnchart_minimap_bar_" + str(index)
		if index == scnchart_selected:
			bar.color = SCNCHART_MINIMAP_SELECTED_COLOR
		elif index == 5:
			bar.color = SCNCHART_LINE_QUERY_COLOR
		else:
			bar.color = SCNCHART_MINIMAP_COLOR
		var width := minimap.size.x * (0.78 if index == scnchart_selected else 0.5)
		bar.position = Vector2((minimap.size.x - width) * 0.5, float(index) * pitch)
		bar.size = Vector2(width, row_height)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bar)


func _handle_scnchart_action(action_name: String) -> bool:
	match action_name:
		"top":
			scnchart_scroll = 0
			_redraw_scnchart_runtime()
			return true
		"pageup":
			scnchart_scroll = max(0, scnchart_scroll - 1)
			_redraw_scnchart_runtime()
			return true
		"pagedown":
			scnchart_scroll = min(max(0, SCNCHART_NODE_TITLES.size() - 7), scnchart_scroll + 1)
			_redraw_scnchart_runtime()
			return true
		"end":
			scnchart_scroll = max(0, SCNCHART_NODE_TITLES.size() - 7)
			_redraw_scnchart_runtime()
			return true
		"jump":
			action_requested.emit("jump")
			return true
		_:
			if action_name.begins_with("page"):
				scnchart_page = clampi(int(action_name.trim_prefix("page")), 0, SCNCHART_ROUTES.size() - 1)
				scnchart_scroll = 0
				scnchart_selected = 0
				_redraw_scnchart_runtime()
				return true
			return false


func _add_runtime_label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color8(255, 255, 255, 220))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _add_centered_label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color, bold: bool) -> Label:
	var label := _add_runtime_label(parent, text, rect, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	if bold:
		label.add_theme_color_override("font_outline_color", Color8(255, 255, 255, 210))
		label.add_theme_constant_override("outline_size", 2)
	return label


func _extra_stand_multistate_layer(path: String) -> bool:
	var multistate_prefixes := [
		"bottom_button/text/on",
		"bottom_button/text/over",
		"bottom_button/bt/on",
		"bottom_button/bt/over",
		"btn_control/",
		"character_add_btn/text/on",
		"character_add_btn/text/over",
		"character_add_btn/btn_bg/on",
		"character_add_btn/btn_bg/over",
		"order_btn/text/on",
		"order_btn/text/over",
		"order_btn/bg/on",
		"order_btn/bg/over",
		"radio_btn/text/on",
		"radio_btn/text/over-push",
		"radio_btn/bg/push",
		"radio_btn/bg/on",
		"radio_btn/bg/over",
		"btn_close/on",
		"btn_close/over",
		"btn_lock/bg/on",
		"btn_lock/bg/over",
		"btn_lock/icon/lock",
		"menu_button/icon/on",
		"menu_button/icon/off-over",
		"menu_button/bg/on",
		"menu_button/bg/over",
		"control_menu/btn_back/on",
		"control_menu/btn_back/over",
		"control_menu/btn_prev/on",
		"control_menu/btn_prev/over",
		"control_menu/btn_layer/on",
		"control_menu/btn_layer/over",
		"control_menu/radio_btn/text/on",
		"control_menu/radio_btn/text/over-push",
		"control_menu/radio_btn/bg/push",
		"control_menu/radio_btn/bg/on",
		"control_menu/radio_btn/bg/over",
		"control_menu/knob/on",
		"control_menu/knob/over",
	]
	return _starts_with_any(path, multistate_prefixes)


func _starts_with_any(value: String, prefixes: Array) -> bool:
	for prefix in prefixes:
		if value.begins_with(str(prefix)):
			return true
	return false


func _build_copied_buttons() -> void:
	for object_name in object_map.keys():
		var object: Dictionary = object_map[object_name]
		var prototype_name := str(object.get("prototype", ""))
		var prototype := _find_object(prototype_name) if prototype_name != "" else object
		if prototype.is_empty():
			continue
		var kind := _widget_kind_for_object(str(object.get("name", "")), prototype)
		match kind:
			"radio":
				_add_radio_button(object, prototype)
			"mute", "check":
				_add_toggle_button(object, prototype, kind)
			"button":
				_add_push_button(object, prototype)
			"jump":
				_add_momentary_button(object, prototype, kind)


func _build_checkbox_widgets() -> void:
	for macro in compiled_ui.get("ini", {}).get("macros", []):
		if not str(macro.get("macro", "")) in ["CTX", "TTX", "RDS"]:
			continue
		var args: Array = macro.get("args", [])
		if args.is_empty():
			continue
		var object_name := str(args[0])
		var object := _find_object(object_name)
		if object.is_empty():
			continue
		if runtime_widgets.has(object_name):
			continue
		check_states[object_name] = SystemSettings.get_bool(object_name, false)
		_add_toggle_button(object, object, "check")


func _build_holder_icon_widgets() -> void:
	var icon_slot := _slot_from_layer_path("bg/icon")
	if icon_slot.is_empty():
		return
	var touch_ui := _touch_ui()
	var base_slot := _external_slot_from_layer_path(touch_ui, "btn_com/btn_bg/off")
	var holder_commands := MOUSE_HOLDER_COMMANDS if screen_name == "option_7mouse" else GAMEPAD_HOLDER_COMMANDS
	var source_rect := scaled_rect(rect_from_dict(icon_slot.get("rect", {})))
	for object_name in object_map.keys():
		var object: Dictionary = object_map[object_name]
		if str(object.get("prototype", "")) != "_holder":
			continue
		var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
		if rect.size == Vector2.ZERO:
			continue
		var holder := Control.new()
		holder.name = "holder_icon_" + str(object_name)
		holder.position = rect.position
		holder.size = rect.size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var icon := _add_slot_texture(holder, icon_slot, source_rect.position)
		icon.position = (rect.size - icon.size) * 0.5
		if not touch_ui.is_empty() and not base_slot.is_empty() and holder_commands.has(str(object_name)):
			_add_command_icon("assigned_" + str(object_name), str(holder_commands[str(object_name)]), object, touch_ui, base_slot)


func _build_command_palette_widgets() -> void:
	if not screen_name in ["option_7mouse", "option_9gamepad"]:
		return
	var touch_ui := _touch_ui()
	if touch_ui.is_empty():
		return
	var order := MOUSE_COMMAND_ORDER if screen_name == "option_7mouse" else GAMEPAD_COMMAND_ORDER
	var base_slot := _external_slot_from_layer_path(touch_ui, "btn_com/btn_bg/off")
	if base_slot.is_empty():
		return
	var object_names := MOUSE_COMMAND_OBJECTS if screen_name == "option_7mouse" else GAMEPAD_COMMAND_OBJECTS
	for index in range(min(order.size(), object_names.size())):
		var object_name := str(object_names[index])
		var object := _find_object(object_name)
		if object.is_empty():
			continue
		_add_command_icon(object_name, str(order[index]), object, touch_ui, base_slot)


func _add_command_icon(object_name: String, command_name: String, object: Dictionary, touch_ui: Dictionary, base_slot: Dictionary) -> void:
	var label := str(COMMAND_LABELS.get(command_name, ""))
	if label == "":
		return
	var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
	if rect.size == Vector2.ZERO:
		return
	var base_rect := scaled_rect(rect_from_dict(base_slot.get("rect", {})))
	var item := Control.new()
	item.name = "command_icon_" + object_name
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	_add_external_slot_texture(item, touch_ui, base_slot, base_rect.position)
	_add_external_slot_texture(item, touch_ui, _external_slot_from_layer_path(touch_ui, "btn_com/icon/off/" + label), base_rect.position)
	_add_external_slot_texture(item, touch_ui, _external_slot_from_layer_path(touch_ui, "btn_com/text/off/" + label), base_rect.position)


func _build_slider_widgets() -> void:
	var ini: Dictionary = compiled_ui.get("ini", {})
	var slider_proto := _find_object("_slider")
	if not slider_proto.is_empty():
		var slots: Dictionary = slider_proto.get("slots", {})
		for control in ini.get("typed_controls", []):
			if str(control.get("type", "")) == "slider":
				_add_slider_from_slots(str(control.get("name", "")), control.get("rect", {}), slots, slider_values.get(str(control.get("name", "")), 0.5))
	_build_knob_copy_sliders()


func _build_knob_copy_sliders() -> void:
	var knob_slots := {
		"normal/slider": _slot_from_layer_path("seekbar/knob/off"),
		"over": _slot_from_layer_path("seekbar/knob/over"),
		"on": _slot_from_layer_path("seekbar/knob/on"),
	}
	if Dictionary(knob_slots["normal/slider"]).is_empty():
		return
	for object_name in object_map.keys():
		var object: Dictionary = object_map[object_name]
		var prototype := _find_object(str(object.get("prototype", "")))
		if prototype.is_empty() or str(prototype.get("control_type", "")) != "knob":
			continue
		var slots: Dictionary = prototype.get("slots", {}).duplicate()
		slots["normal/slider"] = knob_slots["normal/slider"]
		slots["over"] = knob_slots["over"]
		slots["on"] = knob_slots["on"]
		var knob_rect: Dictionary = prototype.get("rect", {})
		slots["knob_rect"] = {"rect": knob_rect}
		var control_name := str(object.get("name", ""))
		var value := 1.0
		if control_name == "chv_slider":
			value = slider_values.get("chv", 1.0)
		elif control_name.ends_with("_slider"):
			value = slider_values.get(control_name.trim_suffix("_slider"), value)
		_add_slider_from_slots(control_name, object.get("rect", {}), slots, value)


func _build_value_widgets() -> void:
	var base_slot := _slot_from_layer_path("seekbar/bg/seek_bar/numerics")
	var number_slot := _slot_from_layer_path("numerics_text")
	for control in compiled_ui.get("ini", {}).get("typed_controls", []):
		if not str(control.get("type", "")) in ["val", "slnum"]:
			continue
		var control_name := str(control.get("name", ""))
		if screen_name == "option_4text" and control_name == "winopac":
			continue
		if not base_slot.is_empty() and not number_slot.is_empty():
			_add_value_widget(control_name, control.get("rect", {}), base_slot, number_slot)
		_add_numeric_label(control_name, control.get("rect", {}))


func _add_value_widget(control_name: String, control_rect_dict: Dictionary, base_slot: Dictionary, number_slot: Dictionary) -> void:
	var control_rect := scaled_rect(rect_from_dict(control_rect_dict))
	var base_origin := scaled_rect(rect_from_dict(base_slot.get("rect", control_rect_dict))).position
	var value := Control.new()
	value.name = "value_" + control_name
	value.position = control_rect.position
	value.size = control_rect.size
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value)
	_add_slot_texture(value, base_slot, base_origin)
	_add_slot_texture(value, number_slot, base_origin)


func _build_option4_runtime_widgets() -> void:
	if screen_name != "option_4text":
		return
	_add_option4_heading_bases()
	_add_color_picker_preview()
	_add_window_sample_text()
	_add_winopac_slider()
	_add_slider_number_labels()


func _add_option4_heading_bases() -> void:
	var headings := {
		"label_a": "テキスト速度",
		"label_b": "オート速度",
		"label_c": "オートモードパターン",
		"label_d1": "未読スキップ",
		"label_d2": "選択肢後スキップ",
		"label_e1": "Ｃｔｒｌスキップ",
		"label_e2": "選択肢後オート",
		"label_f1": "ウィンドウ・文字設定",
		"label_f2": "カラー設定",
		"label_g": "ウィンドウ透明度",
	}
	for label_name in headings.keys():
		var object := _find_object(str(label_name))
		if object.is_empty():
			continue
		var prototype := _find_object(str(object.get("prototype", "")))
		if prototype.is_empty():
			continue
		var slot: Dictionary = prototype.get("slots", {}).get("base/layer", {})
		if slot.is_empty():
			continue
		var rect := scaled_rect(rect_from_dict(object.get("rect", {})))
		var source_rect := scaled_rect(rect_from_dict(slot.get("rect", {})))
		var layer := Control.new()
		layer.name = "runtime_heading_" + str(label_name)
		layer.position = rect.position
		layer.size = rect.size
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		_add_slot_texture(layer, slot, source_rect.position)
		var text := Label.new()
		text.text = str(headings[label_name])
		text.position = Vector2(42, 0) * ui_scale()
		text.size = rect.size - Vector2(50, 0) * ui_scale()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", Color(0.64, 0.30, 0.43, 0.96))
		layer.add_child(text)


func _add_color_picker_preview() -> void:
	var hsv := _find_object("hsv")
	if hsv.is_empty():
		return
	var slot: Dictionary = hsv.get("slots", {}).get("rect/layer", {})
	var rect := scaled_rect(rect_from_dict(slot.get("rect", {"x": 1488, "y": 280, "w": 272, "h": 272})))
	var picker := TextureRect.new()
	picker.name = "runtime_color_picker"
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.texture = _make_hsv_picker_texture(int(rect.size.x), int(rect.size.y))
	picker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picker.stretch_mode = TextureRect.STRETCH_SCALE
	picker.position = rect.position
	picker.size = rect.size
	add_child(picker)
	runtime_widgets["hsv_picker"] = {
		"kind": "color_picker",
		"node": picker,
	}
	var hue_marker := TextureRect.new()
	hue_marker.name = "runtime_hue_marker"
	hue_marker.texture = _make_marker_texture(15)
	hue_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hue_marker.size = Vector2(15, 15)
	picker.add_child(hue_marker)
	var sv_marker := TextureRect.new()
	sv_marker.name = "runtime_sv_marker"
	sv_marker.texture = _make_marker_texture(13)
	sv_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv_marker.size = Vector2(13, 13)
	picker.add_child(sv_marker)
	picker.mouse_entered.connect(func() -> void: _show_widget_help(SystemSettings.get_color_target()))
	picker.mouse_exited.connect(func() -> void:
		if not dragging_color_picker:
			_hide_widget_help()
	)
	picker.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			dragging_color_picker = true
			AudioManager.play_sysse("sel2")
			_set_color_from_picker_mouse(picker)
		elif _is_left_release(event):
			_set_color_from_picker_mouse(picker)
			dragging_color_picker = false
			AudioManager.play_sysse("chg1")
		elif event is InputEventMouseMotion and dragging_color_picker:
			_set_color_from_picker_mouse(picker)
	)
	_update_color_picker_markers()


func _make_hsv_picker_texture(width: int, height: int) -> Texture2D:
	var image := Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	var center := Vector2(width, height) * 0.5
	var outer_r := minf(width, height) * 0.48
	var inner_r := minf(width, height) * 0.34
	var p0 := center + Vector2(-inner_r * 0.78, -inner_r * 0.42)
	var p1 := center + Vector2(inner_r * 0.78, -inner_r * 0.42)
	var p2 := center + Vector2(0, inner_r * 0.86)
	for y in range(height):
		for x in range(width):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(center)
			var color := Color(0, 0, 0, 0)
			if d >= inner_r and d <= outer_r:
				var angle := atan2(p.y - center.y, p.x - center.x)
				var hue := fposmod(angle / TAU + 0.15, 1.0)
				color = Color.from_hsv(hue, 1.0, 1.0, 1.0)
			elif _point_in_triangle(p, p0, p1, p2):
				var weights := _triangle_weights(p, p0, p1, p2)
				var hue_color := Color.from_hsv(0.78, 1.0, 0.95, 1.0)
				color = Color.BLACK * weights.x + Color.WHITE * weights.y + hue_color * weights.z
				color.a = 1.0
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _make_marker_texture(size: int) -> Texture2D:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := float(size) * 0.42
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius and d >= radius - 2.0:
				image.set_pixel(x, y, Color(0.05, 0.04, 0.05, 1.0))
			elif d <= radius - 2.0 and d >= radius - 4.0:
				image.set_pixel(x, y, Color(1, 1, 1, 1.0))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var w := _triangle_weights(p, a, b, c)
	return w.x >= 0.0 and w.y >= 0.0 and w.z >= 0.0


func _triangle_weights(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) <= 0.001:
		return Vector3(-1, -1, -1)
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	return Vector3(1.0 - v - w, v, w)


func _set_color_from_picker_mouse(picker: Control) -> void:
	var target := SystemSettings.get_color_target()
	if not COLOR_TARGETS.has(target):
		target = "color_read"
	var local := picker.get_local_mouse_position()
	var size := picker.size
	var center := size * 0.5
	var outer_r := minf(size.x, size.y) * 0.48
	var inner_r := minf(size.x, size.y) * 0.34
	var current := SystemSettings.get_color_for_target(target, Color.WHITE)
	var hsv := _color_to_hsv(current)
	var distance := local.distance_to(center)
	if distance >= inner_r and distance <= outer_r:
		var angle := atan2(local.y - center.y, local.x - center.x)
		hsv.x = fposmod(angle / TAU + 0.15, 1.0)
	else:
		var p0 := center + Vector2(-inner_r * 0.78, -inner_r * 0.42)
		var p1 := center + Vector2(inner_r * 0.78, -inner_r * 0.42)
		var p2 := center + Vector2(0, inner_r * 0.86)
		if not _point_in_triangle(local, p0, p1, p2):
			return
		var weights := _triangle_weights(local, p0, p1, p2)
		hsv.z = clampf(weights.y + weights.z, 0.0, 1.0)
		hsv.y = 0.0 if hsv.z <= 0.001 else clampf(weights.z / hsv.z, 0.0, 1.0)
	var next_color := Color.from_hsv(hsv.x, hsv.y, hsv.z, 1.0)
	SystemSettings.set_color_for_target(target, next_color)
	_update_color_picker_markers()
	_update_window_sample_preview()


func _update_color_picker_markers() -> void:
	var picker := get_node_or_null("runtime_color_picker") as Control
	if picker == null:
		return
	var target := SystemSettings.get_color_target()
	var color := SystemSettings.get_color_for_target(target, Color.WHITE)
	var hsv := _color_to_hsv(color)
	var size := picker.size
	var center := size * 0.5
	var outer_r := minf(size.x, size.y) * 0.48
	var inner_r := minf(size.x, size.y) * 0.34
	var ring_r := lerpf(inner_r, outer_r, 0.55)
	var angle := (hsv.x - 0.15) * TAU
	var hue_pos := center + Vector2(cos(angle), sin(angle)) * ring_r
	var p0 := center + Vector2(-inner_r * 0.78, -inner_r * 0.42)
	var p1 := center + Vector2(inner_r * 0.78, -inner_r * 0.42)
	var p2 := center + Vector2(0, inner_r * 0.86)
	var black_weight := 1.0 - hsv.z
	var white_weight := hsv.z * (1.0 - hsv.y)
	var hue_weight := hsv.z * hsv.y
	var sv_pos := p0 * black_weight + p1 * white_weight + p2 * hue_weight
	var hue_marker := picker.get_node_or_null("runtime_hue_marker") as Control
	if hue_marker != null:
		hue_marker.position = hue_pos - hue_marker.size * 0.5
	var sv_marker := picker.get_node_or_null("runtime_sv_marker") as Control
	if sv_marker != null:
		sv_marker.position = sv_pos - sv_marker.size * 0.5


func _color_to_hsv(color: Color) -> Vector3:
	var max_channel := maxf(color.r, maxf(color.g, color.b))
	var min_channel := minf(color.r, minf(color.g, color.b))
	var delta := max_channel - min_channel
	var hue := 0.0
	if delta > 0.0001:
		if max_channel == color.r:
			hue = fposmod((color.g - color.b) / delta, 6.0) / 6.0
		elif max_channel == color.g:
			hue = ((color.b - color.r) / delta + 2.0) / 6.0
		else:
			hue = ((color.r - color.g) / delta + 4.0) / 6.0
	var saturation := 0.0 if max_channel <= 0.0001 else delta / max_channel
	return Vector3(hue, saturation, max_channel)


func _add_window_sample_text() -> void:
	var back_slot := _slot_from_layer_path("window_back")
	if not back_slot.is_empty():
		var back := _add_slot_texture(self, back_slot, Vector2.ZERO)
		back.name = "runtime_window_sample_back"
	var window_slot := _slot_from_layer_path("window")
	if not window_slot.is_empty():
		var window := _add_slot_texture(self, window_slot, Vector2.ZERO)
		window.name = "runtime_window_sample_window"
	var sample_rect := scaled_rect(Rect2(1060, 760, 670, 85))
	var text := "天神乱漫 Happy Go Lucky!!\n(c)YUZUSOFTSOUR/JUNOS INC."
	var shadow := Label.new()
	shadow.name = "runtime_window_sample_shadow"
	shadow.text = text
	shadow.position = sample_rect.position + Vector2(2, 2)
	shadow.size = sample_rect.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_font_size_override("font_size", 24)
	shadow.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(shadow)
	var label := Label.new()
	label.name = "runtime_window_sample_text"
	label.text = text
	label.position = sample_rect.position
	label.size = sample_rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	_update_window_sample_preview()


func _update_window_sample_preview() -> void:
	var opacity := SystemSettings.get_slider("winopac", float(slider_values.get("winopac", 0.75)))
	var window := get_node_or_null("runtime_window_sample_window") as TextureRect
	if window != null:
		var window_color := SystemSettings.get_color_for_target("color_win", Color("d3727a"))
		window.modulate = Color(window_color.r, window_color.g, window_color.b, clampf(opacity, 0.0, 1.0))
	var shadow := get_node_or_null("runtime_window_sample_shadow") as Label
	if shadow != null:
		var read_color := SystemSettings.get_color_for_target("color_read", Color("efdfff"))
		shadow.add_theme_color_override("font_color", Color(read_color.r, read_color.g, read_color.b, 0.62))
		_apply_sample_font(shadow)
	var label := get_node_or_null("runtime_window_sample_text") as Label
	if label != null:
		var text_color := SystemSettings.get_color_for_target("color_text", Color.WHITE)
		label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 1.0))
		_apply_sample_font(label)


func _apply_sample_font(label: Label) -> void:
	var font := _current_sample_font()
	if font != null:
		label.add_theme_font_override("font", font)
	else:
		label.remove_theme_font_override("font")


func _current_sample_font() -> Font:
	return SystemSettings.get_message_font()


func _show_font_selection_dialog() -> void:
	if font_dialog != null and is_instance_valid(font_dialog):
		return
	font_dialog_selection = SystemSettings.get_font_name()
	var modal := Control.new()
	modal.name = "FontSelectionDialog"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 100
	add_child(modal)
	font_dialog = modal

	# Original selectFont uses a native modal chooser. This in-game counterpart
	# keeps that behaviour while only exposing packaged fonts that can be safely
	# loaded in the shipped Godot build.
	var blocker := ColorRect.new()
	blocker.name = "ModalBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.0, 0.0, 0.0, 0.04)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(blocker)

	var panel := Panel.new()
	panel.name = "FontSelectionPanel"
	panel.position = Vector2(430, 135)
	panel.size = Vector2(420, 405)
	panel.add_theme_stylebox_override("panel", _font_dialog_panel_style())
	modal.add_child(panel)

	var title_bar := ColorRect.new()
	title_bar.position = Vector2(1, 1)
	title_bar.size = Vector2(418, 42)
	title_bar.color = Color("f6f6f6")
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_bar)
	var title := Label.new()
	title.text = "フォントの選択"
	title.position = Vector2(14, 7)
	title.size = Vector2(350, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("151515"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.position = Vector2(374, 4)
	close.size = Vector2(41, 34)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_close_font_selection_dialog)
	panel.add_child(close)

	var prompt := Label.new()
	prompt.text = "フォントを選択してください"
	prompt.position = Vector2(14, 48)
	prompt.size = Vector2(392, 28)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color("202020"))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prompt)

	var list := ItemList.new()
	list.name = "FontList"
	list.position = Vector2(13, 76)
	list.size = Vector2(394, 252)
	list.allow_reselect = true
	list.select_mode = ItemList.SELECT_SINGLE
	list.focus_mode = Control.FOCUS_ALL
	list.add_theme_font_size_override("font_size", 18)
	list.item_selected.connect(_on_font_dialog_item_selected)
	list.item_activated.connect(_on_font_dialog_item_activated)
	panel.add_child(list)
	font_dialog_list = list
	_populate_font_selection_list()

	var detail := Button.new()
	detail.name = "Detail"
	detail.text = "詳細情報"
	detail.position = Vector2(13, 352)
	detail.size = Vector2(78, 39)
	detail.disabled = true
	detail.focus_mode = Control.FOCUS_NONE
	panel.add_child(detail)
	var accept := Button.new()
	accept.name = "Accept"
	accept.text = "OK"
	accept.position = Vector2(164, 352)
	accept.size = Vector2(110, 39)
	accept.focus_mode = Control.FOCUS_ALL
	accept.pressed.connect(_accept_font_selection_dialog)
	panel.add_child(accept)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "キャンセル"
	cancel.position = Vector2(284, 352)
	cancel.size = Vector2(123, 39)
	cancel.focus_mode = Control.FOCUS_ALL
	cancel.pressed.connect(_close_font_selection_dialog)
	panel.add_child(cancel)
	accept.grab_focus()


func _font_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7f7f7")
	style.border_color = Color("767676")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


func _populate_font_selection_list() -> void:
	if font_dialog_list == null:
		return
	font_dialog_list.clear()
	var selected_index := -1
	for option in SystemSettings.get_message_font_options():
		var id := str(option.get("id", ""))
		var path := str(option.get("path", ""))
		if id == "" or path == "" or not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			continue
		var index := font_dialog_list.add_item(str(option.get("label", id)))
		font_dialog_list.set_item_metadata(index, id)
		if id == font_dialog_selection:
			selected_index = index
	if selected_index < 0 and font_dialog_list.item_count > 0:
		selected_index = 0
		font_dialog_selection = str(font_dialog_list.get_item_metadata(0))
	if selected_index >= 0:
		font_dialog_list.select(selected_index)
		font_dialog_list.ensure_current_is_visible()


func _on_font_dialog_item_selected(index: int) -> void:
	if font_dialog_list == null or index < 0 or index >= font_dialog_list.item_count:
		return
	font_dialog_selection = str(font_dialog_list.get_item_metadata(index))


func _on_font_dialog_item_activated(index: int) -> void:
	_on_font_dialog_item_selected(index)
	_accept_font_selection_dialog()


func _accept_font_selection_dialog() -> void:
	if font_dialog_selection != "":
		SystemSettings.set_font_name(font_dialog_selection)
		_update_window_sample_preview()
		AudioManager.play_sysse("chg1")
	_close_font_selection_dialog()


func _close_font_selection_dialog() -> void:
	if font_dialog == null:
		return
	var closing_dialog := font_dialog
	font_dialog = null
	font_dialog_list = null
	font_dialog_selection = ""
	if is_instance_valid(closing_dialog):
		closing_dialog.queue_free()


func _add_winopac_slider() -> void:
	var slider_proto := _find_object("winopac_slider")
	if slider_proto.is_empty():
		return
	var target_rect := {"x": 1328, "y": 900, "w": 392, "h": 53}
	var winopac := _find_object("winopac")
	for area in winopac.get("areas", []):
		if str(area.get("source", "")) == "seekbar/##bar/3":
			target_rect = area.get("rect", target_rect)
			break
	_add_slider_from_slots("winopac", target_rect, slider_proto.get("slots", {}), SystemSettings.get_slider("winopac", 0.9))
	_add_numeric_label("winopac", {"x": 1740, "y": 914, "w": 56, "h": 25})


func _add_slider_number_labels() -> void:
	_add_numeric_label("textspeed", {"x": 811, "y": 271, "w": 56, "h": 25})
	_add_numeric_label("autospeed", {"x": 811, "y": 401, "w": 56, "h": 25})


func _add_numeric_label(control_name: String, control_rect_dict: Dictionary) -> void:
	var rect := scaled_rect(rect_from_dict(control_rect_dict))
	var label := Label.new()
	label.name = "numeric_" + control_name
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.66, 0.38, 0.50, 0.95))
	label.text = _numeric_text(control_name)
	add_child(label)


func _numeric_text(control_name: String) -> String:
	var value := SystemSettings.get_slider(control_name, float(slider_values.get(control_name, 0.5)))
	match control_name:
		"autotime":
			return "%.2f" % lerpf(0.2, 2.4, value)
		"atextwait":
			return str(int(round(lerpf(0.0, 100.0, value))))
		"winopac":
			return str(int(round(value * 100.0)))
		_:
			return str(int(round(value * 100.0)))


func _build_character_preview() -> void:
	var chview := _find_object("chview")
	if chview.is_empty():
		return
	character_preview = Control.new()
	character_preview.name = "character_preview"
	character_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(character_preview)
	_update_character_preview()


func _update_character_preview() -> void:
	if character_preview == null:
		return
	for child in character_preview.get_children():
		child.queue_free()
	var chview := _find_object("chview")
	if chview.is_empty():
		return
	var slots: Dictionary = chview.get("slots", {})
	var index := selected_chvoice.trim_prefix("chv")
	var background_slot := _slot_from_layer_path("bg/character_window_bg")
	if not background_slot.is_empty():
		_add_slot_texture(character_preview, background_slot, Vector2.ZERO)
	_add_slot_texture(character_preview, _slot(slots, ["chv" + index, "chv0"]), Vector2.ZERO)
	_add_slot_texture(character_preview, _slot(slots, ["namebase"]), Vector2.ZERO)
	_add_slot_texture(character_preview, _slot(slots, ["name" + index, "name0"]), Vector2.ZERO)


func _build_character_voice_widgets() -> void:
	var select_proto := _find_object("_chsel")
	var state_proto := _find_object("_chstate")
	if select_proto.is_empty() or state_proto.is_empty():
		return
	for control in compiled_ui.get("ini", {}).get("typed_controls", []):
		if str(control.get("type", "")) != "chsel":
			continue
		_add_character_voice_button(str(control.get("name", "")), control.get("rect", {}), select_proto, state_proto)


func _add_character_voice_button(control_name: String, control_rect_dict: Dictionary, select_proto: Dictionary, state_proto: Dictionary) -> void:
	var rect := scaled_rect(rect_from_dict(control_rect_dict))
	var origin := scaled_rect(rect_from_dict(select_proto.get("slots", {}).get("rect", {}).get("rect", control_rect_dict))).position
	var button := Control.new()
	button.name = "widget_" + control_name
	button.position = rect.position
	button.size = rect.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	runtime_widgets[control_name] = {
		"kind": "chsel",
		"node": button,
		"select_proto": select_proto,
		"state_proto": state_proto,
		"origin": origin,
	}
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(control_name)
		_update_chvoice_visual(control_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_chvoice_visual(control_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_chvoice_visual(control_name, true, true)
		elif _is_left_release(event):
			selected_chvoice = control_name
			AudioManager.play_sysse("chg1")
			_update_all_chvoice_widgets()
			_update_character_preview()
	)
	_update_chvoice_visual(control_name, false, false)


func _add_slider_from_slots(control_name: String, control_rect_dict: Dictionary, slots: Dictionary, value: float) -> void:
	var rect_slot: Dictionary = slots.get("rect", {})
	var knob_slot: Dictionary = slots.get("normal/slider", {})
	if rect_slot.is_empty() or knob_slot.is_empty():
		return
	var proto_rect := scaled_rect(rect_from_dict(rect_slot.get("rect", control_rect_dict)))
	var knob_rect := scaled_rect(rect_from_dict(slots.get("knob_rect", knob_slot).get("rect", knob_slot.get("rect", {}))))
	var rail_slot: Dictionary = slots.get("rail", {})
	var control_rect := scaled_rect(rect_from_dict(control_rect_dict))
	var slider := Control.new()
	slider.name = "slider_" + control_name
	slider.position = control_rect.position
	slider.size = control_rect.size
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(slider)

	if not rail_slot.is_empty():
		_add_slot_texture(slider, rail_slot, proto_rect.position)

	var knob := _add_slot_texture(slider, knob_slot, proto_rect.position)
	knob.name = "knob"
	slider_values[control_name] = float(value)
	runtime_widgets[control_name] = {
		"kind": "slider",
		"node": slider,
		"knob": knob,
		"proto_rect": proto_rect,
		"knob_rect": knob_rect,
		"rail_slot": rail_slot,
		"normal_slot": knob_slot,
		"over_slot": slots.get("over", knob_slot),
		"on_slot": slots.get("on", knob_slot),
	}
	_update_slider(control_name, false, false)
	slider.mouse_entered.connect(func() -> void:
		_show_widget_help(control_name)
		_update_slider(control_name, true, false)
	)
	slider.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		if dragging_slider != control_name:
			_update_slider(control_name, false, false)
	)
	slider.gui_input.connect(func(event: InputEvent) -> void: _on_slider_input(control_name, event))


func _build_onoff_widgets() -> void:
	var on_proto := _find_object("_cfon")
	var off_proto := _find_object("_cfoff")
	var on_template := _find_object("_on")
	var off_template := _find_object("_off")
	if on_proto.is_empty() or off_proto.is_empty() or on_template.is_empty() or off_template.is_empty():
		return
	var on_rect := rect_from_dict(on_template.get("rect", {}))
	var off_rect := rect_from_dict(off_template.get("rect", {}))
	var off_delta := off_rect.position - on_rect.position
	for control in compiled_ui.get("ini", {}).get("typed_controls", []):
		if str(control.get("type", "")) != "onoff":
			continue
		var control_name := str(control.get("name", ""))
		check_states[control_name] = SystemSettings.get_bool(control_name, true)
		var control_rect := rect_from_dict(control.get("rect", {}))
		_add_onoff_button(control_name, "on", control_rect, on_proto)
		var off_control_rect := Rect2(control_rect.position + off_delta, off_rect.size)
		_add_onoff_button(control_name, "off", off_control_rect, off_proto)


func _add_onoff_button(control_name: String, side: String, source_rect: Rect2, prototype: Dictionary) -> void:
	var rect := scaled_rect(source_rect)
	var proto_slots: Dictionary = prototype.get("slots", {})
	var proto_rect := scaled_rect(rect_from_dict(_slot(proto_slots, ["rect", "rect/"]).get("rect", prototype.get("rect", {}))))
	var widget_name := control_name + "_" + side
	var button := Control.new()
	button.name = "widget_" + widget_name
	button.position = rect.position
	button.size = rect.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	runtime_widgets[widget_name] = {
		"kind": "onoff",
		"node": button,
		"group": control_name,
		"side": side,
		"prototype": prototype,
		"origin": proto_rect.position,
	}
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(widget_name)
		_update_onoff_visual(widget_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_onoff_visual(widget_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_onoff_visual(widget_name, true, true)
		elif _is_left_release(event):
			check_states[control_name] = side == "on"
			SystemSettings.set_bool(control_name, side == "on")
			AudioManager.play_sysse("chg1")
			_update_onoff_pair(control_name)
	)
	_update_onoff_visual(widget_name, false, false)


func _build_key_widgets() -> void:
	var slots := {
		"on": _slot_from_layer_path("btn4/btn_bg/on"),
		"over": _slot_from_layer_path("btn4/btn_bg/over"),
		"off": _slot_from_layer_path("btn4/btn_bg/off"),
	}
	if Dictionary(slots["off"]).is_empty():
		return
	_add_keyboard_preview()
	for control in compiled_ui.get("ini", {}).get("typed_controls", []):
		if str(control.get("type", "")) != "key":
			continue
		var control_name := str(control.get("name", ""))
		var rect := rect_from_dict(control.get("rect", {}))
		_add_key_button(control_name, control_name, rect, slots)
		var alt_rect := Rect2(rect.position + Vector2(136, 0), rect.size)
		_add_key_button(control_name + "_alt", control_name, alt_rect, slots)


func _add_keyboard_preview() -> void:
	var keyboard := _find_object("keyboard")
	if keyboard.is_empty():
		return
	var slot: Dictionary = keyboard.get("slots", {}).get("off", {})
	if slot.is_empty():
		return
	var preview := _add_slot_texture(self, slot, Vector2.ZERO)
	preview.name = "runtime_keyboard_preview"


func _add_key_button(widget_name: String, control_name: String, control_rect: Rect2, slots: Dictionary) -> void:
	var rect := scaled_rect(control_rect)
	var origin := scaled_rect(rect_from_dict(slots["off"].get("rect", {}))).position
	var button := Control.new()
	button.name = "widget_" + widget_name
	button.position = rect.position
	button.size = rect.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	runtime_widgets[widget_name] = {
		"kind": "key",
		"node": button,
		"slots": slots,
		"origin": origin,
		"control_name": control_name,
	}
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(control_name)
		_update_key_visual(widget_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_key_visual(widget_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_key_visual(widget_name, true, true)
		elif _is_left_release(event):
			SystemSettings.set_key_label(widget_name, str(key_labels.get(widget_name, "")))
			AudioManager.play_sysse("sel2")
			_update_key_visual(widget_name, true, false)
	)
	_update_key_visual(widget_name, false, false)


func _add_radio_button(object: Dictionary, prototype: Dictionary) -> void:
	var group_name := _group_name_for_radio(str(object.get("name", "")))
	var value_name := str(object.get("name", ""))
	if not radio_groups.has(group_name):
		radio_groups[group_name] = SystemSettings.get_radio(group_name, value_name)
	var button := _make_widget_button(object, prototype, "radio")
	if button == null:
		return
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(value_name)
		_update_button_visual(value_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_button_visual(value_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_button_visual(value_name, true, true)
		elif _is_left_release(event):
			radio_groups[group_name] = value_name
			SystemSettings.set_radio(value_name)
			AudioManager.play_sysse("chg1")
			_update_radio_group(group_name)
			_emit_widget_action(value_name)
	)
	_update_button_visual(value_name, false, false)


func _add_toggle_button(object: Dictionary, prototype: Dictionary, kind: String) -> void:
	var object_name := str(object.get("name", ""))
	if kind == "mute":
		check_states[object_name] = SystemSettings.is_muted(object_name)
	elif not check_states.has(object_name):
		check_states[object_name] = SystemSettings.get_bool(object_name, false)
	var button := _make_widget_button(object, prototype, kind)
	if button == null:
		return
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(object_name)
		_update_button_visual(object_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_button_visual(object_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_button_visual(object_name, true, true)
		elif _is_left_release(event):
			if kind != "jump":
				check_states[object_name] = not bool(check_states.get(object_name, false))
				if object_name.ends_with("_mute"):
					SystemSettings.set_muted(object_name, bool(check_states.get(object_name, false)))
				else:
					SystemSettings.set_bool(object_name, bool(check_states.get(object_name, false)))
			AudioManager.play_sysse("chg1")
			_update_button_visual(object_name, true, false)
			_emit_widget_action(object_name)
	)
	_update_button_visual(object_name, false, false)


func _add_momentary_button(object: Dictionary, prototype: Dictionary, kind: String) -> void:
	_add_toggle_button(object, prototype, kind)


func _add_push_button(object: Dictionary, prototype: Dictionary) -> void:
	var object_name := str(object.get("name", ""))
	var button := _make_widget_button(object, prototype, "button")
	if button == null:
		return
	button.mouse_entered.connect(func() -> void:
		_show_widget_help(object_name)
		_update_button_visual(object_name, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_hide_widget_help()
		_update_button_visual(object_name, false, false)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_press(event):
			_update_button_visual(object_name, true, true)
		elif _is_left_release(event):
			_emit_widget_action(object_name)
			AudioManager.play_sysse("sel2")
			_update_button_visual(object_name, true, false)
	)
	_update_button_visual(object_name, false, false)


func _make_widget_button(object: Dictionary, prototype: Dictionary, kind: String) -> Control:
	var object_name := str(object.get("name", ""))
	var rect_dict := _widget_rect_dict(object, prototype)
	if rect_dict.is_empty():
		return null
	var rect := scaled_rect(rect_from_dict(rect_dict))
	var proto_origin := _prototype_origin(prototype, object)
	var button := Control.new()
	button.name = "widget_" + object_name
	button.position = rect.position
	button.size = rect.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	runtime_widgets[object_name] = {
		"kind": kind,
		"node": button,
		"object": object,
		"prototype": prototype,
		"origin": proto_origin,
	}
	return button


func _widget_rect_dict(object: Dictionary, prototype: Dictionary) -> Dictionary:
	var rect_value: Variant = object.get("rect", {})
	if typeof(rect_value) == TYPE_DICTIONARY and not Dictionary(rect_value).is_empty():
		return rect_value
	var slots: Dictionary = prototype.get("slots", {})
	if slots.has("rect"):
		var slot: Dictionary = slots["rect"]
		if slot.has("rect"):
			var slot_rect: Variant = slot.get("rect", {})
			if typeof(slot_rect) == TYPE_DICTIONARY:
				return slot_rect
	for slot_name in ["off/toggle", "normal:off/toggle", "off", "normal:on", "on", "over"]:
		if not slots.has(slot_name):
			continue
		var slot: Dictionary = slots[slot_name]
		if slot.has("rect"):
			var slot_rect: Variant = slot.get("rect", {})
			if typeof(slot_rect) == TYPE_DICTIONARY:
				return slot_rect
	for slot_name in slots.keys():
		var slot: Dictionary = slots[slot_name]
		if slot.has("rect"):
			var slot_rect: Variant = slot.get("rect", {})
			if typeof(slot_rect) == TYPE_DICTIONARY:
				return slot_rect
	return {}


func _update_radio_group(group_name: String) -> void:
	for widget_name in runtime_widgets.keys():
		if _group_name_for_radio(str(widget_name)) == group_name:
			_update_button_visual(str(widget_name), false, false)


func _update_button_visual(widget_name: String, hover: bool, pressed: bool) -> void:
	if not runtime_widgets.has(widget_name):
		return
	var record: Dictionary = runtime_widgets[widget_name]
	var node: Control = record.get("node")
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
	var kind := str(record.get("kind", ""))
	var prototype: Dictionary = record.get("prototype", {})
	var slots: Dictionary = prototype.get("slots", {})
	var active := _widget_active(widget_name, kind)
	var state := "normal"
	if pressed:
		state = "on"
	elif hover:
		state = "over"
	match kind:
		"radio":
			_draw_radio_state(node, slots, record.get("origin", Vector2.ZERO), widget_name, active, state)
		"mute":
			_draw_mute_state(node, slots, record.get("origin", Vector2.ZERO), active, state)
		"check":
			_draw_check_state(node, slots, record.get("origin", Vector2.ZERO), active, state)
		"button":
			_draw_button_state(node, slots, record.get("origin", Vector2.ZERO), state)
		"jump":
			_draw_jump_state(node, slots, record.get("origin", Vector2.ZERO), state)


func _draw_radio_state(parent: Control, slots: Dictionary, origin: Vector2, widget_name: String, active: bool, state: String) -> void:
	var value := _radio_value_suffix(widget_name)
	var bg_slot_name := "normal:on" if active else _normal_off_slot(slots)
	if state == "over":
		bg_slot_name = "over"
	elif state == "on":
		bg_slot_name = "on"
	var bg_fallback: Array = [bg_slot_name, _normal_off_slot(slots), "normal:on", "on"]
	if active:
		bg_fallback = [bg_slot_name, "on", "normal:on", _normal_off_slot(slots)]
	_add_slot_texture(parent, _slot(slots, bg_fallback), origin)

	var text_prefix := "n_" if active else "f_"
	if state == "over" or state == "on":
		text_prefix = "v_"
	_add_slot_texture(parent, _slot(slots, [text_prefix + value, "f_" + value, "n_" + value]), origin)


func _draw_mute_state(parent: Control, slots: Dictionary, origin: Vector2, active: bool, state: String) -> void:
	var bg_slot_name := "normal:on" if active else "off/toggle"
	if state == "over":
		bg_slot_name = "over:on" if active else "over"
	elif state == "on":
		bg_slot_name = "on:on" if active else "on"
	_add_slot_texture(parent, _slot(slots, [bg_slot_name, "off/toggle", "normal:on", "on"]), origin)

	var icon_slot_name := "n_ck" if active else "f_un"
	if state == "over" or state == "on":
		icon_slot_name = "f_ck" if active else "n_un"
	_add_slot_texture(parent, _slot(slots, [icon_slot_name, "f_un", "n_un"]), origin)


func _draw_check_state(parent: Control, slots: Dictionary, origin: Vector2, active: bool, state: String) -> void:
	var value := _radio_value_suffix(parent.name.trim_prefix("widget_"))
	var bg_slot_name := "normal:on" if active else _normal_off_slot(slots)
	if state == "over" or state == "on":
		bg_slot_name = "over:on" if active else "over:off"
	_add_slot_texture(parent, _slot(slots, [bg_slot_name, _normal_off_slot(slots), "normal:off/toggle", "normal:on"]), origin)

	var text_slot_name := "n_text" if active else "f_text"
	if state == "over" or state == "on":
		text_slot_name = "v_text"
	_add_slot_texture(parent, _slot(slots, [text_slot_name, text_slot_name.replace("_text", "_" + value), "f_" + value, "n_" + value, "f_text", "n_text"]), origin)


func _draw_jump_state(parent: Control, slots: Dictionary, origin: Vector2, state: String) -> void:
	var widget_name := parent.name.trim_prefix("widget_")
	var value := _radio_value_suffix(widget_name)
	var bg_slot_name := "off"
	var text_slot_name := "f_" + value
	if state == "over":
		bg_slot_name = "over"
		text_slot_name = "v_" + value
	elif state == "on":
		bg_slot_name = "on"
		text_slot_name = "n_" + value
	_add_slot_texture(parent, _slot(slots, [bg_slot_name, "off"]), origin)
	_add_slot_texture(parent, _slot(slots, [text_slot_name, "f_text", "f_" + value]), origin)


func _draw_button_state(parent: Control, slots: Dictionary, origin: Vector2, state: String) -> void:
	var slot_name := "off/button"
	if state == "over":
		slot_name = "over"
	elif state == "on":
		slot_name = "on"
	_add_slot_texture(parent, _slot(slots, [slot_name, "off/button", "off"]), origin)
	var widget_name := parent.name.trim_prefix("widget_")
	var value := _radio_value_suffix(widget_name)
	var text_slot_name := "f_" + value
	if state == "over":
		text_slot_name = "v_" + value
	elif state == "on":
		text_slot_name = "n_" + value
	_add_slot_texture(parent, _slot(slots, [text_slot_name, "f_text", "n_text", "f_" + value]), origin)


func _update_all_chvoice_widgets() -> void:
	for widget_name in runtime_widgets.keys():
		if str(runtime_widgets[widget_name].get("kind", "")) == "chsel":
			_update_chvoice_visual(str(widget_name), false, false)


func _update_onoff_pair(group_name: String) -> void:
	_update_onoff_visual(group_name + "_on", false, false)
	_update_onoff_visual(group_name + "_off", false, false)


func _update_onoff_visual(widget_name: String, hover: bool, pressed: bool) -> void:
	if not runtime_widgets.has(widget_name):
		return
	var record: Dictionary = runtime_widgets[widget_name]
	var node: Control = record.get("node")
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
	var prototype: Dictionary = record.get("prototype", {})
	var slots: Dictionary = prototype.get("slots", {})
	var origin: Vector2 = record.get("origin", Vector2.ZERO)
	var side := str(record.get("side", "on"))
	var group_name := str(record.get("group", ""))
	var active: bool = bool(check_states.get(group_name, true)) == (side == "on")
	var bg_slot_name := "on" if active else "off/toggle"
	var text_slot_name := "n_text" if active else "f_text"
	if pressed:
		bg_slot_name = "on"
		text_slot_name = "n_text"
	elif hover:
		bg_slot_name = "over"
		text_slot_name = "v_text"
	_add_slot_texture(node, _slot(slots, [bg_slot_name, "off/toggle", "off"]), origin)
	_add_slot_texture(node, _slot(slots, [text_slot_name, "f_text", "n_text"]), origin)


func _update_key_visual(widget_name: String, hover: bool, pressed: bool) -> void:
	if not runtime_widgets.has(widget_name):
		return
	var record: Dictionary = runtime_widgets[widget_name]
	var node: Control = record.get("node")
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
	var slots: Dictionary = record.get("slots", {})
	var origin: Vector2 = record.get("origin", Vector2.ZERO)
	var slot_name := "off"
	if pressed:
		slot_name = "on"
	elif hover:
		slot_name = "over"
	_add_slot_texture(node, _slot(slots, [slot_name, "off"]), origin)
	var label := Label.new()
	label.text = str(key_labels.get(widget_name, ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.52, 0.36, 0.47, 0.85))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)


func _update_chvoice_visual(widget_name: String, hover: bool, pressed: bool) -> void:
	if not runtime_widgets.has(widget_name):
		return
	var record: Dictionary = runtime_widgets[widget_name]
	var node: Control = record.get("node")
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
	var select_proto: Dictionary = record.get("select_proto", {})
	var state_proto: Dictionary = record.get("state_proto", {})
	var select_slots: Dictionary = select_proto.get("slots", {})
	var state_slots: Dictionary = state_proto.get("slots", {})
	var origin: Vector2 = record.get("origin", Vector2.ZERO)
	var active := selected_chvoice == widget_name
	var bg_slot_name := "normal:on" if active else "normal:off/toggle"
	var text_prefix := "n_" if active else "f_"
	if pressed:
		bg_slot_name = "over:on"
		text_prefix = "v_"
	elif hover:
		bg_slot_name = "over:on" if active else "over:off"
		text_prefix = "v_"
	_add_slot_texture(node, _slot(select_slots, [bg_slot_name, "normal:off/toggle"]), origin)
	var text_slot_name := text_prefix + widget_name
	var text_slots := select_slots if text_prefix == "v_" else state_slots
	_add_slot_texture(node, _slot(text_slots, [text_slot_name, "f_" + widget_name, "n_" + widget_name]), origin)


func _widget_active(widget_name: String, kind: String) -> bool:
	if kind == "radio":
		var group_name := _group_name_for_radio(widget_name)
		return str(radio_groups.get(group_name, "")) == widget_name
	return bool(check_states.get(widget_name, false))


func _emit_widget_action(widget_name: String) -> void:
	if screen_name != "option":
		if screen_name.begins_with("option_") and widget_name.ends_with("_jump"):
			var quick_page := _quick_setting_page(widget_name)
			if quick_page >= 0:
				action_requested.emit("option_page:" + str(quick_page))
		elif widget_name == "se_test":
			AudioManager.play_sysse("ok1")
		elif widget_name == "cfall_on":
			SystemSettings.set_all_confirms(true)
			for key in check_states.keys():
				if str(key).begins_with("cf_"):
					check_states[key] = true
					_update_onoff_pair(str(key))
		elif widget_name == "cfall_off":
			SystemSettings.set_all_confirms(false)
			for key in check_states.keys():
				if str(key).begins_with("cf_"):
					check_states[key] = false
					_update_onoff_pair(str(key))
		elif COLOR_TARGETS.has(widget_name):
			SystemSettings.set_color_target(widget_name)
			_update_color_picker_markers()
			_update_window_sample_preview()
		elif widget_name == "hsv_reset":
			SystemSettings.reset_color_for_target(SystemSettings.get_color_target())
			_update_color_picker_markers()
			_update_window_sample_preview()
		elif widget_name == "fontselect":
			_show_font_selection_dialog()
		return
	if widget_name.begins_with("page"):
		var page_index := int(widget_name.trim_prefix("page"))
		action_requested.emit("option_page:" + str(page_index))
		return
	if widget_name in ["back", "title", "reset"]:
		action_requested.emit(widget_name)


func _group_name_for_radio(widget_name: String) -> String:
	if screen_name == "option" and widget_name.begins_with("page"):
		return "option_pages"
	var idx := widget_name.rfind("_")
	if idx < 0:
		return widget_name
	return widget_name.substr(0, idx)


func _radio_value_suffix(widget_name: String) -> String:
	for macro in compiled_ui.get("ini", {}).get("macros", []):
		if not str(macro.get("macro", "")) in ["RTX", "TTX", "BTX", "BDS", "RDS", "CTX"]:
			continue
		var args: Array = macro.get("args", [])
		if args.size() >= 2 and str(args[0]) == widget_name:
			return str(args[1])
	var idx := widget_name.rfind("_")
	if idx < 0:
		return widget_name
	return widget_name.substr(idx + 1)


func _on_slider_input(control_name: String, event: InputEvent) -> void:
	if _is_left_press(event):
		dragging_slider = control_name
		AudioManager.play_sysse("sel2")
		_set_slider_from_mouse(control_name)
		_update_slider(control_name, true, true)
	elif _is_left_release(event):
		_set_slider_from_mouse(control_name)
		dragging_slider = ""
		AudioManager.play_sysse("chg1")
		_update_slider(control_name, true, false)
	elif event is InputEventMouseMotion and dragging_slider == control_name:
		_set_slider_from_mouse(control_name)
		_update_slider(control_name, true, true)


func _set_slider_from_mouse(control_name: String) -> void:
	var record: Dictionary = runtime_widgets.get(control_name, {})
	var slider: Control = record.get("node")
	if slider == null:
		return
	var local_x := slider.get_local_mouse_position().x
	var rail := _slider_rail_rect(record)
	var value: float = (local_x - rail.position.x) / maxf(rail.size.x, 1.0)
	slider_values[control_name] = clampf(value, 0.0, 1.0)
	SystemSettings.set_slider(control_name, slider_values[control_name])
	var numeric := get_node_or_null("numeric_" + control_name) as Label
	if numeric != null:
		numeric.text = _numeric_text(control_name)
	if control_name == "winopac":
		_update_window_sample_preview()


func _update_slider(control_name: String, hover: bool, pressed: bool) -> void:
	if not runtime_widgets.has(control_name):
		return
	var record: Dictionary = runtime_widgets[control_name]
	var knob: TextureRect = record.get("knob")
	if knob == null:
		return
	var slot: Dictionary = record.get("normal_slot", {})
	if pressed:
		slot = record.get("on_slot", slot)
	elif hover:
		slot = record.get("over_slot", slot)
	knob.texture = load_texture(layer_path(str(compiled_ui.get("layer_dir", "")), slot.get("layer_id", "")))
	var rail := _slider_rail_rect(record)
	var value := float(slider_values.get(control_name, 0.5))
	var knob_rect: Rect2 = record.get("knob_rect", Rect2())
	knob.position.x = rail.position.x + rail.size.x * value - knob_rect.size.x * 0.5
	var proto_rect: Rect2 = record.get("proto_rect", Rect2())
	knob.position.y = knob_rect.position.y - proto_rect.position.y


func _slider_rail_rect(record: Dictionary) -> Rect2:
	var rail_slot: Dictionary = record.get("rail_slot", {})
	var proto_rect: Rect2 = record.get("proto_rect", Rect2())
	if rail_slot.is_empty():
		return Rect2(Vector2.ZERO, proto_rect.size)
	var rail := scaled_rect(rect_from_dict(rail_slot.get("rect", {})))
	return Rect2(rail.position - proto_rect.position, rail.size)


func _add_slot_texture(parent: Control, slot: Dictionary, origin: Vector2) -> TextureRect:
	var tex := TextureRect.new()
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	if slot.is_empty():
		parent.add_child(tex)
		return tex
	var layer_id: Variant = slot.get("layer_id", "")
	var path := layer_path(str(compiled_ui.get("layer_dir", "")), layer_id)
	if file_exists(path):
		tex.texture = load_texture(path)
	var rect := scaled_rect(rect_from_dict(slot.get("rect", {})))
	tex.position = rect.position - origin
	tex.size = rect.size
	parent.add_child(tex)
	return tex


func _add_external_slot_texture(parent: Control, external_ui: Dictionary, slot: Dictionary, origin: Vector2) -> TextureRect:
	var tex := TextureRect.new()
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	if slot.is_empty():
		parent.add_child(tex)
		return tex
	var layer_id: Variant = slot.get("layer_id", "")
	var path := layer_path(str(external_ui.get("layer_dir", "")), layer_id)
	if file_exists(path):
		tex.texture = load_texture(path)
	var rect := scaled_rect(rect_from_dict(slot.get("rect", {})))
	tex.position = rect.position - origin
	tex.size = rect.size
	parent.add_child(tex)
	return tex


func _slot(slots: Dictionary, names: Array) -> Dictionary:
	for slot_name in names:
		if not slots.has(str(slot_name)):
			continue
		var slot: Dictionary = slots[str(slot_name)]
		if slot.has("layer_id") and file_exists(layer_path(str(compiled_ui.get("layer_dir", "")), slot.get("layer_id", ""))):
			return slot
	for slot_name in names:
		if slots.has(str(slot_name)):
			return slots[str(slot_name)]
	return {}


func _slot_from_layer_path(source_path: String) -> Dictionary:
	for layer in compiled_ui.get("layers", []):
		if str(layer.get("path", "")) == source_path:
			return {
				"source": source_path,
				"layer_id": layer.get("id", ""),
				"rect": layer.get("rect", {}),
			}
	return {}


func _external_slot_from_layer_path(external_ui: Dictionary, source_path: String) -> Dictionary:
	for layer in external_ui.get("layers", []):
		if str(layer.get("path", "")) == source_path:
			return {
				"source": source_path,
				"layer_id": layer.get("id", ""),
				"rect": layer.get("rect", {}),
			}
	return {}


func _touch_ui() -> Dictionary:
	if touch_ui_cache.is_empty():
		touch_ui_cache = load_json(TOUCH_UI_SCREEN)
	return touch_ui_cache


func _show_widget_help(widget_name: String) -> void:
	help_requested.emit(_help_text_for_widget(widget_name), true)


func _hide_widget_help() -> void:
	help_requested.emit("", false)


func _help_text_for_widget(widget_name: String) -> String:
	if widget_name.begins_with("page"):
		var page_index := int(widget_name.trim_prefix("page"))
		if page_index >= 0 and page_index < OPTION_PAGE_HELP.size():
			return OPTION_PAGE_HELP[page_index]
	if widget_name.begins_with("label_") and widget_name.ends_with("_jump"):
		var page_index := _quick_setting_page(widget_name)
		if page_index >= 0 and page_index < OPTION_PAGE_HELP.size():
			return OPTION_PAGE_HELP[page_index]
	var key := widget_name
	if key.ends_with("_on") or key.ends_with("_off"):
		key = _group_name_for_radio(key)
	if key.ends_with("_mute"):
		return str(HELP_TEXT.get(key.trim_suffix("_mute"), "音量のミュートを切り替えます。"))
	if key.ends_with("_slider"):
		key = key.trim_suffix("_slider")
	if key.begins_with("cf_"):
		return "この操作の確認ダイアログ表示を切り替えます。"
	if key.begins_with("key_"):
		return "この操作に割り当てるキーを確認します。"
	if key.begins_with("chv") and key.length() > 3:
		return "キャラクター別ボイス設定の対象を選択します。"
	return str(HELP_TEXT.get(key, "この項目の設定を変更します。"))


func _quick_setting_page(widget_name: String) -> int:
	match widget_name:
		"label_a_jump", "label_b_jump":
			return 1
		"label_c_jump", "label_d_jump", "label_e_jump":
			return 4
		"label_f_jump", "label_g_jump", "label_h_jump", "label_i_jump", "label_j_jump":
			return 5
		_:
			return -1


func _is_left_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed


func _is_left_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed


func _uses_runtime_widgets() -> bool:
	return (screen_name == "option" or screen_name.begins_with("option_")) and not object_map.is_empty()


func _widget_kind_for_object(object_name: String, prototype: Dictionary) -> String:
	var prototype_name := str(prototype.get("name", ""))
	var slots: Dictionary = prototype.get("slots", {})
	if prototype_name == "_mute" or slots.has("n_ck"):
		return "mute"
	if prototype_name == "_test" or slots.has("off/button"):
		return "button"
	if prototype_name == "_jump":
		return "jump"
	var macro := _macro_name_for_object(object_name)
	if macro in ["TTX", "CTX", "RDS"]:
		return "check"
	if macro in ["BTX", "BDS"]:
		return "jump"
	if macro == "RTX":
		return "radio"
	if slots.has("normal:on") and (slots.has("off/toggle") or slots.has("off")):
		return "radio"
	if slots.has("on") and slots.has("off") and (slots.has("n_on") or slots.has("n_off")):
		return "radio"
	return ""


func _macro_name_for_object(object_name: String) -> String:
	for macro in compiled_ui.get("ini", {}).get("macros", []):
		var args: Array = macro.get("args", [])
		if not args.is_empty() and str(args[0]) == object_name:
			return str(macro.get("macro", ""))
	return ""


func _normal_off_slot(slots: Dictionary) -> String:
	if slots.has("off/toggle"):
		return "off/toggle"
	if slots.has("normal:off/toggle"):
		return "normal:off/toggle"
	return "off"


func _prototype_origin(prototype: Dictionary, object: Dictionary) -> Vector2:
	var slots: Dictionary = prototype.get("slots", {})
	for slot_name in ["rect", "rect/", "off/toggle", "normal:off/toggle", "off", "normal:on", "on", "over"]:
		if not slots.has(slot_name):
			continue
		var slot: Dictionary = slots[slot_name]
		if slot.has("rect"):
			return scaled_rect(rect_from_dict(slot.get("rect", {}))).position
	for slot_name in slots.keys():
		var slot: Dictionary = slots[slot_name]
		if slot.has("rect"):
			return scaled_rect(rect_from_dict(slot.get("rect", {}))).position
	return scaled_rect(rect_from_dict(object.get("rect", {}))).position


func _find_object(object_name: String) -> Dictionary:
	if object_map.has(object_name):
		return object_map[object_name]
	return {}
