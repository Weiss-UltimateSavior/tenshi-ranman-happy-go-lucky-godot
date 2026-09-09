extends Node

const DEFAULT_BOOL_SETTINGS := {
	"fullscreen": false,
	"sqscr": false,
	"skipall": false,
	"readskip": true,
	"readjump": true,
	"curmove": true,
	"curmoveyes": true,
	"filedclk": true,
	"flowshow": true,
	"stopdeactive": true,
	"icpreview": true,
	"suspend": true,
	"noeffect": false,
	"scanim": true,
	"esccancel": true,
	"stayontop": false,
	"facemode": true,
	"qcpopover": true,
	"vspeedsync": true,
	"movierclick": true,
	"movieskip": true,
	"dramatic": true,
	"snapsilent": false,
	"ctrlskip": true,
	"afterskip": false,
	"afterauto": false,
	"voicecut": true,
	"chv": true,
}

const DEFAULT_SLIDERS := {
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
	"chapthidetime": 0.5,
	"bgmhidetime": 0.5,
	"drawspeed": 0.5,
	"vspeed": 0.5,
	"skipspeed": 0.5,
	"atextwait": 0.5,
	"autotime": 0.5,
	"winopac": 0.75,
}

const DEFAULT_RADIOS := {
	"panictype": "panictype_0",
	"curhidestep": "curhidestep_5",
	"skipst": "skipst_1",
	"txv_voice": "txv_voice_1",
	"txv_novo": "txv_novo_1",
	"txv_other": "txv_other_1",
	"color": "color_read",
}

const DEFAULT_COLOR_VALUES := {
	"color_win": Color("d3727a"),
	"color_owin": Color("423d75"),
	"color_text": Color.WHITE,
	"color_read": Color("efdfff"),
}

# The original game stores a font face selection in its system configuration.
# Keep the selection inside the project instead of loading arbitrary Windows
# font collections at runtime: some TTC files are not safe to open through
# Godot's dynamic-font loader and caused the Text settings page to terminate.
const DEFAULT_MESSAGE_FONT_ID := "sourcehansansjp-bold"
const MESSAGE_FONT_OPTIONS := [
	{
		"id": "sourcehansansjp-bold",
		"label": "Source Han Sans JP Bold",
		"path": "res://assets/data/font/sourcehansansjp-bold.otf",
	},
	{
		"id": "sourcehansansjp-regular",
		"label": "Source Han Sans JP Regular",
		"path": "res://assets/data/font/sourcehansansjp-regular.otf",
	},
	{
		"id": "sourcehansansjp-heavy",
		"label": "Source Han Sans JP Heavy",
		"path": "res://assets/data/font/sourcehansansjp-heavy.otf",
	},
	{
		"id": "sourcehanserifjp-bold",
		"label": "Source Han Serif JP Bold",
		"path": "res://assets/data/font/sourcehanserifjp-bold.otf",
	},
	{
		"id": "kosugimaru-regular",
		"label": "Kosugi Maru",
		"path": "res://assets/data/font/kosugimaru-regular.ttf",
	},
]

const CONFIG_PATH := "user://system_settings.cfg"
const LEGACY_UI_PLACEHOLDER_WINDOW_COLOR := Color(1.0, 0.62, 0.73, 1.0)
const LEGACY_UI_PLACEHOLDER_TEXT_COLOR := Color(0.08, 0.07, 0.07, 1.0)
const LEGACY_UI_PLACEHOLDER_READ_COLOR := Color(0.62, 0.38, 0.50, 1.0)

signal message_appearance_changed

var bool_settings: Dictionary = {}
var slider_values: Dictionary = {}
var muted: Dictionary = {}
var radio_values: Dictionary = {}
var confirm_settings: Dictionary = {}
var key_labels: Dictionary = {}
var color_values: Dictionary = {}
var selected_color_target := "color_read"
var selected_font_name := DEFAULT_MESSAGE_FONT_ID
var message_font_cache: Dictionary = {}


func _ready() -> void:
	reset_defaults(false)
	load_settings()
	apply_all()


func reset_defaults(save_after: bool = true) -> void:
	bool_settings = DEFAULT_BOOL_SETTINGS.duplicate()
	slider_values = DEFAULT_SLIDERS.duplicate()
	radio_values = DEFAULT_RADIOS.duplicate()
	color_values = DEFAULT_COLOR_VALUES.duplicate()
	selected_color_target = "color_read"
	selected_font_name = DEFAULT_MESSAGE_FONT_ID
	muted.clear()
	key_labels.clear()
	confirm_settings.clear()
	for name in [
		"cf_save", "cf_overwrite", "cf_dsave", "cf_load", "cf_qsave", "cf_qload",
		"cf_title", "cf_jump", "cf_flow", "cf_next", "cf_backto", "cf_nextscn",
		"cf_prevscn", "cf_vsave", "cf_init", "cf_initstand", "cf_delete",
		"cf_swap", "cf_copy", "cf_exit", "cf_resume"
	]:
		confirm_settings[name] = true
	for name in ["wave", "bgm", "down", "se", "sysse", "voice", "movie", "bgv", "chv"]:
		muted[name] = false
	if save_after:
		save_settings()
		apply_all()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for key in bool_settings.keys():
		bool_settings[key] = bool(config.get_value("bool", str(key), bool_settings[key]))
	for key in slider_values.keys():
		slider_values[key] = clampf(float(config.get_value("slider", str(key), slider_values[key])), 0.0, 1.0)
	for key in muted.keys():
		muted[key] = bool(config.get_value("mute", str(key), muted[key]))
	for key in radio_values.keys():
		radio_values[key] = str(config.get_value("radio", str(key), radio_values[key]))
	for key in confirm_settings.keys():
		confirm_settings[key] = bool(config.get_value("confirm", str(key), confirm_settings[key]))
	for key in color_values.keys():
		var loaded: Variant = config.get_value("color", str(key), color_values[key])
		if typeof(loaded) == TYPE_COLOR:
			color_values[key] = loaded
	selected_color_target = str(config.get_value("ui", "selected_color_target", selected_color_target))
	if not color_values.has(selected_color_target):
		selected_color_target = "color_read"
	selected_font_name = _normalize_font_id(str(config.get_value("ui", "selected_font_name", selected_font_name)))
	if config.has_section("keys"):
		for key in config.get_section_keys("keys"):
			key_labels[str(key)] = str(config.get_value("keys", str(key), ""))
	_migrate_legacy_ui_placeholders()


func _migrate_legacy_ui_placeholders() -> void:
	# Early Godot builds persisted colour-picker preview placeholders as if they
	# were player choices.  They do not exist in the original configuration and
	# visibly replace the source defaults in every message window.
	var changed := false
	if color_values.get("color_win") == LEGACY_UI_PLACEHOLDER_WINDOW_COLOR:
		color_values["color_win"] = DEFAULT_COLOR_VALUES["color_win"]
		changed = true
	if color_values.get("color_owin") == LEGACY_UI_PLACEHOLDER_WINDOW_COLOR:
		color_values["color_owin"] = DEFAULT_COLOR_VALUES["color_owin"]
		changed = true
	if color_values.get("color_text") == LEGACY_UI_PLACEHOLDER_TEXT_COLOR:
		color_values["color_text"] = DEFAULT_COLOR_VALUES["color_text"]
		changed = true
	if color_values.get("color_read") == LEGACY_UI_PLACEHOLDER_READ_COLOR:
		color_values["color_read"] = DEFAULT_COLOR_VALUES["color_read"]
		changed = true
	if is_equal_approx(float(slider_values.get("winopac", DEFAULT_SLIDERS["winopac"])), 1.0):
		slider_values["winopac"] = DEFAULT_SLIDERS["winopac"]
		changed = true
	if changed:
		save_settings()
	message_appearance_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in bool_settings.keys():
		config.set_value("bool", str(key), bool_settings[key])
	for key in slider_values.keys():
		config.set_value("slider", str(key), slider_values[key])
	for key in muted.keys():
		config.set_value("mute", str(key), muted[key])
	for key in radio_values.keys():
		config.set_value("radio", str(key), radio_values[key])
	for key in confirm_settings.keys():
		config.set_value("confirm", str(key), confirm_settings[key])
	for key in color_values.keys():
		config.set_value("color", str(key), color_values[key])
	config.set_value("ui", "selected_color_target", selected_color_target)
	config.set_value("ui", "selected_font_name", selected_font_name)
	for key in key_labels.keys():
		config.set_value("keys", str(key), key_labels[key])
	config.save(CONFIG_PATH)


func apply_all() -> void:
	_apply_display()
	_apply_audio()


func set_radio(widget_name: String) -> void:
	var group_name := _group_name(widget_name)
	if widget_name.ends_with("_on") or widget_name.ends_with("_off"):
		bool_settings[group_name] = widget_name.ends_with("_on")
	else:
		radio_values[group_name] = widget_name
	save_settings()
	apply_all()


func get_radio(group_name: String, fallback: String) -> String:
	if bool_settings.has(group_name):
		return group_name + ("_on" if bool(bool_settings[group_name]) else "_off")
	return str(radio_values.get(group_name, fallback))


func set_bool(name: String, value: bool) -> void:
	bool_settings[_canonical_control_name(name)] = value
	save_settings()
	apply_all()


func get_bool(name: String, fallback: bool = false) -> bool:
	var key := _canonical_control_name(name)
	if confirm_settings.has(key):
		return bool(confirm_settings[key])
	return bool(bool_settings.get(key, fallback))


func set_slider(name: String, value: float) -> void:
	var key := _canonical_control_name(name)
	slider_values[key] = clampf(value, 0.0, 1.0)
	save_settings()
	apply_all()
	if key == "winopac":
		message_appearance_changed.emit()


func get_slider(name: String, fallback: float = 0.5) -> float:
	return float(slider_values.get(_canonical_control_name(name), fallback))


func set_muted(name: String, value: bool) -> void:
	muted[_canonical_control_name(name).trim_suffix("_mute")] = value
	save_settings()
	apply_all()


func is_muted(name: String) -> bool:
	return bool(muted.get(_canonical_control_name(name).trim_suffix("_mute"), false))


func set_confirm(name: String, value: bool) -> void:
	confirm_settings[name] = value
	save_settings()


func set_all_confirms(value: bool) -> void:
	for key in confirm_settings.keys():
		confirm_settings[key] = value
	save_settings()


func set_key_label(name: String, label: String) -> void:
	key_labels[name] = label
	save_settings()


func get_key_label(name: String, fallback: String) -> String:
	return str(key_labels.get(name, fallback))


func set_color_target(name: String) -> void:
	if not color_values.has(name):
		return
	selected_color_target = name
	radio_values["color"] = name
	save_settings()


func get_color_target() -> String:
	return selected_color_target


func set_color_for_target(name: String, color: Color) -> void:
	if not color_values.has(name):
		return
	color_values[name] = color
	save_settings()
	message_appearance_changed.emit()


func get_color_for_target(name: String, fallback: Color = Color.WHITE) -> Color:
	return color_values.get(name, fallback)


func reset_color_for_target(name: String) -> void:
	if not DEFAULT_COLOR_VALUES.has(name):
		return
	color_values[name] = DEFAULT_COLOR_VALUES[name]
	save_settings()
	message_appearance_changed.emit()


func set_font_name(name: String) -> void:
	selected_font_name = _normalize_font_id(name)
	save_settings()
	message_appearance_changed.emit()


func get_font_name() -> String:
	return selected_font_name


func get_message_font() -> Font:
	if message_font_cache.has(selected_font_name):
		return message_font_cache[selected_font_name] as Font
	var font := _load_project_font(get_message_font_path())
	if font == null:
		# The restored original default is always the final fallback.
		font = _load_project_font(str(MESSAGE_FONT_OPTIONS[0].get("path", "")))
	if font != null:
		message_font_cache[selected_font_name] = font
	return font


func get_message_font_path() -> String:
	for option in MESSAGE_FONT_OPTIONS:
		if str(option.get("id", "")) == selected_font_name:
			return str(option.get("path", ""))
	return str(MESSAGE_FONT_OPTIONS[0].get("path", ""))


func get_message_font_options() -> Array:
	return MESSAGE_FONT_OPTIONS.duplicate(true)


func get_message_font_label() -> String:
	for option in MESSAGE_FONT_OPTIONS:
		if str(option.get("id", "")) == selected_font_name:
			return str(option.get("label", selected_font_name))
	return str(MESSAGE_FONT_OPTIONS[0].get("label", DEFAULT_MESSAGE_FONT_ID))


func _normalize_font_id(value: String) -> String:
	for option in MESSAGE_FONT_OPTIONS:
		if value == str(option.get("id", "")):
			return value
	# Earlier builds persisted absolute system-font paths. They cannot be
	# shipped with the game and are intentionally migrated to the original font.
	return DEFAULT_MESSAGE_FONT_ID


func _load_project_font(resource_path: String) -> Font:
	if resource_path == "" or not resource_path.begins_with("res://"):
		return null
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var font := FontFile.new()
	if font.load_dynamic_font(absolute_path) == OK:
		return font
	return null


func _apply_display() -> void:
	if bool(bool_settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(AppConfig.design_size())


func _apply_audio() -> void:
	if AudioManager == null:
		return
	AudioManager.set_master_volume(_effective_volume("wave"))
	AudioManager.set_bgm_volume(_effective_volume("bgm"))
	AudioManager.set_sysse_volume(_effective_volume("sysse") * _effective_volume("se"))
	AudioManager.set_voice_volume(_effective_volume("voice"))
	AudioManager.set_movie_volume(_effective_volume("movie"))


func _effective_volume(name: String) -> float:
	if bool(muted.get(name, false)):
		return 0.0
	return clampf(float(slider_values.get(name, 1.0)), 0.0, 1.0)


func _group_name(widget_name: String) -> String:
	var idx := widget_name.rfind("_")
	if idx < 0:
		return widget_name
	return widget_name.substr(0, idx)


func _canonical_control_name(name: String) -> String:
	var result := name
	if result.ends_with("_slider"):
		result = result.trim_suffix("_slider")
	if result.ends_with("_mute"):
		result = result.trim_suffix("_mute")
	return result
