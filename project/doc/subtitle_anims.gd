extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const FILE := "subtitle_animations.json"
const VERSION := 1
const SLOT_IN := "in"
const SLOT_OUT := "out"
const SLOTS: PackedStringArray = ["in", "out"]
const KEYS: PackedStringArray = ["scale", "opacity"]
const INTERPS: PackedStringArray = ["linear", "ease_in", "ease_out", "ease_both", "hold"]
const DEFAULT_ID := "pop"
const MIN_SECONDS := 0.02
const MAX_SECONDS := 10.0
const BUILT_IN: Array = [
	{"id": "pop", "label": "Pop", "slot": "in", "seconds": 0.28, "curves": {"scale": [[0.0, 0.6, "ease_out"], [0.6, 1.08, "ease_both"], [1.0, 1.0, "ease_both"]], "opacity": [[0.0, 0.0, "ease_out"], [0.6, 1.0, "ease_both"]]}},
	{"id": "fade", "label": "Fade", "slot": "in", "seconds": 0.2, "curves": {"opacity": [[0.0, 0.0, "ease_out"], [1.0, 1.0, "linear"]]}},
	{"id": "grow", "label": "Grow", "slot": "in", "seconds": 0.25, "curves": {"scale": [[0.0, 0.0, "ease_out"], [1.0, 1.0, "ease_both"]], "opacity": [[0.0, 0.0, "ease_out"], [0.3, 1.0, "linear"]]}},
	{"id": "letters", "label": "Letters, one by one across the run", "slot": "in", "seconds": 0.6, "per_char": true, "curves": {}},
	{"id": "pop", "label": "Pop", "slot": "out", "seconds": 0.28, "curves": {"scale": [[0.0, 1.0, "ease_in"], [0.6, 1.06, "ease_both"], [1.0, 0.5, "ease_in"]], "opacity": [[0.4, 1.0, "ease_in"], [1.0, 0.0, "ease_in"]]}},
	{"id": "fade", "label": "Fade", "slot": "out", "seconds": 0.2, "curves": {"opacity": [[0.0, 1.0, "ease_in"], [1.0, 0.0, "linear"]]}},
	{"id": "letters", "label": "Letters, one by one across the run", "slot": "out", "seconds": 0.6, "per_char": true, "curves": {}},
	{"id": "shrink", "label": "Shrink", "slot": "out", "seconds": 0.25, "curves": {"scale": [[0.0, 1.0, "ease_in"], [1.0, 0.0, "ease_in"]], "opacity": [[0.7, 1.0, "linear"], [1.0, 0.0, "ease_in"]]}},
]

static var path_override: String = ""
static var _counter: int = 0


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("data_path"):
			return prefs
	return null


static func library_path() -> String:
	if not path_override.is_empty():
		return path_override
	var prefs: Node = prefs_node()
	if prefs == null:
		return ""
	return String(prefs.call("data_path", FILE))


static func clean_points(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for p: Variant in raw:
		if not (p is Array) or (p as Array).size() < 2:
			continue
		var a: Array = p
		var interp: String = String(a[2]) if a.size() > 2 and a[2] is String and INTERPS.has(String(a[2])) else "linear"
		out.append([clampf(float(a[0]), 0.0, 1.0), float(a[1]), interp])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return out


static func normalize(raw: Dictionary) -> Dictionary:
	var curves: Dictionary = {}
	var given: Dictionary = raw.get("curves", {}) if raw.get("curves") is Dictionary else {}
	for k: String in KEYS:
		var pts: Array = clean_points(given.get(k, []))
		if not pts.is_empty():
			curves[k] = pts
	var slot: String = String(raw.get("slot", SLOT_IN))
	return {
		"id": String(raw.get("id", "")),
		"label": String(raw.get("label", "Animation")).strip_edges(),
		"slot": slot if SLOTS.has(slot) else SLOT_IN,
		"seconds": clampf(float(raw.get("seconds", 0.28)), MIN_SECONDS, MAX_SECONDS),
		"curves": curves,
		"user": bool(raw.get("user", false)),
		"per_char": bool(raw.get("per_char", false)),
	}


static func built_in(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in BUILT_IN:
		if String(p["slot"]) == slot:
			out.append(normalize(p))
	return out


static func load_user() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path: String = library_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("presets") is Array):
		return out
	for raw: Variant in (parsed as Dictionary)["presets"]:
		if raw is Dictionary:
			var p: Dictionary = normalize(raw)
			p["user"] = true
			if not String(p["id"]).is_empty():
				out.append(p)
	return out


static func save_user(list: Array[Dictionary]) -> bool:
	var path: String = library_path()
	if path.is_empty():
		return false
	var rows: Array = []
	for p: Dictionary in list:
		var row: Dictionary = normalize(p)
		row.erase("user")
		rows.append(row)
	var text: String = JSON.stringify({"version": VERSION, "presets": rows}, "\t", false, true)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func listing(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = built_in(slot)
	for p: Dictionary in load_user():
		if String(p["slot"]) == slot:
			out.append(p)
	return out


static func find(slot: String, id: String) -> Dictionary:
	for p: Dictionary in listing(slot):
		if String(p["id"]) == id:
			return p
	return {}


static func mint_id() -> String:
	_counter += 1
	return "anim_" + str(Time.get_unix_time_from_system()).replace(".", "") + "_" + str(_counter)


static func make(label: String, slot: String, seconds: float, curves: Dictionary) -> Dictionary:
	var p: Dictionary = normalize({"id": mint_id(), "label": label, "slot": slot, "seconds": seconds, "curves": curves})
	p["user"] = true
	return p


static func from_numbers(label: String, slot: String, seconds: float, start_scale: float, overshoot: float, start_opacity: float) -> Dictionary:
	var scale: Array = []
	var opacity: Array = []
	if slot == SLOT_OUT:
		scale = [[0.0, 1.0, "ease_in"], [0.6, overshoot, "ease_both"], [1.0, start_scale, "ease_in"]]
		opacity = [[0.4, 1.0, "ease_in"], [1.0, start_opacity, "ease_in"]]
	else:
		scale = [[0.0, start_scale, "ease_out"], [0.6, overshoot, "ease_both"], [1.0, 1.0, "ease_both"]]
		opacity = [[0.0, start_opacity, "ease_out"], [0.6, 1.0, "ease_both"]]
	return make(label, slot, seconds, {"scale": scale, "opacity": opacity})


static func is_built_in_id(id: String) -> bool:
	for b: Dictionary in BUILT_IN:
		if String(b["id"]) == id:
			return true
	return false


static func add(preset: Dictionary) -> bool:
	var p: Dictionary = normalize(preset)
	if String(p["id"]).is_empty() or is_built_in_id(String(p["id"])):
		p["id"] = mint_id()
	var list: Array[Dictionary] = load_user()
	list.append(p)
	return save_user(list)


static func _index(list: Array[Dictionary], id: String) -> int:
	for i: int in list.size():
		if String(list[i]["id"]) == id:
			return i
	return -1


static func rename(id: String, label: String) -> bool:
	var list: Array[Dictionary] = load_user()
	var at: int = _index(list, id)
	if at < 0 or label.strip_edges().is_empty():
		return false
	list[at]["label"] = label.strip_edges()
	return save_user(list)


static func remove(id: String) -> bool:
	var list: Array[Dictionary] = load_user()
	var at: int = _index(list, id)
	if at < 0:
		return false
	list.remove_at(at)
	return save_user(list)


static func duplicate_of(slot: String, id: String, label: String = "") -> Dictionary:
	var src: Dictionary = find(slot, id)
	if src.is_empty():
		return {}
	var copy: Dictionary = make(label if not label.strip_edges().is_empty() else String(src["label"]) + " copy", slot, float(src["seconds"]), (src["curves"] as Dictionary).duplicate(true))
	if not add(copy):
		return {}
	return copy


static func move(id: String, step: int) -> bool:
	var list: Array[Dictionary] = load_user()
	var at: int = _index(list, id)
	if at < 0:
		return false
	var slot: String = String(list[at]["slot"])
	var to: int = at
	var dir: int = 1 if step > 0 else -1
	var left: int = absi(step)
	var i: int = at
	while left > 0:
		i += dir
		if i < 0 or i >= list.size():
			break
		if String(list[i]["slot"]) == slot:
			to = i
			left -= 1
	if to == at:
		return false
	var row: Dictionary = list[at]
	list.remove_at(at)
	list.insert(to, row)
	return save_user(list)


static func snapshot(preset: Dictionary) -> Dictionary:
	var p: Dictionary = normalize(preset)
	p.erase("user")
	return p


static func per_char(style: Variant) -> bool:
	return style is Dictionary and bool((style as Dictionary).get("per_char", false))


static func is_default(style: Variant) -> bool:
	if not (style is Dictionary):
		return true
	var d: Dictionary = style
	return d.is_empty() or String(d.get("id", "")) == DEFAULT_ID


static func window(style: Dictionary, run_duration: float) -> float:
	var w: float = float(style.get("seconds", 0.28))
	if run_duration <= 0.0:
		return w
	return minf(w, run_duration)


static func curves_for(style: Dictionary, slot: String, run_duration: float) -> Dictionary:
	var out: Dictionary = {}
	var p: Dictionary = normalize(style)
	var w: float = window(p, run_duration)
	var begin: float = 0.0 if slot == SLOT_IN else maxf(run_duration - w, 0.0)
	var curves: Dictionary = p["curves"]
	for k: String in KEYS:
		if not curves.has(k):
			continue
		var prop: Dictionary = AnimProp.make([1.0, 1.0] if k == "scale" else 1.0)
		for pt: Variant in curves[k]:
			var a: Array = pt
			var v: Variant = [float(a[1]), float(a[1])] if k == "scale" else float(a[1])
			prop = AnimProp.set_key(prop, begin + float(a[0]) * w, v, String(a[2]))
		out[k] = prop
	return out
