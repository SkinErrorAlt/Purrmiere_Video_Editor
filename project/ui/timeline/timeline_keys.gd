extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const KeyEditor := preload("res://ui/timeline/keyframe_editor.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SELF_PATH := "res://ui/timeline/timeline_keys.gd"
const BUS_PATH := "res://modules/core_panels/panel_bus.gd"
const DRAG_MODE := "keys"
const META_SEL := "keys_selected"
const REACH := 6.0
const EDGE_ROOM := 4.0
const SNAP_PX := 8.0
const LEVEL_PATH := "audio.volume"
const LEVEL_LO := 0.0
const LEVEL_HI := 2.0
const RING := 7.5
const REVEAL_FRAMES := 3
const TOOLS: PackedStringArray = ["select", "pen"]
const LOCKED_TEXT := "This clip is on a locked track or in a locked group, unlock it to change its keys"
const BEND_MIN_U := 0.1
const BEND_MAX_U := 0.9
const BEND_LABEL := "Curve volume"

static var reveals: int = 0
static var editors_reached: int = 0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func _bus() -> RefCounted:
	var script: GDScript = load(BUS_PATH)
	return script.call("instance")


static func selected(canvas: Control) -> Dictionary:
	if canvas == null or not canvas.has_meta(META_SEL):
		return {}
	var v: Variant = canvas.get_meta(META_SEL)
	return v if v is Dictionary else {}


static func clear(canvas: Control) -> void:
	if canvas != null and canvas.has_meta(META_SEL):
		canvas.remove_meta(META_SEL)
		canvas.queue_redraw()


static func store(canvas: Control, clip_id: String, keys: Array, level: bool) -> void:
	var s: Sequence = canvas.call("seq")
	var snap: PackedStringArray = s.selected_clip_ids.duplicate() if s != null else PackedStringArray()
	canvas.set_meta(META_SEL, {"clip": clip_id, "keys": keys.duplicate(true), "level": level, "clips": snap})
	canvas.queue_redraw()


static func dragging(canvas: Control) -> bool:
	var drag: RefCounted = canvas.get("drag")
	return drag != null and String(drag.get("mode")) == DRAG_MODE


static func valid(canvas: Control) -> Dictionary:
	var sel: Dictionary = selected(canvas)
	if sel.is_empty():
		return {}
	var s: Sequence = canvas.call("seq")
	var c: Clip = s.clip_by_id(String(sel.get("clip", ""))) if s != null else null
	if c == null or s.selected_clip_ids != (sel.get("clips", PackedStringArray()) as PackedStringArray):
		clear(canvas)
		return {}
	if dragging(canvas):
		return sel
	var kept: Array = []
	for k: Dictionary in sel.get("keys", []):
		if AnimProp.find_key(c.get_param(String(k["path"])), float(k["t"])) >= 0:
			kept.append(k)
	if kept.is_empty():
		clear(canvas)
		return {}
	if kept.size() != (sel["keys"] as Array).size():
		sel["keys"] = kept
		canvas.set_meta(META_SEL, sel)
	return sel


static func times_by_path(keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for k: Dictionary in keys:
		var path: String = String(k["path"])
		if not out.has(path):
			out[path] = PackedFloat64Array()
		var list: PackedFloat64Array = out[path]
		list.append(float(k["t"]))
		out[path] = list
	return out


static func warped(c: Clip, path: String) -> bool:
	return c.anim_warped() if AnimTime.exempt(path) else c.path_warped(path)


static func played_of(c: Clip, path: String, t: float) -> float:
	return c.first_played_for(path, t) if warped(c, path) else t


static func clip_frame(g: Dictionary, l: Dictionary, tr: Track, c: Clip) -> Dictionary:
	var lane_y: float = Hit.lane_screen_y(g, l)
	var body_h: float = float(l["h"]) - 2.0
	if body_h < Paint.KEY_MIN_H or bool(l["nest"]):
		return {}
	var header_w: float = float(g["header_w"])
	var x0: float = Hit.x_of(g, c.start)
	var x1: float = Hit.x_of(g, c.end())
	var lo_x: float = maxf(x0, header_w)
	var hi_x: float = minf(x1, float(g["width"]))
	if hi_x - lo_x < 1.0:
		return {}
	var out: Dictionary = {"x0": x0, "lo_x": lo_x, "hi_x": hi_x, "pps": float(g["pps"]), "level": tr.is_sound(c), "set": String(l["set"])}
	if tr.is_sound(c):
		var inner_h: float = body_h - Paint.name_row_h() - 4.0
		if inner_h < 6.0 or hi_x - lo_x < 4.0:
			return {}
		out["top"] = lane_y + 1.0 + Paint.name_row_h() + 2.0
		out["inner_h"] = inner_h
		out["room"] = EDGE_ROOM
	else:
		out["row_y"] = lane_y + 1.0 + body_h - 7.0
		out["room"] = 0.0
	return out


static func paths_of(fr: Dictionary, c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var candidates: PackedStringArray = PackedStringArray([LEVEL_PATH]) if bool(fr["level"]) else c.param_paths()
	for path: String in candidates:
		if AnimProp.is_animated(c.get_param(path)):
			out.append(path)
	return out


static func value_at(c: Clip, path: String, t: float) -> float:
	return Paint.curve_values(c.get_param(path), PackedFloat64Array([t]), c.duration, 0.0, 0, true)[0]


static func key_pos(fr: Dictionary, c: Clip, path: String, t: float) -> Vector2:
	var x: float = float(fr["x0"]) + played_of(c, path, t) * float(fr["pps"])
	if not bool(fr["level"]):
		return Vector2(x, float(fr["row_y"]))
	var inner_h: float = float(fr["inner_h"])
	var v: float = clampf(value_at(c, path, t), LEVEL_LO, LEVEL_HI)
	return Vector2(x, float(fr["top"]) + inner_h - (v - LEVEL_LO) / (LEVEL_HI - LEVEL_LO) * inner_h)


static func hit(canvas: Control, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return {}
	var h: Dictionary = canvas.call("hit_at", pos)
	if String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)):
		return {}
	var tr: Track = h.get("track", null)
	var l: Dictionary = h.get("lane", {})
	if tr == null or l.is_empty():
		return {}
	var g: Dictionary = canvas.call("geometry")
	var pps: float = maxf(float(g["pps"]), 0.000001)
	var t: float = Hit.t_of(g, pos.x)
	var best: Dictionary = {}
	var best_d: float = REACH + 0.001
	for c: Clip in tr.clips_in_range(t - REACH / pps, t + REACH / pps):
		var fr: Dictionary = clip_frame(g, l, tr, c)
		if fr.is_empty():
			continue
		var room: float = float(fr["room"])
		for path: String in paths_of(fr, c):
			for k: Dictionary in Paint.key_list(c.get_param(path)):
				var kt: float = float(k.get("t", 0.0))
				var kx: float = float(fr["x0"]) + played_of(c, path, kt) * pps
				if absf(kx - pos.x) > REACH or kx < float(fr["lo_x"]) - room or kx > float(fr["hi_x"]) + room:
					continue
				var kp: Vector2 = key_pos(fr, c, path, kt)
				var d: float = kp.distance_to(pos)
				if d <= best_d:
					best_d = d
					best = {"clip": c, "track": tr, "lane": l, "frame": fr, "path": path, "t": kt, "pos": kp}
	if best.is_empty():
		return {}
	var bc: Clip = best["clip"]
	var bfr: Dictionary = best["frame"]
	var keys: Array = [{"path": String(best["path"]), "t": float(best["t"])}]
	if not bool(bfr["level"]):
		var bx: float = (best["pos"] as Vector2).x
		for path2: String in paths_of(bfr, bc):
			for k2: Dictionary in Paint.key_list(bc.get_param(path2)):
				var kt2: float = float(k2.get("t", 0.0))
				if path2 == String(best["path"]) and absf(kt2 - float(best["t"])) <= AnimProp.KEY_TOLERANCE:
					continue
				var kx2: float = float(bfr["x0"]) + played_of(bc, path2, kt2) * pps
				if absf(kx2 - bx) <= Paint.KEY_GAP:
					keys.append({"path": path2, "t": kt2})
	best["keys"] = keys
	best["level"] = bool(bfr["level"])
	return best


static func _has(keys: Array, k: Dictionary) -> int:
	for i: int in keys.size():
		var o: Dictionary = keys[i]
		if String(o["path"]) == String(k["path"]) and absf(float(o["t"]) - float(k["t"])) <= AnimProp.KEY_TOLERANCE:
			return i
	return -1


static func overlaps(a: Array, b: Array) -> bool:
	for k: Dictionary in b:
		if _has(a, k) >= 0:
			return true
	return false


static func editable(canvas: Control, c: Clip) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null or c == null:
		return false
	var tr: Track = s.track_of(c.id)
	return tr != null and not tr.locked and not s.group_locked(c)


static func _pick_clip(canvas: Control, c: Clip) -> void:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return
	if s.selected_clip_ids.size() == 1 and s.selected_clip_ids[0] == c.id:
		return
	Verbs.select_tracks(d, s, PackedStringArray(), "replace")
	Verbs.select(d, s, PackedStringArray([c.id]), "replace", PackedStringArray([c.id]))


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	if not TOOLS.has(Session.tool_id):
		return false
	var alt: bool = bool(mods.get("alt", false))
	var sel: Dictionary = valid(canvas)
	if not alt and sel.is_empty():
		return false
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty():
		if alt and _begin_bend(canvas, pos, mods):
			return true
		clear(canvas)
		return false
	var c: Clip = hr["clip"]
	var picked: Array = hr["keys"]
	var same_clip: bool = not sel.is_empty() and String(sel["clip"]) == c.id
	var on_sel: bool = same_clip and overlaps(sel["keys"], picked)
	if not alt:
		if not on_sel:
			clear(canvas)
			return false
		_begin_drag(canvas, hr, pos, mods)
		return true
	if bool(mods.get("shift", false)) and same_clip:
		var keys: Array = (sel["keys"] as Array).duplicate(true)
		if on_sel:
			for k: Dictionary in picked:
				var i: int = _has(keys, k)
				if i >= 0:
					keys.remove_at(i)
		else:
			for k2: Dictionary in picked:
				if _has(keys, k2) < 0:
					keys.append(k2)
		if keys.is_empty():
			clear(canvas)
			return true
		store(canvas, c.id, keys, bool(hr["level"]))
		reveal(canvas)
		if not on_sel:
			_begin_drag(canvas, hr, pos, mods)
		return true
	_pick_clip(canvas, c)
	store(canvas, c.id, picked, bool(hr["level"]))
	reveal(canvas)
	_begin_drag(canvas, hr, pos, mods)
	return true


static func segment_hit(canvas: Control, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return {}
	var h: Dictionary = canvas.call("hit_at", pos)
	if String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)):
		return {}
	var tr: Track = h.get("track", null)
	var l: Dictionary = h.get("lane", {})
	if tr == null or l.is_empty():
		return {}
	var g: Dictionary = canvas.call("geometry")
	var pps: float = maxf(float(g["pps"]), 0.000001)
	var t: float = Hit.t_of(g, pos.x)
	for c: Clip in tr.clips_in_range(t, t):
		var fr: Dictionary = clip_frame(g, l, tr, c)
		if fr.is_empty() or not bool(fr["level"]):
			continue
		var p: Dictionary = c.get_param(LEVEL_PATH)
		if not AnimProp.is_animated(p):
			continue
		var played: float = (pos.x - float(fr["x0"])) / pps
		var kt: float = c.param_time(LEVEL_PATH, played) if warped(c, LEVEL_PATH) else played
		var span: Vector2 = segment_around(p, kt)
		if span.x < 0.0:
			continue
		var line: Vector2 = key_pos(fr, c, LEVEL_PATH, kt)
		if absf(line.y - pos.y) > REACH:
			continue
		return {"clip": c, "track": tr, "lane": l, "frame": fr, "path": LEVEL_PATH, "ta": span.x, "tb": span.y, "t": kt, "pos": line}
	return {}


static func segment_around(p: Dictionary, t: float) -> Vector2:
	var ta: float = -1.0
	var tb: float = -1.0
	for k: Dictionary in Paint.key_list(p):
		var at: float = float(k.get("t", 0.0))
		if at <= t:
			ta = at
		elif tb < 0.0:
			tb = at
	if ta < 0.0 or tb < 0.0 or tb - ta <= AnimProp.KEY_TOLERANCE * 2.0:
		return Vector2(-1.0, -1.0)
	if t - ta <= AnimProp.KEY_TOLERANCE or tb - t <= AnimProp.KEY_TOLERANCE:
		return Vector2(-1.0, -1.0)
	return Vector2(ta, tb)


static func bend(p: Dictionary, ta: float, tb: float, va: float, vb: float, t: float, want: float) -> Dictionary:
	var seg: float = tb - ta
	if seg <= AnimProp.KEY_TOLERANCE or AnimProp.find_key(p, ta) < 0 or AnimProp.find_key(p, tb) < 0:
		return p
	var u: float = clampf((t - ta) / seg, BEND_MIN_U, BEND_MAX_U)
	var straight: float = va + (vb - va) * u
	var lift: float = (want - straight) / (3.0 * u * (1.0 - u))
	var mid: float = (va + vb) * 0.5
	lift = clampf(lift, (LEVEL_LO - mid) / 0.75, (LEVEL_HI - mid) / 0.75)
	var next: Dictionary = AnimProp.set_key_fields(p, ta, {"i": "bezier", "ho": [seg / 3.0, lift]})
	return AnimProp.set_key_fields(next, tb, {"hi": [-seg / 3.0, lift]})


static func _begin_bend(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	var sh: Dictionary = segment_hit(canvas, pos)
	if sh.is_empty():
		return false
	var c: Clip = sh["clip"]
	clear(canvas)
	var drag: RefCounted = canvas.get("drag")
	drag.call("begin", DRAG_MODE, canvas.call("hit_at", pos), pos, mods)
	drag.set("clip_id", c.id)
	var path: String = String(sh["path"])
	var ta: float = float(sh["ta"])
	var tb: float = float(sh["tb"])
	var fr: Dictionary = sh["frame"]
	var origin: Dictionary = drag.get("origin")
	origin["keys"] = {"clip": c.id, "bend": true, "path": path, "prop": c.get_param(path).duplicate(true), "ta": ta, "tb": tb, "t": float(sh["t"]), "va": value_at(c, path, ta), "vb": value_at(c, path, tb), "v0": value_at(c, path, float(sh["t"])), "inner_h": float(fr.get("inner_h", 40.0)), "editable": editable(canvas, c), "level": true, "next": {}}
	return true


static func _bend_next(info: Dictionary, dy: float) -> Dictionary:
	var want: float = clampf(float(info["v0"]) + dy / maxf(float(info["inner_h"]), 1.0) * (LEVEL_HI - LEVEL_LO), LEVEL_LO, LEVEL_HI)
	return bend(info["prop"], float(info["ta"]), float(info["tb"]), float(info["va"]), float(info["vb"]), float(info["t"]), want)


static func _bend_motion(host: Control, drag: RefCounted, info: Dictionary, pos: Vector2) -> bool:
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	var c: Clip = s.clip_by_id(String(info["clip"])) if s != null else null
	if d == null or c == null or not bool(info["editable"]):
		return true
	var dy: float = (drag.get("press") as Vector2).y - pos.y
	if absf(dy) < 1.0:
		info["next"] = {}
		if not String(drag.get("live_key")).is_empty():
			d.undo.cancel_live()
			drag.set("live_key", "")
		return true
	var next: Dictionary = _bend_next(info, dy)
	info["next"] = next
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, String(info["path"]), next))
	drag.set("live_key", DRAG_MODE)
	return true


static func _bend_release(host: Control, drag: RefCounted, info: Dictionary) -> bool:
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	if d == null or s == null:
		return false
	if not String(drag.get("live_key")).is_empty():
		d.undo.cancel_live()
	var c: Clip = s.clip_by_id(String(info["clip"]))
	if c == null:
		return false
	if not bool(info["editable"]):
		Events.toast(LOCKED_TEXT)
		return false
	var next: Dictionary = info.get("next", {})
	if next.is_empty() or next == c.get_param(String(info["path"])):
		return false
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, String(info["path"]), next)
	cmd.label = BEND_LABEL
	return Verbs.run(d, BEND_LABEL, [cmd])


static func _begin_drag(canvas: Control, hr: Dictionary, pos: Vector2, mods: Dictionary) -> void:
	var sel: Dictionary = valid(canvas)
	if sel.is_empty():
		return
	var c: Clip = hr["clip"]
	var drag: RefCounted = canvas.get("drag")
	drag.call("begin", DRAG_MODE, canvas.call("hit_at", pos), pos, mods)
	drag.set("clip_id", c.id)
	var props: Dictionary = {}
	for path: String in times_by_path(sel["keys"]).keys():
		props[path] = c.get_param(path).duplicate(true)
	var fr: Dictionary = hr["frame"]
	var origin: Dictionary = drag.get("origin")
	origin["keys"] = {"clip": c.id, "keys": (sel["keys"] as Array).duplicate(true), "props": props, "level": bool(sel["level"]), "anchor": {"path": String(hr["path"]), "t": float(hr["t"])}, "inner_h": float(fr.get("inner_h", 40.0)), "editable": editable(canvas, c), "du": 0.0, "dv": 0.0}


static func _snap_time(host: Control, drag: RefCounted, want: float, pps: float) -> float:
	drag.set("snap_x", -INF)
	var targets: PackedFloat64Array = drag.get("snap_targets")
	if bool(host.get("snapping")) and not targets.is_empty():
		var reach: float = SNAP_PX / maxf(pps, 0.000001)
		var i: int = targets.bsearch(want)
		var best: float = want
		var best_d: float = reach
		for j: int in [i - 1, i]:
			if j < 0 or j >= targets.size():
				continue
			var d: float = absf(targets[j] - want)
			if d < best_d:
				best_d = d
				best = targets[j]
		if best_d < reach:
			drag.set("snap_x", float(host.call("x_of", best)))
			return best
	var fps: float = float(host.call("fps"))
	return round(want * fps) / fps


static func _dt_for(c: Clip, path: String, times: PackedFloat64Array, du: float) -> float:
	if times.is_empty() or not warped(c, path):
		return du
	var kt: float = times[0]
	return c.param_time(path, played_of(c, path, kt) + du) - kt


static func _moves(info: Dictionary, c: Clip, du: float, dv: float) -> Dictionary:
	var props: Dictionary = info["props"]
	var by_path: Dictionary = times_by_path(info["keys"])
	var out: Dictionary = {}
	var moved: Array = []
	for path: String in props.keys():
		var times: PackedFloat64Array = by_path.get(path, PackedFloat64Array())
		var dt: float = _dt_for(c, path, times, du)
		out[path] = KeyEditor.move_keys(props[path], times, dt, dv)
		for t: float in times:
			moved.append({"path": path, "t": maxf(t + dt, 0.0)})
	return {"props": out, "keys": moved}


static func drag_motion(host: Control, drag: RefCounted, pos: Vector2, mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get("keys", {})
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	if info.is_empty() or d == null or s == null:
		return false
	if bool(info.get("bend", false)):
		return _bend_motion(host, drag, info, pos)
	var c: Clip = s.clip_by_id(String(info["clip"]))
	if c == null or not bool(info["editable"]):
		return true
	var press: Vector2 = drag.get("press")
	var pps: float = maxf(float(host.get("pps")), 0.000001)
	var dx: float = pos.x - press.x
	var dy: float = press.y - pos.y if bool(info["level"]) else 0.0
	if bool(mods.get("shift", false)):
		if absf(dx) >= absf(dy):
			dy = 0.0
		else:
			dx = 0.0
	var anchor: Dictionary = info["anchor"]
	var a_played: float = played_of(c, String(anchor["path"]), float(anchor["t"]))
	var du: float = 0.0
	drag.set("snap_x", -INF)
	if dx != 0.0:
		du = _snap_time(host, drag, c.start + a_played + dx / pps, pps) - c.start - a_played
	var lo_p: float = INF
	var hi_p: float = -INF
	var lo_v: float = INF
	var hi_v: float = -INF
	var props: Dictionary = info["props"]
	for k: Dictionary in info["keys"]:
		var path: String = String(k["path"])
		var p: float = played_of(c, path, float(k["t"]))
		lo_p = minf(lo_p, p)
		hi_p = maxf(hi_p, p)
		var v: float = Paint.curve_values(props[path], PackedFloat64Array([float(k["t"])]), c.duration, 0.0, 0, true)[0]
		lo_v = minf(lo_v, v)
		hi_v = maxf(hi_v, v)
	du = clampf(du, -lo_p, maxf(c.duration - hi_p, -lo_p))
	var dv: float = 0.0
	if dy != 0.0:
		dv = clampf(dy / maxf(float(info["inner_h"]), 1.0) * (LEVEL_HI - LEVEL_LO), minf(LEVEL_LO - lo_v, 0.0), maxf(LEVEL_HI - hi_v, 0.0))
	info["du"] = du
	info["dv"] = dv
	drag.set("delta_t", du)
	drag.set("value_a", dv)
	if absf(du) < 0.0000001 and absf(dv) < 0.0000001:
		if not String(drag.get("live_key")).is_empty():
			d.undo.cancel_live()
			drag.set("live_key", "")
		return true
	var mv: Dictionary = _moves(info, c, du, dv)
	var next: Dictionary = mv["props"]
	for path2: String in next.keys():
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path2, next[path2]))
	drag.set("live_key", DRAG_MODE)
	return true


static func drag_release(host: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get("keys", {})
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	if d == null or s == null or info.is_empty():
		return false
	if bool(info.get("bend", false)):
		return _bend_release(host, drag, info)
	if not String(drag.get("live_key")).is_empty():
		d.undo.cancel_live()
	var c: Clip = s.clip_by_id(String(info["clip"]))
	if c == null:
		return false
	if not bool(info["editable"]):
		Events.toast(LOCKED_TEXT)
		return false
	var du: float = float(info.get("du", 0.0))
	var dv: float = float(info.get("dv", 0.0))
	if absf(du) < 0.0000001 and absf(dv) < 0.0000001:
		return false
	var mv: Dictionary = _moves(info, c, du, dv)
	var next: Dictionary = mv["props"]
	var cmds: Array[Command] = []
	for path: String in next.keys():
		if next[path] != c.get_param(path):
			cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path, next[path]))
	var count: int = (info["keys"] as Array).size()
	var label: String = "Move key" if count == 1 else "Move keys"
	for cmd: Command in cmds:
		cmd.label = label
	var ok: bool = Verbs.run(d, label, cmds)
	if ok:
		store(host, c.id, mv["keys"], bool(info["level"]))
		reveal(host)
	return ok


static func draw(canvas: Control) -> void:
	var sel: Dictionary = selected(canvas)
	if sel.is_empty():
		return
	var s: Sequence = canvas.call("seq")
	var c: Clip = s.clip_by_id(String(sel.get("clip", ""))) if s != null else null
	if c == null:
		return
	var tr: Track = s.track_of(c.id)
	if tr == null:
		return
	var l: Dictionary = Lanes.lane_for_track(canvas.call("lanes"), tr.id)
	if l.is_empty():
		return
	var g: Dictionary = canvas.call("geometry")
	var fr: Dictionary = clip_frame(g, l, tr, c)
	if fr.is_empty():
		return
	var keys: Array = sel.get("keys", [])
	var drag: RefCounted = canvas.get("drag")
	if dragging(canvas) and bool(drag.get("active")):
		var info: Dictionary = (drag.get("origin") as Dictionary).get("keys", {})
		if not info.is_empty() and not bool(info.get("bend", false)) and String(info["clip"]) == c.id:
			keys = _moves(info, c, float(info.get("du", 0.0)), float(info.get("dv", 0.0)))["keys"]
	var region: Rect2 = g["band_rect"] if String(fr["set"]) == "band" else g["main_rect"]
	var header_w: float = float(g["header_w"])
	var width: float = float(g["width"])
	var sol: Color = Tk.c["sol"]
	var inv: Color = Tk.c["inv"]
	for k: Dictionary in keys:
		var kp: Vector2 = key_pos(fr, c, String(k["path"]), float(k["t"]))
		if kp.x < header_w - RING or kp.x > width + RING or kp.y < region.position.y or kp.y > region.end.y:
			continue
		canvas.draw_arc(kp, RING + 1.5, 0.0, TAU, 24, inv, 1.0, true)
		canvas.draw_arc(kp, RING, 0.0, TAU, 24, sol, 2.0, true)
		canvas.draw_arc(kp, RING - 1.5, 0.0, TAU, 24, inv, 1.0, true)
		Paint.draw_diamond(canvas, kp, Paint.DIAMOND + 1.0, sol, true)
		Paint.draw_diamond(canvas, kp, Paint.DIAMOND + 1.0, inv, false)


static func right(canvas: Control, pos: Vector2) -> bool:
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty():
		return false
	var c: Clip = hr["clip"]
	var sel: Dictionary = valid(canvas)
	if sel.is_empty() or String(sel["clip"]) != c.id or not overlaps(sel["keys"], hr["keys"]):
		_pick_clip(canvas, c)
		store(canvas, c.id, hr["keys"], bool(hr["level"]))
		reveal(canvas)
	var m: Control = PmMenu.open(canvas, menu_items(canvas), canvas.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(_script(), "on_menu").bind(canvas))
	return true


static func _interp_of(canvas: Control) -> String:
	var sel: Dictionary = valid(canvas)
	var s: Sequence = canvas.call("seq")
	if sel.is_empty() or s == null:
		return ""
	var c: Clip = s.clip_by_id(String(sel["clip"]))
	var found: String = ""
	for k: Dictionary in sel["keys"]:
		var p: Dictionary = c.get_param(String(k["path"]))
		var i: int = AnimProp.find_key(p, float(k["t"]))
		if i < 0:
			continue
		var interp: String = String((Paint.key_list(p)[i] as Dictionary).get("i", "linear"))
		if found.is_empty():
			found = interp
		elif found != interp:
			return "mixed"
	return found


static func menu_items(canvas: Control) -> Array:
	var sel: Dictionary = valid(canvas)
	var n: int = (sel.get("keys", []) as Array).size()
	var current: String = _interp_of(canvas)
	var items: Array = []
	for pair: Array in KeyEditor.INTERPS:
		items.append(PmMenu.check_item("interp:" + String(pair[0]), String(pair[1]), current == String(pair[0])))
	var fam: Array = []
	for f: String in AnimProp.EASE_FAMILIES:
		fam.append(PmMenu.item("ease:" + f, f.capitalize()))
	items.append(PmMenu.sub_item("family", "Ease family", fam))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("goto", "Move the playhead to this key" if n == 1 else "Move the playhead to the first key"))
	items.append(PmMenu.item("open_keys", "Show in the Keyframes panel"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("delete", "Delete key" if n == 1 else "Delete " + str(n) + " keys", Cmd.keys_text("edit.delete"), "trash"))
	return items


static func on_menu(id: String, canvas: Control) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	if id.begins_with("interp:"):
		set_interp(canvas, id.substr(7), "")
	elif id.begins_with("ease:"):
		set_interp(canvas, "ease_both", id.substr(5))
	elif id == "goto":
		go_to(canvas)
	elif id == "open_keys":
		open_keyframes_panel(canvas)
	elif id == "delete":
		delete_selected(canvas)


static func _edit(canvas: Control, label: String, change: Callable) -> bool:
	var sel: Dictionary = valid(canvas)
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if sel.is_empty() or d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(String(sel["clip"]))
	if not editable(canvas, c):
		Events.toast(LOCKED_TEXT)
		return false
	var cmds: Array[Command] = []
	var by_path: Dictionary = times_by_path(sel["keys"])
	for path: String in by_path.keys():
		var p: Dictionary = c.get_param(path)
		var next: Dictionary = change.call(p, by_path[path])
		if next != p:
			var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, path, next)
			cmd.label = label
			cmds.append(cmd)
	return Verbs.run(d, label, cmds)


static func set_interp(canvas: Control, interp: String, ease: String) -> bool:
	return _edit(canvas, "Ease " + interp, func(p: Dictionary, times: PackedFloat64Array) -> Dictionary: return KeyEditor.set_interp(p, times, interp, ease))


static func delete_selected(canvas: Control) -> bool:
	if canvas == null or not is_instance_valid(canvas):
		return false
	var sel: Dictionary = valid(canvas)
	if sel.is_empty():
		return false
	var n: int = (sel["keys"] as Array).size()
	var ok: bool = _edit(canvas, "Delete key" if n == 1 else "Delete keys", func(p: Dictionary, times: PackedFloat64Array) -> Dictionary: return KeyEditor.remove_keys(p, times))
	if ok:
		clear(canvas)
	return true


static func timeline_canvas() -> Control:
	var tl: Object = _bus().call("panel", "timeline")
	if tl == null:
		return null
	var c: Variant = tl.get("canvas")
	return c if c is Control and is_instance_valid(c) else null


static func delete_from_timeline() -> bool:
	return delete_selected(timeline_canvas())


static func go_to(canvas: Control) -> void:
	var sel: Dictionary = valid(canvas)
	var s: Sequence = canvas.call("seq")
	if sel.is_empty() or s == null:
		return
	var c: Clip = s.clip_by_id(String(sel["clip"]))
	var first: float = INF
	for k: Dictionary in sel["keys"]:
		first = minf(first, played_of(c, String(k["path"]), float(k["t"])))
	if first < INF:
		Session.set_playhead(c.start + clampf(first, 0.0, c.duration))


static func open_keyframes_panel(canvas: Control) -> void:
	var editor: Node = canvas.get_tree().root.find_child("EditorScreen", true, false) if canvas.get_tree() != null else null
	if editor != null and editor.get("dock") != null:
		(editor.get("dock") as Node).call("show_panel", "keyframes")
	reveal(canvas)


static func reveal(canvas: Control) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	reveals += 1
	reveal_now(canvas)
	var tree: SceneTree = canvas.get_tree()
	if tree == null:
		return
	var later: Callable = Callable(_script(), "_reveal_later").bind(canvas, REVEAL_FRAMES - 1)
	if not tree.process_frame.is_connected(later):
		tree.process_frame.connect(later, CONNECT_ONE_SHOT)


static func _reveal_later(canvas: Control, left: int) -> void:
	if canvas == null or not is_instance_valid(canvas) or not canvas.is_inside_tree():
		return
	reveal_now(canvas)
	if left > 0:
		var later: Callable = Callable(_script(), "_reveal_later").bind(canvas, left - 1)
		if not canvas.get_tree().process_frame.is_connected(later):
			canvas.get_tree().process_frame.connect(later, CONNECT_ONE_SHOT)


static func _panel_path(kp: Object, c: Clip, by_path: Dictionary) -> String:
	var listed: Dictionary = {}
	for it: Dictionary in kp.call("properties_of", c):
		listed[String(it["path"])] = true
	var cur: String = String(kp.get("property_path"))
	if by_path.has(cur) and listed.has(cur):
		return cur
	for path: String in by_path.keys():
		if listed.has(path):
			return path
	return ""


static func reveal_now(canvas: Control) -> int:
	var sel: Dictionary = valid(canvas)
	var s: Sequence = canvas.call("seq")
	var tree: SceneTree = canvas.get_tree()
	if sel.is_empty() or s == null or tree == null:
		return 0
	var c: Clip = s.clip_by_id(String(sel["clip"]))
	var by_path: Dictionary = times_by_path(sel["keys"])
	var kp: Object = _bus().call("panel", "keyframes")
	var kp_editor: Variant = kp.get("editor") if kp != null else null
	if kp != null and is_instance_valid(kp_editor) and kp_editor is Control and (kp_editor as Control).is_inside_tree():
		var want: String = _panel_path(kp, c, by_path)
		if not want.is_empty() and (String(kp.get("_clip_id")) != c.id or String(kp.get("property_path")) != want):
			kp.call("show_property", c.id, want)
	var n: int = 0
	for node: Node in tree.get_nodes_in_group(KeyEditor.PEER_GROUP):
		if not (node is Control) or not node.is_inside_tree():
			continue
		if String(node.get("clip_id")) != c.id or not by_path.has(String(node.get("path"))):
			continue
		focus_editor(node as Control, by_path[String(node.get("path"))])
		n += 1
	editors_reached = n
	return n


static func focus_editor(e: Control, times: PackedFloat64Array) -> void:
	if times.is_empty():
		return
	if bool(e.get("_fit_pending")):
		e.call("fit")
	var have: PackedFloat64Array = e.call("selected_times")
	if have != KeyEditor.sorted_times(times) or (e.get("selected") as PackedFloat64Array).size() != times.size():
		e.call("select_keys", times, false)
	var axes: PackedFloat64Array = e.call("axis_times", times[0])
	var ax: float = axes[0] if not axes.is_empty() else times[0]
	var t0: float = float(e.get("t0"))
	var t1: float = float(e.get("t1"))
	if ax < t0 or ax > t1:
		e.call("pan_time", ax - (t0 + t1) * 0.5)
	else:
		e.call("keep_time_in_view", ax)
	if String(e.get("mode")) == "value":
		var c: Clip = e.call("clip")
		if c != null:
			var v: float = KeyEditor.comp0(AnimProp.evaluate(c.get_param(String(e.get("path"))), times[0], c.duration, float(e.call("fps"))))
			if v < float(e.get("v0")) or v > float(e.get("v1")):
				e.call("keep_values_in_view", v, v)
	var p: Node = e.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(e)
			break
		p = p.get_parent()
	e.queue_redraw()
