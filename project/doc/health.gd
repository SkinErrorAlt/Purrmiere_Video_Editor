extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EPS := 0.00001
const SELF_SCRIPT := preload("res://doc/health.gd")
const CutLinks := preload("res://doc/cut_links.gd")


static func check(project: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if project == null:
		return out
	_check_missing_media(project, out)
	_check_duplicate_track_ids(project, out)
	_check_overlaps(project, out)
	_check_media_bounds(project, out)
	_check_orphan_links(project, out)
	CutLinks.check(project, out)
	_check_nest_cycles(project, out)
	_check_markers(project, out)
	return out


static func fix_all(project: Project) -> int:
	var fixed: int = 0
	for round: int in 4:
		var findings: Array[Dictionary] = check(project)
		var any: bool = false
		for f: Dictionary in findings:
			var fix: Variant = f.get("fix")
			if fix is Callable and (fix as Callable).is_valid():
				(fix as Callable).call()
				fixed += 1
				any = true
		if not any:
			break
	return fixed


static func _finding(kind: String, text: String, fix: Variant = null) -> Dictionary:
	return {"kind": kind, "text": text, "fix": fix}


static func key_of(finding: Dictionary) -> String:
	return String(finding.get("kind", "")) + "|" + String(finding.get("text", ""))


static func has_fix(finding: Dictionary) -> bool:
	var fix: Variant = finding.get("fix")
	return fix is Callable and (fix as Callable).is_valid()


static func find(project: Project, key: String) -> Dictionary:
	for f: Dictionary in check(project):
		if key_of(f) == key:
			return f
	return {}


static func _commit(project: Project, label: String, cmd: FixCommand) -> bool:
	var tx: Variant = project.undo.begin(label)
	tx.apply(cmd)
	if not cmd.ok:
		tx.abandon()
		return false
	tx.commit()
	return true


static func fix_one(project: Project, key: String) -> bool:
	if project == null:
		return false
	var f: Dictionary = find(project, key)
	if f.is_empty() or not has_fix(f):
		return false
	var cmd: FixCommand = FixCommand.new(f["fix"], "Fix: " + String(f.get("text", "")).left(60))
	return _commit(project, cmd.label, cmd)


static func fix_everything(project: Project) -> int:
	if project == null:
		return 0
	var fixable: int = 0
	for f: Dictionary in check(project):
		if has_fix(f):
			fixable += 1
	if fixable == 0:
		return 0
	var cmd: FixCommand = FixCommand.new(Callable(), "Fix every health finding")
	cmd.fix_all = true
	if not _commit(project, cmd.label, cmd):
		return 0
	return cmd.fixed


class FixCommand extends "res://doc/commands/command.gd":
	var fix: Callable = Callable()
	var fix_all: bool = false
	var fixed: int = 0
	var _before: Dictionary = {}
	var _after: Dictionary = {}

	func _init(p_fix: Callable, p_label: String) -> void:
		fix = p_fix
		label = p_label

	static func capture(doc: Project) -> Dictionary:
		var media: Dictionary = {}
		for m: MediaItem in doc.media:
			media[m.id] = m.to_dict()
		var seqs: Dictionary = {}
		for s: Sequence in doc.sequences:
			seqs[s.id] = s.to_dict()
		return {"media": media, "sequences": seqs}

	static func restore(doc: Project, state: Dictionary) -> void:
		var media: Dictionary = state.get("media", {})
		for m: MediaItem in doc.media:
			if media.has(m.id):
				var missing: bool = m.missing
				var handle: int = m.handle
				m.apply_dict(media[m.id])
				m.missing = missing
				m.handle = handle
		var seqs: Dictionary = state.get("sequences", {})
		for s: Sequence in doc.sequences:
			if seqs.has(s.id):
				var sel: PackedStringArray = s.selected_clip_ids.duplicate()
				s.apply_dict(seqs[s.id])
				var keep: PackedStringArray = PackedStringArray()
				for id: String in sel:
					if s.clip_by_id(id) != null:
						keep.append(id)
				s.selected_clip_ids = keep
		doc.touch("structure")

	func do(doc: Project) -> void:
		if not _after.is_empty():
			restore(doc, _after)
			return
		_before = capture(doc)
		if fix_all:
			fixed = SELF_SCRIPT.fix_all(doc)
		elif fix.is_valid():
			fix.call()
			fixed = 1
		if fixed <= 0:
			ok = false
			return
		_after = capture(doc)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		if not _before.is_empty():
			restore(doc, _before)


static func _check_missing_media(project: Project, out: Array[Dictionary]) -> void:
	for m: MediaItem in project.media:
		if m.kind == "sequence" or m.path.is_empty():
			m.missing = false
			continue
		var exists: bool = FileAccess.file_exists(m.path)
		m.missing = not exists
		if not exists:
			out.append(_finding("missing_media", "Media \"" + m.label + "\" is missing at " + m.path, null))


static func _check_duplicate_track_ids(project: Project, out: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for s: Sequence in project.sequences:
		for t: Track in s.all_tracks():
			if seen.has(t.id):
				var dup_track: Track = t
				var seq_ref: Sequence = s
				out.append(_finding("duplicate_track_id", "Track id \"" + t.id + "\" appears twice, second in sequence \"" + s.label + "\"", func() -> void:
					dup_track.id = project.mint_id("t")
					seq_ref.invalidate()
					project.touch("structure")))
			else:
				seen[t.id] = true


static func _check_overlaps(project: Project, out: Array[Dictionary]) -> void:
	for s: Sequence in project.sequences:
		for t: Track in s.all_tracks():
			if not t.is_sorted():
				var track_ref: Track = t
				var seq_ref: Sequence = s
				out.append(_finding("unsorted_track", "Track \"" + t.label + "\" in \"" + s.label + "\" is not sorted by start", func() -> void:
					track_ref.sort_clips()
					seq_ref.invalidate()
					project.touch("structure")))
			for i: int in range(1, t.clips.size()):
				var a: Clip = t.clips[i - 1]
				var b: Clip = t.clips[i]
				if a.end() > b.start + EPS:
					var a_ref: Clip = a
					var b_ref: Clip = b
					var seq_ref2: Sequence = s
					var fix: Callable = func() -> void:
						a_ref.duration = maxf(b_ref.start - a_ref.start, 0.0)
						seq_ref2.invalidate()
						project.touch("structure")
					out.append(_finding("overlap", "Clips \"" + a.label + "\" and \"" + b.label + "\" overlap on track \"" + t.label + "\" in \"" + s.label + "\"", fix))
			for c: Clip in t.clips:
				if c.duration <= 0.0:
					var c_ref: Clip = c
					var seq_ref3: Sequence = s
					out.append(_finding("empty_clip", "Clip \"" + c.label + "\" on track \"" + t.label + "\" has no duration", func() -> void:
						seq_ref3.remove_clip(c_ref.id)
						project.touch("structure")))


static func _check_media_bounds(project: Project, out: Array[Dictionary]) -> void:
	for s: Sequence in project.sequences:
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if c.placeholder or AnimProp.is_animated(c.speed):
					continue
				var item: MediaItem = project.media_by_id(c.media_id)
				if item == null:
					var c_missing: Clip = c
					var seq_missing: Sequence = s
					out.append(_finding("missing_media_item", "Clip \"" + c.label + "\" refers to media \"" + c.media_id + "\" which is not in the project", func() -> void:
						seq_missing.remove_clip(c_missing.id)
						project.touch("structure")))
					continue
				if c.loop or not project.media_is_bounded(item):
					continue
				var md: float = project.media_duration(item)
				if md <= 0.0:
					continue
				var far: float = c.source_out()
				if far > md + EPS:
					var c_ref: Clip = c
					var seq_ref: Sequence = s
					var speed: float = absf(float(c.speed.get("v", 1.0)))
					if speed == 0.0:
						speed = 1.0
					out.append(_finding("past_media_end", "Clip \"" + c.label + "\" runs past the end of \"" + item.label + "\"", func() -> void:
						var allowed: float = (md - c_ref.source_in()) / speed
						c_ref.duration = maxf(allowed, 0.0)
						seq_ref.invalidate()
						project.touch("structure")))


static func _check_orphan_links(project: Project, out: Array[Dictionary]) -> void:
	for s: Sequence in project.sequences:
		var counts: Dictionary = {}
		for c: Clip in s.all_clips():
			if not c.link_id.is_empty():
				counts[c.link_id] = int(counts.get(c.link_id, 0)) + 1
		for c: Clip in s.all_clips():
			if not c.link_id.is_empty() and int(counts.get(c.link_id, 0)) < 2:
				var c_ref: Clip = c
				out.append(_finding("orphan_link", "Clip \"" + c.label + "\" carries link id \"" + c.link_id + "\" with no partner", func() -> void:
					c_ref.link_id = ""
					project.touch("structure")))


static func _check_nest_cycles(project: Project, out: Array[Dictionary]) -> void:
	for s: Sequence in project.sequences:
		for c: Clip in s.all_clips():
			if not c.is_nest():
				continue
			if c.sequence_id == s.id or _reaches(project, c.sequence_id, s.id, {}):
				var c_ref: Clip = c
				var seq_ref: Sequence = s
				out.append(_finding("nest_cycle", "Clip \"" + c.label + "\" in \"" + s.label + "\" nests a sequence that contains this sequence", func() -> void:
					seq_ref.remove_clip(c_ref.id)
					project.touch("structure")))


static func _reaches(project: Project, from_seq: String, target: String, seen: Dictionary) -> bool:
	if seen.has(from_seq):
		return false
	seen[from_seq] = true
	var s: Sequence = project.sequence_by_id(from_seq)
	if s == null:
		return false
	for c: Clip in s.all_clips():
		if c.is_nest():
			if c.sequence_id == target or _reaches(project, c.sequence_id, target, seen):
				return true
	return false


static func _check_markers(project: Project, out: Array[Dictionary]) -> void:
	for s: Sequence in project.sequences:
		var dur: float = s.duration()
		for m: Marker in s.markers:
			if m.time > dur + EPS:
				var m_ref: Marker = m
				var seq_ref: Sequence = s
				out.append(_finding("marker_past_end", "Marker \"" + m.label + "\" sits past the end of \"" + s.label + "\"", func() -> void:
					m_ref.time = dur
					seq_ref.sort_markers()
					project.touch("markers")))
		for c: Clip in s.all_clips():
			for m: Marker in c.markers:
				if m.time > c.duration + EPS or m.time < -EPS:
					var cm_ref: Marker = m
					var c_ref: Clip = c
					out.append(_finding("marker_past_end", "Marker \"" + m.label + "\" sits outside clip \"" + c.label + "\"", func() -> void:
						cm_ref.time = clampf(cm_ref.time, 0.0, c_ref.duration)
						project.touch("markers")))
	for item: MediaItem in project.media:
		if item.markers.is_empty() or not item.is_timed() or not item.probed:
			continue
		var length: float = project.media_duration(item)
		if length <= 0.0:
			continue
		for m: Marker in item.markers:
			if m.time > length + EPS:
				var sm_ref: Marker = m
				var item_ref: MediaItem = item
				out.append(_finding("source_marker_past_end", "Source marker \"" + m.label + "\" sits past the end of \"" + item.label + "\"", func() -> void:
					sm_ref.time = length
					item_ref.markers.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)
					project.touch("markers")))
