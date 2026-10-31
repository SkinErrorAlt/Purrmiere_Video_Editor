extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PREF_REDUCTION := "keys.record_reduction"
const PREF_SMOOTH := "keys.record_smooth"
const PREF_KEEP := "keys.record_keep"
const REDUCTIONS: PackedStringArray = ["off", "low", "medium", "high"]
const TOLERANCE: Dictionary = {"off": -1.0, "low": 0.0, "medium": 0.015, "high": 0.04}
const HOLD_EPS := 0.000001
const SMOOTH_REACH := 2
const PATH_LABELS: Dictionary = {
	"transform.pos": "position", "transform.scale": "scale", "transform.rotation": "rotation",
	"transform.anchor": "anchor", "transform.opacity": "opacity", "audio.volume": "volume", "audio.pan": "pan",
}
const KIND_CLIP := "clip"
const KIND_TRACK := "track"
const KIND_MASTER := "master"
const TRACK_FIELDS: PackedStringArray = ["volume", "pan"]
const MASTER_FIELD := "master_volume"
const LIVE_PREFIX := "clip_param|"

static var _passes: Dictionary = {}
static var _touched: Dictionary = {}
static var _watch: Watch = null
const WATCH_SIGNALS: Array = [["playhead_changed", "on_playhead"], ["playing_changed", "on_playing"], ["recording_changed", "on_recording"]]


class Watch extends RefCounted:
	var doc_ref: WeakRef = null
	var seq_id: String = ""

	func on_playhead(t: float) -> void:
		var d: Project = doc_ref.get_ref() if doc_ref != null else null
		if d == null:
			return
		var s: Sequence = d.sequence_by_id(seq_id)
		if s == null:
			return
		var SelfScript: GDScript = load("res://doc/commands/record_cmds.gd")
		SelfScript.call("sample_all", d, s, t)

	func on_playing(on: bool) -> void:
		var d: Project = doc_ref.get_ref() if doc_ref != null else null
		if d == null:
			return
		var SelfScript: GDScript = load("res://doc/commands/record_cmds.gd")
		SelfScript.call("playing_changed", d, d.sequence_by_id(seq_id), on)

	func on_recording(on: bool) -> void:
		var d: Project = doc_ref.get_ref() if doc_ref != null else null
		if d == null or on:
			return
		var SelfScript: GDScript = load("res://doc/commands/record_cmds.gd")
		SelfScript.call("settle", d)


class SetTrackValue extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var field: String = ""
	var anim: Dictionary = {}
	var old: Dictionary = {}
	var audio: bool = true

	func _init(p_seq_id: String, p_track_id: String, p_field: String, p_anim: Dictionary) -> void:
		label = "Record track " + p_field
		seq_id = p_seq_id
		track_id = p_track_id
		field = p_field
		anim = p_anim.duplicate(true)

	func live_key() -> String:
		return "clip_param|track:" + track_id + "|" + field

	func do(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		if t == null or not (t.get(field) is Dictionary):
			ok = false
			return
		old = (t.get(field) as Dictionary).duplicate(true)
		t.set(field, anim.duplicate(true))
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		if t == null:
			return
		t.set(field, old.duplicate(true))
		doc.touch("structure")


class SetMasterValue extends "res://doc/commands/command.gd":
	var anim: Dictionary = {}
	var old: Dictionary = {}
	var audio: bool = true

	func _init(p_seq_id: String, p_anim: Dictionary) -> void:
		label = "Record master volume"
		seq_id = p_seq_id
		anim = p_anim.duplicate(true)

	func live_key() -> String:
		return "clip_param|seq:" + seq_id + "|master_volume"

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = s.master_volume.duplicate(true)
		s.master_volume = anim.duplicate(true)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			return
		s.master_volume = old.duplicate(true)
		doc.touch("meta")


static func _node(name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null


static func ensure_prefs() -> void:
	var prefs: Node = _node("Prefs")
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_REDUCTION)):
		prefs.call("register", PREF_REDUCTION, "low", {"label": "Recording: key reduction", "type": "enum", "choices": Array(REDUCTIONS)})
	if not bool(prefs.call("is_registered", PREF_SMOOTH)):
		prefs.call("register", PREF_SMOOTH, false, {"label": "Recording: smooth the recorded keys", "type": "bool"})
	if not bool(prefs.call("is_registered", PREF_KEEP)):
		prefs.call("register", PREF_KEEP, false, {"label": "Recording: keep keys already in the recorded span", "type": "bool"})


static func _pref(key: String, fallback: Variant) -> Variant:
	ensure_prefs()
	var prefs: Node = _node("Prefs")
	if prefs == null:
		return fallback
	var v: Variant = prefs.call("get_value", key)
	return fallback if v == null else v


static func recording() -> bool:
	var s: Node = _node("Session")
	return s != null and bool(s.get("recording"))


static func playing() -> bool:
	var s: Node = _node("Session")
	return s != null and bool(s.get("playing"))


static func label_for(path: String) -> String:
	if PATH_LABELS.has(path):
		return String(PATH_LABELS[path])
	var parts: PackedStringArray = path.split(".")
	return parts[parts.size() - 1].replace("_", " ")


static func frame_of(c: Clip, seq: Sequence, playhead: float) -> int:
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	return int(round((playhead - c.start) * fps))


static func key_time_of_frame(c: Clip, seq: Sequence, frame: int, path: String) -> float:
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	var local: float = float(frame) / fps
	if c.has_method("param_time"):
		return float(c.call("param_time", path, local))
	if c.has_method("anim_time"):
		return float(c.call("anim_time", local))
	return local


static func key_time(c: Clip, seq: Sequence, playhead: float, path: String) -> float:
	return key_time_of_frame(c, seq, frame_of(c, seq, playhead), path)


static func seq_frame_of(seq: Sequence, playhead: float) -> int:
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	return int(round(playhead * fps))


static func seq_time_of_frame(seq: Sequence, frame: int) -> float:
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	return float(frame) / fps


static func clip_target(clip_id: String, path: String) -> Dictionary:
	return {"kind": KIND_CLIP, "clip_id": clip_id, "path": path}


static func track_target(track_id: String, field: String) -> Dictionary:
	return {"kind": KIND_TRACK, "track_id": track_id, "path": field}


static func master_target() -> Dictionary:
	return {"kind": KIND_MASTER, "path": MASTER_FIELD}


static func target_key(tg: Dictionary) -> String:
	var kind: String = String(tg.get("kind", KIND_CLIP))
	if kind == KIND_TRACK:
		return "track:" + String(tg.get("track_id", "")) + "|" + String(tg.get("path", ""))
	if kind == KIND_MASTER:
		return "master|" + MASTER_FIELD
	return String(tg.get("clip_id", "")) + "|" + String(tg.get("path", ""))


static func target_label(tg: Dictionary) -> String:
	var kind: String = String(tg.get("kind", KIND_CLIP))
	if kind == KIND_TRACK:
		return "Record track " + String(tg.get("path", ""))
	if kind == KIND_MASTER:
		return "Record master volume"
	return "Record " + label_for(String(tg.get("path", "")))


static func target_prop(seq: Sequence, tg: Dictionary) -> Dictionary:
	var kind: String = String(tg.get("kind", KIND_CLIP))
	if kind == KIND_TRACK:
		var t: Track = seq.track_by_id(String(tg.get("track_id", "")))
		if t == null:
			return {}
		var v: Variant = t.get(String(tg.get("path", "")))
		return v if v is Dictionary else {}
	if kind == KIND_MASTER:
		return seq.master_volume
	var c: Clip = seq.clip_by_id(String(tg.get("clip_id", "")))
	return c.get_param(String(tg.get("path", ""))) if c != null else {}


static func target_exists(seq: Sequence, tg: Dictionary) -> bool:
	var kind: String = String(tg.get("kind", KIND_CLIP))
	if kind == KIND_TRACK:
		return seq.track_by_id(String(tg.get("track_id", ""))) != null and TRACK_FIELDS.has(String(tg.get("path", "")))
	if kind == KIND_MASTER:
		return true
	return seq.clip_by_id(String(tg.get("clip_id", ""))) != null


static func target_frame(seq: Sequence, tg: Dictionary, playhead: float) -> int:
	if String(tg.get("kind", KIND_CLIP)) != KIND_CLIP:
		return seq_frame_of(seq, playhead)
	var c: Clip = seq.clip_by_id(String(tg.get("clip_id", "")))
	return frame_of(c, seq, playhead) if c != null else seq_frame_of(seq, playhead)


static func target_key_time(seq: Sequence, tg: Dictionary, frame: int) -> float:
	if String(tg.get("kind", KIND_CLIP)) != KIND_CLIP:
		return seq_time_of_frame(seq, frame)
	var c: Clip = seq.clip_by_id(String(tg.get("clip_id", "")))
	if c == null:
		return seq_time_of_frame(seq, frame)
	return key_time_of_frame(c, seq, frame, String(tg.get("path", "")))


static func target_command(seq: Sequence, tg: Dictionary, next: Dictionary) -> Command:
	var kind: String = String(tg.get("kind", KIND_CLIP))
	var cmd: Command
	if kind == KIND_TRACK:
		cmd = SetTrackValue.new(seq.id, String(tg.get("track_id", "")), String(tg.get("path", "")), next)
	elif kind == KIND_MASTER:
		cmd = SetMasterValue.new(seq.id, next)
	else:
		cmd = ClipCmds.SetClipParam.new(seq.id, String(tg.get("clip_id", "")), String(tg.get("path", "")), next)
	cmd.label = target_label(tg)
	return cmd


static func is_writing(clip_id: String, path: String) -> bool:
	return _touched.has(clip_id + "|" + path)


static func is_writing_target(tg: Dictionary) -> bool:
	return _touched.has(target_key(tg))


static func active() -> bool:
	return not _passes.is_empty() or not _touched.is_empty()


static func write(doc: Project, seq: Sequence, clip_id: String, path: String, value: Variant, live: bool, hold: bool = false) -> bool:
	return write_target(doc, seq, clip_target(clip_id, path), value, live, hold)


static func write_track(doc: Project, seq: Sequence, track_id: String, field: String, value: float, live: bool) -> bool:
	return write_target(doc, seq, track_target(track_id, field), value, live, false)


static func write_master(doc: Project, seq: Sequence, value: float, live: bool) -> bool:
	return write_target(doc, seq, master_target(), maxf(value, 0.0), live, false)


static func write_target(doc: Project, seq: Sequence, tg: Dictionary, value: Variant, live: bool, hold: bool = false) -> bool:
	if doc == null or seq == null or not recording():
		return false
	if not target_exists(seq, tg):
		return false
	var k: String = target_key(tg)
	if live:
		_touched[k] = {"target": tg.duplicate(), "value": AnimProp.norm(value), "hold": hold}
		_ensure_watch(doc, seq)
	if live and (playing() or _passes.has(k)):
		_sample(doc, seq, tg, value, hold)
		(_passes[k] as Dictionary).erase("latch")
		return true
	if not live and playing():
		_sample(doc, seq, tg, value, hold)
		(_passes[k] as Dictionary)["latch"] = true
		return true
	var cur: Dictionary = target_prop(seq, tg)
	var base: Dictionary = cur if not cur.is_empty() else AnimProp.make(value)
	var at: float = target_key_time(seq, tg, target_frame(seq, tg, seq.playhead))
	var next: Dictionary = AnimProp.set_key(base, at, value, "hold" if hold else "")
	if next == cur:
		return true
	var cmd: Command = target_command(seq, tg, next)
	if live:
		doc.undo.live(cmd)
		return true
	_run(doc, cmd)
	return true


static func _run(doc: Project, cmd: Command) -> bool:
	var tx: RefCounted = doc.undo.begin(cmd.label)
	tx.call("apply", cmd)
	if bool(tx.call("is_empty")):
		tx.call("abandon")
		return false
	tx.call("commit")
	return true


static func _sample(doc: Project, seq: Sequence, tg: Dictionary, value: Variant, hold: bool) -> void:
	var k: String = target_key(tg)
	var p: Dictionary = _passes.get(k, {})
	if p.is_empty():
		var origin: Dictionary = target_prop(seq, tg).duplicate(true)
		var from_t: float = target_key_time(seq, tg, target_frame(seq, tg, seq.playhead))
		p = {"target": tg.duplicate(), "clip_id": String(tg.get("clip_id", "")), "seq_id": seq.id, "path": String(tg.get("path", "")), "origin": origin, "samples": {}, "held": AnimProp.norm(value), "hold": hold or AnimProp.is_discrete_value(value), "last": PackedInt32Array(), "tail": keys_after(origin, from_t)}
		_passes[k] = p
		_ensure_watch(doc, seq)
	p["held"] = AnimProp.norm(value)
	_add_sample(p, target_frame(seq, tg, seq.playhead))
	_apply_live(doc, seq, p)


static func _ensure_watch(doc: Project, seq: Sequence) -> void:
	var session: Node = _node("Session")
	if session == null:
		return
	if _watch == null:
		_watch = Watch.new()
	_watch.doc_ref = weakref(doc)
	_watch.seq_id = seq.id
	for pair: Array in WATCH_SIGNALS:
		var cb: Callable = Callable(_watch, String(pair[1]))
		if session.has_signal(String(pair[0])) and not session.is_connected(String(pair[0]), cb):
			session.connect(String(pair[0]), cb)


static func _drop_watch() -> void:
	var session: Node = _node("Session")
	if session == null or _watch == null:
		return
	for pair: Array in WATCH_SIGNALS:
		var cb: Callable = Callable(_watch, String(pair[1]))
		if session.has_signal(String(pair[0])) and session.is_connected(String(pair[0]), cb):
			session.disconnect(String(pair[0]), cb)


static func keys_after(origin: Dictionary, t: float) -> bool:
	for k: Dictionary in AnimProp.keys(origin):
		if float(k.get("t", 0.0)) > t + AnimProp.KEY_TOLERANCE:
			return true
	return false


static func playing_changed(doc: Project, seq: Sequence, on: bool) -> void:
	if doc == null:
		return
	if not on:
		settle(doc)
		return
	if seq == null or not recording() or not doc.undo.has_live():
		return
	for k: Variant in _touched.keys():
		if _passes.has(k):
			continue
		var held: Variant = _touched[k]
		if not (held is Dictionary):
			continue
		var tg: Dictionary = (held as Dictionary)["target"]
		if target_exists(seq, tg):
			_sample(doc, seq, tg, (held as Dictionary)["value"], bool((held as Dictionary)["hold"]))


static func latched() -> int:
	var n: int = 0
	for k: Variant in _passes.keys():
		if bool((_passes[k] as Dictionary).get("latch", false)):
			n += 1
	return n


static func settle(doc: Project) -> bool:
	if doc == null:
		return false
	var level: String = String(_pref(PREF_REDUCTION, "low"))
	var smoothing: bool = bool(_pref(PREF_SMOOTH, false))
	var keep: bool = bool(_pref(PREF_KEEP, false))
	var label: String = ""
	for k: Variant in _passes.keys():
		var p: Dictionary = _passes[k]
		if not bool(p.get("latch", false)):
			continue
		_passes.erase(k)
		var s: Sequence = doc.sequence_by_id(String(p["seq_id"]))
		var tg: Dictionary = p["target"]
		if s == null or not target_exists(s, tg):
			continue
		var hold: bool = bool(p["hold"])
		var pts: Array = final_points(_points(s, p), hold, level, smoothing)
		var interp: String = "hold" if hold else ("auto" if smoothing else "linear")
		doc.undo.live(target_command(s, tg, merge(p["origin"], pts, interp, keep)))
		label = target_label(tg)
	if label.is_empty():
		return false
	if _passes.is_empty() and doc.undo.has_live():
		doc.undo.commit_live(commit_label(doc, label))
	if _passes.is_empty() and _touched.is_empty():
		_drop_watch()
	return true


static func sample_all(doc: Project, seq: Sequence, playhead: float) -> void:
	for k: Variant in _passes.keys():
		var p: Dictionary = _passes[k]
		if String(p["seq_id"]) != seq.id:
			continue
		var tg: Dictionary = p["target"]
		if not target_exists(seq, tg):
			continue
		var f: int = target_frame(seq, tg, playhead)
		var extends_hold: bool = p.has("max_frame") and f > int(p["max_frame"]) and _same(p["max_value"], p["held"]) and not bool(p.get("tail", false))
		if _add_sample(p, f) and not extends_hold:
			_apply_live(doc, seq, p)


static func _same(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		var aa: Array = a
		var bb: Array = b
		if aa.size() != bb.size():
			return false
		for i: int in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= HOLD_EPS * maxf(1.0, absf(float(a)))
	return a == b


static func _add_sample(p: Dictionary, frame: int) -> bool:
	var samples: Dictionary = p["samples"]
	var held: Variant = p["held"]
	var last: PackedInt32Array = p["last"]
	if samples.has(frame):
		if _same(samples[frame], held):
			return false
		var back: Array = p.get("erased", [])
		if back.size() == 3 and int(back[2]) == frame:
			samples[int(back[0])] = back[1]
			last = PackedInt32Array([int(back[0]), frame])
		p["erased"] = []
		samples[frame] = held
		if int(p.get("max_frame", frame)) == frame:
			p["max_value"] = held
		p["last"] = last
		return true
	samples[frame] = held
	p["erased"] = []
	if not p.has("max_frame") or frame >= int(p["max_frame"]):
		p["max_frame"] = frame
		p["max_value"] = held
	if last.size() >= 2:
		var fa: int = last[last.size() - 2]
		var fb: int = last[last.size() - 1]
		if fa < fb and fb < frame and samples.has(fa) and samples.has(fb) and _same(samples[fa], held) and _same(samples[fb], held):
			p["erased"] = [fb, samples[fb], frame]
			samples.erase(fb)
			last.remove_at(last.size() - 1)
	last.append(frame)
	while last.size() > 2:
		last.remove_at(0)
	p["last"] = last
	return true


static func _points(seq: Sequence, p: Dictionary) -> Array:
	var samples: Dictionary = p["samples"]
	var frames: Array = samples.keys()
	frames.sort()
	var tg: Dictionary = p["target"]
	var out: Array = []
	for f: Variant in frames:
		out.append([target_key_time(seq, tg, int(f)), samples[f]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


static func _apply_live(doc: Project, seq: Sequence, p: Dictionary) -> void:
	var pts: Array = _points(seq, p)
	var next: Dictionary = merge(p["origin"], pts, "hold" if bool(p["hold"]) else "linear", bool(_pref(PREF_KEEP, false)))
	doc.undo.live(target_command(seq, p["target"], next))


static func merge(origin: Dictionary, points: Array, interp: String, keep: bool) -> Dictionary:
	var new_keys: Array = []
	for pt: Array in points:
		new_keys.append({"t": float(pt[0]), "v": AnimProp.norm(pt[1]), "i": interp})
	var t0: float = INF
	var t1: float = -INF
	for k: Dictionary in new_keys:
		t0 = minf(t0, float(k["t"]))
		t1 = maxf(t1, float(k["t"]))
	var old_keys: Array = []
	for k: Dictionary in AnimProp.keys(origin):
		var kt: float = float(k.get("t", 0.0))
		var inside: bool = kt >= t0 - AnimProp.KEY_TOLERANCE and kt <= t1 + AnimProp.KEY_TOLERANCE
		if inside and not keep:
			continue
		var clash: bool = false
		for nk: Dictionary in new_keys:
			if absf(float(nk["t"]) - kt) <= AnimProp.KEY_TOLERANCE:
				clash = true
				break
		if not clash:
			old_keys.append(k)
	var all: Array = old_keys + new_keys
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var out: Dictionary
	if AnimProp.is_animated(origin):
		out = origin.duplicate(true)
	else:
		var base: Variant = AnimProp.static_value(origin) if not origin.is_empty() else (new_keys[0]["v"] if not new_keys.is_empty() else 0.0)
		out = {"a": true, "base": AnimProp.norm(base), "layers": []}
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		(out["layers"] as Array).insert(0, {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": []})
		li = 0
	(out["layers"][li] as Dictionary)["keys"] = all
	return out


static func travel(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var first: Variant = values[0]
	var n: int = (first as Array).size() if first is Array else 1
	var span: float = 0.0
	for c: int in n:
		var lo: float = INF
		var hi: float = -INF
		for v: Variant in values:
			var x: float = float((v as Array)[c]) if v is Array else float(v)
			lo = minf(lo, x)
			hi = maxf(hi, x)
		span = maxf(span, hi - lo)
	return span


static func _lerp(a: Variant, b: Variant, f: float) -> Variant:
	if a is Array:
		var out: Array = []
		for i: int in (a as Array).size():
			out.append(lerpf(float(a[i]), float((b as Array)[i]), f))
		return out
	return lerpf(float(a), float(b), f)


static func _distance(a: Variant, b: Variant) -> float:
	if a is Array:
		var m: float = 0.0
		for i: int in (a as Array).size():
			m = maxf(m, absf(float(a[i]) - float((b as Array)[i])))
		return m
	return absf(float(a) - float(b))


static func smooth(points: Array) -> Array:
	var n: int = points.size()
	if n < 3:
		return points.duplicate(true)
	var out: Array = []
	for i: int in n:
		if i == 0 or i == n - 1:
			out.append([points[i][0], points[i][1]])
			continue
		var reach: int = mini(SMOOTH_REACH, mini(i, n - 1 - i))
		var acc: Variant = null
		for j: int in range(i - reach, i + reach + 1):
			var v: Variant = points[j][1]
			if acc == null:
				acc = (v as Array).duplicate() if v is Array else float(v)
			elif acc is Array:
				for c: int in (acc as Array).size():
					acc[c] = float(acc[c]) + float(v[c])
			else:
				acc = float(acc) + float(v)
		var count: float = float(reach * 2 + 1)
		if acc is Array:
			for c: int in (acc as Array).size():
				acc[c] = float(acc[c]) / count
		else:
			acc = float(acc) / count
		out.append([points[i][0], acc])
	return out


static func thin(points: Array, tolerance: float) -> Array:
	var n: int = points.size()
	if n <= 2 or tolerance < 0.0:
		return points.duplicate(true)
	var out: Array = []
	var i: int = 0
	while i < n - 1:
		var best: int = i + 1
		var j: int = i + 2
		while j < n:
			var ok: bool = true
			var ta: float = float(points[i][0])
			var span: float = float(points[j][0]) - ta
			for k: int in range(i + 1, j):
				var f: float = (float(points[k][0]) - ta) / span if span > 0.0 else 0.0
				if _distance(points[k][1], _lerp(points[i][1], points[j][1], f)) > tolerance:
					ok = false
					break
			if not ok:
				break
			best = j
			j += 1
		out.append(points[i])
		i = best
	out.append(points[n - 1])
	return out


static func thin_holds(points: Array) -> Array:
	var out: Array = []
	for pt: Array in points:
		if out.is_empty() or not _same((out[out.size() - 1] as Array)[1], pt[1]):
			out.append(pt)
	return out


static func final_points(points: Array, hold: bool, level: String, smoothing: bool) -> Array:
	if hold:
		return thin_holds(points)
	var pts: Array = smooth(points) if smoothing else points
	var values: Array = []
	for pt: Array in pts:
		values.append(pt[1])
	var frac: float = float(TOLERANCE.get(level, 0.004))
	if frac < 0.0:
		return pts.duplicate(true)
	var tol: float = maxf(frac * travel(values), HOLD_EPS)
	return thin(pts, tol)


static func finish(doc: Project) -> bool:
	_touched = {}
	if _passes.is_empty():
		_drop_watch()
		return false
	var level: String = String(_pref(PREF_REDUCTION, "low"))
	var smoothing: bool = bool(_pref(PREF_SMOOTH, false))
	var keep: bool = bool(_pref(PREF_KEEP, false))
	var passes: Dictionary = _passes
	_passes = {}
	if doc == null:
		_drop_watch()
		return false
	var still: bool = playing() and recording()
	for k: Variant in passes.keys():
		var p: Dictionary = passes[k]
		if still and (bool(p.get("latch", false)) or (p["samples"] as Dictionary).size() <= 1):
			p["latch"] = true
			_passes[k] = p
			continue
		var s: Sequence = doc.sequence_by_id(String(p["seq_id"]))
		if s == null:
			continue
		var tg: Dictionary = p["target"]
		if not target_exists(s, tg):
			continue
		var hold: bool = bool(p["hold"])
		var pts: Array = final_points(_points(s, p), hold, level, smoothing)
		var interp: String = "hold" if hold else ("auto" if smoothing else "linear")
		doc.undo.live(target_command(s, tg, merge(p["origin"], pts, interp, keep)))
	if _passes.is_empty():
		_drop_watch()
	return true


static func cancel() -> void:
	_drop_watch()
	_passes = {}
	_touched = {}


static func commit_label(doc: Project, fallback: String) -> String:
	if doc == null:
		return fallback
	for cmd: Command in doc.undo.live_commands():
		if cmd.label.begins_with("Record "):
			return cmd.label
	return fallback
