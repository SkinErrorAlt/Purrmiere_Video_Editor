extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const MENU_PREFIX := "view_sfx:"
const MAP_KEY := "view_audio"
const ON_LABEL := "Heard in one view"
const OFF_LABEL := "Heard in every view"


static func owners_of(s: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or c == null:
		return out
	var tr: Track = s.track_of(c.id)
	if tr == null or not tr.is_sound(c):
		return out
	for t2: Track in s.picture_tracks():
		for v: Clip in t2.clips:
			if v.end() <= c.start or v.start >= c.end():
				continue
			for e: Dictionary in v.effects:
				if String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID:
					continue
				var map: Dictionary = ViewMap.of(e)
				var count: int = maxi(ViewMap.crop_count(e), 1)
				if map.is_empty() and count < 2:
					continue
				out.append({"video": v, "uid": String(e.get("uid", "")), "map": map, "count": count, "names": ViewMap.region_names(e)})
	return out


static func name_of(one: Dictionary, index: int) -> String:
	var names: PackedStringArray = one.get("names", PackedStringArray())
	return String(names[index]) if index < names.size() and not String(names[index]).is_empty() else "View " + str(index + 1)


static func clip_items(s: Sequence, c: Clip) -> Array:
	var out: Array = []
	var owners: Array[Dictionary] = owners_of(s, c)
	if owners.is_empty():
		return out
	for one: Dictionary in owners:
		var uid: String = String(one["uid"])
		var map: Dictionary = one["map"]
		var sub: Array = []
		for i: int in int(one["count"]):
			var on: bool = ViewMap.clip_in_view(map, i, c.id)
			sub.append(PmMenu.check_item("%s%s:%d" % [MENU_PREFIX, uid, i], name_of(one, i), on))
		if sub.size() < 2:
			continue
		out.append(PmMenu.sub_item("view_sfx_sub:" + uid, "Heard only in", sub))
	if not out.is_empty():
		out.append(PmMenu.separator())
	return out


static func on_clip_menu(d: Project, s: Sequence, id: String, clip_id: String) -> bool:
	if not id.begins_with(MENU_PREFIX):
		return false
	var rest: String = id.substr(MENU_PREFIX.length())
	var cut: int = rest.rfind(":")
	if cut <= 0:
		return true
	var uid: String = rest.substr(0, cut)
	var index: int = int(rest.substr(cut + 1))
	set_heard(d, s, uid, index, clip_id)
	return true


static func set_heard(d: Project, s: Sequence, uid: String, index: int, clip_id: String) -> bool:
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	for one: Dictionary in owners_of(s, c):
		if String(one["uid"]) != uid:
			continue
		var video: Clip = one["video"]
		var map: Dictionary = one["map"]
		var on: bool = not ViewMap.clip_in_view(map, index, clip_id)
		var next: Dictionary = ViewMap.with_clip(map, index, clip_id, on, int(one["count"]))
		if next.is_empty():
			return false
		var label: String = ON_LABEL if on else OFF_LABEL
		var cmds: Array[Command] = [EffectCmds.SetEffectParam.new(s.id, video.id, uid, MAP_KEY, JSON.stringify(next), -1.0)]
		return Verbs.run(d, label, cmds)
	return false
