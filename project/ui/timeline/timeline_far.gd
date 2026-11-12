extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const ViewMap := preload("res://doc/view_map.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const ViewCuts := preload("res://ui/timeline/timeline_view_cuts.gd")
const Content := preload("res://ui/timeline/timeline_far_content.gd")

const SLIM_PX := 40.0
const WAVE_SLIM_PX := 4.0
const SUMMARY_PX := 32.0
const SUMMARY_MIN_COUNT := 24
const FULL_BUDGET := 36
const DENSE_DEFAULT := 80
const CUT_SPACING_COLUMNS := 3.0
const SELECTED_MIX := 0.45
const DISABLED_MIX := 0.55
const EDGE_ALPHA := 1.0
const CACHE_MAX := 128
const LEVEL_REACH := 12
const LEVELS_MAX := 96
const VIEW_RUNS_MAX := 4096

static var stats: Dictionary = {"paint": -1, "slim": 0, "dense_lanes": 0, "runs": 0, "cuts": 0, "wide": 0, "base_builds": 0, "level_builds": 0, "build_usec": 0}
static var _bases: Dictionary = {}
static var _paint_bases: Dictionary = {}
static var _paint_memo: Dictionary = {}
static var _view_runs: Dictionary = {}
static var _slim_px: Dictionary = {}
static var _slim_paint_id: int = 0
static var _slim_paint: int = -1
static var _slim_paint_px: float = 40.0
static var _levels: Dictionary = {}


static func _tick(canvas: Control) -> void:
	var p: int = int(canvas.get("paint_count"))
	if int(stats["paint"]) == p:
		return
	stats["paint"] = p
	stats["slim"] = 0
	stats["dense_lanes"] = 0
	stats["runs"] = 0
	stats["cuts"] = 0
	stats["wide"] = 0
	stats["building"] = 0
	stats["content_usec"] = 0


static func is_slim(x0: float, x1: float) -> bool:
	return x1 - x0 < SLIM_PX


static func wave_too_slim(x0: float, x1: float) -> bool:
	return x1 - x0 < WAVE_SLIM_PX


static func slim_px(canvas: Control) -> float:
	var p: int = int(canvas.get("paint_count"))
	var id: int = canvas.get_instance_id()
	if _slim_paint_id == id and _slim_paint == p:
		return _slim_paint_px
	_slim_paint_id = id
	_slim_paint = p
	_slim_paint_px = _slim_px_for(canvas)
	return _slim_paint_px


static func _slim_px_for(canvas: Control) -> float:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return SLIM_PX
	var sign: String = "%d|%d|%s|%s|%s|%s|%s|%s" % [d.get_instance_id(), d.serial, s.id, str(canvas.get("pps")), str(canvas.get("scroll_x")), str(canvas.get("scroll_y")), str(canvas.get("band_scroll_y")), str(canvas.size)]
	var key: int = canvas.get_instance_id()
	var hit: Variant = _slim_px.get(key, null)
	if hit is Array and String((hit as Array)[0]) == sign:
		return float((hit as Array)[1])
	var widths: PackedFloat32Array = visible_widths(canvas)
	var px: float = SLIM_PX
	if widths.size() > FULL_BUDGET:
		widths.sort()
		px = maxf(SLIM_PX, widths[widths.size() - FULL_BUDGET - 1] + 0.001)
	if _slim_px.size() > 16:
		_slim_px.clear()
	_slim_px[key] = [sign, px]
	return px


static func visible_widths(canvas: Control) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var ln: Dictionary = canvas.call("lanes")
	var g: Dictionary = canvas.call("geometry")
	var pps: float = float(canvas.get("pps"))
	var hw: float = float(canvas.get("header_w"))
	var t_lo: float = float(canvas.call("t_of", hw))
	var t_hi: float = float(canvas.call("t_of", canvas.size.x))
	for set_name: String in ["main", "band"]:
		var region: Rect2 = g["main_rect"] if set_name == "main" else g["band_rect"]
		if region.size.y <= 0.0:
			continue
		var set_scroll: float = float(canvas.get("scroll_y")) if set_name == "main" else float(canvas.get("band_scroll_y"))
		for l: Dictionary in ln[set_name]:
			if bool(l["nest"]):
				continue
			var y: float = region.position.y + float(l["y"]) - set_scroll
			if y + float(l["h"]) < region.position.y or y > region.end.y:
				continue
			var t: Track = l["track"]
			var i: int = t.index_of_first_visible(t_lo)
			var j: int = t.index_of_last_starting_before(t_hi)
			if j < i or dense(canvas, j - i + 1, DENSE_DEFAULT):
				continue
			for k: int in range(i, j + 1):
				var c: Clip = t.clips[k]
				var w: float = c.duration * pps
				if w >= SLIM_PX:
					out.append(w)
	return out


static func dense(canvas: Control, count: int, limit: int) -> bool:
	if canvas.has_method("fold") and not (canvas.call("fold") as Dictionary).is_empty():
		return false
	if count > limit:
		return true
	if count < SUMMARY_MIN_COUNT:
		return false
	var view_px: float = canvas.size.x - float(canvas.get("header_w"))
	return view_px / float(count) < SUMMARY_PX


static func slim(canvas: Control, t: Track, c: Clip, item: MediaItem, r: Rect2, x0: float, x1: float, col: Color, selected: bool, hover: bool, view_cuts: bool) -> bool:
	if x1 - x0 >= SLIM_PX and x1 - x0 >= slim_px(canvas):
		return false
	_tick(canvas)
	stats["slim"] = int(stats["slim"]) + 1
	draw_slim_body(canvas, r, col, selected, hover, c.enabled)
	if view_cuts and t.kind == "video" and not c.effects.is_empty():
		_slim_views(canvas, c, r, x0, selected)
	if t.is_sound(c):
		if x1 - x0 < SLIM_PX:
			Content.slim_wave(canvas, c, item, r, x0)
	elif t.is_picture(c):
		Content.slim_frames(canvas, c, item, r, x0, x1)
	if item != null and (item.missing or c.placeholder):
		Paint.hatch(canvas, r, Tk.c["hatch"])
	if view_cuts and not c.effects.is_empty() and t.kind == "video":
		_slim_lines(canvas, t, c, r)
	return true


static func draw_slim_body(canvas: Control, r: Rect2, col: Color, selected: bool, hover: bool, enabled: bool) -> void:
	canvas.draw_rect(r, col if enabled else col.lerp(Tk.c["bg_lane_video"], DISABLED_MIX), true)
	if hover and not selected:
		canvas.draw_rect(r, Tk.c["glass"], true)
	canvas.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["sol"] if selected else Tk.c["border_soft"], false, 1.0)


static func slim_fast(canvas: Control, t: Track, c: Clip, r: Rect2, x0: float, x1: float, hovered: bool, view_cuts: bool, skip: bool) -> bool:
	if skip:
		return false
	if x1 - x0 >= SLIM_PX and x1 - x0 >= slim_px(canvas):
		return false
	var memo: Dictionary = _memo(canvas)
	var media: Dictionary = memo["media"]
	var item: MediaItem = null
	var hit: Variant = media.get(c.media_id, false)
	if hit is bool:
		var d: Project = canvas.call("doc")
		item = d.media_by_id(c.media_id) if d != null else null
		media[c.media_id] = item
	else:
		item = hit
	var selected: bool = (memo["sel"] as Dictionary).has(c.id)
	return slim(canvas, t, c, item, r, x0, x1, Paint.clip_colour(c, item, t), selected, hovered, view_cuts)


static func _slim_views(canvas: Control, c: Clip, r: Rect2, x0: float, selected: bool) -> void:
	var d: Project = _memo(canvas)["doc"]
	var vr: Dictionary = view_runs(d, c)
	if vr.is_empty():
		return
	var pps: float = float(canvas.get("pps"))
	var vt0: PackedFloat64Array = vr["t0"]
	var vt1: PackedFloat64Array = vr["t1"]
	var vcols: PackedColorArray = vr["cols"]
	var inner: Rect2 = r.grow(-1.0)
	var sol: Color = Tk.c["sol"]
	for q: int in vcols.size():
		var a: float = maxf(x0 + (vt0[q] - c.start) * pps, inner.position.x)
		var b: float = minf(x0 + (vt1[q] - c.start) * pps, inner.end.x)
		if b - a < 0.5:
			continue
		canvas.draw_rect(Rect2(a, inner.position.y, b - a, inner.size.y), vcols[q].lerp(sol, SELECTED_MIX) if selected else vcols[q], true)


static func _memo(canvas: Control) -> Dictionary:
	var p: int = int(canvas.get("paint_count"))
	var id: int = canvas.get_instance_id()
	if int(_paint_memo.get("paint", -1)) == p and int(_paint_memo.get("id", 0)) == id:
		return _paint_memo
	var sel: Dictionary = {}
	var s: Sequence = canvas.call("seq")
	if s != null:
		for sid: String in s.selected_clip_ids:
			sel[sid] = true
	_paint_memo = {"paint": p, "id": id, "sel": sel, "media": {}, "doc": canvas.call("doc")}
	return _paint_memo


static func _paint_base(canvas: Control, t: Track) -> Dictionary:
	var key: String = str(canvas.get_instance_id()) + "|" + t.id
	var p: int = int(canvas.get("paint_count"))
	var hit: Variant = _paint_bases.get(key, null)
	if hit is Array and int((hit as Array)[0]) == p:
		return (hit as Array)[1]
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return {}
	var base: Dictionary = base_of(canvas, d, s, t)
	if _paint_bases.size() >= CACHE_MAX:
		_paint_bases.clear()
	_paint_bases[key] = [p, base]
	return base


static func _slim_lines(canvas: Control, t: Track, c: Clip, r: Rect2) -> void:
	var lines: PackedFloat64Array = _lines_near(canvas, t, c)
	if lines.is_empty():
		return
	var a: int = lines.bsearch(c.start, false)
	var b: int = lines.bsearch(c.start + c.duration, true)
	if b <= a:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var last_x: float = -INF
	for k: int in range(a, b):
		var x: float = float(canvas.call("x_of", lines[k]))
		if x - last_x < 2.0 or x <= r.position.x or x >= r.end.x:
			continue
		last_x = x
		pts.append(Vector2(x, r.position.y + 1.0))
		pts.append(Vector2(x, r.end.y - 1.0))
	if not pts.is_empty():
		canvas.draw_multiline(pts, cut_colour(), -1.0)


static func _lines_near(canvas: Control, t: Track, c: Clip) -> PackedFloat64Array:
	var lines: PackedFloat64Array = PackedFloat64Array()
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or t.kind != "video":
		return lines
	for o: Clip in t.clips_in_range(c.start, c.start + c.duration):
		if o.effects.is_empty():
			continue
		var vr: Dictionary = view_runs(d, o)
		if vr.is_empty() or (vr["cols"] as PackedColorArray).is_empty():
			continue
		lines.append_array(ViewCuts.lines_of(o, ViewMap.cut_entry(o)))
	lines.sort()
	return lines


static func level_for(pps: float) -> int:
	return int(floor(log(1.0 / maxf(pps, 0.0000001)) / log(2.0)))


static func _theme_sig() -> String:
	return str(Tk.c["clip_video"]) + str(Tk.c["clip_audio"]) + str(Tk.c["sol"]) + str(Tk.c["bg_lane_video"])


static func _colour_of(c: Clip, t: Track, d: Project, media_cols: Dictionary) -> Color:
	if c.colour >= 0:
		return Tk.label_colour(c.colour).darkened(0.45)
	var hit: Variant = media_cols.get(c.media_id, null)
	if hit is Color:
		return hit
	var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var col: Color = Paint.clip_colour(c, item, t)
	if not c.is_nest():
		media_cols[c.media_id] = col
	return col


static func view_runs(d: Project, c: Clip) -> Dictionary:
	if c.effects.is_empty():
		return {}
	var e: Dictionary = ViewMap.cut_entry(c)
	if e.is_empty():
		return {}
	var key: String = "%d|%d|%d|%s|%s" % [d.get_instance_id() if d != null else 0, d.serial if d != null else 0, c.get_instance_id(), str(c.start), str(c.duration)]
	var hit: Variant = _view_runs.get(key, null)
	if hit is Dictionary:
		return hit
	var parts: Dictionary = ViewCuts._parts(c, e)
	var us: PackedFloat64Array = parts["us"]
	var views: PackedInt32Array = parts["views"]
	var colours: PackedInt32Array = parts["colours"]
	var t0s: PackedFloat64Array = PackedFloat64Array()
	var t1s: PackedFloat64Array = PackedFloat64Array()
	var cols: PackedColorArray = PackedColorArray()
	var end: float = c.start + c.duration
	for k: int in us.size():
		var a: float = clampf(c.start + us[k], c.start, end)
		var b: float = end if k + 1 >= us.size() else clampf(c.start + us[k + 1], c.start, end)
		if b <= a:
			continue
		var v: int = views[k]
		if v < 0 or v >= colours.size() or colours[v] < 0:
			continue
		t0s.append(a)
		t1s.append(b)
		cols.append(Tk.label_colour(colours[v]).darkened(0.45))
	var out: Dictionary = {"t0": t0s, "t1": t1s, "cols": cols}
	if _view_runs.size() >= VIEW_RUNS_MAX:
		_view_runs.clear()
	_view_runs[key] = out
	return out


static func base_of(canvas: Control, d: Project, s: Sequence, t: Track) -> Dictionary:
	var sel_hash: int = hash(s.selected_clip_ids) if not s.selected_clip_ids.is_empty() else 0
	var lines_on: bool = t.kind == "video"
	var sign: String = "%d|%d|%d|%d|%s|%s" % [d.get_instance_id(), d.serial, t.get_instance_id(), sel_hash, _theme_sig(), str(t.clips.size())]
	var key: String = str(canvas.get_instance_id()) + "|" + t.id
	var hit: Variant = _bases.get(key, null)
	if hit is Dictionary and String((hit as Dictionary)["sign"]) == sign:
		return hit
	var t0: int = Time.get_ticks_usec()
	var n: int = t.clips.size()
	var starts: PackedFloat64Array = PackedFloat64Array()
	var ends: PackedFloat64Array = PackedFloat64Array()
	var cols: PackedColorArray = PackedColorArray()
	starts.resize(n)
	ends.resize(n)
	cols.resize(n)
	var selected: Dictionary = {}
	for id: String in s.selected_clip_ids:
		selected[id] = true
	var media_cols: Dictionary = {}
	var lines: PackedFloat64Array = PackedFloat64Array()
	var sol: Color = Tk.c["sol"]
	var lane_bg: Color = Tk.c["bg_lane_video"]
	var clip_starts: PackedFloat64Array = PackedFloat64Array()
	var clip_ends: PackedFloat64Array = PackedFloat64Array()
	clip_starts.resize(n)
	clip_ends.resize(n)
	var label_cols: Dictionary = {}
	var any_sel: bool = not selected.is_empty()
	var clips: Array[Clip] = t.clips
	var w: int = 0
	var split_any: bool = false
	for k: int in n:
		var c: Clip = clips[k]
		var c_start: float = c.start
		var c_end: float = c_start + c.duration
		clip_starts[k] = c_start
		clip_ends[k] = c_end
		var col: Color
		if c.colour >= 0:
			var lc: Variant = label_cols.get(c.colour, null)
			if lc is Color:
				col = lc
			else:
				col = Tk.label_colour(c.colour).darkened(0.45)
				label_cols[c.colour] = col
		else:
			var mc: Variant = media_cols.get(c.media_id, null)
			col = mc if mc is Color else _colour_of(c, t, d, media_cols)
		var is_sel: bool = any_sel and selected.has(c.id)
		if not c.enabled or is_sel:
			col = _tint(col, c.enabled, is_sel, lane_bg, sol)
		if lines_on and not c.effects.is_empty():
			var vr: Dictionary = view_runs(d, c)
			if not vr.is_empty() and not (vr["cols"] as PackedColorArray).is_empty():
				split_any = true
				var vt0: PackedFloat64Array = vr["t0"]
				var vt1: PackedFloat64Array = vr["t1"]
				var vcols: PackedColorArray = vr["cols"]
				lines.append_array(ViewCuts.lines_of(c, ViewMap.cut_entry(c)))
				var at: float = c_start
				for q: int in vcols.size():
					if vt0[q] > at:
						_put(starts, ends, cols, w, at, vt0[q], col)
						w += 1
					_put(starts, ends, cols, w, vt0[q], vt1[q], _tint(vcols[q], c.enabled, is_sel, lane_bg, sol))
					w += 1
					at = vt1[q]
				if at < c_end:
					_put(starts, ends, cols, w, at, c_end, col)
					w += 1
				continue
		if w >= starts.size():
			_put(starts, ends, cols, w, c_start, c_end, col)
		else:
			starts[w] = c_start
			ends[w] = c_end
			cols[w] = col
		w += 1
	if w < starts.size():
		starts.resize(w)
		ends.resize(w)
		cols.resize(w)
	if not split_any:
		clip_starts = starts
		clip_ends = ends
	lines.sort()
	var out: Dictionary = {"sign": sign, "starts": starts, "ends": ends, "cols": cols, "lines": lines, "serial": d.serial, "clip_starts": clip_starts, "clip_ends": clip_ends}
	if _bases.size() >= CACHE_MAX:
		_bases.clear()
		_levels.clear()
	_bases[key] = out
	stats["base_builds"] = int(stats["base_builds"]) + 1
	stats["build_usec"] = int(stats["build_usec"]) + Time.get_ticks_usec() - t0
	return out


static func _new_level(base: Dictionary, level: int) -> Dictionary:
	return {"sign": base["sign"], "level": level, "w": pow(2.0, float(level)), "done": false, "phase": 0, "k": 0,
		"cur_s": -INF, "cur_e": -INF, "cur_c": Color(0, 0, 0, 0), "reach": -INF, "last_cut": -INF, "far_end": -INF, "cov_a": -INF, "cov_b": -INF, "cov_s": PackedFloat64Array(), "cov_e": PackedFloat64Array(),
		"run_s": PackedFloat64Array(), "run_e": PackedFloat64Array(), "cols": PackedColorArray(), "pts": PackedVector2Array(),
		"edges": PackedFloat64Array(), "cut_t": PackedFloat64Array(), "cut_pts": PackedVector2Array(),
		"wide_idx": PackedInt32Array(), "wide_s": PackedFloat64Array(), "wide_e": PackedFloat64Array(), "wide_reach": PackedFloat64Array()}


static func _emit_run(lvl: Dictionary) -> void:
	var cs: float = float(lvl["cur_s"])
	var ce: float = float(lvl["cur_e"])
	if ce <= cs:
		return
	var run_s: PackedFloat64Array = lvl["run_s"]
	var run_e: PackedFloat64Array = lvl["run_e"]
	var cols: PackedColorArray = lvl["cols"]
	var pts: PackedVector2Array = lvl["pts"]
	run_s.append(cs)
	run_e.append(ce)
	cols.append(lvl["cur_c"])
	pts.append(Vector2(cs, 0.0))
	pts.append(Vector2(ce, 0.0))
	lvl["run_s"] = run_s
	lvl["run_e"] = run_e
	lvl["cols"] = cols
	lvl["pts"] = pts


static func build_step(lvl: Dictionary, base: Dictionary, deadline_usec: int) -> bool:
	var t0: int = Time.get_ticks_usec()
	if deadline_usec > 0 and t0 >= deadline_usec:
		return false
	var w: float = float(lvl["w"])
	var starts: PackedFloat64Array = base["starts"]
	var ends: PackedFloat64Array = base["ends"]
	var cols: PackedColorArray = base["cols"]
	var n: int = starts.size()
	var k: int = int(lvl["k"])
	if int(lvl["phase"]) == 0:
		var run_s: PackedFloat64Array = lvl["run_s"]
		var run_e: PackedFloat64Array = lvl["run_e"]
		var run_c: PackedColorArray = lvl["cols"]
		var pts: PackedVector2Array = lvl["pts"]
		var edges: PackedFloat64Array = lvl["edges"]
		var cur_s: float = float(lvl["cur_s"])
		var cur_e: float = float(lvl["cur_e"])
		var cur_c: Color = lvl["cur_c"]
		var reach: float = float(lvl["reach"])
		var cov_s: PackedFloat64Array = lvl["cov_s"]
		var cov_e: PackedFloat64Array = lvl["cov_e"]
		var cov_a: float = float(lvl["cov_a"])
		var cov_b: float = float(lvl["cov_b"])
		var half: float = w * 0.5
		while k < n:
			if (k & 255) == 255 and deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
				break
			var s0: float = starts[k]
			var e0: float = ends[k]
			var col: Color = cols[k]
			k += 1
			if s0 <= reach + half:
				edges.append(s0)
			if e0 > reach:
				reach = e0
			var qs: float = floor(s0 / w) * w
			var qe: float = maxf(ceil(e0 / w) * w, qs + w)
			if qs <= cov_b:
				if qe > cov_b:
					cov_b = qe
			else:
				if cov_b > cov_a:
					cov_s.append(cov_a)
					cov_e.append(cov_b)
				cov_a = qs
				cov_b = qe
			if qs <= cur_e:
				if col == cur_c:
					if qe > cur_e:
						cur_e = qe
					continue
				if qe <= cur_e:
					continue
				qs = cur_e
			if cur_e > cur_s:
				run_s.append(cur_s)
				run_e.append(cur_e)
				run_c.append(cur_c)
				pts.append(Vector2(cur_s, 0.0))
				pts.append(Vector2(cur_e, 0.0))
			cur_s = qs
			cur_e = qe
			cur_c = col
		lvl["run_s"] = run_s
		lvl["run_e"] = run_e
		lvl["cols"] = run_c
		lvl["pts"] = pts
		lvl["edges"] = edges
		lvl["cur_s"] = cur_s
		lvl["cur_e"] = cur_e
		lvl["cur_c"] = cur_c
		lvl["reach"] = reach
		if k >= n and cov_b > cov_a:
			cov_s.append(cov_a)
			cov_e.append(cov_b)
			cov_a = INF
			cov_b = -INF
		lvl["cov_s"] = cov_s
		lvl["cov_e"] = cov_e
		lvl["cov_a"] = cov_a
		lvl["cov_b"] = cov_b
		lvl["k"] = k
		if k < n:
			_spent(t0)
			return false
		_emit_run(lvl)
		var all_edges: PackedFloat64Array = lvl["edges"]
		all_edges.append_array(base["lines"])
		all_edges.sort()
		lvl["edges"] = all_edges
		lvl["phase"] = 1
		lvl["k"] = 0
		k = 0
	if int(lvl["phase"]) == 1:
		var edges2: PackedFloat64Array = lvl["edges"]
		var cut_t: PackedFloat64Array = lvl["cut_t"]
		var cut_pts: PackedVector2Array = lvl["cut_pts"]
		var gap: float = w * CUT_SPACING_COLUMNS
		var last: float = float(lvl["last_cut"])
		var m: int = edges2.size()
		while k < m:
			if (k & 255) == 255 and deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
				break
			var e: float = edges2[k]
			k += 1
			if e - last < gap:
				continue
			last = e
			cut_t.append(e)
			cut_pts.append(Vector2(e, 0.0))
			cut_pts.append(Vector2(e, 1.0))
		lvl["cut_t"] = cut_t
		lvl["cut_pts"] = cut_pts
		lvl["last_cut"] = last
		lvl["k"] = k
		if k < m:
			_spent(t0)
			return false
		lvl["phase"] = 2
		lvl["k"] = 0
		k = 0
	if int(lvl["phase"]) == 2:
		starts = base["clip_starts"]
		ends = base["clip_ends"]
		n = starts.size()
		var wide_idx: PackedInt32Array = lvl["wide_idx"]
		var wide_s: PackedFloat64Array = lvl["wide_s"]
		var wide_e: PackedFloat64Array = lvl["wide_e"]
		var wide_reach: PackedFloat64Array = lvl["wide_reach"]
		var wide_min: float = SLIM_PX * w
		var far_end: float = float(lvl["far_end"])
		while k < n:
			if (k & 1023) == 1023 and deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
				break
			var k2: int = k
			k += 1
			if ends[k2] - starts[k2] >= wide_min:
				far_end = maxf(far_end, ends[k2])
				wide_idx.append(k2)
				wide_s.append(starts[k2])
				wide_e.append(ends[k2])
				wide_reach.append(far_end)
		lvl["wide_idx"] = wide_idx
		lvl["wide_s"] = wide_s
		lvl["wide_e"] = wide_e
		lvl["wide_reach"] = wide_reach
		lvl["far_end"] = far_end
		lvl["k"] = k
		if k < n:
			_spent(t0)
			return false
	lvl["done"] = true
	lvl["edges"] = PackedFloat64Array()
	stats["level_builds"] = int(stats["level_builds"]) + 1
	_spent(t0)
	return true


static func _spent(t0: int) -> void:
	stats["build_usec"] = int(stats["build_usec"]) + Time.get_ticks_usec() - t0


static func _deadline(canvas: Control) -> int:
	return Content.pot(canvas)


static func _tint(col: Color, enabled: bool, selected: bool, lane_bg: Color, sol: Color) -> Color:
	var out: Color = col
	if not enabled:
		out = out.lerp(lane_bg, DISABLED_MIX)
	if selected:
		out = out.lerp(sol, SELECTED_MIX)
	return out


static func _put(starts: PackedFloat64Array, ends: PackedFloat64Array, cols: PackedColorArray, at: int, a: float, b: float, col: Color) -> void:
	if at >= starts.size():
		starts.resize(at + 1)
		ends.resize(at + 1)
		cols.resize(at + 1)
	starts[at] = a
	ends[at] = b
	cols[at] = col


static func level_of(canvas: Control, t: Track, base: Dictionary, level: int) -> Dictionary:
	var prefix: String = str(canvas.get_instance_id()) + "|" + t.id + "|"
	var key: String = prefix + str(level)
	var sign: String = String(base["sign"])
	var hit: Variant = _levels.get(key, null)
	var lvl: Dictionary = hit if hit is Dictionary and String((hit as Dictionary)["sign"]) == sign else {}
	if not lvl.is_empty() and bool(lvl["done"]):
		return lvl
	if lvl.is_empty():
		if _levels.size() >= LEVELS_MAX:
			_levels.clear()
		lvl = _new_level(base, level)
		_levels[key] = lvl
	var best: Dictionary = {}
	var best_gap: int = 1 << 30
	for step: int in range(1, LEVEL_REACH + 1):
		for other: int in [level - step, level + step]:
			var o: Variant = _levels.get(prefix + str(other), null)
			if o is Dictionary and bool((o as Dictionary)["done"]) and String((o as Dictionary)["sign"]) == sign and step < best_gap:
				best = o
				best_gap = step
		if not best.is_empty():
			break
	if best.is_empty():
		build_step(lvl, base, 0)
		return lvl
	if not build_step(lvl, base, _deadline(canvas)):
		stats["building"] = int(stats.get("building", 0)) + 1
		canvas.queue_redraw()
		return best
	return lvl


static func visible_runs(lvl: Dictionary, t_lo: float, t_hi: float) -> Vector2i:
	var run_s: PackedFloat64Array = lvl["run_s"]
	var run_e: PackedFloat64Array = lvl["run_e"]
	var a: int = run_e.bsearch(t_lo, false)
	var b: int = run_s.bsearch(t_hi, true)
	return Vector2i(a, maxi(a, b))


static func visible_cuts(lvl: Dictionary, t_lo: float, t_hi: float) -> Vector2i:
	var cut_t: PackedFloat64Array = lvl["cut_t"]
	var a: int = cut_t.bsearch(t_lo, true)
	var b: int = cut_t.bsearch(t_hi, false)
	return Vector2i(a, maxi(a, b))


static func draw_dense(canvas: Control, t: Track, lane_y: float, lane_h: float) -> PackedInt32Array:
	var wide: PackedInt32Array = PackedInt32Array()
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return wide
	_tick(canvas)
	var pps: float = float(canvas.get("pps"))
	var hw: float = float(canvas.get("header_w"))
	var scroll_x: float = float(canvas.get("scroll_x"))
	var base: Dictionary = base_of(canvas, d, s, t)
	var lvl: Dictionary = level_of(canvas, t, base, level_for(pps))
	var t_lo: float = float(canvas.call("t_of", hw))
	var t_hi: float = float(canvas.call("t_of", canvas.size.x))
	var rv: Vector2i = visible_runs(lvl, t_lo, t_hi)
	var body_h: float = maxf(lane_h - 2.0, 1.0)
	var origin_x: float = hw - scroll_x
	stats["dense_lanes"] = int(stats["dense_lanes"]) + 1
	if rv.y > rv.x:
		var pts: PackedVector2Array = (lvl["pts"] as PackedVector2Array).slice(rv.x * 2, rv.y * 2)
		var cols: PackedColorArray = (lvl["cols"] as PackedColorArray).slice(rv.x, rv.y)
		stats["runs"] = int(stats["runs"]) + cols.size()
		canvas.draw_set_transform(Vector2(origin_x, lane_y + lane_h * 0.5), 0.0, Vector2(pps, 1.0))
		canvas.draw_multiline_colors(pts, cols, body_h)
		var edge: Color = Color(Tk.c["border_soft"], EDGE_ALPHA)
		canvas.draw_set_transform(Vector2(origin_x, lane_y + 1.5), 0.0, Vector2(pps, 1.0))
		canvas.draw_multiline(pts, edge, 1.0)
		canvas.draw_set_transform(Vector2(origin_x, lane_y + lane_h - 1.5), 0.0, Vector2(pps, 1.0))
		canvas.draw_multiline(pts, edge, 1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var content_t0: int = Time.get_ticks_usec()
	if t.makes_picture():
		Content.draw_lane_frames(canvas, t, base, lvl["cov_s"], lvl["cov_e"], lane_y, lane_h, t_lo, t_hi)
	elif t.makes_sound():
		Content.draw_lane_waves(canvas, t, base, level_for(pps), lane_y, lane_h, t_lo, t_hi)
	stats["content_usec"] = int(stats.get("content_usec", 0)) + Time.get_ticks_usec() - content_t0
	var cv: Vector2i = visible_cuts(lvl, t_lo, t_hi)
	if cv.y > cv.x:
		var cpts: PackedVector2Array = (lvl["cut_pts"] as PackedVector2Array).slice(cv.x * 2, cv.y * 2)
		stats["cuts"] = int(stats["cuts"]) + cpts.size() / 2
		canvas.draw_set_transform(Vector2(origin_x, lane_y + 1.0), 0.0, Vector2(pps, body_h))
		canvas.draw_multiline(cpts, cut_colour(), -1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var wide_idx: PackedInt32Array = lvl["wide_idx"]
	if wide_idx.is_empty():
		return wide
	var wide_s: PackedFloat64Array = lvl["wide_s"]
	var wide_e: PackedFloat64Array = lvl["wide_e"]
	var wide_reach: PackedFloat64Array = lvl["wide_reach"]
	var a: int = wide_reach.bsearch(t_lo, false)
	var b: int = wide_s.bsearch(t_hi, true)
	var min_len: float = SLIM_PX / maxf(pps, 0.0000001)
	for k: int in range(a, b):
		if wide_e[k] - wide_s[k] >= min_len and wide_e[k] > t_lo:
			wide.append(wide_idx[k])
	stats["wide"] = int(stats.get("wide", 0)) + wide.size()
	return wide


static func cut_colour() -> Color:
	return Color(Tk.c["text_faint"], 0.9)
