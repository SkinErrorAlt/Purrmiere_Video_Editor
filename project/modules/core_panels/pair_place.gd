extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const LayoutCmds := preload("res://doc/commands/pair_layout_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const ViewMap := preload("res://doc/view_map.gd")
const MonitorSnap := preload("res://modules/core_panels/monitor_snap.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PairCrop := preload("res://engine/pair_crop.gd")
const MonitorHandles := preload("res://modules/core_panels/monitor_handles.gd")
const HANDLE := 7.0
const REACH := 2.0
const SLOP := 3.0
const TURN_REACH := 22.0
const MOVE_LABEL := "Move region"
const SIZE_LABEL := "Size region"
const TURN_LABEL := "Turn region"

var drag: Dictionary = {}
var hover: int = -1
var drags: int = 0


func active() -> bool:
	return not drag.is_empty()


static func source_part(d: Project, s: Sequence, c: Clip, layer: Rect2) -> Rect2:
	if s == null or c == null or not PairLayout.has_pair(c):
		return layer
	var src: Vector2i = LayoutCmds.source_px(d, s, c)
	var sb: Rect2 = PairLayout.source_box(src, PairLayout.canvas_for(src, LayoutCmds.frame_px(s)))
	return Rect2(layer.position + sb.position * layer.size, sb.size * layer.size)


static func _affine(q: PackedVector2Array) -> Transform2D:
	return Transform2D(q[1] - q[0], q[3] - q[0], q[0])


static func uv_to_seq(q: PackedVector2Array, uv: Vector2) -> Vector2:
	return _affine(q) * uv


static func seq_to_uv(q: PackedVector2Array, p: Vector2) -> Vector2:
	return _affine(q).affine_inverse() * p


func targets(panel: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var c: Clip = panel.call("gizmo_clip")
	if s == null or d == null or c == null:
		return out
	var e: Dictionary = PairLayout.pair_entry(c)
	if e.is_empty() or MonitorHandles.crop_mode(c.id, String(e.get("uid", ""))):
		return out
	var made: Dictionary = panel.call("quad_for", c)
	var q: PackedVector2Array = made.get("quad", PackedVector2Array())
	if q.size() != 4:
		return out
	var map: Dictionary = ViewMap.of(e)
	for b: Dictionary in PairLayout.region_boxes(c, e, s.playhead, LayoutCmds.frame_px(s), LayoutCmds.source_px(d, s, c), s.fps):
		var role: String = String(b["role"])
		if role != PairLayout.ROLE_INSET and role != PairLayout.ROLE_SOLO:
			continue
		var box: Rect2 = b.get(PairLayout.FRAME_BOX_KEY, b["box"])
		var spin: Transform2D = PairCrop.turned(b, PairLayout.pivot_of(b))
		var corners: PackedVector2Array = PackedVector2Array()
		for uv: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			corners.append(uv_to_seq(q, spin * uv))
		var row: Dictionary = b.duplicate()
		row["clip_id"] = c.id
		row["uid"] = String(e.get("uid", ""))
		row["seq_quad"] = corners
		row["layer_quad"] = q
		row["colour"] = Tk.label_colour(ViewMap.colour_for(map, int(b["index"])))
		out.append(row)
	return out


func _screen(panel: Object, pic: Rect2, pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(panel.call("_to_picture", pic, p))
	return out


func hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	for t: Dictionary in targets(panel):
		var sq: PackedVector2Array = _screen(panel, pic, t["seq_quad"])
		if at.distance_to(turn_point(sq)) <= HANDLE + REACH:
			return {"target": t, "handle": "turn", "corner": -1}
		for i: int in sq.size():
			if at.distance_to(sq[i]) <= HANDLE + REACH:
				return {"target": t, "handle": "size", "corner": i}
		if Geometry2D.is_point_in_polygon(at, sq):
			return {"target": t, "handle": "move", "corner": -1}
	return {}


static func turn_point(sq: PackedVector2Array) -> Vector2:
	var top: Vector2 = (sq[0] + sq[1]) * 0.5
	var dir: Vector2 = top - (sq[0] + sq[2]) * 0.5
	if dir.length() < 0.001:
		dir = Vector2.UP
	return top + dir.normalized() * TURN_REACH


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if pic.size.x <= 0.0:
		return
	if active():
		var snap: RefCounted = panel.call("snapper")
		if snap != null:
			snap.call("draw", ci, pic)
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	var dragged: int = int(drag.get("index", -1))
	for t: Dictionary in targets(panel):
		var idx: int = int(t["index"])
		var sq: PackedVector2Array = _screen(panel, pic, t["seq_quad"])
		var ink: Color = t["colour"]
		var lit: bool = idx == hover or idx == dragged
		var closed: PackedVector2Array = sq.duplicate()
		closed.append(sq[0])
		ci.draw_polyline(closed, ink if lit else Color(ink.r, ink.g, ink.b, 0.85), 2.0 if lit else 1.0, true)
		for p: Vector2 in sq:
			ci.draw_rect(Rect2(p - Vector2(HANDLE, HANDLE) * 0.5, Vector2(HANDLE, HANDLE)), ink, true)
		var spin_at: Vector2 = turn_point(sq)
		ci.draw_line((sq[0] + sq[1]) * 0.5, spin_at, ink, 1.0, true)
		ci.draw_arc(spin_at, 3.5, 0.0, TAU, 12, ink, 1.5, true)
		var label: String = String(t.get("name", ""))
		if label.strip_edges().is_empty():
			label = "View " + str(idx + 1)
		var pad: float = PmText.pad()
		var lw: float = PmText.width_of(font, label, fs)
		var lh: float = font.get_height(fs)
		var lx: float = clampf(sq[0].x, outer.position.x + pad, maxf(outer.end.x - pad - lw, outer.position.x + pad))
		var ly: float = sq[0].y - pad - lh
		if ly < outer.position.y + 2.0:
			ly = sq[0].y + pad
		var back: Rect2 = Rect2(lx - 3.0, ly, minf(lw, outer.end.x - lx) + 6.0, lh)
		ci.draw_rect(back, Color(0.051, 0.055, 0.063, 0.8), true)
		PmText.draw_in(ci, font, Rect2(lx, ly, outer.end.x - pad - lx, lh), label, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, Rect2(outer.position.x, ly, outer.size.x, lh))


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			if Session.tool_id == "type" or Session.tool_id == "hand":
				return false
			var h: Dictionary = hit(panel, pic, mb.position)
			if h.is_empty():
				return false
			_begin(panel, pic, h, mb.position)
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
			var now: int = int((h2.get("target", {}) as Dictionary).get("index", -1)) if not h2.is_empty() else -1
			if now != hover:
				hover = now
				if view != null:
					view.call("redraw_overlay")
			return false
		_motion(panel, mm)
		if view != null:
			view.accept_event()
			view.call("redraw_overlay")
		return true
	return false


func _begin(panel: Object, pic: Rect2, h: Dictionary, press: Vector2) -> void:
	var t: Dictionary = h["target"]
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var c: Clip = s.clip_by_id(String(t["clip_id"]))
	var e: Dictionary = c.effect_by_uid(String(t["uid"]))
	var index: int = int(t["index"])
	var local: float = s.playhead - c.start
	var sq: PackedVector2Array = t["seq_quad"]
	var centre_seq: Vector2 = (sq[0] + sq[2]) * 0.5
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var lq: PackedVector2Array = t["layer_quad"]
	var place_path: String = LayoutCmds.path_of(String(t["uid"]), PairLayout.place_key(index))
	var size_path: String = LayoutCmds.path_of(String(t["uid"]), PairLayout.size_key(index))
	var bus: Object = panel.call("bus")
	drag = {
		"clip_id": c.id, "uid": String(t["uid"]), "index": index, "handle": String(h["handle"]), "press": press, "open": false,
		"centre_uv": PairLayout.place_at(c, e, index, local, s.fps), "size": PairLayout.size_at(c, e, index, local, s.fps),
		"k": k, "layer_quad": lq, "seq_quad": sq, "pos": centre_seq - Vector2(float(s.width), float(s.height)) * 0.5,
		"centre": panel.call("_to_picture", pic, centre_seq), "place_path": place_path, "size_path": size_path,
		"key_place": float(bus.call("key_time_for", c, place_path, s.playhead)) if bus != null else -1.0,
		"key_size": float(bus.call("key_time_for", c, size_path, s.playhead)) if bus != null else -1.0,
		"axis_x": (sq[1] - sq[0]).normalized(), "axis_y": (sq[3] - sq[0]).normalized(), "label": SIZE_LABEL if String(h["handle"]) == "size" else MOVE_LABEL,
	}
	_begin_turn(c, e, index, local, s, bus, String(h["handle"]))
	drags += 1
	var snap: RefCounted = panel.call("snapper")
	if snap != null:
		snap.call("begin", c, s, d, pic, drag, Callable(panel, "_pick_quad"), Callable(self, "_own_quad"), panel.get("view"))


func _own_quad(_c: Clip) -> Dictionary:
	var sq: PackedVector2Array = drag.get("seq_quad", PackedVector2Array())
	if sq.size() != 4:
		return {}
	return {"quad": sq, "pivot": (sq[0] + sq[2]) * 0.5}


func _motion(panel: Object, mm: InputEventMouseMotion) -> void:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var c: Clip = s.clip_by_id(String(drag["clip_id"])) if s != null else null
	if c == null or d == null:
		return
	var press: Vector2 = drag["press"]
	if not bool(drag["open"]):
		if mm.position.distance_to(press) < SLOP:
			return
		drag["open"] = true
	var k: float = maxf(float(drag["k"]), 0.0001)
	var lq: PackedVector2Array = drag["layer_quad"]
	var snap: RefCounted = panel.call("snapper")
	var bypass: bool = MonitorSnap.bypass(mm)
	if String(drag["handle"]) == "turn":
		_turn_motion(d, s, c, mm, snap, bypass)
		return
	if String(drag["handle"]) == "move":
		var p0: Vector2 = drag["pos"]
		var np: Vector2 = p0 + (mm.position - press) / k
		var along_x: bool = absf(mm.position.x - press.x) > absf(mm.position.y - press.y)
		if mm.shift_pressed:
			if along_x:
				np.y = p0.y
			else:
				np.x = p0.x
		if snap != null:
			np = snap.call("move", np, p0, not mm.shift_pressed or along_x, not mm.shift_pressed or not along_x, k, bypass)
		var centre_seq: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5 + np
		var uv: Vector2 = seq_to_uv(lq, centre_seq)
		_write(d, s, c, String(drag["place_path"]), [clampf(uv.x, PairLayout.PLACE_MIN, PairLayout.PLACE_MAX), clampf(uv.y, PairLayout.PLACE_MIN, PairLayout.PLACE_MAX)], float(drag["key_place"]))
		return
	var centre: Vector2 = drag["centre"]
	var from: Vector2 = press - centre
	var to: Vector2 = mm.position - centre
	var ax: Vector2 = drag["axis_x"]
	var ay: Vector2 = drag["axis_y"]
	var lead_x: bool = absf(from.dot(ax)) >= absf(from.dot(ay))
	var base: float = from.dot(ax) if lead_x else from.dot(ay)
	var f: float = (to.dot(ax) if lead_x else to.dot(ay)) / base if absf(base) >= 1.0 else 1.0
	var s0: float = float(drag["size"])
	var ns: float = maxf(s0 * f, PairLayout.SIZE_MIN)
	if snap != null:
		var got: Vector2 = snap.call("scale", Vector2(ns, ns), Vector2(s0, s0), true, false, mm.position, bypass)
		ns = got.x
	_write(d, s, c, String(drag["size_path"]), clampf(ns, PairLayout.SIZE_MIN, PairLayout.SIZE_MAX), float(drag["key_size"]))


func _write(d: Project, s: Sequence, c: Clip, path: String, value: Variant, key_at: float) -> void:
	if RecordCmds.write(d, s, c.id, path, value, true):
		return
	var current: Dictionary = c.get_param(path)
	var next: Dictionary = AnimProp.make(value) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), c.param_time(path, key_at - c.start), value)
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, path, next)
	cmd.label = String(drag.get("label", MOVE_LABEL))
	d.undo.live(cmd)


func _end(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var label: String = String(drag.get("label", MOVE_LABEL))
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


func _begin_turn(c: Clip, e: Dictionary, index: int, local: float, s: Sequence, bus: Object, handle: String) -> void:
	var turn_path: String = LayoutCmds.path_of(String(drag["uid"]), PairCrop.turn_key(index))
	drag["turn_path"] = turn_path
	drag["turn"] = PairLayout.turn_at(c, e, index, local, s.fps)
	drag["key_turn"] = float(bus.call("key_time_for", c, turn_path, s.playhead)) if bus != null else -1.0
	if handle == "turn":
		drag["label"] = TURN_LABEL


func _turn_motion(d: Project, s: Sequence, c: Clip, mm: InputEventMouseMotion, snap: RefCounted, bypass: bool) -> void:
	var centre: Vector2 = drag["centre"]
	var press: Vector2 = drag["press"]
	var nr: float = float(drag["turn"]) + rad_to_deg(wrapf((mm.position - centre).angle() - (press - centre).angle(), -PI, PI))
	if mm.shift_pressed:
		nr = round(nr / MonitorSnap.ANGLE_STEP) * MonitorSnap.ANGLE_STEP
	elif snap != null:
		nr = float(snap.call("rotate", nr, false, mm.position.distance_to(centre), mm.position, bypass))
	_write(d, s, c, String(drag["turn_path"]), clampf(wrapf(nr, -180.0, 180.0), -180.0, 180.0), float(drag["key_turn"]))
