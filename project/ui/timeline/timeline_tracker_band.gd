extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Tracking := preload("res://doc/tracking.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const DRAG_MODE := "tracker_range"
const TOOL_ID := "track_area"
const PICTURE_TOOLS: PackedStringArray = ["track_area", "object_select"]
const OPS_PATH := "res://modules/core_panels/tracker_ops.gd"
const RUN_PATH := "res://modules/core_panels/tracker_run.gd"
const BAND_H := 5.0
const BOTTOM_GAP := 6.0
const EDGE_REACH := 6.0
const GRIP_W := 4.0
const GRIP_H := 11.0
const MIN_FRAMES := 2.0

static var bands_drawn: int = 0


static func timeline_tool(tool: String) -> String:
	return "select" if PICTURE_TOOLS.has(tool) else tool


static func ink() -> Color:
	return Color(0.36, 0.84, 1.0, 1.0)


static func done_ink() -> Color:
	return Color(0.46, 0.9, 0.6, 1.0)


static func _runner() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("TrackerRun")


static func bands(canvas: Control) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or d.tracking.is_empty():
		return out
	var by_clip: Dictionary = {}
	for k: Variant in d.tracking.keys():
		var st: Dictionary = d.tracking[k]
		by_clip[String(st.get("clip", ""))] = st
	var geom: Dictionary = canvas.call("geometry")
	var ln: Dictionary = canvas.call("lanes")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var t0: float = Hit.t_of(geom, header_w)
	var t1: float = Hit.t_of(geom, width)
	for set_name: String in ["main", "band"]:
		var area: Rect2 = geom["main_rect"] if set_name == "main" else geom["band_rect"]
		if area.size.y <= 0.0:
			continue
		for l: Dictionary in ln[set_name]:
			if bool(l["nest"]):
				continue
			var tr: Track = l["track"]
			var y: float = Hit.lane_screen_y(geom, l)
			var h: float = float(l["h"])
			var by: float = y + h - BAND_H - BOTTOM_GAP
			if by < area.position.y or by + BAND_H > area.end.y or h < 22.0:
				continue
			for c: Clip in tr.clips_in_range(t0, t1):
				if not by_clip.has(c.id):
					continue
				var st: Dictionary = by_clip[c.id]
				var rng: Array = st.get("range", [0.0, 0.0])
				var a: float = TrackingEval.seq_time_of(c, float(rng[0]))
				var b: float = TrackingEval.seq_time_of(c, float(rng[1]))
				var cx0: float = maxf(Hit.x_of(geom, c.start), header_w)
				var cx1: float = minf(Hit.x_of(geom, c.end()), width)
				if cx1 <= cx0:
					continue
				out.append({"sid": String(st["id"]), "clip": c, "a": minf(a, b), "b": maxf(a, b), "y": by, "x0": cx0, "x1": cx1})
	return out


static func drag_state(canvas: Control) -> Dictionary:
	var drag: RefCounted = canvas.get("drag")
	if drag == null or String(drag.get("mode")) != DRAG_MODE:
		return {}
	return (drag.get("origin") as Dictionary).get("tracker", {})


static func draw(canvas: Control) -> void:
	bands_drawn = 0
	var list: Array[Dictionary] = bands(canvas)
	if list.is_empty():
		return
	var geom: Dictionary = canvas.call("geometry")
	var st: Dictionary = drag_state(canvas)
	var run: Node = _runner()
	var running: String = String(run.call("running_set")) if run != null else ""
	for bd: Dictionary in list:
		var a: float = float(bd["a"])
		var b: float = float(bd["b"])
		if String(st.get("sid", "")) == String(bd["sid"]):
			a = float(st["a"])
			b = float(st["b"])
		var x0: float = Hit.x_of(geom, a)
		var x1: float = Hit.x_of(geom, b)
		var vx0: float = maxf(x0, float(bd["x0"]))
		var vx1: float = minf(x1, float(bd["x1"]))
		var y: float = float(bd["y"])
		if vx1 > vx0:
			canvas.draw_rect(Rect2(vx0, y, vx1 - vx0, BAND_H), Color(ink(), 0.35), true)
			canvas.draw_rect(Rect2(vx0, y, vx1 - vx0, BAND_H), Color(ink(), 0.9), false, 1.0)
		if running == String(bd["sid"]):
			var c: Clip = bd["clip"]
			var edge: float = float(run.call("latest_time"))
			var started: Dictionary = run.get("state")
			if not is_nan(edge):
				var e: float = TrackingEval.seq_time_of(c, edge)
				var from: float = TrackingEval.seq_time_of(c, float(started.get("a", 0.0)) if String(started.get("direction", "forward")) == "forward" else float(started.get("b", 0.0)))
				var fx0: float = maxf(Hit.x_of(geom, minf(from, e)), vx0)
				var fx1: float = minf(Hit.x_of(geom, maxf(from, e)), vx1)
				if fx1 > fx0:
					canvas.draw_rect(Rect2(fx0, y, fx1 - fx0, BAND_H), done_ink(), true)
		for gx: float in [x0, x1]:
			if gx >= float(bd["x0"]) - 1.0 and gx <= float(bd["x1"]) + 1.0:
				canvas.draw_rect(Rect2(gx - GRIP_W * 0.5, y + BAND_H * 0.5 - GRIP_H * 0.5, GRIP_W, GRIP_H), Tk.c["text_bright"], true)
		bands_drawn += 1


static func hit(canvas: Control, pos: Vector2) -> Dictionary:
	var geom: Dictionary = canvas.call("geometry")
	for bd: Dictionary in bands(canvas):
		var y: float = float(bd["y"])
		if pos.y < y - 5.0 or pos.y > y + BAND_H + 5.0:
			continue
		for side: String in ["a", "b"]:
			var x: float = Hit.x_of(geom, float(bd[side]))
			if absf(pos.x - x) <= EDGE_REACH and x >= float(bd["x0"]) - EDGE_REACH and x <= float(bd["x1"]) + EDGE_REACH:
				var out: Dictionary = bd.duplicate()
				out["side"] = side
				return out
	return {}


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	var hb: Dictionary = hit(canvas, pos)
	if hb.is_empty():
		return false
	var c: Clip = hb["clip"]
	var drag: RefCounted = canvas.get("drag")
	drag.call("begin", DRAG_MODE, canvas.call("hit_at", pos), pos, mods)
	var origin: Dictionary = drag.get("origin")
	origin["tracker"] = {"sid": String(hb["sid"]), "clip": c.id, "side": String(hb["side"]), "a": float(hb["a"]), "b": float(hb["b"]), "a0": float(hb["a"]), "b0": float(hb["b"]), "lo": c.start, "hi": c.end()}
	return true


static func drag_motion(canvas: Control, drag: RefCounted, pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var st: Dictionary = origin.get("tracker", {})
	var s: Sequence = canvas.call("seq")
	if st.is_empty() or s == null:
		return false
	var t: float = clampf(float(canvas.call("t_of", pos.x)), float(st["lo"]), float(st["hi"]))
	var gap: float = MIN_FRAMES / maxf(s.fps, 1.0)
	if String(st["side"]) == "a":
		st["a"] = minf(t, float(st["b0"]) - gap)
		st["b"] = float(st["b0"])
	else:
		st["b"] = maxf(t, float(st["a0"]) + gap)
		st["a"] = float(st["a0"])
	origin["tracker"] = st
	return true


static func drag_release(canvas: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var st: Dictionary = origin.get("tracker", {})
	var d: Project = canvas.call("doc")
	if st.is_empty() or d == null:
		return false
	if absf(float(st["a"]) - float(st["a0"])) < 0.000001 and absf(float(st["b"]) - float(st["b0"])) < 0.000001:
		return false
	var c: Clip = d.clip_by_id(String(st["clip"]))
	if c == null:
		return false
	return bool(load(OPS_PATH).call("set_range", d, String(st["sid"]), c.source_time(float(st["a"])), c.source_time(float(st["b"])), "Set track range"))
