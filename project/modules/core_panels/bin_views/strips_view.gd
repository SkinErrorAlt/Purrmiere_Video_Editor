extends "res://modules/core_panels/bin_views/bin_view.gd"

const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const ROW_DEFAULT := 64.0
const ROW_MIN := 44.0
const ROW_MAX := 132.0
const WAVE_BAND := 10.0
const USED_H := 3.0
const SLOP := 4.0
const AUDIO_OWNER := "bin_scrub"
const PEAK_TIER := 2
const MAX_CELLS := 60
const GROW_SECONDS := 0.25
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")

var hover_t: float = -1.0
var hover_row: int = -1
var drag: Dictionary = {}
var _wave_cache: Dictionary = {}
var _heard_id: String = ""
var _last_scrub_ms: int = 0
var _last_scrub_t: float = -1.0
var _waves_waiting: bool = false
var _wave_poll_ms: int = 0


func id() -> String:
	return "strips"


func title() -> String:
	return "Strips"


func glyph() -> String:
	return "strips"


func setup(panel_: RefCounted, body_: Control) -> void:
	super(panel_, body_)
	if PurrBridge.has_signal("strip_ready") and not PurrBridge.strip_ready.is_connected(_on_strip_ready):
		PurrBridge.strip_ready.connect(_on_strip_ready)
	if PurrBridge.has_signal("peaks_progress") and not PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.connect(_on_peaks_progress)


func _on_strip_ready(_h: int) -> void:
	redraw()


var _grow_armed: bool = false
var wave_refreshes: int = 0


func _on_peaks_progress(_h: int, _stream: int) -> void:
	if _grow_armed or body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	_grow_armed = true
	body.get_tree().create_timer(GROW_SECONDS).timeout.connect(_grow_redraw)


func _grow_redraw() -> void:
	_grow_armed = false
	var stale: Array = []
	for k: Variant in _wave_cache.keys():
		if not bool((_wave_cache[k] as Dictionary)["done"]):
			stale.append(k)
	if stale.is_empty():
		return
	for k2: Variant in stale:
		_wave_cache.erase(k2)
	wave_refreshes += 1
	redraw()


func row_h() -> float:
	return px(float(state("strips", "row", ROW_DEFAULT)))


func side_w() -> float:
	return clampf(body.size.x * 0.28, px(112.0), px(180.0))


func sound_on() -> bool:
	return bool(state("strips", "sound", true))


func layout(width: float, _height: float) -> Vector2:
	var rs: Array[Rect2] = rects()
	var n: int = entries().size()
	rs.resize(n)
	var rh: float = row_h()
	for i: int in n:
		rs[i] = Rect2(0.0, float(i) * rh, width, rh)
	return Vector2(width, float(n) * rh)


func zoom(steps: float, _at: Vector2) -> bool:
	var cur: float = float(state("strips", "row", ROW_DEFAULT))
	var next: float = clampf(cur + 8.0 * signf(steps), ROW_MIN, ROW_MAX)
	if next != cur:
		set_state("strips", "row", next)
		_wave_cache.clear()
		relayout()
	return true


func strip_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	var sw: float = side_w()
	var pad: float = px(5.0)
	return Rect2(r.position.x + sw, r.position.y + pad, maxf(r.size.x - sw - px(6.0), 0.0), maxf(r.size.y - pad * 2.0, 1.0))


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	var sw: float = side_w()
	return Rect2(r.position.x + px(6.0), r.position.y + r.size.y * 0.5 - px(22.0), maxf(sw - px(10.0), px(80.0)), px(22.0))


func length_of(item: MediaItem) -> float:
	var d: Project = doc()
	var dur: float = d.media_duration(item) if d != null else item.duration
	return maxf(dur, 0.0)


func time_at(i: int, local_x: float) -> float:
	var item: MediaItem = item_of(i)
	if item == null:
		return -1.0
	var sr: Rect2 = strip_rect(i)
	var dur: float = length_of(item)
	if dur <= 0.0 or sr.size.x <= 0.0:
		return -1.0
	return clampf((local_x - sr.position.x) / sr.size.x, 0.0, 1.0) * dur


func x_of(i: int, t: float) -> float:
	var item: MediaItem = item_of(i)
	var sr: Rect2 = strip_rect(i)
	var dur: float = length_of(item) if item != null else 0.0
	if dur <= 0.0:
		return sr.position.x
	return sr.position.x + clampf(t / dur, 0.0, 1.0) * sr.size.x


func range_of(media_id: String) -> Vector2:
	return panel.call("item_range", media_id)


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	var item: MediaItem = item_of(i)
	var label: String = String(e.get("label", ""))
	if item == null:
		return label
	var r: Vector2 = range_of(item.id)
	if r.y > r.x:
		return label + "  " + String(panel.call("tc", r.x)) + " to " + String(panel.call("tc", r.y))
	return label


func tick(_dt: float) -> bool:
	if not _waves_waiting:
		return false
	var now: int = Time.get_ticks_msec()
	if now - _wave_poll_ms >= 700:
		_wave_poll_ms = now
		redraw()
	return true


func draw() -> void:
	_waves_waiting = false
	var list: Array[Dictionary] = entries()
	var vis: Rect2 = visible_rect()
	var sw: float = side_w()
	var f: Font = font()
	var m: Font = mono()
	var fsb: int = fs_body()
	var fss: int = fs_small()
	var rid: RID = body.get_canvas_item()
	for i: int in list.size():
		var r: Rect2 = screen_rect(i)
		if r.end.y < 0.0 or r.position.y > vis.end.y:
			continue
		var e: Dictionary = list[i]
		var item: MediaItem = item_of(i)
		var selected: bool = is_selected(i)
		var radius: float = px(Tk.sz("radius_row"))
		if selected:
			Paint.rounded(body, r.grow_individual(-2.0, 0.0, -2.0, -1.0), Tk.c["glass_strong"], radius)
		elif i == hover_index():
			Paint.rounded(body, r.grow_individual(-2.0, 0.0, -2.0, -1.0), Tk.c["glass"], radius)
		body.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["lane_line"], true)
		if item != null and item.colour >= 0:
			body.draw_rect(Rect2(r.position.x, r.position.y + 4.0, 3.0, r.size.y - 8.0), Tk.label_colour(item.colour), true)
		var left: float = r.position.x + px(8.0)
		var text_w: float = sw - px(14.0)
		var name_col: Color = Tk.c["text_bright"] if selected else Tk.c["text"]
		var gap: float = px(3.0)
		var block_h: float = f.get_height(fsb) + gap + m.get_height(fss)
		var top: float = r.position.y + (r.size.y - block_h) * 0.5
		var column: Rect2 = Rect2(r.position.x, r.position.y, sw, r.size.y)
		PmText.draw_in(body, f, Rect2(left, top, text_w, f.get_height(fsb)), String(e.get("label", "")), fsb, name_col, HORIZONTAL_ALIGNMENT_LEFT, top + f.get_ascent(fsb), PmText.ELIDE_OWN_TIP, column)
		var meta: String = _meta_for(e, item)
		PmText.draw_in(body, m, Rect2(left, top + f.get_height(fsb) + gap, text_w, m.get_height(fss)), meta, fss, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, top + f.get_height(fsb) + gap + m.get_ascent(fss), PmText.ELIDE_OWN_TIP, column)
		if item == null:
			continue
		var sr: Rect2 = strip_rect(i)
		if sr.size.x < px(24.0):
			continue
		Paint.rounded(body, sr, Tk.c["bg_panel_alt"], px(6.0))
		_draw_strip(i, item, sr, rid)
		draw_marker_ticks(sr.grow(-1.0), item)
		var used: Dictionary = panel.call("usage_for", item.id)
		_draw_used(sr, item, used)
		var rg: Vector2 = range_of(item.id)
		if rg.y > rg.x:
			var x0: float = x_of(i, rg.x)
			var x1: float = x_of(i, rg.y)
			var rr: Rect2 = Rect2(x0, sr.position.y, maxf(x1 - x0, 2.0), sr.size.y)
			body.draw_rect(rr, Color(Tk.c["sol"], 0.14), true)
			body.draw_rect(Rect2(x0, sr.position.y, 2.0, sr.size.y), Tk.c["sol"], true)
			body.draw_rect(Rect2(x1 - 2.0, sr.position.y, 2.0, sr.size.y), Tk.c["sol"], true)
		if String(drag.get("mode", "")) == "mark" and int(drag.get("row", -1)) == i and bool(drag.get("moved", false)):
			var a: float = x_of(i, float(drag["t0"]))
			var b: float = x_of(i, float(drag["t1"]))
			body.draw_rect(Rect2(minf(a, b), sr.position.y, absf(b - a), sr.size.y), Color(Tk.c["sol"], 0.18), true)
		if i == hover_row and hover_t >= 0.0:
			var hx: float = x_of(i, hover_t)
			body.draw_rect(Rect2(hx, sr.position.y, 1.0, sr.size.y), Tk.c["sol"], true)
			var tc: String = String(panel.call("tc", hover_t)).substr(0, 8)
			var tw: float = ceil(PmText.width_of(m, tc, fss)) + PmText.chip_pad() * 2.0
			var th: float = ceil(m.get_height(fss)) + px(3.0)
			var tx: float = hx + px(5.0)
			if tx + tw > sr.end.x:
				tx = hx - px(5.0) - tw
			var tag: Rect2 = Rect2(tx, sr.position.y + px(2.0), tw, th)
			Paint.rounded(body, tag, Color(Tk.c["bg_app"], 0.78), px(Tk.sz("radius_chip")))
			PmText.draw(body, m, tag, tc, fss, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), NAN, PmText.WHOLE)
	_wake_for_waves()


func _wake_for_waves() -> void:
	if _waves_waiting and body != null and not body.is_processing():
		body.set_process(true)


func _meta_for(e: Dictionary, item: MediaItem) -> String:
	if String(e.get("kind", "")) == "folder":
		return String(e.get("meta", ""))
	if item == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var d: String = duration_text(item)
	if item.is_timed():
		var dur: float = length_of(item)
		parts.append(String(panel.call("tc", dur)).substr(0, 8) if dur > 0.0 else "reading")
	elif item.kind == "image":
		parts.append("picture")
	if item.fps > 0.0 and item.kind == "video":
		parts.append(String(panel.call("_fps_text", item.fps)) + " fps")
	elif item.kind == "audio" and not item.audio_streams.is_empty():
		parts.append(str(int(item.audio_streams[0].get("sample_rate", 48000)) / 1000) + " kHz")
	elif item.width > 0 and item.height > 0 and d.is_empty():
		parts.append(str(item.width) + "x" + str(item.height))
	return " · ".join(parts)


func _draw_strip(i: int, item: MediaItem, sr: Rect2, rid: RID) -> void:
	var inner: Rect2 = sr.grow(-1.0)
	var has_sound: bool = item.has_audio or item.kind == "audio" or item.audio_only
	var picture: bool = item.has_picture() and item.kind != "sequence"
	var used_h: float = px(USED_H)
	var wave_h: float = px(WAVE_BAND) if (picture and has_sound) else 0.0
	var pic_h: float = inner.size.y - used_h - wave_h
	if picture and pic_h > 4.0:
		var aspect: float = 16.0 / 9.0
		if item.width > 0 and item.height > 0:
			aspect = float(item.width) / float(item.height)
		var cell_w: float = maxf(pic_h * aspect, px(24.0))
		var n: int = clampi(int(floor(inner.size.x / cell_w)), 1, MAX_CELLS)
		var cw: float = inner.size.x / float(n)
		var h: int = int(panel.call("media_handle", item))
		var dur: float = length_of(item)
		var video_strip: bool = item.kind == "video" and PurrBridge.available and h >= 0 and dur > 0.0 and not item.props.has("still_time")
		if not video_strip and (item.kind == "image" or item.props.has("still_time")):
			n = 1
			cw = minf(cell_w, inner.size.x)
		for j: int in n:
			var cell: Rect2 = Rect2(inner.position.x + float(j) * cw, inner.position.y, cw, pic_h)
			var drawn: bool = false
			if video_strip:
				var t: float = (float(j) + 0.5) / float(n) * dur
				var tex: RID = PurrBridge.strip_frame(h, t)
				if tex.is_valid():
					RenderingServer.canvas_item_add_texture_rect(rid, cell, tex)
					drawn = true
			if not drawn and (j == 0 or not video_strip):
				var still: float = float(item.props.get("still_time", -1.0))
				var thumb: Texture2D = panel.call("thumb_for", item, still, true)
				if thumb != null:
					draw_texture_in(thumb, cell, true)
					drawn = true
			if not drawn:
				body.draw_rect(cell.grow(-1.0), Tk.c["bg_panel_high"], true)
			if j > 0:
				body.draw_rect(Rect2(cell.position.x, cell.position.y, 1.0, pic_h), Color(0.0, 0.0, 0.0, 0.35), true)
		if item.kind == "image" or item.props.has("still_time"):
			return
	var band: Rect2
	if picture:
		band = Rect2(inner.position.x, inner.position.y + pic_h, inner.size.x, wave_h)
	else:
		band = Rect2(inner.position.x, inner.position.y, inner.size.x, inner.size.y - used_h)
	if band.size.y >= 3.0 and has_sound:
		_draw_wave(item, band)
	elif not picture and not has_sound:
		var side: float = minf(band.size.y, px(18.0))
		IconsKit.draw(body, String(panel.call("kind_icon", item.kind)), Rect2(band.position + Vector2(px(6.0), (band.size.y - side) * 0.5), Vector2(side, side)), Tk.c["text_faint"])


func _draw_wave(item: MediaItem, band: Rect2) -> void:
	var pts: PackedVector2Array = _wave_points(item, band.size)
	if pts.is_empty():
		return
	var rec: Variant = _wave_cache.get(item.id + "|" + str(int(band.size.x)) + "|" + str(int(band.size.y)), null)
	if rec is Dictionary and (rec as Dictionary).has("norm"):
		WaveLook.listen(body)
		var half: float = band.size.y * 0.5 - 0.5
		var lk: Dictionary = WaveLook.look()
		var cols: Dictionary = WaveLook.columns_cached(rec, (rec as Dictionary)["norm"], WaveLook.base_colour(lk, -1, item.colour), WaveLook.scale(true, 1.0), 1.0, half)
		body.draw_set_transform(Vector2(band.position.x, band.position.y + band.size.y * 0.5), 0.0, Vector2(1.0, half))
		WaveLook.draw_columns(body, cols)
		body.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(pts.size())
	var mid: float = band.position.y + band.size.y * 0.5
	for p: int in pts.size():
		out[p] = Vector2(band.position.x + pts[p].x, mid + pts[p].y)
	body.draw_multiline(out, Tk.c["wave"], 1.0)


func _peak_stream(item: MediaItem) -> int:
	if StreamOrdinals.all_off(item):
		return -1
	return StreamOrdinals.first_selected(item)


func _wave_points(item: MediaItem, size: Vector2) -> PackedVector2Array:
	var h: int = int(panel.call("media_handle", item))
	var dur: float = length_of(item)
	if h < 0 or dur <= 0.0 or not PurrBridge.available:
		return PackedVector2Array()
	var key: String = item.id + "|" + str(int(size.x)) + "|" + str(int(size.y))
	var now: int = Time.get_ticks_msec()
	if _wave_cache.has(key):
		var rec: Dictionary = _wave_cache[key]
		if bool(rec["done"]) or now - int(rec["at"]) < 700:
			return rec["pts"]
	var stream: int = _peak_stream(item)
	if stream < 0:
		return PackedVector2Array()
	var tier: int = PEAK_TIER
	for t: int in PEAK_TIER + 1:
		if dur * Lanes.tier_rate(t) <= size.x * 4.0:
			tier = t
			break
	var rate: float = Lanes.tier_rate(tier)
	var count: int = int(ceil(dur * rate))
	var bytes: PackedByteArray = PurrBridge.peaks_read(h, stream, tier, 0, count)
	var coverage: PackedByteArray = PurrBridge.peaks_coverage(h, stream)
	var done: bool = not coverage.is_empty()
	for cv: int in coverage:
		if cv == 0:
			done = false
			break
	if not done:
		Session.want_peaks(h, stream, 0.0)
	var buckets: int = bytes.size() / 2
	var out: PackedVector2Array = PackedVector2Array()
	var norm: PackedVector2Array = PackedVector2Array()
	if buckets > 0:
		var stride: int = maxi(1, int(ceil(float(buckets) / maxf(size.x, 1.0))))
		var raw: PackedVector2Array = Paint.build_wave_points(bytes, 0, rate, stride, true, 1.0)
		var half: float = size.y * 0.5 - 0.5
		out.resize(raw.size())
		norm.resize(raw.size())
		for p: int in raw.size():
			out[p] = Vector2(raw[p].x / dur * size.x, clampf(raw[p].y, -1.0, 1.0) * half)
			norm[p] = Vector2(out[p].x, clampf(raw[p].y, -1.0, 1.0))
	if _wave_cache.size() > 400:
		_wave_cache.clear()
	_wave_cache[key] = {"pts": out, "norm": norm, "done": done, "at": now}
	if not done:
		_waves_waiting = true
	return out


func _draw_used(sr: Rect2, item: MediaItem, used: Dictionary) -> void:
	var h: float = px(USED_H)
	var track: Rect2 = Rect2(sr.position.x + 1.0, sr.end.y - h - 1.0, sr.size.x - 2.0, h)
	body.draw_rect(track, Tk.c["bg_panel_high"], true)
	if used.is_empty():
		return
	var dur: float = length_of(item)
	if not item.is_timed() or dur <= 0.0:
		body.draw_rect(track, Tk.c["sol"], true)
		return
	for v: Vector2 in (used.get("spans", PackedVector2Array()) as PackedVector2Array):
		var a: float = clampf(v.x / dur, 0.0, 1.0)
		var b: float = clampf(v.y / dur, 0.0, 1.0)
		if b > a:
			body.draw_rect(Rect2(track.position.x + track.size.x * a, track.position.y, maxf(track.size.x * (b - a), 1.0), h), Tk.c["sol"], true)


func _on_strip(i: int, local: Vector2) -> bool:
	if i < 0 or item_of(i) == null:
		return false
	return strip_rect(i).has_point(local)


func input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		var i: int = int(body.call("index_at", mm.position))
		var over: bool = _on_strip(i, mm.position)
		var t: float = time_at(i, mm.position.x) if over else -1.0
		if i != hover_row or absf(t - hover_t) > 0.0001:
			hover_row = i if over else -1
			hover_t = t
			redraw()
		if over and t >= 0.0:
			_scrub_sound(item_of(i), t)
		if drag.is_empty():
			return false
		var press: Vector2 = drag["press"]
		if not bool(drag.get("moved", false)) and (mm.position - press).length() >= px(SLOP):
			drag["moved"] = true
			if String(drag["mode"]) == "range":
				var d: Dictionary = drag
				drag = {}
				panel.call("begin_range_drag", String(d["id"]), float(d["in"]), float(d["out"]), Vector2(px(20.0), px(14.0)))
				return true
		if String(drag.get("mode", "")) == "mark" and bool(drag.get("moved", false)):
			drag["t1"] = time_at(int(drag["row"]), mm.position.x)
			redraw()
		return true
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	var i2: int = int(body.call("index_at", mb.position))
	if mb.pressed:
		if not _on_strip(i2, mb.position):
			return false
		var item: MediaItem = item_of(i2)
		var t0: float = time_at(i2, mb.position.x)
		if mb.double_click:
			drag = {}
			open_in_source(item, t0)
			return true
		if not is_selected(i2):
			panel.call("select_entry", item.id, "replace")
		var rg: Vector2 = range_of(item.id)
		if rg.y > rg.x and t0 >= rg.x and t0 <= rg.y:
			drag = {"mode": "range", "press": mb.position, "id": item.id, "in": rg.x, "out": rg.y, "moved": false}
		else:
			drag = {"mode": "mark", "press": mb.position, "row": i2, "id": item.id, "t0": t0, "t1": t0, "moved": false}
		return true
	if drag.is_empty():
		return false
	var dd: Dictionary = drag
	drag = {}
	if String(dd["mode"]) == "mark" and bool(dd.get("moved", false)):
		var a: float = minf(float(dd["t0"]), float(dd["t1"]))
		var b: float = maxf(float(dd["t0"]), float(dd["t1"]))
		panel.call("set_item_range", String(dd["id"]), a, b)
	redraw()
	return true


func open_in_source(item: MediaItem, t: float) -> void:
	if item == null:
		return
	var rg: Vector2 = range_of(item.id)
	panel.call("open_in_source_at", item.id, maxf(t, 0.0), rg.x if rg.y > rg.x else -1.0, rg.y if rg.y > rg.x else -1.0)


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo:
		return false
	var plain: bool = not (e.ctrl_pressed or e.meta_pressed or e.alt_pressed or e.shift_pressed)
	if e.keycode == KEY_ESCAPE and not drag.is_empty():
		drag = {}
		redraw()
		return true
	if plain and (e.keycode == KEY_I or e.keycode == KEY_O) and hover_row >= 0 and hover_t >= 0.0:
		var item: MediaItem = item_of(hover_row)
		if item == null:
			return false
		var rg: Vector2 = range_of(item.id)
		var dur: float = length_of(item)
		var a: float = rg.x if rg.y > rg.x else 0.0
		var b: float = rg.y if rg.y > rg.x else dur
		if e.keycode == KEY_I:
			a = hover_t
			if b <= a:
				b = dur
		else:
			b = hover_t
			if a >= b:
				a = 0.0
		panel.call("set_item_range", item.id, a, b)
		redraw()
		return true
	return false


func leave() -> void:
	hover_row = -1
	hover_t = -1.0
	_release_sound()
	redraw()


func deactivate() -> void:
	drag = {}
	leave()
	if PurrBridge.has_signal("strip_ready") and PurrBridge.strip_ready.is_connected(_on_strip_ready):
		PurrBridge.strip_ready.disconnect(_on_strip_ready)
	if PurrBridge.has_signal("peaks_progress") and PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.disconnect(_on_peaks_progress)


func _scrub_sound(item: MediaItem, t: float) -> void:
	if item == null or not sound_on() or not PurrBridge.available or Session.playing:
		return
	if not (item.has_audio or item.kind == "audio"):
		return
	var h: int = int(panel.call("media_handle", item))
	if h < 0:
		return
	if _heard_id != item.id or String(Session.get("audio_owner")) != AUDIO_OWNER:
		var s: Object = Session.seq()
		var rate: int = int(s.get("sample_rate")) if s != null else 48000
		load("res://engine/ear_safety.gd").call("note_preview", AUDIO_OWNER, item.id)
		if not Session.claim_audio(AUDIO_OWNER, AudioGraph.source_graph(item, h, AudioGraph.monitor_stream(item), rate)):
			return
		_heard_id = item.id
	var now: int = Time.get_ticks_msec()
	if now - _last_scrub_ms < 40 and absf(t - _last_scrub_t) < 0.08:
		return
	_last_scrub_ms = now
	_last_scrub_t = t
	PurrBridge.scrub(t, 0.08)


func _release_sound() -> void:
	if _heard_id.is_empty():
		return
	_heard_id = ""
	Session.release_audio(AUDIO_OWNER)


func build_bar(bar: Container) -> void:
	bar_toggle(bar, "Sound on hover", "Play the sound under the pointer while hovering a strip", sound_on(), _on_sound)
	bar_button(bar, "Clear in and out", "Clear the marked range of the selected items. Drag along a strip, or press I and O while hovering, to mark one", _on_clear)
	set_meta_text("drag along a strip or press I and O to mark")


func _on_sound(on: bool) -> void:
	set_state("strips", "sound", on)
	if not on:
		_release_sound()


func _on_clear() -> void:
	var sel: PackedStringArray = panel.get("selected_ids")
	for sid: String in sel:
		panel.call("set_item_range", sid, -1.0, -1.0)
	redraw()


func context_items(entry_id: String) -> Array:
	var r: Vector2 = range_of(entry_id)
	if r.y <= r.x:
		return []
	return [PmMenu.separator(), PmMenu.item("strips:clear", "Clear in and out"), PmMenu.item("strips:source", "Open the marked range in Source")]


func on_context(pick: String, entry_id: String) -> bool:
	if pick == "strips:clear":
		panel.call("set_item_range", entry_id, -1.0, -1.0)
		redraw()
		return true
	if pick == "strips:source":
		var d: Project = doc()
		var item: MediaItem = d.media_by_id(entry_id) if d != null else null
		open_in_source(item, range_of(entry_id).x)
		return true
	return false
