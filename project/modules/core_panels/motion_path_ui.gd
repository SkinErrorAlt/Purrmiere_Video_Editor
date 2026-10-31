extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MotionPath := preload("res://doc/motion_path.gd")
const Parenting := preload("res://doc/parenting.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://modules/core_panels/motion_path_ui.gd"
const PATH := "transform.pos"
const COMMAND_ID := "view.motion_paths"
const PREF_ON := "program.motion_path.on"
const PREF_STYLE := "program.motion_path.style"
const PREF_COLOUR := "program.motion_path.colour"
const PREF_SPAN := "program.motion_path.span"
const STYLES: PackedStringArray = ["dots", "line", "line_dots", "ticks"]
const STYLE_LABELS: Dictionary = {"dots": "Dots, one for every frame", "line": "Line", "line_dots": "Line with a dot on every frame", "ticks": "Line with a tick on every frame"}
const SPANS: PackedStringArray = ["future", "around", "all"]
const SPAN_LABELS: Dictionary = {"future": "Only the part still to come", "around": "A little before and after the playhead", "all": "The whole path"}
const COLOURS: Dictionary = {"blue": Color(0.369, 0.784, 1.0), "yellow": Color(1.0, 0.85, 0.3), "pink": Color(1.0, 0.45, 0.75), "green": Color(0.45, 0.95, 0.55), "white": Color(1.0, 1.0, 1.0)}
const COLOUR_LABELS: Dictionary = {"blue": "Blue", "yellow": "Yellow", "pink": "Pink", "green": "Green", "white": "White"}
const SPATIAL_LABELS: Dictionary = {"linear": "Straight line (Linear)", "smooth": "Smooth curve (Auto bezier)", "bezier": "Free handles (Bezier)", "continuous": "Joined handles (Continuous)"}
const TEMPORAL_LABELS: Dictionary = {"hold": "Jump to the next key (Hold)", "ease_in": "Ease in", "ease_out": "Ease out", "ease_both": "Ease in and out", "linear": "Steady timing (Linear)"}
const AROUND_SECONDS := 2.0
const MAX_SAMPLES := 2400
const MAX_CLIPS := 8
const KEY_BOX := 7.0
const KEY_REACH := 6.0
const HANDLE_DOT := 3.5
const HANDLE_REACH := 6.0
const LINE_REACH := 4.0
const NOW_GUARD := 8.0
const DOT_R := 1.6
const TICK := 4.0
const SLOP := 3.0
const HANDLE_MIN := 0.0001
const CACHE_MAX := 16
const NOW_INK := Color(1.0, 1.0, 1.0, 0.95)
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const LINE_SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const LINE_W := 1.0
const UNIFORM_PX := 0.35
const SLOW_INK := Color(0.33, 0.62, 1.0)
const FAST_INK := Color(1.0, 0.42, 0.16)
const PREF_SPEED_COLOUR := "program.motion_path.speed_colour"
const PREF_HINTS := "program.motion_path.hints"
const HINT_FONT := 11
const HINT_PAD := Vector2(6.0, 3.0)
const HINT_GAP := Vector2(14.0, 16.0)
const HINT_BACK := Color(0.08, 0.08, 0.1, 0.85)
const HINT_INK := Color(0.92, 0.92, 0.95)
const HINTS: Dictionary = {"path": "Double click: add a point.  Drag: bend this line.  Right click: Curve", "key": "Drag: move.  Ctrl click: remove.  Ctrl drag: pull out handles", "handle": "Drag: bend.  Alt drag: this side only"}
const CURVE_LABELS: Dictionary = {"straight": "Straight", "gentle": "Gentle curve", "strong": "Strong curve", "s": "S curve", "arc": "Arc through here"}

static var _registered: bool = false

var drag: Dictionary = {}
var pending: Dictionary = {}
var selected: Dictionary = {}
var shown: Array[Dictionary] = []
var menu_ctx: Dictionary = {}
var last_drawn: int = 0
var hover: Dictionary = {}
var _eat_release: bool = false
var _hint_view: Control = null
var _cache: Dictionary = {}


static func _script() -> GDScript:
	return load(SELF_PATH)


static func ensure_prefs() -> void:
	if _registered:
		return
	_registered = true
	for spec: Array in [[PREF_ON, true, {"label": "Program: show motion paths for the selected clips", "type": "bool"}], [PREF_STYLE, "line_dots", {"label": "Motion path look (dots, line, line_dots, ticks)", "type": "enum", "choices": Array(STYLES)}], [PREF_COLOUR, "blue", {"label": "Motion path colour", "type": "enum", "choices": COLOURS.keys()}], [PREF_SPAN, "all", {"label": "Motion path span (future, around, all)", "type": "enum", "choices": Array(SPANS)}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	if not Cmd.has(COMMAND_ID):
		var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
		Cmd.register(COMMAND_ID, {"label": "Motion paths on the Program monitor", "category": "View", "scope": "global", "handler": Callable(_script(), "toggle"), "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static"), "toggle": Callable(_script(), "is_on")})


static func is_on() -> bool:
	ensure_prefs()
	return bool(Prefs.get_value(PREF_ON))


static func toggle() -> void:
	ensure_prefs()
	Prefs.set_value(PREF_ON, not is_on())
	_redraw()


static func style() -> String:
	ensure_prefs()
	var v: String = String(Prefs.get_value(PREF_STYLE))
	return v if STYLES.has(v) else "line_dots"


static func span() -> String:
	ensure_prefs()
	var v: String = String(Prefs.get_value(PREF_SPAN))
	return v if SPANS.has(v) else "all"


static func ink() -> Color:
	ensure_prefs()
	return COLOURS.get(String(Prefs.get_value(PREF_COLOUR)), COLOURS["blue"])


static func _redraw() -> void:
	var bus: Object = load("res://modules/core_panels/panel_bus.gd").call("instance")
	var p: Object = bus.call("panel", "program") if bus != null else null
	var v: Variant = p.get("view") if p != null else null
	if v is Control and is_instance_valid(v):
		(v as Control).call("redraw_overlay")


static func look_items() -> Array:
	ensure_prefs()
	var items: Array = [PmMenu.check_item("mp:on", "Show motion paths", is_on(), Cmd.keys_text(COMMAND_ID)), PmMenu.check_item("mp:hints", "Show gesture hints", hints_on()), PmMenu.separator()]
	for st: String in STYLES:
		items.append(PmMenu.check_item("mp:style:" + st, String(STYLE_LABELS[st]), style() == st))
	items.append(PmMenu.separator())
	var cols: Array = []
	for k: Variant in COLOURS.keys():
		cols.append(PmMenu.check_item("mp:colour:" + String(k), String(COLOUR_LABELS[k]), String(Prefs.get_value(PREF_COLOUR)) == String(k)))
	items.append(PmMenu.sub_item("mp_colour", "Colour", cols))
	var spans: Array = []
	for sp: String in SPANS:
		spans.append(PmMenu.check_item("mp:span:" + sp, String(SPAN_LABELS[sp]), span() == sp))
	items.append(PmMenu.sub_item("mp_span", "How much of the path", spans))
	return items


static func on_look_menu(id: String) -> bool:
	if not id.begins_with("mp:"):
		return false
	ensure_prefs()
	var parts: PackedStringArray = id.split(":")
	if parts.size() == 2 and parts[1] == "on":
		Prefs.set_value(PREF_ON, not is_on())
	elif parts.size() == 2 and parts[1] == "hints":
		Prefs.set_value(PREF_HINTS, not hints_on())
	elif parts.size() == 3 and parts[1] == "style" and STYLES.has(parts[2]):
		Prefs.set_value(PREF_STYLE, parts[2])
	elif parts.size() == 3 and parts[1] == "colour" and COLOURS.has(parts[2]):
		Prefs.set_value(PREF_COLOUR, parts[2])
	elif parts.size() == 3 and parts[1] == "span" and SPANS.has(parts[2]):
		Prefs.set_value(PREF_SPAN, parts[2])
	else:
		return false
	_redraw()
	return true


static func key_seq_time(c: Clip, kt: float) -> float:
	var times: PackedFloat64Array = c.played_times_for(PATH, kt)
	if times.is_empty():
		return INF
	return c.start + times[0]


static func _lin(m: Transform2D) -> Transform2D:
	return Transform2D(m.x, m.y, Vector2.ZERO)


static func geometry(s: Sequence, c: Clip, pic: Rect2) -> Dictionary:
	if s == null or c == null or pic.size.x <= 0.0:
		return {}
	var p: Dictionary = c.get_param(PATH)
	if not AnimProp.is_animated(p) or not MotionPath.is_path(p):
		return {}
	var ks: Array = MotionPath.keys_array(p)
	var fps: float = s.fps if s.fps > 0.0 else 30.0
	var kpx: float = pic.size.x / maxf(float(s.width), 1.0)
	var half: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5
	var keys: Array[Dictionary] = []
	var t_lo: float = INF
	var t_hi: float = -INF
	for i: int in ks.size():
		var kt: float = float((ks[i] as Dictionary).get("t", 0.0))
		var ts: float = key_seq_time(c, kt)
		if not is_finite(ts):
			continue
		var m: Transform2D = Parenting.parent_xf(c, s, ts, fps)
		var lin: Transform2D = _lin(m)
		var at: Vector2 = pic.position + (half + m * MotionPath.key_pos(ks, i)) * kpx
		var tg: PackedVector2Array = MotionPath.tangents(ks, i)
		keys.append({"i": i, "kt": kt, "t": ts, "at": at, "in": at + lin.basis_xform(tg[0]) * kpx, "out": at + lin.basis_xform(tg[1]) * kpx, "has_in": tg[0].length() > HANDLE_MIN, "has_out": tg[1].length() > HANDLE_MIN, "into": lin.affine_inverse() if absf(lin.determinant()) > 0.000001 else Transform2D.IDENTITY, "kind": AnimProp.spatial_kind(ks[i]), "interp": str((ks[i] as Dictionary).get("i", "linear"))})
		t_lo = minf(t_lo, ts)
		t_hi = maxf(t_hi, ts)
	var dots: PackedVector2Array = PackedVector2Array()
	var times: PackedFloat64Array = PackedFloat64Array()
	if keys.size() >= 2:
		t_lo = maxf(t_lo, c.start)
		t_hi = minf(t_hi, c.end())
		var f0: int = int(ceil(t_lo * fps - 0.000001))
		var f1: int = int(floor(t_hi * fps + 0.000001))
		var step: int = maxi(1, int(ceil(float(f1 - f0 + 1) / float(MAX_SAMPLES))))
		var f: int = f0
		while f <= f1:
			var ts2: float = float(f) / fps
			dots.append(pic.position + (half + (Parenting.world_tf(c, s, ts2, fps)["pos"] as Vector2)) * kpx)
			times.append(ts2)
			f += step
	return {"clip_id": c.id, "keys": keys, "dots": dots, "times": times, "kpx": kpx}


static func now_point(s: Sequence, c: Clip, pic: Rect2) -> Variant:
	if s.playhead < c.start or s.playhead >= c.end():
		return null
	var kpx: float = pic.size.x / maxf(float(s.width), 1.0)
	var half: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5
	return pic.position + (half + (Parenting.world_tf(c, s, s.playhead, s.fps if s.fps > 0.0 else 30.0)["pos"] as Vector2)) * kpx


func _cached(d: Project, s: Sequence, c: Clip, pic: Rect2) -> Dictionary:
	var live: int = d.undo.live_serial if d != null and d.undo != null else 0
	var serial: int = d.serial if d != null else 0
	var sig: int = [serial, live, c.id, c.start, c.duration, pic, s.width, s.height, s.fps, Parenting.parent_id(c), c.transform.get("pos", {})].hash()
	var hit: Variant = _cache.get(c.id, null)
	if hit is Dictionary and int((hit as Dictionary)["sig"]) == sig:
		return (hit as Dictionary)["geo"]
	var geo: Dictionary = geometry(s, c, pic)
	if _cache.size() >= CACHE_MAX:
		_cache = {}
	_cache[c.id] = {"sig": sig, "geo": geo}
	return geo


static func path_clips(s: Sequence) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	for id: String in s.selected_clip_ids:
		if out.size() >= MAX_CLIPS:
			break
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		var t: Track = s.track_of(c.id)
		if t == null or not t.is_picture(c):
			continue
		var p: Dictionary = c.get_param(PATH)
		if AnimProp.is_animated(p) and MotionPath.is_path(p):
			out.append(c)
	return out


func _visible(t: float, now: float, mode: String) -> bool:
	if mode == "future":
		return t >= now - 0.0005
	if mode == "around":
		return absf(t - now) <= AROUND_SECONDS
	return true


func refresh(pic: Rect2, panel: Object) -> void:
	shown = []
	if pic.size.x <= 0.0 or not is_on():
		return
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null:
		return
	for c: Clip in path_clips(s):
		var geo: Dictionary = _cached(d, s, c, pic)
		if not geo.is_empty():
			shown.append(geo)


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	refresh(pic, panel)
	if shown.is_empty():
		hover = {}
		return
	var s: Sequence = panel.call("seq")
	var col: Color = ink()
	var look: String = style()
	var mode: String = span()
	for geo: Dictionary in shown:
		_draw_path(ci, geo, col, look, mode, s.playhead)
		_draw_keys(ci, geo, col, mode, s.playhead)
		var c: Clip = s.clip_by_id(String(geo["clip_id"]))
		var now: Variant = now_point(s, c, pic) if c != null else null
		if now is Vector2:
			ci.draw_arc(now, 5.0, 0.0, TAU, 20, SHADOW, 3.0, true)
			ci.draw_arc(now, 5.0, 0.0, TAU, 20, NOW_INK, 1.5, true)
	if not hover.is_empty() and drag.is_empty() and pending.is_empty():
		draw_hint(ci, pic, String(HINTS.get(String(hover["kind"]), "")), hover["at"])
	last_drawn = shown.size()


static func hints_on() -> bool:
	if not Prefs.is_registered(PREF_HINTS):
		Prefs.register(PREF_HINTS, true, {"label": "Program: show a small hint for the motion path gestures under the pointer", "type": "bool"})
	return bool(Prefs.get_value(PREF_HINTS))


static func draw_hint(ci: CanvasItem, pic: Rect2, text: String, at: Vector2) -> void:
	if text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HINT_FONT)
	var box: Rect2 = Rect2(at + HINT_GAP, ts + HINT_PAD * 2.0)
	if box.end.x > pic.end.x:
		box.position.x = maxf(pic.position.x, at.x - HINT_GAP.x - box.size.x)
	if box.end.y > pic.end.y:
		box.position.y = at.y - HINT_GAP.y - box.size.y
	ci.draw_rect(box, HINT_BACK, true)
	PmText.draw_at(ci, font, box.position + Vector2(HINT_PAD.x, HINT_PAD.y + font.get_ascent(HINT_FONT)), text, HINT_FONT, HINT_INK)


func _draw_path(ci: CanvasItem, geo: Dictionary, col: Color, look: String, mode: String, now: float) -> void:
	var dots: PackedVector2Array = geo["dots"]
	var times: PackedFloat64Array = geo["times"]
	var run: PackedVector2Array = PackedVector2Array()
	var runs: Array[PackedVector2Array] = []
	for i: int in dots.size():
		if _visible(times[i], now, mode):
			run.append(dots[i])
		elif run.size() > 0:
			runs.append(run)
			run = PackedVector2Array()
	if run.size() > 0:
		runs.append(run)
	var by_speed: bool = speed_colours_on()
	var range_px: Vector2 = speed_range(dots)
	for r: PackedVector2Array in runs:
		var cols: PackedColorArray = speed_colours(r, range_px, col) if by_speed else PackedColorArray()
		if look != "dots" and r.size() >= 2:
			ci.draw_polyline(r, LINE_SHADOW, LINE_W + 1.0, true)
			if by_speed:
				ci.draw_polyline_colors(r, cols, LINE_W, true)
			else:
				ci.draw_polyline(r, col, LINE_W, true)
		if look == "dots" or look == "line_dots":
			for qi: int in r.size():
				ci.draw_circle(r[qi], DOT_R + 0.8, SHADOW, true, -1.0, true)
				ci.draw_circle(r[qi], DOT_R, cols[qi] if by_speed else col, true, -1.0, true)
		elif look == "ticks" and r.size() >= 2:
			for j: int in r.size():
				var a: Vector2 = r[maxi(j - 1, 0)]
				var b: Vector2 = r[mini(j + 1, r.size() - 1)]
				var n: Vector2 = (b - a).orthogonal().normalized() * TICK
				ci.draw_line(r[j] - n, r[j] + n, col, 1.0, true)


static func speed_colours_on() -> bool:
	if not Prefs.is_registered(PREF_SPEED_COLOUR):
		Prefs.register(PREF_SPEED_COLOUR, true, {"label": "Motion paths are coloured by speed: blue where it moves slowly, red orange where it moves fast", "type": "bool"})
	return bool(Prefs.get_value(PREF_SPEED_COLOUR))


static func speed_range(dots: PackedVector2Array) -> Vector2:
	var lo: float = INF
	var hi: float = 0.0
	for i: int in range(1, dots.size()):
		var d: float = dots[i].distance_to(dots[i - 1])
		lo = minf(lo, d)
		hi = maxf(hi, d)
	if lo == INF:
		return Vector2.ZERO
	return Vector2(lo, hi)


static func speed_tint(step_px: float, range_px: Vector2) -> Color:
	var spread: float = range_px.y - range_px.x
	var t: float = 0.5 if spread < UNIFORM_PX else clampf((step_px - range_px.x) / spread, 0.0, 1.0)
	return SLOW_INK.lerp(FAST_INK, t)


static func speed_colours(r: PackedVector2Array, range_px: Vector2, fallback: Color) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	out.resize(r.size())
	if r.size() < 2:
		out.fill(fallback)
		return out
	for i: int in r.size():
		var a: Vector2 = r[maxi(i - 1, 0)]
		var b: Vector2 = r[mini(i + 1, r.size() - 1)]
		var span_n: int = mini(i + 1, r.size() - 1) - maxi(i - 1, 0)
		out[i] = speed_tint(a.distance_to(b) / float(maxi(span_n, 1)), range_px)
	return out


func _draw_keys(ci: CanvasItem, geo: Dictionary, col: Color, mode: String, now: float) -> void:
	var sel: PackedInt32Array = selected_keys(String(geo["clip_id"]))
	var handle_ink: Color = Color(col.r, col.g, col.b, 0.85)
	for k: Dictionary in (geo["keys"] as Array):
		if not _visible(float(k["t"]), now, mode):
			continue
		var at: Vector2 = k["at"]
		for side: String in ["in", "out"]:
			if not bool(k["has_" + side]):
				continue
			var end: Vector2 = k[side]
			ci.draw_line(at, end, SHADOW, 2.5, true)
			ci.draw_line(at, end, handle_ink, 1.0, true)
			ci.draw_circle(end, HANDLE_DOT + 0.8, SHADOW, true, -1.0, true)
			ci.draw_circle(end, HANDLE_DOT, handle_ink, true, -1.0, true)
		var box: Rect2 = Rect2(at - Vector2(KEY_BOX, KEY_BOX) * 0.5, Vector2(KEY_BOX, KEY_BOX))
		ci.draw_rect(box.grow(1.0), SHADOW, true)
		if sel.has(int(k["i"])):
			ci.draw_rect(box, Color(1.0, 1.0, 1.0), true)
			ci.draw_rect(box, col, false, 1.0)
		else:
			ci.draw_rect(box, col, true)


func selected_keys(clip_id: String) -> PackedInt32Array:
	if String(selected.get("clip_id", "")) != clip_id:
		return PackedInt32Array()
	return selected.get("keys", PackedInt32Array())


static func _seg_hit(a: Vector2, b: Vector2, p: Vector2) -> float:
	var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
	return q.distance_to(p)


func hit(at: Vector2, now: float, s: Sequence, pic: Rect2) -> Dictionary:
	var mode: String = span()
	for geo: Dictionary in shown:
		for k: Dictionary in (geo["keys"] as Array):
			if not _visible(float(k["t"]), now, mode):
				continue
			for side: String in ["out", "in"]:
				if bool(k["has_" + side]) and (k[side] as Vector2).distance_to(at) <= HANDLE_REACH:
					return {"kind": "handle", "side": side, "clip_id": geo["clip_id"], "key": k, "geo": geo}
	for geo2: Dictionary in shown:
		for k2: Dictionary in (geo2["keys"] as Array):
			if _visible(float(k2["t"]), now, mode) and (k2["at"] as Vector2).distance_to(at) <= KEY_REACH:
				return {"kind": "key", "clip_id": geo2["clip_id"], "key": k2, "geo": geo2}
	for geo3: Dictionary in shown:
		var c: Clip = s.clip_by_id(String(geo3["clip_id"])) if s != null else null
		if c != null:
			var np: Variant = now_point(s, c, pic)
			if np is Vector2 and (np as Vector2).distance_to(at) <= NOW_GUARD:
				continue
		var dots: PackedVector2Array = geo3["dots"]
		var times: PackedFloat64Array = geo3["times"]
		var best: float = LINE_REACH
		var best_t: float = -1.0
		var best_near: Vector2 = at
		for i: int in range(dots.size() - 1):
			if not _visible(times[i], now, mode):
				continue
			var dd: float = _seg_hit(dots[i], dots[i + 1], at)
			if dd <= best:
				best = dd
				var span_len: float = dots[i].distance_to(dots[i + 1])
				best_near = Geometry2D.get_closest_point_to_segment(at, dots[i], dots[i + 1])
				var f: float = 0.0 if span_len <= 0.0 else clampf(dots[i].distance_to(best_near) / span_len, 0.0, 1.0)
				best_t = times[i] + (times[i + 1] - times[i]) * f
		if best_t >= 0.0:
			return {"kind": "path", "clip_id": geo3["clip_id"], "t": best_t, "near": best_near, "geo": geo3}
	return {}


func _live(d: Project, s: Sequence, clip_id: String, next: Dictionary) -> void:
	d.undo.live(ClipCmds.SetClipParam.new(s.id, clip_id, PATH, next))


static func commit(d: Project, s: Sequence, clip_id: String, next: Dictionary, label: String) -> bool:
	var c: Clip = s.clip_by_id(clip_id)
	if c == null or c.get_param(PATH) == next:
		return false
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, clip_id, PATH, next)
	var tx: RefCounted = d.undo.begin(label)
	tx.call("apply", cmd)
	if bool(tx.call("is_empty")):
		tx.call("abandon")
		return false
	tx.call("commit")
	return true


func _select(clip_id: String, i: int, add: bool) -> void:
	var keys: PackedInt32Array = selected_keys(clip_id).duplicate() if add else PackedInt32Array()
	if add and keys.has(i):
		keys.remove_at(keys.find(i))
	else:
		keys.append(i)
	selected = {"clip_id": clip_id, "keys": keys}


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not is_on():
		return false
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			return _press(mb, pic, d, s, view)
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			return _release(mb, d, s, view)
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			return _context(mb, pic, s, view)
		return false
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not pending.is_empty():
			if mm.position.distance_to(pending["press"]) < SLOP:
				return true
			var press: Vector2 = pending["press"]
			var cid: String = String(pending["clip_id"])
			var grab: Dictionary = pending
			pending = {}
			if not bool(Session.get("recording")) and _start_bend(grab, s):
				_drag_to(mm, d, s)
				if view != null:
					view.call("redraw_overlay")
					view.accept_event()
				return true
			if String(panel.call("_handle_at", press)) == "move":
				panel.call("_start_gizmo_drag", cid, "move", press, pic)
			return false
		if drag.is_empty():
			_hover(mm, pic, s, view)
			return false
		_drag_to(mm, d, s)
		if view != null:
			view.call("redraw_overlay")
			view.accept_event()
		return true
	return false


func _hover(mm: InputEventMouseMotion, pic: Rect2, s: Sequence, view: Control) -> void:
	var was: String = String(hover.get("kind", ""))
	var kind: String = ""
	if mm.button_mask == 0 and not shown.is_empty() and hints_on():
		kind = String(hit(mm.position, s.playhead, s, pic).get("kind", ""))
	hover = {} if kind.is_empty() else {"kind": kind, "at": mm.position}
	if view == null:
		return
	if not kind.is_empty() and not view.mouse_exited.is_connected(_on_view_left):
		view.mouse_exited.connect(_on_view_left)
		_hint_view = view
	if kind != was or not kind.is_empty():
		view.call("redraw_overlay")


func _on_view_left() -> void:
	if hover.is_empty():
		return
	hover = {}
	if is_instance_valid(_hint_view):
		_hint_view.call("redraw_overlay")


func _start_bend(grab: Dictionary, s: Sequence) -> bool:
	var cid: String = String(grab["clip_id"])
	var c: Clip = s.clip_by_id(cid)
	if c == null:
		return false
	var seq_t: float = float(grab["t"])
	var p: Dictionary = c.get_param(PATH)
	var info: Dictionary = MotionPath.bend_grab(p, c.param_time(PATH, seq_t - c.start))
	if info.is_empty():
		return false
	var lin: Transform2D = _lin(Parenting.parent_xf(c, s, seq_t, s.fps if s.fps > 0.0 else 30.0))
	var into: Transform2D = lin.affine_inverse() if absf(lin.determinant()) > 0.000001 else Transform2D.IDENTITY
	drag = {"kind": "bend", "clip_id": cid, "i": int(info["i"]), "s": float(info["s"]), "base": info["base"], "near": grab["near"], "press": grab["press"], "into": into, "kpx": float(grab["kpx"]), "origin": p.duplicate(true), "start": info["base"], "side": "", "moved": true}
	return true


func _press(mb: InputEventMouseButton, pic: Rect2, d: Project, s: Sequence, view: Control) -> bool:
	hover = {}
	_eat_release = false
	var h: Dictionary = hit(mb.position, s.playhead, s, pic)
	if h.is_empty():
		if not selected.is_empty():
			selected = {}
			if view != null:
				view.call("redraw_overlay")
		return false
	var cid: String = String(h["clip_id"])
	var c: Clip = s.clip_by_id(cid)
	if c == null:
		return false
	var kind: String = String(h["kind"])
	var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
	if kind == "handle" and ctrl and (((h["key"] as Dictionary)["at"]) as Vector2).distance_to(mb.position) <= KEY_REACH:
		kind = "key"
	if kind == "path":
		if mb.double_click:
			pending = {}
			_eat_release = true
			add_key_at(d, s, cid, float(h["t"]))
		else:
			pending = {"clip_id": cid, "t": float(h["t"]), "press": mb.position, "near": h.get("near", mb.position), "kpx": float((h["geo"] as Dictionary)["kpx"])}
		if view != null:
			view.call("redraw_overlay")
			view.accept_event()
		return true
	var k: Dictionary = h["key"]
	var i: int = int(k["i"])
	if kind == "key" and not ctrl:
		if mb.shift_pressed or not selected_keys(cid).has(i):
			_select(cid, i, mb.shift_pressed)
	var ks: Array = MotionPath.keys_array(c.get_param(PATH))
	drag = {"kind": kind, "clip_id": cid, "i": i, "press": mb.position, "at": k["at"], "into": k["into"], "kpx": float((h["geo"] as Dictionary)["kpx"]), "origin": c.get_param(PATH).duplicate(true), "start": MotionPath.key_pos(ks, i), "side": String(h.get("side", "")), "moved": false}
	if kind == "key" and ctrl:
		drag["kind"] = "pull"
	if view != null:
		view.call("redraw_overlay")
		view.accept_event()
	return true


func _drag_to(mm: InputEventMouseMotion, d: Project, s: Sequence) -> void:
	var press: Vector2 = drag["press"]
	if not bool(drag["moved"]) and mm.position.distance_to(press) < SLOP:
		return
	drag["moved"] = true
	var into: Transform2D = drag["into"]
	var kpx: float = maxf(float(drag["kpx"]), 0.0001)
	var origin: Dictionary = drag["origin"]
	var i: int = int(drag["i"])
	var kind: String = String(drag["kind"])
	var next: Dictionary = origin
	if kind == "key":
		var delta: Vector2 = mm.position - press
		if mm.shift_pressed:
			if absf(delta.x) > absf(delta.y):
				delta.y = 0.0
			else:
				delta.x = 0.0
		var np: Vector2 = (drag["start"] as Vector2) + into.basis_xform(delta / kpx)
		next = MotionPath.move_key(origin, i, np)
	elif kind == "handle":
		var v: Vector2 = into.basis_xform((mm.position - (drag["at"] as Vector2)) / kpx)
		next = MotionPath.set_handle(origin, i, String(drag["side"]), v, mm.alt_pressed)
	elif kind == "pull":
		var v2: Vector2 = into.basis_xform((mm.position - (drag["at"] as Vector2)) / kpx)
		next = MotionPath.pull_handles(origin, i, v2)
	elif kind == "bend":
		var target: Vector2 = (drag["base"] as Vector2) + into.basis_xform((mm.position - (drag["near"] as Vector2)) / kpx)
		next = MotionPath.bend(origin, i, float(drag["s"]), target)
	_live(d, s, String(drag["clip_id"]), next)


const DRAG_LABELS: Dictionary = {"key": "Move a key on the path", "handle": "Bend the path", "pull": "Pull out path handles", "bend": "Bend the line between two keys"}


func _release(_mb: InputEventMouseButton, d: Project, s: Sequence, view: Control) -> bool:
	if _eat_release:
		_eat_release = false
		if view != null:
			view.accept_event()
		return true
	if not pending.is_empty():
		pending = {}
		selected = {}
		if view != null:
			view.call("redraw_overlay")
			view.accept_event()
		return true
	if drag.is_empty():
		return false
	var kind: String = String(drag["kind"])
	var label: String = String(DRAG_LABELS.get(kind, "Edit the path"))
	var moved: bool = bool(drag["moved"])
	var cid: String = String(drag["clip_id"])
	var i: int = int(drag["i"])
	drag = {}
	if moved and d.undo.has_live():
		d.undo.commit_live(label)
	elif not moved and kind == "pull":
		remove_key(d, s, cid, i)
	if view != null:
		view.call("redraw_overlay")
		view.accept_event()
	return true


func cancel(d: Project) -> void:
	if not drag.is_empty() and bool(drag["moved"]) and d != null:
		d.undo.cancel_live()
	drag = {}
	pending = {}
	hover = {}
	_eat_release = false


func remove_key(d: Project, s: Sequence, clip_id: String, i: int) -> bool:
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	if not commit(d, s, clip_id, MotionPath.delete_keys(c.get_param(PATH), PackedInt32Array([i])), "Delete a key on the path"):
		return false
	selected = {}
	return true


func add_key_at(d: Project, s: Sequence, clip_id: String, seq_t: float) -> int:
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return -1
	var kt: float = c.param_time(PATH, seq_t - c.start)
	var next: Dictionary = MotionPath.add_key(c.get_param(PATH), kt)
	if not commit(d, s, clip_id, next, "Add a key on the path"):
		return -1
	var ks: Array = MotionPath.keys_array(c.get_param(PATH))
	for i: int in ks.size():
		if absf(float((ks[i] as Dictionary).get("t", 0.0)) - kt) <= AnimProp.KEY_TOLERANCE:
			selected = {"clip_id": clip_id, "keys": PackedInt32Array([i])}
			return i
	return -1


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not e.pressed or selected.is_empty() or not is_on():
		return false
	if e.keycode != KEY_DELETE and e.keycode != KEY_BACKSPACE:
		return false
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	var cid: String = String(selected["clip_id"])
	var keys: PackedInt32Array = selected["keys"]
	if keys.is_empty() or s.clip_by_id(cid) == null:
		return false
	commit(d, s, cid, MotionPath.delete_keys(s.clip_by_id(cid).get_param(PATH), keys), "Delete keys on the path")
	selected = {}
	hover = {}
	var view: Variant = panel.get("view")
	if view is Control:
		(view as Control).call("redraw_overlay")
	return true


func _context(mb: InputEventMouseButton, pic: Rect2, s: Sequence, view: Control) -> bool:
	var h: Dictionary = hit(mb.position, s.playhead, s, pic)
	if h.is_empty():
		return false
	var cid: String = String(h["clip_id"])
	var keys: PackedInt32Array = PackedInt32Array()
	if h.has("key"):
		var i: int = int((h["key"] as Dictionary)["i"])
		keys = selected_keys(cid).duplicate()
		if not keys.has(i):
			keys = PackedInt32Array([i])
			selected = {"clip_id": cid, "keys": keys}
	var c: Clip = s.clip_by_id(cid)
	var seg: int = -1
	var kt: float = 0.0
	if String(h["kind"]) == "path" and c != null:
		kt = c.param_time(PATH, float(h["t"]) - c.start)
		seg = MotionPath.segment_of(MotionPath.keys_array(c.get_param(PATH)), kt)
	menu_ctx = {"clip_id": cid, "keys": keys, "seg": seg, "kt": kt}
	hover = {}
	var items: Array = menu_items(c, keys, seg)
	if view != null:
		var m: Control = PmMenu.open(view, items, view.get_global_transform() * mb.position)
		if m != null and m.is_inside_tree():
			m.connect("picked", _on_context_picked)
		view.accept_event()
	return true


func _on_context_picked(id: String) -> void:
	var bus: Object = load("res://modules/core_panels/panel_bus.gd").call("instance")
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	on_menu(id, d, s)
	if bus != null:
		_redraw()


static func curve_items(ks: Array, keys: PackedInt32Array, seg: int) -> Array:
	var out: Array = []
	var focus_i: int = keys[0] if not keys.is_empty() else (seg if seg >= 0 else -1)
	var focus: Dictionary = ks[focus_i] if focus_i >= 0 and focus_i < ks.size() else {}
	var kind: String = AnimProp.spatial_kind(focus) if not focus.is_empty() else ""
	for pr: String in MotionPath.CURVE_PRESETS:
		var label: String = String(CURVE_LABELS[pr])
		if pr == "arc" and seg < 0:
			label = "Arc through this point" if keys.size() <= 1 else "Arc through these points"
		var it: Dictionary = PmMenu.item("mp:curve:" + pr, label)
		if pr == "arc" and seg < 0 and MotionPath.arc_keys(ks, keys).is_empty():
			it["disabled"] = true
		out.append(it)
	out.append(PmMenu.separator())
	var whom: String = "this key" if keys.size() == 1 else ("these keys" if keys.size() > 1 else ("the two keys of this line" if seg >= 0 else "every key"))
	var head: Dictionary = PmMenu.item("mp:head", "Key shape for " + whom)
	head["disabled"] = true
	out.append(head)
	for sp: String in AnimProp.SPATIAL_KINDS:
		out.append(PmMenu.check_item("mp:sp:" + sp, String(SPATIAL_LABELS[sp]), kind == sp))
	return out


static func menu_items(c: Clip, keys: PackedInt32Array, seg: int = -1) -> Array:
	var items: Array = []
	var ks: Array = MotionPath.keys_array(c.get_param(PATH)) if c != null else []
	var focus: Dictionary = ks[keys[0]] if not keys.is_empty() and keys[0] < ks.size() else {}
	var interp: String = str(focus.get("i", "")) if not focus.is_empty() else ""
	items.append(PmMenu.sub_item("mp_curve", "Curve", curve_items(ks, keys, seg)))
	items.append(PmMenu.separator())
	for tm: String in ["linear", "ease_in", "ease_out", "ease_both", "hold"]:
		items.append(PmMenu.check_item("mp:t:" + tm, String(TEMPORAL_LABELS[tm]), interp == tm))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("mp:rove", "Make the speed even along the path"))
	items.append(PmMenu.item("mp:reverse", "Reverse the path"))
	items.append(PmMenu.item("mp:simplify", "Simplify the path (fewer keys)"))
	items.append(PmMenu.item("mp:smooth", "Smooth the path"))
	items.append(PmMenu.separator())
	if not keys.is_empty():
		items.append(PmMenu.item("mp:delete", "Delete key" if keys.size() == 1 else "Delete keys"))
	items.append(PmMenu.item("mp:keep_ends", "Delete all but the first and last key"))
	items.append(PmMenu.separator())
	items.append(PmMenu.sub_item("mp_look", "Path style", look_items()))
	return items


const OP_LABELS: Dictionary = {"rove": "Make the speed even along the path", "reverse": "Reverse the path", "simplify": "Simplify the path", "smooth": "Smooth the path", "delete": "Delete keys on the path", "keep_ends": "Delete all but the first and last key"}


func on_menu(id: String, d: Project, s: Sequence) -> bool:
	if not id.begins_with("mp:"):
		return false
	if on_look_menu(id):
		return true
	if d == null or s == null:
		return true
	var cid: String = String(menu_ctx.get("clip_id", ""))
	var c: Clip = s.clip_by_id(cid)
	if c == null:
		return true
	var keys: PackedInt32Array = menu_ctx.get("keys", PackedInt32Array())
	var seg: int = int(menu_ctx.get("seg", -1))
	var p: Dictionary = c.get_param(PATH)
	var parts: PackedStringArray = id.split(":")
	var next: Dictionary = p
	var label: String = ""
	if parts.size() == 3 and parts[1] == "sp":
		var shape_keys: PackedInt32Array = PackedInt32Array([seg, seg + 1]) if keys.is_empty() and seg >= 0 else keys
		next = MotionPath.set_spatial(p, shape_keys, parts[2])
		label = "Path shape: " + String(SPATIAL_LABELS.get(parts[2], parts[2]))
	elif parts.size() == 3 and parts[1] == "curve" and MotionPath.CURVE_PRESETS.has(parts[2]):
		next = MotionPath.curve_preset(p, keys, seg, parts[2], float(menu_ctx.get("kt", 0.0)))
		label = "Path curve: " + String(CURVE_LABELS[parts[2]])
	elif parts.size() == 3 and parts[1] == "t":
		next = MotionPath.set_temporal(p, keys, parts[2])
		label = "Path timing: " + String(TEMPORAL_LABELS.get(parts[2], parts[2]))
	elif parts.size() == 2:
		var op: String = parts[1]
		if op == "rove":
			next = MotionPath.rove(p)
		elif op == "reverse":
			next = MotionPath.reverse(p)
		elif op == "simplify":
			next = MotionPath.simplify(p, MotionPath.default_tolerance(p))
		elif op == "smooth":
			next = MotionPath.smooth_path(p)
		elif op == "delete":
			next = MotionPath.delete_keys(p, keys)
		elif op == "keep_ends":
			next = MotionPath.delete_all_but_ends(p)
		else:
			return true
		label = String(OP_LABELS[op])
		if op == "delete" or op == "keep_ends" or op == "simplify":
			selected = {}
	else:
		return true
	commit(d, s, cid, next, label)
	return true
