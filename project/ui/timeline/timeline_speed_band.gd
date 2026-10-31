extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const SpeedCurve := preload("res://doc/speed_curve.gd")
const BandCmds := preload("res://doc/commands/speed_band_cmds.gd")
const SpeedFollow := preload("res://host/speed_follow.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://ui/timeline/timeline_speed_band.gd"
const DRAG_MODE := "speed_band"
const BAND_KEY := "band"
const BAND_SPEED := "speed"
const META_KEY := "speed_band_key"
const MENU_ID := "speed_band"
const MENU_LABEL := "Show speed band"
const KEY_MENU := "band_key:"
const LOG_RANGE := 3.0
const MIN_SPEED := 0.01
const MAX_SPEED := 10.0
const LINE_REACH := 5.0
const KEY_REACH := 6.0
const LINE_STEP := 3.0
const FINE := 0.2
const MIN_INNER := 8.0
const TICK_ALPHA := 0.35
const REF_ALPHA := 0.55
const CHIP_GAP := 14.0
const EASE_FAMILY := "sine"
const TOOLS: PackedStringArray = ["select", "pen"]
const LOCKED_TEXT := "This clip is on a locked track or in a locked group, unlock it to change its speed"
const BACKWARDS_TEXT := "This clip plays backwards or holds a frame, change its speed in Effect Controls"
const LAYERED_TEXT := "This clip's speed uses noise, waves, expressions or a loop, change it in Effect Controls"
const HOLD_FRAMES := 2
const LABEL_LINE := "Speed band"
const LABEL_MOVE := "Move speed key"
const LABEL_RAMP := "Speed ramp"
const LABEL_ADD := "Add speed key"
const LABEL_DELETE := "Delete speed key"

static var draws: int = 0
static var steps: int = 0
static var last_step_us: int = 0
static var max_step_us: int = 0


static func shown(c: Clip) -> bool:
	return c != null and not c.props.is_empty() and String(c.props.get(BAND_KEY, "")) == BAND_SPEED


static func band_top(lane_y: float) -> float:
	return lane_y + 1.0 + Paint.name_row_h() + 2.0


static func band_h(lane_h: float) -> float:
	return lane_h - 2.0 - Paint.name_row_h() - 4.0


static func y_of(v: float, top: float, h: float) -> float:
	var u: float = clampf(log(maxf(v, 0.0001)) / log(2.0) / LOG_RANGE, -1.0, 1.0)
	return top + h * 0.5 - u * h * 0.5


static func px_per_double(h: float) -> float:
	return maxf(h * 0.5 / LOG_RANGE, 2.0)


static func clip_value(c: Clip, u: float) -> float:
	return AnimProp.evaluate_float(c.speed, u, c.duration)


static func hit_clip(c: Clip, x0: float, pps: float, lane_y: float, lane_h: float, pos: Vector2) -> Dictionary:
	if not shown(c) or lane_h < Paint.KEY_MIN_H:
		return {}
	var top: float = band_top(lane_y)
	var h: float = band_h(lane_h)
	if h < MIN_INNER or pos.y < top - LINE_REACH or pos.y > top + h + LINE_REACH:
		return {}
	var p: float = maxf(pps, 0.000001)
	var x1: float = x0 + c.duration * p
	if pos.x < x0 or pos.x > x1:
		return {}
	if AnimProp.is_animated(c.speed):
		var best: int = -1
		var best_d: float = KEY_REACH + 0.001
		var best_t: float = 0.0
		var ks: Array = SpeedCurve.sorted_keys(c.speed)
		for i: int in ks.size():
			var kt: float = float((ks[i] as Dictionary).get("t", 0.0))
			var d: float = absf(x0 + kt * p - pos.x)
			if d < best_d:
				best_d = d
				best = i
				best_t = kt
		if best >= 0:
			return {"what": "key", "index": best, "t": best_t, "top": top, "h": h}
	var u: float = (pos.x - x0) / p
	var ly: float = y_of(clip_value(c, u), top, h)
	if absf(pos.y - ly) <= LINE_REACH:
		return {"what": "line", "index": -1, "t": u, "top": top, "h": h}
	return {"what": "inside", "index": -1, "t": u, "top": top, "h": h}


static func hit(canvas: Control, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return {}
	var h: Dictionary = canvas.call("hit_at", pos)
	if String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)) or bool(h.get("transition", false)):
		return {}
	var c: Clip = h.get("clip", null)
	var tr: Track = h.get("track", null)
	var l: Dictionary = h.get("lane", {})
	if c == null or tr == null or l.is_empty() or not shown(c):
		return {}
	if not String(h.get("edge", "")).is_empty() or not String(h.get("fade", "")).is_empty():
		return {}
	var x0: float = float(canvas.call("x_of", c.start))
	var pps: float = float(canvas.get("pps"))
	var bh: Dictionary = hit_clip(c, x0, pps, float(h.get("lane_y", 0.0)), float(l["h"]), pos)
	if bh.is_empty():
		return {}
	bh["clip"] = c
	bh["track"] = tr
	bh["x0"] = x0
	return bh


static func editable(s: Sequence, c: Clip) -> bool:
	var tr: Track = s.track_of(c.id) if s != null and c != null else null
	return tr != null and not tr.locked and not s.group_locked(c)


static func _pick(d: Project, s: Sequence, c: Clip) -> void:
	if s.selected_clip_ids.has(c.id):
		return
	Verbs.select(d, s, PackedStringArray([c.id]), "replace", PackedStringArray([c.id]))


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	if not TOOLS.has(Session.tool_id):
		return false
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty():
		return false
	var what: String = String(hr["what"])
	var pen: bool = Session.tool_id == "pen"
	var ctrl: bool = bool(mods.get("ctrl", false))
	if what == "inside" and not pen:
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var c: Clip = hr["clip"]
	if not editable(s, c):
		Events.toast(LOCKED_TEXT)
		return true
	if ctrl or pen:
		if what == "key":
			delete_key(d, s, c, float(hr["t"]))
		else:
			add_key(d, s, c, float(hr["t"]), float(canvas.call("fps")))
		return true
	if not SpeedCurve.positive(c.speed):
		Events.toast(BACKWARDS_TEXT)
		return true
	if not SpeedCurve.fast(c.speed):
		Events.toast(LAYERED_TEXT)
		return true
	_pick(d, s, c)
	_begin(canvas, hr, pos, mods)
	return true


static func _seg_indices(ks: Array, u: float) -> PackedInt32Array:
	var n: int = ks.size()
	var out: PackedInt32Array = PackedInt32Array()
	if n == 0:
		return out
	if u < float((ks[0] as Dictionary).get("t", 0.0)):
		out.append(0)
		return out
	var i: int = 0
	while i + 1 < n and float((ks[i + 1] as Dictionary).get("t", 0.0)) <= u:
		i += 1
	out.append(i)
	if i + 1 < n and String((ks[i] as Dictionary).get("i", "linear")) != "hold":
		out.append(i + 1)
	return out


static func _begin(canvas: Control, hr: Dictionary, pos: Vector2, mods: Dictionary) -> void:
	var c: Clip = hr["clip"]
	var drag: RefCounted = canvas.get("drag")
	drag.call("begin", DRAG_MODE, canvas.call("hit_at", pos), pos, mods)
	drag.set("clip_id", c.id)
	var prop0: Dictionary = c.speed.duplicate(true)
	var ks: Array = SpeedCurve.sorted_keys(prop0)
	var u: float = float(hr["t"])
	var v0: float = clip_value(c, u)
	var info: Dictionary = {"clip": c.id, "what": String(hr["what"]), "alt": bool(mods.get("alt", false)), "prop0": prop0, "static": not AnimProp.is_animated(prop0), "v0": v0, "value": v0, "u": u, "idx": _seg_indices(ks, u), "key": int(hr["index"]), "kt": float(hr["t"]), "nt": float(hr["t"]), "h": float(hr["h"]), "x0": float(hr["x0"]), "fast": SpeedCurve.fast(prop0), "valid": false, "held": false, "follow": {}, "start": c.start, "dur": c.duration, "in": c.in_offset, "split": false}
	var s: Sequence = canvas.call("seq")
	info["hint"] = BandCmds.BandStep.hint_for(s, c) if s != null else {}
	var origin: Dictionary = drag.get("origin")
	origin["band"] = info


static func _hold_follow(info: Dictionary, s: Sequence, c: Clip) -> void:
	SpeedFollow.held_until = Engine.get_process_frames() + HOLD_FRAMES
	if bool(info["held"]):
		return
	info["held"] = true
	if not SpeedFollow.pref_on() or Session.playing or Session.seq() != s:
		return
	var ph: float = Session.playhead()
	if ph < c.start or ph >= c.end():
		return
	var plan: Dictionary = SpeedCurve.compile(info["prop0"])
	info["follow"] = {"ph": ph, "src": c.in_offset + SpeedCurve.integral(plan, ph - c.start)}


static func _release_follow(info: Dictionary, restore: bool) -> void:
	if not bool(info.get("held", false)):
		return
	info["held"] = false
	SpeedFollow.held_until = Engine.get_process_frames()
	var f: Dictionary = info.get("follow", {})
	if restore and not f.is_empty():
		Session.set_playhead(float(f["ph"]))
	if SpeedFollow.current != null and is_instance_valid(SpeedFollow.current):
		SpeedFollow.current.call("note", Session.playhead())


static func _scaled(prop0: Dictionary, idx: PackedInt32Array, ratio: float) -> Dictionary:
	var ks: Array = SpeedCurve.sorted_keys(prop0)
	for i: int in idx:
		if i < 0 or i >= ks.size():
			continue
		var k: Dictionary = ks[i]
		k["v"] = clampf(snappedf(SpeedCurve.key_value(k) * ratio, 0.0001), MIN_SPEED, MAX_SPEED)
	return SpeedCurve.with_keys(prop0, ks)


static func _plain(k: Dictionary) -> Dictionary:
	var out: Dictionary = k.duplicate(true)
	out.erase(SpeedCurve.PIN)
	out.erase(SpeedCurve.AT)
	out.erase(SpeedCurve.OWNER)
	return out


static func left_value(ks: Array, i: int) -> float:
	if i <= 0:
		return SpeedCurve.key_value(ks[0])
	var prev: Dictionary = ks[i - 1]
	if String(prev.get("i", "linear")) == "hold":
		return SpeedCurve.key_value(prev)
	return SpeedCurve.key_value(ks[i])


static func _key_bounds(ks: Array, i: int, frame: float, dur: float) -> Vector2:
	var lo: float = float((ks[i - 1] as Dictionary).get("t", 0.0)) + frame if i > 0 else minf(0.0, float((ks[i] as Dictionary).get("t", 0.0)))
	var hi: float = float((ks[i + 1] as Dictionary).get("t", 0.0)) - frame if i + 1 < ks.size() else maxf(dur, float((ks[i] as Dictionary).get("t", 0.0)))
	return Vector2(lo, maxf(hi, lo))


static func moved_key(prop0: Dictionary, i: int, nt: float) -> Dictionary:
	var ks: Array = SpeedCurve.sorted_keys(prop0)
	if i < 0 or i >= ks.size():
		return prop0
	(ks[i] as Dictionary)["t"] = nt
	return SpeedCurve.with_keys(prop0, ks)


static func split_key(prop0: Dictionary, i: int, nt: float) -> Dictionary:
	var ks: Array = SpeedCurve.sorted_keys(prop0)
	if i < 0 or i >= ks.size():
		return prop0
	var k: Dictionary = ks[i]
	var kt: float = float(k.get("t", 0.0))
	var vl: float = left_value(ks, i)
	if absf(nt - kt) <= AnimProp.KEY_TOLERANCE * 2.0:
		return prop0
	if nt > kt:
		var right: Dictionary = _plain(k)
		right["t"] = nt
		k["v"] = vl
		k["i"] = "ease_both"
		k["ease"] = EASE_FAMILY
		k.erase("dir")
		ks.insert(i + 1, right)
	else:
		ks.insert(i, {"t": nt, "v": vl, "i": "ease_both", "ease": EASE_FAMILY})
	return SpeedCurve.with_keys(prop0, ks)


static func drag_motion(host: Control, drag: RefCounted, pos: Vector2, mods: Dictionary) -> bool:
	var t_us: int = Time.get_ticks_usec()
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get("band", {})
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	if info.is_empty() or d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(String(info["clip"]))
	if c == null:
		return true
	_hold_follow(info, s, c)
	var press: Vector2 = drag.get("press")
	var prop0: Dictionary = info["prop0"]
	var what: String = String(info["what"])
	var cmd: Command = null
	if what == "line":
		var v0: float = maxf(float(info["v0"]), MIN_SPEED)
		var dy: float = press.y - pos.y
		if bool(mods.get("shift", false)):
			dy *= FINE
		var v: float = clampf(snappedf(v0 * pow(2.0, dy / px_per_double(float(info["h"]))), 0.01), MIN_SPEED, MAX_SPEED)
		info["value"] = v
		if bool(info["static"]):
			if absf(v - v0) > 0.00001:
				cmd = BandCmds.step_static(s.id, c.id, v)
		else:
			var next: Dictionary = _scaled(prop0, info["idx"], v / v0)
			if next != prop0:
				cmd = BandCmds.step(s.id, c.id, next, info.get("hint", {}))
	else:
		var ks: Array = SpeedCurve.sorted_keys(prop0)
		var i: int = int(info["key"])
		if i < 0 or i >= ks.size():
			return true
		var fps: float = maxf(float(host.call("fps")), 1.0)
		var frame: float = 1.0 / fps
		var pps: float = maxf(float(host.get("pps")), 0.000001)
		var kt: float = float(info["kt"])
		var nt: float = kt + (pos.x - press.x) / pps
		nt = round((float(info["start"]) + nt) * fps) / fps - float(info["start"])
		var b: Vector2 = _key_bounds(ks, i, frame, float(info["dur"]))
		nt = clampf(nt, b.x, b.y)
		info["nt"] = nt
		var split: bool = bool(info["alt"]) and absf(left_value(ks, i) - SpeedCurve.key_value(ks[i])) > 0.0001
		info["split"] = split
		info["value"] = SpeedCurve.key_value(ks[i])
		if absf(nt - kt) > AnimProp.KEY_TOLERANCE * 2.0:
			var next2: Dictionary = split_key(prop0, i, nt) if split else moved_key(prop0, i, nt)
			if next2 != prop0:
				cmd = BandCmds.step(s.id, c.id, next2, info.get("hint", {}))
	drag.set("value_a", float(info["value"]))
	if cmd == null:
		if not String(drag.get("live_key")).is_empty():
			d.undo.cancel_live()
			drag.set("live_key", "")
		info["valid"] = false
		_place_playhead(info, c, SpeedCurve.compile(prop0))
		_timed(t_us)
		return true
	d.undo.live(cmd)
	drag.set("live_key", DRAG_MODE)
	info["valid"] = cmd.ok
	var band_cmd: BandCmds.BandStep = cmd as BandCmds.BandStep
	_place_playhead(info, c, band_cmd.plan if cmd.ok and band_cmd != null else SpeedCurve.compile(prop0))
	_timed(t_us)
	return true


static func _timed(t_us: int) -> void:
	steps += 1
	last_step_us = Time.get_ticks_usec() - t_us
	max_step_us = maxi(max_step_us, last_step_us)


static func _place_playhead(info: Dictionary, c: Clip, plan: Dictionary) -> void:
	var f: Dictionary = info.get("follow", {})
	if f.is_empty() or plan.is_empty():
		return
	var nt: float = c.start + SpeedCurve.inverse(plan, float(f["src"]) - c.in_offset)
	Session.set_playhead(maxf(nt, 0.0))


static func drag_release(host: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get("band", {})
	var d: Project = host.call("doc")
	if info.is_empty() or d == null:
		return false
	var live: bool = not String(drag.get("live_key")).is_empty() and d.undo.has_live()
	if not live or not bool(info.get("valid", false)):
		if live:
			d.undo.cancel_live()
		_release_follow(info, true)
		return false
	var what: String = String(info["what"])
	var label: String = LABEL_LINE if what == "line" else (LABEL_RAMP if bool(info.get("split", false)) else LABEL_MOVE)
	d.undo.commit_live(label)
	drag.set("live_key", "")
	_release_follow(info, false)
	return true


static func drag_cancel(_host: Control, drag: RefCounted) -> void:
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get("band", {})
	if not info.is_empty():
		_release_follow(info, true)


static func add_key(d: Project, s: Sequence, c: Clip, u: float, fps: float) -> bool:
	var f: float = maxf(fps, 1.0)
	var t: float = clampf(round((c.start + u) * f) / f - c.start, 0.0, c.duration)
	var p: Dictionary = c.speed
	var v: float = clip_value(c, t)
	var next: Dictionary
	if not AnimProp.is_animated(p):
		next = AnimProp.set_key(p, 0.0, v, "hold")
		if t > 1.0 / f:
			next = AnimProp.set_key(next, t, v, "hold")
	else:
		if AnimProp.find_key(p, t) >= 0:
			return false
		var ks: Array = SpeedCurve.sorted_keys(p)
		var interp: String = "hold"
		var extra: Dictionary = {}
		for k: Dictionary in ks:
			if float(k.get("t", 0.0)) <= t:
				interp = String(k.get("i", "linear"))
				extra = {}
				if k.has("ease"):
					extra["ease"] = k["ease"]
				if k.has("dir"):
					extra["dir"] = k["dir"]
		next = AnimProp.set_key(p, t, v, interp)
		if not extra.is_empty():
			next = AnimProp.set_key_fields(next, t, extra)
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, "speed", next)
	cmd.label = LABEL_ADD
	return Verbs.run(d, LABEL_ADD, [cmd])


static func delete_key(d: Project, s: Sequence, c: Clip, t: float) -> bool:
	var p: Dictionary = c.speed
	if AnimProp.find_key(p, t) < 0:
		return false
	var ks: Array = SpeedCurve.sorted_keys(p)
	var next: Dictionary
	if ks.size() <= 1:
		next = AnimProp.make(SpeedCurve.key_value(ks[0]) if not ks.is_empty() else 1.0)
	else:
		next = AnimProp.remove_key(p, t)
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, "speed", next)
	cmd.label = LABEL_DELETE
	return Verbs.run(d, LABEL_DELETE, [cmd])


static func set_interp(d: Project, s: Sequence, c: Clip, t: float, mode: String) -> bool:
	var ks: Array = SpeedCurve.sorted_keys(c.speed)
	var found: bool = false
	for kv: Variant in ks:
		var k: Dictionary = kv
		if absf(float(k.get("t", 0.0)) - t) > AnimProp.KEY_TOLERANCE:
			continue
		found = true
		k.erase("dir")
		k.erase("ho")
		k.erase("hi")
		if mode == "ease":
			k["i"] = "ease_both"
			k["ease"] = EASE_FAMILY
		else:
			k["i"] = mode
			k.erase("ease")
	if not found:
		return false
	var next: Dictionary = SpeedCurve.with_keys(c.speed, ks)
	if next == c.speed:
		return false
	var label: String = "Speed key " + ("ease" if mode == "ease" else mode)
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, "speed", next)
	cmd.label = label
	return Verbs.run(d, label, [cmd])


static func key_interp(c: Clip, t: float) -> String:
	for k: Dictionary in SpeedCurve.sorted_keys(c.speed):
		if absf(float(k.get("t", 0.0)) - t) <= AnimProp.KEY_TOLERANCE:
			var mode: String = String(k.get("i", "linear"))
			if mode == "ease_both" or mode == "ease_in" or mode == "ease_out":
				return "ease"
			return mode
	return ""


static func key_menu_items(c: Clip, t: float) -> Array:
	var cur: String = key_interp(c, t)
	return [
		PmMenu.check_item(KEY_MENU + "linear", "Linear", cur == "linear"),
		PmMenu.check_item(KEY_MENU + "ease", "Ease in and out", cur == "ease"),
		PmMenu.check_item(KEY_MENU + "hold", "Hold, a sudden change", cur == "hold"),
		PmMenu.separator(),
		PmMenu.item(KEY_MENU + "goto", "Move the playhead to this key"),
		PmMenu.item(KEY_MENU + "delete", "Delete key", "", "trash"),
	]


static func right(canvas: Control, pos: Vector2) -> bool:
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty() or String(hr["what"]) != "key":
		return false
	var c: Clip = hr["clip"]
	canvas.set_meta(META_KEY, {"clip": c.id, "t": float(hr["t"])})
	var m: Control = PmMenu.open(canvas, key_menu_items(c, float(hr["t"])), canvas.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(load(SELF_PATH), "on_key_menu").bind(canvas))
	return true


static func on_key_menu(id: String, canvas: Control) -> void:
	if canvas == null or not is_instance_valid(canvas) or not id.begins_with(KEY_MENU) or not canvas.has_meta(META_KEY):
		return
	var at: Dictionary = canvas.get_meta(META_KEY)
	canvas.remove_meta(META_KEY)
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var c: Clip = s.clip_by_id(String(at.get("clip", ""))) if s != null else null
	if d == null or c == null:
		return
	var t: float = float(at.get("t", 0.0))
	var what: String = id.substr(KEY_MENU.length())
	if what == "goto":
		Session.set_playhead(c.start + t)
		return
	if not editable(s, c):
		Events.toast(LOCKED_TEXT)
		return
	if what == "delete":
		delete_key(d, s, c, t)
	elif what == "linear" or what == "ease" or what == "hold":
		set_interp(d, s, c, t, what)


static func menu_item(c: Clip) -> Dictionary:
	return PmMenu.check_item(MENU_ID, MENU_LABEL, shown(c))


static func set_shown(d: Project, s: Sequence, ids: PackedStringArray, on: bool) -> bool:
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null or shown(c) == on:
			continue
		var props: Dictionary = c.props.duplicate(true)
		if on:
			props[BAND_KEY] = BAND_SPEED
		else:
			props.erase(BAND_KEY)
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "props", props))
	if cmds.is_empty():
		return false
	var label: String = "Show speed band" if on else "Hide speed band"
	for cmd: Command in cmds:
		cmd.label = label
	return Verbs.run(d, label, cmds)


static func on_clip_menu(canvas: Control, id: String, clip_id: String) -> bool:
	if id != MENU_ID:
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return true
	var ids: PackedStringArray = Verbs.selection(s) if s.selected_clip_ids.has(clip_id) else PackedStringArray([clip_id])
	set_shown(d, s, ids, not shown(c))
	return true


static func draw_clip(ci: CanvasItem, r: Rect2, c: Clip, pps: float, x0: float) -> void:
	if r.size.y < Paint.KEY_MIN_H or r.size.x < 2.0:
		return
	var top: float = r.position.y + Paint.name_row_h() + 2.0
	var h: float = r.size.y - Paint.name_row_h() - 4.0
	if h < MIN_INNER:
		return
	var size: Vector2 = Vector2(r.size.x, h)
	var shift: float = r.position.x - x0
	var bright: Color = Tk.c["text_bright"]
	var faint: Color = Tk.c["text_faint"]
	var sig: Array = ["speed_band", c.speed.hash(), c.duration, size, shift, pps, bright, faint]
	var entry: Dictionary = Paint.cached(sig)
	if entry.is_empty():
		entry = band_entry(c, size, shift, pps)
		Paint.remember(sig, entry)
	draws += 1
	ci.draw_set_transform(Vector2(r.position.x, top), 0.0, Vector2.ONE)
	var ry: float = float(entry["ref"])
	ci.draw_dashed_line(Vector2(0.0, ry), Vector2(size.x, ry), Color(faint, REF_ALPHA), 1.0, 4.0)
	var ticks: PackedVector2Array = entry["ticks"]
	if ticks.size() >= 2:
		ci.draw_multiline(ticks, Color(bright, TICK_ALPHA), 1.0)
	var pts: PackedVector2Array = entry["pts"]
	if pts.size() >= 2:
		ci.draw_polyline(pts, bright, 1.5, true)
	Paint.draw_batch(ci, entry)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func band_entry(c: Clip, size: Vector2, shift: float, pps: float) -> Dictionary:
	var p: float = maxf(pps, 0.000001)
	var ks: Array = SpeedCurve.sorted_keys(c.speed) if AnimProp.is_animated(c.speed) else []
	var xs: PackedFloat64Array = PackedFloat64Array()
	var x: float = 0.0
	var key_xs: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in ks:
		var kx: float = float(k.get("t", 0.0)) * p - shift
		if kx >= -KEY_REACH and kx <= size.x + KEY_REACH:
			key_xs.append(kx)
	var ki: int = 0
	while x <= size.x:
		while ki < key_xs.size() and key_xs[ki] <= x:
			if key_xs[ki] >= 0.0 and key_xs[ki] < x:
				xs.append(maxf(key_xs[ki] - 0.01, 0.0))
				xs.append(key_xs[ki])
			ki += 1
		xs.append(x)
		x += LINE_STEP
	if xs.is_empty() or xs[xs.size() - 1] < size.x:
		xs.append(size.x)
	var ts: PackedFloat64Array = PackedFloat64Array()
	ts.resize(xs.size())
	for i: int in xs.size():
		ts[i] = (xs[i] + shift) / p
	var vals: PackedFloat64Array = Paint.curve_values(c.speed, ts, c.duration, 0.0, 0, true) if AnimProp.is_animated(c.speed) else PackedFloat64Array()
	var flat: float = SpeedCurve.static_value(c.speed)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(xs.size())
	for i2: int in xs.size():
		var v: float = vals[i2] if not vals.is_empty() else flat
		pts[i2] = Vector2(xs[i2], y_of(v, 0.0, size.y))
	var ticks: PackedVector2Array = PackedVector2Array()
	var centres: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var kcol: Color = Tk.c["text_bright"]
	for k2: Dictionary in ks:
		var kx2: float = float(k2.get("t", 0.0)) * p - shift
		if kx2 < -KEY_REACH or kx2 > size.x + KEY_REACH:
			continue
		ticks.append(Vector2(kx2, 0.0))
		ticks.append(Vector2(kx2, size.y))
		centres.append(Vector2(kx2, y_of(SpeedCurve.key_value(k2), 0.0, size.y)))
		cols.append(kcol)
		if centres.size() >= Paint.KEY_DRAW_MAX:
			break
	var out: Dictionary = Paint.diamond_batch(centres, cols)
	out["pts"] = pts
	out["ticks"] = ticks
	out["ref"] = y_of(1.0, 0.0, size.y)
	return out


static func chip_text(info: Dictionary) -> String:
	var what: String = String(info.get("what", ""))
	if what == "line":
		return str(int(round(float(info.get("value", 1.0)) * 100.0))) + " %"
	var nt: float = float(info.get("nt", 0.0))
	var dt: float = nt - float(info.get("kt", 0.0))
	var head: String = "Ramp " if bool(info.get("split", false)) else ""
	return head + ("+" if dt >= 0.0 else "") + str(snappedf(dt, 0.01)) + " s"


static func draw_drag(canvas: Control) -> void:
	var drag: RefCounted = canvas.get("drag")
	if drag == null or String(drag.get("mode")) != DRAG_MODE or not bool(drag.get("active")):
		return
	var info: Dictionary = (drag.get("origin") as Dictionary).get("band", {})
	if info.is_empty():
		return
	var text: String = chip_text(info)
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = PmText.chip_pad()
	var w: float = PmText.width_of(font, text, fs) + pad * 2.0
	var hh: float = font.get_height(fs) + 4.0
	var at: Vector2 = drag.get("last")
	var rect: Rect2 = Rect2(at.x + CHIP_GAP, at.y - CHIP_GAP - hh, w, hh)
	if rect.end.x > canvas.size.x:
		rect.position.x = at.x - CHIP_GAP - w
	if rect.position.y < 0.0:
		rect.position.y = at.y + CHIP_GAP
	Paint.rounded(canvas, rect, Tk.c["bg_panel_high"], 3.0, Tk.c["border_soft"], 1)
	PmText.draw_at(canvas, font, Vector2(rect.position.x + pad, rect.position.y + 2.0 + font.get_ascent(fs)), text, fs, Tk.c["text_bright"])
