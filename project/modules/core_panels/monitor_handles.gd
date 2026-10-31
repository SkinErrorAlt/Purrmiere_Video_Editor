extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const LayoutCmds := preload("res://doc/commands/pair_layout_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const PairCrop := preload("res://engine/pair_crop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const MonitorSnap := preload("res://modules/core_panels/monitor_snap.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PanelBus := preload("res://modules/core_panels/panel_bus.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const EffectHandlesUi := preload("res://modules/core_panels/effect_handles_ui.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const TR_UID := "__transition"
const TR_PREFIX := "transition:"
const CURVE_STEPS := 12
const KIND_EDGES := "edges"
const KIND_QUAD := "quad"
const KIND_POINT := "point"
const KIND_LINE := "line"
const KIND_ANGLE := "angle"
const KIND_PLANE := "plane3d"
const KIND_REGIONS := "regions"
const KIND_RING := "ring"
const KIND_BAND := "band"
const HANDLE := 7.0
const REACH := 3.0
const RING := 6.0
const BAR := 14.0
const SLOP := 3.0
const SPIN_REACH := 56.0
const ANGLE_REACH := 2.0
const SEARCH_STEP := 1.0
const TILT_MAX := 89.0
const INK := Color(0.369, 0.784, 1.0, 1.0)
const LAYER_INK := Color(1.0, 1.0, 1.0, 0.45)
const LABEL_BACK := Color(0.051, 0.055, 0.063, 0.85)
const GROUP := "pm_handle_switch"
const CROP_LABEL := "Crop region"
const SWITCH_TIP := "Handles on the Program monitor: drag this effect's corners, edges and points there. Click again for the clip's own handles"
const EDGE_OF_CORNER: Array = [[0, 1], [2, 1], [2, 3], [0, 3]]
const EDGE_OF_SIDE: PackedInt32Array = [1, 2, 3, 0]
const SIDE_MID: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
const UV_CORNERS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]

static var focus: Dictionary = {}

var drag: Dictionary = {}
var hover: String = ""
var drags: int = 0
var last_curve: PackedVector2Array = PackedVector2Array()
static var plant_effect_paths: bool = false


static func def_for(eid: String) -> Dictionary:
	if eid.begins_with(TR_PREFIX):
		return TransitionRegistry.shared().call("get_def", eid.substr(TR_PREFIX.length()))
	return EffectSource.get_def(eid)


static func path_for(uid: String, key: String) -> String:
	if uid == TR_UID and not plant_effect_paths:
		return TransitionRegistry.param_path(key)
	return "effects." + uid + "." + key


static func transition_entry(c: Clip) -> Dictionary:
	if c == null or not c.has_transition():
		return {}
	var lib: String = TransitionRegistry.library_id(c.transition_in)
	if lib.is_empty() or specs_of(TR_PREFIX + lib).is_empty():
		return {}
	var params: Variant = c.transition_in.get(TransitionRegistry.PARAMS_KEY, {})
	return {"uid": TR_UID, "id": TR_PREFIX + lib, "enabled": true, "params": params if params is Dictionary else {}}


static func focus_transition(clip_id: String, s: Sequence) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if transition_entry(c).is_empty():
		return false
	set_focus(clip_id, TR_UID, true)
	return true


static func transition_switch(c: Clip) -> Button:
	if transition_entry(c).is_empty():
		return null
	var clip_id: String = c.id
	var b: Button = PmButton.make("", "region", true)
	b.name = "TransitionHandles"
	b.set("quiet", true)
	b.button_pressed = focus_of(clip_id) == TR_UID
	PmUI.tip(b, "Handles on the Program monitor: drag this transition's points there while the playhead is inside it")
	b.add_to_group(GROUP)
	b.set_meta("clip_id", clip_id)
	b.set_meta("uid", TR_UID)
	b.toggled.connect(func(on: bool) -> void: set_focus(clip_id, TR_UID, on))
	return b


static func specs_of(eid: String) -> Array:
	var def: Dictionary = def_for(eid)
	if def.is_empty():
		return []
	if eid.begins_with(TR_PREFIX):
		var th: Variant = def.get("handles", [])
		return th if th is Array else []
	if not def.has("handles"):
		return EffectHandlesUi.guess(def)
	var raw: Variant = def.get("handles", [])
	return raw if raw is Array else []


static func has_handles(eid: String) -> bool:
	return not specs_of(eid).is_empty()


static func focus_of(clip_id: String) -> String:
	return String(focus.get(clip_id, ""))


static func crop_mode(clip_id: String, uid: String) -> bool:
	return not uid.is_empty() and focus_of(clip_id) == uid


static func set_focus(clip_id: String, uid: String, on: bool) -> void:
	if on:
		focus[clip_id] = uid
	elif focus_of(clip_id) == uid:
		focus.erase(clip_id)
	_sync_switches()
	_redraw_program()


static func clear_focus() -> void:
	focus.clear()
	_sync_switches()
	_redraw_program()


static func _sync_switches() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(GROUP):
		if n is BaseButton and n.has_meta("clip_id"):
			(n as BaseButton).set_pressed_no_signal(focus_of(String(n.get_meta("clip_id"))) == String(n.get_meta("uid", "")))


static func _redraw_program() -> void:
	var b: RefCounted = PanelBus.instance()
	var p: Object = b.call("panel", "program") if b != null else null
	if p == null:
		return
	var v: Variant = p.get("view")
	if v is Control and (v as Control).has_method("redraw_overlay"):
		(v as Control).call("redraw_overlay")


static func switch_for(c: Clip, e: Dictionary) -> Button:
	if c == null or not has_handles(String(e.get("id", ""))):
		return null
	var uid: String = String(e.get("uid", ""))
	var clip_id: String = c.id
	var b: Button = PmButton.make("", "region", true)
	b.set("quiet", true)
	b.button_pressed = focus_of(clip_id) == uid
	PmUI.tip(b, SWITCH_TIP)
	b.add_to_group(GROUP)
	b.set_meta("clip_id", clip_id)
	b.set_meta("uid", uid)
	b.toggled.connect(func(on: bool) -> void: set_focus(clip_id, uid, on))
	return b


static func pair_default(c: Clip, path: String) -> Variant:
	var parts: PackedStringArray = path.split(".")
	if c == null or parts.size() != 3 or parts[0] != "effects":
		return null
	var e: Dictionary = c.effect_by_uid(parts[1])
	if String(e.get("id", "")) != PairLayout.PAIR_VIEW_ID:
		return null
	var key: String = parts[2]
	if key.begins_with("place") or key.begins_with("size") or key.begins_with(PairCrop.TURN_PREFIX):
		return _param_spec(def_for(PairLayout.PAIR_VIEW_ID), key).get("default", null)
	return null


static func switch_many(clips: Array[Clip], uids: Dictionary) -> Button:
	var eid: String = ""
	var on: bool = not clips.is_empty()
	for c: Clip in clips:
		var uid: String = String(uids.get(c.id, ""))
		eid = String(c.effect_by_uid(uid).get("id", ""))
		on = on and focus_of(c.id) == uid
	if clips.is_empty() or not has_handles(eid):
		return null
	var pairs: Dictionary = {}
	for c2: Clip in clips:
		pairs[c2.id] = String(uids.get(c2.id, ""))
	var b: Button = PmButton.make("", "region", true)
	b.set("quiet", true)
	b.name = "ManyHandles"
	b.button_pressed = on
	PmUI.tip(b, SWITCH_TIP + ". With several clips selected it is set on each of them; the handles show on the clip under the playhead")
	b.toggled.connect(func(want: bool) -> void:
		for cid: Variant in pairs.keys():
			set_focus(String(cid), String(pairs[cid]), want))
	return b


static func add_switch_many(f: Control, clips: Array[Clip], uids: Dictionary) -> void:
	var b: Button = switch_many(clips, uids)
	if b != null and f != null:
		f.call("add_right", b)


static func add_switch(f: Control, c: Clip, e: Dictionary) -> void:
	var b: Button = switch_for(c, e)
	if b != null and f != null:
		f.call("add_right", b)


static func plane_project(uv: Vector2, v: Dictionary, aspect: float) -> Vector2:
	var asp: Vector2 = Vector2(maxf(aspect, 0.0001), 1.0)
	var q1: Vector2 = (uv - Vector2(0.5, 0.5)) * 2.0 * asp
	var y0: float = q1.y + q1.x * float(v.get("skew_y", 0.0))
	var x0: float = q1.x + y0 * float(v.get("skew_x", 0.0))
	var rx: float = deg_to_rad(float(v.get("tilt", 0.0)))
	var ry: float = deg_to_rad(float(v.get("swivel", 0.0)))
	var ax: Vector3 = Vector3(cos(ry), 0.0, sin(ry))
	var ay: Vector3 = Vector3(sin(ry) * sin(rx), cos(rx), -cos(ry) * sin(rx))
	var hit: Vector3 = ax * x0 + ay * y0
	var dist: float = maxf(float(v.get("distance", 1.5)), 0.01)
	var focal: float = maxf(float(v.get("lens", 1.5)), 0.01)
	var w: float = hit.z + dist
	if w <= 0.0001:
		return Vector2(NAN, NAN)
	var p: Vector2 = Vector2(hit.x, hit.y) * focal / w
	return p / asp * 0.5 * float(v.get("scale", 1.0)) + Vector2(0.5, 0.5)


static func plane_sample(out_uv: Vector2, v: Dictionary, aspect: float) -> Vector2:
	if not is_finite(out_uv.x) or not is_finite(out_uv.y):
		return Vector2(NAN, NAN)
	var asp: Vector2 = Vector2(maxf(aspect, 0.0001), 1.0)
	var p: Vector2 = (out_uv - Vector2(0.5, 0.5)) * 2.0 * asp / maxf(float(v.get("scale", 1.0)), 0.01)
	var rx: float = deg_to_rad(float(v.get("tilt", 0.0)))
	var ry: float = deg_to_rad(float(v.get("swivel", 0.0)))
	var dist: float = maxf(float(v.get("distance", 1.5)), 0.01)
	var focal: float = maxf(float(v.get("lens", 1.5)), 0.01)
	var ro: Vector3 = Vector3(0.0, 0.0, -dist)
	var rd: Vector3 = Vector3(p.x, p.y, focal).normalized()
	var ax: Vector3 = Vector3(cos(ry), 0.0, sin(ry))
	var ay: Vector3 = Vector3(sin(ry) * sin(rx), cos(rx), -cos(ry) * sin(rx))
	var nn: Vector3 = Vector3(-sin(ry) * cos(rx), sin(rx), cos(ry) * cos(rx))
	var denom: float = rd.dot(nn)
	if absf(denom) <= 0.0001:
		return Vector2(NAN, NAN)
	var t: float = (-ro).dot(nn) / denom
	if t <= 0.0:
		return Vector2(NAN, NAN)
	var hit: Vector3 = ro + rd * t
	var q: Vector2 = Vector2(hit.dot(ax), hit.dot(ay))
	q.x -= q.y * float(v.get("skew_x", 0.0))
	q.y -= q.x * float(v.get("skew_y", 0.0))
	return q / asp * 0.5 + Vector2(0.5, 0.5)


static func solve_plane(key: String, mid: Vector2, want: Vector2, v: Dictionary, aspect: float, now: float) -> float:
	var best: float = now
	var best_d: float = INF
	var a: float = -TILT_MAX
	var trial: Dictionary = v.duplicate()
	while a <= TILT_MAX + 0.0001:
		trial[key] = a
		var got: Vector2 = plane_project(mid, trial, aspect)
		if not is_nan(got.x):
			var dd: float = got.distance_to(want) + absf(a - now) * 0.00001
			if dd < best_d:
				best_d = dd
				best = a
		a += SEARCH_STEP
	var lo: float = maxf(best - SEARCH_STEP, -TILT_MAX)
	var hi: float = minf(best + SEARCH_STEP, TILT_MAX)
	for i: int in 24:
		var m1: float = lo + (hi - lo) / 3.0
		var m2: float = hi - (hi - lo) / 3.0
		trial[key] = m1
		var g1: Vector2 = plane_project(mid, trial, aspect)
		trial[key] = m2
		var g2: Vector2 = plane_project(mid, trial, aspect)
		var d1: float = g1.distance_to(want) if not is_nan(g1.x) else INF
		var d2: float = g2.distance_to(want) if not is_nan(g2.x) else INF
		if d1 <= d2:
			hi = m2
		else:
			lo = m1
	return clampf((lo + hi) * 0.5, -TILT_MAX, TILT_MAX)


static func _vec2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


static func _param_spec(def: Dictionary, key: String) -> Dictionary:
	for p: Variant in def.get("params", []):
		if p is Dictionary and String((p as Dictionary).get("key", "")) == key:
			return p
	return {}


static func value_of(c: Clip, e: Dictionary, def: Dictionary, key: String, local: float, fps: float) -> Variant:
	var fallback: Variant = _param_spec(def, key).get("default", 0.0)
	var raw: Variant = (e.get("params", {}) as Dictionary).get(key, null)
	if not (raw is Dictionary):
		return fallback
	var path: String = path_for(String(e.get("uid", "")), key)
	return AnimProp.evaluate(raw, c.param_time(path, local), c.duration, fps)


static func _num(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	return fallback


func active() -> bool:
	return not drag.is_empty()


func _allowed(panel: Object) -> bool:
	if Session.tool_id == "type" or Session.tool_id == "hand":
		return false
	var sel: Variant = panel.get("_select")
	if sel is Object and (sel as Object).has_method("outline_on") and not bool((sel as Object).call("outline_on")):
		return false
	var scr: Variant = panel.get("_screens")
	if scr is Object and (scr as Object).has_method("hide_handles") and bool((scr as Object).call("hide_handles")):
		return false
	return true


func focused_entry(panel: Object) -> Dictionary:
	var s0: Sequence = panel.call("seq")
	if s0 != null:
		for cid: Variant in focus.keys():
			if String(focus[cid]) != TR_UID or not s0.selected_clip_ids.has(String(cid)):
				continue
			var tc: Clip = s0.clip_by_id(String(cid))
			var te: Dictionary = transition_entry(tc)
			var span: Vector2 = tc.transition_span() if tc != null else Vector2(-1.0, -1.0)
			if not te.is_empty() and s0.playhead >= span.x - 0.0001 and s0.playhead < span.y:
				return {"clip": tc, "entry": te}
	var c: Clip = panel.call("gizmo_clip")
	if c == null:
		return {}
	var uid: String = focus_of(c.id)
	if uid.is_empty():
		return {}
	if uid == TR_UID:
		return {}
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or not bool(e.get("enabled", true)) or not has_handles(String(e.get("id", ""))):
		return {}
	return {"clip": c, "entry": e}


func hides_motion(panel: Object) -> bool:
	return not focused_entry(panel).is_empty() and _allowed(panel)


func _k(panel: Object, pic: Rect2) -> float:
	var s: Sequence = panel.call("seq")
	return pic.size.x / maxf(float(s.width), 1.0) if s != null else 1.0


func _screen(panel: Object, pic: Rect2, p: Vector2) -> Vector2:
	return panel.call("_to_picture", pic, p)


func _to_seq(panel: Object, pic: Rect2, p: Vector2) -> Vector2:
	return (p - pic.position) / maxf(_k(panel, pic), 0.0001)


func _layer_xf(panel: Object, c: Clip) -> Dictionary:
	var made: Dictionary = panel.call("quad_for", c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4:
		return {}
	var qq: PackedVector2Array = q
	return {"quad": qq, "xf": Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])}


static func _frame_xf(s: Sequence) -> Dictionary:
	if s == null:
		return {}
	var w: float = float(s.width)
	var h: float = float(s.height)
	return {"quad": PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)]), "xf": Transform2D(Vector2(w, 0.0), Vector2(0.0, h), Vector2.ZERO)}


static func curve_points(pts: PackedVector2Array, steps: int) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts.duplicate()
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for j: int in steps:
			var t: float = float(j) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


func _picture_px(panel: Object, c: Clip) -> Vector2:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return PairLayout.picture_size(c, MonitorPick.layer_size(c, m, s, d), Vector2(float(s.width), float(s.height)))


func targets(panel: Object, pic: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fe: Dictionary = focused_entry(panel)
	if fe.is_empty():
		return out
	var s: Sequence = panel.call("seq")
	var c: Clip = fe["clip"]
	var e: Dictionary = fe["entry"]
	var lx: Dictionary = _layer_xf(panel, c) if String(e.get("uid", "")) != TR_UID else _frame_xf(s)
	if s == null or lx.is_empty():
		return out
	var eid: String = String(e.get("id", ""))
	var def: Dictionary = def_for(eid)
	var base: Dictionary = {"clip_id": c.id, "uid": String(e.get("uid", "")), "eid": eid, "label": String(def.get("label", eid)), "colour": INK}
	var local: float = s.playhead - c.start
	var specs: Array = specs_of(eid)
	var px: Vector2 = _picture_px(panel, c) if String(e.get("uid", "")) != TR_UID else Vector2(float(s.width), float(s.height))
	for si: int in specs.size():
		var spec: Variant = specs[si]
		if not (spec is Dictionary):
			continue
		var sd: Dictionary = spec
		var kind: String = String(sd.get("kind", ""))
		if not shown(sd, c, e, def, local, s.fps):
			continue
		if kind == KIND_REGIONS:
			out.append_array(_region_targets(panel, c, e, base, lx["xf"]))
			continue
		var t: Dictionary = base.duplicate()
		t["kind"] = kind
		t["spec"] = sd
		t["spec_index"] = si
		t["xf"] = lx["xf"]
		t["px"] = px
		var ok: bool = false
		match kind:
			KIND_EDGES:
				ok = _edges_target(t, c, e, def, local, s.fps)
			KIND_QUAD:
				ok = _quad_target(t, c, e, def, local, s.fps)
			KIND_POINT, KIND_LINE:
				ok = _point_target(t, c, e, def, local, s.fps)
			KIND_ANGLE:
				ok = _angle_target(t, c, e, def, local, s.fps, _k(panel, pic))
			KIND_PLANE:
				ok = _plane_target(t, c, e, def, local, s.fps, px)
			KIND_RING:
				ok = _ring_target(t, c, e, def, local, s.fps, px)
			KIND_BAND:
				ok = _band_target(t, c, e, def, local, s.fps)
		if ok:
			out.append(t)
	return out


func _corner_handles(t: Dictionary, pts: PackedVector2Array, free: bool) -> void:
	var xf: Transform2D = t["xf"]
	var hs: Array[Dictionary] = []
	var shape: PackedVector2Array = PackedVector2Array()
	for i: int in 4:
		shape.append(xf * pts[i])
	for i: int in 4:
		hs.append({"id": "c" + str(i), "at": shape[i], "look": "square", "name": PairCrop.CORNER_NAMES[i]})
	for i: int in 4:
		var a: Vector2 = shape[i]
		var b: Vector2 = shape[(i + 1) % 4]
		hs.append({"id": "e" + str(i), "at": (a + b) * 0.5, "look": "dot" if free else "bar", "dir": b - a, "name": PairCrop.EDGE_NAMES[EDGE_OF_SIDE[i]]})
	t["handles"] = hs
	t["shape"] = shape
	t["movable"] = true


func _edges_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float) -> bool:
	var sd: Dictionary = t["spec"]
	var keys: PackedStringArray = PackedStringArray([String(sd.get("left", "")), String(sd.get("top", "")), String(sd.get("right", "")), String(sd.get("bottom", ""))])
	var ev: PackedFloat64Array = PackedFloat64Array()
	for k: String in keys:
		ev.append(_num(value_of(c, e, def, k, local, fps), 0.0) if not k.is_empty() else 0.0)
	t["keys"] = keys
	t["values"] = ev
	_corner_handles(t, PairCrop.quad_of_edges(ev), false)
	var hs: Array[Dictionary] = t["handles"]
	var kept: Array[Dictionary] = []
	for h: Dictionary in hs:
		var id: String = String(h["id"])
		if id.begins_with("e") and keys[EDGE_OF_SIDE[int(id.substr(1))]].is_empty():
			continue
		kept.append(h)
	t["handles"] = kept
	return true


func _quad_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float) -> bool:
	var sd: Dictionary = t["spec"]
	var raw: Variant = sd.get("keys", [])
	if not (raw is Array) or (raw as Array).size() != 4:
		return false
	var keys: PackedStringArray = PackedStringArray()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 4:
		var k: String = String((raw as Array)[i])
		keys.append(k)
		pts.append(_vec2(value_of(c, e, def, k, local, fps), UV_CORNERS[i]))
	t["keys"] = keys
	t["points"] = pts
	_corner_handles(t, pts, true)
	var hs: Array[Dictionary] = t["handles"]
	for i: int in 4:
		hs[i]["name"] = String(_param_spec(def, keys[i]).get("label", keys[i]))
	return true


func _point_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float) -> bool:
	var sd: Dictionary = t["spec"]
	var keys: PackedStringArray = PackedStringArray()
	if sd.get("keys") is Array:
		for k: Variant in sd["keys"]:
			keys.append(String(k))
	elif sd.has("key"):
		keys.append(String(sd["key"]))
	if keys.is_empty():
		return false
	var xf: Transform2D = t["xf"]
	var pts: PackedVector2Array = PackedVector2Array()
	var hs: Array[Dictionary] = []
	for i: int in keys.size():
		var p: Vector2 = _vec2(value_of(c, e, def, keys[i], local, fps), Vector2(0.5, 0.5))
		pts.append(p)
		hs.append({"id": "p" + str(i), "at": xf * p, "look": "ring", "name": String(_param_spec(def, keys[i]).get("label", keys[i])), "tip": EffectHandlesUi.point_text(def, keys[i], p)})
	t["keys"] = keys
	t["points"] = pts
	t["handles"] = hs
	t["movable"] = false
	return true


func _angle_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float, k: float) -> bool:
	var sd: Dictionary = t["spec"]
	var key: String = String(sd.get("key", ""))
	if key.is_empty():
		return false
	var about_key: String = String(sd.get("about", ""))
	var about: Vector2 = _vec2(value_of(c, e, def, about_key, local, fps), Vector2(0.5, 0.5)) if not about_key.is_empty() else Vector2(0.5, 0.5)
	var xf: Transform2D = t["xf"]
	var centre: Vector2 = xf * about
	var ang: float = _num(value_of(c, e, def, key, local, fps), 0.0)
	var dir: Vector2 = EffectHandlesUi.arm_dir(xf, ang, sd)
	var len_key: String = String(sd.get("length", ""))
	t["keys"] = PackedStringArray([key]) if len_key.is_empty() else PackedStringArray([key, len_key])
	t["angle"] = ang
	t["centre"] = centre
	t["about_uv"] = about
	var hs: Array[Dictionary] = []
	var tip: Vector2 = centre + dir * (SPIN_REACH / maxf(k, 0.0001))
	var name: String = String(_param_spec(def, key).get("label", key))
	if not len_key.is_empty():
		var px: Vector2 = t.get("px", Vector2.ONE)
		var length: float = _num(value_of(c, e, def, len_key, local, fps), 0.0)
		t["length"] = length
		t["aspect"] = px.x / maxf(px.y, 1.0)
		var end_seq: Vector2 = xf * EffectHandlesUi.arm_end_uv(about, ang, length, sd, float(t["aspect"]), px)
		if end_seq.distance_to(centre) * k >= HANDLE * 2.0:
			tip = end_seq
		name += " and " + String(_param_spec(def, len_key).get("label", len_key))
	var tip_text: String = EffectHandlesUi.value_text(def, key, ang) + ("" if len_key.is_empty() else ", " + EffectHandlesUi.value_text(def, len_key, float(t.get("length", 0.0))))
	hs.append({"id": "spin", "at": tip, "look": "knob", "name": name, "tip": tip_text})
	t["handles"] = hs
	t["movable"] = false
	return true


func _ring_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float, px: Vector2) -> bool:
	var sd: Dictionary = t["spec"]
	var raw_r: Variant = value_of(c, e, def, String(sd.get("key", "")), local, fps)
	var vals: Dictionary = {"r": _vec2(raw_r, Vector2.ZERO) if raw_r is Array or raw_r is Vector2 else _num(raw_r, 0.0)}
	if not String(sd.get("stretch", "")).is_empty():
		vals["st"] = _num(value_of(c, e, def, String(sd["stretch"]), local, fps), 1.0)
	if not String(sd.get("rotate", "")).is_empty():
		vals["rot"] = _num(value_of(c, e, def, String(sd["rotate"]), local, fps), 0.0)
	if not String(sd.get("key_y", "")).is_empty():
		vals["ry"] = _num(value_of(c, e, def, String(sd["key_y"]), local, fps), 0.0)
	if not String(sd.get("feather", "")).is_empty():
		vals["f"] = _num(value_of(c, e, def, String(sd["feather"]), local, fps), 0.0)
	if not String(sd.get("round", "")).is_empty():
		vals["q"] = _num(value_of(c, e, def, String(sd["round"]), local, fps), 1.0)
	if not String(sd.get("shape_from", "")).is_empty():
		vals["pick"] = int(_num(value_of(c, e, def, String(sd["shape_from"]), local, fps), -1.0))
	var about_key: String = String(sd.get("about", ""))
	vals["c"] = _vec2(value_of(c, e, def, about_key, local, fps), Vector2(0.5, 0.5)) if not about_key.is_empty() else _vec2(sd.get("at", null), Vector2(0.5, 0.5))
	if not EffectHandlesUi.ring_target(t, def, vals, px.x / maxf(px.y, 1.0), px):
		return false
	t["keys"] = EffectHandlesUi.ring_keys(sd)
	return true


func _band_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float) -> bool:
	var sd: Dictionary = t["spec"]
	var vals: Dictionary = {"pos": _num(value_of(c, e, def, String(sd.get("key", "")), local, fps), 0.5)}
	if not String(sd.get("width", "")).is_empty():
		vals["w"] = _num(value_of(c, e, def, String(sd["width"]), local, fps), 0.0)
	if not String(sd.get("feather", "")).is_empty():
		vals["f"] = _num(value_of(c, e, def, String(sd["feather"]), local, fps), 0.0)
	var vertical: bool = String(sd.get("axis", "y")) == "x"
	if not String(sd.get("axis_from", "")).is_empty():
		vertical = _num(value_of(c, e, def, String(sd["axis_from"]), local, fps), 0.0) > 0.5
	vals["vertical"] = vertical
	if not EffectHandlesUi.band_target(t, def, vals):
		return false
	t["keys"] = EffectHandlesUi.band_keys(sd)
	return true


static func shown(sd: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float) -> bool:
	var w: Variant = sd.get("when", null)
	if not (w is Dictionary) or String((w as Dictionary).get("key", "")).is_empty():
		return true
	var v: float = _num(value_of(c, e, def, String((w as Dictionary)["key"]), local, fps), 0.0)
	var allowed: Variant = (w as Dictionary).get("is", [])
	if not (allowed is Array):
		return true
	for x: Variant in allowed:
		if absf(_num(x, NAN) - v) < 0.0001:
			return true
	return false


static func _angle_dir(xf: Transform2D, deg: float) -> Vector2:
	var a: float = deg_to_rad(deg)
	var d: Vector2 = xf.x.normalized() * sin(a) - xf.y.normalized() * cos(a)
	return d.normalized() if d.length() > 0.000001 else Vector2.UP


static func _angle_of(xf: Transform2D, v: Vector2) -> float:
	return rad_to_deg(atan2(v.dot(xf.x.normalized()), -v.dot(xf.y.normalized())))


func _plane_values(c: Clip, e: Dictionary, def: Dictionary, sd: Dictionary, local: float, fps: float) -> Dictionary:
	var v: Dictionary = {}
	for name: String in ["tilt", "swivel", "scale", "distance", "lens", "skew_x", "skew_y"]:
		var key: String = String(sd.get(name, ""))
		var fallback: float = 1.0 if name == "scale" else (1.5 if name == "distance" or name == "lens" else 0.0)
		v[name] = _num(value_of(c, e, def, key, local, fps), fallback) if not key.is_empty() else fallback
	return v


func _plane_target(t: Dictionary, c: Clip, e: Dictionary, def: Dictionary, local: float, fps: float, px: Vector2) -> bool:
	var sd: Dictionary = t["spec"]
	var v: Dictionary = _plane_values(c, e, def, sd, local, fps)
	var aspect: float = px.x / maxf(px.y, 1.0)
	var xf: Transform2D = t["xf"]
	var shape: PackedVector2Array = PackedVector2Array()
	for uv: Vector2 in UV_CORNERS:
		var o: Vector2 = plane_project(uv, v, aspect)
		if is_nan(o.x):
			return false
		shape.append(xf * o)
	var hs: Array[Dictionary] = []
	for i: int in 4:
		hs.append({"id": "c" + str(i), "at": shape[i], "look": "square", "name": "Scale"})
	for i: int in 4:
		var key: String = "tilt" if i % 2 == 0 else "swivel"
		if String(sd.get(key, "")).is_empty():
			continue
		var o2: Vector2 = plane_project(SIDE_MID[i], v, aspect)
		if is_nan(o2.x):
			continue
		hs.append({"id": "e" + str(i), "at": xf * o2, "look": "cross", "name": "Tilt" if key == "tilt" else "Swivel"})
	t["values"] = v
	t["aspect"] = aspect
	t["shape"] = shape
	t["handles"] = hs
	t["centre"] = xf * plane_project(Vector2(0.5, 0.5), v, aspect)
	t["movable"] = false
	return true


func _region_targets(panel: Object, c: Clip, e: Dictionary, base: Dictionary, layer: Transform2D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	var map: Dictionary = ViewMap.of(e)
	for b: Dictionary in PairLayout.region_boxes(c, e, s.playhead, LayoutCmds.frame_px(s), LayoutCmds.source_px(d, s, c), s.fps):
		var index: int = int(b["index"])
		if index < 0 or index >= crops.size():
			continue
		var cr: Rect2 = (crops[index] as Dictionary)["rect"]
		var cut: Variant = PairCrop.cut_of(e, index)
		var t: Dictionary = base.duplicate()
		t["kind"] = KIND_REGIONS
		t["index"] = index
		t["cut"] = cut
		t["free"] = PairCrop.is_free(cut)
		t["values"] = PairCrop.edges(cut)
		t["points"] = PairCrop.quad(cut)
		t["xf"] = layer * PairCrop.region_frame(b, cr)
		t["colour"] = Tk.label_colour(ViewMap.colour_for(map, index))
		var nm: String = String(b.get("name", ""))
		t["name"] = nm if not nm.strip_edges().is_empty() else "View " + str(index + 1)
		_corner_handles(t, t["points"], bool(t["free"]))
		out.append(t)
	return out


static func _reach_of(look: String) -> float:
	if look == "ring":
		return RING + REACH
	if look.begins_with("knob"):
		return EffectHandlesUi.KNOB + REACH
	return HANDLE + REACH


func _nearest(panel: Object, pic: Rect2, ts: Array[Dictionary], at: Vector2, wide: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for ti: int in ts.size():
		for h: Dictionary in (ts[ti]["handles"] as Array):
			var dd: float = at.distance_to(_screen(panel, pic, h["at"]))
			if dd <= maxf(_reach_of(String(h["look"])), wide) and dd < best_d:
				best_d = dd
				best = {"target": ts[ti], "handle": String(h["id"]), "name": String(h.get("name", "")), "key": str(ti) + ":" + String(h["id"]), "at": h["at"]}
	return best


func hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	var ts: Array[Dictionary] = targets(panel, pic)
	var close: Dictionary = _nearest(panel, pic, ts, at, 0.0)
	if not close.is_empty():
		return close
	for ti3: int in ts.size():
		var rt: Dictionary = ts[ti3]
		if String(rt["kind"]) == KIND_RING and String((rt["spec"] as Dictionary).get("key_y", "")).is_empty() and not bool((rt["ring"] as Dictionary).get("pair", false)):
			if EffectHandlesUi.near_line(rt, at, func(p: Vector2) -> Vector2: return _screen(panel, pic, p), REACH + 2.0):
				return {"target": rt, "handle": "r", "name": EffectHandlesUi.label_of(def_for(String(rt["eid"])), String((rt["spec"] as Dictionary).get("key", ""))), "key": str(ti3) + ":r", "at": _to_seq(panel, pic, at)}
	for ti4: int in ts.size():
		var bt: Dictionary = ts[ti4]
		if String(bt["kind"]) != KIND_BAND:
			continue
		var bh: String = EffectHandlesUi.near_lines(bt, at, func(p: Vector2) -> Vector2: return _screen(panel, pic, p), REACH + 2.0)
		if not bh.is_empty():
			var bk: String = EffectHandlesUi.band_key_of(bt["spec"], bh)
			return {"target": bt, "handle": bh, "name": EffectHandlesUi.label_of(def_for(String(bt["eid"])), bk), "key": str(ti4) + ":" + bh, "at": _to_seq(panel, pic, at)}
	for ti2: int in ts.size():
		var t: Dictionary = ts[ti2]
		if not bool(t.get("movable", false)):
			continue
		var sq: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in (t["shape"] as PackedVector2Array):
			sq.append(_screen(panel, pic, p))
		if Geometry2D.is_point_in_polygon(at, sq):
			return {"target": t, "handle": "in", "name": String(t.get("name", t.get("label", ""))), "key": str(ti2) + ":in"}
	return _nearest(panel, pic, ts, at, EffectHandlesUi.PICK_REACH)


func _keeps_focus(panel: Object) -> bool:
	var fe: Dictionary = focused_entry(panel)
	if fe.is_empty():
		return true
	for spec: Variant in specs_of(String((fe["entry"] as Dictionary).get("id", ""))):
		if spec is Dictionary and String((spec as Dictionary).get("kind", "")) == KIND_REGIONS:
			return true
	return false


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not e.pressed or e.echo or e.keycode != KEY_ESCAPE:
		return false
	var fe: Dictionary = focused_entry(panel)
	if fe.is_empty():
		return false
	if active():
		cancel(panel)
	else:
		set_focus((fe["clip"] as Clip).id, String((fe["entry"] as Dictionary).get("uid", "")), false)
	var view: Variant = panel.get("view")
	if view is Control:
		(view as Control).call("redraw_overlay")
	return true


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not _allowed(panel):
		return false
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and drag.is_empty():
			var fe: Dictionary = focused_entry(panel)
			if fe.is_empty() or view == null:
				return false
			EffectHandlesUi.open_menu(view, mb.global_position, (fe["clip"] as Clip).id)
			view.accept_event()
			return true
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			var h: Dictionary = hit(panel, pic, mb.position)
			if h.is_empty():
				if not _keeps_focus(panel):
					var fe2: Dictionary = focused_entry(panel)
					set_focus((fe2["clip"] as Clip).id, String((fe2["entry"] as Dictionary).get("uid", "")), false)
				return false
			_begin(panel, pic, h, mb)
			if view != null:
				view.accept_event()
				view.call("redraw_overlay")
			return true
		if drag.is_empty():
			return false
		_end(panel)
		if view != null:
			view.accept_event()
			view.call("redraw_overlay")
		return true
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if drag.is_empty():
			var h2: Dictionary = hit(panel, pic, mm.position)
			var now: String = String(h2.get("key", ""))
			if now != hover:
				hover = now
				if view != null:
					view.call("redraw_overlay")
			return false
		_motion(panel, pic, mm)
		if view != null:
			view.accept_event()
			view.call("redraw_overlay")
		return true
	return false


func _begin(panel: Object, pic: Rect2, h: Dictionary, mb: InputEventMouseButton) -> void:
	var t: Dictionary = h["target"]
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var c: Clip = s.clip_by_id(String(t["clip_id"]))
	var bus: Object = panel.call("bus")
	var key_at: Dictionary = {}
	var uid: String = String(t["uid"])
	for k: Variant in t.get("keys", PackedStringArray()):
		var path: String = path_for(uid, String(k))
		key_at[path] = float(bus.call("key_time_for", c, path, s.playhead)) if bus != null and not String(k).is_empty() else -1.0
	var handle: String = String(h["handle"])
	var name: String = String(h.get("name", ""))
	var label: String = CROP_LABEL if String(t["kind"]) == KIND_REGIONS else String(t["label"]) + ": " + (name if handle != "in" else "Move")
	drag = {"target": t, "handle": handle, "press": mb.position, "press_seq": _to_seq(panel, pic, mb.position), "open": false, "key_at": key_at, "label": label, "chip": "", "free": bool(t.get("free", false)), "pointer": mb.position, "grab": h.get("at", _to_seq(panel, pic, mb.position))}
	drags += 1
	EffectHandlesUi.highlight(panel, uid, _handle_key(t, handle))
	var snap: RefCounted = panel.call("snapper")
	if snap != null and c != null:
		snap.call("begin", c, s, d, pic, {"press": mb.position, "centre": mb.position, "pos": Vector2.ZERO}, Callable(panel, "_pick_quad"), Callable(), panel.get("view"))
		_add_own_lines(snap, panel, c)


static func _handle_key(t: Dictionary, handle: String) -> String:
	var keys: PackedStringArray = t.get("keys", PackedStringArray())
	if keys.is_empty():
		return ""
	var kind: String = String(t.get("kind", ""))
	if kind == KIND_BAND:
		return EffectHandlesUi.band_key_of(t["spec"], handle)
	if kind == KIND_RING:
		var sd: Dictionary = t["spec"]
		var field: String = "key"
		if handle == "ry":
			field = "key_y"
		elif handle == "f":
			field = "feather"
		elif handle == "q":
			field = "round"
		return String(sd.get(field, ""))
	if (kind == KIND_POINT or kind == KIND_LINE or kind == KIND_QUAD) and handle.length() >= 2 and handle.substr(1).is_valid_int():
		var i: int = int(handle.substr(1))
		if i >= 0 and i < keys.size():
			return keys[i]
	for k: String in keys:
		if not k.is_empty():
			return k
	return ""


func _add_own_lines(snap: RefCounted, panel: Object, c: Clip) -> void:
	var lx: Dictionary = _layer_xf(panel, c)
	if lx.is_empty():
		return
	var box: Rect2 = MonitorSnap.box_of(lx["quad"])
	var xs: PackedFloat64Array = snap.get("xs")
	var xk: PackedStringArray = snap.get("x_kinds")
	var ys: PackedFloat64Array = snap.get("ys")
	var yk: PackedStringArray = snap.get("y_kinds")
	for vx: float in [box.position.x, box.get_center().x, box.end.x]:
		xs.append(vx)
		xk.append("clip")
	for vy: float in [box.position.y, box.get_center().y, box.end.y]:
		ys.append(vy)
		yk.append("clip")
	var sx: Array = MonitorSnap.sort_lines(xs, xk)
	var sy: Array = MonitorSnap.sort_lines(ys, yk)
	snap.set("xs", sx[0])
	snap.set("x_kinds", sx[1])
	snap.set("ys", sy[0])
	snap.set("y_kinds", sy[1])


func _clear_guides(snap: RefCounted) -> void:
	if snap == null:
		return
	(snap.get("guides") as Array).clear()
	snap.set("chip", "")
	snap.set("cross", false)


func _snap_point(snap: RefCounted, p: Vector2, axes: Vector2i, k: float, skip: bool) -> Vector2:
	if snap == null or skip or not MonitorSnap.is_on() or not bool(snap.get("active")):
		return p
	var reach: float = MonitorSnap.distance_px() / maxf(k, 0.0001)
	var out: Vector2 = p
	var guides: Array = snap.get("guides")
	if axes.x == 1:
		var xs: PackedFloat64Array = snap.get("xs")
		var hx: Dictionary = MonitorSnap.nearest(PackedFloat64Array([p.x]), xs, reach)
		if bool(hx["found"]):
			out.x = xs[int(hx["index"])]
			guides.append({"axis": "x", "at": out.x, "kind": ""})
	if axes.y == 1:
		var ys: PackedFloat64Array = snap.get("ys")
		var hy: Dictionary = MonitorSnap.nearest(PackedFloat64Array([p.y]), ys, reach)
		if bool(hy["found"]):
			out.y = ys[int(hy["index"])]
			guides.append({"axis": "y", "at": out.y, "kind": ""})
	return out


func _snap_shift(snap: RefCounted, pts: PackedVector2Array, delta: Vector2, k: float, skip: bool) -> Vector2:
	if snap == null or skip or not MonitorSnap.is_on() or not bool(snap.get("active")):
		return delta
	var box: Rect2 = MonitorSnap.box_of(pts)
	box.position += delta
	var reach: float = MonitorSnap.distance_px() / maxf(k, 0.0001)
	var out: Vector2 = delta
	var guides: Array = snap.get("guides")
	var xs: PackedFloat64Array = snap.get("xs")
	var hx: Dictionary = MonitorSnap.nearest(PackedFloat64Array([box.position.x, box.get_center().x, box.end.x]), xs, reach)
	if bool(hx["found"]):
		out.x += float(hx["delta"])
		guides.append({"axis": "x", "at": xs[int(hx["index"])], "kind": ""})
	var ys: PackedFloat64Array = snap.get("ys")
	var hy: Dictionary = MonitorSnap.nearest(PackedFloat64Array([box.position.y, box.get_center().y, box.end.y]), ys, reach)
	if bool(hy["found"]):
		out.y += float(hy["delta"])
		guides.append({"axis": "y", "at": ys[int(hy["index"])], "kind": ""})
	return out


static func _axis_of(dir: Vector2) -> Vector2i:
	return Vector2i(1, 0) if absf(dir.x) >= absf(dir.y) else Vector2i(0, 1)


func _motion(panel: Object, pic: Rect2, mm: InputEventMouseMotion) -> void:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var t: Dictionary = drag["target"]
	var c: Clip = s.clip_by_id(String(t["clip_id"])) if s != null else null
	if c == null or d == null:
		return
	var press: Vector2 = drag["press"]
	if not bool(drag["open"]):
		if mm.position.distance_to(press) < SLOP:
			return
		drag["open"] = true
	drag["pointer"] = mm.position
	var snap: RefCounted = panel.call("snapper")
	_clear_guides(snap)
	var k: float = _k(panel, pic)
	var skip: bool = MonitorSnap.bypass(mm)
	var seq_p: Vector2 = _to_seq(panel, pic, mm.position)
	match String(t["kind"]):
		KIND_EDGES:
			_drag_edges(d, s, c, t, seq_p, snap, k, skip, mm)
		KIND_QUAD:
			_drag_quad(d, s, c, t, seq_p, snap, k, skip)
		KIND_POINT, KIND_LINE:
			_drag_point(d, s, c, t, seq_p, snap, k, skip, mm)
		KIND_ANGLE:
			_drag_angle(d, s, c, t, seq_p, snap, pic, panel, skip, mm)
		KIND_PLANE:
			_drag_plane(d, s, c, t, seq_p, snap, k, skip, mm)
		KIND_REGIONS:
			_drag_region(d, s, c, t, seq_p, snap, k, skip, mm)
		KIND_RING:
			_drag_ring(d, s, c, t, seq_p)
		KIND_BAND:
			_drag_band(d, s, c, t, seq_p)


func _edges_from(t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool) -> PackedFloat64Array:
	var xf: Transform2D = t["xf"]
	var inv: Transform2D = xf.affine_inverse()
	var ev: PackedFloat64Array = (t["values"] as PackedFloat64Array).duplicate()
	var handle: String = String(drag["handle"])
	if handle == "in":
		var lq: PackedVector2Array = PairCrop.quad_of_edges(ev)
		var shape: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in lq:
			shape.append(xf * p)
		var moved: Vector2 = _snap_shift(snap, shape, seq_p - Vector2(drag["press_seq"]), k, skip)
		var dl: Vector2 = inv.basis_xform(moved)
		dl.x = clampf(dl.x, -ev[0], ev[2])
		dl.y = clampf(dl.y, -ev[1], ev[3])
		return PackedFloat64Array([ev[0] + dl.x, ev[1] + dl.y, ev[2] - dl.x, ev[3] - dl.y])
	var axes: Vector2i = Vector2i.ONE
	if handle.begins_with("e"):
		var side: int = int(handle.substr(1))
		axes = _axis_of(xf.y if side % 2 == 0 else xf.x)
	var lp: Vector2 = inv * _snap_point(snap, seq_p, axes, k, skip)
	var sides: Array = []
	if handle.begins_with("c"):
		sides = EDGE_OF_CORNER[int(handle.substr(1))]
	elif handle.begins_with("e"):
		sides = [EDGE_OF_SIDE[int(handle.substr(1))]]
	for side2: Variant in sides:
		match int(side2):
			0:
				ev[0] = lp.x
			1:
				ev[1] = lp.y
			2:
				ev[2] = 1.0 - lp.x
			3:
				ev[3] = 1.0 - lp.y
	return ev


func _drag_edges(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool, _mm: InputEventMouseMotion) -> void:
	var ev: PackedFloat64Array = _edges_from(t, seq_p, snap, k, skip)
	var tidy: Array = PairCrop.tidy_edges(ev)
	var keys: PackedStringArray = t["keys"]
	var parts: PackedStringArray = PackedStringArray()
	for i: int in 4:
		if keys[i].is_empty():
			continue
		if absf(float(tidy[i]) - (t["values"] as PackedFloat64Array)[i]) > 0.0000001 or drag.get("wrote", {}).has(keys[i]):
			_write(d, s, c, path_for(String(t["uid"]), keys[i]), float(tidy[i]))
			parts.append(PairCrop.EDGE_NAMES[i] + " " + str(snappedf(float(tidy[i]) * 100.0, 0.1)) + " %")
	drag["chip"] = ", ".join(parts)


func _quad_from(t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool) -> PackedVector2Array:
	var xf: Transform2D = t["xf"]
	var inv: Transform2D = xf.affine_inverse()
	var pts: PackedVector2Array = (t["points"] as PackedVector2Array).duplicate()
	var handle: String = String(drag["handle"])
	if handle.begins_with("c"):
		pts[int(handle.substr(1))] = inv * _snap_point(snap, seq_p, Vector2i.ONE, k, skip)
		return pts
	var moving: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
	if handle.begins_with("e"):
		var i: int = int(handle.substr(1))
		moving = PackedInt32Array([i, (i + 1) % 4])
	var shape: PackedVector2Array = PackedVector2Array()
	for j: int in moving:
		shape.append(xf * pts[j])
	var moved: Vector2 = _snap_shift(snap, shape, seq_p - Vector2(drag["press_seq"]), k, skip)
	var dl: Vector2 = inv.basis_xform(moved)
	for j2: int in moving:
		pts[j2] = pts[j2] + dl
	return pts


func _drag_quad(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool) -> void:
	var pts: PackedVector2Array = _quad_from(t, seq_p, snap, k, skip)
	var keys: PackedStringArray = t["keys"]
	var def: Dictionary = def_for(String(t["eid"]))
	var was: PackedVector2Array = t["points"]
	for i: int in 4:
		if pts[i].distance_to(was[i]) > 0.0000001 or drag.get("wrote", {}).has(keys[i]):
			var v: Vector2 = _clamp_vec2(def, keys[i], pts[i])
			_write(d, s, c, path_for(String(t["uid"]), keys[i]), [v.x, v.y])
	var handle: String = String(drag["handle"])
	drag["chip"] = String(drag.get("label", "")).get_slice(": ", 1) if handle.begins_with("c") else ""


static func _clamp_vec2(def: Dictionary, key: String, v: Vector2) -> Vector2:
	var p: Dictionary = _param_spec(def, key)
	if p.is_empty():
		return v
	var lo: float = float(p.get("min", 0.0))
	var hi: float = float(p.get("max", 1.0))
	if hi <= lo:
		return v
	return Vector2(clampf(v.x, lo, hi), clampf(v.y, lo, hi))


func _drag_point(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool, mm: InputEventMouseMotion) -> void:
	var xf: Transform2D = t["xf"]
	var i: int = int(String(drag["handle"]).substr(1))
	var keys: PackedStringArray = t["keys"]
	if i < 0 or i >= keys.size():
		return
	var start: Vector2 = xf * (t["points"] as PackedVector2Array)[i]
	var want: Vector2 = start + seq_p - Vector2(drag["press_seq"])
	var axes: Vector2i = Vector2i.ONE
	if mm.shift_pressed:
		var along_x: bool = absf(want.x - start.x) >= absf(want.y - start.y)
		want = Vector2(want.x, start.y) if along_x else Vector2(start.x, want.y)
		axes = Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var p: Vector2 = xf.affine_inverse() * _snap_point(snap, want, axes, k, skip)
	var def: Dictionary = def_for(String(t["eid"]))
	var v: Vector2 = _clamp_vec2(def, keys[i], p)
	_write(d, s, c, path_for(String(t["uid"]), keys[i]), [v.x, v.y])
	drag["chip"] = EffectHandlesUi.point_text(def, keys[i], v)


func _drag_ring(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2) -> void:
	var xf: Transform2D = t["xf"]
	var want: Vector2 = Vector2(drag["grab"]) + seq_p - Vector2(drag["press_seq"])
	var got: Dictionary = EffectHandlesUi.ring_drag(t, def_for(String(t["eid"])), String(drag["handle"]), xf.affine_inverse() * want)
	var values: Dictionary = got["values"]
	for key: Variant in values.keys():
		var v: Variant = values[key]
		_write(d, s, c, path_for(String(t["uid"]), String(key)), v if v is Array else float(v))
	drag["chip"] = String(got["chip"])


func _drag_band(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2) -> void:
	var inv: Transform2D = (t["xf"] as Transform2D).affine_inverse()
	var grab: Vector2 = drag["grab"]
	var want: Vector2 = grab + seq_p - Vector2(drag["press_seq"])
	var got: Dictionary = EffectHandlesUi.band_drag(t, def_for(String(t["eid"])), String(drag["handle"]), inv * want, inv * grab)
	var values: Dictionary = got["values"]
	for key: Variant in values.keys():
		_write(d, s, c, path_for(String(t["uid"]), String(key)), float(values[key]))
	drag["chip"] = String(got["chip"])


func _drag_angle(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, pic: Rect2, panel: Object, skip: bool, mm: InputEventMouseMotion) -> void:
	var xf: Transform2D = t["xf"]
	var centre: Vector2 = t["centre"]
	var sd: Dictionary = t["spec"]
	var a0: float = EffectHandlesUi.arm_angle(xf, Vector2(drag["press_seq"]) - centre, sd)
	var a1: float = EffectHandlesUi.arm_angle(xf, seq_p - centre, sd)
	var nr: float = float(t["angle"]) + wrapf(a1 - a0, -180.0, 180.0)
	var len_text: String = ""
	if t.has("length"):
		var def0: Dictionary = def_for(String(t["eid"]))
		var len_key: String = String(sd.get("length", ""))
		var want: Vector2 = Vector2(drag["grab"]) + seq_p - Vector2(drag["press_seq"])
		var arm: Dictionary = EffectHandlesUi.arm_from_uv(t["about_uv"], xf.affine_inverse() * want, sd, float(t["aspect"]), t.get("px", Vector2.ONE))
		var nl: float = EffectHandlesUi.clamp_value(def0, len_key, float(arm["length"]))
		if want.distance_to(centre) * _k(panel, pic) >= HANDLE:
			nr = float(t["angle"]) + wrapf(float(arm["angle"]) - float(t["angle"]), -180.0, 180.0)
		_write(d, s, c, path_for(String(t["uid"]), len_key), nl)
		len_text = ", " + EffectHandlesUi.value_text(def0, len_key, nl)
	if mm.shift_pressed:
		nr = round(nr / MonitorSnap.ANGLE_STEP) * MonitorSnap.ANGLE_STEP
	elif snap != null:
		var radius: float = mm.position.distance_to(_screen(panel, pic, centre))
		nr = float(snap.call("rotate", nr, false, radius, mm.position, skip))
	var def: Dictionary = def_for(String(t["eid"]))
	var key: String = (t["keys"] as PackedStringArray)[0]
	var p: Dictionary = _param_spec(def, key)
	var lo: float = float(p.get("min", -180.0))
	var hi: float = float(p.get("max", 180.0))
	if hi - lo >= 359.9:
		nr = wrapf(nr, lo, lo + 360.0) if lo >= -180.0 else nr
	nr = clampf(nr, lo, hi)
	_write(d, s, c, path_for(String(t["uid"]), key), nr)
	drag["chip"] = String(p.get("label", key)) + " " + str(snappedf(nr, 0.1)) + " deg" + len_text


func _drag_plane(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool, mm: InputEventMouseMotion) -> void:
	var sd: Dictionary = t["spec"]
	var v: Dictionary = t["values"]
	var xf: Transform2D = t["xf"]
	var aspect: float = float(t["aspect"])
	var handle: String = String(drag["handle"])
	var def: Dictionary = def_for(String(t["eid"]))
	var uid: String = String(t["uid"])
	if handle.begins_with("c"):
		var key_s: String = String(sd.get("scale", ""))
		if key_s.is_empty():
			return
		var centre: Vector2 = t["centre"]
		var from: float = Vector2(drag["press_seq"]).distance_to(centre)
		var f: float = seq_p.distance_to(centre) / from if from > 0.0001 else 1.0
		var s0: float = float(v["scale"])
		var ns: float = s0 * f
		if not skip and MonitorSnap.is_on() and absf(ns - 1.0) / maxf(s0, 0.0001) * from * k <= MonitorSnap.distance_px():
			ns = 1.0
			if snap != null:
				snap.set("chip", "100%")
				snap.set("chip_at", mm.position + MonitorSnap.CHIP_GAP)
		var ps: Dictionary = _param_spec(def, key_s)
		ns = clampf(ns, float(ps.get("min", 0.1)), float(ps.get("max", 4.0)))
		_write(d, s, c, path_for(uid, key_s), ns)
		drag["chip"] = "Scale " + str(snappedf(ns * 100.0, 0.1)) + " %"
		return
	var side: int = int(handle.substr(1))
	var name: String = "tilt" if side % 2 == 0 else "swivel"
	var key: String = String(sd.get(name, ""))
	if key.is_empty():
		return
	var want: Vector2 = xf.affine_inverse() * seq_p
	var got: float = solve_plane(name, SIDE_MID[side], want, v, aspect, float(v[name]))
	if mm.shift_pressed:
		got = round(got / MonitorSnap.ANGLE_STEP) * MonitorSnap.ANGLE_STEP
	elif not skip and MonitorSnap.is_on():
		var near: Dictionary = MonitorSnap.snap_angle(got, ANGLE_REACH)
		if bool(near["found"]):
			got = float(near["value"])
	var p: Dictionary = _param_spec(def, key)
	got = clampf(got, float(p.get("min", -TILT_MAX)), float(p.get("max", TILT_MAX)))
	_write(d, s, c, path_for(uid, key), got)
	drag["chip"] = ("Tilt " if name == "tilt" else "Swivel ") + str(snappedf(got, 0.1)) + " deg"


func _drag_region(d: Project, s: Sequence, c: Clip, t: Dictionary, seq_p: Vector2, snap: RefCounted, k: float, skip: bool, mm: InputEventMouseMotion) -> void:
	var handle: String = String(drag["handle"])
	if mm.alt_pressed and handle.begins_with("c"):
		drag["free"] = true
	var cut: Variant = null
	if bool(drag["free"]):
		cut = PairCrop.tidy_quad(_quad_from(t, seq_p, snap, k, skip))
	else:
		cut = PairCrop.as_edges(PackedFloat64Array(PairCrop.tidy_edges(_edges_from(t, seq_p, snap, k, skip))))
	var e: Dictionary = c.effect_by_uid(String(t["uid"]))
	var text: String = PairCrop.text_with_cut(PairCrop.crops_text(e), int(t["index"]), cut)
	if text == PairCrop.crops_text(e):
		return
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, LayoutCmds.path_of(String(t["uid"]), "crops"), AnimProp.make(text))
	cmd.label = CROP_LABEL
	d.undo.live(cmd)
	var ev: PackedFloat64Array = PairCrop.edges(cut)
	drag["chip"] = String(t.get("name", "")) + ": " + ("four corners" if bool(drag["free"]) else "L %s, T %s, R %s, B %s" % [str(snappedf(ev[0] * 100.0, 0.1)), str(snappedf(ev[1] * 100.0, 0.1)), str(snappedf(ev[2] * 100.0, 0.1)), str(snappedf(ev[3] * 100.0, 0.1))])


func _write(d: Project, s: Sequence, c: Clip, path: String, value: Variant) -> void:
	var wrote: Dictionary = drag.get("wrote", {})
	wrote[path.get_slice(".", path.count("."))] = true
	drag["wrote"] = wrote
	if RecordCmds.write(d, s, c.id, path, value, true):
		return
	var key_at: float = float((drag.get("key_at", {}) as Dictionary).get(path, -1.0))
	var current: Dictionary = c.get_param(path)
	var next: Dictionary
	if key_at < 0.0:
		next = AnimProp.make(value)
	else:
		var base_v: Variant = d.undo.live_baseline("clip_param|" + c.id + "|" + path)
		var base: Dictionary = base_v if base_v is Dictionary else current
		next = AnimProp.autokey_next(base, c.param_time(path, key_at - c.start), value, c.duration, s.fps)
	if next == current and d.undo.live_baseline("clip_param|" + c.id + "|" + path) == null:
		return
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, path, next)
	cmd.label = String(drag.get("label", "Set value"))
	d.undo.live(cmd)


func _end(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var label: String = String(drag.get("label", "Set value"))
	drag = {}
	var snap: RefCounted = panel.call("snapper")
	if snap != null:
		snap.call("end")
	if d == null:
		return
	RecordCmds.finish(d)
	d.undo.commit_live(RecordCmds.commit_label(d, label))


func cancel(panel: Object) -> void:
	var d: Project = panel.call("doc")
	drag = {}
	var snap: RefCounted = panel.call("snapper")
	if snap != null:
		snap.call("end")
	if d != null:
		RecordCmds.cancel()
		d.undo.cancel_live()


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if pic.size.x <= 0.0 or not _allowed(panel):
		return
	var ts: Array[Dictionary] = targets(panel, pic)
	if ts.is_empty():
		return
	var c: Clip = panel.call("gizmo_clip")
	var lx: Dictionary = _layer_xf(panel, c) if c != null else {}
	if not lx.is_empty():
		var lq: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in (lx["quad"] as PackedVector2Array):
			lq.append(_screen(panel, pic, p))
		lq.append(lq[0])
		ci.draw_polyline(lq, LAYER_INK, 1.0, true)
	if active():
		var snap: RefCounted = panel.call("snapper")
		if snap != null:
			snap.call("draw", ci, pic)
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	var dragged: String = ""
	if active():
		for ti: int in ts.size():
			if _same_target(ts[ti], drag["target"]):
				dragged = str(ti) + ":" + String(drag["handle"])
	for ti2: int in ts.size():
		_draw_target(ci, pic, panel, ts[ti2], str(ti2), dragged, font, fs, outer)
	if active() and not String(drag.get("chip", "")).is_empty():
		_draw_chip(ci, outer, Vector2(drag["pointer"]) + Vector2(14.0, 16.0), String(drag["chip"]), font, fs)


static func _same_target(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("uid", "")) == String(b.get("uid", "")) and int(a.get("spec_index", -1)) == int(b.get("spec_index", -1)) and int(a.get("index", -1)) == int(b.get("index", -1))


func _draw_target(ci: CanvasItem, pic: Rect2, panel: Object, t: Dictionary, tag: String, dragged: String, font: Font, fs: int, outer: Rect2) -> void:
	var ink: Color = t["colour"]
	var shape: PackedVector2Array = t.get("shape", PackedVector2Array())
	if shape.size() >= 3:
		var closed: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in shape:
			closed.append(_screen(panel, pic, p))
		closed.append(closed[0])
		var lit: bool = hover.begins_with(tag + ":") or dragged.begins_with(tag + ":")
		ci.draw_polyline(closed, ink, 2.0 if lit else 1.5, true)
	var kind: String = String(t["kind"])
	var hs: Array = t["handles"]
	if kind == KIND_RING or kind == KIND_BAND:
		EffectHandlesUi.draw_lines(ci, t, func(p: Vector2) -> Vector2: return _screen(panel, pic, p), ink, hover.begins_with(tag + ":") or dragged.begins_with(tag + ":"))
	if kind == KIND_LINE and hs.size() >= 2:
		if bool((t["spec"] as Dictionary).get("curve", false)) and hs.size() >= 3:
			var through: PackedVector2Array = PackedVector2Array()
			for hp: Dictionary in hs:
				through.append(_screen(panel, pic, hp["at"]))
			var smooth: PackedVector2Array = curve_points(through, CURVE_STEPS)
			last_curve = smooth
			ci.draw_polyline(smooth, Color(ink, 0.8), 1.5, true)
		else:
			for li: int in hs.size() - 1:
				ci.draw_dashed_line(_screen(panel, pic, (hs[li] as Dictionary)["at"]), _screen(panel, pic, (hs[li + 1] as Dictionary)["at"]), Color(ink, 0.6), 1.0, 4.0)
	if kind == KIND_ANGLE and not hs.is_empty():
		ci.draw_line(_screen(panel, pic, t["centre"]), _screen(panel, pic, (hs[0] as Dictionary)["at"]), ink, 1.0, true)
	for h: Dictionary in hs:
		var at: Vector2 = _screen(panel, pic, h["at"])
		var id: String = tag + ":" + String(h["id"])
		var lit_h: bool = id == hover or id == dragged
		_draw_look(ci, String(h["look"]), at, h.get("dir", Vector2.RIGHT), ink, lit_h, panel, pic)
		if lit_h and kind != KIND_REGIONS and not String(h.get("name", "")).is_empty() and not active():
			_draw_chip(ci, outer, at + Vector2(10.0, -22.0), String(h.get("tip", h["name"])), font, fs)
	if kind == KIND_REGIONS and shape.size() == 4:
		var corner: Vector2 = _screen(panel, pic, shape[0])
		_draw_chip(ci, outer, corner + Vector2(0.0, -font.get_height(fs) - PmText.pad()), String(t.get("name", "")), font, fs)


func _draw_look(ci: CanvasItem, look: String, at: Vector2, dir_seq: Variant, ink: Color, lit: bool, _panel: Object, _pic: Rect2) -> void:
	var h: float = HANDLE + (2.0 if lit else 0.0)
	match look:
		"square":
			ci.draw_rect(Rect2(at - Vector2(h, h) * 0.5, Vector2(h, h)), ink, true)
		"bar":
			var dir: Vector2 = (dir_seq as Vector2).normalized() if dir_seq is Vector2 and (dir_seq as Vector2).length() > 0.0001 else Vector2.RIGHT
			ci.draw_line(at - dir * BAR * 0.5, at + dir * BAR * 0.5, ink, 4.0 + (1.0 if lit else 0.0))
		"dot":
			ci.draw_circle(at, 3.5 + (1.0 if lit else 0.0), ink)
		"ring":
			ci.draw_arc(at, RING, 0.0, TAU, 20, ink, 2.0 if lit else 1.5, true)
			for dv: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				ci.draw_line(at + dv * (RING + 2.0), at + dv * (RING + 6.0), ink, 1.5, true)
		"cross":
			ci.draw_line(at - Vector2(h, 0.0), at + Vector2(h, 0.0), ink, 2.0, true)
			ci.draw_line(at - Vector2(0.0, h), at + Vector2(0.0, h), ink, 2.0, true)
		"spin":
			ci.draw_arc(at, 3.5 + (1.0 if lit else 0.0), 0.0, TAU, 12, ink, 1.5, true)
		"knob":
			EffectHandlesUi.draw_knob(ci, at, ink, lit, false)
		"knob_hollow":
			EffectHandlesUi.draw_knob(ci, at, ink, lit, true)
		"knob_bar":
			EffectHandlesUi.draw_pill(ci, at, dir_seq, ink, lit)


func _draw_chip(ci: CanvasItem, outer: Rect2, at: Vector2, text: String, font: Font, fs: int) -> void:
	if text.is_empty():
		return
	var pad: float = PmText.pad()
	var w: float = PmText.width_of(font, text, fs) + pad * 2.0
	var h: float = font.get_height(fs) + 2.0
	var x: float = clampf(at.x, outer.position.x + 2.0, maxf(outer.end.x - w - 2.0, outer.position.x + 2.0))
	var y: float = clampf(at.y, outer.position.y + 2.0, maxf(outer.end.y - h - 2.0, outer.position.y + 2.0))
	var box: Rect2 = Rect2(Vector2(x, y).round(), Vector2(w, h))
	ci.draw_rect(box, LABEL_BACK, true)
	PmText.draw_in(ci, font, box.grow_individual(-pad, 0.0, -pad, 0.0), text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, box)
