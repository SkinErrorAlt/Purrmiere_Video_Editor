extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const MarkerLayers := preload("res://doc/marker_layers.gd")
const MarkerLanes := preload("res://ui/timeline/timeline_marker_lanes.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const SpeedCmds := preload("res://doc/commands/speed_cmds.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const FadeTools := preload("res://doc/commands/edit_tools.gd")
const Stacks := preload("res://ui/timeline/timeline_stacks.gd")
const TrTiming := preload("res://doc/transition_timing.gd")
const TR_SNAP_PX := 8.0
const CensorTool := preload("res://ui/timeline/timeline_censor.gd")
const ViewCuts := preload("res://ui/timeline/timeline_view_cuts.gd")
const Marquee := preload("res://ui/timeline/timeline_marquee.gd")
const Keys := preload("res://ui/timeline/timeline_keys.gd")
const RealignTool := preload("res://ui/timeline/timeline_realign.gd")
const SpeedBand := preload("res://ui/timeline/timeline_speed_band.gd")
const TrackerBand := preload("res://ui/timeline/timeline_tracker_band.gd")
const SLOP := 4.0
const SNAP_PX := 8.0
const IMMEDIATE: PackedStringArray = ["scrub", "header_w", "track_h", "divider", "pan", "band_scroll", "hscroll"]
const MOVING: PackedStringArray = ["move", "trim", "ripple", "rate", "roll", "slip", "slide", "range", "marker", "marker_len", "marker_range", "level", "band_reorder"]

var host: Control = null
var mode: String = ""
var active: bool = false
var press: Vector2 = Vector2.ZERO
var last: Vector2 = Vector2.ZERO
var clip_id: String = ""
var track_id: String = ""
var side: String = ""
var tr_field: String = "transition_in"
var set_name: String = ""
var origin: Dictionary = {}
var delta_t: float = 0.0
var track_delta: int = 0
var mods: Dictionary = {}
var ripple: bool = false
var solo_trim: bool = false
var insert: bool = false
var duplicate: bool = false
var edit_t: float = 0.0
var snap_targets: PackedFloat64Array = PackedFloat64Array()
var snap_x: float = -INF
var marquee: Rect2 = Rect2()
var live_key: String = ""
var value_a: float = 0.0
var value_b: float = 0.0
var marker_id: String = ""
var scrub_t: float = -1.0
var ids: PackedStringArray = PackedStringArray()
var doomed: Array[Rect2] = []
var changed_serial: int = 0


func clear() -> void:
	mode = ""
	active = false
	press = Vector2.ZERO
	last = Vector2.ZERO
	clip_id = ""
	track_id = ""
	side = ""
	set_name = ""
	origin = {}
	delta_t = 0.0
	track_delta = 0
	mods = {}
	ripple = false
	insert = false
	duplicate = false
	edit_t = 0.0
	snap_targets = PackedFloat64Array()
	snap_x = -INF
	marquee = Rect2()
	live_key = ""
	value_a = 0.0
	value_b = 0.0
	marker_id = ""
	scrub_t = -1.0
	ids = PackedStringArray()
	doomed = []


func is_clear() -> bool:
	return mode.is_empty() and not active and clip_id.is_empty() and track_id.is_empty() and side.is_empty() and origin.is_empty() and delta_t == 0.0 and track_delta == 0 and mods.is_empty() and not ripple and not insert and not duplicate and snap_targets.is_empty() and snap_x == -INF and marquee == Rect2() and live_key.is_empty() and marker_id.is_empty() and scrub_t < 0.0 and ids.is_empty() and doomed.is_empty() and value_a == 0.0 and value_b == 0.0 and edit_t == 0.0


func state() -> Dictionary:
	return {"mode": mode, "active": active, "clip_id": clip_id, "track_id": track_id, "side": side, "delta_t": delta_t, "track_delta": track_delta, "ripple": ripple, "insert": insert, "duplicate": duplicate, "snap_x": snap_x, "marquee": marquee, "ids": ids, "scrub_t": scrub_t}


func in_progress() -> bool:
	return not mode.is_empty()


func _doc() -> Project:
	return host.call("doc")


func _seq() -> Sequence:
	return host.call("seq")


func _pps() -> float:
	return float(host.get("pps"))


func _t_of(x: float) -> float:
	return float(host.call("t_of", x))


func _x_of(t: float) -> float:
	return float(host.call("x_of", t))


static func mods_of(event: InputEventWithModifiers) -> Dictionary:
	return {"ctrl": event.ctrl_pressed or event.meta_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed}


func begin(kind: String, hit: Dictionary, pos: Vector2, mods_: Dictionary) -> void:
	clear()
	mode = kind
	press = pos
	last = pos
	mods = mods_.duplicate()
	set_name = String(hit.get("set", ""))
	var c: Clip = hit.get("clip", null)
	var t: Track = hit.get("track", null)
	if c != null:
		clip_id = c.id
	if t != null:
		track_id = t.id
	side = String(hit.get("edge", ""))
	tr_field = TrTiming.OUT_FIELD if String(hit.get("tr_side", "")) == "out" else TrTiming.IN_FIELD
	var m: Marker = hit.get("marker", null)
	if m != null:
		marker_id = m.id
		origin["time"] = m.time
	if kind == "marker_len":
		side = String(hit.get("marker_edge", "tail"))
		if side.is_empty():
			side = "tail"
	if kind in IMMEDIATE:
		active = true
	if kind == "scrub":
		scrub_t = ViewCuts.snap_scrub(self, host, maxf(_t_of(pos.x), 0.0))
	_capture_origin()
	if kind == "scrub" and host.has_method("scrub_pressed"):
		host.call("scrub_pressed")
	if kind == "range":
		origin["anchor"] = Marquee.anchor_at(host.call("geometry"), pos, hit, mods_)


func _capture_origin() -> void:
	var seq: Sequence = _seq()
	if seq == null:
		return
	origin["playhead"] = seq.playhead
	origin["header_w"] = float(host.get("header_w"))
	origin["band_h"] = float(host.call("band_height"))
	origin["scroll_x"] = float(host.get("scroll_x"))
	origin["band_scroll_y"] = float(host.get("band_scroll_y"))
	origin["scroll_y"] = float(host.get("scroll_y"))
	if not marker_id.is_empty():
		_capture_markers(seq)
	if not track_id.is_empty():
		var tr: Track = seq.track_by_id(track_id)
		if tr != null:
			origin["track_h"] = float(host.call("lane_height_of", track_id))
	var c: Clip = seq.clip_by_id(clip_id) if not clip_id.is_empty() else null
	if c != null:
		origin["start"] = c.start
		origin["end"] = c.end()
		origin["duration"] = c.duration
		origin["in_offset"] = c.in_offset
		origin["speed"] = c.static_speed() if c.static_speed() != 0.0 else 1.0
		var vol: Dictionary = c.audio.get("volume", AnimProp.make(1.0))
		origin["volume"] = AnimProp.evaluate_float(vol, c.param_time("audio.volume", maxf(seq.playhead - c.start, 0.0)), c.duration)
		if mode == "move":
			var family: PackedStringArray = Verbs.unlocked(seq, Verbs.MoveRule.drag_ids(seq, c.id, bool(host.get("linked_selection"))))
			if not family.has(c.id):
				family = PackedStringArray([c.id])
			ids = family
			var starts: Dictionary = {}
			for id: String in ids:
				var f: Clip = seq.clip_by_id(id)
				starts[id] = f.start
			origin["starts"] = starts
	if mode == "roll":
		edit_t = c.start if side == "head" else c.end()
	if mode == "transition" and c != null:
		var out_side: bool = tr_field == TrTiming.OUT_FIELD
		var span: Vector2 = c.transition_out_span() if out_side else c.transition_span()
		origin["w0"] = span.x
		origin["w1"] = span.y
		origin["cut"] = c.end() if out_side else c.start
		origin["transition"] = c.transition_field(tr_field).duplicate(true)
		var lim: Vector2 = TrTiming.limits(host.call("doc") if host.has_method("doc") else null, seq, c, tr_field)
		origin["lo"] = lim.x
		origin["hi"] = lim.y


func marker_selection() -> PackedStringArray:
	if host == null or not ("selected_marker_ids" in host):
		return PackedStringArray()
	return (host.get("selected_marker_ids") as PackedStringArray).duplicate()


func _capture_markers(seq: Sequence) -> void:
	var mk: Marker = seq.marker_by_id(marker_id)
	if mk == null:
		return
	origin["time"] = mk.time
	origin["duration"] = mk.duration
	origin["end"] = mk.end()
	if mode != "marker":
		return
	var sel: PackedStringArray = marker_selection()
	ids = sel if sel.has(marker_id) else PackedStringArray([marker_id])
	var times: Dictionary = {}
	for id: String in ids:
		var other: Marker = seq.marker_by_id(id)
		if other != null:
			times[id] = other.time
	origin["times"] = times


func _open() -> void:
	active = true
	var seq: Sequence = _seq()
	if seq == null:
		return
	var exclude: PackedStringArray = PackedStringArray()
	if mode == "move" or mode == "slide":
		exclude = ids if not ids.is_empty() else PackedStringArray([clip_id])
	elif mode == "trim" or mode == "ripple" or mode == "rate" or mode == "roll":
		exclude = PackedStringArray([clip_id])
	snap_targets = host.call("snap_targets", exclude)
	ripple = mode == "ripple"
	solo_trim = bool(mods.get("alt", false)) and (mode == "trim" or mode == "ripple")
	insert = bool(mods.get("ctrl", false)) and mode == "move"
	duplicate = bool(mods.get("alt", false)) and mode == "move"
	if mode == "move":
		var doc: Project = _doc()
		if duplicate and not bool(host.get("linked_selection")):
			ids = Verbs.selection(seq) if seq.selected_clip_ids.has(clip_id) else PackedStringArray([clip_id])
		var starts: Dictionary = {}
		for id: String in ids:
			var f: Clip = seq.clip_by_id(id)
			if f != null:
				starts[id] = f.start
		origin["starts"] = starts
		if Verbs.MoveRule.needs_select(seq, clip_id):
			Verbs.select(doc, seq, ids if bool(host.get("linked_selection")) else PackedStringArray([clip_id]), "replace", PackedStringArray([clip_id]))


static func _prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_step_prefs() -> Node:
	var prefs: Node = _prefs_node()
	if prefs != null and not bool(prefs.call("is_registered", "edit.drag_step")):
		prefs.call("register", "edit.drag_step", "adaptive", {"label": "Drag steps on the timeline", "type": "enum", "choices": ["adaptive", "frame", "free"]})
		prefs.call("register", "edit.drag_step_px", 4, {"label": "Smallest drag step in pixels (adaptive)", "type": "int", "min": 1, "max": 24})
	return prefs


func quantum() -> float:
	var prefs: Node = register_step_prefs()
	var mode_: String = String(prefs.call("get_value", "edit.drag_step")) if prefs != null else "adaptive"
	if mode_ == "free":
		return 0.0
	var seq: Sequence = _seq()
	var fps: float = seq.fps if seq != null and seq.fps > 0.0 else 30.0
	var frame: float = 1.0 / fps
	if mode_ == "frame":
		return frame
	var min_px: float = float(maxi(1, int(prefs.call("get_value", "edit.drag_step_px")))) if prefs != null else 4.0
	var frames_per_step: float = ceil(min_px / maxf(_pps() * frame, 0.000001))
	var nice: Array = [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 150.0, 300.0, 600.0, 1800.0, 3600.0]
	for n: float in nice:
		if n >= frames_per_step:
			return frame * n
	return frame * frames_per_step


func quantise(t: float) -> float:
	var q: float = quantum()
	if q <= 0.0:
		return t
	return round(t / q) * q


func snap(t: float, extra_offsets: PackedFloat64Array = PackedFloat64Array()) -> float:
	snap_x = -INF
	if not bool(host.get("snapping")) or snap_targets.is_empty():
		return quantise(t)
	var reach: float = SNAP_PX / _pps()
	var best_d: float = reach
	var best: float = t
	var offsets: PackedFloat64Array = PackedFloat64Array([0.0])
	offsets.append_array(extra_offsets)
	for off: float in offsets:
		var probe: float = t + off
		var lo: int = 0
		var hi: int = snap_targets.size()
		while lo < hi:
			var mid: int = (lo + hi) >> 1
			if snap_targets[mid] < probe:
				lo = mid + 1
			else:
				hi = mid
		for i: int in [lo - 1, lo]:
			if i < 0 or i >= snap_targets.size():
				continue
			var d: float = absf(snap_targets[i] - probe)
			if d < best_d:
				best_d = d
				best = snap_targets[i] - off
				snap_x = _x_of(snap_targets[i])
	if snap_x == -INF:
		return quantise(best)
	return best


func motion(pos: Vector2, mods_: Dictionary) -> bool:
	if mode.is_empty():
		return false
	last = pos
	mods["shift"] = bool(mods_.get("shift", false))
	if not active:
		if (pos - slop_origin()).length() < float(Tk.px(SLOP)):
			return false
		_open()
	var seq: Sequence = _seq()
	var doc: Project = _doc()
	if seq == null or doc == null:
		return false
	if mode == MarkerLanes.DRAG_MODE:
		return MarkerLanes.drag_motion(host, self, pos, mods_)
	if mode == CensorTool.DRAG_MODE:
		return CensorTool.drag_motion(host, self, pos, mods_)
	if mode == Keys.DRAG_MODE:
		return Keys.drag_motion(host, self, pos, mods_)
	if mode == RealignTool.DRAG_MODE:
		return RealignTool.drag_motion(host, self, pos, mods_)
	if mode == SpeedBand.DRAG_MODE:
		return SpeedBand.drag_motion(host, self, pos, mods_)
	if mode == TrackerBand.DRAG_MODE:
		return TrackerBand.drag_motion(host, self, pos, mods_)
	if mode == "scrub":
		scrub_t = ViewCuts.snap_scrub(self, host, maxf(_t_of(pos.x), 0.0))
		return true
	if mode == "header_w":
		host.call("set_header_w", float(origin.get("header_w", 160.0)) + (pos.x - press.x))
		return true
	if mode == "divider":
		host.call("set_band_height_preview", float(origin.get("band_h", 180.0)) + (press.y - pos.y) * (1.0 if bool(host.call("band_at_bottom")) else -1.0))
		return true
	if mode == "track_h":
		host.call("set_track_height_preview", track_id, float(origin.get("track_h", 54.0)) + (pos.y - press.y))
		return true
	if mode == "pan":
		host.call("pan_by", press - pos, origin)
		return true
	if mode == "band_scroll":
		host.call("band_scroll_thumb", pos.y - press.y, origin)
		return true
	if mode == "hscroll":
		host.call("hscroll_thumb", pos.x - press.x, origin)
		return true
	if mode == "range":
		marquee = marquee_rect()
		return true
	if mode == "marker":
		var mt: float = snap(maxf(float(origin.get("time", 0.0)) + (pos.x - press.x) / _pps(), 0.0))
		var times: Dictionary = origin.get("times", {})
		var shift: float = mt - float(origin.get("time", 0.0))
		var lowest: float = INF
		for id: String in ids:
			lowest = minf(lowest, float(times.get(id, 0.0)))
		if lowest < INF and lowest + shift < 0.0:
			shift = -lowest
		delta_t = shift
		if ids.is_empty():
			doc.undo.live(MarkerCmds.SetMarker.new(seq.id, "", marker_id, {"time": maxf(mt, 0.0)}))
		for id: String in ids:
			doc.undo.live(MarkerCmds.SetMarker.new(seq.id, "", id, {"time": maxf(float(times.get(id, 0.0)) + shift, 0.0)}))
		live_key = "marker"
		return true
	if mode == "marker_len":
		doc.undo.live(MarkerCmds.SetMarker.new(seq.id, "", marker_id, marker_length_fields(pos)))
		live_key = "marker_len"
		return true
	if mode == "marker_range":
		marquee = marker_rect()
		return true
	if mode == "track_reorder":
		return true
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	if mode == "fade":
		return _fade_motion(seq, doc, c, pos)
	if mode == "move":
		var raw: float = (pos.x - press.x) / _pps()
		var min_start: float = INF
		var offsets: PackedFloat64Array = PackedFloat64Array()
		var starts: Dictionary = origin.get("starts", {})
		for id: String in ids:
			var f: Clip = seq.clip_by_id(id)
			if f == null:
				continue
			min_start = minf(min_start, float(starts.get(id, f.start)))
			offsets.append(f.start - c.start)
			offsets.append(f.end() - c.start)
		offsets.append_array(ViewCuts.move_offsets(host, seq, ids, c))
		var want: float = float(origin.get("start", c.start)) + raw
		var snapped: float = snap(want, offsets)
		delta_t = snapped - float(origin.get("start", c.start))
		if min_start + delta_t < 0.0:
			delta_t = -min_start
		var hit: Dictionary = host.call("hit_at", pos)
		var dest: Track = hit.get("track", null)
		track_delta = 0
		var own: Track = seq.track_of(clip_id)
		if dest != null and own != null and (dest.kind == own.kind or seq.free_tracks) and not bool(hit.get("nest", false)):
			var list: Array[Track] = seq.hop_list(own)
			track_delta = list.find(dest) - list.find(own)
		insert = bool(mods_.get("ctrl", false))
		duplicate = bool(mods_.get("alt", false))
		mods["ctrl"] = insert
		mods["alt"] = duplicate
		_update_doomed(seq)
		return true
	if mode == "trim" or mode == "ripple":
		var edge0: float = float(origin.get("start", 0.0)) if side == "head" else float(origin.get("end", 0.0))
		var want: float = snap(edge0 + (pos.x - press.x) / _pps())
		var fam: PackedStringArray = Verbs.trim_family(seq, clip_id, side, solo_trim)
		if fam.is_empty():
			return true
		var cmd: Command = EditCmds.RippleTrim.new(seq.id, fam, side, want) if ripple else EditCmds.TrimClip.new(seq.id, fam, side, want)
		doc.undo.live(cmd)
		live_key = cmd.live_key()
		return true
	if mode == "rate":
		var edge1: float = float(origin.get("start", 0.0)) if side == "head" else float(origin.get("end", 0.0))
		var to: float = snap(edge1 + (pos.x - press.x) / _pps())
		var stretch: Command = SpeedCmds.RateStretch.new(seq.id, PackedStringArray([clip_id]), side, to)
		doc.undo.live(stretch)
		live_key = stretch.live_key()
		return true
	if mode == "roll":
		var want: float = snap(edit_t + (pos.x - press.x) / _pps())
		var tracks: PackedStringArray = PackedStringArray([track_id])
		doc.undo.live(EditCmds.RollEdit.new(seq.id, edit_t, tracks, want))
		live_key = "roll"
		return true
	if mode == "transition":
		var w0: float = float(origin.get("w0", 0.0))
		var w1: float = float(origin.get("w1", 0.0))
		var cut: float = float(origin.get("cut", origin.get("start", 0.0)))
		var lo: float = float(origin.get("lo", w0))
		var hi: float = float(origin.get("hi", w1))
		var dt: float = (pos.x - press.x) / _pps()
		var dur0: float = maxf(w1 - w0, Clip.MIN_TRANSITION)
		if side == "head":
			w0 = clampf(snap(w0 + dt), lo, minf(cut, w1 - Clip.MIN_TRANSITION))
		elif side == "tail":
			w1 = clampf(snap(w1 + dt), maxf(cut, w0 + Clip.MIN_TRANSITION), hi)
		else:
			var want: float = snap(w0 + dt, PackedFloat64Array([dur0]))
			for frac: float in [0.0, 0.5, 1.0]:
				if absf(want - (cut - dur0 * frac)) * _pps() <= TR_SNAP_PX:
					want = cut - dur0 * frac
			w0 = clampf(want, maxf(lo, cut - dur0), minf(hi - dur0, cut))
			w1 = w0 + dur0
		var dur: float = maxf(w1 - w0, Clip.MIN_TRANSITION)
		var next: Dictionary = TrTiming.stretched((origin.get("transition", {}) as Dictionary), dur)
		next["offset"] = clampf((cut - w0) / dur, 0.0, 1.0)
		next.erase("align")
		value_a = w0
		value_b = w1
		if tr_field == TrTiming.OUT_FIELD:
			doc.undo.live(ClipCmds.SetClipField.new(seq.id, clip_id, TrTiming.OUT_FIELD, next))
		else:
			doc.undo.live(ClipCmds.SetTransition.new(seq.id, clip_id, next))
		live_key = "transition"
		return true
	if mode == "slip":
		var d: float = (press.x - pos.x) / _pps()
		delta_t = d
		var fam: PackedStringArray = Verbs.MoveRule.slide_ids(seq, c.id)
		doc.undo.live(EditCmds.SlipClip.new(seq.id, Verbs.unlocked(seq, fam), d))
		live_key = "slip"
		return true
	if mode == "slide":
		var want: float = snap(float(origin.get("start", 0.0)) + (pos.x - press.x) / _pps())
		delta_t = want - float(origin.get("start", 0.0))
		var fam: PackedStringArray = Verbs.MoveRule.slide_ids(seq, c.id)
		doc.undo.live(EditCmds.SlideClip.new(seq.id, Verbs.unlocked(seq, fam), delta_t))
		live_key = "slide"
		return true
	if mode == "level":
		return _level_motion(seq, doc, c, pos)
	return false


func _update_doomed(seq: Sequence) -> void:
	doomed = []
	if insert or duplicate or overlapping(seq):
		return
	var geom: Dictionary = host.call("geometry")
	var lanes: Dictionary = host.call("lanes")
	var starts: Dictionary = origin.get("starts", {})
	for id: String in ids:
		var f: Clip = seq.clip_by_id(id)
		if f == null:
			continue
		var own: Track = seq.track_of(id)
		var dest: Track = seq.track_at_offset(own, track_delta)
		if dest.locked:
			dest = own
		var s: float = float(starts.get(id, f.start)) + delta_t
		var e: float = s + f.duration
		var l: Dictionary = Lanes.lane_for_track(lanes, dest.id)
		if l.is_empty():
			continue
		for o: Clip in seq.clips_overlapping(dest, s, e):
			if ids.has(o.id):
				continue
			var a: float = maxf(o.start, s)
			var b: float = minf(o.end(), e)
			if b <= a:
				continue
			var y: float = Hit.lane_screen_y(geom, l)
			doomed.append(Rect2(Hit.x_of(geom, a), y, (b - a) * float(geom["pps"]), float(l["h"])))


func overlapping(seq: Sequence) -> bool:
	return mode == "move" and not insert and Verbs.place_mode(seq, false, bool(mods.get("shift", false))) == Verbs.MODE_OVERLAP


func slop_origin() -> Vector2:
	if mode == "range" and origin.has("anchor"):
		return Marquee.anchor_screen(host.call("geometry"), origin["anchor"])
	return press


func marker_length_fields(pos: Vector2) -> Dictionary:
	var t0: float = float(origin.get("time", 0.0))
	var e0: float = maxf(float(origin.get("end", t0)), t0)
	var moved: float = (pos.x - press.x) / _pps()
	if side == "head":
		var head: float = clampf(snap(t0 + moved), 0.0, e0)
		value_a = head
		value_b = e0
		return {"time": head, "duration": e0 - head}
	var tail: float = maxf(snap(e0 + moved), t0)
	value_a = t0
	value_b = tail
	return {"duration": tail - t0}


func marker_rect() -> Rect2:
	var g: Dictionary = host.call("geometry")
	var hw: float = float(g["header_w"])
	var span: Vector2 = Hit.row_span(g, press.y)
	var x0: float = maxf(minf(press.x, last.x), hw)
	var x1: float = maxf(maxf(press.x, last.x), hw)
	return Rect2(x0, span.x, maxf(x1 - x0, 0.0), span.y - span.x)


func marquee_rect() -> Rect2:
	if mode != "range" or not origin.has("anchor"):
		return marquee
	return Marquee.screen_rect(host.call("geometry"), origin["anchor"], last)


func modifier_changed() -> bool:
	if mode != "move" or not active:
		return false
	var alt: bool = Input.is_key_pressed(KEY_ALT)
	var ctrl: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if alt == duplicate and ctrl == insert:
		return false
	return motion(last, {"alt": alt, "ctrl": ctrl, "shift": bool(mods.get("shift", false))})


func preview_offset_for(id: String) -> Dictionary:
	if mode != "move" or not active or not ids.has(id):
		return {}
	return {"delta_t": delta_t, "track_delta": track_delta}


func release(pos: Vector2, mods_: Dictionary) -> bool:
	if mode.is_empty():
		return false
	var was_active: bool = active
	var m: String = mode
	var doc: Project = _doc()
	var seq: Sequence = _seq()
	var did: bool = false
	if doc == null or seq == null:
		clear()
		return false
	if not was_active:
		if m == "move" and not clip_id.is_empty():
			host.call("click_select", Stacks.alt_pick(host, clip_id, press, mods), mods)
		if m == "marker_range":
			host.call("marker_band_click", press, mods_)
		clear()
		host.call("gesture_ended")
		return false
	last = pos
	if m == "scrub":
		if host.has_method("scrub_release"):
			host.call("scrub_release", scrub_t, last != press)
		else:
			if scrub_t >= 0.0:
				Session.scrub_to(scrub_t)
			Session.scrub_done()
		did = true
	elif m == "header_w":
		host.call("persist_header_w")
		did = true
	elif m == "divider":
		host.call("commit_band_height")
		did = true
	elif m == "track_h":
		host.call("commit_track_height", track_id)
		did = true
	elif m == "pan" or m == "band_scroll" or m == "hscroll":
		did = true
	elif m == "band_reorder":
		did = bool(host.call("reorder_band", track_id, pos))
	elif m == "track_reorder":
		did = bool(host.call("reorder_track_at", track_id, pos))
	elif m == "fade":
		did = _fade_release(doc, seq)
	elif m == MarkerLanes.DRAG_MODE:
		did = MarkerLanes.drag_release(host, self, pos, mods_)
	elif m == CensorTool.DRAG_MODE:
		did = CensorTool.drag_release(host, self, pos, mods_)
	elif m == Keys.DRAG_MODE:
		did = Keys.drag_release(host, self, pos, mods_)
	elif m == RealignTool.DRAG_MODE:
		did = RealignTool.drag_release(host, self, pos, mods_)
	elif m == SpeedBand.DRAG_MODE:
		did = SpeedBand.drag_release(host, self, pos, mods_)
	elif m == TrackerBand.DRAG_MODE:
		did = TrackerBand.drag_release(host, self, pos, mods_)
	elif m == "range":
		var anchor: Dictionary = origin.get("anchor", {})
		var found: PackedStringArray = Marquee.selection(host, anchor, pos) if not anchor.is_empty() else host.call("clips_in_marquee", marquee)
		Verbs.select(doc, seq, found, "add" if bool(anchor.get("add", mods_.get("shift", false))) else "replace")
		did = true
	elif m == "marker":
		did = _marker_move_release(doc, seq)
	elif m == "marker_len":
		did = _marker_length_release(doc, seq)
	elif m == "marker_range":
		if bool(mods.get("ctrl", false)) or bool(mods_.get("ctrl", false)):
			did = not MarkerLanes.tag_from_rect(host, marker_rect()).is_empty()
		else:
			host.call("select_markers_in", marker_rect(), bool(mods_.get("shift", false)))
			did = true
	elif m == "move":
		mods["shift"] = bool(mods_.get("shift", false))
		if absf(delta_t) > 0.00001 or track_delta != 0:
			if duplicate:
				var place: String = Verbs.MODE_OVERLAP if overlapping(seq) else ("insert" if insert else "overwrite")
				did = Verbs.duplicate_clips(doc, seq, ids, delta_t, track_delta, place, clip_id)
			else:
				did = Verbs.move_selection(doc, seq, delta_t, track_delta, Verbs.place_mode(seq, insert, bool(mods.get("shift", false))), clip_id)
	elif m == "trim" or m == "ripple":
		var c: Clip = seq.clip_by_id(clip_id)
		var final_t: float = 0.0
		if c != null:
			final_t = c.start if side == "head" else c.end()
		doc.undo.cancel_live()
		var before: float = float(origin.get("start", 0.0)) if side == "head" else float(origin.get("end", 0.0))
		if c != null and absf(final_t - before) > 0.00001:
			did = Verbs.trim(doc, seq, clip_id, side, final_t, ripple, solo_trim)
	elif m == "rate":
		var cr: Clip = seq.clip_by_id(clip_id)
		var final_r: float = 0.0
		if cr != null:
			final_r = cr.start if side == "head" else cr.end()
		doc.undo.cancel_live()
		var was_r: float = float(origin.get("start", 0.0)) if side == "head" else float(origin.get("end", 0.0))
		if cr != null and absf(final_r - was_r) > 0.00001:
			did = Verbs.rate_stretch(doc, seq, clip_id, side, final_r)
	elif m == "roll":
		var c2: Clip = seq.clip_by_id(clip_id)
		var final_t2: float = edit_t
		if c2 != null:
			final_t2 = c2.start if side == "head" else c2.end()
		doc.undo.cancel_live()
		if absf(final_t2 - edit_t) > 0.00001:
			did = Verbs.roll(doc, seq, edit_t, track_id, final_t2)
	elif m == "slip":
		doc.undo.cancel_live()
		if absf(delta_t) > 0.00001:
			did = Verbs.slip(doc, seq, clip_id, delta_t)
	elif m == "slide":
		doc.undo.cancel_live()
		if absf(delta_t) > 0.00001:
			did = Verbs.slide(doc, seq, clip_id, delta_t)
	elif m == "level":
		did = _level_release(doc, seq)
	elif m == "transition":
		var c4: Clip = seq.clip_by_id(clip_id)
		var final_tr: Dictionary = c4.transition_field(tr_field).duplicate(true) if c4 != null else {}
		doc.undo.cancel_live()
		if c4 != null and not final_tr.is_empty() and final_tr != origin.get("transition", {}):
			if tr_field == TrTiming.OUT_FIELD:
				did = Verbs.set_transition_out(doc, seq, clip_id, final_tr)
			else:
				did = Verbs.set_transition(doc, seq, clip_id, final_tr)
	clear()
	host.call("gesture_ended")
	return did


func _marker_move_release(doc: Project, seq: Sequence) -> bool:
	var times: Dictionary = origin.get("times", {})
	var moved: Dictionary = {}
	var list: PackedStringArray = ids if not ids.is_empty() else PackedStringArray([marker_id])
	for id: String in list:
		var mk: Marker = seq.marker_by_id(id)
		if mk != null:
			moved[id] = mk.time
	doc.undo.cancel_live()
	var to_layer: String = marker_drop_layer(seq)
	var cmds: Array[Command] = []
	for id: String in list:
		var was: float = float(times.get(id, origin.get("time", 0.0)))
		var now: float = float(moved.get(id, was))
		var fields: Dictionary = {}
		if absf(now - was) > 0.00001:
			fields["time"] = now
		var mk2: Marker = seq.marker_by_id(id)
		if to_layer != "?" and mk2 != null and MarkerLayers.lane_of(seq, mk2) != to_layer:
			fields["layer"] = to_layer
		if not fields.is_empty():
			cmds.append(MarkerCmds.SetMarker.new(seq.id, "", id, fields))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Move marker" if cmds.size() == 1 else "Move markers", cmds)


func marker_drop_layer(seq: Sequence) -> String:
	var g: Dictionary = host.call("geometry")
	var from: Vector2 = Hit.row_span(g, press.y)
	var to: Vector2 = Hit.row_span(g, last.y)
	var rh: float = float(g["ruler_h"])
	if from == to or (last.y >= rh and Hit.row_at(g, last.y).is_empty()):
		return "?"
	if last.y < rh:
		return "" if MarkerLayers.shown(seq, "") and not MarkerLayers.locked(seq, "") else "?"
	var id: String = String(Hit.row_at(g, last.y)["id"])
	if not MarkerLayers.shown(seq, id) or MarkerLayers.locked(seq, id):
		return "?"
	return id


func _marker_length_release(doc: Project, seq: Sequence) -> bool:
	var mk: Marker = seq.marker_by_id(marker_id)
	if mk == null:
		doc.undo.cancel_live()
		return false
	var fields: Dictionary = {"time": mk.time, "duration": mk.duration}
	doc.undo.cancel_live()
	if absf(float(fields["time"]) - float(origin.get("time", 0.0))) < 0.00001 and absf(float(fields["duration"]) - float(origin.get("duration", 0.0))) < 0.00001:
		return false
	return Verbs.run(doc, "Marker length", [MarkerCmds.SetMarker.new(seq.id, "", marker_id, fields)])


func cancel() -> void:
	if mode.is_empty():
		return
	var doc: Project = _doc()
	if mode == "level" and bool(origin.get("recorded", false)):
		RecordCmds.cancel()
	if mode == RealignTool.DRAG_MODE:
		RealignTool.drag_cancel(host, self)
	if mode == SpeedBand.DRAG_MODE:
		SpeedBand.drag_cancel(host, self)
	if doc != null and not live_key.is_empty():
		doc.undo.cancel_live()
	var m: String = mode
	if m == "header_w":
		host.call("set_header_w", float(origin.get("header_w", 160.0)))
	elif m == "divider":
		host.call("set_band_height_preview", -1.0)
	elif m == "track_h":
		host.call("set_track_height_preview", track_id, -1.0)
	clear()
	host.call("gesture_ended")


func _fade_motion(seq: Sequence, doc: Project, c: Clip, pos: Vector2) -> bool:
	if not origin.has("fade0"):
		origin["fade0"] = FadeTools.fade_of(seq, c, side)
	var x0: float = _x_of(float(origin.get("start", c.start)))
	var x1: float = _x_of(float(origin.get("end", c.end())))
	var secs: float = (pos.x - x0) / _pps() if side == "in" else (x1 - pos.x) / _pps()
	secs = maxf(quantise(maxf(secs, 0.0)), 0.0)
	value_a = secs
	var cmd: Command = FadeTools.fade_command(seq, c, side, secs)
	doc.undo.live(cmd)
	live_key = cmd.live_key()
	return true


func _fade_release(doc: Project, seq: Sequence) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	var final_v: float = FadeTools.fade_of(seq, c, side) if c != null else 0.0
	doc.undo.cancel_live()
	if c == null:
		return false
	var was: float = FadeTools.fade_of(seq, c, side)
	if absf(final_v - was) < 0.0001:
		return false
	return FadeTools.set_fade(doc, seq, clip_id, side, final_v)


const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const LEVEL_VOLUME := "audio.volume"
const LEVEL_OPACITY := "transform.opacity"


func level_path() -> String:
	return String(origin.get("level_path", LEVEL_VOLUME))


func level_start() -> float:
	return float(origin.get("level_value", origin.get("volume", 1.0)))


func begin_level(c: Clip, path: String, lo: float, hi: float, inner_h: float) -> void:
	var seq: Sequence = _seq()
	origin["inner_h"] = inner_h
	origin["level_path"] = path
	origin["level_lo"] = lo
	origin["level_hi"] = hi
	var prop: Dictionary = c.get_param(path)
	if prop.is_empty():
		prop = AnimProp.make(1.0)
	var ph: float = seq.playhead if seq != null else c.start
	origin["level_value"] = AnimProp.evaluate_float(prop, c.param_time(path, maxf(ph - c.start, 0.0)), c.duration)
	origin["key_at"] = ph if AnimProp.is_animated(prop) else -1.0


func _level_motion(seq: Sequence, doc: Project, c: Clip, pos: Vector2) -> bool:
	var inner_h: float = maxf(float(origin.get("inner_h", 40.0)), 8.0)
	var lo: float = float(origin.get("level_lo", 0.0))
	var hi: float = float(origin.get("level_hi", 2.0))
	var path: String = level_path()
	var v: float = clampf(level_start() + (press.y - pos.y) / inner_h * (hi - lo), lo, hi)
	value_a = v
	live_key = "level"
	if RecordCmds.write(doc, seq, clip_id, path, v, true):
		origin["recorded"] = true
		return true
	var key_at: float = float(origin.get("key_at", -1.0))
	var prop: Dictionary = c.get_param(path)
	var next: Dictionary = AnimProp.make(v) if key_at < 0.0 else AnimProp.set_key(prop if not prop.is_empty() else AnimProp.make(v), c.param_time(path, key_at - c.start), v)
	doc.undo.live(ClipCmds.SetClipParam.new(seq.id, clip_id, path, next))
	return true


func _level_release(doc: Project, seq: Sequence) -> bool:
	var path: String = level_path()
	if bool(origin.get("recorded", false)):
		RecordCmds.finish(doc)
		if not doc.undo.has_live():
			return false
		doc.undo.commit_live(RecordCmds.commit_label(doc, "Record " + RecordCmds.label_for(path)))
		return true
	doc.undo.cancel_live()
	var c: Clip = seq.clip_by_id(clip_id)
	if c != null and absf(value_a - level_start()) > 0.0001:
		return Verbs.set_clip_param(doc, seq, clip_id, path, value_a, float(origin.get("key_at", -1.0)))
	return false
