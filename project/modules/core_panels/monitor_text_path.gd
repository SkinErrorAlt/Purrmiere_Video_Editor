extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const INK := Color(0.569, 0.733, 1.0, 1.0)
const LABEL_BACK := Color(0.051, 0.055, 0.063, 0.85)
const HANDLE := 7.0
const DOT := 4.0
const RING := 6.0
const REACH := 4.0
const LEG_REACH := 7.0
const SLOP := 3.0
const DRAG_LABEL := "Shape the text path"
const ADD_LABEL := "Add a text path point"
const DROP_LABEL := "Remove a text path point"
const POINT_HINT := "Alt click the line to add a point, Ctrl click a point to take it out"

var drag: Dictionary = {}
var hover: String = ""
var drags: int = 0
var edits: int = 0


func active() -> bool:
	return not drag.is_empty()


func _allowed(panel: Object) -> bool:
	if Session.tool_id == "type" or Session.tool_id == "hand" or Session.tool_id == "pen":
		return false
	if panel.has_method("placing_region") and bool(panel.call("placing_region")):
		return false
	var scr: Variant = panel.get("_screens")
	if scr is Object and (scr as Object).has_method("hide_handles") and bool((scr as Object).call("hide_handles")):
		return false
	if panel.has_method("monitor_mask"):
		var mask: Variant = panel.call("monitor_mask")
		if mask is Object and (bool((mask as Object).call("active")) or bool((mask as Object).call("drawing"))):
			return false
	return true


func _k(panel: Object, pic: Rect2) -> float:
	var s: Sequence = panel.call("seq")
	return pic.size.x / maxf(float(s.width), 1.0) if s != null else 1.0


func _layer(panel: Object, c: Clip) -> Dictionary:
	var made: Dictionary = panel.call("quad_for", c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4:
		return {}
	var qq: PackedVector2Array = q
	var xf: Transform2D = Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])
	if absf(xf.determinant()) < 0.000001:
		return {}
	return {"xf": xf, "quad": qq}


func live_props(panel: Object, c: Clip) -> Dictionary:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null or c == null:
		return {}
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return {}
	var base: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(s.playhead - c.start, s.fps)
	for k: Variant in now.keys():
		base[k] = now[k]
	return TitleStyle.merged("title", {}, base, m.label)


func target(panel: Object) -> Dictionary:
	var out: Dictionary = {}
	if not _allowed(panel):
		return out
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var c: Clip = panel.call("gizmo_clip")
	if d == null or s == null or c == null:
		return out
	var props: Dictionary = live_props(panel, c)
	if props.is_empty() or not TextExtras.path_on(props):
		return out
	var m: MediaItem = d.media_by_id(c.media_id)
	var size: Vector2 = MonitorPick.layer_size(c, m, s, d)
	if size.x < 2.0 or size.y < 2.0:
		return out
	var line: PackedVector2Array = TextGlyphs.path_line(props, size)
	if line.size() < 2:
		return out
	var lx: Dictionary = _layer(panel, c)
	if lx.is_empty():
		return out
	var width: float = TextGlyphs.para_width(props, size)
	return {
		"clip_id": c.id,
		"xf": lx["xf"],
		"size": size,
		"props": props,
		"shape": TextExtras.path_shape(props),
		"line": line,
		"width": width,
		"grips": TextExtras.grips(props, size, width),
	}


func _screen(panel: Object, pic: Rect2, t: Dictionary, p: Vector2) -> Vector2:
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	return panel.call("_to_picture", pic, xf * (p / size))


func _layer_at(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> Vector2:
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	var seq_p: Vector2 = (at - pic.position) / maxf(_k(panel, pic), 0.0001)
	return (xf.affine_inverse() * seq_p) * size


func hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	var t: Dictionary = target(panel)
	if t.is_empty():
		return {}
	for g: Dictionary in (t["grips"] as Array[Dictionary]):
		if at.distance_to(_screen(panel, pic, t, g["at"])) <= HANDLE + REACH:
			return {"target": t, "handle": String(g["id"]), "name": String(g.get("name", "")), "key": String(g["id"])}
	return {}


func leg_hit(panel: Object, pic: Rect2, at: Vector2) -> Dictionary:
	var t: Dictionary = target(panel)
	if t.is_empty() or String(t["shape"]) != "points":
		return {}
	var size: Vector2 = t["size"]
	var pts: PackedVector2Array = TextExtras.point_list(t["props"])
	if pts.size() < 2:
		return {}
	var sq: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		sq.append(_screen(panel, pic, t, p * size))
	var near: Dictionary = TextExtras.nearest_leg(sq, at)
	if int(near["index"]) < 0 or float(near["distance"]) > LEG_REACH:
		return {}
	var frac: Vector2 = _layer_at(panel, pic, t, near["at"]) / size
	return {"target": t, "index": int(near["index"]), "frac": frac}


func _taken_by_move(panel: Object, at: Vector2) -> bool:
	return panel.has_method("_grab_handle_at") and bool(panel.call("_grab_handle_at", at))


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not _allowed(panel):
		if not drag.is_empty():
			cancel(panel)
		return false
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed and mb.double_click:
			if _double(panel, pic, mb):
				_accept(view)
				return true
			return false
		if mb.pressed and (mb.ctrl_pressed or mb.meta_pressed):
			if _ctrl_press(panel, pic, mb):
				_accept(view)
				return true
			return false
		if mb.pressed and mb.alt_pressed:
			if _alt_press(panel, pic, mb):
				_accept(view)
				return true
			return false
		if mb.pressed:
			if _taken_by_move(panel, mb.position):
				return false
			var h: Dictionary = hit(panel, pic, mb.position)
			if h.is_empty():
				return false
			_begin(panel, pic, h, mb)
			_accept(view)
			return true
		if drag.is_empty():
			return false
		_end(panel)
		_accept(view)
		return true
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if drag.is_empty():
			var h2: Dictionary = hit(panel, pic, mm.position)
			var now: String = String(h2.get("key", ""))
			if now != hover:
				hover = now
				if view != null:
					view.call("redraw_overlay")
			return false
		_motion(panel, pic, mm)
		_accept(view)
		return true
	return false


func _accept(view: Control) -> void:
	if view != null:
		view.accept_event()
		view.call("redraw_overlay")


func _begin(panel: Object, pic: Rect2, h: Dictionary, mb: InputEventMouseButton) -> void:
	var t: Dictionary = h["target"]
	drag = {"target": t, "handle": String(h["handle"]), "press": mb.position, "press_at": _layer_at(panel, pic, t, mb.position), "open": false, "pointer": mb.position, "chip": String(h.get("name", ""))}
	drags += 1


func _motion(panel: Object, pic: Rect2, mm: InputEventMouseMotion) -> void:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var t: Dictionary = drag["target"]
	var c: Clip = s.clip_by_id(String(t["clip_id"])) if s != null else null
	if c == null or d == null:
		return
	if not bool(drag["open"]):
		if mm.position.distance_to(Vector2(drag["press"])) < SLOP:
			return
		drag["open"] = true
	drag["pointer"] = mm.position
	var size: Vector2 = t["size"]
	var at: Vector2 = _layer_at(panel, pic, t, mm.position)
	var w: float = TextExtras.path_span(size, float(t["width"]))
	var handle: String = String(drag["handle"])
	if handle == "bend":
		var bend: float = TextExtras.bend_for(size, w, at)
		_write(d, s, c, "path_bend", bend)
		drag["chip"] = "Bend %.0f %%" % bend
	elif handle == "radius":
		var r: float = TextExtras.radius_for(size, at)
		_write(d, s, c, "path_size", r)
		drag["chip"] = "Circle size %.0f" % r
	elif handle == "crest":
		var amp: float = TextExtras.amp_for(size, at)
		var waves: float = TextExtras.waves_for(size, w, at)
		_write(d, s, c, "path_size", amp)
		_write(d, s, c, "path_waves", waves)
		drag["chip"] = "Wave %.0f tall, %.1f across" % [amp, waves]
	elif handle.begins_with("p"):
		_drag_point(d, s, c, t, at / size, mm)


func _drag_point(d: Project, s: Sequence, c: Clip, t: Dictionary, frac: Vector2, mm: InputEventMouseMotion) -> void:
	var j: int = int(String(drag["handle"]).substr(1))
	var pts: PackedVector2Array = TextExtras.point_list(t["props"])
	if j < 0 or j >= pts.size():
		return
	var want: Vector2 = frac
	if mm.shift_pressed:
		var was: Vector2 = pts[j]
		want = Vector2(want.x, was.y) if absf(want.x - was.x) >= absf(want.y - was.y) else Vector2(was.x, want.y)
	pts[j] = want
	_write(d, s, c, "path_points", TextExtras.point_flat(pts))
	drag["chip"] = "Point %d: %.1f %%, %.1f %%" % [j + 1, want.x * 100.0, want.y * 100.0]


func _write(d: Project, s: Sequence, c: Clip, field: String, value: Variant) -> void:
	var path: String = "props." + field
	var cur: Variant = c.props.get(field)
	var keyed: bool = field != "path_points" and cur is Dictionary and AnimProp.is_animated(cur)
	Verbs.set_clip_param(d, s, c.id, path, value, s.playhead if keyed else -1.0, true)


func _end(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var opened: bool = bool(drag.get("open", false))
	drag = {}
	if d == null or not d.undo.has_live():
		return
	if opened:
		d.undo.commit_live(DRAG_LABEL)
	else:
		d.undo.cancel_live()


func cancel(panel: Object) -> void:
	var d: Project = panel.call("doc")
	var was: bool = not drag.is_empty()
	drag = {}
	if d != null and was and d.undo.has_live():
		d.undo.cancel_live()


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if drag.is_empty() or not e.pressed or e.keycode != KEY_ESCAPE:
		return false
	cancel(panel)
	var view: Control = panel.get("view")
	if view != null:
		view.call("redraw_overlay")
	return true


func _ctrl_press(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	var on: Dictionary = hit(panel, pic, mb.position)
	if on.is_empty() or not String(on["handle"]).begins_with("p"):
		return false
	return drop_point(panel, int(String(on["handle"]).substr(1)))


func _alt_press(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	var near: Dictionary = leg_hit(panel, pic, mb.position)
	if near.is_empty():
		return false
	return add_point(panel, int(near["index"]) + 1, near["frac"])


func _double(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	var on: Dictionary = hit(panel, pic, mb.position)
	if not on.is_empty() and String(on["handle"]).begins_with("p"):
		return drop_point(panel, int(String(on["handle"]).substr(1)))
	var near: Dictionary = leg_hit(panel, pic, mb.position)
	if near.is_empty():
		return false
	return add_point(panel, int(near["index"]) + 1, near["frac"])


func _set_points(panel: Object, pts: PackedVector2Array, label: String) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var c: Clip = panel.call("gizmo_clip")
	if d == null or s == null or c == null:
		return false
	edits += 1
	var anim: Dictionary = AnimProp.make(TextExtras.point_flat(pts))
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, "props.path_points", anim)]
	return Verbs.run(d, label, cmds)


func add_point(panel: Object, at: int, frac: Vector2) -> bool:
	var t: Dictionary = target(panel)
	if t.is_empty() or String(t["shape"]) != "points":
		return false
	var pts: PackedVector2Array = TextExtras.point_list(t["props"])
	var next: PackedVector2Array = TextExtras.with_point(pts, at, frac)
	if next.size() == pts.size():
		return false
	return _set_points(panel, next, ADD_LABEL)


func drop_point(panel: Object, at: int) -> bool:
	var t: Dictionary = target(panel)
	if t.is_empty() or String(t["shape"]) != "points":
		return false
	var pts: PackedVector2Array = TextExtras.point_list(t["props"])
	var next: PackedVector2Array = TextExtras.without_point(pts, at)
	if next.size() == pts.size():
		return false
	return _set_points(panel, next, DROP_LABEL)


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if pic.size.x <= 0.0 or not _allowed(panel):
		return
	var t: Dictionary = target(panel)
	if t.is_empty():
		return
	var line: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in (t["line"] as PackedVector2Array):
		line.append(_screen(panel, pic, t, p))
	if line.size() >= 2:
		ci.draw_polyline(line, Color(0.0, 0.0, 0.0, 0.45), 3.5, true)
		ci.draw_polyline(line, Color(INK, 0.95), 1.5, true)
	var grips: Array[Dictionary] = t["grips"]
	for g: Dictionary in grips:
		var at: Vector2 = _screen(panel, pic, t, g["at"])
		var hot: bool = String(g["id"]) == hover or (active() and String(drag["handle"]) == String(g["id"]))
		if String(g["look"]) == "ring":
			var r: float = RING + (2.0 if hot else 0.0)
			ci.draw_circle(at, r + 1.5, Color(0.0, 0.0, 0.0, 0.5))
			ci.draw_arc(at, r, 0.0, TAU, 24, INK, 2.0, true)
			ci.draw_circle(at, 2.0, INK)
		else:
			var d: float = DOT + (1.5 if hot else 0.0)
			ci.draw_circle(at, d + 1.5, Color(0.0, 0.0, 0.0, 0.5))
			ci.draw_circle(at, d, INK)
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	if active() and not String(drag.get("chip", "")).is_empty():
		_draw_chip(ci, outer, Vector2(drag["pointer"]) + Vector2(14.0, 16.0), String(drag["chip"]), font, fs)
		return
	if hover.is_empty() or grips.is_empty():
		return
	for g2: Dictionary in grips:
		if String(g2["id"]) != hover:
			continue
		var tip: String = String(g2.get("name", ""))
		if String(t["shape"]) == "points":
			tip += ". " + POINT_HINT
		_draw_chip(ci, outer, _screen(panel, pic, t, g2["at"]) + Vector2(10.0, -22.0), tip, font, fs)


func _draw_chip(ci: CanvasItem, outer: Rect2, at: Vector2, text: String, font: Font, fs: int) -> void:
	if text.is_empty() or font == null:
		return
	var pad: float = PmText.pad()
	var w: float = PmText.width_of(font, text, fs) + pad * 2.0
	var h: float = font.get_height(fs) + 2.0
	var x: float = clampf(at.x, outer.position.x + 2.0, maxf(outer.end.x - w - 2.0, outer.position.x + 2.0))
	var y: float = clampf(at.y, outer.position.y + 2.0, maxf(outer.end.y - h - 2.0, outer.position.y + 2.0))
	var box: Rect2 = Rect2(Vector2(x, y).round(), Vector2(w, h))
	ci.draw_rect(box, LABEL_BACK, true)
	PmText.draw_in(ci, font, box.grow_individual(-pad, 0.0, -pad, 0.0), text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, box)
