extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const Command := preload("res://doc/commands/command.gd")
const MARKER_CMDS := "res://doc/commands/marker_cmds.gd"
const PREF_NEW := "markers.follow_new"
const PREF_GAP := "markers.gap_follows_after"
const OFF := "off"
const VIDEO := "video"
const AUDIO := "audio"
const LABEL := "Markers follow"
const EPS := 0.000001
const MAX_DEPTH := 4

static var enabled: bool = true
static var fixes: int = 0


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs != null and not bool(prefs.call("is_registered", PREF_NEW)):
		prefs.call("register", PREF_NEW, OFF, {"label": "What a new marker follows (off, the first video track, the first audio track)", "type": "enum", "choices": [OFF, VIDEO, AUDIO]})
	if prefs != null and not bool(prefs.call("is_registered", PREF_GAP)):
		prefs.call("register", PREF_GAP, false, {"label": "Markers over a gap follow the clips after it", "type": "bool"})
	return prefs


static func gap_follows_after() -> bool:
	var prefs: Node = register_prefs()
	if prefs == null:
		return false
	return bool(prefs.call("get_value", PREF_GAP))


static func clip_after(seq: Sequence, track_id: String, t: float) -> Clip:
	if seq == null or track_id.is_empty():
		return null
	var tr: Track = seq.track_by_id(track_id)
	if tr == null:
		return null
	var best: Clip = null
	for c: Clip in tr.clips:
		if c.start > t + EPS and (best == null or c.start < best.start):
			best = c
	return best


static func default_mode() -> String:
	var prefs: Node = register_prefs()
	if prefs == null:
		return OFF
	var v: String = String(prefs.call("get_value", PREF_NEW))
	return v if v == VIDEO or v == AUDIO else OFF


static func set_default_mode(mode: String) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_NEW, mode if mode == VIDEO or mode == AUDIO else OFF)


static func default_track(seq: Sequence, mode: String = "") -> String:
	if seq == null:
		return ""
	var want: String = mode if not mode.is_empty() else default_mode()
	if want == OFF:
		return ""
	var first: Array[Track] = seq.audio_tracks if want == AUDIO else seq.video_tracks
	var second: Array[Track] = seq.video_tracks if want == AUDIO else seq.audio_tracks
	if not first.is_empty():
		return first[0].id
	if not second.is_empty():
		return second[0].id
	return ""


static func has_anchors(seq: Sequence) -> bool:
	if seq == null:
		return false
	for m: Marker in seq.markers:
		if m.follows():
			return true
	return false


static func clip_under(seq: Sequence, track_id: String, t: float) -> Clip:
	if seq == null or track_id.is_empty():
		return null
	var tr: Track = seq.track_by_id(track_id)
	if tr == null:
		return null
	return tr.clip_at(t)


static func bind_fields(seq: Sequence, track_id: String, t: float, keep_clip: String = "") -> Dictionary:
	var under: Clip = clip_under(seq, track_id, t)
	if under != null:
		return {"anchor_clip": under.id, "anchor_offset": t - under.start}
	if gap_follows_after():
		var after: Clip = clip_after(seq, track_id, t)
		if after != null:
			return {"anchor_clip": after.id, "anchor_offset": t - after.start}
	var held: Clip = seq.clip_by_id(keep_clip) if seq != null and not keep_clip.is_empty() else null
	if held != null:
		return {"anchor_clip": held.id, "anchor_offset": t - held.start}
	return {"anchor_clip": "", "anchor_offset": 0.0}


static func anchor_fields(seq: Sequence, track_id: String, t: float) -> Dictionary:
	var out: Dictionary = {"anchor": track_id}
	if track_id.is_empty():
		out["anchor_clip"] = ""
		out["anchor_offset"] = 0.0
		return out
	out.merge(bind_fields(seq, track_id, t))
	return out


static func new_marker_fields(seq: Sequence, t: float) -> Dictionary:
	var track_id: String = default_track(seq)
	if track_id.is_empty():
		return {}
	return anchor_fields(seq, track_id, t)


static func resolved_time(seq: Sequence, m: Marker) -> float:
	if seq == null or m == null or not m.follows() or m.anchor_clip.is_empty():
		return m.time if m != null else 0.0
	var c: Clip = seq.clip_by_id(m.anchor_clip)
	if c == null:
		return m.time
	return maxf(c.start + m.anchor_offset, 0.0)


static func resolved_end(seq: Sequence, m: Marker) -> float:
	return resolved_time(seq, m) + (m.duration if m != null else 0.0)


static func plan(seq: Sequence, skip: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out: Dictionary = {}
	if seq == null:
		return out
	for m: Marker in seq.markers:
		if not m.follows() or seq.track_by_id(m.anchor) == null:
			continue
		var t: float = m.time
		if not skip.has(m.id):
			t = resolved_time(seq, m)
		var fields: Dictionary = bind_fields(seq, m.anchor, t, m.anchor_clip)
		if absf(t - m.time) > EPS:
			fields["time"] = t
		if String(fields["anchor_clip"]) == m.anchor_clip and absf(float(fields["anchor_offset"]) - m.anchor_offset) <= EPS:
			fields.erase("anchor_clip")
			fields.erase("anchor_offset")
		if not fields.is_empty():
			out[m.id] = fields
	return out


static func touched_markers(cmds: Array, depth: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cmd: Variant in cmds:
		if not (cmd is Object):
			continue
		var o: Object = cmd
		if "marker_id" in o:
			var id: String = String(o.get("marker_id"))
			if not id.is_empty() and not out.has(id):
				out.append(id)
		if "marker_dict" in o and o.get("marker_dict") is Dictionary:
			var made: String = String((o.get("marker_dict") as Dictionary).get("id", ""))
			if not made.is_empty() and not out.has(made):
				out.append(made)
		if depth < MAX_DEPTH and "steps" in o and o.get("steps") is Array:
			for id2: String in touched_markers(o.get("steps"), depth + 1):
				if not out.has(id2):
					out.append(id2)
	return out


static func seq_ids(cmds: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cmd: Variant in cmds:
		if not (cmd is Object) or not ("seq_id" in cmd):
			continue
		var sid: String = String((cmd as Object).get("seq_id"))
		if not sid.is_empty() and not out.has(sid):
			out.append(sid)
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or doc == null or cmds.is_empty():
		return out
	var ids: PackedStringArray = seq_ids(cmds)
	if ids.is_empty():
		return out
	var skip: PackedStringArray = touched_markers(cmds, 0)
	var MarkerCmds: GDScript = load(MARKER_CMDS)
	for sid: String in ids:
		var s: Sequence = doc.sequence_by_id(sid)
		if s == null or not has_anchors(s):
			continue
		var wanted: Dictionary = plan(s, skip)
		for marker_id: String in wanted.keys():
			var cmd: Command = MarkerCmds.SetMarker.new(s.id, "", marker_id, wanted[marker_id])
			cmd.label = LABEL
			cmd.do(doc)
			if cmd.ok:
				out.append(cmd)
				fixes += 1
	return out
