extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const Censor := preload("res://doc/censor.gd")
const Verbs := preload("res://doc/verbs.gd")


class SetRegions extends "res://doc/commands/command.gd":
	const CensorModel := preload("res://doc/censor.gd")
	var clip_id: String = ""
	var regions: Array = []
	var old: Array = []
	var old_base: String = ""
	var new_base: String = ""
	var _based: bool = false

	func _init(p_seq_id: String, p_clip_id: String, p_regions: Array, p_label: String = "Censor") -> void:
		label = p_label
		seq_id = p_seq_id
		clip_id = p_clip_id
		regions = p_regions.duplicate(true)

	func live_key() -> String:
		return "censor|" + clip_id

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		old = CensorModel.regions_copy(c)
		old_base = CensorModel.base_of(c)
		if not _based:
			new_base = old_base
			_based = true
		if old == regions:
			ok = false
			return
		CensorModel.write_based(c, regions, new_base)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return
		CensorModel.write_based(c, old, old_base)
		doc.touch("meta")


static func editable(doc: Project, seq: Sequence, c: Clip) -> bool:
	if doc == null or seq == null or c == null:
		return false
	var tr: Track = seq.track_of(c.id)
	if tr == null or tr.locked or seq.group_locked(c):
		return false
	return Censor.takes_censor(doc, c)


static func add(doc: Project, seq: Sequence, spans: Array[Dictionary], settings: Dictionary = {}, overlap: int = -1, label: String = "Censor") -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	if doc == null or seq == null:
		return made
	var use: Dictionary = Censor.new_settings(doc) if settings.is_empty() else Censor.normalised_settings(settings)
	var may_overlap: bool = Censor.overlap_allowed() if overlap < 0 else overlap == 1
	var cmds: Array[Command] = []
	var fresh: Array[Dictionary] = []
	var seen: Dictionary = {}
	for sp: Dictionary in spans:
		var c: Clip = seq.clip_by_id(String(sp.get("clip_id", "")))
		if not editable(doc, seq, c) or seen.has(c.id):
			continue
		var t0: float = clampf(minf(float(sp.get("t0", 0.0)), float(sp.get("t1", 0.0))), c.start, c.end())
		var t1: float = clampf(maxf(float(sp.get("t0", 0.0)), float(sp.get("t1", 0.0))), c.start, c.end())
		if t1 - t0 < Censor.MIN_SPAN:
			continue
		seen[c.id] = true
		var src: Vector2 = Censor.stored_span(c, t0, t1)
		var rid: String = doc.mint_id("cz")
		var list: Array[Dictionary] = Censor.added(Censor.regions(c), Censor.make_region(rid, src.x, src.y, use), may_overlap)
		cmds.append(SetRegions.new(seq.id, c.id, list, label))
		fresh.append({"clip_id": c.id, "region_id": rid, "mid": (src.x + src.y) * 0.5})
	if cmds.is_empty() or not Verbs.run(doc, label, cmds):
		return made
	for f: Dictionary in fresh:
		var c2: Clip = seq.clip_by_id(String(f["clip_id"]))
		var hit: Dictionary = Censor.region_by_id(c2, String(f["region_id"]))
		if hit.is_empty():
			for r: Dictionary in Censor.regions(c2):
				if float(r.get("from", 0.0)) <= float(f["mid"]) + Censor.TOUCH and float(r.get("to", 0.0)) >= float(f["mid"]) - Censor.TOUCH:
					hit = r
					break
		if not hit.is_empty():
			made.append({"clip_id": c2.id, "region_id": String(hit.get("id", ""))})
	return made


static func spans_under(doc: Project, seq: Sequence, tracks: Array[Track], t0: float, t1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var lo: float = minf(t0, t1)
	var hi: float = maxf(t0, t1)
	for tr: Track in tracks:
		for c: Clip in tr.clips_in_range(lo, hi):
			if c.end() <= lo or c.start >= hi:
				continue
			var targets: Array[Clip] = []
			if Censor.takes_censor(doc, c) and not tr.is_picture(c):
				targets.append(c)
			else:
				for f: Clip in seq.linked(c):
					var ft: Track = seq.track_of(f.id)
					if f != c and ft != null and not ft.is_picture(f) and Censor.takes_censor(doc, f):
						targets.append(f)
			for tc: Clip in targets:
				if seen.has(tc.id) or tc.end() <= lo or tc.start >= hi:
					continue
				seen[tc.id] = true
				out.append({"clip_id": tc.id, "t0": maxf(lo, tc.start), "t1": minf(hi, tc.end())})
	return out


static func censor_in_out(doc: Project, seq: Sequence) -> int:
	if doc == null or seq == null or seq.in_point < 0.0 or seq.out_point < 0.0 or seq.out_point - seq.in_point < Censor.MIN_SPAN:
		return -1
	var tracks: Array[Track] = Verbs.working_tracks(seq, "audio")
	var spans: Array[Dictionary] = spans_under(doc, seq, tracks, seq.in_point, seq.out_point)
	return add(doc, seq, spans, {}, -1, "Censor in to out").size()


static func resize(doc: Project, seq: Sequence, clip_id: String, region_id: String, t0: float, t1: float, overlap: int = -1) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if not editable(doc, seq, c) or Censor.region_by_id(c, region_id).is_empty():
		return false
	var a: float = clampf(minf(t0, t1), c.start, c.end())
	var b: float = clampf(maxf(t0, t1), c.start, c.end())
	if b - a < Censor.MIN_SPAN:
		return false
	var src: Vector2 = Censor.stored_span(c, a, b)
	var may_overlap: bool = Censor.overlap_allowed() if overlap < 0 else overlap == 1
	var list: Array[Dictionary] = Censor.resized(Censor.regions(c), region_id, src.x, src.y, may_overlap)
	var cmds: Array[Command] = [SetRegions.new(seq.id, clip_id, list, "Resize censor")]
	return Verbs.run(doc, "Resize censor", cmds)


static func remove(doc: Project, seq: Sequence, clip_id: String, region_id: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if not editable(doc, seq, c) or Censor.region_by_id(c, region_id).is_empty():
		return false
	var list: Array[Dictionary] = Censor.removed(Censor.regions(c), region_id)
	var cmds: Array[Command] = [SetRegions.new(seq.id, clip_id, list, "Delete censor")]
	return Verbs.run(doc, "Delete censor", cmds)


static func restyle(doc: Project, seq: Sequence, clip_id: String, region_id: String, settings: Dictionary) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if not editable(doc, seq, c) or Censor.region_by_id(c, region_id).is_empty():
		return false
	var list: Array[Dictionary] = Censor.restyled(Censor.regions(c), region_id, settings)
	var cmds: Array[Command] = [SetRegions.new(seq.id, clip_id, list, "Censor settings")]
	return Verbs.run(doc, "Censor settings", cmds)
