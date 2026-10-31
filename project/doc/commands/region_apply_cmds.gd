extends "res://doc/commands/composite.gd"

const RegionApply := preload("res://doc/region_apply.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const TagApply := preload("res://doc/tag_apply.gd")
const TagApplyCmds := preload("res://doc/commands/tag_apply_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const CensorCmds := preload("res://doc/commands/censor_cmds.gd")
const Censor := preload("res://doc/censor.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const REGISTRY := "res://engine/effect_registry.gd"
const HIDE_EFFECT := "plate_blur"
const REGION_TAG := "org_region"
const HIDE_STYLES: Dictionary = {"blur": 0, "pixels": 1, "colour": 2}
const SILENT_DB := -80.0
const KEY_MUTE := "org_mute"
const KEY_SWEAR := "org_swear"
const COME_BACK_LABEL := "Come back: "

var fns: PackedStringArray = PackedStringArray()
var clip_ids: PackedStringArray = PackedStringArray()
var swear_way: String = "censor"
var hide_way: String = "blur"
var done: Dictionary = {}


func _init(p_seq_id: String, p_fns: PackedStringArray, p_clip_ids: PackedStringArray, p_swear_way: String = "censor") -> void:
	label = "Use the organizer regions"
	seq_id = p_seq_id
	fns = p_fns
	clip_ids = p_clip_ids
	swear_way = p_swear_way


func _plan(doc: Project) -> bool:
	var s: Sequence = seq(doc)
	if s == null:
		return false
	done = {}
	for k: String in RegionApply.DONE_KEYS:
		done[k] = 0
	var p: Dictionary = RegionApply.plan(doc, s, fns, clip_ids)
	if p.has(Kinds.FN_COME_BACK):
		_come_back(doc, s, p[Kinds.FN_COME_BACK])
	if p.has(Kinds.FN_SWEAR):
		_swear(doc, s, p[Kinds.FN_SWEAR])
		_hide_picture(doc, s, p[Kinds.FN_SWEAR], false)
	if p.has(Kinds.FN_BLUR):
		_hide_picture(doc, s, p[Kinds.FN_BLUR], true)
	if p.has(Kinds.FN_MUTE):
		done["mute"] = _tag_ops(doc, p[Kinds.FN_MUTE], TagApply.SCOPE_AUDIO, KEY_MUTE)
	if p.has(Kinds.FN_CUT_MUTE):
		done["cut_mute"] = _tag_ops(doc, p[Kinds.FN_CUT_MUTE], TagApply.SCOPE_BOTH, KEY_MUTE)
	if p.has(Kinds.FN_MOVER):
		_mover(doc, s, p[Kinds.FN_MOVER])
	if p.has(Kinds.FN_SPLIT):
		_split(doc, s, p[Kinds.FN_SPLIT])
	if p.has(Kinds.FN_CUT):
		_cut(doc, s, p[Kinds.FN_CUT])
	return not steps.is_empty()


func _tag_ops(doc: Project, list: Array, scope: String, key: String) -> int:
	var n: int = 0
	var tracks: Dictionary = RegionApply.by_track(list)
	for tid: Variant in tracks.keys():
		var spans: PackedVector2Array = RegionApply.merged(tracks[tid])
		if spans.is_empty():
			continue
		var cmd: Command = apply(doc, TagApplyCmds.new(seq_id, spans, key, scope, PackedStringArray([String(tid)]), {"volume_db": SILENT_DB}))
		if cmd.ok:
			n += spans.size()
	return n


func _cut(doc: Project, s: Sequence, list: Array) -> void:
	var spans: PackedVector2Array = RegionApply.merged(list)
	if spans.is_empty():
		return
	var ids: PackedStringArray = PackedStringArray()
	for t: Track in s.all_tracks():
		if not t.locked:
			ids.append(t.id)
	for i: int in range(spans.size() - 1, -1, -1):
		var v: Vector2 = spans[i]
		var cmd: Command = apply(doc, EditCmds.ExtractRange.new(seq_id, v.x, v.y, ids))
		if cmd.ok:
			done["cut"] = int(done["cut"]) + 1


func _split(doc: Project, s: Sequence, list: Array) -> void:
	var edges: Array[float] = []
	var media: Dictionary = {}
	for e: Variant in list:
		media[String((e as Dictionary)["media_id"])] = true
	for v: Vector2 in RegionApply.merged(list):
		edges.append(v.x)
		edges.append(v.y)
	for edge: float in edges:
		var ids: PackedStringArray = PackedStringArray()
		for t: Track in s.all_tracks():
			if t.locked:
				continue
			for c: Clip in t.clips_in_range(edge - RegionApply.EPS, edge + RegionApply.EPS):
				if media.has(c.media_id) and edge > c.start + RegionApply.EPS and edge < c.end() - RegionApply.EPS:
					ids.append(c.id)
		if ids.is_empty():
			continue
		var cmd: Command = apply(doc, EditCmds.SplitClips.new(seq_id, ids, edge, true))
		if cmd.ok:
			done["split"] = int(done["split"]) + 1


func _mover(doc: Project, s: Sequence, list: Array) -> void:
	var tracks: Dictionary = RegionApply.by_track(list)
	for tid: Variant in tracks.keys():
		var t: Track = s.track_by_id(String(tid))
		if t == null:
			continue
		for e: Variant in tracks[tid]:
			var ed: Dictionary = e
			var a: float = float(ed["from"])
			var b: float = float(ed["to"])
			var media_id: String = String(ed["media_id"])
			for edge: float in [a, b]:
				var cut_ids: PackedStringArray = PackedStringArray()
				for c: Clip in t.clips_in_range(edge - RegionApply.EPS, edge + RegionApply.EPS):
					if c.media_id == media_id and edge > c.start + RegionApply.EPS and edge < c.end() - RegionApply.EPS:
						cut_ids.append(c.id)
				if not cut_ids.is_empty():
					apply(doc, EditCmds.SplitClips.new(seq_id, cut_ids, edge, false))
			for c: Clip in t.clips_in_range(a, b):
				if c.media_id != media_id or c.start < a - RegionApply.EPS or c.end() > b + RegionApply.EPS or c.props.has(RegionApply.MOVER_KEY):
					continue
				var props: Dictionary = c.props.duplicate(true)
				props[RegionApply.MOVER_KEY] = String((ed["region"] as Dictionary).get("id", ""))
				apply(doc, ClipCmds.SetClipField.new(seq_id, c.id, "props", props))
				apply(doc, ClipCmds.SetClipField.new(seq_id, c.id, "enabled", false))
				done["mover"] = int(done["mover"]) + 1


func _swear(doc: Project, s: Sequence, list: Array) -> void:
	if swear_way == "beep":
		_swear_beep(doc, s, list)
		return
	var per_clip: Dictionary = {}
	for e: Variant in list:
		var ed: Dictionary = e
		if not bool(ed["sound"]):
			continue
		var cid: String = String(ed["clip_id"])
		if not per_clip.has(cid):
			per_clip[cid] = []
		(per_clip[cid] as Array).append(ed)
	var settings: Dictionary = Censor.new_settings(doc)
	for cid: Variant in per_clip.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if not CensorCmds.editable(doc, s, c):
			continue
		var list_now: Array[Dictionary] = Censor.regions_copy(c)
		var changed: bool = false
		for e: Variant in per_clip[cid]:
			var ed: Dictionary = e
			var t0: float = clampf(float(ed["from"]), c.start, c.end())
			var t1: float = clampf(float(ed["to"]), c.start, c.end())
			if t1 - t0 < Censor.MIN_SPAN:
				continue
			var src: Vector2 = Censor.stored_span(c, t0, t1)
			var already: bool = false
			for r: Dictionary in list_now:
				if absf(float(r.get("from", 0.0)) - src.x) < 0.002 and absf(float(r.get("to", 0.0)) - src.y) < 0.002:
					already = true
			if already:
				continue
			list_now = Censor.added(list_now, Censor.make_region(doc.mint_id("cz"), src.x, src.y, settings), Censor.overlap_allowed())
			done["swear"] = int(done["swear"]) + 1
			changed = true
		if changed:
			apply(doc, CensorCmds.SetRegions.new(seq_id, c.id, list_now, "Swear"))


static func area_of(r: Dictionary) -> Rect2:
	var raw: Variant = r.get("area", null)
	if raw is Array and (raw as Array).size() >= 4:
		var a: Array = raw
		var rect: Rect2 = Rect2(clampf(float(a[0]), 0.0, 1.0), clampf(float(a[1]), 0.0, 1.0), clampf(float(a[2]), 0.0, 1.0), clampf(float(a[3]), 0.0, 1.0))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect
	return Rect2()


static func hide_def() -> Dictionary:
	var reg: RefCounted = load(REGISTRY).call("shared")
	var def: Dictionary = reg.call("get_def", HIDE_EFFECT) if reg != null else {}
	return def


static func mix_keys(c: Clip, a: float, b: float) -> Dictionary:
	var ka: float = c.anim_time(a)
	var kb: float = c.anim_time(b)
	if a <= RegionApply.EPS and b >= c.duration - RegionApply.EPS:
		return AnimProp.make(1.0)
	var p: Dictionary = AnimProp.make(0.0)
	if a > RegionApply.EPS:
		p = AnimProp.set_key(p, c.anim_time(0.0), 0.0, "hold")
	p = AnimProp.set_key(p, ka, 1.0, "hold")
	if b < c.duration - RegionApply.EPS:
		p = AnimProp.set_key(p, kb, 0.0, "hold")
	return p


static func hide_entry(def: Dictionary, uid: String, c: Clip, a: float, b: float, rect: Rect2, way: String, tag: String) -> Dictionary:
	var e: Dictionary = EffectCmds.EffectCommand.entry_from_def(def, uid)
	var params: Dictionary = e["params"]
	var r: Rect2 = rect if rect.size.x > 0.0 and rect.size.y > 0.0 else Rect2(0.0, 0.0, 1.0, 1.0)
	params["top_left"] = AnimProp.make([r.position.x, r.position.y])
	params["top_right"] = AnimProp.make([r.end.x, r.position.y])
	params["bottom_right"] = AnimProp.make([r.end.x, r.end.y])
	params["bottom_left"] = AnimProp.make([r.position.x, r.end.y])
	params["style"] = AnimProp.make(int(HIDE_STYLES.get(way, 0)))
	e[EffectCmds.MIX_KEY] = mix_keys(c, a, b)
	e[REGION_TAG] = tag
	return e


static func has_hide(c: Clip, tag: String) -> bool:
	for e: Dictionary in c.effects:
		if String(e.get(REGION_TAG, "")) == tag:
			return true
	return false


func _hide_picture(doc: Project, s: Sequence, list: Array, whole_when_unset: bool) -> void:
	var def: Dictionary = {}
	for e: Variant in list:
		var ed: Dictionary = e
		if not bool(ed["picture"]):
			continue
		var r: Dictionary = ed["region"]
		var rect: Rect2 = area_of(r)
		if rect.size.x <= 0.0 and not whole_when_unset:
			continue
		var c: Clip = s.clip_by_id(String(ed["clip_id"]))
		if c == null:
			continue
		var a: float = clampf(float(ed["from"]) - c.start, 0.0, c.duration)
		var b: float = clampf(float(ed["to"]) - c.start, 0.0, c.duration)
		if b - a < Censor.MIN_SPAN:
			continue
		var tag: String = String(r.get("id", "")) + "@" + str(snappedf(a, 0.001))
		if has_hide(c, tag):
			continue
		if def.is_empty():
			def = hide_def()
			if def.is_empty():
				return
		var uid: String = doc.mint_id("e")
		var cmd: Command = apply(doc, EffectCmds.InsertEffectEntry.new(seq_id, c.id, hide_entry(def, uid, c, a, b, rect, hide_way, tag), uid))
		if cmd.ok:
			done["blur"] = int(done["blur"]) + 1


func _swear_beep(doc: Project, s: Sequence, list: Array) -> void:
	var sound: Array = []
	for e: Variant in list:
		if bool((e as Dictionary)["sound"]):
			sound.append(e)
	if sound.is_empty():
		return
	done["swear"] = _tag_ops(doc, sound, TagApply.SCOPE_AUDIO, KEY_SWEAR)
	var spare: Track = null
	for t: Track in s.audio_tracks:
		if not t.locked and t.clips.is_empty():
			spare = t
			break
	if spare == null:
		return
	var spans: PackedVector2Array = RegionApply.merged(sound)
	apply(doc, TagApplyCmds.new(seq_id, spans, KEY_SWEAR + "_beep", TagApply.SCOPE_AUDIO, PackedStringArray([spare.id]), {"file": "bleep", "file_track": spare.id}))


func _come_back(doc: Project, s: Sequence, list: Array) -> void:
	for v: Vector2 in RegionApply.merged(list):
		var exists: bool = false
		for m: Marker in s.markers:
			if m.kind == "todo" and absf(m.time - v.x) < 0.01 and m.label.begins_with(COME_BACK_LABEL.strip_edges()):
				exists = true
		if exists:
			continue
		var name: String = "Come back"
		for e: Variant in list:
			var ed: Dictionary = e
			if absf(float(ed["from"]) - v.x) < 0.01:
				name = Kinds.name_of(String((ed["region"] as Dictionary).get("kind", "")))
		var d: Dictionary = {"id": doc.mint_id("k"), "time": v.x, "duration": v.y - v.x, "kind": "todo", "label": COME_BACK_LABEL + name}
		var cmd: Command = apply(doc, MarkerCmds.AddMarker.new(seq_id, "", d))
		if cmd.ok:
			done["come_back"] = int(done["come_back"]) + 1
