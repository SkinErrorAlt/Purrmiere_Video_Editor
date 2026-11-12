extends RefCounted

const VERSION := 1


class SplitSharedSound extends "res://doc/commands/composite.gd":
	const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
	const ViewMap := preload("res://doc/view_map.gd")

	var video_id: String = ""
	var uid: String = ""
	var made_tracks: PackedStringArray = PackedStringArray()
	var made_clips: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_video_id: String, p_uid: String) -> void:
		label = "Give each view its own sound"
		seq_id = p_seq_id
		video_id = p_video_id
		uid = p_uid

	func _new_track(doc: Project, s: Sequence, beside: Track, view_name: String, step: int) -> Track:
		var list: Array[Track] = s.tracks_of_kind(beside.kind)
		var at: int = list.find(beside) + step
		var made: Track = doc.make_track(beside.kind, beside.label + " " + view_name)
		apply(doc, TrackCmds.AddTrack.new(seq_id, beside.kind, at, made.to_dict()))
		made_tracks.append(made.id)
		return s.track_by_id(made.id)

	func _copy_onto(doc: Project, s: Sequence, c: Clip, tr: Track) -> String:
		var d: Dictionary = c.to_dict()
		var fresh: String = doc.mint_id("c")
		d["id"] = fresh
		apply(doc, ClipCmds.PlaceClip.new(seq_id, tr.id, d))
		made_clips.append(fresh)
		return fresh

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var video: Clip = s.clip_by_id(video_id)
		if video == null:
			return false
		var entry: Dictionary = video.effect_by_uid(uid)
		var map: Dictionary = ViewMap.of(entry)
		if map.is_empty():
			return false
		var names: PackedStringArray = ViewMap.region_names(entry)
		var fixed: Dictionary = map.duplicate(true)
		var views: Array = fixed.get("views", [])
		for tr: Track in s.all_tracks().duplicate():
			if tr.locked:
				continue
			var hearers: Array[int] = []
			for i: int in views.size():
				if ((views[i] as Dictionary).get("tracks", []) as Array).has(tr.id):
					hearers.append(i)
			if hearers.size() < 2:
				continue
			var governed: Array[Clip] = []
			for c: Clip in tr.clips:
				if c != video and ViewMap.reaches(map, video, c, tr.id):
					governed.append(c)
			if governed.is_empty():
				continue
			for k: int in range(1, hearers.size()):
				var vi: int = hearers[k]
				var view_name: String = names[vi] if vi < names.size() else "View " + str(vi + 1)
				var dest: Track = _new_track(doc, s, tr, view_name, k)
				if dest == null:
					return false
				for c2: Clip in governed:
					_copy_onto(doc, s, c2, dest)
				var tl: Array = (views[vi] as Dictionary).get("tracks", [])
				tl[tl.find(tr.id)] = dest.id
		var named: Dictionary = {}
		for i: int in views.size():
			for cid: Variant in (views[i] as Dictionary).get("clips", []):
				var id: String = String(cid)
				if not named.has(id):
					named[id] = []
				(named[id] as Array).append(i)
		for id: Variant in named.keys():
			var owners: Array = named[id]
			if owners.size() < 2:
				continue
			var c3: Clip = s.clip_by_id(String(id))
			var own: Track = s.track_of(String(id))
			if c3 == null or own == null or own.locked:
				continue
			for k2: int in range(1, owners.size()):
				var vi2: int = int(owners[k2])
				var view_name2: String = names[vi2] if vi2 < names.size() else "View " + str(vi2 + 1)
				var dest2: Track = _new_track(doc, s, own, view_name2, k2)
				if dest2 == null:
					return false
				var copy_id: String = _copy_onto(doc, s, c3, dest2)
				var cl: Array = (views[vi2] as Dictionary).get("clips", [])
				cl[cl.find(String(id))] = copy_id
		if made_clips.is_empty():
			return false
		fixed["views"] = views
		apply(doc, EffectCmds.SetEffectParam.new(seq_id, video_id, uid, "view_audio", JSON.stringify(fixed), -1.0))
		return true


class SetOffset extends "res://doc/commands/clip_cmds.gd".SetClipParam:
	var audio: bool = false

	func _init(p_seq_id: String, p_clip_id: String, p_path: String, p_anim: Dictionary, p_moves_sound: bool = false) -> void:
		super(p_seq_id, p_clip_id, p_path, p_anim)
		label = "Sync offset"
		audio = p_moves_sound


class SwitchView extends "res://doc/commands/command.gd":
	const ViewSwitch := preload("res://doc/view_switch.gd")

	var clip_id: String = ""
	var uid: String = ""
	var view: int = 0
	var at: float = 0.0
	var record: bool = false
	var path: String = ""
	var anim: Dictionary = {}
	var old: Dictionary = {}
	var keyed: bool = false
	var why: String = ""
	var group_only: bool = false
	var more: Array = []
	var more_old: Array = []
	var _planned: bool = false

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_view: int, p_at: float, p_record: bool, p_group_only: bool = false) -> void:
		label = "Switch group" if p_group_only else "Switch view"
		group_only = p_group_only
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		view = p_view
		at = p_at
		record = p_record
		path = ViewSwitch.path_of(p_uid)

	func live_key() -> String:
		return "clip_param|" + clip_id + "|" + path

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		if not _planned:
			_planned = true
			var p: Dictionary = ViewSwitch.plan_group(seq(doc), c, uid, view, at, record) if group_only else ViewSwitch.plan(seq(doc), c, uid, view, at, record)
			why = String(p["why"])
			if not bool(p["ok"]):
				ok = false
				return
			anim = p["anim"]
			keyed = bool(p["keyed"])
			path = String(p.get("path", path))
			more = p.get("more", [])
		old = c.get_param(path).duplicate(true)
		ok = c.set_param(path, anim)
		more_old = []
		for m: Variant in more:
			var md: Dictionary = m
			more_old.append(c.get_param(String(md["path"])).duplicate(true))
			c.set_param(String(md["path"]), md["anim"])
		if ok and not _auto_done:
			_auto_done = true
			_auto_match(c)
		doc.touch("meta")

	var _auto_done: bool = false
	var matched: Array = []

	func _auto_match(c: Clip) -> void:
		var e: Dictionary = c.effect_by_uid(uid)
		var named: GDScript = load("res://doc/named_offsets.gd")
		if e.is_empty() or not bool(named.call("auto_on", e)):
			return
		var cuts: Array = load("res://doc/view_offsets.gd").call("cuts_of", e, c)
		var local: float = clampf(at - c.start, 0.0, maxf(c.duration, 0.0))
		var k: int = int(load("res://doc/view_offsets.gd").call("cut_index_at", cuts, local))
		if k < 1:
			return
		var made: Dictionary = named.call("plan", e, c, k)
		matched = made.get("matched", [])
		var props: Dictionary = made.get("props", {})
		var vm: GDScript = load("res://doc/view_map.gd")
		for idx: Variant in props.keys():
			var next: Dictionary = props[idx]
			if next.is_empty():
				continue
			var mp: String = String(vm.call("param_path", e, String(vm.call("offset_key", int(idx)))))
			more.append({"path": mp, "anim": next})
			more_old.append(c.get_param(mp).duplicate(true))
			c.set_param(mp, next)

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return
		for i: int in range(more.size() - 1, -1, -1):
			var mp: String = String((more[i] as Dictionary)["path"])
			var mo: Dictionary = more_old[i] if i < more_old.size() else {}
			if mo.is_empty():
				c.erase_param(mp)
			else:
				c.set_param(mp, mo)
		if old.is_empty():
			c.erase_param(path)
		else:
			c.set_param(path, old)
		doc.touch("meta")
