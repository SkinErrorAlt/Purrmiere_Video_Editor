extends RefCounted

const Io := preload("res://doc/io.gd")
const FILE := "kinds.json"
const DIR := "organizer"
const VERSION := 1
const FN_NONE := "none"
const FN_CUT := "cut"
const FN_CUT_MUTE := "cut_mute"
const FN_MUTE := "mute"
const FN_MOVER := "mover"
const FN_SWEAR := "swear"
const FN_COME_BACK := "come_back"
const FN_SPLIT := "split"
const FN_BLUR := "blur"
const FUNCTIONS: PackedStringArray = ["none", "split", "cut", "cut_mute", "mute", "mover", "swear", "blur", "come_back"]
const FUNCTION_LABELS: Dictionary = {
	"none": "Just a coloured region",
	"split": "Cut the clip where it starts and ends",
	"cut": "Cut it out (dead space)",
	"cut_mute": "Cut at the edges and mute it",
	"mute": "Mute it",
	"mover": "Skip over it but keep it",
	"swear": "Swear: beep or censor it",
	"blur": "Blur this part of the picture",
	"come_back": "Come back to tag it later",
}
const CUTTING: PackedStringArray = ["split", "cut", "cut_mute", "mover", "swear"]
const DEFAULTS: Array = [
	{"id": "dead", "name": "Dead space", "rgb": "#6b6f78", "fn": "cut"},
	{"id": "talking", "name": "Talking", "rgb": "#4f8ff7", "fn": "none"},
	{"id": "random", "name": "Random", "rgb": "#a874e8", "fn": "none"},
	{"id": "best", "name": "Best moment", "rgb": "#f2c84b", "fn": "none"},
	{"id": "swear", "name": "Swear", "rgb": "#e5484d", "fn": "swear"},
	{"id": "mute", "name": "Quiet this", "rgb": "#3fb6a8", "fn": "mute"},
	{"id": "skip", "name": "Skip over", "rgb": "#46a758", "fn": "mover"},
	{"id": "come_back", "name": "Come back", "rgb": "#f08c3a", "fn": "come_back"},
	{"id": "blur", "name": "Blur this part", "rgb": "#8e7dbe", "fn": "blur"},
]

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _override_path: String = ""
static var serial: int = 0


static func path() -> String:
	if not _override_path.is_empty():
		return _override_path
	return Io.data_path(DIR).path_join(FILE)


static func use_path(p: String) -> void:
	_override_path = p
	_loaded = false
	_cache = {}
	serial += 1


static func reread() -> void:
	_loaded = false
	_cache = {}
	serial += 1


static func _fresh() -> Dictionary:
	return {"version": VERSION, "kinds": DEFAULTS.duplicate(true), "next": 1}


static func library() -> Dictionary:
	if _loaded:
		return _cache
	var d: Dictionary = Io.read_json(path())
	if d.is_empty() or not (d.get("kinds") is Array):
		d = _fresh()
	var clean: Array = []
	for k: Variant in d["kinds"]:
		if k is Dictionary:
			clean.append(normalised(k))
	d["kinds"] = clean
	_cache = d
	_loaded = true
	return _cache


static func save() -> bool:
	var d: Dictionary = library()
	d["version"] = VERSION
	serial += 1
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	return Io.write_atomic(path(), JSON.stringify(d, "\t", false, true), false) == OK


static func normalised(k: Dictionary) -> Dictionary:
	var fn: String = String(k.get("fn", FN_NONE))
	var rgb: String = String(k.get("rgb", "#888888"))
	if not Color.html_is_valid(rgb):
		rgb = "#888888"
	var out: Dictionary = {"id": String(k.get("id", "")), "name": String(k.get("name", "Region")).strip_edges(), "rgb": rgb, "fn": fn if FUNCTIONS.has(fn) else FN_NONE}
	if bool(k.get("hidden", false)):
		out["hidden"] = true
	if k.get("samples") is Dictionary:
		out["samples"] = (k["samples"] as Dictionary).duplicate(true)
	return out


static func kinds() -> Array:
	return library()["kinds"]


static func by_id(id: String) -> Dictionary:
	for k: Dictionary in kinds():
		if String(k["id"]) == id:
			return k
	return {}


static func by_name(name: String) -> Dictionary:
	var low: String = name.strip_edges().to_lower()
	for k: Dictionary in kinds():
		if String(k["name"]).to_lower() == low:
			return k
	return {}


static func name_of(id: String) -> String:
	var k: Dictionary = by_id(id)
	return String(k["name"]) if not k.is_empty() else id.capitalize()


static func colour_of(id: String) -> Color:
	var k: Dictionary = by_id(id)
	return Color.from_string(String(k.get("rgb", "#888888")), Color(0.55, 0.55, 0.55))


static func fn_of(id: String) -> String:
	var k: Dictionary = by_id(id)
	return String(k.get("fn", FN_NONE)) if not k.is_empty() else FN_NONE


static func cuts_by_default(id: String) -> bool:
	return CUTTING.has(fn_of(id))


static func function_label(fn: String) -> String:
	return String(FUNCTION_LABELS.get(fn, fn))


static func add(name: String, rgb: String, fn: String) -> Dictionary:
	var n: String = name.strip_edges()
	if n.is_empty():
		return {}
	var same: Dictionary = by_name(n)
	if not same.is_empty():
		return same
	var d: Dictionary = library()
	var next: int = int(d.get("next", 1))
	var id: String = "k" + str(next) + "_" + n.to_lower().validate_node_name().replace(" ", "_").left(24)
	while not by_id(id).is_empty():
		next += 1
		id = "k" + str(next) + "_" + n.to_lower().validate_node_name().replace(" ", "_").left(24)
	d["next"] = next + 1
	var k: Dictionary = normalised({"id": id, "name": n, "rgb": rgb, "fn": fn})
	(d["kinds"] as Array).append(k)
	save()
	return k


static func change(id: String, fields: Dictionary) -> bool:
	var list: Array = kinds()
	for i: int in list.size():
		var k: Dictionary = list[i]
		if String(k["id"]) != id:
			continue
		var merged: Dictionary = k.duplicate(true)
		for f: Variant in fields.keys():
			merged[f] = fields[f]
		if String(merged.get("name", "")).strip_edges().is_empty():
			return false
		list[i] = normalised(merged)
		save()
		return true
	return false


static func remove(id: String) -> bool:
	var list: Array = kinds()
	for i: int in list.size():
		if String((list[i] as Dictionary)["id"]) == id:
			list.remove_at(i)
			save()
			return true
	return false


static func move(id: String, to_index: int) -> bool:
	var list: Array = kinds()
	for i: int in list.size():
		if String((list[i] as Dictionary)["id"]) == id:
			var k: Variant = list[i]
			list.remove_at(i)
			list.insert(clampi(to_index, 0, list.size()), k)
			save()
			return true
	return false


static func restore_defaults() -> void:
	var list: Array = kinds()
	for dk: Dictionary in DEFAULTS:
		if by_id(String(dk["id"])).is_empty():
			list.append(normalised(dk))
	save()
