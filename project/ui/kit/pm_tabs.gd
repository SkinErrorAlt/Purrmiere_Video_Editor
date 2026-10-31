extends Control

signal tab_changed(id: String)
signal tab_closed(id: String)
signal tab_reordered(ids: PackedStringArray)
signal tab_dragged_out(id: String, at: Vector2)
signal tab_menu(id: String, at: Vector2)
signal tab_double_clicked(id: String)
signal strip_double_clicked

const Icons := preload("res://ui/kit/icons.gd")
const SLOP := 4.0
const OUT_REACH := 14.0
const CLOSE_PX := 12.0

var tabs: Array[Dictionary] = []
var active: String = ""
var scroll_offset: float = 0.0
var closable_default: bool = false
var allow_reorder: bool = true
var allow_drag_out: bool = false
var min_tab_w: float = 40.0
var max_tab_w: float = 220.0
var fit_to_content: bool = false
var _rects: Array[Rect2] = []
var _content_w: float = 0.0
var _hover: int = -1
var _hover_close: bool = false
var _press: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_close: bool = false
var _dragging: bool = false
var _drag_dx: float = 0.0
var ink: Rect2 = Rect2():
	set(v):
		ink = v
		queue_redraw()
var _ink_tween: Tween = null
var _ink_known: bool = false


static func make(closable: bool = false) -> Control:
	var script: GDScript = load("res://ui/kit/pm_tabs.gd")
	var t: Control = script.new()
	t.set("closable_default", closable)
	return t


func _init() -> void:
	name = "PmTabs"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	gui_input.connect(_on_input)
	mouse_exited.connect(_on_exit)
	resized.connect(_on_resized)


func _ready() -> void:
	custom_minimum_size = Vector2(0, float(Tk.px(Tk.sz("tab_h"))))
	_layout()


func _font() -> Font:
	return Tk.font("body")


func _fsz() -> int:
	return Tk.fs(Tk.sz("font_body"))


func add_tab(id: String, label: String, closable: int = -1) -> void:
	if id.is_empty():
		print("PmTabs: a tab without an id was refused")
		return
	if has_tab(id):
		set_label(id, label)
		return
	tabs.append({"id": id, "label": label, "closable": closable_default if closable < 0 else closable > 0})
	if active.is_empty():
		active = id
	_layout()


func remove_tab(id: String) -> void:
	var i: int = index_of(id)
	if i < 0:
		return
	tabs.remove_at(i)
	if active == id:
		active = ""
		if not tabs.is_empty():
			var j: int = clampi(i, 0, tabs.size() - 1)
			active = String(tabs[j]["id"])
	_layout()


func clear_tabs() -> void:
	tabs.clear()
	active = ""
	_layout()


func has_tab(id: String) -> bool:
	return index_of(id) >= 0


func index_of(id: String) -> int:
	for i: int in range(tabs.size()):
		if String(tabs[i]["id"]) == id:
			return i
	return -1


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for t: Dictionary in tabs:
		out.append(String(t["id"]))
	return out


func count() -> int:
	return tabs.size()


func set_label(id: String, label: String) -> void:
	var i: int = index_of(id)
	if i >= 0:
		tabs[i]["label"] = label
		_layout()


func set_active(id: String, emit: bool = true) -> void:
	if not has_tab(id) or active == id:
		return
	active = id
	ensure_visible(id)
	_move_ink(true)
	queue_redraw()
	if emit:
		tab_changed.emit(id)


func _ink_target() -> Rect2:
	var i: int = index_of(active)
	if i < 0 or i >= _rects.size():
		return Rect2()
	var r: Rect2 = _rects[i]
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 2.0
	return Rect2(r.position.x + pad, r.end.y - 2.0, maxf(0.0, r.size.x - pad * 2.0), 2.0)


func _move_ink(animate: bool) -> void:
	var target: Rect2 = _ink_target()
	if _ink_tween != null and _ink_tween.is_valid():
		_ink_tween.kill()
	_ink_tween = null
	var d: float = Tk.dur("tab")
	if not animate or not _ink_known or d <= 0.0 or not is_inside_tree() or ink.size.x <= 0.0 or target.size.x <= 0.0:
		ink = target
		_ink_known = target.size.x > 0.0
		return
	_ink_tween = Tk.ease(create_tween())
	_ink_tween.tween_property(self, "ink", target, d)


func set_order(order: PackedStringArray) -> void:
	var fresh: Array[Dictionary] = []
	for id: String in order:
		var i: int = index_of(id)
		if i >= 0:
			fresh.append(tabs[i])
	for t: Dictionary in tabs:
		if not (String(t["id"]) in order):
			fresh.append(t)
	tabs = fresh
	_layout()


func content_width() -> float:
	return _content_w


func max_scroll() -> float:
	return maxf(0.0, _content_w - size.x)


func label_width(label: String) -> float:
	var plain: float = _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _fsz()).x
	var bold: float = Tk.font("body_medium").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _fsz()).x
	return ceil(maxf(plain, bold))


func _text_room(i: int) -> float:
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	var w: float = _rects[i].size.x - pad * 2.0
	if bool(tabs[i]["closable"]):
		w -= float(Tk.px(CLOSE_PX)) + float(Tk.px(Tk.sz("gap")))
	return maxf(w, 0.0)


func is_elided(i: int) -> bool:
	if i < 0 or i >= tabs.size() or i >= _rects.size():
		return false
	return label_width(String(tabs[i]["label"])) > _text_room(i) + 0.5


func fit_texts() -> Array:
	var out: Array = []
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	for i: int in range(mini(tabs.size(), _rects.size())):
		var r: Rect2 = _rects[i]
		r.position.x -= scroll_offset
		if r.position.x < -0.5 or r.end.x > size.x + 0.5:
			continue
		var label: String = String(tabs[i]["label"])
		var need: float = label_width(label)
		var room: float = _text_room(i)
		var drawn: float = minf(need, room)
		out.append({"text": label, "rect": Rect2(r.position.x + pad, 0.0, drawn, r.size.y), "need": need, "box": r, "pad": float(Tk.px(Tk.sz("pad"))), "elided": need > room + 0.5, "tip": true})
	return out


func _tip_for_hover() -> void:
	var PmTip: GDScript = load("res://ui/kit/pm_tip.gd")
	var tip: Control = PmTip.call("instance_for", self)
	if tip == null:
		return
	if _hover >= 0 and is_elided(_hover):
		PmTip.call("attach", self, String(tabs[_hover]["label"]))
		tip.call("arm", self)
	else:
		PmTip.call("attach", self, "")
		if tip.get("target") == self:
			tip.call("disarm", self)


func _tab_width(t: Dictionary) -> float:
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	var w: float = label_width(String(t["label"])) + pad * 2.0
	if bool(t["closable"]):
		w += float(Tk.px(CLOSE_PX)) + float(Tk.px(Tk.sz("gap")))
	return clampf(ceil(w), float(Tk.px(min_tab_w)), float(Tk.px(max_tab_w)))


func fitted_widths() -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	var total: float = 0.0
	for t: Dictionary in tabs:
		var w: float = _tab_width(t)
		widths.append(w)
		total += w
	if fit_to_content or size.x <= 0.0 or total <= size.x:
		return widths
	var floors := PackedFloat32Array()
	var give: float = 0.0
	for i: int in widths.size():
		var f: float = minf(widths[i], _shrink_floor(tabs[i]))
		floors.append(f)
		give += widths[i] - f
	if give <= 0.0:
		return widths
	var k: float = clampf((total - size.x) / give, 0.0, 1.0)
	for i: int in widths.size():
		widths[i] = floor(widths[i] - (widths[i] - floors[i]) * k)
	return widths


func _shrink_floor(t: Dictionary) -> float:
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	var w: float = pad * 2.0 + float(Tk.px(24.0))
	if bool(t["closable"]):
		w += float(Tk.px(CLOSE_PX)) + float(Tk.px(Tk.sz("gap")))
	return maxf(w, float(Tk.px(min_tab_w)))


func _layout() -> void:
	_rects.clear()
	var x: float = 0.0
	var h: float = maxf(size.y, float(Tk.px(Tk.sz("tab_h"))))
	var widths: PackedFloat32Array = fitted_widths()
	for i: int in tabs.size():
		var w: float = widths[i]
		_rects.append(Rect2(x, 0.0, w, h))
		x += w
	_content_w = x
	scroll_offset = clampf(scroll_offset, 0.0, max_scroll())
	if fit_to_content:
		custom_minimum_size = Vector2(_content_w, float(Tk.px(Tk.sz("tab_h"))))
	_move_ink(false)
	queue_redraw()


func _on_resized() -> void:
	_layout()


func ensure_visible(id: String) -> void:
	var i: int = index_of(id)
	if i < 0 or i >= _rects.size():
		return
	var r: Rect2 = _rects[i]
	if r.position.x < scroll_offset:
		scroll_offset = r.position.x
	elif r.end.x > scroll_offset + size.x:
		scroll_offset = r.end.x - size.x
	scroll_offset = clampf(scroll_offset, 0.0, max_scroll())
	queue_redraw()


func tab_at(local: Vector2) -> int:
	var x: float = local.x + scroll_offset
	for i: int in range(_rects.size()):
		if x >= _rects[i].position.x and x < _rects[i].end.x:
			return i
	return -1


func insert_index_at(local_x: float) -> int:
	var x: float = local_x + scroll_offset
	for i: int in range(_rects.size()):
		if x < _rects[i].get_center().x:
			return i
	return _rects.size()


func _close_rect(i: int) -> Rect2:
	var r: Rect2 = _rects[i]
	var side: float = float(Tk.px(CLOSE_PX))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	return Rect2(r.end.x - pad - side, (r.size.y - side) * 0.5, side, side)


func _is_on_close(i: int, local: Vector2) -> bool:
	if i < 0 or i >= tabs.size() or not bool(tabs[i]["closable"]):
		return false
	var p: Vector2 = local + Vector2(scroll_offset, 0.0)
	return _close_rect(i).grow(2.0).has_point(p)


func _on_exit() -> void:
	if _hover != -1 or _hover_close:
		_hover = -1
		_hover_close = false
		queue_redraw()


func _end_drag() -> void:
	_dragging = false
	_press = -1
	_press_close = false
	_drag_dx = 0.0
	queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _press >= 0 and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_motion(mm.position)
			return
		var i: int = tab_at(mm.position)
		var on_close: bool = _is_on_close(i, mm.position)
		if i != _hover or on_close != _hover_close:
			var moved: bool = i != _hover
			_hover = i
			_hover_close = on_close
			queue_redraw()
			if moved:
				_tip_for_hover()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.pressed and max_scroll() > 0.0:
				var dir: float = -1.0 if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT) else 1.0
				scroll_offset = clampf(scroll_offset + dir * float(Tk.px(48.0)), 0.0, max_scroll())
				queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var i: int = tab_at(mb.position)
				if mb.double_click:
					_end_drag()
					if i >= 0:
						tab_double_clicked.emit(String(tabs[i]["id"]))
					else:
						strip_double_clicked.emit()
					accept_event()
					return
				_press = i
				_press_pos = mb.position
				_press_close = _is_on_close(i, mb.position)
				_dragging = false
				_drag_dx = 0.0
				accept_event()
			else:
				_release(mb.position)
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var i: int = tab_at(mb.position)
			if i >= 0:
				tab_menu.emit(String(tabs[i]["id"]), get_global_mouse_position())
			accept_event()


func _release(pos: Vector2) -> void:
	var i: int = _press
	var was_dragging: bool = _dragging
	var was_close: bool = _press_close
	_end_drag()
	if i < 0 or i >= tabs.size():
		return
	if was_dragging:
		tab_reordered.emit(ids())
		return
	var here: int = tab_at(pos)
	if here != i:
		return
	var id: String = String(tabs[i]["id"])
	if was_close and _is_on_close(i, pos):
		tab_closed.emit(id)
		return
	set_active(id)


func _drag_motion(pos: Vector2) -> void:
	if _press < 0 or _press >= tabs.size():
		return
	if not _dragging:
		if (pos - _press_pos).length() < SLOP:
			return
		if _press_close:
			return
		_dragging = true
	var id: String = String(tabs[_press]["id"])
	if allow_drag_out and (pos.y < -OUT_REACH or pos.y > size.y + OUT_REACH):
		var at: Vector2 = get_global_mouse_position()
		_end_drag()
		tab_dragged_out.emit(id, at)
		return
	if not allow_reorder:
		return
	_drag_dx = pos.x - _press_pos.x
	var r: Rect2 = _rects[_press]
	var centre: float = r.get_center().x + _drag_dx
	if _press > 0 and centre < _rects[_press - 1].get_center().x:
		_swap(_press, _press - 1)
	elif _press < tabs.size() - 1 and centre > _rects[_press + 1].get_center().x:
		_swap(_press, _press + 1)
	queue_redraw()


func _swap(a: int, b: int) -> void:
	var t: Dictionary = tabs[a]
	tabs[a] = tabs[b]
	tabs[b] = t
	var old_x: float = _rects[a].position.x
	_layout()
	var new_x: float = _rects[b].position.x
	_press_pos.x += new_x - old_x
	_drag_dx -= new_x - old_x
	_press = b


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
	draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Tk.c["border"], true)
	var f: Font = _font()
	var f_active: Font = Tk.font("body_medium")
	var fs: int = _fsz()
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	var asc: float = f.get_ascent(fs)
	var desc: float = f.get_descent(fs)
	var row_radius: int = Tk.px(Tk.sz("radius_row"))
	var order: Array[int] = []
	for i: int in range(tabs.size()):
		if not (_dragging and i == _press):
			order.append(i)
	if _dragging and _press >= 0 and _press < tabs.size():
		order.append(_press)
	for i: int in order:
		var t: Dictionary = tabs[i]
		var r: Rect2 = _rects[i]
		r.position.x -= scroll_offset
		if _dragging and i == _press:
			r.position.x += _drag_dx
		if r.end.x < 0.0 or r.position.x > size.x:
			continue
		var id: String = String(t["id"])
		var is_active: bool = id == active
		var is_hover: bool = i == _hover
		if (is_hover and not is_active) or (_dragging and i == _press):
			var hs := StyleBoxFlat.new()
			hs.bg_color = Tk.c["glass"]
			hs.set_corner_radius_all(row_radius)
			hs.anti_aliasing = true
			draw_style_box(hs, Rect2(r.position + Vector2(3.0, 4.0), r.size - Vector2(6.0, 9.0)))
		if _dragging and i == _press and is_active:
			draw_rect(Rect2(r.position.x + pad - 2.0, r.end.y - 2.0, r.size.x - pad * 2.0 + 4.0, 2.0), Tk.c["sol"], true)
		var col: Color = Tk.c["text_bright"] if is_active else (Tk.c["text"] if is_hover else Tk.c["text_dim"])
		var text_w: float = r.size.x - pad * 2.0
		if bool(t["closable"]):
			text_w -= float(Tk.px(CLOSE_PX)) + float(Tk.px(Tk.sz("gap")))
		var line := TextLine.new()
		line.add_string(String(t["label"]), f_active if is_active else f, fs)
		line.width = maxf(0.0, text_w)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var y: float = (r.size.y - (asc + desc)) * 0.5
		line.draw(get_canvas_item(), Vector2(r.position.x + pad, y), col)
		if bool(t["closable"]) and (is_active or is_hover):
			var cr: Rect2 = _close_rect(i)
			cr.position.x -= scroll_offset
			if _dragging and i == _press:
				cr.position.x += _drag_dx
			var ccol: Color = Tk.c["text_bright"] if (is_hover and _hover_close) else Tk.c["text_dim"]
			Icons.draw(self, "close", cr, ccol)
	if ink.size.x > 0.0 and not (_dragging and index_of(active) == _press):
		var ir: Rect2 = ink
		ir.position.x -= scroll_offset
		var ink_sb := StyleBoxFlat.new()
		ink_sb.bg_color = Tk.c["sol"]
		ink_sb.set_corner_radius_all(1)
		ink_sb.anti_aliasing = true
		draw_style_box(ink_sb, ir)
