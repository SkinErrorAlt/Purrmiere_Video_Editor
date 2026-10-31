extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const VIEW_KEY := "view"
const MODE_KEY := "view_mode"
const HOLD := "hold"
const EDGE := 0.000001
const WHY_NONE := "none"
const WHY_RANGE := "range"
const WHY_SAME := "same"
const WHY_OUTSIDE := "outside"
const PREF_KEY_ON_SWITCH := "pairview.key_on_switch"
const PREF_KEY_ON_SWITCH_LABEL := "Pair View: switching a view adds a keyframe"
const PREF_KEY_ON_SWITCH_HINT := "On: pressing a view button writes a hold keyframe at the playhead, so the switch is recorded even when you are not recording. Off: it writes one only when that view is already animated, and otherwise just changes the value. This is one setting for every Pair View, not one per clip."


static func register_prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	if prefs == null:
		return null
	if not bool(prefs.call("is_registered", PREF_KEY_ON_SWITCH)):
		prefs.call("register", PREF_KEY_ON_SWITCH, false, {"label": PREF_KEY_ON_SWITCH_LABEL, "type": "bool", "hint": PREF_KEY_ON_SWITCH_HINT})
	return prefs


static func key_on_switch() -> bool:
	var prefs: Node = register_prefs()
	if prefs == null:
		return false
	return bool(prefs.call("get_value", PREF_KEY_ON_SWITCH))


static func set_key_on_switch(on: bool) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_KEY_ON_SWITCH, on)


static func records(record: bool) -> bool:
	return record or key_on_switch()


static func path_of(uid: String) -> String:
	return "effects." + uid + "." + VIEW_KEY


static func pair_entry(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == ViewMap.PAIR_VIEW_ID and bool(e.get("enabled", true)):
			return e
	return {}


static func covers(c: Clip, t: float) -> bool:
	return c != null and t >= c.start - EDGE and t < c.end() - EDGE


static func fps_of(s: Sequence) -> float:
	return s.fps if s != null and s.fps > 0.0 else 30.0


static func local_at(s: Sequence, c: Clip, t: float) -> float:
	var fps: float = fps_of(s)
	var frame: int = int(round((t - c.start) * fps))
	return clampf(float(frame) / fps, 0.0, maxf(c.duration, 0.0))


static func key_time(c: Clip, e: Dictionary, key: String, u: float) -> float:
	if c.has_method("fx_time"):
		return float(c.call("fx_time", e, key, u))
	return c.param_time("effects." + String(e.get("uid", "")) + "." + key, u)


static func mode_at(c: Clip, e: Dictionary, u: float) -> int:
	var p: Dictionary = ViewMap.prop_of(e, MODE_KEY)
	if not AnimProp.is_animated(p):
		return int(AnimProp.static_value(p))
	return int(AnimProp.evaluate_float(p, key_time(c, e, MODE_KEY, u), maxf(c.duration, 0.0)))


static func value_for(c: Clip, e: Dictionary, index: int, u: float) -> float:
	var count: int = maxi(ViewMap.crop_count(e), 1)
	if mode_at(c, e, u) == 1:
		return (float(index) + 0.5) / float(count)
	return float(index)


static func view_at(c: Clip, e: Dictionary, u: float) -> int:
	if c == null or e.is_empty():
		return -1
	return ViewMap.heard_view_at(ViewMap.changes(e, c), u)


static func shown_view(s: Sequence, c: Clip, e: Dictionary, t: float) -> int:
	if c == null or e.is_empty():
		return -1
	var u: float = local_at(s, c, t) if covers(c, t) else 0.0
	return view_at(c, e, u)


static func pick_clip(s: Sequence, t: float) -> Clip:
	if s == null:
		return null
	var chosen: Clip = null
	for id: String in s.selected_clip_ids:
		var c: Clip = s.clip_by_id(id)
		if c == null or pair_entry(c).is_empty():
			continue
		if covers(c, t):
			return c
		if chosen == null:
			chosen = c
	var under: Clip = under_playhead(s, t)
	if under != null and not pair_entry(under).is_empty():
		return under
	return chosen


static func under_playhead(s: Sequence, t: float) -> Clip:
	if s == null:
		return null
	var first: Clip = null
	for tr: Track in _top_first(s):
		if tr.hidden:
			continue
		for c: Clip in tr.clips_at(t):
			if not tr.is_picture(c) or not covers(c, t):
				continue
			if not c.enabled:
				continue
			if not pair_entry(c).is_empty():
				return c
			if first == null:
				first = c
	return first


static func _top_first(s: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	var pics: Array[Track] = s.picture_tracks()
	for i: int in range(pics.size() - 1, -1, -1):
		out.append(pics[i])
	return out


static func _fail(why: String) -> Dictionary:
	return {"ok": false, "why": why, "anim": {}, "keyed": false, "u": -1.0}


static func plan(s: Sequence, c: Clip, uid: String, index: int, t: float, record: bool) -> Dictionary:
	if c == null:
		return _fail(WHY_NONE)
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID:
		return _fail(WHY_NONE)
	var count: int = maxi(ViewMap.crop_count(e), 1)
	if index < 0 or index >= count:
		return _fail(WHY_RANGE)
	if not ViewMap.grouped(e):
		var one: Dictionary = _plan_prop(s, c, e, VIEW_KEY, MODE_KEY, count, index, t, record)
		if bool(one["ok"]):
			one["path"] = path_of(uid)
			one["more"] = []
		return one
	var place: Vector2i = ViewMap.place_of(e, index)
	if place.x < 0:
		return _fail(WHY_RANGE)
	var u_now: float = local_at(s, c, t) if covers(c, t) else 0.0
	if view_at(c, e, u_now) == index:
		return _fail(WHY_SAME)
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	var key: String = ViewMap.view_key_for(place.x)
	var pv: Dictionary = _plan_prop(s, c, e, key, MODE_KEY, m[place.x].size(), place.y, t, record)
	var pg: Dictionary = _plan_prop(s, c, e, ViewMap.GROUP_KEY, "", m.size(), place.x, t, record)
	var parts: Array[Dictionary] = []
	for pair: Array in [[pv, key], [pg, ViewMap.GROUP_KEY]]:
		var r: Dictionary = pair[0]
		if bool(r["ok"]):
			parts.append({"path": "effects." + uid + "." + String(pair[1]), "anim": r["anim"], "keyed": bool(r["keyed"]), "u": float(r["u"])})
		elif String(r["why"]) != WHY_SAME:
			return r
	if parts.is_empty():
		return _fail(WHY_SAME)
	var first: Dictionary = parts[0]
	var more: Array = []
	for i: int in range(1, parts.size()):
		more.append({"path": parts[i]["path"], "anim": parts[i]["anim"]})
	var keyed: bool = false
	for pt: Dictionary in parts:
		keyed = keyed or bool(pt["keyed"])
	return {"ok": true, "why": "", "anim": first["anim"], "keyed": keyed, "u": float(first["u"]), "path": first["path"], "more": more}


static func plan_group(s: Sequence, c: Clip, uid: String, group: int, t: float, record: bool) -> Dictionary:
	if c == null:
		return _fail(WHY_NONE)
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID:
		return _fail(WHY_NONE)
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	if m.size() < 2 or group < 0 or group >= m.size():
		return _fail(WHY_RANGE)
	var r: Dictionary = _plan_prop(s, c, e, ViewMap.GROUP_KEY, "", m.size(), group, t, record)
	if bool(r["ok"]):
		r["path"] = "effects." + uid + "." + ViewMap.GROUP_KEY
		r["more"] = []
	return r


static func value_in(c: Clip, e: Dictionary, mkey: String, count: int, index: int, u: float) -> float:
	var mode: int = 0
	if not mkey.is_empty():
		var p: Dictionary = ViewMap.prop_of(e, mkey)
		mode = int(AnimProp.static_value(p)) if not AnimProp.is_animated(p) else int(AnimProp.evaluate_float(p, key_time(c, e, mkey, u), maxf(c.duration, 0.0)))
	if mode == 1:
		return (float(index) + 0.5) / float(maxi(count, 1))
	return float(index)


static func _plan_prop(s: Sequence, c: Clip, e: Dictionary, key: String, mkey: String, count: int, index: int, t: float, record: bool) -> Dictionary:
	var cur: Dictionary = ViewMap.prop_of(e, key)
	var keyed: bool = AnimProp.is_animated(cur)
	var uid: String = String(e.get("uid", ""))
	if not keyed and not records(record):
		var u_flat: float = local_at(s, c, t) if covers(c, t) else 0.0
		if ViewMap.heard_view_at(ViewMap.prop_changes(e, c, key, mkey, count), u_flat) == index:
			return _fail(WHY_SAME)
		return {"ok": true, "why": "", "anim": AnimProp.make(value_in(c, e, mkey, count, index, u_flat)), "keyed": false, "u": -1.0}
	if not covers(c, t):
		return _fail(WHY_OUTSIDE)
	var u: float = local_at(s, c, t)
	var before: Array[Dictionary] = ViewMap.prop_changes(e, c, key, mkey, count)
	if ViewMap.heard_view_at(before, u) == index:
		return _fail(WHY_SAME)
	var path: String = "effects." + uid + "." + key
	var kt: float = key_time(c, e, key, u)
	var next: Dictionary = cur.duplicate(true) if keyed else AnimProp.make(AnimProp.static_value(cur))
	var ks: Array[Dictionary] = AnimProp.keys(next)
	var prev: Dictionary = {}
	for k: Dictionary in ks:
		if float(k.get("t", 0.0)) < kt - AnimProp.KEY_TOLERANCE:
			prev = k
	var keep_from: float = 0.0
	var keep: bool = false
	if prev.is_empty():
		keep = u > EDGE
		if keep:
			var v0: int = int((before[0] as Dictionary)["view"]) if not before.is_empty() else 0
			next = _hold_key(next, key_time(c, e, key, 0.0), value_in(c, e, mkey, count, v0, 0.0))
	elif String(prev.get("i", "")) != HOLD:
		keep = true
		var pt: float = float(prev.get("t", 0.0))
		next = AnimProp.set_key_fields(next, pt, {"i": HOLD})
		keep_from = _first_played(c, path, pt)
	if keep:
		for ch: Dictionary in before:
			var cu: float = float(ch["u"])
			if cu > keep_from + EDGE and cu < u - EDGE:
				next = _hold_key(next, key_time(c, e, key, cu), value_in(c, e, mkey, count, int(ch["view"]), cu))
	next = _hold_key(next, kt, value_in(c, e, mkey, count, index, u))
	if next == cur:
		return _fail(WHY_SAME)
	return {"ok": true, "why": "", "anim": next, "keyed": true, "u": u}


static func _hold_key(p: Dictionary, t: float, v: float) -> Dictionary:
	var out: Dictionary = AnimProp.set_key(p, t, v, HOLD)
	return AnimProp.set_key_fields(out, t, {"i": HOLD})


static func _first_played(c: Clip, path: String, kt: float) -> float:
	if not c.path_warped(path):
		return kt
	var times: PackedFloat64Array = c.played_times_for(path, kt)
	if times.is_empty():
		return kt
	var lo: float = times[0]
	for x: float in times:
		lo = minf(lo, x)
	return lo


static func why_text(why: String, view_name: String) -> String:
	if why == WHY_SAME:
		return view_name + " is already on screen"
	if why == WHY_OUTSIDE:
		return "Move the playhead onto the clip to key its view"
	if why == WHY_RANGE:
		return "This Pair View has no view " + view_name
	return "The clip has no Pair View"
