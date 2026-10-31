extends Container

signal overflow_picked(id: String)

const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")

var _more: Button = null
var _overflow: Array[Control] = []


static func make() -> Container:
	var script: GDScript = load("res://ui/kit/pm_toolbar.gd")
	var t: Container = script.new()
	return t


func _init() -> void:
	name = "PmToolbar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more = PmButton.make("", "more")
	_more.set("quiet", true)
	_more.name = "More"
	_more.visible = false
	_more.pressed.connect(_on_more)
	add_child(_more)


func add_item(c: Control, id: String = "", label: String = "") -> void:
	var real_id: String = id if not id.is_empty() else String(c.name)
	c.set_meta("pm_id", real_id)
	var real_label: String = label
	if real_label.is_empty():
		if c is Button:
			real_label = (c as Button).text
		if real_label.is_empty() and c.has_meta("pm_tip_text"):
			real_label = String(c.get_meta("pm_tip_text"))
		if real_label.is_empty():
			real_label = real_id.capitalize()
	c.set_meta("pm_label", real_label)
	add_child(c)
	move_child(_more, -1)


func items() -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in get_children():
		if n != _more and n is Control:
			out.append(n)
	return out


func clear() -> void:
	for c: Control in items():
		remove_child(c)
		c.queue_free()
	_overflow.clear()
	_more.visible = false
	queue_sort()


func overflow_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Control in _overflow:
		out.append(String(c.get_meta("pm_id")))
	return out


func _gap() -> float:
	return float(Tk.px(Tk.sz("gap")))


func _get_minimum_size() -> Vector2:
	var h: float = 0.0
	for c: Control in items():
		h = maxf(h, c.get_combined_minimum_size().y)
	var more_min: Vector2 = _more.get_combined_minimum_size()
	return Vector2(more_min.x, maxf(h, more_min.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _sort() -> void:
	var gap: float = _gap()
	var list: Array[Control] = items()
	var total: float = 0.0
	for c: Control in list:
		total += c.get_combined_minimum_size().x
	total += gap * float(maxi(0, list.size() - 1))
	var avail: float = size.x
	var fits_all: bool = total <= avail
	var more_w: float = _more.get_combined_minimum_size().x
	var limit: float = avail if fits_all else avail - more_w - gap
	var x: float = 0.0
	var overflow: Array[Control] = []
	for c: Control in list:
		var w: float = c.get_combined_minimum_size().x
		var shown: bool = overflow.is_empty() and x + w <= limit
		if shown:
			c.visible = true
			fit_child_in_rect(c, Rect2(x, 0.0, w, size.y))
			x += w + gap
		else:
			overflow.append(c)
			c.visible = false
			fit_child_in_rect(c, Rect2(0.0, 0.0, 0.0, 0.0))
	_overflow = overflow
	if overflow.is_empty():
		_more.visible = false
		fit_child_in_rect(_more, Rect2(0.0, 0.0, 0.0, 0.0))
	else:
		_more.visible = true
		fit_child_in_rect(_more, Rect2(maxf(0.0, avail - more_w), 0.0, more_w, size.y))


func _on_more() -> void:
	var menu_items: Array = []
	for c: Control in _overflow:
		var id: String = String(c.get_meta("pm_id"))
		var it: Dictionary = PmMenu.item(id, String(c.get_meta("pm_label")))
		if c is Button and (c as Button).toggle_mode:
			it = PmMenu.check_item(id, String(c.get_meta("pm_label")), (c as Button).button_pressed)
		if c is BaseButton and (c as BaseButton).disabled:
			it["disabled"] = true
		menu_items.append(it)
	var m: Control = PmMenu.open(_more, menu_items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_overflow_picked)


func _on_overflow_picked(id: String) -> void:
	for c: Control in _overflow:
		if String(c.get_meta("pm_id")) != id:
			continue
		if c is Button and (c as Button).toggle_mode:
			(c as Button).button_pressed = not (c as Button).button_pressed
		elif c is BaseButton:
			(c as BaseButton).pressed.emit()
		break
	overflow_picked.emit(id)
