extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Io := preload("res://doc/io.gd")
const CHECK_EVERY := 8

static var _names_by_script: Dictionary = {}

var project: Project = null
var serial: int = -1
var running: bool = false
var restarts: int = 0
var reused: int = 0
var rebuilt: int = 0
var result: Dictionary = {}
var _lists: Array = []
var _outs: Array = []
var _list_at: int = 0
var _item_at: int = 0
var _cache: Dictionary = {}
var _fresh: Dictionary = {}
var _vals: Array = []
var _old: Array = []


func _init(p: Project) -> void:
	project = p


static func names_for(obj: Object) -> Array[StringName]:
	var script: Script = obj.get_script()
	if _names_by_script.has(script):
		return _names_by_script[script]
	var out: Array[StringName] = []
	if script != null:
		for prop: Dictionary in script.get_script_property_list():
			var n: String = String(prop["name"])
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not n.begins_with("_"):
				out.append(StringName(n))
	_names_by_script[script] = out
	return out


func begin() -> void:
	serial = project.serial
	_lists = [project.media]
	for s: Sequence in project.sequences:
		for t: Track in s.video_tracks:
			_lists.append(t.clips)
		for t: Track in s.audio_tracks:
			_lists.append(t.clips)
	_outs = []
	for list: Array in _lists:
		var out: Array = []
		out.resize(list.size())
		_outs.append(out)
	_list_at = 0
	_item_at = 0
	_fresh = {}
	reused = 0
	rebuilt = 0
	result = {}
	running = true


func step(budget_usec: int) -> bool:
	if not running:
		return false
	if project.serial != serial or not _shapes_hold():
		restarts += 1
		begin()
	var t0: int = Time.get_ticks_usec()
	var counted: int = 0
	while _list_at < _lists.size():
		var list: Array = _lists[_list_at]
		var out: Array = _outs[_list_at]
		while _item_at < list.size():
			out[_item_at] = _dict_for(list[_item_at])
			_item_at += 1
			counted += 1
			if counted % CHECK_EVERY == 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				return false
		_list_at += 1
		_item_at = 0
	result = _assemble()
	_old.append(_cache)
	_cache = _fresh
	_fresh = {}
	running = false
	return true


func _shapes_hold() -> bool:
	for i: int in _lists.size():
		if (_lists[i] as Array).size() != (_outs[i] as Array).size():
			return false
	return true


func take_old() -> Array:
	var out: Array = _old
	_old = []
	return out


func _dict_for(obj: Object) -> Dictionary:
	var names: Array[StringName] = names_for(obj)
	var n: int = names.size()
	if _vals.size() != n:
		_vals.resize(n)
	for i: int in n:
		var v: Variant = obj.get(names[i])
		if v is Array and not (v as Array).is_empty() and (v as Array)[0] is Object:
			v = _objects_sig(v)
		_vals[i] = v
	var h: int = _vals.hash()
	var iid: int = obj.get_instance_id()
	var e: Variant = _cache.get(iid)
	if e is Array and int((e as Array)[0]) == h:
		_fresh[iid] = e
		reused += 1
		return (e as Array)[1]
	var d: Dictionary = (obj.call("to_dict") as Dictionary).duplicate(true)
	_fresh[iid] = [h, d]
	rebuilt += 1
	return d


static func _objects_sig(list: Array) -> Array:
	var out: Array = []
	for o: Variant in list:
		if o is Object and (o as Object).has_method("to_dict"):
			out.append((o as Object).call("to_dict"))
		elif o is Object:
			out.append(inst_to_dict(o as Object))
		else:
			out.append(o)
	return out


func _assemble() -> Dictionary:
	var held: Array = []
	var empty_clips: Array[Clip] = []
	var empty_media: Array[MediaItem] = []
	for s: Sequence in project.sequences:
		for t: Track in s.video_tracks:
			held.append(t.clips)
			t.clips = empty_clips
		for t: Track in s.audio_tracks:
			held.append(t.clips)
			t.clips = empty_clips
	var media: Array[MediaItem] = project.media
	project.media = empty_media
	var d: Dictionary = Io.project_dict(project).duplicate(true)
	project.media = media
	var k: int = 0
	for s: Sequence in project.sequences:
		for t: Track in s.video_tracks:
			t.clips = held[k]
			k += 1
		for t: Track in s.audio_tracks:
			t.clips = held[k]
			k += 1
	d["media"] = _outs[0]
	var li: int = 1
	var seqs: Array = d.get("sequences", [])
	for si: int in seqs.size():
		var sd: Dictionary = seqs[si]
		for key: String in ["video_tracks", "audio_tracks"]:
			for td: Variant in sd.get(key, []):
				if li < _outs.size():
					(td as Dictionary)["clips"] = _outs[li]
				li += 1
	if li != _outs.size():
		print("SaveWalk: the tracks changed shape during the walk, saving the whole project at once")
		return Io.project_dict(project)
	return d


func take_result() -> Dictionary:
	var d: Dictionary = result
	result = {}
	_outs = []
	_lists = []
	return d


func cached() -> int:
	return _cache.size()
