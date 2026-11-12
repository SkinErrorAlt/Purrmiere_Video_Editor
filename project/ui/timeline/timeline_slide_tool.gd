extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewCutCmds := preload("res://doc/commands/view_cut_cmds.gd")
const DRAG_MODE := "view_cut"
const ORIGIN_KEY := "view_cut"
const NEAR_PX := 9.0
const EPS := 0.00001

static var last_choice: String = ""


static func near_px() -> float:
	return float(Tk.px(NEAR_PX))


static func choose(canvas: Control, s: Sequence, c: Clip, t: Track, x: float) -> Dictionary:
	if s == null or c == null or t == null:
		return {}
	var x0: float = float(canvas.call("x_of", c.start))
	var x1: float = float(canvas.call("x_of", c.end()))
	var reach: float = minf(near_px(), maxf((x1 - x0) * 0.25, 2.0))
	var e: Dictionary = ViewCutCmds.pair_entry(c)
	if not e.is_empty() and ViewMap.cuts_on(e):
		var best: float = INF
		var best_u: float = -1.0
		for u: float in ViewCutCmds.cut_times(c):
			var d: float = absf(float(canvas.call("x_of", c.start + u)) - x)
			if d <= reach and d < best:
				best = d
				best_u = u
		if best_u >= 0.0 and minf(absf(x - x0), absf(x - x1)) > best:
			return {"kind": DRAG_MODE, "u": best_u, "uid": String(e.get("uid", ""))}
	if absf(x - x0) <= reach:
		var prev: Clip = t.prev_clip(c)
		var touching: bool = prev != null and absf(prev.end() - c.start) < EPS
		return {"kind": "roll" if touching else "trim", "side": "head"}
	if absf(x - x1) <= reach:
		var next: Clip = t.next_clip(c)
		var touching2: bool = next != null and absf(next.start - c.end()) < EPS
		return {"kind": "roll" if touching2 else "trim", "side": "tail"}
	return {"kind": "slide"}


static func press(canvas: Control, h: Dictionary, pos: Vector2, mods: Dictionary) -> void:
	var s: Sequence = canvas.call("seq")
	var c: Clip = h.get("clip", null)
	var t: Track = h.get("track", null)
	var drag: RefCounted = canvas.get("drag")
	var pick: Dictionary = choose(canvas, s, c, t, pos.x)
	var kind: String = String(pick.get("kind", "slide"))
	last_choice = kind
	if t != null and t.locked and kind != "slide":
		Events.toast("This track is locked, unlock it to move the cut")
		return
	if kind == DRAG_MODE:
		drag.call("begin", DRAG_MODE, h, pos, mods)
		var fps: float = maxf(s.fps, 1.0)
		var u: float = float(pick["u"])
		(drag.get("origin") as Dictionary)[ORIGIN_KEY] = {"clip": c.id, "uid": String(pick["uid"]), "u": u, "range": ViewCutCmds.bounds(c, u, 1.0 / fps)}
		return
	if kind == "roll" or kind == "trim":
		var hit: Dictionary = h.duplicate()
		hit["edge"] = String(pick["side"])
		drag.call("begin", kind, hit, pos, mods)
		return
	drag.call("begin", "slide", h, pos, mods)


static func drag_motion(host: Control, drag: RefCounted, pos: Vector2, _mods: Dictionary) -> bool:
	var info: Dictionary = (drag.get("origin") as Dictionary).get(ORIGIN_KEY, {})
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	if info.is_empty() or d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(String(info["clip"]))
	if c == null:
		return true
	var press: Vector2 = drag.get("press")
	var u0: float = float(info["u"])
	var pps: float = maxf(float(host.get("pps")), 0.000001)
	var want: float = c.start + u0 + (pos.x - press.x) / pps
	var snapped: float = float(drag.call("snap", want)) - c.start
	var r: Vector2 = info["range"]
	var u1: float = clampf(snapped, r.x, r.y)
	drag.set("value_a", c.start + u1)
	drag.set("delta_t", u1 - u0)
	if absf(u1 - u0) < EPS:
		if not String(drag.get("live_key")).is_empty():
			d.undo.cancel_live()
			drag.set("live_key", "")
		return true
	var cmd: ViewCutCmds.MoveViewCut = ViewCutCmds.MoveViewCut.new(s.id, c.id, String(info["uid"]), u0, u1)
	d.undo.live(cmd)
	drag.set("live_key", DRAG_MODE)
	return true


static func drag_release(_host: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var host: Control = drag.get("host")
	var d: Project = host.call("doc") if host != null else null
	if d == null:
		return false
	if String(drag.get("live_key")).is_empty() or not d.undo.has_live():
		return false
	d.undo.commit_live(ViewCutCmds.LABEL)
	drag.set("live_key", "")
	return true
