extends RefCounted

const MAX_STEPS := 100
const MAX_CLOSED := 10
const MAX_LISTED := 20
const PREF_CLOSED := "ui.window.closed_panels"

var stacks: Dictionary = {}
var closed: Array[Dictionary] = []
var _closed_loaded: bool = false


func clear() -> void:
	stacks.clear()


func _stack(ws: String) -> Dictionary:
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


func push_redo(ws: String, entry: Dictionary) -> void:
	var redo: Array = _stack(ws)["redo"]
	redo.append(entry)
	while redo.size() > MAX_STEPS:
		redo.remove_at(0)


func pop_undo(ws: String) -> Dictionary:
	var undo: Array = _stack(ws)["undo"]
	if undo.is_empty():
		return {}
	return undo.pop_back()


func pop_redo(ws: String) -> Dictionary:
	var redo: Array = _stack(ws)["redo"]
	if redo.is_empty():
		return {}
	return redo.pop_back()


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
