extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const FreeCmds := preload("res://doc/commands/free_transition_cmds.gd")
const PREFIX := "free:"
const PROGRESS := "progress"

static var _cache: Dictionary = {}


static func id_for(track_id: String, ft_id: String) -> String:
	return PREFIX + track_id + "/" + ft_id


static func is_free(clip_id: String) -> bool:
	return clip_id.begins_with(PREFIX)


static func parts(clip_id: String) -> PackedStringArray:
	if not is_free(clip_id):
		return PackedStringArray()
	var rest: String = clip_id.substr(PREFIX.length())
	var at: int = rest.find("/")
	if at < 0:
		return PackedStringArray()
	return PackedStringArray([rest.substr(0, at), rest.substr(at + 1)])


static func ft_of(s: Sequence, clip_id: String) -> Dictionary:
	var p: PackedStringArray = parts(clip_id)
	if s == null or p.is_empty():
		return {}
	var tr: Track = s.track_by_id(p[0])
	return FreeTransition.by_id(tr.free_transitions, p[1]) if tr != null else {}


static func stand_in(s: Sequence, clip_id: String) -> Clip:
	var ft: Dictionary = ft_of(s, clip_id)
	if ft.is_empty():
		return null
	var stamp: int = ft.hash()
	var hit: Array = _cache.get(clip_id, [])
	if not hit.is_empty() and int(hit[0]) == stamp:
		return hit[1]
	var c: Clip = Clip.new()
	c.id = clip_id
	c.start = FreeTransition.start_of(ft)
	c.duration = FreeTransition.duration_of(ft)
	var spec: Dictionary = FreeTransition.spec_of(ft).duplicate(true)
	spec["duration"] = c.duration
	spec["offset"] = 0.0
	spec.erase("align")
	c.transition_in = spec
	if _cache.size() > 32:
		_cache.clear()
	_cache[clip_id] = [stamp, c]
	return c


static func held_stand_in(s: Sequence) -> Clip:
	if s == null:
		return null
	var held: Dictionary = s.held_free()
	if held.is_empty():
		return null
	return stand_in(s, id_for(String(held.get("track_id", "")), String(held.get("id", ""))))


static func key_of(path: String) -> String:
	return path.substr(Clip.TRANSITION_PATH.length()) if path.begins_with(Clip.TRANSITION_PATH) else ""


static func command(s: Sequence, clip_id: String, path: String, p: Dictionary) -> Command:
	var pr: PackedStringArray = parts(clip_id)
	var key: String = key_of(path)
	if s == null or pr.is_empty() or key.is_empty():
		return null
	return FreeCmds.SetFreeParam.new(s.id, pr[0], pr[1], key, p)


static func properties(c: Clip, label: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var prog: String = Clip.TRANSITION_PATH + PROGRESS
	out.append({"path": prog, "label": label + " · Progress", "animated": AnimProp.is_animated(c.get_param(prog))})
	var params: Variant = c.transition_in.get("params", {})
	if params is Dictionary:
		for key: Variant in (params as Dictionary).keys():
			if String(key) == PROGRESS:
				continue
			var path: String = Clip.TRANSITION_PATH + String(key)
			if not AnimProp.is_animated(c.get_param(path)):
				continue
			out.append({"path": path, "label": label + " · " + String(key).capitalize(), "animated": true})
	return out


static func held_id(s: Sequence) -> String:
	if s == null:
		return ""
	var held: Dictionary = s.held_free()
	if held.is_empty():
		return ""
	return id_for(String(held.get("track_id", "")), String(held.get("id", "")))
