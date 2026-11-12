extends VBoxContainer

const TextGlyphs := preload("res://engine/text_glyphs.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const KEY := "strokes_more"
const MAX_STROKES := 8
const NEW_WIDTH := 6.0

var block: Object = null
var _rows: VBoxContainer = null
var _add: Button = null
var _shown: String = ""


static func make(host: Object) -> Control:
	var s: VBoxContainer = (load("res://modules/core_panels/text_strokes_ui.gd") as GDScript).new()
	s.set("block", host)
	s.call("_build")
	return s


static func cleaned(list: Array) -> Array:
	var out: Array = []
	for s: Variant in list:
		if s is Dictionary:
			var d: Dictionary = s
			out.append({"on": bool(d.get("on", true)), "width": maxf(float(d.get("width", NEW_WIDTH)), 0.0), "colour": d.get("colour", [0.0, 0.0, 0.0, 1.0])})
	return out


func _build() -> void:
	name = "MoreStrokes"
	add_theme_constant_override("separation", Tk.px(3.0))
	_rows = PmUI.vbox(Tk.px(3.0))
	add_child(_rows)
	var r: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(float(Tk.px(30.0)), 0.0)
	r.add_child(gap)
	_add = PmButton.make("Add another stroke", "plus")
	_add.name = "AddStroke"
	_add.set("quiet", true)
	PmUI.tip(_add, "Adds a stroke outside the ones already there, so a title can have as many outlines as it needs")
	_add.pressed.connect(add_stroke)
	r.add_child(_add)
	add_child(r)


func current() -> Array:
	if block == null:
		return []
	return cleaned(TextGlyphs.stroke_list(block.call("props_now")))


func show_for(props: Dictionary) -> void:
	var list: Array = cleaned(TextGlyphs.stroke_list(props))
	var stamp: String = JSON.stringify(list)
	if stamp == _shown:
		return
	_shown = stamp
	for ch: Node in _rows.get_children():
		_rows.remove_child(ch)
		ch.queue_free()
	for i: int in list.size():
		_rows.add_child(_row(i, list[i]))
	_add.disabled = list.size() >= MAX_STROKES


func _row(i: int, s: Dictionary) -> Control:
	var r: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	r.name = "Stroke%d" % i
	var cb: CheckBox = CheckBox.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(s.get("on", true))
	cb.toggled.connect(func(on: bool) -> void: set_field(i, "on", on))
	r.add_child(cb)
	var l: Label = PmLabel.trim("Stroke %d" % (i + 3))
	l.custom_minimum_size.x = float(Tk.px(70.0))
	r.add_child(l)
	var pick: ColorPickerButton = ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(float(Tk.px(34.0)), float(Tk.px(20.0)))
	var c: Array = s.get("colour", [0.0, 0.0, 0.0, 1.0])
	pick.color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
	pick.color_changed.connect(func(col: Color) -> void: set_field(i, "colour", [col.r, col.g, col.b, col.a]))
	r.add_child(pick)
	var f: Control = PmField.make(float(s.get("width", NEW_WIDTH)), 0.0, 60.0, 0.5, "")
	f.custom_minimum_size.x = float(Tk.px(64.0))
	PmUI.tip(f, "Stroke width")
	f.connect("value_changed", func(v: float) -> void: set_field(i, "width", v))
	r.add_child(f)
	var x: Button = PmButton.make("", "close")
	x.set("quiet", true)
	PmUI.tip(x, "Remove this stroke")
	x.pressed.connect(func() -> void: remove_stroke(i))
	r.add_child(x)
	return r


func _write(list: Array) -> bool:
	_shown = ""
	return bool(block.call("write", KEY, list))


func add_stroke() -> bool:
	var list: Array = current()
	if list.size() >= MAX_STROKES:
		return false
	var col: Array = [0.0, 0.0, 0.0, 1.0] if list.size() % 2 == 1 else [1.0, 1.0, 1.0, 1.0]
	list.append({"on": true, "width": NEW_WIDTH, "colour": col})
	return _write(list)


func remove_stroke(i: int) -> bool:
	var list: Array = current()
	if i < 0 or i >= list.size():
		return false
	list.remove_at(i)
	return _write(list)


func set_field(i: int, field: String, value: Variant) -> bool:
	var list: Array = current()
	if i < 0 or i >= list.size():
		return false
	(list[i] as Dictionary)[field] = value
	return _write(list)
