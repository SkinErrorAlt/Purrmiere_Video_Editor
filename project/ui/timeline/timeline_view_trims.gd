extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const ViewTrims := preload("res://doc/view_trims.gd")
const ANIM_PATH := "res://ui/timeline/timeline_trim_anim.gd"
const EPS := 0.000001

static var mended: int = 0


static func mend(shot: Dictionary) -> void:
	var d: Project = shot.get("doc", null)
	var s: Sequence = shot.get("seq", null)
	var post: Dictionary = ViewTrims.take(d, s)
	if post.is_empty():
		return
	mended += 1
	var p: float = float(shot.get("playhead", 0.0))
	var at: Array[Clip] = shot.get("at", [] as Array[Clip])
	var at_vals: PackedFloat64Array = shot.get("at_vals", PackedFloat64Array())
	var seen: Dictionary = {}
	for i: int in at.size():
		var c: Clip = at[i]
		seen[c.id] = true
		if post.has(c.id):
			var v: PackedFloat64Array = (post[c.id] as Dictionary)["vals"]
			at_vals[i * 2] = v[0]
			at_vals[i * 2 + 1] = v[1]
	for id: Variant in post.keys():
		var pc: Clip = s.clip_by_id(String(id))
		var v2: PackedFloat64Array = (post[id] as Dictionary)["vals"]
		if pc == null or seen.has(pc.id) or not (p > v2[0] - EPS and p < v2[0] + v2[1] + EPS):
			continue
		at.append(pc)
		at_vals.append(v2[0])
		at_vals.append(v2[1])
	shot["at"] = at
	shot["at_vals"] = at_vals
	if not bool(shot.get("animate", false)) or bool(shot.get("dense", false)):
		return
	var captured: Array[Clip] = shot.get("clips", [] as Array[Clip])
	var vals: PackedFloat64Array = shot.get("vals", PackedFloat64Array())
	var have: Dictionary = {}
	for i: int in captured.size():
		var c: Clip = captured[i]
		have[c.id] = true
		if post.has(c.id):
			var v3: PackedFloat64Array = (post[c.id] as Dictionary)["vals"]
			vals[i * 3] = v3[0]
			vals[i * 3 + 1] = v3[1]
			vals[i * 3 + 2] = v3[2]
	var keyed: Dictionary = shot.get("keyed", {})
	var anim: GDScript = load(ANIM_PATH)
	for id2: Variant in post.keys():
		var pc2: Clip = s.clip_by_id(String(id2))
		if pc2 == null:
			continue
		var row: Dictionary = post[id2]
		var v4: PackedFloat64Array = row["vals"]
		if not have.has(pc2.id):
			captured.append(pc2)
			vals.append(v4[0])
			vals.append(v4[1])
			vals.append(v4[2])
		keyed[pc2.get_instance_id()] = anim.call("_key_times", Clip.from_dict(row["dict"]))
	shot["clips"] = captured
	shot["vals"] = vals
	shot["keyed"] = keyed
