extends RefCounted

const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Store := preload("res://doc/region_store.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Regions := preload("res://doc/media_regions.gd")
const CaptureTime := preload("res://modules/core_panels/bin_views/capture_time.gd")
const FILE := "folders.json"
const DIR := "organizer"
const VERSION := 1
const BY_HAND := "hand"
const BY_RECORDED := "recorded"
const ORDERS: PackedStringArray = ["hand", "recorded"]

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _override_path: String = ""


static func path() -> String:
	if not _override_path.is_empty():
		return _override_path
	return Io.data_path(DIR).path_join(FILE)


static func use_path(p: String) -> void:
	_override_path = p
	_loaded = false
	_cache = {}


static func data() -> Dictionary:
	if _loaded:
		return _cache
	var d: Dictionary = Io.read_json(path())
	if d.is_empty() or not (d.get("order") is Dictionary):
		d = {"version": VERSION, "order": {}}
	_cache = d
	_loaded = true
	return _cache


static func save() -> bool:
	var d: Dictionary = data()
	d["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	return Io.write_atomic(path(), JSON.stringify(d, "\t", false, true), false) == OK


static func order_of(kind: String) -> Dictionary:
	var all: Dictionary = data()["order"]
	var v: Variant = all.get(kind, {})
	var o: Dictionary = v if v is Dictionary else {}
	if not ORDERS.has(String(o.get("mode", ""))):
		o["mode"] = BY_RECORDED
	if not (o.get("hand") is Array):
		o["hand"] = []
	all[kind] = o
	return o


static func mode(kind: String) -> String:
	return String(order_of(kind)["mode"])


static func set_mode(kind: String, m: String) -> void:
	if not ORDERS.has(m):
		return
	order_of(kind)["mode"] = m
	save()


static func _files(doc: Project) -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = Store.files()
	for k: Variant in all.keys():
		var e: Variant = all[k]
		if e is Dictionary:
			out[String(k)] = {"path": String((e as Dictionary).get("path", String(k))), "regions": (e as Dictionary).get("regions", []), "facts": e}
	if doc != null:
		for m: MediaItem in doc.media:
			if m.path.is_empty():
				continue
			var key: String = Store.key_of(m.path)
			if not out.has(key) and not m.regions.is_empty():
				out[key] = {"path": m.path, "regions": m.regions, "facts": {"label": m.label, "recorded": m.recorded_at, "duration": m.duration}}
	return out


static func folders(doc: Project = null) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var files: Dictionary = _files(doc)
	for key: Variant in files.keys():
		var seen: Dictionary = {}
		for r: Variant in (files[key] as Dictionary)["regions"]:
			if not (r is Dictionary):
				continue
			var k: String = String((r as Dictionary).get("kind", ""))
			var c: Dictionary = counts.get(k, {"files": 0, "parts": 0, "seconds": 0.0})
			c["parts"] = int(c["parts"]) + 1
			c["seconds"] = float(c["seconds"]) + float((r as Dictionary).get("to", 0.0)) - float((r as Dictionary).get("from", 0.0))
			if not seen.has(k):
				seen[k] = true
				c["files"] = int(c["files"]) + 1
			counts[k] = c
	var out: Array[Dictionary] = []
	for k: Dictionary in Kinds.kinds():
		var id: String = String(k["id"])
		if counts.has(id):
			var c2: Dictionary = counts[id]
			out.append({"kind": id, "name": String(k["name"]), "files": int(c2["files"]), "parts": int(c2["parts"]), "seconds": float(c2["seconds"])})
	return out


static func recorded_of(file_path: String, facts: Dictionary) -> float:
	var r: float = float(facts.get("recorded", -1.0))
	if r >= 0.0:
		return r
	var file_time: int = int(FileAccess.get_modified_time(file_path)) if FileAccess.file_exists(file_path) else 0
	var rec: Dictionary = CaptureTime.recorded(String(facts.get("label", "")), file_path, file_time, float(facts.get("duration", 0.0)), true)
	return float(rec.get("start", -1.0))


static func entries(kind: String, doc: Project = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: Dictionary = _files(doc)
	for key: Variant in files.keys():
		var f: Dictionary = files[key]
		var mine: Array = Regions.of_kind(f["regions"], kind)
		if mine.is_empty():
			continue
		out.append({"key": String(key), "path": String(f["path"]), "regions": mine, "recorded": recorded_of(String(f["path"]), f["facts"]), "label": String((f["facts"] as Dictionary).get("label", String(f["path"]).get_file()))})
	var o: Dictionary = order_of(kind)
	if String(o["mode"]) == BY_HAND:
		var hand: Array = o["hand"]
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ia: int = hand.find(String(a["key"]))
			var ib: int = hand.find(String(b["key"]))
			if ia < 0:
				ia = 1000000
			if ib < 0:
				ib = 1000000
			if ia != ib:
				return ia < ib
			return float(a["recorded"]) < float(b["recorded"])
		)
	else:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if float(a["recorded"]) != float(b["recorded"]):
				return float(a["recorded"]) < float(b["recorded"])
			return String(a["key"]) < String(b["key"])
		)
	return out


static func move(kind: String, key: String, to_index: int, doc: Project = null) -> bool:
	var list: Array[Dictionary] = entries(kind, doc)
	var keys: Array = []
	for e: Dictionary in list:
		keys.append(String(e["key"]))
	var at: int = keys.find(key)
	if at < 0:
		return false
	keys.remove_at(at)
	keys.insert(clampi(to_index, 0, keys.size()), key)
	var o: Dictionary = order_of(kind)
	o["hand"] = keys
	o["mode"] = BY_HAND
	save()
	return true


static func parts(kind: String, doc: Project = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries(kind, doc):
		var n: int = 0
		for r: Variant in e["regions"]:
			n += 1
			out.append({"path": String(e["path"]), "key": String(e["key"]), "label": String(e["label"]), "region": r, "index": n})
	return out
