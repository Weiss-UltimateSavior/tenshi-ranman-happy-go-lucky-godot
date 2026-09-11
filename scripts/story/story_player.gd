extends Control

#"st04_04.ks" / "*0429_4"

signal action_requested(action: String)

# The original Extractor_Output/scn workspace is shipped inside assets/scn.
const SCENARIO_ROOT := AppConfig.GAME_ROOT + "/scn"
const RESTORED_ROOT := AppConfig.RESTORED_ROOT
const ENTRY_STORAGE := "st01_01.ks"
const ENTRY_TARGET := "*0408"
const WINDOW_BASE := "res://assets/ui/exported/window/layers/5950.png"
const QUICKMENU_LAYER_DIR := "res://assets/ui/exported/quickmenu/layers/"
const VOICEBAR_LAYER_DIR := "res://assets/ui/exported/voicebar/layers/"
# TLG->PNG converter: the Windows environment uses the historical
# Tlg2Png.exe from the Codex workspace; other platforms build the
# cross-platform tools/tlg2png C tool (see docs/tlg2png.md).
const TLG2PNG_WIN := AppConfig.CODEX_WORK_ROOT + "/tlg2png/Tlg2Png.exe"
const TLG2PNG_NATIVE := "res://tools/tlg2png/tlg2png"
# TLG conversion output is a per-machine cache, so it stays in user://.
const CACHE_ROOT := "user://godot_cache"
const UI_SCALE := Vector2(1280.0 / 1920.0, 720.0 / 1440.0)
const HUD_SCALE := 1280.0 / 1920.0
const SOURCE_SCALE := 1280.0 / 1920.0
const SOURCE_SCALE_VECTOR := Vector2(SOURCE_SCALE, SOURCE_SCALE)
const WhiteBallEmitterScene := preload("res://scripts/story/white_ball_emitter.gd")
const BranchFlags := preload("res://scripts/story/branch_flags.gd")
const SelectScreen := preload("res://scripts/ui/select_screen.gd")
# KAGEnvironment converts between a perspective-space z position and z-order
# with cameraoffsetz=-100. Character layers opt into zorderZoom/zorderMove,
# so their scale and authored offsets use this derived resolution.
const KAG_CAMERA_OFFSET_Z := -100.0
# `slayer` is a camera-enabled KAG layer.  Its xpos/ypos coordinates are
# offsets from the original game's stage composition reference point, not
# screen-space top-left positions. The horizontal reference was calibrated
# against the untouched name_sana source asset's underline in the original
# renderer; ypos already aligned at the same reference.
const SLAYER_STAGE_ORIGIN_SOURCE := Vector2(842.0, 487.0)
const STAND_PSD_PAGE_VERTICAL_OFFSET := 139.0
# PBD layer JSON is regenerated on demand from the shipped .pbd payloads
# (qa/pbd_json_test); the Windows Codex workspace is only a fallback.
const STAND_PBD_JSON_ROOT := "user://pbd_json"
const PRELOAD_TEXTURES_PER_FRAME := 16
const STAND_DRESS_MOJIBAKE := {
	"蛻ｶ譛肴丼": "制服春",
	"蛻ｶ譛肴丼謇・": "制服春",
	"蛻ｶ譛狗ｧ・": "制服夏",
	"遘∵恪譏･": "私服春",
	"遘∵恪螟・": "私服夏",
	"豌ｴ逹": "水着",
	"繝代ず繝｣繝・": "パジャマ",
	"繧ｦ繧ｧ繧､繝医Ξ繧ｹ": "ウェイトレス",
	"繝代・繧ｫ繝ｼ": "パーカー",
}
const ORIGINAL_WINDOW_COLOR := Color("d3727a")
const ORIGINAL_OTHER_WINDOW_COLOR := Color("423d75")
const ORIGINAL_TEXT_COLOR := Color.WHITE
const ORIGINAL_READ_TEXT_COLOR := Color("efdfff")
const ORIGINAL_WINDOW_OPACITY := 0.75
const MESSAGE_FONT := "res://assets/data/font/sourcehansansjp-bold.otf"
const CLICK_GLYPH := "res://assets/data/image/sys/clickglyph.png"
const CLICK_GLYPH_FRAME_SIZE := Vector2(49, 50)
const CLICK_GLYPH_FRAME_TIME := 0.08
# KAG's `character` zorder is local to the scene composition.  Message faces
# use absoluteBase=1000001 in envinit.tjs, placing the complete message UI
# above every stage/character z-order.  Keep equivalent, separate domains in
# Godot so an `order` action cannot draw a stand over the dialogue window.
const SCENE_COMPOSITION_Z := 0
const MESSAGE_WINDOW_Z := 1000
const MOVIE_OVERLAY_Z := 2000
const MESSAGE_WINDOW_OVERLAY_SHADER := """
shader_type canvas_item;

// custom.tjs uses fillOperateRect(..., omPsOverlay) after restoring the
// window PIMG's grayscale base.  A regular CanvasItem modulate multiplies
// the two colours instead, which makes the original pink frame much too dark.
// The colour originates from Kirikiri's 0xRRGGBB config value.  Do not mark
// this as source_color: that conversion is for an editor-authored sRGB swatch
// and would convert a runtime Color a second time.
uniform vec4 overlay_color = vec4(0.827451, 0.447059, 0.478431, 1.0);

void fragment() {
	vec4 base_sample = texture(TEXTURE, UV);
	// KAG's D3D omPsOverlay blends the legacy PIMG values in display/gamma
	// space. CanvasItem shaders receive sampled textures in Godot's linear
	// space, so move into the same domain before evaluating the Overlay curve.
	vec3 base = pow(base_sample.rgb, vec3(1.0 / 2.2));
	// Runtime Color values come from Kirikiri's display-space 0xRRGGBB setting.
	// Unlike sampled PIMG pixels, they are passed to this non-source_color
	// uniform unchanged. Converting them again washed the lower, opaque half of
	// the message frame into grey and made it appear absent over bright scenes.
	vec3 tint = overlay_color.rgb;
	vec3 dark = 2.0 * base * tint;
	vec3 light = 1.0 - 2.0 * (1.0 - base) * (1.0 - tint);
	// The Compatibility renderer writes CanvasItem output in the display domain.
	// `base` above has already moved the imported PIMG into that domain; encoding
	// the Overlay result again with pow(..., 2.2) makes the opaque lower section
	// brown/grey instead of the source game's pink message frame.
	vec3 result = mix(dark, light, step(vec3(0.5), base));
	// CanvasItem's incoming COLOR already contains the TextureRect texture.
	// Re-multiplying by it darkens the grayscale PIMG a second time. Retain its
	// alpha (including the configurable window opacity) only.
	COLOR = vec4(result, COLOR.a);
}
"""
const MESSAGE_NAME_RECT := Rect2(450, 822, 792, 53)
const MESSAGE_TEXT_RECT := Rect2(468, 867, 1154, 160)
# Kirikiri's embedded message face and Godot's dynamic fonts do not share the
# same ascent.  This preserves the original PIMG rectangles while moving only
# the visible first-line baseline to its Kirikiri position.
const MESSAGE_TEXT_BASELINE_COMPENSATION := 5.0
const QUICK_ACTION_ORDER := [
	"hold", "custom", "save", "load", "qsave", "qload", "option",
	"prev", "prevscn", "backskip", "backone", "log", "auto",
	"skip", "nextscn", "next", "scnchart", "volchg",
	"vreplay", "qvsave", "snapshot", "hide", "title"
]
const QUICK_ICON_IDS := {
	"hold": {"off": 3313, "on": 5740},
	"dsave": {"off": 4380, "on": 5791},
	"save": {"off": 4372, "on": 5783},
	"load": {"off": 4364, "on": 5775},
	"qsave": {"off": 4356, "on": 5767},
	"qload": {"off": 4335, "on": 5759},
	"option": {"off": 3290, "on": 5751},
	"prev": {"off": 3053, "on": 5750},
	"prevscn": {"off": 3054, "on": 5749},
	"backskip": {"off": 3055, "on": 5748},
	"backone": {"off": 3192, "on": 5747},
	"log": {"off": 3056, "on": 5746},
	"auto": {"off": 3051, "on": 5745},
	"skip": {"off": 3049, "on": 5744},
	"nextscn": {"off": 3047, "on": 5743},
	"next": {"off": 3045, "on": 5742},
	"custom": {"off": 3311, "on": 5739},
	"scnchart": {"off": 3288, "on": 5738},
	"volchg": {"off": 3280, "on": 5737},
	"vreplay": {"off": 3278, "on": 5736},
	"qvsave": {"off": 3274, "on": 5734},
	"vsave": {"off": 3276, "on": 5735},
	"snapshot": {"off": 3272, "on": 5733},
	"hide": {"off": 3110, "on": 5732},
	"title": {"off": 3223, "on": 5731},
}

var texture_cache: Dictionary = {}
var stream_cache: Dictionary = {}
var image_resolve_cache: Dictionary = {}
var character_image_resolve_cache: Dictionary = {}
var audio_resolve_cache: Dictionary = {}
var scenario_cache: Dictionary = {}
var scenario_preload_keys: Dictionary = {}
var preload_thread := Thread.new()
var preload_mutex := Mutex.new()
var preload_semaphore := Semaphore.new()
var preload_running := false
var preload_jobs: Array = []
var preload_enqueued: Dictionary = {}
var preloaded_images: Dictionary = {}
var preloaded_streams: Dictionary = {}
var preloaded_scenarios: Dictionary = {}
var preload_schedule_key := ""
var preload_scheduled_until := 0
var storage := ""
var target := ""
var scenario: Dictionary = {}
var scene_index := 0
var line_index := 0
var pending_texts: Array = []
var bgm_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var stage_layer: TextureRect
var event_layer: TextureRect
var scene_camera_layer: Control
var stage_effect_layer: Control
var character_layer: Control
var window_layer: Control
var message_face_layer: Control
var quickmenu_layer: Control
var voicebar_layer: Control
var name_label: Label
var text_label: Label
var window_base: TextureRect
var click_glyph: Sprite2D
var click_glyph_elapsed := 0.0
var click_glyph_frame := 0
var message_font: Font
var character_nodes: Dictionary = {}
var character_image_files: Dictionary = {}
var character_visual_keys: Dictionary = {}
var message_face_node: Control
var message_face_key := ""
var quick_button_visuals: Dictionary = {}
var stand_sinfo_cache: Dictionary = {}
var stand_pbd_cache: Dictionary = {}
var last_voice_name := ""
var current_entry: Dictionary = {}
var history_entries: Array = []
var window_hidden := false
var message_window_mode := "MSGWIN"
var current_chapter := ""
var current_scnchart := ""
var respect_script_waits := true
var replaying_state := false
var wait_deadline_ms := -1
var waiting_for_voice := false
var waiting_for_actions := false
var active_action_count := 0
var active_transition_message_hides := 0
var script_skip_scope := false
var backlog_mode := false
var auto_mode := false
var skip_mode := false
var muted := false
var auto_elapsed := 0.0
var bgm_current_path := ""
var visual_layer_paths: Dictionary = {}
var auxiliary_visual_paths: Dictionary = {}
var script_effect_layer: Control
var auxiliary_visual_nodes: Dictionary = {}
var particle_emitters: Dictionary = {}
var stage_effect_animations: Dictionary = {}
var sound_players: Dictionary = {}
var sound_channel_kinds: Dictionary = {}
var movie_overlay: ColorRect
var movie_player: VideoStreamPlayer
var movie_playing := false
var movie_can_skip := false
var current_movie_storage := ""
var environment_camera_x := 0.0
var environment_camera_y := 0.0
var environment_camera_zoom := 100.0
var branch_flags: BranchFlags
var selection_pending := false
var _pending_selects: Array = []
var _pending_select_info: Dictionary = {}
var _select_screen: Control = null
var selection_history: Array = []
var last_branch_decision: Dictionary = {}
var last_selection_event: Dictionary = {}
var game_ended := false
var _decision_load_failed := false
var procedural_script_actions: Array[Dictionary] = []
var script_action_tweens: Array[Tween] = []


func _ready() -> void:
	if SystemSettings != null and not SystemSettings.message_appearance_changed.is_connected(_on_message_appearance_changed):
		SystemSettings.message_appearance_changed.connect(_on_message_appearance_changed)
	_fit_full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	branch_flags = BranchFlags.new()
	_start_preload_thread()
	_build_layers()
	AudioManager.stop_bgm()
	start(ENTRY_STORAGE, ENTRY_TARGET)


func _exit_tree() -> void:
	_cancel_script_action_tweens()
	_clear_visual_transition_overlays()
	_stop_preload_thread()


func _process(delta: float) -> void:
	_drain_preloaded_assets()
	_update_click_glyph(delta)
	_update_stage_effect_animations(delta)
	_update_procedural_script_actions(delta)
	if game_ended:
		return
	if backlog_mode:
		return
	if _process_script_wait():
		return
	if skip_mode or Input.is_key_pressed(KEY_CTRL):
		for i in range(3):
			advance()
		return
	if auto_mode:
		auto_elapsed += delta
		if auto_elapsed >= 1.35 and not voice_player.playing:
			auto_elapsed = 0.0
			advance()


func start(start_storage: String, start_target: String = "") -> void:
	# A new scenario/target replaces the active KAG state.  Source actions from
	# the old state must not continue mutating freshly created stage nodes.
	_clear_runtime_story_state()
	# envinit keeps the empty event canvas alive.  It is visually inert without a
	# texture, but subsequent event updates assume that baseline visibility.
	if event_layer != null:
		event_layer.visible = true
	storage = start_storage.to_lower()
	target = start_target
	if not _load_scenario(storage):
		_show_error("Scenario not found: " + storage)
		return
	_select_scene(target)
	_continue_until_text()


func _gui_input(event: InputEvent) -> void:
	if movie_playing:
		if event is InputEventMouseButton and event.pressed:
			if movie_can_skip and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
				_finish_movie()
			accept_event()
			return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			if movie_can_skip:
				_finish_movie()
			accept_event()
			return
		accept_event()
		return
	if backlog_mode:
		# Backlog is a modal history overlay.  Do not let this Control consume a
		# press before the overlay can receive it, and never advance the story
		# while it is shown.
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		# Keep the story canvas as the single backlog entry point. Consuming the
		# notch here prevents a click-style advance behind the modal overlay.
		action_requested.emit("backlog")
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if window_hidden:
			_set_window_hidden(false)
			return
		advance()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_set_window_hidden(not window_hidden)
	elif event.is_action_pressed("ui_accept"):
		advance()
	elif event.is_action_pressed("ui_cancel"):
		_set_window_hidden(not window_hidden)


func advance() -> void:
	if game_ended:
		return
	auto_elapsed = 0.0
	if _is_script_waiting():
		return
	if window_hidden:
		_set_window_hidden(false)
		return
	if not pending_texts.is_empty():
		_show_text(pending_texts.pop_front())
		return
	_continue_until_text()


func _build_layers() -> void:
	# envinit.tjs marks stage, event, character, slayer, and related effect
	# layers as cameraMode=true. Keep them in one canvas so an SCN env camera
	# command moves the same composition while the message UI remains fixed.
	scene_camera_layer = Control.new()
	scene_camera_layer.name = "SceneCamera"
	_fit_full_rect(scene_camera_layer)
	scene_camera_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_camera_layer.z_index = SCENE_COMPOSITION_Z
	scene_camera_layer.z_as_relative = false
	add_child(scene_camera_layer)
	stage_layer = _make_texture_layer("Stage", scene_camera_layer)
	stage_effect_layer = Control.new()
	stage_effect_layer.name = "StageEffects"
	_fit_full_rect(stage_effect_layer)
	stage_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_camera_layer.add_child(stage_effect_layer)
	event_layer = _make_texture_layer("Event", scene_camera_layer)
	script_effect_layer = Control.new()
	script_effect_layer.name = "ScriptEffects"
	_fit_full_rect(script_effect_layer)
	script_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_camera_layer.add_child(script_effect_layer)
	character_layer = Control.new()
	character_layer.name = "Characters"
	_fit_full_rect(character_layer)
	character_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_camera_layer.add_child(character_layer)

	window_layer = Control.new()
	window_layer.name = "MessageWindow"
	_fit_full_rect(window_layer)
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.z_index = MESSAGE_WINDOW_Z
	window_layer.z_as_relative = false
	add_child(window_layer)
	window_base = TextureRect.new()
	window_base.name = "WindowBase"
	window_base.texture = load(WINDOW_BASE)
	window_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window_base.stretch_mode = TextureRect.STRETCH_SCALE
	window_base.position = _source_point(Vector2(0, 750))
	window_base.size = _source_point(Vector2(1920, 420))
	window_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_base.material = _make_message_window_overlay_material()
	window_layer.add_child(window_base)

	message_face_layer = Control.new()
	message_face_layer.name = "MessageFace"
	# The original msgwin object is clipped by facemask rather than drawing a
	# miniature full stand over the dialogue surface.
	message_face_layer.position = Vector2(0, 500)
	message_face_layer.size = Vector2(280, 220)
	message_face_layer.clip_contents = true
	message_face_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.add_child(message_face_layer)

	name_label = Label.new()
	name_label.name = "Name"
	name_label.position = _source_point(MESSAGE_NAME_RECT.position)
	name_label.size = _source_point(MESSAGE_NAME_RECT.size)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _message_font())
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", ORIGINAL_TEXT_COLOR)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 1)
	window_layer.add_child(name_label)

	text_label = Label.new()
	text_label.name = "Text"
	text_label.position = _source_point(MESSAGE_TEXT_RECT.position + Vector2(0, MESSAGE_TEXT_BASELINE_COMPENSATION))
	text_label.size = _source_point(MESSAGE_TEXT_RECT.size)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_override("font", _message_font())
	text_label.add_theme_font_size_override("font_size", 26)
	# Original config.tjs uses SizeCoef(8): 12px on the 1920 canvas and 8px
	# after the game's 1920 -> 1280 presentation scale.
	text_label.add_theme_constant_override("line_spacing", 8)
	text_label.add_theme_color_override("font_color", ORIGINAL_TEXT_COLOR)
	text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	text_label.add_theme_constant_override("outline_size", 1)
	# KAG's defaultEdge takes priority over defaultShadow.  Rendering both in
	# Godot made the dialogue visibly heavier than the original.
	text_label.remove_theme_color_override("font_shadow_color")
	text_label.remove_theme_constant_override("shadow_offset_x")
	text_label.remove_theme_constant_override("shadow_offset_y")
	window_layer.add_child(text_label)

	_build_click_glyph()
	_apply_message_appearance()

	_build_voicebar()
	_build_quickmenu()

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "StoryBGM"
	add_child(bgm_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "StoryVoice"
	add_child(voice_player)

	# envinit.tjs defines movie as the foremost camera-enabled layer. Keep the
	# actual VideoStreamPlayer in a black full-canvas overlay so 16:9 source
	# frames retain their exact original presentation rectangle.
	movie_overlay = ColorRect.new()
	movie_overlay.name = "ScenarioMovieOverlay"
	movie_overlay.color = Color.BLACK
	movie_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	movie_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movie_overlay.z_index = MOVIE_OVERLAY_Z
	movie_overlay.z_as_relative = false
	movie_overlay.visible = false
	add_child(movie_overlay)
	movie_player = VideoStreamPlayer.new()
	movie_player.name = "ScenarioMovie"
	movie_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	movie_player.expand = true
	movie_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movie_player.finished.connect(_on_movie_finished)
	movie_overlay.add_child(movie_player)


func _make_texture_layer(node_name: String, parent: Control) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = node_name
	_fit_full_rect(layer)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _message_font() -> Font:
	if message_font != null:
		return message_font
	if SystemSettings != null:
		message_font = SystemSettings.get_message_font()
	if message_font == null:
		message_font = load(MESSAGE_FONT)
	return message_font


func _on_message_appearance_changed() -> void:
	message_font = null
	var font := _message_font()
	if name_label != null:
		name_label.add_theme_font_override("font", font)
	if text_label != null:
		text_label.add_theme_font_override("font", font)
	_apply_message_appearance()


func _build_click_glyph() -> void:
	click_glyph = Sprite2D.new()
	click_glyph.name = "ClickGlyph"
	# This asset is copied from the original game's loose resource tree.  Loading
	# it through Image avoids a stale Godot import record preventing the glyph
	# from appearing in exported builds.
	click_glyph.texture = _load_image(ProjectSettings.globalize_path(CLICK_GLYPH))
	click_glyph.hframes = 1
	click_glyph.vframes = 11
	click_glyph.frame = 0
	click_glyph.centered = false
	click_glyph.position = _source_point(Vector2(1682, 961))
	click_glyph.scale = Vector2(SOURCE_SCALE, SOURCE_SCALE)
	click_glyph.z_index = 2
	window_layer.add_child(click_glyph)


func _update_click_glyph(delta: float) -> void:
	if click_glyph == null or not click_glyph.visible:
		return
	click_glyph_elapsed += delta
	if click_glyph_elapsed < CLICK_GLYPH_FRAME_TIME:
		return
	click_glyph_elapsed = fmod(click_glyph_elapsed, CLICK_GLYPH_FRAME_TIME)
	click_glyph_frame = (click_glyph_frame + 1) % 11
	click_glyph.frame = click_glyph_frame


func _apply_message_appearance() -> void:
	var window_color := ORIGINAL_WINDOW_COLOR
	var text_color := ORIGINAL_TEXT_COLOR
	var opacity := ORIGINAL_WINDOW_OPACITY
	if SystemSettings != null:
		var color_target := "color_owin" if message_window_mode == "another" else "color_win"
		var fallback_color := ORIGINAL_OTHER_WINDOW_COLOR if message_window_mode == "another" else ORIGINAL_WINDOW_COLOR
		window_color = SystemSettings.get_color_for_target(color_target, fallback_color)
		text_color = SystemSettings.get_color_for_target("color_text", ORIGINAL_TEXT_COLOR)
		opacity = clampf(float(SystemSettings.slider_values.get("winopac", ORIGINAL_WINDOW_OPACITY)), 0.0, 1.0)
	if window_base != null:
		var material := window_base.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("overlay_color", window_color)
		# KAG applies the configured alpha after it has recoloured the PIMG.
		# Keep this separate from the Overlay tint so scene art shows through at
		# the same intensity as the original renderer.
		window_base.modulate = Color(1.0, 1.0, 1.0, opacity)
	if name_label != null:
		name_label.add_theme_color_override("font_color", text_color)
	if text_label != null:
		text_label.add_theme_color_override("font_color", text_color)


func _fit_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_message_window_overlay_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = MESSAGE_WINDOW_OVERLAY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _source_point(point: Vector2) -> Vector2:
	return point * SOURCE_SCALE_VECTOR


func _build_voicebar() -> void:
	voicebar_layer = Control.new()
	voicebar_layer.name = "VoiceBar"
	_fit_full_rect(voicebar_layer)
	voicebar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.add_child(voicebar_layer)
	_add_hud_texture(voicebar_layer, VOICEBAR_LAYER_DIR + "87.png", Rect2(1745, 985, 127, 14))
	_add_hud_texture(voicebar_layer, VOICEBAR_LAYER_DIR + "88.png", Rect2(1746, 986, 123, 10))
	_add_hud_texture(voicebar_layer, VOICEBAR_LAYER_DIR + "92.png", Rect2(1743, 968, 54, 17))


func _build_quickmenu() -> void:
	quickmenu_layer = Control.new()
	quickmenu_layer.name = "QuickMenu"
	_fit_full_rect(quickmenu_layer)
	quickmenu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.add_child(quickmenu_layer)
	_add_hud_texture(quickmenu_layer, QUICKMENU_LAYER_DIR + "4285.png", Rect2(440, 1056, 1340, 24))
	for index in QUICK_ACTION_ORDER.size():
		var action := str(QUICK_ACTION_ORDER[index])
		var rect := Rect2(457 + 57 * index, 1025, 51, 50)
		_add_quick_button(action, rect)


func _add_quick_button(action: String, source_rect: Rect2) -> void:
	var holder := Control.new()
	holder.name = "Quick_" + action
	holder.position = Vector2(source_rect.position.x, source_rect.position.y) * HUD_SCALE
	holder.size = source_rect.size * HUD_SCALE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quickmenu_layer.add_child(holder)

	var bg := _make_texture_rect(QUICKMENU_LAYER_DIR + "4212.png", Rect2(Vector2.ZERO, Vector2(49, 48) * HUD_SCALE))
	bg.position = Vector2(2, 1) * HUD_SCALE
	holder.add_child(bg)
	var icon := _make_texture_rect(_quick_icon_path(action, false), Rect2(Vector2.ZERO, Vector2.ZERO))
	icon.name = "Icon"
	holder.add_child(icon)
	_center_quick_icon(icon, holder.size)

	quick_button_visuals[action] = {"bg": bg, "icon": icon}
	var button := Button.new()
	button.name = "Hit"
	button.text = ""
	button.position = Vector2.ZERO
	button.size = holder.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.mouse_entered.connect(func() -> void: _set_quick_button_state(action, true))
	button.mouse_exited.connect(func() -> void: _set_quick_button_state(action, false))
	button.pressed.connect(func() -> void: _on_quick_action(action))
	holder.add_child(button)


func _make_texture_rect(path: String, rect: Rect2) -> TextureRect:
	var texture := _load_image(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	var tex := TextureRect.new()
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = texture
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	if rect.size == Vector2.ZERO and texture != null:
		tex.size = texture.get_size() * HUD_SCALE
	else:
		tex.position = rect.position
		tex.size = rect.size
	return tex


func _add_hud_texture(parent: Control, path: String, source_rect: Rect2) -> TextureRect:
	var rect := Rect2(source_rect.position * HUD_SCALE, source_rect.size * HUD_SCALE)
	var tex := _make_texture_rect(path, rect)
	parent.add_child(tex)
	return tex


func _center_quick_icon(icon: TextureRect, holder_size: Vector2) -> void:
	icon.position = (holder_size - icon.size) * 0.5


func _quick_icon_path(action: String, active: bool) -> String:
	var ids: Dictionary = QUICK_ICON_IDS.get(action, {})
	var id := int(ids.get("on" if active else "off", 4212))
	return QUICKMENU_LAYER_DIR + str(id) + ".png"


func _set_quick_button_state(action: String, hover: bool) -> void:
	if not quick_button_visuals.has(action):
		return
	var visual: Dictionary = quick_button_visuals[action]
	var bg: TextureRect = visual.get("bg")
	var icon: TextureRect = visual.get("icon")
	var active := hover or _quick_action_is_active(action)
	bg.texture = _load_image(ProjectSettings.globalize_path(QUICKMENU_LAYER_DIR + ("4513.png" if active else "4212.png")))
	icon.texture = _load_image(ProjectSettings.globalize_path(_quick_icon_path(action, active)))
	_center_quick_icon(icon, bg.get_parent().size)


func _quick_action_is_active(action: String) -> bool:
	match action:
		"auto":
			return auto_mode
		"skip":
			return skip_mode
		"volchg":
			return muted
		"hide":
			return window_hidden
	return false


func _on_quick_action(action: String) -> void:
	AudioManager.play_sysse("chg1")
	match action:
		"next":
			advance()
		"auto":
			auto_mode = not auto_mode
			skip_mode = false
		"skip":
			skip_mode = not skip_mode
			auto_mode = false
		"hide":
			_set_window_hidden(true)
		"vreplay":
			if last_voice_name != "":
				_play_voice(last_voice_name)
		"volchg":
			muted = not muted
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
		"option":
			action_requested.emit("system")
		"save", "dsave", "qsave":
			action_requested.emit(action)
		"load", "qload":
			action_requested.emit(action)
		"log":
			action_requested.emit("backlog")
		"scnchart":
			action_requested.emit("flowchart")
		"snapshot":
			_save_story_screenshot()
		"title":
			action_requested.emit("title")
		"backone", "prev", "prevscn", "backskip":
			pass
		_:
			pass
	_set_quick_button_state(action, false)


func _set_window_hidden(hidden: bool) -> void:
	window_hidden = hidden
	window_layer.visible = not hidden and not backlog_mode


func set_backlog_mode(enabled: bool) -> void:
	backlog_mode = enabled
	if window_layer != null:
		window_layer.visible = not enabled and not window_hidden
	if enabled and voice_player != null:
		voice_player.stop()


func play_history_voice(voice: String) -> void:
	if voice != "":
		_play_voice(voice)


func toggle_history_favorite(index: int) -> bool:
	if index < 0 or index >= history_entries.size():
		return false
	var entry: Dictionary = Dictionary(history_entries[index])
	entry["favorite"] = not bool(entry.get("favorite", false))
	history_entries[index] = entry
	return bool(entry["favorite"])


func _save_story_screenshot() -> void:
	var output_dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "")
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(output_dir + "/tenshin_" + stamp + ".png"))


func _load_scenario(next_storage: String) -> bool:
	var cached_key := next_storage.to_lower()
	if scenario_cache.has(cached_key):
		scenario = scenario_cache[cached_key]
		return true
	preload_mutex.lock()
	var preloaded = preloaded_scenarios.get(cached_key)
	if preloaded != null:
		preloaded_scenarios.erase(cached_key)
	preload_mutex.unlock()
	if preloaded != null:
		var preloaded_data: Dictionary = preloaded.get("data", {}) if typeof(preloaded) == TYPE_DICTIONARY else preloaded
		scenario_cache[cached_key] = preloaded_data
		scenario = preloaded_data
		return true
	var path := SCENARIO_ROOT + "/" + next_storage.to_lower().trim_suffix(".scn") + ".json"
	if not FileAccess.file_exists(path):
		path = SCENARIO_ROOT + "/" + next_storage.to_lower().replace(".ks", ".ks.json")
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	scenario = parsed
	scenario_cache[cached_key] = parsed
	return true


func _select_scene(scene_target: String) -> void:
	scene_index = 0
	line_index = 0
	if scene_target == "":
		return
	var scenes: Array = scenario.get("scenes", [])
	for index in scenes.size():
		var scene: Dictionary = scenes[index]
		if str(scene.get("label", "")).to_lower() == scene_target.to_lower():
			scene_index = index
			return


func _continue_until_text() -> void:
	if _is_script_waiting():
		return
	while true:
		var scenes: Array = scenario.get("scenes", [])
		if scene_index >= scenes.size():
			if not _jump_to_next_storage():
				if game_ended or _decision_load_failed:
					return
				_show_error("End of playable scenario.")
				return
			continue
		var scene: Dictionary = scenes[scene_index]
		var lines: Array = scene.get("lines", [])
		while line_index < lines.size():
			var line: Variant = lines[line_index]
			line_index += 1
			_apply_line_state(line)
			if _is_script_waiting():
				return
			if _is_number(line):
				var entry := _text_entry(scene, int(line))
				if not entry.is_empty():
					if script_skip_scope:
						_apply_skipped_text_entry(entry)
						continue
					_show_text(entry)
					return
		if _scene_requests_selection(scene):
			return
		_decision_load_failed = false
		var jumped := _jump_to_next_scene_or_storage(scene)
		if not jumped and not _decision_load_failed and scene.get("nexts", []).is_empty():
			# A scene compiled without nexts falls back to scanning the rest of
			# the storage for the next jumpable edge (PLAN_P0 step 2).
			jumped = _jump_to_next_storage()
		if _decision_load_failed:
			# A branch decision was reached but its storage JSON is missing; a
			# specific error is already shown and playback must not loop.
			return
		if not jumped:
			if game_ended:
				return
			_show_error("End of playable scenario.")
			return


func _scene_requests_selection(scene: Dictionary) -> bool:
	# A scene carrying selects pauses playback instead of following nexts:
	# apply_selection() resumes after the player picks one
	# (docs/plan/PLAN_P0_BRANCH_ENGINE.md step 3).
	if replaying_state or selection_pending:
		return false
	var selects: Array = scene.get("selects", [])
	if selects.is_empty():
		return false
	var available := _filter_selects(selects)
	if available.is_empty():
		push_warning("All selects filtered out at %s *%s; falling through to nexts" % [storage, str(scene.get("label", ""))])
		return false
	_present_selection(available, scene.get("selectInfo", {}))
	return true


func _filter_selects(selects: Array) -> Array:
	var available: Array = []
	for option_value in selects:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		if option.has("eval") and not branch_flags.check(str(option["eval"])):
			continue
		available.append(option)
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("selidx", 0)) < int(b.get("selidx", 0))
	)
	return available


func _present_selection(available: Array, info: Dictionary) -> void:
	_pending_selects = available
	_pending_select_info = info.duplicate(true)
	selection_pending = true
	last_selection_event = {"pending": true, "count": available.size()}
	_present_selection_ui()


func _close_select_screen() -> void:
	if _select_screen != null and is_instance_valid(_select_screen):
		_select_screen.queue_free()
	_select_screen = null


## SelectScreen click handler.
func _on_select_chosen(index: int) -> void:
	apply_selection(index)


## Injection API for QA/trace fixtures: resolves the pending selection exactly
## like a click on the overlay would (PLAN_P0 step 3).
func apply_selection(index: int) -> bool:
	if not selection_pending or index < 0 or index >= _pending_selects.size():
		return false
	var option: Dictionary = _pending_selects[index]
	if not _apply_selection_expression(str(option.get("exp", ""))):
		push_warning("Selection exp could not be parsed: " + str(option.get("exp", "")))
	var tag := str(option.get("tag", ""))
	var chosen_value := _selection_value_from_expression(str(option.get("exp", "")))
	branch_flags.set_branch(tag, chosen_value)
	selection_history.append({
		"storage": str(option.get("storage", storage)),
		"target": str(option.get("target", "")),
		"tag": tag,
		"value": chosen_value,
		"selidx": int(option.get("selidx", 0)),
		"name": str(option.get("name", "")),
	})
	last_selection_event = {
		"pending": false,
		"index": index,
		"storage": str(option.get("storage", storage)),
		"target": str(option.get("target", "")),
		"tag": tag,
		"value": chosen_value,
	}
	_pending_selects = []
	selection_pending = false
	_close_select_screen()
	var next_storage := str(option.get("storage", storage)).to_lower()
	var next_target := str(option.get("target", ""))
	last_branch_decision = {"storage": next_storage, "target": next_target, "source": "select"}
	if next_storage == storage:
		_select_scene(next_target)
	else:
		# Load BEFORE mutating storage/target so a failed load leaves the
		# current cursor consistent (the choice itself is kept in history).
		if not _load_scenario(next_storage):
			_decision_load_failed = true
			_show_error("Scenario not found: " + next_storage + " (missing scn json)")
			return true
		storage = next_storage
		target = next_target
		_select_scene(target)
	_continue_until_text()
	return true


func _apply_selection_expression(expression: String) -> bool:
	var parsed := _selection_expression_parts(expression)
	if parsed.is_empty():
		return false
	branch_flags.set_branch(parsed["tag"], int(parsed["value"]))
	return true


func _selection_expression_parts(expression: String) -> Dictionary:
	var match := RegEx.create_from_string('SetBranchFlags\\("([^"]+)",\\s*(\\d+)\\)').search(expression)
	if match == null:
		return {}
	return {"tag": match.get_string(1), "value": int(match.get_string(2))}


func _selection_value_from_expression(expression: String) -> int:
	var parsed := _selection_expression_parts(expression)
	return int(parsed.get("value", 0))


func _resolve_map_background_path(background_name: String) -> String:
	if background_name == "":
		return ""
	var direct := _resolve_image("bgimage", background_name)
	if direct != "":
		return direct
	direct = _resolve_image("evimage", background_name)
	if direct != "":
		return direct
	return ProjectSettings.globalize_path(ResourceIndex.resolve_first(
		["bgimage", "evimage", "data"],
		_name_candidates(background_name, "png") + _name_candidates(background_name, "jpg")
	))


func _jump_to_next_scene_or_storage(scene: Dictionary) -> bool:
	return _evaluate_nexts(scene.get("nexts", []))


func _evaluate_nexts(nexts: Array) -> bool:
	# Branch points list candidate edges in priority order: the first type-0
	# entry whose eval passes (or that has no eval) wins. type-1 entries are
	# compiler sentinels — error.ks is unreachable by design, and the one other
	# variant (ru05_04 → start.ks *gameend_title) means the scenario finished
	# and control returns to the title.
	# Returns true when playback may continue from the new cursor. A decision
	# whose storage JSON is missing reports _decision_load_failed instead.
	_decision_load_failed = false
	var fallback_error := false
	for item in nexts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var next: Dictionary = item
		var next_type := int(next.get("type", 0))
		if next_type != 0:
			var sentinel_storage := str(next.get("storage", "error.ks")).to_lower()
			if sentinel_storage == "error.ks":
				fallback_error = true
				continue
			_handle_gameend(next)
			return false
		if next.has("eval") and not branch_flags.check(str(next["eval"])):
			continue
		var next_storage := str(next.get("storage", storage)).to_lower()
		var next_target := str(next.get("target", ""))
		last_branch_decision = {"storage": next_storage, "target": next_target, "eval": str(next.get("eval", ""))}
		if next_storage == storage:
			_select_scene(next_target)
			return true
		# Load BEFORE mutating storage/target: a failed load must leave the
		# current cursor untouched so re-evaluation stays consistent.
		if not _load_scenario(next_storage):
			_decision_load_failed = true
			_show_error("Scenario not found: " + next_storage + " (missing scn json)")
			return false
		storage = next_storage
		target = next_target
		_select_scene(target)
		return true
	if fallback_error:
		# Only error sentinels remained: the chart tooling considers this path
		# unreachable, so surface the missing-route condition explicitly.
		_show_error("End of playable scenario. (only unreachable error.ks edges remain)")
		return false
	return false


func _handle_gameend(next: Dictionary) -> void:
	game_ended = true
	var next_storage := str(next.get("storage", "")).to_lower()
	var next_target := str(next.get("target", ""))
	last_branch_decision = {"storage": next_storage, "target": next_target, "source": "gameend"}
	action_requested.emit("gameend")


func _jump_to_next_storage() -> bool:
	# Defensive fallback for scenes without nexts: scan the remaining scenes of
	# the current storage for the next jumpable edge.
	var scenes: Array = scenario.get("scenes", [])
	for index in range(clampi(scene_index, 0, scenes.size()), scenes.size()):
		var candidate: Dictionary = scenes[index]
		var nexts: Array = candidate.get("nexts", [])
		if nexts.is_empty():
			continue
		return _evaluate_nexts(nexts)
	return false


func _text_entry(scene: Dictionary, text_index: int) -> Dictionary:
	var texts: Array = scene.get("texts", [])
	var index := text_index - 1
	if index < 0 or index >= texts.size():
		return {}
	var raw: Variant = texts[index]
	if typeof(raw) != TYPE_ARRAY:
		return {}
	var row: Array = raw
	var entry := {
		"name": "",
		"text": "",
		"voice": "",
		"state": {},
	}
	if row.size() > 0 and row[0] != null:
		entry["name"] = str(row[0])
	if row.size() > 1 and typeof(row[1]) == TYPE_ARRAY:
		var blocks: Array = row[1]
		var text_parts: Array[String] = []
		for block_value in blocks:
			if typeof(block_value) != TYPE_ARRAY:
				continue
			var block: Array = block_value
			if str(entry["name"]) == "" and block.size() > 0 and block[0] != null:
				entry["name"] = str(block[0])
			if block.size() > 1:
				text_parts.append(str(block[1]))
		entry["text"] = "\n".join(text_parts)
	if row.size() > 2 and typeof(row[2]) == TYPE_ARRAY:
		var voices: Array = row[2]
		if not voices.is_empty() and typeof(voices[0]) == TYPE_DICTIONARY:
			entry["voice"] = str(Dictionary(voices[0]).get("voice", ""))
	if row.size() > 4 and typeof(row[4]) == TYPE_DICTIONARY:
		entry["state"] = row[4]
	return entry


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _show_text(entry: Dictionary) -> void:
	current_entry = entry.duplicate(true)
	var history_entry := {
		"name": str(entry.get("name", "")),
		"text": str(entry.get("text", "")),
		"voice": str(entry.get("voice", "")),
		"favorite": bool(entry.get("favorite", false)),
		"state": {"storage": storage, "target": target, "scene_index": scene_index, "line_index": line_index, "branch_flags": branch_flags.to_dict()},
	}
	if history_entries.is_empty() or history_entries.back() != history_entry:
		history_entries.append(history_entry)
		if history_entries.size() > 2000:
			history_entries.pop_front()
	_apply_state(Dictionary(entry.get("state", {})))
	_apply_message_appearance()
	var speaker_name := str(entry.get("name", ""))
	name_label.text = _format_speaker_name(speaker_name)
	text_label.text = str(entry.get("text", ""))
	var voice := str(entry.get("voice", ""))
	if voice != "":
		_play_voice(voice)
	_schedule_story_preload()


func _apply_skipped_text_entry(entry: Dictionary) -> void:
	# beginskip/endskip blocks still apply their KAG state records and waits,
	# but the intermediate text is neither presented nor added to the backlog.
	_apply_state(Dictionary(entry.get("state", {})))


func _format_speaker_name(speaker_name: String) -> String:
	var name := speaker_name.strip_edges()
	if name == "":
		return ""
	# custom.tjs routes all displayed speaker names through dispNameFilter(),
	# whose Japanese format is the original corner-bracket nameplate.
	if (name.begins_with("【") and name.ends_with("】")) or (name.begins_with("[") and name.ends_with("]")):
		return name
	return "【%s】" % name


func _apply_line_state(line: Variant) -> void:
	if typeof(line) != TYPE_ARRAY:
		return
	var row: Array = line
	if row.size() > 1 and typeof(row[1]) == TYPE_DICTIONARY:
		_apply_state(row[1])
	if row.is_empty() or typeof(row[0]) != TYPE_STRING:
		return
	var command := str(row[0])
	_apply_line_command(command, row)
	if command == "envupdate":
		_apply_env_update(row)
	elif command == "delayrun":
		# delayrun embeds the same update grammar after its delay label.
		# It starts an asynchronous KAG action.  The script continues until the
		# matching delaydone, so its nested wait record must not block here.
		for index in range(1, row.size()):
			if str(row[index]) == "envupdate":
				_apply_env_update(row.slice(index + 1), false)
				break


func _apply_line_command(command: String, row: Array) -> void:
	var properties := _line_properties(row)
	match command:
		"msgoff":
			_set_window_hidden(true)
		"msgon":
			_set_window_hidden(false)
		"_meswinchange":
			_set_message_window_mode(str(properties.get("type", "MSGWIN")))
		"meswinload":
			_set_message_window_mode(str(properties.get("page", message_window_mode)))
		"playvoice":
			var voice_name := str(properties.get("voice", ""))
			if voice_name != "":
				_play_voice(voice_name)
		"stopvoice":
			if voice_player != null:
				voice_player.stop()
		"quickmenu":
			if quickmenu_layer != null:
				quickmenu_layer.visible = str(properties.get("fadeout", "false")).to_lower() != "true"
		"sysmovie":
			_apply_sysmovie(properties)
		"beforemovie":
			# The original synchronous hook precedes an actual sysmovie tag. The
			# route flag controls scenario bookkeeping, not a separate visual.
			current_movie_storage = str(properties.get("flag", ""))
		"chapter":
			current_chapter = str(row[1]) if row.size() > 1 else ""
		"scnchart":
			current_scnchart = str(row[1]) if row.size() > 1 else ""
		"er":
			if str(properties.get("all", "false")).to_lower() == "true":
				_erase_all_visuals()
		"wait":
			_request_time_wait(int(properties.get("time", 0)))
		"waitvoice":
			_request_voice_wait()
		"beginskip":
			script_skip_scope = true
		"endskip":
			script_skip_scope = false
		"wact", "delaydone":
			_request_action_wait()


func _line_properties(row: Array) -> Dictionary:
	var result := {}
	for index in range(1, row.size() - 1, 2):
		if typeof(row[index]) == TYPE_STRING:
			result[str(row[index])] = row[index + 1]
	return result


func set_trace_instant_mode(enabled: bool) -> void:
	# Trace fixtures compare script state, not wall-clock playback. Keeping their
	# replay instant makes the baseline deterministic while game sessions retain
	# the source script's waits and action barriers.
	respect_script_waits = not enabled
	if enabled:
		_clear_script_wait()
		_cancel_script_action_tweens()
		_clear_visual_transition_overlays()
		if window_layer != null and not window_hidden and not backlog_mode:
			window_layer.visible = true


func _request_time_wait(duration_ms: int) -> void:
	if not respect_script_waits or replaying_state or duration_ms <= 0:
		return
	wait_deadline_ms = max(wait_deadline_ms, Time.get_ticks_msec() + duration_ms)


func _request_voice_wait() -> void:
	if respect_script_waits and not replaying_state and voice_player != null and voice_player.playing:
		waiting_for_voice = true


func _request_action_wait() -> void:
	if respect_script_waits and not replaying_state and active_action_count > 0:
		waiting_for_actions = true


func _is_script_waiting() -> bool:
	return wait_deadline_ms >= 0 or waiting_for_voice or waiting_for_actions or movie_playing or selection_pending


func _clear_script_wait() -> void:
	wait_deadline_ms = -1
	waiting_for_voice = false
	waiting_for_actions = false


func _process_script_wait() -> bool:
	if not _is_script_waiting():
		return false
	if selection_pending:
		# A choice overlay is up: only apply_selection() may resolve this wait.
		return true
	if movie_playing:
		return true
	if wait_deadline_ms >= 0 and Time.get_ticks_msec() < wait_deadline_ms:
		return true
	if waiting_for_voice and voice_player != null and voice_player.playing:
		return true
	if waiting_for_actions and active_action_count > 0:
		return true
	_clear_script_wait()
	_continue_until_text()
	return true


func _set_message_window_mode(mode: String) -> void:
	var normalized := mode.to_lower()
	message_window_mode = "another" if normalized == "another" else "MSGWIN"
	_apply_message_appearance()


func _erase_all_visuals() -> void:
	_cancel_script_action_tweens()
	_clear_visual_transition_overlays()
	_reset_environment_camera()
	_clear_procedural_script_actions()
	if stage_layer != null:
		stage_layer.visible = false
	if event_layer != null:
		event_layer.visible = false
	_clear_characters()
	_clear_message_face()
	for effect in auxiliary_visual_nodes.values():
		if is_instance_valid(effect):
			effect.queue_free()
	auxiliary_visual_nodes.clear()
	for emitter in particle_emitters.values():
		if is_instance_valid(emitter):
			emitter.queue_free()
	particle_emitters.clear()
	stage_effect_animations.clear()
	_finish_movie(false)


func _apply_env_update(row: Array, wait_for_completion: bool = true) -> void:
	for index in range(row.size() - 1):
		if str(row[index]) != "update" or typeof(row[index + 1]) != TYPE_ARRAY:
			continue
		# SCN encodes the runtime class separately from the object payload:
		# ["new", "_lse0", "loopse"], { "name": "_lse0", ... }.
		# The declaration can be separated from its dictionary by unrelated
		# declarations, so pair on the object name rather than list position.
		var declared_classes: Dictionary = {}
		var declarations: Array[Dictionary] = []
		for update_value in row[index + 1]:
			if typeof(update_value) == TYPE_DICTIONARY:
				var object: Dictionary = Dictionary(update_value).duplicate(true)
				var kind := str(object.get("class", ""))
				if kind == "":
					var object_name := str(object.get("name", ""))
					kind = str(declared_classes.get(object_name, ""))
					if kind == "":
						kind = str(sound_channel_kinds.get(object_name, ""))
					# LoopSE uses a logical `_lse0` wrapper but writes audio to `_se0`.
					# Keep `_se0` as the player name: the next SCN command is
					# `stop _se0`, which must terminate the loop before another SE.
					if kind == "" and declarations.size() == 1:
						var declaration := declarations[0]
						kind = str(declaration.get("class", ""))
				_apply_script_object(kind, object)
			elif typeof(update_value) == TYPE_ARRAY:
				var lifecycle: Array = Array(update_value)
				if lifecycle.size() >= 3 and str(lifecycle[0]) == "new":
					var declaration := {"name": str(lifecycle[1]), "class": str(lifecycle[2])}
					declared_classes[str(declaration["name"])] = str(declaration["class"])
					declarations.append(declaration)
					if str(declaration["class"]) in ["se", "loopse"]:
						sound_channel_kinds[str(declaration["name"])] = str(declaration["class"])
				else:
					_apply_script_lifecycle(lifecycle)
	if wait_for_completion and row.find("wait") >= 0:
		_request_action_wait()


func _apply_script_lifecycle(update: Array) -> void:
	if update.is_empty():
		return
	var operation := str(update[0])
	if operation == "del" and update.size() >= 2:
		_remove_script_object(str(update[1]))
	elif operation == "ren" and update.size() >= 3:
		_rename_script_object(str(update[1]), str(update[2]))


func _apply_script_object(kind: String, object: Dictionary) -> void:
	match kind:
		"bgm", "se", "loopse":
			_apply_sound_object(kind, object)
		"stage":
			_apply_visual_object(stage_layer, object, "bgimage")
			_apply_stage_transform(stage_layer, object)
			_finish_visual_transition(stage_layer, object)
		"event":
			_apply_visual_object(event_layer, object, "evimage")
			_apply_script_transform(event_layer, object, true)
			_finish_visual_transition(event_layer, object)
		"character":
			_apply_character_object(object)
		"msgwin":
			_apply_message_face_object(object)
		"stageeff":
			_apply_stage_effect(object)
		"emotion":
			_apply_emotion_object(object)
		"particle":
			_apply_particle_object(object)
		"env":
			_apply_environment_camera(object)
		"":
			pass
		_:
			_apply_auxiliary_visual(kind, object)


func _apply_state(state: Dictionary) -> void:
	var data: Array = state.get("data", [])
	for item_value in data:
		if typeof(item_value) != TYPE_ARRAY:
			continue
		var item: Array = item_value
		if item.size() < 3 or typeof(item[2]) != TYPE_DICTIONARY:
			continue
		var kind := str(item[1])
		var object: Dictionary = item[2]
		_apply_script_object(kind, object)
	var environment: Variant = state.get("env", null)
	if typeof(environment) == TYPE_DICTIONARY:
		_apply_environment_camera_state(Dictionary(environment))


func _reset_environment_camera() -> void:
	environment_camera_x = 0.0
	environment_camera_y = 0.0
	environment_camera_zoom = 100.0
	_apply_environment_camera_transform()


func _apply_environment_camera(object: Dictionary) -> void:
	var actions: Array = object.get("action", [])
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action: Array = action_value
		if action.size() < 2:
			continue
		var property_name := str(action[0]).to_lower()
		if property_name not in ["camerax", "cameray", "camerazoom"]:
			continue
		var value: Variant = action[1]
		var handler := _script_action_handler(value)
		if handler == "MoveAction":
			_apply_environment_camera_motion(property_name, Array(value)[0])
			continue
		if handler == "SinAction" or handler == "RandomAction":
			_start_environment_procedural_action(property_name, Dictionary(Array(value)[0]), handler)
			continue
		var numeric: Variant = _script_action_number(value)
		if numeric != null:
			_set_environment_camera_value(property_name, float(numeric))


func _apply_environment_camera_state(object: Dictionary) -> void:
	# Every JSON state holds a complete KAG environment snapshot. An `env` with
	# only its name is the default 0/0/100 camera, not an instruction to keep a
	# previous scene's pan and zoom. Retaining those values enlarged the following
	# school-gate background and exposed the unpainted canvas beside it.
	for property_name in ["camerax", "cameray", "camerazoom"]:
		_clear_procedural_camera_action(property_name)
	_reset_environment_camera()
	_apply_environment_camera(object)


func _apply_environment_camera_motion(property_name: String, directive: Dictionary) -> void:
	_clear_procedural_camera_action(property_name)
	var target: Variant = directive.get("value", null)
	if not (typeof(target) == TYPE_INT or typeof(target) == TYPE_FLOAT):
		return
	var start_value := _environment_camera_value(property_name)
	var explicit_start: Variant = directive.get("start", null)
	if typeof(explicit_start) == TYPE_INT or typeof(explicit_start) == TYPE_FLOAT:
		start_value = float(explicit_start)
		_set_environment_camera_value(property_name, start_value)
	var target_value := float(target)
	if replaying_state or not respect_script_waits:
		_set_environment_camera_value(property_name, target_value)
		return
	var seconds := maxf(_script_directive_number(directive, "time", 0.0) / 1000.0, 0.01)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void: _set_environment_camera_value(property_name, value), start_value, target_value, seconds)
	_track_script_action(tween)


func _script_action_handler(value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var entries: Array = value
	if entries.is_empty() or typeof(entries[0]) != TYPE_DICTIONARY:
		return ""
	return str(Dictionary(entries[0]).get("handler", ""))


func _script_directive_number(directive: Dictionary, property_name: String, fallback: float) -> float:
	var value: Variant = directive.get(property_name, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _environment_camera_value(property_name: String) -> float:
	match property_name:
		"camerax":
			return environment_camera_x
		"cameray":
			return environment_camera_y
		"camerazoom":
			return environment_camera_zoom
	return 0.0


func _set_environment_camera_value(property_name: String, value: float) -> void:
	match property_name:
		"camerax":
			environment_camera_x = value
		"cameray":
			environment_camera_y = value
		"camerazoom":
			environment_camera_zoom = maxf(value, 1.0)
	_apply_environment_camera_transform()


func _start_environment_procedural_action(property_name: String, directive: Dictionary, handler: String) -> void:
	_clear_procedural_camera_action(property_name)
	if replaying_state or not respect_script_waits:
		return
	var duration_ms := _script_directive_number(directive, "time", 0.0)
	if duration_ms <= 0.0:
		return
	var amplitude := _script_directive_number(directive, "vibration", 0.0)
	if is_zero_approx(amplitude):
		return
	var action := {
		"target_type": "camera",
		"property": property_name,
		"handler": handler,
		"base": _environment_camera_value(property_name),
		"amplitude": amplitude,
		"cycle_ms": maxf(_script_directive_number(directive, "cycle", duration_ms * 2.0), 1.0),
		"duration_ms": duration_ms,
		"elapsed_ms": 0.0,
		"next_sample_ms": 0.0,
		"sample_interval_ms": maxf(_script_directive_number(directive, "waittime", _script_directive_number(directive, "waitTime", 20.0)), 1.0),
		"random_offset": 0.0,
	}
	procedural_script_actions.append(action)
	active_action_count += 1


func _clear_procedural_camera_action(property_name: String) -> void:
	for index in range(procedural_script_actions.size() - 1, -1, -1):
		var action: Dictionary = procedural_script_actions[index]
		if str(action.get("target_type", "")) != "camera" or str(action.get("property", "")) != property_name:
			continue
		_set_environment_camera_value(property_name, float(action.get("base", 0.0)))
		procedural_script_actions.remove_at(index)
		active_action_count = maxi(0, active_action_count - 1)


func _apply_environment_camera_transform() -> void:
	if scene_camera_layer == null:
		return
	var zoom := environment_camera_zoom / 100.0
	var center := size * 0.5
	scene_camera_layer.pivot_offset = center
	scene_camera_layer.scale = Vector2(zoom, zoom)
	# Stage's existing camera transform uses -xpos/-ypos. Apply the global
	# camera values with that same KAG sign convention, then retain the visual
	# centre when a camerazoom action changes scale.
	scene_camera_layer.position = center * (1.0 - zoom) + Vector2(-environment_camera_x, -environment_camera_y) * SOURCE_SCALE


func _start_procedural_script_actions(node: Control, actions: Array) -> void:
	_clear_procedural_node_actions(node)
	if replaying_state or not respect_script_waits:
		return
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action_row: Array = action_value
		if action_row.size() < 2:
			continue
		var property_name := str(action_row[0]).to_lower()
		if property_name not in ["xpos", "ypos", "visvalue", "zoomx", "zoomy", "rotate"]:
			continue
		var value: Variant = action_row[1]
		var handler := _script_action_handler(value)
		if handler != "SinAction" and handler != "RandomAction":
			continue
		var directive: Dictionary = Dictionary(Array(value)[0])
		var duration_ms := _script_directive_number(directive, "time", 0.0)
		var amplitude := _script_directive_number(directive, "vibration", 0.0)
		if duration_ms <= 0.0 or is_zero_approx(amplitude):
			continue
		var script_action := {
			"target_type": "node",
			"node": node,
			"property": property_name,
			"handler": handler,
			"base": _procedural_node_base_value(node, property_name),
			"amplitude": amplitude * _procedural_property_scale(property_name),
			"cycle_ms": maxf(_script_directive_number(directive, "cycle", duration_ms * 2.0), 1.0),
			"duration_ms": duration_ms,
			"elapsed_ms": 0.0,
			"next_sample_ms": 0.0,
			"sample_interval_ms": maxf(_script_directive_number(directive, "waittime", _script_directive_number(directive, "waitTime", 20.0)), 1.0),
			"random_offset": 0.0,
		}
		procedural_script_actions.append(script_action)
		active_action_count += 1


func _clear_procedural_node_actions(node: Control) -> void:
	for index in range(procedural_script_actions.size() - 1, -1, -1):
		var action: Dictionary = procedural_script_actions[index]
		if str(action.get("target_type", "")) != "node" or action.get("node") != node:
			continue
		_set_procedural_node_value(node, str(action.get("property", "")), float(action.get("base", 0.0)))
		procedural_script_actions.remove_at(index)
		active_action_count = maxi(0, active_action_count - 1)


func _clear_procedural_script_actions() -> void:
	for action_value in procedural_script_actions:
		var action: Dictionary = action_value
		if str(action.get("target_type", "")) == "camera":
			_set_environment_camera_value(str(action.get("property", "")), float(action.get("base", 0.0)))
		else:
			var node: Control = action.get("node")
			if is_instance_valid(node):
				_set_procedural_node_value(node, str(action.get("property", "")), float(action.get("base", 0.0)))
	procedural_script_actions.clear()
	active_action_count = 0


func _update_procedural_script_actions(delta: float) -> void:
	for index in range(procedural_script_actions.size() - 1, -1, -1):
		var action: Dictionary = procedural_script_actions[index]
		var elapsed_ms := float(action.get("elapsed_ms", 0.0)) + delta * 1000.0
		# Array elements are copied as Dictionaries; persist this action's clock
		# before applying its current frame.
		action["elapsed_ms"] = elapsed_ms
		var duration_ms := float(action.get("duration_ms", 0.0))
		var target_type := str(action.get("target_type", ""))
		var property_name := str(action.get("property", ""))
		if target_type == "node" and not is_instance_valid(action.get("node")):
			procedural_script_actions.remove_at(index)
			active_action_count = maxi(0, active_action_count - 1)
			continue
		if elapsed_ms >= duration_ms:
			_apply_procedural_value(action, float(action.get("base", 0.0)))
			procedural_script_actions.remove_at(index)
			active_action_count = maxi(0, active_action_count - 1)
			continue
		var offset := 0.0
		if str(action.get("handler", "")) == "SinAction":
			offset = sin(TAU * elapsed_ms / float(action.get("cycle_ms", 1.0))) * float(action.get("amplitude", 0.0))
		else:
			var next_sample_ms := float(action.get("next_sample_ms", 0.0))
			if elapsed_ms >= next_sample_ms:
				action["random_offset"] = randf_range(-float(action.get("amplitude", 0.0)), float(action.get("amplitude", 0.0)))
				action["next_sample_ms"] = elapsed_ms + float(action.get("sample_interval_ms", 20.0))
			offset = float(action.get("random_offset", 0.0))
		procedural_script_actions[index] = action
		_apply_procedural_value(action, float(action.get("base", 0.0)) + offset)


func _apply_procedural_value(action: Dictionary, value: float) -> void:
	if str(action.get("target_type", "")) == "camera":
		_set_environment_camera_value(str(action.get("property", "")), value)
		return
	var node: Control = action.get("node")
	if is_instance_valid(node):
		_set_procedural_node_value(node, str(action.get("property", "")), value)


func _procedural_node_base_value(node: Control, property_name: String) -> float:
	match property_name:
		"xpos": return node.position.x
		"ypos": return node.position.y
		"visvalue": return node.modulate.a
		"zoomx": return node.scale.x
		"zoomy": return node.scale.y
		"rotate": return node.rotation_degrees
	return 0.0


func _set_procedural_node_value(node: Control, property_name: String, value: float) -> void:
	match property_name:
		"xpos": node.position.x = value
		"ypos": node.position.y = value
		"visvalue": node.modulate.a = clampf(value, 0.0, 1.0)
		"zoomx": node.scale.x = value
		"zoomy": node.scale.y = value
		"rotate": node.rotation_degrees = value


func _procedural_property_scale(property_name: String) -> float:
	match property_name:
		"xpos", "ypos": return SOURCE_SCALE
		"visvalue", "zoomx", "zoomy": return 0.01
	return 1.0


func _schedule_story_preload() -> void:
	var scenes: Array = scenario.get("scenes", [])
	if scene_index >= scenes.size():
		return
	var scene: Dictionary = scenes[scene_index]
	var lines: Array = scene.get("lines", [])
	var schedule_key := storage + ":" + str(scene_index)
	if preload_schedule_key != schedule_key:
		preload_schedule_key = schedule_key
		preload_scheduled_until = line_index
	var start_line: int = maxi(line_index, preload_scheduled_until)
	var max_line: int = mini(lines.size(), line_index + 80)
	if start_line >= max_line:
		return
	preload_scheduled_until = max_line
	for index in range(start_line, max_line):
		var line: Variant = lines[index]
		if typeof(line) == TYPE_ARRAY:
			var row: Array = line
			if row.size() > 1 and typeof(row[1]) == TYPE_DICTIONARY:
				_collect_state_preload(row[1])
		elif _is_number(line):
			var entry := _text_entry(scene, int(line))
			if not entry.is_empty():
				_collect_state_preload(Dictionary(entry.get("state", {})))
				var voice := str(entry.get("voice", ""))
				if voice != "":
					_queue_audio_preload(["data_hgl", "voice"], voice)
	_preload_next_storage_resources(scene)


func _preload_next_storage_resources(scene: Dictionary) -> void:
	var nexts: Array = scene.get("nexts", [])
	for item in nexts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var next: Dictionary = item
		if int(next.get("type", 0)) != 0:
			continue
		var next_storage := str(next.get("storage", storage)).to_lower()
		if next_storage == storage:
			continue
		var next_target := str(next.get("target", ""))
		_queue_scenario_preload(next_storage, next_target)


func _queue_scenario_preload(storage_name: String, scene_target: String) -> void:
	var key := storage_name.to_lower()
	if scenario_cache.has(key):
		return
	var preload_key := key + ":next:" + scene_target
	if scenario_preload_keys.has(preload_key):
		return
	scenario_preload_keys[preload_key] = true
	_queue_preload_job({"type": "scenario", "storage": key, "target": scene_target})


func _scenario_data(storage_name: String) -> Dictionary:
	var key := storage_name.to_lower()
	if scenario_cache.has(key):
		return scenario_cache[key]
	var parsed := _read_scenario_file(key)
	if not parsed.is_empty():
		scenario_cache[key] = parsed
	return parsed


func _read_scenario_file(storage_name: String) -> Dictionary:
	var key := storage_name.to_lower()
	var path := SCENARIO_ROOT + "/" + key.trim_suffix(".scn") + ".json"
	if not FileAccess.file_exists(path):
		path = SCENARIO_ROOT + "/" + key.replace(".ks", ".ks.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _preload_scenario_window(storage_name: String, scenario_data: Dictionary, scene_target: String, count: int) -> void:
	var scenes: Array = scenario_data.get("scenes", [])
	if scenes.is_empty():
		return
	var preload_key := storage_name + ":window:" + scene_target
	if scenario_preload_keys.has(preload_key):
		return
	scenario_preload_keys[preload_key] = true
	var target_scene_index := 0
	if scene_target != "":
		for index in scenes.size():
			var candidate: Dictionary = scenes[index]
			if str(candidate.get("label", "")).to_lower() == scene_target.to_lower():
				target_scene_index = index
				break
	var scene: Dictionary = scenes[target_scene_index]
	var lines: Array = scene.get("lines", [])
	for index in range(mini(lines.size(), count)):
		var line: Variant = lines[index]
		if typeof(line) == TYPE_ARRAY:
			var row: Array = line
			if row.size() > 1 and typeof(row[1]) == TYPE_DICTIONARY:
				_collect_state_preload(row[1])
		elif _is_number(line):
			var entry := _text_entry(scene, int(line))
			if not entry.is_empty():
				_collect_state_preload(Dictionary(entry.get("state", {})))
				var voice := str(entry.get("voice", ""))
				if voice != "":
					_queue_audio_preload(["data_hgl", "voice"], voice)


func _collect_state_preload(state: Dictionary) -> void:
	var data: Array = state.get("data", [])
	for item_value in data:
		if typeof(item_value) != TYPE_ARRAY:
			continue
		var item: Array = item_value
		if item.size() < 3 or typeof(item[2]) != TYPE_DICTIONARY:
			continue
		var kind := str(item[1])
		var object: Dictionary = item[2]
		match kind:
			"bgm":
				var replay: Dictionary = object.get("replay", {})
				var filename := str(replay.get("filename", ""))
				if filename != "":
					_queue_audio_preload(["bgm"], filename)
			"stage":
				_queue_visual_preload(object, "bgimage")
			"event":
				_queue_visual_preload(object, "evimage")
			"character":
				_queue_character_preload(object)
			"msgwin":
				if str(item[0]) == "face":
					_queue_character_preload(object)


func _queue_visual_preload(object: Dictionary, package: String) -> void:
	if int(object.get("showmode", 3)) == 0:
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name == "":
		return
	var path := _resolve_image(package, image_name)
	if path != "":
		_queue_preload_job({"type": "image", "path": path})


func _queue_audio_preload(packages: Array, name: String) -> void:
	var path := _resolve_audio(packages, name)
	if path != "":
		_queue_preload_job({"type": "audio", "path": path})


func _queue_character_preload(object: Dictionary) -> void:
	if int(object.get("showmode", 3)) == 0:
		return
	var name := str(object.get("name", ""))
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name == "":
		image_name = name
	if image_name.to_lower().ends_with(".stand"):
		_queue_stand_preload(name, image_name, image_file, object)
		return
	var path := _resolve_character_image(name, image_name)
	if path != "":
		_queue_preload_job({"type": "image", "path": path})


func _queue_stand_preload(character_name: String, image_name: String, image_file: Dictionary, object: Dictionary) -> void:
	var options: Dictionary = image_file.get("options", {})
	var entry := _stand_entry(character_name, image_name, options)
	if entry.is_empty():
		return
	var prefix := str(entry.get("filename", ""))
	var sinfo := _stand_sinfo(prefix)
	var dress_name := _normalize_dress_name(str(options.get("dress", "")))
	var face_name := _normalize_face_name(str(options.get("face", "10")))
	var image_variant := _stand_image_variant(_stand_zoom(object))
	var layer_names := _stand_body_layer_names(sinfo, dress_name) + _stand_face_layer_names(sinfo, face_name)
	var pbd_layers := _stand_pbd_layers(character_name, prefix, image_variant)
	_queue_stand_directory_preload(character_name)
	for layer_name_value in layer_names:
		var layer_name := str(layer_name_value)
		var part_info := _stand_pbd_part_info(pbd_layers, layer_name)
		var part_index := int(part_info.get("layer_id", 0))
		if part_index <= 0:
			continue
		var paths := _stand_part_paths(character_name, prefix, image_variant, part_index)
		if paths.is_empty():
			continue
		if _is_ready_file(str(paths["target"])):
			_queue_preload_job({"type": "image", "path": paths["target"]})
		else:
			_queue_preload_job({"type": "tlg", "source": paths["source"], "target": paths["target"], "output_dir": paths["output_dir"]})


func _queue_stand_directory_preload(character_name: String, force: bool = false) -> void:
	if character_name == "":
		return
	var source_dir := RESTORED_ROOT + "/fgimage/" + character_name
	var output_dir := CACHE_ROOT + "/fgimage/" + character_name
	if not force and _stand_cache_is_complete(character_name):
		return
	if _dir_exists_absolute(source_dir):
		if force or FileAccess.file_exists(output_dir + "/.complete"):
			# Re-queue after an earlier attempt that left a partial or stale
			# cache: the marker alone cannot prove the parts exist.
			var key := "tlg_dir:" + source_dir
			preload_mutex.lock()
			preload_enqueued.erase(key)
			preload_mutex.unlock()
		_queue_preload_job({"type": "tlg_dir", "source_dir": source_dir, "output_dir": output_dir})


## A cache directory counts as complete only when its marker exists AND the
## converted part count covers the source directory — a marker written before
## the converter was available must not short-circuit a later, correct run.
func _stand_cache_is_complete(character_name: String) -> bool:
	var output_dir := CACHE_ROOT + "/fgimage/" + character_name
	if not FileAccess.file_exists(output_dir + "/.complete"):
		return false
	var cached := _count_files_with_extension(output_dir, ".png")
	if cached <= 0:
		return false
	var source_abs := _external_path(RESTORED_ROOT + "/fgimage/" + character_name)
	if source_abs == "" or not DirAccess.dir_exists_absolute(source_abs):
		return true
	return cached >= _count_files_with_extension(source_abs, ".tlg")


func _count_files_with_extension(path: String, extension: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if not dir.current_is_dir() and file_name.ends_with(extension):
			count += 1
	dir.list_dir_end()
	return count


## Resolve a project or absolute directory for the *Absolute DirAccess APIs.
func _dir_exists_absolute(path: String) -> bool:
	var resolved := _external_path(path)
	return resolved != "" and DirAccess.dir_exists_absolute(resolved)


func _apply_bgm(object: Dictionary) -> void:
	if bgm_player == null:
		return
	var replay: Dictionary = object.get("replay", {})
	var filename := str(replay.get("filename", ""))
	var state := int(replay.get("state", 0)) if replay.get("state", null) != null else -1
	if filename == "":
		return
	if state == 0:
		bgm_player.stop()
		bgm_current_path = ""
		return
	var path := _resolve_audio(["bgm"], filename)
	if path == "":
		return
	if bgm_current_path == path and bgm_player.playing:
		return
	var stream := _load_ogg(path)
	if stream == null:
		return
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = bool(int(replay.get("loop", 1)))
	bgm_player.stream = stream
	bgm_current_path = path
	bgm_player.volume_db = AudioManager._volume_db(AudioManager.master_volume * AudioManager.bgm_volume)
	bgm_player.play()


func _apply_sound_object(kind: String, object: Dictionary) -> void:
	if kind == "bgm":
		_apply_bgm(object)
		return
	var name := str(object.get("name", ""))
	if name == "":
		return
	# Preserve the declared regular-SE channel when a LoopSE wrapper temporarily
	# writes to it. Later SCN updates omit `class` and must be interpreted as the
	# original channel type after the loop has been stopped.
	if not sound_channel_kinds.has(name):
		sound_channel_kinds[name] = kind
	var replay: Dictionary = object.get("replay", {})
	var filename := str(replay.get("filename", ""))
	var replay_state: Variant = replay.get("state", null)
	var should_stop := bool(object.get("stop", false)) or (replay_state != null and int(replay_state) == 0)
	if should_stop:
		if sound_players.has(name):
			var existing: AudioStreamPlayer = sound_players[name]
			if is_instance_valid(existing):
				existing.stop()
		return
	if filename == "":
		return
	# Scenario SE/loopSE references can resolve from data/sound, while voices
	# live under voice and some system sounds use data_hgl.
	var path := _resolve_audio(["data_hgl", "data", "voice"], filename)
	var stream := _load_ogg(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = sound_players.get(name)
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = "ScriptSound_" + name
		add_child(player)
		sound_players[name] = player
	if player.stream == stream and player.playing:
		return
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = kind == "loopse" or bool(int(replay.get("loop", 0)))
	player.stream = stream
	player.volume_db = AudioManager._volume_db(AudioManager.master_volume * AudioManager.sysse_volume)
	player.play()


func _apply_visual_object(layer: TextureRect, object: Dictionary, package: String) -> void:
	if _script_object_is_hidden(object):
		_clear_visual_transition_overlay(layer)
		layer.visible = false
		visual_layer_paths.erase(layer.name)
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name == "":
		layer.visible = int(object.get("showmode", 3)) != 0 and layer.texture != null
		return
	var path := _resolve_image(package, image_name)
	if visual_layer_paths.get(layer.name, "") == path and layer.visible and layer.texture != null:
		_apply_visual_redraw_effects(layer, image_file, object.get("action", []))
		if layer.has_meta("visual_transition_previous"):
			layer.remove_meta("visual_transition_previous")
		return
	var texture := _load_image(path)
	if texture == null:
		return
	if layer.visible and layer.texture != null:
		layer.set_meta("visual_transition_previous", {
			"material": layer.material,
			"modulate": layer.modulate,
			"pivot_offset": layer.pivot_offset,
			"position": layer.position,
			"scale": layer.scale,
			"size": layer.size,
			"texture": layer.texture,
			"texture_filter": layer.texture_filter,
			"z_index": layer.z_index,
		})
	elif layer.has_meta("visual_transition_previous"):
		layer.remove_meta("visual_transition_previous")
	layer.texture = texture
	_set_visual_layer_geometry(layer, texture, package)
	if package == "bgimage":
		# A stage redraw is a new source canvas. KAG does not inherit the previous
		# background's camera position or zoom when the incoming state only carries
		# zpos. Retaining those values shrank a 2220px school gate image to a strip
		# and exposed the empty canvas on the right.
		_reset_stage_visual_transform(layer)
	_apply_visual_redraw_effects(layer, image_file, object.get("action", []))
	visual_layer_paths[layer.name] = path
	layer.visible = true


func _finish_visual_transition(layer: TextureRect, object: Dictionary) -> void:
	var previous: Variant = null
	if layer.has_meta("visual_transition_previous"):
		previous = layer.get_meta("visual_transition_previous")
		layer.remove_meta("visual_transition_previous")
	var transition: Dictionary = object.get("trans", {})
	var method := str(transition.get("method", "")).to_lower()
	var duration_ms := int(transition.get("time", 0))
	if duration_ms <= 0 or method == "":
		return
	if replaying_state or not respect_script_waits:
		return
	var restore_message_window := _hide_message_for_visual_transition(transition)
	if not (previous is Dictionary):
		_apply_script_fade(layer, object)
		_restore_message_after_visual_transition(duration_ms, restore_message_window)
		return
	var previous_state: Dictionary = previous
	var previous_texture: Texture2D = previous_state.get("texture")
	if previous_texture == null:
		_apply_script_fade(layer, object)
		_restore_message_after_visual_transition(duration_ms, restore_message_window)
		return
	var overlay := _make_transition_overlay(layer, previous_state)
	if overlay == null:
		_apply_script_fade(layer, object)
		_restore_message_after_visual_transition(duration_ms, restore_message_window)
		return
	var tween: Tween = overlay.create_tween()
	var seconds := maxf(float(duration_ms) / 1000.0, 0.01)
	if method == "universal":
		var rule_name := str(transition.get("rule", ""))
		var rule_texture := _load_transition_rule(rule_name)
		if rule_texture != null:
			overlay.material = _make_universal_transition_material(rule_texture, float(transition.get("vague", 64.0)) / 255.0)
			tween.tween_method(func(progress: float) -> void: _set_universal_transition_progress(overlay, progress), 0.0, 1.0, seconds)
		else:
			tween.tween_property(overlay, "modulate:a", 0.0, seconds)
	else:
		tween.tween_property(overlay, "modulate:a", 0.0, seconds)
	tween.finished.connect(_finish_visual_transition_overlay.bind(overlay, restore_message_window), CONNECT_ONE_SHOT)
	_track_script_action(tween)


func _hide_message_for_visual_transition(transition: Dictionary) -> bool:
	var msgoff: Variant = transition.get("msgoff", false)
	var requested := false
	match typeof(msgoff):
		TYPE_BOOL:
			requested = msgoff
		TYPE_INT, TYPE_FLOAT:
			requested = float(msgoff) != 0.0
		_:
			requested = str(msgoff).to_lower() == "true"
	if not requested or window_layer == null or window_hidden or backlog_mode:
		return false
	if not window_layer.visible and active_transition_message_hides == 0:
		return false
	# kagenvtrans exposes msgoff as a transition option. It temporarily removes
	# the message layer while the source/target scene images are composited.
	active_transition_message_hides += 1
	window_layer.visible = false
	return true


func _finish_visual_transition_overlay(overlay: TextureRect, restore_message_window: bool) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	_finish_transition_message_hide(restore_message_window)


func _restore_message_after_visual_transition(duration_ms: int, restore_message_window: bool) -> void:
	if not restore_message_window:
		return
	var timer := create_tween()
	timer.tween_interval(maxf(float(duration_ms) / 1000.0, 0.01))
	timer.tween_callback(func() -> void:
		_finish_transition_message_hide(restore_message_window)
	)
	_track_script_action(timer)


func _finish_transition_message_hide(restore_message_window: bool) -> void:
	if not restore_message_window:
		return
	active_transition_message_hides = maxi(active_transition_message_hides - 1, 0)
	if active_transition_message_hides == 0 and window_layer != null and not window_hidden and not backlog_mode:
		window_layer.visible = true


func _make_transition_overlay(layer: TextureRect, previous: Dictionary) -> TextureRect:
	var parent := layer.get_parent()
	if parent == null:
		return null
	var overlay := TextureRect.new()
	overlay.name = layer.name + "_TransitionPrevious"
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.texture = previous.get("texture")
	overlay.position = previous.get("position", layer.position)
	overlay.size = previous.get("size", layer.size)
	overlay.scale = previous.get("scale", layer.scale)
	overlay.pivot_offset = previous.get("pivot_offset", layer.pivot_offset)
	overlay.modulate = previous.get("modulate", Color.WHITE)
	overlay.z_index = int(previous.get("z_index", layer.z_index))
	overlay.texture_filter = int(previous.get("texture_filter", layer.texture_filter))
	overlay.material = previous.get("material")
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	parent.move_child(overlay, layer.get_index())
	return overlay


func _clear_visual_transition_overlays() -> void:
	active_transition_message_hides = 0
	_clear_visual_transition_overlay(stage_layer)
	_clear_visual_transition_overlay(event_layer)
	for node_value in auxiliary_visual_nodes.values():
		if node_value is TextureRect:
			_clear_visual_transition_overlay(node_value)


func _clear_visual_transition_overlay(layer: TextureRect) -> void:
	if layer == null:
		return
	var parent := layer.get_parent()
	if parent == null:
		return
	var overlay := parent.get_node_or_null(layer.name + "_TransitionPrevious") as TextureRect
	if overlay != null and is_instance_valid(overlay):
		overlay.free()


func _load_transition_rule(rule_name: String) -> Texture2D:
	if rule_name == "":
		return null
	var path := "res://assets/data/rule/%s.png" % rule_name.to_lower()
	var loaded: Variant = load(path)
	return loaded as Texture2D


func _make_universal_transition_material(rule_texture: Texture2D, vague: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
// Kirikiri rule images are compared as raw 8-bit thresholds, not colors.
uniform sampler2D rule_texture : filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float vague = 0.2509804;
void fragment() {
	vec4 previous = texture(TEXTURE, UV);
	float rule = texture(rule_texture, UV).r;
	float edge = clamp(vague, 0.0, 1.0);
	float phase = progress * (1.0 + edge * 2.0) - edge;
	float reveal = smoothstep(rule - edge, rule + edge, phase);
	COLOR = vec4(previous.rgb, previous.a * (1.0 - reveal));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("rule_texture", rule_texture)
	material.set_shader_parameter("vague", clampf(vague, 0.0, 1.0))
	material.set_shader_parameter("progress", 0.0)
	return material


func _set_universal_transition_progress(overlay: TextureRect, progress: float) -> void:
	if not is_instance_valid(overlay):
		return
	var material := overlay.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("progress", progress)


func _apply_visual_redraw_effects(layer: TextureRect, image_file: Dictionary, actions: Array = []) -> void:
	var redraw_commands: Array = image_file.get("redraw", [])
	var raster := _script_raster_settings(actions)
	layer.set_meta("script_raster", raster)
	var material := _make_redraw_effect_material(redraw_commands, raster)
	layer.material = material
	if material != null:
		# The original D3D image operations sample the source texture linearly.
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _script_raster_settings(actions: Array) -> Dictionary:
	var settings := {"amount": 0.0, "cycle_ms": 1000.0, "lines": 100.0}
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action: Array = action_value
		if action.size() < 2:
			continue
		var numeric: Variant = _script_action_number(action[1])
		if numeric == null:
			continue
		match str(action[0]).to_lower():
			"raster": settings["amount"] = float(numeric)
			"rastercycle": settings["cycle_ms"] = maxf(float(numeric), 1.0)
			"rasterlines": settings["lines"] = maxf(float(numeric), 1.0)
	return settings


func _make_redraw_effect_material(redraw_commands: Array, raster: Dictionary = {}) -> ShaderMaterial:
	var blur_radius := Vector2.ZERO
	var blur_passes := 0
	var grayscale := false
	var gamma := Vector3.ONE
	var gamma_black := Vector3.ZERO
	var gamma_white := Vector3.ONE
	var overlay_color := Color.TRANSPARENT
	var overlay_strength := 0.0
	var light_brightness := 0.0
	var light_contrast := 0.0
	var raster_amount := float(raster.get("amount", 0.0))
	var raster_cycle_ms := maxf(float(raster.get("cycle_ms", 1000.0)), 1.0)
	var raster_lines := maxf(float(raster.get("lines", 100.0)), 1.0)
	for command_value in redraw_commands:
		if typeof(command_value) != TYPE_ARRAY:
			continue
		var command: Array = command_value
		if command.is_empty():
			continue
		match str(command[0]):
			"doBoxBlur":
				if command.size() >= 3:
					blur_radius = Vector2(maxf(blur_radius.x, float(command[1])), maxf(blur_radius.y, float(command[2])))
					blur_passes += 1
			"doGrayScale":
				grayscale = true
			"adjustGamma":
				if command.size() >= 10:
					gamma = Vector3(maxf(float(command[1]), 0.001), maxf(float(command[4]), 0.001), maxf(float(command[7]), 0.001))
					gamma_black = Vector3(float(command[2]), float(command[5]), float(command[8])) / 255.0
					gamma_white = Vector3(float(command[3]), float(command[6]), float(command[9])) / 255.0
			"overcolor", "tc_overcolor":
				if command.size() >= 3:
					var packed := int(command[1])
					overlay_color = Color8((packed >> 16) & 0xff, (packed >> 8) & 0xff, packed & 0xff)
					overlay_strength = clampf(float(command[2]) / 100.0, 0.0, 1.0)
			"tc_light":
				if command.size() >= 3:
					light_brightness = float(command[1]) / 255.0
					light_contrast = float(command[2]) / 100.0
	if blur_passes == 0 and not grayscale and gamma == Vector3.ONE and is_zero_approx(overlay_strength) and is_zero_approx(light_brightness) and is_zero_approx(light_contrast) and is_zero_approx(raster_amount):
		return null
	# Two same-radius box blurs form a separable triangular kernel. Sampling
	# that kernel at its full 1/16-radius cadence avoids the visible 6px grid
	# produced by the former sparse Gaussian approximation.
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 blur_radius_px = vec2(0.0);
uniform bool apply_grayscale = false;
uniform vec3 gamma_value = vec3(1.0);
uniform vec3 gamma_black = vec3(0.0);
uniform vec3 gamma_white = vec3(1.0);
uniform vec3 overlay_color = vec3(0.0);
uniform float overlay_strength = 0.0;
uniform float light_brightness = 0.0;
uniform float light_contrast = 0.0;
uniform float raster_amount_px = 0.0;
uniform float raster_cycle_ms = 1000.0;
uniform float raster_lines = 100.0;
void fragment() {
	float raster_band = floor(UV.y * max(raster_lines, 1.0));
	float raster_phase = (TIME * 1000.0 / max(raster_cycle_ms, 1.0)) * 6.28318530718;
	float raster_wave = sin((raster_band / max(raster_lines, 1.0)) * 6.28318530718 + raster_phase);
	vec2 raster_uv = UV + vec2(raster_wave * raster_amount_px * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 sum = vec4(0.0);
	float weight_sum = 0.0;
	for (int y = -16; y <= 16; y++) {
		for (int x = -16; x <= 16; x++) {
			vec2 sample_offset = vec2(float(x), float(y));
			float weight = (1.0 - abs(sample_offset.x) / 17.0) * (1.0 - abs(sample_offset.y) / 17.0);
			vec2 uv_offset = sample_offset * blur_radius_px * TEXTURE_PIXEL_SIZE / 16.0;
		sum += texture(TEXTURE, raster_uv + uv_offset) * weight;
		weight_sum += weight;
	}
}
	vec4 source = sum / weight_sum;
	vec3 rgb = source.rgb;
	if (apply_grayscale) {
		float luminance = dot(rgb, vec3(0.299, 0.587, 0.114));
		rgb = vec3(luminance);
	}
	rgb = clamp((rgb - gamma_black) / max(gamma_white - gamma_black, vec3(0.0001)), 0.0, 1.0);
	rgb = pow(rgb, vec3(1.0) / gamma_value);
	rgb = mix(rgb, overlay_color, overlay_strength);
	rgb = clamp((rgb - 0.5) * (1.0 + light_contrast) + 0.5 + light_brightness, 0.0, 1.0);
	COLOR = vec4(rgb, source.a);
}
"""
	material.shader = shader
	material.set_shader_parameter("blur_radius_px", blur_radius * sqrt(float(blur_passes)))
	material.set_shader_parameter("apply_grayscale", grayscale)
	material.set_shader_parameter("gamma_value", gamma)
	material.set_shader_parameter("gamma_black", gamma_black)
	material.set_shader_parameter("gamma_white", gamma_white)
	material.set_shader_parameter("overlay_color", Vector3(overlay_color.r, overlay_color.g, overlay_color.b))
	material.set_shader_parameter("overlay_strength", overlay_strength)
	material.set_shader_parameter("light_brightness", light_brightness)
	material.set_shader_parameter("light_contrast", light_contrast)
	material.set_shader_parameter("raster_amount_px", raster_amount)
	material.set_shader_parameter("raster_cycle_ms", raster_cycle_ms)
	material.set_shader_parameter("raster_lines", raster_lines)
	return material


func _set_visual_layer_geometry(layer: TextureRect, texture: Texture2D, package: String) -> void:
	# Stage assets are authored at a 1.5x source resolution.  Some are wider
	# than 16:9 to provide camera margins, so stretching them into the viewport
	# changes both the illustration and the original crop.
	if package == "bgimage":
		# This layer is a camera canvas, not a full-rect UI control.  Its anchors
		# must not override the native background size on the following frame.
		layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		layer.size = texture.get_size() * SOURCE_SCALE_VECTOR
		layer.set_meta("stage_native_size", layer.size)
	else:
		_fit_full_rect(layer)
		layer.set_meta("stage_native_size", size)


func _reset_stage_visual_transform(layer: TextureRect) -> void:
	layer.scale = Vector2.ONE
	layer.modulate = Color.WHITE
	layer.z_index = 0
	# Backgrounds wider than the 1920px source canvas carry camera margins on
	# both sides. Centre the untouched source view before a later xpos action
	# requests a different camera origin.
	layer.position = Vector2(
		minf(0.0, (size.x - layer.size.x) * 0.5),
		minf(0.0, (size.y - layer.size.y) * 0.5)
	)
	layer.set_meta("stage_base_position", layer.position)
	layer.set_meta("stage_base_scale", layer.scale)


func _script_object_is_hidden(object: Dictionary) -> bool:
	var showmode: Variant = object.get("showmode", 3)
	return showmode != null and (int(showmode) == 0 or int(showmode) == 2)


func _apply_stage_effect(object: Dictionary) -> void:
	var name := str(object.get("name", "stageeff"))
	if _script_object_is_hidden(object):
		_remove_script_object(name)
		return
	var node := _get_or_create_auxiliary_node(name, stage_effect_layer)
	if node == null:
		return
	# custom.tjs registers fure_l/fure_r/hanabi as ltAdditive. They are a
	# separate, camera-independent stage layer between background and event CG.
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = material
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name != "":
		_configure_stage_effect_animation(name, image_name, node)
		if node.texture == null:
			var path := _resolve_script_image(image_name)
			var texture := _load_image(path)
			if texture != null:
				node.texture = texture
	if node.texture == null:
		return
	node.size = node.texture.get_size() * SOURCE_SCALE_VECTOR
	node.pivot_offset = Vector2.ZERO
	node.visible = true
	_apply_script_transform(node, object, true)
	_apply_script_fade(node, object)


func _apply_emotion_object(object: Dictionary) -> void:
	var name := str(object.get("name", "emotion"))
	if _script_object_is_hidden(object):
		_remove_script_object(name)
		return
	var node := _get_or_create_auxiliary_node(name, script_effect_layer)
	if node == null:
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	var path := _resolve_script_image(image_name)
	var texture := _load_image(path)
	if texture == null:
		return
	node.texture = texture
	node.size = texture.get_size() * SOURCE_SCALE_VECTOR
	node.pivot_offset = node.size * 0.5
	node.visible = true
	node.z_index = 3
	_apply_particle_blend(node, str(object.get("trans", {}).get("type", "")))
	var link_name := str(object.get("link", ""))
	var link_node: Control = character_nodes.get(link_name)
	var x_offset := 0.0
	var y_offset := 0.0
	var zoom_x := 100.0
	var zoom_y := 100.0
	var opacity := 1.0
	var order := 3
	for action_value in object.get("action", []):
		if typeof(action_value) != TYPE_ARRAY or action_value.size() < 2:
			continue
		var action: Array = action_value
		var numeric: Variant = _script_action_number(action[1])
		if numeric == null:
			continue
		match str(action[0]):
			"xpos": x_offset = float(numeric)
			"ypos": y_offset = float(numeric)
			"zoomx": zoom_x = float(numeric)
			"zoomy": zoom_y = float(numeric)
			"visvalue", "opacity": opacity = clampf(float(numeric) / 100.0, 0.0, 1.0)
			"order": order = int(numeric)
	node.z_index = order
	node.scale = Vector2(zoom_x / 100.0, zoom_y / 100.0)
	node.modulate.a = opacity
	var offset := Vector2(x_offset, -y_offset) * SOURCE_SCALE
	if link_node != null and is_instance_valid(link_node):
		node.position = link_node.position + offset
	else:
		node.position = Vector2(size.x * 0.5, size.y * 0.5) + offset - node.size * 0.5
	_apply_script_fade(node, object)


func _apply_particle_object(object: Dictionary) -> void:
	var name := str(object.get("name", "particle"))
	if _script_object_is_hidden(object):
		_remove_script_object(name)
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	var profile_index := _particle_profile_index(image_name)
	if profile_index == 0:
		return
	if auxiliary_visual_nodes.has(name):
		_remove_script_object(name)
	var node: WhiteBallEmitter = particle_emitters.get(name)
	if node == null or not is_instance_valid(node):
		node = WhiteBallEmitterScene.new()
		node.name = "Particle_" + name
		script_effect_layer.add_child(node)
		particle_emitters[name] = node
	var actions: Array = object.get("action", [])
	var opacity := clampf(_script_action_value(actions, "visvalue", 100.0) / 100.0, 0.0, 1.0)
	var zoom := _script_action_value(actions, "zoomx", _script_action_value(actions, "zoomy", 100.0)) / 100.0
	node.position = Vector2.ZERO
	node.scale = Vector2.ONE * zoom
	node.z_index = int(_script_action_value(actions, "zpos", 0.0))
	node.configure(profile_index, name.hash(), opacity)
	_apply_particle_blend(node, str(object.get("trans", {}).get("type", "")))
	node.visible = true


func _particle_profile_index(image_name: String) -> int:
	var suffix := image_name.trim_prefix("particle_white_ball_")
	if not suffix.is_valid_int():
		return 0
	var index := suffix.to_int()
	# The source macro defines three normal layers and five BU layers.  SCN
	# exposes the exact one-based profile through its generated resource name.
	return index if index >= 1 and index <= 5 else 0


func _resolve_particle_image(image_name: String) -> String:
	var direct := _resolve_script_image(image_name)
	if direct != "":
		return direct
	# particle_ball.tjs names its generated entries particle10/30/50. Keep the
	# lookup explicit so a decoded particle source can be dropped in without
	# changing scenario logic; never substitute an unrelated ordinary image.
	var index := image_name.trim_prefix("particle_white_ball_")
	var source_name: String = str({"1": "particle10", "2": "particle30", "3": "particle50"}.get(index, ""))
	if source_name == "":
		return ""
	for root_path in [RESTORED_ROOT, AppConfig.STRUCTURED_ROOT]:
		var source: String = str(root_path) + "/data/image/" + source_name + ".tlg"
		if FileAccess.file_exists(source):
			return _convert_tlg_to_png(source)
	return ""


func _apply_particle_blend(node: CanvasItem, blend_type: String) -> void:
	var normalized := blend_type.to_lower()
	if normalized == "" or normalized == "ltadditive":
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if normalized == "ltadditive" else CanvasItemMaterial.BLEND_MODE_MIX
		node.material = material
		return
	if normalized != "ltpsoverlay" and normalized != "ltpshardlight":
		return
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 background = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 result;
	if (BLEND_KIND < 0.5) {
		result = 2.0 * background.rgb * source.rgb;
	} else {
		result = mix(2.0 * background.rgb * source.rgb, 1.0 - 2.0 * (1.0 - background.rgb) * (1.0 - source.rgb), step(vec3(0.5), background.rgb));
	}
	COLOR = vec4(result, source.a) * COLOR;
}
""".replace("BLEND_KIND", "0.0" if normalized == "ltpshardlight" else "1.0")
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material


func _script_action_value(actions: Array, property_name: String, fallback: float) -> float:
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY or action_value.size() < 2:
			continue
		if str(action_value[0]) == property_name:
			var numeric: Variant = _script_action_number(action_value[1])
			if numeric != null:
				return float(numeric)
	return fallback


func _get_or_create_auxiliary_node(name: String, parent: Control) -> TextureRect:
	var node: TextureRect = auxiliary_visual_nodes.get(name)
	if node != null and is_instance_valid(node):
		if node.get_parent() != parent:
			node.reparent(parent)
		return node
	node = TextureRect.new()
	node.name = "ScriptVisual_" + name
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	parent.add_child(node)
	auxiliary_visual_nodes[name] = node
	return node


func _configure_stage_effect_animation(name: String, image_name: String, node: TextureRect) -> void:
	var existing: Dictionary = stage_effect_animations.get(name, {})
	if str(existing.get("image_name", "")) == image_name:
		return
	var descriptor := _stage_effect_animation_descriptor(image_name)
	if descriptor.is_empty():
		stage_effect_animations.erase(name)
		return
	descriptor["image_name"] = image_name
	descriptor["elapsed_ms"] = 0.0
	descriptor["frame_index"] = 0
	stage_effect_animations[name] = descriptor
	_apply_stage_effect_animation_frame(name, node)


func _stage_effect_animation_descriptor(image_name: String) -> Dictionary:
	var source_dir := ""
	for root_path in [RESTORED_ROOT, AppConfig.STRUCTURED_ROOT, ProjectSettings.globalize_path("res://assets")]:
		var candidate_dir := str(root_path) + "/video/" + image_name
		var asd_path := candidate_dir + "/" + image_name + "_.asd"
		if DirAccess.dir_exists_absolute(candidate_dir) and FileAccess.file_exists(asd_path):
			source_dir = candidate_dir
			break
	if source_dir == "":
		return {}
	var bytes := FileAccess.get_file_as_bytes(source_dir + "/" + image_name + "_.asd")
	var text := bytes.get_string_from_utf16()
	var frames: Array[Dictionary] = []
	var storage := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("@load"):
			storage = _script_attribute(line, "storage")
		elif line.begins_with("@wait") and storage != "":
			frames.append({"storage": storage, "duration_ms": maxf(1.0, float(_script_attribute(line, "time").to_float()))})
			storage = ""
	if frames.is_empty():
		return {}
	var output_dir := CACHE_ROOT + "/video/" + source_dir.get_file()
	var first_source := source_dir + "/" + str(frames[0].get("storage", "")) + ".tlg"
	if FileAccess.file_exists(first_source) and not FileAccess.file_exists(output_dir + "/.complete"):
		_queue_preload_job({"type": "tlg_dir", "source_dir": source_dir, "output_dir": output_dir})
	return {"source_dir": source_dir, "output_dir": output_dir, "frames": frames}


func _script_attribute(line: String, attribute: String) -> String:
	var prefix := attribute + "="
	var offset := line.find(prefix)
	if offset < 0:
		return ""
	var value := line.substr(offset + prefix.length()).strip_edges()
	return value.split(" ", false)[0].trim_prefix("\"").trim_suffix("\"")


func _update_stage_effect_animations(delta: float) -> void:
	if stage_effect_animations.is_empty():
		return
	for name_value in stage_effect_animations.keys():
		var name := str(name_value)
		var node: TextureRect = auxiliary_visual_nodes.get(name)
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var descriptor: Dictionary = stage_effect_animations.get(name, {})
		var frames: Array = descriptor.get("frames", [])
		if frames.is_empty():
			continue
		descriptor["elapsed_ms"] = float(descriptor.get("elapsed_ms", 0.0)) + delta * 1000.0
		var frame_index := int(descriptor.get("frame_index", 0))
		while float(descriptor["elapsed_ms"]) >= float(Dictionary(frames[frame_index]).get("duration_ms", 1.0)):
			descriptor["elapsed_ms"] = float(descriptor["elapsed_ms"]) - float(Dictionary(frames[frame_index]).get("duration_ms", 1.0))
			frame_index = (frame_index + 1) % frames.size()
			descriptor["frame_index"] = frame_index
		stage_effect_animations[name] = descriptor
		_apply_stage_effect_animation_frame(name, node)


func _apply_stage_effect_animation_frame(name: String, node: TextureRect) -> void:
	var descriptor: Dictionary = stage_effect_animations.get(name, {})
	var frames: Array = descriptor.get("frames", [])
	if frames.is_empty():
		return
	var frame_index := clampi(int(descriptor.get("frame_index", 0)), 0, frames.size() - 1)
	var storage := str(Dictionary(frames[frame_index]).get("storage", ""))
	var source_dir := str(descriptor.get("source_dir", ""))
	var output_dir := str(descriptor.get("output_dir", ""))
	var png_path := source_dir + "/" + storage + ".png"
	if not _is_ready_file(png_path):
		png_path = output_dir + "/" + storage + ".png"
	if not _is_ready_file(png_path):
		return
	var texture := _load_image(png_path)
	if texture == null:
		return
	node.texture = texture
	node.size = texture.get_size() * SOURCE_SCALE_VECTOR


func _apply_auxiliary_visual(kind: String, object: Dictionary) -> void:
	var name := str(object.get("name", kind))
	if name == "":
		return
	if _script_object_is_hidden(object):
		_remove_script_object(name)
		return
	# showdate.tjs creates the blackboard as a `slayer`, but it is a full
	# source-canvas background rather than an ordinary positioned effect. Its
	# original `kokuban.png` is 1920x1080 and must occupy the complete 1280x720
	# output canvas. Applying the generic slayer origin would move it offscreen.
	if kind == "slayer" and name == "black_bord":
		_apply_blackboard_visual(object)
		return
	var node := _get_or_create_auxiliary_node(name, script_effect_layer)
	# KAG environment effects are independent source-canvas layers.  They
	# are not 1280x720 containers: the image's native 1920-canvas size and
	# xpos/ypos actions define their layout.
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	var previous: Variant = null
	if image_name != "":
		var path := _resolve_script_image(image_name)
		var texture := _load_image(path)
		if texture != null:
			# The date card's source is a white alpha mask. Capture a previous
			# card only for a real source replacement, never for an identical state
			# replay, otherwise its transition restarts and turns the chalk grey.
			if kind == "day_full" and node.visible and node.texture != null and auxiliary_visual_paths.get(name, "") != path:
				previous = _capture_visual_transition_state(node)
			node.texture = texture
			auxiliary_visual_paths[name] = path
	if node.texture == null:
		return
	# Restore the PIMG/source-canvas relation before applying script motion.
	# The previous full-rect holder enlarged small nameplate assets to the
	# viewport and caused them to cover the entire scene.
	node.size = node.texture.get_size() * SOURCE_SCALE_VECTOR
	node.pivot_offset = Vector2.ZERO
	node.visible = true
	if kind == "day_full":
		# Date textures are authored in straight white RGB plus alpha. A retained
		# redraw material or RGB tint would alter the original blackboard colours.
		node.material = null
		node.modulate = Color(1.0, 1.0, 1.0, node.modulate.a)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var stage_origin := SLAYER_STAGE_ORIGIN_SOURCE * SOURCE_SCALE_VECTOR if kind == "slayer" else Vector2.ZERO
	_apply_script_transform(node, object, true, false, stage_origin)
	if kind == "day_full":
		_finish_day_full_transition(node, object, previous)
	else:
		_apply_script_fade(node, object)


func _apply_blackboard_visual(object: Dictionary) -> void:
	var node := _get_or_create_auxiliary_node("black_bord", script_effect_layer)
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name != "":
		var path := _resolve_script_image(image_name)
		var texture := _load_image(path)
		if texture != null:
			node.texture = texture
			auxiliary_visual_paths["black_bord"] = path
	if node.texture == null:
		return
	node.material = null
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.size = node.texture.get_size() * SOURCE_SCALE_VECTOR
	node.position = Vector2.ZERO
	node.pivot_offset = Vector2.ZERO
	node.scale = Vector2.ONE
	node.modulate = Color.WHITE
	node.z_index = 0
	node.visible = true
	_apply_script_fade(node, object)


func _capture_visual_transition_state(node: TextureRect) -> Dictionary:
	return {
		"material": node.material,
		"modulate": node.modulate,
		"pivot_offset": node.pivot_offset,
		"position": node.position,
		"scale": node.scale,
		"size": node.size,
		"texture": node.texture,
		"texture_filter": node.texture_filter,
		"z_index": node.z_index,
	}


func _finish_day_full_transition(node: TextureRect, object: Dictionary, previous: Variant) -> void:
	var transition: Dictionary = object.get("trans", {})
	var method := str(transition.get("method", "")).to_lower()
	var duration_ms := int(transition.get("time", 0))
	if duration_ms <= 0 or method == "" or replaying_state or not respect_script_waits:
		node.material = null
		return
	if previous is Dictionary:
		node.set_meta("visual_transition_previous", previous)
		_finish_visual_transition(node, object)
		return
	if method != "universal":
		_apply_script_fade(node, object)
		return
	var rule_texture := _load_transition_rule(str(transition.get("rule", "")))
	if rule_texture == null:
		_apply_script_fade(node, object)
		return
	var material := _make_universal_reveal_material(rule_texture, float(transition.get("vague", 64.0)) / 255.0)
	node.material = material
	var tween := node.create_tween()
	var seconds := maxf(float(duration_ms) / 1000.0, 0.01)
	tween.tween_method(func(progress: float) -> void:
		if is_instance_valid(node) and node.material == material:
			material.set_shader_parameter("progress", progress)
	, 0.0, 1.0, seconds)
	tween.finished.connect(func() -> void:
		if is_instance_valid(node) and node.material == material:
			node.material = null
	, CONNECT_ONE_SHOT)
	_track_script_action(tween)


func _make_universal_reveal_material(rule_texture: Texture2D, vague: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D rule_texture : filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float vague = 0.2509804;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float rule = texture(rule_texture, UV).r;
	float edge = clamp(vague, 0.0, 1.0);
	float phase = progress * (1.0 + edge * 2.0) - edge;
	float reveal = smoothstep(rule - edge, rule + edge, phase);
	COLOR = vec4(source.rgb, source.a * reveal) * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("rule_texture", rule_texture)
	material.set_shader_parameter("vague", clampf(vague, 0.0, 1.0))
	material.set_shader_parameter("progress", 0.0)
	return material


func _resolve_script_image(name: String) -> String:
	var candidates := _name_candidates(name, "png")
	for root in [RESTORED_ROOT, AppConfig.STRUCTURED_ROOT]:
		# Script effects live under data/image.  Resolve that exact original
		# package before broad archive fallbacks, whose extracted filenames can
		# collide with an unrelated package's reconstructed name.
		for package in ["data", "data_hgl", "bgimage", "evimage", "fgimage"]:
			for candidate_value in candidates:
				var candidate := str(candidate_value)
				for relative_dir in ["image/effect", "image/date_full", "image", ""]:
					var direct: String = str(root) + "/" + str(package)
					if relative_dir != "":
						direct += "/" + relative_dir
					direct += "/" + candidate
					if FileAccess.file_exists(direct):
						return direct
	# Stage effects are stored as TLG animation frames under the video package.
	for root in [RESTORED_ROOT, AppConfig.STRUCTURED_ROOT]:
		var video_dir: String = str(root) + "/video/" + name
		var first_frame: String = video_dir + "/" + name + "_000.tlg"
		if FileAccess.file_exists(first_frame):
			return _convert_tlg_to_png(first_frame)
	return ResourceIndex.resolve_first(["data", "data_hgl", "bgimage", "evimage", "fgimage"], candidates)


func _remove_script_object(name: String) -> void:
	if name == "stage":
		stage_layer.visible = false
		return
	if name == "ev":
		event_layer.visible = false
		return
	if name == "face":
		_clear_message_face()
		return
	if character_nodes.has(name):
		_remove_character(name)
	if auxiliary_visual_nodes.has(name):
		var node: Control = auxiliary_visual_nodes[name]
		auxiliary_visual_nodes.erase(name)
		auxiliary_visual_paths.erase(name)
		if is_instance_valid(node):
			_clear_procedural_node_actions(node)
			if node is TextureRect:
				_clear_visual_transition_overlay(node)
			node.queue_free()
	if particle_emitters.has(name):
		var emitter: WhiteBallEmitter = particle_emitters[name]
		particle_emitters.erase(name)
		if is_instance_valid(emitter):
			emitter.queue_free()
	stage_effect_animations.erase(name)
	if sound_players.has(name):
		var player: AudioStreamPlayer = sound_players[name]
		sound_players.erase(name)
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	sound_channel_kinds.erase(name)


func _rename_script_object(from_name: String, to_name: String) -> void:
	if from_name == to_name or from_name == "" or to_name == "":
		return
	if auxiliary_visual_nodes.has(from_name):
		var node: TextureRect = auxiliary_visual_nodes[from_name]
		auxiliary_visual_nodes.erase(from_name)
		auxiliary_visual_nodes[to_name] = node
	if particle_emitters.has(from_name):
		var emitter: WhiteBallEmitter = particle_emitters[from_name]
		particle_emitters.erase(from_name)
		particle_emitters[to_name] = emitter
		emitter.name = "Particle_" + to_name
	if character_nodes.has(from_name):
		var character: Control = character_nodes[from_name]
		character_nodes.erase(from_name)
		character_nodes[to_name] = character
		character.name = "Character_" + to_name
	if sound_players.has(from_name):
		var player: AudioStreamPlayer = sound_players[from_name]
		sound_players.erase(from_name)
		sound_players[to_name] = player
	if sound_channel_kinds.has(from_name):
		var sound_kind: Variant = sound_channel_kinds[from_name]
		sound_channel_kinds.erase(from_name)
		sound_channel_kinds[to_name] = sound_kind


func _apply_stage_transform(layer: TextureRect, object: Dictionary) -> void:
	# JSON state records are complete render states, not incremental camera
	# commands. In particular, the school-gate narration repeatedly supplies the
	# same redraw with only zpos. Start from that image's own source-canvas base
	# every time so a previous zoom cannot leak through the same-path fast path.
	var base_position: Vector2 = layer.get_meta("stage_base_position", layer.position)
	var base_scale: Vector2 = layer.get_meta("stage_base_scale", Vector2.ONE)
	var x_offset := -base_position.x
	var y_offset := -base_position.y
	var zoom_x := base_scale.x * 100.0
	var zoom_y := base_scale.y * 100.0
	var opacity := layer.modulate.a
	var order := layer.z_index
	for action_value in object.get("action", []):
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action: Array = action_value
		if action.size() < 2:
			continue
		var numeric: Variant = _script_action_number(action[1])
		if numeric == null:
			continue
		match str(action[0]):
			"xpos":
				x_offset = float(numeric) * SOURCE_SCALE
			"ypos":
				y_offset = float(numeric) * SOURCE_SCALE
			"zoomx":
				zoom_x = float(numeric)
			"zoomy":
				zoom_y = float(numeric)
			"visvalue":
				opacity = clampf(float(numeric) / 100.0, 0.0, 1.0)
			"opacity":
				opacity = clampf(float(numeric) / 255.0, 0.0, 1.0)
			"order":
				order = int(numeric)
	layer.z_index = order
	layer.modulate.a = opacity
	var target_scale := Vector2(zoom_x / 100.0, zoom_y / 100.0)
	layer.scale = target_scale
	# stage has cameraMode=true in the original KAGEnvironment.  Its xpos/ypos
	# actions represent the camera origin in 1920px source coordinates.
	layer.position = _bounded_stage_position(layer, Vector2(-x_offset, -y_offset), target_scale)
	_start_procedural_script_actions(layer, object.get("action", []))


func _apply_script_transform(node: Control, object: Dictionary, include_position: bool, camera_position: bool = false, position_origin: Vector2 = Vector2.ZERO) -> void:
	var actions: Array = object.get("action", [])
	var x_offset := (node.position.x - position_origin.x) / SOURCE_SCALE
	var y_offset := (node.position.y - position_origin.y) / SOURCE_SCALE
	if camera_position:
		x_offset = -node.position.x / SOURCE_SCALE
		y_offset = -node.position.y / SOURCE_SCALE
	var base_scale: Vector2 = node.get_meta("script_base_scale", Vector2.ONE)
	var zoom_x := node.scale.x / maxf(base_scale.x, 0.0001) * 100.0
	var zoom_y := node.scale.y / maxf(base_scale.y, 0.0001) * 100.0
	var opacity := node.modulate.a
	var order := node.z_index
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action: Array = action_value
		if action.size() < 2:
			continue
		var property_name := str(action[0])
		var value: Variant = action[1]
		var numeric: Variant = _script_action_number(value)
		if numeric == null:
			continue
		match property_name:
			"xpos":
				x_offset = float(numeric) * SOURCE_SCALE
			"ypos":
				y_offset = float(numeric) * SOURCE_SCALE
			"zoomx":
				zoom_x = float(numeric)
			"zoomy":
				zoom_y = float(numeric)
			"visvalue":
				opacity = clampf(float(numeric) / 100.0, 0.0, 1.0)
			"opacity":
				opacity = clampf(float(numeric) / 255.0, 0.0, 1.0)
			"order":
				order = int(numeric)
	node.z_index = order
	node.modulate.a = opacity
	if include_position:
		if camera_position:
			node.position = _bounded_stage_position(node, Vector2(-x_offset, -y_offset), Vector2(zoom_x / 100.0, zoom_y / 100.0))
		else:
			node.position = Vector2(x_offset, y_offset) + position_origin
		node.scale = Vector2(zoom_x / 100.0, zoom_y / 100.0)
	else:
		node.scale = Vector2(base_scale.x * zoom_x / 100.0, base_scale.y * zoom_y / 100.0)
	_apply_script_motion(node, actions, include_position, camera_position, position_origin)
	_start_procedural_script_actions(node, actions)


func _bounded_stage_position(node: Control, requested: Vector2, target_scale: Vector2) -> Vector2:
	var view_size := size
	var scaled_size := node.size * target_scale
	return Vector2(
		clampf(requested.x, minf(view_size.x - scaled_size.x, 0.0), 0.0),
		clampf(requested.y, minf(view_size.y - scaled_size.y, 0.0), 0.0)
	)


func _apply_script_motion(node: Control, actions: Array, include_position: bool, camera_position: bool = false, position_origin: Vector2 = Vector2.ZERO) -> void:
	for action_value in actions:
		if typeof(action_value) != TYPE_ARRAY:
			continue
		var action: Array = action_value
		if action.size() < 2 or typeof(action[1]) != TYPE_ARRAY:
			continue
		var directives: Array = action[1]
		var property_name := str(action[0]).to_lower()
		if property_name not in ["xpos", "ypos", "visvalue", "opacity", "zoomx", "zoomy"]:
			continue
		# Character static placement is resolved by StandLayer first. Its animated
		# xpos/ypos directives are offsets from that resolved position, whereas
		# stage/event directives are source-canvas coordinates.
		var action_origin := position_origin if include_position else node.position
		var planned_value := _script_motion_source_value(node, property_name, include_position, camera_position, action_origin)
		var relative_base := planned_value
		var tween: Tween = null
		var pending_wait := 0.0
		for directive_value in directives:
			if typeof(directive_value) != TYPE_DICTIONARY:
				continue
			var directive: Dictionary = directive_value
			var handler := str(directive.get("handler", ""))
			var seconds := maxf(_script_directive_number(directive, "time", 0.0) / 1000.0, 0.0)
			if handler == "wait":
				if seconds > 0.0:
					if tween == null:
						pending_wait += seconds
					else:
						tween.tween_interval(seconds)
				continue
			if handler != "MoveAction":
				continue
			var target: Variant = _resolve_script_motion_value(directive.get("value", null), planned_value, relative_base)
			if target == null:
				continue
			var start: Variant = _resolve_script_motion_value(directive.get("start", null), planned_value, relative_base)
			var start_value := planned_value if start == null else float(start)
			planned_value = float(target)
			if replaying_state or not respect_script_waits:
				_apply_script_motion_value(node, property_name, planned_value, include_position, camera_position, action_origin)
				continue
			if tween == null:
				tween = node.create_tween()
				tween.set_trans(Tween.TRANS_SINE)
				tween.set_ease(Tween.EASE_IN_OUT)
				if pending_wait > 0.0:
					tween.tween_interval(pending_wait)
			tween.tween_method(func(value: float) -> void: _apply_script_motion_value(node, property_name, value, include_position, camera_position, action_origin), start_value, planned_value, maxf(seconds, 0.01))
		if tween != null:
			_track_script_action(tween)


func _resolve_script_motion_value(value: Variant, base_value: float, relative_base: float = NAN) -> Variant:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	if typeof(value) != TYPE_STRING:
		return null
	var raw := str(value).strip_edges()
	if not raw.begins_with("@"):
		return null
	var delta := raw.trim_prefix("@").to_float()
	return (base_value if is_nan(relative_base) else relative_base) + delta


func _script_motion_source_value(node: Control, property_name: String, include_position: bool, camera_position: bool, position_origin: Vector2) -> float:
	match property_name:
		"visvalue": return node.modulate.a * 100.0
		"opacity": return node.modulate.a * 255.0
		"xpos":
			return -node.position.x / SOURCE_SCALE if camera_position else (node.position.x - position_origin.x) / SOURCE_SCALE
		"ypos":
			return -node.position.y / SOURCE_SCALE if camera_position else (node.position.y - position_origin.y) / SOURCE_SCALE
		"zoomx":
			return node.scale.x / maxf(_script_motion_base_scale(node).x, 0.0001) * 100.0
		"zoomy":
			return node.scale.y / maxf(_script_motion_base_scale(node).y, 0.0001) * 100.0
	return 0.0


func _script_motion_base_scale(node: Control) -> Vector2:
	var base_scale: Variant = node.get_meta("script_base_scale", Vector2.ONE)
	return base_scale if base_scale is Vector2 else Vector2.ONE


func _apply_script_motion_value(node: Control, property_name: String, target: float, include_position: bool, camera_position: bool, position_origin: Vector2) -> void:
	match property_name:
		"visvalue":
			node.modulate.a = clampf(target / 100.0, 0.0, 1.0)
		"opacity":
			node.modulate.a = clampf(target / 255.0, 0.0, 1.0)
		"xpos":
			var position_x := target * SOURCE_SCALE + position_origin.x
			node.position.x = _bounded_stage_position(node, Vector2(-position_x, node.position.y), node.scale).x if camera_position else position_x
		"ypos":
			var position_y := target * SOURCE_SCALE + position_origin.y
			node.position.y = _bounded_stage_position(node, Vector2(node.position.x, -position_y), node.scale).y if camera_position else position_y
		"zoomx":
			node.scale.x = _script_motion_base_scale(node).x * target / 100.0
		"zoomy":
			node.scale.y = _script_motion_base_scale(node).y * target / 100.0


func _apply_script_motion_final(node: Control, property_name: String, target: float, include_position: bool, camera_position: bool, position_origin: Vector2) -> void:
	_apply_script_motion_value(node, property_name, target, include_position, camera_position, position_origin)


func _script_action_number(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	if typeof(value) != TYPE_ARRAY:
		return null
	var entries: Array = value
	if entries.is_empty() or typeof(entries[0]) != TYPE_DICTIONARY:
		return null
	var action: Dictionary = entries[0]
	var target: Variant = action.get("value", null)
	if typeof(target) == TYPE_INT or typeof(target) == TYPE_FLOAT:
		return float(target)
	return null


func _apply_script_fade(node: Control, object: Dictionary) -> void:
	var transition: Dictionary = object.get("trans", {})
	var method := str(transition.get("method", ""))
	var duration_ms := int(transition.get("time", 0))
	if duration_ms <= 0 or method == "":
		return
	var target_alpha := node.modulate.a
	if replaying_state or not respect_script_waits:
		node.modulate.a = target_alpha
		return
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, float(duration_ms) / 1000.0)
	_track_script_action(tween)


func _track_script_action(tween: Tween) -> void:
	active_action_count += 1
	script_action_tweens.append(tween)
	tween.finished.connect(_on_script_action_finished.bind(tween), CONNECT_ONE_SHOT)


func _on_script_action_finished(tween: Tween) -> void:
	script_action_tweens.erase(tween)
	active_action_count = maxi(0, active_action_count - 1)


func _cancel_script_action_tweens() -> void:
	for tween in script_action_tweens:
		if is_instance_valid(tween):
			tween.kill()
	script_action_tweens.clear()
	active_action_count = 0


func _apply_character_object(object: Dictionary) -> void:
	var name := str(object.get("name", ""))
	if _script_object_is_hidden(object):
		if name == "":
			_clear_characters()
		else:
			_remove_character(name)
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name == "":
		image_name = name
	var visual_key := _character_visual_key(image_name, image_file, object)
	if character_nodes.has(name) and character_visual_keys.get(name, "") == visual_key:
		return
	var node := _make_stand_character(name, image_name, image_file, object)
	if node == null:
		if image_name.to_lower().ends_with(".stand"):
			return
		var path := _resolve_character_image(name, image_name)
		if path == "":
			return
		node = _make_character_sprite(name, path)
	if node == null:
		return
	_remove_character(name)
	character_layer.add_child(node)
	character_nodes[name] = node
	character_image_files[name] = image_file
	character_visual_keys[name] = visual_key
	_apply_character_redraw_effects(node, image_file)
	_apply_script_transform(node, object, false)


func _apply_character_redraw_effects(node: Control, image_file: Dictionary) -> void:
	var material := _make_redraw_effect_material(image_file.get("redraw", []))
	_apply_material_to_character_parts(node, material)


func _apply_material_to_character_parts(node: Node, material: ShaderMaterial) -> void:
	if node is TextureRect:
		var texture_node := node as TextureRect
		texture_node.material = material
		if material != null:
			texture_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for child in node.get_children():
		_apply_material_to_character_parts(child, material)


func _clear_characters() -> void:
	character_nodes.clear()
	character_image_files.clear()
	character_visual_keys.clear()
	for child in character_layer.get_children():
		# Script state can replace several stands in a single advance. Freeing
		# synchronously prevents an obsolete PBD page from surviving one rendered
		# frame as an opaque rectangle while the next composition is attached.
		child.free()


func _remove_character(character_name: String) -> void:
	if not character_nodes.has(character_name):
		return
	var node: Node = character_nodes[character_name]
	character_nodes.erase(character_name)
	character_image_files.erase(character_name)
	character_visual_keys.erase(character_name)
	if is_instance_valid(node):
		if node is Control:
			_clear_procedural_node_actions(node)
		node.free()


func _character_visual_key(image_name: String, image_file: Dictionary, object: Dictionary) -> String:
	return image_name + "|" + JSON.stringify(image_file) + "|" + JSON.stringify(object.get("action", []))


func _make_character_sprite(character_name: String, path: String) -> Control:
	var texture := _load_image(path)
	if texture == null:
		return null
	var sprite := TextureRect.new()
	sprite.name = "Character_" + character_name
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fit_full_rect(sprite)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


func _make_stand_character(character_name: String, image_name: String, image_file: Dictionary, object: Dictionary) -> Control:
	if not image_name.to_lower().ends_with(".stand"):
		return null
	var options: Dictionary = image_file.get("options", {})
	var entry := _stand_entry(character_name, image_name, options)
	if entry.is_empty():
		return null
	var prefix := str(entry.get("filename", ""))
	var sinfo := _stand_sinfo(prefix)
	var dress_name := _normalize_dress_name(str(options.get("dress", "")))
	var face_name := _normalize_face_name(str(options.get("face", "10")))
	var zoom := _stand_zoom(object)
	var image_variant := _stand_image_variant(zoom)
	var body_layers := _stand_layer_pngs(character_name, prefix, image_variant, _stand_body_layer_names(sinfo, dress_name))
	var face_layers := _stand_layer_pngs(character_name, prefix, image_variant, _stand_face_layer_names(sinfo, face_name))
	if body_layers.is_empty():
		return null
	var pbd_size := _stand_pbd_canvas_size(character_name, prefix, image_variant)
	if pbd_size == Vector2.ZERO:
		var first_body: Dictionary = body_layers[0]
		var first_texture := _load_image(str(first_body.get("path", "")))
		if first_texture == null:
			return null
		pbd_size = first_texture.get_size()

	var holder := Control.new()
	holder.name = "Character_" + character_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = pbd_size
	for layer_value in body_layers + face_layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue
		var layer: Dictionary = layer_value
		var path := str(layer.get("path", ""))
		if path == "":
			continue
		var texture := _load_image(path)
		if texture != null:
			holder.add_child(_make_part_rect(texture, Vector2(float(layer.get("left", 0.0)), float(layer.get("top", 0.0)))))

	if holder.get_child_count() == 0:
		return null
	_position_character_holder(holder, pbd_size, entry, image_variant, zoom, object)
	holder.set_meta("script_base_scale", holder.scale)
	return holder


func _make_part_rect(texture: Texture2D, part_position: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = part_position
	rect.size = texture.get_size()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _position_character_holder(holder: Control, image_size: Vector2, entry: Dictionary, image_variant: int, zoom: float, object: Dictionary) -> void:
	var viewport_size := get_viewport_rect().size
	# StandLayer applies the inverse of its internal PSD scale.  Its scene is
	# authored on the original 1920px-wide virtual canvas, so its final transform
	# must then pass through the same 1920 -> 1280 conversion as the PIMG UI.
	var x_offset := 0.0
	var y_offset := 0.0
	var z_pos := 0.0
	var has_z_pos := false
	for action in object.get("action", []):
		if typeof(action) != TYPE_ARRAY or action.size() < 2:
			continue
		var numeric: Variant = _script_action_number(action[1])
		if numeric == null:
			continue
		match str(action[0]):
			"xpos":
				x_offset = float(numeric)
			"ypos":
				y_offset = float(numeric)
			"zpos":
				z_pos = float(numeric)
				has_z_pos = true
	if not has_z_pos:
		z_pos = _character_position_zpos(str(object.get("posName", "")))
	var perspective_scale := _kag_z_resolution(z_pos)
	var scale_value := _stand_screen_scale(image_variant, zoom) * SOURCE_SCALE * perspective_scale
	holder.scale = Vector2(scale_value, scale_value)
	# custom.tjs centres the PSD page before applying `baseInfo.xoffset` and
	# `baseInfo.yoffset`.  The PBD root is that page.  `leveloffset` belongs to
	# the engine's z-order level selection, not the static stand transform, and
	# must not be substituted with a fixed level here.
	var base_position := (viewport_size - image_size * scale_value) * 0.5
	# PBD's root includes the export-only transparent bottom margin.  The source
	# renderer centres the PSD page (`pageHeight`), which begins 139 final pixels
	# lower than that root on this 1280x720 output canvas.
	# The PBD root's transparent page margin is inside the character layer and
	# therefore receives the same zresolution as the rest of the stand.
	base_position.y += STAND_PSD_PAGE_VERTICAL_OFFSET * perspective_scale
	holder.position = Vector2(
		base_position.x + (x_offset + float(entry.get("xoffset", 0.0))) * SOURCE_SCALE * perspective_scale,
		base_position.y + (y_offset + float(entry.get("yoffset", 0.0)) * _stand_screen_scale(image_variant, zoom)) * SOURCE_SCALE * perspective_scale
	)


func _kag_z_resolution(z_pos: float) -> float:
	# Original KAG: calcZorderFromZpos(z) = -cameraoffsetz /
	# (z + -cameraoffsetz) * 100; zresolution is zorder / 100 for characters.
	var camera_distance := -KAG_CAMERA_OFFSET_Z
	var denominator := z_pos + camera_distance
	if is_zero_approx(denominator):
		return 1.0
	return camera_distance / denominator


func _character_position_zpos(position_name: String) -> float:
	# main/envinit.tjs: named size presets set zorder. KAG converts it back to
	# zpos before rendering; retain that behavior when a JSON command has no
	# explicit zpos action.
	var zorder_by_name := {
		"35%": 50.0,
		"50%": 75.0,
		"75%": 100.0,
		"100%": 133.0,
		"120%": 150.0,
		"140%": 200.0,
	}
	if not zorder_by_name.has(position_name):
		return 0.0
	var zorder: float = zorder_by_name[position_name]
	return KAG_CAMERA_OFFSET_Z / (zorder / 100.0) - KAG_CAMERA_OFFSET_Z


func _apply_message_face_object(object: Dictionary) -> void:
	if int(object.get("showmode", 3)) == 0:
		_clear_message_face()
		return
	var redraw: Dictionary = object.get("redraw", {})
	var image_file: Dictionary = redraw.get("imageFile", {})
	var image_name := str(image_file.get("file", ""))
	if image_name == "":
		return
	var character_name := image_name.trim_suffix(".stand")
	var key := character_name + "|" + _character_visual_key(image_name, image_file, object)
	if message_face_key == key and message_face_node != null and is_instance_valid(message_face_node):
		return
	var node := _make_stand_character(character_name, image_name, image_file, object)
	if node == null:
		return
	_clear_message_face()
	node.name = "MessageFace_" + character_name
	_place_message_face(node)
	message_face_layer.add_child(node)
	message_face_node = node
	message_face_key = key


func _clear_message_face() -> void:
	if message_face_node != null and is_instance_valid(message_face_node):
		message_face_node.queue_free()
	message_face_node = null
	message_face_key = ""


func _place_message_face(node: Control) -> void:
	# `msgwin` uses originx=-480 / originy=400 and facemask clipping.  PBD _3
	# files are 2x source assets, hence the half-size composition below.
	node.scale = Vector2(0.25, 0.25)
	node.position = Vector2(-320, -440)


func _resolve_image(package: String, name: String) -> String:
	var cache_key := package + ":" + name
	if image_resolve_cache.has(cache_key):
		return image_resolve_cache[cache_key]
	var candidates := _name_candidates(name, "png")
	var packages := _image_package_candidates(package)
	for image_package_value in packages:
		var image_package := str(image_package_value)
		for root in [RESTORED_ROOT, AppConfig.STRUCTURED_ROOT]:
			for candidate_value in candidates:
				var candidate := str(candidate_value)
				var restored: String = str(root) + "/" + image_package + "/" + candidate
				if FileAccess.file_exists(restored):
					image_resolve_cache[cache_key] = restored
					return restored
	var path := ResourceIndex.resolve_first(packages, candidates)
	if path != "" and path.to_lower().ends_with(".png"):
		image_resolve_cache[cache_key] = path
		return path
	image_resolve_cache[cache_key] = ""
	return ""


func _image_package_candidates(package: String) -> Array[String]:
	# The original scenario distinguishes stage/event objects, but shared still
	# illustrations (for example blue_sky) live in the bgimage XP3 archive.
	if package == "evimage":
		return ["evimage", "bgimage"]
	if package == "bgimage":
		return ["bgimage", "evimage"]
	return [package]


func _resolve_character_image(character_name: String, image_name: String) -> String:
	var cache_key := character_name + ":" + image_name
	if character_image_resolve_cache.has(cache_key):
		return character_image_resolve_cache[cache_key]
	var candidates := _name_candidates(image_name, "png")
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		var path: String = RESTORED_ROOT + "/fgimage/" + character_name + "/" + candidate
		if FileAccess.file_exists(path):
			character_image_resolve_cache[cache_key] = path
			return path
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		var path: String = RESTORED_ROOT + "/fgimage/" + candidate
		if FileAccess.file_exists(path):
			character_image_resolve_cache[cache_key] = path
			return path
	var indexed := ResourceIndex.resolve_first(["fgimage", "data_hgl"], candidates)
	if indexed != "" and indexed.to_lower().ends_with(".png"):
		character_image_resolve_cache[cache_key] = indexed
		return indexed
	character_image_resolve_cache[cache_key] = ""
	return ""


func _stand_entry(character_name: String, image_name: String, options: Dictionary) -> Dictionary:
	var stand_path := RESTORED_ROOT + "/fgimage/" + image_name
	if not FileAccess.file_exists(stand_path):
		stand_path = RESTORED_ROOT + "/fgimage/" + character_name + ".stand"
	if not FileAccess.file_exists(stand_path):
		return {}
	var text := _read_utf16_text(stand_path)
	var chunks := text.split("],%[")
	var entries: Array[Dictionary] = []
	for chunk in chunks:
		var filename := _regex_string(chunk, "\"filename\"=>\"([^\"]+)\"")
		if filename == "":
			continue
		entries.append({
			"filename": filename,
			"facexoff": _regex_float(chunk, "\"facexoff\"=>(-?\\d+)"),
			"faceyoff": _regex_float(chunk, "\"faceyoff\"=>(-?\\d+)"),
			"xoffset": _regex_float(chunk, "\"xoffset\"=>(-?\\d+)"),
			"yoffset": _regex_float(chunk, "\"yoffset\"=>(-?\\d+)"),
			"leveloffset": _parse_level_offsets(chunk),
		})
	if entries.is_empty():
		return {}
	var pose := str(options.get("pose", "1"))
	if (pose == "3" or pose == "4") and entries.size() > 1:
		return entries[1]
	return entries[0]


func _parse_level_offsets(chunk: String) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var marker := "\"leveloffset\"=>[["
	var start := chunk.find(marker)
	if start < 0:
		return offsets
	start += marker.length()
	var end := chunk.find("]]", start)
	if end < 0:
		return offsets
	var payload := chunk.substr(start, end - start)
	for pair_text in payload.split("],["):
		var parts := pair_text.split(",")
		if parts.size() < 2:
			continue
		offsets.append(Vector2(float(parts[0]), float(parts[1])))
	return offsets


func _stand_level_offset(entry: Dictionary, level: int) -> Vector2:
	var offsets: Array = entry.get("leveloffset", [])
	if offsets.is_empty():
		return Vector2.ZERO
	var index: int = clampi(level, 0, offsets.size() - 1)
	return offsets[index]


func _stand_zoom(object: Dictionary) -> float:
	var zoom := 1.0
	for action in object.get("action", []):
		if typeof(action) != TYPE_ARRAY or action.size() < 2:
			continue
		var name := str(action[0])
		if name == "zoomx" or name == "zoomy":
			zoom = float(action[1]) / 100.0
	return zoom


func _stand_image_variant(zoom: float) -> int:
	return 1 if zoom <= 0.75 else 3


func _stand_screen_scale(image_variant: int, zoom: float) -> float:
	var selected_zoom := 2.0
	var image_zoom := 1.4
	if zoom <= 0.50:
		selected_zoom = 0.50
		image_zoom = 0.35
	elif zoom <= 0.75:
		selected_zoom = 0.75
		image_zoom = 0.50
	elif zoom <= 1.00:
		selected_zoom = 1.00
		image_zoom = 0.75
	elif zoom <= 1.33:
		selected_zoom = 1.33
		image_zoom = 1.00
	elif zoom <= 1.50:
		selected_zoom = 1.50
		image_zoom = 1.20
	# main/imagemulti.txt declares the _3 assets as 100% and the _1 assets as
	# 50%.  `iz /= image.scale` in the original StandLayer uses those declared
	# factors, not the pixel-dimension ratio between PBD files.
	var image_declared_scale := 0.50 if image_variant == 1 else 1.00
	return (image_zoom / image_declared_scale) / selected_zoom


func _stand_sinfo(prefix: String) -> Dictionary:
	if prefix == "":
		return {}
	if stand_sinfo_cache.has(prefix):
		return stand_sinfo_cache[prefix]
	var path := RESTORED_ROOT + "/fgimage/sinfo/" + prefix + ".sinfo"
	if not FileAccess.file_exists(path):
		stand_sinfo_cache[prefix] = {}
		return {}
	var result := {
		"dress": {},
		"face": {},
	}
	var text := _read_utf16_text(path)
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split("\t", false)
		if parts.size() < 4:
			continue
		var kind := str(parts[0])
		if kind == "dress" and parts.size() >= 5:
			var dress_name := _normalize_dress_name(str(parts[1]))
			var layer_name := str(parts[4])
			if not result["dress"].has(dress_name):
				result["dress"][dress_name] = []
			result["dress"][dress_name].append(layer_name)
		elif kind == "face":
			var face_name := _normalize_face_name(str(parts[1]))
			var layer_name := str(parts[3])
			if not result["face"].has(face_name):
				result["face"][face_name] = []
			result["face"][face_name].append(layer_name)
	stand_sinfo_cache[prefix] = result
	return result


func _stand_body_layer_names(sinfo: Dictionary, dress_name: String) -> Array:
	var dress_map: Dictionary = sinfo.get("dress", {})
	if dress_name != "" and dress_map.has(dress_name):
		return dress_map[dress_name]
	if dress_map.has("制服春"):
		return dress_map["制服春"]
	if not dress_map.is_empty():
		return dress_map[dress_map.keys()[0]]
	return []


func _stand_face_layer_names(sinfo: Dictionary, face_name: String) -> Array:
	var face_map: Dictionary = sinfo.get("face", {})
	if face_map.has(face_name):
		return face_map[face_name]
	if face_map.has("01"):
		return face_map["01"]
	if not face_map.is_empty():
		return face_map[face_map.keys()[0]]
	return []


func _stand_layer_pngs(character_name: String, prefix: String, dress_index: int, layer_names: Array) -> Array:
	var layers: Array = []
	if layer_names.is_empty():
		return layers
	var pbd_layers := _stand_pbd_layers(character_name, prefix, dress_index)
	for layer_name_value in layer_names:
		var layer_name := str(layer_name_value)
		var part_info := _stand_pbd_part_info(pbd_layers, layer_name)
		var part_index := int(part_info.get("layer_id", 0))
		if part_index <= 0:
			continue
		var path := _stand_part_png(character_name, prefix, dress_index, part_index)
		if path != "":
			part_info["path"] = path
			layers.append(part_info)
	return layers


func _stand_pbd_canvas_size(character_name: String, prefix: String, dress_index: int) -> Vector2:
	var pbd_layers := _stand_pbd_layers(character_name, prefix, dress_index)
	if pbd_layers.is_empty() or typeof(pbd_layers[0]) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var root: Dictionary = pbd_layers[0]
	if not root.has("width") or not root.has("height"):
		return Vector2.ZERO
	return Vector2(float(root["width"]), float(root["height"]))


func _stand_pbd_layers(character_name: String, prefix: String, dress_index: int) -> Array:
	var key := character_name + "/" + prefix + "/" + str(dress_index)
	if stand_pbd_cache.has(key):
		return stand_pbd_cache[key]
	var paths := [
		STAND_PBD_JSON_ROOT + "/" + character_name + "/" + prefix + "_" + str(dress_index) + ".json",
		STAND_PBD_JSON_ROOT + "/" + prefix + "_" + str(dress_index) + ".json",
		RESTORED_ROOT + "/fgimage/" + character_name + "/" + prefix + "_" + str(dress_index) + ".pbd.json",
		RESTORED_ROOT + "/fgimage/" + character_name + "/" + prefix + "_" + str(dress_index) + ".json",
	]
	for path_value in paths:
		var path := str(path_value)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			stand_pbd_cache[key] = parsed
			return parsed
		if typeof(parsed) == TYPE_DICTIONARY:
			for candidate_key in ["layers", "items", "children"]:
				if parsed.has(candidate_key) and typeof(parsed[candidate_key]) == TYPE_ARRAY:
					stand_pbd_cache[key] = parsed[candidate_key]
					return parsed[candidate_key]
	stand_pbd_cache[key] = []
	return []


func _stand_pbd_part_info(layers: Array, layer_name: String) -> Dictionary:
	for index in range(layers.size()):
		var item = layers[index]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var candidate_name := ""
		for name_key in ["name", "layer_name", "layerName", "Name"]:
			if item.has(name_key):
				candidate_name = str(item[name_key])
				break
		if candidate_name != layer_name:
			continue
		var result := {
			"left": float(item.get("left", 0.0)),
			"top": float(item.get("top", 0.0)),
			"width": float(item.get("width", 0.0)),
			"height": float(item.get("height", 0.0)),
			"name": candidate_name,
		}
		for id_key in ["layer_id", "layerId", "id", "Id", "index", "Index"]:
			if item.has(id_key):
				result["layer_id"] = int(item[id_key])
				return result
		result["layer_id"] = index + 1
		return result
	return {}


func _stand_part_png(character_name: String, prefix: String, dress_index: int, part_index: int) -> String:
	var paths := _stand_part_paths(character_name, prefix, dress_index, part_index)
	if paths.is_empty():
		return ""
	return _convert_tlg_to_png(str(paths["source"]))


func _stand_part_paths(character_name: String, prefix: String, dress_index: int, part_index: int) -> Dictionary:
	if prefix == "":
		return {}
	var character_dir := RESTORED_ROOT + "/fgimage/" + character_name
	var stem := prefix + "_" + str(dress_index) + "_" + str(part_index)
	var source := character_dir + "/" + stem + ".tlg"
	if not FileAccess.file_exists(source) and dress_index != 1:
		source = character_dir + "/" + prefix + "_1_" + str(part_index) + ".tlg"
	if not FileAccess.file_exists(source):
		return {}
	var output_dir := CACHE_ROOT + "/fgimage/" + source.get_base_dir().get_file()
	var target := output_dir + "/" + source.get_file().get_basename() + ".png"
	return {"source": source, "output_dir": output_dir, "target": target}


func _external_path(path: String) -> String:
	# The preload worker shells out to the TLG converter, which needs a real
	# filesystem path. Project resources arrive as res:// URIs after the
	# assets root moved into the project, so resolve them here.
	if path == "":
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _tlg2png_path() -> String:
	# Each developer keeps their own converter: the historical Windows exe in
	# the Codex workspace, or the built native binary from tools/tlg2png.
	var native := ProjectSettings.globalize_path(TLG2PNG_NATIVE)
	if OS.get_name() != "Windows" and FileAccess.file_exists(native):
		return native
	if FileAccess.file_exists(TLG2PNG_WIN):
		return TLG2PNG_WIN
	return ""


func _convert_tlg_to_png(source: String) -> String:
	var output_dir := CACHE_ROOT + "/fgimage/" + source.get_base_dir().get_file()
	var target := output_dir + "/" + source.get_file().get_basename() + ".png"
	if _is_ready_file(target):
		return target
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	var converter := _tlg2png_path()
	if converter == "":
		# Encrypted (TJS/4s0) and converter-less environments resolve here;
		# stand parts degrade to a missing layer instead of aborting playback.
		return ""
	DirAccess.make_dir_recursive_absolute(output_dir)
	_queue_preload_job({"type": "tlg", "source": source, "target": target, "output_dir": output_dir})
	return ""


func _is_ready_file(path: String, min_size: int = 1024) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var length := file.get_length()
	return length >= min_size


func _start_preload_thread() -> void:
	if preload_running:
		return
	preload_running = true
	preload_thread.start(_preload_worker)


func _stop_preload_thread() -> void:
	if not preload_running:
		return
	preload_mutex.lock()
	preload_running = false
	preload_mutex.unlock()
	preload_semaphore.post()
	if preload_thread.is_started():
		preload_thread.wait_to_finish()


func _queue_preload_job(job: Dictionary) -> void:
	var job_type := str(job.get("type", ""))
	var identity := ""
	match job_type:
		"scenario":
			identity = str(job.get("storage", ""))
		"tlg_dir":
			identity = str(job.get("source_dir", ""))
		_:
			identity = str(job.get("target", job.get("path", job.get("source", ""))))
	var key := job_type + ":" + identity
	if key == ":":
		return
	preload_mutex.lock()
	if not preload_enqueued.has(key):
		preload_enqueued[key] = true
		preload_jobs.append(job)
		preload_semaphore.post()
	preload_mutex.unlock()


func _preload_worker() -> void:
	while true:
		preload_semaphore.wait()
		preload_mutex.lock()
		if not preload_running:
			preload_mutex.unlock()
			return
		var job: Dictionary = {}
		if not preload_jobs.is_empty():
			job = preload_jobs.pop_front()
		preload_mutex.unlock()
		if job.is_empty():
			continue
		_process_preload_job(job)


func _process_preload_job(job: Dictionary) -> void:
	var job_type := str(job.get("type", ""))
	match job_type:
		"scenario":
			var storage_name := str(job.get("storage", "")).to_lower()
			var target := str(job.get("target", ""))
			var parsed := _read_scenario_file(storage_name)
			if not parsed.is_empty():
				preload_mutex.lock()
				preloaded_scenarios[storage_name] = {"data": parsed, "target": target}
				preload_mutex.unlock()
		"tlg_dir":
			var source_dir := str(job.get("source_dir", ""))
			var output_dir := str(job.get("output_dir", ""))
			var converter := _tlg2png_path()
			var source_abs := _external_path(source_dir)
			var output_abs := _external_path(output_dir)
			if source_abs != "" and output_abs != "" \
					and DirAccess.dir_exists_absolute(source_abs) and converter != "":
				DirAccess.make_dir_recursive_absolute(output_abs)
				OS.execute(converter, [source_abs, output_abs], [])
				var marker := FileAccess.open(output_abs + "/.complete", FileAccess.WRITE)
				if marker != null:
					marker.store_string(Time.get_datetime_string_from_system())
		"tlg":
			var source := str(job.get("source", ""))
			var target := str(job.get("target", ""))
			var output_dir := str(job.get("output_dir", ""))
			if target == "":
				return
			if _is_ready_file(target):
				_queue_preload_job({"type": "image", "path": target})
				return
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(target)
			var tlg_converter := _tlg2png_path()
			# OS.execute and *Absolute APIs need real filesystem paths: the job
			# carries res:// URIs after the assets-root migration.
			var tlg_source := _external_path(source)
			var tlg_output := _external_path(output_dir)
			if tlg_source != "" and tlg_output != "" and tlg_converter != "":
				DirAccess.make_dir_recursive_absolute(tlg_output)
				OS.execute(tlg_converter, [tlg_source, tlg_output], [])
			if _is_ready_file(target):
				_queue_preload_job({"type": "image", "path": target})
		"image":
			var path := str(job.get("path", ""))
			if path == "":
				return
			preload_mutex.lock()
			var already_loaded := preloaded_images.has(path)
			preload_mutex.unlock()
			if already_loaded:
				return
			if path.begins_with("res://"):
				# Loose Image.load() cannot reach packed resources once the PCK
				# is embedded, so imported project images are read through the
				# resource system instead. The marker suffix lets the drain pass
				# distinguish raw Image payloads from ready textures.
				var packed := ResourceLoader.load(path) as Texture2D
				if packed == null:
					return
				preload_mutex.lock()
				if not preloaded_images.has(path):
					preloaded_images[path] = packed
				preload_mutex.unlock()
				return
			var image := Image.new()
			if image.load(path) == OK:
				preload_mutex.lock()
				preloaded_images[path] = image
				preload_mutex.unlock()
		"audio":
			var path := str(job.get("path", ""))
			if path == "":
				return
			preload_mutex.lock()
			var already_streamed := preloaded_streams.has(path)
			preload_mutex.unlock()
			if already_streamed:
				return
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream != null:
				preload_mutex.lock()
				preloaded_streams[path] = stream
				preload_mutex.unlock()


func _drain_preloaded_assets() -> void:
	preload_mutex.lock()
	var images: Dictionary = {}
	var image_keys := preloaded_images.keys()
	var image_count: int = mini(PRELOAD_TEXTURES_PER_FRAME, image_keys.size())
	for index in range(image_count):
		var path = image_keys[index]
		images[path] = preloaded_images[path]
		preloaded_images.erase(path)
	var streams := preloaded_streams
	var scenarios := preloaded_scenarios
	preloaded_streams = {}
	preloaded_scenarios = {}
	preload_mutex.unlock()
	for path in images.keys():
		if texture_cache.has(path):
			continue
		var payload: Variant = images[path]
		if payload is Texture2D:
			# Packed res:// resources arrive as ready textures from the worker.
			texture_cache[path] = payload
		else:
			texture_cache[path] = ImageTexture.create_from_image(payload)
	for path in streams.keys():
		if not stream_cache.has(path):
			stream_cache[path] = streams[path]
	for key in scenarios.keys():
		if not scenario_cache.has(key):
			var wrapper: Dictionary = scenarios[key]
			var scenario_data: Dictionary = wrapper.get("data", {})
			scenario_cache[key] = scenario_data
			_preload_scenario_window(str(key), scenario_data, str(wrapper.get("target", "")), 100)


func _normalize_dress_name(dress_name: String) -> String:
	var normalized := dress_name.strip_edges()
	if STAND_DRESS_MOJIBAKE.has(normalized):
		return STAND_DRESS_MOJIBAKE[normalized]
	return normalized


func _normalize_face_name(face_name: String) -> String:
	var text := face_name.strip_edges()
	if text == "":
		return "10"
	if text.is_valid_int():
		return "%02d" % int(text)
	return text


func _regex_string(text: String, pattern: String) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return ""
	var result := regex.search(text)
	if result == null:
		return ""
	return result.get_string(1)


func _regex_float(text: String, pattern: String) -> float:
	var value := _regex_string(text, pattern)
	if value == "":
		return 0.0
	return float(value)


func _read_utf16_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() >= 2 and bytes[0] == 0xff and bytes[1] == 0xfe:
		bytes = bytes.slice(2)
	return bytes.get_string_from_utf16()


func _resolve_audio(packages: Array, name: String) -> String:
	var cache_key := ",".join(PackedStringArray(packages)) + ":" + name
	if audio_resolve_cache.has(cache_key):
		return audio_resolve_cache[cache_key]
	var candidates := _name_candidates(name, "ogg")
	for package in packages:
		for candidate_value in candidates:
			var candidate := str(candidate_value)
			var restored: String = RESTORED_ROOT + "/" + str(package) + "/" + candidate
			if FileAccess.file_exists(restored):
				audio_resolve_cache[cache_key] = restored
				return restored
	var path := ResourceIndex.resolve_first(packages, candidates)
	if path != "":
		audio_resolve_cache[cache_key] = path
		return path
	audio_resolve_cache[cache_key] = ""
	return ""


func _play_voice(name: String) -> void:
	if voice_player == null:
		return
	last_voice_name = name
	var path := _resolve_audio(["data_hgl", "voice"], name)
	var stream := _load_ogg(path)
	if stream == null:
		return
	voice_player.stream = stream
	voice_player.volume_db = AudioManager._volume_db(AudioManager.master_volume * AudioManager.voice_volume)
	voice_player.play()


func _name_candidates(name: String, extension: String) -> Array:
	var normalized := name.replace("\\", "/").get_file()
	var candidates: Array[String] = [normalized]
	if not normalized.to_lower().ends_with("." + extension):
		candidates.append(normalized + "." + extension)
	return candidates


func _load_image(path: String) -> Texture2D:
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	# Project-local images are packed and imported by Godot. Image.load() only
	# accepts a loose filesystem path, which produced a misleadingly successful
	# editor run but fails once the PCK is embedded in the release executable.
	if path.begins_with("res://"):
		var imported := ResourceLoader.load(path) as Texture2D
		if imported == null:
			push_warning("Failed to load packed story image: " + path)
			return null
		texture_cache[path] = imported
		return imported
	preload_mutex.lock()
	var preloaded = preloaded_images.get(path)
	if preloaded != null:
		preloaded_images.erase(path)
	preload_mutex.unlock()
	if preloaded != null:
		var texture := ImageTexture.create_from_image(preloaded)
		texture_cache[path] = texture
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("Failed to load story image: " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture


func _apply_sysmovie(properties: Dictionary) -> void:
	var requested := str(properties.get("storage", properties.get("file", ""))).strip_edges()
	if requested == "" or str(properties.get("state", "")).to_lower() == "end":
		_finish_movie(false)
		return
	var stream_path := _resolve_movie_stream(requested)
	if stream_path == "":
		push_warning("No converted OGV movie found for scenario storage: " + requested)
		return
	var stream := ResourceLoader.load(stream_path) as VideoStream
	if stream == null:
		push_warning("Failed to load scenario movie stream: " + stream_path)
		return
	current_movie_storage = requested
	movie_can_skip = str(properties.get("canskip", "false")).to_lower() == "true"
	movie_overlay.color = _movie_background_color(properties.get("color", "0x000000"))
	movie_player.stream = stream
	movie_overlay.visible = true
	movie_playing = true
	movie_player.play()


func _resolve_movie_stream(storage_name: String) -> String:
	var normalized := storage_name.replace("\\", "/").get_file()
	var base := normalized.get_basename()
	var candidates: Array[String] = [base + ".ogv"]
	if normalized.to_lower().ends_with(".ogv"):
		candidates.append(normalized)
	for candidate in candidates:
		var path := "res://assets/video/" + candidate
		if ResourceLoader.exists(path):
			return path
	return ""


func _movie_background_color(value: Variant) -> Color:
	var raw := str(value).strip_edges().to_lower()
	if raw.begins_with("0x"):
		raw = raw.trim_prefix("0x")
	if raw.length() == 6 and raw.is_valid_hex_number():
		return Color.html("#" + raw)
	return Color.BLACK


func _on_movie_finished() -> void:
	_finish_movie()


func _finish_movie(continue_script: bool = true) -> void:
	if movie_player != null:
		movie_player.stop()
		movie_player.stream = null
	if movie_overlay != null:
		movie_overlay.visible = false
	var was_playing := movie_playing
	movie_playing = false
	movie_can_skip = false
	if was_playing and continue_script and not replaying_state:
		call_deferred("_continue_until_text")


func _load_ogg(path: String) -> AudioStream:
	if path == "":
		return null
	if stream_cache.has(path):
		return stream_cache[path]
	preload_mutex.lock()
	var preloaded = preloaded_streams.get(path)
	if preloaded != null:
		preloaded_streams.erase(path)
	preload_mutex.unlock()
	if preloaded != null:
		stream_cache[path] = preloaded
		return preloaded
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("Failed to load story ogg: " + path)
		return null
	stream_cache[path] = stream
	return stream


func _show_error(message: String) -> void:
	name_label.text = ""
	text_label.text = message


func export_save_state() -> Dictionary:
	return {
		"v": 2,
		"storage": storage,
		"target": target,
		"scene_index": scene_index,
		"line_index": line_index,
		"history_entries": history_entries.duplicate(true),
		"pending_texts": pending_texts.duplicate(true),
		"current_entry": current_entry.duplicate(true),
		"name": name_label.text,
		"text": text_label.text,
		"last_voice": last_voice_name,
		"window_hidden": window_hidden,
		"message_window_mode": message_window_mode,
		"current_chapter": current_chapter,
		"current_scnchart": current_scnchart,
		"quickmenu_visible": quickmenu_layer != null and quickmenu_layer.visible,
		"branch_flags": branch_flags.to_dict(),
		"selection_history": selection_history.duplicate(true),
		"last_branch_decision": last_branch_decision.duplicate(true),
		"pending_selects": _pending_selects.duplicate(true) if selection_pending else [],
		"pending_select_info": _pending_select_info.duplicate(true) if selection_pending else {},
	}


func export_trace_frame() -> Dictionary:
	# A JSON-safe scene snapshot for regression comparison. The original SCN
	# cursor is preserved alongside the Godot layer state, so visual differences
	# can be tied back to one exact script command rather than a loose screenshot.
	var characters: Dictionary = {}
	var character_names: Array = character_nodes.keys()
	character_names.sort()
	for character_name_value in character_names:
		var character_name := str(character_name_value)
		var node := character_nodes.get(character_name) as Control
		if node == null or not is_instance_valid(node):
			continue
		characters[character_name] = {
			"image_file": character_image_files.get(character_name, {}),
			"visual_key": str(character_visual_keys.get(character_name, "")),
			"node": _trace_control(node),
			"parts": node.get_child_count(),
		}
	var effects: Dictionary = {}
	var effect_names: Array = auxiliary_visual_nodes.keys()
	effect_names.sort()
	for effect_name_value in effect_names:
		var effect_name := str(effect_name_value)
		var effect := auxiliary_visual_nodes.get(effect_name) as Control
		if effect != null and is_instance_valid(effect):
			effects[effect_name] = _trace_control(effect)
	var active_sounds: Array[String] = []
	var sound_names: Array = sound_players.keys()
	sound_names.sort()
	for sound_name_value in sound_names:
		var sound_name := str(sound_name_value)
		var sound_player := sound_players.get(sound_name) as AudioStreamPlayer
		if sound_player != null and is_instance_valid(sound_player) and sound_player.playing:
			active_sounds.append(sound_name)
	return {
		"cursor": {
			"storage": storage,
			"target": target,
			"scene_index": scene_index,
			"line_index": line_index,
		},
		"entry": {
			"name": str(current_entry.get("name", "")),
			"text": str(current_entry.get("text", "")),
			"voice": str(current_entry.get("voice", "")),
		},
		"script_state": {
			"window_hidden": window_hidden,
			"message_window_mode": message_window_mode,
			"current_chapter": current_chapter,
			"current_scnchart": current_scnchart,
			"quickmenu_visible": quickmenu_layer != null and quickmenu_layer.visible,
		},
		"layers": {
			"stage": _trace_control(stage_layer, str(visual_layer_paths.get(stage_layer.name, ""))),
			"event": _trace_control(event_layer, str(visual_layer_paths.get(event_layer.name, ""))),
			"message_face": _trace_control(message_face_node),
			"message_window": _trace_control(window_layer),
			"characters": characters,
			"effects": effects,
		},
		"audio": {
			"bgm_path": bgm_current_path,
			"bgm_playing": bgm_player != null and bgm_player.playing,
			"voice": last_voice_name,
			"voice_playing": voice_player != null and voice_player.playing,
			"active_sounds": active_sounds,
		},
		"branch": {
			"branch_flags": branch_flags.to_dict(),
			"selection_pending": selection_pending,
			"pending_count": _pending_selects.size(),
			"last_selection": last_selection_event,
			"last_decision": last_branch_decision,
			"game_ended": game_ended,
		},
	}


func _trace_control(node: Control, source_path: String = "") -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {"present": false}
	var rect := node.get_global_rect()
	var result := {
		"present": true,
		"visible": node.visible,
		"position": [snappedf(node.position.x, 0.001), snappedf(node.position.y, 0.001)],
		"size": [snappedf(node.size.x, 0.001), snappedf(node.size.y, 0.001)],
		"scale": [snappedf(node.scale.x, 0.001), snappedf(node.scale.y, 0.001)],
		"global_rect": [snappedf(rect.position.x, 0.001), snappedf(rect.position.y, 0.001), snappedf(rect.size.x, 0.001), snappedf(rect.size.y, 0.001)],
		"z_index": node.z_index,
		"opacity": snappedf(node.modulate.a, 0.001),
	}
	if source_path != "":
		result["source_path"] = source_path
	return result


func import_save_state(state: Dictionary) -> void:
	storage = str(state.get("storage", ENTRY_STORAGE)).to_lower()
	target = str(state.get("target", ""))
	if not _load_scenario(storage):
		_show_error("Scenario not found: " + storage)
		return
	_clear_runtime_story_state()
	var saved_scene := int(state.get("scene_index", 0))
	var saved_line := int(state.get("line_index", 0))
	history_entries = Array(state.get("history_entries", [])).duplicate(true)
	_replay_until(saved_scene, saved_line)
	scene_index = saved_scene
	line_index = saved_line
	pending_texts = Array(state.get("pending_texts", [])).duplicate(true)
	current_entry = Dictionary(state.get("current_entry", {})).duplicate(true)
	if not current_entry.is_empty():
		_show_text(current_entry)
	else:
		name_label.text = str(state.get("name", ""))
		text_label.text = str(state.get("text", ""))
	last_voice_name = str(state.get("last_voice", last_voice_name))
	_set_message_window_mode(str(state.get("message_window_mode", message_window_mode)))
	current_chapter = str(state.get("current_chapter", current_chapter))
	current_scnchart = str(state.get("current_scnchart", current_scnchart))
	if quickmenu_layer != null:
		quickmenu_layer.visible = bool(state.get("quickmenu_visible", quickmenu_layer.visible))
	_set_window_hidden(bool(state.get("window_hidden", window_hidden)))
	branch_flags.from_dict(Dictionary(state.get("branch_flags", {})))
	selection_history = Array(state.get("selection_history", [])).duplicate(true)
	last_branch_decision = Dictionary(state.get("last_branch_decision", {})).duplicate(true)
	var pending_selects: Array = Array(state.get("pending_selects", [])).duplicate(true)
	if not pending_selects.is_empty():
		_pending_selects = pending_selects
		_pending_select_info = Dictionary(state.get("pending_select_info", {})).duplicate(true)
		selection_pending = true
		_present_selection_ui()
	else:
		selection_pending = false


func _present_selection_ui() -> void:
	_close_select_screen()
	var screen: Control = SelectScreen.new()
	var background_name := str(Dictionary(_pending_select_info.get("_init", {})).get("bg", ""))
	screen.setup(_pending_selects, _pending_select_info, _resolve_map_background_path(background_name))
	screen.selected.connect(_on_select_chosen)
	screen.z_index = 1500
	screen.z_as_relative = false
	screen.name = "SelectScreen"
	add_child(screen)
	_select_screen = screen
	action_requested.emit("select_show")


func jump_to_history_entry(history_entry: Dictionary, history_index: int = -1) -> bool:
	var jump_state: Dictionary = Dictionary(history_entry.get("state", {}))
	if jump_state.is_empty():
		return false
	var preserved_history := history_entries.duplicate(true)
	if history_index >= 0 and history_index < preserved_history.size():
		# The original HistoryTextStore follows the selected record.  Entries
		# after the selected point are future text and must not reappear when the
		# backlog is opened again after a jump.
		preserved_history = preserved_history.slice(0, history_index + 1)
	storage = str(jump_state.get("storage", ENTRY_STORAGE)).to_lower()
	target = str(jump_state.get("target", ""))
	if not _load_scenario(storage):
		_show_error("Scenario not found: " + storage)
		return false
	_clear_runtime_story_state()
	branch_flags.from_dict(Dictionary(jump_state.get("branch_flags", {})))
	var saved_scene := int(jump_state.get("scene_index", 0))
	var saved_line := int(jump_state.get("line_index", 0))
	_replay_until(saved_scene, saved_line)
	scene_index = saved_scene
	line_index = saved_line
	_apply_state(jump_state)
	pending_texts.clear()
	current_entry = {
		"name": str(history_entry.get("name", "")),
		"text": str(history_entry.get("text", "")),
		"voice": str(history_entry.get("voice", "")),
		"state": jump_state.duplicate(true),
	}
	# _replay_until has reconstructed all visual commands up to the stored
	# cursor.  Render the selected line without adding a duplicate history row
	# or overwriting the complete history list with this partial state.
	_apply_message_appearance()
	var speaker_name := str(current_entry.get("name", ""))
	name_label.text = _format_speaker_name(speaker_name)
	text_label.text = str(current_entry.get("text", ""))
	last_voice_name = str(current_entry.get("voice", ""))
	history_entries = preserved_history
	return true


func _clear_runtime_story_state() -> void:
	_cancel_script_action_tweens()
	_clear_visual_transition_overlays()
	_clear_script_wait()
	script_skip_scope = false
	_reset_environment_camera()
	_clear_procedural_script_actions()
	stage_layer.texture = null
	stage_layer.visible = false
	stage_layer.modulate = Color.WHITE
	stage_layer.position = Vector2.ZERO
	stage_layer.scale = Vector2.ONE
	event_layer.texture = null
	event_layer.visible = false
	event_layer.modulate = Color.WHITE
	event_layer.position = Vector2.ZERO
	event_layer.scale = Vector2.ONE
	visual_layer_paths.clear()
	auxiliary_visual_paths.clear()
	for effect in auxiliary_visual_nodes.values():
		if is_instance_valid(effect):
			effect.free()
	auxiliary_visual_nodes.clear()
	for emitter in particle_emitters.values():
		if is_instance_valid(emitter):
			emitter.free()
	particle_emitters.clear()
	stage_effect_animations.clear()
	for player_value in sound_players.values():
		var player := player_value as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	sound_players.clear()
	sound_channel_kinds.clear()
	_clear_characters()
	_clear_message_face()
	if voice_player != null:
		voice_player.stop()
	if bgm_player != null:
		bgm_player.stop()
	bgm_current_path = ""
	# Selection/branch state: a fresh start or a history jump rebuilds these
	# from their own source (empty new game, save state, or history snapshot).
	selection_pending = false
	_pending_selects = []
	_pending_select_info = {}
	_close_select_screen()
	selection_history = []
	last_selection_event = {}
	last_branch_decision = {}
	game_ended = false
	branch_flags.scene_values.clear()


func _replay_until(saved_scene: int, saved_line: int) -> void:
	replaying_state = true
	var scenes: Array = scenario.get("scenes", [])
	for s in range(min(saved_scene + 1, scenes.size())):
		var scene: Dictionary = scenes[s]
		var lines: Array = scene.get("lines", [])
		var limit := lines.size()
		if s == saved_scene:
			limit = clampi(saved_line, 0, lines.size())
		for i in range(limit):
			var line: Variant = lines[i]
			_apply_line_state(line)
			if _is_number(line):
				var entry := _text_entry(scene, int(line))
				if not entry.is_empty():
					_apply_state(Dictionary(entry.get("state", {})))
	replaying_state = false
