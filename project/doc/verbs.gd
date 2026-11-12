extends RefCounted

const VERSION := 1
const MoveInPlace := preload("res://doc/commands/move_in_place.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Undo := preload("res://doc/undo.gd")
const Command := preload("res://doc/commands/command.gd")
const SpeedLength := preload("res://doc/speed_length.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ViewCmds := preload("res://doc/commands/view_cmds.gd")
const SpeedCmds := preload("res://doc/commands/speed_cmds.gd")
const ViewMap := preload("res://doc/view_map.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
static var last_block: String = ""
const MARKER_LAYERS_PATH := "res://doc/marker_layers.gd"
const EPS := 0.00001
const MODE_OVERLAP := "overlap"
const StackCmds := preload("res://doc/commands/stack_cmds.gd")
const ManyCmds := preload("res://doc/commands/many_cmds.gd")
const CutLinks := preload("res://doc/cut_links.gd")
const TrimToPlayhead := preload("res://doc/commands/trim_to_playhead.gd")
const DropRule := preload("res://doc/drop_rule.gd")
const MoveRule := preload("res://doc/move_rule.gd")
const SyncAlign := preload("res://doc/sync_align.gd")
const LinkAsOne := preload("res://doc/link_as_one.gd")
const LinkCmds := preload("res://doc/commands/link_as_one_cmds.gd")
const ViewTrims := preload("res://doc/view_trims.gd")


static func run(doc: Project, label: String, cmds: Array[Command]) -> bool:
	if doc == null or cmds.is_empty():
		return false
	var tx: Undo.Transaction = doc.undo.begin(label)
	var before: int = tx.commands.size()
	for c: Command in cmds:
		tx.apply(c)
	if tx.commands.size() == before:
		tx.abandon()
		return false
	return tx.commit()


static func working_tracks(seq: Sequence, kind: String = "") -> Array[Track]:
	var out: Array[Track] = []
	var any_targeted: bool = false
	for t: Track in seq.all_tracks():
		if t.targeted and not t.locked:
			any_targeted = true
	for t: Track in seq.all_tracks():
		if t.locked:
			continue
		if any_targeted and not t.targeted:
			continue
		if not kind.is_empty() and t.kind != kind:
			continue
		out.append(t)
	return out


static func track_ids(tracks: Array[Track]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: Track in tracks:
		out.append(t.id)
	return out


static func selection(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in seq.selected_clip_ids:
		if seq.clip_by_id(id) != null:
			out.append(id)
	return out


static func selection_family(seq: Sequence) -> PackedStringArray:
	return seq.expand_selection(selection(seq))


static func unlocked(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var t: Track = seq.track_of(id)
		if t != null and not t.locked and not seq.group_locked(seq.clip_by_id(id)):
			out.append(id)
	return out


static func set_playhead(doc: Project, seq: Sequence, t: float) -> bool:
	if seq == null:
		return false
	seq.playhead = maxf(t, 0.0)
	doc.changed.emit("playhead")
	return true



const PREF_MEDIA_SCALING := "edit.default_media_scaling"
const MEDIA_SCALING_CHOICES: PackedStringArray = ["set_to_frame", "scale_to_frame", "none"]


static func media_scaling_mode() -> String:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("Prefs")
		if prefs != null:
			if not bool(prefs.call("is_registered", PREF_MEDIA_SCALING)):
				prefs.call("register", PREF_MEDIA_SCALING, "set_to_frame", {"label": "Default media scaling when placing a clip", "type": "enum", "choices": MEDIA_SCALING_CHOICES})
			return String(prefs.call("get_value", PREF_MEDIA_SCALING))
	return "set_to_frame"


static func frame_fit_scale(seq: Sequence, item: MediaItem) -> Vector2:
	if seq == null or item == null or item.width <= 0 or item.height <= 0 or seq.width <= 0 or seq.height <= 0:
		return Vector2.ONE
	if not item.has_picture() or item.kind == "sequence" or item.kind == "adjust":
		return Vector2.ONE
	var mode: String = media_scaling_mode()
	if mode == "none":
		return Vector2.ONE
	var f: float = minf(float(seq.width) / float(item.width), float(seq.height) / float(item.height))
	if mode == "scale_to_frame" and f > 1.0:
		f = 1.0
	return Vector2(f, f)


static func selected_streams(item: MediaItem) -> PackedInt32Array:
	return StreamOrdinals.selected(item) if item != null else PackedInt32Array()


static func stream_label(item: MediaItem, stream: int) -> String:
	return StreamOrdinals.label(item, stream) if item != null else ""


const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const SoundAdjust := preload("res://engine/sound_adjust.gd")


static func audio_tracks_from(doc: Project, seq: Sequence, first: Track, count: int, cmds: Array[Command]) -> Array[Track]:
	var out: Array[Track] = []
	if first == null:
		return out
	if seq.free_tracks:
		return free_tracks_from(doc, seq, first, count, cmds)
	var list: Array[Track] = seq.audio_tracks
	var start: int = list.find(first)
	if start < 0:
		return out
	for k: int in count:
		var i: int = start + k
		if i < list.size():
			if list[i].locked:
				continue
			out.append(list[i])
		else:
			var made: Track = doc.make_track("audio", "A" + str(i + 1))
			cmds.append(TrackCmds.AddTrack.new(seq.id, "audio", -1, made.to_dict()))
			out.append(made)
	return out


static func free_tracks_from(doc: Project, seq: Sequence, first: Track, count: int, cmds: Array[Command]) -> Array[Track]:
	var out: Array[Track] = [first]
	var list: Array[Track] = seq.top_down_tracks()
	var i: int = list.find(first)
	var made_count: int = 1 if i < 0 else 0
	for n: int in range(1, count):
		var next: Track = null
		if i >= 0:
			i += 1
			while i < list.size() and list[i].locked:
				i += 1
			if i < list.size():
				next = list[i]
		if next == null:
			made_count += 1
			next = new_free_track(doc, seq, made_count, cmds)
		out.append(next)
	return out


static func new_free_track(doc: Project, seq: Sequence, nth: int, cmds: Array[Command]) -> Track:
	var made: Track = doc.make_track("audio", "A" + str(seq.audio_tracks.size() + nth))
	made.free = seq.free_tracks
	cmds.append(TrackCmds.AddTrack.new(seq.id, "audio", -1, made.to_dict()))
	return made


static func sound_target(doc: Project, seq: Sequence, target: Track, wants_video: bool, cmds: Array[Command]) -> Track:
	if not seq.free_tracks:
		if target.kind == "audio":
			return target
		for a: Track in seq.audio_tracks:
			if a.targeted and not a.locked:
				return a
		if not seq.audio_tracks.is_empty() and not seq.audio_tracks[0].locked:
			return seq.audio_tracks[0]
		return null
	if not wants_video:
		return target
	var below: Track = seq.track_below(target)
	while below != null and below.locked:
		below = seq.track_below(below)
	if below != null:
		return below
	return new_free_track(doc, seq, 1, cmds)


static func clear_for_place(seq: Sequence, mode: String, t: float, duration: float, seeds: PackedStringArray, cmds: Array[Command]) -> void:
	if mode == "insert":
		cmds.append(EditCmds.InsertGap.new(seq.id, t, duration, seeds))
	elif mode != MODE_OVERLAP and not seeds.is_empty():
		cmds.append(EditCmds.LiftRange.new(seq.id, t, t + duration, seeds))


static func stamp_place(track: Track, d: Dictionary, wanted_kind: String, mode: String, skip: PackedStringArray = PackedStringArray()) -> void:
	var p: String = track.part_for(wanted_kind)
	if p.is_empty():
		d.erase("part")
	else:
		d["part"] = p
	if mode == MODE_OVERLAP:
		var t0: float = float(d.get("start", 0.0))
		var top: int = track.top_stack_over(t0, t0 + float(d.get("duration", 0.0)), skip)
		if top != 0:
			d["stack"] = top
		else:
			d.erase("stack")


static func place_mode(seq: Sequence, insert: bool, flip: bool) -> String:
	if insert:
		return "insert"
	if seq != null and seq.overlap_clips != flip:
		return MODE_OVERLAP
	return "overwrite"


static func new_title_clip(doc: Project, seq: Sequence, track_id: String, t: float, text: String = "", want: float = 5.0, extra_props: Dictionary = {}, transform: Dictionary = {}) -> String:
	if doc == null or seq == null or t < 0.0:
		return ""
	var tr: Track = seq.track_by_id(track_id)
	if tr == null or not tr.accepts("video"):
		tr = seq.video_tracks[0] if not seq.video_tracks.is_empty() else null
	if tr == null:
		return ""
	var cmds: Array[Command] = []
	var room: float = _room_on(tr, t)
	var index: int = seq.track_index(tr.id)
	while (not TrackGuard.accepts(doc, seq, tr, TrackGuard.PLACE) or room < 0.25) and index + 1 < seq.video_tracks.size():
		index += 1
		tr = seq.video_tracks[index]
		room = _room_on(tr, t)
	var dest_id: String = tr.id
	if not TrackGuard.accepts(doc, seq, tr, TrackGuard.PLACE) or room < 0.25:
		dest_id = doc.mint_id("t")
		cmds.append(TrackCmds.AddTrack.new(seq.id, "video", -1, {"id": dest_id, "label": "V" + str(seq.video_tracks.size() + 1)}))
		room = INF
	var n: int = 1
	for m: MediaItem in doc.media:
		if m.kind == "title":
			n += 1
	var label: String = text if not text.is_empty() else "Title " + str(n)
	var media_id: String = doc.mint_id("m")
	var props: Dictionary = {"text": label}
	for k: Variant in extra_props.keys():
		props[k] = extra_props[k]
	cmds.append(MediaCmds.AddMedia.new({"id": media_id, "kind": "title", "label": label, "bin": "", "probed": true, "duration": want, "props": props}))
	var clip_id: String = doc.mint_id("c")
	var title_dict: Dictionary = {"id": clip_id, "media_id": media_id, "label": label, "start": t, "duration": minf(want, room), "in_offset": 0.0}
	if not transform.is_empty():
		title_dict["transform"] = transform.duplicate(true)
	if dest_id == tr.id:
		stamp_place(tr, title_dict, "video", "overwrite")
	cmds.append(ClipCmds.PlaceClip.new(seq.id, dest_id, title_dict))
	if not run(doc, "New title", cmds):
		return ""
	select(doc, seq, PackedStringArray([clip_id]), "replace")
	return clip_id


static func _room_on(tr: Track, t: float) -> float:
	if tr.clip_at(t) != null:
		return 0.0
	var i: int = tr.index_of_last_starting_before(t) + 1
	if i < tr.clips.size():
		return tr.clips[i].start - t
	return INF


static func sequence_has_sound(doc: Project, item: MediaItem, depth: int = 0) -> bool:
	if doc == null or item == null or item.kind != "sequence" or depth > 4:
		return false
	var s: Sequence = doc.sequence_by_id(item.sequence_id)
	if s == null:
		return false
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			var m: MediaItem = doc.media_by_id(c.media_id)
			if m == null or m == item:
				continue
			if t.is_sound(c) and (m.has_audio or m.kind == "audio"):
				return true
			if m.kind == "sequence" and sequence_has_sound(doc, m, depth + 1):
				return true
	return false


static func place_media(doc: Project, seq: Sequence, media_id: String, track_id: String, t: float, mode: String = "overwrite") -> bool:
	var item: MediaItem = doc.media_by_id(media_id)
	var target: Track = seq.track_by_id(track_id) if seq != null else null
	if item == null or target == null or target.locked or t < 0.0:
		return false
	if item.props.has("subclip_in"):
		return bool(load("res://doc/commands/edit_tools.gd").call("place_subclip", doc, seq, media_id, track_id, t, mode))
	if item.is_object_source():
		return bool(load("res://modules/core_panels/object_ui.gd").call("place_object", doc, seq, media_id, track_id, t, mode))
	var duration: float = doc.media_duration(item)
	var placeholder: bool = false
	if item.is_timed() and not item.probed and item.kind != "sequence":
		duration = MediaItem.PLACEHOLDER_DURATION
		placeholder = true
	elif duration <= 0.0:
		if item.is_timed():
			return false
		duration = MediaItem.PLACEHOLDER_DURATION
	var wants_video: bool = item.has_picture() and target.accepts("video")
	var sound_adjust: bool = SoundAdjust.drops_on(item, target)
	var wants_audio: bool = sound_adjust or ((item.has_audio or item.kind == "audio" or item.audio_only or sequence_has_sound(doc, item)) and not StreamOrdinals.all_off(item))
	var cmds: Array[Command] = []
	var audio_track: Track = sound_target(doc, seq, target, wants_video, cmds) if wants_audio else null
	if not wants_video and audio_track == null:
		return false
	var streams: PackedInt32Array = selected_streams(item) if item.kind != "sequence" and not sound_adjust else PackedInt32Array([0])
	var audio_tracks: Array[Track] = audio_tracks_from(doc, seq, audio_track, streams.size(), cmds) if audio_track != null else ([] as Array[Track])
	var seeds: PackedStringArray = PackedStringArray()
	if wants_video:
		seeds.append(target.id)
	for at: Track in audio_tracks:
		if not seeds.has(at.id):
			seeds.append(at.id)
	clear_for_place(seq, mode, t, duration, seeds, cmds)
	var link_id: String = doc.mint_id("l") if (wants_video and not audio_tracks.is_empty()) or audio_tracks.size() > 1 else ""
	var new_ids: PackedStringArray = PackedStringArray()
	var resize_on: bool = item.kind != "sequence" and item.kind != "title" and item.kind != "shape" and item.kind != "adjust" and item.kind != "generator" and item.kind != "image" and SpeedLength.new_clips_on()
	if resize_on:
		Clip.speed_length_seen = true
	if wants_video:
		var vid: String = doc.mint_id("c")
		var vd: Dictionary = {"id": vid, "media_id": media_id, "label": item.label, "start": t, "duration": duration, "in_offset": 0.0}
		if item.kind == "sequence":
			vd["sequence_id"] = item.sequence_id
		if not link_id.is_empty():
			vd["link_id"] = link_id
		if placeholder:
			vd["placeholder"] = true
		var fit: Vector2 = frame_fit_scale(seq, item)
		if fit != Vector2.ONE:
			vd["transform"] = {"scale": AnimProp.make([fit.x, fit.y]), "scale_linked": is_equal_approx(fit.x, fit.y)}
		if resize_on:
			vd["audio"] = {SpeedLength.KEY_ON: true}
		Clip.stamp_auto_loop(item.path, vd)
		stamp_place(target, vd, "video", mode)
		cmds.append(ClipCmds.PlaceClip.new(seq.id, target.id, vd))
		new_ids.append(vid)
	for k: int in audio_tracks.size():
		var aid: String = doc.mint_id("c")
		var stream: int = streams[mini(k, streams.size() - 1)]
		var label: String = item.label if streams.size() == 1 else item.label + " " + stream_label(item, stream)
		var ad: Dictionary = {"id": aid, "media_id": media_id, "label": label, "start": t, "duration": duration, "in_offset": 0.0, "audio": {"stream": float(stream)}}
		if resize_on:
			(ad["audio"] as Dictionary)[SpeedLength.KEY_ON] = true
		if item.kind == "sequence":
			ad["sequence_id"] = item.sequence_id
		if not link_id.is_empty():
			ad["link_id"] = link_id
		if placeholder:
			ad["placeholder"] = true
		Clip.stamp_auto_loop(item.path, ad)
		stamp_place(audio_tracks[k], ad, "audio", mode)
		cmds.append(ClipCmds.PlaceClip.new(seq.id, audio_tracks[k].id, ad))
		new_ids.append(aid)
	if not run(doc, "Place " + item.label, cmds):
		return false
	select(doc, seq, new_ids, "replace")
	return true


static func move_selection(doc: Project, seq: Sequence, delta_t: float, track_delta: int, mode: String = "overwrite", anchor_id: String = "") -> bool:
	var original: PackedStringArray = selection(seq)
	var picked: PackedStringArray = seq.picked_clip_ids.duplicate()
	var ids: PackedStringArray = unlocked(seq, MoveRule.moving(seq))
	if ids.is_empty():
		return false
	var anchor_track: Track = seq.track_of(anchor_id)
	var anchor_kind: String = anchor_track.kind if anchor_track != null else "video"
	var steps: int = seq.visual_track_delta(anchor_kind, track_delta)
	var min_start: float = INF
	var max_end: float = -INF
	var rows: Array[Dictionary] = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		var t: Track = seq.track_of(id)
		var own_delta: int = seq.visual_track_delta(t.kind, steps) if seq.was_picked(id) else 0
		var dest: Track = seq.track_at_offset(t, own_delta)
		if dest.locked:
			dest = t
		rows.append({"clip": c, "track": dest, "kind": t.clip_kind(c)})
		min_start = minf(min_start, c.start)
		max_end = maxf(max_end, c.end())
	if min_start + delta_t < 0.0:
		delta_t = -min_start
	if absf(delta_t) < EPS and track_delta == 0:
		return false
	var in_place: Array[Command] = MoveInPlace.commands(seq, rows, delta_t, mode, ids)
	if not in_place.is_empty():
		if not run(doc, "Move", in_place):
			return false
		select(doc, seq, original, "replace")
		seq.picked_clip_ids = picked
		return true
	var cmds: Array[Command] = []
	cmds.append(ClipCmds.RemoveClips.new(seq.id, ids))
	var seeds: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		var dest: Track = r["track"]
		if not seeds.has(dest.id):
			seeds.append(dest.id)
	if mode == "insert":
		cmds.append(EditCmds.InsertGap.new(seq.id, min_start + delta_t, max_end - min_start, seeds))
	for r: Dictionary in rows:
		var c: Clip = r["clip"]
		var dest: Track = r["track"]
		var d: Dictionary = c.to_dict()
		d["start"] = c.start + delta_t
		stamp_place(dest, d, String(r["kind"]), mode, ids)
		if mode != "insert" and mode != MODE_OVERLAP:
			cmds.append(EditCmds.LiftRange.new(seq.id, c.start + delta_t, c.end() + delta_t, PackedStringArray([dest.id])))
		cmds.append(ClipCmds.PlaceClip.new(seq.id, dest.id, d, false))
	if not run(doc, "Move", cmds):
		return false
	select(doc, seq, original, "replace")
	seq.picked_clip_ids = picked
	return true


static func edge_family(seq: Sequence, clip_id: String, side: String) -> PackedStringArray:
	var c: Clip = seq.clip_by_id(clip_id)
	var out: PackedStringArray = PackedStringArray()
	if c == null:
		return out
	var edge: float = c.start if side == "head" else c.end()
	for f: Clip in seq.linked(c):
		var fe: float = f.start if side == "head" else f.end()
		var t: Track = seq.track_of(f.id)
		if absf(fe - edge) < EPS and t != null and not t.locked:
			out.append(f.id)
	return out


static func trim_family(seq: Sequence, clip_id: String, side: String, solo: bool) -> PackedStringArray:
	if not solo:
		return edge_family(seq, clip_id, side)
	var t: Track = seq.track_of(clip_id)
	if seq.clip_by_id(clip_id) == null or t == null or t.locked:
		return PackedStringArray()
	return PackedStringArray([clip_id])


static func trim(doc: Project, seq: Sequence, clip_id: String, side: String, new_t: float, ripple: bool = false, solo: bool = false) -> bool:
	var ids: PackedStringArray = trim_family(seq, clip_id, side, solo)
	if ids.is_empty():
		return false
	var cmd: Command = EditCmds.RippleTrim.new(seq.id, ids, side, new_t) if ripple else EditCmds.TrimClip.new(seq.id, ids, side, new_t)
	return run(doc, cmd.label, [cmd])


static func roll(doc: Project, seq: Sequence, edit_t: float, track_id: String, new_t: float) -> bool:
	var t: Track = seq.track_by_id(track_id)
	if t == null or t.locked:
		return false
	var tracks: PackedStringArray = PackedStringArray([track_id])
	for c: Clip in t.clips:
		if absf(c.end() - edit_t) < EPS or absf(c.start - edit_t) < EPS:
			for f: Clip in seq.linked(c):
				var ft: Track = seq.track_of(f.id)
				if ft != null and not ft.locked and not tracks.has(ft.id):
					if absf(f.end() - edit_t) < EPS or absf(f.start - edit_t) < EPS:
						tracks.append(ft.id)
	var cmd: Command = EditCmds.RollEdit.new(seq.id, edit_t, tracks, new_t)
	return run(doc, cmd.label, [cmd])


static func slip(doc: Project, seq: Sequence, clip_id: String, delta: float) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var ids: PackedStringArray = MoveRule.slide_ids(seq, clip_id)
	var cmd: Command = EditCmds.SlipClip.new(seq.id, unlocked(seq, ids), delta)
	return run(doc, cmd.label, [cmd])


static func slide(doc: Project, seq: Sequence, clip_id: String, delta: float) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var ids: PackedStringArray = MoveRule.slide_ids(seq, clip_id)
	var cmd: Command = EditCmds.SlideClip.new(seq.id, unlocked(seq, ids), delta)
	return run(doc, cmd.label, [cmd])


static func linked_cuts() -> bool:
	if CutLinks.links_always():
		return true
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("is_registered") and bool(prefs.call("is_registered", "timeline.linked_selection")):
			return bool(prefs.call("get_value", "timeline.linked_selection"))
	return true


static func with_linked(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if not out.has(id):
			out.append(id)
		if not linked_cuts():
			continue
		for f: Clip in seq.linked(seq.clip_by_id(id)):
			if not out.has(f.id):
				out.append(f.id)
	return out


static func razor(doc: Project, seq: Sequence, t: float, only_selected: bool = false, all_tracks: bool = false) -> bool:
	var ids: PackedStringArray = PackedStringArray()
	if only_selected:
		ids = unlocked(seq, with_linked(seq, seq.expand_selection(selection(seq)) if CutLinks.links_always() else selection(seq)))
	else:
		var tracks: Array[Track] = []
		if all_tracks:
			for tr: Track in seq.all_tracks():
				if not tr.locked:
					tracks.append(tr)
		else:
			tracks = working_tracks(seq)
		for tr: Track in tracks:
			for c: Clip in tr.clips_at(t):
				ids.append(c.id)
		ids = unlocked(seq, with_linked(seq, ids))
	ids = _cuttable(seq, ids, t)
	if ids.is_empty():
		return false
	var cmd: Command = EditCmds.SplitClips.new(seq.id, ids, t, false)
	return run(doc, "Split", [cmd])


static func _cuttable(seq: Sequence, ids: PackedStringArray, t: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and t > c.start + EPS and t < c.end() - EPS:
			out.append(id)
	return out


const PREF_RIPPLE_CONFIRM := "edit.ripple_cut_confirm"
const RIPPLE_CONFIRM_LABEL := "Ripple trim: press the key twice before cutting a clip that blocks the ripple"
const RIPPLE_CONFIRM_HINT := "On: the first press refuses and names the clip in the way, the second press within a few seconds cuts it there and ripples. Off: one press does it, as Premiere does."
const RIPPLE_CONFIRM_SECONDS := 4.0
static var ripple_confirm_key: String = ""
static var ripple_confirm_ms: int = 0


static func register_ripple_prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	if prefs == null:
		return null
	if not bool(prefs.call("is_registered", PREF_RIPPLE_CONFIRM)):
		prefs.call("register", PREF_RIPPLE_CONFIRM, true, {"label": RIPPLE_CONFIRM_LABEL, "type": "bool", "hint": RIPPLE_CONFIRM_HINT})
	return prefs


static func ripple_confirm_needed() -> bool:
	var prefs: Node = register_ripple_prefs()
	if prefs == null:
		return true
	return bool(prefs.call("get_value", PREF_RIPPLE_CONFIRM))


static func ripple_commands(seq: Sequence, ids: PackedStringArray, side: String, t: float) -> Array[Command]:
	var by_lines: Command = ViewTrims.ripple(seq, ids, side, t)
	if by_lines != null:
		return [by_lines] as Array[Command]
	return TrimToPlayhead.commands(seq, ids, side, t)


static func ripple_confirm_id(doc: Project, seq: Sequence, ids: PackedStringArray, side: String, t: float) -> String:
	return seq.id + "|" + side + "|%.5f" % t + "|" + ",".join(ids) + "|" + str(doc.undo.current_index())


static func ripple_armed(key: String) -> bool:
	if ripple_confirm_key != key or ripple_confirm_key.is_empty():
		return false
	return float(Time.get_ticks_msec() - ripple_confirm_ms) * 0.001 <= RIPPLE_CONFIRM_SECONDS


static func ripple_trim_to_playhead(doc: Project, seq: Sequence, side: String) -> bool:
	last_block = ""
	var t: float = seq.playhead
	var ids: PackedStringArray = PackedStringArray()
	for id: String in unlocked(seq, selection(seq)):
		var c: Clip = seq.clip_by_id(id)
		if t > c.start + EPS and t < c.end() - EPS:
			ids.append(id)
	if ids.is_empty():
		for tr: Track in working_tracks(seq):
			for c: Clip in tr.clips_at(t):
				if t > c.start + EPS and t < c.end() - EPS:
					ids.append(c.id)
	if ids.is_empty():
		ripple_confirm_key = ""
		last_block = "the playhead is not inside a clip on a working track"
		return false
	var key: String = ripple_confirm_id(doc, seq, ids, side, t)
	if run(doc, "Ripple trim to playhead", ripple_commands(seq, ids, side, t)):
		ripple_confirm_key = ""
		return true
	var block: Dictionary = ripple_blockers(doc, seq, ids, side, t)
	var cut_tracks: PackedStringArray = block["cut"]
	if cut_tracks.is_empty():
		ripple_confirm_key = ""
		last_block = ripple_block_note(seq, ids, side)
		return false
	if ripple_confirm_needed() and not ripple_armed(key):
		ripple_confirm_key = key
		ripple_confirm_ms = Time.get_ticks_msec()
		last_block = ripple_block_note(seq, ids, side) + " " + String(block["again_note"])
		return false
	ripple_confirm_key = ""
	var cmd: Command = TrimToPlayhead.CutThrough.new(seq.id, ids, side, t, cut_tracks, float(block["edge"]), float(block["span"]))
	var done: bool = run(doc, "Ripple trim to playhead", [cmd])
	if not done:
		last_block = ripple_block_note(seq, ids, side)
	return done


static func track_name(tr: Track) -> String:
	return tr.label if not tr.label.strip_edges().is_empty() else tr.id


static func clip_name(c: Clip) -> String:
	return c.label if not c.label.strip_edges().is_empty() else c.id


static func crossing_clip(tr: Track, at: float) -> Clip:
	for c: Clip in tr.clips:
		if c.start < at - EditMath.EPS and c.end() > at + EditMath.EPS:
			return c
	return null


static func ripple_edge(s: Sequence, ids: PackedStringArray, side: String) -> float:
	var edge: float = -INF if side == "head" else INF
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		edge = maxf(edge, c.start) if side == "head" else minf(edge, c.end())
	return edge


static func ripple_span(doc: Project, s: Sequence, ids: PackedStringArray, side: String, t: float, edge: float) -> float:
	var bounds: Vector2 = Vector2(-INF, INF)
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		if side == "head":
			bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, c, false))
		else:
			bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, c, false))
	return absf(EditMath.clamp_delta(t - edge, bounds))


static func join_names(names: PackedStringArray) -> String:
	if names.size() < 2:
		return "" if names.is_empty() else names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


static func ripple_again_note(names: PackedStringArray, crossers: PackedStringArray) -> String:
	var secs: String = "%.0f" % RIPPLE_CONFIRM_SECONDS
	if names.size() == 1 and not crossers[0].is_empty():
		return "Press it again within " + secs + " seconds to cut " + crossers[0] + " there and ripple anyway."
	if names.size() == 1:
		return "Press it again within " + secs + " seconds to make room on " + names[0] + " and ripple anyway."
	return "Press it again within " + secs + " seconds to cut " + join_names(names) + " there and ripple anyway."


static func ripple_blockers(doc: Project, s: Sequence, ids: PackedStringArray, side: String, t: float) -> Dictionary:
	var out: Dictionary = {"edge": 0.0, "span": 0.0, "cut": PackedStringArray(), "again_note": ""}
	if doc == null or s == null or ids.is_empty():
		return out
	var edge: float = ripple_edge(s, ids, side)
	if is_inf(edge):
		return out
	var span: float = ripple_span(doc, s, ids, side, t, edge)
	out["edge"] = edge
	out["span"] = span
	if span <= EPS:
		return out
	var seeds: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var tr: Track = s.track_of(id)
		if tr != null and not seeds.has(tr.id):
			seeds.append(tr.id)
	var cut: PackedStringArray = PackedStringArray()
	var cut_names: PackedStringArray = PackedStringArray()
	var cut_clips: PackedStringArray = PackedStringArray()
	for tr: Track in EditMath.ripple_tracks(s, seeds):
		if seeds.has(tr.id) or not tr.sync_lock:
			continue
		if EditMath.ripple_limit(s, [tr] as Array[Track], edge, ids) >= span - EPS:
			continue
		var crosser: Clip = crossing_clip(tr, edge)
		cut.append(tr.id)
		cut_names.append(track_name(tr))
		cut_clips.append("" if crosser == null else clip_name(crosser))
	out["cut"] = cut
	out["again_note"] = ripple_again_note(cut_names, cut_clips)
	return out


static func ripple_block_note(s: Sequence, ids: PackedStringArray, side: String) -> String:
	if s == null or ids.is_empty():
		return ""
	var first: Clip = s.clip_by_id(ids[0])
	if first == null:
		return ""
	var edge: float = first.start if side == "head" else first.end()
	var seeds: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var tr: Track = s.track_of(id)
		if tr != null and not seeds.has(tr.id):
			seeds.append(tr.id)
	var worst: String = ""
	var crosser: String = ""
	var room: float = INF
	for tr: Track in EditMath.ripple_tracks(s, seeds):
		if seeds.has(tr.id):
			continue
		var one: float = EditMath.ripple_limit(s, [tr] as Array[Track], edge, ids)
		if one < room:
			room = one
			worst = tr.label
			crosser = ""
			for c: Clip in tr.clips:
				if c.start < edge - EditMath.EPS and c.end() > edge + EditMath.EPS:
					crosser = c.label if not c.label.strip_edges().is_empty() else c.id
					break
	if worst.is_empty() or room > EditMath.EPS:
		return "nothing could move without running past the media or another clip"
	if not crosser.is_empty():
		return "the clip " + crosser + " on the sync locked track " + worst + " runs straight across that point, so nothing could move. Cut it there, or turn that track's sync lock off."
	return "the sync locked track " + worst + " has no room at that point, so nothing moved. Turn its sync lock off, or make a gap there."


static func extend_edit_to_playhead(doc: Project, seq: Sequence, direction: int = 0, only: PackedStringArray = PackedStringArray()) -> bool:
	var by_lines: Command = ViewTrims.extend(seq, direction, only)
	if by_lines != null:
		return run(doc, "Extend edit to playhead", [by_lines])
	return run(doc, "Extend edit to playhead", extend_commands(seq, direction, only))


static func extend_commands(seq: Sequence, direction: int = 0, only: PackedStringArray = PackedStringArray()) -> Array[Command]:
	var t: float = seq.playhead
	var cmds: Array[Command] = []
	var done_edges: PackedStringArray = PackedStringArray()
	var bests: Dictionary = {}
	for tr: Track in working_tracks(seq):
		var best: float = -1.0
		var best_dist: float = INF
		for c: Clip in tr.clips:
			if not only.is_empty() and not only.has(c.id):
				continue
			for e: float in [c.start, c.end()]:
				var d: float = absf(e - t)
				if d <= EPS or (direction < 0 and e > t) or (direction > 0 and e < t):
					continue
				if d < best_dist:
					best_dist = d
					best = e
		if best >= 0.0:
			bests[tr.id] = best
	for tr: Track in working_tracks(seq):
		if not bests.has(tr.id):
			continue
		var best: float = float(bests[tr.id])
		var key: String = tr.id + "|%.5f" % best
		if done_edges.has(key):
			continue
		var a: Clip = null
		var b: Clip = null
		for c: Clip in tr.clips:
			if absf(c.end() - best) < EPS:
				a = c
			if absf(c.start - best) < EPS:
				b = c
		var tracks: PackedStringArray = PackedStringArray([tr.id])
		for c: Clip in [a, b]:
			if c == null:
				continue
			for f: Clip in seq.linked(c):
				var ft: Track = seq.track_of(f.id)
				if ft != null and not ft.locked and not tracks.has(ft.id) and (absf(f.end() - best) < EPS or absf(f.start - best) < EPS):
					tracks.append(ft.id)
		for tid: String in tracks:
			done_edges.append(tid + "|%.5f" % best)
		if a != null and b != null:
			cmds.append(EditCmds.RollEdit.new(seq.id, best, tracks, t))
		elif a != null:
			cmds.append(EditCmds.TrimClip.new(seq.id, edge_family(seq, a.id, "tail"), "tail", t))
		elif b != null:
			cmds.append(EditCmds.TrimClip.new(seq.id, edge_family(seq, b.id, "head"), "head", t))
	return cmds


static func lift(doc: Project, seq: Sequence) -> bool:
	if seq.in_point < 0.0 or seq.out_point < 0.0 or seq.out_point - seq.in_point <= EPS:
		return false
	var cmd: Command = EditCmds.LiftRange.new(seq.id, seq.in_point, seq.out_point, track_ids(working_tracks(seq)))
	return run(doc, cmd.label, [cmd])


static func extract(doc: Project, seq: Sequence) -> bool:
	if seq.in_point < 0.0 or seq.out_point < 0.0 or seq.out_point - seq.in_point <= EPS:
		return false
	var cmd: Command = EditCmds.ExtractRange.new(seq.id, seq.in_point, seq.out_point, track_ids(working_tracks(seq)))
	return run(doc, cmd.label, [cmd])


static func delete_selection(doc: Project, seq: Sequence, ripple: bool = false) -> bool:
	var ids: PackedStringArray = unlocked(seq, selection(seq))
	if ids.is_empty():
		return false
	var cmd: Command = EditCmds.RippleRemove.new(seq.id, ids) if ripple else ClipCmds.RemoveClips.new(seq.id, ids)
	return run(doc, "Ripple delete" if ripple else "Delete", [cmd])


static func nudge(doc: Project, seq: Sequence, frames: int) -> bool:
	if frames == 0 or seq.fps <= 0.0:
		return false
	return move_selection(doc, seq, float(frames) / seq.fps, 0, "overwrite")


static func replace_media(doc: Project, seq: Sequence, clip_ids: PackedStringArray, media_id: String, align: bool = false) -> bool:
	var item: MediaItem = doc.media_by_id(media_id)
	if item == null or seq == null or clip_ids.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var t: Track = seq.track_of(id)
		if t == null or t.locked:
			continue
		if t.is_sound(c) and not item.has_audio and item.kind != "audio":
			continue
		cmds.append(ClipCmds.SetClipField.new(seq.id, id, "media_id", media_id))
		var room: float = item.duration if item.duration > 0.0 else c.duration
		var speed: float = c.static_speed()
		if speed == 0.0:
			speed = 1.0
		var used: float = c.duration * absf(speed)
		var want: float = c.in_offset
		if align:
			var lined: float = SyncAlign.aligned_in_offset(doc.media_by_id(c.media_id), item, c.in_offset)
			if lined > SyncAlign.NONE:
				want = lined
		var in_off: float = clampf(want, 0.0, maxf(room - used, 0.0))
		var dur: float = c.duration
		if used > room:
			dur = maxf(room / absf(speed), 1.0 / maxf(seq.fps, 1.0))
			in_off = 0.0
		if absf(in_off - c.in_offset) > 0.00001 or absf(dur - c.duration) > 0.00001:
			cmds.append(EditCmds.SetTiming.new(seq.id, id, c.start, dur, in_off, 0.0))
	if cmds.is_empty():
		return false
	return run(doc, "Replace footage", cmds)


static func view_entry(seq: Sequence, clip_id: String, uid: String) -> Dictionary:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return {}
	return c.effect_by_uid(uid)


static func rearrange_view_audio(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	if doc == null or seq == null:
		return false
	var video: Clip = seq.clip_by_id(clip_id)
	var map: Dictionary = ViewMap.of(view_entry(seq, clip_id, uid))
	if video == null or map.is_empty():
		return false
	var order: PackedStringArray = PackedStringArray()
	for id: String in ViewMap.track_order(map):
		var tr: Track = seq.track_by_id(id)
		if tr != null and tr.makes_sound():
			order.append(id)
	if order.size() < 2:
		return false
	var slots: Array[Track] = []
	for tr: Track in seq.sound_carriers():
		if order.has(tr.id):
			if tr.locked:
				return false
			slots.append(tr)
	if slots.size() != order.size():
		return false
	var remap: Dictionary = {}
	var shifts: bool = false
	for i: int in order.size():
		remap[order[i]] = slots[i].id
		if order[i] != slots[i].id:
			shifts = true
	if not shifts:
		return false
	var moves: Array[Dictionary] = []
	var landing: Dictionary = {}
	for tr: Track in slots:
		landing[tr.id] = []
	for tr: Track in slots:
		var dest_id: String = String(remap[tr.id])
		for c: Clip in tr.clips:
			var travels: bool = c.end() > video.start + EPS and c.start < video.end() - EPS
			if travels:
				moves.append({"id": c.id, "start": c.start, "track_id": dest_id})
			(landing[dest_id if travels else tr.id] as Array).append(Vector2(c.start, c.end()))
	if moves.is_empty():
		return false
	for tid: Variant in landing.keys():
		var spans: Array = landing[tid]
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for i: int in spans.size() - 1:
			if float((spans[i] as Vector2).y) > float((spans[i + 1] as Vector2).x) + EPS:
				return false
	var fixed: Dictionary = map.duplicate(true)
	var out_views: Array = []
	for v: Variant in map.get("views", []):
		var vd: Dictionary = (v as Dictionary).duplicate(true)
		var fresh: Array = []
		for tid2: Variant in vd.get("tracks", []):
			fresh.append(String(remap.get(String(tid2), String(tid2))))
		vd["tracks"] = fresh
		ViewMap.ViewStreams.remap_picks(vd, remap)
		out_views.append(vd)
	fixed["views"] = out_views
	fixed = ViewMap.remap_always(fixed, remap)
	var cmds: Array[Command] = []
	cmds.append(ClipCmds.MoveClips.new(seq.id, moves))
	cmds.append(EffectCmds.SetEffectParam.new(seq.id, clip_id, uid, "view_audio", JSON.stringify(fixed), -1.0))
	return run(doc, "Rearrange view audio", cmds)


static func cut_on_view_changes(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	if doc == null or seq == null:
		return false
	var cmd: Command = ViewCmds.CutViews.new(seq.id, clip_id, uid)
	return run(doc, "Cut on view changes", [cmd])


static func source_span_of(seq: Sequence, clip_id: String) -> float:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return 0.0
	var span: float = c.source_span()
	if span > EPS:
		return span
	return c.duration * maxf(absf(c.static_speed()), SpeedCmds.MIN_SPEED)


static func set_clip_speed(doc: Project, seq: Sequence, clip_id: String, speed: float, keep_pitch: bool, mode: String) -> bool:
	if doc == null or seq == null or seq.clip_by_id(clip_id) == null:
		return false
	var cmd: Command = SpeedCmds.SetSpeed.new(seq.id, PackedStringArray([clip_id]), speed, keep_pitch, mode)
	return run(doc, "Speed", [cmd])


static func rate_stretch(doc: Project, seq: Sequence, clip_id: String, side: String, new_t: float) -> bool:
	if doc == null or seq == null or seq.clip_by_id(clip_id) == null:
		return false
	var cmd: Command = SpeedCmds.RateStretch.new(seq.id, PackedStringArray([clip_id]), side, new_t)
	return run(doc, "Rate stretch", [cmd])


static func apply_crossfeed_everywhere(doc: Project, settings: Dictionary) -> int:
	if doc == null:
		return 0
	var AudioEffects: GDScript = load("res://engine/audio_effects.gd")
	var AudioGraph: GDScript = load("res://engine/audio_graph.gd")
	var def: Dictionary = AudioEffects.call("get_def", "crossfeed")
	var on: bool = bool(settings.get("on", false))
	var touched: int = 0
	var cmds: Array[Command] = []
	for s: Sequence in doc.sequences:
		for tr: Track in s.audio_tracks:
			if tr.locked:
				continue
			for c: Clip in tr.clips:
				var at: int = -1
				var list: Array = c.audio_effects()
				for i: int in list.size():
					if String((list[i] as Dictionary).get("id", "")) == "crossfeed":
						at = i
				if not on:
					if at >= 0:
						cmds.append(EffectCmds.RemoveEffect.new(s.id, c.id, String((list[at] as Dictionary).get("uid", "")), true))
						touched += 1
					continue
				var uid: String = String((list[at] as Dictionary).get("uid", "")) if at >= 0 else doc.mint_id("e")
				if at < 0:
					cmds.append(EffectCmds.AddEffect.new(s.id, c.id, def, uid, -1, true))
				for key: String in ["amount", "cutoff", "delay_ms"]:
					cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, key, float(settings.get(key, 0.0)), -1.0, true))
				touched += 1
	if cmds.is_empty():
		return 0
	if not run(doc, "Crossfeed on every clip" if on else "Crossfeed off every clip", cmds):
		return 0
	return touched


const TYPE_SECONDS := 1.5


static func text_presets() -> Array[Dictionary]:
	return [
		{"id": "type_on", "label": "Type on", "tip": "Reveals the text one letter at a time over the first second and a half"},
		{"id": "type_on_caret", "label": "Type on with a cursor", "tip": "The same, with an underscore sitting after the last letter while it types"},
		{"id": "type_off", "label": "Type off", "tip": "Takes the text away a letter at a time over the last second and a half"},
		{"id": "type_clear", "label": "No typing", "tip": "Takes the typing off and shows the whole text again"},
	]


static func apply_text_preset(doc: Project, seq: Sequence, clip_id: String, kind: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var span: float = minf(TYPE_SECONDS, maxf(c.duration, 1.0 / maxf(seq.fps, 1.0)))
	var reveal: Dictionary = AnimProp.make(1.0)
	var caret: String = ""
	if kind == "type_on" or kind == "type_on_caret":
		reveal = AnimProp.set_key(AnimProp.set_key(AnimProp.make(0.0), 0.0, 0.0, "linear"), span, 1.0, "linear")
		caret = "_" if kind == "type_on_caret" else ""
	elif kind == "type_off":
		var from: float = maxf(c.duration - span, 0.0)
		reveal = AnimProp.set_key(AnimProp.set_key(AnimProp.make(1.0), from, 1.0, "linear"), c.duration, 0.0, "linear")
	elif kind != "type_clear":
		return false
	var cmds: Array[Command] = []
	var props: Dictionary = c.props.duplicate(true)
	if kind == "type_clear":
		props.erase("reveal")
		props.erase("cursor")
	else:
		props["reveal"] = reveal
		props["cursor"] = caret
	if props == c.props:
		return false
	cmds.append(ClipCmds.SetClipField.new(seq.id, clip_id, "props", props))
	return run(doc, "Text " + kind.replace("_", " "), cmds)


static func copy(doc: Project, seq: Sequence) -> Dictionary:
	return copy_ids(doc, seq, selection(seq))


static func copy_ids(doc: Project, seq: Sequence, ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"clips": [], "span": 0.0, "seq_id": seq.id, "fps": seq.fps}
	if ids.is_empty():
		return out
	var clips: Array[Clip] = []
	var t0: float = INF
	var t1: float = -INF
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		clips.append(c)
		t0 = minf(t0, c.start)
		t1 = maxf(t1, c.end())
	clips.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	for c: Clip in clips:
		var t: Track = seq.track_of(c.id)
		out["clips"].append({"track_id": t.id, "kind": t.kind, "track_index": seq.track_index(t.id), "offset": c.start - t0, "clip": c.to_dict()})
	out["span"] = t1 - t0
	var records: Dictionary = copied_group_records(seq, clips)
	if not records.is_empty():
		out["groups"] = records
	return out


static func duplicate_clips(doc: Project, seq: Sequence, ids: PackedStringArray, delta_t: float, track_delta: int, mode: String = "overwrite", anchor_id: String = "") -> bool:
	if doc == null or seq == null:
		return false
	var live: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if seq.clip_by_id(id) != null and not live.has(id):
			live.append(id)
	if live.is_empty():
		return false
	var clipboard: Dictionary = copy_ids(doc, seq, live)
	var anchor_track: Track = seq.track_of(anchor_id)
	var steps: int = seq.visual_track_delta(anchor_track.kind if anchor_track != null else "video", track_delta)
	var t0: float = INF
	for row: Variant in clipboard["clips"]:
		var rd: Dictionary = row
		var cd: Dictionary = rd["clip"]
		var c: Clip = seq.clip_by_id(String(cd.get("id", "")))
		var own: Track = seq.track_by_id(String(rd["track_id"]))
		if c == null or own == null:
			continue
		t0 = minf(t0, c.start)
		var own_delta: int = seq.visual_track_delta(own.kind, steps) if steps != 0 and seq.was_picked(c.id) else 0
		var dest: Track = seq.track_at_offset(own, own_delta)
		if dest.locked:
			dest = own
		rd["track_id"] = dest.id
		rd["kind"] = dest.kind
		rd["track_index"] = seq.track_index(dest.id)
		stamp_place(dest, cd, own.clip_kind(c), "overwrite")
	if t0 == INF:
		return false
	var at: float = maxf(t0 + delta_t, 0.0)
	if mode == MODE_OVERLAP:
		return paste_overlapping(doc, seq, clipboard, at)
	return paste(doc, seq, clipboard, at, mode == "insert")


static func copied_group_records(seq: Sequence, clips: Array[Clip]) -> Dictionary:
	var out: Dictionary = {}
	for c: Clip in clips:
		if c.group_id.is_empty() or out.has(c.group_id):
			continue
		var g: Dictionary = seq.group_by_id(c.group_id)
		if not g.is_empty():
			out[c.group_id] = g.duplicate(true)
	return out


static func paste(doc: Project, seq: Sequence, clipboard: Dictionary, t: float, insert: bool = false) -> bool:
	if clipboard.get("clips", []).is_empty() or t < 0.0:
		return false
	var cmd: Command = EditCmds.PasteInsert.new(seq.id, clipboard, t) if insert else EditCmds.PasteClips.new(seq.id, clipboard, t)
	if not run(doc, cmd.label, [cmd]):
		return false
	select(doc, seq, cmd.get("pasted_ids"), "replace")
	return true


static func paste_attributes(doc: Project, seq: Sequence, clipboard: Dictionary, which: PackedStringArray) -> bool:
	var rows: Array = clipboard.get("clips", [])
	var ids: PackedStringArray = unlocked(seq, selection(seq))
	if rows.is_empty() or ids.is_empty() or which.is_empty():
		return false
	var source: Dictionary = (rows[0] as Dictionary).get("clip", {})
	for r: Variant in rows:
		var rd: Dictionary = r
		if str(rd.get("kind", "")) == "video":
			source = rd.get("clip", {})
			break
	var cmd: Command = EditCmds.PasteAttributes.new(seq.id, ids, source, which)
	return run(doc, cmd.label, [cmd])


static func pin_track(doc: Project, seq: Sequence, track_id: String, on: bool) -> bool:
	var t: Track = seq.track_by_id(track_id)
	if t == null or t.pinned == on:
		return false
	var cmd: Command = TrackCmds.PinTrack.new(seq.id, track_id, on)
	return run(doc, cmd.label, [cmd])


static func nest_selection(doc: Project, seq: Sequence, label: String) -> bool:
	var ids: PackedStringArray = unlocked(seq, MoveRule.moving(seq))
	if ids.is_empty():
		return false
	var cmd: Command = EditCmds.NestClips.new(seq.id, ids, label if not label.is_empty() else "Nested sequence")
	if not run(doc, cmd.label, [cmd]):
		return false
	select(doc, seq, cmd.get("nest_clip_ids"), "replace")
	return true


static func unnest_selection(doc: Project, seq: Sequence) -> bool:
	var cmds: Array[Command] = []
	var seen: PackedStringArray = PackedStringArray()
	for id: String in unlocked(seq, selection(seq)):
		var c: Clip = seq.clip_by_id(id)
		if c == null or not c.is_nest() or seen.has(c.sequence_id + "|" + str(c.start)):
			continue
		seen.append(c.sequence_id + "|" + str(c.start))
		cmds.append(EditCmds.UnnestClips.new(seq.id, id))
	if cmds.is_empty():
		return false
	if not run(doc, "Unnest", cmds):
		return false
	var placed: PackedStringArray = PackedStringArray()
	for c: Command in cmds:
		if c.ok:
			placed.append_array(c.get("placed_ids"))
	select(doc, seq, placed, "replace")
	return true


static func add_marker_at(doc: Project, seq: Sequence, t: float) -> bool:
	var layers: GDScript = load(MARKER_LAYERS_PATH)
	var target: String = String(layers.call("target_of", seq))
	var idx: Dictionary = layers.call("index", seq)
	for m: Marker in seq.markers:
		if absf(m.time - t) < EPS and String(layers.call("lane_in", idx, m)) == target:
			return false
	var cmd: Command = MarkerCmds.AddMarker.new(seq.id, "", {"id": doc.mint_id("k"), "time": maxf(t, 0.0)})
	return run(doc, cmd.label, [cmd])


static func set_in(doc: Project, seq: Sequence, t: float) -> bool:
	t = maxf(t, 0.0)
	var out_t: float = seq.out_point
	if out_t >= 0.0 and out_t < t:
		out_t = t
	if absf(seq.in_point - t) < EPS and out_t == seq.out_point:
		return false
	return run(doc, "Set in", [SequenceCmds.SetInOut.new(seq.id, t, out_t)])


static func set_out(doc: Project, seq: Sequence, t: float) -> bool:
	t = maxf(t, 0.0)
	var in_t: float = seq.in_point
	if in_t >= 0.0 and in_t > t:
		in_t = t
	if absf(seq.out_point - t) < EPS and in_t == seq.in_point:
		return false
	return run(doc, "Set out", [SequenceCmds.SetInOut.new(seq.id, in_t, t)])


static func clear_in_out(doc: Project, seq: Sequence) -> bool:
	if seq.in_point < 0.0 and seq.out_point < 0.0:
		return false
	return run(doc, "Clear in and out", [SequenceCmds.SetInOut.new(seq.id, -1.0, -1.0)])


static func transition_side_of(c: Clip, side: String) -> Dictionary:
	if c == null:
		return {}
	if side == "out":
		return c.transition_out if c.has_transition_out() else {}
	return c.transition_in if c.has_transition() else {}


static func selected_transition(seq: Sequence) -> Dictionary:
	if seq == null or seq.selected_transition.is_empty():
		return {}
	var held: Dictionary = seq.selected_transition
	var c: Clip = seq.clip_by_id(String(held.get("clip_id", "")))
	if transition_side_of(c, String(held.get("side", "in"))).is_empty():
		seq.selected_transition = {}
		return {}
	return held


static func select_transition(doc: Project, seq: Sequence, clip_id: String, side: String) -> bool:
	if doc == null or seq == null:
		return false
	var c: Clip = seq.clip_by_id(clip_id)
	if transition_side_of(c, side).is_empty():
		return false
	var want: Dictionary = {"clip_id": clip_id, "side": "out" if side == "out" else "in"}
	if seq.selected_transition == want and seq.selected_clip_ids.is_empty():
		return false
	seq.selected_transition = want
	seq.selected_clip_ids = PackedStringArray()
	seq.picked_clip_ids = PackedStringArray()
	doc.changed.emit("selection")
	return true


static func clear_transition(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null or seq.selected_transition.is_empty():
		return false
	seq.selected_transition = {}
	doc.changed.emit("selection")
	return true


static func select(doc: Project, seq: Sequence, ids: PackedStringArray, mode: String = "replace", picked: PackedStringArray = PackedStringArray()) -> bool:
	var dropped: bool = not seq.selected_transition.is_empty()
	seq.selected_transition = {}
	var before: PackedStringArray = seq.selected_clip_ids.duplicate()
	var next: PackedStringArray = PackedStringArray()
	if mode == "replace":
		for id: String in ids:
			if seq.clip_by_id(id) != null and not next.has(id):
				next.append(id)
	elif mode == "add":
		next = before.duplicate()
		for id: String in ids:
			if seq.clip_by_id(id) != null and not next.has(id):
				next.append(id)
	elif mode == "toggle":
		next = before.duplicate()
		for id: String in ids:
			var i: int = next.find(id)
			if i >= 0:
				next.remove_at(i)
			elif seq.clip_by_id(id) != null:
				next.append(id)
	else:
		return false
	seq.picked_clip_ids = picked.duplicate() if not picked.is_empty() else next.duplicate()
	if next == before:
		if dropped:
			doc.changed.emit("selection")
		return dropped
	seq.selected_clip_ids = next
	doc.changed.emit("selection")
	return true


static func select_tracks(doc: Project, seq: Sequence, ids: PackedStringArray, mode: String = "replace") -> bool:
	if seq == null:
		return false
	var before: PackedStringArray = seq.selected_track_ids.duplicate()
	var next: PackedStringArray = PackedStringArray()
	if mode == "replace":
		for id: String in ids:
			if seq.track_by_id(id) != null and not next.has(id):
				next.append(id)
	elif mode == "add":
		next = before.duplicate()
		for id: String in ids:
			if seq.track_by_id(id) != null and not next.has(id):
				next.append(id)
	elif mode == "toggle":
		next = before.duplicate()
		for id: String in ids:
			var i: int = next.find(id)
			if i >= 0:
				next.remove_at(i)
			elif seq.track_by_id(id) != null:
				next.append(id)
	else:
		return false
	if next == before:
		return false
	seq.selected_track_ids = next
	doc.changed.emit("selection")
	return true


static func selected_tracks(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for id: String in seq.selected_track_ids:
		if seq.track_by_id(id) != null:
			out.append(id)
	return out


static func target_track(seq: Sequence, kind: String) -> Track:
	if seq == null:
		return null
	for id: String in seq.selected_track_ids:
		var t: Track = seq.track_by_id(id)
		if t != null and t.kind == kind and not t.locked:
			return t
	return null


static func select_range(doc: Project, seq: Sequence, t0: float, t1: float, tracks: PackedStringArray = PackedStringArray()) -> bool:
	var lo: float = minf(t0, t1)
	var hi: float = maxf(t0, t1)
	var ids: PackedStringArray = PackedStringArray()
	for t: Track in seq.all_tracks():
		if not tracks.is_empty() and not tracks.has(t.id):
			continue
		for c: Clip in seq.clips_overlapping(t, lo, hi):
			ids.append(c.id)
	return select(doc, seq, ids, "replace")


static func go_to_next_edit(doc: Project, seq: Sequence) -> bool:
	var t: float = seq.next_edit(seq.playhead)
	if t < 0.0:
		return false
	return set_playhead(doc, seq, t)


static func go_to_prev_edit(doc: Project, seq: Sequence) -> bool:
	var t: float = seq.prev_edit(seq.playhead)
	if t < 0.0:
		return false
	return set_playhead(doc, seq, t)


static func set_clip_param(doc: Project, seq: Sequence, clip_id: String, path: String, value: Variant, key_at: float = -1.0, live: bool = false) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var current: Dictionary = c.get_param(path)
	var next: Dictionary
	if key_at < 0.0:
		next = AnimProp.make(value)
	else:
		var local_t: float = c.param_time(path, key_at - c.start)
		if live:
			var base_v: Variant = doc.undo.live_baseline("clip_param|" + clip_id + "|" + path)
			var base: Dictionary = base_v if base_v is Dictionary else current
			next = AnimProp.autokey_next(base, local_t, value, c.duration, seq.fps)
		else:
			next = AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), local_t, value)
	if next == current:
		return false
	var cmd: Command = ClipCmds.SetClipParam.new(seq.id, clip_id, path, next)
	if live:
		doc.undo.live(cmd)
		return cmd.ok
	return run(doc, cmd.label, [cmd])


static func toggle_keyframe(doc: Project, seq: Sequence, clip_id: String, path: String, t: float) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var current: Dictionary = c.get_param(path)
	if current.is_empty():
		return false
	var local_t: float = c.param_time(path, t - c.start)
	var next: Dictionary
	if AnimProp.find_key(current, local_t) >= 0:
		next = AnimProp.remove_key(current, local_t)
	else:
		next = AnimProp.set_key(current, local_t, AnimProp.evaluate(current, local_t, c.duration, seq.fps))
	var cmd: Command = ClipCmds.SetClipParam.new(seq.id, clip_id, path, next)
	cmd.label = "Toggle keyframe"
	return run(doc, cmd.label, [cmd])


static func link_selection(doc: Project, seq: Sequence) -> bool:
	var ids: PackedStringArray = selection(seq)
	if ids.size() < 2:
		return false
	return run(doc, "Link", [ClipCmds.Link.new(seq.id, ids, doc.mint_id("l"))])


static func unlink_selection(doc: Project, seq: Sequence) -> bool:
	var ids: PackedStringArray = PackedStringArray()
	var links: PackedStringArray = PackedStringArray()
	for id: String in selection(seq):
		for f: Clip in seq.linked(seq.clip_by_id(id)):
			if f.link_id.is_empty():
				continue
			if not ids.has(f.id):
				ids.append(f.id)
			if not links.has(f.link_id):
				links.append(f.link_id)
	if ids.is_empty():
		return false
	var cmds: Array[Command] = [ClipCmds.Unlink.new(seq.id, ids)]
	for link: String in links:
		cmds.append(LinkCmds.SetLinkRule.new(seq.id, link, false, false, "Unlink"))
	return run(doc, "Unlink", cmds)


static func set_link_as_one(doc: Project, seq: Sequence, clip_id: String, on: bool) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null or c.link_id.is_empty():
		return false
	var keep: bool = on and bool(seq.link_rule(c.link_id).get("fill", false))
	return run(doc, LinkAsOne.AS_ONE_LABEL, [LinkCmds.SetLinkRule.new(seq.id, c.link_id, on, keep, LinkAsOne.AS_ONE_LABEL)])


static func set_link_fill(doc: Project, seq: Sequence, clip_id: String, on: bool) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null or c.link_id.is_empty():
		return false
	if on and not bool(seq.link_rule(c.link_id).get("as_one", false)):
		return false
	return run(doc, LinkAsOne.FILL_LABEL, [LinkCmds.SetLinkRule.new(seq.id, c.link_id, true, on, LinkAsOne.FILL_LABEL)])


const GROUP_VERBS_PATH := "res://doc/group_verbs.gd"


static func group_verbs() -> GDScript:
	return load(GROUP_VERBS_PATH)


static func group_selection(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null:
		return false
	return bool(group_verbs().call("group_selection", doc, seq))


static func ungroup_selection(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null:
		return false
	return bool(group_verbs().call("ungroup_selection", doc, seq))


static func nest_family(seq: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or c == null or not c.is_nest():
		return out
	for f: Clip in seq.linked(c):
		if f.sequence_id == c.sequence_id:
			out.append(f)
	if not out.has(c):
		out.append(c)
	return out


static func set_nest_option(doc: Project, seq: Sequence, clip_id: String, key: String, value: Variant) -> bool:
	var labels: Dictionary = {"hear_audio": "Hear audio", "audio_allow": "Nest tracks heard", "see_inside": "See inside", "show_audio_below": "Show audio below"}
	return set_nest_options(doc, seq, clip_id, {key: value}, String(labels.get(key, "Nest option")))


static func set_nest_options(doc: Project, seq: Sequence, clip_id: String, values: Dictionary, label: String) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for f: Clip in nest_family(seq, seq.clip_by_id(clip_id)):
		for k: Variant in values.keys():
			var key: String = String(k)
			var value: Variant = values[k]
			var have: Variant = f.nest.get(key)
			if have is Array and value is Array and (have as Array) == (value as Array):
				continue
			if not (have is Array) and not (value is Array) and have == value:
				continue
			cmds.append(ClipCmds.SetNestOption.new(seq.id, f.id, key, value))
	return run(doc, label, cmds)


static func nest_heard_tracks(doc: Project, c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or c == null or not c.is_nest() or not bool(c.nest.get("hear_audio", true)):
		return out
	var inner: Sequence = doc.sequence_by_id(c.sequence_id)
	if inner == null:
		return out
	var raw: Variant = c.nest.get("audio_allow", [])
	var allow: Array = raw if raw is Array else []
	for t: Track in inner.audio_tracks:
		if allow.is_empty() or allow.has(t.id):
			out.append(t.id)
	return out


static func set_nest_track_heard(doc: Project, seq: Sequence, clip_id: String, track_id: String, on: bool) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null or not c.is_nest():
		return false
	var inner: Sequence = doc.sequence_by_id(c.sequence_id)
	if inner == null:
		return false
	var heard: PackedStringArray = nest_heard_tracks(doc, c)
	var at: int = heard.find(track_id)
	if on and at < 0:
		heard.append(track_id)
	elif not on and at >= 0:
		heard.remove_at(at)
	if heard.is_empty():
		return set_nest_options(doc, seq, clip_id, {"hear_audio": false}, "Nest tracks heard")
	var allow: Array = []
	for t: Track in inner.audio_tracks:
		if heard.has(t.id):
			allow.append(t.id)
	if allow.size() == inner.audio_tracks.size():
		allow = []
	return set_nest_options(doc, seq, clip_id, {"hear_audio": true, "audio_allow": allow}, "Nest tracks heard")


static func enable_selection(doc: Project, seq: Sequence, on: bool) -> bool:
	var cmds: Array[Command] = []
	for id: String in selection(seq):
		var c: Clip = seq.clip_by_id(id)
		if c.enabled != on:
			cmds.append(ClipCmds.SetClipField.new(seq.id, id, "enabled", on))
	return run(doc, "Enable" if on else "Disable", cmds)


static func effect_def_for_clip(doc: Project, seq: Sequence, c: Clip, def: Dictionary) -> Dictionary:
	if c == null or not (def.get("params") is Array):
		return def
	var out: Dictionary = def.duplicate(true)
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	var source_fps: float = m.fps if m != null and m.fps > 0.0 else (seq.fps if seq != null else 0.0)
	var params: Array = out["params"]
	for i: int in params.size():
		if not (params[i] is Dictionary):
			continue
		var pd: Dictionary = params[i]
		var key: String = str(pd.get("key", ""))
		if source_fps > 0.0 and (key == "fps" or key == "frame_rate") and str(pd.get("type", "float")) == "float":
			pd["default"] = source_fps
			params[i] = pd
	return out


static func add_effect(doc: Project, seq: Sequence, clip_ids: PackedStringArray, def: Dictionary, index: int = -1) -> bool:
	var is_audio: bool = bool(def.get("audio", false))
	var targets: PackedStringArray = audio_targets(seq, clip_ids) if is_audio else video_targets(seq, clip_ids)
	if String(def.get("applies_to", "")) == "text":
		targets = title_targets(doc, seq, targets)
	var cmds: Array[Command] = []
	for id: String in targets:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		cmds.append(EffectCmds.AddEffect.new(seq.id, id, effect_def_for_clip(doc, seq, c, def), doc.mint_id("e"), index, is_audio))
	if cmds.is_empty():
		return false
	return run(doc, cmds[0].label, cmds)


static func title_targets(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null:
		return out
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		var m: MediaItem = doc.media_by_id(c.media_id) if c != null else null
		if m != null and m.kind == "title":
			out.append(id)
	return out


static func carries_sound(_doc: Project, seq: Sequence, c: Clip) -> bool:
	if c == null or seq == null:
		return false
	var tr: Track = seq.track_of(c.id)
	return tr != null and tr.is_sound(c)


static func video_targets(seq: Sequence, clip_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var tr: Track = seq.track_of(id)
		if tr != null and tr.is_picture(c):
			if not tr.locked and not out.has(id):
				out.append(id)
			continue
		for f: Clip in seq.linked(c):
			var ft: Track = seq.track_of(f.id)
			if ft != null and ft.is_picture(f) and not ft.locked and not out.has(f.id):
				out.append(f.id)
	return out


static func audio_targets(seq: Sequence, clip_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var tr: Track = seq.track_of(id)
		if tr != null and tr.is_sound(c):
			if not tr.locked and not out.has(id):
				out.append(id)
			continue
		for f: Clip in seq.linked(c):
			var ft: Track = seq.track_of(f.id)
			if ft != null and ft.is_sound(f) and not ft.locked and not out.has(f.id):
				out.append(f.id)
	return out


static func effect_is_audio(seq: Sequence, clip_id: String, uid: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	return c != null and c.is_audio_effect(uid)


static func remove_effect(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	var cmd: Command = EffectCmds.RemoveEffect.new(seq.id, clip_id, uid, effect_is_audio(seq, clip_id, uid))
	return run(doc, cmd.label, [cmd])


static func set_effect_param(doc: Project, seq: Sequence, clip_id: String, uid: String, key: String, value: Variant, key_at: float = -1.0, live: bool = false) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var local_t: float = c.param_time(("audio_effects." if c.is_audio_effect(uid) else "effects.") + uid + "." + key, key_at - c.start) if key_at >= 0.0 else -1.0
	var cmd: Command = EffectCmds.SetEffectParam.new(seq.id, clip_id, uid, key, value, local_t, c.is_audio_effect(uid), "", live)
	if live:
		doc.undo.live(cmd)
		return cmd.ok
	return run(doc, cmd.label, [cmd])


static func set_piece_override(doc: Project, seq: Sequence, clip_id: String, uid: String, index: int, piece: Variant) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var cmd: Command = EffectCmds.SetPieceOverride.new(seq.id, clip_id, uid, index, piece, c.is_audio_effect(uid))
	return run(doc, cmd.label, [cmd])


static func set_clip_prop(doc: Project, seq: Sequence, clip_id: String, path: String, prop: Dictionary, label: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null or c.get_param(path) == prop:
		return false
	var cmd: Command = ClipCmds.SetClipParam.new(seq.id, clip_id, path, prop)
	cmd.label = label
	return run(doc, label, [cmd])


static func set_transition_out(doc: Project, seq: Sequence, clip_id: String, transition: Dictionary) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null or c.transition_out == transition:
		return false
	var cmd: Command = ClipCmds.SetClipField.new(seq.id, clip_id, "transition_out", transition)
	cmd.label = "Set transition"
	return run(doc, "Set transition", [cmd])


static func set_transition(doc: Project, seq: Sequence, clip_id: String, transition: Dictionary) -> bool:
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null or c.transition_in == transition:
		return false
	return run(doc, "Set transition", [ClipCmds.SetTransition.new(seq.id, clip_id, transition)])


static func paste_overlapping(doc: Project, seq: Sequence, clipboard: Dictionary, t: float) -> bool:
	if doc == null or seq == null or clipboard.get("clips", []).is_empty() or t < 0.0:
		return false
	var cmd: StackCmds.PasteOverlap = StackCmds.PasteOverlap.new(seq.id, clipboard, t)
	if not run(doc, cmd.label, [cmd]):
		return false
	select(doc, seq, cmd.pasted_ids, "replace")
	return true


static func layer_tracks(seq: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	if seq == null:
		return out
	if seq.free_tracks:
		return seq.top_down_tracks()
	out.append_array(seq.video_tracks)
	for t: Track in seq.audio_tracks:
		if t.foreign:
			out.append(t)
	return out


static func clips_under(seq: Sequence, track: Track, t: float) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or track == null:
		return out
	var list: Array[Clip] = track.clips_at(t)
	for i: int in range(list.size() - 1, -1, -1):
		out.append(list[i])
	return out


static func in_stack(seq: Sequence, c: Clip) -> bool:
	if seq == null or c == null:
		return false
	var tr: Track = seq.track_of(c.id)
	return tr != null and tr.has_stack() and not tr.overlapping(c).is_empty()


static func pick_behind(seq: Sequence, track: Track, t: float, current_id: String) -> String:
	var under: Array[Clip] = clips_under(seq, track, t)
	if under.size() < 2:
		return current_id
	var at: int = -1
	for i: int in under.size():
		if under[i].id == current_id:
			at = i
	var selected_at: int = -1
	for i: int in under.size():
		if seq.selected_clip_ids.has(under[i].id) and seq.selected_clip_ids.size() == 1:
			selected_at = i
	if selected_at >= 0:
		return under[(selected_at + 1) % under.size()].id
	return under[(maxi(at, 0) + 1) % under.size()].id


static func set_stack_order(doc: Project, seq: Sequence, front_to_back: PackedStringArray, label: String = "Stack order") -> bool:
	if doc == null or seq == null or front_to_back.size() < 2:
		return false
	var values: Array[int] = []
	var clips: Array[Clip] = []
	for id: String in front_to_back:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			return false
		clips.append(c)
		values.append(c.stack)
	values.sort()
	var distinct: bool = true
	for i: int in range(1, values.size()):
		if values[i] == values[i - 1]:
			distinct = false
	var order: Dictionary = {}
	var n: int = clips.size()
	for i: int in n:
		var back_rank: int = n - 1 - i
		order[clips[i].id] = values[back_rank] if distinct else values[0] + back_rank
	return run(doc, label, [StackCmds.SetStackOrder.new(seq.id, order, label)])


static func bring_to_front(doc: Project, seq: Sequence, clip_id: String) -> bool:
	return _restack(doc, seq, clip_id, true)


static func send_to_back(doc: Project, seq: Sequence, clip_id: String) -> bool:
	return _restack(doc, seq, clip_id, false)


static func _restack(doc: Project, seq: Sequence, clip_id: String, front: bool) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	var tr: Track = seq.track_of(clip_id) if c != null else null
	if tr == null:
		return false
	var others: Array[Clip] = tr.overlapping(c)
	if others.is_empty():
		return false
	var edge: int = others[0].stack
	for o: Clip in others:
		edge = maxi(edge, o.stack) if front else mini(edge, o.stack)
	var want: int = edge + 1 if front else edge - 1
	if (front and c.stack > edge) or (not front and c.stack < edge):
		return false
	var order: Dictionary = {c.id: want}
	var label: String = "Bring to front" if front else "Send to back"
	return run(doc, label, [StackCmds.SetStackOrder.new(seq.id, order, label)])


static func set_free_tracks(doc: Project, seq: Sequence, on: bool) -> bool:
	if doc == null or seq == null:
		return false
	return run(doc, "Free tracks " + ("on" if on else "off"), [StackCmds.SetSequenceMode.new(seq.id, "free_tracks", on)])


const MODE_NOTE := "With clips overlapping, a drop lays the clip over the others and Shift overwrites. Free tracks keep every clip where it is when turned on or off."


static func mode_fields(seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	out.append({"key": "overlap_clips", "label": "Clips may overlap on a track", "type": "bool", "default": seq.overlap_clips})
	out.append({"key": "free_tracks", "label": "Free tracks: any clip on any track", "type": "bool", "default": seq.free_tracks})
	out.append({"key": "modes_note", "type": "note", "default": MODE_NOTE})
	return out


static func mode_answer(r: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in StackCmds.MODE_FIELDS:
		if r.has(key):
			out[key] = bool(r[key])
	return out


static func mode_commands(seq: Sequence, fields: Dictionary) -> Array[Command]:
	var out: Array[Command] = []
	if seq == null:
		return out
	for key: String in StackCmds.MODE_FIELDS:
		if fields.has(key) and bool(fields[key]) != bool(seq.get(key)):
			out.append(StackCmds.SetSequenceMode.new(seq.id, key, bool(fields[key])))
	return out


static func set_overlap_clips(doc: Project, seq: Sequence, on: bool) -> bool:
	if doc == null or seq == null:
		return false
	return run(doc, "Clips may overlap " + ("on" if on else "off"), [StackCmds.SetSequenceMode.new(seq.id, "overlap_clips", on)])


static func link_families(seq: Sequence, ids: PackedStringArray) -> int:
	var seen: Dictionary = {}
	if seq == null:
		return 0
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null:
			seen[c.link_id if not c.link_id.is_empty() else "#" + c.id] = true
	return seen.size()


static func many_selected(seq: Sequence) -> bool:
	return seq != null and link_families(seq, selection(seq)) > 1


static func param_next(seq: Sequence, clip_id: String, path: String, value: Variant, key_at: float = -1.0, interp: String = "") -> Dictionary:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return {}
	var current: Dictionary = c.get_param(path)
	var next: Dictionary
	if key_at < 0.0:
		next = AnimProp.make(value)
	else:
		var base: Dictionary = current if not current.is_empty() else AnimProp.make(value)
		next = AnimProp.set_key(base, c.param_time(path, key_at - c.start), value, interp)
	if next == current:
		return {}
	return next


static func clip_param_command(seq: Sequence, clip_id: String, path: String, value: Variant, key_at: float = -1.0, interp: String = "") -> Command:
	var next: Dictionary = param_next(seq, clip_id, path, value, key_at, interp)
	if next.is_empty():
		return null
	return ClipCmds.SetClipParam.new(seq.id, clip_id, path, next)


static func write_command(seq: Sequence, writes: Array[Dictionary], key: String, label: String) -> Command:
	var entries: Array[Dictionary] = []
	for w: Dictionary in writes:
		var cid: String = String(w.get("clip_id", ""))
		var path: String = String(w.get("path", ""))
		var key_at: float = float(w.get("key_at", -1.0))
		var interp: String = "hold" if bool(w.get("hold", false)) and key_at >= 0.0 else ""
		var next: Dictionary = param_next(seq, cid, path, w.get("value"), key_at, interp)
		if not next.is_empty():
			entries.append({"clip_id": cid, "path": path, "anim": next})
	if entries.is_empty():
		return null
	return ManyCmds.SetParams.new(seq.id, entries, key, label)


static func live_kind(sound: bool) -> String:
	return Undo.LIVE_SOUND if sound else Undo.LIVE


static func live_begin(doc: Project) -> bool:
	var was: bool = doc.is_blocking_signals()
	doc.set_block_signals(true)
	return was


static func live_end(doc: Project, was: bool, kind: String) -> void:
	doc.set_block_signals(was)
	if not was:
		doc.changed.emit(kind)


static func live_all(doc: Project, cmds: Array[Command]) -> bool:
	if doc == null or cmds.is_empty():
		return false
	if cmds.size() == 1 and Undo.is_value_edit(cmds[0]):
		doc.undo.live(cmds[0])
		return cmds[0].ok
	var quiet: bool = true
	var sound: bool = false
	var was: bool = live_begin(doc)
	for cmd: Command in cmds:
		doc.undo.live(cmd)
		quiet = quiet and Undo.is_value_edit(cmd)
		sound = sound or Undo.touches_sound(cmd)
	live_end(doc, was, (Undo.LIVE_SOUND if sound else Undo.LIVE) if quiet else "structure")
	return true


static func write_many(doc: Project, seq: Sequence, writes: Array[Dictionary], label: String, live: bool = false, key: String = "") -> bool:
	if doc == null or seq == null:
		return false
	var cmd: Command = write_command(seq, writes, key if not key.is_empty() else label, label)
	if cmd == null:
		return false
	if live:
		doc.undo.live(cmd)
		return cmd.ok
	return run(doc, label, [cmd])


static func effect_targets(seq: Sequence, clip_ids: PackedStringArray, def: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var sound: bool = bool(def.get("audio", false))
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		var tr: Track = seq.track_of(id)
		if c == null or tr == null or tr.locked or out.has(id):
			continue
		if (tr.is_sound(c) if sound else tr.is_picture(c)):
			out.append(id)
	if out.is_empty():
		return audio_targets(seq, clip_ids) if sound else video_targets(seq, clip_ids)
	return out


static func drop_effect(doc: Project, seq: Sequence, clip_ids: PackedStringArray, def: Dictionary, at_t: float = -1.0) -> int:
	if doc == null or seq == null or def.is_empty():
		return 0
	var targets: PackedStringArray = effect_targets(seq, clip_ids, def)
	if targets.is_empty():
		return 0
	if String(def.get("applies_to", "")) == "text":
		var titles: PackedStringArray = title_targets(doc, seq, targets)
		return titles.size() if add_effect(doc, seq, titles, def) else 0
	var split: int = int(load("res://doc/commands/region_fx_cmds.gd").call("drop_split", doc, seq, targets, def, at_t))
	if split >= 0:
		return split
	return targets.size() if add_effect(doc, seq, targets, def) else 0


static func drop_targets(seq: Sequence, clip_id: String) -> PackedStringArray:
	return DropRule.targets(seq, clip_id)


static func speed_targets(seq: Sequence, clip_id: String) -> PackedStringArray:
	var ids: PackedStringArray = selection(seq) if seq != null else PackedStringArray()
	if clip_id.is_empty() or ids.has(clip_id):
		return ids
	return PackedStringArray([clip_id])


static func speed_command(seq: Sequence, clip_ids: PackedStringArray, speed: float, keep_pitch: bool, mode: String, fit_length: float = -1.0, touch_pitch: bool = true) -> Command:
	if seq == null or clip_ids.is_empty():
		return null
	var cmd: SpeedCmds.SetSpeed = SpeedCmds.SetSpeed.new(seq.id, clip_ids, speed, keep_pitch, mode)
	cmd.fit_length = fit_length
	cmd.touch_pitch = touch_pitch
	return cmd


static func set_clips_speed(doc: Project, seq: Sequence, clip_ids: PackedStringArray, speed: float, keep_pitch: bool, mode: String, fit_length: float = -1.0) -> bool:
	var cmd: Command = speed_command(seq, clip_ids, speed, keep_pitch, mode, fit_length)
	if doc == null or cmd == null:
		return false
	return run(doc, "Speed", [cmd])


static func speed_many_note(seq: Sequence, clip_id: String) -> String:
	var ids: PackedStringArray = speed_targets(seq, clip_id)
	if link_families(seq, ids) < 2:
		return ""
	var lo: float = INF
	var hi: float = -INF
	var keyed: bool = false
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		if AnimProp.is_animated(c.speed):
			keyed = true
			continue
		lo = minf(lo, absf(c.static_speed()) * 100.0)
		hi = maxf(hi, absf(c.static_speed()) * 100.0)
	var text: String = "%d clips change together and each one is resized" % link_families(seq, ids)
	if hi > lo + 0.0001:
		text += ", their speeds differ now (%s to %s percent)" % [String.num(lo, 0), String.num(hi, 0)]
	if keyed:
		text += ", keyframed speeds are replaced"
	return text + ", a length fits each clip to it"


const TrackGuard := preload("res://doc/track_guard.gd")


static func track_accepts(doc: Project, seq: Sequence, track: Track, what: String, media_id: String = "") -> bool:
	return TrackGuard.accepts(doc, seq, track, what, media_id)


static func track_refusal(doc: Project, seq: Sequence, track: Track, what: String, media_id: String = "") -> String:
	return TrackGuard.refusal(doc, seq, track, what, media_id)
