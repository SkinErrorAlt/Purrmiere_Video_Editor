extends RefCounted

const SELF := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Undo := preload("res://doc/undo.gd")
const FORMAT_VERSION := 1

signal changed(kind: String)
signal history_changed

var id: String = ""
var name: String = ""
var path: String = ""
var description: String = ""
var tags: PackedStringArray = PackedStringArray()
var info: Dictionary = {}
var _hold: int = 0
var _held: Dictionary = {}
var held_emits: int = 0
static var plant_no_hold: bool = false
static var change_frame: int = -1
var created: String = ""
var modified: String = ""
var dirty: bool = false
var media: Array[MediaItem] = []
var sequences: Array[Sequence] = []
var active_sequence_id: String = ""
var bins: PackedStringArray = PackedStringArray()
var presets: Array[Dictionary] = []
var sub_projects: Array[Dictionary] = []
var imported_shaders: Dictionary = {}
var tracking: Dictionary = {}
var view: Dictionary = {}
var next_id: int = 1
var serial: int = 0
var undo: Undo = null


func _init() -> void:
	undo = Undo.new(self)


static func create(project_name: String, video_tracks: int = 3, audio_tracks: int = 3, fps: float = 30.0) -> SELF:
	var p: SELF = SELF.new()
	p.name = project_name
	p.created = Time.get_datetime_string_from_system(true)
	p.modified = p.created
	p.id = p.mint_id("p")
	var s: Sequence = p.add_sequence("Sequence 1", video_tracks, audio_tracks, fps)
	p.active_sequence_id = s.id
	p.dirty = false
	return p


func mint_id(prefix: String) -> String:
	var out: String = prefix + str(next_id)
	next_id += 1
	return out


func touch(kind: String) -> void:
	dirty = true
	serial += 1
	change_frame = Engine.get_process_frames()
	modified = Time.get_datetime_string_from_system(true)
	for s: Sequence in sequences:
		s.invalidate_edits()
	if _hold > 0 and not plant_no_hold:
		_held[kind] = true
		return
	changed.emit(kind)


func hold_changes() -> void:
	_hold += 1


func release_changes() -> void:
	_hold = maxi(_hold - 1, 0)
	if _hold > 0 or _held.is_empty():
		return
	var kinds: Array = _held.keys()
	_held = {}
	held_emits += 1
	for k: Variant in kinds:
		changed.emit(String(k))


func add_sequence(label: String, video_tracks: int, audio_tracks: int, fps: float) -> Sequence:
	var s: Sequence = Sequence.new()
	s.id = mint_id("s")
	s.label = label
	s.fps = fps
	for i: int in video_tracks:
		s.video_tracks.append(make_track("video", "V" + str(i + 1)))
	for i: int in audio_tracks:
		s.audio_tracks.append(make_track("audio", "A" + str(i + 1)))
	sequences.append(s)
	var item: MediaItem = MediaItem.new()
	item.id = mint_id("m")
	item.kind = "sequence"
	item.label = label
	item.sequence_id = s.id
	item.probed = true
	media.append(item)
	return s


func make_track(kind: String, label: String) -> Track:
	var t: Track = Track.new()
	t.id = mint_id("t")
	t.kind = kind
	t.label = label
	return t


func media_by_id(media_id: String) -> MediaItem:
	for m: MediaItem in media:
		if m.id == media_id:
			return m
	return null


func media_for_sequence(sequence_id: String) -> MediaItem:
	for m: MediaItem in media:
		if m.kind == "sequence" and m.sequence_id == sequence_id:
			return m
	return null


func sequence_by_id(sequence_id: String) -> Sequence:
	for s: Sequence in sequences:
		if s.id == sequence_id:
			return s
	return null


func active_sequence() -> Sequence:
	return sequence_by_id(active_sequence_id)


func clip_by_id(clip_id: String) -> Clip:
	for s: Sequence in sequences:
		var c: Clip = s.clip_by_id(clip_id)
		if c != null:
			return c
	return null


func sequence_of_clip(clip_id: String) -> Sequence:
	for s: Sequence in sequences:
		if s.clip_by_id(clip_id) != null:
			return s
	return null


func media_duration(item: MediaItem) -> float:
	if item == null:
		return 0.0
	if item.kind == "sequence":
		var s: Sequence = sequence_by_id(item.sequence_id)
		return s.duration() if s != null else 0.0
	return item.duration


func media_is_bounded(item: MediaItem) -> bool:
	if item == null:
		return false
	return item.kind == "video" or item.kind == "audio" or item.kind == "sequence"


func edit_seconds() -> float:
	return float(info.get("edit_seconds", 0.0))


func add_edit_seconds(dt: float) -> void:
	if dt > 0.0:
		info["edit_seconds"] = edit_seconds() + dt


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "name": name}
	if not description.is_empty():
		d["description"] = description
	if not tags.is_empty():
		d["tags"] = Array(tags)
	if not info.is_empty():
		d["info"] = info.duplicate(true)
	if not created.is_empty():
		d["created"] = created
	if not modified.is_empty():
		d["modified"] = modified
	d["next_id"] = next_id
	var ms: Array = []
	for m: MediaItem in media:
		ms.append(m.to_dict())
	d["media"] = ms
	var ss: Array = []
	for s: Sequence in sequences:
		ss.append(s.to_dict())
	d["sequences"] = ss
	d["active_sequence_id"] = active_sequence_id
	if not bins.is_empty():
		d["bins"] = Array(bins)
	if not presets.is_empty():
		d["presets"] = presets.duplicate(true)
	if not sub_projects.is_empty():
		d["sub_projects"] = sub_projects.duplicate(true)
	load("res://doc/imported_shaders.gd").call("write", self, d)
	load("res://doc/tracking.gd").call("write", self, d)
	return d


static func from_dict(d: Dictionary) -> SELF:
	var p: SELF = SELF.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.description = str(d.get("description", ""))
	p.tags = PackedStringArray()
	for t: Variant in d.get("tags", []):
		p.tags.append(str(t))
	p.info = (d["info"] as Dictionary).duplicate(true) if d.get("info") is Dictionary else {}
	p.created = str(d.get("created", ""))
	p.modified = str(d.get("modified", ""))
	p.next_id = int(d.get("next_id", 1))
	for m: Variant in d.get("media", []):
		if m is Dictionary:
			p.media.append(MediaItem.from_dict(m))
	for s: Variant in d.get("sequences", []):
		if s is Dictionary:
			p.sequences.append(Sequence.from_dict(s))
	p.active_sequence_id = str(d.get("active_sequence_id", ""))
	if p.active_sequence_id.is_empty() and not p.sequences.is_empty():
		p.active_sequence_id = p.sequences[0].id
	p.bins = PackedStringArray()
	for b: Variant in d.get("bins", []):
		p.bins.append(str(b))
	for pr: Variant in d.get("presets", []):
		if pr is Dictionary:
			p.presets.append((pr as Dictionary).duplicate(true))
	for g: Variant in d.get("sub_projects", []):
		if g is Dictionary:
			p.sub_projects.append(_read_sub_project(g))
	load("res://doc/imported_shaders.gd").call("read", p, d)
	load("res://doc/tracking.gd").call("read", p, d)
	p._ensure_next_id()
	p.dirty = false
	return p


static func _read_sub_project(g: Dictionary) -> Dictionary:
	var ids: Array = []
	for v: Variant in g.get("sequences", []):
		ids.append(str(v))
	return {"id": str(g.get("id", "")), "name": str(g.get("name", "")), "sequences": ids}


func _ensure_next_id() -> void:
	var top: int = next_id
	var ids: PackedStringArray = PackedStringArray()
	for m: MediaItem in media:
		ids.append(m.id)
	for g: Dictionary in sub_projects:
		ids.append(str(g.get("id", "")))
	for s: Sequence in sequences:
		ids.append(s.id)
		for t: Track in s.all_tracks():
			ids.append(t.id)
			for c: Clip in t.clips:
				ids.append(c.id)
	for i: String in ids:
		var digits: String = ""
		for j: int in range(i.length() - 1, -1, -1):
			var ch: String = i[j]
			if ch >= "0" and ch <= "9":
				digits = ch + digits
			else:
				break
		if not digits.is_empty() and digits.length() < 18:
			top = maxi(top, int(digits) + 1)
	next_id = top
