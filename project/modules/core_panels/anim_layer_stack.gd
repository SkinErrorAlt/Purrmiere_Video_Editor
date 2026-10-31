extends VBoxContainer

signal reordered(from: int, to: int)
signal flipped(index: int, on: bool)
signal opened(index: int)

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const SELF_PATH := "res://modules/core_panels/anim_layer_stack.gd"
const OPENABLE: PackedStringArray = ["expr", "driven"]

var rows: Array[Dictionary] = []
var row_h: float = 20.0
var drag_from: int = -1
var drag_to: int = -1


static func make(rows_: Array[Dictionary]) -> VBoxContainer:
	var script: GDScript = load(SELF_PATH)
	var made: VBoxContainer = script.new()
	made.call("set_rows", rows_)
	return made


func _init() -> void:
	name = "LayerStack"
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	row_h = float(Tk.px(20.0))
	draw.connect(_on_draw)


func set_rows(rows_: Array) -> void:
	rows = []
	for one: Variant in rows_:
		rows.append((one as Dictionary).duplicate(true))
	drag_from = -1
	drag_to = -1
	_build()


func row_count() -> int:
	return rows.size()


func index_at(local_y: float) -> int:
	return AnimLayerUi.drop_index(local_y, row_h, rows.size())


func begin_drag(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	drag_from = index
	drag_to = index
	queue_redraw()


func drag_to_y(local_y: float) -> void:
	if drag_from < 0:
		return
	var want: int = index_at(local_y)
	if want == drag_to:
		return
	drag_to = want
	queue_redraw()


func end_drag() -> bool:
	if drag_from < 0:
		return false
	var from: int = drag_from
	var to: int = drag_to
	drag_from = -1
	drag_to = -1
	queue_redraw()
	if to < 0 or to == from:
		return false
	reordered.emit(from, to)
	return true


func _build() -> void:
	PmUI.clear(self)
	if rows.is_empty():
		return
	for r: Dictionary in rows:
		add_child(_row(r))


func _row(r: Dictionary) -> Control:
	var index: int = int(r.get("index", 0))
	var line: HBoxContainer = PmUI.hbox(Tk.px(3.0))
	line.custom_minimum_size = Vector2(0.0, row_h)
	var grip: Button = PmButton.make("", "list")
	grip.set("quiet", true)
	grip.set("icon_px", 9.0)
	grip.focus_mode = Control.FOCUS_NONE
	grip.custom_minimum_size = Vector2(float(Tk.px(14.0)), 0.0)
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	PmUI.tip(grip, "Hold the mouse down here and move to change the order these layers run in")
	grip.gui_input.connect(_on_input.bind(index))
	line.add_child(grip)
	var on: CheckBox = CheckBox.new()
	on.focus_mode = Control.FOCUS_NONE
	on.button_pressed = bool(r.get("on", true))
	on.toggled.connect(_on_flip.bind(index))
	line.add_child(on)
	line.add_child(PmLabel.body(str(r.get("title", ""))))
	line.add_child(PmLabel.dim(_tail(r)))
	line.add_child(PmUI.spacer())
	if OPENABLE.has(str(r.get("type", ""))):
		var open_btn: Button = PmButton.make("Open")
		open_btn.set("quiet", true)
		open_btn.pressed.connect(_on_open.bind(index))
		line.add_child(open_btn)
	return line


func _tail(r: Dictionary) -> String:
	var blend: String = str(r.get("blend", "over"))
	var weight: float = float(r.get("weight", 1.0))
	if str(r.get("type", "")) == "keys":
		return ""
	return blend + " " + AnimLayerUi.number_text(weight)


func _on_flip(on: bool, index: int) -> void:
	flipped.emit(index, on)


func _on_open(index: int) -> void:
	opened.emit(index)


func _on_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			begin_drag(index)
		else:
			end_drag()
		return
	if event is InputEventMouseMotion and drag_from >= 0:
		drag_to_y(get_local_mouse_position().y)


func _on_draw() -> void:
	if drag_from < 0 or drag_to < 0:
		return
	var y: float = float(drag_to) * row_h
	if drag_to > drag_from:
		y += row_h
	draw_rect(Rect2(0.0, maxf(y - 1.0, 0.0), size.x, 2.0), Tk.c["accent"], true)
