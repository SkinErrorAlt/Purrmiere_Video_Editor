extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const MonitorView := preload("res://modules/core_panels/monitor_view.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const SELF_PATH := "res://modules/core_panels/monitor_snap.gd"
const OWNER := "core_panels"
const PREF_ON := "program.snap.on"
const PREF_DISTANCE := "program.snap.distance"
const CMD_ID := "view.program_snap"
const MENU_TOGGLE := "sel:snap"
const MENU_DISTANCE := "sel:snap_distance"
const MENU_DISTANCE_PICK := "sel:snapd:"
const DISTANCES: Array[int] = [4, 6, 8, 12, 16, 24]
const DISTANCE_DEFAULT := 8
const DISTANCE_MIN := 1
const DISTANCE_MAX := 40
const ANGLE_STEP := 15.0
const ANGLE_REACH_MIN := 0.25
const ANGLE_REACH_MAX := 5.0
const MATCH_PX := 0.5
const START_ARM := 2.0
const OTHERS_MAX := 32
const REFRESH_MS := 100
const CROSS_ARM := 5.0
const CHIP_GAP := Vector2(14.0, -22.0)
const GUIDE_COLOUR := Color(1.0, 0.251, 0.816, 0.95)
const CHIP_INK := Color(0.051, 0.055, 0.063, 1.0)
const BYPASS_TEXT := "Hold Ctrl while dragging to place freely"
const TIP := "Snap in the monitor: frame edges and centre, safe margins and thirds when shown, other clips, where the clip started, 15 degree turns and 100 percent size. " + BYPASS_TEXT

var xs: PackedFloat64Array = PackedFloat64Array()
var ys: PackedFloat64Array = PackedFloat64Array()
var x_kinds: PackedStringArray = PackedStringArray()
var y_kinds: PackedStringArray = PackedStringArray()
var guides: Array[Dictionary] = []
var chip: String = ""
var chip_at: Vector2 = Vector2.ZERO
var cross: bool = false
var active: bool = false
var own: Rect2 = Rect2()
var start_pos: Vector2 = Vector2.ZERO
var seq_centre: Vector2 = Vector2.ZERO
var pivot: Vector2 = Vector2.ZERO
var corner: Vector2 = Vector2.ZERO
var axis_x: Vector2 = Vector2.RIGHT
var axis_y: Vector2 = Vector2.DOWN
var pic: Rect2 = Rect2()
var gathers: int = 0
var _start_armed: bool = false
var _built_at: float = NAN
var _gathered_ms: int = 0
var _clip_id: String = ""
var _seq_ref: WeakRef = null
var _doc_ref: WeakRef = null
var _view_ref: WeakRef = null
var _quad_of: Callable = Callable()
var _own_quad: Callable = Callable()


static func ensure_prefs(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_ON)):
		prefs.call("register", PREF_ON, true, {"label": "Program: snap while moving, sizing and turning", "type": "bool"})
	if not bool(prefs.call("is_registered", PREF_DISTANCE)):
		prefs.call("register", PREF_DISTANCE, DISTANCE_DEFAULT, {"label": "Program: snap distance in screen pixels", "type": "int", "min": DISTANCE_MIN, "max": DISTANCE_MAX})


static func register_all() -> void:
	ensure_prefs(Prefs)
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var label: String = "Snap in the Program monitor"
	var category: String = "View"
	if cat.has(CMD_ID):
		label = String(cat[CMD_ID]["label"])
		category = String(cat[CMD_ID]["category"])
	Cmd.register(CMD_ID, {"label": label, "category": category, "scope": "global", "handler": Callable(script, "toggle"), "owner": OWNER, "toggle": Callable(script, "is_on")})


static func is_on() -> bool:
	return not Prefs.is_registered(PREF_ON) or bool(Prefs.get_value(PREF_ON))


static func distance_px() -> float:
	if not Prefs.is_registered(PREF_DISTANCE):
		return float(DISTANCE_DEFAULT)
	return float(clampi(int(Prefs.get_value(PREF_DISTANCE)), DISTANCE_MIN, DISTANCE_MAX))


static func toggle() -> void:
	var on: bool = not is_on()
	Prefs.set_value(PREF_ON, on)
	Events.toast("Snapping in the monitor is on. " + BYPASS_TEXT if on else "Snapping in the monitor is off")


static func menu_items() -> Array:
	var now: int = int(distance_px())
	var picks: Array = []
	for px: int in DISTANCES:
		picks.append(PmMenu.check_item(MENU_DISTANCE_PICK + str(px), str(px) + " px", now == px))
	return [
		PmMenu.check_item(MENU_TOGGLE, "Snap in the monitor", is_on(), Cmd.keys_text(CMD_ID)),
		PmMenu.sub_item(MENU_DISTANCE, "Snap distance", picks),
	]


static func on_menu_picked(id: String) -> bool:
	if id == MENU_TOGGLE:
		Prefs.set_value(PREF_ON, not is_on())
		return true
	if id.begins_with(MENU_DISTANCE_PICK):
		var px: String = id.substr(MENU_DISTANCE_PICK.length())
		if px.is_valid_int():
			Prefs.set_value(PREF_DISTANCE, clampi(int(px), DISTANCE_MIN, DISTANCE_MAX))
		return true
	return id == MENU_DISTANCE


static func bypass(e: InputEventWithModifiers) -> bool:
	return e != null and (e.ctrl_pressed or e.meta_pressed)


static func frame_lines(frame: Vector2, safe: bool, thirds: bool) -> Dictionary:
	var fx: float = frame.x
	var fy: float = frame.y
	var x: PackedFloat64Array = PackedFloat64Array([0.0, fx * 0.5, fx])
	var xk: PackedStringArray = PackedStringArray(["frame", "centre", "frame"])
	var y: PackedFloat64Array = PackedFloat64Array([0.0, fy * 0.5, fy])
	var yk: PackedStringArray = PackedStringArray(["frame", "centre", "frame"])
	if safe:
		for k: float in [MonitorView.ACTION_SAFE, MonitorView.TITLE_SAFE]:
			var ix: float = fx * (1.0 - k) * 0.5
			var iy: float = fy * (1.0 - k) * 0.5
			x.append_array(PackedFloat64Array([ix, fx - ix]))
			xk.append_array(PackedStringArray(["safe", "safe"]))
			y.append_array(PackedFloat64Array([iy, fy - iy]))
			yk.append_array(PackedStringArray(["safe", "safe"]))
	if thirds:
		for i: int in [1, 2]:
			x.append(fx * float(i) / 3.0)
			xk.append("thirds")
			y.append(fy * float(i) / 3.0)
			yk.append("thirds")
	return {"x": x, "xk": xk, "y": y, "yk": yk}


static func box_of(q: PackedVector2Array) -> Rect2:
	if q.is_empty():
		return Rect2()
	var lo: Vector2 = q[0]
	var hi: Vector2 = q[0]
	for p: Vector2 in q:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


static func nearest(sources: PackedFloat64Array, targets: PackedFloat64Array, reach: float) -> Dictionary:
	var best: float = reach
	var found: bool = false
	var delta: float = 0.0
	var at: int = -1
	var from: int = -1
	var n: int = targets.size()
	for j: int in sources.size():
		var s: float = sources[j]
		var i: int = targets.bsearch(s)
		for c: int in [i - 1, i]:
			if c < 0 or c >= n:
				continue
			var dd: float = absf(targets[c] - s)
			if dd <= best and (not found or dd < best):
				best = dd
				delta = targets[c] - s
				at = c
				from = j
				found = true
	return {"found": found, "delta": delta, "index": at, "source": from}


static func sort_lines(values: PackedFloat64Array, kinds: PackedStringArray) -> Array:
	var order: Array = range(values.size())
	order.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b] or (values[a] == values[b] and a < b))
	var v: PackedFloat64Array = PackedFloat64Array()
	var k: PackedStringArray = PackedStringArray()
	v.resize(order.size())
	k.resize(order.size())
	for i: int in order.size():
		v[i] = values[int(order[i])]
		k[i] = kinds[int(order[i])] if int(order[i]) < kinds.size() else ""
	return [v, k]


static func angle_reach(radius_px: float, reach_px: float) -> float:
	return clampf(rad_to_deg(reach_px / maxf(radius_px, 1.0)), ANGLE_REACH_MIN, ANGLE_REACH_MAX)


static func snap_angle(deg: float, reach_deg: float) -> Dictionary:
	var step: float = round(deg / ANGLE_STEP) * ANGLE_STEP
	if absf(deg - step) <= reach_deg:
		return {"found": true, "value": step}
	return {"found": false, "value": deg}


static func visible_clips(s: Sequence, d: Project, t: float, skip_id: String) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	var tracks: Array[Track] = s.picture_tracks()
	var any_solo: bool = false
	for tr: Track in tracks:
		if tr.solo:
			any_solo = true
	for tr: Track in tracks:
		if tr.muted or (any_solo and not tr.solo):
			continue
		for c: Clip in tr.clips_at(t):
			if c.id == skip_id or not c.enabled or not tr.is_picture(c):
				continue
			var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
			if m != null and m.kind == "audio":
				continue
			if MonitorPick.is_weak(c, m, t, s.fps):
				continue
			out.append(c)
			if out.size() >= OTHERS_MAX:
				return out
	return out


func begin(c: Clip, s: Sequence, d: Project, pic_: Rect2, drag: Dictionary, quad_of: Callable, own_quad: Callable, view: Control) -> void:
	end()
	if c == null or s == null:
		return
	_clip_id = c.id
	_seq_ref = weakref(s)
	_doc_ref = weakref(d) if d != null else null
	_view_ref = weakref(view) if view != null else null
	_quad_of = quad_of
	_own_quad = own_quad
	pic = pic_
	seq_centre = Vector2(float(s.width), float(s.height)) * 0.5
	start_pos = drag.get("pos", Vector2.ZERO)
	pivot = drag.get("centre", Vector2.ZERO)
	axis_x = drag.get("axis_x", Vector2.RIGHT)
	axis_y = drag.get("axis_y", Vector2.DOWN)
	_start_armed = false
	_gather(c, s, d)
	var press: Vector2 = drag.get("press", pivot)
	var k: float = _k()
	var q: PackedVector2Array = _own_seq_quad(c)
	var best: float = INF
	corner = pivot
	for p: Vector2 in q:
		var sp: Vector2 = pic.position + p * k
		var dd: float = sp.distance_squared_to(press)
		if dd < best:
			best = dd
			corner = sp
	active = true


func end() -> void:
	active = false
	guides.clear()
	chip = ""
	cross = false


func _k() -> float:
	var s: Sequence = _seq()
	if s == null:
		return 1.0
	return pic.size.x / maxf(float(s.width), 1.0)


func _seq() -> Sequence:
	var got: Variant = _seq_ref.get_ref() if _seq_ref != null else null
	return got if got is Sequence else null


func _own_made(c: Clip) -> Dictionary:
	if not _own_quad.is_valid():
		return {}
	var made: Variant = _own_quad.call(c)
	return made if made is Dictionary else {}


func _own_seq_quad(c: Clip) -> PackedVector2Array:
	var q: Variant = _own_made(c).get("quad", PackedVector2Array())
	return q if q is PackedVector2Array else PackedVector2Array()


func _gather(c: Clip, s: Sequence, d: Project) -> void:
	gathers += 1
	_built_at = s.playhead
	_gathered_ms = Time.get_ticks_msec()
	var v: Control = _view_ref.get_ref() if _view_ref != null else null
	var safe: bool = v != null and bool(v.call("overlay_on", "safe"))
	var thirds: bool = v != null and bool(v.call("overlay_on", "thirds"))
	var lines: Dictionary = frame_lines(Vector2(float(s.width), float(s.height)), safe, thirds)
	xs = lines["x"]
	x_kinds = lines["xk"]
	ys = lines["y"]
	y_kinds = lines["yk"]
	for other: Clip in visible_clips(s, d, s.playhead, c.id):
		var q: PackedVector2Array = PackedVector2Array()
		if _quad_of.is_valid():
			var got: Variant = _quad_of.call(other)
			if got is PackedVector2Array:
				q = got
		if q.size() != 4:
			q = MonitorPick.quad_of_clip(other, s, d, s.playhead)
		var b: Rect2 = box_of(q)
		if b.size.x <= 0.0 and b.size.y <= 0.0:
			continue
		for vx: float in [b.position.x, b.get_center().x, b.end.x]:
			xs.append(vx)
			x_kinds.append("clip")
		for vy: float in [b.position.y, b.get_center().y, b.end.y]:
			ys.append(vy)
			y_kinds.append("clip")
	var sx: Array = sort_lines(xs, x_kinds)
	xs = sx[0]
	x_kinds = sx[1]
	var sy: Array = sort_lines(ys, y_kinds)
	ys = sy[0]
	y_kinds = sy[1]
	var made: Dictionary = _own_made(c)
	var q_own: Variant = made.get("quad", PackedVector2Array())
	var mine: Rect2 = box_of(q_own if q_own is PackedVector2Array else PackedVector2Array())
	var at: Variant = made.get("pivot", seq_centre + start_pos)
	own = Rect2(mine.position - (at if at is Vector2 else seq_centre + start_pos), mine.size)


func _refresh() -> void:
	if not Session.playing:
		return
	var s: Sequence = _seq()
	if s == null or s.playhead == _built_at or Time.get_ticks_msec() - _gathered_ms < REFRESH_MS:
		return
	var c: Clip = s.clip_by_id(_clip_id)
	if c == null:
		return
	var d: Variant = _doc_ref.get_ref() if _doc_ref != null else null
	_gather(c, s, d if d is Project else null)


func _clear() -> void:
	guides.clear()
	chip = ""
	cross = false


func move(np: Vector2, p0: Vector2, free_x: bool, free_y: bool, k: float, skip: bool) -> Vector2:
	_clear()
	if not active or skip or not is_on():
		return np
	_refresh()
	var reach: float = distance_px() / maxf(k, 0.0001)
	if not _start_armed and np.distance_to(p0) > reach * START_ARM:
		_start_armed = true
	var out: Vector2 = np
	var to_start: Vector2i = Vector2i.ZERO
	var on_line: Vector2i = Vector2i.ZERO
	var off_x: PackedFloat64Array = PackedFloat64Array([seq_centre.x + own.position.x, seq_centre.x + own.position.x + own.size.x * 0.5, seq_centre.x + own.position.x + own.size.x])
	var off_y: PackedFloat64Array = PackedFloat64Array([seq_centre.y + own.position.y, seq_centre.y + own.position.y + own.size.y * 0.5, seq_centre.y + own.position.y + own.size.y])
	if free_x:
		var src: PackedFloat64Array = PackedFloat64Array([np.x + off_x[0], np.x + off_x[1], np.x + off_x[2]])
		var hit: Dictionary = nearest(src, xs, reach)
		var back: float = p0.x - np.x
		if _start_armed and absf(back) <= reach and (not bool(hit["found"]) or absf(back) < absf(float(hit["delta"]))):
			out.x = p0.x
			to_start.x = 1
		elif bool(hit["found"]):
			out.x = xs[int(hit["index"])] - off_x[int(hit["source"])]
			on_line.x = 1
	if free_y:
		var src_y: PackedFloat64Array = PackedFloat64Array([np.y + off_y[0], np.y + off_y[1], np.y + off_y[2]])
		var hit_y: Dictionary = nearest(src_y, ys, reach)
		var back_y: float = p0.y - np.y
		if _start_armed and absf(back_y) <= reach and (not bool(hit_y["found"]) or absf(back_y) < absf(float(hit_y["delta"]))):
			out.y = p0.y
			to_start.y = 1
		elif bool(hit_y["found"]):
			out.y = ys[int(hit_y["index"])] - off_y[int(hit_y["source"])]
			on_line.y = 1
	var snapped_box: Rect2 = Rect2(own.position + seq_centre + out, own.size)
	if on_line.x == 1 or to_start.x == 1:
		if to_start.x == 1:
			guides.append({"axis": "x", "at": seq_centre.x + p0.x, "kind": "start"})
		else:
			_match_guides("x", PackedFloat64Array([snapped_box.position.x, snapped_box.get_center().x, snapped_box.end.x]), xs, x_kinds, MATCH_PX / maxf(k, 0.0001))
	if on_line.y == 1 or to_start.y == 1:
		if to_start.y == 1:
			guides.append({"axis": "y", "at": seq_centre.y + p0.y, "kind": "start"})
		else:
			_match_guides("y", PackedFloat64Array([snapped_box.position.y, snapped_box.get_center().y, snapped_box.end.y]), ys, y_kinds, MATCH_PX / maxf(k, 0.0001))
	cross = to_start == Vector2i.ONE
	return out


func _match_guides(axis: String, sources: PackedFloat64Array, targets: PackedFloat64Array, kinds: PackedStringArray, eps: float) -> void:
	var last: float = -INF
	var n: int = targets.size()
	for s: float in sources:
		var i: int = targets.bsearch(s - eps)
		while i < n and targets[i] <= s + eps:
			var t: float = targets[i]
			if absf(t - last) > eps and not _has_guide(axis, t, eps):
				last = t
				guides.append({"axis": axis, "at": t, "kind": kinds[i] if i < kinds.size() else ""})
			i += 1


func _has_guide(axis: String, at: float, eps: float) -> bool:
	for g: Dictionary in guides:
		if String(g["axis"]) == axis and absf(float(g["at"]) - at) <= eps:
			return true
	return false


func _screen_lines(values: PackedFloat64Array, origin: float, k: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(values.size())
	for i: int in values.size():
		out[i] = origin + values[i] * k
	return out


func _best_factor(f: float, coef: float, base: float, lines: PackedFloat64Array, reach: float, best: Dictionary) -> void:
	if absf(coef) < 0.5:
		return
	for i: int in lines.size():
		var ft: float = (lines[i] - base) / coef
		if ft <= 0.0:
			continue
		var dist: float = absf(coef) * absf(f - ft)
		if dist < float(best["dist"]):
			best["dist"] = dist
			best["f"] = ft
			best["hundred"] = false


func scale(ns: Vector2, s0: Vector2, linked: bool, only_x: bool, pointer: Vector2, skip: bool) -> Vector2:
	_clear()
	if not active or skip or not is_on() or absf(s0.x) < 0.000001 or absf(s0.y) < 0.000001:
		return ns
	_refresh()
	var k: float = _k()
	var reach: float = distance_px()
	var sx: PackedFloat64Array = _screen_lines(xs, pic.position.x, k)
	var sy: PackedFloat64Array = _screen_lines(ys, pic.position.y, k)
	var d: Vector2 = corner - pivot
	var out: Vector2 = ns
	var hundred: bool = false
	if linked:
		var f: float = ns.x / s0.x
		var best: Dictionary = {"dist": reach + 0.0001, "f": NAN, "hundred": false}
		var f100: float = 1.0 / s0.x
		var dist100: float = d.length() * absf(f - f100)
		if dist100 < float(best["dist"]):
			best = {"dist": dist100, "f": f100, "hundred": true}
		_best_factor(f, d.x, pivot.x, sx, reach, best)
		_best_factor(f, d.y, pivot.y, sy, reach, best)
		if not is_nan(float(best["f"])):
			hundred = bool(best["hundred"])
			out = Vector2(1.0, s0.y / s0.x) if hundred else s0 * float(best["f"])
	else:
		var fx: float = ns.x / s0.x
		var fy: float = ns.y / s0.y
		var dx: float = d.dot(axis_x)
		var dy: float = d.dot(axis_y)
		var bx: Dictionary = {"dist": reach + 0.0001, "f": NAN, "hundred": false}
		var by: Dictionary = {"dist": reach + 0.0001, "f": NAN, "hundred": false}
		var fx100: float = 1.0 / s0.x
		var fy100: float = 1.0 / s0.y
		if absf(dx) * absf(fx - fx100) < float(bx["dist"]):
			bx = {"dist": absf(dx) * absf(fx - fx100), "f": fx100, "hundred": true}
		if absf(dy) * absf(fy - fy100) < float(by["dist"]):
			by = {"dist": absf(dy) * absf(fy - fy100), "f": fy100, "hundred": true}
		if absf(axis_x.y) < 0.01:
			_best_factor(fx, axis_x.x * dx, pivot.x + axis_y.x * dy * fy, sx, reach, bx)
			_best_factor(fy, axis_y.y * dy, pivot.y + axis_x.y * dx * fx, sy, reach, by)
		elif absf(axis_x.x) < 0.01:
			_best_factor(fy, axis_y.x * dy, pivot.x + axis_x.x * dx * fx, sx, reach, by)
			_best_factor(fx, axis_x.y * dx, pivot.y + axis_y.y * dy * fy, sy, reach, bx)
		if not is_nan(float(bx["f"])):
			out.x = 1.0 if bool(bx["hundred"]) else s0.x * float(bx["f"])
			hundred = bool(bx["hundred"])
		if not only_x and not is_nan(float(by["f"])):
			out.y = 1.0 if bool(by["hundred"]) else s0.y * float(by["f"])
			hundred = hundred or bool(by["hundred"])
	if out == ns:
		return ns
	var fxn: float = out.x / s0.x
	var fyn: float = out.y / s0.y
	var dxn: float = d.dot(axis_x)
	var dyn: float = d.dot(axis_y)
	var moved: Vector2 = pivot + d * fxn if linked else pivot + axis_x * (dxn * fxn) + axis_y * (dyn * fyn)
	var seq_corner: Vector2 = (moved - pic.position) / maxf(k, 0.0001)
	_match_guides("x", PackedFloat64Array([seq_corner.x]), xs, x_kinds, MATCH_PX / maxf(k, 0.0001))
	_match_guides("y", PackedFloat64Array([seq_corner.y]), ys, y_kinds, MATCH_PX / maxf(k, 0.0001))
	if hundred:
		chip = "100%"
		chip_at = pointer + CHIP_GAP
	return out


func rotate(nr: float, stepped: bool, radius: float, pointer: Vector2, skip: bool) -> float:
	_clear()
	if not active or stepped or skip or not is_on():
		return nr
	var got: Dictionary = snap_angle(nr, angle_reach(radius, distance_px()))
	if not bool(got["found"]):
		return nr
	var v: float = float(got["value"])
	guides.append({"axis": "angle", "at": v, "kind": "turn"})
	chip = PmField.turns_text(round(v), 0, "°")
	chip_at = pointer + CHIP_GAP
	return v


func lines_for(pic_: Rect2, area: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var s: Sequence = _seq()
	if s == null or pic_.size.x <= 0.0:
		return out
	var k: float = pic_.size.x / maxf(float(s.width), 1.0)
	for g: Dictionary in guides:
		var axis: String = String(g["axis"])
		if axis == "x":
			var x: float = floor(pic_.position.x + float(g["at"]) * k) + 0.5
			out.append(PackedVector2Array([Vector2(x, area.position.y), Vector2(x, area.end.y)]))
		elif axis == "y":
			var y: float = floor(pic_.position.y + float(g["at"]) * k) + 0.5
			out.append(PackedVector2Array([Vector2(area.position.x, y), Vector2(area.end.x, y)]))
		elif axis == "angle":
			var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(g["at"])))
			var reach: float = area.size.length()
			out.append(PackedVector2Array([pivot - dir * reach, pivot + dir * reach]))
	return out


func draw(ci: CanvasItem, pic_: Rect2) -> void:
	if guides.is_empty() and chip.is_empty():
		return
	var area: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic_
	for seg: PackedVector2Array in lines_for(pic_, area):
		ci.draw_line(seg[0], seg[1], GUIDE_COLOUR, 1.0)
	var s: Sequence = _seq()
	if cross and s != null:
		var k: float = pic_.size.x / maxf(float(s.width), 1.0)
		var at: Vector2 = (pic_.position + (seq_centre + start_pos) * k).floor() + Vector2(0.5, 0.5)
		ci.draw_line(at - Vector2(CROSS_ARM, 0.0), at + Vector2(CROSS_ARM, 0.0), GUIDE_COLOUR, 1.0)
		ci.draw_line(at - Vector2(0.0, CROSS_ARM), at + Vector2(0.0, CROSS_ARM), GUIDE_COLOUR, 1.0)
	if not chip.is_empty():
		_draw_chip(ci, area)


func _draw_chip(ci: CanvasItem, area: Rect2) -> void:
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = PmText.chip_pad()
	var w: float = PmText.width_of(font, chip, fs) + pad * 2.0 + 1.0
	var h: float = font.get_height(fs) + 2.0
	var x: float = clampf(chip_at.x, area.position.x + 2.0, maxf(area.end.x - w - 2.0, area.position.x + 2.0))
	var y: float = clampf(chip_at.y, area.position.y + 2.0, maxf(area.end.y - h - 2.0, area.position.y + 2.0))
	var box: Rect2 = Rect2(Vector2(x, y).round(), Vector2(w, h))
	ci.draw_rect(box, GUIDE_COLOUR, true)
	PmText.draw(ci, font, box, chip, fs, CHIP_INK, HORIZONTAL_ALIGNMENT_CENTER, pad, NAN, PmText.WHOLE)
