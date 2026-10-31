extends PanelContainer

signal closed

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const AnimLayerStack := preload("res://modules/core_panels/anim_layer_stack.gd")
const SELF_PATH := "res://modules/core_panels/anim_driven_sheet.gd"
const KIND := "driven"
const NO_VALUE := "Pick a value"
const BOTH_WAYS := "Look both ways"
const BACK_ONLY := "Look backwards only"


class Graph extends Control:
	const Ui := preload("res://modules/core_panels/anim_layer_ui.gd")

	var layer: Dictionary = {}
	var raw: float = 0.0
	var has_raw: bool = false

	func _init() -> void:
		name = "MappingGraph"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(float(Tk.px(Ui.GRAPH_W)), float(Tk.px(Ui.GRAPH_H)))

	func set_layer(l: Dictionary, raw_: float, has_raw_: bool) -> void:
		layer = l.duplicate(true)
		raw = raw_
		has_raw = has_raw_
		queue_redraw()

	func points() -> PackedVector2Array:
		return Ui.graph_points(layer, size.x, size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
		if layer.is_empty():
			return
		var pts: PackedVector2Array = points()
		if pts.size() >= 2:
			draw_polyline(pts, Tk.c["accent"], 1.5, true)
		if has_raw:
			var dot: Vector2 = Ui.graph_dot(layer, raw, size.x, size.y)
			draw_circle(dot, 3.0, Tk.c["text_bright"])


var panel: Object = null
var path: String = ""
var label_text: String = ""
var stack: VBoxContainer = null
var graph: Control = null
var clip_drop: Button = null
var value_btn: Button = null
var in_lo: Control = null
var in_hi: Control = null
var out_lo: Control = null
var out_hi: Control = null
var over_box: CheckBox = null
var curve_drop: Button = null
var ease_drop: Button = null
var smooth_drop: Button = null
var smooth_row: HBoxContainer = null
var window_field: Control = null
var taps_field: Control = null
var dir_btn: Button = null
var lead_field: Control = null
var blend_drop: Button = null
var weight_field: Control = null


static func make(panel_: Object, path_: String, label_: String) -> Control:
	var script: GDScript = load(SELF_PATH)
	var made: PanelContainer = script.new()
	made.set("panel", panel_)
	made.set("path", path_)
	made.set("label_text", label_)
	made.call("build")
	return made


func _init() -> void:
	name = "DrivenSheet"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_panel"))))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	add_theme_stylebox_override("panel", sb)


func layer_index() -> int:
	return AnimLayerUi.layer_index(prop(), KIND)


func prop() -> Dictionary:
	if panel == null:
		return {}
	var got: Variant = panel.call("anim_layer_prop", path)
	return got if got is Dictionary else {}


func layer() -> Dictionary:
	return AnimLayerUi.layer_at(prop(), layer_index())


func source() -> Dictionary:
	return AnimProp.driven_source(layer())


func target_clip() -> Clip:
	if panel == null:
		return null
	return panel.call("target_clip") as Clip


func sequence() -> Sequence:
	if panel == null:
		return null
	return panel.call("seq") as Sequence


func source_clip() -> Clip:
	var s: Sequence = sequence()
	if s == null:
		return null
	return s.clip_by_id(str(source().get("clip", "")))


func sentence() -> String:
	return AnimLayerUi.sentence_head(label_text)


func value_text() -> String:
	var src: Dictionary = source()
	var sp: String = str(src.get("path", ""))
	if sp.is_empty():
		return NO_VALUE
	return AnimLayerUi.path_label(source_clip(), sp)


func build() -> void:
	var outer: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	add_child(outer)
	var col: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	head.add_child(PmLabel.body(sentence()))
	var choices: Array = []
	for one: Dictionary in AnimLayerUi.source_clips(target_clip(), sequence()):
		choices.append(PmDrop.choice(str(one["id"]), str(one["label"])))
	clip_drop = PmDrop.make_drop(choices, str(source().get("clip", "")))
	clip_drop.name = "ClipPicker"
	clip_drop.custom_minimum_size.x = float(Tk.px(110.0))
	clip_drop.connect("changed", _on_clip)
	head.add_child(clip_drop)
	value_btn = PmButton.make(value_text(), "chev_d")
	value_btn.name = "ValuePicker"
	value_btn.set("quiet", true)
	value_btn.pressed.connect(_on_value_menu)
	head.add_child(value_btn)
	head.add_child(PmUI.spacer())
	var shut: Button = PmButton.make("", "close")
	shut.set("quiet", true)
	shut.set("icon_px", 11.0)
	PmUI.tip(shut, "Close the driven sheet")
	shut.pressed.connect(_on_done)
	head.add_child(shut)
	col.add_child(head)
	stack = AnimLayerStack.make(AnimLayerUi.stack_rows(prop()))
	stack.connect("reordered", _on_reorder)
	stack.connect("flipped", _on_flip)
	col.add_child(stack)
	var from_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	from_row.add_child(PmLabel.dim("From"))
	in_lo = _number(float(layer().get("in_min", 0.0)), "in_min")
	from_row.add_child(in_lo)
	in_hi = _number(float(layer().get("in_max", 1.0)), "in_max")
	from_row.add_child(in_hi)
	var fill: Button = PmButton.make(AnimLayerUi.RANGE_BUTTON)
	fill.set("quiet", true)
	fill.pressed.connect(use_source_range)
	from_row.add_child(fill)
	col.add_child(from_row)
	var to_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	to_row.add_child(PmLabel.dim("To"))
	out_lo = _number(float(layer().get("out_min", 0.0)), "out_min")
	to_row.add_child(out_lo)
	out_hi = _number(float(layer().get("out_max", 1.0)), "out_max")
	to_row.add_child(out_hi)
	col.add_child(to_row)
	var over_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	over_box = CheckBox.new()
	over_box.name = "Overshoot"
	over_box.text = "Let it overshoot"
	over_box.focus_mode = Control.FOCUS_NONE
	over_box.button_pressed = bool(layer().get("overshoot", false))
	over_box.toggled.connect(_on_overshoot)
	over_row.add_child(over_box)
	col.add_child(over_row)
	col.add_child(_note(AnimLayerUi.OVERSHOOT_NOTE))
	var resp: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	resp.add_child(PmLabel.dim("Response"))
	var curves: Array = []
	for cv: Array in AnimLayerUi.CURVES:
		curves.append(PmDrop.choice(String(cv[0]), String(cv[1])))
	curve_drop = PmDrop.make_drop(curves, str(layer().get("curve", "linear")))
	curve_drop.name = "Response"
	curve_drop.custom_minimum_size.x = float(Tk.px(90.0))
	curve_drop.connect("changed", _on_curve)
	resp.add_child(curve_drop)
	var eases: Array = []
	for fam: String in AnimProp.EASE_FAMILIES:
		eases.append(PmDrop.choice(fam, fam.capitalize()))
	ease_drop = PmDrop.make_drop(eases, str(layer().get("ease", "cubic")))
	ease_drop.custom_minimum_size.x = float(Tk.px(84.0))
	ease_drop.connect("changed", _on_ease)
	resp.add_child(ease_drop)
	col.add_child(resp)
	var smooth_head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	smooth_head.add_child(PmLabel.dim("Smoothing"))
	var modes: Array = []
	for md: Array in AnimLayerUi.SMOOTH_CHOICES:
		modes.append(PmDrop.choice(String(md[0]), String(md[1])))
	smooth_drop = PmDrop.make_drop(modes, str(AnimLayerUi.smooth_of(layer()).get("mode", "off")))
	smooth_drop.name = "Smoothing"
	smooth_drop.custom_minimum_size.x = float(Tk.px(90.0))
	smooth_drop.connect("changed", _on_smooth_mode)
	smooth_head.add_child(smooth_drop)
	col.add_child(smooth_head)
	smooth_row = PmUI.hbox(Tk.px(4.0))
	smooth_row.name = "SmoothingOptions"
	smooth_row.add_child(PmLabel.dim("Over"))
	window_field = PmField.make(float(AnimLayerUi.smooth_of(layer()).get("window", 0.2)), 0.0, 10.0, 0.05, " s")
	window_field.custom_minimum_size.x = float(Tk.px(64.0))
	window_field.connect("value_changed", _on_window)
	smooth_row.add_child(window_field)
	smooth_row.add_child(PmLabel.dim("Samples"))
	taps_field = PmField.make(float(AnimLayerUi.smooth_of(layer()).get("taps", 5)), float(AnimProp.SMOOTH_TAPS_MIN), float(AnimProp.SMOOTH_TAPS_MAX), 2.0, "")
	taps_field.set("precision", 0)
	taps_field.custom_minimum_size.x = float(Tk.px(52.0))
	taps_field.connect("value_changed", _on_taps)
	smooth_row.add_child(taps_field)
	dir_btn = PmButton.make(BOTH_WAYS if bool(AnimLayerUi.smooth_of(layer()).get("centre", true)) else BACK_ONLY)
	dir_btn.set("quiet", true)
	dir_btn.pressed.connect(_on_direction)
	smooth_row.add_child(dir_btn)
	col.add_child(smooth_row)
	col.add_child(_note(AnimLayerUi.SMOOTH_NOTE))
	var lead_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	lead_row.add_child(PmLabel.dim("Lead"))
	lead_field = PmField.make(float(source().get("lead", 0.0)), -60.0, 60.0, 0.05, " s")
	lead_field.custom_minimum_size.x = float(Tk.px(64.0))
	lead_field.connect("value_changed", _on_lead)
	lead_row.add_child(lead_field)
	col.add_child(lead_row)
	col.add_child(_note(AnimLayerUi.LEAD_NOTE))
	var mix: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	mix.add_child(PmLabel.dim("Blend"))
	var blends: Array = []
	for b: Array in AnimLayerUi.BLENDS:
		blends.append(PmDrop.choice(String(b[0]), String(b[1])))
	blend_drop = PmDrop.make_drop(blends, str(layer().get("blend", "over")))
	blend_drop.custom_minimum_size.x = float(Tk.px(84.0))
	blend_drop.connect("changed", _on_blend)
	mix.add_child(blend_drop)
	mix.add_child(PmLabel.dim("Weight"))
	weight_field = PmField.make(float(layer().get("weight", 1.0)), 0.0, 1.0, 0.05, "")
	weight_field.custom_minimum_size.x = float(Tk.px(64.0))
	weight_field.connect("value_changed", _on_weight)
	mix.add_child(weight_field)
	col.add_child(mix)
	var buttons: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	buttons.add_child(PmUI.spacer())
	var bake: Button = PmButton.make("Bake to keys")
	bake.set("quiet", true)
	PmUI.tip(bake, "Work the link out at every frame and leave plain keys behind")
	bake.pressed.connect(_on_bake)
	buttons.add_child(bake)
	var drop: Button = PmButton.make("Remove")
	drop.set("quiet", true)
	drop.pressed.connect(_on_remove)
	buttons.add_child(drop)
	var done: Button = PmButton.primary("Done")
	done.pressed.connect(_on_done)
	buttons.add_child(done)
	col.add_child(buttons)
	var side: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	graph = Graph.new()
	side.add_child(graph)
	side.add_child(PmLabel.small("Source across, result up"))
	outer.add_child(side)
	refresh()


func _note(text: String) -> Label:
	var l: Label = PmLabel.wrap(text, "text_dim")
	l.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	l.custom_minimum_size.x = float(Tk.px(220.0))
	return l


func _number(v: float, key: String) -> Control:
	var f: Control = PmField.make(v, -INF, INF, 0.05, "")
	f.name = key
	f.custom_minimum_size.x = float(Tk.px(64.0))
	f.connect("value_changed", _on_number.bind(key))
	return f


func refresh() -> void:
	var l: Dictionary = layer()
	if value_btn != null:
		value_btn.text = value_text()
	if smooth_row != null:
		smooth_row.visible = str(AnimLayerUi.smooth_of(l).get("mode", "off")) != "off"
	if dir_btn != null:
		dir_btn.text = BOTH_WAYS if bool(AnimLayerUi.smooth_of(l).get("centre", true)) else BACK_ONLY
	if stack != null:
		stack.call("set_rows", AnimLayerUi.stack_rows(prop()))
	if graph != null:
		var now: Dictionary = raw_now()
		graph.call("set_layer", l, float(now.get("v", 0.0)), bool(now.get("ok", false)))


func raw_now() -> Dictionary:
	var at: Dictionary = {}
	if panel != null:
		var got: Variant = panel.call("anim_sheet_time", path)
		if got is Dictionary:
			at = got
	return AnimLayerUi.source_value(source_clip(), source(), float(at.get("t", 0.0)), float(at.get("fps", 0.0)))


func use_source_range() -> void:
	var src: Dictionary = source()
	var got: Vector2 = AnimLayerUi.source_range(source_clip(), str(src.get("path", "")), _fps())
	var index: int = layer_index()
	if index < 0 or panel == null:
		return
	panel.call("set_anim_layer_fields", path, index, {"in_min": got.x, "in_max": got.y}, "Driven range")
	if in_lo != null:
		in_lo.set("value", got.x)
	if in_hi != null:
		in_hi.set("value", got.y)
	refresh()


func _fps() -> float:
	var s: Sequence = sequence()
	return s.fps if s != null and s.fps > 0.0 else 30.0


func _write(key: String, value: Variant, label: String) -> void:
	var index: int = layer_index()
	if index < 0 or panel == null:
		return
	panel.call("set_anim_layer_field", path, index, key, value, label)
	refresh()


func _write_src(key: String, value: Variant, label: String) -> void:
	var src: Dictionary = source()
	src[key] = value
	_write("src", src, label)


func _on_number(v: float, key: String) -> void:
	_write(key, v, "Driven range")


func _on_overshoot(on: bool) -> void:
	_write("overshoot", on, "Driven overshoot")


func _on_curve(id: String) -> void:
	_write("curve", id, "Driven response")


func _on_ease(id: String) -> void:
	_write("ease", id, "Driven response")


func _on_smooth_mode(id: String) -> void:
	_write("smooth", AnimLayerUi.with_smooth(layer(), "mode", id), "Driven smoothing")


func _on_window(v: float) -> void:
	_write("smooth", AnimLayerUi.with_smooth(layer(), "window", v), "Driven smoothing")


func _on_taps(v: float) -> void:
	var n: int = clampi(int(round(v)), AnimProp.SMOOTH_TAPS_MIN, AnimProp.SMOOTH_TAPS_MAX)
	if n % 2 == 0:
		n += 1
	_write("smooth", AnimLayerUi.with_smooth(layer(), "taps", n), "Driven smoothing")


func _on_direction() -> void:
	var now: bool = bool(AnimLayerUi.smooth_of(layer()).get("centre", true))
	_write("smooth", AnimLayerUi.with_smooth(layer(), "centre", not now), "Driven smoothing")


func _on_lead(v: float) -> void:
	_write_src("lead", v, "Driven lead")


func _on_blend(id: String) -> void:
	_write("blend", id, "Driven blend")


func _on_weight(v: float) -> void:
	_write("weight", v, "Driven weight")


func _on_clip(id: String) -> void:
	pick_source(id, "")


func _on_value_menu() -> void:
	var items: Array = menu_items()
	if items.is_empty():
		return
	var m: Control = PmMenu.open(value_btn, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_value_picked)


func menu_items() -> Array:
	var src_clip: Clip = source_clip()
	if src_clip == null:
		src_clip = target_clip()
	var out: Array = []
	for group: Dictionary in AnimLayerUi.value_groups(src_clip):
		var subs: Array = []
		for one: Variant in group["values"]:
			var v: Dictionary = one
			subs.append(PmMenu.item(str(v["path"]), str(v["label"])))
		if not subs.is_empty():
			out.append(PmMenu.sub_item("group_" + str(group["group"]), str(group["group"]), subs))
	return out


func _on_value_picked(id: String) -> void:
	pick_source("", id)


func pick_source(clip_id: String, value_path: String) -> void:
	var index: int = layer_index()
	if index < 0 or panel == null:
		return
	var src: Dictionary = source()
	var s: Sequence = sequence()
	var c: Clip = target_clip()
	if not clip_id.is_empty():
		src["clip"] = clip_id
		src["path"] = ""
	if not value_path.is_empty():
		src["path"] = value_path
		if str(src.get("clip", "")).is_empty() and c != null:
			src["clip"] = c.id
	var picked: Clip = s.clip_by_id(str(src.get("clip", ""))) if s != null else null
	src["src_start"] = picked.start if picked != null else 0.0
	src["dst_start"] = c.start if c != null else 0.0
	panel.call("set_anim_layer_field", path, index, "src", src, "Driven source")
	if clip_drop != null:
		clip_drop.call("set_value", str(src.get("clip", "")), false)
	refresh()


func _on_reorder(from: int, to: int) -> void:
	if panel != null:
		panel.call("move_anim_layer", path, from, to)


func _on_flip(index: int, on: bool) -> void:
	if panel != null:
		panel.call("set_anim_layer_field", path, index, "on", on, "Layer on")


func _on_bake() -> void:
	if panel != null:
		panel.call("bake_anim_layers", path)
	_on_done()


func _on_remove() -> void:
	var index: int = layer_index()
	if index >= 0 and panel != null:
		panel.call("remove_anim_layer", path, index)
	_on_done()


func _on_done() -> void:
	closed.emit()
	if panel != null:
		panel.call("close_anim_sheet", path)
