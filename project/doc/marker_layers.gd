extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Marker := preload("res://doc/marker.gd")
const MarkerKinds := preload("res://doc/marker_kinds.gd")
const PREF_LAYERS := "markers.layers"
const PREF_HIDDEN_EXPORT := "markers.hidden_export"
const RULER := ""
const RULER_NAME := "Ruler"
const NEW_NAME := "Markers"
const DEFAULT_LENGTH := 0.8
const HIDDEN := "hidden"
const LOCKED := "locked"
const TARGET := "target"
const HEIGHT := "h"
const ORDER_KEY := "*order"
const HEIGHT_MIN := 14.0
const HEIGHT_MAX := 96.0
const FIELDS: PackedStringArray = ["name", "colour", "rgb", "length", "kind"]

static var honour_layers: bool = true
static var _serial: int = 0
static var _cache_key: String = ""
static var _cache: Array[Dictionary] = []
static var _index: Dictionary = {}
static var _raw_seen: Variant = null


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs == null:
		return null
	if not bool(prefs.call("is_registered", PREF_LAYERS)):
		prefs.call("register", PREF_LAYERS, [], {"label": "Marker layers you keep in every project", "type": "list", "hint": "Made with Make available in every project on a marker lane. Each one is a name, a colour, a default marker length and a default kind."})
	if not bool(prefs.call("is_registered", PREF_HIDDEN_EXPORT)):
		prefs.call("register", PREF_HIDDEN_EXPORT, true, {"label": "Hidden marker layers still count for chapters, scatter sounds, clip cut and text from marks", "type": "bool", "hint": "Hiding a marker layer only hides it from view. Turn this off to leave hidden layers out of everything that reads markers."})
	return prefs


static func bump() -> void:
	_serial += 1


static func clean(v: Variant, global: bool) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	var id: String = str(d.get("id", "")).strip_edges()
	if id.is_empty():
		return {}
	var kind: String = str(d.get("kind", Marker.DEFAULT_KIND))
	if not Marker.KINDS.has(kind):
		kind = Marker.DEFAULT_KIND
	var name: String = str(d.get("name", "")).strip_edges()
	return {
		"id": id,
		"name": name if not name.is_empty() else NEW_NAME,
		"colour": int(d.get("colour", -1)),
		"rgb": Marker.clean_rgb(d.get("rgb", "")),
		"length": maxf(float(d.get("length", DEFAULT_LENGTH)), 0.0),
		"kind": kind,
		"global": global,
	}


static func global_layers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var prefs: Node = register_prefs()
	if prefs == null:
		return out
	var raw: Variant = prefs.call("get_value", PREF_LAYERS)
	if raw is Array:
		var seen: Dictionary = {}
		for e: Variant in raw:
			var l: Dictionary = clean(e, true)
			if not l.is_empty() and not seen.has(l["id"]):
				seen[l["id"]] = true
				out.append(l)
	return out


static func local_layers(seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	for e: Dictionary in seq.marker_layers:
		var l: Dictionary = clean(e, false)
		if not l.is_empty():
			out.append(l)
	return out


static func _key(seq: Sequence) -> String:
	var prefs: Node = prefs_node()
	var raw: Variant = null
	if prefs != null and bool(prefs.call("is_registered", PREF_LAYERS)):
		raw = prefs.call("get_value", PREF_LAYERS)
	if not is_same(raw, _raw_seen):
		_raw_seen = raw
		_serial += 1
	if seq == null:
		return str(_serial)
	return str(_serial) + "|" + str(seq.get_instance_id()) + "|" + str(seq.marker_layers.hash()) + "|" + str(seq.marker_view.hash())


static func layers(seq: Sequence) -> Array[Dictionary]:
	var key: String = _key(seq)
	if key == _cache_key:
		return _cache
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for l: Dictionary in global_layers():
		seen[l["id"]] = true
		out.append(_with_view(seq, l))
	for l: Dictionary in local_layers(seq):
		if seen.has(l["id"]):
			continue
		seen[l["id"]] = true
		out.append(_with_view(seq, l))
	out = _ordered(seq, out)
	_cache = out
	_index = {}
	for l: Dictionary in out:
		_index[l["id"]] = l
	_cache_key = key
	return out


static func index(seq: Sequence) -> Dictionary:
	layers(seq)
	return _index


static func lane_in(idx: Dictionary, m: Marker) -> String:
	if not honour_layers or m.layer.is_empty() or not idx.has(m.layer):
		return RULER
	return m.layer


static func order_of(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var raw: Variant = seq.marker_view.get(ORDER_KEY, [])
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func _ordered(seq: Sequence, list: Array[Dictionary]) -> Array[Dictionary]:
	var order: PackedStringArray = order_of(seq)
	if order.is_empty():
		return list
	var out: Array[Dictionary] = []
	for id: String in order:
		for l: Dictionary in list:
			if String(l["id"]) == id and not out.has(l):
				out.append(l)
	for l: Dictionary in list:
		if not out.has(l):
			out.append(l)
	return out


static func height_of(seq: Sequence, id: String) -> float:
	if seq == null:
		return 0.0
	var v: Variant = seq.marker_view.get(id, null)
	if v is Dictionary:
		return float((v as Dictionary).get(HEIGHT, 0.0))
	return 0.0


static func view_height(seq: Sequence, id: String, h: float) -> Dictionary:
	var view: Dictionary = seq.marker_view.duplicate(true) if seq != null else {}
	var entry: Dictionary = (view[id] as Dictionary).duplicate() if view.get(id) is Dictionary else {}
	if h <= 0.0:
		entry.erase(HEIGHT)
	else:
		entry[HEIGHT] = clampf(h, HEIGHT_MIN, HEIGHT_MAX)
	if entry.is_empty():
		view.erase(id)
	else:
		view[id] = entry
	return view


static func view_order(seq: Sequence, order: PackedStringArray) -> Dictionary:
	var view: Dictionary = seq.marker_view.duplicate(true) if seq != null else {}
	if order.is_empty():
		view.erase(ORDER_KEY)
	else:
		view[ORDER_KEY] = Array(order)
	return view


static func moved_order(seq: Sequence, id: String, to_index: int) -> PackedStringArray:
	var out: PackedStringArray = ids(seq)
	var from: int = out.find(id)
	if from < 0:
		return out
	out.remove_at(from)
	out.insert(clampi(to_index, 0, out.size()), id)
	return out


static func _with_view(seq: Sequence, l: Dictionary) -> Dictionary:
	var out: Dictionary = l.duplicate()
	out[HEIGHT] = height_of(seq, String(l["id"]))
	out[HIDDEN] = view_flag(seq, String(l["id"]), HIDDEN)
	out[LOCKED] = view_flag(seq, String(l["id"]), LOCKED)
	out[TARGET] = view_flag(seq, String(l["id"]), TARGET)
	return out


static func find(seq: Sequence, id: String) -> Dictionary:
	if id.is_empty():
		return {}
	var idx: Dictionary = index(seq)
	return idx[id] if idx.has(id) else {}


static func has_layer(seq: Sequence, id: String) -> bool:
	return not find(seq, id).is_empty()


static func ids(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: Dictionary in layers(seq):
		out.append(String(l["id"]))
	return out


static func view_flag(seq: Sequence, id: String, key: String) -> bool:
	if seq == null:
		return false
	var v: Variant = seq.marker_view.get(id, null)
	return v is Dictionary and bool((v as Dictionary).get(key, false))


static func shown(seq: Sequence, id: String) -> bool:
	return not view_flag(seq, id, HIDDEN)


static func locked(seq: Sequence, id: String) -> bool:
	return view_flag(seq, id, LOCKED)


static func target_of(seq: Sequence) -> String:
	if seq == null:
		return RULER
	for l: Dictionary in layers(seq):
		if bool(l[TARGET]) and not bool(l[LOCKED]):
			return String(l["id"])
	return RULER


static func new_marker_fields(seq: Sequence, given: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if given.has("layer"):
		return out
	var id: String = target_of(seq)
	if id.is_empty():
		return out
	out["layer"] = id
	var kind: String = String(find(seq, id).get("kind", Marker.DEFAULT_KIND))
	if not given.has("kind") and kind != Marker.DEFAULT_KIND:
		out["kind"] = kind
	return out


static func view_targeting(seq: Sequence, id: String, on: bool) -> Dictionary:
	var view: Dictionary = seq.marker_view.duplicate(true) if seq != null else {}
	for k: Variant in view.keys():
		if view[k] is Dictionary:
			var e: Dictionary = (view[k] as Dictionary).duplicate()
			e.erase(TARGET)
			if e.is_empty():
				view.erase(k)
			else:
				view[k] = e
	if on and not id.is_empty():
		var entry: Dictionary = (view[id] as Dictionary).duplicate() if view.get(id) is Dictionary else {}
		entry[TARGET] = true
		view[id] = entry
	return view


static func lane_of(seq: Sequence, m: Marker) -> String:
	if m == null:
		return RULER
	return lane_in(index(seq), m)


static func name_of(seq: Sequence, id: String) -> String:
	if id.is_empty():
		return RULER_NAME
	var l: Dictionary = find(seq, id)
	return String(l["name"]) if not l.is_empty() else RULER_NAME


static func hidden_still_count() -> bool:
	var prefs: Node = register_prefs()
	if prefs == null:
		return true
	return bool(prefs.call("get_value", PREF_HIDDEN_EXPORT))


static func any_hidden(seq: Sequence) -> bool:
	if seq == null:
		return false
	for id: Variant in seq.marker_view.keys():
		if view_flag(seq, String(id), HIDDEN):
			return true
	return false


static func counts(seq: Sequence, m: Marker) -> bool:
	return shown(seq, lane_of(seq, m)) or hidden_still_count()


static func usable(seq: Sequence) -> Array[Marker]:
	var out: Array[Marker] = []
	if seq == null:
		return out
	if not any_hidden(seq) or hidden_still_count():
		out.assign(seq.markers)
		return out
	var idx: Dictionary = index(seq)
	for m: Marker in seq.markers:
		if shown(seq, lane_in(idx, m)):
			out.append(m)
	return out


static func length_of(seq: Sequence, id: String) -> float:
	var l: Dictionary = find(seq, id)
	return float(l["length"]) if not l.is_empty() else 0.0


static func groups_for_text(seq: Sequence, picked: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	var order: PackedStringArray = PackedStringArray()
	var by: Dictionary = {}
	var idx: Dictionary = index(seq)
	for m: Marker in usable(seq):
		if not picked.is_empty() and not picked.has(m.id):
			continue
		if m.kind == "tag" or not MarkerKinds.makes_text(m):
			continue
		var lane: String = lane_in(idx, m)
		if not by.has(lane):
			by[lane] = []
			order.append(lane)
		(by[lane] as Array).append(m.id)
	for lane: String in order:
		out.append({"layer": lane, "ids": PackedStringArray(by[lane] as Array), "length": length_of(seq, lane)})
	return out


static func view_with(seq: Sequence, id: String, key: String, on: bool) -> Dictionary:
	var view: Dictionary = seq.marker_view.duplicate(true) if seq != null else {}
	var entry: Dictionary = (view[id] as Dictionary).duplicate() if view.get(id) is Dictionary else {}
	if on:
		entry[key] = true
	else:
		entry.erase(key)
	if entry.is_empty():
		view.erase(id)
	else:
		view[id] = entry
	return view


static func view_without(seq: Sequence, id: String) -> Dictionary:
	var view: Dictionary = seq.marker_view.duplicate(true) if seq != null else {}
	view.erase(id)
	return view


static func new_layer(id: String, name: String, colour: int = -1, rgb: String = "", length: float = DEFAULT_LENGTH, kind: String = Marker.DEFAULT_KIND) -> Dictionary:
	return clean({"id": id, "name": name, "colour": colour, "rgb": rgb, "length": length, "kind": kind}, false)


static func stored(l: Dictionary) -> Dictionary:
	var out: Dictionary = {"id": String(l.get("id", ""))}
	for k: String in FIELDS:
		if l.has(k):
			out[k] = l[k]
	return out


static func locals_with(seq: Sequence, l: Dictionary) -> Array:
	var out: Array = []
	var put: bool = false
	if seq != null:
		for e: Dictionary in seq.marker_layers:
			if str(e.get("id", "")) == String(l.get("id", "")):
				out.append(stored(l))
				put = true
			else:
				out.append(e.duplicate(true))
	if not put:
		out.append(stored(l))
	return out


static func locals_without(seq: Sequence, id: String) -> Array:
	var out: Array = []
	if seq != null:
		for e: Dictionary in seq.marker_layers:
			if str(e.get("id", "")) != id:
				out.append(e.duplicate(true))
	return out


static func is_global(id: String) -> bool:
	for l: Dictionary in global_layers():
		if String(l["id"]) == id:
			return true
	return false


static func mint_global_id() -> String:
	var taken: Dictionary = {}
	for l: Dictionary in global_layers():
		taken[l["id"]] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var id: String = ""
	while id.is_empty() or taken.has(id):
		id = "g" + String.num_int64(Time.get_unix_time_from_system() as int, 36) + String.num_int64(rng.randi() & 0xffff, 36)
	return id


static func _write_globals(list: Array) -> void:
	var prefs: Node = register_prefs()
	if prefs == null:
		return
	prefs.call("set_value", PREF_LAYERS, list)
	bump()


static func save_global(l: Dictionary) -> void:
	var list: Array = []
	var put: bool = false
	for g: Dictionary in global_layers():
		if String(g["id"]) == String(l.get("id", "")):
			list.append(stored(l))
			put = true
		else:
			list.append(stored(g))
	if not put:
		list.append(stored(l))
	_write_globals(list)


static func forget_global(id: String) -> void:
	var list: Array = []
	for g: Dictionary in global_layers():
		if String(g["id"]) != id:
			list.append(stored(g))
	_write_globals(list)


static var _bk_key: String = ""
static var _bk: Dictionary = {}


static func buckets(seq: Sequence, serial: int) -> Dictionary:
	if seq == null:
		return {}
	var key: String = _key(seq) + "|" + str(serial) + "|" + str(seq.markers.size())
	if key == _bk_key:
		return _bk
	var idx: Dictionary = index(seq)
	var out: Dictionary = {RULER: _bucket()}
	for id: Variant in idx.keys():
		out[id] = _bucket()
	for m: Marker in seq.markers:
		var b: Dictionary = out[lane_in(idx, m)]
		if m.follows():
			(b["followers"] as Array).append(m)
		else:
			(b["list"] as Array).append(m)
	for id: Variant in out.keys():
		var b2: Dictionary = out[id]
		var list: Array = b2["list"]
		var times: PackedFloat64Array = PackedFloat64Array()
		times.resize(list.size())
		var top: float = 0.0
		var sorted: bool = true
		for i: int in list.size():
			var m2: Marker = list[i]
			times[i] = m2.time
			top = maxf(top, m2.duration)
			if i > 0 and times[i] < times[i - 1]:
				sorted = false
		if not sorted:
			list.sort_custom(func(a: Marker, c: Marker) -> bool: return a.time < c.time)
			for i: int in list.size():
				times[i] = (list[i] as Marker).time
		b2["times"] = times
		b2["max"] = top
	_bk = out
	_bk_key = key
	return out


static func _bucket() -> Dictionary:
	return {"list": [], "times": PackedFloat64Array(), "max": 0.0, "followers": []}


static func in_view(b: Dictionary, t0: float, t1: float) -> Array:
	if b.is_empty():
		return []
	var times: PackedFloat64Array = b["times"]
	var list: Array = b["list"]
	var i0: int = times.bsearch(t0 - float(b["max"]), true)
	var i1: int = times.bsearch(t1, false)
	var out: Array = list.slice(i0, i1) if i1 > i0 else []
	var followers: Array = b["followers"]
	if not followers.is_empty():
		out.append_array(followers)
		out.sort_custom(func(a: Marker, c: Marker) -> bool: return a.time < c.time)
	return out
