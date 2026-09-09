extends Control
class_name HglUIScreen

const DEFAULT_TARGET_SIZE := Vector2(1280, 720)

var texture_cache: Dictionary = {}
var compiled_ui: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func source_size() -> Vector2:
	var data: Dictionary = compiled_ui.get("source_size", {})
	return Vector2(float(data.get("w", 1920.0)), float(data.get("h", 1080.0)))


func target_size() -> Vector2:
	var data: Dictionary = compiled_ui.get("target_size", {})
	return Vector2(float(data.get("w", DEFAULT_TARGET_SIZE.x)), float(data.get("h", DEFAULT_TARGET_SIZE.y)))


func ui_scale() -> Vector2:
	return target_size() / source_size()


func rect_from_dict(data: Dictionary) -> Rect2:
	return Rect2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("w", 0.0)),
		float(data.get("h", 0.0))
	)


func scaled_rect(rect: Rect2) -> Rect2:
	var scale := ui_scale()
	return Rect2(rect.position * scale, rect.size * scale)


func add_texture(parent: Control, path: String, rect: Rect2, node_name: String) -> TextureRect:
	var tex := TextureRect.new()
	tex.name = node_name
	tex.texture = load_texture(path)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	var scaled := scaled_rect(rect)
	tex.position = scaled.position
	tex.size = scaled.size
	parent.add_child(tex)
	return tex


func prototype_slot_origin(slot_root: Dictionary, slot_name: String = "rect") -> Vector2:
	var prototype_slots: Dictionary = slot_root.get("prototype_slots", {})
	var slot: Dictionary = prototype_slots.get(slot_name, {})
	return scaled_rect(rect_from_dict(slot.get("rect", {}))).position


func slot_position(slot_root: Dictionary, slot_rect: Rect2, slot_name: String = "rect") -> Vector2:
	return slot_rect.position - prototype_slot_origin(slot_root, slot_name)


func layer_path(base: String, layer_id: Variant) -> String:
	if typeof(layer_id) == TYPE_FLOAT:
		return base + str(int(layer_id)) + ".png"
	return base + str(layer_id) + ".png"


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func load_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Failed to load texture: " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture


func load_json(path: String) -> Dictionary:
	if not file_exists(path):
		push_warning("Missing UI JSON: " + path)
		return {}
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid UI JSON: " + path)
		return {}
	return parsed
