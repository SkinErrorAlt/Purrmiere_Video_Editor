extends RefCounted

signal changed

const LOOK_SIDE := 1
const LOOK_BLEND := 2
const REGION_MAX := 8

static var _inst: RefCounted = null

var seq_id: String = ""
var clip_id: String = ""
var uid: String = ""
var hidden: Dictionary = {}
var chosen: Dictionary = {}
var overlap: bool = false
var look: int = LOOK_SIDE


static func instance() -> RefCounted:
	if _inst == null:
		var script: GDScript = load("res://engine/pair_sync_state.gd")
		_inst = script.new()
	return _inst


func active() -> bool:
	return not clip_id.is_empty() and not uid.is_empty()


func is_for(p_clip_id: String, p_uid: String) -> bool:
	return active() and clip_id == p_clip_id and uid == p_uid


func begin(p_seq_id: String, p_clip_id: String, p_uid: String) -> void:
	seq_id = p_seq_id
	clip_id = p_clip_id
	uid = p_uid
	hidden = {}
	chosen = {}
	overlap = false
	changed.emit()


func end() -> void:
	if not active():
		return
	seq_id = ""
	clip_id = ""
	uid = ""
	hidden = {}
	chosen = {}
	overlap = false
	changed.emit()


func is_hidden(index: int) -> bool:
	return bool(hidden.get(index, false))


func set_hidden(index: int, on: bool) -> void:
	if on:
		hidden[index] = true
	else:
		hidden.erase(index)
	changed.emit()


func is_chosen(index: int) -> bool:
	return bool(chosen.get(index, false))


func choose(index: int, add: bool) -> void:
	if add:
		if chosen.has(index):
			chosen.erase(index)
		else:
			chosen[index] = true
	else:
		var only: bool = chosen.size() == 1 and chosen.has(index)
		chosen = {}
		if not only:
			chosen[index] = true
	if chosen.size() < 2:
		overlap = false
	changed.emit()


func chosen_list() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in REGION_MAX:
		if chosen.has(i):
			out.append(i)
	return out


func set_overlap(on: bool) -> void:
	overlap = on and chosen.size() >= 2
	changed.emit()


func set_look(v: int) -> void:
	look = LOOK_BLEND if v == LOOK_BLEND else LOOK_SIDE
	changed.emit()


func overlapping() -> bool:
	return overlap and chosen.size() >= 2


func show_mask(count: int) -> int:
	var bits: int = 0
	for i: int in mini(count, REGION_MAX):
		if is_hidden(i):
			continue
		if overlapping() and not chosen.has(i):
			continue
		bits |= 1 << i
	return bits


func picture_mode() -> int:
	if overlapping() and look == LOOK_BLEND:
		return LOOK_BLEND
	return LOOK_SIDE


static func exporting() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var s: Node = (loop as SceneTree).root.get_node_or_null("Session")
	if s == null or not s.has_method("exporting"):
		return false
	return bool(s.call("exporting"))


func live_for(p_clip_id: String, p_uid: String) -> bool:
	return is_for(p_clip_id, p_uid) and not exporting()
