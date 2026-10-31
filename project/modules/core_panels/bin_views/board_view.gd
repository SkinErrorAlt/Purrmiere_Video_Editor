extends "res://modules/core_panels/bin_views/bin_view.gd"

const BoardModel := preload("res://modules/core_panels/bin_views/board_model.gd")
const BoardCmds := preload("res://doc/commands/board_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.15
const DEFAULT_ZOOM := 0.7
const MARGIN := 24.0
const SMOOTH := 18.0
const SLOP := 4.0
const ARROW_STEPS := 18
const GRIP := 14.0
const TITLE_H := 24.0
const DOT_STEP := 24.0
const NAME_MIN_FS := 9

var board: Dictionary = {}
var folder_key: String = ""
var zoom_v: float = DEFAULT_ZOOM
var origin: Vector2 = Vector2.ZERO
var targets: Dictionary = {}
var shown: Dictionary = {}
var index_of_id: Dictionary = {}
var placed: Dictionary = {}
var flow_label_at: Vector2 = Vector2(INF, INF)
var sel_thing: String = ""
var drag: Dictionary = {}
var editor: LineEdit = null
var editor_target: Dictionary = {}
var pick_from: String = ""
var context_at: Vector2 = Vector2.ZERO
var pointer: Vector2 = Vector2.ZERO
var _origin_known: bool = false
var _pending_shift: Vector2 = Vector2.ZERO
var _restore_view: bool = true
var _stale: bool = true


func id() -> String:
	return "board"


func title() -> String:
	return "Board"


func glyph() -> String:
	return "board"


func draws_scrollbar() -> bool:
	return false


func k() -> float:
	return zoom_v * float(Tk.px(100.0)) / 100.0


func to_board(local: Vector2) -> Vector2:
	return (local + scroll_pos()) / k() + origin


func to_local(b: Vector2) -> Vector2:
	return (b - origin) * k() - scroll_pos()


func rect_local(r: Rect2) -> Rect2:
	return Rect2(to_local(r.position), r.size * k())


func card_size() -> Vector2:
	return Vector2(BoardModel.CARD_W, BoardModel.CARD_H)


func _sync() -> void:
	var key: String = BoardModel.key_for(String(panel.get("folder")))
	if key != folder_key:
		if not folder_key.is_empty():
			_remember_view()
		folder_key = key
		_stale = true
		_restore_view = true
		_origin_known = false
		shown.clear()
		sel_thing = ""
		zoom_v = _saved_view()[0]
	if _stale:
		board = BoardModel.read(doc(), String(panel.get("folder")))
		_stale = false


func _saved_view() -> Array:
	var raw: Variant = state("board", folder_key, [])
	if raw is Array and (raw as Array).size() >= 3:
		var a: Array = raw
		return [clampf(float(a[0]), ZOOM_MIN, ZOOM_MAX), float(a[1]), float(a[2])]
	return [DEFAULT_ZOOM, INF, INF]


func _remember_view() -> void:
	if folder_key.is_empty() or body == null or not is_instance_valid(body):
		return
	var tl: Vector2 = to_board(Vector2.ZERO)
	set_state("board", folder_key, [snappedf(zoom_v, 0.001), snappedf(tl.x, 0.5), snappedf(tl.y, 0.5)])


func doc_changed(kind: String) -> void:
	if kind == BoardCmds.CHANGE_KIND or kind == "media":
		_stale = true


func deactivate() -> void:
	_remember_view()
	_close_editor(false)
	drag = {}
	pick_from = ""


func leave() -> void:
	_remember_view()


func note_rect(n: Dictionary) -> Rect2:
	var w: float = float(n.get("w", BoardModel.NOTE_W))
	var h: float = maxf(float(n.get("h", BoardModel.NOTE_H)), _note_text_h(n, w) + 2.0 * maxf(8.0, px(4.0) / k()) + 2.0)
	return Rect2(float(n.get("x", 0.0)), float(n.get("y", 0.0)), w, h)


func _note_text_h(n: Dictionary, w: float) -> float:
	var text: String = String(n.get("text", ""))
	if text.is_empty():
		return 0.0
	var kk: float = k()
	var fs: int = _note_fs()
	var pad: float = maxf(8.0 * kk, px(4.0))
	var width_px: float = maxf(w * kk - pad * 2.0, 20.0)
	return font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width_px, fs).y / kk


func _note_fs() -> int:
	return maxi(NAME_MIN_FS, int(round(float(fs_body()) * clampf(sqrt(zoom_v), 0.6, 1.4))))


func group_rect(g: Dictionary) -> Rect2:
	return Rect2(float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("w", 200.0)), float(g.get("h", 120.0)))


func layout(width: float, height: float) -> Vector2:
	_sync()
	var list: Array[Dictionary] = entries()
	index_of_id.clear()
	placed.clear()
	targets.clear()
	var unplaced: PackedStringArray = PackedStringArray()
	var bounds: Rect2 = Rect2()
	var has: bool = false
	for i: int in list.size():
		var eid: String = String(list[i]["id"])
		index_of_id[eid] = i
		var p: Variant = BoardModel.card_pos(board, eid)
		if p != null:
			targets[eid] = p
			placed[eid] = true
			var cr: Rect2 = Rect2(p as Vector2, card_size())
			bounds = cr if not has else bounds.merge(cr)
			has = true
	for i: int in list.size():
		var eid2: String = String(list[i]["id"])
		if not placed.has(eid2):
			unplaced.append(eid2)
	for n: Variant in board.get("notes", []):
		var nr: Rect2 = note_rect(n)
		bounds = nr if not has else bounds.merge(nr)
		has = true
	for g: Variant in board.get("groups", []):
		var gr: Rect2 = group_rect(g)
		bounds = gr if not has else bounds.merge(gr)
		has = true
	var kk: float = k()
	var cell: float = BoardModel.CARD_W + BoardModel.GAP
	var view_units: float = maxf(width / kk - MARGIN * 2.0, cell)
	var cols: int = maxi(1, int(floor((view_units + BoardModel.GAP) / cell)))
	flow_label_at = Vector2(INF, INF)
	if not unplaced.is_empty():
		var start: Vector2 = Vector2(0.0, 0.0)
		if has:
			start = Vector2(bounds.position.x, bounds.end.y + BoardModel.GAP * 3.0)
			flow_label_at = start - Vector2(0.0, BoardModel.GAP * 1.3)
		var flow: Dictionary = BoardModel.flow_positions(unplaced, start, cols)
		for fid: Variant in flow.keys():
			targets[String(fid)] = flow[fid]
		var rows: int = (unplaced.size() + cols - 1) / cols
		var fr: Rect2 = Rect2(start, Vector2(float(mini(cols, unplaced.size())) * cell - BoardModel.GAP, float(rows) * (BoardModel.CARD_H + BoardModel.GAP) - BoardModel.GAP))
		bounds = fr if not has else bounds.merge(fr)
		has = true
	if not has:
		bounds = Rect2(Vector2.ZERO, card_size())
	var new_origin: Vector2 = bounds.position - Vector2(MARGIN, MARGIN)
	if _origin_known and new_origin != origin:
		_pending_shift += (origin - new_origin) * kk
	origin = new_origin
	_origin_known = true
	for tid: Variant in targets.keys():
		if not shown.has(tid):
			shown[tid] = targets[tid]
	for sid: Variant in shown.keys():
		if not targets.has(sid):
			shown.erase(sid)
	_apply_rects()
	_update_meta()
	var content: Vector2 = (bounds.size + Vector2(MARGIN, MARGIN) * 2.0) * kk
	return Vector2(maxf(content.x, width), maxf(content.y, height))


func post_layout() -> void:
	var sc: Node = body.get("scroll")
	if _restore_view:
		_restore_view = false
		_pending_shift = Vector2.ZERO
		var saved: Array = _saved_view()
		if float(saved[1]) != INF:
			var at: Vector2 = (Vector2(float(saved[1]), float(saved[2])) - origin) * k()
			sc.call("scroll_to", at.x, at.y, false)
		return
	if _pending_shift != Vector2.ZERO:
		var tx: float = float(sc.get("target_x")) + _pending_shift.x
		var ty: float = float(sc.get("target_y")) + _pending_shift.y
		_pending_shift = Vector2.ZERO
		sc.call("scroll_to", tx, ty, false)


func _apply_rects() -> void:
	var rs: Array[Rect2] = rects()
	var n: int = entries().size()
	if rs.size() != n:
		rs.resize(n)
	var kk: float = k()
	var cs: Vector2 = card_size() * kk
	for eid: Variant in index_of_id.keys():
		var i: int = int(index_of_id[eid])
		var p: Vector2 = shown.get(eid, targets.get(eid, Vector2.ZERO))
		rs[i] = Rect2((p - origin) * kk, cs)


func tick(dt: float) -> bool:
	var moving: bool = false
	var dragged: Dictionary = drag.get("starts", {}) if String(drag.get("mode", "")) == "cards" and bool(drag.get("moved", false)) else {}
	var f: float = 1.0 - exp(-SMOOTH * dt)
	for eid: Variant in targets.keys():
		if dragged.has(eid):
			continue
		var t: Vector2 = targets[eid]
		var s: Vector2 = shown.get(eid, t)
		if s.distance_squared_to(t) > 0.04:
			shown[eid] = s.lerp(t, f)
			moving = true
		elif s != t:
			shown[eid] = t
			moving = true
	if moving:
		_apply_rects()
		redraw()
	return moving


func zoom(steps: float, at: Vector2) -> bool:
	set_zoom(zoom_v * pow(ZOOM_STEP, steps), at)
	return true


func set_zoom(z: float, at: Vector2) -> void:
	var nz: float = clampf(z, ZOOM_MIN, ZOOM_MAX)
	if absf(nz - zoom_v) < 0.0001:
		return
	var b: Vector2 = to_board(at)
	zoom_v = nz
	_restore_view = false
	relayout()
	var sc: Node = body.get("scroll")
	var want: Vector2 = (b - origin) * k() - at
	sc.call("scroll_to", want.x, want.y, false)
	_remember_view()
	_update_meta()
	redraw()


func fit() -> void:
	var list: Array[Dictionary] = entries()
	var r: Rect2 = Rect2()
	var has: bool = false
	for eid: Variant in targets.keys():
		var cr: Rect2 = Rect2(targets[eid] as Vector2, card_size())
		r = cr if not has else r.merge(cr)
		has = true
	for n: Variant in board.get("notes", []):
		r = note_rect(n) if not has else r.merge(note_rect(n))
		has = true
	for g: Variant in board.get("groups", []):
		r = group_rect(g) if not has else r.merge(group_rect(g))
		has = true
	if not has or (list.is_empty() and (board.get("notes", []) as Array).is_empty() and (board.get("groups", []) as Array).is_empty()):
		return
	var ui: float = float(Tk.px(100.0)) / 100.0
	var zw: float = (body.size.x - px(24.0)) / maxf(r.size.x * ui, 1.0)
	var zh: float = (body.size.y - px(24.0)) / maxf(r.size.y * ui, 1.0)
	zoom_v = clampf(minf(zw, zh), ZOOM_MIN, ZOOM_MAX)
	_restore_view = false
	relayout()
	var sc: Node = body.get("scroll")
	var centre: Vector2 = (r.get_center() - origin) * k() - body.size * 0.5
	sc.call("scroll_to", centre.x, centre.y, true)
	_remember_view()
	_update_meta()


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	var pic_h: float = BoardModel.PIC_H * k()
	return Rect2(r.position.x, r.position.y + pic_h, maxf(r.size.x, px(80.0)), maxf(r.size.y - pic_h, px(22.0)))


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	var label: String = String(e.get("label", ""))
	var item: MediaItem = item_of(i)
	var d: String = duration_text(item)
	return label if d.is_empty() else label + "  " + d


func _name_fs() -> int:
	return maxi(NAME_MIN_FS, int(round(float(fs_small()) * clampf(sqrt(zoom_v), 0.6, 1.4))))


func draw() -> void:
	var kk: float = k()
	var vis: Rect2 = visible_rect()
	_draw_dots(kk)
	for g: Variant in board.get("groups", []):
		_draw_group(g as Dictionary, kk, vis)
	_draw_arrows(kk)
	if flow_label_at.x != INF:
		var lh: float = mono().get_height(fs_meta())
		var start: Vector2 = to_local(flow_label_at + Vector2(0.0, BoardModel.GAP * 1.3))
		var lp: Vector2 = Vector2(start.x, start.y - px(4.0) - lh)
		if lp.y > -px(20.0) and lp.y < vis.end.y and BoardModel.GAP * 3.0 * kk >= lh + px(8.0):
			PmText.draw_in(body, mono(), Rect2(lp.x, lp.y, maxf(vis.end.x - PmText.pad() - lp.x, 0.0), lh), "NOT PLACED YET", fs_meta(), Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, lp.y + mono().get_ascent(fs_meta()), PmText.ELIDE, Rect2(vis.position.x, lp.y, vis.size.x, lh))
	var list: Array[Dictionary] = entries()
	for i: int in list.size():
		var r: Rect2 = screen_rect(i)
		if not r.intersects(vis):
			continue
		_draw_card(i, r, kk)
	for n: Variant in board.get("notes", []):
		_draw_note(n as Dictionary, kk, vis)
	_draw_drag_overlay(kk)


func _draw_dots(kk: float) -> void:
	var step: float = DOT_STEP * kk
	if step < px(10.0):
		step *= 2.0
	var sp: Vector2 = scroll_pos()
	var off: Vector2 = Vector2(fposmod(-sp.x - origin.x * kk, step), fposmod(-sp.y - origin.y * kk, step))
	var cols: int = int(body.size.x / step) + 2
	var rows: int = int(body.size.y / step) + 2
	if cols * rows > 2400:
		return
	var c: Color = Color(Tk.c["text"], 0.06)
	var pts: PackedVector2Array = PackedVector2Array()
	for y: int in rows:
		for x: int in cols:
			var p: Vector2 = off + Vector2(float(x) * step, float(y) * step)
			pts.append(p)
			pts.append(p + Vector2(1.0, 0.0))
	body.draw_multiline(pts, c, 1.0)


func _label_colour(i: int) -> Color:
	var n: int = Tk.LABEL_NAMES.size()
	return Tk.label_colour(clampi(i, 0, n - 1))


func _draw_group(g: Dictionary, kk: float, vis: Rect2) -> void:
	var r: Rect2 = rect_local(group_rect(g))
	if not r.intersects(vis):
		return
	var col: Color = _label_colour(int(g.get("colour", 0)))
	var radius: float = px(9.0) * zoom_v
	var selected: bool = sel_thing == String(g.get("id", ""))
	Paint.rounded(body, r, Color(col, 0.08), radius, Color(Tk.c["sol"], 0.9) if selected else Color(col, 0.55), 1)
	var fs: int = maxi(NAME_MIN_FS, int(round(float(fs_small()) * zoom_v)))
	var f: Font = Tk.font("body_semibold")
	var label: String = String(g.get("label", ""))
	var pad: float = px(6.0) * zoom_v
	var max_w: float = r.size.x - pad * 4.0
	if max_w > px(20.0) and not label.is_empty():
		var tw: float = minf(ceil(PmText.width_of(f, label, fs)), max_w - px(14.0))
		var th: float = f.get_height(fs)
		var chip: Rect2 = Rect2(r.position + Vector2(pad, pad), Vector2(tw + px(14.0), th + px(4.0)))
		Paint.rounded(body, chip, Color(col, 0.35), px(5.0))
		PmText.draw(body, f, chip, label, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, px(7.0))
	var gs: float = px(8.0)
	var gp: Vector2 = r.end - Vector2(px(4.0), px(4.0))
	body.draw_line(gp - Vector2(gs, 0.0), gp, Tk.c["text_faint"], 1.4)
	body.draw_line(gp - Vector2(0.0, gs), gp, Tk.c["text_faint"], 1.4)


func _thing_rect(tid: String) -> Rect2:
	if index_of_id.has(tid):
		var p: Vector2 = shown.get(tid, targets.get(tid, Vector2.ZERO))
		return Rect2(p, card_size())
	var ni: int = BoardModel.find(board, "notes", tid)
	if ni >= 0:
		return note_rect((board["notes"] as Array)[ni])
	return Rect2()


func _arrow_points(a: Rect2, b: Rect2) -> PackedVector2Array:
	var p0: Vector2 = _edge_point(a, b.get_center())
	var p3: Vector2 = _edge_point(b, a.get_center())
	var horizontal: bool = absf(b.get_center().x - a.get_center().x) >= absf(b.get_center().y - a.get_center().y)
	var dist: float = p0.distance_to(p3) * 0.4
	var c1: Vector2 = p0 + (Vector2(signf(p3.x - p0.x) * dist, 0.0) if horizontal else Vector2(0.0, signf(p3.y - p0.y) * dist))
	var c2: Vector2 = p3 - (Vector2(signf(p3.x - p0.x) * dist, 0.0) if horizontal else Vector2(0.0, signf(p3.y - p0.y) * dist))
	var out: PackedVector2Array = PackedVector2Array()
	for s: int in ARROW_STEPS + 1:
		var t: float = float(s) / float(ARROW_STEPS)
		out.append(p0.bezier_interpolate(c1, c2, p3, t))
	return out


func _edge_point(r: Rect2, towards: Vector2) -> Vector2:
	var c: Vector2 = r.get_center()
	var d: Vector2 = towards - c
	if d.length_squared() < 0.0001:
		return c
	var hx: float = r.size.x * 0.5 + 4.0
	var hy: float = r.size.y * 0.5 + 4.0
	var tx: float = hx / absf(d.x) if absf(d.x) > 0.0001 else INF
	var ty: float = hy / absf(d.y) if absf(d.y) > 0.0001 else INF
	return c + d * minf(tx, ty)


func arrow_polyline(a: Dictionary) -> PackedVector2Array:
	var ra: Rect2 = _thing_rect(String(a.get("from", "")))
	var rb: Rect2 = _thing_rect(String(a.get("to", "")))
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return PackedVector2Array()
	var pts: PackedVector2Array = _arrow_points(ra, rb)
	for i: int in pts.size():
		pts[i] = to_local(pts[i])
	return pts


func _draw_arrows(_kk: float) -> void:
	for a: Variant in board.get("arrows", []):
		var ad: Dictionary = a
		var pts: PackedVector2Array = arrow_polyline(ad)
		if pts.size() < 2:
			continue
		var selected: bool = sel_thing == String(ad.get("id", ""))
		var col: Color = Tk.c["sol"] if selected else Tk.c["text_dim"]
		body.draw_polyline(pts, col, 1.5 if not selected else 2.0, true)
		_draw_head(pts[pts.size() - 2], pts[pts.size() - 1], col)


func _draw_head(from: Vector2, to: Vector2, col: Color) -> void:
	var dir: Vector2 = (to - from).normalized()
	if dir == Vector2.ZERO:
		return
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var s: float = px(7.0)
	body.draw_colored_polygon(PackedVector2Array([to, to - dir * s + side * s * 0.55, to - dir * s - side * s * 0.55]), col)


func _draw_card(i: int, r: Rect2, kk: float) -> void:
	var e: Dictionary = entry(i)
	var item: MediaItem = item_of(i)
	var radius: float = maxf(px(3.0), px(Tk.sz("radius")) * zoom_v)
	var pic: Rect2 = Rect2(r.position, Vector2(r.size.x, BoardModel.PIC_H * kk))
	if String(e["kind"]) == "folder":
		Paint.rounded(body, pic, Tk.c["bg_panel_alt"], radius, Tk.c["border"], 1)
		var side: float = minf(pic.size.x, pic.size.y) * 0.36
		IconsKit.draw(body, "folder", Rect2(pic.position + (pic.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
		draw_badge(pic, str(int(e.get("count", 0))))
	else:
		var t: float = -1.0
		if i == hover_index() and item != null and item.kind == "video" and zoom_v >= 0.5:
			t = float(panel.call("scrub_time", item, float(body.get("hover_frac"))))
		draw_picture(pic, item, t, radius)
		draw_label_stripe(pic, item)
		draw_badge(pic, duration_text(item))
		draw_marker_ticks(pic, item)
		if t >= 0.0:
			body.draw_rect(Rect2(pic.position.x + pic.size.x * float(body.get("hover_frac")), pic.position.y, 1.0, pic.size.y), Tk.c["accent_dim"], true)
	var fs: int = _name_fs()
	var nh: float = r.end.y - pic.end.y
	if nh >= font().get_height(fs) * 0.9:
		var col: Color = Tk.c["text_bright"] if is_selected(i) else Tk.c["text"]
		caption(r, pic.end.y, nh, String(e.get("label", "")), fs, col)
	draw_outline(pic, i, radius)


func _draw_note(n: Dictionary, kk: float, vis: Rect2) -> void:
	var r: Rect2 = rect_local(note_rect(n))
	if not r.intersects(vis):
		return
	var col: Color = _label_colour(int(n.get("colour", BoardModel.NOTE_COLOUR)))
	var selected: bool = sel_thing == String(n.get("id", ""))
	var editing: bool = editor != null and String(editor_target.get("id", "")) == String(n.get("id", ""))
	Paint.rounded(body, r, Color(col, 0.22), px(7.0) * minf(zoom_v, 1.0) + 1.0, Color(Tk.c["sol"], 0.9) if selected else Color(col, 0.5), 1)
	if editing:
		return
	var fs: int = _note_fs()
	var pad: float = maxf(8.0 * kk, px(4.0))
	if r.size.y < font().get_height(fs) + pad:
		return
	var text: String = String(n.get("text", ""))
	var f: Font = font()
	var max_lines: int = maxi(1, int((r.size.y - pad * 2.0) / f.get_height(fs)))
	PmText.draw_lines(body, f, r, text, fs, Tk.c["text_bright"], max_lines, pad)


func _draw_drag_overlay(_kk: float) -> void:
	var mode: String = String(drag.get("mode", ""))
	if mode == "marquee" and bool(drag.get("moved", false)):
		var a: Vector2 = drag["press"]
		var r: Rect2 = Rect2(a, Vector2.ZERO).expand(pointer).abs()
		body.draw_rect(r, Tk.c["selection_fill"], true)
		body.draw_rect(r, Color(Tk.c["sol"], 0.6), false, 1.0)
	var from_id: String = String(drag.get("from", "")) if mode == "arrow" else pick_from
	if not from_id.is_empty():
		var fr: Rect2 = _thing_rect(from_id)
		if fr.size != Vector2.ZERO:
			var start: Vector2 = to_local(_edge_point(fr, to_board(pointer)))
			body.draw_line(start, pointer, Tk.c["sol"], 1.5, true)
			_draw_head(start, pointer, Tk.c["sol"])


func note_at(local: Vector2) -> String:
	var b: Vector2 = to_board(local)
	var notes: Array = board.get("notes", [])
	for i: int in range(notes.size() - 1, -1, -1):
		if note_rect(notes[i]).has_point(b):
			return String((notes[i] as Dictionary).get("id", ""))
	return ""


func group_at(local: Vector2) -> String:
	var b: Vector2 = to_board(local)
	var groups: Array = board.get("groups", [])
	for i: int in range(groups.size() - 1, -1, -1):
		if group_rect(groups[i]).has_point(b):
			return String((groups[i] as Dictionary).get("id", ""))
	return ""


func grip_at(local: Vector2) -> String:
	var groups: Array = board.get("groups", [])
	for i: int in range(groups.size() - 1, -1, -1):
		var r: Rect2 = rect_local(group_rect(groups[i]))
		var g: Rect2 = Rect2(r.end - Vector2(px(GRIP), px(GRIP)), Vector2(px(GRIP), px(GRIP)))
		if g.has_point(local):
			return String((groups[i] as Dictionary).get("id", ""))
	return ""


func group_title_at(local: Vector2) -> String:
	var groups: Array = board.get("groups", [])
	for i: int in range(groups.size() - 1, -1, -1):
		var r: Rect2 = rect_local(group_rect(groups[i]))
		if Rect2(r.position, Vector2(r.size.x, px(TITLE_H) * maxf(zoom_v, 0.6))).has_point(local):
			return String((groups[i] as Dictionary).get("id", ""))
	return ""


func arrow_at(local: Vector2) -> String:
	var best: String = ""
	var best_d: float = px(5.0)
	for a: Variant in board.get("arrows", []):
		var pts: PackedVector2Array = arrow_polyline(a)
		for s: int in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(local, pts[s], pts[s + 1])
			var dd: float = q.distance_to(local)
			if dd < best_d:
				best_d = dd
				best = String((a as Dictionary).get("id", ""))
	return best


func card_at(local: Vector2) -> int:
	return int(body.call("index_at", local))


func thing_under(local: Vector2) -> String:
	var n: String = note_at(local)
	if not n.is_empty():
		return n
	var i: int = card_at(local)
	if i >= 0:
		return String(entry(i).get("id", ""))
	return ""


func input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		pointer = mm.position
		if not pick_from.is_empty():
			redraw()
		if drag.is_empty():
			return false
		_drag_motion(mm)
		return true
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	pointer = mb.position
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		context_at = to_board(mb.position)
		if not drag.is_empty():
			_cancel_drag()
			return true
		pick_from = ""
		var nid: String = note_at(mb.position)
		var aid: String = arrow_at(mb.position) if nid.is_empty() and card_at(mb.position) < 0 else ""
		var gid: String = ""
		if nid.is_empty() and aid.is_empty() and card_at(mb.position) < 0:
			gid = group_at(mb.position)
		var thing: String = nid if not nid.is_empty() else (aid if not aid.is_empty() else gid)
		if thing.is_empty():
			return false
		sel_thing = thing
		redraw()
		_open_thing_menu(thing, body.get_global_mouse_position())
		return true
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mb.pressed:
		return _press(mb)
	return _release(mb)


func _press(mb: InputEventMouseButton) -> bool:
	_close_editor(true)
	var local: Vector2 = mb.position
	if not pick_from.is_empty():
		var target: String = thing_under(local)
		var from: String = pick_from
		pick_from = ""
		if not target.is_empty() and target != from:
			add_arrow(from, target)
		redraw()
		return true
	if mb.double_click:
		var nid: String = note_at(local)
		if not nid.is_empty():
			edit_note(nid)
			return true
		var tid: String = group_title_at(local)
		if not tid.is_empty() and card_at(local) < 0:
			rename_group(tid)
			return true
		if card_at(local) >= 0:
			return false
		new_note_at(to_board(local))
		return true
	var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
	var note_id: String = note_at(local)
	var i: int = card_at(local) if note_id.is_empty() else -1
	if mb.alt_pressed and (i >= 0 or not note_id.is_empty()):
		drag = {"mode": "arrow", "press": local, "from": note_id if not note_id.is_empty() else String(entry(i)["id"]), "moved": false}
		return true
	if not note_id.is_empty():
		sel_thing = note_id
		var n: Dictionary = (board["notes"] as Array)[BoardModel.find(board, "notes", note_id)]
		drag = {"mode": "note", "press": local, "id": note_id, "start": Vector2(float(n.get("x", 0.0)), float(n.get("y", 0.0))), "moved": false}
		redraw()
		return true
	if i >= 0:
		sel_thing = ""
		var eid: String = String(entry(i)["id"])
		if ctrl or mb.shift_pressed:
			panel.call("select_entry", eid, "toggle")
		elif not is_selected(i):
			panel.call("select_entry", eid, "replace")
		var starts: Dictionary = {}
		for sid: String in _selected_card_ids():
			starts[sid] = targets.get(sid, Vector2.ZERO)
		if not starts.has(eid) and not (ctrl or mb.shift_pressed):
			starts[eid] = targets.get(eid, Vector2.ZERO)
		drag = {"mode": "cards", "press": local, "id": eid, "starts": starts, "moved": false, "plain": not (ctrl or mb.shift_pressed)}
		redraw()
		return true
	var grip: String = grip_at(local)
	if not grip.is_empty():
		sel_thing = grip
		var g: Dictionary = (board["groups"] as Array)[BoardModel.find(board, "groups", grip)]
		drag = {"mode": "group_size", "press": local, "id": grip, "start": Vector2(float(g.get("w", 200.0)), float(g.get("h", 120.0))), "moved": false}
		redraw()
		return true
	var aid: String = arrow_at(local)
	if not aid.is_empty():
		sel_thing = aid
		redraw()
		return true
	var gid: String = group_at(local)
	if not gid.is_empty():
		sel_thing = gid
		var gr: Rect2 = group_rect((board["groups"] as Array)[BoardModel.find(board, "groups", gid)])
		var inside: Dictionary = {}
		for eid2: Variant in targets.keys():
			if placed.has(eid2) and gr.has_point((targets[eid2] as Vector2) + card_size() * 0.5):
				inside[eid2] = targets[eid2]
		var notes_inside: Dictionary = {}
		for n2: Variant in board.get("notes", []):
			var nd: Dictionary = n2
			if gr.has_point(note_rect(nd).get_center()):
				notes_inside[String(nd.get("id", ""))] = Vector2(float(nd.get("x", 0.0)), float(nd.get("y", 0.0)))
		drag = {"mode": "group", "press": local, "id": gid, "start": gr.position, "starts": inside, "notes": notes_inside, "moved": false}
		redraw()
		return true
	sel_thing = ""
	if not (ctrl or mb.shift_pressed):
		panel.call("clear_selection")
	drag = {"mode": "marquee", "press": local, "moved": false, "base": _selected_card_ids()}
	redraw()
	return true


func _selected_card_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var sel: PackedStringArray = panel.get("selected_ids")
	for sid: String in sel:
		if index_of_id.has(sid):
			out.append(sid)
	var sf: String = String(panel.get("selected_folder"))
	if not sf.is_empty() and index_of_id.has("bin:" + sf):
		out.append("bin:" + sf)
	return out


func _drag_motion(mm: InputEventMouseMotion) -> void:
	var mode: String = String(drag.get("mode", ""))
	var press: Vector2 = drag["press"]
	if not bool(drag.get("moved", false)):
		if (mm.position - press).length() < px(SLOP):
			return
		drag["moved"] = true
	var delta: Vector2 = (mm.position - press) / k()
	if mode == "cards":
		if not Rect2(Vector2.ZERO, body.size).grow(-2.0).has_point(mm.position):
			_drag_out()
			return
		var starts: Dictionary = drag["starts"]
		for sid: Variant in starts.keys():
			shown[sid] = (starts[sid] as Vector2) + delta
		_apply_rects()
	elif mode == "note":
		var ni: int = BoardModel.find(board, "notes", String(drag["id"]))
		if ni >= 0:
			var st: Vector2 = drag["start"]
			var n: Dictionary = (board["notes"] as Array)[ni]
			n["x"] = snappedf(st.x + delta.x, 0.5)
			n["y"] = snappedf(st.y + delta.y, 0.5)
	elif mode == "group":
		var gi: int = BoardModel.find(board, "groups", String(drag["id"]))
		if gi >= 0:
			var gst: Vector2 = drag["start"]
			var g: Dictionary = (board["groups"] as Array)[gi]
			g["x"] = snappedf(gst.x + delta.x, 0.5)
			g["y"] = snappedf(gst.y + delta.y, 0.5)
			var inside: Dictionary = drag["starts"]
			for sid2: Variant in inside.keys():
				shown[sid2] = (inside[sid2] as Vector2) + delta
			var notes_in: Dictionary = drag["notes"]
			for nid: Variant in notes_in.keys():
				var nj: int = BoardModel.find(board, "notes", String(nid))
				if nj >= 0:
					var nn: Dictionary = (board["notes"] as Array)[nj]
					nn["x"] = snappedf((notes_in[nid] as Vector2).x + delta.x, 0.5)
					nn["y"] = snappedf((notes_in[nid] as Vector2).y + delta.y, 0.5)
			_apply_rects()
	elif mode == "group_size":
		var gi2: int = BoardModel.find(board, "groups", String(drag["id"]))
		if gi2 >= 0:
			var sz: Vector2 = drag["start"]
			var g2: Dictionary = (board["groups"] as Array)[gi2]
			g2["w"] = snappedf(maxf(120.0, sz.x + delta.x), 0.5)
			g2["h"] = snappedf(maxf(80.0, sz.y + delta.y), 0.5)
	elif mode == "marquee":
		var r: Rect2 = Rect2(press, Vector2.ZERO).expand(mm.position).abs()
		var base: PackedStringArray = drag.get("base", PackedStringArray())
		var picked: PackedStringArray = base.duplicate()
		for eid: Variant in index_of_id.keys():
			var i: int = int(index_of_id[eid])
			if screen_rect(i).intersects(r) and not picked.has(String(eid)) and not String(eid).begins_with("bin:"):
				picked.append(String(eid))
		panel.set("selected_ids", picked)
		panel.call("select_changed")
	redraw()


func _drag_out() -> void:
	var eid: String = String(drag.get("id", ""))
	var starts: Dictionary = drag.get("starts", {})
	for sid: Variant in starts.keys():
		shown[sid] = starts[sid]
	drag = {}
	_apply_rects()
	redraw()
	if eid.begins_with("bin:"):
		return
	panel.call("begin_drag", eid, Vector2(px(20.0), px(14.0)))


func _release(mb: InputEventMouseButton) -> bool:
	if drag.is_empty():
		return false
	var mode: String = String(drag.get("mode", ""))
	var moved: bool = bool(drag.get("moved", false))
	var d: Dictionary = drag
	drag = {}
	if mode == "cards":
		if moved:
			var next: Dictionary = board.duplicate(true)
			var starts: Dictionary = d["starts"]
			for sid: Variant in starts.keys():
				BoardModel.set_card(next, String(sid), shown.get(sid, starts[sid]))
			_commit(next, "Move on the board" if starts.size() == 1 else "Move " + str(starts.size()) + " cards on the board")
		elif bool(d.get("plain", false)):
			panel.call("select_entry", String(d["id"]), "replace")
	elif mode == "note" or mode == "group" or mode == "group_size":
		if moved:
			var next2: Dictionary = board.duplicate(true)
			if mode == "group":
				var inside: Dictionary = d["starts"]
				for sid2: Variant in inside.keys():
					BoardModel.set_card(next2, String(sid2), shown.get(sid2, inside[sid2]))
			var label: String = "Move note" if mode == "note" else ("Move colour group" if mode == "group" else "Size colour group")
			_stale = true
			_commit(next2, label)
	elif mode == "arrow":
		var target: String = thing_under(mb.position)
		if moved and not target.is_empty() and target != String(d.get("from", "")):
			add_arrow(String(d["from"]), target)
	redraw()
	return true


func _cancel_drag() -> void:
	var mode: String = String(drag.get("mode", ""))
	if mode == "cards" or mode == "group":
		var starts: Dictionary = drag.get("starts", {})
		for sid: Variant in starts.keys():
			shown[sid] = starts[sid]
	drag = {}
	_stale = true
	relayout()
	redraw()


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if e.keycode == KEY_ESCAPE:
		if not drag.is_empty():
			_cancel_drag()
			return true
		if not pick_from.is_empty():
			pick_from = ""
			redraw()
			return true
		if not sel_thing.is_empty():
			sel_thing = ""
			redraw()
			return true
		return false
	if (e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE) and not sel_thing.is_empty():
		remove_thing(sel_thing)
		return true
	return false


func _commit(next: Dictionary, label: String) -> bool:
	var d: Project = doc()
	if d == null:
		return false
	var ok: bool = Verbs.run(d, label, [BoardCmds.SetBoard.new(folder_key, next, label)] as Array[Command])
	_stale = true
	relayout()
	redraw()
	return ok


func board_copy() -> Dictionary:
	_sync()
	return board.duplicate(true)


func view_centre() -> Vector2:
	return to_board(body.size * 0.5)


func new_note_at(at: Vector2) -> void:
	_open_editor({"kind": "new_note", "at": at}, "")


func add_note_here() -> void:
	var at: Vector2 = view_centre() - Vector2(BoardModel.NOTE_W, BoardModel.NOTE_H) * 0.5
	if Rect2(Vector2.ZERO, body.size).has_point(pointer):
		at = to_board(pointer)
	new_note_at(at)


func edit_note(nid: String) -> void:
	var ni: int = BoardModel.find(board, "notes", nid)
	if ni < 0:
		return
	sel_thing = nid
	_open_editor({"kind": "note", "id": nid}, String(((board["notes"] as Array)[ni] as Dictionary).get("text", "")))


func rename_group(gid: String) -> void:
	var gi: int = BoardModel.find(board, "groups", gid)
	if gi < 0:
		return
	sel_thing = gid
	_open_editor({"kind": "group", "id": gid}, String(((board["groups"] as Array)[gi] as Dictionary).get("label", "")))


func _editor_rect(target: Dictionary) -> Rect2:
	var kind: String = String(target.get("kind", ""))
	var h: float = float(Tk.px(Tk.sz("field_h")))
	if kind == "new_note":
		var at: Vector2 = target["at"]
		var r: Rect2 = rect_local(Rect2(at, Vector2(BoardModel.NOTE_W, BoardModel.NOTE_H)))
		return Rect2(r.position, Vector2(maxf(r.size.x, px(180.0)), h))
	if kind == "note":
		var ni: int = BoardModel.find(board, "notes", String(target["id"]))
		if ni >= 0:
			var r2: Rect2 = rect_local(note_rect((board["notes"] as Array)[ni]))
			return Rect2(r2.position, Vector2(maxf(r2.size.x, px(180.0)), h))
	if kind == "group":
		var gi: int = BoardModel.find(board, "groups", String(target["id"]))
		if gi >= 0:
			var r3: Rect2 = rect_local(group_rect((board["groups"] as Array)[gi]))
			return Rect2(r3.position + Vector2(px(4.0), px(4.0)), Vector2(clampf(r3.size.x - px(8.0), px(140.0), px(260.0)), h))
	return Rect2()


func _open_editor(target: Dictionary, text: String) -> void:
	_close_editor(false)
	var r: Rect2 = _editor_rect(target)
	if r.size == Vector2.ZERO:
		return
	editor_target = target
	editor = PmUI.line_edit("Write a note" if String(target["kind"]) != "group" else "Group name", text)
	r.position = r.position.clamp(Vector2.ZERO, (body.size - r.size).max(Vector2.ZERO))
	editor.position = r.position
	editor.size = r.size
	editor.text_submitted.connect(_on_editor_submitted)
	editor.focus_exited.connect(_on_editor_focus_out)
	editor.gui_input.connect(_on_editor_input)
	body.add_child(editor)
	editor.grab_focus()
	editor.select_all()
	redraw()


func _on_editor_submitted(_t: String) -> void:
	_close_editor(true)


func _on_editor_focus_out() -> void:
	_close_editor(true)


func _on_editor_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		editor.accept_event()
		_close_editor(false)


func editing() -> bool:
	return editor != null


func _close_editor(commit: bool) -> void:
	if editor == null:
		return
	if not is_instance_valid(editor):
		editor = null
		editor_target = {}
		return
	var le: LineEdit = editor
	var target: Dictionary = editor_target
	editor = null
	editor_target = {}
	var text: String = le.text.strip_edges()
	if le.focus_exited.is_connected(_on_editor_focus_out):
		le.focus_exited.disconnect(_on_editor_focus_out)
	PmUI.free_node(le)
	redraw()
	if not commit:
		return
	var kind: String = String(target.get("kind", ""))
	var next: Dictionary = board.duplicate(true)
	if kind == "new_note":
		if text.is_empty():
			return
		sel_thing = BoardModel.add_note(next, target["at"], text)
		_commit(next, "Add note")
	elif kind == "note":
		var ni: int = BoardModel.find(next, "notes", String(target["id"]))
		if ni < 0:
			return
		if text.is_empty():
			BoardModel.remove_thing(next, String(target["id"]))
			sel_thing = ""
			_commit(next, "Remove note")
			return
		((next["notes"] as Array)[ni] as Dictionary)["text"] = text
		_commit(next, "Edit note")
	elif kind == "group":
		var gi: int = BoardModel.find(next, "groups", String(target["id"]))
		if gi < 0 or text.is_empty():
			return
		((next["groups"] as Array)[gi] as Dictionary)["label"] = text
		_commit(next, "Rename colour group")


func add_group_here() -> void:
	var sel: PackedStringArray = _selected_card_ids()
	if not sel.is_empty():
		group_selected()
		return
	var at: Vector2 = view_centre() - Vector2(180.0, 100.0)
	if Rect2(Vector2.ZERO, body.size).has_point(pointer):
		at = to_board(pointer)
	add_group_at(at)


func add_group_at(at: Vector2) -> String:
	var next: Dictionary = board.duplicate(true)
	var colour: int = (next.get("groups", []) as Array).size() % Tk.LABEL_NAMES.size()
	var gid: String = BoardModel.add_group(next, Rect2(at, Vector2(360.0, 200.0)), "Group " + str((next.get("groups", []) as Array).size() + 1), colour)
	sel_thing = gid
	if _commit(next, "Add colour group"):
		rename_group(gid)
	return gid


func group_selected() -> String:
	var sel: PackedStringArray = _selected_card_ids()
	if sel.is_empty():
		return ""
	var next: Dictionary = board.duplicate(true)
	var r: Rect2 = Rect2()
	var first: bool = true
	for sid: String in sel:
		var p: Vector2 = targets.get(sid, Vector2.ZERO)
		BoardModel.set_card(next, sid, p)
		var cr: Rect2 = Rect2(p, card_size())
		r = cr if first else r.merge(cr)
		first = false
	r = r.grow(BoardModel.GROUP_PAD)
	r.position.y -= BoardModel.GROUP_PAD * 0.6
	r.size.y += BoardModel.GROUP_PAD * 0.6
	var colour: int = (next.get("groups", []) as Array).size() % Tk.LABEL_NAMES.size()
	var gid: String = BoardModel.add_group(next, r, "Group " + str((next.get("groups", []) as Array).size() + 1), colour)
	sel_thing = gid
	if _commit(next, "Group the selected cards"):
		rename_group(gid)
	return gid


func add_arrow(from_id: String, to_id: String) -> bool:
	var next: Dictionary = board.duplicate(true)
	for tid: String in [from_id, to_id]:
		if index_of_id.has(tid) and not placed.has(tid):
			BoardModel.set_card(next, tid, targets.get(tid, Vector2.ZERO))
	var aid: String = BoardModel.add_arrow(next, from_id, to_id)
	if aid.is_empty():
		return false
	sel_thing = aid
	return _commit(next, "Add arrow")


func remove_thing(tid: String) -> bool:
	var next: Dictionary = board.duplicate(true)
	if not BoardModel.remove_thing(next, tid):
		return false
	var label: String = "Remove arrow" if tid.begins_with("a") else ("Remove note" if tid.begins_with("n") else "Remove colour group")
	sel_thing = ""
	return _commit(next, label)


func set_thing_colour(tid: String, colour: int) -> bool:
	var next: Dictionary = board.duplicate(true)
	for key: String in ["notes", "groups"]:
		var i: int = BoardModel.find(next, key, tid)
		if i >= 0:
			((next[key] as Array)[i] as Dictionary)["colour"] = colour
			return _commit(next, "Note colour" if key == "notes" else "Colour group colour")
	return false


func unplace(ids: PackedStringArray) -> bool:
	var next: Dictionary = board.duplicate(true)
	var cards: Dictionary = next["cards"]
	var n: int = 0
	for sid: String in ids:
		if cards.has(sid):
			cards.erase(sid)
			BoardModel.drop_arrows_of(next, sid)
			n += 1
	if n == 0:
		return false
	return _commit(next, "Take off the board")


func tidy_up() -> bool:
	var ids: PackedStringArray = _selected_card_ids()
	if ids.size() < 2:
		ids = PackedStringArray(placed.keys())
	if ids.size() < 2:
		ids = PackedStringArray(targets.keys())
	if ids.is_empty():
		return false
	var pos: Dictionary = {}
	var r: Rect2 = Rect2()
	var first: bool = true
	for sid: String in ids:
		var p: Vector2 = targets.get(sid, Vector2.ZERO)
		pos[sid] = p
		r = Rect2(p, card_size()) if first else r.merge(Rect2(p, card_size()))
		first = false
	var order: PackedStringArray = BoardModel.board_order(pos, BoardModel.CARD_W)
	var cols: int = maxi(1, int(ceil(sqrt(float(order.size()) * 1.6))))
	var laid: Dictionary = BoardModel.tidy(order, r.position, cols)
	var next: Dictionary = board.duplicate(true)
	for sid2: Variant in laid.keys():
		BoardModel.set_card(next, String(sid2), laid[sid2])
	return _commit(next, "Tidy up the board")


func rough_cut_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for sid: String in _selected_card_ids():
		if not sid.begins_with("bin:"):
			ids.append(sid)
	if ids.size() < 2:
		ids = PackedStringArray()
		for pid: Variant in placed.keys():
			if not String(pid).begins_with("bin:"):
				ids.append(String(pid))
	if ids.is_empty():
		for tid: Variant in targets.keys():
			if not String(tid).begins_with("bin:"):
				ids.append(String(tid))
	var pos: Dictionary = {}
	for sid2: String in ids:
		pos[sid2] = targets.get(sid2, Vector2.ZERO)
	return BoardModel.board_order(pos, BoardModel.CARD_W)


func send_to_timeline() -> int:
	var order: PackedStringArray = rough_cut_ids()
	if order.is_empty():
		Events.toast("Nothing on the board to send")
		return 0
	return int(panel.call("rough_cut", order))


func context_items(entry_id: String) -> Array:
	var items: Array = [PmMenu.separator()]
	items.append(PmMenu.item("board:arrow_from", "Draw an arrow from here"))
	var sel: PackedStringArray = _selected_card_ids()
	if sel.size() >= 1:
		items.append(PmMenu.item("board:group_sel", "Group the selected cards", Cmd.keys_text("bin.board_group")))
	if placed.has(entry_id):
		items.append(PmMenu.item("board:unplace", "Take off the board"))
	items.append(PmMenu.item("board:to_timeline", "Send to the timeline in board order", Cmd.keys_text("bin.board_to_timeline")))
	return items


func on_context(pick: String, entry_id: String) -> bool:
	if pick == "board:arrow_from":
		pick_from = entry_id
		redraw()
		return true
	if pick == "board:group_sel":
		group_selected()
		return true
	if pick == "board:unplace":
		var ids: PackedStringArray = _selected_card_ids()
		if not ids.has(entry_id):
			ids = PackedStringArray([entry_id])
		unplace(ids)
		return true
	if pick == "board:to_timeline":
		send_to_timeline()
		return true
	return false


func empty_items(at_local: Vector2) -> Array:
	context_at = to_board(at_local)
	var items: Array = [
		PmMenu.item("board:note", "Add a note here", Cmd.keys_text("bin.board_note")),
		PmMenu.item("board:group", "Add a colour group here", Cmd.keys_text("bin.board_group")),
	]
	var gs: Dictionary = PmMenu.item("board:group_sel", "Group the selected cards")
	gs["disabled"] = _selected_card_ids().is_empty()
	items.append(gs)
	items.append(PmMenu.separator())
	items.append(PmMenu.item("board:to_timeline", "Send to the timeline in board order", Cmd.keys_text("bin.board_to_timeline")))
	items.append(PmMenu.item("board:tidy", "Tidy up the board"))
	items.append(PmMenu.item("board:fit", "Fit the board"))
	items.append(PmMenu.separator())
	return items


func on_empty(pick: String) -> bool:
	if pick == "board:note":
		new_note_at(context_at)
		return true
	if pick == "board:group":
		add_group_at(context_at)
		return true
	if pick == "board:group_sel":
		group_selected()
		return true
	if pick == "board:to_timeline":
		send_to_timeline()
		return true
	if pick == "board:tidy":
		tidy_up()
		return true
	if pick == "board:fit":
		fit()
		return true
	return false


func _open_thing_menu(tid: String, at: Vector2) -> void:
	var items: Array = []
	if tid.begins_with("n"):
		items.append(PmMenu.item("thing:edit", "Edit note"))
	elif tid.begins_with("g"):
		items.append(PmMenu.item("thing:rename", "Rename colour group"))
	if not tid.begins_with("a"):
		var sub: Array = []
		for c: int in Tk.LABEL_NAMES.size():
			sub.append(PmMenu.item("thing:colour:" + str(c), Tk.label_name(c)))
		items.append(PmMenu.sub_item("thing:colour", "Colour", sub))
	if tid.begins_with("n"):
		items.append(PmMenu.item("thing:arrow", "Draw an arrow from here"))
	if not items.is_empty():
		items.append(PmMenu.separator())
	items.append(PmMenu.item("thing:remove", "Remove", "Delete", "trash"))
	var m: Control = PmMenu.open(body, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_thing_picked.bind(tid))


func _on_thing_picked(pick: String, tid: String) -> void:
	if pick == "thing:edit":
		edit_note(tid)
	elif pick == "thing:rename":
		rename_group(tid)
	elif pick == "thing:arrow":
		pick_from = tid
		redraw()
	elif pick == "thing:remove":
		remove_thing(tid)
	elif pick.begins_with("thing:colour:"):
		set_thing_colour(tid, int(pick.substr(13)))


func build_bar(bar: Container) -> void:
	bar_button(bar, "Note", "Add a sticky note, or double click empty board", add_note_here, Cmd.keys_text("bin.board_note"))
	bar_button(bar, "Group", "Add a colour group, around the selected cards when some are selected", add_group_here, Cmd.keys_text("bin.board_group"))
	bar_button(bar, "Tidy up", "Line up the selected cards, or every placed card, in a grid in board order", tidy_up)
	bar_button(bar, "To the timeline", "Send the selected cards, or every card you have placed, to the timeline from left to right", send_to_timeline, Cmd.keys_text("bin.board_to_timeline"))
	bar_button(bar, "Fit", "Zoom to show the whole board, Ctrl+wheel zooms", fit)
	_update_meta()


func _update_meta() -> void:
	set_meta_text("board at " + str(int(round(zoom_v * 100.0))) + "%")
