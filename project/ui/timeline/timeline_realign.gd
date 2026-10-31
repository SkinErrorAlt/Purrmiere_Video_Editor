extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const Realign := preload("res://doc/realign.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const DRAG_MODE := Realign.DRAG_MODE
const META_HOVER := "realign_hover"
const STATE := "realign"
const CHIP_GAP := 14.0
const CHIP_RISE := 30.0

static var stats: Dictionary = {"steps": 0, "applies": 0, "quiet_emits": 0}


static func tool_on() -> bool:
	return Session.tool_id == Realign.TOOL_ID


static func cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_HSIZE


static func _overlay_redraw(canvas: Control) -> void:
	var ov: Variant = canvas.get("_overlay")
	if ov is CanvasItem:
		(ov as CanvasItem).queue_redraw()


static func _fps(canvas: Control) -> float:
	return float(canvas.call("fps"))


static func hover(canvas: Control, pos: Vector2) -> void:
	if not tool_on():
		if canvas.has_meta(META_HOVER):
			canvas.remove_meta(META_HOVER)
			_overlay_redraw(canvas)
		return
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	var h: Dictionary = canvas.call("hit_at", pos)
	var c: Clip = h.get("clip", null)
	var p: Dictionary = {}
	if s != null and d != null and c != null and String(h.get("zone", "")) == "lane" and not bool(h.get("nest", false)):
		p = Realign.plan(s, c.id, float(h.get("t", c.start)), Input.is_key_pressed(KEY_ALT), Realign.scope())
	var old: Variant = canvas.get_meta(META_HOVER) if canvas.has_meta(META_HOVER) else {}
	var key: String = "" if p.is_empty() else "%s|%s|%.6f|%.6f|%d" % [String(p["clip"]), ",".join(p["ids"] as PackedStringArray), float(p["a"]), float(p["b"]), d.serial]
	var old_key: String = String((old as Dictionary).get("key", "")) if old is Dictionary else ""
	if key == old_key:
		return
	if p.is_empty():
		canvas.remove_meta(META_HOVER)
	else:
		p["key"] = key
		canvas.set_meta(META_HOVER, p)
	_overlay_redraw(canvas)


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	if not tool_on():
		return false
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if s == null or d == null:
		return false
	var h: Dictionary = canvas.call("hit_at", pos)
	var c: Clip = h.get("clip", null)
	var tr: Track = h.get("track", null)
	if c == null or tr == null or bool(h.get("nest", false)):
		return false
	if s.group_locked(c):
		canvas.call("click_select", c.id, mods)
		Events.toast("This clip is in a locked group, unlock the group to realign it")
		return true
	if tr.locked:
		Events.toast("This track is locked")
		return true
	var t: float = float(h.get("t", c.start))
	var p: Dictionary = Realign.plan(s, c.id, t, bool(mods.get("alt", false)), Realign.scope())
	if p.is_empty():
		return true
	var drag: RefCounted = canvas.get("drag")
	drag.call("begin", DRAG_MODE, h, pos, mods)
	var origin: Dictionary = drag.get("origin")
	origin[STATE] = {"plan": p, "t": t, "asked": 0.0, "cmd": null, "loop": Realign.loop_on(), "text": Realign.chip_text(null, 0.0, _fps(canvas))}
	return true


static func state(drag: RefCounted) -> Dictionary:
	if drag == null or String(drag.get("mode")) != DRAG_MODE:
		return {}
	return (drag.get("origin") as Dictionary).get(STATE, {})


static func _quiet(d: Project, undo_cmd: Command, do_cmd: Command) -> bool:
	var was: bool = d.is_blocking_signals()
	d.set_block_signals(true)
	if undo_cmd != null:
		undo_cmd.undo(d)
	var ok: bool = false
	if do_cmd != null:
		do_cmd.do(d)
		ok = do_cmd.ok
		stats["applies"] = int(stats["applies"]) + 1
	d.set_block_signals(was)
	return ok


static func _told(canvas: Control, d: Project) -> void:
	canvas.call("on_doc_changed", "structure")
	if not d.is_blocking_signals():
		stats["quiet_emits"] = int(stats["quiet_emits"]) + 1
		d.changed.emit("live")


static func drag_motion(canvas: Control, drag: RefCounted, pos: Vector2, mods: Dictionary) -> bool:
	var st: Dictionary = state(drag)
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if st.is_empty() or s == null or d == null:
		return false
	var press: Vector2 = drag.get("press")
	var raw: float = (pos.x - press.x) / float(canvas.get("pps"))
	var asked: float = raw if bool(mods.get("ctrl", false)) else Realign.frames(raw, _fps(canvas))
	if st["cmd"] != null and absf(asked - float(st["asked"])) < 0.0000001:
		return true
	stats["steps"] = int(stats["steps"]) + 1
	var prev: Command = st["cmd"]
	var next: Command = null
	if absf(asked) >= Realign.EPS:
		next = Realign.command(s, st["plan"], asked, bool(st["loop"]))
	var ok: bool = _quiet(d, prev, next)
	st["cmd"] = next if ok else null
	st["asked"] = asked
	drag.set("delta_t", asked)
	drag.set("live_key", "")
	Realign.monitor_time = float(st["t"])
	st["text"] = Realign.chip_text(st["cmd"], asked, _fps(canvas))
	_told(canvas, d)
	return true


static func _drop_preview(canvas: Control, drag: RefCounted) -> Dictionary:
	var st: Dictionary = state(drag)
	var d: Project = canvas.call("doc")
	if st.is_empty() or d == null:
		return st
	var prev: Command = st["cmd"]
	if prev != null:
		_quiet(d, prev, null)
		st["cmd"] = null
	Realign.monitor_time = -1.0
	return st


static func drag_release(canvas: Control, drag: RefCounted, _pos: Vector2, _mods: Dictionary) -> bool:
	var st: Dictionary = _drop_preview(canvas, drag)
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if st.is_empty() or s == null or d == null:
		return false
	var asked: float = float(st.get("asked", 0.0))
	if absf(asked) < Realign.EPS:
		_told(canvas, d)
		return false
	var done: Command = Realign.run(d, s, st["plan"], asked, bool(st["loop"]))
	if done == null:
		_told(canvas, d)
		return false
	var note: String = Realign.notice(done, _fps(canvas))
	if not note.is_empty():
		Events.toast(note)
	return true


static func drag_cancel(canvas: Control, drag: RefCounted) -> void:
	var st: Dictionary = _drop_preview(canvas, drag)
	var d: Project = canvas.call("doc")
	if not st.is_empty() and d != null:
		_told(canvas, d)


static func _piece_rect(canvas: Control, g: Dictionary, lanes: Dictionary, s: Sequence, c: Clip, a: float, b: float) -> Rect2:
	var tr: Track = s.track_of(c.id)
	if tr == null:
		return Rect2()
	var l: Dictionary = Lanes.lane_for_track(lanes, tr.id)
	if l.is_empty():
		return Rect2()
	var region: Rect2 = g["main_rect"] if String(l.get("set", "main")) == "main" else g["band_rect"]
	var y: float = Hit.lane_screen_y(g, l)
	var y0: float = maxf(y + 1.0, region.position.y)
	var y1: float = minf(y + float(l["h"]) - 1.0, region.end.y)
	var x0: float = maxf(float(canvas.call("x_of", maxf(a, c.start))), float(g["header_w"]))
	var x1: float = minf(float(canvas.call("x_of", minf(b, c.end()))), canvas.size.x)
	if x1 - x0 < 1.0 or y1 - y0 < 1.0:
		return Rect2()
	return Rect2(x0, y0, x1 - x0, y1 - y0)


static func section_rects(canvas: Control) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var s: Sequence = canvas.call("seq")
	if s == null:
		return out
	var g: Dictionary = canvas.call("geometry")
	var lanes: Dictionary = canvas.call("lanes")
	var drag: RefCounted = canvas.get("drag")
	var st: Dictionary = state(drag)
	if not st.is_empty() and bool(drag.get("active")):
		var cmd: Command = st["cmd"]
		var p: Dictionary = st["plan"]
		var ids: PackedStringArray = cmd.get("pieces") if cmd != null else p["ids"]
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var a: float = float(p["a"]) if bool(p["span"]) else c.start
			var b: float = float(p["b"]) if bool(p["span"]) else c.end()
			var r: Rect2 = _piece_rect(canvas, g, lanes, s, c, a, b)
			if r.has_area():
				out.append(r)
		return out
	if not canvas.has_meta(META_HOVER) or drag.call("in_progress") or (canvas.get("hover") as Dictionary).get("clip", null) == null:
		return out
	var hp: Dictionary = canvas.get_meta(META_HOVER)
	for id2: String in (hp["ids"] as PackedStringArray):
		var c2: Clip = s.clip_by_id(id2)
		if c2 == null:
			continue
		var a2: float = float(hp["a"]) if bool(hp["span"]) else c2.start
		var b2: float = float(hp["b"]) if bool(hp["span"]) else c2.end()
		var r2: Rect2 = _piece_rect(canvas, g, lanes, s, c2, a2, b2)
		if r2.has_area():
			out.append(r2)
	return out


static func chip_rect(canvas: Control, text: String, font: Font, fs: int) -> Rect2:
	var drag: RefCounted = canvas.get("drag")
	var at: Vector2 = drag.get("last")
	var pad: float = PmText.chip_pad()
	var w: float = ceil(PmText.width_of(font, text, fs)) + pad * 3.0
	var h: float = ceil(font.get_height(fs)) + 6.0
	var g: Dictionary = canvas.call("geometry")
	var x: float = at.x + float(Tk.px(CHIP_GAP))
	if x + w > canvas.size.x - 2.0:
		x = at.x - float(Tk.px(CHIP_GAP)) - w
	x = maxf(x, float(g["header_w"]) + 2.0)
	var y: float = maxf(at.y - float(Tk.px(CHIP_RISE)), float(g["ruler_h"]) + 2.0)
	return Rect2(x, y, w, h)


static func draw_overlay(canvas: Control, ci: CanvasItem) -> void:
	if not tool_on():
		return
	var drag: RefCounted = canvas.get("drag")
	var st: Dictionary = state(drag)
	var live: bool = not st.is_empty() and bool(drag.get("active"))
	var rects: Array[Rect2] = section_rects(canvas)
	var ink: Color = Tk.c["sol"]
	var radius: float = float(Tk.px(Tk.sz("radius_chip")))
	for r: Rect2 in rects:
		if live:
			ci.draw_rect(r, Color(ink, 0.10), true)
			Paint.rounded(ci, r, Color(0, 0, 0, 0), radius, ink, 2)
		else:
			Paint.rounded(ci, r, Color(ink, 0.05), radius, Color(ink, 0.7), 1)
	if not live:
		return
	var font: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_meta"))
	var text: String = String(st.get("text", ""))
	var pill: Rect2 = chip_rect(canvas, text, font, fs)
	Paint.rounded(ci, pill, Tk.c["bg_panel_alt"], radius, Tk.c["border_soft"], 1)
	var split: int = text.find("  ")
	var main_text: String = text if split < 0 else text.substr(0, split)
	var base: float = PmText.baseline_in(font, fs, pill)
	var drawn: Rect2 = PmText.draw(ci, font, pill, main_text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), base, PmText.WHOLE)
	if split >= 0 and drawn.has_area():
		var rest: Rect2 = Rect2(drawn.end.x, pill.position.y, pill.end.x - drawn.end.x, pill.size.y)
		PmText.draw_in(ci, font, rest, text.substr(split), fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, base, PmText.WHOLE, pill, PmText.chip_pad())
