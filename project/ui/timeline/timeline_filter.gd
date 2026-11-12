extends RefCounted

const Fold := preload("res://ui/timeline/timeline_fold.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipFilter := preload("res://doc/clip_filter.gd")
const ViewCmds := preload("res://doc/commands/track_view_cmds.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const Tags := preload("res://doc/marker_tags.gd")
const Verbs := preload("res://doc/verbs.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const Far := preload("res://ui/timeline/timeline_far.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Solo := preload("res://ui/timeline/timeline_view_solo.gd")
const LISTEN_TEXT := "LISTEN MUTED, STILL EXPORTED"
const LISTEN_HATCH := 9.0
const META := "timeline_filter_state"
const GHOST_MIX := 0.72
const EDGE_REACH := 6.0
const NAME_MIN_W := 40.0
const NEW_VIDEO := "new:video"
const NEW_AUDIO := "new:audio"

static var pass_clicks: bool = true
static var cheap: bool = true
static var last_note: String = ""


class State extends RefCounted:
	var serial: int = -1
	var seq_ref: int = 0
	var view: Dictionary = {}
	var matcher: ClipFilter.Matcher = null
	var active: bool = false
	var rules: bool = false
	var solo: bool = false
	var solo_hidden: Dictionary = {}
	var darken: bool = false
	var shown: Dictionary = {}
	var roles: Dictionary = {}
	var track_any: Dictionary = {}
	var paint: int = -1
	var sel: Dictionary = {}
	var sel_tracks: Dictionary = {}
	var moving: Dictionary = {}
	var pending: Array[Rect2] = []
	var lane_dark: bool = false
	var lane_veil: bool = false
	var lane_done: bool = false
	var lane_out: bool = false
	var lane_rect: Rect2 = Rect2()
	var font: Font = null
	var fs: int = 11
	var header_w: float = 160.0
	var pps: float = 40.0
	var scroll_x: float = 0.0
	var fold: Dictionary = {}
	var width: float = 0.0
	var ghosts: int = 0
	var veils: int = 0


static func _doc(canvas: Control) -> Project:
	return canvas.call("doc") if canvas != null else null


static func _seq(canvas: Control) -> Sequence:
	return canvas.call("seq") if canvas != null else null


static func view_of(s: Sequence) -> Dictionary:
	return ClipFilter.clean(s.track_view) if s != null else {}


static func state(canvas: Control) -> State:
	return state_for(canvas, _doc(canvas), _seq(canvas))


static func state_for(canvas: Control, d: Project, s: Sequence) -> State:
	var st: State = canvas.get_meta(META) if canvas.has_meta(META) else null
	if st == null:
		st = State.new()
		canvas.set_meta(META, st)
	var serial: int = d.serial if d != null else -1
	var ref: int = s.get_instance_id() if s != null else 0
	if st.serial != serial or st.seq_ref != ref:
		st.serial = serial
		st.seq_ref = ref
		st.view = view_of(s)
		st.matcher = ClipFilter.compile(s, st.view) if s != null else null
		st.rules = st.matcher != null and st.matcher.active
		st.solo = Solo.is_on(s)
		st.solo_hidden = Solo.hidden_ids(d, s) if st.solo else {}
		st.active = st.rules or st.solo
		st.darken = ClipFilter.darken_on(st.view)
		st.shown = {}
		st.track_any = {}
	return st


static func role_cached(st: State, item: MediaItem, t: Track, c: Clip) -> String:
	if ClipFilter.ROLES.has(c.role):
		return c.role
	var key: String = (item.label + "|" + str(item.duration) if item != null else "|") + "|" + t.label + "|" + t.role + "|" + str(ClipFilter.stream_of(c)) + "|" + (str(c.duration) if item == null or item.duration <= 0.0 else "")
	if st.roles.has(key):
		return String(st.roles[key])
	var r: String = ClipFilter.derived_role(item, t, c)
	st.roles[key] = r
	return r


static func shown_in(st: State, d: Project, t: Track, c: Clip) -> bool:
	if not st.active:
		return true
	var v: Variant = st.shown.get(c, null)
	if v != null:
		return bool(v)
	var ok: bool = not (st.solo and st.solo_hidden.has(c.id))
	if ok and st.rules:
		var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
		var m: ClipFilter.Matcher = st.matcher
		var role: String = role_cached(st, item, t, c) if ClipFilter.wants_role(m) and t.is_sound(c) else ""
		ok = ClipFilter.matches(m, item, t, c, role)
	st.shown[c] = ok
	return ok


static func is_shown(canvas: Control, c: Clip) -> bool:
	var st: State = state(canvas)
	if not st.active or c == null:
		return true
	var s: Sequence = _seq(canvas)
	var t: Track = s.track_of(c.id) if s != null else null
	return t == null or shown_in(st, _doc(canvas), t, c)


static func track_has_match(st: State, d: Project, t: Track) -> bool:
	var v: Variant = st.track_any.get(t, null)
	if v != null:
		return bool(v)
	var any: bool = false
	for c: Clip in t.clips:
		if shown_in(st, d, t, c):
			any = true
			break
	st.track_any[t] = any
	return any


static func _per_paint(st: State, canvas: Control, s: Sequence) -> void:
	var pc: int = int(canvas.get("paint_count"))
	if st.paint == pc:
		return
	st.paint = pc
	st.ghosts = 0
	st.veils = 0
	st.sel = {}
	st.sel_tracks = {}
	for id: String in s.selected_clip_ids:
		st.sel[id] = true
		if st.darken:
			var tr: Track = s.track_of(id)
			if tr != null:
				st.sel_tracks[tr] = true
	st.moving = {}
	var dr: Object = canvas.get("drag")
	if dr != null and String(dr.get("mode")) == "move" and bool(dr.get("active")):
		for id: String in (dr.get("ids") as PackedStringArray):
			st.moving[id] = true
	st.font = canvas.get("_font")
	st.fs = int(canvas.get("_fs_small"))
	st.header_w = float(canvas.get("header_w"))
	st.pps = float(canvas.get("pps"))
	st.scroll_x = float(canvas.get("scroll_x"))
	st.fold = canvas.call("fold") if canvas.has_method("fold") else {}
	st.width = canvas.size.x


static func bright_track(s: Sequence, t: Track) -> bool:
	return t.locked or s.selected_track_ids.has(t.id)


static func begin_lane(canvas: Control, d: Project, s: Sequence, l: Dictionary, lane_rect: Rect2, lane_y: float, lane_h: float) -> State:
	if s == null:
		return null
	if s.track_view.is_empty():
		if canvas.has_meta(META):
			var idle: State = canvas.get_meta(META)
			idle.ghosts = 0
			idle.veils = 0
			idle.lane_veil = false
			idle.lane_out = false
			idle.pending.clear()
		return null
	var st: State = state_for(canvas, d, s)
	if not st.active and not st.darken:
		st.ghosts = 0
		st.veils = 0
		return null
	if bool(l.get("nest", false)):
		return null
	_per_paint(st, canvas, s)
	var t: Track = l["track"]
	st.pending.clear()
	st.lane_done = false
	st.lane_out = false
	st.lane_rect = lane_rect
	st.lane_dark = st.darken and not bright_track(s, t)
	st.lane_veil = st.lane_dark and not st.sel_tracks.has(t)
	if st.lane_dark and not st.lane_veil:
		canvas.draw_rect(lane_rect, Tk.c["veil"], true)
		st.veils += 1
	if cheap and st.active and st.moving.is_empty() and not track_has_match(st, d, t):
		var count: int = t.index_of_last_starting_before(Fold.t_of(st.fold, st.width, st.header_w, st.pps, st.scroll_x)) - t.index_of_first_visible(Fold.t_of(st.fold, st.header_w, st.header_w, st.pps, st.scroll_x)) + 1
		if Far.dense(canvas, count, Far.DENSE_DEFAULT):
			st.lane_out = true
		else:
			_ghost_lane(st, canvas, d, t, lane_y, lane_h)
			st.lane_done = true
	return st


static func _ghost_lane(st: State, canvas: Control, d: Project, t: Track, lane_y: float, lane_h: float) -> void:
	var t0: float = Fold.t_of(st.fold, st.header_w, st.header_w, st.pps, st.scroll_x)
	var t1: float = Fold.t_of(st.fold, st.width, st.header_w, st.pps, st.scroll_x)
	var i: int = t.index_of_first_visible(t0)
	var j: int = t.index_of_last_starting_before(t1)
	var last_x: float = -INF
	for idx: int in range(i, j + 1):
		var c: Clip = t.clips[idx]
		var x0: float = Fold.x_of(st.fold, c.start, st.header_w, st.pps, st.scroll_x)
		var x1: float = Fold.x_of(st.fold, c.end(), st.header_w, st.pps, st.scroll_x)
		if x1 <= st.header_w or x0 >= st.width or x1 <= last_x + 1.0:
			continue
		var r: Rect2 = Rect2(maxf(x0, st.header_w), lane_y + 1.0, minf(x1, st.width) - maxf(x0, st.header_w), lane_h - 2.0)
		r.size.x = maxf(r.size.x, 1.0)
		ghost(st, canvas, d, t, c, r)
		last_x = maxf(last_x, x1)


static func ghost(st: State, canvas: Control, d: Project, t: Track, c: Clip, r: Rect2) -> void:
	var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var bg: Color = Tk.c["bg_lane_video"]
	canvas.draw_rect(r, Paint.clip_colour(c, item, t).lerp(bg, GHOST_MIX), true)
	if r.size.x >= 4.0:
		canvas.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
	st.ghosts += 1
	if r.size.x < NAME_MIN_W or st.font == null or r.size.y < st.font.get_height(st.fs) + 2.0:
		return
	var row: Rect2 = Rect2(r.position.x, r.position.y, r.size.x, minf(r.size.y, st.font.get_height(st.fs) + 4.0))
	var pad: float = PmText.pad()
	PmText.draw_in(canvas, st.font, Rect2(r.position.x + pad, row.position.y, r.size.x - pad * 2.0, row.size.y), StreamRoles.shown_label(item, c, t.is_sound(c)), st.fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, r.position.y + 2.0 + st.font.get_ascent(st.fs), PmText.ELIDE, row)


static func skip(st: State, canvas: Control, t: Track, c: Clip, r: Rect2) -> bool:
	if st.lane_out or st.moving.has(c.id):
		return false
	if st.active and not shown_in(st, _doc(canvas), t, c):
		if not cheap:
			st.pending.append(r)
			return false
		ghost(st, canvas, _doc(canvas), t, c, r)
		return true
	if st.lane_dark and not st.lane_veil and not st.sel.has(c.id):
		st.pending.append(r)
	return false


static func after_lane(canvas: Control, l: Dictionary, region: Rect2, set_scroll: float) -> void:
	if Track.listen_seen or Clip.listen_seen:
		draw_listen(canvas, l, region, set_scroll)
	var st: State = canvas.get_meta(META) if canvas.has_meta(META) else null
	if st == null or (not st.darken and st.pending.is_empty() and not st.lane_out):
		if st != null:
			st.lane_veil = false
		return
	if st.lane_out:
		var bg: Color = Tk.c["bg_lane_video"]
		canvas.draw_rect(st.lane_rect, Color(bg.r, bg.g, bg.b, GHOST_MIX), true)
		st.ghosts += 1
		st.lane_out = false
	if st.lane_veil:
		canvas.draw_rect(st.lane_rect, Tk.c["veil"], true)
		st.veils += 1
	for r: Rect2 in st.pending:
		canvas.draw_rect(r, Tk.c["veil"], true)
		st.veils += 1
	st.pending.clear()
	st.lane_veil = false
	st.lane_dark = false


static func listen_colour() -> Color:
	var a: Color = Tk.c["accent"]
	return Color(a.r, a.g, a.b, 0.55)


static func draw_listen(canvas: Control, l: Dictionary, region: Rect2, set_scroll: float) -> void:
	if bool(l.get("nest", false)):
		return
	var t: Track = l["track"]
	var lane_y: float = region.position.y + float(l["y"]) - set_scroll
	var lane_h: float = float(l["h"])
	if lane_y + lane_h < region.position.y or lane_y > region.end.y:
		return
	var hw: float = float(canvas.get("header_w"))
	var vis: Rect2 = Rect2(hw, maxf(lane_y, region.position.y), canvas.size.x - hw, minf(lane_y + lane_h, region.end.y) - maxf(lane_y, region.position.y))
	if t.listen_muted:
		Paint.hatch(canvas, vis, listen_colour(), LISTEN_HATCH)
		var font: Font = canvas.get("_font")
		var fs: int = int(canvas.get("_fs_small"))
		if font != null and lane_h >= font.get_height(fs) + 4.0:
			var w: float = PmText.width_of(font, LISTEN_TEXT, fs) + PmText.pad() * 2.0
			var chip: Rect2 = Rect2(canvas.size.x - w - 14.0, lane_y + 2.0, w, font.get_height(fs) + 2.0)
			canvas.draw_rect(chip, Tk.c["bg_panel"], true)
			PmText.draw_in(canvas, font, chip, LISTEN_TEXT, fs, Tk.c["accent"], HORIZONTAL_ALIGNMENT_CENTER, chip.position.y + 1.0 + font.get_ascent(fs), PmText.WHOLE, chip)
	if not Clip.listen_seen:
		return
	var pps: float = float(canvas.get("pps"))
	var sx: float = float(canvas.get("scroll_x"))
	var lf: Dictionary = canvas.call("fold") if canvas.has_method("fold") else {}
	var t0: float = Fold.t_of(lf, hw, hw, pps, sx)
	var t1: float = Fold.t_of(lf, canvas.size.x, hw, pps, sx)
	var i: int = t.index_of_first_visible(t0)
	while i < t.clips.size() and t.clips[i].start < t1:
		var c: Clip = t.clips[i]
		i += 1
		if not c.listen_muted:
			continue
		var x0: float = maxf(Fold.x_of(lf, c.start, hw, pps, sx), hw)
		var x1: float = minf(Fold.x_of(lf, c.end(), hw, pps, sx), canvas.size.x)
		if x1 <= x0:
			continue
		var r: Rect2 = Rect2(x0, lane_y + 1.0, x1 - x0, lane_h - 2.0).intersection(vis)
		Paint.hatch(canvas, r, listen_colour(), LISTEN_HATCH)
		canvas.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["accent"], false, 1.0)


static func set_listen_track(canvas: Control, track_id: String, on: bool) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	var t: Track = s.track_by_id(track_id) if s != null else null
	if d == null or t == null or not t.makes_sound() or t.listen_muted == on:
		return false
	return Verbs.run(d, "Listen mute " + ("on" if on else "off"), [TrackCmds.SetTrackField.new(s.id, track_id, "listen_muted", on)])


static func set_listen_clips(canvas: Control, ids: PackedStringArray, on: bool) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id)
		if c != null and t != null and t.is_sound(c) and c.listen_muted != on:
			cmds.append(ClipCmds.SetClipField.new(s.id, id, "listen_muted", on))
	return Verbs.run(d, "Listen mute " + ("on" if on else "off"), cmds)


static func set_track_role(canvas: Control, track_id: String, role: String) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	var t: Track = s.track_by_id(track_id) if s != null else null
	var r: String = role if ClipFilter.ROLES.has(role) else ""
	if d == null or t == null or t.role == r:
		return false
	return Verbs.run(d, "Track sound role", [TrackCmds.SetTrackField.new(s.id, track_id, "role", r)])


static func hit(canvas: Control, h: Dictionary) -> Dictionary:
	var c: Clip = h.get("clip", null)
	if c == null or not pass_clicks or String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)):
		return h
	var s: Sequence = _seq(canvas)
	if s == null or s.track_view.is_empty():
		return h
	var d: Project = _doc(canvas)
	var st: State = state_for(canvas, d, s)
	if not st.active:
		return h
	var t: Track = h.get("track", null)
	if t == null or shown_in(st, d, t, c):
		return h
	h["clip"] = null
	h["edge"] = ""
	h["fade"] = ""
	h["level"] = false
	h["transition"] = false
	h["tr_edge"] = ""
	var at: float = float(h.get("t", 0.0))
	var under: Array[Clip] = t.clips_at(at)
	for k: int in range(under.size() - 1, -1, -1):
		var o: Clip = under[k]
		if o != c and shown_in(st, d, t, o):
			h["clip"] = o
			var x: float = float(h.get("x", 0.0))
			var x0: float = float(canvas.call("x_of", o.start))
			var x1: float = float(canvas.call("x_of", o.end()))
			var reach: float = minf(EDGE_REACH, (x1 - x0) * 0.3)
			if x - x0 <= reach:
				h["edge"] = "head"
			elif x1 - x <= reach:
				h["edge"] = "tail"
			break
	return h


static func keep_shown(canvas: Control, ids: PackedStringArray) -> PackedStringArray:
	var s: Sequence = _seq(canvas)
	if s == null or s.track_view.is_empty():
		return ids
	var d: Project = _doc(canvas)
	var st: State = state_for(canvas, d, s)
	if not st.active:
		return ids
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var t: Track = s.track_of(id)
		var c: Clip = s.clip_by_id(id)
		if t != null and c != null and shown_in(st, d, t, c):
			out.append(id)
	return out


static func set_view(canvas: Control, view: Dictionary, label: String) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	if d == null or s == null:
		return false
	var done: bool = Verbs.run(d, label, [Solo.SetView.new(s.id, Solo.with_solo_into(s, view), label)])
	if done and canvas.has_method("_notify_toolbar"):
		canvas.call("_notify_toolbar")
	canvas.queue_redraw()
	return done


static func move_targets(s: Sequence, prefix: String) -> Array:
	var items: Array = []
	for t: Track in s.top_down_tracks():
		var it: Dictionary = PmMenu.item(prefix + t.id, s.display_label(t) + (" (locked)" if t.locked else ""))
		if t.locked:
			it["disabled"] = true
		items.append(it)
	items.append(PmMenu.separator())
	items.append(PmMenu.item(prefix + NEW_VIDEO, "A new video track"))
	items.append(PmMenu.item(prefix + NEW_AUDIO, "A new audio track"))
	return items


static func menu_items(canvas: Control) -> Array:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	if s == null:
		return []
	var view: Dictionary = view_of(s)
	var rules: bool = ClipFilter.has_rules(view)
	var items: Array = []
	var on: Dictionary = PmMenu.check_item("on", "Filter on: " + ClipFilter.summary(view), ClipFilter.is_active(view))
	if not rules:
		on["disabled"] = true
	items.append(on)
	items.append(PmMenu.separator())
	var kinds: Array = []
	var chosen: Array = view.get(ClipFilter.K_KINDS, [])
	for e: Array in ClipFilter.KINDS:
		kinds.append(PmMenu.check_item("kind:" + String(e[0]), String(e[2]), chosen.has(String(e[0]))))
	items.append(PmMenu.sub_item("kinds", "Show only these kinds", kinds))
	var cols: Array = []
	var picked: Array = view.get(ClipFilter.K_COLOURS, [])
	cols.append(PmMenu.check_item("colour:-1", "No label colour", picked.has(-1)))
	for i: int in Tk.LABEL_NAMES.size():
		cols.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), picked.has(i)))
	items.append(PmMenu.sub_item("colours", "Show only these label colours", cols))
	var text: String = str(view.get(ClipFilter.K_TEXT, ""))
	items.append(PmMenu.item("text", "Name contains..." if text.is_empty() else "Name contains \"" + text + "\"..."))
	var tag_items: Array = []
	var tag_on: Array = view.get(ClipFilter.K_TAGS, [])
	for n: String in Tags.names(s):
		tag_items.append(PmMenu.check_item("tag:" + n, n, tag_on.has(n)))
	if tag_items.is_empty():
		var none: Dictionary = PmMenu.item("no_tags", "No tags in this sequence")
		none["disabled"] = true
		tag_items.append(none)
	items.append(PmMenu.sub_item("tags", "Show only clips under these tags", tag_items))
	var clear: Dictionary = PmMenu.item("clear", "Clear the filter")
	if not rules:
		clear["disabled"] = true
	items.append(clear)
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("darken", "Darken all but locked and selected", ClipFilter.darken_on(view)))
	items.append(PmMenu.separator())
	items.append_array(Solo.menu_items(s, Solo.overlap_count(d, s)))
	items.append(PmMenu.separator())
	var sel_matching: Dictionary = PmMenu.item("select_matching", "Select the matching clips")
	var mv: Dictionary = PmMenu.sub_item("move_matching", "Move the matching clips to", move_targets(s, "fmove:"))
	if not ClipFilter.is_active(view):
		sel_matching["disabled"] = true
		mv["disabled"] = true
	items.append(sel_matching)
	items.append(mv)
	var mvs: Dictionary = PmMenu.sub_item("move_selection", "Move the selection to", move_targets(s, "smove:"))
	if Verbs.selection(s).is_empty():
		mvs["disabled"] = true
	items.append(mvs)
	if d == null:
		return items
	return items


static func open_menu(canvas: Control, anchor: Control) -> void:
	if anchor is Button:
		sync_button(anchor as Button, canvas)
	var m: Control = PmMenu.open(anchor, menu_items(canvas))
	if m != null and m.is_inside_tree():
		m.connect("picked", on_menu.bind(canvas))


static func on_menu(id: String, canvas: Control) -> bool:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	if s == null or d == null:
		return false
	var view: Dictionary = view_of(s)
	if Solo.on_menu(d, s, id):
		canvas.queue_redraw()
		if canvas.has_method("_notify_toolbar"):
			canvas.call("_notify_toolbar")
		return true
	if id == "on":
		return set_view(canvas, ClipFilter.with(view, ClipFilter.K_ON, not ClipFilter.is_active(view)), "Filter " + ("off" if ClipFilter.is_active(view) else "on"))
	if id.begins_with("kind:"):
		return set_view(canvas, ClipFilter.toggled_in(view, ClipFilter.K_KINDS, id.substr(5)), "Filter by kind")
	if id.begins_with("colour:"):
		return set_view(canvas, ClipFilter.toggled_in(view, ClipFilter.K_COLOURS, int(id.substr(7))), "Filter by label colour")
	if id.begins_with("tag:"):
		return set_view(canvas, ClipFilter.toggled_in(view, ClipFilter.K_TAGS, id.substr(4)), "Filter by tag")
	if id == "text":
		var fields: Array[Dictionary] = [{"key": "text", "label": "Name contains", "type": "string", "default": str(view.get(ClipFilter.K_TEXT, ""))}]
		var answered: Signal = PmUI.form(canvas, "Filter by name", fields, "Filter", "Cancel")
		answered.connect(_on_text_answered.bind(canvas))
		return true
	if id == "clear":
		return set_view(canvas, ClipFilter.cleared_rules(view), "Clear the filter")
	if id == "darken":
		return set_view(canvas, ClipFilter.with(view, ClipFilter.K_DARKEN, null if ClipFilter.darken_on(view) else true), "Darken view " + ("off" if ClipFilter.darken_on(view) else "on"))
	if id == "select_matching":
		return Verbs.select(d, s, ClipFilter.matching_ids(d, s, view), "replace")
	if id.begins_with("fmove:"):
		return ask_move(canvas, ClipFilter.matching_ids(d, s, view), id.substr(6))
	if id.begins_with("smove:"):
		return ask_move(canvas, Verbs.selection(s), id.substr(6))
	return false


static func _on_text_answered(result: Variant, canvas: Control) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var s: Sequence = _seq(canvas)
	if s == null:
		return
	var text: String = String((result as Dictionary).get("text", "")).strip_edges()
	set_view(canvas, ClipFilter.with(view_of(s), ClipFilter.K_TEXT, text if not text.is_empty() else null), "Filter by name")


static func partners_outside(s: Sequence, ids: PackedStringArray, target: String) -> int:
	var wanted: Dictionary = {}
	var links: Dictionary = {}
	for id: String in ids:
		wanted[id] = true
		var c: Clip = s.clip_by_id(id)
		if c != null and not c.link_id.is_empty():
			links[c.link_id] = true
	if links.is_empty():
		return 0
	var tr: Track = s.track_by_id(target) if not target.begins_with("new:") else null
	var kind: String = tr.kind if tr != null else target.substr(4)
	var n: int = 0
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			if links.has(c.link_id) and not wanted.has(c.id) and ((tr != null and tr.accepts(t.clip_kind(c))) or (tr == null and t.clip_kind(c) == kind)):
				n += 1
	return n


static func ask_move(canvas: Control, ids: PackedStringArray, target: String) -> bool:
	var s: Sequence = _seq(canvas)
	if s == null or ids.is_empty():
		return false
	var outside: int = partners_outside(s, ids, target)
	if outside == 0:
		return move(canvas, ids, target, false)
	var fields: Array[Dictionary] = [{"key": "partners", "label": "Also move their " + str(outside) + " linked clips this track can take", "type": "bool", "default": false}]
	var answered: Signal = PmUI.form(canvas, "Move to track", fields, "Move", "Cancel")
	answered.connect(_on_move_answered.bind(canvas, ids, target))
	return true


static func _on_move_answered(result: Variant, canvas: Control, ids: PackedStringArray, target: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	move(canvas, ids, target, bool((result as Dictionary).get("partners", false)))


static func role_track_name(view: Dictionary) -> String:
	var kinds: Array = view.get(ClipFilter.K_KINDS, [])
	if kinds.size() != 1:
		return ""
	var k: String = String(kinds[0])
	if k == "sfx":
		return "SFX"
	if k == "music" or k == "voice" or k == "titles":
		return k.capitalize()
	return ""


static func move(canvas: Control, ids: PackedStringArray, target: String, partners: bool) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	if d == null or s == null or ids.is_empty():
		return false
	var cmd: ViewCmds.MoveToTrack = null
	if target.begins_with("new:"):
		cmd = ViewCmds.MoveToTrack.new(s.id, ids, "", target.substr(4), role_track_name(view_of(s)), partners)
	else:
		cmd = ViewCmds.MoveToTrack.new(s.id, ids, target, "", "", partners)
	var done: bool = Verbs.run(d, "Move to track", [cmd])
	var note: String = ""
	if done:
		note = "Moved " + ClipFilter.counted(cmd.moved, "clip", "clips")
		if cmd.new_tracks.size() > 0:
			note += ", " + ClipFilter.counted(cmd.new_tracks.size(), "new track", "new tracks")
		if cmd.stacked > 0:
			note += ", " + str(cmd.stacked) + " stacked over others"
		if cmd.skipped_kind > 0:
			note += ", " + str(cmd.skipped_kind) + " of another kind stayed put"
		if cmd.skipped_locked > 0:
			note += ", " + str(cmd.skipped_locked) + " locked stayed put"
	else:
		note = cmd.refusal if not cmd.refusal.is_empty() else "Nothing was moved"
	_say(note)
	return done


static func clear_track(canvas: Control, track_id: String) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	if d == null or s == null:
		return false
	var cmd: ViewCmds.ClearTrack = ViewCmds.ClearTrack.new(s.id, track_id)
	var done: bool = Verbs.run(d, "Clear track", [cmd])
	if not done or not cmd.refusal.is_empty():
		_say(cmd.refusal if not cmd.refusal.is_empty() else "Nothing was cleared")
	return done


static func set_role(canvas: Control, role: String) -> bool:
	var d: Project = _doc(canvas)
	var s: Sequence = _seq(canvas)
	if d == null or s == null:
		return false
	var ids: PackedStringArray = PackedStringArray()
	for id: String in Verbs.selection(s):
		var t: Track = s.track_of(id)
		if t != null and t.is_sound(s.clip_by_id(id)):
			ids.append(id)
	if ids.is_empty():
		_say("Select sound clips to give them a role")
		return false
	return Verbs.run(d, "Sound role", [ViewCmds.SetClipRole.new(s.id, ids, role)])


static func _say(text: String) -> void:
	last_note = text
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var ev: Node = tree.root.get_node_or_null("/root/Events") if tree != null else null
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)


static func clip_menu_items(canvas: Control, c: Clip) -> Array:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	var items: Array = []
	if s == null or c == null:
		return items
	var t: Track = s.track_of(c.id)
	if t != null and t.is_sound(c):
		var worked: String = ClipFilter.derived_role(d.media_by_id(c.media_id) if d != null else null, t, c)
		var sub: Array = [PmMenu.check_item("frole:auto", "Work it out (" + String(ClipFilter.ROLE_NAMES[worked]) + ")", c.role.is_empty())]
		for r: String in ClipFilter.ROLES:
			sub.append(PmMenu.check_item("frole:" + r, String(ClipFilter.ROLE_NAMES[r]), c.role == r))
		items.append(PmMenu.sub_item("frole", "Sound role", sub))
		items.append(PmMenu.check_item("flisten", "Listen mute, playback only, never exports", c.listen_muted))
	items.append(PmMenu.sub_item("fmove", "Move to track", move_targets(s, "cmove:")))
	return items


static func on_clip_menu(canvas: Control, id: String, clip_id: String) -> bool:
	if id.begins_with("frole:"):
		var r: String = id.substr(6)
		set_role(canvas, "" if r == "auto" else r)
		return true
	if id.begins_with("cmove:"):
		var s: Sequence = _seq(canvas)
		if s != null:
			ask_move(canvas, Verbs.selection(s), id.substr(6))
		return true
	if id == "flisten":
		var s2: Sequence = _seq(canvas)
		var c: Clip = s2.clip_by_id(clip_id) if s2 != null else null
		if c != null:
			set_listen_clips(canvas, Verbs.selection(s2) if s2.selected_clip_ids.has(clip_id) else PackedStringArray([clip_id]), not c.listen_muted)
		return true
	return false


static func header_items(canvas: Control, t: Track) -> Array:
	var items: Array = [PmMenu.separator()]
	if t.makes_sound():
		var sub: Array = [PmMenu.check_item("trole:auto", "None, work it out per clip", t.role.is_empty())]
		for r: String in ClipFilter.ROLES:
			sub.append(PmMenu.check_item("trole:" + r, String(ClipFilter.ROLE_NAMES[r]), t.role == r))
		items.append(PmMenu.sub_item("trole", "Sound role for this track", sub))
		items.append(PmMenu.check_item("tlisten", "Listen mute, playback only, never exports", t.listen_muted))
	var clear: Dictionary = PmMenu.item("fclear", "Clear every clip on this track", "", "trash")
	if t.locked or t.clips.is_empty():
		clear["disabled"] = true
	items.append(clear)
	var s: Sequence = _seq(canvas)
	if s != null and ClipFilter.is_active(view_of(s)) and not t.locked:
		items.append(PmMenu.item("fhere", "Move the matching clips here"))
	return items


static func on_header_menu(canvas: Control, id: String, track_id: String) -> bool:
	if id == "fclear":
		clear_track(canvas, track_id)
		return true
	if id.begins_with("trole:"):
		var r: String = id.substr(6)
		set_track_role(canvas, track_id, "" if r == "auto" else r)
		return true
	if id == "tlisten":
		var s0: Sequence = _seq(canvas)
		var t0: Track = s0.track_by_id(track_id) if s0 != null else null
		if t0 != null:
			set_listen_track(canvas, track_id, not t0.listen_muted)
		return true
	if id == "fhere":
		var s: Sequence = _seq(canvas)
		var d: Project = _doc(canvas)
		if s != null and d != null:
			ask_move(canvas, ClipFilter.matching_ids(d, s, view_of(s)), track_id)
		return true
	return false


static func sync_button(b: Button, canvas: Control) -> void:
	if b == null or canvas == null:
		return
	var s: Sequence = _seq(canvas)
	var view: Dictionary = view_of(s)
	var soloing: bool = Solo.is_on(s)
	b.button_pressed = ClipFilter.is_active(view) or ClipFilter.darken_on(view) or soloing
	var tip: String = "Timeline view: " + (ClipFilter.summary(view) if ClipFilter.is_active(view) else "no filter")
	if soloing:
		tip += ", soloing " + Solo.view_name(s)
	if ClipFilter.darken_on(view):
		tip += ", darkened"
	PmUI.tip(b, tip)
