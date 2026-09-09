extends SceneTree


const WINDOW_BASE := "res://assets/ui/exported/window/layers/5950.png"
const TINT := Color("d3727a")
const OPACITY := 0.75
const SAMPLE := Vector2i(1100, 190)
const BACKGROUND := Color("b9a780")

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform vec4 overlay_color = vec4(0.827451, 0.447059, 0.478431, 1.0);
void fragment() {
	vec4 base_sample = texture(TEXTURE, UV);
	vec3 base = pow(base_sample.rgb, vec3(1.0 / 2.2));
	vec3 tint = overlay_color.rgb;
	vec3 dark = 2.0 * base * tint;
	vec3 light = 1.0 - 2.0 * (1.0 - base) * (1.0 - tint);
	vec3 result = mix(dark, light, step(vec3(0.5), base));
	COLOR = vec4(result, COLOR.a);
}
"""


func _initialize() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(1280, 720)
	root.add_child(background)
	var frame := TextureRect.new()
	frame.texture = load(WINDOW_BASE)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = Vector2(1280, 280)
	frame.modulate.a = OPACITY
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("overlay_color", TINT)
	frame.material = material
	root.add_child(frame)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var sample := image.get_pixelv(SAMPLE)
	var source := frame.texture.get_image().get_pixelv(Vector2i(1650, 285))
	var expected_overlay := _overlay(_to_display(source), TINT)
	var expected := expected_overlay.lerp(_to_display(BACKGROUND), 1.0 - source.a * OPACITY)
	print("uniform=", material.get_shader_parameter("overlay_color"), " source=", source, " final=", sample, " expected_display=", expected)
	# At this opaque PIMG coordinate the original frame is visibly pink. This
	# guards against accidentally multiplying the frame RGB by TEXTURE twice.
	if sample.r < 0.80 or sample.g < 0.62 or sample.b < 0.60:
		push_error("Message window lower section is too dark: %s" % sample)
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path("res://qa/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	image.save_png(output_dir + "/message_window_shader.png")
	quit(0)


func _to_display(color: Color) -> Color:
	return Color(pow(color.r, 1.0 / 2.2), pow(color.g, 1.0 / 2.2), pow(color.b, 1.0 / 2.2), color.a)


func _overlay(base: Color, tint: Color) -> Color:
	return Color(_overlay_channel(base.r, tint.r), _overlay_channel(base.g, tint.g), _overlay_channel(base.b, tint.b), base.a)


func _overlay_channel(base_value: float, tint_value: float) -> float:
	return 2.0 * base_value * tint_value if base_value < 0.5 else 1.0 - 2.0 * (1.0 - base_value) * (1.0 - tint_value)
