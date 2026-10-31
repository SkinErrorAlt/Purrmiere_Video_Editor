extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PREF_KIND := "program.pen_shape"
const TRACKING_EVAL := "res://engine/tracking_eval.gd"
const KINDS: PackedStringArray = ["rect", "ellipse", "polygon"]
const KIND_LABELS: Dictionary = {"rect": "Rectangle", "ellipse": "Ellipse", "polygon": "Polygon"}
const INK := Color(1.0, 0.776, 0.337, 1.0)
const PEN_INK := Color(0.459, 0.898, 0.608, 1.0)
const LABEL_BACK := Color(0.051, 0.055, 0.063, 0.85)
const HANDLE := 7.0
const DOT := 4.0
const REACH := 4.0
const EDGE_REACH := 7.0
const SLOP := 3.0
const CLOSE_REACH := 9.0
const ELLIPSE_STEPS := 48
const MIN_SIDE := 0.004
const ADD_LABEL := "Add a shape point"
const DROP_LABEL := "Remove a shape point"
const DRAW_LABEL := "Draw a shape"

var drag: Dictionary = {}
var pen: Dictionary = {}
var hover: String = ""
var drags: int = 0
var edits: int = 0
var draws: int = 0


static func ensure_prefs(prefs: Object) -> void:
	if prefs == null or bool(prefs.call("is_registered", PREF_KIND)):
		return
	prefs.call("register", PREF_KIND, "polygon", {"label": "Shape the Pen draws on the picture", "type": "enum", "choices": KINDS})


static func pen_kind(prefs: Object) -> String:
	if prefs == null or not bool(prefs.call("is_registered", PREF_KIND)):
		return "polygon"
	var k: String = String(prefs.call("get_value", PREF_KIND))
	return k if KINDS.has(k) else "polygon"


static func fwd(p: Vector2, centre: Vector2, ax: float, rot: float) -> Vector2:
	var d: Vector2 = p - centre
	d.x *= ax
	d = d.rotated(rot)
	d.x /= ax
	return centre + d


static func inv(p: Vector2, centre: Vector2, ax: float, rot: float) -> Vector2:
	var d: Vector2 = p - centre
	d.x *= ax
	d = d.rotated(-rot)
	d.x /= ax
	return centre + d


static func spin(d: Vector2, ax: float, rot: float) -> Vector2:
	var v: Vector2 = d
	v.x *= ax
	v = v.rotated(rot)
	v.x /= ax
	return v


static func unspin(d: Vector2, ax: float, rot: float) -> Vector2:
	var v: Vector2 = d
	v.x *= ax
	v = v.rotated(-rot)
	v.x /= ax
	return v


static func box_corners(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])


static func ellipse_outline(box: Rect2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var mid: Vector2 = box.get_center()
	var r: Vector2 = box.size * 0.5
	for i: int in ELLIPSE_STEPS:
		var a: float = TAU * float(i) / float(ELLIPSE_STEPS)
		out.append(Vector2(mid.x + cos(a) * r.x, mid.y + sin(a) * r.y))
	return out


static func nearest_edge(pts: PackedVector2Array, at: Vector2) -> Dictionary:
	var best: int = -1
	var best_d: float = INF
	var best_p: Vector2 = at
	var n: int = pts.size()
	for i: int in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(at, a, b)
		var dd: float = on.distance_to(at)
		if dd < best_d:
			best_d = dd
			best = i
			best_p = on
	return {"index": best, "distance": best_d, "at": best_p}


func active() -> bool:
	return not drag.is_empty()


func drawing() -> bool:
	return not pen.is_empty()


func _allowed(panel: Object) -> bool:
	if Session.tool_id == "type" or Session.tool_id == "hand":
		return false
	if panel.has_method("placing_region") and bool(panel.call("placing_region")):
		return false
	var scr: Variant = panel.get("_screens")
	if scr is Object and (scr as Object).has_method("hide_handles") and bool((scr as Object).call("hide_handles")):
		return false
	return true


func _k(panel: Object, pic: Rect2) -> float:
	var s: Sequence = panel.call("seq")
	return pic.size.x / maxf(float(s.width), 1.0) if s != null else 1.0


func _screen(panel: Object, pic: Rect2, p: Vector2) -> Vector2:
	return panel.call("_to_picture", pic, p)


func _to_seq(panel: Object, pic: Rect2, p: Vector2) -> Vector2:
	return (p - pic.position) / maxf(_k(panel, pic), 0.0001)


func _layer(panel: Object, c: Clip) -> Dictionary:
	var made: Dictionary = panel.call("quad_for", c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4:
		return {}
	var qq: PackedVector2Array = q
	var xf: Transform2D = Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])
	if absf(xf.determinant()) < 0.000001:
		return {}
	return {"xf": xf, "quad": qq}


func _aspect(panel: Object, c: Clip) -> float:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null:
		return 1.0
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var px: Vector2 = PairLayout.picture_size(c, MonitorPick.layer_size(c, m, s, d), Vector2(float(s.width), float(s.height)))
	return maxf(px.x, 1.0) / maxf(px.y, 1.0)


func _uv_at(panel: Object, pic: Rect2, xf: Transform2D, at: Vector2) -> Vector2:
	return xf.affine_inverse() * _to_seq(panel, pic, at)


func targets(panel: Object, pic: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pic.size.x <= 0.0 or not _allowed(panel):
		return out
	var c: Clip = panel.call("gizmo_clip")
	var s: Sequence = panel.call("seq")
	if c == null or s == null or c.masks.is_empty():
		return out
	var lx: Dictionary = _layer(panel, c)
	if lx.is_empty():
		return out
	var xf: Transform2D = lx["xf"]
	var ax: float = _aspect(panel, c)
	var local: float = s.playhead - c.start
	for i: int in c.masks.size():
		var m: Dictionary = c.masks[i]
		var mid: String = String(m.get("id", ""))
		if mid.is_empty() or not bool(m.get("enabled", true)) or not String(m.get("region_of", "")).is_empty():
			continue
		var mxf: Transform2D = xf
		if m.has("track"):
			var tx: Variant = load(TRACKING_EVAL).call("mask_xf", panel.call("doc"), c, m, s.playhead, s.fps)
			if tx is Transform2D:
				mxf = xf * (tx as Transform2D)
		var t: Dictionary = {"clip_id": c.id, "mask_id": mid, "index": i, "xf": mxf, "aspect": ax, "label": MaskShape.label_of(m, i), "box": MaskShape.is_box(m)}
		var ok: bool = _box_target(t, m, local, c.duration, s.fps) if bool(t["box"]) else _poly_target(t, m, local, c.duration, s.fps)
		if ok:
			out.append(t)
	return out


func _box_target(t: Dictionary, m: Dictionary, local: float, dur: float, fps: float) -> bool:
	var box: Rect2 = MaskShape.box_at(m, local, dur, fps)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return false
	var rot: float = deg_to_rad(float(MaskShape.value_at(m, "rotation", local, dur, fps)))
	var ax: float = float(t["aspect"])
	var mid: Vector2 = box.get_center()
	var xf: Transform2D = t["xf"]
	var corners: PackedVector2Array = box_corners(box)
	var hs: Array[Dictionary] = []
	for i: int in 4:
		hs.append({"id": "c" + str(i), "at": xf * fwd(corners[i], mid, ax, rot), "look": "square", "name": "Corner"})
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		hs.append({"id": "e" + str(i), "at": xf * fwd((a + b) * 0.5, mid, ax, rot), "look": "dot", "name": "Edge"})
	var shape: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in (ellipse_outline(box) if String(m.get("kind", "")) == "ellipse" else corners):
		shape.append(xf * fwd(p, mid, ax, rot))
	t["handles"] = hs
	t["shape"] = shape
	t["box_rect"] = box
	t["rotation"] = rot
	t["centre"] = mid
	return true


func _poly_target(t: Dictionary, m: Dictionary, local: float, dur: float, fps: float) -> bool:
	var pts: PackedVector2Array = MaskShape.points_at(m, local, dur, fps)
	if pts.size() < 2:
		return false
	var xf: Transform2D = t["xf"]
	var hs: Array[Dictionary] = []
	var shape: PackedVector2Array = PackedVector2Array()
	for i: int in pts.size():
		var at: Vector2 = xf * pts[i]
		hs.append({"id": "p" + str(i), "at": at, "look": "dot", "name": "Point " + str(i + 1)})
		shape.append(at)
	t["handles"] = hs
	t["shape"] = shape
	t["points"] = pts
	return true


func hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	var ts: Array[Dictionary] = targets(panel, pic)
	for ti: int in ts.size():
		var t: Dictionary = ts[ti]
		for h: Dictionary in (t["handles"] as Array):
			if at.distance_to(_screen(panel, pic, h["at"])) <= HANDLE + REACH:
				return {"target": t, "handle": String(h["id"]), "name": String(h.get("name", "")), "key": str(ti) + ":" + String(h["id"])}
	for ti2: int in ts.size():
		var t2: Dictionary = ts[ti2]
		var sq: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in (t2["shape"] as PackedVector2Array):
			sq.append(_screen(panel, pic, p))
		if sq.size() >= 3 and Geometry2D.is_point_in_polygon(at, sq):
			return {"target": t2, "handle": "in", "name": String(t2["label"]), "key": str(ti2) + ":in"}
	return {}


func edge_hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	var ts: Array[Dictionary] = targets(panel, pic)
	for ti: int in ts.size():
		var t: Dictionary = ts[ti]
		if bool(t["box"]):
			continue
		var sq: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in (t["shape"] as PackedVector2Array):
			sq.append(_screen(panel, pic, p))
		if sq.size() < 2:
			continue
		var near: Dictionary = nearest_edge(sq, at)
		if float(near["distance"]) <= EDGE_REACH:
			return {"target": t, "index": int(near["index"])}
	return {}


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not _allowed(panel):
		return false
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed and mb.double_click:
			if _double(panel, pic, mb):
				_accept(view)
				return true
			return false
		if mb.pressed:
			var h: Dictionary = hit(panel, pic, mb.position)
			if h.is_empty():
				return false
			_begin(panel, pic, h, mb)
			_accept(view)
			return true
		if drag.is_empty():
			return false
		_end(panel)
		_accept(view)
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
		_accept(view)
		return true
	return false


func _accept(view: Control) -> void:
	if view != null:
		view.accept_event()
		view.call("redraw_overlay")


func _begin(panel: Object, pic: Rect2, h: Dictionary, mb: InputEventMouseButton) -> void:
	var t: Dictionary = h["target"]
	var s: Sequence = panel.call("seq")
	var c: Clip = s.clip_by_id(String(t["clip_id"])) if s != null else null
	var bus: Object = panel.call("bus")
	var key_at: Dictionary = {}
	for key: String in (["centre", "size"] if bool(t["box"]) else ["points"]):
		var path: String = "masks." + String(t["mask_id"]) + "." + key
		key_at[path] = float(bus.call("key_time_for", c, path, s.playhead)) if bus != null and c != null else -1.0
	drag = {"target": t, "handle": String(h["handle"]), "press": mb.position, "press_uv": _uv_at(panel, pic, t["xf"], mb.position), "open": false, "key_at": key_at, "label": String(t["label"]), "pointer": mb.position, "chip": ""}
	drags += 1


func _motion(panel: Object, pic: Rect2, mm: InputEventMouseMotion) -> void:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var t: Dictionary = drag["target"]
	var c: Clip = s.clip_by_id(String(t["clip_id"])) if s != null else null
	if c == null or d == null:
		return
	if not bool(drag["open"]):
		if mm.position.distance_to(Vector2(drag["press"])) < SLOP:
			return
		drag["open"] = true
	drag["pointer"] = mm.position
	var uv: Vector2 = _uv_at(panel, pic, t["xf"], mm.position)
	if bool(t["box"]):
		_drag_box(d, s, c, t, uv, mm)
	else:
		_drag_points(d, s, c, t, uv, mm)


func _drag_box(d: Project, s: Sequence, c: Clip, t: Dictionary, uv: Vector2, mm: InputEventMouseMotion) -> void:
	var box: Rect2 = t["box_rect"]
	var rot: float = float(t["rotation"])
	var ax: float = float(t["aspect"])
	var mid: Vector2 = box.get_center()
	var handle: String = String(drag["handle"])
	var centre: Vector2 = mid
	var size: Vector2 = box.size
	if handle == "in":
		centre = mid + uv - Vector2(drag["press_uv"])
	elif handle.begins_with("c"):
		var i: int = int(handle.substr(1))
		var corners: PackedVector2Array = box_corners(box)
		var anchor: Vector2 = fwd(corners[(i + 2) % 4], mid, ax, rot)
		var local_d: Vector2 = unspin(uv - anchor, ax, rot)
		if mm.shift_pressed and box.size.y > 0.0:
			var ratio: float = box.size.x / box.size.y
			var mag: float = maxf(absf(local_d.x), absf(local_d.y) * ratio)
			local_d = Vector2(mag * signf(local_d.x), mag / maxf(ratio, 0.0001) * signf(local_d.y))
		size = local_d.abs()
		centre = anchor + spin(local_d * 0.5, ax, rot)
	elif handle.begins_with("e"):
		var j: int = int(handle.substr(1))
		var cs: PackedVector2Array = box_corners(box)
		var far: Vector2 = (cs[(j + 2) % 4] + cs[(j + 3) % 4]) * 0.5
		var anchor2: Vector2 = fwd(far, mid, ax, rot)
		var ld: Vector2 = unspin(uv - anchor2, ax, rot)
		if j % 2 == 0:
			size = Vector2(box.size.x, absf(ld.y))
			centre = anchor2 + spin(Vector2(0.0, ld.y * 0.5), ax, rot)
		else:
			size = Vector2(absf(ld.x), box.size.y)
			centre = anchor2 + spin(Vector2(ld.x * 0.5, 0.0), ax, rot)
	size = Vector2(maxf(size.x, MIN_SIDE), maxf(size.y, MIN_SIDE))
	var base: String = "masks." + String(t["mask_id"]) + "."
	if handle != "in":
		_write(d, s, c, base + "size", [size.x, size.y])
	_write(d, s, c, base + "centre", [centre.x, centre.y])
	drag["chip"] = "%s %.1f %%, %.1f %%" % [String(t["label"]), centre.x * 100.0, centre.y * 100.0] if handle == "in" else "%s %.1f %% by %.1f %%" % [String(t["label"]), size.x * 100.0, size.y * 100.0]


func _drag_points(d: Project, s: Sequence, c: Clip, t: Dictionary, uv: Vector2, mm: InputEventMouseMotion) -> void:
	var pts: PackedVector2Array = (t["points"] as PackedVector2Array).duplicate()
	var handle: String = String(drag["handle"])
	if handle == "in":
		var shift: Vector2 = uv - Vector2(drag["press_uv"])
		for i: int in pts.size():
			pts[i] = pts[i] + shift
		drag["chip"] = String(t["label"]) + " moved"
	else:
		var j: int = int(handle.substr(1))
		if j < 0 or j >= pts.size():
			return
		var want: Vector2 = uv
		if mm.shift_pressed:
			var was: Vector2 = pts[j]
			want = Vector2(want.x, was.y) if absf(want.x - was.x) >= absf(want.y - was.y) else Vector2(was.x, want.y)
		pts[j] = want
		drag["chip"] = "%s point %d: %.1f %%, %.1f %%" % [String(t["label"]), j + 1, want.x * 100.0, want.y * 100.0]
	_write(d, s, c, "masks." + String(t["mask_id"]) + ".points", MaskShape.flat_of(pts))


func _write(d: Project, s: Sequence, c: Clip, path: String, value: Variant) -> void:
	if RecordCmds.write(d, s, c.id, path, value, true):
		return
	var key_at: float = float((drag.get("key_at", {}) as Dictionary).get(path, -1.0))
	var current: Dictionary = c.get_param(path)
	if path.ends_with(".points") and not current.is_empty():
		current = MaskShape.flatten_prop(current)
	var next: Dictionary = AnimProp.make(value)
	if key_at >= 0.0:
		next = AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), c.param_time(path, key_at - c.start), value)
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, path, next)
	cmd.label = String(drag.get("label", "Shape"))
	d.undo.live(cmd)


func _end(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var label: String = String(drag.get("label", "Shape"))
	drag = {}
	if d == null:
		return
	RecordCmds.finish(d)
	d.undo.commit_live(RecordCmds.commit_label(d, label))


func cancel(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var was: bool = not drag.is_empty()
	drag = {}
	pen = {}
	if d != null and was:
		RecordCmds.cancel()
		d.undo.cancel_live()


func _double(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	var on: Dictionary = hit(panel, pic, mb.position)
	if not on.is_empty() and String(on["handle"]).begins_with("p"):
		return drop_point(panel, String((on["target"] as Dictionary)["mask_id"]), int(String(on["handle"]).substr(1)))
	var near: Dictionary = edge_hit(panel, pic, mb.position)
	if near.is_empty():
		return false
	var t: Dictionary = near["target"]
	var uv: Vector2 = _uv_at(panel, pic, t["xf"], mb.position)
	return add_point(panel, String(t["mask_id"]), int(near["index"]) + 1, uv)


func add_point(panel: Object, mask_id: String, at: int, uv: Vector2) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var c: Clip = panel.call("gizmo_clip")
	if d == null or s == null or c == null:
		return false
	var path: String = "masks." + mask_id + ".points"
	var current: Dictionary = c.get_param(path)
	if current.is_empty():
		return false
	var next: Dictionary = MaskShape.insert_point(current, at, uv)
	if next == current:
		return false
	edits += 1
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path, next)]
	return Verbs.run(d, ADD_LABEL, cmds)


func drop_point(panel: Object, mask_id: String, at: int) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var c: Clip = panel.call("gizmo_clip")
	if d == null or s == null or c == null:
		return false
	var path: String = "masks." + mask_id + ".points"
	var current: Dictionary = c.get_param(path)
	if current.is_empty() or MaskShape.point_count(current) <= MaskShape.MIN_POINTS:
		return false
	var next: Dictionary = MaskShape.remove_point(current, at)
	if next == current:
		return false
	edits += 1
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path, next)]
	return Verbs.run(d, DROP_LABEL, cmds)


func pen_on(panel: Object) -> bool:
	return Session.tool_id == "pen" and _allowed(panel) and panel.call("gizmo_clip") != null


func pen_input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not pen_on(panel):
		if not pen.is_empty():
			pen = {}
		return false
	var view: Control = panel.get("view")
	var c: Clip = panel.call("gizmo_clip")
	var lx: Dictionary = _layer(panel, c)
	if lx.is_empty():
		return false
	var xf: Transform2D = lx["xf"]
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		var uv: Vector2 = _uv_at(panel, pic, xf, mb.position)
		if mb.pressed:
			_pen_press(panel, pic, c, uv, mb)
		else:
			_pen_release(panel, c, uv)
		_accept(view)
		return true
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if pen.is_empty():
			return false
		pen["at"] = _uv_at(panel, pic, xf, mm.position)
		pen["pointer"] = mm.position
		if String(pen["kind"]) != "polygon" and bool(pen.get("dragging", false)):
			pen["to"] = pen["at"]
		if view != null:
			view.call("redraw_overlay")
		return String(pen["kind"]) != "polygon"
	return false


func _pen_press(panel: Object, pic: Rect2, c: Clip, uv: Vector2, mb: InputEventMouseButton) -> void:
	var kind: String = pen_kind(Prefs)
	if kind != "polygon":
		pen = {"clip_id": c.id, "kind": kind, "from": uv, "to": uv, "at": uv, "pointer": mb.position, "dragging": true, "pts": PackedVector2Array()}
		return
	if pen.is_empty() or String(pen.get("clip_id", "")) != c.id:
		pen = {"clip_id": c.id, "kind": "polygon", "pts": PackedVector2Array([uv]), "at": uv, "pointer": mb.position, "dragging": false}
		return
	var pts: PackedVector2Array = pen["pts"]
	if mb.double_click or (pts.size() >= 3 and mb.position.distance_to(_screen(panel, pic, pts[0])) <= CLOSE_REACH):
		finish_pen(panel)
		return
	pts.append(uv)
	pen["pts"] = pts
	pen["at"] = uv


func _pen_release(panel: Object, c: Clip, uv: Vector2) -> void:
	if pen.is_empty() or String(pen["kind"]) == "polygon":
		return
	pen["to"] = uv
	pen["dragging"] = false
	var from: Vector2 = pen["from"]
	var box: Rect2 = Rect2(from, uv - from).abs()
	if box.size.x < MIN_SIDE or box.size.y < MIN_SIDE:
		pen = {}
		return
	_make_box_mask(panel, c, String(pen["kind"]), box)
	pen = {}


func _make_box_mask(panel: Object, c: Clip, kind: String, box: Rect2) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null or c == null:
		return false
	var m: Dictionary = MaskShape.make(kind, d.mint_id("mask"))
	m["centre"] = [box.get_center().x, box.get_center().y]
	m["size"] = [box.size.x, box.size.y]
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	masks.append(m)
	draws += 1
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)]
	return Verbs.run(d, DRAW_LABEL, cmds)


func finish_pen(panel: Object) -> bool:
	if pen.is_empty():
		return false
	var kind: String = String(pen["kind"])
	var pts: PackedVector2Array = pen.get("pts", PackedVector2Array())
	var clip_id: String = String(pen["clip_id"])
	pen = {}
	var view: Control = panel.get("view")
	if view != null:
		view.call("redraw_overlay")
	if kind != "polygon" or pts.size() < MaskShape.MIN_POINTS:
		return false
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	masks.append(MaskShape.make_polygon(d.mint_id("mask"), MaskShape.flat_of(pts)))
	draws += 1
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)]
	return Verbs.run(d, DRAW_LABEL, cmds)


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if pen.is_empty() or not e.pressed:
		return false
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		finish_pen(panel)
		return true
	if e.keycode == KEY_ESCAPE:
		pen = {}
		var view: Control = panel.get("view")
		if view != null:
			view.call("redraw_overlay")
		return true
	if e.keycode == KEY_BACKSPACE and String(pen["kind"]) == "polygon":
		var pts: PackedVector2Array = pen["pts"]
		if pts.size() > 0:
			pts.remove_at(pts.size() - 1)
			pen["pts"] = pts
		if pts.is_empty():
			pen = {}
		var v2: Control = panel.get("view")
		if v2 != null:
			v2.call("redraw_overlay")
		return true
	return false


func menu_items() -> Array:
	var now: String = pen_kind(Prefs)
	var out: Array = []
	for k: String in KINDS:
		out.append(PmMenu.check_item("penshape:" + k, String(KIND_LABELS[k]), now == k))
	return out


func arm_items(panel: Object) -> Array:
	var out: Array = []
	var c: Clip = panel.call("gizmo_clip")
	var bus: Object = panel.call("bus")
	if c == null or bus == null:
		return out
	for i: int in c.masks.size():
		var m: Dictionary = c.masks[i]
		var mid: String = String(m.get("id", ""))
		if mid.is_empty() or not String(m.get("region_of", "")).is_empty() or MaskShape.is_box(m):
			continue
		var path: String = "masks." + mid + ".points"
		var on: bool = AnimProp.is_animated(c.get_param(path)) or bool(bus.call("is_armed", c.id, path))
		out.append(PmMenu.check_item("maskarm:" + mid, MaskShape.label_of(m, i), on))
	if out.is_empty():
		var none: Dictionary = PmMenu.item("maskarm:none", "No shape mask on this clip")
		none["disabled"] = true
		out.append(none)
	return out


func on_menu_picked(id: String, panel: Object = null) -> bool:
	if id.begins_with("penshape:"):
		var k: String = id.substr(9)
		if KINDS.has(k):
			Prefs.set_value(PREF_KIND, k)
		return true
	if not id.begins_with("maskarm:"):
		return false
	var mid: String = id.substr(8)
	if mid == "none" or panel == null:
		return true
	var c: Clip = panel.call("gizmo_clip")
	var bus: Object = panel.call("bus")
	if c == null or bus == null:
		return true
	var path: String = "masks." + mid + ".points"
	var want: bool = not (AnimProp.is_animated(c.get_param(path)) or bool(bus.call("is_armed", c.id, path)))
	bus.call("set_armed", c.id, path, want)
	if not want:
		var d: Project = panel.call("doc")
		var s: Sequence = panel.call("seq")
		if d != null and s != null and AnimProp.is_animated(c.get_param(path)):
			var flat: Array = MaskShape.flat_of(MaskShape.points_at(c.masks[MaskShape.index_of(c.masks, mid)], s.playhead - c.start, c.duration, s.fps))
			var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path, AnimProp.make(flat))]
			Verbs.run(d, "Stop animating the shape", cmds)
	return true


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if pic.size.x <= 0.0 or not _allowed(panel):
		return
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	var ts: Array[Dictionary] = targets(panel, pic)
	for ti: int in ts.size():
		_draw_target(ci, pic, panel, ts[ti], str(ti), font, fs, outer)
	_draw_pen(ci, pic, panel, font, fs, outer)
	if active() and not String(drag.get("chip", "")).is_empty():
		_draw_chip(ci, outer, Vector2(drag["pointer"]) + Vector2(14.0, 16.0), String(drag["chip"]), font, fs)


func _draw_target(ci: CanvasItem, pic: Rect2, panel: Object, t: Dictionary, tag: String, font: Font, fs: int, outer: Rect2) -> void:
	var shape: PackedVector2Array = t["shape"]
	var lit: bool = hover.begins_with(tag + ":") or (active() and String((drag["target"] as Dictionary).get("mask_id", "")) == String(t["mask_id"]))
	if shape.size() >= 2:
		var closed: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in shape:
			closed.append(_screen(panel, pic, p))
		closed.append(closed[0])
		ci.draw_polyline(closed, INK, 2.0 if lit else 1.5, true)
	for h: Dictionary in (t["handles"] as Array):
		var at: Vector2 = _screen(panel, pic, h["at"])
		var id: String = tag + ":" + String(h["id"])
		var hot: bool = id == hover or (active() and String(drag["handle"]) == String(h["id"]) and String((drag["target"] as Dictionary).get("mask_id", "")) == String(t["mask_id"]))
		if String(h["look"]) == "square":
			var w: float = HANDLE + (2.0 if hot else 0.0)
			ci.draw_rect(Rect2(at - Vector2(w, w) * 0.5, Vector2(w, w)), INK, true)
		else:
			ci.draw_circle(at, DOT + (1.5 if hot else 0.0), INK)
	if lit and shape.size() >= 1:
		_draw_chip(ci, outer, _screen(panel, pic, shape[0]) + Vector2(10.0, -22.0), String(t["label"]), font, fs)


func _draw_pen(ci: CanvasItem, pic: Rect2, panel: Object, font: Font, fs: int, outer: Rect2) -> void:
	if pen.is_empty():
		return
	var c: Clip = panel.call("gizmo_clip")
	if c == null:
		return
	var lx: Dictionary = _layer(panel, c)
	if lx.is_empty():
		return
	var xf: Transform2D = lx["xf"]
	var kind: String = String(pen["kind"])
	var line: PackedVector2Array = PackedVector2Array()
	if kind == "polygon":
		for p: Vector2 in (pen["pts"] as PackedVector2Array):
			line.append(_screen(panel, pic, xf * p))
		if pen.has("at"):
			line.append(_screen(panel, pic, xf * Vector2(pen["at"])))
	else:
		var box: Rect2 = Rect2(Vector2(pen["from"]), Vector2(pen["to"]) - Vector2(pen["from"])).abs()
		var pts: PackedVector2Array = ellipse_outline(box) if kind == "ellipse" else box_corners(box)
		for p2: Vector2 in pts:
			line.append(_screen(panel, pic, xf * p2))
		if line.size() >= 2:
			line.append(line[0])
	if line.size() >= 2:
		ci.draw_polyline(line, PEN_INK, 1.5, true)
	for p3: Vector2 in line:
		ci.draw_circle(p3, DOT, PEN_INK)
	if kind == "polygon" and not line.is_empty():
		_draw_chip(ci, outer, line[0] + Vector2(10.0, -22.0), "Click to add a point, double click or Enter to finish", font, fs)


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
