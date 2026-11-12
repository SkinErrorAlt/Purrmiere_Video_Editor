extends RefCounted

const Fold := preload("res://ui/timeline/timeline_fold.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const Follow := preload("res://doc/marker_follow.gd")
const Layers := preload("res://doc/marker_layers.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const Tags := preload("res://doc/marker_tags.gd")
const TagApply := preload("res://doc/tag_apply.gd")
const Censor := preload("res://doc/censor.gd")
const EFFECT_SOURCE := "res://modules/core_panels/effect_source.gd"
const Kind := preload("res://ui/timeline/marker_lane_kind.gd")
const Shapes := preload("res://ui/timeline/marker_shapes.gd")
const MenuExtra := preload("res://ui/timeline/marker_menu_extra.gd")
const PlayheadLook := preload("res://ui/timeline/playhead_look.gd")
const MarkerRuns := preload("res://doc/marker_runs.gd")
const MarkerKinds := preload("res://doc/marker_kinds.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const SELF_PATH := "res://ui/timeline/timeline_marker_lanes.gd"
const SWATCH_W := 3.0
const NAME_X := 9.0
const TINT_DIST := 0.18
const PLAYHEAD_W := 2.0
const RULER_BAND := 12.0
const DRAG_MODE := "marker_lane"
const GRIP_PX := 4.0

static var tint_on: bool = true
static var snap_hidden: bool = false
static var lanes_drawn: int = 0
static var last_usec: int = 0
static var _pending_move: PackedStringArray = PackedStringArray()
static var _preview_h: Dictionary = {}
static var _drop_y: float = -1.0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func rows(seq: Sequence, top: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	var y: float = top
	for l: Dictionary in Layers.layers(seq):
		var id: String = String(l["id"])
		var own: float = float(_preview_h.get(id, l.get(Layers.HEIGHT, 0.0)))
		var h: float = float(Tk.px(own)) if own > 0.0 else Kind.lane_h()
		out.append({"id": id, "layer": l, "y": y, "h": h})
		y += h
	return out


static func unit() -> float:
	return maxf(float(Tk.px(100.0)) / 100.0, 0.0001)


static func rows_end(list: Array[Dictionary], top: float) -> float:
	if list.is_empty():
		return top
	var last: Dictionary = list[list.size() - 1]
	return float(last["y"]) + float(last["h"])


static func row_at(geom: Dictionary, y: float) -> Dictionary:
	for r: Dictionary in geom.get("marker_rows", []):
		if y >= float(r["y"]) and y < float(r["y"]) + float(r["h"]):
			return r
	return {}


static func _font_size() -> int:
	return Tk.fs(Tk.sz("font_tiny"))


static func draw(canvas: Control) -> void:
	var t0: int = Time.get_ticks_usec()
	var s: Sequence = canvas.call("seq")
	var g: Dictionary = canvas.call("geometry")
	var list: Array = g.get("marker_rows", [])
	if s == null or list.is_empty():
		last_usec = Time.get_ticks_usec() - t0
		return
	var header_w: float = float(g["header_w"])
	var idx: Dictionary = Layers.index(s)
	var bk: Dictionary = Layers.buckets(s, serial_of(canvas))
	var span: Vector2 = view_span(canvas)
	var font: Font = Tk.font("body")
	var fs: int = _font_size()
	var picked: PackedStringArray = canvas.get("selected_marker_ids")
	var runs_by: Dictionary = MarkerRuns.by_lane(s, serial_of(canvas))
	for r: Dictionary in list:
		var y: float = float(r["y"])
		var h: float = float(r["h"])
		var layer: Dictionary = idx.get(r["id"], r["layer"])
		var body: Rect2 = Rect2(header_w, y, canvas.size.x - header_w, h)
		var ctx: Dictionary = {"layer": layer, "markers": Layers.in_view(bk.get(r["id"], {}), span.x if Kind.cull else -INF, span.y if Kind.cull else INF), "seq": s, "header_w": header_w, "pps": float(g["pps"]), "scroll_x": float(g["scroll_x"]), "fold": g.get("fold", {}), "picked": picked, "font": font, "fs": fs, "runs": runs_by.get(r["id"], [])}
		Kind.paint(canvas, body, ctx)
		draw_header(canvas, Rect2(0.0, y, header_w, h), layer, font, fs)
		lanes_drawn += 1
	var end_y: float = rows_end(list, 0.0)
	canvas.draw_rect(Rect2(0.0, end_y - 1.0, canvas.size.x, 1.0), Tk.c["border"], true)
	if _drop_y >= 0.0 and String((canvas.get("drag") as RefCounted).get("mode")) == DRAG_MODE:
		var di: int = drop_index(canvas, _drop_y)
		var ly: float = float((list[di] as Dictionary)["y"]) if di < list.size() else end_y
		canvas.draw_rect(Rect2(0.0, ly - 1.0, header_w, 2.0), Tk.c["accent"], true)
	last_usec = Time.get_ticks_usec() - t0


static func serial_of(canvas: Control) -> int:
	var d: Project = canvas.call("doc")
	return d.serial if d != null else 0


static func view_span(canvas: Control) -> Vector2:
	var header_w: float = float(canvas.get("header_w"))
	var pps: float = maxf(float(canvas.get("pps")), 0.000001)
	var scroll_x: float = float(canvas.get("scroll_x"))
	var pad: float = 8.0 / pps
	var f: Dictionary = canvas.call("fold") if canvas.has_method("fold") else {}
	return Vector2(Fold.real(f, scroll_x / pps - pad), Fold.real(f, (canvas.size.x - header_w + scroll_x) / pps + pad))


static func draw_header(canvas: Control, r: Rect2, layer: Dictionary, font: Font, fs: int) -> void:
	canvas.draw_rect(r, Tk.c["bg_panel_alt"], true)
	canvas.draw_rect(Rect2(r.position.x, r.position.y, SWATCH_W, r.size.y), Kind.layer_colour(layer), true)
	var btns: Array[Dictionary] = Kind.header_rects(r, layer)
	var name_end: float = (btns[btns.size() - 1]["rect"] as Rect2).position.x - 4.0
	var hidden: bool = bool(layer.get("hidden", false))
	var col: Color = Tk.c["text_dim"] if hidden else Tk.c["text"]
	var shown: String = String(layer.get("name", "")) + (" *" if bool(layer.get("global", false)) else "")
	PmText.draw_in(canvas, font, Rect2(r.position.x + NAME_X, r.position.y, maxf(name_end - r.position.x - NAME_X, 10.0), r.size.y), shown, fs, col, HORIZONTAL_ALIGNMENT_LEFT, r.position.y + r.size.y * 0.5 + font.get_ascent(fs) * 0.5 - 1.0, PmText.ELIDE, r)
	for b: Dictionary in btns:
		Icons.draw(canvas, String(b["icon"]), b["rect"], Tk.c["text"] if bool(b["on"]) else Tk.c["text_faint"])
	canvas.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), Tk.c["border"], true)
	canvas.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)


static func draw_ruler_markers(canvas: Control, s: Sequence, rh: float) -> void:
	if not Layers.shown(s, Layers.RULER):
		return
	var idx: Dictionary = Layers.index(s)
	var header_w: float = float(canvas.get("header_w"))
	var pps: float = float(canvas.get("pps"))
	var scroll_x: float = float(canvas.get("scroll_x"))
	var picked: PackedStringArray = canvas.get("selected_marker_ids")
	var x_max: float = canvas.size.x
	var span: Vector2 = view_span(canvas)
	var rf: Dictionary = canvas.call("fold") if canvas.has_method("fold") else {}
	var last_px: float = -INF
	var list: Array = Layers.in_view(Layers.buckets(s, serial_of(canvas)).get(Layers.RULER, {}), span.x, span.y)
	for run: Dictionary in MarkerRuns.by_lane(s, serial_of(canvas)).get(Layers.RULER, []) as Array:
		var first: Marker = run["first"]
		var rcol: Color = plain_colour(first)
		var x_of: Callable = func(t: float) -> float: return Fold.x_of(rf, t, header_w, pps, scroll_x)
		Shapes.draw_run(canvas, rh - 8.0, 7.0, x_of, run, rcol, header_w, x_max, null, 0)
	var dense: bool = Kind.is_dense(list.size(), x_max - header_w)
	var plain: Color = Tk.c["text"]
	var crowd: float = Kind.DENSE_CROWD_PX if dense else Kind.CROWD_PX
	for m: Marker in list:
		var mt: float = Follow.resolved_time(s, m) if m.follows() else m.time
		var mx: float = Fold.x_of(rf, mt, header_w, pps, scroll_x)
		var mw: float = maxf(m.duration, 0.0) * pps if rf.is_empty() else Fold.px_between(rf, mt, mt + maxf(m.duration, 0.0), pps)
		if mx + mw < header_w - 6.0 or mx > x_max + 6.0:
			continue
		var on: bool = not picked.is_empty() and picked.has(m.id)
		if mw <= 0.0 and not on and mx - last_px < crowd:
			continue
		if mw <= 0.0:
			last_px = mx
		var col: Color = plain if m.colour < 0 and m.rgb.is_empty() else Kind.colour_of(m, {})
		if dense and not on:
			if mw > 1.0:
				canvas.draw_rect(Rect2(mx, rh - 3.0, mw, 3.0), col, true)
			Kind.tick(canvas, mx, 1.0, col)
			continue
		if m.duration > 0.0:
			if m.kind == Kind.TAG_KIND:
				canvas.draw_rect(Rect2(mx, 0.0, mw, rh), Color(col, Kind.TAG_FILL * 0.7), true)
			canvas.draw_rect(Rect2(mx, rh - 3.0, mw, 3.0), col, true)
			if on:
				canvas.draw_rect(Rect2(mx - 1.0, rh - 9.0, 2.0, 9.0), col, true)
				canvas.draw_rect(Rect2(mx + mw - 1.0, rh - 9.0, 2.0, 9.0), col, true)
		if m.follows():
			canvas.draw_circle(Vector2(mx, 13.5), 1.5, col)
		Shapes.draw(canvas, m, mx, 1.0, col, not m.comment.is_empty(), on)


static func plain_colour(m: Marker) -> Color:
	return Tk.c["text"] if m.colour < 0 and m.rgb.is_empty() else Kind.colour_of(m, {})


static func doc_of(canvas: Control) -> Project:
	return canvas.call("doc")


static func set_view(canvas: Control, view: Dictionary, label: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or view == s.marker_view:
		return false
	return Verbs.run(d, label, [MarkerCmds.SetMarkerLayers.new(s.id, s.marker_layers, view, label)])


static func set_locals(canvas: Control, list: Array, view: Dictionary, label: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return false
	return Verbs.run(d, label, [MarkerCmds.SetMarkerLayers.new(s.id, list, view, label)])


static func toggle(canvas: Control, id: String, button: String) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	if button == "eye":
		var hide: bool = Layers.shown(s, id)
		return set_view(canvas, Layers.view_with(s, id, Layers.HIDDEN, hide), "Hide marker lane" if hide else "Show marker lane")
	if button == "lock":
		var lock: bool = not Layers.locked(s, id)
		return set_view(canvas, Layers.view_with(s, id, Layers.LOCKED, lock), "Lock marker lane" if lock else "Unlock marker lane")
	if button == "target":
		var on: bool = Layers.target_of(s) != id
		return set_view(canvas, Layers.view_targeting(s, id, on), "New markers go on " + Layers.name_of(s, id) if on else "New markers go on the ruler")
	return false


static func press(canvas: Control, h: Dictionary, mb: InputEventMouseButton) -> bool:
	var id: String = String(h.get("layer", ""))
	var g: Dictionary = canvas.call("geometry")
	if mb.position.x >= float(g["header_w"]):
		return false
	var button: String = String(h.get("button", ""))
	if not button.is_empty():
		toggle(canvas, id, button)
		return true
	if mb.double_click:
		open_lane_form(canvas, id)
		return true
	var r: Dictionary = row_at(g, mb.position.y)
	if r.is_empty():
		return true
	var drag: RefCounted = canvas.get("drag")
	_drop_y = -1.0
	_preview_h = {}
	drag.call("begin", DRAG_MODE, h, mb.position, {})
	var origin: Dictionary = drag.get("origin")
	var bottom: float = float(r["y"]) + float(r["h"])
	var grip: bool = bottom - mb.position.y <= GRIP_PX
	origin["mlane"] = {"kind": "height" if grip else "order", "id": id, "h0": float(r["h"]) / unit()}
	return true


static func drag_motion(canvas: Control, drag: RefCounted, pos: Vector2, _mods: Dictionary) -> bool:
	var st: Dictionary = (drag.get("origin") as Dictionary).get("mlane", {})
	if st.is_empty():
		return false
	var press_at: Vector2 = drag.get("press")
	if String(st["kind"]) == "height":
		var dy: float = (pos.y - press_at.y) / unit()
		_preview_h = {String(st["id"]): clampf(float(st["h0"]) + dy, Layers.HEIGHT_MIN, Layers.HEIGHT_MAX)}
		return true
	_drop_y = pos.y
	return true


static func drop_index(canvas: Control, y: float) -> int:
	var g: Dictionary = canvas.call("geometry")
	var list: Array = g.get("marker_rows", [])
	var i: int = 0
	for r: Dictionary in list:
		if y > float(r["y"]) + float(r["h"]) * 0.5:
			i += 1
	return i


static func drag_release(canvas: Control, drag: RefCounted, pos: Vector2, _mods: Dictionary) -> bool:
	var st: Dictionary = (drag.get("origin") as Dictionary).get("mlane", {})
	var s: Sequence = canvas.call("seq")
	_drop_y = -1.0
	if st.is_empty() or s == null:
		_preview_h = {}
		return false
	var id: String = String(st["id"])
	if String(st["kind"]) == "height":
		var h: float = float(_preview_h.get(id, 0.0))
		_preview_h = {}
		canvas.queue_redraw()
		if h <= 0.0 or absf(h - Layers.height_of(s, id)) < 0.5:
			return false
		return set_view(canvas, Layers.view_height(s, id, h), "Marker lane height")
	var to: int = drop_index(canvas, pos.y)
	var current: PackedStringArray = Layers.ids(s)
	var from: int = current.find(id)
	if to > from:
		to -= 1
	if to == from:
		return false
	return set_view(canvas, Layers.view_order(s, Layers.moved_order(s, id, to)), "Reorder marker lanes")


static func reset_height(canvas: Control, id: String) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null or Layers.height_of(s, id) <= 0.0:
		return false
	return set_view(canvas, Layers.view_height(s, id, 0.0), "Marker lane height")


static func snap_times(canvas: Control, s: Sequence, t0: float, t1: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if s == null:
		return out
	var bk: Dictionary = Layers.buckets(s, serial_of(canvas))
	for lane: Variant in bk.keys():
		if not snap_hidden and not Layers.shown(s, String(lane)):
			continue
		for m: Marker in Layers.in_view(bk[lane], t0, t1):
			var t: float = Follow.resolved_time(s, m) if m.follows() else m.time
			if t >= t0 and t <= t1:
				out.append(t)
	return out


static func right(canvas: Control, h: Dictionary, at: Vector2) -> bool:
	var zone: String = String(h.get("zone", ""))
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	if zone == "corner":
		var m0: Control = PmMenu.open(canvas, ruler_items(s), at)
		if m0 != null and m0.is_inside_tree():
			m0.connect("picked", _script().on_lane_menu.bind(canvas, Layers.RULER, float(h.get("t", 0.0))))
		return true
	if zone != "marker_lane":
		return false
	if h.get("marker", null) != null:
		return false
	var id: String = String(h.get("layer", ""))
	var g: Dictionary = canvas.call("geometry")
	var on_body: bool = float(h.get("x", 0.0)) >= float(g["header_w"])
	var m: Control = PmMenu.open(canvas, lane_items(s, id, on_body), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _script().on_lane_menu.bind(canvas, id, float(h.get("t", 0.0))))
	return true


static func ruler_items(s: Sequence) -> Array:
	return [
		PmMenu.item("new_lane", "New marker lane", "", "marker"),
		PmMenu.separator(),
		PmMenu.check_item("eye", "Show ruler markers", Layers.shown(s, Layers.RULER)),
		PmMenu.check_item("lock", "Lock ruler markers", Layers.locked(s, Layers.RULER)),
		PmMenu.check_item("hidden_count", "Hidden lanes still count for chapters and the rest", Layers.hidden_still_count()),
	]


static func lane_items(s: Sequence, id: String, on_body: bool) -> Array:
	var l: Dictionary = Layers.find(s, id)
	var items: Array = []
	if on_body and not Layers.locked(s, id):
		items.append(PmMenu.item("add_here", "Add marker here", "", "marker"))
		items.append(PmMenu.separator())
	if s.in_point >= 0.0 and s.out_point > s.in_point and not Layers.locked(s, id):
		items.append(PmMenu.item("tag_range", "Tag in to out on this lane...", "", "marker"))
	items.append(PmMenu.item("edit_lane", "Lane settings..."))
	if Layers.height_of(s, id) > 0.0:
		items.append(PmMenu.item("reset_h", "Default height"))
	items.append(PmMenu.check_item("eye", "Show", Layers.shown(s, id)))
	items.append(PmMenu.check_item("lock", "Locked", Layers.locked(s, id)))
	items.append(PmMenu.check_item("target", "New markers go here", Layers.target_of(s) == id))
	items.append(PmMenu.separator())
	if bool(l.get("global", false)):
		items.append(PmMenu.item("to_local", "Keep in this project only"))
	else:
		items.append(PmMenu.item("to_global", "Make available in every project"))
	items.append(PmMenu.item("new_lane", "New marker lane"))
	items.append(PmMenu.separator())
	if bool(l.get("global", false)):
		items.append(PmMenu.item("forget", "Forget this lane in every project", "", "trash"))
	else:
		items.append(PmMenu.item("remove", "Remove lane, its markers go back to the ruler", "", "trash"))
	return items


static func on_lane_menu(id: String, canvas: Control, layer_id: String, t: float) -> void:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return
	if id == "eye" or id == "lock" or id == "target":
		toggle(canvas, layer_id, id)
	elif id == "hidden_count":
		var prefs: Node = Layers.register_prefs()
		if prefs != null:
			prefs.call("set_value", Layers.PREF_HIDDEN_EXPORT, not Layers.hidden_still_count())
	elif id == "new_lane":
		open_lane_form(canvas, "")
	elif id == "edit_lane":
		open_lane_form(canvas, layer_id)
	elif id == "reset_h":
		reset_height(canvas, layer_id)
	elif id == "tag_range":
		open_tag_form(canvas, layer_id)
	elif id == "add_here":
		add_marker(canvas, layer_id, t)
	elif id == "remove":
		remove_lane(canvas, layer_id)
	elif id == "forget":
		forget_lane(canvas, layer_id)
	elif id == "to_global":
		make_global(canvas, layer_id)
	elif id == "to_local":
		make_local(canvas, layer_id)


static func add_marker(canvas: Control, layer_id: String, t: float) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return false
	var fields: Dictionary = {"id": d.mint_id("k"), "time": maxf(t, 0.0), "layer": layer_id}
	var kind: String = String(Layers.find(s, layer_id).get("kind", Marker.DEFAULT_KIND))
	if kind != Marker.DEFAULT_KIND:
		fields["kind"] = kind
	var cmd: Command = MarkerCmds.AddMarker.new(s.id, "", fields)
	return Verbs.run(d, "Add marker", [cmd])


static func new_lane(canvas: Control, name: String, colour: int, rgb: String, length: float, kind: String, everywhere: bool) -> String:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return ""
	if everywhere:
		var gid: String = Layers.mint_global_id()
		Layers.save_global(Layers.clean({"id": gid, "name": name, "colour": colour, "rgb": rgb, "length": length, "kind": kind}, true))
		d.touch("markers")
		return gid
	var id: String = d.mint_id("ml")
	var l: Dictionary = Layers.new_layer(id, name, colour, rgb, length, kind)
	if not set_locals(canvas, Layers.locals_with(s, l), s.marker_view, "New marker lane"):
		return ""
	return id


static func edit_lane(canvas: Control, id: String, fields: Dictionary) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	var l: Dictionary = Layers.find(s, id)
	if d == null or s == null or l.is_empty():
		return false
	var next: Dictionary = l.duplicate()
	for k: String in fields.keys():
		next[k] = fields[k]
	if bool(l.get("global", false)):
		Layers.save_global(Layers.clean(next, true))
		d.touch("markers")
		return true
	return set_locals(canvas, Layers.locals_with(s, Layers.clean(next, false)), s.marker_view, "Marker lane settings")


static func remove_lane(canvas: Control, id: String) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	return set_locals(canvas, Layers.locals_without(s, id), Layers.view_without(s, id), "Remove marker lane")


static func forget_lane(canvas: Control, id: String) -> bool:
	var d: Project = doc_of(canvas)
	if d == null or not Layers.is_global(id):
		return false
	Layers.forget_global(id)
	d.touch("markers")
	return true


static func make_global(canvas: Control, id: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	var l: Dictionary = Layers.find(s, id)
	if d == null or s == null or l.is_empty() or bool(l.get("global", false)):
		return false
	Layers.save_global(Layers.clean(l, true))
	set_locals(canvas, Layers.locals_without(s, id), s.marker_view, "Marker lane in every project")
	return true


static func make_local(canvas: Control, id: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	var l: Dictionary = Layers.find(s, id)
	if d == null or s == null or l.is_empty() or not bool(l.get("global", false)):
		return false
	var ok: bool = set_locals(canvas, Layers.locals_with(s, Layers.clean(l, false)), s.marker_view, "Marker lane in this project only")
	Layers.forget_global(id)
	d.touch("markers")
	return ok


static func colour_choices() -> Array:
	var out: Array = ["None"]
	for i: int in Tk.LABEL_NAMES.size():
		out.append(Tk.label_name(i))
	return out


static func open_lane_form(canvas: Control, id: String) -> void:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return
	var l: Dictionary = Layers.find(s, id)
	var fresh: bool = l.is_empty()
	if fresh:
		l = Layers.new_layer("new", "Markers " + str(Layers.layers(s).size() + 1))
	var fields: Array[Dictionary] = []
	fields.append({"key": "name", "label": "Name", "type": "string", "default": String(l["name"])})
	fields.append({"key": "colour", "label": "Colour", "type": "enum", "choices": colour_choices(), "default": int(l["colour"]) + 1})
	fields.append({"key": "rgb", "label": "Or any colour, as #rrggbb", "type": "string", "default": String(l["rgb"])})
	fields.append({"key": "length", "label": "Default marker length for text (seconds)", "type": "float", "default": float(l["length"])})
	fields.append({"key": "kind", "label": "New markers are", "type": "enum", "choices": Marker.kind_choices(), "default": Marker.kind_index(String(l["kind"]))})
	if fresh:
		fields.append({"key": "everywhere", "label": "Available in every project", "type": "bool", "default": false})
	var answered: Signal = PmUI.form(canvas, "New marker lane" if fresh else "Marker lane", fields, "Make lane" if fresh else "Apply", "Cancel")
	answered.connect(_script().on_lane_form.bind(canvas, "" if fresh else id))


static func on_lane_form(result: Variant, canvas: Control, id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		_pending_move = PackedStringArray()
		return
	var r: Dictionary = result
	var name: String = String(r.get("name", "")).strip_edges()
	var colour: int = int(r.get("colour", 0)) - 1
	var rgb: String = Marker.clean_rgb(r.get("rgb", ""))
	var length: float = maxf(float(r.get("length", Layers.DEFAULT_LENGTH)), 0.0)
	var kind: String = Marker.kind_at(int(r.get("kind", 0)))
	if id.is_empty():
		take_pending(canvas, new_lane(canvas, name, colour, rgb, length, kind, bool(r.get("everywhere", false))))
		return
	edit_lane(canvas, id, {"name": name, "colour": colour, "rgb": rgb, "length": length, "kind": kind})


static func marker_items(canvas: Control, mk: Marker, tail: String) -> Array:
	var s: Sequence = canvas.call("seq")
	var current: String = Layers.lane_of(s, mk)
	var lane_sub: Array = [PmMenu.check_item("mlane:", Layers.RULER_NAME, current.is_empty())]
	for l: Dictionary in Layers.layers(s):
		if bool(l[Layers.LOCKED]) and String(l["id"]) != current:
			continue
		lane_sub.append(PmMenu.check_item("mlane:" + String(l["id"]), String(l["name"]), current == String(l["id"])))
	lane_sub.append(PmMenu.separator())
	lane_sub.append(PmMenu.item("mlane_new", "New lane with these markers..."))
	var col_sub: Array = [PmMenu.check_item("mcol:-1", "Lane colour", mk.colour < 0 and not mk.has_free_colour())]
	for i: int in Tk.LABEL_NAMES.size():
		col_sub.append(PmMenu.check_item("mcol:" + str(i), Tk.label_name(i), mk.colour == i and not mk.has_free_colour()))
	col_sub.append(PmMenu.separator())
	col_sub.append(PmMenu.check_item("mcol_pick", "Any colour...", mk.has_free_colour()))
	var out: Array = [PmMenu.sub_item("mlane", "Lane" + tail, lane_sub), PmMenu.sub_item("mcol", "Colour" + tail, col_sub)]
	var picked_regions: PackedVector2Array = TagApply.regions_of_markers(s, canvas.call("markers_for_edit", mk.id))
	if picked_regions.size() > 1:
		out.append(PmMenu.item("mapply", "Apply to the " + str(picked_regions.size()) + " picked regions...", "", "fx"))
	if Tags.is_tag(mk):
		out.append(PmMenu.sub_item("tagall", "Every " + Tags.name_of(mk) + " tag (" + str(Tags.of_name(s, Tags.name_of(mk)).size()) + ")", tag_items()))
	out.append_array(MenuExtra.items(canvas, mk, tail))
	return out


static func tag_items() -> Array:
	var col_sub: Array = []
	for i: int in Tk.LABEL_NAMES.size():
		col_sub.append(PmMenu.item("tagall:col:" + str(i), Tk.label_name(i)))
	return [
		PmMenu.item("tagall:apply", "Apply to every one...", "", "fx"),
		PmMenu.item("tagall:select", "Pick them all"),
		PmMenu.separator(),
		PmMenu.item("tagall:prev", "Go to the previous one"),
		PmMenu.item("tagall:next", "Go to the next one"),
		PmMenu.separator(),
		PmMenu.item("tagall:rename", "Rename all..."),
		PmMenu.sub_item("tagall:col", "Colour all", col_sub),
		PmMenu.separator(),
		PmMenu.item("tagall:remove", "Remove all", "", "trash"),
	]


static func on_tag_menu(canvas: Control, id: String, marker_id: String) -> bool:
	var s: Sequence = canvas.call("seq")
	var d: Project = doc_of(canvas)
	var mk: Marker = s.marker_by_id(marker_id) if s != null else null
	if mk == null or d == null or not id.begins_with("tagall:"):
		return false
	var name: String = Tags.name_of(mk)
	var what: String = id.substr(7)
	if what == "apply":
		open_apply_form(canvas, TagApply.regions_of_tag(s, name), TagApply.key_for(name), "every " + name + " tag")
		return true
	if what == "select":
		var ids: PackedStringArray = PackedStringArray()
		for m2: Marker in Tags.of_name(s, name):
			ids.append(m2.id)
		canvas.call("set_marker_selection", ids, false)
		return true
	if what == "prev" or what == "next":
		var t: float = Tags.next_time(s, name, s.playhead, 1 if what == "next" else -1)
		if t >= 0.0:
			Session.set_playhead(t)
		return true
	if what == "remove":
		Tags.remove_all(d, s, name)
		return true
	if what.begins_with("col:"):
		Tags.recolour_all(d, s, name, int(what.substr(4)), "")
		return true
	if what == "rename":
		var fields: Array[Dictionary] = [{"key": "name", "label": "New name", "type": "string", "default": name}]
		var answered: Signal = PmUI.form(canvas, "Rename every " + name + " tag", fields, "Rename", "Cancel")
		answered.connect(_script().on_rename_tags.bind(canvas, name))
		return true
	return false


static func on_rename_tags(result: Variant, canvas: Control, name: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	Tags.rename_all(doc_of(canvas), canvas.call("seq"), name, String((result as Dictionary).get("name", "")))


static func on_marker_menu(canvas: Control, id: String, marker_id: String) -> bool:
	if MenuExtra.on_pick(canvas, id, marker_id):
		return true
	if id.begins_with("mlane:"):
		move_markers(canvas, marker_id, id.substr(6))
		return true
	if id == "mlane_new":
		_pending_move = canvas.call("markers_for_edit", marker_id)
		open_lane_form(canvas, "")
		return true
	if id.begins_with("mcol:"):
		set_colour(canvas, marker_id, int(id.substr(5)), "")
		return true
	if id == "mcol_pick":
		open_colour_window(canvas, marker_id)
		return true
	if id == "mapply":
		var s0: Sequence = canvas.call("seq")
		open_apply_form(canvas, TagApply.regions_of_markers(s0, canvas.call("markers_for_edit", marker_id)), "picked", "the picked regions")
		return true
	return on_tag_menu(canvas, id, marker_id)


static func move_markers(canvas: Control, marker_id: String, layer_id: String) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	return move_ids(canvas, canvas.call("markers_for_edit", marker_id), layer_id)


static func move_ids(canvas: Control, ids: PackedStringArray, layer_id: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return false
	if not layer_id.is_empty() and (not Layers.has_layer(s, layer_id) or Layers.locked(s, layer_id)):
		return false
	var cmds: Array[Command] = []
	for mid: String in ids:
		var mk: Marker = s.marker_by_id(mid)
		if mk != null and Layers.lane_of(s, mk) != layer_id:
			cmds.append(MarkerCmds.SetMarker.new(s.id, "", mid, {"layer": layer_id}))
	if cmds.is_empty():
		return false
	return Verbs.run(d, ("Move marker to " if cmds.size() == 1 else "Move markers to ") + Layers.name_of(s, layer_id), cmds)


static func take_pending(canvas: Control, layer_id: String) -> void:
	if _pending_move.is_empty() or layer_id.is_empty():
		_pending_move = PackedStringArray()
		return
	var ids: PackedStringArray = _pending_move
	_pending_move = PackedStringArray()
	move_ids(canvas, ids, layer_id)


static func set_colour(canvas: Control, marker_id: String, colour: int, rgb: String) -> bool:
	var d: Project = doc_of(canvas)
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for mid: String in canvas.call("markers_for_edit", marker_id):
		var mk: Marker = s.marker_by_id(mid)
		if mk != null and (mk.colour != colour or mk.rgb != rgb):
			cmds.append(MarkerCmds.SetMarker.new(s.id, "", mid, {"colour": colour, "rgb": rgb}))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Marker colour" if cmds.size() == 1 else "Marker colours", cmds)


static func open_colour_window(canvas: Control, marker_id: String) -> Control:
	var s: Sequence = canvas.call("seq")
	var mk: Marker = s.marker_by_id(marker_id) if s != null else null
	if mk == null:
		return null
	var col: VBoxContainer = PmUI.vbox(6)
	var picker: ColorPicker = ColorPicker.new()
	picker.color = Kind.colour_of(mk, Layers.find(s, Layers.lane_of(s, mk)))
	picker.edit_alpha = false
	col.add_child(picker)
	var apply: Button = PmButton.primary("Use this colour")
	col.add_child(apply)
	var w: Control = PmWindow.open(canvas, "Marker colour", col, Vector2(300.0, 470.0), "timeline.marker_colour")
	apply.pressed.connect(_script().on_colour_apply.bind(canvas, marker_id, picker, w))
	return w


static func on_colour_apply(canvas: Control, marker_id: String, picker: ColorPicker, w: Control) -> void:
	set_colour(canvas, marker_id, -1, "#" + picker.color.to_html(false))
	if w != null and is_instance_valid(w):
		w.call("close")


static func layer_at(canvas: Control, pos: Vector2) -> String:
	var g: Dictionary = canvas.call("geometry")
	if pos.y < float(g["ruler_h"]):
		return Layers.RULER
	var r: Dictionary = row_at(g, pos.y)
	if r.is_empty():
		return "?"
	return String(r["id"])


static func colour_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < TINT_DIST * 3.0


static func tint_rows(canvas: Control, ph: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var s: Sequence = canvas.call("seq")
	if s == null or not tint_on or not PlayheadLook.tint_on() or s.markers.is_empty():
		return out
	var g: Dictionary = canvas.call("geometry")
	var pps: float = maxf(float(g["pps"]), 0.000001)
	var reach: float = 5.0 / pps
	var sol: Color = PlayheadLook.colour()
	var idx: Dictionary = Layers.index(s)
	var rh: float = float(g["ruler_h"])
	var bk: Dictionary = Layers.buckets(s, serial_of(canvas))
	var rows_list: Array = [{"id": Layers.RULER, "y": 0.0, "h": rh}]
	rows_list.append_array(g.get("marker_rows", []))
	for r: Dictionary in rows_list:
		var lane: String = String(r["id"])
		if not Layers.shown(s, lane):
			continue
		for m: Marker in Layers.in_view(bk.get(lane, {}), ph - reach, ph + reach):
			var t0: float = Follow.resolved_time(s, m)
			if ph < t0 - reach or ph > t0 + maxf(m.duration, 0.0) + reach:
				continue
			if not colour_close(Kind.colour_of(m, idx.get(lane, {})), sol):
				continue
			out.append(Vector2(float(r["y"]), float(r["y"]) + float(r["h"])))
			break
	return out


static func draw_playhead(ci: CanvasItem, canvas: Control, px: float, y0: float, y1: float, ph: float) -> void:
	var s: Sequence = canvas.call("seq")
	var fps: float = s.fps if s != null and s.fps > 0.0 else 30.0
	var frame_px: float = float(canvas.get("pps")) / fps
	var g: Dictionary = canvas.call("geometry")
	PlayheadLook.draw(ci, px, y0, y1, {"clash": tint_rows(canvas, ph), "frame_px": frame_px, "band_top": float(g.get("ruler_h", y0))})


static func editor_lane_ids(s: Sequence, m: Marker) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([Layers.RULER])
	var current: String = Layers.lane_of(s, m)
	for l: Dictionary in Layers.layers(s):
		var id: String = String(l["id"])
		if id == current or not bool(l[Layers.LOCKED]):
			out.append(id)
	return out


static func editor_fields(s: Sequence, m: Marker) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: PackedStringArray = editor_lane_ids(s, m)
	if ids.size() > 1:
		var names: Array = []
		for id: String in ids:
			names.append(Layers.name_of(s, id))
		out.append({"key": "lane", "label": "Lane", "type": "enum", "choices": names, "default": maxi(ids.find(Layers.lane_of(s, m)), 0)})
	out.append({"key": "rgb", "label": "Or any colour, as #rrggbb", "type": "string", "default": m.rgb})
	return out


static func editor_answer(s: Sequence, m: Marker, r: Dictionary, was: Dictionary, next: Dictionary) -> void:
	was["rgb"] = m.rgb
	var rgb: String = Marker.clean_rgb(r.get("rgb", ""))
	if rgb == m.rgb and int(next.get("colour", -1)) != int(was.get("colour", -1)):
		rgb = ""
	next["rgb"] = rgb
	if r.has("lane"):
		var ids: PackedStringArray = editor_lane_ids(s, m)
		var pick: int = clampi(int(r.get("lane", 0)), 0, ids.size() - 1)
		was["layer"] = Layers.lane_of(s, m)
		next["layer"] = ids[pick]


static func text_length_default(s: Sequence, picked: PackedStringArray, fields: Array[Dictionary]) -> float:
	var groups: Array[Dictionary] = Layers.groups_for_text(s, picked)
	if groups.size() != 1:
		return 0.0
	var length: float = float(groups[0]["length"])
	if length <= 0.0:
		return 0.0
	for f: Dictionary in fields:
		if String(f.get("key", "")) == "length":
			f["default"] = "%.2f" % length
	return length


static func open_tag_form(canvas: Control, layer_id: String) -> bool:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	if s.in_point < 0.0 or s.out_point <= s.in_point:
		Events.toast("Mark in and out first, then tag that range")
		return false
	var known: PackedStringArray = Tags.names(s)
	var fields: Array[Dictionary] = []
	fields.append({"key": "name", "label": "Tag name", "type": "string", "default": Tags.last_name})
	if not known.is_empty():
		fields.append({"key": "note", "type": "note", "default": "Tags in this sequence: " + ", ".join(known) + ". The same name keeps its colour."})
	fields.append({"key": "colour", "label": "Colour, for a new name", "type": "enum", "choices": colour_choices(), "default": 0})
	var answered: Signal = PmUI.form(canvas, "Tag " + str(snappedf(s.out_point - s.in_point, 0.01)) + " s", fields, "Tag it", "Cancel")
	answered.connect(_script().on_tag_form.bind(canvas, layer_id, s.in_point, s.out_point))
	return true


static func on_tag_form(result: Variant, canvas: Control, layer_id: String, from: float, to: float) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	var s: Sequence = canvas.call("seq")
	var name: String = String(r.get("name", "")).strip_edges()
	var known: bool = Tags.names(s).has(name)
	var colour: int = -2 if known else int(r.get("colour", 0)) - 1
	Tags.add(doc_of(canvas), s, name, from, to, layer_id, colour)


static func tag_from_rect(canvas: Control, rect: Rect2) -> String:
	var s: Sequence = canvas.call("seq")
	var d: Project = doc_of(canvas)
	if s == null or d == null or rect.size.x < 2.0:
		return ""
	var layer: String = layer_at(canvas, rect.get_center())
	if layer == "?":
		return ""
	var t0: float = maxf(float(canvas.call("t_of", rect.position.x)), 0.0)
	var t1: float = maxf(float(canvas.call("t_of", rect.end.x)), 0.0)
	if Tags.reuse_silently():
		return Tags.add(d, s, Tags.last_name, t0, t1, layer)
	var fields: Array[Dictionary] = [{"key": "name", "label": "Tag name", "type": "string", "default": Tags.last_name}]
	var known: PackedStringArray = Tags.names(s)
	if not known.is_empty():
		fields.append({"key": "note", "type": "note", "default": "Tags in this sequence: " + ", ".join(known) + ". Settings can skip this question and reuse the last name."})
	var answered: Signal = PmUI.form(canvas, "Tag " + str(snappedf(t1 - t0, 0.01)) + " s", fields, "Tag it", "Cancel")
	answered.connect(_script().on_drag_tag_form.bind(canvas, layer, t0, t1))
	return ""


static func on_drag_tag_form(result: Variant, canvas: Control, layer: String, t0: float, t1: float) -> String:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return ""
	return Tags.add(doc_of(canvas), canvas.call("seq"), String((result as Dictionary).get("name", "")), t0, t1, layer)


static func effect_choices(scope_audio: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src: GDScript = load(EFFECT_SOURCE)
	if src == null:
		return out
	var defs: Array = src.call("audio_list") if scope_audio else src.call("list")
	for d: Variant in defs:
		if d is Dictionary and not String((d as Dictionary).get("id", "")).is_empty():
			out.append(d)
	return out


static func sound_choices(d: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: String in TagApply.BUILT_IN_SOUNDS:
		out.append({"id": k, "label": String((Censor.SOUNDS.get(k, {}) as Dictionary).get("label", k))})
	if d != null:
		for m: MediaItem in d.media:
			if m.kind == "audio" or m.audio_only:
				out.append({"id": m.id, "label": m.label})
	return out


static func open_apply_form(canvas: Control, regions: PackedVector2Array, key: String, what: String, preset: Dictionary = {}) -> bool:
	var s: Sequence = canvas.call("seq")
	var d: Project = doc_of(canvas)
	if s == null or d == null or regions.is_empty():
		return false
	var tracks: Array = ["Every track in the scope"]
	var track_ids: PackedStringArray = PackedStringArray([""])
	for t: Track in s.all_tracks():
		if not t.locked:
			tracks.append(t.shown_label())
			track_ids.append(t.id)
	var audio_tracks: Array = []
	var audio_ids: PackedStringArray = PackedStringArray()
	for t2: Track in s.all_tracks():
		if t2.makes_sound() and not t2.locked:
			audio_tracks.append(t2.shown_label())
			audio_ids.append(t2.id)
	var fx: Array[Dictionary] = effect_choices(true)
	fx.append_array(effect_choices(false))
	var fx_names: Array = ["None"]
	for e: Dictionary in fx:
		fx_names.append(String(e.get("label", e.get("id", ""))) + (" (sound)" if bool(e.get("audio", false)) else ""))
	var sounds: Array[Dictionary] = sound_choices(d)
	var sound_names: Array = ["None"]
	var sound_pick: int = 0
	for i: int in sounds.size():
		sound_names.append(String(sounds[i]["label"]))
		if String(sounds[i]["id"]) == String(preset.get("file", "")):
			sound_pick = i + 1
	var fields: Array[Dictionary] = []
	fields.append({"key": "note", "type": "note", "default": str(regions.size()) + " regions. Clips are cut at the region edges so only what is inside changes, and it is all one undo step. Applying again to the same tag updates every region together."})
	fields.append({"key": "scope", "label": "Change", "type": "enum", "choices": Array(TagApply.SCOPE_LABELS), "default": 0})
	fields.append({"key": "tracks", "label": "On", "type": "enum", "choices": tracks, "default": 0})
	fields.append({"key": "volume", "label": "Volume of what is inside, dB (blank leaves it)", "type": "string", "default": String(preset.get("volume", ""))})
	fields.append({"key": "effect", "label": "Effect", "type": "enum", "choices": fx_names, "default": 0})
	var value_names: Array = ["None"]
	for vv: Array in TagApply.VALUES:
		value_names.append(String(vv[1]))
	fields.append({"key": "value", "label": "Set a value", "type": "enum", "choices": value_names, "default": 0})
	fields.append({"key": "value_to", "label": "To (x, y for two numbers)", "type": "string", "default": ""})
	fields.append({"key": "file", "label": "Sound placed at each region", "type": "enum", "choices": sound_names, "default": sound_pick})
	if not audio_tracks.is_empty():
		fields.append({"key": "file_track", "label": "On the sound track", "type": "enum", "choices": audio_tracks, "default": maxi(audio_tracks.size() - 1, 0)})
	fields.append({"key": "file_db", "label": "Its volume, dB", "type": "string", "default": "0"})
	fields.append({"key": "file_loop", "label": "Repeat a shorter sound to fill the region", "type": "bool", "default": false})
	var answered: Signal = PmUI.form(canvas, "Apply to " + what, fields, "Apply to all", "Cancel")
	answered.connect(_script().on_apply_form.bind(canvas, regions, key, track_ids, audio_ids, fx, sounds))
	return true


static func ops_from_answer(r: Dictionary, fx: Array[Dictionary], sounds: Array[Dictionary], audio_ids: PackedStringArray) -> Dictionary:
	var ops: Dictionary = {}
	var vol: String = String(r.get("volume", "")).strip_edges()
	if vol.is_valid_float():
		ops["volume_db"] = vol.to_float()
	var fi: int = int(r.get("effect", 0)) - 1
	if fi >= 0 and fi < fx.size():
		ops["effect"] = fx[fi]
	var vi: int = int(r.get("value", 0)) - 1
	if vi >= 0 and vi < TagApply.VALUES.size():
		var path: String = String((TagApply.VALUES[vi] as Array)[0])
		var parsed: Variant = TagApply.value_of(path, String(r.get("value_to", "")))
		if parsed != null:
			ops["param"] = {"path": path, "value": parsed}
	var si: int = int(r.get("file", 0)) - 1
	if si >= 0 and si < sounds.size() and not audio_ids.is_empty():
		ops["file"] = String(sounds[si]["id"])
		ops["file_track"] = audio_ids[clampi(int(r.get("file_track", 0)), 0, audio_ids.size() - 1)]
		var fdb: String = String(r.get("file_db", "0")).strip_edges()
		if fdb.is_valid_float() and absf(fdb.to_float()) > 0.0001:
			ops["file_db"] = fdb.to_float()
		if bool(r.get("file_loop", false)):
			ops["file_loop"] = true
	return ops


static func on_apply_form(result: Variant, canvas: Control, regions: PackedVector2Array, key: String, track_ids: PackedStringArray, audio_ids: PackedStringArray, fx: Array[Dictionary], sounds: Array[Dictionary]) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return {}
	var r: Dictionary = result
	var ops: Dictionary = ops_from_answer(r, fx, sounds, audio_ids)
	if ops.is_empty():
		Events.toast("Nothing to apply: give a volume, an effect or a sound")
		return {}
	var scope: String = TagApply.SCOPES[clampi(int(r.get("scope", 0)), 0, TagApply.SCOPES.size() - 1)]
	var ti: int = clampi(int(r.get("tracks", 0)), 0, track_ids.size() - 1)
	var only: PackedStringArray = PackedStringArray() if ti == 0 else PackedStringArray([track_ids[ti]])
	var out: Dictionary = TagApply.apply(doc_of(canvas), canvas.call("seq"), regions, key, scope, only, ops)
	if not bool(out["ok"]):
		Events.toast("Nothing changed: no clip in that scope inside the regions")
	return out


static func tag_under(h: Dictionary) -> Marker:
	var zone: String = String(h.get("zone", ""))
	if zone != "marker_lane" and zone != "ruler":
		return null
	var m: Marker = h.get("marker", null)
	return m if Tags.is_tag(m) else null


static func drop_effect_on_tag(canvas: Control, h: Dictionary, def: Dictionary) -> bool:
	var m: Marker = tag_under(h)
	if m == null or def.is_empty():
		return false
	var s: Sequence = canvas.call("seq")
	var scope: String = TagApply.SCOPE_AUDIO if bool(def.get("audio", false)) else TagApply.SCOPE_VIDEO
	var out: Dictionary = TagApply.apply_to_tag(doc_of(canvas), s, Tags.name_of(m), scope, PackedStringArray(), {"effect": def})
	if not bool(out["ok"]):
		Events.toast("No clip with " + ("sound" if scope == TagApply.SCOPE_AUDIO else "a picture") + " inside the " + Tags.name_of(m) + " tags")
	return true


static func drop_media_on_tag(canvas: Control, payload: Dictionary, h: Dictionary) -> bool:
	var m: Marker = tag_under(h)
	if m == null:
		return false
	var ids: Variant = payload.get("ids", [])
	var first: String = String(payload.get("id", ""))
	if ids is Array and not (ids as Array).is_empty():
		first = String((ids as Array)[0])
	elif ids is PackedStringArray and not (ids as PackedStringArray).is_empty():
		first = (ids as PackedStringArray)[0]
	var s: Sequence = canvas.call("seq")
	return open_apply_form(canvas, TagApply.regions_of_tag(s, Tags.name_of(m)), TagApply.key_for(Tags.name_of(m)), "every " + Tags.name_of(m) + " tag", {"file": first})


static func drop_preset_on_tag(canvas: Control, preset: Dictionary, h: Dictionary) -> bool:
	var m: Marker = tag_under(h)
	if m == null or preset.is_empty():
		return false
	if not TagApply.preset_ok(preset):
		Events.toast("Effect, transform and sound presets go on tags; that preset goes on clips")
		return true
	var s: Sequence = canvas.call("seq")
	var out: Dictionary = TagApply.apply_to_tag(doc_of(canvas), s, Tags.name_of(m), TagApply.preset_scope(preset), PackedStringArray(), {"preset": preset})
	if not bool(out["ok"]):
		Events.toast("Nothing inside the " + Tags.name_of(m) + " tags takes that preset")
	return true
