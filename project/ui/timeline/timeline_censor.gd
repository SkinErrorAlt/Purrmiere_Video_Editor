extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Censor := preload("res://doc/censor.gd")
const CensorCmds := preload("res://doc/commands/censor_cmds.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://ui/timeline/timeline_censor.gd"
const BAR_PATH := "res://modules/core_panels/censor_bar.gd"
const DRAG_MODE := "censor"
const META_SEL := "censor_selected"
const META_HOT := "censor_hot"
const EDGE_REACH := 5.0
const SNAP_PX := 8.0
const TAG_H := 13.0
const TAG_PAD := 5.0
const MARK_W := 9.0
const TAG_MIN_W := 18.0
const FILL := 0.24
const FILL_DUCK := 0.15
const FILL_SEL := 0.38
const FILL_PREVIEW := 0.14
const GRIP_W := 4.0
const GRIP_H := 14.0
const DASH := 4.0

static var regions_drawn: int = 0
static var previews_drawn: int = 0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func band_colour() -> Color:
	return Color.from_hsv(0.0, 0.55, 0.64 if Tk.is_light() else 0.78)


static func tool_on() -> bool:
	return Session.tool_id == Censor.TOOL_ID


static func name_h(lane_h: float) -> float:
	return Paint.name_row_h() if lane_h >= 34.0 else 0.0


static func selected(canvas: Control) -> Dictionary:
	if canvas == null or not canvas.has_meta(META_SEL):
		return {}
	var v: Variant = canvas.get_meta(META_SEL)
	return v if v is Dictionary else {}


static func select(canvas: Control, clip_id: String, region_id: String) -> void:
	var s: Sequence = canvas.call("seq")
	var snap: PackedStringArray = s.selected_clip_ids.duplicate() if s != null else PackedStringArray()
	canvas.set_meta(META_SEL, {"clip": clip_id, "region": region_id, "clips": snap})
	canvas.queue_redraw()


static func clear_selection(canvas: Control) -> void:
	if canvas != null and canvas.has_meta(META_SEL):
		canvas.remove_meta(META_SEL)
		canvas.queue_redraw()


static func valid_selection(canvas: Control) -> Dictionary:
	var sel: Dictionary = selected(canvas)
	if sel.is_empty():
		return {}
	var s: Sequence = canvas.call("seq")
	if s == null:
		return {}
	var c: Clip = s.clip_by_id(String(sel.get("clip", "")))
	if c == null or Censor.region_by_id(c, String(sel.get("region", ""))).is_empty() or s.selected_clip_ids != (sel.get("clips", PackedStringArray()) as PackedStringArray):
		return {}
	return sel


static func live_selection(canvas: Control) -> Dictionary:
	var sel: Dictionary = valid_selection(canvas)
	if sel.is_empty():
		clear_selection(canvas)
	return sel


static func tag_rect(canvas: Control, doc: Project, r: Dictionary, x0: float, x1: float, top: float, clip_x0: float, clip_x1: float) -> Rect2:
	var vx0: float = maxf(x0, clip_x0)
	var vx1: float = minf(x1, clip_x1)
	var room: float = vx1 - vx0
	if room < TAG_MIN_W:
		return Rect2()
	var font: Font = canvas.get("_font")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var text: String = Censor.tag_text(doc, r)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 40.0
	return Rect2(vx0, top, minf(tw + TAG_PAD * 2.0 + MARK_W, room), float(Tk.px(TAG_H)))


static func hit(canvas: Control, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if s == null:
		return {}
	var h: Dictionary = canvas.call("hit_at", pos)
	if String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)):
		return {}
	var tr: Track = h.get("track", null)
	var l: Dictionary = h.get("lane", {})
	if tr == null or l.is_empty():
		return {}
	var geom: Dictionary = canvas.call("geometry")
	var lane_y: float = Hit.lane_screen_y(geom, l)
	var lane_h: float = float(l["h"])
	var top: float = lane_y + name_h(lane_h)
	if pos.y < top or pos.y > lane_y + lane_h:
		return {}
	var area: Rect2 = geom["main_rect"] if String(h.get("set", "main")) == "main" else geom["band_rect"]
	var tag_top: float = top if top >= area.position.y else INF
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var pps: float = float(geom["pps"])
	var t: float = float(h.get("t", 0.0))
	var reach_t: float = EDGE_REACH / maxf(pps, 0.000001)
	var sel: Dictionary = selected(canvas)
	var best: Dictionary = {}
	for c: Clip in tr.clips_in_range(t - reach_t, t + reach_t):
		if not Censor.has_regions(c):
			continue
		var cx0: float = maxf(Hit.x_of(geom, c.start), header_w)
		var cx1: float = minf(Hit.x_of(geom, c.end()), width)
		for r: Dictionary in Censor.regions(c):
			var sp: Vector2 = Censor.span(c, r)
			if sp.y - sp.x <= Censor.TOUCH:
				continue
			var x0: float = Hit.x_of(geom, sp.x)
			var x1: float = Hit.x_of(geom, sp.y)
			if pos.x < x0 - EDGE_REACH or pos.x > x1 + EDGE_REACH:
				continue
			var d0: float = absf(pos.x - x0)
			var d1: float = absf(pos.x - x1)
			var edge: String = ""
			if minf(d0, d1) <= EDGE_REACH:
				edge = "from" if d0 <= d1 else "to"
				var ex: float = x0 if edge == "from" else x1
				if not tool_on() and (absf(ex - Hit.x_of(geom, c.start)) <= Hit.EDGE_REACH + 1.0 or absf(ex - Hit.x_of(geom, c.end())) <= Hit.EDGE_REACH + 1.0):
					edge = ""
			if edge.is_empty() and (pos.x < x0 or pos.x > x1):
				continue
			var tag: Rect2 = tag_rect(canvas, d, r, x0, x1, tag_top, cx0, cx1) if tag_top < INF else Rect2()
			var cand: Dictionary = {"clip": c, "track": tr, "region": r, "span": sp, "edge": edge, "tag": tag.has_point(pos), "lane": l}
			var is_sel: bool = String(sel.get("clip", "")) == c.id and String(sel.get("region", "")) == String(r.get("id", ""))
			if is_sel:
				return cand
			if best.is_empty() or (not edge.is_empty() and String(best.get("edge", "")).is_empty()):
				best = cand
	return best


static func hot_of(canvas: Control, pos: Vector2) -> String:
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty():
		return ""
	if not String(hr["edge"]).is_empty():
		return "edge"
	if bool(hr["tag"]):
		return "tag"
	return "band" if tool_on() else ""


static func hover(canvas: Control, pos: Vector2) -> void:
	if canvas == null:
		return
	var hot: String = ""
	var s: Sequence = canvas.call("seq")
	if s != null and (tool_on() or any_regions(canvas)):
		hot = hot_of(canvas, pos)
	if hot != String(canvas.get_meta(META_HOT, "")):
		canvas.set_meta(META_HOT, hot)
		canvas.call("_update_cursor")


static func any_regions(canvas: Control) -> bool:
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if s == null:
		return false
	var key: String = s.id + "|" + str(d.serial if d != null else 0)
	if String(canvas.get_meta("censor_any_key", "")) == key:
		return bool(canvas.get_meta("censor_any", false))
	var found: bool = false
	for tr: Track in s.all_tracks():
		for c: Clip in tr.clips:
			if Censor.has_regions(c):
				found = true
				break
		if found:
			break
	canvas.set_meta("censor_any_key", key)
	canvas.set_meta("censor_any", found)
	return found


static func claims_cursor(canvas: Control, tool: String, h: Dictionary) -> bool:
	var hot: String = String(canvas.get_meta(META_HOT, ""))
	if hot == "edge" or hot == "tag":
		return true
	return tool == Censor.TOOL_ID and String(h.get("zone", "")) == "lane"


static func cursor_shape(canvas: Control, _tool: String, _h: Dictionary) -> Control.CursorShape:
	var hot: String = String(canvas.get_meta(META_HOT, ""))
	if hot == "edge":
		return Control.CURSOR_HSIZE
	if hot == "tag":
		return Control.CURSOR_POINTING_HAND
	return Control.CURSOR_IBEAM


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return false
	var on: bool = tool_on()
	var hr: Dictionary = hit(canvas, pos)
	var drag: RefCounted = canvas.get("drag")
	if not hr.is_empty() and (on or not String(hr["edge"]).is_empty() or bool(hr["tag"])):
		var c: Clip = hr["clip"]
		var r: Dictionary = hr["region"]
		var rid: String = String(r.get("id", ""))
		select(canvas, c.id, rid)
		var sp: Vector2 = hr["span"]
		if not String(hr["edge"]).is_empty() and CensorCmds.editable(d, s, c):
			drag.call("begin", DRAG_MODE, canvas.call("hit_at", pos), pos, mods)
			var origin: Dictionary = drag.get("origin")
			origin["censor"] = {"kind": "edge", "clip": c.id, "region": rid, "side": String(hr["edge"]), "a": sp.x, "b": sp.y, "a0": sp.x, "b0": sp.y, "lo": c.start, "hi": c.end(), "guides": []}
		elif on:
			_begin_new(canvas, drag, pos, mods)
		return true
	if not on:
		if not selected(canvas).is_empty():
			clear_selection(canvas)
		return false
	clear_selection(canvas)
	_begin_new(canvas, drag, pos, mods)
	return true


static func _begin_new(canvas: Control, drag: RefCounted, pos: Vector2, mods: Dictionary) -> void:
	var h: Dictionary = canvas.call("hit_at", pos)
	var tr: Track = h.get("track", null)
	var c: Clip = h.get("clip", null)
	drag.call("begin", DRAG_MODE, h, pos, mods)
	var origin: Dictionary = drag.get("origin")
	origin["censor"] = {"kind": "new", "t_press": maxf(float(h.get("t", 0.0)), 0.0), "track": tr.id if tr != null else "", "set": String(h.get("set", "main")), "clip": c.id if c != null else "", "last_track": tr.id if tr != null else "", "a": 0.0, "b": 0.0, "preview": [], "guides": []}


static func _tracks_between(canvas: Control, set_name: String, from_id: String, to_id: String) -> Array[Track]:
	var out: Array[Track] = []
	var ln: Dictionary = canvas.call("lanes")
	var list: Array = ln.get(set_name, [])
	var i0: int = -1
	var i1: int = -1
	for i: int in list.size():
		var l: Dictionary = list[i]
		if bool(l["nest"]):
			continue
		var t: Track = l["track"]
		if t.id == from_id:
			i0 = i
		if t.id == to_id:
			i1 = i
	if i0 < 0:
		return out
	if i1 < 0:
		i1 = i0
	for i: int in range(mini(i0, i1), maxi(i0, i1) + 1):
		var l2: Dictionary = list[i]
		if not bool(l2["nest"]):
			out.append(l2["track"])
	return out


static func peaks_reader(canvas: Control, c: Clip) -> Callable:
	var d: Project = canvas.call("doc")
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m == null:
		return Callable()
	var handle: int = int(canvas.call("_handle_of", m))
	var stream: int = int(c.audio.get("stream", 0.0))
	var render: String = str(c.audio.get("render", ""))
	if not render.is_empty() and not (canvas.get("peaks_provider") as Callable).is_valid():
		var rh: int = Session.render_handle(render)
		if rh >= 0:
			handle = rh
			stream = 0
	return func(first: int, count: int) -> PackedByteArray: return canvas.call("_peaks", handle, stream, 0, first, count)


static func snap_time(canvas: Control, drag: RefCounted, c: Clip, t: float, side: String, guides: Array) -> float:
	if not bool(canvas.get("snapping")):
		return t
	var timeline: bool = Censor.snaps_timeline()
	var sound: bool = Censor.snaps_sound()
	var grid: float = t
	if timeline and drag != null:
		grid = float(drag.call("snap", t))
		var hit: bool = float(drag.get("snap_x")) > -INF
		drag.set("snap_x", -INF)
		if hit:
			guides.append(grid)
			return grid
	if sound:
		var src: Clip = sound_clip(canvas, c, t)
		if src != null:
			var q: float = Censor.quiet_snap(peaks_reader(canvas, src), src, t, side)
			if absf(q - t) > 0.0000001:
				guides.append(q)
				return q
	return grid


static func sound_clip(canvas: Control, c: Clip, t: float) -> Clip:
	var from: String = Censor.snap_from()
	if from == Censor.SNAP_FROM_CLIP:
		return c
	var s: Sequence = canvas.call("seq")
	var tr: Track = Censor.snap_track(s, from)
	if tr == null:
		return null
	for hit: Clip in tr.clips_at(t):
		if tr.is_sound(hit):
			return hit
	return null


static func drag_motion(canvas: Control, drag: RefCounted, pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var st: Dictionary = origin.get("censor", {})
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if st.is_empty() or d == null or s == null:
		return false
	var t: float = maxf(float(canvas.call("t_of", pos.x)), 0.0)
	var guides: Array = []
	if String(st["kind"]) == "edge":
		var c: Clip = s.clip_by_id(String(st["clip"]))
		if c == null:
			return false
		var side: String = String(st["side"])
		var want: float = snap_time(canvas, drag, c, clampf(t, float(st["lo"]), float(st["hi"])), side, guides)
		if side == "from":
			st["a"] = clampf(want, float(st["lo"]), float(st["b0"]) - Censor.MIN_SPAN)
			st["b"] = float(st["b0"])
		else:
			st["b"] = clampf(want, float(st["a0"]) + Censor.MIN_SPAN, float(st["hi"]))
			st["a"] = float(st["a0"])
		st["guides"] = guides
		origin["censor"] = st
		return true
	var h: Dictionary = canvas.call("hit_at", pos)
	var here: Track = h.get("track", null)
	if here != null and String(h.get("set", "")) == String(st["set"]):
		st["last_track"] = here.id
	var tracks: Array[Track] = _tracks_between(canvas, String(st["set"]), String(st["track"]), String(st["last_track"]))
	var lo: float = minf(float(st["t_press"]), t)
	var hi: float = maxf(float(st["t_press"]), t)
	var raw: Array[Dictionary] = CensorCmds.spans_under(d, s, tracks, lo, hi)
	var ref: Clip = s.clip_by_id(String(st["clip"]))
	if ref == null or not Censor.takes_censor(d, ref):
		ref = s.clip_by_id(String(raw[0]["clip_id"])) if not raw.is_empty() else null
	var a: float = snap_time(canvas, drag, ref, lo, "from", guides)
	var b: float = snap_time(canvas, drag, ref, hi, "to", guides)
	if b - a < Censor.MIN_SPAN:
		a = lo
		b = hi
		guides.clear()
	st["a"] = a
	st["b"] = b
	st["guides"] = guides
	st["preview"] = CensorCmds.spans_under(d, s, tracks, a, b)
	origin["censor"] = st
	return true


static func drag_release(canvas: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var origin: Dictionary = drag.get("origin")
	var st: Dictionary = origin.get("censor", {})
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if st.is_empty() or d == null or s == null:
		return false
	if String(st["kind"]) == "edge":
		var a: float = float(st["a"])
		var b: float = float(st["b"])
		if absf(a - float(st["a0"])) < 0.00001 and absf(b - float(st["b0"])) < 0.00001:
			return false
		var ok: bool = CensorCmds.resize(d, s, String(st["clip"]), String(st["region"]), a, b)
		if ok:
			select(canvas, String(st["clip"]), String(st["region"]))
		return ok
	var spans: Array[Dictionary] = []
	for p: Variant in st.get("preview", []):
		spans.append(p)
	if spans.is_empty():
		return false
	var made: Array[Dictionary] = CensorCmds.add(d, s, spans)
	if made.is_empty():
		Events.toast("Nothing to censor there: drag across a sound clip on an unlocked track")
		return false
	select(canvas, String(made[0]["clip_id"]), String(made[0]["region_id"]))
	return true


static func drag_state(canvas: Control) -> Dictionary:
	var drag: RefCounted = canvas.get("drag")
	if drag == null or String(drag.get("mode")) != DRAG_MODE or not bool(drag.get("active")):
		return {}
	return (drag.get("origin") as Dictionary).get("censor", {})


static func draw(canvas: Control) -> void:
	regions_drawn = 0
	previews_drawn = 0
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if s == null:
		return
	var st: Dictionary = drag_state(canvas)
	if st.is_empty() and not any_regions(canvas):
		return
	var geom: Dictionary = canvas.call("geometry")
	var ln: Dictionary = canvas.call("lanes")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var t0: float = Hit.t_of(geom, header_w)
	var t1: float = Hit.t_of(geom, width)
	var sel: Dictionary = valid_selection(canvas)
	var red: Color = band_colour()
	var editing: String = String(st.get("clip", "")) + "|" + String(st.get("region", "")) if String(st.get("kind", "")) == "edge" else ""
	var preview: Dictionary = {}
	if String(st.get("kind", "")) == "new":
		for p: Variant in st.get("preview", []):
			preview[String((p as Dictionary)["clip_id"])] = p
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
			var top: float = y + name_h(h)
			var cy0: float = maxf(top, area.position.y)
			var cy1: float = minf(y + h - 1.0, area.end.y)
			if cy1 - cy0 < 2.0:
				continue
			for c: Clip in tr.clips_in_range(t0, t1):
				var cx0: float = maxf(Hit.x_of(geom, c.start), header_w)
				var cx1: float = minf(Hit.x_of(geom, c.end()), width)
				if cx1 <= cx0:
					continue
				for r: Dictionary in Censor.regions(c):
					var sp: Vector2 = Censor.span(c, r)
					var key: String = c.id + "|" + String(r.get("id", ""))
					if key == editing:
						sp = Vector2(float(st["a"]), float(st["b"]))
					if sp.y - sp.x <= Censor.TOUCH:
						continue
					var is_sel: bool = String(sel.get("clip", "")) == c.id and String(sel.get("region", "")) == String(r.get("id", ""))
					_band(canvas, d, r, Hit.x_of(geom, sp.x), Hit.x_of(geom, sp.y), Rect2(cx0, cy0, cx1 - cx0, cy1 - cy0), top, red, is_sel, float(geom["pps"]))
					regions_drawn += 1
				if preview.has(c.id):
					var pv: Dictionary = preview[c.id]
					_preview(canvas, Hit.x_of(geom, float(pv["t0"])), Hit.x_of(geom, float(pv["t1"])), Rect2(cx0, cy0, cx1 - cx0, cy1 - cy0), red)
					previews_drawn += 1
	var main_rect: Rect2 = geom["main_rect"]
	for g: Variant in st.get("guides", []):
		var gx: float = Hit.x_of(geom, float(g))
		if gx >= header_w and gx <= width:
			canvas.draw_line(Vector2(gx, main_rect.position.y), Vector2(gx, main_rect.end.y), Color(Tk.c["text_bright"], 0.7), 1.0)


static func _band(canvas: Control, d: Project, r: Dictionary, x0: float, x1: float, clip_rect: Rect2, top: float, red: Color, is_sel: bool, pps: float) -> void:
	var vx0: float = maxf(x0, clip_rect.position.x)
	var vx1: float = minf(x1, clip_rect.end.x)
	var y0: float = clip_rect.position.y
	var y1: float = clip_rect.end.y
	if vx1 < vx0:
		return
	var cut: String = String(r.get("cut", "mute"))
	var alpha: float = FILL_SEL if is_sel else (FILL_DUCK if cut == "duck" else FILL)
	var fade_px: float = 0.0
	if cut == "fade":
		fade_px = minf(float(r.get("fade_ms", 60.0)) / 1000.0 * pps, (x1 - x0) * 0.5)
	if fade_px >= 2.0 and vx0 == x0 and vx1 == x1 and absf(top - y0) < 0.5:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0, y1), Vector2(x0 + fade_px, y0), Vector2(x1 - fade_px, y0), Vector2(x1, y1)]), Color(red, alpha))
	elif vx1 - vx0 >= 1.0:
		canvas.draw_rect(Rect2(vx0, y0, vx1 - vx0, y1 - y0), Color(red, alpha), true)
	var edge_w: float = 2.0 if is_sel else 1.0
	if x0 >= clip_rect.position.x and x0 <= clip_rect.end.x:
		canvas.draw_rect(Rect2(x0, y0, edge_w, y1 - y0), red, true)
	if x1 >= clip_rect.position.x and x1 <= clip_rect.end.x:
		canvas.draw_rect(Rect2(x1 - edge_w, y0, edge_w, y1 - y0), red, true)
	if is_sel and vx1 - vx0 >= 2.0:
		canvas.draw_rect(Rect2(vx0 + 0.5, y0 + 0.5, vx1 - vx0 - 1.0, y1 - y0 - 1.0), Color(Tk.c["text_bright"], 0.55), false, 1.0)
		var gy: float = (y0 + y1) * 0.5 - GRIP_H * 0.5
		for gx: float in [x0, x1]:
			if gx >= clip_rect.position.x - 1.0 and gx <= clip_rect.end.x + 1.0 and y1 - y0 >= GRIP_H + 2.0:
				Paint.rounded(canvas, Rect2(gx - GRIP_W * 0.5, gy, GRIP_W, GRIP_H), Tk.c["text_bright"], 2.0, Tk.c["bg_app"], 1)
	if absf(top - y0) >= 0.5:
		return
	var tag: Rect2 = tag_rect(canvas, d, r, x0, x1, top, clip_rect.position.x, clip_rect.end.x)
	if tag.size.x <= 0.0 or tag.end.y > y1:
		return
	canvas.draw_rect(tag, red, true)
	var ink: Color = Tk.c["inv"]
	var my: float = tag.position.y + tag.size.y * 0.5
	var mx: float = tag.position.x + 3.0
	canvas.draw_polyline(PackedVector2Array([Vector2(mx, my), Vector2(mx + 1.5, my - 3.0), Vector2(mx + 3.0, my + 3.0), Vector2(mx + 4.5, my - 3.0), Vector2(mx + 6.0, my)]), ink, 1.0, true)
	var font: Font = canvas.get("_font")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var room: float = tag.size.x - MARK_W - 1.0 - PmText.chip_pad()
	if font == null or room < 8.0:
		return
	PmText.draw_in(canvas, font, Rect2(tag.position.x + MARK_W + 1.0, tag.position.y, room, tag.size.y), Censor.tag_text(d, r), fs, ink, HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, tag, PmText.chip_pad())


static func elide(font: Font, text: String, fs: int, room: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
		return text
	var out: String = text
	while out.length() > 1 and font.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		out = out.left(out.length() - 1)
	return out + "…"


static func _preview(canvas: Control, x0: float, x1: float, clip_rect: Rect2, red: Color) -> void:
	var vx0: float = maxf(x0, clip_rect.position.x)
	var vx1: float = minf(x1, clip_rect.end.x)
	if vx1 - vx0 < 1.0:
		return
	var y0: float = clip_rect.position.y
	var y1: float = clip_rect.end.y
	canvas.draw_rect(Rect2(vx0, y0, vx1 - vx0, y1 - y0), Color(red, FILL_PREVIEW), true)
	canvas.draw_dashed_line(Vector2(vx0, y0 + 0.5), Vector2(vx1, y0 + 0.5), red, 1.0, DASH)
	canvas.draw_dashed_line(Vector2(vx0, y1 - 0.5), Vector2(vx1, y1 - 0.5), red, 1.0, DASH)
	canvas.draw_dashed_line(Vector2(vx0 + 0.5, y0), Vector2(vx0 + 0.5, y1), red, 1.0, DASH)
	canvas.draw_dashed_line(Vector2(vx1 - 0.5, y0), Vector2(vx1 - 0.5, y1), red, 1.0, DASH)


static func menu_items(d: Project, r: Dictionary) -> Array:
	var sound: String = String(r.get("sound", "bleep"))
	var sounds: Array = []
	for k: String in Censor.BUILT_IN:
		sounds.append(PmMenu.check_item("sound:" + k, String(Censor.SOUNDS[k]["label"]), sound == k))
	var bin: Array = []
	if d != null:
		for m: MediaItem in d.media:
			if m.kind == "audio":
				bin.append(PmMenu.check_item("sound:media:" + m.id, m.label, sound == "media:" + m.id))
	if not bin.is_empty():
		sounds.append(PmMenu.separator())
		sounds.append_array(bin)
	if sound.begins_with("file:"):
		sounds.append(PmMenu.separator())
		sounds.append(PmMenu.check_item("sound:" + sound, sound.substr(5).get_file(), true))
	sounds.append(PmMenu.separator())
	sounds.append(PmMenu.item("choose", "Choose a file"))
	var cuts: Array = []
	for k2: String in Censor.CUTS:
		cuts.append(PmMenu.check_item("cut:" + k2, String(Censor.CUT_LABELS[k2]), String(r.get("cut", "mute")) == k2))
	var fits: Array = []
	for k3: String in Censor.FITS:
		fits.append(PmMenu.check_item("fit:" + k3, String(Censor.FIT_LABELS[k3]), String(r.get("fit", "cut")) == k3))
	return [
		PmMenu.item("settings", "Censor settings"),
		PmMenu.sub_item("sound", "Sound", sounds),
		PmMenu.sub_item("cut", "Cut", cuts),
		PmMenu.sub_item("fit", "Fit", fits),
		PmMenu.item("defaults", "Use these settings for new censors"),
		PmMenu.separator(),
		PmMenu.item("delete", "Delete", Cmd.keys_text("edit.delete"), "trash"),
	]


static func right(canvas: Control, pos: Vector2) -> bool:
	var hr: Dictionary = hit(canvas, pos)
	if hr.is_empty():
		return false
	var d: Project = canvas.call("doc")
	var c: Clip = hr["clip"]
	var r: Dictionary = hr["region"]
	var rid: String = String(r.get("id", ""))
	select(canvas, c.id, rid)
	var m: Control = PmMenu.open(canvas, menu_items(d, r), canvas.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(_script(), "on_menu").bind(canvas, c.id, rid))
	return true


static func on_menu(id: String, canvas: Control, clip_id: String, region_id: String) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	apply(canvas, canvas.call("doc"), canvas.call("seq"), clip_id, region_id, id)


static func apply(host: Control, d: Project, s: Sequence, clip_id: String, region_id: String, id: String) -> bool:
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	var r: Dictionary = Censor.region_by_id(c, region_id)
	if r.is_empty():
		return false
	if id == "delete":
		var gone: bool = CensorCmds.remove(d, s, clip_id, region_id)
		if gone and host != null:
			clear_selection(host)
		return gone
	if id == "settings":
		if host != null:
			load(BAR_PATH).call("open_sheet", host, d, s, clip_id, region_id)
		return true
	if id == "choose":
		if host != null:
			load(BAR_PATH).call("choose_file", host, Callable(_script(), "on_file_chosen").bind(host, clip_id, region_id))
		return true
	if id == "defaults":
		load(BAR_PATH).call("use_as_defaults", d, Censor.settings_of(r))
		Events.toast("New censors use these settings now")
		return true
	var settings: Dictionary = Censor.settings_of(r)
	if id.begins_with("sound:"):
		settings["sound"] = id.substr(6)
	elif id.begins_with("cut:"):
		settings["cut"] = id.substr(4)
	elif id.begins_with("fit:"):
		settings["fit"] = id.substr(4)
	else:
		return false
	return CensorCmds.restyle(d, s, clip_id, region_id, settings)


static func on_file_chosen(path: String, host: Control, clip_id: String, region_id: String) -> void:
	if host == null or not is_instance_valid(host) or path.is_empty():
		return
	var d: Project = host.call("doc")
	var s: Sequence = host.call("seq")
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var r: Dictionary = Censor.region_by_id(c, region_id)
	if r.is_empty():
		return
	var settings: Dictionary = Censor.settings_of(r)
	settings["sound"] = Censor.custom_sound(d, path)
	CensorCmds.restyle(d, s, clip_id, region_id, settings)


static func delete_selected(canvas: Control) -> bool:
	if canvas == null or not is_instance_valid(canvas):
		return false
	var sel: Dictionary = live_selection(canvas)
	if sel.is_empty():
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var gone: bool = CensorCmds.remove(d, s, String(sel["clip"]), String(sel["region"]))
	clear_selection(canvas)
	return gone
