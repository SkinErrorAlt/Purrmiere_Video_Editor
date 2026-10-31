extends Control

const PmUI := preload("res://ui/kit/pm_ui.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const ExportJob := preload("res://modules/export/export_job.gd")
const SELF_PATH := "res://modules/export/audio_visualiser.gd"
const PREF_LOOK := "export.visualiser"
const PREF_LABEL := "Export: how the sound looks while an audio only export runs"
const LOOK_BARS := "bars"
const LOOK_CIRCLE := "circle"
const LOOK_WAVE := "wave"
const LOOKS: PackedStringArray = ["bars", "circle", "wave"]
const BAR_COUNT := 12
const RING_POINTS := 48
const WAVE_POINTS := 72
const WINDOW_SECONDS := 0.2
const MAX_WINDOW_FRAMES := 12000
const TARGET_SAMPLES := 2400
const POLL_MS := 70
const BOX_H := 120.0
const FLOOR_DB := -54.0
const SMOOTH := 0.45
const HEADER_MIN := 44
const QUIET_FLOOR := 0.0005
const TIP_TEXT := "The sound already written for this export, at the point it has reached. Settings has export.visualiser for the three looks: bars, circle, wave."

var _look: String = LOOK_BARS
var _values: PackedFloat32Array = PackedFloat32Array()
var _line: float = 0.5
var _path: String = ""
var _head: Dictionary = {}
var _total: float = 0.0
var _kbps: int = 0
var _polled_ms: int = 0


static func attach(parent: Control) -> Control:
	if parent == null:
		return null
	var made: Control = load(SELF_PATH).new()
	parent.add_child(made)
	return made


func _ready() -> void:
	name = "ExportAudioVisualiser"
	custom_minimum_size.y = float(Tk.px(BOX_H))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	register()
	_look = look()
	PmUI.tip(self, TIP_TEXT)
	var p: Node = prefs_node()
	if p != null and not p.is_connected("changed", _on_pref_changed):
		p.connect("changed", _on_pref_changed)
	set_process(true)


func _on_pref_changed(key: String) -> void:
	if key != PREF_LOOK:
		return
	_look = look()
	_values = PackedFloat32Array()
	queue_redraw()


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


static func register() -> void:
	var p: Node = prefs_node()
	if p == null:
		return
	if not bool(p.call("is_registered", PREF_LOOK)):
		p.call("register", PREF_LOOK, LOOK_BARS, {"label": PREF_LABEL, "type": "enum", "choices": Array(LOOKS)})


static func look() -> String:
	var p: Node = prefs_node()
	if p == null:
		return LOOK_BARS
	register()
	return normalise_look(String(p.call("get_value", PREF_LOOK)))


static func set_look(v: String) -> void:
	var p: Node = prefs_node()
	if p == null:
		return
	register()
	p.call("set_value", PREF_LOOK, normalise_look(v))


static func normalise_look(v: String) -> String:
	var low: String = v.strip_edges().to_lower()
	return low if LOOKS.has(low) else LOOK_BARS


static func point_count(which: String) -> int:
	var low: String = normalise_look(which)
	if low == LOOK_CIRCLE:
		return RING_POINTS
	if low == LOOK_WAVE:
		return WAVE_POINTS
	return BAR_COUNT


static func loud_of(level: float) -> float:
	if level <= QUIET_FLOOR:
		return 0.0
	var db: float = linear_to_db(clampf(level, 0.0, 1.0))
	return clampf((db - FLOOR_DB) / -FLOOR_DB, 0.0, 1.0)


static func spread_of(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var low: float = values[0]
	var high: float = values[0]
	for v: float in values:
		low = minf(low, v)
		high = maxf(high, v)
	return high - low


static func _slice_end(band: int, bands: int, count: int) -> int:
	var from_i: int = int(float(band) * float(count) / float(bands))
	return maxi(int(float(band + 1) * float(count) / float(bands)), from_i + 1)


static func _slice_start(band: int, bands: int, count: int) -> int:
	return int(float(band) * float(count) / float(bands))


static func bar_levels(samples: PackedFloat32Array, bands: int) -> PackedFloat32Array:
	var n: int = maxi(bands, 1)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	if samples.is_empty():
		return out
	for b: int in n:
		var from_i: int = _slice_start(b, n, samples.size())
		var to_i: int = mini(_slice_end(b, n, samples.size()), samples.size())
		var peak: float = 0.0
		for i: int in range(from_i, to_i):
			peak = maxf(peak, absf(samples[i]))
		out[b] = loud_of(peak)
	return out


static func ring_levels(samples: PackedFloat32Array, points: int) -> PackedFloat32Array:
	var n: int = maxi(points, 3)
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(n)
	if samples.is_empty():
		return raw
	for b: int in n:
		var from_i: int = _slice_start(b, n, samples.size())
		var to_i: int = mini(_slice_end(b, n, samples.size()), samples.size())
		var sum: float = 0.0
		var taken: int = 0
		for i: int in range(from_i, to_i):
			sum += samples[i] * samples[i]
			taken += 1
		raw[b] = loud_of(sqrt(sum / float(maxi(taken, 1))))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for b: int in n:
		var before: float = raw[(b - 1 + n) % n]
		var after: float = raw[(b + 1) % n]
		out[b] = (before + raw[b] * 2.0 + after) * 0.25
	return out


static func wave_points(samples: PackedFloat32Array, points: int) -> PackedFloat32Array:
	var n: int = maxi(points, 2)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	if samples.is_empty():
		return out
	for b: int in n:
		var from_i: int = _slice_start(b, n, samples.size())
		var to_i: int = mini(_slice_end(b, n, samples.size()), samples.size())
		var best: float = 0.0
		for i: int in range(from_i, to_i):
			if absf(samples[i]) > absf(best):
				best = samples[i]
		out[b] = clampf(best, -1.0, 1.0)
	return out


static func values_for(which: String, samples: PackedFloat32Array) -> PackedFloat32Array:
	var low: String = normalise_look(which)
	if low == LOOK_CIRCLE:
		return ring_levels(samples, RING_POINTS)
	if low == LOOK_WAVE:
		return wave_points(samples, WAVE_POINTS)
	return bar_levels(samples, BAR_COUNT)


static func blended(old_values: PackedFloat32Array, new_values: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	if old_values.size() != new_values.size():
		return new_values
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(new_values.size())
	var a: float = clampf(amount, 0.0, 1.0)
	for i: int in new_values.size():
		out[i] = lerpf(old_values[i], new_values[i], a)
	return out


static func _one_sample(data: PackedByteArray, at: int, bits: int) -> float:
	if bits == 8:
		return (float(data.decode_u8(at)) - 128.0) / 128.0
	if bits == 16:
		return float(data.decode_s16(at)) / 32768.0
	if bits == 24:
		var raw: int = int(data.decode_u8(at)) | (int(data.decode_u8(at + 1)) << 8) | (int(data.decode_u8(at + 2)) << 16)
		if raw >= 8388608:
			raw -= 16777216
		return float(raw) / 8388608.0
	if bits == 32:
		return float(data.decode_s32(at)) / 2147483648.0
	return 0.0


static func mono_from(data: PackedByteArray, channels: int, bits: int, stride: int = 1) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var ch: int = maxi(channels, 1)
	var wide: int = bits / 8
	if wide < 1 or wide > 4:
		return out
	var frame: int = ch * wide
	var count: int = data.size() / frame
	var step: int = maxi(stride, 1)
	if count <= 0:
		return out
	var taken: int = int(ceil(float(count) / float(step)))
	out.resize(taken)
	for i: int in taken:
		var base: int = i * step * frame
		var sum: float = 0.0
		for c: int in ch:
			sum += _one_sample(data, base + c * wide, bits)
		out[i] = sum / float(ch)
	return out


static func header_of(path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "rate": 48000, "channels": 2, "bits": 16, "at": 0, "length": 0, "why": ""}
	if path.is_empty() or not FileAccess.file_exists(path):
		out["why"] = "the file is not there: " + path
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["why"] = "the file could not be opened: " + path
		return out
	var size: int = int(f.get_length())
	if size < HEADER_MIN or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		f.close()
		out["why"] = "not a RIFF file: " + path
		return out
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		f.close()
		out["why"] = "not a WAVE file: " + path
		return out
	while f.get_position() + 8 <= size:
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var length: int = int(f.get_32())
		var here: int = int(f.get_position())
		if id == "fmt ":
			f.get_16()
			out["channels"] = int(f.get_16())
			out["rate"] = int(f.get_32())
			f.get_32()
			f.get_16()
			out["bits"] = int(f.get_16())
		elif id == "data":
			var left: int = size - here
			out["at"] = here
			out["length"] = length if length > 0 and length <= left else left
			out["ok"] = int(out["length"]) > 0
			break
		if length <= 0 or here + length > size:
			break
		f.seek(here + length + (length % 2))
	f.close()
	if not bool(out["ok"]):
		out["why"] = "no sound in " + path
	return out


static func total_seconds(head: Dictionary) -> float:
	if not bool(head.get("ok", false)):
		return 0.0
	var frame: int = maxi(int(head.get("channels", 2)) * (int(head.get("bits", 16)) / 8), 1)
	var rate: int = maxi(int(head.get("rate", 48000)), 1)
	return float(int(head.get("length", 0)) / frame) / float(rate)


static func window_from(head: Dictionary, path: String, at_seconds: float, window_seconds: float) -> Dictionary:
	var out: Dictionary = {"ok": false, "samples": PackedFloat32Array(), "seconds": 0.0, "from": 0.0, "to": 0.0, "at": 0.0}
	if not bool(head.get("ok", false)):
		return out
	var rate: int = maxi(int(head.get("rate", 48000)), 1)
	var channels: int = maxi(int(head.get("channels", 2)), 1)
	var bits: int = int(head.get("bits", 16))
	var wide: int = bits / 8
	if wide < 1 or wide > 4:
		return out
	var frame: int = channels * wide
	var frames: int = int(head.get("length", 0)) / frame
	if frames <= 0:
		return out
	var want: int = mini(clampi(int(window_seconds * float(rate)), 2, MAX_WINDOW_FRAMES), frames)
	var centre: int = clampi(int(at_seconds * float(rate)), 0, frames)
	var start: int = clampi(centre - want / 2, 0, maxi(frames - want, 0))
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	f.seek(int(head.get("at", 0)) + start * frame)
	var data: PackedByteArray = f.get_buffer(want * frame)
	f.close()
	var samples: PackedFloat32Array = mono_from(data, channels, bits, maxi(want / TARGET_SAMPLES, 1))
	out["samples"] = samples
	out["ok"] = not samples.is_empty()
	out["seconds"] = float(frames) / float(rate)
	out["from"] = float(start) / float(rate)
	out["to"] = float(start + want) / float(rate)
	out["at"] = clampf(at_seconds, 0.0, float(frames) / float(rate))
	return out


static func window_at(path: String, at_seconds: float, window_seconds: float) -> Dictionary:
	return window_from(header_of(path), path, at_seconds, window_seconds)


static func line_fraction(win: Dictionary) -> float:
	var from_v: float = float(win.get("from", 0.0))
	var to_v: float = float(win.get("to", 0.0))
	if to_v <= from_v:
		return 0.5
	return clampf((float(win.get("at", 0.0)) - from_v) / (to_v - from_v), 0.0, 1.0)


static func audio_only_wanted(settings: Dictionary, containers: Array[Dictionary]) -> bool:
	var container: Dictionary = ExportPresets.container_by_id(containers, String(settings.get("container", "mp4")))
	return not container.is_empty() and ExportPresets.is_audio_only(container)


static func stream_kbps(audio: Dictionary) -> int:
	var codec: String = String(audio.get("codec", ""))
	var rate: int = maxi(int(audio.get("sample_rate", 48000)), 1)
	var ch: int = maxi(int(audio.get("channels", 2)), 1)
	if ExportPresets.PCM_BITS.has(codec):
		return int(round(float(rate) * float(ch) * float(int(ExportPresets.PCM_BITS[codec])) / 1000.0))
	var declared: int = int(audio.get("bitrate_kbps", 0))
	if declared > 0:
		return declared
	return ExportPresets.audio_kbps_of(codec, 0, rate, ch)


static func reached_seconds(stats: Dictionary, total: float, kbps: int) -> float:
	if total <= 0.0:
		return 0.0
	var frames_total: int = int(stats.get("total", 0))
	if frames_total > 0:
		return clampf(total * float(int(stats.get("frames", 0))) / float(frames_total), 0.0, total)
	var expect: float = total * float(maxi(kbps, 0)) * 125.0
	if expect <= 0.0:
		return 0.0
	return clampf(total * float(int(stats.get("bytes", 0))) / expect, 0.0, total)


static func export_job_in(root: Node) -> Node:
	if root == null:
		return null
	for n: Node in root.get_children():
		if n.get_script() == ExportJob and n.has_method("stats"):
			return n
	return null


func _tree_root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _polled_ms < POLL_MS:
		return
	_polled_ms = now
	_poll()


func _poll() -> void:
	var job: Node = export_job_in(_tree_root())
	if job == null:
		if visible:
			visible = false
			_values = PackedFloat32Array()
			_path = ""
			queue_redraw()
		return
	var job_settings: Dictionary = job.get("settings")
	var job_containers: Array[Dictionary] = job.get("containers")
	if not audio_only_wanted(job_settings, job_containers):
		if visible:
			visible = false
		return
	if not visible:
		visible = true
	if String(job.get("state")) != "running":
		return
	var plan: Dictionary = job.get("job")
	var audio: Dictionary = plan.get("audio", {})
	var path: String = String(audio.get("pcm_path", ""))
	if path.is_empty():
		return
	if path != _path:
		_path = path
		_head = header_of(path)
		_total = total_seconds(_head)
		_kbps = stream_kbps(audio)
		_values = PackedFloat32Array()
	if not bool(_head.get("ok", false)):
		return
	var at: float = reached_seconds(job.call("stats"), _total, _kbps)
	var win: Dictionary = window_from(_head, _path, at, WINDOW_SECONDS)
	if not bool(win["ok"]):
		return
	var fresh: PackedFloat32Array = values_for(_look, win["samples"])
	_values = fresh if _look == LOOK_WAVE else blended(_values, fresh, SMOOTH)
	_line = line_fraction(win)
	queue_redraw()


func _draw() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full, Tk.c["bg_lane_audio"], true)
	draw_rect(full, Tk.c["border_soft"], false, 1.0)
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var box: Rect2 = Rect2(full.position + Vector2(pad, pad), full.size - Vector2(pad * 2.0, pad * 2.0))
	if box.size.x <= 2.0 or box.size.y <= 2.0:
		return
	if _values.is_empty():
		draw_rect(Rect2(box.position.x, box.position.y + box.size.y * 0.5, box.size.x, 1.0), Tk.c["wave_line"], true)
		return
	if _look == LOOK_CIRCLE:
		_draw_ring(box)
	elif _look == LOOK_WAVE:
		_draw_wave(box)
	else:
		_draw_bars(box)


func _draw_bars(box: Rect2) -> void:
	var n: int = _values.size()
	var gap: float = maxf(float(Tk.px(Tk.sz("gap"))) * 0.5, 1.0)
	var wide: float = maxf((box.size.x - gap * float(n - 1)) / float(n), 1.0)
	var col: Color = Tk.c["wave"]
	for i: int in n:
		var h: float = maxf(_values[i] * box.size.y, 1.0)
		var x: float = box.position.x + float(i) * (wide + gap)
		draw_rect(Rect2(x, box.position.y + box.size.y - h, wide, h), col, true)


func _draw_ring(box: Rect2) -> void:
	var mid: Vector2 = box.position + box.size * 0.5
	var short_side: float = minf(box.size.x, box.size.y)
	var base: float = short_side * 0.3
	var amp: float = short_side * 0.16
	var n: int = _values.size()
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n + 1)
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = base + _values[i] * amp
		pts[i] = mid + Vector2(cos(a), sin(a)) * r
	pts[n] = pts[0]
	draw_arc(mid, base + amp + 2.0, 0.0, TAU, n, Tk.c["wave_line"], 1.0)
	draw_polyline(pts, Tk.c["wave"], 2.0, true)


func _draw_wave(box: Rect2) -> void:
	var n: int = _values.size()
	var mid_y: float = box.position.y + box.size.y * 0.5
	var amp: float = box.size.y * 0.45
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	for i: int in n:
		var x: float = box.position.x + box.size.x * float(i) / float(maxi(n - 1, 1))
		pts[i] = Vector2(x, mid_y - _values[i] * amp)
	draw_rect(Rect2(box.position.x, mid_y, box.size.x, 1.0), Tk.c["wave_line"], true)
	draw_polyline(pts, Tk.c["wave"], 1.5, true)
	draw_rect(Rect2(box.position.x + box.size.x * _line, box.position.y, 1.0, box.size.y), Tk.c["text_bright"], true)
