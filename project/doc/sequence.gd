extends RefCounted

const SELF := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const MasterAnim := preload("res://doc/anim_prop.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const EDIT_EPS := 0.00001

var id: String = ""
var label: String = ""
var fps: float = 30.0
var width: int = 1920
var height: int = 1080
var sample_rate: int = 48000
var drop_frame: bool = false
var video_tracks: Array[Track] = []
var audio_tracks: Array[Track] = []
var markers: Array[Marker] = []
var in_point: float = -1.0
var out_point: float = -1.0
var playhead: float = 0.0
var pinned: Dictionary = default_pinned()
var master_volume: Dictionary = MasterAnim.make(1.0)
var selected_clip_ids: PackedStringArray = PackedStringArray()
var selected_free: Dictionary = {}
var selected_transition: Dictionary = {}:
	set(value):
		selected_transition = value
		if not selected_free.is_empty():
			selected_free = {}
var picked_clip_ids: PackedStringArray = PackedStringArray()
var selected_track_ids: PackedStringArray = PackedStringArray()
var groups: Array[Dictionary] = []
var link_rules: Array[Dictionary] = []
var marker_layers: Array[Dictionary] = []
var marker_view: Dictionary = {}
var track_view: Dictionary = {}
var free_tracks: bool = false:
	set = set_free_tracks
## Locked regions, see doc/fences.gd: [{"id", "start", "end", "label"}], sorted by start.
var fences: Array = []
var overlap_clips: bool = false

var _clip_map: Dictionary = {}
var _map_valid: bool = false
var _edit_cache: Dictionary = {}


static func default_pinned() -> Dictionary:
	return {"position": "bottom", "height": 0.0, "collapsed": false}


static func master_volume_from(raw: Variant) -> Dictionary:
	if raw is Dictionary and ((raw as Dictionary).has("v") or (raw as Dictionary).has("a")):
		return (raw as Dictionary).duplicate(true)
	if raw is float or raw is int:
		return MasterAnim.make(maxf(float(raw), 0.0))
	return MasterAnim.make(1.0)


func invalidate() -> void:
	_map_valid = false
	_edit_cache = {}
	sync_track_modes()


func invalidate_edits() -> void:
	_edit_cache = {}
	_mark_stacks_changed()


func _ensure_map() -> void:
	if _map_valid:
		return
	_clip_map = {}
	for t: Track in all_tracks():
		for c: Clip in t.clips:
			_clip_map[c.id] = [t, c]
	_map_valid = true


func selected_tracks() -> Array[Track]:
	var out: Array[Track] = []
	for id: String in selected_track_ids:
		var t: Track = track_by_id(id)
		if t != null:
			out.append(t)
	return out


func all_tracks() -> Array[Track]:
	var out: Array[Track] = []
	out.append_array(video_tracks)
	out.append_array(audio_tracks)
	return out


func tracks_of_kind(kind: String) -> Array[Track]:
	return video_tracks if kind == "video" else audio_tracks


func track_by_id(track_id: String) -> Track:
	for t: Track in all_tracks():
		if t.id == track_id:
			return t
	return null


func track_index(track_id: String) -> int:
	for i: int in video_tracks.size():
		if video_tracks[i].id == track_id:
			return i
	for i: int in audio_tracks.size():
		if audio_tracks[i].id == track_id:
			return i
	return -1


func any_free_transition() -> bool:
	for t: Track in video_tracks:
		if not t.free_transitions.is_empty():
			return true
	for t: Track in audio_tracks:
		if not t.free_transitions.is_empty():
			return true
	return false


func track_of_free(ft_id: String) -> Track:
	for t: Track in all_tracks():
		if not FreeTransition.by_id(t.free_transitions, ft_id).is_empty():
			return t
	return null


func free_transition_by_id(ft_id: String) -> Dictionary:
	for t: Track in all_tracks():
		var ft: Dictionary = FreeTransition.by_id(t.free_transitions, ft_id)
		if not ft.is_empty():
			return ft
	return {}


func hold_free(track_id: String, ft_id: String) -> void:
	selected_transition = {}
	selected_clip_ids = PackedStringArray()
	picked_clip_ids = PackedStringArray()
	selected_free = {"track_id": track_id, "id": ft_id}


func held_free() -> Dictionary:
	if selected_free.is_empty():
		return {}
	var tr: Track = track_by_id(String(selected_free.get("track_id", "")))
	var ft_id: String = String(selected_free.get("id", ""))
	if tr == null or FreeTransition.by_id(tr.free_transitions, ft_id).is_empty():
		selected_free = {}
		return {}
	return selected_free


func track_of(clip_id: String) -> Track:
	_ensure_map()
	if _clip_map.has(clip_id):
		return _clip_map[clip_id][0]
	return null


func clip_by_id(clip_id: String) -> Clip:
	_ensure_map()
	if _clip_map.has(clip_id):
		return _clip_map[clip_id][1]
	return null


func all_clips() -> Array[Clip]:
	var out: Array[Clip] = []
	for t: Track in all_tracks():
		out.append_array(t.clips)
	return out


func clip_at(track_id: String, t: float) -> Clip:
	var tr: Track = track_by_id(track_id)
	if tr == null:
		return null
	return tr.clip_at(t)


func insert_clip(track: Track, c: Clip) -> void:
	track.insert_clip(c)
	if _map_valid:
		_clip_map[c.id] = [track, c]
	_edit_cache = {}


func remove_clip(clip_id: String) -> Clip:
	_ensure_map()
	if not _clip_map.has(clip_id):
		return null
	var entry: Array = _clip_map[clip_id]
	var tr: Track = entry[0]
	var c: Clip = entry[1]
	if not tr.erase_clip(c, c.start):
		return null
	_clip_map.erase(clip_id)
	_edit_cache = {}
	return c


func remove_clips(ids: PackedStringArray) -> Array[Dictionary]:
	var wanted: Dictionary = {}
	for id: String in ids:
		wanted[id] = true
	var out: Array[Dictionary] = []
	for t: Track in all_tracks():
		var hit: bool = false
		for c: Clip in t.clips:
			if wanted.has(c.id):
				hit = true
				break
		if not hit:
			continue
		var keep: Array[Clip] = []
		for c: Clip in t.clips:
			if wanted.has(c.id):
				out.append({"track_id": t.id, "clip": c})
				if _map_valid:
					_clip_map.erase(c.id)
			else:
				keep.append(c)
		t.clips = keep
		t.mark_changed()
	_edit_cache = {}
	return out


func move_clips(list: Array[Dictionary]) -> void:
	var wanted: Dictionary = {}
	for m: Dictionary in list:
		wanted[str(m["id"])] = m
	var lifted: Dictionary = {}
	var lifted_kind: Dictionary = {}
	for t: Track in all_tracks():
		var hit: bool = false
		for c: Clip in t.clips:
			if wanted.has(c.id):
				hit = true
				break
		if not hit:
			continue
		var keep: Array[Clip] = []
		for c: Clip in t.clips:
			if wanted.has(c.id):
				lifted[c.id] = c
				lifted_kind[c.id] = t.clip_kind(c)
			else:
				keep.append(c)
		t.clips = keep
		t.mark_changed()
	var per_track: Dictionary = {}
	for id: String in wanted.keys():
		if not lifted.has(id):
			continue
		var m: Dictionary = wanted[id]
		var c: Clip = lifted[id]
		c.start = float(m["start"])
		var tid: String = str(m["track_id"])
		if not per_track.has(tid):
			per_track[tid] = []
		(per_track[tid] as Array).append(c)
	for tid: String in per_track.keys():
		var t: Track = track_by_id(tid)
		if t == null:
			continue
		var incoming: Array = per_track[tid]
		for c: Clip in incoming:
			c.part = t.part_for(String(lifted_kind.get(c.id, t.kind)))
		if incoming.size() * 16 > t.clips.size():
			for c: Clip in incoming:
				t.clips.append(c)
			t.sort_clips()
			t.scan_modes()
		else:
			for c: Clip in incoming:
				t.insert_clip(c)
		if _map_valid:
			for c: Clip in incoming:
				_clip_map[c.id] = [t, c]
	_edit_cache = {}


func resort(track: Track) -> void:
	track.sort_clips()
	_edit_cache = {}


func resort_clip(track: Track, c: Clip, old_start: float) -> void:
	track.reposition(c, old_start)
	_edit_cache = {}


func duration() -> float:
	var e: float = 0.0
	for t: Track in all_tracks():
		e = maxf(e, t.end_time())
	return e


func edit_points(only_targeted: bool = false) -> PackedFloat64Array:
	if _edit_cache.has(only_targeted):
		return _edit_cache[only_targeted]
	var pts: PackedFloat64Array = PackedFloat64Array()
	for t: Track in all_tracks():
		if t.locked:
			continue
		if only_targeted and not t.targeted:
			continue
		for c: Clip in t.clips:
			pts.append(c.start)
			pts.append(c.end())
	pts.sort()
	var unique: PackedFloat64Array = PackedFloat64Array()
	for p: float in pts:
		if unique.is_empty() or p - unique[unique.size() - 1] > EDIT_EPS:
			unique.append(p)
	_edit_cache[only_targeted] = unique
	return unique


func next_edit(t: float, only_targeted: bool = false) -> float:
	var pts: PackedFloat64Array = edit_points(only_targeted)
	var lo: int = 0
	var hi: int = pts.size()
	var limit: float = t + EDIT_EPS
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if pts[mid] <= limit:
			lo = mid + 1
		else:
			hi = mid
	if lo < pts.size():
		return pts[lo]
	return -1.0


func prev_edit(t: float, only_targeted: bool = false) -> float:
	var pts: PackedFloat64Array = edit_points(only_targeted)
	var lo: int = 0
	var hi: int = pts.size()
	var limit: float = t - EDIT_EPS
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if pts[mid] < limit:
			lo = mid + 1
		else:
			hi = mid
	if lo > 0:
		return pts[lo - 1]
	return -1.0


func sync_locked_tracks() -> Array[Track]:
	var out: Array[Track] = []
	for t: Track in all_tracks():
		if t.sync_lock and not t.locked:
			out.append(t)
	return out


func clips_overlapping(track: Track, t0: float, t1: float) -> Array[Clip]:
	var out: Array[Clip] = []
	for c: Clip in track.clips_in_range(t0, t1):
		if c.end() > t0 + EDIT_EPS and c.start < t1 - EDIT_EPS:
			out.append(c)
	return out



func visual_track_delta(kind: String, steps: int) -> int:
	if free_tracks:
		return steps
	return steps if kind == "video" else -steps


func was_picked(clip_id: String) -> bool:
	return picked_clip_ids.is_empty() or picked_clip_ids.has(clip_id)


func set_free_tracks(on: bool) -> void:
	free_tracks = on
	sync_track_modes()


func sync_track_modes() -> void:
	var n: int = 0
	for i: int in range(video_tracks.size() - 1, -1, -1):
		n += 1
		video_tracks[i].free = free_tracks
		video_tracks[i].free_number = n
	for t: Track in audio_tracks:
		n += 1
		t.free = free_tracks
		t.free_number = n


func _mark_stacks_changed() -> void:
	for t: Track in video_tracks:
		if t.can_stack:
			t.mark_changed()
	for t: Track in audio_tracks:
		if t.can_stack:
			t.mark_changed()


func top_down_tracks() -> Array[Track]:
	var out: Array[Track] = []
	for i: int in range(video_tracks.size() - 1, -1, -1):
		out.append(video_tracks[i])
	out.append_array(audio_tracks)
	return out


func bottom_up_tracks() -> Array[Track]:
	var out: Array[Track] = top_down_tracks()
	out.reverse()
	return out


func hop_list(track: Track) -> Array[Track]:
	if free_tracks:
		return bottom_up_tracks()
	return tracks_of_kind(track.kind)


func mixed_pictures() -> bool:
	for t: Track in audio_tracks:
		if t.foreign:
			return true
	return false


func mixed_sounds() -> bool:
	for t: Track in video_tracks:
		if t.foreign:
			return true
	return false


func picture_tracks() -> Array[Track]:
	if not free_tracks and not mixed_pictures():
		return video_tracks
	var out: Array[Track] = []
	for i: int in range(audio_tracks.size() - 1, -1, -1):
		out.append(audio_tracks[i])
	out.append_array(video_tracks)
	return out


func extra_sound_tracks() -> Array[Track]:
	var out: Array[Track] = []
	if not free_tracks and not mixed_sounds():
		return out
	for i: int in range(video_tracks.size() - 1, -1, -1):
		out.append(video_tracks[i])
	return out


func sound_carriers() -> Array[Track]:
	var out: Array[Track] = []
	out.append_array(audio_tracks)
	out.append_array(extra_sound_tracks())
	return out


func track_below(track: Track) -> Track:
	var list: Array[Track] = top_down_tracks()
	var i: int = list.find(track)
	if i < 0 or i + 1 >= list.size():
		return null
	return list[i + 1]


func display_label(track: Track) -> String:
	if track == null:
		return ""
	return track.shown_label()


func track_at_offset(track: Track, delta: int) -> Track:
	var list: Array[Track] = hop_list(track)
	var i: int = list.find(track)
	if i < 0:
		return track
	return list[clampi(i + delta, 0, list.size() - 1)]


func linked(c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if c == null:
		return out
	if c.link_id.is_empty():
		out.append(c)
		return out
	for other: Clip in all_clips():
		if other.link_id == c.link_id:
			out.append(other)
	return out


func group_members(c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if c == null:
		return out
	if c.group_id.is_empty():
		out.append(c)
		return out
	for other: Clip in all_clips():
		if other.group_id == c.group_id:
			out.append(other)
	return out


const GROUP_COLOURS := 16
const GROUP_NAME := "Group"


static func default_group(group_id: String, name_: String, colour_: int) -> Dictionary:
	return {"id": group_id, "name": name_, "colour": colour_, "locked": false, "muted": false, "was_off": []}


static func clean_group(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var g: Dictionary = v
	var gid: String = str(g.get("id", ""))
	if gid.is_empty():
		return {}
	var off: Array = []
	for x: Variant in g.get("was_off", []):
		off.append(str(x))
	var out: Dictionary = {"id": gid, "name": str(g.get("name", GROUP_NAME)), "colour": int(g.get("colour", 0)), "locked": bool(g.get("locked", false)), "muted": bool(g.get("muted", false)), "was_off": off}
	if not str(g.get("parent", "")).is_empty():
		out["parent"] = str(g.get("parent", ""))
	return out


static func groups_from(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for e: Variant in v:
			var g: Dictionary = clean_group(e)
			if not g.is_empty():
				out.append(g)
	return out


func groups_to_array() -> Array:
	var out: Array = []
	for g: Dictionary in groups:
		out.append(g.duplicate(true))
	return out


static func default_link_rule(link_id: String) -> Dictionary:
	return {"id": link_id, "as_one": false, "fill": false}


static func clean_link_rule(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var r: Dictionary = v
	var lid: String = str(r.get("id", ""))
	if lid.is_empty():
		return {}
	return {"id": lid, "as_one": bool(r.get("as_one", false)), "fill": bool(r.get("fill", false))}


static func link_rules_from(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for e: Variant in v:
			var r: Dictionary = clean_link_rule(e)
			if not r.is_empty():
				out.append(r)
	return out


func link_rules_to_array() -> Array:
	var out: Array = []
	for r: Dictionary in link_rules:
		out.append(r.duplicate(true))
	return out


func link_rule(link_id: String) -> Dictionary:
	if not link_id.is_empty():
		for r: Dictionary in link_rules:
			if String(r.get("id", "")) == link_id:
				return r.duplicate(true)
	return default_link_rule(link_id)


func set_link_rule(link_id: String, as_one: bool, fill: bool) -> void:
	if link_id.is_empty():
		return
	for i: int in link_rules.size():
		if String(link_rules[i].get("id", "")) == link_id:
			if as_one or fill:
				link_rules[i] = {"id": link_id, "as_one": as_one, "fill": fill}
			else:
				link_rules.remove_at(i)
			return
	if as_one or fill:
		link_rules.append({"id": link_id, "as_one": as_one, "fill": fill})


func group_by_id(group_id: String) -> Dictionary:
	for g: Dictionary in groups:
		if String(g.get("id", "")) == group_id:
			return g
	return {}


func group_record(group_id: String) -> Dictionary:
	var g: Dictionary = group_by_id(group_id)
	if not g.is_empty():
		return g
	return default_group(group_id, GROUP_NAME, -1)


func group_clips(group_id: String) -> Array[Clip]:
	var out: Array[Clip] = []
	if group_id.is_empty():
		return out
	for c: Clip in all_clips():
		if c.group_id == group_id:
			out.append(c)
	return out


func group_ids_in_use() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for c: Clip in all_clips():
		if not c.group_id.is_empty() and not out.has(c.group_id):
			out.append(c.group_id)
	return out


func group_locked(c: Clip) -> bool:
	if c == null or c.group_id.is_empty():
		return false
	return bool(group_by_id(c.group_id).get("locked", false))


func next_group_name() -> String:
	var taken: Dictionary = {}
	var used: PackedStringArray = group_ids_in_use()
	for g0: Dictionary in groups:
		if used.has(String(g0.get("id", ""))) and not String(g0.get("parent", "")).is_empty():
			used.append(String(g0.get("parent", "")))
	for g: Dictionary in groups:
		if used.has(String(g.get("id", ""))):
			taken[String(g.get("name", ""))] = true
	var n: int = 1
	while taken.has(GROUP_NAME + " " + str(n)):
		n += 1
	return GROUP_NAME + " " + str(n)


func next_group_colour() -> int:
	return (groups.size() * 5 + 3) % GROUP_COLOURS


func expand_selection(ids: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	var queue: Array[String] = []
	for i: String in ids:
		if not seen.has(i):
			seen[i] = true
			queue.append(i)
	var head: int = 0
	while head < queue.size():
		var c: Clip = clip_by_id(queue[head])
		head += 1
		if c == null:
			continue
		var family: Array[Clip] = linked(c)
		family.append_array(group_members(c))
		for f: Clip in family:
			if not seen.has(f.id):
				seen[f.id] = true
				queue.append(f.id)
	var out: PackedStringArray = PackedStringArray()
	for q: String in queue:
		if clip_by_id(q) != null:
			out.append(q)
	return out


func marker_by_id(marker_id: String) -> Marker:
	for m: Marker in markers:
		if m.id == marker_id:
			return m
	return null


func sort_markers() -> void:
	markers.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "label": label, "fps": fps, "width": width, "height": height, "sample_rate": sample_rate}
	if drop_frame:
		d["drop_frame"] = true
	var vt: Array = []
	for t: Track in video_tracks:
		vt.append(t.to_dict())
	var at: Array = []
	for t: Track in audio_tracks:
		at.append(t.to_dict())
	d["video_tracks"] = vt
	d["audio_tracks"] = at
	if not markers.is_empty():
		var ms: Array = []
		for m: Marker in markers:
			ms.append(m.to_dict())
		d["markers"] = ms
	if in_point >= 0.0:
		d["in_point"] = in_point
	if out_point >= 0.0:
		d["out_point"] = out_point
	if playhead != 0.0:
		d["playhead"] = playhead
	if pinned != default_pinned():
		d["pinned"] = pinned.duplicate(true)
	if master_volume != MasterAnim.make(1.0):
		d["master_volume"] = master_volume.duplicate(true)
	if not groups.is_empty():
		d["groups"] = groups_to_array()
	if not link_rules.is_empty():
		d["link_rules"] = link_rules_to_array()
	if not marker_layers.is_empty():
		d["marker_layers"] = marker_layers.duplicate(true)
	if not marker_view.is_empty():
		d["marker_view"] = marker_view.duplicate(true)
	if not track_view.is_empty():
		d["track_view"] = track_view.duplicate(true)
	if free_tracks:
		d["free_tracks"] = true
	if overlap_clips:
		d["overlap_clips"] = true
	if not fences.is_empty():
		d["fences"] = fences.duplicate(true)
	return d


static func from_dict(d: Dictionary) -> SELF:
	var s: SELF = SELF.new()
	s.apply_dict(d)
	return s


func apply_dict(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	label = str(d.get("label", ""))
	fps = float(d.get("fps", 30.0))
	width = int(d.get("width", 1920))
	height = int(d.get("height", 1080))
	sample_rate = int(d.get("sample_rate", 48000))
	drop_frame = bool(d.get("drop_frame", false))
	video_tracks = []
	for t: Variant in d.get("video_tracks", []):
		if t is Dictionary:
			video_tracks.append(Track.from_dict(t))
	audio_tracks = []
	for t: Variant in d.get("audio_tracks", []):
		if t is Dictionary:
			audio_tracks.append(Track.from_dict(t))
	markers = []
	for m: Variant in d.get("markers", []):
		if m is Dictionary:
			markers.append(Marker.from_dict(m))
	in_point = float(d.get("in_point", -1.0))
	out_point = float(d.get("out_point", -1.0))
	playhead = float(d.get("playhead", 0.0))
	pinned = default_pinned()
	var pd: Variant = d.get("pinned")
	if pd is Dictionary:
		pinned["position"] = str(pd.get("position", "bottom"))
		pinned["height"] = float(pd.get("height", 0.0))
		pinned["collapsed"] = bool(pd.get("collapsed", false))
	master_volume = master_volume_from(d.get("master_volume"))
	groups = groups_from(d.get("groups", []))
	link_rules = link_rules_from(d.get("link_rules", []))
	marker_layers = []
	for e: Variant in d.get("marker_layers", []):
		if e is Dictionary and not str((e as Dictionary).get("id", "")).is_empty():
			marker_layers.append((e as Dictionary).duplicate(true))
	marker_view = (d["marker_view"] as Dictionary).duplicate(true) if d.get("marker_view") is Dictionary else {}
	track_view = (d["track_view"] as Dictionary).duplicate(true) if d.get("track_view") is Dictionary else {}
	free_tracks = bool(d.get("free_tracks", false))
	fences = []
	for fv: Variant in d.get("fences", []):
		if fv is Dictionary and float((fv as Dictionary).get("end", 0.0)) > float((fv as Dictionary).get("start", 0.0)):
			fences.append((fv as Dictionary).duplicate())
	overlap_clips = bool(d.get("overlap_clips", false))
	selected_clip_ids = PackedStringArray()
	selected_transition = {}
	selected_free = {}
	picked_clip_ids = PackedStringArray()
	selected_track_ids = PackedStringArray()
	invalidate()
