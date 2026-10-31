extends Control

signal activated(index: int)
signal pressed_row(index: int, on_right: bool)
signal cursor_moved(index: int)

const PmScroll := preload("res://ui/kit/pm_scroll.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://modules/core_panels/sheet_list.gd"

var rows: Array[Dictionary] = []
var cursor: int = -1
var hover: int = -1
var row_px: float = 30.0
var two_line: bool = false
var lead_px: float = 0.0
var right_px: float = 180.0
var tag_px: float = 0.0
var click_activates: bool = true
var auto_cursor: bool = true
var empty_text: String = "Nothing to show"
var scroll: Node = null


static func make(row_height: float = 30.0, lines: bool = false, lead: float = 0.0) -> Control:
	var script: GDScript = load(SELF_PATH)
	var l: Control = script.new()
	l.set("row_px", row_height)
	l.set("two_line", lines)
	l.set("lead_px", lead)
	return l


func _init() -> void:
	name = "SheetList"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll = PmScroll.make(false)
	scroll.set("ctrl_wheel_zooms", false)
	scroll.set("alt_wheel_zooms", false)
	scroll.connect("changed", queue_redraw)
	add_child(scroll)
	gui_input.connect(_on_input)
	mouse_exited.connect(_on_exit)
	resized.connect(relayout)


func row_h() -> float:
	return float(Tk.px(row_px))


func set_rows(list: Array[Dictionary], keep_cursor: bool = false) -> void:
	rows = list
	hover = -1
	if not keep_cursor or cursor < 0 or cursor >= rows.size() or not selectable(cursor):
		cursor = first_selectable() if auto_cursor else -1
	relayout()
	if keep_cursor:
		ensure_visible(cursor)
	else:
		scroll.call("scroll_to", 0.0, 0.0, false)


func selectable(i: int) -> bool:
	if i < 0 or i >= rows.size():
		return false
	return not bool(rows[i].get("head", false))


func first_selectable() -> int:
	for i: int in rows.size():
		if selectable(i):
			return i
	return -1


func selectable_count() -> int:
	var n: int = 0
	for i: int in rows.size():
		if selectable(i):
			n += 1
	return n


func relayout() -> void:
	scroll.call("set_view", size.x, size.y)
	scroll.call("set_content", size.x, float(rows.size()) * row_h())
	queue_redraw()


func index_at(local: Vector2) -> int:
	var y: float = local.y + float(scroll.get("scroll_y"))
	var i: int = int(floor(y / row_h()))
	if i < 0 or i >= rows.size() or local.x < 0.0 or local.x > size.x:
		return -1
	return i


func set_cursor(i: int) -> void:
	if not selectable(i):
		return
	cursor = i
	ensure_visible(i)
	queue_redraw()
	cursor_moved.emit(i)


func move(step: int) -> void:
	if rows.is_empty():
		return
	var i: int = cursor
	var n: int = rows.size()
	for _k: int in n:
		i += step
		if i < 0 or i >= n:
			return
		if selectable(i):
			set_cursor(i)
			return


func page(step: int) -> void:
	var per: int = maxi(1, int(floor(size.y / row_h())) - 1)
	var target: int = clampi(cursor + step * per, 0, maxi(rows.size() - 1, 0))
	while target >= 0 and target < rows.size() and not selectable(target):
		target += step
	if selectable(target):
		set_cursor(target)


func ensure_visible(i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var top: float = float(i) * row_h()
	var sy: float = float(scroll.get("target_y"))
	if top < sy:
		scroll.call("scroll_to", 0.0, top)
	elif top + row_h() > sy + size.y:
		scroll.call("scroll_to", 0.0, top + row_h() - size.y)


func activate_cursor() -> bool:
	if not selectable(cursor):
		return false
	activated.emit(cursor)
	return true


func handle_nav_key(k: InputEventKey) -> bool:
	if not k.pressed:
		return false
	if k.keycode == KEY_DOWN:
		move(1)
		return true
	if k.keycode == KEY_UP:
		move(-1)
		return true
	if k.keycode == KEY_PAGEDOWN:
		page(1)
		return true
	if k.keycode == KEY_PAGEUP:
		page(-1)
		return true
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		activate_cursor()
		return true
	return false


func _on_exit() -> void:
	if hover != -1:
		hover = -1
		queue_redraw()


func _on_input(event: InputEvent) -> void:
	if bool(scroll.call("handle", event)):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var i: int = index_at((event as InputEventMouseMotion).position)
		if i != hover:
			hover = i
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		var i2: int = index_at(mb.position)
		accept_event()
		if not selectable(i2):
			return
		cursor = i2
		queue_redraw()
		cursor_moved.emit(i2)
		var on_right: bool = mb.position.x >= size.x - float(Tk.px(right_px))
		pressed_row.emit(i2, on_right)
		if mb.double_click or click_activates:
			activated.emit(i2)


func _draw() -> void:
	var f: Font = Tk.font("body")
	var mono: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var fs_small: int = Tk.fs(Tk.sz("font_small"))
	var fs_meta: int = Tk.fs(Tk.sz("font_meta"))
	var rh: float = row_h()
	var sy: float = float(scroll.get("scroll_y"))
	var pad: float = float(Tk.px(8.0))
	var radius: float = float(Tk.px(Tk.sz("radius_row")))
	if rows.is_empty():
		PmText.draw(self, f, Rect2(Vector2.ZERO, size), empty_text, fs_small, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_CENTER, pad, size.y * 0.5)
		return
	var first: int = maxi(0, int(floor(sy / rh)))
	var last: int = mini(rows.size() - 1, int(ceil((sy + size.y) / rh)))
	for i: int in range(first, last + 1):
		var r: Dictionary = rows[i]
		var top: float = float(i) * rh - sy
		var box: Rect2 = Rect2(0.0, top, size.x, rh)
		if bool(r.get("head", false)):
			var head: String = String(r.get("title", "")).to_upper()
			PmText.draw(self, mono, box, head, fs_meta, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, pad, top + rh - float(Tk.px(7.0)))
			continue
		if i == cursor:
			Paint.rounded(self, box.grow_individual(0.0, -1.0, 0.0, -1.0), Tk.c["glass_strong"], radius)
		elif i == hover:
			Paint.rounded(self, box.grow_individual(0.0, -1.0, 0.0, -1.0), Tk.c["glass"], radius)
		if bool(r.get("rule", false)):
			draw_rect(Rect2(0.0, top + rh - 1.0, size.x, 1.0), Tk.c["border"], true)
		var dim: bool = bool(r.get("dim", false))
		var x: float = pad
		var lead: String = String(r.get("lead", ""))
		if lead_px > 0.0:
			if not lead.is_empty():
				PmText.draw_in(self, mono, Rect2(x, top, float(Tk.px(lead_px)) - 4.0, rh), lead.to_upper(), fs_meta, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, box)
			x += float(Tk.px(lead_px))
		var right: String = String(r.get("right", ""))
		var right_w: float = 0.0
		var chip: bool = bool(r.get("chip", false))
		if not right.is_empty():
			right_w = mono.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_meta).x
			var rx: float = size.x - pad - right_w
			var ry: float = top + (rh - mono.get_height(fs_meta)) * 0.5 + mono.get_ascent(fs_meta)
			var rcol: Color = Tk.c["text_bright"] if bool(r.get("strong", false)) else Tk.c["text_faint"]
			var right_frame: Rect2 = box
			if chip:
				var cr: Rect2 = Rect2(rx - float(Tk.px(6.0)), top + (rh - float(Tk.px(18.0))) * 0.5, right_w + float(Tk.px(12.0)), float(Tk.px(18.0)))
				right_frame = cr
				if bool(r.get("ink", false)):
					Paint.rounded(self, cr, Tk.c["sol"], float(Tk.px(Tk.sz("radius_chip"))))
					rcol = Tk.c["inv"]
				else:
					Paint.rounded(self, cr, Color(0, 0, 0, 0), float(Tk.px(Tk.sz("radius_chip"))), Tk.c["text_dim"] if bool(r.get("strong", false)) else Tk.c["border_soft"], 1)
					rcol = Tk.c["text_bright"] if bool(r.get("strong", false)) else Tk.c["text"]
			PmText.draw_in(self, mono, Rect2(rx, top, right_w, rh), right, fs_meta, rcol, HORIZONTAL_ALIGNMENT_LEFT, ry, PmText.WHOLE, right_frame, PmText.chip_pad() if chip else -1.0)
			right_w += float(Tk.px(18.0))
		if tag_px > 0.0:
			right_w = maxf(right_w, float(Tk.px(right_px)))
			var tag: String = String(r.get("tag", ""))
			var tag_x: float = size.x - pad - right_w - float(Tk.px(tag_px))
			if not tag.is_empty():
				PmText.draw_in(self, f, Rect2(tag_x, top, float(Tk.px(tag_px)) - 6.0, rh), tag, fs_small, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, box)
			right_w += float(Tk.px(tag_px))
		var avail: float = maxf(size.x - x - pad - right_w, 8.0)
		var title_col: Color = Tk.c["text_faint"] if dim else (Tk.c["text_bright"] if i == cursor else Tk.c["text"])
		var title: String = String(r.get("title", ""))
		var detail: String = String(r.get("detail", ""))
		if two_line and not detail.is_empty():
			var block: float = f.get_height(fs) + f.get_height(fs_small)
			var y0: float = top + (rh - block) * 0.5
			PmText.draw_in(self, f, Rect2(x, top, avail, rh), title, fs, title_col, HORIZONTAL_ALIGNMENT_LEFT, y0 + f.get_ascent(fs), PmText.ELIDE, box)
			PmText.draw_in(self, f, Rect2(x, top, avail, rh), detail, fs_small, Tk.c["text_faint"] if dim else Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, y0 + f.get_height(fs) + f.get_ascent(fs_small), PmText.ELIDE, box)
		else:
			PmText.draw_in(self, f, Rect2(x, top, avail, rh), title, fs, title_col, HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, box)
	var content: float = float(rows.size()) * rh
	if content > size.y + 0.5:
		var bar_h: float = maxf(20.0, size.y * size.y / content)
		var bar_y: float = (size.y - bar_h) * (sy / maxf(1.0, content - size.y))
		Paint.rounded(self, Rect2(size.x - 4.0, bar_y, 3.0, bar_h), Tk.c["border_soft"], 1.5)
