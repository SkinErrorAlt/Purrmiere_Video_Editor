extends RefCounted

const Tracking := preload("res://doc/tracking.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const Ops := preload("res://modules/core_panels/tracker_ops.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const SELF_PATH := "res://modules/core_panels/tracker_ui.gd"
const RUN_PATH := "res://modules/core_panels/tracker_run.gd"
const TOOL_ID := "track_area"
const COMMAND_ID := "tool.track_area"
const PANEL_ID := "tracker"
const CMD_PANEL := "tracker.panel"
const CMD_FORWARD := "tracker.forward"
const CMD_BACKWARD := "tracker.backward"
const CMD_STEP_FORWARD := "tracker.step_forward"
const CMD_STEP_BACKWARD := "tracker.step_backward"
const CMD_STOP := "tracker.stop"
const KIND_LABELS: Dictionary = {"box": "Box", "shape": "Free shape", "points": "Points"}
const TOOL_TIP := "Track area tool: drag a box, draw a free shape or click points round the part to track (Tracker panel picks which). Drag a point or the inside to change it, Delete removes the area under the pointer"
const AREA_INK := Color(0.36, 0.84, 1.0, 1.0)
const LEAVE_INK := Color(1.0, 0.42, 0.36, 1.0)
const DIM := Color(0.0, 0.0, 0.0, 0.42)
const GOOD_INK := Color(0.46, 0.9, 0.6, 1.0)
const WEAK_INK := Color(1.0, 0.82, 0.2, 1.0)
const LOST_INK := Color(1.0, 0.35, 0.3, 1.0)
const RUN_INK := Color(0.36, 0.84, 1.0, 1.0)
const CROSS_INK := Color(1.0, 1.0, 1.0, 1.0)
const RIM := Color(0.0, 0.0, 0.0, 0.75)
const LABEL_BACK := Color(0.051, 0.055, 0.063, 0.85)
const PATH_FRAMES := 30
const CROSS := 9.0
const REACH := 10.0
const HANDLE := 7.0
const SLOP := 3.0
const CLOSE_REACH := 9.0
const FREE_STEP := 4.0
const PATTERN_PX := 21.0
const DIM_STEP := 2.0
const MIN_BOX := 4.0

static var active_set: String = ""
static var draw_kind: String = "box"
static var leave_out: bool = false
static var _registered: bool = false

var drag: Dictionary = {}
var pen: PackedVector2Array = PackedVector2Array()
var hover: String = ""
var stats: Dictionary = {}


static func _script() -> GDScript:
	return load(SELF_PATH)


static func tool_on() -> bool:
	return Session.tool_id == TOOL_ID


static func use_tool() -> void:
	Session.set_tool(TOOL_ID)
	Events.toast(TOOL_TIP)


static func toggle_tool() -> void:
	if tool_on():
		Session.set_tool("select")
	else:
		use_tool()


static func runner() -> Node:
	return (load(RUN_PATH) as GDScript).call("shared")


static func register_commands() -> void:
	if _registered:
		return
	_registered = true
	var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var me: GDScript = _script()
	var specs: Array = [
		[COMMAND_ID, "Track area tool", "Tools", Callable(me, "use_tool"), Callable(me, "tool_on")],
		[CMD_PANEL, "Tracker panel", "Clip", Callable(me, "open_panel"), Callable()],
		[CMD_FORWARD, "Tracker: track forward to the end of the range", "Clip", Callable(me, "track").bind("forward", false), Callable()],
		[CMD_BACKWARD, "Tracker: track backward to the start of the range", "Clip", Callable(me, "track").bind("backward", false), Callable()],
		[CMD_STEP_FORWARD, "Tracker: track forward one frame", "Clip", Callable(me, "track").bind("forward", true), Callable()],
		[CMD_STEP_BACKWARD, "Tracker: track backward one frame", "Clip", Callable(me, "track").bind("backward", true), Callable()],
		[CMD_STOP, "Tracker: stop tracking", "Clip", Callable(me, "stop"), Callable()],
	]
	var cat: Dictionary = Cmd.catalogue()
	for sp: Array in specs:
		var id: String = sp[0]
		if Cmd.has(id):
			continue
		var label: String = String(sp[1])
		var category: String = String(sp[2])
		if cat.has(id):
			label = String((cat[id] as Dictionary).get("label", label))
			category = String((cat[id] as Dictionary).get("category", category))
		var spec: Dictionary = {"label": label, "category": category, "scope": "global", "handler": sp[3], "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static")}
		if (sp[4] as Callable).is_valid():
			spec["toggle"] = sp[4]
		Cmd.register(id, spec)


static func open_panel() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	var dock: Variant = editor.get("dock") if editor != null else null
	if dock is Node and (dock as Node).has_method("show_panel"):
		(dock as Node).call("show_panel", PANEL_ID)


static func set_for(doc: Project, seq: Sequence) -> String:
	if doc == null or seq == null:
		return ""
	if not active_set.is_empty():
		var s: Dictionary = Tracking.set_by_id(doc, active_set)
		if not s.is_empty() and seq.clip_by_id(String(s.get("clip", ""))) != null:
			return active_set
	for id: String in seq.selected_clip_ids:
		var sets: Array[Dictionary] = Tracking.sets_for_clip(doc, id)
		if not sets.is_empty():
			return String(sets[0]["id"])
	return ""


static func ctx() -> Dictionary:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	var sid: String = set_for(doc, seq)
	if sid.is_empty():
		return {}
	var s: Dictionary = Tracking.set_by_id(doc, sid)
	var c: Clip = seq.clip_by_id(String(s.get("clip", "")))
	if c == null or seq.playhead < c.start or seq.playhead >= c.end():
		return {}
	var tf: Dictionary = TrackingEval.world_tf(c, seq, seq.playhead, seq.fps)
	var size: Vector2 = Vector2(float((s["size"] as Array)[0]), float((s["size"] as Array)[1]))
	var xf: Transform2D = TrackingEval.layer_xf(tf, size, Vector2(float(seq.width), float(seq.height)))
	return {"doc": doc, "seq": seq, "sid": sid, "set": s, "clip": c, "mt": c.source_time(seq.playhead), "xf": xf, "size": size, "fps": float(s.get("fps", 30.0))}


static func track(direction: String, one: bool) -> String:
	var cx: Dictionary = ctx()
	if cx.is_empty():
		var why: String = "Put the playhead on a clip with a tracker"
		Events.toast(why)
		return why
	var fps: float = float(cx["fps"])
	var mt: float = float(cx["mt"])
	var until: float = NAN
	if one:
		until = mt + (1.0 if direction == "forward" else -1.0) / fps
	var err: String = String(runner().call("start", cx["doc"], cx["sid"], direction, mt, until))
	if not err.is_empty():
		Events.toast("The tracker did not start: " + err)
	return err


static func stop() -> void:
	runner().call("stop")


func _k(cx: Dictionary, pic: Rect2) -> float:
	return pic.size.x / maxf(float((cx["seq"] as Sequence).width), 1.0)


func _scr(cx: Dictionary, pic: Rect2, m: Vector2) -> Vector2:
	return pic.position + ((cx["xf"] as Transform2D) * m) * _k(cx, pic)


func _media(cx: Dictionary, pic: Rect2, p: Vector2) -> Vector2:
	return (cx["xf"] as Transform2D).affine_inverse() * ((p - pic.position) / maxf(_k(cx, pic), 0.0001))


func _allowed() -> bool:
	return Session.tool_id != "type" and Session.tool_id != "hand" and Session.tool_id != "pen"


func _area_screen(cx: Dictionary, pic: Rect2, a: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for m: Vector2 in Tracking.area_points_at(a, float(cx["mt"])):
		out.append(_scr(cx, pic, m))
	return out


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	stats = {"areas": 0, "handles": 0, "trackers": 0, "dots": 0, "dim_rows": 0, "running": false}
	if pic.size.x <= 0.0:
		return
	var cx: Dictionary = ctx()
	if cx.is_empty():
		return
	var s: Dictionary = cx["set"]
	var on: bool = tool_on()
	var includes: Array[PackedVector2Array] = []
	for a: Variant in s.get("areas", []):
		var ad: Dictionary = a
		var poly: PackedVector2Array = _area_screen(cx, pic, ad)
		if poly.size() >= 3 and not bool(ad.get("leave_out", false)):
			includes.append(poly)
	if on and not includes.is_empty():
		_dim_outside(ci, pic, includes)
	for a: Variant in s.get("areas", []):
		_draw_area(ci, pic, cx, a, on)
	_draw_pen(ci, pic, cx)
	_draw_trackers(ci, pic, cx)
	if on and pen.is_empty() and drag.is_empty() and (s.get("areas", []) as Array).is_empty():
		_chip(ci, pic, pic.position + Vector2(12.0, 12.0), "%s: drag on the picture to draw the track area" % String(KIND_LABELS.get(draw_kind, "Box")))


func _dim_outside(ci: CanvasItem, pic: Rect2, polys: Array[PackedVector2Array]) -> void:
	var y: float = pic.position.y
	var rows: int = 0
	while y < pic.end.y:
		var yc: float = y + DIM_STEP * 0.5
		var spans: Array[Vector2] = []
		for poly: PackedVector2Array in polys:
			var xs: PackedFloat64Array = PackedFloat64Array()
			var n: int = poly.size()
			for i: int in n:
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % n]
				if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for j: int in range(0, xs.size() - 1, 2):
				spans.append(Vector2(xs[j], xs[j + 1]))
		spans.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var x: float = pic.position.x
		for sp: Vector2 in spans:
			if sp.x > x:
				ci.draw_rect(Rect2(x, y, minf(sp.x, pic.end.x) - x, DIM_STEP), DIM, true)
			x = maxf(x, sp.y)
		if x < pic.end.x:
			ci.draw_rect(Rect2(x, y, pic.end.x - x, DIM_STEP), DIM, true)
		y += DIM_STEP
		rows += 1
	stats["dim_rows"] = rows


func _draw_area(ci: CanvasItem, pic: Rect2, cx: Dictionary, a: Dictionary, on: bool) -> void:
	var poly: PackedVector2Array = _area_screen(cx, pic, a)
	if poly.size() < 3:
		return
	stats["areas"] = int(stats["areas"]) + 1
	var leave: bool = bool(a.get("leave_out", false))
	var ink: Color = LEAVE_INK if leave else AREA_INK
	if not on:
		ink.a = 0.55
	var aid: String = String(a.get("id", ""))
	var lit: bool = hover.begins_with("ai:" + aid) or hover.begins_with("ap:" + aid + ":")
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	if leave:
		for i: int in poly.size():
			_dashed(ci, closed[i], closed[i + 1], ink, 2.0 if lit else 1.5)
	else:
		ci.draw_polyline(closed, RIM, 3.5, true)
		ci.draw_polyline(closed, ink, 2.0 if lit else 1.5, true)
	if not on:
		return
	for i: int in poly.size():
		var hot: bool = hover == "ap:%s:%d" % [aid, i]
		var w: float = HANDLE + (2.0 if hot else 0.0)
		ci.draw_rect(Rect2(poly[i] - Vector2(w, w) * 0.5, Vector2(w, w)), ink, true)
		ci.draw_rect(Rect2(poly[i] - Vector2(w, w) * 0.5, Vector2(w, w)), RIM, false, 1.0)
		stats["handles"] = int(stats["handles"]) + 1
	if Tracking.area_keyed(a):
		_chip(ci, pic, poly[0] + Vector2(8.0, -22.0), "Keyed")
	if lit and leave:
		_chip(ci, pic, poly[0] + Vector2(8.0, 6.0), "Left out")


func _dashed(ci: CanvasItem, a: Vector2, b: Vector2, ink: Color, w: float) -> void:
	var len: float = a.distance_to(b)
	var steps: int = maxi(1, int(len / 6.0))
	for i: int in range(0, steps, 2):
		ci.draw_line(a.lerp(b, float(i) / float(steps)), a.lerp(b, minf(1.0, float(i + 1) / float(steps))), ink, w, true)


func _draw_pen(ci: CanvasItem, pic: Rect2, cx: Dictionary) -> void:
	var ink: Color = LEAVE_INK if leave_out else AREA_INK
	if String(drag.get("kind", "")) == "box" and bool(drag.get("moved", false)):
		var r: Rect2 = Rect2(drag["from"], Vector2.ZERO).expand(drag["to"])
		ci.draw_rect(r, ink, false, 1.5)
	if String(drag.get("kind", "")) == "shape":
		var line: PackedVector2Array = PackedVector2Array()
		for m: Vector2 in (drag["pts"] as PackedVector2Array):
			line.append(_scr(cx, pic, m))
		if line.size() >= 2:
			ci.draw_polyline(line, ink, 1.5, true)
	if pen.is_empty():
		return
	var pl: PackedVector2Array = PackedVector2Array()
	for m: Vector2 in pen:
		pl.append(_scr(cx, pic, m))
	if pl.size() >= 2:
		ci.draw_polyline(pl, ink, 1.5, true)
	for p: Vector2 in pl:
		ci.draw_circle(p, 3.5, ink)
	_chip(ci, pic, pl[0] + Vector2(10.0, -22.0), "Click to add a point, click the first point, double click or Enter to finish")


func _samples_for(cx: Dictionary, tr: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = [Tracking.samples(tr)]
	var run: Node = runner()
	if run != null and bool(run.call("running")):
		var pv: Dictionary = run.call("preview_samples", String(cx["sid"]), String(tr.get("id", "")))
		if not pv.is_empty():
			out.append(pv)
			stats["running"] = true
	return out


func tracker_at(cx: Dictionary, tr: Dictionary) -> Dictionary:
	var mt: float = float(cx["mt"])
	var fps: float = float(cx["fps"])
	var run: Node = runner()
	if run != null and bool(run.call("running")):
		var pv: Dictionary = run.call("preview_samples", String(cx["sid"]), String(tr.get("id", "")))
		if not pv.is_empty():
			var t: PackedFloat64Array = pv["t"]
			for i: int in t.size():
				if absf(t[i] - mt) < 0.5 / fps or (t[i] <= mt + Tracking.frame_eps(fps) and mt - t[i] < 1.0 / fps):
					return {"p": Vector2((pv["x"] as PackedFloat32Array)[i], (pv["y"] as PackedFloat32Array)[i]), "flags": (pv["f"] as PackedInt32Array)[i], "tracked": true}
	return Tracking.position_at(tr, mt, fps)


func _ink_of(flags: int) -> Color:
	if (flags & Tracking.LOST) != 0:
		return LOST_INK
	if (flags & Tracking.WEAK) != 0:
		return WEAK_INK
	return GOOD_INK


func _draw_trackers(ci: CanvasItem, pic: Rect2, cx: Dictionary) -> void:
	var s: Dictionary = cx["set"]
	var mt: float = float(cx["mt"])
	var fps: float = float(cx["fps"])
	var span: float = float(PATH_FRAMES) / fps
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	for t: Variant in s.get("trackers", []):
		var tr: Dictionary = t
		for sm: Dictionary in _samples_for(cx, tr):
			var ts: PackedFloat64Array = sm["t"]
			var xs: PackedFloat32Array = sm["x"]
			var ys: PackedFloat32Array = sm["y"]
			var fl: PackedInt32Array = sm["f"]
			var lo: int = maxi(0, Tracking.last_at_or_before(ts, mt - span))
			for i: int in range(lo, ts.size()):
				if ts[i] > mt + span:
					break
				if ts[i] < mt - span:
					continue
				var p: Vector2 = _scr(cx, pic, Vector2(xs[i], ys[i]))
				var hand: bool = (fl[i] & Tracking.HAND) != 0
				ci.draw_circle(p, 3.2 if hand else 1.8, _ink_of(fl[i]))
				if hand:
					ci.draw_arc(p, 3.2, 0.0, TAU, 12, RIM, 1.0, true)
				stats["dots"] = int(stats["dots"]) + 1
		var at: Dictionary = tracker_at(cx, tr)
		var m: Vector2 = at["p"]
		var c: Vector2 = _scr(cx, pic, m)
		var ink: Color = _ink_of(int(at.get("flags", 0))) if bool(at.get("tracked", false)) else CROSS_INK
		var box: PackedVector2Array = PackedVector2Array()
		var half: float = PATTERN_PX * 0.5
		for corner: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)]:
			box.append(_scr(cx, pic, m + corner))
		var tid: String = String(tr.get("id", ""))
		var hot: bool = hover == "tr:" + tid or String(drag.get("tid", "")) == tid
		ci.draw_polyline(box, RIM, 3.0, true)
		ci.draw_polyline(box, ink, 1.5 if not hot else 2.0, true)
		for d: Vector2 in [Vector2(CROSS, 0.0), Vector2(0.0, CROSS)]:
			ci.draw_line(c - d, c + d, RIM, 3.0, true)
			ci.draw_line(c - d, c + d, ink, 1.5, true)
		stats["trackers"] = int(stats["trackers"]) + 1
		if hot:
			_chip(ci, pic, c + Vector2(12.0, 10.0), String(tr.get("name", tid)), font, fs)


func _chip(ci: CanvasItem, pic: Rect2, at: Vector2, text: String, font: Font = null, fs: int = 0) -> void:
	var f: Font = font if font != null else Tk.font("body")
	var size: int = fs if fs > 0 else Tk.fs(Tk.sz("font_small"))
	var pad: float = PmText.pad()
	var w: float = PmText.width_of(f, text, size) + pad * 2.0
	var h: float = f.get_height(size) + 2.0
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	var x: float = clampf(at.x, outer.position.x + 2.0, maxf(outer.end.x - w - 2.0, outer.position.x + 2.0))
	var y: float = clampf(at.y, outer.position.y + 2.0, maxf(outer.end.y - h - 2.0, outer.position.y + 2.0))
	var r: Rect2 = Rect2(Vector2(x, y).round(), Vector2(w, h))
	ci.draw_rect(r, LABEL_BACK, true)
	PmText.draw_in(ci, f, r.grow_individual(-pad, 0.0, -pad, 0.0), text, size, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, r)


func hit(cx: Dictionary, pic: Rect2, p: Vector2) -> String:
	var s: Dictionary = cx["set"]
	for t: Variant in s.get("trackers", []):
		var tr: Dictionary = t
		var c: Vector2 = _scr(cx, pic, tracker_at(cx, tr)["p"])
		if c.distance_to(p) <= REACH:
			return "tr:" + String(tr.get("id", ""))
	if not tool_on():
		return ""
	var areas: Array = s.get("areas", [])
	for ai: int in range(areas.size() - 1, -1, -1):
		var a: Dictionary = areas[ai]
		var poly: PackedVector2Array = _area_screen(cx, pic, a)
		for i: int in poly.size():
			if poly[i].distance_to(p) <= HANDLE:
				return "ap:%s:%d" % [String(a.get("id", "")), i]
	for ai: int in range(areas.size() - 1, -1, -1):
		var a: Dictionary = areas[ai]
		var poly: PackedVector2Array = _area_screen(cx, pic, a)
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
			return "ai:" + String(a.get("id", ""))
	return ""


func _redraw(panel: Object) -> void:
	var v: Variant = panel.get("view")
	if v is Control:
		(v as Control).call("redraw_overlay")


func _accept(panel: Object) -> void:
	var v: Variant = panel.get("view")
	if v is Control:
		(v as Control).accept_event()
		(v as Control).call("redraw_overlay")


func busy() -> bool:
	return not drag.is_empty() or not pen.is_empty()


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not _allowed() and not busy():
		return false
	var cx: Dictionary = ctx()
	if cx.is_empty():
		if busy():
			cancel()
		return false
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not drag.is_empty():
			_drag_to(cx, pic, mm.position, panel)
			_accept(panel)
			return true
		var h: String = hit(cx, pic, mm.position)
		if h != hover:
			hover = h
			_redraw(panel)
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not pen.is_empty():
			_finish_pen(cx)
			_accept(panel)
			return true
		return false
	if not mb.pressed:
		if drag.is_empty():
			return false
		_release(cx, pic, mb.position, panel)
		_accept(panel)
		return true
	if not pen.is_empty() and mb.double_click:
		_finish_pen(cx)
		_accept(panel)
		return true
	var h2: String = hit(cx, pic, mb.position)
	if h2.begins_with("tr:"):
		drag = {"kind": "tracker", "tid": h2.substr(3), "start": mb.position, "moved": false, "grab": _scr(cx, pic, tracker_at(cx, Tracking.tracker_by_id(cx["set"], h2.substr(3)))["p"]) - mb.position}
		_accept(panel)
		return true
	if not tool_on():
		return false
	if not pen.is_empty():
		var first: Vector2 = _scr(cx, pic, pen[0])
		if pen.size() >= 3 and first.distance_to(mb.position) <= CLOSE_REACH:
			_finish_pen(cx)
		else:
			pen.append(_media(cx, pic, mb.position))
		_accept(panel)
		return true
	if h2.begins_with("ap:") or h2.begins_with("ai:"):
		var parts: PackedStringArray = h2.split(":")
		var aid: String = parts[1]
		var s: Dictionary = cx["set"]
		var a: Dictionary = (s["areas"] as Array)[Ops.area_index(s, aid)]
		drag = {"kind": "area_point" if parts[0] == "ap" else "area_move", "aid": aid, "index": int(parts[2]) if parts.size() > 2 else -1, "start": mb.position, "set0": s.duplicate(true), "area0": a.duplicate(true), "pts0": Tracking.area_points_at(a, float(cx["mt"])), "moved": false}
		_accept(panel)
		return true
	if draw_kind == "points":
		pen = PackedVector2Array([_media(cx, pic, mb.position)])
		_accept(panel)
		return true
	if draw_kind == "shape":
		drag = {"kind": "shape", "start": mb.position, "last": mb.position, "pts": PackedVector2Array([_media(cx, pic, mb.position)]), "moved": false}
	else:
		drag = {"kind": "box", "from": mb.position, "to": mb.position, "start": mb.position, "moved": false}
	_accept(panel)
	return true


func _drag_to(cx: Dictionary, pic: Rect2, at: Vector2, panel: Object) -> void:
	var kind: String = String(drag["kind"])
	if not bool(drag["moved"]):
		if at.distance_to(drag["start"]) < SLOP:
			return
		drag["moved"] = true
	var doc: Project = cx["doc"]
	var sid: String = cx["sid"]
	var mt: float = float(cx["mt"])
	if kind == "tracker":
		var p: Vector2 = _media(cx, pic, at + (drag["grab"] as Vector2))
		Ops.move_tracker(doc, sid, String(drag["tid"]), mt, p, true)
		return
	if kind == "box":
		drag["to"] = at
		return
	if kind == "shape":
		if at.distance_to(drag["last"]) >= FREE_STEP:
			var pts: PackedVector2Array = drag["pts"]
			pts.append(_media(cx, pic, at))
			drag["pts"] = pts
			drag["last"] = at
		return
	var pts0: PackedVector2Array = drag["pts0"]
	var a0: Dictionary = drag["area0"]
	var d: Vector2 = _media(cx, pic, at) - _media(cx, pic, drag["start"])
	var pts1: PackedVector2Array = pts0.duplicate()
	if kind == "area_move":
		for i: int in pts1.size():
			pts1[i] = pts0[i] + d
	else:
		var i0: int = int(drag["index"])
		if String(a0.get("kind", "")) == Tracking.KIND_BOX and pts0.size() == 4:
			var moved: Vector2 = pts0[i0] + d
			var opp: Vector2 = pts0[(i0 + 2) % 4]
			pts1 = Tracking.box_points(Rect2(moved, Vector2.ZERO).expand(opp))
		else:
			pts1[i0] = pts0[i0] + d
	var keyed: bool = Tracking.area_keyed(a0)
	var a1: Dictionary = Tracking.with_area_points(a0, mt, pts1, keyed)
	Ops.write_live(doc, sid, Ops.with_area(drag["set0"], a1), "Change track area")


func _release(cx: Dictionary, pic: Rect2, at: Vector2, panel: Object) -> void:
	var kind: String = String(drag["kind"])
	var moved: bool = bool(drag["moved"])
	var doc: Project = cx["doc"]
	var sid: String = cx["sid"]
	var mt: float = float(cx["mt"])
	drag = drag.duplicate()
	var d: Dictionary = drag
	drag = {}
	if kind == "tracker" or kind == "area_point" or kind == "area_move":
		if moved and doc.undo.has_live():
			doc.undo.commit_live("Move tracker" if kind == "tracker" else "Change track area")
		return
	if kind == "box":
		var r: Rect2 = Rect2(d["from"], Vector2.ZERO).expand(at)
		if not moved or r.size.x < MIN_BOX or r.size.y < MIN_BOX:
			return
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			pts.append(_media(cx, pic, p))
		Ops.add_area(doc, sid, Tracking.KIND_BOX, mt, pts, leave_out)
		return
	if kind == "shape":
		var sp: PackedVector2Array = d["pts"]
		if sp.size() >= 3 and _extent(sp) * _k(cx, pic) >= MIN_BOX:
			Ops.add_area(doc, sid, Tracking.KIND_SHAPE, mt, sp, leave_out)


func _extent(pts: PackedVector2Array) -> float:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return minf(hi.x - lo.x, hi.y - lo.y)


func _finish_pen(cx: Dictionary) -> void:
	var pts: PackedVector2Array = pen
	pen = PackedVector2Array()
	if pts.size() >= 3:
		Ops.add_area(cx["doc"], cx["sid"], Tracking.KIND_POINTS, float(cx["mt"]), pts, leave_out)


func cancel() -> void:
	pen = PackedVector2Array()
	if not drag.is_empty():
		var doc: Project = Session.doc
		if doc != null and doc.undo.has_live():
			doc.undo.cancel_live()
	drag = {}


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not e.pressed:
		return false
	if e.keycode == KEY_ESCAPE and busy():
		cancel()
		_redraw(panel)
		return true
	var cx: Dictionary = ctx()
	if cx.is_empty():
		return false
	if not pen.is_empty() and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER):
		_finish_pen(cx)
		_redraw(panel)
		return true
	if not pen.is_empty() and e.keycode == KEY_BACKSPACE:
		pen.remove_at(pen.size() - 1)
		_redraw(panel)
		return true
	if tool_on() and (e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE) and (hover.begins_with("ai:") or hover.begins_with("ap:")):
		var aid: String = hover.split(":")[1]
		hover = ""
		Ops.remove_area(cx["doc"], cx["sid"], aid)
		_redraw(panel)
		return true
	return false
