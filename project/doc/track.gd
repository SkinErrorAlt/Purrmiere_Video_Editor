extends RefCounted

const SELF := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const FreeTransition := preload("res://doc/free_transition.gd")

var id: String = ""
var kind: String = "video"
var label: String = ""
var colour: int = -1
var muted: bool = false
var solo: bool = false
var locked: bool = false
var lock_kind: String = ""
var lock_files: PackedStringArray = PackedStringArray()
var targeted: bool = false
var sync_lock: bool = true
var hidden: bool = false
var view_hidden: bool = false:
	set(value):
		view_hidden = value
		if value:
			view_hidden_seen = true
static var view_hidden_seen: bool = false
var listen_muted: bool = false:
	set(value):
		listen_muted = value
		if value:
			listen_seen = true
static var listen_seen: bool = false
var role: String = ""
var pinned: bool = false
var subtitle: bool = false
var speaker: String = ""
var push_up: float = 90.0
var push_back: bool = true
var height: float = 0.0
var volume: Dictionary = AnimProp.make(1.0)
var pan: Dictionary = AnimProp.make(0.0)
var effects: Array[Dictionary] = []
var free_transitions: Array[Dictionary] = []
var clips: Array[Clip] = []
var free: bool = false
var free_number: int = 0
var can_stack: bool = false
var foreign: bool = false
var _stack_valid: bool = false
var _stacked: bool = false
var _reach: float = 0.0

const STACK_EPS := 0.00001
const PICTURE := "video"
const SOUND := "audio"
const FREE_NAME := "Track"


static func _by_start(a: Clip, b: Clip) -> bool:
	if a.start == b.start:
		return a.id < b.id
	return a.start < b.start


static func _by_stack(a: Clip, b: Clip) -> bool:
	if a.stack != b.stack:
		return a.stack < b.stack
	return _by_start(a, b)


func accepts(clip_kind: String) -> bool:
	return free or clip_kind == kind


func makes_picture() -> bool:
	return free or kind == PICTURE


func makes_sound() -> bool:
	return free or kind == SOUND


func clip_kind(c: Clip) -> String:
	if c != null and not c.part.is_empty():
		return c.part
	return kind


func is_picture(c: Clip) -> bool:
	return clip_kind(c) == PICTURE


func is_sound(c: Clip) -> bool:
	return clip_kind(c) == SOUND


func part_for(wanted_kind: String) -> String:
	return "" if wanted_kind == kind else wanted_kind


static func is_classic_label(text: String) -> bool:
	if text.is_empty():
		return true
	var head: String = text.substr(0, 1)
	return (head == "V" or head == "A") and text.length() > 1 and text.substr(1).is_valid_int()


func shown_label() -> String:
	if free and free_number > 0 and is_classic_label(label):
		return FREE_NAME + " " + str(free_number)
	return label


func mark_changed() -> void:
	_stack_valid = false


func _note_inserted(c: Clip, at: int) -> void:
	_stack_valid = false
	if not c.part.is_empty() and c.part != kind:
		foreign = true
	if can_stack:
		return
	if c.stack != 0:
		can_stack = true
	elif at > 0 and clips[at - 1].end() > c.start + STACK_EPS:
		can_stack = true
	elif at + 1 < clips.size() and clips[at + 1].start < c.end() - STACK_EPS:
		can_stack = true


func scan_modes() -> void:
	_stack_valid = false
	var reach: float = -INF
	for c: Clip in clips:
		if not c.part.is_empty() and c.part != kind:
			foreign = true
		if c.stack != 0 or c.start < reach - STACK_EPS:
			can_stack = true
		reach = maxf(reach, c.end())


func _ensure_stack() -> void:
	if _stack_valid:
		return
	_stack_valid = true
	_stacked = false
	_reach = 0.0
	var reach: float = -INF
	for c: Clip in clips:
		if c.start < reach - STACK_EPS:
			_stacked = true
		reach = maxf(reach, c.end())
		_reach = maxf(_reach, c.duration)


func has_stack() -> bool:
	if not can_stack:
		return false
	_ensure_stack()
	return _stacked


func stack_sorted(list: Array[Clip]) -> Array[Clip]:
	var out: Array[Clip] = list.duplicate()
	out.sort_custom(_by_stack)
	return out


func clips_at(t: float) -> Array[Clip]:
	var out: Array[Clip] = []
	if not has_stack():
		var c: Clip = _plain_clip_at(t)
		if c != null:
			out.append(c)
		return out
	var i: int = index_of_last_starting_before(t)
	while i >= 0 and clips[i].start > t - _reach - STACK_EPS:
		var c2: Clip = clips[i]
		if t >= c2.start and t < c2.end():
			out.append(c2)
		i -= 1
	out.sort_custom(_by_stack)
	return out


func front_at(t: float) -> Clip:
	var list: Array[Clip] = clips_at(t)
	return list[list.size() - 1] if not list.is_empty() else null


func overlapping(c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if c == null:
		return out
	for o: Clip in clips_in_range(c.start, c.end()):
		if o != c and o.end() > c.start + STACK_EPS and o.start < c.end() - STACK_EPS:
			out.append(o)
	return out


func top_stack_over(t0: float, t1: float, skip: PackedStringArray = PackedStringArray()) -> int:
	var top: int = 0
	var any: bool = false
	for o: Clip in clips_in_range(t0, t1):
		if skip.has(o.id) or o.end() <= t0 + STACK_EPS or o.start >= t1 - STACK_EPS:
			continue
		top = o.stack if not any else maxi(top, o.stack)
		any = true
	return top + 1 if any else 0


func stack_spans(t0: float, t1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_stack():
		return out
	var edges: Array = []
	for c: Clip in clips_in_range(t0, t1):
		edges.append([c.start, 1])
		edges.append([c.end(), -1])
	edges.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var depth: int = 0
	var open_at: float = 0.0
	var peak: int = 0
	for e: Array in edges:
		var at: float = float(e[0])
		var before: int = depth
		depth += int(e[1])
		if before < 2 and depth >= 2:
			open_at = at
			peak = depth
		elif before >= 2 and depth >= 2:
			peak = maxi(peak, depth)
		elif before >= 2 and depth < 2:
			if at - open_at > STACK_EPS:
				out.append({"t0": open_at, "t1": at, "count": peak})
	return out


func sort_clips() -> void:
	clips.sort_custom(_by_start)
	_stack_valid = false


func insert_clip(c: Clip) -> void:
	var lo: int = 0
	var hi: int = clips.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if _by_start(c, clips[mid]):
			hi = mid
		else:
			lo = mid + 1
	clips.insert(lo, c)
	_note_inserted(c, lo)


func is_sorted() -> bool:
	for i: int in range(1, clips.size()):
		if _by_start(clips[i], clips[i - 1]):
			return false
	return true


func remove_clip(clip_id: String) -> Clip:
	for i: int in clips.size():
		if clips[i].id == clip_id:
			var c: Clip = clips[i]
			clips.remove_at(i)
			_stack_valid = false
			return c
	return null


func index_of_clip(c: Clip, start_hint: float) -> int:
	var i: int = index_of_last_starting_before(start_hint)
	var j: int = i
	while j >= 0 and clips[j].start >= start_hint - 0.000001:
		if clips[j] == c:
			return j
		j -= 1
	j = i + 1
	while j < clips.size() and clips[j].start <= start_hint + 0.000001:
		if clips[j] == c:
			return j
		j += 1
	return clips.find(c)


func erase_clip(c: Clip, start_hint: float) -> bool:
	var i: int = index_of_clip(c, start_hint)
	if i < 0:
		return false
	clips.remove_at(i)
	_stack_valid = false
	return true


func reposition(c: Clip, old_start: float) -> void:
	if erase_clip(c, old_start):
		insert_clip(c)


func clip_by_id(clip_id: String) -> Clip:
	for c: Clip in clips:
		if c.id == clip_id:
			return c
	return null


func index_of_last_starting_before(t: float) -> int:
	var lo: int = 0
	var hi: int = clips.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if clips[mid].start <= t:
			lo = mid + 1
		else:
			hi = mid
	return lo - 1


func clip_at(t: float) -> Clip:
	if has_stack():
		return front_at(t)
	return _plain_clip_at(t)


func _plain_clip_at(t: float) -> Clip:
	var i: int = index_of_last_starting_before(t)
	if i < 0:
		return null
	var c: Clip = clips[i]
	if t >= c.start and t < c.end():
		return c
	return null


func index_of_first_visible(t0: float) -> int:
	if has_stack():
		var k: int = index_of_last_starting_before(t0) + 1
		while k > 0 and clips[k - 1].start > t0 - _reach - STACK_EPS:
			k -= 1
		return k
	var i: int = index_of_last_starting_before(t0)
	if i >= 0 and clips[i].end() > t0:
		return i
	return i + 1


func clips_in_range(t0: float, t1: float) -> Array[Clip]:
	var out: Array[Clip] = []
	var i: int = index_of_first_visible(t0)
	while i < clips.size() and clips[i].start < t1:
		out.append(clips[i])
		i += 1
	return out


func clips_from(t: float) -> Array[Clip]:
	var out: Array[Clip] = []
	for c: Clip in clips:
		if c.start >= t:
			out.append(c)
	return out


func prev_clip(c: Clip) -> Clip:
	var i: int = clips.find(c)
	if i > 0:
		return clips[i - 1]
	return null


func next_clip(c: Clip) -> Clip:
	var i: int = clips.find(c)
	if i >= 0 and i < clips.size() - 1:
		return clips[i + 1]
	return null


func end_time() -> float:
	var e: float = 0.0
	for c: Clip in clips:
		e = maxf(e, c.end())
	return e


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "kind": kind, "label": label}
	if colour != -1:
		d["colour"] = colour
	if muted:
		d["muted"] = true
	if solo:
		d["solo"] = true
	if locked:
		d["locked"] = true
	if not lock_kind.is_empty():
		d["lock_kind"] = lock_kind
	if not lock_files.is_empty():
		d["lock_files"] = Array(lock_files)
	if targeted:
		d["targeted"] = true
	if not sync_lock:
		d["sync_lock"] = false
	if hidden:
		d["hidden"] = true
	if view_hidden:
		d["view_hidden"] = true
	if listen_muted:
		d["listen_muted"] = true
	if not role.is_empty():
		d["role"] = role
	if pinned:
		d["pinned"] = true
	if subtitle:
		d["subtitle"] = true
	if not speaker.is_empty():
		d["speaker"] = speaker
	if push_up != 90.0:
		d["push_up"] = push_up
	if not push_back:
		d["push_back"] = false
	if height != 0.0:
		d["height"] = height
	if volume != AnimProp.make(1.0):
		d["volume"] = volume.duplicate(true)
	if pan != AnimProp.make(0.0):
		d["pan"] = pan.duplicate(true)
	if not effects.is_empty():
		d["effects"] = effects.duplicate(true)
	if not free_transitions.is_empty():
		d[FreeTransition.FIELD] = FreeTransition.to_array(free_transitions)
	var cs: Array = []
	for c: Clip in clips:
		cs.append(c.to_dict())
	d["clips"] = cs
	return d


static func from_dict(d: Dictionary) -> SELF:
	var t: SELF = SELF.new()
	t.apply_dict(d)
	return t


func apply_dict(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	kind = str(d.get("kind", "video"))
	label = str(d.get("label", ""))
	colour = int(d.get("colour", -1))
	muted = bool(d.get("muted", false))
	solo = bool(d.get("solo", false))
	locked = bool(d.get("locked", false))
	lock_kind = str(d.get("lock_kind", ""))
	lock_files = PackedStringArray()
	for f: Variant in d.get("lock_files", []):
		lock_files.append(str(f))
	targeted = bool(d.get("targeted", false))
	sync_lock = bool(d.get("sync_lock", true))
	hidden = bool(d.get("hidden", false))
	view_hidden = bool(d.get("view_hidden", false))
	listen_muted = bool(d.get("listen_muted", false))
	role = str(d.get("role", ""))
	pinned = bool(d.get("pinned", false))
	subtitle = bool(d.get("subtitle", false))
	speaker = str(d.get("speaker", ""))
	push_up = float(d.get("push_up", 90.0))
	push_back = bool(d.get("push_back", true))
	height = float(d.get("height", 0.0))
	volume = (d["volume"] as Dictionary).duplicate(true) if d.get("volume") is Dictionary else AnimProp.make(1.0)
	pan = (d["pan"] as Dictionary).duplicate(true) if d.get("pan") is Dictionary else AnimProp.make(0.0)
	effects = Clip._dicts(d.get("effects", []))
	free_transitions = FreeTransition.normalise_list(d.get(FreeTransition.FIELD, []))
	clips = []
	for c: Variant in d.get("clips", []):
		if c is Dictionary:
			clips.append(Clip.from_dict(c))
	if not is_sorted():
		sort_clips()
	can_stack = false
	foreign = false
	scan_modes()


func header_dict() -> Dictionary:
	var d: Dictionary = to_dict()
	d.erase("clips")
	d.erase(FreeTransition.FIELD)
	return d
