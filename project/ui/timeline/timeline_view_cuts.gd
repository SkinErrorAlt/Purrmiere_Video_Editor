extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const ViewMap := preload("res://doc/view_map.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PLAN_META := "view_cuts_plan"
const SCAN_MAX := 400
const GAP_W := 2.0
const TAG_INSET := 3.0
const TAG_MIN_W := 22.0
const TAG_RADIUS := 3.0
const FLAT_PX := 4.0
const NAME_ROW_MIN_LANE := 34.0
const SPAN_EPS := 0.000000001
const SNAP_PX := 8.0
const PREF_SNAP_PLAYHEAD := "timeline.snap_playhead"
const KEEP_OWN_LINES: PackedStringArray = ["trim", "ripple", "roll"]
const INK_DARK := Color(0.051, 0.055, 0.063)
const INK_LIGHT := Color(0.945, 0.949, 0.953)
const OWN := 0
const HEARD := 1
const PARTS_MAX := 512
const MIN_CLIP_PX := 3.0
const SILENT := 2

static var stats: Dictionary = {"records": 0, "record_usec": 0, "plans": 0, "plan_usec": 0, "plans_reused": 0, "snap_scans": 0, "segments": 0}
static var _records: Dictionary = {}
static var _records_doc: int = 0
static var _records_serial: int = -1
static var _prefs_seen: bool = false
static var _parts_cache: Dictionary = {}
static var _box_sets: Dictionary = {}
static var _box_theme: String = ""
static var _widths: Dictionary = {}
static var _last_id: int = 0
static var _last_geo: Dictionary = {}
static var _fills: Dictionary = {}
static var _plans: Dictionary = {}


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = _prefs()
	if prefs != null and not bool(prefs.call("is_registered", PREF_SNAP_PLAYHEAD)):
		prefs.call("register", PREF_SNAP_PLAYHEAD, true, {"label": "Snap the playhead when snapping is on", "type": "bool"})
	return prefs


static func snaps_playhead() -> bool:
	var prefs: Node = register_prefs()
	return prefs == null or bool(prefs.call("get_value", PREF_SNAP_PLAYHEAD))


static func lines_of(video: Clip, e: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var chs: Array[Dictionary] = ViewMap.changes(e, video)
	for i: int in range(1, chs.size()):
		out.append(video.start + float(chs[i]["u"]))
	return out


static func _record(d: Project, s: Sequence, video: Clip, e: Dictionary, posed: bool = false) -> Dictionary:
	if _records_doc != d.get_instance_id() or _records_serial != d.serial:
		_records = {}
		_records_doc = d.get_instance_id()
		_records_serial = d.serial
	var key: String = str(video.get_instance_id()) + "|" + String(e.get("uid", ""))
	var hit: Variant = _records.get(key, null)
	if hit is Dictionary:
		var hd: Dictionary = hit
		if posed or (not bool(hd["posed"]) and float(hd["start"]) == video.start and float(hd["duration"]) == video.duration and float(hd["in"]) == video.in_offset):
			return hd
	var t0: int = Time.get_ticks_usec()
	var parts: Dictionary = _parts(video, e)
	var rec: Dictionary = parts.duplicate()
	rec["video"] = video
	rec["start"] = video.start
	rec["duration"] = video.duration
	rec["in"] = video.in_offset
	var sp: float = absf(video.static_speed())
	rec["speed"] = sp if sp > 0.000001 else 1.0
	rec["posed"] = posed
	rec["sounds"] = _sounds_of(s, video, parts["map"], (parts["colours"] as PackedInt32Array).size())
	_records[key] = rec
	stats["records"] = int(stats["records"]) + 1
	stats["record_usec"] = int(stats["record_usec"]) + Time.get_ticks_usec() - t0
	return rec


static func _parts(video: Clip, e: Dictionary) -> Dictionary:
	var sign: String = "%d|%s|%s|%d|%d" % [e.hash(), str(video.duration), str(video.anim_start), video.anim_speed.hash(), hash(video.get("speeds"))]
	var hit: Variant = _parts_cache.get(sign, null)
	if hit is Dictionary:
		return hit
	var map: Dictionary = ViewMap.of(e)
	var us: PackedFloat64Array = PackedFloat64Array()
	var views: PackedInt32Array = PackedInt32Array()
	var top: int = ViewMap.crop_count(e) - 1
	for ch: Dictionary in ViewMap.changes(e, video):
		us.append(float(ch["u"]))
		views.append(int(ch["view"]))
		top = maxi(top, int(ch["view"]))
	var names: PackedStringArray = ViewMap.region_names(e)
	var colours: PackedInt32Array = PackedInt32Array()
	for v: int in top + 1:
		colours.append(ViewMap.colour_for(map, v))
		if v >= names.size():
			names.append("View " + str(v + 1))
	var out: Dictionary = {"map": map, "us": us, "views": views, "colours": colours, "names": names}
	if _parts_cache.size() >= PARTS_MAX:
		_parts_cache.clear()
	_parts_cache[sign] = out
	return out


static func _sounds_of(s: Sequence, video: Clip, map: Dictionary, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_link: bool = map.is_empty()
	if by_link and video.link_id.is_empty():
		return out
	var tracks: Dictionary = {}
	var named: Dictionary = {}
	var hear_tracks: Array[Dictionary] = []
	var hear_clips: Array[Dictionary] = []
	var views: Array = map.get("views", [])
	for v: int in count:
		var ht: Dictionary = {}
		var hc: Dictionary = {}
		if v < views.size() and views[v] is Dictionary:
			for tid: Variant in (views[v] as Dictionary).get("tracks", []):
				ht[String(tid)] = true
				tracks[String(tid)] = true
			for cid: Variant in (views[v] as Dictionary).get("clips", []):
				hc[String(cid)] = true
				named[String(cid)] = true
		hear_tracks.append(ht)
		hear_clips.append(hc)
	for vx: Variant in views:
		if vx is Dictionary:
			for tid2: Variant in (vx as Dictionary).get("tracks", []):
				tracks[String(tid2)] = true
			for cid2: Variant in (vx as Dictionary).get("clips", []):
				named[String(cid2)] = true
	var group_scope: bool = String(map.get("scope", "group")) == "group"
	for tr: Track in s.sound_carriers():
		if not by_link and not tracks.has(tr.id) and named.is_empty():
			continue
		var i: int = tr.index_of_first_visible(video.start)
		var n: int = 0
		while i < tr.clips.size() and tr.clips[i].start < video.end() and n < SCAN_MAX:
			var sc: Clip = tr.clips[i]
			i += 1
			n += 1
			if sc == video or sc.end() <= video.start or not tr.is_sound(sc):
				continue
			if by_link:
				if sc.link_id != video.link_id:
					continue
			else:
				if not tracks.has(tr.id) and not named.has(sc.id):
					continue
				if group_scope and not named.has(sc.id) and not ViewMap.in_family(video, sc):
					continue
			var heard: PackedByteArray = PackedByteArray()
			heard.resize(count)
			for v2: int in count:
				heard[v2] = 1 if by_link or (hear_tracks[v2] as Dictionary).has(tr.id) or (hear_clips[v2] as Dictionary).has(sc.id) else 0
			out.append({"clip": sc, "heard": heard})
	return out


static func _all_heard(count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	out.fill(1)
	return out


static func _add_source(by_clip: Dictionary, id: String, src: Dictionary) -> void:
	var was: Variant = by_clip.get(id, null)
	if was is Array:
		var list: Array = was
		list.append(src)
		list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return ((x["rec"] as Dictionary)["video"] as Clip).start < ((y["rec"] as Dictionary)["video"] as Clip).start)
		return
	by_clip[id] = [src]


static func add_clip(by_clip: Dictionary, d: Project, s: Sequence, video: Clip, e: Dictionary, posed: bool = false) -> void:
	var rec: Dictionary = _record(d, s, video, e, posed)
	_add_source(by_clip, video.id, {"rec": rec, "heard": _all_heard((rec["colours"] as PackedInt32Array).size())})
	for snd: Dictionary in (rec["sounds"] as Array):
		_add_source(by_clip, (snd["clip"] as Clip).id, {"rec": rec, "heard": snd["heard"]})


static func begin_paint(canvas: Control) -> void:
	if not _prefs_seen:
		_prefs_seen = true
		register_prefs()
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		_keep_plan(canvas, {})
		return
	var hw: float = float(canvas.get("header_w"))
	var t0: float = float(canvas.call("t_of", hw))
	var t1: float = float(canvas.call("t_of", canvas.size.x))
	var trim: Variant = canvas.get("trim_anim")
	var posed: bool = trim is Object and bool((trim as Object).get("posed"))
	var sign: String = ("posed|" if posed else "") + str(d.get_instance_id()) + "|" + str(d.serial) + "|" + s.id + "|" + str(t0) + "|" + str(t1)
	var old: Variant = canvas.get_meta(PLAN_META) if canvas.has_meta(PLAN_META) else null
	if old is Dictionary and String((old as Dictionary).get("sign", "")) == sign:
		stats["plans_reused"] = int(stats["plans_reused"]) + 1
		var od: Dictionary = old
		if not (od.get("clips", {}) as Dictionary).is_empty():
			var theme: String = _check_theme()
			if String(od.get("theme", "")) != theme:
				od["theme"] = theme
				od["bodies"] = _bodies()
				od["geo"] = {}
		return
	var started: int = Time.get_ticks_usec()
	var by_clip: Dictionary = {}
	var min_t: float = MIN_CLIP_PX / maxf(float(canvas.get("pps")), 0.000001)
	if posed:
		var width: float = t1 - t0
		t0 -= width
		t1 += width
	for tr: Track in s.picture_tracks():
		var i: int = tr.index_of_first_visible(t0)
		var n: int = 0
		while i < tr.clips.size() and tr.clips[i].start < t1 and n < SCAN_MAX:
			var c: Clip = tr.clips[i]
			i += 1
			n += 1
			if c.effects.is_empty() or c.duration < min_t:
				continue
			for e: Dictionary in c.effects:
				if e.get("id", "") == ViewMap.PAIR_VIEW_ID and bool(e.get("enabled", true)) and ViewMap.cuts_on(e) and tr.is_picture(c):
					add_clip(by_clip, d, s, c, e, posed)
					break
	var plan: Dictionary = {"sign": sign, "clips": by_clip, "geo": {}, "posed": posed}
	if not by_clip.is_empty():
		plan["bodies"] = _bodies()
		plan["theme"] = _check_theme()
	_keep_plan(canvas, plan)
	stats["plans"] = int(stats["plans"]) + 1
	stats["plan_usec"] = int(stats["plan_usec"]) + Time.get_ticks_usec() - started


static func _bodies() -> Array[Color]:
	var out: Array[Color] = []
	for i: int in Tk.LABEL_NAMES.size():
		out.append(Tk.label_colour(i).darkened(0.45))
	return out


static func _keep_plan(canvas: Control, plan: Dictionary) -> void:
	canvas.set_meta(PLAN_META, plan)
	if _plans.size() > 16:
		_plans = {}
	_plans[canvas.get_instance_id()] = plan


static func _plan(canvas: Control) -> Dictionary:
	var hit: Variant = _plans.get(canvas.get_instance_id(), null)
	if hit is Dictionary:
		return hit
	if not canvas.has_meta(PLAN_META):
		return {}
	var plan: Variant = canvas.get_meta(PLAN_META)
	return plan if plan is Dictionary else {}


static func any(canvas: Control) -> bool:
	return not (_plan(canvas).get("clips", {}) as Dictionary).is_empty()


static func sources_for(canvas: Control, c: Clip) -> Array:
	var clips: Dictionary = _plan(canvas).get("clips", {})
	if clips.is_empty():
		return []
	var hit: Variant = clips.get(c.id, null)
	return hit if hit is Array else []


static func base_of(rec: Dictionary) -> float:
	var v: Clip = rec["video"]
	if v.in_offset == float(rec["in"]):
		return v.start
	return v.start - (v.in_offset - float(rec["in"])) / float(rec["speed"])


static func _last_at_or_before(us: PackedFloat64Array, base: float, t: float) -> int:
	var lo: int = 0
	var hi: int = us.size() - 1
	if hi < 0 or base + us[0] > t:
		return 0
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if base + us[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


static func segments(c: Clip, sources: Array, t_lo: float, t_hi: float) -> Dictionary:
	var t0s: PackedFloat64Array = PackedFloat64Array()
	var t1s: PackedFloat64Array = PackedFloat64Array()
	var kinds: PackedInt32Array = PackedInt32Array()
	var views: PackedInt32Array = PackedInt32Array()
	var cols: PackedInt32Array = PackedInt32Array()
	var cuts: PackedByteArray = PackedByteArray()
	var names: PackedStringArray = PackedStringArray()
	var out: Dictionary = {"t0": t0s, "t1": t1s, "kind": kinds, "view": views, "colour": cols, "cut": cuts, "name": names}
	var lo: float = maxf(t_lo, c.start)
	var hi: float = minf(t_hi, c.end())
	if hi <= lo:
		return out
	var at: float = c.start
	for sv: Variant in sources:
		var src: Dictionary = sv
		var rec: Dictionary = src["rec"]
		var v: Clip = rec["video"]
		var a_src: float = maxf(maxf(v.start, c.start), at)
		var b_src: float = minf(v.end(), c.end())
		if b_src - a_src <= SPAN_EPS or b_src <= lo:
			continue
		if a_src >= hi:
			break
		if a_src - at > SPAN_EPS:
			t0s.append(at)
			t1s.append(a_src)
			kinds.append(OWN)
			views.append(-1)
			cols.append(-1)
			cuts.append(0)
			names.append("")
		var us: PackedFloat64Array = rec["us"]
		var vv: PackedInt32Array = rec["views"]
		var colours: PackedInt32Array = rec["colours"]
		var nm: PackedStringArray = rec["names"]
		var heard: PackedByteArray = src["heard"]
		var n: int = us.size()
		var base: float = base_of(rec)
		var k: int = _last_at_or_before(us, base, maxf(a_src, lo))
		var stop: float = minf(b_src, hi)
		while k < n:
			var s0: float = base + us[k]
			var s1: float = v.end() if k + 1 >= n else base + us[k + 1]
			var p0: float = maxf(s0, a_src)
			var p1: float = minf(s1, b_src)
			if p1 - p0 > SPAN_EPS:
				var view: int = vv[k]
				var on: bool = view >= 0 and view < heard.size() and heard[view] == 1
				t0s.append(p0)
				t1s.append(p1)
				kinds.append(HEARD if on else SILENT)
				views.append(view)
				cols.append(colours[view] if on and view >= 0 and view < colours.size() else -1)
				cuts.append(1 if k > 0 and s0 > c.start + SPAN_EPS and p0 == s0 else 0)
				names.append(nm[view] if view >= 0 and view < nm.size() else "")
			if s1 >= stop:
				break
			k += 1
		at = b_src
		if at >= hi:
			break
	if at < hi and c.end() - at > SPAN_EPS:
		t0s.append(at)
		t1s.append(c.end())
		kinds.append(OWN)
		views.append(-1)
		cols.append(-1)
		cuts.append(0)
		names.append("")
	return out


static func spans_for(canvas: Control, c: Clip) -> Array:
	var sources: Array = sources_for(canvas, c)
	var out: Array = []
	if sources.is_empty():
		return out
	var seg: Dictionary = segments(c, sources, c.start, c.end())
	var kinds: PackedInt32Array = seg["kind"]
	for i: int in kinds.size():
		if kinds[i] == OWN:
			continue
		out.append({"t0": (seg["t0"] as PackedFloat64Array)[i], "t1": (seg["t1"] as PackedFloat64Array)[i], "view": (seg["view"] as PackedInt32Array)[i], "heard": kinds[i] == HEARD, "colour": (seg["colour"] as PackedInt32Array)[i], "cut": (seg["cut"] as PackedByteArray)[i] == 1, "name": (seg["name"] as PackedStringArray)[i]})
	return out


static func _visible(canvas: Control, c: Clip, r: Rect2, x0: float) -> Vector2:
	var pps: float = maxf(float(canvas.get("pps")), 0.000001)
	return Vector2(c.start + (r.position.x - x0) / pps, c.start + (r.end.x - x0) / pps)


static func _theme_sign() -> String:
	return str(Tk.c["border_soft"]) + str(Tk.c["glass"]) + str(Tk.c["bg_lane_video"])


static func _check_theme() -> String:
	var sign: String = _theme_sign()
	if sign != _box_theme:
		_box_theme = sign
		_box_sets = {}
		_fills = {}
	return sign


static func _boxes_for(body: Color, enabled: bool, radius: float) -> Array:
	var key: Array = [body, enabled, int(radius)]
	var hit: Variant = _box_sets.get(key, null)
	if hit is Array:
		return hit
	var fill_col: Color = body if enabled else body.lerp(Tk.c["bg_lane_video"], 0.55)
	var fill: StyleBoxFlat = _flat(fill_col, radius, true, true)
	var right: StyleBoxFlat = _flat(fill_col, radius, false, true)
	var glass: StyleBoxFlat = _flat(Tk.c["glass"], radius, true, true)
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = Tk.c["border_soft"] if enabled else Tk.c["border"]
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(int(radius))
	edge.anti_aliasing = radius > 0.0
	edge.anti_aliasing_size = 0.7
	var tex: Variant = Paint.stripe_texture(Paint.stripe_colour(fill_col)) if enabled else null
	var set_: Array = [fill, right, glass, edge, tex, fill_col]
	if _box_sets.size() > 256:
		_box_sets = {}
	_box_sets[key] = set_
	return set_


static func _flat(col: Color, radius: float, left: bool, right: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	var rl: int = int(radius) if left else 0
	var rr: int = int(radius) if right else 0
	sb.corner_radius_top_left = rl
	sb.corner_radius_bottom_left = rl
	sb.corner_radius_top_right = rr
	sb.corner_radius_bottom_right = rr
	sb.anti_aliasing = radius > 0.0
	sb.anti_aliasing_size = 0.7
	return sb


static func _text_w(name: String) -> float:
	var key: String = name + "|" + str(_tag_fs())
	var hit: Variant = _widths.get(key, null)
	if hit is float:
		return hit
	var w: float = PmText.width_of(_tag_font(), name, _tag_fs())
	if _widths.size() > 512:
		_widths = {}
	_widths[key] = w
	return w


static func _rel_of(c: Clip, sources: Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array([c.duration])
	for sv: Variant in sources:
		var rec: Dictionary = (sv as Dictionary)["rec"]
		var v: Clip = rec["video"]
		out.append(base_of(rec) - c.start)
		out.append(v.start - c.start)
		out.append(v.end() - c.start)
	return out


static func _geo(canvas: Control, plan: Dictionary, t: Track, c: Clip, r: Rect2, x0: float, own: Color) -> Dictionary:
	var cache: Dictionary = plan["geo"]
	var key: int = c.get_instance_id()
	var hit: Variant = cache.get(key, null)
	if hit is Dictionary and not bool(plan["posed"]):
		var quick: Dictionary = hit
		if float(quick["x0"]) == x0 and quick["r"] == r and quick["own"] == own:
			return quick
	var found: Variant = (plan["clips"] as Dictionary).get(c.id, null)
	if not (found is Array):
		return {}
	var sources: Array = found
	if sources.size() == 1:
		return _single(canvas, plan, t, c, r, x0, own, sources[0], hit)
	var pps: float = maxf(float(canvas.get("pps")), 0.000001)
	var rel: PackedFloat64Array = _rel_of(c, sources)
	var need_lo: float = (r.position.x - x0) / pps
	var need_hi: float = (r.end.x - x0) / pps
	if hit is Dictionary:
		var hd: Dictionary = hit
		if float(hd["pps"]) == pps and hd["own"] == own and bool(hd["enabled"]) == c.enabled and float(hd["y"]) == r.position.y and float(hd["h"]) == r.size.y and hd["rel"] == rel and float(hd["lo"]) <= need_lo + SPAN_EPS and float(hd["hi"]) >= need_hi - SPAN_EPS:
			if float(hd["x0"]) != x0 or hd["r"] != r:
				_layout(hd, x0, r)
			return hd
	stats["segments"] = int(stats["segments"]) + 1
	var span: float = maxf(need_hi - need_lo, 0.0)
	var lo: float = maxf(need_lo - span, 0.0)
	var hi: float = minf(need_hi + span, c.duration)
	var bodies: Array = plan.get("bodies", [])
	var picture: bool = not t.is_sound(c)
	var plain: Color = Tk.c["clip_video"] if picture else Tk.c["clip_audio"]
	var radius: float = minf(float(Tk.px(Tk.sz("radius_clip"))), r.size.y * 0.5)
	var seg: Dictionary = segments(c, sources, c.start + lo, c.start + hi)
	var t0s: PackedFloat64Array = seg["t0"]
	var t1s: PackedFloat64Array = seg["t1"]
	var kinds: PackedInt32Array = seg["kind"]
	var cols: PackedInt32Array = seg["colour"]
	var cuts: PackedByteArray = seg["cut"]
	var names: PackedStringArray = seg["name"]
	var las: PackedFloat64Array = PackedFloat64Array()
	var lbs: PackedFloat64Array = PackedFloat64Array()
	var row_h: float = Paint.name_row_h()
	var tag_h: float = minf(row_h - 3.0, _tag_font().get_height(_tag_fs()) + 2.0)
	var sets: Array = []
	var gaps: PackedByteArray = PackedByteArray()
	var tag_names: PackedStringArray = PackedStringArray()
	var tag_w: PackedFloat64Array = PackedFloat64Array()
	var tag_fill: PackedColorArray = PackedColorArray()
	var last_w: float = INF
	var by_colour: Dictionary = {}
	var clear: Color = Color(0, 0, 0, 0)
	var quiet: bool = true
	for i: int in t0s.size():
		var la: float = (t0s[i] - c.start) * pps
		var lb: float = (t1s[i] - c.start) * pps
		var w: float = lb - la
		var ci: int = -2 if kinds[i] == OWN else cols[i]
		var set_: Variant = by_colour.get(ci, null)
		if set_ == null:
			var col: Color = own
			if kinds[i] != OWN:
				col = bodies[cols[i]] if cols[i] >= 0 and cols[i] < bodies.size() else plain
			set_ = _boxes_for(col, c.enabled, radius)
			by_colour[ci] = set_
		las.append(la)
		lbs.append(lb)
		sets.append(set_)
		var gap: bool = kinds[i] != OWN and cuts[i] == 1 and w >= FLAT_PX and last_w >= FLAT_PX
		gaps.append(1 if gap else 0)
		if picture and kinds[i] == HEARD and cols[i] >= 0 and not names[i].is_empty():
			tag_names.append(names[i])
			tag_w.append(1.0)
			tag_fill.append(Tk.label_colour(cols[i]))
			quiet = false
		else:
			tag_names.append("")
			tag_w.append(0.0)
			tag_fill.append(clear)
		if gap:
			quiet = false
		last_w = w
	var g: Dictionary = {"x0": x0, "r": r, "pps": pps, "own": own, "enabled": c.enabled, "y": r.position.y, "h": r.size.y, "rel": rel, "lo": lo if lo > 0.0 else -INF, "hi": hi if hi < c.duration else INF, "radius": radius, "la": las, "lb": lbs, "sets": sets, "gaps": gaps, "tag_names": tag_names, "tag_w": tag_w, "tag_fill": tag_fill, "quiet": quiet, "plain": las.size() == 1 and quiet, "row_h": row_h, "tag_h": tag_h, "font": _tag_font(), "fs": _tag_fs()}
	_layout(g, x0, r)
	cache[key] = g
	plan["geo"] = cache
	return g


static func _single(canvas: Control, plan: Dictionary, t: Track, c: Clip, r: Rect2, x0: float, own: Color, src: Dictionary, hit: Variant) -> Dictionary:
	var rec: Dictionary = src["rec"]
	var v: Clip = rec["video"]
	var pps: float = maxf(float(canvas.get("pps")), 0.000001)
	var inputs: PackedFloat64Array = PackedFloat64Array([x0, r.position.x, r.position.y, r.size.x, r.size.y, c.start, c.duration, v.start, v.duration, v.in_offset, pps, 1.0 if c.enabled else 0.0])
	var g: Dictionary = {}
	if hit is Dictionary and bool((hit as Dictionary).get("single", false)) and (hit as Dictionary)["own"] == own and is_same((hit as Dictionary)["rec"], rec):
		g = hit
		if g["inputs"] == inputs:
			return g
	else:
		g = _single_tables(plan, t, c, r, own, src)
		(plan["geo"] as Dictionary)[c.get_instance_id()] = g
	g["inputs"] = inputs
	g["pps"] = pps
	_fill_single(g, c, x0, r)
	_layout(g, x0, r)
	return g


static func _single_tables(plan: Dictionary, t: Track, c: Clip, r: Rect2, own: Color, src: Dictionary) -> Dictionary:
	var rec: Dictionary = src["rec"]
	var bodies: Array = plan.get("bodies", [])
	var picture: bool = not t.is_sound(c)
	var plain: Color = Tk.c["clip_video"] if picture else Tk.c["clip_audio"]
	var radius: float = minf(float(Tk.px(Tk.sz("radius_clip"))), r.size.y * 0.5)
	var colours: PackedInt32Array = rec["colours"]
	var names: PackedStringArray = rec["names"]
	var heard: PackedByteArray = src["heard"]
	var vset: Array = []
	var vkind: PackedInt32Array = PackedInt32Array()
	var vtag: PackedStringArray = PackedStringArray()
	var vfill: PackedColorArray = PackedColorArray()
	for view: int in colours.size():
		var on: bool = view < heard.size() and heard[view] == 1
		var ci: int = colours[view] if on else -1
		var col: Color = bodies[ci] if ci >= 0 and ci < bodies.size() else plain
		vset.append(_boxes_for(col, c.enabled, radius))
		vkind.append(HEARD if on else SILENT)
		var named: bool = picture and on and ci >= 0 and view < names.size() and not names[view].is_empty()
		vtag.append(names[view] if named else "")
		vfill.append(Tk.label_colour(ci) if named else Color(0, 0, 0, 0))
	var row_h: float = Paint.name_row_h()
	return {"single": true, "rec": rec, "own": own, "own_set": _boxes_for(own, c.enabled, radius), "vset": vset, "vkind": vkind, "vtag": vtag, "vfill": vfill, "enabled": c.enabled, "radius": radius, "row_h": row_h, "tag_h": minf(row_h - 3.0, _tag_font().get_height(_tag_fs()) + 2.0), "font": _tag_font(), "fs": _tag_fs()}


static func _fill_single(g: Dictionary, c: Clip, x0: float, r: Rect2) -> void:
	var rec: Dictionary = g["rec"]
	var v: Clip = rec["video"]
	var us: PackedFloat64Array = rec["us"]
	var views: PackedInt32Array = rec["views"]
	var vset: Array = g["vset"]
	var vtag: PackedStringArray = g["vtag"]
	var vfill: PackedColorArray = g["vfill"]
	var own_set: Array = g["own_set"]
	var pps: float = float(g["pps"])
	var base: float = base_of(rec)
	var c0: float = c.start
	var c1: float = c.end()
	var s0: float = maxf(v.start, c0)
	var s1: float = minf(v.end(), c1)
	var t_left: float = c0 + (r.position.x - x0) / pps
	var t_right: float = c0 + (r.end.x - x0) / pps
	var las: PackedFloat64Array = PackedFloat64Array()
	var lbs: PackedFloat64Array = PackedFloat64Array()
	var sets: Array = []
	var gaps: PackedByteArray = PackedByteArray()
	var tag_names: PackedStringArray = PackedStringArray()
	var tag_w: PackedFloat64Array = PackedFloat64Array()
	var tag_fill: PackedColorArray = PackedColorArray()
	var clear: Color = Color(0, 0, 0, 0)
	var last_w: float = INF
	var quiet: bool = true
	if s0 - c0 > SPAN_EPS:
		las.append(0.0)
		lbs.append((s0 - c0) * pps)
		sets.append(own_set)
		gaps.append(0)
		tag_names.append("")
		tag_w.append(0.0)
		tag_fill.append(clear)
		last_w = (s0 - c0) * pps
	var n: int = us.size()
	if s1 - s0 > SPAN_EPS and n > 0:
		var k: int = _last_at_or_before(us, base, maxf(s0, t_left))
		var stop: float = minf(s1, t_right)
		while k < n:
			var a_t: float = base + us[k]
			var b_t: float = v.end() if k + 1 >= n else base + us[k + 1]
			var p0: float = maxf(a_t, s0)
			var p1: float = minf(b_t, s1)
			if p1 - p0 > SPAN_EPS:
				var view: int = clampi(views[k], 0, vset.size() - 1)
				var la: float = (p0 - c0) * pps
				var lb: float = (p1 - c0) * pps
				var w: float = lb - la
				var gap: bool = k > 0 and a_t > c0 + SPAN_EPS and p0 == a_t and w >= FLAT_PX and last_w >= FLAT_PX
				las.append(la)
				lbs.append(lb)
				sets.append(vset[view])
				gaps.append(1 if gap else 0)
				tag_names.append(vtag[view])
				tag_w.append(1.0 if not vtag[view].is_empty() else 0.0)
				tag_fill.append(vfill[view])
				if gap or not vtag[view].is_empty():
					quiet = false
				last_w = w
			if b_t >= stop:
				break
			k += 1
	if c1 - s1 > SPAN_EPS and s1 >= s0:
		las.append((s1 - c0) * pps)
		lbs.append((c1 - c0) * pps)
		sets.append(own_set)
		gaps.append(0)
		tag_names.append("")
		tag_w.append(0.0)
		tag_fill.append(clear)
	g["la"] = las
	g["lb"] = lbs
	g["sets"] = sets
	g["gaps"] = gaps
	g["tag_names"] = tag_names
	g["tag_w"] = tag_w
	g["tag_fill"] = tag_fill
	g["quiet"] = quiet


static func _first_shown(lbs: PackedFloat64Array, x0: float, left: float) -> int:
	var lo: int = 0
	var hi: int = lbs.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if x0 + lbs[mid] <= left + 0.5:
			lo = mid + 1
		else:
			hi = mid
	return lo


static func _layout(g: Dictionary, x0: float, r: Rect2) -> void:
	stats["layouts"] = int(stats.get("layouts", 0)) + 1
	g["x0"] = x0
	g["r"] = r
	var las: PackedFloat64Array = g["la"]
	var lbs: PackedFloat64Array = g["lb"]
	var sets: Array = g["sets"]
	var gaps: PackedByteArray = g["gaps"]
	var tag_w: PackedFloat64Array = g["tag_w"]
	var tag_names: PackedStringArray = g["tag_names"]
	var tag_fill: PackedColorArray = g["tag_fill"]
	var radius: float = float(g["radius"])
	var row_h: float = float(g["row_h"])
	var tag_h: float = float(g["tag_h"])
	var left: float = r.position.x
	var right: float = r.end.x
	var small: bool = r.size.x < 24.0 or r.size.y < 12.0
	var stripes_on: bool = not small and bool(g["enabled"]) and r.size.y >= 10.0 and r.size.x - 4.0 >= Paint.STRIPE_MIN_W
	var n: int = las.size()
	var i0: int = _first_shown(lbs, x0, left)
	var pa: PackedFloat64Array = PackedFloat64Array()
	var pb: PackedFloat64Array = PackedFloat64Array()
	var ptag: Array[Rect2] = []
	var rects: Array[Rect2] = []
	var rect_cols: PackedColorArray = PackedColorArray()
	var stripe_rects: Array[Rect2] = []
	var stripe_tex: Array = []
	var gap_rects: Array[Rect2] = []
	var tag_rects: Array[Rect2] = []
	var tag_texts: PackedStringArray = PackedStringArray()
	var tag_fills: PackedColorArray = PackedColorArray()
	var tag_inks: PackedColorArray = PackedColorArray()
	var cap: Rect2 = Rect2()
	var cap_col: Color = Color(0, 0, 0, 0)
	var i: int = maxi(i0 - 1, 0)
	while i < n:
		var xa: float = x0 + las[i]
		if xa >= right:
			break
		if gaps[i] == 1 and xa > left + 1.0 and xa < right - 1.0:
			gap_rects.append(Rect2(xa - GAP_W * 0.5, r.position.y, GAP_W, r.size.y))
		if i < i0:
			i += 1
			continue
		var a: float = maxf(xa, left)
		var b: float = minf(x0 + lbs[i], right)
		var set_: Array = sets[i]
		var tag: Rect2 = Rect2()
		if b - a >= 0.5:
			if small or i > i0:
				if not small and b >= right - 0.5 and b - a >= radius * 2.0:
					cap = Rect2(a, r.position.y, b - a, r.size.y)
					cap_col = set_[5]
				else:
					rects.append(Rect2(a, r.position.y, b - a, r.size.y))
					rect_cols.append(set_[5])
			if stripes_on and b - a >= FLAT_PX:
				var sl: float = maxf(a, left + 2.0)
				var sr: float = minf(b, right - 2.0)
				if set_[4] is Texture2D and sr - sl >= 2.0:
					stripe_rects.append(Rect2(sl, r.position.y + 2.0, sr - sl, r.size.y - 4.0))
					stripe_tex.append(set_[4])
			var room: float = b - a - TAG_INSET * 2.0
			if tag_w[i] > 0.0 and room >= TAG_MIN_W:
				tag = Rect2(a + TAG_INSET, r.position.y + (row_h - tag_h) * 0.5, minf(_text_w(tag_names[i]) + PmText.chip_pad() * 2.0, room), tag_h)
				tag_rects.append(tag)
				tag_texts.append(tag_names[i])
				tag_fills.append(tag_fill[i])
				tag_inks.append(INK_DARK if tag_fill[i].get_luminance() > 0.42 else INK_LIGHT)
		pa.append(a)
		pb.append(b)
		ptag.append(tag)
		i += 1
	g["i0"] = i0
	g["small"] = small
	g["pa"] = pa
	g["pb"] = pb
	g["ptag"] = ptag
	g["rects"] = rects
	g["rect_cols"] = rect_cols
	g["cap"] = _cap_rects(cap, radius)
	g["cap_col"] = cap_col
	g["stripe_rects"] = stripe_rects
	g["stripe_tex"] = stripe_tex
	g["gap_rects"] = gap_rects
	g["tag_rects"] = tag_rects
	g["tag_texts"] = tag_texts
	g["tag_fills"] = tag_fills
	g["tag_inks"] = tag_inks
	g["loud"] = not gap_rects.is_empty() or not tag_rects.is_empty()
	g["plain"] = pa.size() <= 1 and tag_rects.is_empty()


static func draw_body(canvas: Control, t: Track, c: Clip, r: Rect2, x0: float, own: Color, selected: bool, hover: bool) -> bool:
	if r.size.x < MIN_CLIP_PX:
		return false
	var plan: Dictionary = _plan(canvas)
	if not plan.has("geo"):
		return false
	var g: Dictionary = _geo(canvas, plan, t, c, r, x0, own)
	if g.is_empty() or int(g["i0"]) >= (g["la"] as PackedFloat64Array).size():
		return false
	_last_id = c.get_instance_id()
	_last_geo = g
	var first: Array = (g["sets"] as Array)[int(g["i0"])]
	var small: bool = bool(g["small"])
	var radius: float = float(g["radius"])
	if not small:
		canvas.draw_style_box(first[0], r)
	var rects: Array[Rect2] = g["rects"]
	var cols: PackedColorArray = g["rect_cols"]
	for k: int in rects.size():
		canvas.draw_rect(rects[k], cols[k], true)
	var cap_rects: Array[Rect2] = g["cap"]
	if not cap_rects.is_empty():
		var cap_col: Color = g["cap_col"]
		for cr: Rect2 in cap_rects:
			canvas.draw_rect(cr, cap_col, true)
	var stripe_rects: Array[Rect2] = g["stripe_rects"]
	var stripe_tex: Array = g["stripe_tex"]
	for k2: int in stripe_rects.size():
		canvas.draw_texture_rect(stripe_tex[k2], stripe_rects[k2], true)
	if not small and hover and not selected:
		canvas.draw_style_box(first[2], r)
	if selected:
		Paint.rounded(canvas, r, Color(0, 0, 0, 0), radius, Tk.c["sol"], 1)
		Paint.rounded(canvas, r.grow(-1.0), Color(0, 0, 0, 0), maxf(radius - 1.0, 0.0), Tk.c["sol"], 1)
	elif not small:
		canvas.draw_style_box(first[3], r)
	else:
		canvas.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
	return true


static func _cap_rects(rr: Rect2, radius: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not rr.has_area():
		return out
	var cols: int = int(ceil(radius))
	out.append(Rect2(rr.position.x, rr.position.y, rr.size.x - float(cols), rr.size.y))
	for dx: int in cols:
		var off: float = radius - float(dx) - 0.5
		var inset: float = radius - sqrt(maxf(radius * radius - off * off, 0.0))
		out.append(Rect2(rr.end.x - float(dx) - 1.0, rr.position.y + inset, 1.0, rr.size.y - inset * 2.0))
	return out


static func _lane_fill(kind: String, band: bool) -> Color:
	var key: String = kind + ("|b" if band else "|m")
	var hit: Variant = _fills.get(key, null)
	if hit is Color:
		return hit
	var col: Color = Paint.lane_fill(kind, band, false)
	_fills[key] = col
	return col


static func _drawn_geo(c: Clip) -> Dictionary:
	if _last_id != c.get_instance_id():
		return {}
	return _last_geo


static func _tag_font() -> Font:
	return Tk.font("body")


static func _tag_fs() -> int:
	return Tk.fs(Tk.sz("font_tiny"))


static func name_room(canvas: Control, c: Clip, x0: float, name_r: Rect2) -> Rect2:
	var g: Dictionary = _drawn_geo(c)
	if g.is_empty() or bool(g["plain"]):
		return name_r
	var pa: PackedFloat64Array = g["pa"]
	var pb: PackedFloat64Array = g["pb"]
	var ptag: Array[Rect2] = g["ptag"]
	for i: int in pa.size():
		if pb[i] <= name_r.position.x + 0.5:
			continue
		var a: float = maxf(pa[i], name_r.position.x)
		var b: float = minf(pb[i], name_r.end.x)
		var from: float = maxf(ptag[i].end.x + 2.0, a) if ptag[i].has_area() else a
		return Rect2(from, name_r.position.y, maxf(b - from, 0.0), name_r.size.y)
	return Rect2(name_r.position, Vector2(0.0, name_r.size.y))


static func draw_marks(canvas: Control, lane: Dictionary, t: Track, c: Clip, r: Rect2, x0: float, lane_h: float) -> void:
	var g: Dictionary = _drawn_geo(c)
	if g.is_empty() or not bool(g["loud"]):
		return
	var gap_rects: Array[Rect2] = g["gap_rects"]
	if not gap_rects.is_empty():
		var fv: Variant = g.get("fill", null)
		if not (fv is Color):
			fv = _lane_fill(t.kind, String(lane.get("set", "")) == "band")
			g["fill"] = fv
		var fill: Color = fv
		for gr: Rect2 in gap_rects:
			canvas.draw_rect(gr, fill, true)
	if lane_h < NAME_ROW_MIN_LANE:
		return
	var tag_rects: Array[Rect2] = g["tag_rects"]
	if tag_rects.is_empty():
		return
	var texts: PackedStringArray = g["tag_texts"]
	var fills: PackedColorArray = g["tag_fills"]
	var inks: PackedColorArray = g["tag_inks"]
	var font: Font = g["font"]
	var fs: int = int(g["fs"])
	var pad: float = PmText.chip_pad()
	for k: int in tag_rects.size():
		var tr_: Rect2 = tag_rects[k]
		canvas.draw_rect(Rect2(tr_.position.x + 1.0, tr_.position.y, tr_.size.x - 2.0, tr_.size.y), fills[k], true)
		canvas.draw_rect(Rect2(tr_.position.x, tr_.position.y + 1.0, tr_.size.x, tr_.size.y - 2.0), fills[k], true)
		PmText.draw(canvas, font, tr_, texts[k], fs, inks[k], HORIZONTAL_ALIGNMENT_LEFT, pad)


static func cut_times(rec: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var video: Clip = rec["video"]
	var base: float = base_of(rec)
	var us: PackedFloat64Array = rec["us"]
	for i: int in range(1, us.size()):
		var at: float = base + us[i]
		if at > video.start and at < video.end():
			out.append(at)
	return out


static func snap_times(canvas: Control, s: Sequence, t0: float, t1: float, excluded: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var d: Project = canvas.call("doc")
	if d == null or s == null:
		return out
	stats["snap_scans"] = int(stats["snap_scans"]) + 1
	var drag: Variant = canvas.get("drag")
	var mode: String = String((drag as Object).get("mode")) if drag is Object else ""
	var keep_own: bool = KEEP_OWN_LINES.has(mode)
	for tr: Track in s.picture_tracks():
		if tr.hidden:
			continue
		var i: int = tr.index_of_first_visible(t0)
		var n: int = 0
		while i < tr.clips.size() and tr.clips[i].start < t1 and n < SCAN_MAX:
			var c: Clip = tr.clips[i]
			i += 1
			n += 1
			if c.effects.is_empty() or not tr.is_picture(c):
				continue
			if excluded.has(c.id) and not keep_own:
				continue
			var e: Dictionary = ViewMap.cut_entry(c)
			if not e.is_empty():
				out.append_array(cut_times(_record(d, s, c, e)))
	return out


static func move_offsets(host: Control, s: Sequence, ids: PackedStringArray, anchor: Clip) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var d: Project = host.call("doc")
	if d == null or s == null or anchor == null:
		return out
	for id: String in ids:
		var f: Clip = s.clip_by_id(id)
		if f == null or f.effects.is_empty():
			continue
		var e: Dictionary = ViewMap.cut_entry(f)
		if e.is_empty():
			continue
		for at: float in cut_times(_record(d, s, f, e)):
			out.append(at - anchor.start)
	return out


static func snap_scrub(drag: RefCounted, host: Control, t: float) -> float:
	drag.set("snap_x", -INF)
	if not bool(host.get("snapping")) or not snaps_playhead():
		return t
	var targets: PackedFloat64Array = drag.get("snap_targets")
	if targets.is_empty():
		targets = host.call("snap_targets", PackedStringArray())
		var s: Sequence = host.call("seq")
		if s != null:
			var own: int = targets.find(s.playhead)
			if own >= 0:
				targets.remove_at(own)
		drag.set("snap_targets", targets)
	if targets.is_empty():
		return t
	var reach: float = SNAP_PX / maxf(float(host.get("pps")), 0.000001)
	var lo: int = 0
	var hi: int = targets.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if targets[mid] < t:
			lo = mid + 1
		else:
			hi = mid
	var best: float = t
	var best_d: float = reach
	var found: bool = false
	for i: int in [lo - 1, lo]:
		if i < 0 or i >= targets.size():
			continue
		var dist: float = absf(targets[i] - t)
		if dist < best_d:
			best_d = dist
			best = targets[i]
			found = true
	if found:
		drag.set("snap_x", float(host.call("x_of", best)))
	return maxf(best, 0.0)
