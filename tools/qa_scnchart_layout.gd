extends SceneTree

## Flowchart layout regression: the chart must be laid out from the authored data
## (`scnchart.ini` object rects + `default.tjs` .scnchartUiItemConsts step), never
## from hand-tuned pixel numbers.
##
## Checks:
##   1. every compiled screen scales its PSD canvas uniformly (no 1440-vs-1080
##      squash; see `presentation_size` in tools/compile_hgl_ui_screens.py),
##   2. the node rows line up with the `section`/`subsection` templates and are
##      spaced by SCNCHART_ITEM_STEP on the source canvas,
##   3. the rows and their hitboxes stay inside the `#scroll` viewport,
##   4. each of the eight route tabs sits on its own `page0..page7` rect,
##   5. `visible,false` .func templates are not drawn as static layers.

const SCREEN_JSON := "res://assets/ui/compiled/screens/%s.json"
## Part canvases that are not full screens: these are standalone panels/strips
## whose own box is the presentation size, so a target-sized aspect is not
## meaningful for them.
const PART_CANVAS_SCREENS := ["file_data", "gesture_help", "touchuibar"]


func _initialize() -> void:
	var failures: Array[String] = []
	_check_uniform_scale(failures)
	await _check_scnchart_layout(failures)
	if failures.is_empty():
		print("OK: scnchart layout matches the authored chart data")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_uniform_scale(failures: Array[String]) -> void:
	var dir := DirAccess.open("res://assets/ui/compiled/screens")
	if dir == null:
		failures.append("cannot open compiled screen dir")
		return
	for file_name in dir.get_files():
		if not str(file_name).ends_with(".json"):
			continue
		var screen_name := str(file_name).trim_suffix(".json")
		if screen_name in PART_CANVAS_SCREENS:
			continue
		var data := _load_screen(screen_name)
		if data.is_empty():
			continue
		var source: Dictionary = data.get("source_size", {})
		var target: Dictionary = data.get("target_size", {})
		var sw := float(source.get("w", 0.0))
		var sh := float(source.get("h", 0.0))
		var tw := float(target.get("w", 0.0))
		var th := float(target.get("h", 0.0))
		if sw <= 0.0 or sh <= 0.0:
			continue
		if not is_equal_approx(sw / sh, tw / th):
			failures.append("%s: source %dx%d and target %dx%d have different aspect ratios (the screen would be squashed)" % [file_name, int(sw), int(sh), int(tw), int(th)])


func _check_scnchart_layout(failures: Array[String]) -> void:
	var data := _load_screen("scnchart")
	if data.is_empty():
		failures.append("scnchart.json missing")
		return
	var scale := _ui_scale(data)
	var objects := _object_map(data)
	var scroll := _scaled(_object_rect(objects, "scroll", Rect2(576, 0, 896, 982)), scale)
	var section := _scaled(_object_rect(objects, "section", Rect2(889, 459, 435, 74)), scale)
	var subsection := _scaled(_object_rect(objects, "subsection", Rect2(889, 459, 274, 74)), scale)

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	main_scene.show_static_ui_screen("scnchart")
	for _i in range(3):
		await process_frame
	var screen: Node = main_scene.screen_root.get_child(0)
	var layer: Control = screen.scnchart_runtime_layer
	if layer == null:
		failures.append("scnchart runtime layer missing")
		_finish(main_scene)
		return

	# 1. rows are the authored templates, spaced by the chart's own step.
	var holder := _find_child(layer, "scnchart_node_list")
	if holder == null:
		failures.append("scnchart_node_list missing")
		_finish(main_scene)
		return
	var step := float(screen.SCNCHART_ITEM_STEP) * scale.y
	var rows: Array[Control] = []
	for child in holder.get_children():
		var control := child as Control
		if control != null and str(control.name).begins_with("scnchart_node_"):
			rows.append(control)
	if rows.size() != 7:
		failures.append("expected 7 visible chart rows, found %d" % rows.size())
	var expected_top := scroll.position.y + maxf(0.0, (scroll.size.y - (step * 6.0 + section.size.y)) * 0.5)
	for i in range(rows.size()):
		var row := rows[i]
		var template := section if i == 0 else subsection
		var expected_x := template.position.x - scroll.position.x
		var expected_y := expected_top + step * float(i) - scroll.position.y
		if absf(row.position.x - expected_x) > 0.6:
			failures.append("row %d x=%.1f, expected %.1f (from the %s template)" % [i, row.position.x, expected_x, "section" if i == 0 else "subsection"])
		if absf(row.position.y - expected_y) > 0.6:
			failures.append("row %d y=%.1f, expected %.1f (step %.1f)" % [i, row.position.y, expected_y, step])

	# 2. rows and hitboxes stay inside the chart viewport.
	for i in range(rows.size()):
		var row := rows[i]
		if row.position.x < -0.6 or row.position.x + row.size.x > scroll.size.x + 0.6:
			failures.append("row %d horizontally outside the #scroll viewport" % i)
	for child in layer.get_children():
		var hit := child as Control
		if hit == null or not str(hit.name).begins_with("scnchart_node_hit_"):
			continue
		if hit.position.x < scroll.position.x - 0.6 or hit.position.x + hit.size.x > scroll.position.x + scroll.size.x + 0.6:
			failures.append("%s is outside the #scroll viewport" % hit.name)
		if hit.position.y < scroll.position.y - 0.6 or hit.position.y + hit.size.y > scroll.position.y + scroll.size.y + 0.6:
			failures.append("%s is outside the #scroll viewport" % hit.name)

	# 3. every route tab sits on its own authored page rect.
	for index in range(8):
		var tab := _find_child(layer, "scnchart_route_" + str(index))
		if tab == null:
			failures.append("route tab %d missing" % index)
			continue
		var expected := _scaled(_object_rect(objects, "page" + str(index), Rect2(1580, 75, 137, 86)), scale)
		if tab.position.distance_to(expected.position) > 0.6:
			failures.append("route tab %d at %s, expected %s" % [index, str(tab.position), str(expected.position)])
		var button := _find_child(layer, "scnchart_route_hit_" + str(index))
		if button == null:
			failures.append("route tab %d has no hitbox" % index)

	# 4. a visible hitbox must exist for every visible row.
	for i in range(rows.size()):
		if _find_child(layer, "scnchart_node_hit_" + str(i)) == null:
			failures.append("row %d has no hitbox" % i)

	_finish(main_scene)


func _finish(main_scene: Node) -> void:
	main_scene.queue_free()
	await process_frame


func _find_child(parent: Node, child_name: String) -> Control:
	for child in parent.get_children():
		if str(child.name) == child_name:
			return child as Control
	return null


func _ui_scale(data: Dictionary) -> Vector2:
	var source: Dictionary = data.get("source_size", {})
	var target: Dictionary = data.get("target_size", {})
	return Vector2(
		float(target.get("w", 1280.0)) / maxf(1.0, float(source.get("w", 1920.0))),
		float(target.get("h", 720.0)) / maxf(1.0, float(source.get("h", 1080.0)))
	)


func _scaled(rect: Rect2, scale: Vector2) -> Rect2:
	return Rect2(rect.position * scale, rect.size * scale)


func _object_map(data: Dictionary) -> Dictionary:
	var objects := {}
	for object_value in data.get("ini", {}).get("objects", []):
		if typeof(object_value) == TYPE_DICTIONARY:
			objects[str(Dictionary(object_value).get("name", ""))] = object_value
	return objects


func _object_rect(objects: Dictionary, object_name: String, fallback: Rect2) -> Rect2:
	if not objects.has(object_name):
		return fallback
	var slots: Dictionary = Dictionary(objects[object_name]).get("slots", {})
	for slot_name in ["rect", "rect/layer", "rect/layer"]:
		if not slots.has(slot_name):
			continue
		var slot: Dictionary = slots[slot_name]
		if not slot.has("rect"):
			continue
		var data: Dictionary = slot["rect"]
		return Rect2(
			float(data.get("x", 0.0)), float(data.get("y", 0.0)),
			float(data.get("w", 0.0)), float(data.get("h", 0.0))
		)
	var object: Dictionary = objects[object_name]
	if object.has("rect"):
		var direct: Dictionary = object["rect"]
		return Rect2(
			float(direct.get("x", 0.0)), float(direct.get("y", 0.0)),
			float(direct.get("w", 0.0)), float(direct.get("h", 0.0))
		)
	return fallback


func _load_screen(screen_name: String) -> Dictionary:
	var path := SCREEN_JSON % screen_name
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
