extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const ViewMap := preload("res://doc/view_map.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const DROP_KEY := "drop_on_view"
const PREF_DROP_ALL := "pair.drop_on_view_all"
const ADD_LABEL := "Effect on a region"
const WHOLE_LABEL := "Effect on the whole clip"


static func editable(seq: Sequence, c: Clip) -> bool:
	if seq == null or c == null:
		return false
	var tr: Track = seq.track_of(c.id)
	return tr != null and not tr.locked and tr.is_picture(c)


static func add_commands(doc: Project, seq: Sequence, c: Clip, pv_uid: String, index: int, def: Dictionary) -> Array[Command]:
	var cmds: Array[Command] = []
	if doc == null or not editable(seq, c) or not RegionFx.refusal(def).is_empty():
		return cmds
	var e: Dictionary = RegionFx.live_pair(c, pv_uid)
	if e.is_empty() or index < 0 or index >= RegionFx.region_count(e):
		return cmds
	var cr: Dictionary = RegionFx.crop(e, index)
	var name: String = RegionFx.region_name(e, index)
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var mid: String = RegionFx.region_mask_id(c, pv_uid, index)
	var pts: Array = RegionFx.region_points(cr)
	if mid.is_empty():
		mid = doc.mint_id("mask")
		masks.append({"id": mid, "kind": "polygon", "feather": 0.0, "invert": false, "points": pts, "path": "", RegionFx.LINK_KEY: pv_uid, RegionFx.INDEX_KEY: index, "label": name})
	else:
		for m: Dictionary in masks:
			if String(m.get("id", "")) == mid:
				m["points"] = pts
				m["label"] = name
	cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "masks", masks))
	var uid: String = doc.mint_id("e")
	cmds.append(EffectCmds.AddEffect.new(seq.id, c.id, Verbs.effect_def_for_clip(doc, seq, c, def), uid, c.effect_index(pv_uid)))
	cmds.append(EffectCmds.SetMask.new(seq.id, c.id, uid, mid))
	return cmds


static func add(doc: Project, seq: Sequence, c: Clip, pv_uid: String, index: int, def: Dictionary) -> bool:
	var cmds: Array[Command] = add_commands(doc, seq, c, pv_uid, index, def)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, ADD_LABEL, cmds)


static func targets(seq: Sequence, clip_id: String, pv_uid: String, index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null or seq.clip_by_id(clip_id) == null:
		return out
	out.append({"clip": clip_id, "pv": pv_uid, "index": index})
	if not seq.selected_clip_ids.has(clip_id):
		return out
	var c0: Clip = seq.clip_by_id(clip_id)
	var name: String = RegionFx.region_name(RegionFx.live_pair(c0, pv_uid), index)
	for id: String in Verbs.selection(seq):
		if id == clip_id:
			continue
		var hit: Dictionary = RegionFx.match_region(seq.clip_by_id(id), name, index)
		if not hit.is_empty():
			out.append({"clip": id, "pv": String(hit["pv"]), "index": int(hit["index"])})
	return out


static func drop(doc: Project, seq: Sequence, where: Array[Dictionary], def: Dictionary) -> int:
	if doc == null or seq == null:
		return 0
	var cmds: Array[Command] = []
	var done: int = 0
	for w: Dictionary in where:
		var part: Array[Command] = add_commands(doc, seq, seq.clip_by_id(String(w["clip"])), String(w["pv"]), int(w["index"]), def)
		if part.is_empty():
			continue
		cmds.append_array(part)
		done += 1
	if cmds.is_empty() or not Verbs.run(doc, ADD_LABEL, cmds):
		return 0
	return done


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func drop_all_on() -> bool:
	var prefs: Node = _prefs()
	if prefs == null:
		return false
	if not bool(prefs.call("is_registered", PREF_DROP_ALL)):
		prefs.call("register", PREF_DROP_ALL, false, {"label": "Every Pair View with Cut on view changes: an effect dropped on the timeline goes on the view showing where it is dropped", "type": "bool"})
	return bool(prefs.call("get_value", PREF_DROP_ALL))


static func drops_on_view(e: Dictionary) -> bool:
	if e.is_empty() or not ViewMap.cuts_on(e):
		return false
	if drop_all_on():
		return true
	var raw: Variant = (e.get("params", {}) as Dictionary).get(DROP_KEY, null)
	if raw is Dictionary:
		return bool(AnimProp.static_value(raw))
	return true


static func view_target(seq: Sequence, c: Clip, at_t: float) -> Dictionary:
	if seq == null or c == null or at_t < 0.0:
		return {}
	var e: Dictionary = RegionFx.first_pair(c)
	if not drops_on_view(e):
		return {}
	var index: int = ViewSwitch.shown_view(seq, c, e, at_t)
	if index < 0 or index >= RegionFx.region_count(e):
		return {}
	return {"pv": String(e.get("uid", "")), "index": index}


static func drop_split(doc: Project, seq: Sequence, targets: PackedStringArray, def: Dictionary, at_t: float = -1.0) -> int:
	if doc == null or seq == null or not RegionFx.refusal(def).is_empty():
		return -1
	var any_solo: bool = false
	for id: String in targets:
		if not RegionFx.solo_of(seq.clip_by_id(id)).is_empty() or not view_target(seq, seq.clip_by_id(id), at_t).is_empty():
			any_solo = true
	if not any_solo:
		return -1
	var cmds: Array[Command] = []
	for id2: String in targets:
		var c: Clip = seq.clip_by_id(id2)
		if c == null:
			continue
		var solo: Dictionary = RegionFx.solo_of(c)
		if solo.is_empty():
			solo = view_target(seq, c, at_t)
		if not solo.is_empty():
			var part: Array[Command] = add_commands(doc, seq, c, String(solo["pv"]), int(solo["index"]), def)
			if not part.is_empty():
				cmds.append_array(part)
				continue
		cmds.append(EffectCmds.AddEffect.new(seq.id, id2, Verbs.effect_def_for_clip(doc, seq, c, def), doc.mint_id("e")))
	if cmds.is_empty() or not Verbs.run(doc, ADD_LABEL, cmds):
		return 0
	return targets.size()


static func whole_commands(seq: Sequence, c: Clip, uid: String) -> Array[Command]:
	var cmds: Array[Command] = []
	if seq == null or c == null:
		return cmds
	var e: Dictionary = c.effect_by_uid(uid)
	var mid: String = String(e.get("mask", ""))
	var m: Dictionary = RegionFx.mask_by_id(c, mid)
	var link: Dictionary = RegionFx.mask_link(m)
	if e.is_empty() or link.is_empty():
		return cmds
	cmds.append(EffectCmds.SetMask.new(seq.id, c.id, uid, ""))
	var pv_at: int = c.effect_index(String(link["pv"]))
	var from: int = c.effect_index(uid)
	if pv_at >= 0 and from >= 0:
		cmds.append(EffectCmds.ReorderEffect.new(seq.id, c.id, uid, pv_at if from < pv_at else pv_at + 1))
	var shared: bool = false
	for other: Dictionary in c.effects:
		if String(other.get("uid", "")) != uid and String(other.get("mask", "")) == mid:
			shared = true
	if not shared:
		var kept: Array[Dictionary] = []
		for mm: Dictionary in c.masks:
			if String(mm.get("id", "")) != mid:
				kept.append(mm.duplicate(true))
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "masks", kept))
	return cmds


static func to_whole(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = whole_commands(seq, seq.clip_by_id(clip_id), uid)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, WHOLE_LABEL, cmds)


static func remove(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null or c.effect_index(uid) < 0:
		return false
	var cmds: Array[Command] = [EffectCmds.RemoveEffect.new(seq.id, c.id, uid)]
	var mid: String = String(c.effect_by_uid(uid).get("mask", ""))
	var shared: bool = false
	for other: Dictionary in c.effects:
		if String(other.get("uid", "")) != uid and String(other.get("mask", "")) == mid:
			shared = true
	if not shared and not RegionFx.mask_link(RegionFx.mask_by_id(c, mid)).is_empty():
		var kept: Array[Dictionary] = []
		for mm: Dictionary in c.masks:
			if String(mm.get("id", "")) != mid:
				kept.append(mm.duplicate(true))
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "masks", kept))
	return Verbs.run(doc, "Remove effect", cmds)
