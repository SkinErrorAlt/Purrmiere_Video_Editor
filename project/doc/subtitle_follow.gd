extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const SUBTITLES := "res://doc/subtitles.gd"
const RESEED := "res://doc/text_reseed.gd"
const MARK_IN := "anim_in"
const MARK_OUT := "anim_out"
const META := "subtitle_follow_clips"
const LABEL := "Text animation follows"
const MAX_DEPTH := 6
const TRACK_KEYS: PackedStringArray = ["track_id", "track_ids"]
const ID_KEYS: PackedStringArray = ["clip_id", "clip_ids", "ids", "moves", "entries", "order", "right_ids", "pasted_ids", "placed_ids", "nest_clip_ids", "writes"]

static var enabled: bool = true
static var fixes: int = 0
static var scans: int = 0
static var plans: int = 0
static var last_us: int = 0
static var total_us: int = 0
static var calls: int = 0


static func add_ids(v: Variant, into: Dictionary) -> void:
	if v is String:
		if not String(v).is_empty():
			into[String(v)] = true
	elif v is PackedStringArray:
		for id: String in v:
			into[id] = true
	elif v is Array:
		for x: Variant in v:
			if x is Dictionary:
				var xd: Dictionary = x
				add_ids(xd.get("id", xd.get("clip_id", "")), into)
			else:
				add_ids(x, into)
	elif v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if k is String:
				into[String(k)] = true


static func gather(cmds: Array, depth: int, seqs: PackedStringArray, tracks: Dictionary, clips: Dictionary) -> void:
	for cmd: Variant in cmds:
		if not (cmd is Command):
			continue
		var c: Command = cmd
		if not c.seq_id.is_empty() and not seqs.has(c.seq_id):
			seqs.append(c.seq_id)
		for key: String in TRACK_KEYS:
			add_ids(c.get(key), tracks)
		for key2: String in ID_KEYS:
			add_ids(c.get(key2), clips)
		var made: Variant = c.get("clip_dict")
		if made is Dictionary:
			add_ids((made as Dictionary).get("id", ""), clips)
		if depth < MAX_DEPTH:
			var inner: Variant = c.get("steps")
			if inner is Array:
				gather(inner, depth + 1, seqs, tracks, clips)


static func lane_has_marks(tr: Track) -> bool:
	for c: Clip in tr.clips:
		if c.props.has(MARK_IN) or c.props.has(MARK_OUT):
			return true
	return false


static func is_marked(c: Clip) -> bool:
	return c != null and (c.props.has(MARK_IN) or c.props.has(MARK_OUT))


static func remember(tr: Track) -> void:
	var marked: bool = lane_has_marks(tr)
	var ids: Dictionary = {}
	if marked:
		for c: Clip in tr.clips:
			ids[c.id] = true
	tr.set_meta(META, {"marked": marked, "size": tr.clips.size(), "ids": ids})


static func needs_plan(s: Sequence, tr: Track, tracks: Dictionary, clips: Dictionary) -> bool:
	if not tr.has_meta(META):
		if lane_has_marks(tr):
			return true
		remember(tr)
		return false
	var m: Dictionary = tr.get_meta(META)
	var marked: bool = bool(m.get("marked", true))
	var was: Dictionary = m.get("ids", {})
	var hit: bool = tracks.has(tr.id) or tr.clips.size() != int(m.get("size", -1))
	var arrived_marked: bool = false
	for id: Variant in clips.keys():
		var key: String = String(id)
		var here: bool = s.track_of(key) == tr
		if here or was.has(key):
			hit = true
			if here and not marked and is_marked(s.clip_by_id(key)):
				arrived_marked = true
	if not hit:
		return false
	if marked or arrived_marked:
		return true
	m["size"] = tr.clips.size()
	return false


static func dirty_lanes(s: Sequence, tracks: Dictionary, clips: Dictionary) -> Array[Track]:
	var out: Array[Track] = []
	for tr: Track in s.video_tracks:
		if not tr.locked and needs_plan(s, tr, tracks, clips):
			out.append(tr)
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or doc == null or cmds.is_empty():
		return out
	var began: int = Time.get_ticks_usec()
	var seqs: PackedStringArray = PackedStringArray()
	var tracks: Dictionary = {}
	var clips: Dictionary = {}
	gather(cmds, 0, seqs, tracks, clips)
	out.append_array(load(RESEED).call("fix", doc, cmds))
	for sid: String in seqs:
		var s: Sequence = doc.sequence_by_id(sid)
		if s == null:
			continue
		scans += 1
		var lanes: Array[Track] = dirty_lanes(s, tracks, clips)
		if lanes.is_empty():
			continue
		plans += lanes.size()
		var subs: GDScript = load(SUBTITLES)
		var planned: Array[Command] = subs.call("follow_cmds", doc, s, lanes)
		for cmd: Command in planned:
			cmd.label = LABEL
			cmd.do(doc)
			if cmd.ok:
				out.append(cmd)
				fixes += 1
		for tr: Track in lanes:
			remember(tr)
	last_us = Time.get_ticks_usec() - began
	total_us += last_us
	calls += 1
	return out
