extends RefCounted
## Which sound the spectrogram shows: the selected audio clip (or the sound linked to a selected video clip), else
## the sound selected in the bin. Also maps between timeline time and the sound file's own time.

const Verbs := preload("res://doc/verbs.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")


static func find(d: Project, s: Sequence, bin_sel: PackedStringArray = PackedStringArray()) -> Dictionary:
	if d == null:
		return {}
	var c: Clip = selected_sound(s)
	if c != null:
		return for_clip(d, s, c)
	for id: String in bin_sel:
		var m: MediaItem = d.media_by_id(id)
		if has_sound(m):
			return {"media_id": m.id, "path": m.path, "stream": 0, "label": m.label}
	return {}


static func selected_sound(s: Sequence) -> Clip:
	if s == null:
		return null
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id) if c != null else null
		if t != null and t.is_sound(c):
			return c
	for id2: String in Verbs.selection(s):
		var c2: Clip = s.clip_by_id(id2)
		if c2 == null:
			continue
		for other: Clip in s.linked(c2):
			var ot: Track = s.track_of(other.id)
			if ot != null and ot.is_sound(other):
				return other
	return null


static func has_sound(m: MediaItem) -> bool:
	if m == null or m.path.is_empty():
		return false
	return m.kind == "audio" or not m.audio_streams.is_empty()


static func for_clip(d: Project, _s: Sequence, c: Clip) -> Dictionary:
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null:
		return {}
	var path: String = m.path
	var stream: int = int(c.audio.get("stream", 0.0))
	var render: String = str(c.audio.get("render", ""))
	if not render.is_empty() and FileAccess.file_exists(render):
		path = render
		stream = 0
	var a: float = c.source_time_exact(c.start)
	var b: float = c.source_time_exact(c.end())
	return {"clip_id": c.id, "path": path, "stream": stream, "label": c.label if not c.label.is_empty() else m.label, "from": minf(a, b), "to": maxf(a, b)}


static func source_time(_d: Project, s: Sequence, target: Dictionary, playhead: float) -> float:
	var id: String = String(target.get("clip_id", ""))
	if id.is_empty() or s == null:
		return NAN
	var c: Clip = s.clip_by_id(id)
	if c == null or playhead < c.start or playhead > c.end():
		return NAN
	return c.source_time(playhead)


static func timeline_time(s: Sequence, target: Dictionary, src: float) -> float:
	var id: String = String(target.get("clip_id", ""))
	if id.is_empty() or s == null:
		return NAN
	var c: Clip = s.clip_by_id(id)
	if c == null:
		return NAN
	var sp: float = c.static_speed()
	if absf(sp) < 0.0001:
		sp = 1.0
	return clampf(c.start + (src - c.in_offset) / sp, c.start, c.end())
