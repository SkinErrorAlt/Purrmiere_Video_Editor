extends RefCounted

const Presets := preload("res://doc/presets.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const Sequence := preload("res://doc/sequence.gd")
const KIND := "export_place"
const PREF_LAST := "export.last_place"
const BORDERS: PackedStringArray = ["solid", "dashed", "double", "glow", "none"]
const COLOURS: Array = [
	["amber", "Amber", "d98b4a"],
	["green", "Green", "5aa06f"],
	["blue", "Blue", "7a86c8"],
	["pink", "Pink", "c45c7c"],
	["teal", "Teal", "4a9aa0"],
	["grey", "Grey", "8e949c"],
]
const TOKEN_PROJECT := "{project}"
const TOKEN_SEQUENCE := "{sequence}"
const TOKEN_DATE := "{date}"
const TOKEN_HEIGHT := "{height}"
const TOKEN_FPS := "{fps}"


static func colour_hex(id: String) -> String:
	for c: Array in COLOURS:
		if String(c[0]) == id:
			return String(c[2])
	return String(COLOURS[COLOURS.size() - 1][2])


static func colour_label(id: String) -> String:
	for c: Array in COLOURS:
		if String(c[0]) == id:
			return String(c[1])
	return id.capitalize()


static func make(name_: String, dir: String, colour: String = "grey", border: String = "solid", pattern: String = "", settings: Dictionary = {}) -> Dictionary:
	return {
		"id": "",
		"name": name_.strip_edges(),
		"dir": dir.strip_edges(),
		"colour": colour if colour_hex(colour) != "" else "grey",
		"border": border if BORDERS.has(border) else "solid",
		"pattern": pattern,
		"settings": settings.duplicate(true),
	}


static func valid(place: Dictionary) -> bool:
	return not String(place.get("name", "")).strip_edges().is_empty() and not String(place.get("dir", "")).strip_edges().is_empty()


static func normalise(place: Dictionary) -> Dictionary:
	var out: Dictionary = make(
		String(place.get("name", "")),
		String(place.get("dir", "")),
		String(place.get("colour", "grey")),
		String(place.get("border", "solid")),
		String(place.get("pattern", "")),
		place.get("settings", {}) if place.get("settings") is Dictionary else {})
	out["id"] = String(place.get("id", ""))
	if not BORDERS.has(String(out["border"])):
		out["border"] = "solid"
	var known: bool = false
	for c: Array in COLOURS:
		if String(c[0]) == String(out["colour"]):
			known = true
	if not known:
		out["colour"] = "grey"
	return out


static func to_preset(place: Dictionary) -> Dictionary:
	var p: Dictionary = normalise(place)
	var preset: Dictionary = Presets.make(KIND, String(p["name"]), {
		"dir": String(p["dir"]),
		"colour": String(p["colour"]),
		"border": String(p["border"]),
		"pattern": String(p["pattern"]),
		"settings": (p["settings"] as Dictionary).duplicate(true),
	})
	if not String(p["id"]).is_empty():
		preset["id"] = String(p["id"])
	return preset


static func from_preset(preset: Dictionary) -> Dictionary:
	var payload: Variant = preset.get("payload", {})
	var d: Dictionary = payload if payload is Dictionary else {}
	var out: Dictionary = normalise({
		"name": String(preset.get("label", "")),
		"dir": String(d.get("dir", "")),
		"colour": String(d.get("colour", "grey")),
		"border": String(d.get("border", "solid")),
		"pattern": String(d.get("pattern", "")),
		"settings": d.get("settings", {}) if d.get("settings") is Dictionary else {},
	})
	out["id"] = String(preset.get("id", ""))
	return out


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for preset: Dictionary in Presets.list_user(KIND):
		var place: Dictionary = from_preset(preset)
		if valid(place):
			out.append(place)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


static func by_id(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for place: Dictionary in list():
		if String(place["id"]) == id:
			return place
	return {}


static func save(place: Dictionary) -> bool:
	if not valid(place):
		return false
	return Presets.save_to_user(to_preset(place))


static func remove(id: String) -> bool:
	if id.is_empty():
		return false
	return bool(load("res://doc/io.gd").delete_preset(KIND, id))


static func expand(pattern: String, project_name: String, sequence_name: String, height: int, fps: float) -> String:
	var out: String = pattern
	out = out.replace(TOKEN_PROJECT, project_name)
	out = out.replace(TOKEN_SEQUENCE, sequence_name)
	out = out.replace(TOKEN_DATE, Time.get_date_string_from_system(false))
	out = out.replace(TOKEN_HEIGHT, str(height) + "p")
	out = out.replace(TOKEN_FPS, String.num(fps, 2).trim_suffix("0").trim_suffix("0").trim_suffix("."))
	return out.strip_edges()


static func file_name_for(place: Dictionary, project_name: String, sequence_name: String, height: int, fps: float) -> String:
	var pattern: String = String(place.get("pattern", "")).strip_edges()
	if pattern.is_empty():
		return project_name if not project_name.is_empty() else sequence_name
	var made: String = expand(pattern, project_name, sequence_name, height, fps)
	return made if not made.is_empty() else project_name


static func apply(settings: Dictionary, place: Dictionary, project_name: String = "", sequence_name: String = "", height: int = 0, fps: float = 0.0) -> Dictionary:
	if not valid(place):
		return settings.duplicate(true)
	var over: Variant = place.get("settings", {})
	var out: Dictionary = ExportPresets.merge(settings, over if over is Dictionary else {})
	var dest: Dictionary = out.get("destination", {})
	dest["dir"] = String(place["dir"])
	dest["place"] = String(place.get("id", ""))
	if not String(place.get("pattern", "")).strip_edges().is_empty():
		dest["name"] = file_name_for(place, project_name, sequence_name, height, fps)
	out["destination"] = dest
	return out


static func place_of(settings: Dictionary) -> String:
	var dest: Variant = settings.get("destination", {})
	return String((dest as Dictionary).get("place", "")) if dest is Dictionary else ""
