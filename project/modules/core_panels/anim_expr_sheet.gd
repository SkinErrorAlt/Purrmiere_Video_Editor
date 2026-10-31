extends PanelContainer

signal closed

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmFold := preload("res://ui/kit/pm_fold.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const AnimLayerStack := preload("res://modules/core_panels/anim_layer_stack.gd")
const SELF_PATH := "res://modules/core_panels/anim_expr_sheet.gd"
const KIND := "expr"
const IDLE := 0.4
const TAB_SPACES := "  "

var panel: Object = null
var path: String = ""
var code_field: TextEdit = null
var result: Label = null
var stack: VBoxContainer = null
var blend_drop: Button = null
var weight_field: Control = null
var _idle: Timer = null
var _applied: String = ""


static func make(panel_: Object, path_: String) -> Control:
	var script: GDScript = load(SELF_PATH)
	var made: PanelContainer = script.new()
	made.set("panel", panel_)
	made.set("path", path_)
	made.call("build")
	return made


func _init() -> void:
	name = "ExpressionSheet"
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


func build() -> void:
	var col: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	add_child(col)
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	head.add_child(PmLabel.body("Expression"))
	head.add_child(PmUI.spacer())
	var shut: Button = PmButton.make("", "close")
	shut.set("quiet", true)
	shut.set("icon_px", 11.0)
	PmUI.tip(shut, "Close the expression sheet")
	shut.pressed.connect(_on_done)
	head.add_child(shut)
	col.add_child(head)
	stack = AnimLayerStack.make(AnimLayerUi.stack_rows(prop()))
	stack.connect("reordered", _on_reorder)
	stack.connect("flipped", _on_flip)
	col.add_child(stack)
	code_field = TextEdit.new()
	code_field.name = "Code"
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Tk.c["bg_field"]
	tsb.border_color = Tk.c["border_soft"]
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_field"))))
	tsb.content_margin_left = 6.0
	tsb.content_margin_right = 6.0
	tsb.content_margin_top = 4.0
	tsb.content_margin_bottom = 4.0
	code_field.add_theme_stylebox_override("normal", tsb)
	code_field.add_theme_stylebox_override("focus", tsb)
	code_field.add_theme_font_override("font", Tk.font("mono"))
	code_field.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	code_field.custom_minimum_size = Vector2(float(Tk.px(180.0)), float(Tk.px(56.0)))
	code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_field.text = str(layer().get("code", ""))
	_applied = code_field.text
	code_field.text_changed.connect(_on_typed)
	code_field.focus_exited.connect(apply_now)
	code_field.gui_input.connect(_on_input)
	col.add_child(code_field)
	result = PmLabel.small("")
	result.name = "Result"
	col.add_child(result)
	var chips: HFlowContainer = PmUI.flow(Tk.px(3.0), Tk.px(3.0))
	chips.name = "Names"
	for pair: Array in AnimLayerUi.NAME_CHIPS:
		var chip: Button = PmButton.make(String(pair[0]))
		chip.set("quiet", true)
		PmUI.tip(chip, String(pair[1]))
		chip.pressed.connect(insert_text.bind(String(pair[0])))
		chips.add_child(chip)
	col.add_child(chips)
	var funcs: VBoxContainer = PmFold.make("Functions", "anim.expr_funcs", false)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	for fname: String in AnimProp.EXPR_FUNCS:
		var fb: Button = PmButton.make(fname)
		fb.set("quiet", true)
		fb.pressed.connect(insert_call.bind(fname))
		grid.add_child(fb)
	(funcs.get("body") as VBoxContainer).add_child(grid)
	col.add_child(funcs)
	var presets: VBoxContainer = PmFold.make("Presets", "anim.expr_presets", false)
	var plist: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	for pair2: Array in AnimLayerUi.PRESETS:
		var pb: Button = PmButton.make(String(pair2[0]))
		pb.set("quiet", true)
		pb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		PmUI.tip(pb, String(pair2[1]))
		pb.pressed.connect(use_preset.bind(String(pair2[1])))
		plist.add_child(pb)
	(presets.get("body") as VBoxContainer).add_child(plist)
	col.add_child(presets)
	var mix: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	mix.add_child(PmLabel.dim("Blend"))
	var choices: Array = []
	for b: Array in AnimLayerUi.BLENDS:
		choices.append(PmDrop.choice(String(b[0]), String(b[1])))
	blend_drop = PmDrop.make_drop(choices, str(layer().get("blend", "over")))
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
	PmUI.tip(bake, "Work the expression out at every frame and leave plain keys behind")
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
	_idle = Timer.new()
	_idle.one_shot = true
	_idle.wait_time = IDLE
	_idle.timeout.connect(apply_now)
	add_child(_idle)
	refresh()


func refresh() -> void:
	if result == null:
		return
	if stack != null:
		stack.call("set_rows", AnimLayerUi.stack_rows(prop()))
	result.text = result_now()


func result_now() -> String:
	var at: Dictionary = {}
	if panel != null:
		var got: Variant = panel.call("anim_sheet_time", path)
		if got is Dictionary:
			at = got
	return AnimLayerUi.result_text(
		code_field.text if code_field != null else "",
		float(at.get("t", 0.0)),
		float(at.get("dur", 0.0)),
		float(at.get("value", 0.0)),
		float(at.get("fps", 0.0)),
		int(at.get("comp", 0)))


func insert_text(text: String) -> void:
	if code_field == null:
		return
	code_field.insert_text_at_caret(text)
	_on_typed()


func insert_call(fname: String) -> void:
	if code_field == null:
		return
	code_field.insert_text_at_caret(fname + "()")
	var line: int = code_field.get_caret_line()
	code_field.set_caret_column(maxi(code_field.get_caret_column() - 1, 0), true, 0)
	code_field.set_caret_line(line, true, true, 0, 0)
	_on_typed()


func use_preset(code: String) -> void:
	if code_field == null:
		return
	code_field.text = code
	_on_typed()
	apply_now()


func apply_now() -> void:
	if code_field == null or panel == null:
		return
	if _idle != null:
		_idle.stop()
	var want: String = code_field.text
	if want == _applied:
		return
	_applied = want
	var index: int = layer_index()
	if index < 0:
		return
	panel.call("set_anim_layer_field", path, index, "code", want, "Expression")


func _on_typed() -> void:
	refresh()
	if _idle != null and _idle.is_inside_tree():
		_idle.start(IDLE)


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and k.keycode == KEY_TAB and code_field != null:
		code_field.accept_event()
		code_field.insert_text_at_caret(TAB_SPACES)
		_on_typed()


func _on_blend(id: String) -> void:
	var index: int = layer_index()
	if index >= 0 and panel != null:
		panel.call("set_anim_layer_field", path, index, "blend", id, "Expression blend")


func _on_weight(v: float) -> void:
	var index: int = layer_index()
	if index >= 0 and panel != null:
		panel.call("set_anim_layer_field", path, index, "weight", v, "Expression weight")


func _on_reorder(from: int, to: int) -> void:
	if panel != null:
		panel.call("move_anim_layer", path, from, to)


func _on_flip(index: int, on: bool) -> void:
	if panel != null:
		panel.call("set_anim_layer_field", path, index, "on", on, "Layer on")


func _on_bake() -> void:
	apply_now()
	if panel != null:
		panel.call("bake_anim_layers", path)
	_on_done()


func _on_remove() -> void:
	var index: int = layer_index()
	if index >= 0 and panel != null:
		panel.call("remove_anim_layer", path, index)
	_on_done()


func _on_done() -> void:
	apply_now()
	closed.emit()
	if panel != null:
		panel.call("close_anim_sheet", path)
