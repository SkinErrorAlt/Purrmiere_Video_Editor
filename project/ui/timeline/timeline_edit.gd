extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const Verbs := preload("res://doc/verbs.gd")
const Tools := preload("res://doc/commands/edit_tools.gd")
const SourceMarks := preload("res://doc/source_marks.gd")
const ClipLoop := preload("res://doc/clip_loop.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const RegionClipUi := preload("res://modules/core_panels/organizer/region_clip_ui.gd")
const ViewSoundUi := preload("res://modules/core_panels/view_sound_ui.gd")
const SyncAlign := preload("res://doc/sync_align.gd")
const SELF_PATH := "res://ui/timeline/timeline_edit.gd"
const COMMANDS_PATH := "res://modules/core_panels/edit_commands.gd"
const HANDLE := 7.0
const MIN_CLIP_W := 28.0
const CURVE_STEPS := 12

static var clip_markers_drawn: int = 0
static var fade_handles_drawn: int = 0
static var gaps_drawn: int = 0


static func _commands() -> GDScript:
	return load(COMMANDS_PATH)


static func _curve(x_from: float, x_to: float, top: float, bottom: float, shape: String, rising: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 1 if shape == "linear" else CURVE_STEPS
	for i: int in steps + 1:
		var u: float = float(i) / float(steps)
		var g: float = Tools.fade_gain(shape, u if rising else 1.0 - u)
		pts.append(Vector2(lerpf(x_from, x_to, u), bottom - g * (bottom - top)))
	return pts


static func draw_fades(ci: CanvasItem, seq: Sequence, c: Clip, track_kind: String, r: Rect2, clip_x0: float, clip_x1: float, pps: float) -> void:
	if r.size.y < 6.0 or clip_x1 - clip_x0 < 3.0:
		return
	var shape: String = Tools.fade_shape(c) if track_kind == "audio" else "linear"
	var wash: Color = Color(Tk.c["bg_app"], 0.45)
	var line: Color = Tk.c["text_dim"]
	var top: float = r.position.y
	var bottom: float = r.end.y
	var fin: float = Tools.fade_value(c, track_kind, "in") * pps
	var fout: float = Tools.fade_value(c, track_kind, "out") * pps
	if fin > 1.0:
		var x_end: float = minf(clip_x0 + fin, clip_x1)
		var curve: PackedVector2Array = _curve(clip_x0, x_end, top, bottom, shape, true)
		var poly := PackedVector2Array([Vector2(clip_x0, top)])
		for i: int in range(curve.size() - 1, -1, -1):
			poly.append(curve[i])
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, wash)
		ci.draw_polyline(curve, line, 1.0, true)
	if fout > 1.0:
		var x_start: float = maxf(clip_x1 - fout, clip_x0)
		var curve2: PackedVector2Array = _curve(x_start, clip_x1, top, bottom, shape, false)
		var poly2: PackedVector2Array = curve2.duplicate()
		poly2.append(Vector2(clip_x1, top))
		if poly2.size() >= 3:
			ci.draw_colored_polygon(poly2, wash)
		ci.draw_polyline(curve2, line, 1.0, true)


static func draw_clip_markers(ci: CanvasItem, c: Clip, r: Rect2, clip_x0: float, pps: float, item: MediaItem = null) -> void:
	if c == null or r.size.y < 12.0:
		return
	RegionClipUi.draw_on_clip(ci, c, r, clip_x0, pps, item)
	var from_source: Array[Dictionary] = SourceMarks.on_clip(c, item) if item != null else ([] as Array[Dictionary])
	if c.markers.is_empty() and from_source.is_empty():
		return
	var y: float = r.position.y + 1.0
	for m: Marker in c.markers:
		_clip_mark(ci, m, clip_x0 + m.time * pps, m.duration * pps, r, y)
	for e: Dictionary in from_source:
		_clip_mark(ci, e["marker"], clip_x0 + float(e["local"]) * pps, float(e["length"]) * pps, r, y)


static func _clip_mark(ci: CanvasItem, m: Marker, x: float, len_px: float, r: Rect2, y: float) -> void:
	if x < r.position.x - 4.0 or x > r.end.x + 4.0:
		return
	var col: Color = m.free_colour() if m.has_free_colour() else (Tk.label_colour(m.colour) if m.colour >= 0 else Tk.c["text"])
	if len_px > 0.0:
		var w: float = minf(len_px, r.end.x - x)
		if w > 0.0:
			ci.draw_rect(Rect2(x, y, w, 2.0), col, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, y), Vector2(x + 3.5, y), Vector2(x + 3.5, y + 4.0), Vector2(x, y + 7.5), Vector2(x - 3.5, y + 4.0)]), col)
	if not m.comment.is_empty():
		ci.draw_circle(Vector2(x, y + 2.5), 1.2, Tk.c["bg_app"])
	clip_markers_drawn += 1


static func speed_badge(c: Clip) -> String:
	if Tools.is_hold(c):
		return "hold"
	return "ramp"


static func draw_overlay(canvas: Control, ci: Control) -> void:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return
	var g: Dictionary = canvas.call("geometry")
	var header_w: float = float(g["header_w"])
	var gap: Dictionary = canvas.get("selected_gap")
	if not gap.is_empty():
		_draw_gap(canvas, ci, s, g, gap, header_w)
	var drag: RefCounted = canvas.get("drag")
	if String(drag.get("mode")) == "track_reorder" and bool(drag.get("active")):
		var target: Dictionary = reorder_target(canvas, String(drag.get("track_id")), drag.get("last"))
		if not target.is_empty():
			ci.draw_rect(Rect2(0.0, float(target["y"]) - 1.0, ci.size.x, 2.0), Tk.c["accent"], true)
	var dp: Dictionary = canvas.get("drop_preview")
	if String(dp.get("kind", "")) == "replace":
		var rc: Rect2 = dp.get("rect", Rect2())
		if rc.size.x > 0.0:
			ci.draw_rect(rc, Tk.c["selection_fill"], true)
			Paint.rounded(ci, rc, Color(0, 0, 0, 0), 3.0, Tk.c["accent"], 2)
	var hov: Dictionary = canvas.get("hover")
	var hc: Clip = hov.get("clip", null)
	var ht: Track = hov.get("track", null)
	if hc == null or ht == null or String(hov.get("zone", "")) != "lane" or bool(hov.get("nest", false)) or bool(hov.get("transition", false)) or drag.call("in_progress") or Session.tool_id != "select":
		return
	var lane: Dictionary = hov.get("lane", {})
	if lane.is_empty():
		return
	var y: float = Hit.lane_screen_y(g, lane) + 1.0
	var x0: float = float(canvas.call("x_of", hc.start))
	var x1: float = float(canvas.call("x_of", hc.end()))
	if x1 - x0 < MIN_CLIP_W:
		return
	var pps: float = float(g["pps"])
	var hot: String = String(hov.get("fade", ""))
	for side: String in ["in", "out"]:
		var hx: float = Hit.fade_handle_x(x0, x1, Tools.fade_value(hc, ht.kind, side) * pps, side == "in")
		if hx < header_w or hx > ci.size.x:
			continue
		var big: float = HANDLE + (2.0 if hot == side else 0.0)
		var rr: Rect2 = Rect2(hx - big * 0.5, y + 1.0, big, big)
		Paint.rounded(ci, rr, Tk.c["text_bright"] if hot == side else Tk.c["text_dim"], 2.0, Tk.c["bg_app"], 1)
		fade_handles_drawn += 1


static func _draw_gap(canvas: Control, ci: Control, s: Sequence, g: Dictionary, gap: Dictionary, header_w: float) -> void:
	var lane: Dictionary = Lanes.lane_for_track(canvas.call("lanes"), String(gap.get("track_id", "")))
	if lane.is_empty():
		return
	var region: Rect2 = g["main_rect"] if String(lane["set"]) == "main" else g["band_rect"]
	var y: float = Hit.lane_screen_y(g, lane)
	var h: float = float(lane["h"])
	var y0: float = maxf(y + 1.0, region.position.y)
	var y1: float = minf(y + h - 1.0, region.end.y)
	var x0: float = maxf(float(canvas.call("x_of", float(gap["t0"]))), header_w)
	var x1: float = minf(float(canvas.call("x_of", float(gap["t1"]))), ci.size.x)
	if x1 <= x0 or y1 <= y0:
		return
	var r: Rect2 = Rect2(x0, y0, x1 - x0, y1 - y0)
	ci.draw_rect(r, Tk.c["selection_fill"], true)
	Paint.rounded(ci, r, Color(0, 0, 0, 0), 3.0, Tk.c["sol"], 1)
	gaps_drawn += 1


static func gap_for_point(canvas: Control, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return {}
	var h: Dictionary = canvas.call("hit_at", pos)
	var tr: Track = h.get("track", null)
	if String(h.get("zone", "")) != "lane" or tr == null or bool(h.get("nest", false)) or h.get("clip", null) != null:
		return {}
	var span: Vector2 = Tools.gap_at(s, tr.id, float(h.get("t", 0.0)))
	if span.x < 0.0:
		return {}
	return {"track_id": tr.id, "t0": span.x, "t1": span.y}


static func release_left(canvas: Control, pos: Vector2, mods: Dictionary) -> void:
	var drag: RefCounted = canvas.get("drag")
	var gap_click: bool = String(drag.get("mode")) == "range" and not bool(drag.get("active"))
	var at: Vector2 = drag.get("press")
	drag.call("release", pos, mods)
	if gap_click:
		canvas.set("selected_gap", gap_for_point(canvas, at))
		canvas.queue_redraw()
		(canvas.call("overlay") as Control).queue_redraw()


static func reorder_target(canvas: Control, track_id: String, pos: Vector2) -> Dictionary:
	var s: Sequence = canvas.call("seq")
	var tr: Track = s.track_by_id(track_id) if s != null else null
	if tr == null:
		return {}
	var ln: Dictionary = canvas.call("lanes")
	var g: Dictionary = canvas.call("geometry")
	var main_rect: Rect2 = g["main_rect"]
	var others: Array[Dictionary] = []
	for l: Dictionary in ln["main"]:
		var lt: Track = l["track"]
		if bool(l["nest"]) or lt.kind != tr.kind or lt == tr:
			continue
		others.append(l)
	if others.is_empty():
		return {}
	var content_y: float = pos.y - main_rect.position.y + float(g["scroll_y"])
	var slot: int = 0
	for l: Dictionary in others:
		if content_y > float(l["y"]) + float(l["h"]) * 0.5:
			slot += 1
	var full: Array[Track] = s.tracks_of_kind(tr.kind).duplicate()
	full.erase(tr)
	var index: int = 0
	var line_y: float = 0.0
	if slot < others.size():
		var below: Track = others[slot]["track"]
		index = full.find(below) + (1 if tr.kind == "video" else 0)
		line_y = Hit.lane_screen_y(g, others[slot])
	else:
		var last: Dictionary = others[others.size() - 1]
		var above: Track = last["track"]
		index = full.find(above) + (0 if tr.kind == "video" else 1)
		line_y = Hit.lane_screen_y(g, last) + float(last["h"])
	return {"index": index, "y": line_y}


static func reorder_at(canvas: Control, track_id: String, pos: Vector2) -> bool:
	var target: Dictionary = reorder_target(canvas, track_id, pos)
	if target.is_empty():
		return false
	return Tools.reorder_track(canvas.call("doc"), canvas.call("seq"), track_id, int(target["index"]))


static func _insert_after(items: Array, after_id: String, extra: Array) -> Array:
	var at: int = -1
	for i: int in items.size():
		if String((items[i] as Dictionary).get("id", "")) == after_id:
			at = i
	if at < 0:
		at = items.size() - 1
	var out: Array = items.slice(0, at + 1)
	out.append_array(extra)
	out.append_array(items.slice(at + 1))
	return out


static func use_time(seq: Sequence, c: Clip, t: float) -> float:
	if seq != null and seq.playhead >= c.start and seq.playhead < c.end():
		return seq.playhead
	return t


static func clip_items(canvas: Control, c: Clip, t: float, items: Array) -> Array:
	var s: Sequence = canvas.call("seq")
	if s == null or c == null:
		return items
	var tr: Track = s.track_of(c.id)
	var out: Array = items
	var pair: PackedStringArray = Tools.through_pair(s, c.id, t)
	if not pair.is_empty():
		out = _insert_after(out, "add_edit", [PmMenu.item("join_through", "Join through edit")])
	out = _insert_after(out, "enable", [loop_item(c)])
	var extra: Array = []
	if tr != null and tr.is_picture(c):
		extra.append(PmMenu.item("freeze_frame", "Freeze frame", Cmd.keys_text("clip.freeze_frame")))
		extra.append(PmMenu.item("rewind_buildup", "Rewind build-up", Cmd.keys_text("clip.rewind_buildup")))
		extra.append(PmMenu.item("hold_end", "Hold this frame to the end"))
	extra.append(PmMenu.item("match_frame", "Match frame", Cmd.keys_text("clip.match_frame")))
	var rep: Dictionary = PmMenu.item("replace_footage", "Replace with the selected bin item")
	rep["disabled"] = String(_commands().call("bin_choice")).is_empty()
	extra.append(rep)
	var lined: Dictionary = PmMenu.item("replace_footage_synced", "Replace with it, lined up on the sync marks")
	lined["disabled"] = bool(rep["disabled"]) or not SyncAlign.has_sync(canvas.call("doc").media_by_id(c.media_id))
	extra.append(lined)
	if not Tools.audio_clip_ids(s, Verbs.selection(s)).is_empty():
		extra.append(PmMenu.item("audio_gain", "Audio gain", Cmd.keys_text("clip.audio_gain")))
	var regions_items: Array = RegionClipUi.clip_items(canvas.call("doc"), c, t)
	if not regions_items.is_empty():
		out = regions_items + out
	var view_items: Array = ViewSoundUi.clip_items(s, c)
	if not view_items.is_empty():
		out = view_items + out
	return _insert_after(out, "speed", extra)


static func loop_item(c: Clip) -> Dictionary:
	return PmMenu.check_item(ClipLoop.MENU_ID, ClipLoop.MENU_LABEL, c.loop)


static func on_clip_menu(canvas: Control, id: String, clip_id: String, t: float) -> bool:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var cmds: GDScript = _commands()
	if RegionClipUi.on_clip_menu(canvas, d, s, id, clip_id):
		return true
	if ViewSoundUi.on_clip_menu(d, s, id, clip_id):
		return true
	if id == ClipLoop.MENU_ID:
		ClipLoop.toggle(d, s, clip_id)
		return true
	if id == "join_through":
		var pair: PackedStringArray = Tools.through_pair(s, clip_id, t)
		if pair.size() == 2:
			Tools.heal(d, s, pair[0], pair[1])
		return true
	if id == "freeze_frame":
		cmds.call("open_freeze_form", clip_id, use_time(s, c, t))
		return true
	if id == "rewind_buildup":
		cmds.call("open_rewind_form", clip_id)
		return true
	if id == "hold_end":
		cmds.call("hold_to_end_at", clip_id, use_time(s, c, t))
		return true
	if id == "match_frame":
		cmds.call("match_at", use_time(s, c, t))
		return true
	if id == "replace_footage":
		cmds.call("replace_clip_with_bin", clip_id)
		return true
	if id == "replace_footage_synced":
		cmds.call("replace_clip_with_bin", clip_id, true)
		return true
	if id == "audio_gain":
		Cmd.run("clip.audio_gain")
		return true
	return false


static func open_fade_menu(canvas: Control, c: Clip, side: String, at: Vector2) -> void:
	var s: Sequence = canvas.call("seq")
	var tr: Track = s.track_of(c.id) if s != null else null
	if tr == null:
		return
	var items: Array = []
	if tr.is_sound(c):
		var shape: String = Tools.fade_shape(c)
		for i: int in Tools.FADE_SHAPES.size():
			items.append(PmMenu.check_item("shape:" + Tools.FADE_SHAPES[i], Tools.FADE_SHAPE_LABELS[i], shape == Tools.FADE_SHAPES[i]))
		items.append(PmMenu.separator())
	var remove: Dictionary = PmMenu.item("remove", "Remove fade in" if side == "in" else "Remove fade out")
	remove["disabled"] = Tools.fade_value(c, tr.kind, side) <= 0.0
	items.append(remove)
	var m: Control = PmMenu.open(canvas, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(load(SELF_PATH), "on_fade_menu").bind(canvas, c.id, side))


static func on_fade_menu(id: String, canvas: Control, clip_id: String, side: String) -> void:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return
	if id.begins_with("shape:"):
		var ids: PackedStringArray = PackedStringArray([clip_id])
		for other: String in Verbs.selection(s):
			if not ids.has(other):
				ids.append(other)
		Tools.set_fade_shape(d, s, ids, id.substr(6))
	elif id == "remove":
		Tools.set_fade(d, s, clip_id, side, 0.0)


static func replace_preview(canvas: Control, payload: Dictionary, h: Dictionary) -> bool:
	if String(payload.get("kind", "")) != "media" or not Input.is_key_pressed(KEY_ALT):
		return false
	var c: Clip = h.get("clip", null)
	var lane: Dictionary = h.get("lane", {})
	if c == null or lane.is_empty() or bool(h.get("nest", false)):
		canvas.set("drop_preview", {})
		(canvas.call("overlay") as Control).queue_redraw()
		return true
	var g: Dictionary = canvas.call("geometry")
	var x0: float = maxf(float(canvas.call("x_of", c.start)), float(g["header_w"]))
	var x1: float = minf(float(canvas.call("x_of", c.end())), canvas.size.x)
	var y: float = Hit.lane_screen_y(g, lane)
	canvas.set("drop_preview", {"kind": "replace", "clip_id": c.id, "rect": Rect2(x0, y + 1.0, maxf(x1 - x0, 1.0), float(lane["h"]) - 2.0)})
	(canvas.call("overlay") as Control).queue_redraw()
	return true


static func replace_drop(canvas: Control, payload: Dictionary, h: Dictionary) -> bool:
	if String(payload.get("kind", "")) != "media" or not Input.is_key_pressed(KEY_ALT):
		return false
	var c: Clip = h.get("clip", null)
	var ids: Array = payload.get("ids", [])
	if c == null or ids.is_empty() or bool(h.get("nest", false)):
		Events.toast("Hold Alt and drop onto a clip to replace its footage")
		return true
	if not Tools.replace_with(canvas.call("doc"), canvas.call("seq"), c.id, String(ids[0])):
		Events.toast("That bin item cannot replace this clip")
	return true
