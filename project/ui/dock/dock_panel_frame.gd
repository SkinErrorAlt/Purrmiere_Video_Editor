extends Control

signal tab_activated(frame: Control, id: String)
signal tab_close_requested(frame: Control, id: String)
signal tab_dragged_out(frame: Control, id: String, at: Vector2)
signal tab_reordered(frame: Control, ids: PackedStringArray)
signal menu_action(frame: Control, action: String, id: String)
signal panel_dropped(frame: Control, payload: Dictionary, zone: String, index: int)
signal maximise_requested(frame: Control, id: String)

const PmTabs := preload("res://ui/kit/pm_tabs.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const EDGE_FRACTION := 0.25
const MIN_W := 200.0
const ZONES: PackedStringArray = ["l", "r", "t", "b", "c", "tabs"]

var uid: int = 0
var tabs: Control = null
var body: Control = null
var holder: Control = null
var focused: bool = false:
	set(v):
		focused = v
		queue_redraw()
		if _overlay != null:
			_overlay.queue_redraw()
var hover_zone: String = ""
var locked: bool = false
var hover_index: int = -1
var _menu_btn: Button = null
var _strip: HBoxContainer = null
var _tab_slot: Control = null
var _overlay: Control = null


func _init() -> void:
	name = "DockPanelFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_strip = HBoxContainer.new()
	_strip.name = "Strip"
	_strip.add_theme_constant_override("separation", 0)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	tabs = PmTabs.make(false)
	tabs.set("allow_drag_out", true)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.connect("tab_changed", _on_tab_changed)
	tabs.connect("tab_closed", _on_tab_closed)
	tabs.connect("tab_dragged_out", _on_tab_dragged_out)
	tabs.connect("tab_reordered", _on_tab_reordered)
	tabs.connect("tab_menu", _on_tab_menu)
	tabs.connect("tab_double_clicked", _on_tab_double_clicked)
	_strip.add_child(tabs)
	_menu_btn = PmButton.make("", "more")
	_menu_btn.set("quiet", true)
	_menu_btn.pressed.connect(_on_menu)
	_strip.add_child(_menu_btn)
	_tab_slot = PmSlot.make(PackedStringArray(["panel"]))
	_tab_slot.name = "TabSlot"
	_tab_slot.set("draw_highlight", false)
	_tab_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_slot.connect("dropped", _on_tab_slot_dropped)
	_tab_slot.connect("hover_changed", _on_slot_hover_changed)
	_tab_slot.connect("hover_moved", _on_tab_slot_hover_moved)
	add_child(_tab_slot)
	body = PmSlot.make(PackedStringArray(["panel"]))
	body.name = "Body"
	body.set("draw_highlight", false)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.connect("dropped", _on_body_dropped)
	body.connect("hover_changed", _on_slot_hover_changed)
	body.connect("hover_moved", _on_body_hover_moved)
	add_child(body)
	holder = Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(holder)
	_overlay = _FrameOverlay.new()
	_overlay.frame = self
	add_child(_overlay)
	resized.connect(_layout)


func _ready() -> void:
	_menu_btn.set("icon_px", 14.0)
	PmUI.tip(_menu_btn, "Panel menu")
	_layout()


func _get_minimum_size() -> Vector2:
	return Vector2(float(Tk.px(MIN_W)), 0.0)


func _layout() -> void:
	var th: float = float(Tk.px(Tk.sz("tab_h")))
	_strip.position = Vector2.ZERO
	_strip.size = Vector2(size.x, th)
	_tab_slot.position = Vector2.ZERO
	_tab_slot.size = Vector2(size.x, th)
	body.position = Vector2(0.0, th)
	body.size = Vector2(size.x, maxf(0.0, size.y - th))
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	queue_redraw()


func set_tabs(entries: Array[Dictionary], active: String) -> void:
	tabs.call("clear_tabs")
	for e: Dictionary in entries:
		tabs.call("add_tab", String(e["id"]), String(e["label"]), 1)
	if not active.is_empty():
		tabs.call("set_active", active, false)


func active_id() -> String:
	return String(tabs.get("active"))


func ids() -> PackedStringArray:
	return tabs.call("ids")


func has_panel(id: String) -> bool:
	return bool(tabs.call("has_tab", id))


func show_content(c: Control) -> void:
	for child: Node in holder.get_children():
		if child != c:
			holder.remove_child(child)
	if c == null:
		return
	if c.get_parent() != holder:
		var old: Node = c.get_parent()
		if old != null:
			old.remove_child(c)
		holder.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = true
	c.modulate.a = 1.0


func release_content() -> Control:
	if holder.get_child_count() == 0:
		return null
	var c: Control = holder.get_child(0)
	holder.remove_child(c)
	return c


func _on_tab_changed(id: String) -> void:
	tab_activated.emit(self, id)


func _on_tab_closed(id: String) -> void:
	tab_close_requested.emit(self, id)


func _on_tab_dragged_out(id: String, at: Vector2) -> void:
	tab_dragged_out.emit(self, id, at)


func _on_tab_reordered(ids_: PackedStringArray) -> void:
	tab_reordered.emit(self, ids_)


func _on_tab_double_clicked(id: String) -> void:
	maximise_requested.emit(self, id)


func _menu_items(id: String) -> Array:
	var items: Array = []
	items.append(PmMenu.item("close", "Close panel"))
	items.append(PmMenu.item("undock", "Undock panel"))
	items.append(PmMenu.item("maximise", "Maximise or restore", "`"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("close_others", "Close other tabs"))
	items.append(PmMenu.item("panel_list", "Open panel"))
	if id.is_empty():
		items[0]["disabled"] = true
		items[1]["disabled"] = true
		items[2]["disabled"] = true
		items[4]["disabled"] = true
	if locked:
		items[0]["disabled"] = true
		items[1]["disabled"] = true
		items[4]["disabled"] = true
	return items


func _on_menu() -> void:
	var id: String = active_id()
	var m: Control = PmMenu.open(_menu_btn, _menu_items(id))
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked.bind(id))


func _on_tab_menu(id: String, at: Vector2) -> void:
	var m: Control = PmMenu.open(tabs, _menu_items(id), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked.bind(id))


func _on_menu_picked(action: String, id: String) -> void:
	menu_action.emit(self, action, id)


func zone_for(local: Vector2) -> String:
	var r: Rect2 = Rect2(Vector2.ZERO, body.size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return "c"
	var fx: float = local.x / r.size.x
	var fy: float = local.y / r.size.y
	var dl: float = fx
	var dr: float = 1.0 - fx
	var dt: float = fy
	var db: float = 1.0 - fy
	var m: float = minf(minf(dl, dr), minf(dt, db))
	if m > EDGE_FRACTION:
		return "c"
	if m == dl:
		return "l"
	if m == dr:
		return "r"
	if m == dt:
		return "t"
	return "b"


func _on_slot_hover_changed(on: bool) -> void:
	if not on:
		hover_zone = ""
		hover_index = -1
		queue_redraw()


func _on_body_hover_moved(local: Vector2) -> void:
	var z: String = zone_for(local)
	if z != hover_zone:
		hover_zone = z
		hover_index = -1
		queue_redraw()


func _on_tab_slot_hover_moved(local: Vector2) -> void:
	var idx: int = int(tabs.call("insert_index_at", local.x))
	if hover_zone != "tabs" or idx != hover_index:
		hover_zone = "tabs"
		hover_index = idx
		queue_redraw()


func _on_body_dropped(payload: Dictionary, local: Vector2) -> void:
	var z: String = zone_for(local)
	hover_zone = ""
	queue_redraw()
	panel_dropped.emit(self, payload, z, -1)


func _on_tab_slot_dropped(payload: Dictionary, local: Vector2) -> void:
	var idx: int = int(tabs.call("insert_index_at", local.x))
	hover_zone = ""
	hover_index = -1
	queue_redraw()
	panel_dropped.emit(self, payload, "tabs", idx)


func zone_rect(zone: String) -> Rect2:
	var b: Rect2 = Rect2(body.position, body.size)
	if zone == "l":
		return Rect2(b.position, Vector2(b.size.x * 0.5, b.size.y))
	if zone == "r":
		return Rect2(b.position + Vector2(b.size.x * 0.5, 0.0), Vector2(b.size.x * 0.5, b.size.y))
	if zone == "t":
		return Rect2(b.position, Vector2(b.size.x, b.size.y * 0.5))
	if zone == "b":
		return Rect2(b.position + Vector2(0.0, b.size.y * 0.5), Vector2(b.size.x, b.size.y * 0.5))
	if zone == "c":
		return b
	if zone == "tabs":
		return Rect2(_tab_slot.position, _tab_slot.size)
	return Rect2()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
	if _overlay != null:
		_overlay.queue_redraw()


class _FrameOverlay:
	extends Control

	var frame: Control = null

	func _init() -> void:
		name = "Overlay"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		if frame == null:
			return
		var zone: String = String(frame.get("hover_zone"))
		if not zone.is_empty():
			var zr: Rect2 = frame.call("zone_rect", zone)
			var idx: int = int(frame.get("hover_index"))
			if zone == "tabs" and idx >= 0:
				var tabs_: Control = frame.get("tabs")
				var x: float = 0.0
				var rects: Array = tabs_.get("_rects")
				var off: float = float(tabs_.get("scroll_offset"))
				if idx < rects.size():
					x = (rects[idx] as Rect2).position.x - off
				elif rects.size() > 0:
					x = (rects[rects.size() - 1] as Rect2).end.x - off
				draw_rect(Rect2(x - 1.0, 2.0, 2.0, zr.size.y - 4.0), Tk.c["accent"], true)
			else:
				draw_rect(zr, Tk.c["selection_fill"], true)
				draw_rect(Rect2(zr.position + Vector2(0.5, 0.5), zr.size - Vector2(1.0, 1.0)), Tk.c["accent"], false, 1.0)
		_draw_card_edge(bool(frame.get("focused")))

	func _draw_card_edge(focused_: bool) -> void:
		var radius: float = float(Tk.px(Tk.sz("radius_dock")))
		if radius <= 0.0 or size.x < radius * 2.0 or size.y < radius * 2.0:
			if focused_:
				draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
			return
		var mask: Color = Tk.c["bg_app"]
		var steps: int = 8
		for corner: int in range(4):
			var cx: float = radius if (corner == 0 or corner == 3) else size.x - radius
			var cy: float = radius if (corner == 0 or corner == 1) else size.y - radius
			var sx: float = 0.0 if (corner == 0 or corner == 3) else size.x
			var sy: float = 0.0 if (corner == 0 or corner == 1) else size.y
			var a0: float = PI + float(corner) * PI * 0.5
			var pts := PackedVector2Array()
			pts.append(Vector2(sx, sy))
			for i: int in range(steps + 1):
				var a: float = a0 + PI * 0.5 * float(i) / float(steps)
				pts.append(Vector2(cx + cos(a) * radius, cy + sin(a) * radius))
			draw_colored_polygon(pts, mask)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Tk.c["border_soft"] if focused_ else Tk.c["border"]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
