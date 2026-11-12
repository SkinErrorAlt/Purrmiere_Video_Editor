extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const SpeedCurve := preload("res://doc/speed_curve.gd")
const SpeedLength := preload("res://doc/speed_length.gd")
const KeyAnchor := preload("res://doc/key_anchor.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const DUR_EPS := 0.000001
const ALIGN_EPS := 0.0005


class BandStep extends "res://doc/commands/composite.gd":
	var clip_id: String = ""
	var prop: Dictionary = {}
	var static_v: float = 0.0
	var is_static: bool = false
	var plan: Dictionary = {}
	var solved: Dictionary = {}
	var solve_ok: bool = true
	var family: PackedStringArray = PackedStringArray()
	var hint: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_prop: Dictionary, p_static: float, p_is_static: bool = false) -> void:
		label = "Speed band"
		seq_id = p_seq_id
		clip_id = p_clip_id
		prop = p_prop.duplicate(true)
		static_v = p_static
		is_static = p_is_static

	static func aligned_family(s: Sequence, c: Clip) -> Array[Clip]:
		var out: Array[Clip] = [c]
		for p: Clip in s.linked(c):
			if p == c:
				continue
			var pt: Track = s.track_of(p.id)
			if pt == null or pt.locked:
				continue
			if absf(p.start - c.start) > ALIGN_EPS or absf(p.duration - c.duration) > DUR_EPS:
				continue
			out.append(p)
		return out

	static func hint_for(s: Sequence, c: Clip) -> Dictionary:
		var ids: PackedStringArray = PackedStringArray()
		var paths: Dictionary = {}
		var owners: Dictionary = {}
		for f: Clip in aligned_family(s, c):
			ids.append(f.id)
			owners[f.id] = KeyAnchor.owner_of(s, f)
			paths[f.id] = pinned_paths(f, String(owners[f.id]))
		return {"family": ids, "paths": paths, "owners": owners}

	static func pinned_paths(f: Clip, owner: String = "") -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		var who: String = f.id if owner.is_empty() else owner
		for path: String in f.param_paths():
			if path == "speed":
				continue
			if SpeedCurve.has_pins(f.get_param(path), who) and KeyAnchor.pinnable(f, path):
				out.append(path)
		return out

	func _owner(s: Sequence, f: Clip) -> String:
		var known: Dictionary = hint.get("owners", {})
		if known.has(f.id):
			return String(known[f.id])
		return KeyAnchor.owner_of(s, f)

	func _family_of(s: Sequence, c: Clip) -> Array[Clip]:
		if not hint.has("family"):
			return aligned_family(s, c)
		var out: Array[Clip] = []
		for id: String in (hint["family"] as PackedStringArray):
			var f: Clip = s.clip_by_id(id)
			if f != null:
				out.append(f)
		if out.is_empty() or out[0] != c:
			return aligned_family(s, c)
		return out

	func live_key() -> String:
		return "speed_band|" + clip_id

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		var c: Clip = s.clip_by_id(clip_id) if s != null else null
		if c == null:
			return false
		var tr: Track = s.track_of(c.id)
		if tr == null or tr.locked:
			return false
		var fam: Array[Clip] = []
		if is_static:
			for cmd: Command in SpeedLength.typed_speed_commands(s, PackedStringArray([c.id]), static_v):
				apply(doc, cmd)
			plan = SpeedCurve.compile(AnimProp.make(static_v))
			solved = AnimProp.make(static_v)
			for f: Clip in s.linked(c):
				var ftr: Track = s.track_of(f.id)
				if ftr != null and not ftr.locked:
					fam.append(f)
		else:
			fam = _family_of(s, c)
			var res: Dictionary = {}
			if SpeedCurve.positive(prop) and not KeyAnchor.plant_ignore:
				res = SpeedCurve.solve_pins(prop, c.in_offset, _owner(s, c))
			else:
				res = {"prop": prop, "ok": true, "plan": SpeedCurve.compile(prop)}
			solve_ok = bool(res["ok"])
			if not solve_ok:
				return false
			solved = res["prop"]
			plan = res["plan"]
			for f2: Clip in fam:
				apply(doc, ClipCmds.SetClipParam.new(s.id, f2.id, "speed", solved))
			_fit(doc, s, c, fam)
		for f3: Clip in fam:
			family.append(f3.id)
			if not SpeedCurve.positive(f3.speed):
				continue
			var known: Dictionary = hint.get("paths", {})
			var who: String = _owner(s, f3)
			var list: PackedStringArray = known[f3.id] if known.has(f3.id) else pinned_paths(f3, who)
			for path: String in list:
				var p: Dictionary = f3.get_param(path)
				var nxt: Dictionary = SpeedCurve.moved_pins(p, plan, f3.in_offset, who)
				if nxt != p:
					apply(doc, ClipCmds.SetClipParam.new(s.id, f3.id, path, nxt))
		return true

	func _fit(doc: Project, s: Sequence, c: Clip, fam: Array[Clip]) -> void:
		if not SpeedLength.enabled or not SpeedLength.is_on(c):
			return
		var r: Dictionary = SpeedLength.ref_of(c)
		if r.is_empty() or absf(float(r.get("dur", -1.0)) - c.duration) > DUR_EPS:
			return
		var want_span: float = float(r.get("span", 0.0))
		if want_span <= 0.0:
			return
		var d: float = SpeedCurve.inverse(plan, want_span)
		if d <= 0.0:
			return
		d = maxf(d, 1.0 / maxf(s.fps, 1.0))
		if absf(d - c.duration) <= DUR_EPS:
			return
		var per_track: Dictionary = {}
		for f: Clip in fam:
			var ft: Track = s.track_of(f.id)
			if not per_track.has(ft):
				per_track[ft] = {}
			(per_track[ft] as Dictionary)[f.id] = d
		var moves: Array[Dictionary] = []
		for ft2: Variant in per_track.keys():
			moves.append_array(EditMath.resize_ripple_moves(ft2, per_track[ft2]))
		for f2: Clip in fam:
			apply(doc, EditCmds.SetTiming.new(s.id, f2.id, f2.start, d, f2.in_offset, 0.0))
		if not moves.is_empty():
			apply(doc, ShiftStarts.new(s.id, moves))


class ShiftStarts extends "res://doc/commands/command.gd":
	var moves: Array[Dictionary] = []
	var _clips: Array[Clip] = []
	var _tracks: Array[Track] = []
	var _old: PackedFloat64Array = PackedFloat64Array()
	var _new: PackedFloat64Array = PackedFloat64Array()

	func _init(p_seq_id: String, p_moves: Array[Dictionary]) -> void:
		label = "Move clips"
		seq_id = p_seq_id
		moves = p_moves.duplicate(true)

	func _apply(doc: Project, starts: PackedFloat64Array) -> void:
		for i: int in _clips.size():
			_clips[i].start = starts[i]
		for tr: Track in _tracks:
			if tr.can_stack and not tr.is_sorted():
				tr.sort_clips()
			tr.mark_changed()
		seq(doc).invalidate_edits()
		doc.touch("structure")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		_clips = []
		_tracks = []
		_old = PackedFloat64Array()
		_new = PackedFloat64Array()
		for m: Dictionary in moves:
			var id: String = str(m["id"])
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var t: Track = s.track_of(id)
			if not _tracks.has(t):
				_tracks.append(t)
			_clips.append(c)
			_old.append(c.start)
			_new.append(float(m["start"]))
		if _clips.is_empty():
			ok = false
			return
		_apply(doc, _new)

	func undo(doc: Project) -> void:
		_apply(doc, _old)


static func step(seq_id: String, clip_id: String, prop: Dictionary, hint: Dictionary = {}) -> BandStep:
	var out: BandStep = BandStep.new(seq_id, clip_id, prop, 0.0, false)
	out.hint = hint
	return out


static func step_static(seq_id: String, clip_id: String, v: float) -> BandStep:
	return BandStep.new(seq_id, clip_id, {}, v, true)
