extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Find := preload("res://doc/picture_find.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const Command := preload("res://doc/commands/command.gd")
const OrganizerCmds := preload("res://doc/commands/organizer_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const LAYOUT_KEY := "pair_layout"
const MADE_FIND := "find"
const MADE_SWITCH := "switch"
const SWITCH_KIND := "come_back"
const SAMPLES_KEY := "samples"


static func spec_of(kind_id: String) -> Dictionary:
	var k: Dictionary = Kinds.by_id(kind_id)
	var raw: Variant = k.get(SAMPLES_KEY, {})
	var d: Dictionary = (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
	if not (d.get("frames") is Array):
		d["frames"] = []
	for key: String in ["focus", "drop"]:
		if not (d.get(key) is Array):
			d[key] = []
	d["threshold"] = clampf(float(d.get("threshold", Find.DEFAULT_THRESHOLD)), 0.3, 0.995)
	d["min_len"] = maxf(float(d.get("min_len", Find.DEFAULT_MIN_LEN)), 0.0)
	d["gap"] = maxf(float(d.get("gap", Find.DEFAULT_GAP)), 0.0)
	d["cut"] = bool(d.get("cut", false))
	d["auto"] = bool(d.get("auto", false))
	d["both"] = bool(d.get("both", true))
	return d


static func save_spec(kind_id: String, spec: Dictionary) -> bool:
	return Kinds.change(kind_id, {SAMPLES_KEY: spec.duplicate(true)})


static func samples(spec: Dictionary) -> Array:
	var out: Array = []
	for f: Variant in spec.get("frames", []):
		if f is Dictionary:
			var s: Dictionary = Find.sample_from_dict(f)
			if not s.is_empty():
				out.append(s)
	return out


static func add_sample(kind_id: String, sample: Dictionary) -> int:
	var spec: Dictionary = spec_of(kind_id)
	(spec["frames"] as Array).append(Find.sample_to_dict(sample))
	save_spec(kind_id, spec)
	return (spec["frames"] as Array).size()


static func layout_key(list: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: Dictionary in list:
		var r: Rect2 = v["rect"]
		parts.append("%s:%.3f,%.3f,%.3f,%.3f" % [String(v.get("name", "")), r.position.x, r.position.y, r.size.x, r.size.y])
	return "pl" + str("|".join(parts).hash())


static func pair_layouts(doc: Project, media_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	var seen: Dictionary = {}
	for s: Sequence in doc.sequences:
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if c.media_id != media_id:
					continue
				for e: Dictionary in c.effects:
					if String(e.get("id", "")) != "pair_view" or not bool(e.get("enabled", true)):
						continue
					var list: Array[Dictionary] = RegionFx.crops(e)
					if list.size() < 2:
						continue
					var key: String = layout_key(list)
					if seen.has(key):
						(out[int(seen[key])] as Dictionary)["clips"] = int((out[int(seen[key])] as Dictionary)["clips"]) + 1
						continue
					var names: PackedStringArray = PackedStringArray()
					for i: int in list.size():
						var n: String = String(list[i].get("name", ""))
						names.append(n if not n.is_empty() else "View %d" % (i + 1))
					seen[key] = out.size()
					out.append({"key": key, "views": list, "names": names, "seq_id": s.id, "clip_id": c.id, "clips": 1, "label": "%s at %s in %s: %s" % [c.label if not c.label.is_empty() else "Clip", _clock(c.start), s.label, ", ".join(names)]})
	return out


static func _clock(t: float) -> String:
	var total: int = int(floor(maxf(t, 0.0)))
	return "%d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60] if total >= 3600 else "%d:%02d" % [total / 60, total % 60]


static func chosen_layout(item: MediaItem) -> String:
	return String(item.props.get(LAYOUT_KEY, "")) if item != null else ""


static func choose_layout(doc: Project, media_id: String, key: String) -> bool:
	if doc == null or doc.media_by_id(media_id) == null:
		return false
	var cmds: Array[Command] = [OrganizerCmds.SetMediaProp.new(media_id, LAYOUT_KEY, key if not key.is_empty() else null, "Pair View layout for finding")]
	return Verbs.run(doc, String(cmds[0].label), cmds)


static func pair_views(doc: Project, media_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array[Dictionary] = pair_layouts(doc, media_id)
	if all.is_empty():
		return out
	var want: String = chosen_layout(doc.media_by_id(media_id))
	for l: Dictionary in all:
		if String(l["key"]) == want:
			return l["views"]
	return all[0]["views"]


static func job_spec(doc: Project, item: MediaItem, kind_id: String, per_view: bool) -> Dictionary:
	var spec: Dictionary = spec_of(kind_id)
	var out: Dictionary = {"path": item.path, "media_id": item.id, "kind": kind_id, "samples": samples(spec), "focus": spec["focus"], "drop": spec["drop"], "threshold": spec["threshold"], "min_len": spec["min_len"], "gap": spec["gap"], "mode": "find", "label": "Finding %s in %s" % [Kinds.name_of(kind_id), item.label]}
	if per_view:
		var views: Array = []
		var names: PackedStringArray = PackedStringArray()
		for v: Dictionary in pair_views(doc, item.id):
			views.append(Find.rect_array(v["rect"]))
			names.append(String(v.get("name", "")))
		if views.size() > 1:
			out["views"] = views
			out["view_names"] = names
	return out


static func switch_spec(item: MediaItem) -> Dictionary:
	return {"path": item.path, "media_id": item.id, "kind": SWITCH_KIND, "samples": [], "mode": "switch", "label": "Looking for scene switches in " + item.label}


static func made_from(result: Dictionary, job: Dictionary, spec: Dictionary) -> Array:
	var out: Array = []
	var kind: String = String(job.get("kind", ""))
	if not bool(result.get("ok", false)):
		return out
	if String(job.get("mode", "find")) == "switch":
		for t: float in (result.get("switches", PackedFloat64Array()) as PackedFloat64Array):
			out.append(Regions.make(kind, maxf(t - 0.25, 0.0), t + Find.SWITCH_LEN - 0.25, {"made": MADE_SWITCH, "note": "Possible scene switch", "come_back": true}))
		return out
	var cut: bool = bool(spec.get("cut", false))
	var views: Array = result.get("views", [])
	if views.size() > 1:
		var names: PackedStringArray = job.get("view_names", PackedStringArray())
		for vi: int in views.size():
			var label: String = names[vi] if vi < names.size() and not names[vi].is_empty() else "View %d" % (vi + 1)
			for v: Vector2 in (views[vi] as PackedVector2Array):
				out.append(Regions.make(kind, v.x, v.y, {"made": MADE_FIND, "note": label, "view": vi, "cut": false}))
		if bool(spec.get("both", true)):
			for v: Vector2 in (result.get("ranges", PackedVector2Array()) as PackedVector2Array):
				out.append(Regions.make(kind, v.x, v.y, {"made": MADE_FIND, "note": "Every view", "cut": cut}))
		return out
	for v: Vector2 in (result.get("ranges", PackedVector2Array()) as PackedVector2Array):
		out.append(Regions.make(kind, v.x, v.y, {"made": MADE_FIND, "cut": cut}))
	return out


static func merged_into(existing: Array, found: Array, kind: String, made: String) -> Array:
	var out: Array = []
	for r: Variant in existing:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		if String(rd.get("kind", "")) == kind and String(rd.get("made", "")) == made:
			continue
		out.append(rd.duplicate(true))
	for r: Variant in found:
		out.append((r as Dictionary).duplicate(true))
	return out


static func apply_result(doc: Project, job: Dictionary, result: Dictionary) -> int:
	var item: MediaItem = doc.media_by_id(String(job.get("media_id", ""))) if doc != null else null
	if item == null or not bool(result.get("ok", false)):
		return -1
	var kind: String = String(job.get("kind", ""))
	var made: String = MADE_SWITCH if String(job.get("mode", "find")) == "switch" else MADE_FIND
	var found: Array = made_from(result, job, spec_of(kind))
	var dur: float = doc.media_duration(item)
	if dur > 0.0:
		for r: Variant in found:
			var rd: Dictionary = r
			rd["to"] = minf(float(rd["to"]), dur)
	var next: Array = merged_into(Regions.list(item), found, kind, made)
	var label: String = ("Find " + Kinds.name_of(kind)) if made == MADE_FIND else "Find scene switches"
	if not Regions.replace(doc, item.id, next, label):
		return 0
	return found.size()
