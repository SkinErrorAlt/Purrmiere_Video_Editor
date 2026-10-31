extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Project := preload("res://doc/project.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const JOB_KEY := "pair_view"
const PANEL_KEY := "pair_view_export"
const MODE_ONLY := "only"
const MODE_WHOLE := "whole"
const MODES: Array = [["only", "Only where the view is on screen"], ["whole", "Switch the whole video to the view"]]
const JOIN_FADE := 0.002
const EPS := 0.000001
const COPY_FRAMES := 65536
const TAIL_SECONDS := 0.05

var view: int = 0
var mode: String = MODE_ONLY
var view_name: String = ""
var keep_plain: bool = false
var original: Sequence = null
var forced: Sequence = null
var spans: PackedVector2Array = PackedVector2Array()
var forced_count: int = 0
var kept_count: int = 0
var error: String = ""
var _cum: PackedFloat64Array = PackedFloat64Array()
var _comp: Node = null
var _comp_prev: Sequence = null


static func panel_choice(settings: Dictionary) -> Dictionary:
	var raw: Variant = settings.get(PANEL_KEY, {})
	var d: Dictionary = raw if raw is Dictionary else {}
	var skip: Array = d.get("skip", []) if d.get("skip") is Array else []
	var m: String = String(d.get("mode", MODE_ONLY))
	if m != MODE_WHOLE:
		m = MODE_ONLY
	return {"on": bool(d.get("on", false)), "mode": m, "skip": skip.duplicate(), "keep_plain": bool(d.get("keep_plain", false))}


static func pair_entry(c: Clip) -> Dictionary:
	var e: Dictionary = PairLayout.pair_entry(c)
	if e.is_empty() or PairLayout.solo_of(e) >= 0:
		return {}
	return e


static func sources(seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	var list: Array[Track] = seq.picture_tracks()
	var any_solo: bool = false
	for tr: Track in list:
		if tr.solo:
			any_solo = true
	for tr: Track in list:
		if tr.muted or (any_solo and not tr.solo):
			continue
		for c: Clip in tr.clips:
			if not c.enabled or not tr.is_picture(c):
				continue
			var e: Dictionary = pair_entry(c)
			if not e.is_empty():
				out.append({"clip": c, "entry": e, "track": tr})
	return out


static func views_of(seq: Sequence) -> Array[Dictionary]:
	var counts: Array[Dictionary] = []
	var colours: Array[int] = []
	for src: Dictionary in sources(seq):
		var e: Dictionary = src["entry"]
		var n: int = mini(ViewMap.crop_count(e), ViewMap.REGION_MAX)
		var names: PackedStringArray = ViewMap.region_names(e)
		var map: Dictionary = ViewMap.of(e)
		for i: int in n:
			while counts.size() <= i:
				counts.append({})
				colours.append(-1)
			var nm: String = names[i] if i < names.size() else "View " + str(i + 1)
			counts[i][nm] = int(counts[i].get(nm, 0)) + 1
			if colours[i] < 0:
				colours[i] = ViewMap.colour_for(map, i)
	var out: Array[Dictionary] = []
	for i: int in counts.size():
		var best: String = ""
		var best_n: int = -1
		for k: Variant in counts[i].keys():
			if int(counts[i][k]) > best_n:
				best_n = int(counts[i][k])
				best = String(k)
		out.append({"index": i, "name": best, "colour": colours[i]})
	return out


static func merged(list: Array[Vector2]) -> PackedVector2Array:
	var sorted: Array[Vector2] = list.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in sorted:
		if v.y - v.x <= EPS:
			continue
		var n: int = out.size()
		if n > 0 and v.x <= out[n - 1].y + EPS:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, v.y))
		else:
			out.append(v)
	return out


static func within(list: PackedVector2Array, range_v: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in list:
		var a: float = maxf(v.x, range_v.x)
		var b: float = minf(v.y, range_v.y)
		if b - a > EPS:
			out.append(Vector2(a, b))
	return out


static func gaps(covered: PackedVector2Array, range_v: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var at: float = range_v.x
	for v: Vector2 in covered:
		if v.x > at + EPS:
			out.append(Vector2(at, minf(v.x, range_v.y)))
		at = maxf(at, v.y)
		if at >= range_v.y:
			break
	if range_v.y > at + EPS:
		out.append(Vector2(at, range_v.y))
	return out


static func spans_for(seq: Sequence, index: int, range_v: Vector2, with_plain: bool = false) -> PackedVector2Array:
	var raw: Array[Vector2] = []
	var cover: Array[Vector2] = []
	for src: Dictionary in sources(seq):
		var c: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		cover.append(Vector2(c.start, c.end()))
		var st: Array[Dictionary] = ViewMap.steps(e, c)
		for i: int in st.size():
			if int(st[i]["view"]) != index:
				continue
			var a: float = maxf(float(st[i]["t"]), c.start)
			var b: float = minf(float(st[i + 1]["t"]) if i + 1 < st.size() else c.end(), c.end())
			if b - a > EPS:
				raw.append(Vector2(a, b))
	if with_plain:
		raw.append_array(gaps(merged(cover), range_v))
	return within(merged(raw), range_v)


static func total(list: PackedVector2Array) -> float:
	var s: float = 0.0
	for v: Vector2 in list:
		s += v.y - v.x
	return s


static func cumulative(list: PackedVector2Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var acc: float = 0.0
	for v: Vector2 in list:
		out.append(acc)
		acc += v.y - v.x
	out.append(acc)
	return out


static func source_time(list: PackedVector2Array, cum: PackedFloat64Array, out_t: float) -> float:
	var n: int = list.size()
	if n == 0:
		return out_t
	var lo: int = 0
	var hi: int = n - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if cum[mid] - EPS <= out_t:
			lo = mid
		else:
			hi = mid - 1
	var v: Vector2 = list[lo]
	return v.x + clampf(out_t - cum[lo], 0.0, v.y - v.x)


static func out_time(list: PackedVector2Array, cum: PackedFloat64Array, t: float) -> float:
	for i: int in list.size():
		if t >= list[i].x - EPS and t < list[i].y - EPS:
			return cum[i] + maxf(t - list[i].x, 0.0)
	return -1.0


static func forced_copy(seq: Sequence, index: int) -> Dictionary:
	var copy: Sequence = Sequence.from_dict(seq.to_dict())
	var done: int = 0
	var kept: int = 0
	for tr: Track in copy.all_tracks():
		for c: Clip in tr.clips:
			for e: Dictionary in c.effects:
				if String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID or not bool(e.get("enabled", true)) or PairLayout.solo_of(e) >= 0:
					continue
				if index >= ViewMap.crop_count(e):
					kept += 1
					continue
				var params: Dictionary = e.get("params", {})
				params["view"] = AnimProp.make(float(index))
				params["view_mode"] = AnimProp.make(0.0)
				if params.has(ViewMap.GROUPS_KEY):
					params[ViewMap.GROUPS_KEY] = AnimProp.make("")
				e["params"] = params
				done += 1
	copy.invalidate()
	return {"seq": copy, "forced": done, "kept": kept}


static func pieces_without(seq: Sequence, index: int) -> int:
	var n: int = 0
	for src: Dictionary in sources(seq):
		if index >= ViewMap.crop_count(src["entry"]):
			n += 1
	return n


static func file_base(settings: Dictionary, seq: Sequence) -> String:
	var dest: Dictionary = settings.get("destination", {})
	var base: String = String(dest.get("name", "")).strip_edges()
	if base.is_empty():
		base = seq.label if seq != null and not seq.label.is_empty() else "export"
	return base


static func expand(settings: Dictionary, seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var choice: Dictionary = panel_choice(settings)
	var plain: Dictionary = settings.duplicate(true)
	plain.erase(JOB_KEY)
	if not bool(choice["on"]) or seq == null:
		out.append(plain)
		return out
	var views: Array[Dictionary] = views_of(seq)
	if views.is_empty():
		out.append(plain)
		return out
	var range_v: Vector2 = ExportPresets.resolve_range(settings, seq)
	var base: String = file_base(settings, seq)
	var used: Dictionary = {}
	for v: Dictionary in views:
		var i: int = int(v["index"])
		if (choice["skip"] as Array).has(i):
			continue
		if String(choice["mode"]) == MODE_ONLY and spans_for(seq, i, range_v, bool(choice["keep_plain"])).is_empty():
			continue
		var nm: String = String(v["name"])
		var file_name: String = base + " - " + nm
		var k: int = 2
		while used.has(file_name.to_lower()):
			file_name = base + " - " + nm + " " + str(k)
			k += 1
		used[file_name.to_lower()] = true
		var s: Dictionary = settings.duplicate(true)
		s.erase(PANEL_KEY)
		s[JOB_KEY] = {"view": i, "mode": String(choice["mode"]), "name": nm, "keep_plain": bool(choice["keep_plain"])}
		var dest: Dictionary = s.get("destination", {})
		dest["name"] = file_name
		s["destination"] = dest
		out.append(s)
	return out


static func queue_note(settings: Dictionary) -> String:
	var raw: Variant = settings.get(JOB_KEY, null)
	if not (raw is Dictionary):
		return ""
	var d: Dictionary = raw
	var how: String = "only where on screen" if String(d.get("mode", MODE_ONLY)) == MODE_ONLY else "whole video"
	return " (Pair View: " + String(d.get("name", "")) + ", " + how + ")"


static func for_job(settings: Dictionary, seq: Sequence) -> RefCounted:
	var raw: Variant = settings.get(JOB_KEY, null)
	if not (raw is Dictionary) or seq == null:
		return null
	var d: Dictionary = raw
	var script: GDScript = load("res://modules/export/view_export.gd")
	var run: RefCounted = script.new()
	run.call("prepare", seq, int(d.get("view", 0)), String(d.get("mode", MODE_ONLY)), String(d.get("name", "")), bool(d.get("keep_plain", false)), ExportPresets.resolve_range(settings, seq))
	return run


func prepare(seq: Sequence, index: int, mode_: String, name_: String, plain: bool, range_v: Vector2) -> void:
	original = seq
	view = maxi(index, 0)
	mode = MODE_WHOLE if mode_ == MODE_WHOLE else MODE_ONLY
	view_name = name_ if not name_.is_empty() else "View " + str(view + 1)
	keep_plain = plain
	var f: Dictionary = forced_copy(seq, view)
	forced = f["seq"]
	forced_count = int(f["forced"])
	kept_count = int(f["kept"])
	if mode == MODE_ONLY:
		spans = spans_for(seq, view, range_v, keep_plain)
		_cum = cumulative(spans)
		if spans.is_empty():
			error = view_name + " is never on screen in this range, so there is nothing to export for it"


func only() -> bool:
	return mode == MODE_ONLY


func duration(range_v: Vector2) -> float:
	if only():
		return total(spans)
	return range_v.y - range_v.x


func frame_time(n: int, range_v: Vector2, fps: float) -> float:
	if only():
		return source_time(spans, _cum, float(n) / fps)
	return range_v.x + float(n) / fps


func thumb_time(t: float) -> float:
	if only() and not spans.is_empty() and out_time(spans, _cum, t) < 0.0:
		return spans[0].x
	return t


func hold(comp: Node, doc: Project) -> void:
	if comp == null or not comp.has_method("set_sequence"):
		return
	_comp = comp
	_comp_prev = comp.get("seq")
	comp.call("set_sequence", forced, doc)


func release(doc: Project) -> void:
	if _comp == null or not is_instance_valid(_comp):
		_comp = null
		return
	if _comp.get("seq") == forced:
		_comp.call("set_sequence", _comp_prev if _comp_prev != null else original, doc)
	_comp = null


func fix_job(job: Dictionary, fps: float, range_v: Vector2, with_chapters: bool) -> void:
	if not only():
		return
	job["total_frames"] = int(round(total(spans) * fps))
	var chapters: Array = []
	if with_chapters:
		for ch: Variant in ExportPresets.chapters_from(original, range_v):
			var o: float = out_time(spans, _cum, float((ch as Dictionary)["t"]) + range_v.x)
			if o >= 0.0:
				chapters.append({"t": o, "label": String((ch as Dictionary)["label"])})
	job["chapters"] = chapters


func render_audio(bridge: Node, range_v: Vector2, pcm_path: String, rate: int, channels: int) -> bool:
	if not only():
		return bool(bridge.call("render_audio", range_v.x, range_v.y, pcm_path, rate, channels))
	if spans.is_empty():
		return false
	var from_t: float = spans[0].x
	var whole: String = pcm_path.get_basename() + "_whole.wav"
	var ok: bool = bool(bridge.call("render_audio", from_t, spans[spans.size() - 1].y + TAIL_SECONDS, whole, rate, channels))
	if ok:
		ok = cut_wav(whole, from_t, spans, pcm_path, rate)
	if FileAccess.file_exists(whole):
		DirAccess.remove_absolute(whole)
	return ok


static func wav_layout(f: FileAccess) -> Dictionary:
	var out: Dictionary = {"offset": -1, "bytes": 0, "channels": 2, "rate": 48000}
	f.seek(12)
	while f.get_position() + 8 <= f.get_length():
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var size: int = int(f.get_32())
		var at: int = int(f.get_position())
		if id == "fmt ":
			f.get_16()
			out["channels"] = maxi(int(f.get_16()), 1)
			out["rate"] = int(f.get_32())
		elif id == "data":
			out["offset"] = at
			out["bytes"] = mini(size, int(f.get_length()) - at)
			return out
		f.seek(at + size + (size & 1))
	return out


static func wav_header(frames: int, channels: int, rate: int) -> PackedByteArray:
	var data_bytes: int = frames * channels * 2
	var head: PackedByteArray = PackedByteArray()
	head.resize(44)
	head.encode_u32(0, 0x46464952)
	head.encode_u32(4, 36 + data_bytes)
	head.encode_u32(8, 0x45564157)
	head.encode_u32(12, 0x20746d66)
	head.encode_u32(16, 16)
	head.encode_u16(20, 1)
	head.encode_u16(22, channels)
	head.encode_u32(24, rate)
	head.encode_u32(28, rate * channels * 2)
	head.encode_u16(32, channels * 2)
	head.encode_u16(34, 16)
	head.encode_u32(36, 0x61746164)
	head.encode_u32(40, data_bytes)
	return head


static func _fade(buf: PackedByteArray, channels: int, first: int, count: int, span_n: int, fade_n: int, fade_in: bool, fade_out: bool) -> void:
	if fade_n <= 0:
		return
	var ranges: Array[Vector2i] = []
	if fade_in:
		ranges.append(Vector2i(first, mini(first + count, fade_n)))
	if fade_out:
		var lo: int = maxi(first, span_n - fade_n)
		if not ranges.is_empty():
			lo = maxi(lo, ranges[0].y)
		ranges.append(Vector2i(lo, first + count))
	for r: Vector2i in ranges:
		for j: int in range(r.x, r.y):
			var g: float = 1.0
			if fade_in and j < fade_n:
				g = minf(g, (float(j) + 0.5) / float(fade_n))
			if fade_out and j >= span_n - fade_n:
				g = minf(g, (float(span_n - j) - 0.5) / float(fade_n))
			for c: int in channels:
				var at: int = ((j - first) * channels + c) * 2
				buf.encode_s16(at, int(round(float(buf.decode_s16(at)) * g)))


static func cut_wav(src_path: String, from_t: float, list: PackedVector2Array, out_path: String, rate: int) -> bool:
	var f: FileAccess = FileAccess.open(src_path, FileAccess.READ)
	if f == null:
		return false
	var lay: Dictionary = wav_layout(f)
	if int(lay["offset"]) < 0:
		f.close()
		return false
	var ch: int = int(lay["channels"])
	var sr: int = int(lay["rate"]) if int(lay["rate"]) > 0 else rate
	var block: int = ch * 2
	var avail: int = int(lay["bytes"]) / block
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		f.close()
		return false
	out.store_buffer(wav_header(0, ch, sr))
	var fade_n: int = maxi(int(round(JOIN_FADE * float(sr))), 1)
	var acc: float = 0.0
	var written: int = 0
	for i: int in list.size():
		var a: float = list[i].x
		var length: float = list[i].y - a
		var n: int = int(round((acc + length) * float(sr))) - int(round(acc * float(sr)))
		var src0: int = int(round((a - from_t) * float(sr)))
		var fn: int = mini(fade_n, n / 2)
		var k: int = 0
		while k < n:
			var m: int = mini(COPY_FRAMES, n - k)
			var start: int = src0 + k
			var have: int = clampi(avail - start, 0, m)
			var buf: PackedByteArray = PackedByteArray()
			if have > 0 and start >= 0:
				f.seek(int(lay["offset"]) + start * block)
				buf = f.get_buffer(have * block)
			if buf.size() < m * block:
				buf.resize(m * block)
			_fade(buf, ch, k, m, n, fn, i > 0, i < list.size() - 1)
			out.store_buffer(buf)
			k += m
		written += n
		acc += length
	out.seek(0)
	out.store_buffer(wav_header(written, ch, sr))
	out.close()
	f.close()
	return true


func graph_back(doc: Project, handles: Dictionary, bridge: Node) -> void:
	restore_playback_graph(doc, original, handles, bridge)


static func restore_playback_graph(doc: Project, seq: Sequence, handles: Dictionary, bridge: Node) -> void:
	if bridge == null or not bool(bridge.get("available")) or doc == null or seq == null:
		return
	var loop: MainLoop = Engine.get_main_loop()
	var session: Node = (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null
	if session != null and session.get("doc") == doc and session.has_method("push_playback_graph"):
		if String(session.get("audio_owner")).is_empty():
			session.call("push_playback_graph")
		return
	bridge.call("set_audio_graph", AudioGraph.build(doc, seq, handles))
