extends "res://ui/kit/pm_button.gd"

signal changed(id: String)

const PmMenu := preload("res://ui/kit/pm_menu.gd")
const CHEVRON_PX := 14.0

var choices: Array[Dictionary] = []
var value: String = ""
var placeholder: String = "Choose"
var _menu: Control = null


static func make_drop(choices_: Array, value_: String = "") -> Button:
	var script: GDScript = load("res://ui/kit/pm_drop.gd")
	var d: Button = script.new()
	d.call("set_choices", choices_)
	d.call("set_value", value_, false)
	return d


static func choice(id: String, label: String) -> Dictionary:
	return {"id": id, "label": label}


func _init() -> void:
	pressed.connect(_on_open)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	elide = true


func set_choices(list: Array) -> void:
	choices.clear()
	for raw: Variant in list:
		if typeof(raw) == TYPE_DICTIONARY:
			var d: Dictionary = raw
			var id: String = String(d.get("id", ""))
			if id.is_empty():
				print("PmDrop: a choice without an id was dropped")
				continue
			choices.append({"id": id, "label": String(d.get("label", id))})
		elif typeof(raw) == TYPE_STRING:
			choices.append({"id": String(raw), "label": String(raw)})
	_refresh_text()


func has_choice(id: String) -> bool:
	for c: Dictionary in choices:
		if String(c["id"]) == id:
			return true
	return false


func label_for(id: String) -> String:
	for c: Dictionary in choices:
		if String(c["id"]) == id:
			return String(c["label"])
	return ""


func set_value(id: String, emit: bool = true) -> void:
	if not id.is_empty() and not has_choice(id):
		return
	var was: String = value
	value = id
	_refresh_text()
	if emit and was != value:
		changed.emit(value)


func _refresh_text() -> void:
	if value.is_empty():
		text = placeholder
	else:
		text = label_for(value)
	elide_fit()
	queue_redraw()


func _on_open() -> void:
	if disabled:
		return
	var items: Array = []
	for c: Dictionary in choices:
		var id: String = String(c["id"])
		items.append(PmMenu.check_item(id, String(c["label"]), id == value))
	_menu = PmMenu.open(self, items, Vector2(INF, INF), size.x)
	if _menu != null and _menu.is_inside_tree():
		_menu.connect("picked", _on_picked)
		_menu.connect("closed", _on_menu_closed)


func _on_picked(id: String) -> void:
	set_value(id)


func _on_menu_closed() -> void:
	_menu = null


func _restyle() -> void:
	super()
	if not is_inside_tree():
		return
	var extra: float = float(Tk.px(CHEVRON_PX)) + float(Tk.px(Tk.sz("gap")))
	for state: String in PmTheme.BUTTON_STATES:
		var sb: StyleBox = get_theme_stylebox(state)
		if sb is StyleBoxFlat:
			(sb as StyleBoxFlat).content_margin_right = (sb as StyleBoxFlat).content_margin_right + extra
	var focus: StyleBox = get_theme_stylebox("focus")
	if focus is StyleBoxFlat:
		(focus as StyleBoxFlat).content_margin_right = (focus as StyleBoxFlat).content_margin_right + extra
	elide_fit()


func _draw() -> void:
	super()
	var side: float = float(Tk.px(CHEVRON_PX))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var pos := Vector2(size.x - pad - side, (size.y - side) * 0.5)
	Icons.draw(self, "chev_d", Rect2(pos.round(), Vector2(side, side)), _icon_tint())
