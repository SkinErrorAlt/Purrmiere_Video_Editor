extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const SpeedCurve := preload("res://doc/speed_curve.gd")
const Command := preload("res://doc/commands/command.gd")
const EDIT_CMDS := "res://doc/commands/edit_cmds.gd"
const CLIP_CMDS := "res://doc/commands/clip_cmds.gd"
const EDIT_MATH := "res://doc/commands/edit_math.gd"
const KEY_ON := "speed_length"
const KEY_REF := "speed_length_ref"
const STEP_RATE := 240.0
const MAX_SECONDS := 21600.0
const EPS := 0.0005
const DUR_EPS := 0.000001

static var enabled: bool = true
static var fits: int = 0
static var slow_walks: int = 0
const PREF_NEW := "speed.resize_new"


static func new_clips_on() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs") if loop is SceneTree else null
	if prefs == null:
		return false
	if not bool(prefs.call("is_registered", PREF_NEW)):
		prefs.call("register", PREF_NEW, true, {"label": "New clips change length with their speed (Resize with speed), so a slowed down clip keeps all of its frames", "type": "bool"})
	return bool(prefs.call("get_value", PREF_NEW))


static func is_on(c: Clip) -> bool:
	return c != null and bool(c.audio.get(KEY_ON, false))


static func ref_of(c: Clip) -> Dictionary:
	var r: Variant = c.audio.get(KEY_REF, null)
	return r if r is Dictionary else {}


static func span_of(c: Clip) -> float:
	return absf(c.source_time(c.end()) - c.source_time(c.start))


static func solve_length(speed: Dictionary, span: float, guess: float) -> float:
	if span <= EPS:
		return -1.0
	if not AnimProp.is_animated(speed):
		var v: float = absf(float(speed.get("v", 1.0)))
		if v <= 0.000001:
			return -1.0
		return span / v
	var plan: Dictionary = SpeedCurve.plan_of(speed)
	if not plan.is_empty():
		return SpeedCurve.walk_span(plan, span)
	slow_walks += 1
	var dur: float = maxf(guess, 0.001)
	var found: float = -1.0
	for pass_i: int in 3:
		found = _walk(speed, span, dur)
		if found < 0.0:
			return -1.0
		if absf(found - dur) <= DUR_EPS:
			break
		dur = found
	return found


static func _walk(speed: Dictionary, span: float, dur: float) -> float:
	var step: float = 1.0 / STEP_RATE
	var acc: float = 0.0
	var u: float = 0.0
	var prev: float = AnimProp.evaluate_float(speed, 0.0, dur)
	while u < MAX_SECONDS:
		var cur: float = AnimProp.evaluate_float(speed, u + step, dur)
		var piece: float = (prev + cur) * 0.5 * step
		if absf(acc + piece) >= span:
			var need: float = span - absf(acc)
			var rate: float = absf(piece) / step
			return u + (need / rate if rate > 0.0 else step)
		acc += piece
		u += step
		prev = cur
	return -1.0


static func _marks(cmds: Array, depth: int) -> bool:
	for cmd: Variant in cmds:
		if not (cmd is Object):
			continue
		var o: Object = cmd
		if "field" in o and String(o.get("field")) == "audio":
			var v: Variant = o.get("value")
			if v is Dictionary and bool((v as Dictionary).get(KEY_ON, false)):
				return true
		if depth < 4 and "steps" in o and o.get("steps") is Array and _marks(o.get("steps"), depth + 1):
			return true
	return false


static func _speed_edit(cmds: Array) -> bool:
	for cmd: Variant in cmds:
		if cmd is Object and ("fit_length" in cmd and "touch_pitch" in cmd):
			return true
		if cmd is Object and String((cmd as Object).get("label")) == "Rate stretch":
			return true
	return false


static func _seq_ids(cmds: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cmd: Variant in cmds:
		if not (cmd is Object):
			continue
		var sid: String = String((cmd as Object).get("seq_id")) if "seq_id" in cmd else ""
		if not sid.is_empty() and not out.has(sid):
			out.append(sid)
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or doc == null or cmds.is_empty():
		return out
	if not Clip.speed_length_seen:
		if not _marks(cmds, 0):
			return out
		Clip.speed_length_seen = true
	var skip_fit: bool = _speed_edit(cmds)
	for sid: String in _seq_ids(cmds):
		var s: Sequence = doc.sequence_by_id(sid)
		if s != null:
			out.append_array(_fix_seq(doc, s, skip_fit))
	return out


static func _fix_seq(doc: Project, s: Sequence, skip_fit: bool) -> Array[Command]:
	var out: Array[Command] = []
	var ClipCmds: GDScript = load(CLIP_CMDS)
	var marked: Array[Clip] = []
	var stale: Array[Clip] = []
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			if bool(c.audio.get(KEY_ON, false)):
				marked.append(c)
			elif c.audio.has(KEY_REF):
				stale.append(c)
	for c: Clip in stale:
		var a: Dictionary = c.audio.duplicate(true)
		a.erase(KEY_REF)
		out.append(_apply(doc, ClipCmds.SetClipField.new(s.id, c.id, "audio", a)))
	if marked.is_empty():
		return _ok(out)
	var wants: Dictionary = {}
	var partner_speed: Dictionary = {}
	var known: Dictionary = {}
	if not skip_fit:
		for c: Clip in marked:
			if wants.has(c.id):
				continue
			var r: Dictionary = ref_of(c)
			if r.is_empty():
				continue
			var tr: Track = s.track_of(c.id)
			if tr == null or tr.locked:
				continue
			if absf(float(r.get("dur", -1.0)) - c.duration) > DUR_EPS:
				continue
			var want_span: float = float(r.get("span", 0.0))
			var span_was: float = span_of(c)
			known[c.id] = [c.start, c.duration, c.in_offset, c.speed, span_was]
			if absf(span_was - want_span) <= EPS:
				continue
			var d: float = solve_length(c.speed, want_span, c.duration)
			if d <= 0.0:
				continue
			d = maxf(d, 1.0 / maxf(s.fps, 1.0))
			if absf(d - c.duration) <= DUR_EPS:
				continue
			wants[c.id] = d
			for p: Clip in s.linked(c):
				if p == c or wants.has(p.id):
					continue
				var ptr: Track = s.track_of(p.id)
				if ptr == null or ptr.locked:
					continue
				if absf(p.start - c.start) > EPS or absf(p.duration - c.duration) > DUR_EPS:
					continue
				wants[p.id] = d
				if p.speed != c.speed:
					partner_speed[p.id] = c.speed.duplicate(true)
	if not wants.is_empty():
		var EditCmds: GDScript = load(EDIT_CMDS)
		var EditMath: GDScript = load(EDIT_MATH)
		var per_track: Dictionary = {}
		for id: Variant in wants.keys():
			var tr2: Track = s.track_of(String(id))
			if tr2 == null:
				continue
			if not per_track.has(tr2):
				per_track[tr2] = {}
			(per_track[tr2] as Dictionary)[id] = wants[id]
		var moves: Array[Dictionary] = []
		for tr3: Variant in per_track.keys():
			moves.append_array(EditMath.call("resize_ripple_moves", tr3, per_track[tr3]))
		for pid: Variant in partner_speed.keys():
			out.append(_apply(doc, ClipCmds.SetClipParam.new(s.id, String(pid), "speed", partner_speed[pid])))
		for id2: Variant in wants.keys():
			var rc: Clip = s.clip_by_id(String(id2))
			if rc == null:
				continue
			out.append(_apply(doc, EditCmds.SetTiming.new(s.id, rc.id, rc.start, float(wants[id2]), rc.in_offset, 0.0)))
		if not moves.is_empty():
			out.append(_apply(doc, ClipCmds.MoveClips.new(s.id, moves)))
		fits += 1
	for c2: Clip in marked:
		var r2: Dictionary = ref_of(c2)
		var span_now: float = _known_span(known, c2)
		if not r2.is_empty() and absf(float(r2.get("dur", -1.0)) - c2.duration) <= DUR_EPS and absf(float(r2.get("span", -1.0)) - span_now) <= EPS:
			continue
		var a2: Dictionary = c2.audio.duplicate(true)
		a2[KEY_REF] = {"dur": c2.duration, "span": span_now}
		out.append(_apply(doc, ClipCmds.SetClipField.new(s.id, c2.id, "audio", a2)))
	return _ok(out)


static func rebase(project: Project) -> int:
	var n: int = 0
	if project == null:
		return n
	for s: Sequence in project.sequences:
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if not is_on(c):
					continue
				var r: Dictionary = ref_of(c)
				if r.is_empty() or absf(float(r.get("dur", -1.0)) - c.duration) > DUR_EPS:
					continue
				var span_now: float = span_of(c)
				if absf(float(r.get("span", -1.0)) - span_now) <= EPS:
					continue
				c.audio[KEY_REF] = {"dur": c.duration, "span": span_now}
				n += 1
	return n


static func _known_span(known: Dictionary, c: Clip) -> float:
	var k: Variant = known.get(c.id, null)
	if k is Array and float((k as Array)[0]) == c.start and float((k as Array)[1]) == c.duration and float((k as Array)[2]) == c.in_offset and is_same((k as Array)[3], c.speed):
		return float((k as Array)[4])
	return span_of(c)


static func _apply(doc: Project, cmd: Command) -> Command:
	cmd.do(doc)
	return cmd if cmd.ok else null


static func _ok(list: Array[Command]) -> Array[Command]:
	var out: Array[Command] = []
	for c: Command in list:
		if c != null:
			out.append(c)
	return out


static func typed_speed_commands(s: Sequence, ids: PackedStringArray, value: float) -> Array[Command]:
	var out: Array[Command] = []
	if s == null or ids.is_empty():
		return out
	var on_ids: PackedStringArray = PackedStringArray()
	var off_ids: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if is_on(s.clip_by_id(id)):
			on_ids.append(id)
		else:
			off_ids.append(id)
	var Verbs: GDScript = load("res://doc/verbs.gd")
	if not on_ids.is_empty():
		var a: Variant = Verbs.call("speed_command", s, on_ids, value, false, "ripple", -1.0, false)
		if a is Command:
			out.append(a)
	if not off_ids.is_empty():
		var b: Variant = Verbs.call("speed_command", s, off_ids, value, false, "hold_length", -1.0, false)
		if b is Command:
			out.append(b)
	return out
