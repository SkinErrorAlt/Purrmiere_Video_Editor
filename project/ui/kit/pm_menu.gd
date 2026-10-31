extends Control

signal picked(id: String)
signal closed

const Icons := preload("res://ui/kit/icons.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SEP_H := 9.0
const MIN_W := 150.0
const KEY_GAP := 28.0
const INSET := 5.0

var items: Array = []
var anchor: Control = null
var anchor_offset: Vector2 = Vector2.ZERO
var follow_anchor: bool = true
var is_sub: bool = false
var parent_menu: Control = null
var min_width: float = 0.0
var hover: int = -1
var scroll_offset: float = 0.0
var _panel: Control = null
var _child: Control = null
var _child_index: int = -1
var _row_h: float = 22.0
var _pad: float = 6.0
var _icon_w: float = 0.0
var _label_w: float = 0.0
var _key_w: float = 0.0
var _content_h: float = 0.0
var _has_check: bool = false
var _has_sub: bool = false
var _press_row: int = -1
var _hover_switch_time: float = 0.0
var _closing: bool = false


static func open(anchor_: Control, items_: Array, at: Vector2 = Vector2(INF, INF), min_w: float = 0.0) -> Control:
	var script: GDScript = load("res://ui/kit/pm_menu.gd")
	var m: Control = script.new()
	m.set("items", items_)
	m.set("anchor", anchor_)
	m.set("min_width", min_w)
	var overlay: Node = PmUI.overlay_for(anchor_)
	if overlay == null:
		return m
	overlay.add_child(m)
	if at.x != INF:
		m.set("follow_anchor", false)
		m.call("place_at", at)
	else:
		m.set("anchor_offset", Vector2(0.0, anchor_.size.y))
		m.call("place_at", anchor_.global_position + Vector2(0.0, anchor_.size.y))
	m.call("take_keys")
	return m


static func open_sub(parent: Control, items_: Array, at: Vector2) -> Control:
	var script: GDScript = load("res://ui/kit/pm_menu.gd")
	var m: Control = script.new()
	m.set("items", items_)
	m.set("is_sub", true)
	m.set("parent_menu", parent)
	m.set("follow_anchor", false)
	parent.add_child(m)
	m.call("place_at", at)
	return m


static func item(id: String, label: String, keys: String = "", icon: String = "") -> Dictionary:
	return {"id": id, "label": label, "keys": keys, "icon": icon, "disabled": false, "sep": false}


static func check_item(id: String, label: String, checked: bool, keys: String = "") -> Dictionary:
	return {"id": id, "label": label, "keys": keys, "icon": "", "disabled": false, "sep": false, "checked": checked}


static func sub_item(id: String, label: String, submenu: Array, icon: String = "") -> Dictionary:
	return {"id": id, "label": label, "keys": "", "icon": icon, "disabled": false, "sep": false, "submenu": submenu}


static func separator() -> Dictionary:
	return {"id": "sep", "label": "", "keys": "", "icon": "", "disabled": true, "sep": true}


func _init() -> void:
	name = "PmMenu"
	focus_mode = Control.FOCUS_ALL
	_panel = _MenuPanel.new()
	_panel.menu = self
	add_child(_panel)


func _ready() -> void:
	if is_sub:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gui_input.connect(_on_input)
	_measure()
	_panel.queue_redraw()
	set_process(true)
	PmUI.pop_in(_panel, Tk.dur("medium"), 0.0, 0.97)


func take_keys() -> void:
	get_viewport().gui_release_focus()
	grab_focus()


func _font() -> Font:
	return Tk.font("body")


func _fsz() -> int:
	return Tk.fs(Tk.sz("font_body"))


func _measure() -> void:
	_row_h = float(Tk.px(Tk.sz("row_h"))) + 4.0
	_pad = float(Tk.px(Tk.sz("pad"))) + 3.0
	var f: Font = _font()
	var fs: int = _fsz()
	_label_w = 0.0
	_key_w = 0.0
	_has_check = false
	_has_sub = false
	var any_icon: bool = false
	var clean: Array = []
	for raw: Variant in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = raw
		if not it.has("id") or String(it["id"]).is_empty():
			print("PmMenu: an item without an id was dropped: ", String(it.get("label", "")))
			continue
		clean.append(it)
		if bool(it.get("sep", false)):
			continue
		if it.has("checked"):
			_has_check = true
		if it.has("submenu"):
			_has_sub = true
		if not String(it.get("icon", "")).is_empty():
			any_icon = true
		_label_w = maxf(_label_w, f.get_string_size(String(it.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		_key_w = maxf(_key_w, f.get_string_size(String(it.get("keys", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	items = clean
	_icon_w = float(Tk.px(20.0)) if (any_icon or _has_check) else 0.0
	_content_h = 0.0
	for it: Dictionary in items:
		_content_h += SEP_H if bool(it.get("sep", false)) else _row_h
	var w: float = _pad * 2.0 + _icon_w + _label_w + (KEY_GAP + _key_w if _key_w > 0.0 else 0.0) + (float(Tk.px(18.0)) if _has_sub else 0.0)
	w = maxf(w, maxf(float(Tk.px(MIN_W)), min_width))
	if is_inside_tree():
		w = minf(w, maxf(get_viewport_rect().size.x - 8.0, float(Tk.px(MIN_W))))
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, _content_h + INSET * 2.0)


func content_size() -> Vector2:
	return _panel.size


func place_at(pos: Vector2) -> void:
	_measure()
	var vp: Rect2 = get_viewport_rect()
	var sz: Vector2 = _panel.size
	var max_h: float = vp.size.y - 8.0
	if sz.y > max_h:
		sz.y = max_h
		_panel.size = sz
	var p: Vector2 = pos
	if p.x + sz.x > vp.size.x - 2.0:
		if is_sub and parent_menu != null:
			var pp: Control = parent_menu.get("_panel")
			p.x = pp.global_position.x - sz.x
		else:
			p.x = vp.size.x - 2.0 - sz.x
	if p.y + sz.y > vp.size.y - 2.0:
		if anchor != null and follow_anchor and not is_sub:
			p.y = anchor.global_position.y - sz.y
		else:
			p.y = vp.size.y - 2.0 - sz.y
	p.x = maxf(0.0, p.x)
	p.y = maxf(0.0, p.y)
	_panel.global_position = p.round()


func _process(_dt: float) -> void:
	if _closing:
		return
	if _panel.modulate.a < 1.0 or _panel.scale != Vector2.ONE:
		queue_redraw()
	if follow_anchor and anchor != null and is_instance_valid(anchor) and anchor.is_inside_tree():
		var want: Vector2 = anchor.global_position + anchor_offset
		if (want - _panel.global_position).length() > 0.5:
			place_at(want)
	elif follow_anchor and anchor != null and not is_instance_valid(anchor):
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	_close_child()
	closed.emit()
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()


func close_all() -> void:
	var root: Control = self
	while root.get("is_sub") and root.get("parent_menu") != null:
		root = root.get("parent_menu")
	root.call("close")


func _close_child() -> void:
	if _child != null and is_instance_valid(_child):
		var ch: Control = _child
		_child = null
		_child_index = -1
		ch.call("close")
	_child = null
	_child_index = -1


func _open_child(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	if not it.has("submenu"):
		return
	if _child_index == index and _child != null:
		return
	_close_child()
	var top: float = _row_top(index)
	var at: Vector2 = _panel.global_position + Vector2(_panel.size.x - 2.0, top - 2.0)
	var script: GDScript = load("res://ui/kit/pm_menu.gd")
	var m: Control = script.new()
	m.set("items", it["submenu"])
	m.set("is_sub", true)
	m.set("parent_menu", self)
	m.set("follow_anchor", false)
	add_child(m)
	m.call("place_at", at)
	m.connect("picked", _on_child_picked)
	_child = m
	_child_index = index


func _on_child_picked(id: String) -> void:
	picked.emit(id)


func _row_top(index: int) -> float:
	var y: float = INSET - scroll_offset
	for i: int in range(index):
		y += SEP_H if bool(items[i].get("sep", false)) else _row_h
	return y


func row_at(local_y: float) -> int:
	var y: float = INSET - scroll_offset
	for i: int in range(items.size()):
		var h: float = SEP_H if bool(items[i].get("sep", false)) else _row_h
		if local_y >= y and local_y < y + h:
			return i
		y += h
	return -1


func set_hover(index: int) -> void:
	if hover == index:
		return
	hover = index
	_panel.queue_redraw()
	if index >= 0 and index < items.size() and items[index].has("submenu"):
		_open_child(index)
	elif index >= 0:
		_close_child()


func pick(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	if bool(it.get("sep", false)) or bool(it.get("disabled", false)):
		return
	if it.has("submenu"):
		_open_child(index)
		return
	var id: String = String(it["id"])
	picked.emit(id)
	close_all()


func _first_enabled(from: int, step: int) -> int:
	if items.is_empty():
		return -1
	var i: int = from
	for _n: int in range(items.size()):
		i = wrapi(i + step, 0, items.size())
		var it: Dictionary = items[i]
		if not bool(it.get("sep", false)) and not bool(it.get("disabled", false)):
			return i
	return -1


func handle_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	if _child != null and is_instance_valid(_child):
		if _child.call("handle_key", event):
			return true
	var code: Key = event.keycode
	if code == KEY_ESCAPE:
		if is_sub and parent_menu != null:
			parent_menu.call("_close_child")
		else:
			close()
		return true
	if code == KEY_DOWN:
		set_hover(_first_enabled(hover, 1))
		return true
	if code == KEY_UP:
		set_hover(_first_enabled(hover if hover >= 0 else 0, -1))
		return true
	if code == KEY_RIGHT:
		if hover >= 0 and items[hover].has("submenu"):
			_open_child(hover)
			if _child != null:
				_child.call("set_hover", _child.call("_first_enabled", -1, 1))
			return true
		return not is_sub
	if code == KEY_LEFT:
		if is_sub and parent_menu != null:
			parent_menu.call("_close_child")
			return true
		return false
	if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
		if hover >= 0:
			pick(hover)
		return true
	return false


func _draw() -> void:
	if _panel == null or _closing:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
	sb.shadow_color = Color(Tk.c["shadow"], (Tk.c["shadow"] as Color).a * _panel.modulate.a)
	sb.shadow_size = Tk.px(10.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(3.0)))
	draw_style_box(sb, Rect2(_panel.position + (Vector2.ONE - _panel.scale) * Vector2(_panel.size.x * 0.5, 0.0), _panel.size * _panel.scale))


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if handle_key(event):
			accept_event()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE):
			accept_event()
			close()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return


func _panel_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		set_hover(row_at(mm.position.y))
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if _content_h + 4.0 > panel.size.y:
				scroll_offset = clampf(scroll_offset + _row_h * 3.0, 0.0, _content_h + 4.0 - panel.size.y)
				panel.queue_redraw()
			panel.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			scroll_offset = clampf(scroll_offset - _row_h * 3.0, 0.0, maxf(0.0, _content_h + 4.0 - panel.size.y))
			panel.queue_redraw()
			panel.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			panel.accept_event()
			if mb.pressed:
				_press_row = row_at(mb.position.y)
			else:
				var r: int = row_at(mb.position.y)
				if r >= 0 and r == _press_row:
					pick(r)
				_press_row = -1


class _MenuPanel:
	extends Control

	var menu: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		gui_input.connect(_on_input)
		mouse_exited.connect(_on_exit)

	func _on_input(event: InputEvent) -> void:
		if menu != null:
			menu.call("_panel_input", event, self)

	func _on_exit() -> void:
		if menu != null and menu.get("_child") == null:
			menu.call("set_hover", -1)

	func _draw() -> void:
		if menu == null:
			return
		var radius: float = float(Tk.px(Tk.sz("radius_menu")))
		var row_radius: float = float(Tk.px(Tk.sz("radius_row")))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tk.c["bg_panel_alt"]
		sb.border_color = Tk.c["border_soft"]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var items_: Array = menu.get("items")
		var row_h: float = menu.get("_row_h")
		var pad: float = menu.get("_pad")
		var icon_w: float = menu.get("_icon_w")
		var has_sub: bool = menu.get("_has_sub")
		var hover_: int = menu.get("hover")
		var f: Font = Tk.font("body")
		var mono: Font = Tk.font("mono")
		var fs: int = Tk.fs(Tk.sz("font_body"))
		var key_fs: int = Tk.fs(Tk.sz("font_small"))
		var y: float = INSET - float(menu.get("scroll_offset"))
		var asc: float = f.get_ascent(fs)
		var desc: float = f.get_descent(fs)
		var chev_w: float = float(Tk.px(18.0)) if has_sub else 0.0
		for i: int in range(items_.size()):
			var it: Dictionary = items_[i]
			if bool(it.get("sep", false)):
				draw_rect(Rect2(INSET + 4.0, y + SEP_H * 0.5, size.x - INSET * 2.0 - 8.0, 1.0), Tk.c["border"], true)
				y += SEP_H
				continue
			var disabled: bool = bool(it.get("disabled", false))
			if i == hover_ and not disabled:
				var hs := StyleBoxFlat.new()
				hs.bg_color = Tk.c["glass"]
				hs.set_corner_radius_all(int(row_radius))
				hs.anti_aliasing = true
				draw_style_box(hs, Rect2(INSET, y, size.x - INSET * 2.0, row_h))
			var col: Color = Tk.c["text_faint"] if disabled else (Tk.c["text_bright"] if i == hover_ else Tk.c["text"])
			var text_y: float = y + (row_h - (asc + desc)) * 0.5 + asc
			var x: float = pad + icon_w
			if it.has("checked") and bool(it["checked"]):
				Icons.draw(self, "check", Rect2(pad, y + (row_h - 14.0) * 0.5, 14.0, 14.0), col)
			elif not String(it.get("icon", "")).is_empty():
				Icons.draw(self, String(it["icon"]), Rect2(pad, y + (row_h - 14.0) * 0.5, 14.0, 14.0), col)
			var row_box := Rect2(0.0, y, size.x, row_h)
			var label_right: float = size.x - pad - chev_w
			var keys: String = String(it.get("keys", ""))
			if not keys.is_empty():
				var kw: float = PmText.width_of(mono, keys, key_fs)
				var kr: Rect2 = PmText.draw_in(self, mono, Rect2(label_right - kw, y, kw, row_h), keys, key_fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, text_y, PmText.WHOLE, row_box)
				if kr.has_area():
					label_right = kr.position.x - float(Tk.px(Tk.sz("gap"))) * 2.0
			PmText.draw_in(self, f, Rect2(x, y, label_right - x, row_h), String(it.get("label", "")), fs, col, HORIZONTAL_ALIGNMENT_LEFT, text_y, PmText.ELIDE, row_box)
			if it.has("submenu"):
				Icons.draw(self, "chev_r", Rect2(size.x - pad - 14.0, y + (row_h - 14.0) * 0.5, 14.0, 14.0), Tk.c["text_faint"] if disabled else Tk.c["text_dim"])
			y += row_h
