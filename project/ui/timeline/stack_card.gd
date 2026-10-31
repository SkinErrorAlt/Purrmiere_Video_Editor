extends Control

signal reordered(front_to_back: PackedStringArray)
signal row_picked(clip_id: String)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmTip := preload("res://ui/kit/pm_tip.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const STACKS_PATH := "res://ui/timeline/timeline_stacks.gd"
const CARD_W := 228.0
const ROW_H := 28.0
const TITLE_H := 22.0
const HINT_H := 22.0
const GAP := 8.0
const SLOP := 4.0
const SWAY := 5.0
const DOT_R := 2.5
const TITLE := "Clips here"
const HINT := "Drag a row to change the order"
const KIND_PICTURE := "Picture"
const KIND_SOUND := "Sound"
const FRONT := "Front"

var canvas: Control = null
var track_id: String = ""
var time: float = 0.0
var at: Vector2 = Vector2.ZERO
var menu: Control = null
var ids: PackedStringArray = PackedStringArray()
var hot_index: int = -1
var drop_index: int = -1
var dragging: bool = false
var closed_count: int = 0
var _panel: PanelContainer = null
var _rows_box: VBoxContainer = null
var _title: Label = null
var _rows: Array[Control] = []
var _press_index: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _rebuilding_menu: bool = false
var _closing: bool = false


func setup(p_canvas: Control, p_track_id: String, p_time: float, p_at: Vector2) -> void:
	canvas = p_canvas
	track_id = p_track_id
	time = p_time
	at = p_at


func _init() -> void:
	name = "StackCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	refresh(true)
	_place()
	PmUI.pop_in(_panel, Tk.dur("medium"), 0.0, 0.97)
	set_process(true)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
	var inset: float = float(Tk.px(5.0))
	sb.content_margin_left = inset
	sb.content_margin_right = inset
	sb.content_margin_top = inset
	sb.content_margin_bottom = inset
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(10.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(3.0)))
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(float(Tk.px(CARD_W)), 0.0)
	add_child(_panel)
	var col: VBoxContainer = PmUI.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	var title_box := MarginContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad(title_box)
	title_box.custom_minimum_size = Vector2(0.0, float(Tk.px(TITLE_H)))
	_title = PmLabel.meta(TITLE)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(_title)
	col.add_child(title_box)
	_rows_box = PmUI.vbox(0)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows_box)
	var hint_box := MarginContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad(hint_box)
	hint_box.custom_minimum_size = Vector2(0.0, float(Tk.px(HINT_H)))
	var hint: Label = PmLabel.faint(HINT)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.clip_text = true
	hint_box.add_child(hint)
	col.add_child(hint_box)


func _pad(box: MarginContainer) -> void:
	var pad: int = Tk.px(Tk.sz("pad"))
	box.add_theme_constant_override("margin_left", pad)
	box.add_theme_constant_override("margin_right", pad)
	box.add_theme_constant_override("margin_top", 0)
	box.add_theme_constant_override("margin_bottom", 0)


func seq() -> Sequence:
	return canvas.call("seq") if canvas != null and is_instance_valid(canvas) else null


func doc() -> Project:
	return canvas.call("doc") if canvas != null and is_instance_valid(canvas) else null


func track() -> Track:
	var s: Sequence = seq()
	return s.track_by_id(track_id) if s != null else null


func current_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var s: Sequence = seq()
	var tr: Track = track()
	if s == null or tr == null:
		return out
	for c: Clip in Verbs.clips_under(s, tr, time):
		out.append(c.id)
	return out


func refresh(force: bool = false) -> void:
	var now: PackedStringArray = current_ids()
	if not force and now == ids:
		return
	ids = now
	PmUI.clear(_rows_box)
	_rows = []
	var s: Sequence = seq()
	var tr: Track = track()
	var d: Project = doc()
	_title.text = (TITLE + "  " + str(ids.size())).to_upper()
	for i: int in ids.size():
		var c: Clip = s.clip_by_id(ids[i]) if s != null else null
		if c == null:
			continue
		var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
		var row: _Row = _Row.new()
		row.card = self
		row.index = i
		row.clip_id = c.id
		row.custom_minimum_size = Vector2(0.0, float(Tk.px(ROW_H)))
		var name_: String = c.label if not c.label.is_empty() else (item.label if item != null else c.id)
		row.fill(Paint.clip_colour(c, item, tr), name_, KIND_PICTURE if tr.is_picture(c) else KIND_SOUND, i == 0)
		PmTip.attach(row, name_)
		_rows_box.add_child(row)
		_rows.append(row)
	if ids.is_empty():
		close()


func attach_menu(m: Control) -> void:
	menu = m
	if menu != null and menu.has_signal("closed"):
		menu.connect("closed", _on_menu_closed)
	var p: Node = get_parent()
	if p != null:
		p.move_child(self, -1)
	_place()


func _on_menu_closed() -> void:
	closed_count += 1
	if _rebuilding_menu:
		return
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	PmUI.free_node(self)


func _menu_panel() -> Control:
	if menu == null or not is_instance_valid(menu):
		return null
	var mp: Variant = menu.get("_panel")
	return mp if mp is Control else null


func _place() -> void:
	if _panel == null:
		return
	var w: float = maxf(_panel.size.x, _panel.get_combined_minimum_size().x)
	var mp: Control = _menu_panel()
	var top_left: Vector2 = at
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	if mp != null:
		var mg: Transform2D = mp.get_global_transform_with_canvas()
		var mpos: Vector2 = inv * mg.origin
		top_left = Vector2(mpos.x - float(Tk.px(GAP)) - w, mpos.y)
		if top_left.x < 2.0:
			top_left.x = mpos.x + mp.size.x + float(Tk.px(GAP))
	else:
		top_left = inv * at - Vector2(w + float(Tk.px(GAP)), 0.0)
	var h: float = maxf(_panel.size.y, _panel.get_combined_minimum_size().y)
	top_left.y = _clear_of_lane(top_left.y, h)
	top_left.x = clampf(top_left.x, 2.0, maxf(size.x - w - 2.0, 2.0))
	top_left.y = clampf(top_left.y, 2.0, maxf(size.y - h - 2.0, 2.0))
	if (_panel.position - top_left).length() > 0.5:
		_panel.position = top_left.round()


func lane_band() -> Vector2:
	if canvas == null or not is_instance_valid(canvas):
		return Vector2(-1.0, -1.0)
	var lane: Dictionary = Lanes.lane_for_track(canvas.call("lanes"), track_id)
	if lane.is_empty():
		return Vector2(-1.0, -1.0)
	var geom: Dictionary = canvas.call("geometry")
	var y: float = float(Hit.lane_screen_y(geom, lane))
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse() * canvas.get_global_transform_with_canvas()
	return Vector2((to_local * Vector2(0.0, y)).y, (to_local * Vector2(0.0, y + float(lane["h"]))).y)


func _clear_of_lane(top: float, h: float) -> float:
	var band: Vector2 = lane_band()
	if band.y <= band.x or top + h <= band.x or top >= band.y:
		return top
	var gap: float = float(Tk.px(GAP))
	if band.y + gap + h <= size.y - 2.0:
		return band.y + gap
	if band.x - gap - h >= 2.0:
		return band.x - gap - h
	return top


func _process(_dt: float) -> void:
	if _closing:
		return
	if canvas == null or not is_instance_valid(canvas) or not canvas.is_inside_tree():
		close()
		return
	refresh()
	_place()
	queue_redraw()


func row_event(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_index = index
			_press_pos = mb.global_position
			dragging = false
			drop_index = -1
			return
		var was_drag: bool = dragging
		var from: int = _press_index
		_lift(from, false)
		_press_index = -1
		dragging = false
		if was_drag:
			var to: int = drop_index
			drop_index = -1
			_apply_drop(from, to)
		elif from == index:
			pick_row(index)
		queue_redraw()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _press_index < 0:
			return
		if not dragging and (mm.global_position - _press_pos).length() >= float(Tk.px(SLOP)):
			dragging = true
			_lift(_press_index, true)
		if dragging:
			drop_index = _drop_at(mm.global_position)
			queue_redraw()


func _lift(index: int, on: bool) -> void:
	if index >= 0 and index < _rows.size():
		_rows[index].modulate.a = 0.55 if on else 1.0


func _drop_at(global_pos: Vector2) -> int:
	if _rows.is_empty():
		return 0
	for i: int in _rows.size():
		var r: Rect2 = _rows[i].get_global_rect()
		if global_pos.y < r.get_center().y:
			return i
	return _rows.size()


func _apply_drop(from: int, to: int) -> void:
	if from < 0 or from >= ids.size() or to < 0:
		return
	var order: PackedStringArray = ids.duplicate()
	var moving: String = order[from]
	order.remove_at(from)
	var at_i: int = to if to <= from else to - 1
	order.insert(clampi(at_i, 0, order.size()), moving)
	if order == ids:
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if Verbs.set_stack_order(d, s, order):
		reordered.emit(order)
		refresh(true)


func set_hot(index: int) -> void:
	if hot_index == index:
		return
	hot_index = index
	for r: Control in _rows:
		r.queue_redraw()
	queue_redraw()


func pick_row(index: int) -> void:
	if index < 0 or index >= ids.size():
		return
	var s: Sequence = seq()
	var c: Clip = s.clip_by_id(ids[index]) if s != null else null
	if c == null:
		return
	canvas.call("click_select", c.id, {})
	row_picked.emit(c.id)
	var stacks: GDScript = load(STACKS_PATH)
	_rebuilding_menu = true
	if menu != null and is_instance_valid(menu):
		menu.call("close")
	_rebuilding_menu = false
	var m: Control = stacks.call("open_clip_menu", canvas, c, time, at)
	attach_menu(m)
	for r: Control in _rows:
		r.queue_redraw()


func is_selected(clip_id: String) -> bool:
	var s: Sequence = seq()
	return s != null and s.selected_clip_ids.has(clip_id)


func clip_screen_rect(clip_id: String) -> Rect2:
	var s: Sequence = seq()
	if s == null or canvas == null:
		return Rect2()
	var c: Clip = s.clip_by_id(clip_id)
	var lane: Dictionary = Lanes.lane_for_track(canvas.call("lanes"), track_id)
	if c == null or lane.is_empty():
		return Rect2()
	var geom: Dictionary = canvas.call("geometry")
	var r: Rect2 = Hit.clip_rect(geom, lane, c)
	var header_w: float = float(geom["header_w"])
	var region: Rect2 = geom["main_rect"] if String(lane["set"]) == "main" else geom["band_rect"]
	var x0: float = clampf(r.position.x, header_w, canvas.size.x)
	var x1: float = clampf(r.end.x, header_w, canvas.size.x)
	var y0: float = clampf(r.position.y, region.position.y, region.end.y)
	var y1: float = clampf(r.end.y, region.position.y, region.end.y)
	return Rect2(x0, y0, maxf(x1 - x0, 0.0), maxf(y1 - y0, 0.0))


func tether_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if canvas == null or _panel == null:
		return out
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var to_local: Transform2D = inv * canvas.get_global_transform_with_canvas()
	var n: int = _rows.size()
	var panel_r: Rect2 = Rect2(_panel.position, _panel.size)
	for i: int in n:
		var row: Control = _rows[i]
		var id: String = String(row.get("clip_id"))
		var cr: Rect2 = clip_screen_rect(id)
		if cr.size.x <= 0.0 or cr.size.y <= 0.0:
			continue
		var target: Vector2 = to_local * Vector2(cr.position.x + minf(10.0, cr.size.x * 0.5), cr.get_center().y + (float(i) - float(n - 1) * 0.5) * 4.0)
		var row_y: float = (inv * row.get_global_transform_with_canvas().origin).y + row.size.y * 0.5
		var start: Vector2 = Vector2(panel_r.end.x, row_y) if target.x > panel_r.end.x else Vector2(panel_r.position.x, row_y)
		out.append({"from": start, "to": target, "clip_rect": Rect2(to_local * cr.position, cr.size), "index": i, "clip_id": id})
	return out


func local_y_of(c: Control) -> float:
	return (get_global_transform_with_canvas().affine_inverse() * c.get_global_transform_with_canvas().origin).y


func _draw() -> void:
	if _closing or _panel == null:
		return
	var phase: float = float(Time.get_ticks_msec()) / 1000.0
	var sway: float = SWAY if Tk.dur("fast") > 0.0 else 0.0
	var focus_id: String = ids[hot_index] if hot_index >= 0 and hot_index < ids.size() else ""
	for tp: Dictionary in tether_points():
		var a: Vector2 = tp["from"]
		var b: Vector2 = tp["to"]
		var i: int = int(tp["index"])
		var hot: bool = String(tp["clip_id"]) == focus_id or is_selected(String(tp["clip_id"]))
		var dir: float = 1.0 if b.x >= a.x else -1.0
		var reach: float = maxf(absf(b.x - a.x) * 0.45, 30.0)
		var c1: Vector2 = a + Vector2(dir * reach, sin(phase * 1.6 + float(i) * 1.3) * sway)
		var c2: Vector2 = b + Vector2(cos(phase * 1.3 + float(i)) * sway, -maxf(absf(b.y - a.y) * 0.5, 24.0) * (1.0 if b.y >= a.y else -1.0))
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 24
		for k: int in steps + 1:
			var u: float = float(k) / float(steps)
			var v: float = 1.0 - u
			pts.append(a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + b * u * u * u)
		var col: Color = Tk.c["sol"] if hot else Tk.c["text_dim"]
		draw_polyline(pts, col, 1.6 if hot else 1.1, true)
		draw_circle(b, DOT_R, col)
		if String(tp["clip_id"]) == focus_id:
			var cr: Rect2 = tp["clip_rect"]
			if cr.size.x >= 2.0 and cr.size.y >= 2.0:
				draw_rect(cr.grow(-1.0), Tk.c["sol"], false, 1.5)
	if dragging and drop_index >= 0 and not _rows.is_empty():
		var y: float = 0.0
		if drop_index < _rows.size():
			y = local_y_of(_rows[drop_index])
		else:
			var last: Control = _rows[_rows.size() - 1]
			y = local_y_of(last) + last.size.y
		var x0: float = _panel.position.x + float(Tk.px(6.0))
		draw_rect(Rect2(x0, y - 1.0, _panel.size.x - float(Tk.px(12.0)), 2.0), Tk.c["sol"], true)


class _Row:
	extends Control

	var card: Control = null
	var index: int = -1
	var clip_id: String = ""
	var _box: HBoxContainer = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func fill(colour: Color, name_: String, kind: String, front: bool) -> void:
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pad: int = Tk.px(Tk.sz("pad"))
		margin.add_theme_constant_override("margin_left", pad)
		margin.add_theme_constant_override("margin_right", pad)
		add_child(margin)
		_box = PmUI.hbox()
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(_box)
		var chip := _Chip.new()
		chip.colour = colour
		chip.custom_minimum_size = Vector2(float(Tk.px(10.0)), float(Tk.px(10.0)))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_box.add_child(chip)
		var label: Label = PmLabel.trim(name_)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_FILL
		_box.add_child(label)
		var kind_label: Label = PmLabel.meta(kind)
		kind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kind_label.size_flags_vertical = Control.SIZE_FILL
		_box.add_child(kind_label)
		if front:
			var tag := PanelContainer.new()
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var sb := StyleBoxFlat.new()
			sb.bg_color = Tk.c["sol"]
			sb.set_corner_radius_all(Tk.px(Tk.sz("radius_chip")))
			sb.content_margin_left = float(Tk.px(5.0))
			sb.content_margin_right = float(Tk.px(5.0))
			tag.add_theme_stylebox_override("panel", sb)
			tag.set_meta("pm_box_pad", 4.0)
			tag.add_child(PmLabel.meta(FRONT, "inv"))
			_box.add_child(tag)

	func _on_enter() -> void:
		if card != null:
			card.call("set_hot", index)

	func _on_exit() -> void:
		if card != null and int(card.get("hot_index")) == index:
			card.call("set_hot", -1)

	func _on_input(event: InputEvent) -> void:
		if card == null:
			return
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			card.call("row_event", index, event)
			accept_event()

	func _draw() -> void:
		if card == null:
			return
		var hot: bool = int(card.get("hot_index")) == index
		var sel: bool = bool(card.call("is_selected", clip_id))
		var dragged: bool = bool(card.get("dragging")) and int(card.get("_press_index")) == index
		if sel or hot or dragged:
			var fill_c: Color = Tk.c["glass_strong"] if sel else Tk.c["glass"]
			Paint.rounded(self, Rect2(Vector2.ZERO, size), fill_c, float(Tk.px(Tk.sz("radius_row"))))


class _Chip:
	extends Control

	var colour: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Paint.rounded(self, Rect2(Vector2.ZERO, size), colour, 3.0, Tk.c["border_soft"], 1)
