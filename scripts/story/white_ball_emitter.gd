extends Control
class_name WhiteBallEmitter

# `parsermacro.ks` preserves the original particle tag values.  The compiled
# SCN resolves them through `particle_white_ball_1` through `_8`; only the
# image name changes, so the corresponding emitter profile is restored here.
const FRAME_SIZE := Vector2(50.0, 50.0)
const FRAME_COUNT := 60
const SPRITE_SHEET_PATH := "res://assets/story/particle_ball.png"

const PROFILES := {
	1: {"rate": 5.0, "speed": Vector2(100.0, 150.0), "size": 1.0, "vibration": Vector2(5.0, 8.0), "life": Vector2(1.0, 1.5)},
	2: {"rate": 10.0, "speed": Vector2(80.0, 120.0), "size": 0.6, "vibration": Vector2(3.0, 5.0), "life": Vector2(2.0, 2.5)},
	3: {"rate": 15.0, "speed": Vector2(50.0, 100.0), "size": 0.2, "vibration": Vector2(1.0, 2.0), "life": Vector2(3.0, 4.0)},
	4: {"rate": 3.0, "speed": Vector2(80.0, 120.0), "size": 0.6, "vibration": Vector2(3.0, 5.0), "life": Vector2(2.0, 3.0)},
	5: {"rate": 3.0, "speed": Vector2(50.0, 100.0), "size": 0.2, "vibration": Vector2(1.0, 2.0), "life": Vector2(3.0, 5.0)},
}

var profile_index := 1
var profile: Dictionary = PROFILES[1]
var particles: Array[Dictionary] = []
var spawn_remainder := 0.0
var emitter_opacity := 1.0
var rng := RandomNumberGenerator.new()
var sprite_sheet: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = false
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SPRITE_SHEET_PATH)) == OK:
		sprite_sheet = ImageTexture.create_from_image(image)


func configure(next_profile_index: int, seed_value: int, opacity: float) -> void:
	profile_index = clampi(next_profile_index, 1, 5)
	profile = PROFILES[profile_index]
	emitter_opacity = clampf(opacity, 0.0, 1.0)
	particles.clear()
	spawn_remainder = 0.0
	rng.seed = seed_value
	# The original tag begins generating immediately. Seed the display with a
	# short history so the first rendered frame is not an empty particle layer.
	var warmup_count: int = max(1, roundi(float(profile["rate"]) * 0.75))
	for index in warmup_count:
		_spawn_particle(rng.randf_range(0.0, float(profile["life"].y)))
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	spawn_remainder += delta * float(profile["rate"])
	while spawn_remainder >= 1.0:
		_spawn_particle(0.0)
		spawn_remainder -= 1.0
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle["age"] = float(particle["age"]) + delta
		if float(particle["age"]) >= float(particle["life"]):
			particles.remove_at(index)
		else:
			particles[index] = particle
	queue_redraw()


func _spawn_particle(initial_age: float) -> void:
	if particles.size() >= 128:
		return
	var speed_range: Vector2 = profile["speed"]
	var life_range: Vector2 = profile["life"]
	var vibration_range: Vector2 = profile["vibration"]
	var angle := deg_to_rad(rng.randf_range(265.0, 275.0))
	particles.append({
		"age": initial_age,
		"life": rng.randf_range(life_range.x, life_range.y),
		"origin": Vector2(rng.randf_range(0.0, size.x), rng.randf_range(size.y, size.y + 25.0)),
		"velocity": Vector2.RIGHT.rotated(angle) * rng.randf_range(speed_range.x, speed_range.y),
		"vibration": rng.randf_range(vibration_range.x, vibration_range.y),
		"vibration_speed": rng.randf_range(0.5, 1.0),
		"phase": rng.randf_range(0.0, TAU),
		"frame_speed": rng.randf_range(10.0, 20.0),
		"size": float(profile["size"]),
	})


func _draw() -> void:
	if sprite_sheet == null:
		return
	for particle_value in particles:
		var particle: Dictionary = particle_value
		var age := float(particle["age"])
		var life := float(particle["life"])
		var remaining_fade := clampf((life - age) / 0.5, 0.0, 1.0)
		var wave := sin(age * float(particle["vibration_speed"]) * TAU + float(particle["phase"]))
		var position: Vector2 = particle["origin"] + particle["velocity"] * age
		position += Vector2(wave * float(particle["vibration"]), cos(age * float(particle["vibration_speed"]) * TAU) * float(particle["vibration"]) * 0.35)
		var frame := posmod(floori(age * float(particle["frame_speed"])), FRAME_COUNT)
		var source := Rect2(Vector2(0.0, frame * FRAME_SIZE.y), FRAME_SIZE)
		var target_size := FRAME_SIZE * float(particle["size"])
		var target := Rect2(position - target_size * 0.5, target_size)
		draw_texture_rect_region(sprite_sheet, target, source, Color(1.0, 1.0, 1.0, remaining_fade * emitter_opacity))
