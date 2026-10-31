extends RefCounted

const VERSION := 1


class CutViews extends "res://doc/commands/composite.gd":
	const EditCmds := preload("res://doc/commands/edit_cmds.gd")
	const ViewMap := preload("res://doc/view_map.gd")

	var video_id: String = ""
	var uid: String = ""
	var colour_audio: bool = true

	func _init(p_seq_id: String, p_video_id: String, p_uid: String, p_colour_audio: bool = true) -> void:
		label = "Cut on view changes"
		seq_id = p_seq_id
		video_id = p_video_id
		uid = p_uid
		colour_audio = p_colour_audio

	func _family(s: Sequence, video: Clip, map: Dictionary, scope_all: bool) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray([video.id])
		for tr: Track in s.sound_carriers():
			if tr.locked:
				continue
			for c: Clip in tr.clips:
				if not tr.is_sound(c) or c.end() <= video.start + EditMath.EPS or c.start >= video.end() - EditMath.EPS:
					continue
				if map.is_empty():
					if not video.link_id.is_empty() and c.link_id == video.link_id:
						out.append(c.id)
					continue
				if not ViewMap.governs(map, tr.id, c.id):
					continue
				if not scope_all and not ViewMap.in_family(video, c) and not ViewMap.named_clip(map, c.id):
					continue
				out.append(c.id)
		return out

	func _view_over(spans: Array[Dictionary], mid: float) -> int:
		for sp: Dictionary in spans:
			if mid >= float(sp["t0"]) - EditMath.EPS and mid < float(sp["t1"]):
				return int(sp["view"])
		return -1

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var video: Clip = s.clip_by_id(video_id)
		if video == null:
			return false
		var own: Track = s.track_of(video_id)
		if own == null or own.locked:
			return false
		var entry: Dictionary = video.effect_by_uid(uid)
		var map: Dictionary = ViewMap.of(entry)
		var at_view: Array[Dictionary] = ViewMap.steps(entry, video)
		if at_view.is_empty():
			return false
		var span0: float = video.start
		var span1: float = video.end()
		var scope_all: bool = String(map.get("scope", "group")) == "all"
		var ids: PackedStringArray = _family(s, video, map, scope_all)
		var spans: Array[Dictionary] = []
		for i: int in at_view.size():
			var t0: float = maxf(float(at_view[i]["t"]), span0)
			var t1: float = span1 if i + 1 >= at_view.size() else minf(float(at_view[i + 1]["t"]), span1)
			if t1 - t0 <= EditMath.EPS:
				continue
			spans.append({"t0": t0, "t1": t1, "view": int(at_view[i]["view"])})
		if spans.size() < 2:
			return false
		for i: int in range(1, spans.size()):
			var at: float = float(spans[i]["t0"])
			var here: PackedStringArray = PackedStringArray()
			for id: String in ids:
				var c: Clip = s.clip_by_id(id)
				if c == null:
					continue
				if at > c.start + EditMath.EPS and at < c.end() - EditMath.EPS:
					here.append(id)
			if here.is_empty():
				continue
			var cut := EditCmds.SplitClips.new(seq_id, here, at, false)
			apply(doc, cut)
			if not cut.ok:
				continue
			for fresh: String in cut.right_ids:
				if not ids.has(fresh):
					ids.append(fresh)
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			var tr: Track = s.track_of(id)
			if c == null or tr == null:
				continue
			var view: int = _view_over(spans, (c.start + c.end()) * 0.5)
			if view < 0:
				continue
			var want: int = ViewMap.colour_for(map, view)
			if tr.is_sound(c):
				if not colour_audio:
					continue
				if not map.is_empty() and not ViewMap.hears(map, view, tr.id, id):
					want = -1
			if c.colour == want:
				continue
			apply(doc, ClipCmds.SetClipField.new(seq_id, id, "colour", want))
		return not steps.is_empty()
