extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const CUT := "cut"
const FILES := "files"
const KEEP := "keep"
const KINDS: PackedStringArray = [CUT, FILES, KEEP]
const PLACE := "place"
const MOVE_IN := "move_in"
const REPLACE := "replace"
const TRIM := "trim"
const PAIR := "pair"
const PAIR_PREFIX := "view_"
const EPS := 0.0005

static var last_refusal: String = ""
static var refusal_count: int = 0
static var last_check_us: int = 0
static var _said_at: int = -100000
static var cache_hits: int = 0
const SAY_GAP_MS := 1500
const META := "track_guard_rec"
const TRACK_KEYS: PackedStringArray = ["track_id", "track_ids"]
const ID_KEYS: PackedStringArray = ["clip_id", "clip_ids", "ids", "moves", "entries", "order", "video_id", "writes"]


static func kind_of(t: Track) -> String:
	if t == null or not KINDS.has(t.lock_kind):
		return ""
	return t.lock_kind


static func is_protected(t: Track) -> bool:
	return not kind_of(t).is_empty()


static func guards_sound(t: Track) -> bool:
	var k: String = kind_of(t)
	return k == CUT or k == KEEP


static func kind_name(kind: String) -> String:
	if kind == CUT:
		return "Allow cutting only"
	if kind == FILES:
		return "Only these files"
	if kind == KEEP:
		return "No replace"
	return "No lock kind"


static func tag(t: Track) -> String:
	var k: String = kind_of(t)
	if k == CUT:
		return "Cut only"
	if k == FILES:
		return "Files " + str(t.lock_files.size())
	if k == KEEP:
		return "No replace"
	return ""


static func tip(t: Track) -> String:
	if t == null:
		return "Lock track"
	if t.locked:
		return "Unlock track"
	var k: String = kind_of(t)
	if k == CUT:
		return "Lock track. Now: allow cutting only, nothing can be put on it"
	if k == FILES:
		return "Lock track. Now: only its chosen files (" + str(t.lock_files.size()) + ")"
	if k == KEEP:
		return "Lock track. Now: No replace, nothing may overwrite its clips"
	return "Lock track"


static func media_label(doc: Project, media_id: String) -> String:
	var m: MediaItem = doc.media_by_id(media_id) if doc != null and not media_id.is_empty() else null
	if m == null:
		return "this clip"
	return m.label if not m.label.is_empty() else "this clip"


static func file_allowed(doc: Project, t: Track, media_id: String) -> bool:
	if t == null or media_id.is_empty():
		return false
	if t.lock_files.has(media_id):
		return true
	var m: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if m == null:
		return false
	var root: String = String(m.props.get("subclip_of", ""))
	if not root.is_empty() and t.lock_files.has(root):
		return true
	if m.path.is_empty():
		return false
	for id: String in t.lock_files:
		var other: MediaItem = doc.media_by_id(id)
		if other != null and other.path == m.path:
			return true
	return false


static func refusal(doc: Project, _s: Sequence, t: Track, what: String, media_id: String = "", victim: String = "") -> String:
	if t == null:
		return ""
	var name_: String = t.shown_label()
	if t.locked:
		return name_ + " is locked"
	var k: String = kind_of(t)
	if k.is_empty() or what == TRIM:
		return ""
	if k == CUT:
		if what == PAIR:
			return name_ + " allows cutting only: Pair View cannot change its sound"
		return name_ + " allows cutting only: nothing can be put on it"
	if k == KEEP:
		if what == PAIR:
			return name_ + " has No replace on: Pair View cannot change its sound"
		if what == REPLACE:
			return name_ + " has No replace on: " + (victim if not victim.is_empty() else "its clips") + " would be overwritten"
		return ""
	if what == PAIR:
		return ""
	if file_allowed(doc, t, media_id):
		return ""
	return name_ + " takes only its chosen files: " + media_label(doc, media_id) + " is not one of them"


static func accepts(doc: Project, s: Sequence, t: Track, what: String, media_id: String = "") -> bool:
	return refusal(doc, s, t, what, media_id).is_empty()


static func snapshot(doc: Project) -> Dictionary:
	var out: Dictionary = {}
	if doc == null:
		return out
	for s: Sequence in doc.sequences:
		for t: Track in s.all_tracks():
			if is_protected(t) and not t.locked:
				var r: Dictionary = record_for(doc, t).duplicate()
				r["seq"] = s
				r["track"] = t
				out[s.id + "|" + t.id] = r
	return out


static func record_for(doc: Project, t: Track) -> Dictionary:
	if t.has_meta(META):
		var m: Dictionary = t.get_meta(META)
		var r: Dictionary = m.get("rec", {})
		if int(m.get("serial", -1)) == doc.serial and not r.is_empty() and r["clips"] == t.clips:
			cache_hits += 1
			return r
	var fresh: Dictionary = _record(t)
	t.set_meta(META, {"serial": doc.serial, "rec": fresh})
	return fresh


static func _restamp(doc: Project, s: Sequence, t: Track, r: Dictionary, flat: Array[Command]) -> void:
	if not t.has_meta(META):
		return
	if r["clips"] == t.clips and not touches(flat, s, t):
		var m: Dictionary = t.get_meta(META)
		m["serial"] = doc.serial
	else:
		t.remove_meta(META)


static func touches(flat: Array[Command], s: Sequence, t: Track) -> bool:
	for c: Command in flat:
		for key: String in TRACK_KEYS:
			var tv: Variant = c.get(key)
			if (tv is String and String(tv) == t.id) or (tv is PackedStringArray and (tv as PackedStringArray).has(t.id)):
				return true
		for key2: String in ID_KEYS:
			if _names_clip_on(c.get(key2), s, t):
				return true
	return false


static func _names_clip_on(v: Variant, s: Sequence, t: Track) -> bool:
	if v is String:
		return not String(v).is_empty() and s.track_of(String(v)) == t
	if v is PackedStringArray:
		for id: String in v:
			if s.track_of(id) == t:
				return true
		return false
	if v is Array:
		for x: Variant in v:
			if x is Dictionary:
				var xd: Dictionary = x
				if _names_clip_on(xd.get("id", xd.get("clip_id", "")), s, t):
					return true
			elif _names_clip_on(x, s, t):
				return true
		return false
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if _names_clip_on(k, s, t):
				return true
	return false


static func _record(t: Track) -> Dictionary:
	var ids: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	var media: PackedStringArray = PackedStringArray()
	var labels: PackedStringArray = PackedStringArray()
	var t0: PackedFloat64Array = PackedFloat64Array()
	var dur: PackedFloat64Array = PackedFloat64Array()
	var src: PackedFloat64Array = PackedFloat64Array()
	var rate: PackedFloat64Array = PackedFloat64Array()
	for i: int in t.clips.size():
		var c: Clip = t.clips[i]
		ids[c.id] = i
		order.append(c.id)
		media.append(c.media_id)
		labels.append(c.label)
		t0.append(c.start)
		dur.append(c.duration)
		src.append(c.in_offset)
		rate.append(absf(c.static_speed()))
	return {"clips": t.clips.duplicate(), "ids": ids, "order": order, "media": media, "labels": labels, "t0": t0, "dur": dur, "src": src, "rate": rate}


static func passes(doc: Project, cmds: Array, snap: Dictionary) -> bool:
	if snap.is_empty() or cmds.is_empty():
		return true
	var why: String = check(doc, cmds, snap)
	if why.is_empty():
		return true
	say(why)
	return false


static func say(text: String) -> void:
	var now: int = Time.get_ticks_msec()
	var repeat: bool = text == last_refusal and now - _said_at < SAY_GAP_MS
	last_refusal = text
	refusal_count += 1
	_said_at = now
	if repeat:
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var ev: Node = (loop as SceneTree).root.get_node_or_null("Events")
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)


static func check(doc: Project, cmds: Array, snap: Dictionary) -> String:
	if doc == null or snap.is_empty():
		return ""
	var began: int = Time.get_ticks_usec()
	var flat: Array[Command] = []
	walk(cmds, flat)
	var pieces: Dictionary = pieces_of(flat)
	var why: String = ""
	for rec: Variant in snap.values():
		var r: Dictionary = rec
		var s: Sequence = r["seq"]
		var t: Track = r["track"]
		if doc.sequence_by_id(s.id) != s or s.track_by_id(t.id) != t:
			continue
		why = _check_swaps(doc, s, t, r, flat) if r["clips"] == t.clips else _check_track(doc, s, t, r, pieces)
		if not why.is_empty():
			break
	if why.is_empty():
		why = _check_pair(doc, flat, snap)
	if why.is_empty():
		for rec2: Variant in snap.values():
			var r2: Dictionary = rec2
			_restamp(doc, r2["seq"], r2["track"], r2, flat)
	last_check_us = Time.get_ticks_usec() - began
	return why


static func walk(list: Array, out: Array[Command]) -> void:
	for v: Variant in list:
		if not (v is Command):
			continue
		var c: Command = v
		out.append(c)
		var inner: Variant = c.get("steps")
		if inner is Array:
			walk(inner, out)


static func pieces_of(flat: Array[Command]) -> Dictionary:
	var out: Dictionary = {}
	for c: Command in flat:
		var r: Variant = c.get("right_ids")
		if r is PackedStringArray:
			for id: String in r:
				out[id] = true
		var h: Variant = c.get("hold_id")
		if h is String and not String(h).is_empty():
			out[String(h)] = true
	return out


static func _check_swaps(doc: Project, s: Sequence, t: Track, r: Dictionary, flat: Array[Command]) -> String:
	var ids: Dictionary = r["ids"]
	var media: PackedStringArray = r["media"]
	var labels: PackedStringArray = r["labels"]
	for c: Command in flat:
		var v: Variant = c.get("clip_id")
		if not (v is String) or not ids.has(String(v)):
			continue
		var cl: Clip = s.clip_by_id(String(v))
		var i: int = int(ids[String(v)])
		if cl == null or s.track_of(cl.id) != t or cl.media_id == media[i]:
			continue
		var why: String = refusal(doc, s, t, REPLACE, cl.media_id, labels[i])
		if not why.is_empty():
			return why
	return ""


static func _check_track(doc: Project, s: Sequence, t: Track, r: Dictionary, pieces: Dictionary) -> String:
	var ids: Dictionary = r["ids"]
	var media: PackedStringArray = r["media"]
	var labels: PackedStringArray = r["labels"]
	var arrivals: Array[Clip] = []
	var arrived: Dictionary = {}
	for c: Clip in t.clips:
		var i: int = int(ids.get(c.id, -1))
		if i >= 0:
			if c.media_id != media[i]:
				var swapped: String = refusal(doc, s, t, REPLACE, c.media_id, labels[i])
				if not swapped.is_empty():
					return swapped
			continue
		if pieces.has(c.id):
			continue
		arrivals.append(c)
		arrived[c.id] = true
	for a: Clip in arrivals:
		var why: String = refusal(doc, s, t, PLACE, a.media_id)
		if not why.is_empty():
			return why
		var victim: int = _overwritten(t, r, a, arrived, pieces)
		if victim >= 0:
			var hit: String = refusal(doc, s, t, REPLACE, a.media_id, labels[victim])
			if not hit.is_empty():
				return hit
	return ""


static func _overwritten(t: Track, r: Dictionary, a: Clip, arrived: Dictionary, pieces: Dictionary) -> int:
	var t0: PackedFloat64Array = r["t0"]
	var dur: PackedFloat64Array = r["dur"]
	for j: int in t0.size():
		if t0[j] >= a.end() - EPS:
			break
		if minf(t0[j] + dur[j], a.end()) - maxf(t0[j], a.start) <= EPS:
			continue
		if _remaining(t, r, j, arrived, pieces) < dur[j] - EPS:
			return j
	return -1


static func _remaining(t: Track, r: Dictionary, j: int, arrived: Dictionary, pieces: Dictionary) -> float:
	var own: String = (r["order"] as PackedStringArray)[j]
	var m: String = (r["media"] as PackedStringArray)[j]
	var src0: float = (r["src"] as PackedFloat64Array)[j]
	var rate: float = (r["rate"] as PackedFloat64Array)[j]
	var src1: float = src0 + (r["dur"] as PackedFloat64Array)[j] * rate if rate > 0.0 else INF
	var total: float = 0.0
	for c: Clip in t.clips:
		if arrived.has(c.id):
			continue
		if c.id == own:
			total += c.duration
		elif pieces.has(c.id) and c.media_id == m and c.in_offset >= src0 - EPS and c.in_offset <= src1 + EPS:
			total += c.duration
	return total


static func _check_pair(doc: Project, flat: Array[Command], snap: Dictionary) -> String:
	var guarded: Array[Dictionary] = []
	for rec: Variant in snap.values():
		if guards_sound((rec as Dictionary)["track"]):
			guarded.append(rec)
	if guarded.is_empty():
		return ""
	for c: Command in flat:
		var key: Variant = c.get("key")
		if not (key is String) or not String(key).begins_with(PAIR_PREFIX):
			continue
		var text: String = pair_text(c.get("value"))
		if text.is_empty():
			continue
		for r: Dictionary in guarded:
			var t: Track = r["track"]
			if names_any(text, t):
				return refusal(doc, r["seq"], t, PAIR)
	return ""


static func pair_text(v: Variant) -> String:
	if v is String:
		return v
	if v is Dictionary:
		var d: Dictionary = v
		if d.get("v") is String:
			return String(d["v"])
		return JSON.stringify(d)
	if v is Array:
		return JSON.stringify(v)
	return ""


static func names_any(text: String, t: Track) -> bool:
	if text.contains("\"" + t.id + "\""):
		return true
	for c: Clip in t.clips:
		if text.contains("\"" + c.id + "\""):
			return true
	return false
