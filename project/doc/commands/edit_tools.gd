extends RefCounted

const MarkerLayers := preload("res://doc/marker_layers.gd")
const VERSION := 1
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const ToolCmds := preload("res://doc/commands/tool_cmds.gd")
const CutLinks := preload("res://doc/cut_links.gd")
const EPS := 0.00001
const SOURCE_TOLERANCE := 0.001
const PREF_FREEZE_SECONDS := "edit.freeze_seconds"
const PREF_FREEZE_RIPPLE := "edit.freeze_ripple"
const PREF_PREROLL := "playback.preroll"
const PREF_POSTROLL := "playback.postroll"
const PREF_RAZOR_TIME := "timeline.razor_time"
const FADE_SHAPES: PackedStringArray = ["linear", "equal_power", "s_curve"]
const FADE_SHAPE_LABELS: PackedStringArray = ["Linear", "Equal power", "S curve"]
const GAIN_MIN_DB := -80.0
const GAIN_MAX_DB := 24.0
const GAIN_MODES: PackedStringArray = ["set", "adjust", "normalise"]
const SIZE_PRESETS: Array = [[1920, 1080, "1920 x 1080  HD"], [3840, 2160, "3840 x 2160  4K UHD"], [1080, 1920, "1080 x 1920  vertical 9:16"], [1080, 1080, "1080 x 1080  square"], [1080, 1350, "1080 x 1350  portrait 4:5"]]
const FRAME_RATES: Array = [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0, 120.0]
const SAMPLE_RATES: Array = [44100, 48000, 96000]


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func register_prefs() -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	var specs: Array = [
		[PREF_FREEZE_SECONDS, 2.0, {"label": "Freeze frame length (seconds)", "type": "float", "min": 0.04, "max": 600.0}],
		[PREF_FREEZE_RIPPLE, true, {"label": "Freeze frame pushes later clips along", "type": "bool"}],
		[PREF_PREROLL, 2.0, {"label": "Preroll for play around and play in to out (seconds)", "type": "float", "min": 0.0, "max": 60.0}],
		[PREF_POSTROLL, 2.0, {"label": "Postroll for play around and play in to out (seconds)", "type": "float", "min": 0.0, "max": 60.0}],
		[PREF_RAZOR_TIME, true, {"label": "Razor: show the cut time in the ruler", "type": "bool"}],
		[CutLinks.PREF_RAZOR_LINKS, true, {"label": CutLinks.RAZOR_LINKS_LABEL, "type": "bool"}],
		[Verbs.MoveRule.PREF_MOVE_LINKS, true, {"label": Verbs.MoveRule.MOVE_LINKS_LABEL, "type": "bool"}],
		["timeline.slice_groups", true, {"label": "Cutting through a group makes each side a slice of it", "type": "bool"}],
	]
	for spec: Array in specs:
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])


static func pref(key: String, fallback: Variant) -> Variant:
	register_prefs()
	var prefs: Node = _prefs()
	if prefs == null or not bool(prefs.call("is_registered", key)):
		return fallback
	return prefs.call("get_value", key)


static func frame_of(seq: Sequence) -> float:
	if seq == null or seq.fps <= 0.0:
		return 1.0 / 30.0
	return 1.0 / seq.fps


static func snap_frame(seq: Sequence, t: float) -> float:
	var f: float = frame_of(seq)
	return round(t / f) * f


static func ordered_tracks(seq: Sequence, kind: String) -> Array[Track]:
	var out: Array[Track] = []
	var list: Array[Track] = seq.tracks_of_kind(kind)
	if kind == "video":
		for i: int in range(list.size() - 1, -1, -1):
			out.append(list[i])
	else:
		out.append_array(list)
	return out


static func clip_under(seq: Sequence, t: float, kind: String) -> Clip:
	if seq == null:
		return null
	for id: String in Verbs.selection(seq):
		var c: Clip = seq.clip_by_id(id)
		var tr: Track = seq.track_of(id)
		if c != null and tr != null and tr.kind == kind and not tr.locked and t >= c.start - EPS and t < c.end() - EPS:
			return c
	for targeted_only: bool in [true, false]:
		for tr: Track in ordered_tracks(seq, kind):
			if tr.locked or tr.hidden:
				continue
			if targeted_only and not tr.targeted:
				continue
			var c: Clip = tr.clip_at(t)
			if c != null:
				return c
	return null


static func freeze_frame(doc: Project, seq: Sequence, clip_id: String, t: float, length: float, ripple: bool) -> String:
	if doc == null or seq == null or seq.clip_by_id(clip_id) == null or length <= 0.0:
		return ""
	var cmd: Command = ToolCmds.FreezeFrame.new(seq.id, clip_id, snap_frame(seq, t), length, ripple)
	if not Verbs.run(doc, "Freeze frame", [cmd]):
		return ""
	var hold_id: String = String(cmd.get("hold_id"))
	Verbs.select(doc, seq, PackedStringArray([hold_id]), "replace")
	return hold_id


static func hold_to_end(doc: Project, seq: Sequence, clip_id: String, t: float) -> String:
	if doc == null or seq == null or seq.clip_by_id(clip_id) == null:
		return ""
	var cmd: Command = ToolCmds.HoldToEnd.new(seq.id, clip_id, snap_frame(seq, t))
	if not Verbs.run(doc, "Hold this frame to the end", [cmd]):
		return ""
	var hold_id: String = String(cmd.get("hold_id"))
	Verbs.select(doc, seq, PackedStringArray([hold_id]), "replace")
	return hold_id


static func is_hold(c: Clip) -> bool:
	return c != null and not AnimProp.is_animated(c.speed) and absf(float(c.speed.get("v", 1.0))) < EPS


static func match_frame(doc: Project, seq: Sequence, t: float) -> Dictionary:
	if doc == null or seq == null:
		return {}
	var c: Clip = clip_under(seq, t, "video")
	if c == null:
		c = clip_under(seq, t, "audio")
	if c == null:
		return {}
	var src: float = c.source_time(clampf(t, c.start, c.end()))
	var total: float = EditMath.media_duration(doc, c)
	if total > 0.0:
		src = clampf(src, 0.0, total)
	return {"clip_id": c.id, "media_id": c.media_id, "sequence_id": c.sequence_id, "time": maxf(src, 0.0), "in": maxf(c.source_in(), 0.0), "out": c.source_out()}


static func timeline_time_for(c: Clip, src: float) -> float:
	if c == null:
		return -1.0
	if not AnimProp.is_animated(c.speed):
		var sp: float = float(c.speed.get("v", 1.0))
		if absf(sp) < EPS:
			return c.start if absf(src - c.in_offset) <= SOURCE_TOLERANCE * 40.0 else -1.0
		var u: float = (src - c.in_offset) / sp
		if u < -SOURCE_TOLERANCE or u > c.duration + SOURCE_TOLERANCE:
			return -1.0
		return c.start + clampf(u, 0.0, c.duration)
	var n: int = clampi(int(c.duration * 240.0), 16, 20000)
	var prev_u: float = 0.0
	var prev_s: float = c.source_time(c.start)
	if absf(prev_s - src) <= SOURCE_TOLERANCE:
		return c.start
	for i: int in range(1, n + 1):
		var u2: float = c.duration * float(i) / float(n)
		var s2: float = c.source_time(c.start + u2)
		if (prev_s - src) * (s2 - src) <= 0.0 and absf(s2 - prev_s) > 0.0:
			var f: float = (src - prev_s) / (s2 - prev_s)
			return c.start + lerpf(prev_u, u2, clampf(f, 0.0, 1.0))
		prev_u = u2
		prev_s = s2
	return -1.0


static func same_source(doc: Project, a_id: String, b_id: String) -> bool:
	if a_id == b_id:
		return true
	var a: MediaItem = doc.media_by_id(a_id)
	var b: MediaItem = doc.media_by_id(b_id)
	return a != null and b != null and not a.path.is_empty() and a.path == b.path and a.kind == b.kind


static func reverse_match(doc: Project, seq: Sequence, media_id: String, src: float, near: float) -> Dictionary:
	if doc == null or seq == null or media_id.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score: float = INF
	for tr: Track in seq.all_tracks():
		for c: Clip in tr.clips:
			if c.is_nest() or not same_source(doc, c.media_id, media_id):
				continue
			if src < c.source_in() - SOURCE_TOLERANCE or src > c.source_out() + SOURCE_TOLERANCE:
				continue
			var at: float = timeline_time_for(c, src)
			if at < 0.0:
				continue
			var score: float = absf(at - near)
			if seq.selected_clip_ids.has(c.id):
				score -= 1.0e9
			if tr.kind == "video":
				score -= 0.5
			if score < best_score:
				best_score = score
				best = {"clip_id": c.id, "t": at}
	return best


static func subclip_range(item: MediaItem) -> Vector2:
	if item == null or not item.props.has("subclip_in"):
		return Vector2(-1.0, -1.0)
	return Vector2(float(item.props.get("subclip_in", 0.0)), float(item.props.get("subclip_out", -1.0)))


static func is_subclip(item: MediaItem) -> bool:
	return item != null and item.props.has("subclip_in")


static func make_subclip(doc: Project, media_id: String, in_t: float, out_t: float) -> String:
	if doc == null:
		return ""
	var src: MediaItem = doc.media_by_id(media_id)
	if src == null or not (src.kind == "video" or src.kind == "audio"):
		return ""
	var total: float = doc.media_duration(src)
	var a: float = maxf(in_t, 0.0)
	var b: float = out_t if out_t > a else total
	if total > 0.0:
		b = minf(b, total)
	if b - a < 0.01:
		return ""
	var root_id: String = String(src.props.get("subclip_of", src.id))
	var n: int = 1
	for m: MediaItem in doc.media:
		if String(m.props.get("subclip_of", "")) == root_id:
			n += 1
	var base: String = src.label
	if is_subclip(src):
		var root: MediaItem = doc.media_by_id(root_id)
		if root != null:
			base = root.label
	var d: Dictionary = src.to_dict()
	var id: String = doc.mint_id("m")
	d["id"] = id
	d["label"] = base.get_basename() + " subclip " + str(n)
	var props: Dictionary = (d.get("props", {}) as Dictionary).duplicate(true)
	props["subclip_in"] = a
	props["subclip_out"] = b
	props["subclip_of"] = root_id
	d["props"] = props
	d["poster_time"] = a
	if not Verbs.run(doc, "Make subclip", [MediaCmds.AddMedia.new(d)]):
		return ""
	return id


static func place_range(doc: Project, seq: Sequence, media_id: String, track_id: String, t: float, in_t: float, out_t: float, mode: String) -> PackedStringArray:
	var none: PackedStringArray = PackedStringArray()
	if doc == null or seq == null:
		return none
	var item: MediaItem = doc.media_by_id(media_id)
	var target: Track = seq.track_by_id(track_id)
	if item == null or target == null or target.locked or t < 0.0:
		return none
	var total: float = doc.media_duration(item)
	var i0: float = maxf(in_t, 0.0)
	var i1: float = out_t if out_t > i0 else total
	if total > 0.0:
		i1 = minf(i1, total)
	var dur: float = i1 - i0
	if dur <= 0.0:
		return none
	var wants_video: bool = item.has_picture() and target.accepts("video")
	var wants_audio: bool = (item.has_audio or item.kind == "audio" or item.audio_only) and not Verbs.StreamOrdinals.all_off(item)
	var cmds: Array[Command] = []
	var audio_track: Track = Verbs.sound_target(doc, seq, target, wants_video, cmds) if wants_audio else null
	if not wants_video and audio_track == null:
		return none
	var streams: PackedInt32Array = Verbs.selected_streams(item)
	var audio_tracks: Array[Track] = Verbs.audio_tracks_from(doc, seq, audio_track, streams.size(), cmds) if audio_track != null else ([] as Array[Track])
	var seeds: PackedStringArray = PackedStringArray()
	if wants_video:
		seeds.append(target.id)
	for at: Track in audio_tracks:
		if not seeds.has(at.id):
			seeds.append(at.id)
	Verbs.clear_for_place(seq, mode, t, dur, seeds, cmds)
	var link_id: String = doc.mint_id("l") if (wants_video and not audio_tracks.is_empty()) or audio_tracks.size() > 1 else ""
	var new_ids: PackedStringArray = PackedStringArray()
	if wants_video:
		var vid: String = doc.mint_id("c")
		var vd: Dictionary = {"id": vid, "media_id": media_id, "label": item.label, "start": t, "duration": dur, "in_offset": i0}
		if not link_id.is_empty():
			vd["link_id"] = link_id
		var fit: Vector2 = Verbs.frame_fit_scale(seq, item)
		if fit != Vector2.ONE:
			vd["transform"] = {"scale": AnimProp.make([fit.x, fit.y]), "scale_linked": is_equal_approx(fit.x, fit.y)}
		Clip.stamp_auto_loop(item.path, vd)
		Verbs.stamp_place(target, vd, "video", mode)
		cmds.append(ClipCmds.PlaceClip.new(seq.id, target.id, vd))
		new_ids.append(vid)
	for k: int in audio_tracks.size():
		var aid: String = doc.mint_id("c")
		var stream: int = streams[mini(k, streams.size() - 1)]
		var label: String = item.label if streams.size() == 1 else item.label + " " + Verbs.stream_label(item, stream)
		var ad: Dictionary = {"id": aid, "media_id": media_id, "label": label, "start": t, "duration": dur, "in_offset": i0, "audio": {"stream": float(stream)}}
		if not link_id.is_empty():
			ad["link_id"] = link_id
		Clip.stamp_auto_loop(item.path, ad)
		Verbs.stamp_place(audio_tracks[k], ad, "audio", mode)
		cmds.append(ClipCmds.PlaceClip.new(seq.id, audio_tracks[k].id, ad))
		new_ids.append(aid)
	if not Verbs.run(doc, "Place " + item.label, cmds):
		return none
	return new_ids


static func place_subclip(doc: Project, seq: Sequence, media_id: String, track_id: String, t: float, mode: String) -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	var r: Vector2 = subclip_range(item)
	if r.x < 0.0:
		return false
	var ids: PackedStringArray = place_range(doc, seq, media_id, track_id, t, r.x, r.y, mode)
	if ids.is_empty():
		return false
	Verbs.select(doc, seq, ids, "replace")
	return true


static func subclip_payload(doc: Project, payload: Dictionary) -> Dictionary:
	if doc == null or String(payload.get("kind", "")) != "media" or float(payload.get("in", -1.0)) >= 0.0:
		return payload
	var ids: Array = payload.get("ids", [])
	if ids.size() != 1:
		return payload
	var r: Vector2 = subclip_range(doc.media_by_id(String(ids[0])))
	if r.x < 0.0:
		return payload
	var out: Dictionary = payload.duplicate(true)
	out["in"] = r.x
	out["out"] = r.y
	return out


static func replace_targets(seq: Sequence, clip_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return out
	for f: Clip in seq.linked(c):
		if f.media_id == c.media_id and not out.has(f.id):
			out.append(f.id)
	return out


static func replace_with(doc: Project, seq: Sequence, clip_id: String, media_id: String) -> bool:
	if doc == null or seq == null or doc.media_by_id(media_id) == null:
		return false
	var item: MediaItem = doc.media_by_id(media_id)
	if item.kind == "sequence":
		return false
	var fits: PackedStringArray = PackedStringArray()
	for id: String in replace_targets(seq, clip_id):
		var tr: Track = seq.track_of(id)
		if tr == null:
			continue
		var c: Clip = seq.clip_by_id(id)
		if tr.is_picture(c) and not item.has_picture():
			continue
		if tr.is_sound(c) and not (item.has_audio or item.kind == "audio"):
			continue
		fits.append(id)
	if not fits.has(clip_id):
		return false
	return Verbs.replace_media(doc, seq, fits, media_id)


static func is_through(a: Clip, b: Clip) -> bool:
	if a == null or b == null or a == b:
		return false
	if a.media_id != b.media_id or a.sequence_id != b.sequence_id:
		return false
	if absf(a.end() - b.start) > EPS * 10.0:
		return false
	if AnimProp.is_animated(a.speed) or AnimProp.is_animated(b.speed):
		return false
	if absf(float(a.speed.get("v", 1.0)) - float(b.speed.get("v", 1.0))) > EPS:
		return false
	if int(a.audio.get("stream", 0.0)) != int(b.audio.get("stream", 0.0)):
		return false
	if b.has_transition():
		return false
	return absf(a.source_time(a.end()) - b.in_offset) <= SOURCE_TOLERANCE


static func through_pair(seq: Sequence, clip_id: String, t: float) -> PackedStringArray:
	var none: PackedStringArray = PackedStringArray()
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	var tr: Track = seq.track_of(clip_id) if c != null else null
	if tr == null:
		return none
	var near_head: bool = absf(t - c.start) <= absf(t - c.end())
	var prev: Clip = tr.prev_clip(c)
	var next: Clip = tr.next_clip(c)
	if near_head and prev != null and is_through(prev, c):
		return PackedStringArray([prev.id, c.id])
	if not near_head and next != null and is_through(c, next):
		return PackedStringArray([c.id, next.id])
	if prev != null and is_through(prev, c):
		return PackedStringArray([prev.id, c.id])
	if next != null and is_through(c, next):
		return PackedStringArray([c.id, next.id])
	return none


static func heal(doc: Project, seq: Sequence, left_id: String, right_id: String) -> bool:
	if doc == null or seq == null:
		return false
	var a: Clip = seq.clip_by_id(left_id)
	var b: Clip = seq.clip_by_id(right_id)
	if not is_through(a, b):
		return false
	var tr: Track = seq.track_of(a.id)
	if tr == null or tr.locked:
		return false
	var pairs: Array[PackedStringArray] = [PackedStringArray([a.id, b.id])]
	var rights: Array[Clip] = seq.linked(b)
	for f: Clip in seq.linked(a):
		if f == a:
			continue
		var ft: Track = seq.track_of(f.id)
		if ft == null or ft.locked:
			continue
		for g: Clip in rights:
			if g != b and seq.track_of(g.id) == ft and is_through(f, g):
				pairs.append(PackedStringArray([f.id, g.id]))
				break
	return Verbs.run(doc, "Join through edit", [ToolCmds.HealEdit.new(seq.id, pairs)])


static func razor_click(doc: Project, seq: Sequence, clip_id: String, t: float, lane_only: bool, linked: bool = true) -> bool:
	if doc == null or seq == null:
		return false
	return razor_apply(doc, seq, razor_targets(seq, clip_id, t, lane_only, false, linked), t)


static func razor_targets(seq: Sequence, clip_id: String, t: float, lane_only: bool, all_tracks: bool, linked: bool) -> Dictionary:
	var picked: PackedStringArray = PackedStringArray()
	var select: PackedStringArray = PackedStringArray()
	var ids: PackedStringArray = PackedStringArray()
	if seq == null:
		return {"ids": ids, "select": select}
	if all_tracks:
		for tr: Track in seq.all_tracks():
			if tr.locked:
				continue
			for c: Clip in tr.clips_at(t):
				picked.append(c.id)
	else:
		var c: Clip = seq.clip_by_id(clip_id)
		var tr: Track = seq.track_of(clip_id)
		if c == null or tr == null or tr.locked:
			return {"ids": ids, "select": select}
		if lane_only:
			picked.append(clip_id)
		else:
			if seq.selected_clip_ids.has(clip_id):
				picked = Verbs.selection(seq)
			else:
				picked = seq.expand_selection(PackedStringArray([clip_id])) if linked else PackedStringArray([clip_id])
				select = picked.duplicate()
			if linked:
				for id: String in picked.duplicate():
					for f: Clip in seq.linked(seq.clip_by_id(id)):
						if not picked.has(f.id):
							picked.append(f.id)
	for id: String in Verbs.unlocked(seq, picked):
		var cut: Clip = seq.clip_by_id(id)
		if not ids.has(id) and t > cut.start + EditMath.EPS and t < cut.end() - EditMath.EPS:
			ids.append(id)
	return {"ids": ids, "select": select}


static func razor_apply(doc: Project, seq: Sequence, targets: Dictionary, t: float) -> bool:
	if doc == null or seq == null:
		return false
	var select: PackedStringArray = targets.get("select", PackedStringArray())
	if not select.is_empty():
		Verbs.select(doc, seq, select, "replace")
	var ids: PackedStringArray = targets.get("ids", PackedStringArray())
	if ids.is_empty():
		return false
	return Verbs.run(doc, "Split", [EditCmds.SplitClips.new(seq.id, ids, t, false)])


static func gap_at(seq: Sequence, track_id: String, t: float) -> Vector2:
	var none: Vector2 = Vector2(-1.0, -1.0)
	var tr: Track = seq.track_by_id(track_id) if seq != null else null
	if tr == null or tr.clip_at(t) != null:
		return none
	var g0: float = 0.0
	var g1: float = -1.0
	for c: Clip in tr.clips:
		if c.end() <= t + EPS:
			g0 = maxf(g0, c.end())
		elif c.start >= t - EPS:
			g1 = c.start
			break
	if g1 < 0.0 or g1 - g0 <= EPS:
		return none
	return Vector2(g0, g1)


static func close_gap(doc: Project, seq: Sequence, track_id: String, t: float) -> bool:
	if doc == null or seq == null:
		return false
	var g: Vector2 = gap_at(seq, track_id, t)
	if g.x < 0.0:
		return false
	return Verbs.run(doc, "Close gap", [EditCmds.CloseGap.new(seq.id, track_id, (g.x + g.y) * 0.5)])


static func count_gaps(seq: Sequence, track_ids: PackedStringArray) -> int:
	var n: int = 0
	if seq == null:
		return 0
	for tid: String in track_ids:
		var tr: Track = seq.track_by_id(tid)
		if tr == null or tr.locked:
			continue
		var reach: float = -INF
		for c: Clip in tr.clips:
			if reach > -INF and c.start - reach > EPS:
				n += 1
			reach = maxf(reach, c.end())
	return n


static func close_all_gaps(doc: Project, seq: Sequence, track_ids: PackedStringArray) -> int:
	if doc == null or seq == null or track_ids.is_empty():
		return 0
	var cmd: Command = ToolCmds.CloseAllGaps.new(seq.id, track_ids)
	if not Verbs.run(doc, "Close all gaps", [cmd]):
		return 0
	return int(cmd.get("closed"))


static func reorder_track(doc: Project, seq: Sequence, track_id: String, new_index: int) -> bool:
	if doc == null or seq == null:
		return false
	var tr: Track = seq.track_by_id(track_id)
	if tr == null:
		return false
	var list: Array[Track] = seq.tracks_of_kind(tr.kind)
	var to: int = clampi(new_index, 0, list.size() - 1)
	if list.find(tr) == to:
		return false
	return Verbs.run(doc, "Reorder track", [TrackCmds.ReorderTrack.new(seq.id, track_id, to)])


static func key_times(seq: Sequence, clip_ids: PackedStringArray) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if seq == null:
		return out
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		for path: String in c.param_paths():
			var p: Dictionary = c.get_param(path)
			if not AnimProp.is_animated(p):
				continue
			for k: Dictionary in AnimProp.keys(p):
				for played: float in c.played_times_for(path, float(k.get("t", 0.0))):
					var at: float = c.start + played
					if at >= c.start - EPS and at <= c.end() + EPS:
						out.append(at)
	out.sort()
	return out


static func next_key_time(seq: Sequence, clip_ids: PackedStringArray, from_t: float, dir: int) -> float:
	var times: PackedFloat64Array = key_times(seq, clip_ids)
	var reach: float = frame_of(seq) * 0.25
	if dir > 0:
		for v: float in times:
			if v > from_t + reach:
				return v
		return -1.0
	for i: int in range(times.size() - 1, -1, -1):
		if times[i] < from_t - reach:
			return times[i]
	return -1.0


static func fade_field(seq: Sequence, c: Clip) -> String:
	var tr: Track = seq.track_of(c.id) if seq != null and c != null else null
	if tr != null and tr.is_sound(c):
		return "audio"
	return "props"


static func fade_of(seq: Sequence, c: Clip, side: String) -> float:
	if c == null:
		return 0.0
	return fade_value(c, "audio" if fade_field(seq, c) == "audio" else "video", side)


static func fade_value(c: Clip, track_kind: String, side: String) -> float:
	if c == null:
		return 0.0
	var key: String = "fade_in" if side == "in" else "fade_out"
	var d: Dictionary = c.audio if track_kind == "audio" else c.props
	var v: Variant = d.get(key, 0.0)
	if v is float or v is int:
		return maxf(float(v), 0.0)
	return 0.0


static func fade_shape(c: Clip) -> String:
	if c == null:
		return "linear"
	var s: String = String(c.audio.get("fade_shape", "linear"))
	return s if FADE_SHAPES.has(s) else "linear"


static func clamp_fade(seq: Sequence, c: Clip, side: String, seconds: float) -> float:
	var other: float = fade_of(seq, c, "out" if side == "in" else "in")
	var room: float = maxf(c.duration - other, 0.0)
	return clampf(seconds, 0.0, room)


static func fade_command(seq: Sequence, c: Clip, side: String, seconds: float) -> Command:
	var key: String = "fade_in" if side == "in" else "fade_out"
	var v: float = clamp_fade(seq, c, side, seconds)
	var field: String = fade_field(seq, c)
	var value: Variant = v
	if field == "props" and v <= EPS:
		value = null
	return ToolCmds.SetClipKey.new(seq.id, c.id, field, key, value, "Fade in" if side == "in" else "Fade out")


static func set_fade(doc: Project, seq: Sequence, clip_id: String, side: String, seconds: float) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	var tr: Track = seq.track_of(clip_id) if c != null else null
	if doc == null or c == null or tr == null or tr.locked:
		return false
	var cmd: Command = fade_command(seq, c, side, seconds)
	return Verbs.run(doc, cmd.label, [cmd])


static func set_fade_shape(doc: Project, seq: Sequence, clip_ids: PackedStringArray, shape: String) -> bool:
	if doc == null or seq == null or not FADE_SHAPES.has(shape):
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		var tr: Track = seq.track_of(id)
		if c == null or tr == null or not tr.is_sound(c) or tr.locked:
			continue
		cmds.append(ToolCmds.SetClipKey.new(seq.id, id, "audio", "fade_shape", shape, "Fade shape"))
	return Verbs.run(doc, "Fade shape", cmds)


static func fade_gain(shape: String, x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	if shape == "equal_power":
		return sin(u * PI * 0.5)
	if shape == "s_curve":
		return u * u * (3.0 - 2.0 * u)
	return u


static func video_fade_mul(c: Clip, t: float) -> float:
	if c == null:
		return 1.0
	return c.video_fade_mul(t)


static func _num(v: Variant) -> float:
	if v is float or v is int:
		return float(v)
	return 0.0


static func audio_clip_ids(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	return Verbs.audio_targets(seq, ids)


static func gain_entry(c: Clip) -> Dictionary:
	if c == null:
		return {}
	var list: Array = c.audio_effects()
	if list.is_empty():
		return {}
	var first: Dictionary = list[0]
	if String(first.get("id", "")) != "gain":
		return {}
	return first


static func gain_of(c: Clip) -> float:
	var e: Dictionary = gain_entry(c)
	if e.is_empty():
		return 0.0
	var params: Dictionary = e.get("params", {})
	var p: Variant = params.get("db", 0.0)
	if p is Dictionary:
		return AnimProp.evaluate_float(p, c.fx_time(e, "db", 0.0), c.duration)
	return float(p) if (p is float or p is int) else 0.0


static func gain_target(mode: String, current: float, value: float, source_peak_db: float) -> float:
	var want: float = current
	if mode == "set":
		want = value
	elif mode == "adjust":
		want = current + value
	elif mode == "normalise":
		want = value - source_peak_db
	return clampf(want, GAIN_MIN_DB, GAIN_MAX_DB)


static func apply_gain(doc: Project, seq: Sequence, clip_ids: PackedStringArray, mode: String, value: float, peaks: Dictionary = {}) -> bool:
	if doc == null or seq == null or not GAIN_MODES.has(mode):
		return false
	var AudioEffects: GDScript = load("res://engine/audio_effects.gd")
	var def: Dictionary = AudioEffects.call("get_def", "gain")
	if def.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		var tr: Track = seq.track_of(id)
		if c == null or tr == null or not tr.is_sound(c) or tr.locked:
			continue
		if mode == "normalise" and not peaks.has(id):
			continue
		var current: float = gain_of(c)
		var db: float = gain_target(mode, current, value, float(peaks.get(id, 0.0)))
		var e: Dictionary = gain_entry(c)
		var uid: String = String(e.get("uid", ""))
		if e.is_empty():
			uid = doc.mint_id("e")
			cmds.append(EffectCmds.AddEffect.new(seq.id, id, def, uid, 0, true))
		elif absf(db - current) < 0.0001:
			continue
		cmds.append(EffectCmds.SetEffectParam.new(seq.id, id, uid, "db", db, -1.0, true))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Audio gain", cmds)


static func measure_job(doc: Project, seq: Sequence, clip_id: String) -> Dictionary:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null or c.is_nest():
		return {}
	var m: MediaItem = doc.media_by_id(c.media_id)
	var render: String = String(c.audio.get("render", ""))
	if not render.is_empty() and FileAccess.file_exists(render):
		return {"input": render, "stream": 0, "from": maxf(c.source_in(), 0.0), "to": c.source_out()}
	if m == null or m.path.is_empty():
		return {}
	return {"input": m.path, "stream": int(c.audio.get("stream", 0.0)), "from": maxf(c.source_in(), 0.0), "to": c.source_out()}


static func sequence_settings(doc: Project, seq: Sequence, fields: Dictionary) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for f: String in ["label", "width", "height", "fps", "sample_rate"]:
		if not fields.has(f):
			continue
		var v: Variant = fields[f]
		if f == "label":
			var text: String = String(v).strip_edges()
			if text.is_empty() or text == seq.label:
				continue
			v = text
		elif f == "width" or f == "height":
			var n: int = clampi(int(v), 16, 16384)
			if n % 2 == 1:
				n += 1
			if n == int(seq.get(f)):
				continue
			v = n
		elif f == "fps":
			var r: float = clampf(float(v), 1.0, 240.0)
			if absf(r - seq.fps) < 0.0001:
				continue
			v = r
		elif f == "sample_rate":
			var sr: int = clampi(int(v), 8000, 192000)
			if sr == seq.sample_rate:
				continue
			v = sr
		cmds.append(SequenceCmds.SetSequenceField.new(seq.id, f, v))
	if fields.has("fps"):
		var r2: float = float(fields["fps"])
		var drop: bool = absf(r2 - 29.97) < 0.01 or absf(r2 - 59.94) < 0.01
		if drop != seq.drop_frame and absf(r2 - seq.fps) >= 0.0001:
			cmds.append(SequenceCmds.SetSequenceField.new(seq.id, "drop_frame", drop))
	cmds.append_array(Verbs.mode_commands(seq, fields))
	return Verbs.run(doc, "Sequence settings", cmds)


static func new_sequence_dict(doc: Project, label: String, width: int, height: int, fps: float, sample_rate: int, tracks: int) -> Dictionary:
	var s: Sequence = Sequence.new()
	s.id = doc.mint_id("s")
	s.label = label
	s.width = width
	s.height = height
	s.fps = fps
	s.sample_rate = sample_rate
	for i: int in tracks:
		s.video_tracks.append(doc.make_track("video", "V" + str(i + 1)))
		s.audio_tracks.append(doc.make_track("audio", "A" + str(i + 1)))
	if not s.video_tracks.is_empty():
		s.video_tracks[0].targeted = true
	if not s.audio_tracks.is_empty():
		s.audio_tracks[0].targeted = true
	return s.to_dict()


static func new_sequence_from_media(doc: Project, media_id: String, base: Sequence = null) -> String:
	if doc == null:
		return ""
	var m: MediaItem = doc.media_by_id(media_id)
	if m == null or m.kind == "sequence":
		return ""
	var w: int = m.width if m.width > 0 else (base.width if base != null else 1920)
	var h: int = m.height if m.height > 0 else (base.height if base != null else 1080)
	var fps: float = m.fps if m.fps > 0.0 else (base.fps if base != null else 30.0)
	var rate: int = base.sample_rate if base != null else 48000
	if not m.audio_streams.is_empty():
		rate = int((m.audio_streams[0] as Dictionary).get("sample_rate", rate))
	var label: String = m.label.get_basename() if not m.label.get_basename().is_empty() else m.label
	var tracks: int = maxi(3, Verbs.selected_streams(m).size())
	var sd: Dictionary = new_sequence_dict(doc, label, w + (w % 2), h + (h % 2), fps, rate, tracks)
	var seq_id: String = String(sd["id"])
	var media: Dictionary = {"id": doc.mint_id("m"), "kind": "sequence", "label": label, "sequence_id": seq_id, "probed": true}
	var tx: RefCounted = doc.undo.begin("New sequence from clip")
	tx.call("apply", SequenceCmds.AddSequence.new(sd, media, -1, true))
	var s: Sequence = doc.sequence_by_id(seq_id)
	if s == null:
		tx.call("abandon")
		return ""
	var first: Track = s.video_tracks[0] if m.has_picture() else s.audio_tracks[0]
	if is_subclip(m):
		place_subclip(doc, s, media_id, first.id, 0.0, "overwrite")
	else:
		Verbs.place_media(doc, s, media_id, first.id, 0.0, "overwrite")
	tx.call("commit")
	return seq_id


static func duplicate_sequence(doc: Project, seq: Sequence) -> String:
	if doc == null or seq == null:
		return ""
	var d: Dictionary = seq.to_dict()
	var seq_id: String = doc.mint_id("s")
	d["id"] = seq_id
	d["label"] = seq.label + " copy"
	var links: Dictionary = {}
	var groups: Dictionary = {}
	for key: String in ["video_tracks", "audio_tracks"]:
		for tv: Variant in d.get(key, []):
			var td: Dictionary = tv
			td["id"] = doc.mint_id("t")
			for cv: Variant in td.get("clips", []):
				var cd: Dictionary = cv
				cd["id"] = doc.mint_id("c")
				var link: String = String(cd.get("link_id", ""))
				if not link.is_empty():
					if not links.has(link):
						links[link] = doc.mint_id("l")
					cd["link_id"] = links[link]
				var group: String = String(cd.get("group_id", ""))
				if not group.is_empty():
					if not groups.has(group):
						groups[group] = doc.mint_id("g")
					cd["group_id"] = groups[group]
				var mks: Array = cd.get("markers", [])
				for mv: Variant in mks:
					var md: Dictionary = mv
					md["id"] = doc.mint_id("k")
	for mv2: Variant in d.get("markers", []):
		var md2: Dictionary = mv2
		md2["id"] = doc.mint_id("k")
	var media: Dictionary = {"id": doc.mint_id("m"), "kind": "sequence", "label": String(d["label"]), "sequence_id": seq_id, "probed": true}
	var old_media: MediaItem = doc.media_for_sequence(seq.id)
	if old_media != null:
		media["bin"] = old_media.bin
	if not Verbs.run(doc, "Duplicate sequence", [SequenceCmds.AddSequence.new(d, media, doc.sequences.find(seq) + 1, true)]):
		return ""
	return seq_id


static func markers_in_range(seq: Sequence) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if seq == null:
		return out
	var lo: float = seq.in_point if seq.in_point >= 0.0 else -INF
	var hi: float = seq.out_point if seq.out_point >= 0.0 else INF
	for m: Marker in MarkerLayers.usable(seq):
		if m.time >= lo - EPS and m.time <= hi + EPS and not out.has(m.time):
			out.append(m.time)
	out.sort()
	return out


static func cut_at_markers(doc: Project, seq: Sequence) -> int:
	if doc == null or seq == null:
		return 0
	var times: PackedFloat64Array = markers_in_range(seq)
	if times.is_empty():
		return 0
	var selected: PackedStringArray = Verbs.unlocked(seq, Verbs.with_linked(seq, Verbs.selection(seq)))
	var tracks: PackedStringArray = PackedStringArray()
	if selected.is_empty():
		tracks = Verbs.track_ids(Verbs.working_tracks(seq))
	var cmd: Command = ToolCmds.CutAtMarkers.new(seq.id, times, selected, tracks, Verbs.linked_cuts())
	if not Verbs.run(doc, "Cut at markers", [cmd]):
		return 0
	return int(cmd.get("cuts"))


static func chapter_markers(seq: Sequence) -> Array[Marker]:
	var out: Array[Marker] = []
	if seq == null:
		return out
	for m: Marker in MarkerLayers.usable(seq):
		if m.kind == "chapter":
			out.append(m)
	out.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)
	return out


static func chapter_problems(times: PackedFloat64Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if times.is_empty():
		out.append("there are no chapter markers")
		return out
	var sorted: PackedFloat64Array = times.duplicate()
	sorted.sort()
	if sorted[0] > 0.5:
		out.append("the first chapter must start at 0:00")
	if sorted.size() < 3:
		out.append("YouTube needs at least three chapters")
	for i: int in range(1, sorted.size()):
		if sorted[i] - sorted[i - 1] < 10.0 - EPS:
			out.append("chapters must be at least 10 seconds apart")
			break
	return out


static func chapter_line(m: Marker) -> String:
	var total: int = int(floor(m.time + EPS))
	var hh: int = total / 3600
	var mm: int = (total / 60) % 60
	var ss: int = total % 60
	var stamp: String = ("%d:%02d:%02d" % [hh, mm, ss]) if hh > 0 else ("%d:%02d" % [mm, ss])
	return stamp + " " + (m.label if not m.label.is_empty() else "Chapter")


const YOUTUBE_GAP := 10.0
const YOUTUBE_MIN := 3
const YOUTUBE_FIRST := "Intro"
const YOUTUBE_ZERO_SLACK := 0.5


static func chapter_stamp(t: float) -> String:
	var total: int = int(floor(maxf(t, 0.0) + 0.0005))
	var hh: int = total / 3600
	var mm: int = (total / 60) % 60
	var ss: int = total % 60
	return ("%d:%02d:%02d" % [hh, mm, ss]) if hh > 0 else ("%d:%02d" % [mm, ss])


static func chapter_list(seq: Sequence, from_t: float = 0.0, to_t: float = INF) -> Array:
	var out: Array = []
	for m: Marker in chapter_markers(seq):
		if m.time < from_t - 0.0005 or m.time > to_t + 0.0005:
			continue
		out.append({"t": maxf(m.time - from_t, 0.0), "label": m.label})
	return out


static func youtube_list(chapters: Array) -> Dictionary:
	var sorted: Array = chapters.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var kept: Array = []
	var notes: PackedStringArray = PackedStringArray()
	for ch: Dictionary in sorted:
		var t: float = maxf(float(ch.get("t", 0.0)), 0.0)
		var label: String = String(ch.get("label", "")).strip_edges().replace("
", " ")
		if label.is_empty():
			label = "Chapter " + str(kept.size() + 1)
		if kept.is_empty():
			if t > YOUTUBE_GAP - 0.0005:
				kept.append({"t": 0.0, "label": YOUTUBE_FIRST})
				notes.append("added \"0:00 " + YOUTUBE_FIRST + "\" because YouTube needs the first chapter at 0:00 and yours starts at " + chapter_stamp(t))
			elif t > YOUTUBE_ZERO_SLACK:
				notes.append("moved \"" + label + "\" from " + chapter_stamp(t) + " to 0:00 because YouTube needs the first chapter at 0:00")
				t = 0.0
			else:
				t = 0.0
		if not kept.is_empty():
			var prev: Dictionary = kept[kept.size() - 1]
			var gap: float = t - float(prev["t"])
			if gap < YOUTUBE_GAP - 0.0005:
				notes.append("left out \"" + label + "\" at " + chapter_stamp(t) + ", only " + String.num(gap, 1) + " s after \"" + String(prev["label"]) + "\", because YouTube needs 10 seconds between chapters")
				continue
		kept.append({"t": t, "label": label})
	var problems: PackedStringArray = PackedStringArray()
	if kept.size() < YOUTUBE_MIN:
		problems.append("YouTube needs at least %d chapters and this list has %d, so it will not show them" % [YOUTUBE_MIN, kept.size()])
	var lines: PackedStringArray = PackedStringArray()
	for k: Dictionary in kept:
		lines.append(chapter_stamp(float(k["t"])) + " " + String(k["label"]))
	return {"text": "
".join(lines), "chapters": kept, "notes": notes, "problems": problems}


static func play_span(seq: Sequence, kind: String, preroll: float, postroll: float) -> Dictionary:
	if seq == null:
		return {}
	var at: float = seq.playhead
	var end_t: float = seq.duration()
	var in_t: float = seq.in_point if seq.in_point >= 0.0 else 0.0
	var out_t: float = seq.out_point if seq.out_point >= 0.0 else end_t
	if kind == "around":
		return {"from": maxf(at - preroll, 0.0), "to": at + postroll, "back": at}
	if kind == "in_to_out":
		return {"from": in_t, "to": out_t, "back": -1.0}
	if kind == "in_to_out_roll":
		return {"from": maxf(in_t - preroll, 0.0), "to": out_t + postroll, "back": -1.0}
	if kind == "to_out":
		if seq.out_point >= 0.0 and at < seq.out_point - EPS:
			return {"from": at, "to": seq.out_point, "back": -1.0}
		return {"from": at, "to": -1.0, "back": -1.0}
	return {}
