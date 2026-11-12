extends RefCounted

const Io := preload("res://doc/io.gd")
const MAX_STEPS := 100
const MAX_CLOSED := 10
const MAX_LISTED := 20
const PREF_CLOSED := "ui.window.closed_panels"
const FILE_NAME := "layout_history.json"
const SAVE_VERSION := 1
const KINDS: PackedStringArray = ["snap", "ws"]

var stacks: Dictionary = {}
var closed: Array[Dictionary] = []
var path_override: String = ""
var _closed_loaded: bool = false
var _stacks_loaded: bool = false


func clear() -> void:
	_stacks_loaded = true
	stacks.clear()
	_save()


func store_path() -> String:
	if not path_override.is_empty():
		return path_override
	return Io.data_path("layouts").path_join(FILE_NAME)


func _ensure_loaded() -> void:
	if _stacks_loaded:
		return
	_stacks_loaded = true
	var path: String = store_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != SAVE_VERSION:
		return
	var saved: Variant = (parsed as Dictionary).get("stacks", {})
	if not (saved is Dictionary):
		return
	for ws: Variant in (saved as Dictionary).keys():
		var raw: Variant = (saved as Dictionary)[ws]
		if not (raw is Dictionary) or String(ws).is_empty():
			continue
		var into: Dictionary = {"undo": _valid((raw as Dictionary).get("undo", [])), "redo": _valid((raw as Dictionary).get("redo", []))}
		if stacks.has(ws):
			(into["undo"] as Array).append_array((stacks[ws] as Dictionary)["undo"])
			into["redo"] = (stacks[ws] as Dictionary)["redo"]
		stacks[String(ws)] = into


func _valid(list: Variant) -> Array:
	var out: Array = []
	if not (list is Array):
		return out
	for e: Variant in (list as Array):
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		var kind: String = String(d.get("kind", ""))
		if not KINDS.has(kind):
			continue
		if kind == "snap" and not (d.get("snap", null) is Dictionary):
			continue
		if kind == "ws" and String(d.get("other", "")).is_empty():
			continue
		out.append(d)
	while out.size() > MAX_STEPS:
		out.remove_at(0)
	return out


func _save() -> void:
	var path: String = store_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out: Dictionary = {}
	for ws: Variant in stacks.keys():
		var st: Dictionary = stacks[ws]
		if (st["undo"] as Array).is_empty() and (st["redo"] as Array).is_empty():
			continue
		out[ws] = {"undo": st["undo"], "redo": st["redo"]}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "stacks": out}))
	f.close()


func _stack(ws: String) -> Dictionary:
	_ensure_loaded()
	if not stacks.has(ws):
		stacks[ws] = {"undo": [], "redo": []}
	return stacks[ws]


func push_undo(ws: String, entry: Dictionary, clear_redo: bool = true) -> void:
	var s: Dictionary = _stack(ws)
	var undo: Array = s["undo"]
	undo.append(entry)
	while undo.size() > MAX_STEPS:
		undo.remove_at(0)
	if clear_redo:
		(s["redo"] as Array).clear()
	_save()


func push_redo(ws: String, entry: Dictionary) -> void:
	var redo: Array = _stack(ws)["redo"]
	redo.append(entry)
	while redo.size() > MAX_STEPS:
		redo.remove_at(0)
	_save()


func pop_undo(ws: String) -> Dictionary:
	var undo: Array = _stack(ws)["undo"]
	if undo.is_empty():
		return {}
	var e: Dictionary = undo.pop_back()
	_save()
	return e


func pop_redo(ws: String) -> Dictionary:
	var redo: Array = _stack(ws)["redo"]
	if redo.is_empty():
		return {}
	var e: Dictionary = redo.pop_back()
	_save()
	return e


func can_undo(ws: String) -> bool:
	return not (_stack(ws)["undo"] as Array).is_empty()


func can_redo(ws: String) -> bool:
	return not (_stack(ws)["redo"] as Array).is_empty()


func undo_label(ws: String) -> String:
	var undo: Array = _stack(ws)["undo"]
	if undo.is_empty():
		return ""
	return String((undo[undo.size() - 1] as Dictionary).get("label", ""))


func redo_label(ws: String) -> String:
	var redo: Array = _stack(ws)["redo"]
	if redo.is_empty():
		return ""
	return String((redo[redo.size() - 1] as Dictionary).get("label", ""))


func undo_count(ws: String) -> int:
	return (_stack(ws)["undo"] as Array).size()


func redo_count(ws: String) -> int:
	return (_stack(ws)["redo"] as Array).size()


func labels(ws: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var undo: Array = _stack(ws)["undo"]
	for i: int in range(undo.size() - 1, -1, -1):
		var e: Dictionary = undo[i]
		out.append(String(e.get("label", "")))
		if String(e.get("kind", "")) == "ws" or out.size() >= MAX_LISTED:
			break
	return out


func forget(ws: String) -> void:
	_ensure_loaded()
	stacks.erase(ws)
	for key: Variant in stacks.keys():
		var s: Dictionary = stacks[key]
		for side: String in ["undo", "redo"]:
			var kept_steps: Array = []
			for e: Variant in (s[side] as Array):
				var d: Dictionary = e
				if String(d.get("kind", "")) == "ws" and String(d.get("other", "")) == ws:
					continue
				kept_steps.append(d)
			s[side] = kept_steps
	_save()
	var kept: Array[Dictionary] = []
	for c: Dictionary in closed_list():
		if String(c.get("ws", "")) != ws:
			kept.append(c)
	closed = kept
	_save_closed()


func closed_list() -> Array[Dictionary]:
	if not _closed_loaded:
		_closed_loaded = true
		closed.clear()
		if not Prefs.is_registered(PREF_CLOSED):
			Prefs.register(PREF_CLOSED, {}, {"label": "Recently closed panels", "type": "dict"})
		var raw: Variant = Prefs.get_value(PREF_CLOSED)
		if typeof(raw) == TYPE_DICTIONARY:
			var list: Variant = (raw as Dictionary).get("list", [])
			if typeof(list) == TYPE_ARRAY:
				for e: Variant in list:
					if typeof(e) == TYPE_DICTIONARY and not String((e as Dictionary).get("id", "")).is_empty():
						closed.append(e)
	return closed


func add_closed(entry: Dictionary) -> void:
	var id: String = String(entry.get("id", ""))
	if id.is_empty():
		return
	var kept: Array[Dictionary] = [entry]
	for c: Dictionary in closed_list():
		if String(c.get("id", "")) != id and kept.size() < MAX_CLOSED:
			kept.append(c)
	closed = kept
	_save_closed()


func take_closed(id: String) -> Dictionary:
	var found: Dictionary = {}
	var kept: Array[Dictionary] = []
	for c: Dictionary in closed_list():
		if String(c.get("id", "")) == id and found.is_empty():
			found = c
		else:
			kept.append(c)
	if not found.is_empty():
		closed = kept
		_save_closed()
	return found


func _save_closed() -> void:
	if not Prefs.is_registered(PREF_CLOSED):
		Prefs.register(PREF_CLOSED, {}, {"label": "Recently closed panels", "type": "dict"})
	var list: Array = []
	for c: Dictionary in closed:
		list.append(c)
	Prefs.set_value(PREF_CLOSED, {"list": list})
