extends Control
## The spectrogram: time across, frequency up, loudness as colour. Computes only the area on screen, only when
## the view, the settings or the sound change, and only while it can be seen.

signal view_changed
signal seek_requested(source_time: float)
signal settings_changed
signal selection_dragged(from_time: float, to_time: float)

const SpectroGpu := preload("res://modules/core_panels/spectro/spectro_gpu.gd")
const SpectroSource := preload("res://modules/core_panels/spectro/spectro_source.gd")
const PmTextKit := preload("res://ui/kit/pm_text.gd")
const COLOUR_SHADER := preload("res://modules/core_panels/spectro/spectro_colour.gdshader")
const CMAPS: PackedStringArray = ["inferno", "magma", "viridis", "classic", "grey"]
const CMAP_LABELS: PackedStringArray = ["Inferno", "Magma", "Viridis", "Classic", "Grey"]
const SIZES: PackedInt32Array = [256, 512, 1024, 2048, 4096, 8192, 16384]
const OVERLAPS: PackedFloat32Array = [0.0, 0.5, 0.75, 0.875, 0.9375]
const OVERLAP_LABELS: PackedStringArray = ["Every pixel", "50%", "75%", "87.5%", "93.75%"]
const MIN_T_SPAN := 0.0005
const MIN_F_SPAN := 2.0
const LOG_MIN_HZ := 10.0
const RULER_H := 18.0
const AXIS_W := 50.0
const DRAG_PX := 3.0

var t0: float = 0.0
var t1: float = 1.0
var f0: float = 0.0
var f1: float = 24000.0
var log_freq: bool = false
var window_size: int = 4096
var window_kind: String = "hann"
var overlap: float = 0.0
var floor_db: float = -100.0
var range_db: float = 90.0
var cmap: String = "inferno"
var playhead_src: float = NAN
var span_from: float = NAN
var span_to: float = NAN
var sel_from: float = NAN
var sel_to: float = NAN
var message: String = ""
var drag_selects: bool = false

var gpu: RefCounted = null
var length: float = 0.0
var rate: float = 48000.0
var loads: int = 0
var last_db: PackedFloat32Array = PackedFloat32Array()
var last_db_size: Vector2i = Vector2i.ZERO

var _want_path: String = ""
var _want_stream: int = 0
var _want_key: String = ""
var _loaded_key: String = ""
var _direct: Dictionary = {}
var _dirty: bool = true
var _fit_on_load: bool = true
var _image: TextureRect = null
var _over: Control = null
var _mat: ShaderMaterial = null
var _font: Font = null
var _fs: int = 11
var _press_button: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _press_view: Array = []
var _drag: String = ""
var _box_from: Vector2 = Vector2.ZERO
var _box_to: Vector2 = Vector2.ZERO
var _hover: Vector2 = Vector2(-1.0, -1.0)
var _reading: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	custom_minimum_size = Vector2(float(Tk.px(160.0)), float(Tk.px(110.0)))
	_mat = ShaderMaterial.new()
	_mat.shader = COLOUR_SHADER
	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.material = _mat
	_image.visible = false
	add_child(_image)
	_over = _Overlay.new()
	_over.view = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	gui_input.connect(_on_input)
	resized.connect(_on_resized)
	mouse_exited.connect(func() -> void:
		_hover = Vector2(-1.0, -1.0)
		_over.queue_redraw())
	set_process(false)


func _ready() -> void:
	_font = Tk.font("body")
	_fs = Tk.fs(Tk.sz("font_tiny"))
	_apply_colours()
	_on_resized()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE) and is_visible_in_tree():
		_wake()
	elif what == NOTIFICATION_PREDELETE:
		if gpu != null:
			gpu.call("release")


func _exit_tree() -> void:
	if gpu != null:
		gpu.call("release")
		gpu = null
		_loaded_key = ""
		_image.texture = null


func plot_rect() -> Rect2:
	var ax: float = float(Tk.px(AXIS_W))
	var rh: float = float(Tk.px(RULER_H))
	return Rect2(ax, rh, maxf(size.x - ax, 1.0), maxf(size.y - rh, 1.0))


func computes() -> int:
	return int(gpu.get("computes")) if gpu != null else 0


func has_sound() -> bool:
	return gpu != null and bool(gpu.call("has_samples")) and _loaded_key == _want_key and not _want_key.is_empty()


func nyquist() -> float:
	return rate * 0.5


## Follows a file. Nothing is read until the view can be seen.
func set_source(path: String, stream: int) -> void:
	var key: String = "" if path.is_empty() else SpectroSource.key_for(path, stream)
	if key == _want_key and _direct.is_empty():
		return
	_direct = {}
	_want_path = path
	_want_stream = stream
	_want_key = key
	_fit_on_load = true
	message = ""
	_wake()


## Shows these samples directly (a generated sound, or a test signal).
func set_samples(samples: PackedFloat32Array, sample_rate: float, key: String = "") -> void:
	_direct = {"samples": samples, "rate": sample_rate}
	_want_path = ""
	_want_key = key if not key.is_empty() else "direct:" + str(Time.get_ticks_usec())
	_fit_on_load = true
	message = ""
	_wake()


func clear_source() -> void:
	_direct = {}
	_want_path = ""
	_want_key = ""
	message = ""
	_dirty = true
	_image.visible = false
	_over.queue_redraw()
	queue_redraw()


func _wake() -> void:
	_dirty = true
	if is_inside_tree():
		set_process(true)
	queue_redraw()
	if _over != null:
		_over.queue_redraw()


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		set_process(false)
		return
	if _want_key != _loaded_key:
		if not _load():
			set_process(false)
			return
	if _dirty:
		_dirty = false
		_compute()
	set_process(false)


func _ensure_gpu() -> bool:
	if gpu != null:
		return String(gpu.call("error")).is_empty()
	if not SpectroGpu.available():
		message = "The spectrogram needs the GPU renderer"
		return false
	gpu = SpectroGpu.new()
	var err: String = String(gpu.call("error"))
	if not err.is_empty():
		message = err
		return false
	_image.texture = gpu.get("texture")
	return true


func _load() -> bool:
	if _want_key.is_empty():
		return false
	if not _ensure_gpu():
		_over.queue_redraw()
		return false
	var got: Dictionary = _direct
	if got.is_empty():
		var src: RefCounted = SpectroSource.instance()
		if not src.is_connected("source_ready", _on_source_ready):
			src.connect("source_ready", _on_source_ready)
			src.connect("source_failed", _on_source_failed)
		got = src.call("request", _want_path, _want_stream)
		if got.has("error"):
			message = String(got["error"])
			_over.queue_redraw()
			return false
		if got.has("pending"):
			message = "Reading the sound"
			_over.queue_redraw()
			return false
	var samples: PackedFloat32Array = got["samples"]
	rate = float(got.get("rate", 48000.0))
	gpu.call("set_samples", samples, rate)
	length = float(samples.size()) / maxf(rate, 1.0)
	_loaded_key = _want_key
	loads += 1
	message = ""
	if _fit_on_load:
		_fit_on_load = false
		fit()
	else:
		set_view(t0, t1, f0, minf(f1, nyquist()), false)
	_dirty = true
	return true


func _on_source_ready(key: String) -> void:
	if key == _want_key:
		_wake()


func _on_source_failed(key: String, why: String) -> void:
	if key == _want_key:
		message = why
		_over.queue_redraw()


func _on_resized() -> void:
	var r: Rect2 = plot_rect()
	_image.position = r.position
	_image.size = r.size
	_over.position = Vector2.ZERO
	_over.size = size
	_wake()


func _compute() -> void:
	if not has_sound():
		return
	var r: Rect2 = plot_rect()
	var px := Vector2i(maxi(1, int(round(r.size.x))), maxi(1, int(round(r.size.y))))
	gpu.call("set_window", window_size, window_kind)
	gpu.call("set_out_size", px)
	var hop: float = float(int(gpu.get("n"))) * (1.0 - overlap) if overlap > 0.0 else 0.0
	var lo: float = maxf(f0, LOG_MIN_HZ) if log_freq else f0
	if bool(gpu.call("compute", t0, t1, lo, f1, log_freq, hop)):
		_image.visible = true
		_read_back()
	_over.queue_redraw()


func _read_back() -> void:
	if _reading or gpu == null:
		return
	_reading = true
	var want: Vector2i = gpu.get("out_size")
	var serial: int = computes()
	var ok: bool = bool(gpu.call("read_db_async", func(data: PackedFloat32Array) -> void:
		_reading = false
		last_db = data
		last_db_size = want
		_over.queue_redraw()
		if gpu != null and computes() != serial:
			_read_back()))
	if not ok:
		_reading = false


func set_view(a: float, b: float, lo: float, hi: float, emit: bool = true) -> void:
	var span: float = maxf(b - a, MIN_T_SPAN)
	t0 = a
	if length > 0.0:
		t0 = clampf(a, -span * 0.5, maxf(length - span * 0.5, 0.0))
	t1 = t0 + span
	var top: float = nyquist()
	var bottom: float = LOG_MIN_HZ if log_freq else 0.0
	var fs_: float = clampf(hi - lo, MIN_F_SPAN, top - bottom)
	f0 = clampf(lo, bottom, top - fs_)
	f1 = f0 + fs_
	_dirty = true
	_wake()
	if emit:
		view_changed.emit()


func fit() -> void:
	var a: float = 0.0
	var b: float = maxf(length, MIN_T_SPAN)
	if not is_nan(span_from) and not is_nan(span_to) and span_to > span_from:
		a = span_from
		b = span_to
	set_view(a, b, LOG_MIN_HZ if log_freq else 0.0, nyquist())


func fit_time(a: float, b: float) -> void:
	set_view(a, b, f0, f1)


func set_log(on: bool) -> void:
	if on == log_freq:
		return
	log_freq = on
	set_view(t0, t1, maxf(f0, LOG_MIN_HZ) if on else f0, f1)
	settings_changed.emit()


func set_settings(d: Dictionary) -> void:
	window_size = clampi(int(d.get("size", window_size)), 64, 16384)
	window_kind = String(d.get("window", window_kind))
	overlap = clampf(float(d.get("overlap", overlap)), 0.0, 0.97)
	floor_db = float(d.get("floor", floor_db))
	range_db = clampf(float(d.get("range", range_db)), 1.0, 300.0)
	cmap = String(d.get("cmap", cmap))
	if d.has("log"):
		log_freq = bool(d["log"])
	_apply_colours()
	_wake()
	settings_changed.emit()


func settings() -> Dictionary:
	return {"size": window_size, "window": window_kind, "overlap": overlap, "floor": floor_db, "range": range_db, "cmap": cmap, "log": log_freq}


func set_levels(floor_: float, range_: float) -> void:
	floor_db = floor_
	range_db = clampf(range_, 1.0, 300.0)
	_apply_colours()
	settings_changed.emit()


func _apply_colours() -> void:
	_mat.set_shader_parameter("floor_db", floor_db)
	_mat.set_shader_parameter("range_db", range_db)
	_mat.set_shader_parameter("cmap", maxi(CMAPS.find(cmap), 0))
	_over.queue_redraw()


## Sets floor and range from what is on screen: the floor just above the quiet half, the top at the loudest.
func auto_levels() -> bool:
	if last_db.is_empty():
		return false
	var vals := PackedFloat32Array()
	var step: int = maxi(1, last_db.size() / 40000)
	for i: int in range(0, last_db.size(), step):
		var v: float = last_db[i]
		if v > -900.0:
			vals.append(v)
	if vals.size() < 16:
		return false
	vals.sort()
	var mid: float = vals[int(vals.size() * 0.5)]
	var top: float = vals[mini(int(vals.size() * 0.999), vals.size() - 1)]
	set_levels(mid + 3.0, maxf(top - mid - 3.0, 12.0))
	return true


# Mapping between pixels and time or frequency --------------------------------------------------------------------

func time_at(x: float) -> float:
	var r: Rect2 = plot_rect()
	return t0 + (x - r.position.x) / maxf(r.size.x, 1.0) * (t1 - t0)


func x_of(t: float) -> float:
	var r: Rect2 = plot_rect()
	return r.position.x + (t - t0) / maxf(t1 - t0, 1e-9) * r.size.x


func freq_at(y: float) -> float:
	var r: Rect2 = plot_rect()
	var v: float = 1.0 - (y - r.position.y) / maxf(r.size.y, 1.0)
	return freq_of_v(v)


func freq_of_v(v: float) -> float:
	if log_freq:
		var lo: float = maxf(f0, LOG_MIN_HZ)
		return lo * pow(f1 / lo, v)
	return f0 + (f1 - f0) * v


func v_of_freq(f: float) -> float:
	if log_freq:
		var lo: float = maxf(f0, LOG_MIN_HZ)
		return log(maxf(f, 1e-6) / lo) / log(f1 / lo)
	return (f - f0) / maxf(f1 - f0, 1e-9)


func y_of(f: float) -> float:
	var r: Rect2 = plot_rect()
	return r.position.y + (1.0 - v_of_freq(f)) * r.size.y


func db_at(p: Vector2) -> float:
	var r: Rect2 = plot_rect()
	if last_db.is_empty() or not r.has_point(p):
		return NAN
	var x: int = int(p.x - r.position.x)
	var y: int = int(p.y - r.position.y)
	if x < 0 or y < 0 or x >= last_db_size.x or y >= last_db_size.y:
		return NAN
	var i: int = y * last_db_size.x + x
	return last_db[i] if i < last_db.size() else NAN


# Zoom and pan -----------------------------------------------------------------------------------------------------

func zoom_time(factor: float, pivot: float = NAN) -> void:
	var p: float = (t0 + t1) * 0.5 if is_nan(pivot) else pivot
	var span: float = clampf((t1 - t0) * factor, MIN_T_SPAN, maxf(length * 1.2, MIN_T_SPAN))
	var frac: float = (p - t0) / maxf(t1 - t0, 1e-9)
	set_view(p - span * frac, p - span * frac + span, f0, f1)


func zoom_freq(factor: float, pivot_v: float = 0.5) -> void:
	if log_freq:
		var lo: float = maxf(f0, LOG_MIN_HZ)
		var l0: float = log(lo)
		var l1: float = log(f1)
		var lp: float = lerpf(l0, l1, pivot_v)
		var ls: float = (l1 - l0) * factor
		var top_l: float = log(nyquist())
		ls = clampf(ls, 0.0005, top_l - log(LOG_MIN_HZ))
		var a: float = lp - ls * pivot_v
		set_view(t0, t1, exp(a), exp(a + ls))
		return
	var p: float = lerpf(f0, f1, pivot_v)
	var span: float = (f1 - f0) * factor
	set_view(t0, t1, p - span * pivot_v, p - span * pivot_v + span)


func pan_by_pixels(d: Vector2, from_view: Array) -> void:
	var r: Rect2 = plot_rect()
	var a: float = float(from_view[0])
	var b: float = float(from_view[1])
	var lo: float = float(from_view[2])
	var hi: float = float(from_view[3])
	var dt: float = -d.x / maxf(r.size.x, 1.0) * (b - a)
	var dv: float = d.y / maxf(r.size.y, 1.0)
	if log_freq:
		var l0: float = log(maxf(lo, LOG_MIN_HZ))
		var l1: float = log(hi)
		var shift: float = dv * (l1 - l0)
		var top_l: float = log(nyquist())
		var bot_l: float = log(LOG_MIN_HZ)
		shift = clampf(shift, bot_l - l0, top_l - l1)
		set_view(a + dt, b + dt, exp(l0 + shift), exp(l1 + shift))
		return
	var df: float = dv * (hi - lo)
	df = clampf(df, -lo, nyquist() - hi)
	set_view(a + dt, b + dt, lo + df, hi + df)


func zoom_to_box(a: Vector2, b: Vector2) -> void:
	var r: Rect2 = plot_rect()
	var x0: float = clampf(minf(a.x, b.x), r.position.x, r.end.x)
	var x1: float = clampf(maxf(a.x, b.x), r.position.x, r.end.x)
	var y0: float = clampf(minf(a.y, b.y), r.position.y, r.end.y)
	var y1: float = clampf(maxf(a.y, b.y), r.position.y, r.end.y)
	if x1 - x0 < 2.0 and y1 - y0 < 2.0:
		return
	var ta: float = time_at(x0)
	var tb: float = time_at(x1)
	var fa: float = freq_at(y1)
	var fb: float = freq_at(y0)
	if x1 - x0 < 2.0:
		ta = t0
		tb = t1
	if y1 - y0 < 2.0:
		fa = f0
		fb = f1
	set_view(ta, tb, fa, fb)


func _view_now() -> Array:
	return [t0, t1, f0, f1]


func _zone(p: Vector2) -> String:
	var r: Rect2 = plot_rect()
	if p.x < r.position.x and p.y >= r.position.y:
		return "freq_axis"
	if p.y < r.position.y and p.x >= r.position.x:
		return "ruler"
	return "plot" if r.has_point(p) else ""


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var r: Rect2 = plot_rect()
		var v: float = clampf(1.0 - (mb.position.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not mb.pressed or not has_sound():
				return
			var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
			var zone: String = _zone(mb.position)
			var factor: float = 0.8 if up else 1.25
			if zone == "freq_axis" or mb.shift_pressed:
				zoom_freq(factor, v)
			elif mb.ctrl_pressed or mb.meta_pressed:
				var span: float = t1 - t0
				set_view(t0 + span * (-0.1 if up else 0.1), t1 + span * (-0.1 if up else 0.1), f0, f1)
			elif mb.alt_pressed:
				pan_by_pixels(Vector2(0.0, (1.0 if up else -1.0) * r.size.y * 0.1), _view_now())
			else:
				zoom_time(factor, time_at(mb.position.x))
			accept_event()
			return
		if mb.pressed:
			grab_focus()
			if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
				fit()
				_press_button = 0
				accept_event()
				return
			if _press_button != 0:
				return
			_press_button = mb.button_index
			_press_pos = mb.position
			_press_view = _view_now()
			_drag = ""
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_drag = "pan"
			elif mb.button_index == MOUSE_BUTTON_RIGHT or (mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed):
				_drag = "box"
				_box_from = mb.position
				_box_to = mb.position
			accept_event()
			return
		if mb.button_index != _press_button:
			return
		if _drag == "box":
			if _box_from.distance_to(_box_to) >= DRAG_PX:
				zoom_to_box(_box_from, _box_to)
		elif _drag == "" and _press_button == MOUSE_BUTTON_LEFT and _zone(mb.position) != "freq_axis":
			seek_requested.emit(time_at(mb.position.x))
		_press_button = 0
		_drag = ""
		_over.queue_redraw()
		accept_event()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_hover = mm.position
		if _press_button != 0:
			if _drag == "box":
				_box_to = mm.position
			elif _drag == "select" or (_drag == "" and drag_selects and _press_button == MOUSE_BUTTON_LEFT and mm.position.distance_to(_press_pos) >= DRAG_PX):
				_drag = "select"
				selection_dragged.emit(time_at(_press_pos.x), time_at(mm.position.x))
			elif _drag == "pan" or mm.position.distance_to(_press_pos) >= DRAG_PX:
				_drag = "pan"
				pan_by_pixels(mm.position - _press_pos, _press_view)
			accept_event()
		_over.queue_redraw()


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or not has_sound():
		return false
	if e.keycode == KEY_F and not e.ctrl_pressed:
		fit()
		return true
	if e.keycode == KEY_EQUAL or e.keycode == KEY_KP_ADD:
		if e.shift_pressed:
			zoom_freq(0.5)
		else:
			zoom_time(0.5)
		return true
	if e.keycode == KEY_MINUS or e.keycode == KEY_KP_SUBTRACT:
		if e.shift_pressed:
			zoom_freq(2.0)
		else:
			zoom_time(2.0)
		return true
	return false


# Drawing ----------------------------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
	var r: Rect2 = plot_rect()
	draw_rect(r, Color(0.0, 0.0, 0.0, 1.0), true)


static func nice_step(span: float, room_px: float, min_px: float) -> float:
	var raw: float = span * min_px / maxf(room_px, 1.0)
	var mag: float = pow(10.0, floor(log(maxf(raw, 1e-12)) / log(10.0)))
	for m: float in [1.0, 2.0, 5.0, 10.0]:
		if m * mag >= raw:
			return m * mag
	return 10.0 * mag


static func time_text(t: float, step: float) -> String:
	var neg: bool = t < 0.0
	var a: float = absf(t)
	var digits: int = clampi(int(ceil(-log(maxf(step, 1e-9)) / log(10.0))), 0, 6)
	var text: String = ""
	if a >= 60.0:
		var m: int = int(a / 60.0)
		var s: float = a - float(m) * 60.0
		text = str(m) + ":" + ("%0*.*f" % [digits + (3 if digits > 0 else 2), digits, s])
	else:
		text = ("%.*f" % [digits, a]) + "s"
	return ("-" if neg else "") + text


static func freq_text(f: float, step: float = 0.0) -> String:
	if f >= 1000.0:
		if step <= 0.0:
			var k: float = f / 1000.0
			return (str(int(round(k))) if absf(k - round(k)) < 0.001 else String.num(k, 2)) + "k"
		var d: int = clampi(int(ceil(-log(maxf(step / 1000.0, 1e-9)) / log(10.0))), 0, 3)
		return ("%.*f" % [d, f / 1000.0]) + "k"
	if step > 0.0 and step < 1.0:
		return "%.1f" % f
	return str(int(round(f)))


func freq_ticks() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var r: Rect2 = plot_rect()
	var min_px: float = float(Tk.px(26.0))
	if not log_freq:
		var step: float = nice_step(f1 - f0, r.size.y, min_px)
		var f: float = ceil(f0 / step) * step
		while f <= f1 + step * 0.001:
			out.append(f)
			f += step
		return out
	var lo: float = maxf(f0, LOG_MIN_HZ)
	var last_y: float = INF
	var dec: float = pow(10.0, floor(log(lo) / log(10.0)))
	while dec <= f1:
		for m: float in [1.0, 2.0, 5.0]:
			var fv: float = dec * m
			if fv < lo or fv > f1:
				continue
			var y: float = y_of(fv)
			if last_y - y >= min_px:
				out.append(fv)
				last_y = y
		dec *= 10.0
	if out.size() < 2:
		var step2: float = nice_step(f1 - lo, r.size.y, min_px)
		out.clear()
		var f2: float = ceil(lo / step2) * step2
		while f2 <= f1:
			out.append(f2)
			f2 += step2
	return out


class _Overlay:
	extends Control

	const PmText := preload("res://ui/kit/pm_text.gd")

	var view: Control = null

	func _draw() -> void:
		var v: Control = view
		var r: Rect2 = v.call("plot_rect")
		var font: Font = Tk.font("mono")
		var fs: int = Tk.fs(Tk.sz("font_tiny"))
		var msg: String = String(v.get("message"))
		if not bool(v.call("has_sound")):
			var text: String = msg if not msg.is_empty() else "Select an audio clip or a sound in the bin"
			PmText.draw(self, Tk.font("body"), Rect2(r.position, Vector2(r.size.x, 24.0)), text, Tk.fs(Tk.sz("font_small")), Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, r.position.y + 18.0)
			_draw_axes(v, r, font, fs, false)
			return
		_shade_outside(v, r)
		_draw_selection(v, r)
		_draw_axes(v, r, font, fs, true)
		var ph: float = float(v.get("playhead_src"))
		if not is_nan(ph):
			var px: float = float(v.call("x_of", ph))
			if px >= r.position.x and px <= r.end.x:
				draw_rect(Rect2(round(px), 0.0, 1.0, size.y), Tk.c["sol"], true)
		if String(v.get("_drag")) == "box":
			var a: Vector2 = v.get("_box_from")
			var b: Vector2 = v.get("_box_to")
			var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
			draw_rect(box, Color(Tk.c["sol"], 0.15), true)
			draw_rect(box, Tk.c["sol"], false, 1.0)
		var hv: Vector2 = v.get("_hover")
		if hv.x >= 0.0 and r.has_point(hv) and String(v.get("_drag")) != "pan":
			var line: Color = Color(1.0, 1.0, 1.0, 0.35)
			draw_rect(Rect2(round(hv.x), r.position.y, 1.0, r.size.y), line, true)
			draw_rect(Rect2(r.position.x, round(hv.y), r.size.x, 1.0), line, true)
			_draw_readout(v, r, hv, font, fs)

	func _shade_outside(v: Control, r: Rect2) -> void:
		var length: float = float(v.get("length"))
		var dim := Color(0.0, 0.0, 0.0, 0.55)
		var a: float = float(v.call("x_of", 0.0))
		var b: float = float(v.call("x_of", length))
		var sf: float = float(v.get("span_from"))
		var st: float = float(v.get("span_to"))
		if not is_nan(sf) and not is_nan(st) and st > sf:
			a = maxf(a, float(v.call("x_of", sf)))
			b = minf(b, float(v.call("x_of", st)))
		if a > r.position.x:
			draw_rect(Rect2(r.position.x, r.position.y, minf(a, r.end.x) - r.position.x, r.size.y), dim, true)
		if b < r.end.x:
			var bx: float = maxf(b, r.position.x)
			draw_rect(Rect2(bx, r.position.y, r.end.x - bx, r.size.y), dim, true)

	func _draw_selection(v: Control, r: Rect2) -> void:
		var a: float = float(v.get("sel_from"))
		var b: float = float(v.get("sel_to"))
		if is_nan(a) or is_nan(b) or b <= a:
			return
		var x0: float = clampf(float(v.call("x_of", a)), r.position.x, r.end.x)
		var x1: float = clampf(float(v.call("x_of", b)), r.position.x, r.end.x)
		if x1 <= x0:
			return
		draw_rect(Rect2(x0, r.position.y, x1 - x0, r.size.y), Color(1.0, 1.0, 1.0, 0.1), true)
		draw_rect(Rect2(x0, r.position.y, 1.0, r.size.y), Tk.c["sol"], true)
		draw_rect(Rect2(x1, r.position.y, 1.0, r.size.y), Tk.c["sol"], true)

	func _draw_axes(v: Control, r: Rect2, font: Font, fs: int, with_ticks: bool) -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, r.position.y), Tk.c["bg_ruler"], true)
		draw_rect(Rect2(0.0, r.position.y, r.position.x, r.size.y), Tk.c["bg_ruler"], true)
		draw_rect(Rect2(0.0, r.position.y - 1.0, size.x, 1.0), Tk.c["border"], true)
		draw_rect(Rect2(r.position.x - 1.0, 0.0, 1.0, size.y), Tk.c["border"], true)
		var unit: String = "Hz"
		PmText.draw_in(self, font, Rect2(2.0, 0.0, r.position.x - 4.0, r.position.y), unit, fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, r.position.y - 5.0)
		if not with_ticks:
			return
		var t0: float = float(v.get("t0"))
		var t1: float = float(v.get("t1"))
		var step: float = v.call("nice_step", t1 - t0, r.size.x, float(Tk.px(80.0)))
		var t: float = ceil(t0 / step) * step
		var guard: int = 0
		while t <= t1 and guard < 400:
			guard += 1
			var x: float = float(v.call("x_of", t))
			draw_rect(Rect2(round(x), r.position.y - 5.0, 1.0, 5.0), Tk.c["text_faint"], true)
			var label: String = v.call("time_text", t, step)
			var w: float = PmText.width_of(font, label, fs)
			if x + 3.0 + w <= size.x:
				PmText.draw_in(self, font, Rect2(x + 3.0, 0.0, w, r.position.y), label, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, r.position.y - 6.0, PmText.WHOLE)
			t += step
		var ticks: PackedFloat64Array = v.call("freq_ticks")
		var fstep: float = ticks[1] - ticks[0] if ticks.size() > 1 else 0.0
		for f: float in ticks:
			var y: float = float(v.call("y_of", f))
			if y < r.position.y - 0.5 or y > r.end.y + 0.5:
				continue
			draw_rect(Rect2(r.position.x - 5.0, round(y), 5.0, 1.0), Tk.c["text_faint"], true)
			var label2: String = v.call("freq_text", f, fstep if not bool(v.get("log_freq")) else 0.0)
			var w2: float = PmText.width_of(font, label2, fs)
			var ty: float = clampf(y + font.get_ascent(fs) * 0.5, r.position.y + font.get_ascent(fs), r.end.y - 1.0)
			PmText.draw_in(self, font, Rect2(r.position.x - 7.0 - w2, ty - font.get_ascent(fs), w2, font.get_height(fs)), label2, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, ty, PmText.WHOLE)

	func _draw_readout(v: Control, r: Rect2, hv: Vector2, font: Font, fs: int) -> void:
		var t: float = float(v.call("time_at", hv.x))
		var f: float = float(v.call("freq_at", hv.y))
		var span: float = float(v.get("t1")) - float(v.get("t0"))
		var text: String = String(v.call("time_text", t, span / maxf(r.size.x, 1.0))) + "   " + String(v.call("freq_text", f, (float(v.get("f1")) - float(v.get("f0"))) / maxf(r.size.y, 1.0))) + "Hz"
		var db: float = float(v.call("db_at", hv))
		if not is_nan(db) and db > -900.0:
			text += "   " + ("%.1f" % db) + " dB"
		var pad: float = PmText.chip_pad()
		var w: float = PmText.width_of(font, text, fs) + pad * 2.0
		var h: float = font.get_height(fs) + pad
		var x: float = hv.x + 12.0
		if x + w > r.end.x:
			x = hv.x - 12.0 - w
		var y: float = hv.y + 14.0
		if y + h > r.end.y:
			y = hv.y - 14.0 - h
		var box := Rect2(x, y, w, h)
		draw_rect(box, Color(Tk.c["bg_panel"], 0.88), true)
		PmText.draw_in(self, font, box, text, fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_CENTER, y + pad * 0.5 + font.get_ascent(fs), PmText.WHOLE)
