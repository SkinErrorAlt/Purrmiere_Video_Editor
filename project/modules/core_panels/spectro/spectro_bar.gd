extends RefCounted
## The spectrogram's controls: window size and shape, overlap, linear or log frequency, colours, floor and range.
## Shared by the Spectrogram panel and the Audio Editor's spectrogram view.

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const SpectroGpu := preload("res://modules/core_panels/spectro/spectro_gpu.gd")
const SpectroView := preload("res://modules/core_panels/spectro/spectro_view.gd")

static var shared: Dictionary = {}


static func build(view: Control) -> HFlowContainer:
	var row: HFlowContainer = PmUI.flow(Tk.px(8.0), Tk.px(2.0))
	row.name = "SpectroSettings"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sizes: Array = []
	for s: int in SpectroView.SIZES:
		sizes.append(PmDrop.choice(str(s), str(s)))
	_labelled(row, "Window", _drop(sizes, str(int(view.get("window_size"))), "Size", "How many samples each column looks at. Bigger is sharper in frequency, blurrier in time", func(id: String) -> void: _apply_one(view, "size", int(id))))
	var shapes: Array = []
	for i: int in SpectroGpu.WINDOWS.size():
		shapes.append(PmDrop.choice(SpectroGpu.WINDOWS[i], SpectroGpu.WINDOW_LABELS[i]))
	row.add_child(_drop(shapes, String(view.get("window_kind")), "Shape", "The window's shape: Hann is a good start, Blackman-Harris hides leaks around loud tones, Rectangle is sharpest but leaks most", func(id: String) -> void: _apply_one(view, "window", id)))
	var overlaps: Array = []
	for i2: int in SpectroView.OVERLAPS.size():
		overlaps.append(PmDrop.choice(str(i2), SpectroView.OVERLAP_LABELS[i2]))
	var oi: int = maxi(0, Array(SpectroView.OVERLAPS).find(float(view.get("overlap"))))
	_labelled(row, "Overlap", _drop(overlaps, str(oi), "Overlap", "Every pixel computes a column for each pixel across. A percentage steps columns by the window's hop, like a classic spectrogram", func(id: String) -> void: _apply_one(view, "overlap", float(SpectroView.OVERLAPS[int(id)]))))
	var log_b: Button = PmButton.make("Log", "", true)
	log_b.name = "Log"
	log_b.set("quiet", true)
	log_b.button_pressed = bool(view.get("log_freq"))
	PmUI.tip(log_b, "Frequency on a log scale: more room for the low notes")
	log_b.toggled.connect(func(on: bool) -> void:
		view.call("set_log", on)
		_remember(view))
	row.add_child(log_b)
	var maps: Array = []
	for i3: int in SpectroView.CMAPS.size():
		maps.append(PmDrop.choice(SpectroView.CMAPS[i3], SpectroView.CMAP_LABELS[i3]))
	row.add_child(_drop(maps, String(view.get("cmap")), "Colours", "The colours loudness is drawn in", func(id: String) -> void: _apply_one(view, "cmap", id)))
	var floor_f: Control = PmField.make(float(view.get("floor_db")), -200.0, 0.0, 1.0, " dB")
	floor_f.name = "Floor"
	PmUI.tip(floor_f, "Anything quieter than this is black. Raise it to clear noise away from a faint picture")
	floor_f.connect("value_changed", func(v: float) -> void: _apply_one(view, "floor", v))
	_labelled(row, "Floor", floor_f)
	var range_f: Control = PmField.make(float(view.get("range_db")), 6.0, 200.0, 1.0, " dB")
	range_f.name = "Range"
	PmUI.tip(range_f, "How many decibels go from black to the brightest colour. Smaller gives more contrast")
	range_f.connect("value_changed", func(v: float) -> void: _apply_one(view, "range", v))
	_labelled(row, "Range", range_f)
	var auto_b: Button = PmButton.make("Auto", "sun")
	auto_b.name = "Auto"
	auto_b.set("quiet", true)
	PmUI.tip(auto_b, "Set floor and range from what is on screen, to pull a faint picture out of noise")
	auto_b.pressed.connect(func() -> void:
		if bool(view.call("auto_levels")):
			floor_f.set("value", float(view.get("floor_db")))
			range_f.set("value", float(view.get("range_db")))
			_remember(view))
	row.add_child(auto_b)
	view.connect("settings_changed", func() -> void:
		log_b.set_pressed_no_signal(bool(view.get("log_freq")))
		floor_f.set("value", float(view.get("floor_db")))
		range_f.set("value", float(view.get("range_db"))))
	return row


static func _labelled(row: HFlowContainer, text: String, c: Control) -> void:
	var box: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	box.add_child(PmLabel.dim(text))
	box.add_child(c)
	row.add_child(box)


static func _drop(choices: Array, value: String, name_: String, tip: String, on_change: Callable) -> Button:
	var d: Button = PmDrop.make_drop(choices, value)
	d.name = name_
	PmUI.tip(d, tip)
	d.connect("changed", on_change)
	return d


static func _apply_one(view: Control, key: String, v: Variant) -> void:
	view.call("set_settings", {key: v})
	_remember(view)


static func _remember(view: Control) -> void:
	shared = view.call("settings")


static func apply_shared(view: Control) -> void:
	if not shared.is_empty():
		view.call("set_settings", shared)


## Fit, zoom in and zoom out, for a header row.
static func view_buttons(row: Container, view: Control) -> void:
	var fit: Button = _icon("maximize", "Fit the whole sound", "F")
	fit.name = "Fit"
	fit.pressed.connect(func() -> void: view.call("fit"))
	row.add_child(fit)
	var zin: Button = _icon("plus", "Zoom in on time (Shift+wheel zooms frequency)")
	zin.name = "ZoomIn"
	zin.pressed.connect(func() -> void: view.call("zoom_time", 0.5))
	row.add_child(zin)
	var zout: Button = _icon("minus", "Zoom out on time")
	zout.name = "ZoomOut"
	zout.pressed.connect(func() -> void: view.call("zoom_time", 2.0))
	row.add_child(zout)
	var fin: Button = _icon("chev_u", "Zoom in on frequency")
	fin.name = "FreqIn"
	fin.pressed.connect(func() -> void: view.call("zoom_freq", 0.5, 0.5))
	row.add_child(fin)
	var fout: Button = _icon("chev_d", "Zoom out on frequency")
	fout.name = "FreqOut"
	fout.pressed.connect(func() -> void: view.call("zoom_freq", 2.0, 0.5))
	row.add_child(fout)


static func _icon(icon: String, tip: String, keys: String = "") -> Button:
	var b: Button = PmButton.make("", icon)
	b.set("quiet", true)
	PmUI.tip(b, tip, keys)
	return b


const HINT := "Wheel zooms time, Shift+wheel zooms frequency, drag to move, right-drag a box to zoom into it, double-click to fit"
