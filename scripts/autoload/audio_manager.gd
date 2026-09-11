extends Node

const SliParser := preload("res://scripts/story/sli_parser.gd")
const SYSSE_DIR := "res://assets/audio/sysse/"
const BGM_DIR := "res://assets/audio/bgm/"

const SYSSE := {
	"ok1": {"file": "ok1.ogg", "channel": 9},
	"ok2": {"file": "ok2.ogg", "channel": 9},
	"ok3": {"file": "ok3.ogg", "channel": 9},
	"cancel": {"file": "cancel.ogg", "channel": 9},
	"sel1": {"file": "sel1.ogg", "channel": 10},
	"sel2": {"file": "sel2.ogg", "channel": 10},
	"chg1": {"file": "chg1.ogg", "channel": 9},
	"chg2": {"file": "chg2.ogg", "channel": 9},
}

const TITLE_CLICK_SYSSE := {
	"*": "chg2",
	"exit": "ok1",
	"start": "ok3",
	"load": "ok3",
	"extra": "ok1",
	"continue": "ok2",
}

const TITLE_ENTER_SYSSE := {
	"*": "sel1",
}

var players: Dictionary = {}
var stream_cache: Dictionary = {}
var bgm_player: AudioStreamPlayer
var current_bgm := ""
var master_volume := 1.0
var bgm_volume := 1.0
var sysse_volume := 1.0
var voice_volume := 1.0
var movie_volume := 1.0


func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGM"
	add_child(bgm_player)
	for channel in range(0, 12):
		var player := AudioStreamPlayer.new()
		player.name = "SysSEChannel%d" % channel
		add_child(player)
		players[channel] = player
	_apply_audio_volumes()


func play_title_enter(action: String) -> void:
	play_sysse(str(TITLE_ENTER_SYSSE.get(action, TITLE_ENTER_SYSSE.get("*", ""))))


func play_title_click(action: String) -> void:
	play_sysse(str(TITLE_CLICK_SYSSE.get(action, TITLE_CLICK_SYSSE.get("*", ""))))


func play_sysse(name: String) -> void:
	if name == "" or not SYSSE.has(name):
		return
	var data: Dictionary = SYSSE[name]
	var channel := int(data.get("channel", 0))
	var player: AudioStreamPlayer = players.get(channel)
	if player == null:
		return
	player.volume_db = _volume_db(master_volume * sysse_volume)
	player.stream = _load_ogg(SYSSE_DIR + str(data.get("file", "")))
	if player.stream != null:
		player.play()


func play_bgm(name: String) -> void:
	if current_bgm == name and bgm_player.playing:
		return
	var stream := _load_ogg(BGM_DIR + name + ".ogg")
	if stream == null:
		return
	_apply_loop_points(stream, BGM_DIR + name + ".ogg")
	bgm_player.stream = stream
	bgm_player.volume_db = _volume_db(master_volume * bgm_volume)
	bgm_player.play()
	current_bgm = name


## Apply WaveLoopManager `.sli` loop points when the sidecar exists, so the
## track loops at the authored sabi segment instead of restarting from the top
## (docs/sli_loop.md).
func _apply_loop_points(stream: AudioStream, audio_path: String) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg == null:
		return
	ogg.loop = true
	var parser := SliParser.new()
	if not parser.load_for_audio(audio_path):
		return
	# AudioStreamOggVorbis exposes no sample-rate property in Godot 4.6; the
	# shipped .sli files are authored against 44.1 kHz (verified via ffprobe).
	var rate := 44100.0
	var loop := parser.loop_seconds(rate)
	if loop.is_empty():
		return
	# Only loop_offset exists (no loop_end): the loop-ready copy is already
	# truncated at the sli `From`, so offset = To reproduces [To, From].
	ogg.loop_offset = float(loop["begin"])


func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm = ""


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_volumes()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_audio_volumes()


func set_sysse_volume(value: float) -> void:
	sysse_volume = clampf(value, 0.0, 1.0)
	_apply_audio_volumes()


func set_voice_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)


func set_movie_volume(value: float) -> void:
	movie_volume = clampf(value, 0.0, 1.0)


func _apply_audio_volumes() -> void:
	if bgm_player != null:
		bgm_player.volume_db = _volume_db(master_volume * bgm_volume)
	for player in players.values():
		var audio_player := player as AudioStreamPlayer
		if audio_player != null:
			audio_player.volume_db = _volume_db(master_volume * sysse_volume)


func _volume_db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(clampf(value, 0.0, 1.0))


func _load_ogg(path: String) -> AudioStream:
	if stream_cache.has(path):
		return stream_cache[path]
	var stream := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null:
		push_warning("Failed to load ogg stream: " + path)
		return null
	stream_cache[path] = stream
	return stream
