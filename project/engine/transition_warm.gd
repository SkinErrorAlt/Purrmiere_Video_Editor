extends Node

const TransitionRegistry := preload("res://engine/transition_registry.gd")
const TransitionUnit := preload("res://engine/transition_unit.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const WARM_SIZE := Vector2i(16, 16)
const HOLD_FRAMES := 2
const LOOK_EVERY_MS := 400

static var plant_cold: bool = false

var watch_session: bool = true
var _vp: SubViewport = null
var _unit: Node = null
var _held: int = 0
var _holding: String = ""
var _queue: PackedStringArray = PackedStringArray()
var _idle: PackedStringArray = PackedStringArray()
var _queued: Dictionary = {}
var _warm: Dictionary = {}
var _seen_doc: int = 0
var _seen_serial: int = -1
var _next_look: int = 0
var warmed: int = 0
var last_warm_usec: int = 0


func _ready() -> void:
	name = "TransitionWarm"
	var reg: RefCounted = TransitionRegistry.shared()
	if not reg.is_connected("changed", _on_library_changed):
		reg.connect("changed", _on_library_changed)


static func ids_in_project(doc: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	var seen: Dictionary = {}
	for s: Variant in doc.get("sequences"):
		if s == null:
			continue
		for t: Variant in s.get("video_tracks"):
			if t == null:
				continue
			for c: Variant in t.get("clips"):
				if c == null:
					continue
				_take(TransitionRegistry.library_id(c.get("transition_in")), seen, out)
				_take(TransitionRegistry.library_id(c.get("transition_out")), seen, out)
			for ft: Variant in t.get("free_transitions"):
				if ft is Dictionary:
					_take(TransitionRegistry.library_id(FreeTransition.spec_of(ft)), seen, out)
	return out


static func _take(id: String, seen: Dictionary, out: PackedStringArray) -> void:
	if id.is_empty() or seen.has(id):
		return
	seen[id] = true
	out.append(id)


func is_warm(id: String) -> bool:
	return _warm.has(id)


func pending() -> int:
	return _queue.size() + (1 if _unit != null else 0)


func idle_pending() -> int:
	return _idle.size()


func busy() -> bool:
	return pending() > 0


func queue(id: String, soon: bool = true) -> void:
	if id.is_empty() or _warm.has(id) or plant_cold:
		return
	if _queued.has(id):
		if not soon or _queue.has(id):
			return
		_idle.remove_at(_idle.find(id))
	_queued[id] = true
	if soon:
		_queue.insert(0, id)
	else:
		_idle.append(id)


func queue_project(doc: Object) -> int:
	var ids: PackedStringArray = ids_in_project(doc)
	var added: int = 0
	for i: int in range(ids.size() - 1, -1, -1):
		var id: String = ids[i]
		if not _warm.has(id) and not _queue.has(id) and id != _holding:
			queue(id, true)
			added += 1
	return added


func queue_library() -> void:
	var reg: RefCounted = TransitionRegistry.shared()
	for id: String in reg.call("ids"):
		queue(id, false)


func forget() -> void:
	_warm = {}


func _on_library_changed() -> void:
	_warm = {}
	_seen_serial = -1


func _look_at_session() -> void:
	if not watch_session:
		return
	var now: int = Time.get_ticks_msec()
	if now < _next_look:
		return
	_next_look = now + LOOK_EVERY_MS
	var session: Node = get_node_or_null("/root/Session")
	if session == null:
		return
	var doc: Object = session.get("doc")
	if doc == null:
		_seen_doc = 0
		return
	var serial: int = int(doc.get("serial"))
	if doc.get_instance_id() == _seen_doc and serial == _seen_serial:
		return
	_seen_doc = doc.get_instance_id()
	_seen_serial = serial
	queue_project(doc)


func _build() -> void:
	if _vp != null:
		return
	_vp = SubViewport.new()
	_vp.name = "TransitionWarmViewport"
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.size = WARM_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)


func step(idle_ok: bool = false) -> bool:
	_look_at_session()
	if _unit != null:
		_held += 1
		if _held < HOLD_FRAMES:
			return false
		_warm[_holding] = true
		warmed += 1
		_unit.get_parent().remove_child(_unit)
		_unit.queue_free()
		_unit = null
		_holding = ""
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false
	var id: String = ""
	if not _queue.is_empty():
		id = _queue[0]
		_queue.remove_at(0)
	elif idle_ok and not _idle.is_empty():
		id = _idle[0]
		_idle.remove_at(0)
	else:
		return false
	_queued.erase(id)
	if _warm.has(id):
		return false
	var t0: int = Time.get_ticks_usec()
	var reg: RefCounted = TransitionRegistry.shared()
	var info: Dictionary = reg.call("resolve", id)
	if bool(info.get("fell_back", false)) or not bool(info.get("ok", false)):
		_warm[id] = true
		return true
	_build()
	_unit = TransitionUnit.new()
	_unit.name = "Warm_" + id
	_vp.add_child(_unit)
	_unit.call("fit", WARM_SIZE)
	_unit.call("use", info)
	_unit.call("set_pyramid", bool(info.get("pyramid", false)))
	_unit.call("set_blend", 0)
	_unit.call("apply", 0.5, 1.0, 1.0, 1.0, 0.0, reg.call("values_at", id, {}, 0.5, 1.0, 30.0))
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_holding = id
	_held = 0
	last_warm_usec = Time.get_ticks_usec() - t0
	return true
