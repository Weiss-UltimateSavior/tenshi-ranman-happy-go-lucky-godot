extends Node

var manifest: Array = []
var by_real_path: Dictionary = {}
var by_package: Dictionary = {}
var by_basename: Dictionary = {}


func _ready() -> void:
	load_manifest(AppConfig.HASH_MANIFEST)


func load_manifest(path: String) -> void:
	manifest.clear()
	by_real_path.clear()
	by_package.clear()
	by_basename.clear()
	if not FileAccess.file_exists(path):
		push_warning("Hash manifest not found: " + path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Hash manifest is not an array: " + path)
		return
	manifest = parsed
	for row in manifest:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var package := str(row.get("package", ""))
		if package != "":
			if not by_package.has(package):
				by_package[package] = []
			by_package[package].append(row)
		var real_path := str(row.get("real_path", ""))
		if real_path != "":
			by_real_path[package + ":" + real_path] = row
			_add_basename(package, real_path.get_file(), row)
		var hash_path := str(row.get("hash_path", ""))
		if hash_path != "":
			_add_basename(package, hash_path.replace("\\", "/").get_file(), row)


func resolve(package: String, real_path: String) -> String:
	var key := package + ":" + real_path
	if not by_real_path.has(key):
		return ""
	var row: Dictionary = by_real_path[key]
	return str(row.get("hash_path", ""))


func resolve_existing(package: String, real_path: String) -> String:
	var direct := resolve(package, real_path)
	if direct != "" and FileAccess.file_exists(direct):
		return direct
	var basename := real_path.replace("\\", "/").get_file()
	return resolve_basename(package, basename)


func resolve_basename(package: String, basename: String) -> String:
	var key := package + ":" + basename.to_lower()
	if not by_basename.has(key):
		return ""
	for row in by_basename[key]:
		var hash_path := str(Dictionary(row).get("hash_path", ""))
		if hash_path != "" and FileAccess.file_exists(hash_path):
			return hash_path
	return ""


func resolve_first(packages: Array, basenames: Array) -> String:
	for package in packages:
		for basename in basenames:
			var path := resolve_basename(str(package), str(basename))
			if path != "":
				return path
	return ""


func _add_basename(package: String, basename: String, row: Dictionary) -> void:
	if package == "" or basename == "":
		return
	var key := package + ":" + basename.to_lower()
	if not by_basename.has(key):
		by_basename[key] = []
	by_basename[key].append(row)
