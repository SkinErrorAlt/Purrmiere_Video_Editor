extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const APPLY_CMDS := "res://doc/commands/region_apply_cmds.gd"
const MOVER_KEY := "region_mover"
const PREF_AUTO_CUT := "organizer.auto_cut_on_place"
const PREF_AUTO_MUTE := "organizer.auto_mute_on_place"
const PREF_SWEAR := "organizer.swear_with"
const SWEAR_WAYS: PackedStringArray = ["censor", "beep"]
const PREF_SKIP := "organizer.skip_movers"
const PREF_SKIP_EXPORT := "organizer.skip_movers_export"
const PREF_HIDE := "organizer.hide_picture_with"
const HIDE_WAYS: PackedStringArray = ["blur", "pixels", "colour"]
const EDITOR_FNS: PackedStringArray = ["split", "cut", "cut_mute", "mute", "mover", "swear", "blur", "come_back"]
const DONE_KEYS: PackedStringArray = ["split", "cut", "mute", "cut_mute", "mover", "swear", "blur", "come_back"]
const EPS := 0.0005

static var _skip_key: String = ""
static var _skip_spans: PackedVector2Array = PackedVector2Array()
static var skip_override: int = -1


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs == null:
		return null
	if not bool(prefs.call("is_registered", PREF_AUTO_CUT)):
		prefs.call("register", PREF_AUTO_CUT, false, {"label": "Cut out dead space regions as soon as a clip is placed", "type": "bool", "hint": "Regions whose kind cuts (like Dead space) are cut from the timeline the moment the clip lands."})
	if not bool(prefs.call("is_registered", PREF_AUTO_MUTE)):
		prefs.call("register", PREF_AUTO_MUTE, false, {"label": "Mute regions as soon as a clip is placed", "type": "bool", "hint": "Regions whose kind mutes are muted the moment the clip lands."})
	if not bool(prefs.call("is_registered", PREF_SWEAR)):
		prefs.call("register", PREF_SWEAR, "censor", {"label": "Swear regions are covered with", "type": "enum", "choices": Array(SWEAR_WAYS), "hint": "censor: the Censor tool with its own sound settings. beep: the sound is muted and a beep is laid on a spare sound track."})
	if not bool(prefs.call("is_registered", PREF_SKIP)):
		prefs.call("register", PREF_SKIP, true, {"label": "Playback jumps over Skip over regions", "type": "bool"})
	if not bool(prefs.call("is_registered", PREF_SKIP_EXPORT)):
		prefs.call("register", PREF_SKIP_EXPORT, true, {"label": "Export jumps over Skip over regions too", "type": "bool", "hint": "The file leaves the skipped pieces out, picture and sound together, the way playback jumps over them."})
	if not bool(prefs.call("is_registered", PREF_HIDE)):
		prefs.call("register", PREF_HIDE, "blur", {"label": "A part of the picture is hidden with", "type": "enum", "choices": Array(HIDE_WAYS), "hint": "Used by Swear and Blur this part when a region has a part of the picture: blur, big pixels or a solid colour."})
	return prefs


static func pref(key: String, fallback: Variant) -> Variant:
	var prefs: Node = register_prefs()
	if prefs == null:
		return fallback
	var v: Variant = prefs.call("get_value", key)
	return fallback if v == null else v


static func plan(doc: Project, seq: Sequence, fns: PackedStringArray, clip_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out: Dictionary = {}
	for fn: String in fns:
		out[fn] = []
	if doc == null or seq == null:
		return out
	for t: Track in seq.all_tracks():
		if t.locked:
			continue
		for c: Clip in t.clips:
			if not clip_ids.is_empty() and not clip_ids.has(c.id):
				continue
			if c.props.has(MOVER_KEY):
				continue
			var item: MediaItem = doc.media_by_id(c.media_id)
			if item == null or not item.is_timed():
				continue
			for e: Dictionary in Regions.on_clip(c, item):
				var r: Dictionary = e["region"]
				var lane: String = String(r.get("lane", ""))
				if lane == Regions.LANE_PICTURE and not t.is_picture(c):
					continue
				if lane == Regions.LANE_SOUND and not t.is_sound(c):
					continue
				var fn: String = Regions.fn_of(r)
				if not out.has(fn):
					continue
				(out[fn] as Array).append({"from": c.start + float(e["from"]), "to": c.start + float(e["to"]), "track_id": t.id, "clip_id": c.id, "media_id": item.id, "region": r, "sound": t.is_sound(c), "picture": t.is_picture(c)})
	return out


static func count(p: Dictionary) -> int:
	var n: int = 0
	for k: Variant in p.keys():
		n += (p[k] as Array).size()
	return n


static func apply(doc: Project, seq: Sequence, fns: PackedStringArray, clip_ids: PackedStringArray = PackedStringArray(), label: String = "") -> Dictionary:
	var out: Dictionary = {"ok": false}
	for k: String in DONE_KEYS:
		out[k] = 0
	if doc == null or seq == null or count(plan(doc, seq, fns, clip_ids)) == 0:
		return out
	var Cmds: GDScript = load(APPLY_CMDS)
	var swear_way: String = String(pref(PREF_SWEAR, "censor"))
	var cmd: Command = Cmds.new(seq.id, fns, clip_ids, swear_way)
	cmd.set("hide_way", hide_way())
	var arr: Array[Command] = [cmd]
	if not Verbs.run(doc, label if not label.is_empty() else "Use the organizer regions", arr):
		return out
	out["ok"] = true
	var done: Dictionary = cmd.get("done")
	for k: Variant in done.keys():
		out[k] = done[k]
	return out


static func merged(list: Array) -> PackedVector2Array:
	var vs: Array[Vector2] = []
	for e: Variant in list:
		var ed: Dictionary = e
		if float(ed["to"]) - float(ed["from"]) > EPS:
			vs.append(Vector2(float(ed["from"]), float(ed["to"])))
	vs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in vs:
		var n: int = out.size()
		if n > 0 and v.x <= out[n - 1].y + EPS:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, v.y))
		else:
			out.append(v)
	return out


static func by_track(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in list:
		var ed: Dictionary = e
		var tid: String = String(ed["track_id"])
		if not out.has(tid):
			out[tid] = []
		(out[tid] as Array).append(ed)
	return out


static func hide_way() -> String:
	var v: String = String(pref(PREF_HIDE, "blur"))
	return v if HIDE_WAYS.has(v) else "blur"


static func skips_on() -> bool:
	if skip_override >= 0:
		return skip_override == 1
	return bool(pref(PREF_SKIP, true))


static func mover_spans(doc: Project, seq: Sequence) -> PackedVector2Array:
	if doc == null or seq == null:
		return PackedVector2Array()
	var key: String = seq.id + "|" + str(doc.serial) + "|" + str(doc.get_instance_id())
	if key == _skip_key:
		return _skip_spans
	var list: Array = []
	for t: Track in seq.all_tracks():
		for c: Clip in t.clips:
			if c.props.has(MOVER_KEY) and not c.enabled:
				list.append({"from": c.start, "to": c.end()})
	_skip_spans = merged(list)
	_skip_key = key
	return _skip_spans


static func past(doc: Project, seq: Sequence, t: float) -> float:
	if doc == null or seq == null or not skips_on():
		return t
	var spans: PackedVector2Array = mover_spans(doc, seq)
	if spans.is_empty():
		return t
	for v: Vector2 in spans:
		if t >= v.x - EPS and t < v.y - EPS:
			return v.y
		if v.x > t:
			break
	return t


static func export_skips_on() -> bool:
	if skip_override >= 0:
		return skip_override == 1
	return skips_on() and bool(pref(PREF_SKIP_EXPORT, true))


static func without(spans: PackedVector2Array, gone: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in spans:
		var a: float = v.x
		for g: Vector2 in gone:
			if g.y <= a + EPS or g.x >= v.y - EPS:
				continue
			if g.x > a + EPS:
				out.append(Vector2(a, g.x))
			a = maxf(a, g.y)
		if v.y - a > EPS:
			out.append(Vector2(a, v.y))
	return out


static func on_frames(spans: PackedVector2Array, origin: float, fps: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if fps <= 0.0:
		return spans
	for v: Vector2 in spans:
		var a: float = origin + round((v.x - origin) * fps) / fps
		var b: float = origin + round((v.y - origin) * fps) / fps
		if b - a < 0.5 / fps:
			continue
		var n: int = out.size()
		if n > 0 and a <= out[n - 1].y + EPS:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, b))
		else:
			out.append(Vector2(a, b))
	return out


static func export_spans(doc: Project, seq: Sequence, spans: PackedVector2Array, fps: float) -> PackedVector2Array:
	if doc == null or seq == null or spans.is_empty() or not export_skips_on():
		return PackedVector2Array()
	var gone: PackedVector2Array = mover_spans(doc, seq)
	if gone.is_empty():
		return PackedVector2Array()
	var kept: PackedVector2Array = without(spans, gone)
	if kept == spans:
		return PackedVector2Array()
	return on_frames(kept, spans[0].x, fps)


static func out_time(spans: PackedVector2Array, t: float) -> float:
	var acc: float = 0.0
	for v: Vector2 in spans:
		if t < v.x:
			return acc
		if t <= v.y:
			return acc + t - v.x
		acc += v.y - v.x
	return acc


static func chapters_through(chapters: Array, spans: PackedVector2Array, origin: float) -> Array:
	var out: Array = []
	var last: float = -1.0
	for c: Variant in chapters:
		if not (c is Dictionary):
			continue
		var d: Dictionary = (c as Dictionary).duplicate()
		var t: float = out_time(spans, origin + float(d.get("t", 0.0)))
		if t <= last + 0.0005:
			continue
		d["t"] = t
		last = t
		out.append(d)
	return out
