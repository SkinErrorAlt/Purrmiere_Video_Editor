extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const CARD_PATH := "res://ui/timeline/stack_card.gd"
const MARK_H := 2.0
const EDGE_STEP := 2.0
const EDGE_MAX := 3
const TICK_H := 6.0
const BADGE_H := 13.0
const BADGE_MIN_SPAN := 18.0
const TIP_GAP := Vector2(16.0, 18.0)
const TIP_LAY_OVER := "Shift: lay over the clips here"
const TIP_OVERWRITE := "Laying over. Shift: overwrite instead"
const MENU_FRONT := "stack_front"
const MENU_BACK := "stack_back"
const MENU_LIST := "stack_list"
const HEADER_FREE := "free_tracks"
const HEADER_OVERLAP := "overlap_clips"
const CMD_FRONT := "clip.bring_to_front"
const CMD_BACK := "clip.send_to_back"
const CMD_PASTE := "edit.paste_overlap"
const CMD_FREE := "seq.free_tracks"
const CMD_OVERLAP := "seq.overlap_clips"


static var _slot_key: String = ""
static var _slots: Dictionary = {}


static func meter_level(canvas: Control, t: Track, meters: PackedFloat32Array) -> float:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or t == null:
		return 0.0
	var key: String = s.id + "|" + str(d.serial)
	if key != _slot_key:
		_slot_key = key
		_slots = AudioGraph.meter_slots(d, s)
	var slots: PackedInt32Array = _slots.get(t.id, PackedInt32Array())
	return maxf(AudioGraph.slot_level(meters, slots, 0), AudioGraph.slot_level(meters, slots, 1))


static func draw_order(t: Track, i: int, j: int) -> Array:
	var list: Array[Clip] = []
	var pos: Dictionary = {}
	for k: int in range(i, j + 1):
		list.append(t.clips[k])
		pos[t.clips[k]] = k
	var out: Array = []
	for c: Clip in t.stack_sorted(list):
		out.append(pos[c])
	return out


static func order_for(t: Track, i: int, j: int) -> Array:
	if t.has_stack():
		return draw_order(t, i, j)
	var out: Array = []
	for k: int in range(i, j + 1):
		out.append(k)
	return out


static func draw_lane_marks(canvas: Control, s: Sequence, t: Track, lane_y: float, lane_h: float, t0: float, t1: float) -> void:
	if not t.has_stack():
		return
	var header_w: float = float(canvas.get("header_w"))
	var right: float = canvas.size.x
	var font: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var bottom: float = lane_y + lane_h - 1.0
	for span: Dictionary in t.stack_spans(t0, t1):
		var x0: float = maxf(float(canvas.call("x_of", float(span["t0"]))), header_w)
		var x1: float = minf(float(canvas.call("x_of", float(span["t1"]))), right)
		if x1 - x0 < 1.0:
			continue
		canvas.draw_rect(Rect2(x0, bottom - MARK_H, x1 - x0, MARK_H), Tk.c["accent_dim"], true)
		canvas.draw_rect(Rect2(x0, bottom - MARK_H - 3.0, 1.0, MARK_H + 3.0), Tk.c["accent_dim"], true)
		canvas.draw_rect(Rect2(x1 - 1.0, bottom - MARK_H - 3.0, 1.0, MARK_H + 3.0), Tk.c["accent_dim"], true)
		var n: int = mini(int(span["count"]) - 1, EDGE_MAX)
		for k: int in range(1, n + 1):
			var ey: float = bottom - MARK_H - 1.0 - EDGE_STEP * float(k)
			canvas.draw_rect(Rect2(x0 + 2.0, ey, maxf(x1 - x0 - 4.0, 1.0), 1.0), Color(Tk.c["text_faint"], 0.85), true)
		var bh: float = maxf(float(Tk.px(BADGE_H)), ceil(font.get_height(fs)) + 2.0)
		if x1 - x0 >= BADGE_MIN_SPAN and lane_h >= bh + 10.0:
			var text: String = str(int(span["count"]))
			var bw: float = ceil(PmText.width_of(font, text, fs)) + PmText.chip_pad() * 2.0
			var br: Rect2 = Rect2(x0 + 3.0, bottom - MARK_H - EDGE_STEP * float(n) - bh - 3.0, bw, bh)
			if br.end.x < x1 - 2.0 and br.position.y > lane_y + Paint.name_row_h():
				Paint.rounded(canvas, br, Tk.c["bg_panel_alt"], bh * 0.5, Tk.c["border_soft"], 1)
				PmText.draw(canvas, font, br, text, fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_CENTER, PmText.chip_pad(), NAN, PmText.WHOLE)
	_draw_hidden_edges(canvas, s, t, lane_y, lane_h, t0, t1, header_w, right)


static func name_room(canvas: Control, t: Track, c: Clip, r: Rect2) -> Rect2:
	if not t.has_stack():
		return r
	var x0: float = r.position.x
	var x1: float = r.end.x
	for o: Clip in t.overlapping(c):
		if t.stack_sorted([c, o] as Array[Clip])[1] != o:
			continue
		var ox0: float = float(canvas.call("x_of", o.start))
		var ox1: float = float(canvas.call("x_of", o.end()))
		if ox0 <= x0 + 0.5:
			x0 = maxf(x0, ox1)
		else:
			x1 = minf(x1, ox0)
	return Rect2(x0, r.position.y, maxf(x1 - x0, 0.0), r.size.y)


static func _draw_hidden_edges(canvas: Control, s: Sequence, t: Track, lane_y: float, lane_h: float, t0: float, t1: float, header_w: float, right: float) -> void:
	for c: Clip in t.clips_in_range(t0, t1):
		if c.end() <= t0 or c.start >= t1:
			continue
		for edge: float in [c.start, c.end()]:
			var probe: float = edge + (0.0005 if edge == c.start else -0.0005)
			var front: Clip = t.front_at(probe)
			if front == null or front == c:
				continue
			var x: float = float(canvas.call("x_of", edge))
			if x < header_w or x > right:
				continue
			canvas.draw_rect(Rect2(x, lane_y + 1.0, 1.0, TICK_H), Tk.c["text_faint"], true)
		if s != null and s.selected_clip_ids.has(c.id) and not _in_front_everywhere(t, c):
			var x0: float = maxf(float(canvas.call("x_of", c.start)), header_w)
			var x1: float = minf(float(canvas.call("x_of", c.end())), right)
			if x1 - x0 >= 2.0:
				canvas.draw_rect(Rect2(x0 + 0.5, lane_y + 1.5, x1 - x0 - 1.0, lane_h - 3.0), Tk.c["sol"], false, 1.0)


static func _in_front_everywhere(t: Track, c: Clip) -> bool:
	for o: Clip in t.overlapping(c):
		var pair: Array[Clip] = [o, c]
		if t.stack_sorted(pair)[1] != c:
			return false
	return true


static func alt_pick(canvas: Control, clip_id: String, press: Vector2, mods: Dictionary) -> String:
	if not bool(mods.get("alt", false)) or bool(mods.get("ctrl", false)):
		return clip_id
	var s: Sequence = canvas.call("seq")
	if s == null:
		return clip_id
	var h: Dictionary = canvas.call("hit_at", press)
	var tr: Track = h.get("track", null)
	if tr == null or not tr.has_stack():
		return clip_id
	var t: float = float(h.get("t", 0.0))
	if Verbs.clips_under(s, tr, t).size() < 2:
		return clip_id
	return Verbs.pick_behind(s, tr, t, clip_id)


static func open_card(canvas: Control, menu: Control, h: Dictionary, at: Vector2) -> Control:
	if menu == null or not menu.is_inside_tree():
		return null
	var s: Sequence = canvas.call("seq")
	var tr: Track = h.get("track", null)
	if s == null or tr == null or bool(h.get("nest", false)):
		return null
	var t: float = float(h.get("t", 0.0))
	if Verbs.clips_under(s, tr, t).size() < 2:
		return null
	var overlay: Node = PmUI.overlay_for(canvas)
	if overlay == null:
		return null
	var script: GDScript = load(CARD_PATH)
	var card: Control = script.new()
	card.call("setup", canvas, tr.id, t, at)
	overlay.add_child(card)
	card.call("attach_menu", menu)
	return card


static func open_clip_menu(canvas: Control, c: Clip, t: float, at: Vector2) -> Control:
	var edit_kit: GDScript = load("res://ui/timeline/timeline_edit.gd")
	var items: Array = edit_kit.call("clip_items", canvas, c, t, canvas.call("_clip_menu_items", c, false))
	var m: Control = PmMenu.open(canvas, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(canvas, "_on_clip_menu").bind(c.id, t))
	return m


static func menu_items(canvas: Control, c: Clip) -> Array:
	var out: Array = []
	var s: Sequence = canvas.call("seq")
	if not Verbs.in_stack(s, c):
		return out
	out.append(PmMenu.separator())
	out.append(PmMenu.item(MENU_FRONT, "Bring to front", Cmd.keys_text(CMD_FRONT)))
	out.append(PmMenu.item(MENU_BACK, "Send to back", Cmd.keys_text(CMD_BACK)))
	return out


static func on_clip_menu(canvas: Control, id: String, clip_id: String) -> bool:
	if id != MENU_FRONT and id != MENU_BACK:
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return true
	if id == MENU_FRONT:
		Verbs.bring_to_front(d, s, clip_id)
	else:
		Verbs.send_to_back(d, s, clip_id)
	return true


static func header_items(t: Track) -> Array:
	var out: Array = []
	out.append(PmMenu.separator())
	out.append(PmMenu.check_item(HEADER_FREE, "Free tracks", t.free, Cmd.keys_text(CMD_FREE)))
	return out


static func on_header_menu(canvas: Control, id: String) -> bool:
	if id != HEADER_FREE:
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d != null and s != null:
		Verbs.set_free_tracks(d, s, not s.free_tracks)
	return true


static func drop_overlap(s: Sequence) -> bool:
	return Verbs.place_mode(s, false, Input.is_key_pressed(KEY_SHIFT)) == Verbs.MODE_OVERLAP


static func free_lanes(canvas: Control, s: Sequence, track: Track, lane: Dictionary, wants_video: bool, wants_audio: bool) -> Dictionary:
	var out: Dictionary = {"video": {}, "audio": {}}
	if wants_video:
		out["video"] = lane
		if wants_audio:
			var below: Track = s.track_below(track)
			while below != null and below.locked:
				below = s.track_below(below)
			if below != null:
				out["audio"] = Lanes.lane_for_track(canvas.call("lanes"), below.id)
	elif wants_audio:
		out["audio"] = lane
	return out


static func tip_text(s: Sequence, insert: bool, shift: bool) -> String:
	if insert or s == null:
		return ""
	return TIP_OVERWRITE if Verbs.place_mode(s, false, shift) == Verbs.MODE_OVERLAP else TIP_LAY_OVER


static func draw_overlay(canvas: Control, ci: Control) -> void:
	var s: Sequence = canvas.call("seq")
	if s == null:
		return
	var drag: RefCounted = canvas.get("drag")
	var text: String = ""
	var at: Vector2 = Vector2.ZERO
	if drag != null and String(drag.get("mode")) == "move" and bool(drag.get("active")) and not bool(drag.get("duplicate")):
		var mods: Dictionary = drag.get("mods")
		text = tip_text(s, bool(drag.get("insert")), bool(mods.get("shift", false)))
		at = drag.get("last")
	var dp: Dictionary = canvas.get("drop_preview")
	if text.is_empty() and String(dp.get("kind", "")) == "media":
		text = String(dp.get("refused", "")) if not String(dp.get("refused", "")).is_empty() else tip_text(s, bool(dp.get("insert", false)), Input.is_key_pressed(KEY_SHIFT))
		at = Vector2(float(canvas.call("x_of", float(dp.get("t", 0.0)))), float(dp.get("y", 0.0)))
	if text.is_empty():
		return
	draw_tip(ci, text, at + TIP_GAP)


static func draw_tip(ci: Control, text: String, at: Vector2) -> void:
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var tw: float = ceil(PmText.width_of(font, text, fs))
	var h: float = maxf(float(Tk.px(20.0)), ceil(font.get_height(fs)) + 4.0)
	var r: Rect2 = Rect2(at, Vector2(minf(tw + pad * 2.0, maxf(ci.size.x - 4.0, 0.0)), h))
	if r.end.x > ci.size.x - 2.0:
		r.position.x = maxf(ci.size.x - 2.0 - r.size.x, 2.0)
	if r.end.y > ci.size.y - 2.0:
		r.position.y = at.y - TIP_GAP.y * 2.0 - h
	Paint.rounded(ci, r, Tk.c["bg_panel_alt"], float(Tk.px(Tk.sz("radius_menu"))), Tk.c["border_soft"], 1)
	PmText.draw(ci, font, r, text, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, pad)
