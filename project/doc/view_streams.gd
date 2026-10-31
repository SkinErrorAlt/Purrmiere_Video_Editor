extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const Sequence := preload("res://doc/sequence.gd")
const MediaItem := preload("res://doc/media_item.gd")
const MODE_KEY := "mode"
const MODE_STREAMS := "streams"
const MODE_TRACKS := "tracks"
const PICKS_KEY := "streams"
const NAMES_PROP := "stream_names"
const SILENT := -1
const ALWAYS_KEY := "always"
const ALWAYS_EVERY_KEY := "always_every"


static func always(map: Dictionary, track_id: String) -> bool:
	var own_list: Variant = map.get(ALWAYS_KEY, null)
	if own_list is Array and (own_list as Array).has(track_id):
		return true
	var every_list: Variant = map.get(ALWAYS_EVERY_KEY, null)
	return every_list is Array and (every_list as Array).has(track_id)


static func on(map: Dictionary) -> bool:
	return String(map.get(MODE_KEY, MODE_TRACKS)) == MODE_STREAMS


static func own(c: Clip) -> int:
	if c == null:
		return 0
	return int(c.audio.get("stream", 0.0))


static func applies(map: Dictionary, c: Clip, video: Clip) -> bool:
	if not on(map) or c == null or video == null or c.media_id.is_empty() or c.media_id != video.media_id:
		return false
	return String(c.audio.get("render", "")).is_empty()


static func _view(map: Dictionary, index: int) -> Dictionary:
	var views: Variant = map.get("views", [])
	if not (views is Array) or index < 0 or index >= (views as Array).size():
		return {}
	var v: Variant = (views as Array)[index]
	return v if v is Dictionary else {}


static func hears(map: Dictionary, index: int, track_id: String, clip_id: String) -> bool:
	var v: Dictionary = _view(map, index)
	for cid: Variant in v.get("clips", []):
		if String(cid) == clip_id:
			return true
	for tid: Variant in v.get("tracks", []):
		if String(tid) == track_id:
			return true
	return false


static func picked_anywhere(map: Dictionary, track_id: String) -> bool:
	if not on(map):
		return false
	var views: Variant = map.get("views", [])
	if not (views is Array):
		return false
	for v: Variant in (views as Array):
		if not (v is Dictionary):
			continue
		var picks: Variant = (v as Dictionary).get(PICKS_KEY, {})
		if picks is Dictionary and (picks as Dictionary).has(track_id):
			return true
	return false


static func governs(map: Dictionary, track_id: String, clip_id: String) -> bool:
	if always(map, track_id):
		return false
	var views: Variant = map.get("views", [])
	if views is Array:
		for i: int in (views as Array).size():
			if hears(map, i, track_id, clip_id):
				return true
	return picked_anywhere(map, track_id)


static func pick(map: Dictionary, index: int, track_id: String) -> int:
	var picks: Variant = _view(map, index).get(PICKS_KEY, {})
	if not (picks is Dictionary) or not (picks as Dictionary).has(track_id):
		return SILENT
	return int((picks as Dictionary)[track_id])


static func played(map: Dictionary, index: int, track_id: String, c: Clip, video: Clip) -> int:
	if c == null or not hears(map, index, track_id, c.id):
		return SILENT
	if not applies(map, c, video):
		return own(c)
	var p: int = pick(map, index, track_id)
	return p if p >= 0 else own(c)


static func plays(map: Dictionary, index: int, track_id: String, c: Clip, video: Clip, stream: int) -> bool:
	var want: int = stream if stream >= 0 else own(c)
	var p: int = played(map, index, track_id, c, video)
	return p >= 0 and p == want


static func views_playing(map: Dictionary, track_id: String, c: Clip, video: Clip, stream: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var views: Variant = map.get("views", [])
	if not (views is Array):
		return out
	for i: int in (views as Array).size():
		if plays(map, i, track_id, c, video, stream):
			out.append(i)
	return out


static func streams_of(map: Dictionary, track_id: String, c: Clip, video: Clip) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var views: Variant = map.get("views", [])
	if not (views is Array):
		return out
	for i: int in (views as Array).size():
		var p: int = played(map, i, track_id, c, video)
		if p >= 0 and not out.has(p):
			out.append(p)
	out.sort()
	return out


static func extra_of(map: Dictionary, track_id: String, c: Clip, video: Clip) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not applies(map, c, video):
		return out
	var mine: int = own(c)
	for s: int in streams_of(map, track_id, c, video):
		if s != mine:
			out.append(s)
	return out


static func hearing_groups(map: Dictionary, track_id: String, c: Clip, video: Clip) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if not applies(map, c, video):
		var all: PackedInt32Array = PackedInt32Array()
		var views: Variant = map.get("views", [])
		if views is Array:
			for i: int in (views as Array).size():
				if hears(map, i, track_id, c.id):
					all.append(i)
		out.append(all)
		return out
	for s: int in streams_of(map, track_id, c, video):
		out.append(views_playing(map, track_id, c, video, s))
	return out


static func family(video: Clip, c: Clip) -> bool:
	if video == null or c == null:
		return false
	if not video.link_id.is_empty() and video.link_id == c.link_id:
		return true
	return not video.group_id.is_empty() and video.group_id == c.group_id


static func named_clip(map: Dictionary, clip_id: String) -> bool:
	for v: Variant in map.get("views", []):
		if not (v is Dictionary):
			continue
		for cid: Variant in (v as Dictionary).get("clips", []):
			if String(cid) == clip_id:
				return true
	return false


static func file_clips(seq: Sequence, video: Clip, map: Dictionary, tr: Track) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or video == null or tr == null:
		return out
	var wide: bool = String(map.get("scope", "group")) != "group"
	for c: Clip in tr.clips:
		if c == video or c.media_id != video.media_id or not tr.is_sound(c):
			continue
		if c.end() <= video.start or c.start >= video.end():
			continue
		if wide or family(video, c) or named_clip(map, c.id):
			out.append(c)
	return out


static func carriers(seq: Sequence, video: Clip, map: Dictionary) -> Array[Track]:
	var out: Array[Track] = []
	if seq == null or video == null:
		return out
	for tr: Track in seq.sound_carriers():
		if not file_clips(seq, video, map, tr).is_empty():
			out.append(tr)
	return out


static func first_stream(seq: Sequence, video: Clip, map: Dictionary, tr: Track) -> int:
	var list: Array[Clip] = file_clips(seq, video, map, tr)
	if list.is_empty():
		return 0
	var best: Clip = list[0]
	for c: Clip in list:
		if c.start <= video.start and c.end() > video.start:
			best = c
			break
	return own(best)


static func normal(map: Dictionary, count: int) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	if out.is_empty():
		out = {"v": 1, "scope": "group", "views": []}
	var views: Array = out.get("views", []) if out.get("views", []) is Array else []
	while views.size() < count:
		views.append({"tracks": [], "clips": [], "colour": -1})
	while views.size() > count and count > 0:
		views.remove_at(views.size() - 1)
	out["views"] = views
	return out


static func to_streams(map: Dictionary, seq: Sequence, video: Clip) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	out[MODE_KEY] = MODE_STREAMS
	var views: Array = out.get("views", [])
	for i: int in views.size():
		var v: Dictionary = views[i]
		var had: Dictionary = v.get(PICKS_KEY, {}) if v.get(PICKS_KEY, {}) is Dictionary else {}
		var picks: Dictionary = {}
		for tid: Variant in v.get("tracks", []):
			var id: String = String(tid)
			if had.has(id):
				picks[id] = int(had[id])
				continue
			var tr: Track = seq.track_by_id(id) if seq != null else null
			if tr != null and not file_clips(seq, video, map, tr).is_empty():
				picks[id] = first_stream(seq, video, map, tr)
		for hid: Variant in had.keys():
			if not picks.has(String(hid)) and int(had[hid]) < 0:
				picks[String(hid)] = SILENT
		v[PICKS_KEY] = picks
	out["views"] = views
	return out


static func to_tracks(map: Dictionary) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	out.erase(MODE_KEY)
	return out


static func with_pick(map: Dictionary, index: int, track_id: String, stream: int) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	var views: Array = out.get("views", [])
	if index < 0 or index >= views.size():
		return out
	var v: Dictionary = views[index]
	var picks: Dictionary = v.get(PICKS_KEY, {}) if v.get(PICKS_KEY, {}) is Dictionary else {}
	var tracks: Array = v.get("tracks", []) if v.get("tracks", []) is Array else []
	var at: int = -1
	for i: int in tracks.size():
		if String(tracks[i]) == track_id:
			at = i
	if stream >= 0:
		picks[track_id] = stream
		if at < 0:
			tracks.append(track_id)
	else:
		picks[track_id] = SILENT
		if at >= 0:
			tracks.remove_at(at)
	v[PICKS_KEY] = picks
	v["tracks"] = tracks
	return out


static func count(item: MediaItem) -> int:
	if item == null:
		return 0
	if not item.audio_streams.is_empty():
		return item.audio_streams.size()
	return 1 if item.has_audio or item.kind == "audio" else 0


static func given_name(item: MediaItem, ordinal: int) -> String:
	return StreamOrdinals.given(item, ordinal)


static func file_title(item: MediaItem, ordinal: int) -> String:
	if item == null or ordinal < 0 or ordinal >= item.audio_streams.size():
		return ""
	return String(item.audio_streams[ordinal].get("title", "")).strip_edges()


static func hint_of(item: MediaItem, ordinal: int) -> String:
	var t: String = file_title(item, ordinal)
	return t if not t.is_empty() else "Stream " + str(ordinal + 1)


static func name_of(item: MediaItem, ordinal: int) -> String:
	var n: String = given_name(item, ordinal)
	return n if not n.is_empty() else hint_of(item, ordinal)


static func with_name(item: MediaItem, ordinal: int, text: String) -> Dictionary:
	return StreamOrdinals.props_with_name(item, ordinal, text)


static func info_of(item: MediaItem, ordinal: int) -> String:
	if item == null or ordinal < 0 or ordinal >= item.audio_streams.size():
		return ""
	var sd: Dictionary = item.audio_streams[ordinal]
	var ch: int = int(sd.get("channels", 2))
	var rate: int = int(sd.get("sample_rate", 48000))
	return str(ch) + " ch " + str(rate / 1000) + " kHz"


static func remap_picks(view: Dictionary, remap: Dictionary) -> void:
	var picks: Variant = view.get(PICKS_KEY, null)
	if not (picks is Dictionary) or (picks as Dictionary).is_empty():
		return
	var fresh: Dictionary = {}
	for tid: Variant in (picks as Dictionary).keys():
		fresh[String(remap.get(String(tid), String(tid)))] = (picks as Dictionary)[tid]
	view[PICKS_KEY] = fresh


const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
