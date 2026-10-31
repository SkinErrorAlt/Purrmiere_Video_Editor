extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const LoopDraw := preload("res://ui/timeline/timeline_loop.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")
const WaveVolume := preload("res://ui/timeline/wave_volume.gd")
const AMP_CAP := 8.0

const COARSE_TIER := 2
const STRIP_H := 240.0
const WAVE_MIN_H := 16.0
const THUMB_MIN_H := 32.0
const PYR_CHECK_MS := 1500
const PYR_EMPTY_CHECK_MS := 250
const STRIP_CHECK_MS := 1000
const BUDGET_USEC := 2000
const CONTENT_BUDGET_USEC := 700
const ENV_MAX := 4096
const MAPS_MAX := 64
const WAVES_MAX := 96
const TILES_MAX := 160
const QUIET := 0.015
const TILE_LINE := Color(0.0, 0.0, 0.0, 0.35)

static var stats: Dictionary = {"paint": -1, "frames": 0, "envelopes": 0, "env_builds": 0, "pyr_builds": 0, "pyr_usec": 0, "wave_lanes": 0, "tiles": 0, "put_off": 0, "build_usec": 0}
static var _pyr: Dictionary = {}
static var _env: Dictionary = {}
static var _maps: Dictionary = {}
static var _waves: Dictionary = {}
static var _paint_memo: Dictionary = {}
static var _amp_tables: Dictionary = {}
static var _strips: Dictionary = {}
static var _pyr_version: int = 0
static var _budget_paint: int = -1
static var _budget_id: int = 0
static var _budget_end: int = 0
static var _content_paint: int = -1
static var _content_id: int = 0
static var _content_end: int = 0


static func _tick(canvas: Control) -> void:
	var p: int = int(canvas.get("paint_count"))
	if int(stats["paint"]) == p:
		return
	stats["paint"] = p
	for k: String in ["frames", "envelopes", "wave_lanes", "tiles", "put_off"]:
		stats[k] = 0


static func pot(canvas: Control) -> int:
	var p: int = int(canvas.get("paint_count"))
	var id: int = canvas.get_instance_id()
	if _budget_paint != p or _budget_id != id:
		_budget_paint = p
		_budget_id = id
		_budget_end = Time.get_ticks_usec() + BUDGET_USEC
	return _budget_end


static func _deadline(canvas: Control) -> int:
	var shared: int = pot(canvas)
	if _content_paint != _budget_paint or _content_id != _budget_id:
		_content_paint = _budget_paint
		_content_id = _budget_id
		_content_end = Time.get_ticks_usec() + CONTENT_BUDGET_USEC
	return mini(shared, _content_end)


static func _over(canvas: Control) -> bool:
	return Time.get_ticks_usec() >= _deadline(canvas)


static func coarse_rate() -> float:
	return Lanes.tier_rate(COARSE_TIER)


static func _handle(canvas: Control, item: MediaItem) -> int:
	if item == null:
		return -1
	return int(canvas.call("_handle_of", item))


static func _has_peaks(canvas: Control, h: int) -> bool:
	if (canvas.get("peaks_provider") as Callable).is_valid():
		return true
	return PurrBridge.available and h >= 0


static func _coverage_sign(canvas: Control, h: int, stream: int) -> String:
	var cov: PackedByteArray = canvas.call("_coverage", h, stream)
	if cov.is_empty():
		return "all" if (canvas.get("coverage_provider") as Callable).is_valid() else "none"
	return str(cov.size()) + ":" + str(cov.size() - cov.count(0)) + ":" + str(hash(cov))


static func pyramid(canvas: Control, h: int, stream: int, duration: float) -> Dictionary:
	if h < 0 and not (canvas.get("peaks_provider") as Callable).is_valid():
		return {}
	var key: String = str(h) + "|" + str(stream)
	var now: int = Time.get_ticks_msec()
	var hit: Variant = _pyr.get(key, null)
	if hit is Dictionary:
		var hd: Dictionary = hit
		var wait_ms: int = PYR_CHECK_MS if int(hd["n"]) > 0 else PYR_EMPTY_CHECK_MS
		if bool(hd["complete"]) or now - int(hd["checked"]) < wait_ms:
			return hd
		var sign_now: String = _coverage_sign(canvas, h, stream)
		hd["checked"] = now
		if sign_now == String(hd["sign"]):
			return hd
	var t0: int = Time.get_ticks_usec()
	var sign: String = _coverage_sign(canvas, h, stream)
	var rate: float = coarse_rate()
	if sign == "none":
		if PurrBridge.available:
			Session.want_peaks(h, stream, 0.0)
		var empty_pyr: Dictionary = {"sign": sign, "checked": now, "complete": false, "up": [PackedByteArray([0])], "dn": [PackedByteArray([0])], "n": 0, "rate": rate}
		if not (hit is Dictionary) or int((hit as Dictionary)["n"]) > 0:
			_pyr_version += 1
		_pyr[key] = empty_pyr
		return empty_pyr
	var n: int = int(ceil(maxf(duration, 0.0) * rate)) + 1
	var bytes: PackedByteArray = canvas.call("_peaks", h, stream, COARSE_TIER, 0, n)
	var got: int = bytes.size() / 2
	var up: PackedByteArray = PackedByteArray()
	var dn: PackedByteArray = PackedByteArray()
	up.resize(maxi(got, 1))
	dn.resize(maxi(got, 1))
	var any: bool = false
	for i: int in got:
		var lo_b: int = bytes[i * 2]
		var hi_b: int = bytes[i * 2 + 1]
		if lo_b == 0 and hi_b == 0:
			continue
		up[i] = clampi(hi_b - 128, 0, 255)
		dn[i] = clampi(128 - lo_b, 0, 255)
		any = true
	var ups: Array[PackedByteArray] = [up]
	var dns: Array[PackedByteArray] = [dn]
	while (ups[ups.size() - 1] as PackedByteArray).size() > 1:
		var pu: PackedByteArray = ups[ups.size() - 1]
		var pd: PackedByteArray = dns[dns.size() - 1]
		var m: int = (pu.size() + 1) / 2
		var nu: PackedByteArray = PackedByteArray()
		var nd: PackedByteArray = PackedByteArray()
		nu.resize(m)
		nd.resize(m)
		for j: int in m:
			var a: int = j * 2
			var b: int = mini(a + 1, pu.size() - 1)
			nu[j] = maxi(pu[a], pu[b])
			nd[j] = maxi(pd[a], pd[b])
		ups.append(nu)
		dns.append(nd)
	var complete: bool = sign == "all" or (not sign.begins_with("none") and _all_ready(canvas, h, stream))
	var out: Dictionary = {"sign": sign, "checked": now, "complete": complete and any, "up": ups, "dn": dns, "n": got if any else 0, "rate": rate}
	if _pyr.size() >= MAPS_MAX:
		_pyr.clear()
	_pyr[key] = out
	_pyr_version += 1
	stats["pyr_builds"] = int(stats["pyr_builds"]) + 1
	stats["pyr_usec"] = int(stats["pyr_usec"]) + Time.get_ticks_usec() - t0
	return out


static func _all_ready(canvas: Control, h: int, stream: int) -> bool:
	var cov: PackedByteArray = canvas.call("_coverage", h, stream)
	if cov.is_empty():
		return (canvas.get("coverage_provider") as Callable).is_valid()
	return cov.count(0) == 0


static func peak(pyr: Dictionary, b0: int, b1: int) -> Vector2i:
	var n: int = int(pyr["n"])
	if n <= 0:
		return Vector2i.ZERO
	var a: int = clampi(b0, 0, n - 1)
	var b: int = clampi(maxi(b1, b0 + 1), a + 1, n)
	var span: int = b - a
	var p: int = 0
	while (1 << (p + 1)) <= span:
		p += 1
	var ups: Array = pyr["up"]
	var dns: Array = pyr["dn"]
	p = mini(p, ups.size() - 1)
	var lu: PackedByteArray = ups[p]
	var ld: PackedByteArray = dns[p]
	var i0: int = a >> p
	var i1: int = mini((b - 1) >> p, lu.size() - 1)
	var u: int = 0
	var d: int = 0
	for i: int in range(i0, i1 + 1):
		u = maxi(u, lu[i])
		d = maxi(d, ld[i])
	return Vector2i(u, d)


static func amp(byte: int, log_mode: bool, gain: float) -> float:
	return maxf(Paint.wave_amp(byte, log_mode, gain, AMP_CAP), QUIET)


static func envelope(pyr: Dictionary, s0: float, e0: float, src0: float, src1: float, w: float, log_mode: bool, gain: float, out: PackedVector2Array) -> void:
	var rate: float = float(pyr["rate"])
	var amps: PackedFloat32Array = amp_table(log_mode, gain)
	var len_t: float = maxf(e0 - s0, 0.000001)
	var c0: int = int(floor(s0 / w))
	var c1: int = maxi(int(ceil(e0 / w)) - 1, c0)
	for col: int in range(c0, c1 + 1):
		var ta: float = maxf(float(col) * w, s0)
		var tb: float = minf(float(col + 1) * w, e0)
		if tb <= ta:
			continue
		var sa: float = src0 + (ta - s0) / len_t * (src1 - src0)
		var sb: float = src0 + (tb - s0) / len_t * (src1 - src0)
		var pk: Vector2i = peak(pyr, int(floor(minf(sa, sb) * rate)), int(ceil(maxf(sa, sb) * rate)))
		var tm: float = (ta + tb) * 0.5
		out.append(Vector2(tm, -amps[mini(pk.x, 255)]))
		out.append(Vector2(tm, amps[mini(pk.y, 255)]))


static func _paint(canvas: Control) -> Dictionary:
	var p: int = int(canvas.get("paint_count"))
	var id: int = canvas.get_instance_id()
	if int(_paint_memo.get("paint", -1)) == p and int(_paint_memo.get("id", 0)) == id:
		return _paint_memo
	var pps: float = float(canvas.get("pps"))
	var log_mode: bool = bool(canvas.get("wave_log"))
	var gain: float = float(canvas.get("wave_gain"))
	_paint_memo = {"paint": p, "id": id, "pps": pps, "level": int(floor(log(1.0 / maxf(pps, 0.0000001)) / log(2.0))), "log": log_mode, "gain": gain, "mode": str(log_mode) + "|" + str(gain), "handles": {}, "pyrs": {}, "strips": {}, "provider": (canvas.get("peaks_provider") as Callable).is_valid(), "name_h": Paint.name_row_h(), "wave_min": float(Tk.px(WAVE_MIN_H)), "wave_col": Tk.c["wave"], "line_col": Tk.c["wave_line"]}
	return _paint_memo


static func _handle_memo(canvas: Control, memo: Dictionary, item: MediaItem) -> int:
	var hs: Dictionary = memo["handles"]
	var hit: Variant = hs.get(item.get_instance_id(), null)
	if hit is int:
		return hit
	var h: int = _handle(canvas, item)
	hs[item.get_instance_id()] = h
	return h


static func wave_band(r: Rect2, name_h: float) -> Rect2:
	var lane_h: float = r.size.y + 2.0
	var nh: float = name_h if lane_h >= 34.0 else 0.0
	return Rect2(r.position.x, r.position.y + nh, r.size.x, r.size.y - nh - 1.0)


static func _memo_pyr(canvas: Control, memo: Dictionary, h: int, stream: int, duration: float) -> Dictionary:
	var pyrs: Dictionary = memo["pyrs"]
	var key: int = h * 64 + stream
	var hit: Variant = pyrs.get(key, null)
	if hit is Dictionary:
		return hit
	var pyr: Dictionary = pyramid(canvas, h, stream, duration)
	pyrs[key] = pyr
	return pyr


static func slim_wave(canvas: Control, c: Clip, item: MediaItem, r: Rect2, x0: float) -> void:
	if item == null:
		return
	var memo: Dictionary = _paint(canvas)
	if r.size.y + 2.0 < float(memo["wave_min"]):
		return
	var h: int = _handle_memo(canvas, memo, item)
	if h < 0 and not bool(memo["provider"]):
		return
	var stream: int = int(c.audio.get("stream", 0.0))
	var pyr: Dictionary = _memo_pyr(canvas, memo, h, stream, item.duration)
	if pyr.is_empty() or int(pyr["n"]) <= 0:
		return
	var pps: float = float(memo["pps"])
	var level: int = int(memo["level"])
	var sp: float = c.static_speed()
	var id: int = c.get_instance_id()
	var hit: Variant = _env.get(id, null)
	var seg: PackedVector2Array
	var fresh: bool = false
	if hit is Dictionary:
		var e: Dictionary = hit
		fresh = sp != 0.0 and int(e["lv"]) == level and float(e["s"]) == c.start and float(e["d"]) == c.duration and float(e["in"]) == c.in_offset and float(e["sp"]) == sp and int(e["h"]) == h and int(e["st"]) == stream and String(e["ps"]) == String(pyr["sign"]) and String(e["mode"]) == String(memo["mode"]) and bool(e["lp"]) == c.loop and float(e["li"]) == c.loop_in
		if fresh:
			seg = e["seg"]
	_tick(canvas)
	if not fresh:
		if _over(canvas):
			stats["put_off"] = int(stats["put_off"]) + 1
			canvas.queue_redraw()
			return
		var spans: PackedFloat64Array = LoopDraw.source_spans(c, item.duration)
		seg = PackedVector2Array()
		for si: int in range(0, spans.size(), 4):
			envelope(pyr, spans[si], spans[si + 1], spans[si + 2], spans[si + 3], pow(2.0, float(level)), bool(memo["log"]), float(memo["gain"]), seg)
		if _env.size() >= ENV_MAX:
			_env.clear()
		_env[id] = {"lv": level, "s": c.start, "d": c.duration, "in": c.in_offset, "sp": sp, "h": h, "st": stream, "ps": String(pyr["sign"]), "mode": String(memo["mode"]), "lp": c.loop, "li": c.loop_in, "seg": seg}
		stats["env_builds"] = int(stats["env_builds"]) + 1
	if seg.is_empty():
		return
	stats["envelopes"] = int(stats["envelopes"]) + 1
	var band: Rect2 = wave_band(r, float(memo["name_h"]))
	if band.size.y < 4.0:
		return
	var centre_y: float = band.position.y + band.size.y * 0.5
	var lk: Dictionary = WaveLook.look()
	if WaveLook.anchor_of(lk) == WaveLook.GROW_MIDDLE:
		canvas.draw_line(Vector2(band.position.x, centre_y), Vector2(band.end.x, centre_y), memo["line_col"], 1.0)
	var half: float = band.size.y * 0.5 - 1.0
	var holder: Variant = _env.get(id, null)
	var base: Color = WaveLook.base_colour(lk, c.colour, item.colour, _track_colour(canvas, c, lk))
	var sc: Dictionary = WaveLook.scale(bool(memo["log"]), float(memo["gain"]))
	var vol: Dictionary = clip_volume(canvas, c)
	var cols: Dictionary = WaveLook.columns_cached(holder, seg, base, sc, pps, half, vol) if holder is Dictionary else WaveLook.columns_heard(seg, vol, lk, base, sc, pps, half)
	canvas.draw_set_transform(Vector2(x0 - c.start * pps, centre_y), 0.0, Vector2(pps, half))
	WaveLook.draw_columns(canvas, cols)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func clip_volume(canvas: Control, c: Clip) -> Dictionary:
	if not WaveLook.volume_on() or not canvas.has_method("doc"):
		return {}
	var env: Dictionary = WaveVolume.for_clip(canvas.call("doc"), canvas.call("seq"), c)
	return WaveVolume.window(env, -c.start, 1.0)


static func lane_volume(canvas: Control, t: Track) -> Dictionary:
	if not WaveLook.volume_on() or not canvas.has_method("doc"):
		return {}
	return WaveVolume.for_lane(canvas.call("doc"), canvas.call("seq"), t)


static func _track_colour(canvas: Control, c: Clip, lk: Dictionary) -> int:
	var from: String = String(lk.get("colour_from", WaveLook.COLOUR_THEME))
	if from != WaveLook.COLOUR_CLIP and from != WaveLook.COLOUR_TRACK:
		return -1
	if not canvas.has_method("seq"):
		return -1
	var s: Variant = canvas.call("seq")
	if not (s is Sequence):
		return -1
	var tr: Track = (s as Sequence).track_of(c.id)
	return tr.colour if tr != null else -1


static func _aspect(item: MediaItem) -> float:
	if item != null and item.width > 0 and item.height > 0:
		return float(item.width) / float(item.height)
	return 16.0 / 9.0


static func _tex_size(aspect: float) -> Vector2:
	return Vector2(float(int(round(STRIP_H * aspect)) & ~1), STRIP_H)


static func draw_frame(canvas: Control, tex: RID, dest: Rect2, aspect: float) -> void:
	if not tex.is_valid() or dest.size.x < 1.0 or dest.size.y < 1.0:
		return
	var ts: Vector2 = _tex_size(aspect)
	var full_w: float = dest.size.y * aspect
	var src_w: float = ts.x * minf(dest.size.x / maxf(full_w, 1.0), 1.0)
	var src: Rect2 = Rect2((ts.x - src_w) * 0.5, 0.0, src_w, ts.y)
	RenderingServer.canvas_item_add_texture_rect_region(canvas.get_canvas_item(), dest, tex, src)
	stats["frames"] = int(stats["frames"]) + 1


static func picture_band(r: Rect2) -> Rect2:
	var lane_h: float = r.size.y + 2.0
	var name_h: float = Paint.name_row_h() if lane_h >= 34.0 else 0.0
	return Rect2(r.position.x, r.position.y + name_h, r.size.x, r.size.y - name_h - 1.0)


static func has_strip(h: int) -> bool:
	if h < 0 or not PurrBridge.available:
		return false
	var now: int = Time.get_ticks_msec()
	var hit: Variant = _strips.get(h, null)
	if hit is Array and now - int((hit as Array)[0]) < STRIP_CHECK_MS:
		return bool((hit as Array)[1])
	var st: String = String((PurrBridge.media_info(h) as Dictionary).get("strip_state", "none"))
	var ok: bool = st == "ready" or st == "building"
	if _strips.size() > MAPS_MAX:
		_strips.clear()
	_strips[h] = [now, ok]
	return ok


static func slim_frames(canvas: Control, c: Clip, item: MediaItem, r: Rect2, x0: float, x1: float) -> void:
	if item == null or item.kind != "video":
		return
	var memo: Dictionary = _paint(canvas)
	if not memo.has("pictures"):
		memo["pictures"] = String(canvas.call("clip_pictures"))
		memo["thumb_min"] = float(Tk.px(THUMB_MIN_H))
	if r.size.y + 2.0 < float(memo["thumb_min"]):
		return
	var pictures: String = String(memo["pictures"])
	if pictures == "none":
		return
	var h: int = _handle_memo(canvas, memo, item)
	var strips: Dictionary = memo["strips"]
	var sv: Variant = strips.get(h, null)
	if not (sv is bool):
		sv = has_strip(h)
		strips[h] = sv
	if not bool(sv):
		return
	_tick(canvas)
	var name_h: float = float(memo["name_h"]) if r.size.y + 2.0 >= 34.0 else 0.0
	var band: Rect2 = Rect2(r.position.x + 1.0, r.position.y + name_h, r.size.x - 2.0, r.size.y - name_h - 1.0)
	if band.size.x < 1.0 or band.size.y < 4.0:
		return
	var aspect: float = _aspect(item)
	var still_t: float = -1.0 if item.props.is_empty() or not item.props.has("still_time") else float(item.props["still_time"])
	var step: float = maxf(band.size.y * aspect, 24.0)
	var pps: float = float(memo["pps"])
	var full_w: float = x1 - x0
	if pictures == "head" or still_t >= 0.0 or full_w <= step * 1.5:
		var mid: float = c.start + c.duration * 0.5
		var tex: RID = PurrBridge.strip_frame(h, still_t if still_t >= 0.0 else c.media_time(mid, item.duration))
		draw_frame(canvas, tex, band, aspect)
		return
	var x: float = x0
	var n: int = 0
	while x < band.end.x and n < 12:
		var xe: float = minf(x + step, x1)
		var a: float = maxf(x, band.position.x)
		var b: float = minf(xe, band.end.x)
		if b > a:
			var tm: float = c.start + ((a + b) * 0.5 - x0) / pps
			draw_frame(canvas, PurrBridge.strip_frame(h, c.media_time(tm, item.duration)), Rect2(a, band.position.y, b - a, band.size.y), aspect)
			if x > band.position.x:
				canvas.draw_rect(Rect2(x, band.position.y, 1.0, band.size.y), TILE_LINE, true)
		x += step
		n += 1


static func clip_map(canvas: Control, d: Project, t: Track) -> Dictionary:
	var sign: String = "%d|%d|%d|%d" % [d.get_instance_id(), d.serial, t.get_instance_id(), t.clips.size()]
	var key: String = str(canvas.get_instance_id()) + "|" + t.id
	var hit: Variant = _maps.get(key, null)
	var m: Dictionary = hit if hit is Dictionary and String((hit as Dictionary)["sign"]) == sign else {}
	if not m.is_empty() and bool(m["done"]):
		return m
	if m.is_empty():
		m = {"sign": sign, "done": false, "k": 0, "h": PackedInt32Array(), "stream": PackedInt32Array(), "src0": PackedFloat64Array(), "src1": PackedFloat64Array(), "aspect": PackedFloat32Array(), "dur": PackedFloat64Array(), "items": {}, "keys": {}, "loops": {}}
		if _maps.size() >= MAPS_MAX:
			_maps.clear()
		_maps[key] = m
	var deadline: int = _deadline(canvas)
	var t0: int = Time.get_ticks_usec()
	if t0 >= deadline:
		stats["put_off"] = int(stats["put_off"]) + 1
		canvas.queue_redraw()
		return m
	var clips: Array[Clip] = t.clips
	var n: int = clips.size()
	var hs: PackedInt32Array = m["h"]
	var streams: PackedInt32Array = m["stream"]
	var src0: PackedFloat64Array = m["src0"]
	var src1: PackedFloat64Array = m["src1"]
	var aspects: PackedFloat32Array = m["aspect"]
	var durs: PackedFloat64Array = m["dur"]
	if hs.size() != n:
		hs.resize(n)
		streams.resize(n)
		src0.resize(n)
		src1.resize(n)
		aspects.resize(n)
		durs.resize(n)
	var items: Dictionary = m["items"]
	var keys: Dictionary = m["keys"]
	var loops: Dictionary = m["loops"]
	var provider: bool = (canvas.get("peaks_provider") as Callable).is_valid()
	var pictures: bool = t.makes_picture()
	var last_media: String = ""
	var ia: Array = []
	var last_key: int = -2147483647
	var k: int = int(m["k"])
	while k < n:
		if (k & 31) == 31 and Time.get_ticks_usec() >= deadline:
			break
		var c: Clip = clips[k]
		if c.media_id != last_media or ia.is_empty():
			var info: Variant = items.get(c.media_id, null)
			if not (info is Array):
				var item: MediaItem = d.media_by_id(c.media_id)
				info = [_handle(canvas, item), _aspect(item), item.duration if item != null else 0.0, item != null and item.kind == "video"]
				items[c.media_id] = info
			ia = info
			last_media = c.media_id
		var sp: float = c.static_speed()
		var stream: int = int(c.audio.get("stream", 0.0))
		var h: int = int(ia[0])
		hs[k] = h if (not pictures or bool(ia[3])) else -1
		streams[k] = stream
		if sp != 0.0:
			src0[k] = c.in_offset
			src1[k] = c.in_offset + c.duration * sp
		else:
			src0[k] = c.source_time(c.start)
			src1[k] = c.source_time(c.start + c.duration)
		aspects[k] = float(ia[1])
		durs[k] = float(ia[2])
		var spans: PackedFloat64Array = LoopDraw.source_spans(c, float(ia[2])) if c.loop else PackedFloat64Array()
		if spans.size() > 4:
			loops[k] = spans
		elif not loops.is_empty():
			loops.erase(k)
		var kk: int = h * 64 + stream
		if kk != last_key and (h >= 0 or provider):
			last_key = kk
			keys[kk] = [h, stream, float(ia[2])]
		k += 1
	m["h"] = hs
	m["stream"] = streams
	m["src0"] = src0
	m["src1"] = src1
	m["aspect"] = aspects
	m["dur"] = durs
	m["k"] = k
	m["done"] = k >= n
	stats["build_usec"] = int(stats["build_usec"]) + Time.get_ticks_usec() - t0
	if not bool(m["done"]):
		stats["put_off"] = int(stats["put_off"]) + 1
		canvas.queue_redraw()
	return m


static func _pyr_sign(canvas: Control, m: Dictionary) -> String:
	var now: int = Time.get_ticks_msec()
	if now - int(m.get("checked", -100000)) >= PYR_EMPTY_CHECK_MS:
		m["checked"] = now
		for kv: Variant in (m["keys"] as Dictionary).values():
			var a: Array = kv
			pyramid(canvas, int(a[0]), int(a[1]), float(a[2]))
	return str(_pyr_version)


static func lane_waves(canvas: Control, t: Track, base: Dictionary, level: int) -> Dictionary:
	var d: Project = canvas.call("doc")
	if d == null:
		return {}
	var m: Dictionary = clip_map(canvas, d, t)
	if not bool(m["done"]):
		return {}
	var log_mode: bool = bool(canvas.get("wave_log"))
	var gain: float = float(canvas.get("wave_gain"))
	var sign: String = String(base["sign"]) + "|" + _pyr_sign(canvas, m) + "|" + str(log_mode) + str(gain)
	var prefix: String = str(canvas.get_instance_id()) + "|" + t.id + "|"
	var key: String = prefix + str(level)
	var hit: Variant = _waves.get(key, null)
	var wv: Dictionary = hit if hit is Dictionary and String((hit as Dictionary)["sign"]) == sign else {}
	if not wv.is_empty() and bool(wv["done"]):
		return wv
	if wv.is_empty():
		if _waves.size() >= WAVES_MAX:
			_waves.clear()
		wv = {"sign": sign, "done": false, "k": 0, "col": -1, "up": 0, "dn": 0, "w": pow(2.0, float(level)), "t": PackedFloat64Array(), "pts": PackedVector2Array()}
		_waves[key] = wv
	_build_waves(canvas, wv, base, m, log_mode, gain)
	if bool(wv["done"]):
		return wv
	stats["put_off"] = int(stats["put_off"]) + 1
	canvas.queue_redraw()
	for step: int in range(1, 13):
		for other: int in [level - step, level + step]:
			var o: Variant = _waves.get(prefix + str(other), null)
			if o is Dictionary and bool((o as Dictionary)["done"]) and String((o as Dictionary)["sign"]) == sign:
				return o
	return {}


static func amp_table(log_mode: bool, gain: float) -> PackedFloat32Array:
	var key: String = str(log_mode) + "|" + str(gain)
	var hit: Variant = _amp_tables.get(key, null)
	if hit is PackedFloat32Array:
		return hit
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(256)
	for i: int in 256:
		out[i] = amp(i, log_mode, gain)
	_amp_tables[key] = out
	return out


static func _build_waves(canvas: Control, wv: Dictionary, base: Dictionary, m: Dictionary, log_mode: bool, gain: float) -> void:
	var deadline: int = _deadline(canvas)
	var t0: int = Time.get_ticks_usec()
	if t0 >= deadline:
		return
	var w: float = float(wv["w"])
	var starts: PackedFloat64Array = base["clip_starts"]
	var ends: PackedFloat64Array = base["clip_ends"]
	var hs: PackedInt32Array = m["h"]
	var streams: PackedInt32Array = m["stream"]
	var src0: PackedFloat64Array = m["src0"]
	var src1: PackedFloat64Array = m["src1"]
	var durs: PackedFloat64Array = m["dur"]
	var loops: Dictionary = m.get("loops", {})
	var times: PackedFloat64Array = wv["t"]
	var pts: PackedVector2Array = wv["pts"]
	var amps: PackedFloat32Array = amp_table(log_mode, gain)
	var n: int = mini(starts.size(), hs.size())
	var k: int = int(wv["k"])
	var cur_col: int = int(wv["col"])
	var cur_up: int = int(wv["up"])
	var cur_dn: int = int(wv["dn"])
	var pyrs: Dictionary = {}
	var last_key: int = -2147483647
	var ups: Array = []
	var dns: Array = []
	var pn: int = 0
	var rate: float = coarse_rate()
	var inv_ln2: float = 1.0 / log(2.0)
	while k < n:
		if (k & 15) == 15 and Time.get_ticks_usec() >= deadline:
			break
		var s0: float = starts[k]
		var e0: float = ends[k]
		var pk_key: int = hs[k] * 64 + streams[k]
		if pk_key != last_key:
			var pv: Variant = pyrs.get(pk_key, null)
			if not (pv is Dictionary):
				pv = pyramid(canvas, hs[k], streams[k], durs[k])
				pyrs[pk_key] = pv
			var pyr: Dictionary = pv
			last_key = pk_key
			pn = 0 if pyr.is_empty() else int(pyr["n"])
			if pn > 0:
				ups = pyr["up"]
				dns = pyr["dn"]
		var a: float = src0[k]
		var b: float = src1[k]
		k += 1
		if pn <= 0:
			continue
		var top: int = ups.size() - 1
		var spans: Variant = loops.get(k - 1, null) if not loops.is_empty() else null
		var n_sp: int = 1 if spans == null else (spans as PackedFloat64Array).size() / 4
		for si: int in n_sp:
			if spans != null:
				var sv: PackedFloat64Array = spans
				s0 = sv[si * 4]
				e0 = sv[si * 4 + 1]
				a = sv[si * 4 + 2]
				b = sv[si * 4 + 3]
			var len_t: float = maxf(e0 - s0, 0.000001)
			var slope: float = (b - a) / len_t
			var c0: int = int(floor(s0 / w))
			var c1: int = maxi(int(ceil(e0 / w)) - 1, c0)
			for col: int in range(c0, c1 + 1):
				var ta: float = maxf(float(col) * w, s0)
				var tb: float = minf(float(col + 1) * w, e0)
				if tb <= ta and c1 > c0:
					continue
				var sa: float = a + (ta - s0) * slope
				var sb: float = a + (tb - s0) * slope
				var b0: int = clampi(int(floor(minf(sa, sb) * rate)), 0, pn - 1)
				var b1: int = clampi(int(ceil(maxf(sa, sb) * rate)), b0 + 1, pn)
				var span: int = b1 - b0
				var p: int = 0
				if span > 1:
					p = int(log(float(span)) * inv_ln2)
					if (1 << (p + 1)) <= span:
						p += 1
					elif (1 << p) > span:
						p -= 1
					p = mini(p, top)
				var lu: PackedByteArray = ups[p]
				var ld: PackedByteArray = dns[p]
				var i0: int = b0 >> p
				var i1: int = mini((b1 - 1) >> p, lu.size() - 1)
				var u: int = 0
				var d: int = 0
				for i: int in range(i0, i1 + 1):
					if lu[i] > u:
						u = lu[i]
					if ld[i] > d:
						d = ld[i]
				if col == cur_col:
					if u > cur_up:
						cur_up = u
					if d > cur_dn:
						cur_dn = d
					continue
				if cur_col >= 0:
					var tm: float = (float(cur_col) + 0.5) * w
					times.append(tm)
					pts.append(Vector2(tm, -amps[mini(cur_up, 255)]))
					pts.append(Vector2(tm, amps[mini(cur_dn, 255)]))
				cur_col = col
				cur_up = u
				cur_dn = d
	if k >= n and cur_col >= 0:
		var tm2: float = (float(cur_col) + 0.5) * w
		times.append(tm2)
		pts.append(Vector2(tm2, -amps[mini(cur_up, 255)]))
		pts.append(Vector2(tm2, amps[mini(cur_dn, 255)]))
		cur_col = -1
	wv["t"] = times
	wv["pts"] = pts
	wv["k"] = k
	wv["col"] = cur_col
	wv["up"] = cur_up
	wv["dn"] = cur_dn
	wv["done"] = k >= n
	stats["build_usec"] = int(stats["build_usec"]) + Time.get_ticks_usec() - t0


static func draw_lane_waves(canvas: Control, t: Track, base: Dictionary, level: int, lane_y: float, lane_h: float, t_lo: float, t_hi: float) -> void:
	if lane_h < float(Tk.px(WAVE_MIN_H)):
		return
	_tick(canvas)
	var wv: Dictionary = lane_waves(canvas, t, base, level)
	if wv.is_empty():
		return
	var times: PackedFloat64Array = wv["t"]
	var a: int = times.bsearch(t_lo, true)
	var b: int = times.bsearch(t_hi, false)
	if b <= a:
		return
	var pps: float = float(canvas.get("pps"))
	var band: Rect2 = wave_band(Rect2(0.0, lane_y + 1.0, 1.0, lane_h - 2.0), Paint.name_row_h())
	if band.size.y < 4.0:
		return
	var h: float = band.size.y
	var centre_y: float = band.position.y + h * 0.5
	var origin_x: float = float(canvas.get("header_w")) - float(canvas.get("scroll_x"))
	var lk: Dictionary = WaveLook.look()
	var wave_base: Color = WaveLook.base_colour(lk, -1, -1, t.colour)
	var sc: Dictionary = WaveLook.scale(bool(canvas.get("wave_log")), float(canvas.get("wave_gain")))
	var cols: Dictionary = WaveLook.columns_cached(wv, wv["pts"], wave_base, sc, pps, h * 0.5 - 1.0, lane_volume(canvas, t))
	canvas.draw_set_transform(Vector2(origin_x, centre_y), 0.0, Vector2(pps, h * 0.5 - 1.0))
	WaveLook.draw_columns(canvas, cols, a, b)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	stats["wave_lanes"] = int(stats["wave_lanes"]) + 1


static func draw_lane_frames(canvas: Control, t: Track, base: Dictionary, cov_s: PackedFloat64Array, cov_e: PackedFloat64Array, lane_y: float, lane_h: float, t_lo: float, t_hi: float) -> void:
	if not PurrBridge.available or lane_h < float(Tk.px(THUMB_MIN_H)):
		return
	var pictures: String = String(canvas.call("clip_pictures"))
	if pictures == "none":
		return
	var d: Project = canvas.call("doc")
	if d == null:
		return
	_tick(canvas)
	var m: Dictionary = clip_map(canvas, d, t)
	if not bool(m["done"]):
		return
	var hs: PackedInt32Array = m["h"]
	var src0: PackedFloat64Array = m["src0"]
	var src1: PackedFloat64Array = m["src1"]
	var aspects: PackedFloat32Array = m["aspect"]
	var loops: Dictionary = m.get("loops", {})
	var starts: PackedFloat64Array = base["clip_starts"]
	var ends: PackedFloat64Array = base["clip_ends"]
	var pps: float = float(canvas.get("pps"))
	var hw: float = float(canvas.get("header_w"))
	var origin_x: float = hw - float(canvas.get("scroll_x"))
	var band: Rect2 = picture_band(Rect2(hw, lane_y + 1.0, canvas.size.x - hw, lane_h - 2.0))
	if band.size.y < 4.0:
		return
	var step: float = maxf(band.size.y * 16.0 / 9.0, 24.0)
	var a: int = cov_e.bsearch(t_lo, false)
	var b: int = cov_s.bsearch(t_hi, true)
	var tiles: int = 0
	for q: int in range(a, b):
		var sx0: float = origin_x + cov_s[q] * pps
		var sx1: float = origin_x + cov_e[q] * pps
		var x: float = sx0
		if x < hw - step:
			x = sx0 + floor((hw - sx0) / step) * step
		var first: bool = true
		while x < minf(sx1, canvas.size.x) and tiles < TILES_MAX:
			var xe: float = minf(x + step, sx1)
			var ca: float = maxf(x, hw)
			var cb: float = minf(xe, canvas.size.x)
			if cb > ca:
				var tm: float = ((ca + cb) * 0.5 - origin_x) / pps
				var k: int = starts.bsearch(tm, false) - 1
				if k < 0 or ends[k] < tm:
					k = mini(k + 1, starts.size() - 1)
				if k >= 0 and k < hs.size() and has_strip(hs[k]):
					var len_t: float = maxf(ends[k] - starts[k], 0.000001)
					var u: float = clampf((tm - starts[k]) / len_t, 0.0, 1.0)
					var at_src: float = src0[k] + u * (src1[k] - src0[k])
					if not loops.is_empty() and loops.has(k):
						at_src = span_source(loops[k], tm, at_src)
					var tex: RID = PurrBridge.strip_frame(hs[k], at_src)
					draw_frame(canvas, tex, Rect2(ca, band.position.y, cb - ca, band.size.y), float(aspects[k]))
					tiles += 1
				if not first and x > hw:
					canvas.draw_rect(Rect2(x, band.position.y, 1.0, band.size.y), TILE_LINE, true)
			first = false
			if pictures == "head":
				break
			x += step
	stats["tiles"] = int(stats["tiles"]) + tiles


static func span_source(spans: PackedFloat64Array, t: float, fallback: float) -> float:
	for i: int in range(0, spans.size(), 4):
		if t >= spans[i] and t <= spans[i + 1]:
			var len_t: float = maxf(spans[i + 1] - spans[i], 0.000001)
			return spans[i + 2] + (t - spans[i]) / len_t * (spans[i + 3] - spans[i + 2])
	return fallback
