extends Control

signal picked_time(media_id: String, t: float)
signal region_menu(media_id: String, region_id: String, t: float, at: Vector2)
signal overlaps_wanted(media_id: String, t: float, at: Vector2)
signal empty_menu(media_id: String, t: float, at: Vector2)
signal selection_changed

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const LABEL_W := 168.0
const RULER_H := 20.0
const ROW_BASE := 30.0
const SUB_H := 15.0
const ROW_GAP := 6.0
const EDGE_PX := 6.0
const MIN_PPS := 0.002
const MAX_PPS := 2000.0
const DRAG_SLOP := 3.0
const TOOL_PICK := "pick"
const TOOL_PAINT := "paint"
const TOOL_ERASE := "erase"
const TOOL_CUTS := "cuts"

var doc: Project = null
var media_ids: PackedStringArray = PackedStringArray()
var tool: String = TOOL_PAINT
var kind: String = "dead"
var lane: String = ""
var pps: float = 1.0
var scroll_t: float = 0.0
var rows: Array[Dictionary] = []
var selected: Dictionary = {}
var cursor_media: String = ""
var cursor_t: float = 0.0
var drag: Dictionary = {}
var _fitted: bool = false
var draws: int = 0
var last_draw_us: int = 0
var _look: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	gui_input.connect(_on_input)
	resized.connect(_on_resized)


func _on_resized() -> void:
	if not _fitted and size.x > LABEL_W + 40.0:
		fit()
	queue_redraw()


func set_media(d: Project, ids: PackedStringArray) -> void:
	doc = d
	media_ids = ids
	relayout()
	if not _fitted:
		fit()


func longest() -> float:
	var most: float = 0.0
	for r: Dictionary in rows:
		most = maxf(most, float(r["dur"]))
	return most


func fit() -> void:
	var w: float = size.x - LABEL_W - 12.0
	var most: float = longest()
	if w <= 40.0 or most <= 0.0:
		return
	pps = clampf(w / most, MIN_PPS, MAX_PPS)
	scroll_t = 0.0
	_fitted = true
	queue_redraw()


func relayout() -> void:
	rows = []
	var y: float = RULER_H + 4.0
	if doc != null:
		for id: String in media_ids:
			var m: MediaItem = doc.media_by_id(id)
			if m == null:
				continue
			var list: Array = Regions.list(m)
			var stack: Dictionary = Regions.stack_rows(list)
			var subs: int = maxi(int(stack.get("_count", 0)), 1)
			var h: float = ROW_BASE + float(subs - 1) * SUB_H
			rows.append({"media_id": id, "label": m.label, "dur": maxf(doc.media_duration(m), 0.0), "y": y, "h": h, "stack": stack, "regions": list})
			y += h + ROW_GAP
	custom_minimum_size = Vector2(0.0, y + 8.0)
	queue_redraw()


func x_of(t: float) -> float:
	return LABEL_W + (t - scroll_t) * pps


func t_of(x: float) -> float:
	return scroll_t + (x - LABEL_W) / maxf(pps, 0.000001)


func row_index_at(y: float) -> int:
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if y >= float(r["y"]) and y <= float(r["y"]) + float(r["h"]):
			return i
	return -1


func row_of(media_id: String) -> Dictionary:
	for r: Dictionary in rows:
		if String(r["media_id"]) == media_id:
			return r
	return {}


func region_rect(row: Dictionary, reg: Dictionary) -> Rect2:
	var stack: Dictionary = row["stack"]
	var sub: int = int(stack.get(String(reg.get("id", "")), 0))
	var subs: int = maxi(int(stack.get("_count", 1)), 1)
	var top: float = float(row["y"]) + 2.0
	var h: float = (float(row["h"]) - 4.0) if subs == 1 else SUB_H - 2.0
	var y: float = top + float(sub) * SUB_H
	var x0: float = x_of(float(reg.get("from", 0.0)))
	var x1: float = x_of(float(reg.get("to", 0.0)))
	return Rect2(x0, y, maxf(x1 - x0, 2.0), h)


func hit(pos: Vector2) -> Dictionary:
	var i: int = row_index_at(pos.y)
	if i < 0 or pos.x < LABEL_W:
		return {"row": i}
	var row: Dictionary = rows[i]
	var best: Dictionary = {}
	for reg: Variant in row["regions"]:
		var rd: Dictionary = reg
		var rc: Rect2 = region_rect(row, rd)
		var grown: Rect2 = rc.grow_individual(EDGE_PX * 0.5, 0.0, EDGE_PX * 0.5, 0.0)
		if not grown.has_point(pos):
			continue
		var zone: String = "body"
		if absf(pos.x - rc.position.x) <= EDGE_PX:
			zone = "left"
		elif absf(pos.x - rc.end.x) <= EDGE_PX:
			zone = "right"
		best = {"row": i, "region": rd, "zone": zone}
		if zone != "body":
			break
	if best.is_empty():
		best = {"row": i}
	best["t"] = clampf(t_of(pos.x), 0.0, float(row["dur"]) if float(row["dur"]) > 0.0 else INF)
	best["media_id"] = String(row["media_id"])
	return best


func select(media_id: String, region_id: String) -> void:
	selected = {} if region_id.is_empty() else {"media_id": media_id, "region_id": region_id}
	selection_changed.emit()
	queue_redraw()


func selected_region() -> Dictionary:
	if selected.is_empty() or doc == null:
		return {}
	var m: MediaItem = doc.media_by_id(String(selected["media_id"]))
	return Regions.by_id(Regions.list(m), String(selected["region_id"])) if m != null else {}


func zoom_at(factor: float, x: float) -> void:
	var anchor: float = t_of(x)
	pps = clampf(pps * factor, MIN_PPS, MAX_PPS)
	scroll_t = maxf(anchor - (x - LABEL_W) / pps, 0.0)
	queue_redraw()


func scroll_by(px: float) -> void:
	scroll_t = maxf(scroll_t + px / maxf(pps, 0.000001), 0.0)
	queue_redraw()


func set_cursor(media_id: String, t: float, tell: bool = true) -> void:
	cursor_media = media_id
	cursor_t = maxf(t, 0.0)
	var w: float = size.x - LABEL_W
	if w > 40.0 and (x_of(cursor_t) < LABEL_W or x_of(cursor_t) > size.x - 10.0):
		scroll_t = maxf(cursor_t - w * 0.25 / pps, 0.0)
	queue_redraw()
	if tell:
		picked_time.emit(media_id, cursor_t)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)


func _on_button(mb: InputEventMouseButton) -> void:
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
		if mb.ctrl_pressed or mb.meta_pressed or mb.alt_pressed:
			zoom_at(1.25 if up else 0.8, mb.position.x)
			accept_event()
		elif mb.shift_pressed:
			scroll_by(-60.0 if up else 60.0)
			accept_event()
		return
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT):
		scroll_by(-60.0 if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT else 60.0)
		accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var h: Dictionary = hit(mb.position)
		if int(h["row"]) < 0:
			return
		var mid: String = String(h["media_id"])
		var t: float = float(h["t"])
		var row: Dictionary = rows[int(h["row"])]
		var under: Array = Regions.covering(row["regions"], t)
		if under.size() > 1:
			overlaps_wanted.emit(mid, t, mb.global_position)
		elif under.size() == 1:
			select(mid, String((under[0] as Dictionary).get("id", "")))
			region_menu.emit(mid, String((under[0] as Dictionary).get("id", "")), t, mb.global_position)
		else:
			empty_menu.emit(mid, t, mb.global_position)
		accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		grab_focus()
		_press(mb.position, mb.shift_pressed)
		accept_event()
	elif not drag.is_empty():
		_release(mb.position)
		accept_event()


func _press(pos: Vector2, shift: bool) -> void:
	var h: Dictionary = hit(pos)
	if pos.y < RULER_H and not rows.is_empty():
		var row0: Dictionary = rows[0] if cursor_media.is_empty() or row_of(cursor_media).is_empty() else row_of(cursor_media)
		set_cursor(String(row0["media_id"]), maxf(t_of(pos.x), 0.0))
		drag = {"mode": "scrub", "media_id": String(row0["media_id"])}
		return
	if int(h["row"]) < 0 or pos.x < LABEL_W:
		if int(h["row"]) >= 0:
			set_cursor(String(h["media_id"]), cursor_t if String(h["media_id"]) == cursor_media else 0.0)
		return
	var mid: String = String(h["media_id"])
	var t: float = float(h["t"])
	var reg: Dictionary = h.get("region", {})
	if tool == TOOL_ERASE:
		if not reg.is_empty():
			Regions.remove(doc, mid, PackedStringArray([String(reg["id"])]))
		return
	if tool == TOOL_CUTS:
		if not reg.is_empty():
			var now: bool = Regions.acts_as_cut(reg)
			Regions.change(doc, mid, String(reg["id"]), {"cut": not now}, "Region acts as a cut" if not now else "Region marks only")
			select(mid, String(reg["id"]))
		else:
			set_cursor(mid, t)
		return
	if tool == TOOL_PICK or (not reg.is_empty() and String(h.get("zone", "body")) != "body") or (tool == TOOL_PAINT and not reg.is_empty() and shift):
		if not reg.is_empty():
			select(mid, String(reg["id"]))
			drag = {"mode": String(h.get("zone", "body")), "media_id": mid, "region_id": String(reg["id"]), "t0": t, "t": t, "from": float(reg["from"]), "to": float(reg["to"]), "x0": pos.x, "moved": false}
			return
		select("", "")
		set_cursor(mid, t)
		drag = {"mode": "scrub", "media_id": mid}
		return
	drag = {"mode": "paint", "media_id": mid, "t0": t, "t": t, "x0": pos.x, "moved": false}
	queue_redraw()


func _snap_t(media_id: String, t: float) -> float:
	var row: Dictionary = row_of(media_id)
	var dur: float = float(row.get("dur", 0.0))
	return clampf(t, 0.0, dur if dur > 0.0 else INF)


func _on_motion(mm: InputEventMouseMotion) -> void:
	if drag.is_empty():
		var h: Dictionary = hit(mm.position)
		var zone: String = String(h.get("zone", ""))
		mouse_default_cursor_shape = Control.CURSOR_HSIZE if zone == "left" or zone == "right" else (Control.CURSOR_POINTING_HAND if (tool == TOOL_ERASE or tool == TOOL_CUTS) and h.has("region") else Control.CURSOR_ARROW)
		return
	var mid: String = String(drag["media_id"])
	var t: float = _snap_t(mid, t_of(mm.position.x))
	if String(drag["mode"]) == "scrub":
		set_cursor(mid, t)
		return
	if absf(mm.position.x - float(drag.get("x0", mm.position.x))) >= DRAG_SLOP:
		drag["moved"] = true
	drag["t"] = t
	queue_redraw()


func drag_span() -> Vector2:
	if drag.is_empty():
		return Vector2.ZERO
	var mode: String = String(drag["mode"])
	var t: float = float(drag.get("t", 0.0))
	if mode == "paint":
		return Vector2(minf(float(drag["t0"]), t), maxf(float(drag["t0"]), t))
	var a: float = float(drag.get("from", 0.0))
	var b: float = float(drag.get("to", 0.0))
	var dt: float = t - float(drag.get("t0", 0.0))
	if mode == "left":
		return Vector2(minf(a + dt, b - Regions.MIN_LENGTH), b)
	if mode == "right":
		return Vector2(a, maxf(b + dt, a + Regions.MIN_LENGTH))
	var dur: float = float(row_of(String(drag["media_id"])).get("dur", 0.0))
	var shift: float = maxf(dt, -a)
	if dur > 0.0:
		shift = minf(shift, dur - b)
	return Vector2(a + shift, b + shift)


func _release(pos: Vector2) -> void:
	var d: Dictionary = drag
	var span: Vector2 = drag_span()
	drag = {}
	var mode: String = String(d.get("mode", ""))
	var mid: String = String(d.get("media_id", ""))
	if mode == "scrub" or doc == null:
		queue_redraw()
		return
	if mode == "paint":
		if bool(d.get("moved", false)) and span.y - span.x >= Regions.MIN_LENGTH:
			var fields: Dictionary = {"lane": lane, "made": "paint"}
			var id: String = Regions.add(doc, mid, kind, span.x, span.y, fields)
			if not id.is_empty():
				select(mid, id)
		else:
			set_cursor(mid, _snap_t(mid, t_of(pos.x)))
		queue_redraw()
		return
	if not bool(d.get("moved", false)):
		set_cursor(mid, float(d.get("t0", 0.0)))
		return
	Regions.change(doc, mid, String(d["region_id"]), {"from": span.x, "to": span.y}, "Move region" if mode == "body" else "Resize region")
	queue_redraw()


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	draws += 1
	var font: Font = Tk.font("body")
	var mono: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var tiny: int = Tk.fs(Tk.sz("font_tiny"))
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
	_look = {}
	_draw_ruler(mono, tiny)
	for row: Dictionary in rows:
		_draw_row(row, font, fs, tiny)
	if rows.is_empty():
		PmText.draw_at(self, font, Vector2(LABEL_W, RULER_H + 40.0), "Pick videos in the bin, then press Show picked, or show every video.", fs, Tk.c["text_dim"])
	last_draw_us = Time.get_ticks_usec() - t0


func _tick_step() -> float:
	var want: float = 90.0 / maxf(pps, 0.000001)
	for s: float in [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0, 7200.0]:
		if s >= want:
			return s
	return 14400.0


static func clock(t: float) -> String:
	var whole: int = int(floor(maxf(t, 0.0) + 0.0005))
	var h: int = whole / 3600
	var m: int = (whole % 3600) / 60
	var sec: int = whole % 60
	var frac: float = t - floor(t)
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	if frac > 0.05 and frac < 0.95:
		return "%d:%02d.%d" % [m, sec, int(frac * 10.0)]
	return "%d:%02d" % [m, sec]


func _draw_ruler(mono: Font, tiny: int) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, RULER_H), Tk.c["bg_ruler"], true)
	draw_line(Vector2(0.0, RULER_H), Vector2(size.x, RULER_H), Tk.c["border"], 1.0)
	var step: float = _tick_step()
	var t: float = floor(scroll_t / step) * step
	var end_t: float = t_of(size.x)
	var guard: int = 0
	while t <= end_t and guard < 400:
		var x: float = x_of(t)
		if x >= LABEL_W:
			draw_line(Vector2(x, RULER_H - 6.0), Vector2(x, RULER_H), Tk.c["text_faint"], 1.0)
			PmText.draw_at(self, mono, Vector2(x + 3.0, RULER_H - 7.0), clock(t), tiny, Tk.c["text_dim"])
		t += step
		guard += 1


func _draw_row(row: Dictionary, font: Font, fs: int, tiny: int) -> void:
	var y: float = float(row["y"])
	var h: float = float(row["h"])
	var mid: String = String(row["media_id"])
	var dur: float = float(row["dur"])
	var focus: bool = mid == cursor_media
	draw_rect(Rect2(0.0, y, LABEL_W - 4.0, h), Tk.c["bg_panel_high"] if focus else Tk.c["bg_panel_alt"], true)
	PmText.draw_at(self, font, Vector2(8.0, y + 14.0), String(row["label"]), fs, Tk.c["text"], LABEL_W - 16.0)
	PmText.draw_at(self, font, Vector2(8.0, y + 26.0), "%s · %d regions" % [clock(dur), (row["regions"] as Array).size()], tiny, Tk.c["text_faint"], LABEL_W - 16.0)
	var x0: float = maxf(x_of(0.0), LABEL_W)
	var x1: float = minf(x_of(dur), size.x)
	if x1 > x0:
		draw_rect(Rect2(x0, y, x1 - x0, h), Tk.c["bg_lane_video"], true)
	var sel_id: String = String(selected.get("region_id", "")) if String(selected.get("media_id", "")) == mid else ""
	for reg: Variant in row["regions"]:
		var rd: Dictionary = reg
		if String(drag.get("region_id", "")) == String(rd.get("id", "")) and String(drag.get("media_id", "")) == mid and bool(drag.get("moved", false)):
			continue
		_draw_region(row, rd, String(rd.get("id", "")) == sel_id, font, tiny)
	if not drag.is_empty() and String(drag.get("media_id", "")) == mid and bool(drag.get("moved", false)):
		var span: Vector2 = drag_span()
		var ghost: Dictionary = {"id": String(drag.get("region_id", "_ghost")), "kind": kind if String(drag["mode"]) == "paint" else String(Regions.by_id(row["regions"], String(drag.get("region_id", ""))).get("kind", kind)), "from": span.x, "to": span.y}
		var rc: Rect2 = Rect2(x_of(span.x), y + 2.0, maxf(x_of(span.y) - x_of(span.x), 2.0), h - 4.0)
		var col: Color = Regions.colour_of(ghost)
		draw_rect(rc, Color(col, 0.55), true)
		draw_rect(rc, Tk.c["text_bright"], false, 1.0)
		PmText.draw_at(self, font, rc.position + Vector2(4.0, 12.0), "%s  %s" % [Kinds.name_of(String(ghost["kind"])), clock(span.y - span.x)], tiny, Tk.c["text_bright"], maxf(rc.size.x - 6.0, 1.0))
	if focus:
		var cx: float = x_of(cursor_t)
		if cx >= LABEL_W and cx <= size.x:
			draw_line(Vector2(cx, RULER_H), Vector2(cx, y + h), Tk.c["accent"], 1.0)
	draw_line(Vector2(0.0, y + h + ROW_GAP * 0.5), Vector2(size.x, y + h + ROW_GAP * 0.5), Tk.c["lane_line"], 1.0)


func look_of(rd: Dictionary) -> Array:
	var k: String = String(rd.get("kind", ""))
	var hit: Variant = _look.get(k, null)
	if hit is Array:
		return hit
	var made: Array = [Kinds.colour_of(k), Kinds.cuts_by_default(k), Kinds.name_of(k)]
	_look[k] = made
	return made


func _draw_region(row: Dictionary, rd: Dictionary, is_sel: bool, font: Font, tiny: int) -> void:
	var a: float = float(rd.get("from", 0.0))
	var b: float = float(rd.get("to", 0.0))
	if x_of(b) < LABEL_W or x_of(a) > size.x:
		return
	var rc: Rect2 = region_rect(row, rd)
	if rc.position.x < LABEL_W:
		rc = Rect2(LABEL_W, rc.position.y, rc.end.x - LABEL_W, rc.size.y)
	var look: Array = look_of(rd)
	var col: Color = look[0]
	if rd.has("rgb"):
		col = Regions.colour_of(rd)
	var cut: bool = bool(rd["cut"]) if rd.has("cut") else bool(look[1])
	draw_rect(rc, Color(col, 0.78 if cut else 0.42), true)
	if not cut:
		draw_rect(Rect2(rc.position, Vector2(rc.size.x, 2.0)), col, true)
	var lane_id: String = String(rd.get("lane", ""))
	if lane_id == Regions.LANE_SOUND:
		draw_rect(Rect2(rc.position.x, rc.end.y - 3.0, rc.size.x, 3.0), Tk.c["text_bright"], true)
	elif lane_id == Regions.LANE_PICTURE:
		draw_rect(Rect2(rc.position.x, rc.position.y, rc.size.x, 3.0), Tk.c["text_bright"], true)
	if is_sel:
		draw_rect(rc.grow(1.0), Tk.c["text_bright"], false, 1.5)
	if rc.size.x > 30.0:
		var label: String = String(look[2])
		if bool(rd.get("come_back", false)) and String(rd.get("kind", "")) != "come_back":
			label += "  (come back)"
		PmText.draw_at(self, font, rc.position + Vector2(4.0, minf(12.0, rc.size.y - 2.0)), label, tiny, Tk.c["text_bright"], rc.size.x - 6.0)
