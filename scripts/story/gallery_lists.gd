extends RefCounted

## CSV readers for the Extra gallery lists
## (docs/plan/PLAN_P2_TEXT_AUDIO_CONTENT.md §3). The originals ship as
## UTF-16 TSV-ish files under assets/main:
##
##   cglist.csv     "#CGモード一覧"      rows: <thum>, <CG名>, <CG名>, ...
##   soundlist.csv  "#ファイル名,タイトル" rows: <BGMxx>, <title>
##   scenelist.csv  "# ●回想モード一覧"   rows: <thum>, , <replay*NAME>, , <@replay_NAME>, <TAG>
##
## Comment lines start with '#' and are skipped.

const MAIN_DIR := "res://assets/main"


static func cg_entries() -> Array[Dictionary]:
	var rows := _read_rows("cglist.csv")
	var out: Array[Dictionary] = []
	for row in rows:
		var cells := _split(row)
		if cells.size() < 2:
			continue
		var thumb := cells[0]
		if thumb == "" or thumb.begins_with(":"):
			continue
		# Remaining cells are the CG image names grouped under this thumbnail.
		var names: Array[String] = []
		for i in range(1, cells.size()):
			if cells[i] != "":
				names.append(cells[i])
		if names.is_empty():
			continue
		out.append({
			"thumb": thumb,
			"group": names[0].get_basename(),
			"names": names,
		})
	return out


## Map any CG variant name to its cglist group key (case-insensitive).
## "ev0102f" belongs to the group whose first entry is "EV0102A"; returns the
## group's canonical name (as authored) or "" when the name is not listed.
static func cg_group_for(image_name: String) -> String:
	var wanted := image_name.to_lower()
	if wanted == "":
		return ""
	for entry in cg_entries():
		var names: Array = entry.get("names", [])
		for name in names:
			if str(name).to_lower() == wanted:
				return str(entry.get("group", ""))
	return ""


static func sound_entries() -> Array[Dictionary]:
	var rows := _read_rows("soundlist.csv")
	var out: Array[Dictionary] = []
	for row in rows:
		# soundlist uses commas (its header is "#ファイル名,タイトル") while the
		# other lists are tab separated; without a comma it is a title-only line.
		var cells := _split(row)
		if cells.size() < 2:
			continue
		var file_stem := cells[0]
		if file_stem == "":
			continue
		out.append({
			"file": file_stem,
			"key": file_stem.to_lower(),
			"title": cells[1],
		})
	return out


static func scene_entries() -> Array[Dictionary]:
	var rows := _read_rows("scenelist.csv")
	var out: Array[Dictionary] = []
	for row in rows:
		var cells := _split(row)
		if cells.size() < 2:
			continue
		var thumb := cells[0]
		if thumb == "":
			continue
		# Column 2 is "replay*<MOVIE>" (or @replay_<...> in column 4); keep both.
		var movie := ""
		var tag := cells[cells.size() - 1]
		for cell in cells:
			if cell.begins_with("replay*"):
				movie = cell.trim_prefix("replay*")
				break
			if cell.begins_with("@replay_"):
				movie = cell.trim_prefix("@replay_")
		out.append({
			"thumb": thumb,
			"key": thumb,
			"movie": movie,
			"tag": tag,
		})
	return out


# --- reading ---------------------------------------------------------------

static func _read_rows(file_name: String) -> Array[String]:
	var path := MAIN_DIR.path_join(file_name)
	var text := _read_text(path)
	var rows: Array[String] = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		rows.append(line.trim_prefix("\ufeff"))
	return rows


## The original lists are comma separated with decorative tabs inside the
## fields (e.g. "thum_EV0102A,\tEV0102A,EV0102B"), so split on commas and
## strip stray tabs/whitespace from every cell.
static func _split(row: String) -> Array[String]:
	return _split_by(row, ",")


static func _split_by(row: String, delimiter: String) -> Array[String]:
	var out: Array[String] = []
	for cell in row.split(delimiter, true):
		out.append(str(cell).replace("\t", "").strip_edges())
	return out


static func _read_text(path: String) -> String:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return ""
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	# The shipped lists are UTF-16LE with BOM; fall back to UTF-8 otherwise.
	if bytes.size() >= 2 and bytes[0] == 0xff and bytes[1] == 0xfe:
		return bytes.slice(2).get_string_from_utf16()
	return bytes.get_string_from_utf8()
