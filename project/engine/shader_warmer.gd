extends Node

const EffectRegistry := preload("res://engine/effect_registry.gd")

const WARM_SIZE := 16
const IDLE_PER_FRAME := 1
const URGENT_PER_FRAME := 4
const IDLE_AFTER_MS := 3000
const FRAME_CAP_PATH := "res://host/frame_cap.gd"

var _vp: SubViewport = null
var _rects: Array[ColorRect] = []
var _pending: Array = []
var _queued: Dictionary = {}
var _warmed: Dictionary = {}
var _urgent: int = 0
var _enabled: bool = true


func _ready() -> void:
	process_priority = 500
	set_process(true)
	if not Prefs.is_registered("playback.warm_shaders"):
		Prefs.register("playback.warm_shaders", true, {"label": "Compile effect shaders ahead of time so adding an effect does not stutter", "type": "bool"})
	_enabled = bool(Prefs.get_value("playback.warm_shaders"))


func _build() -> void:
	if _vp != null:
		return
	_vp = SubViewport.new()
	_vp.name = "ShaderWarmViewport"
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(WARM_SIZE, WARM_SIZE)
	add_child(_vp)


func _slot(index: int) -> ColorRect:
	while _rects.size() <= index:
		var r := ColorRect.new()
		r.size = Vector2(WARM_SIZE, WARM_SIZE)
		_vp.add_child(r)
		_rects.append(r)
	return _rects[index]


func is_warm(id: String, pass_index: int) -> bool:
	return _warmed.has(id + "#" + str(pass_index))


func pending() -> int:
	return _pending.size()


func warmed_count() -> int:
	return _warmed.size()


func queue_effect(id: String, urgent: bool = false) -> void:
	if not _enabled or id == "":
		return
	var reg: RefCounted = EffectRegistry.shared()
	var def: Dictionary = reg.call("get_def", id)
	var passes: Array = def.get("passes", [])
	for i: int in range(passes.size()):
		var key: String = id + "#" + str(i)
		if _warmed.has(key) or _queued.has(key):
			continue
		_queued[key] = true
		if urgent:
			_pending.push_front(key)
		else:
			_pending.push_back(key)
	if urgent:
		_urgent = maxi(_urgent, 8)


func warm_all() -> void:
	if not _enabled:
		return
	var reg: RefCounted = EffectRegistry.shared()
	for e: Dictionary in reg.call("list"):
		if String(e.get("domain", "picture")) == "audio":
			continue
		queue_effect(String(e.get("id", "")), false)


func _user_busy() -> bool:
	var cap: GDScript = load(FRAME_CAP_PATH)
	if cap == null or int(cap.get("ours")) < 0:
		return false
	return Time.get_ticks_msec() - int(cap.get("active_ms")) < IDLE_AFTER_MS


func _process(_dt: float) -> void:
	if _pending.is_empty():
		return
	if _urgent <= 0 and _user_busy():
		return
	_build()
	var budget: int = URGENT_PER_FRAME if _urgent > 0 else IDLE_PER_FRAME
	if _urgent > 0:
		_urgent -= 1
	var reg: RefCounted = EffectRegistry.shared()
	var done: int = 0
	while done < budget and not _pending.is_empty():
		var key: String = String(_pending.pop_front())
		_queued.erase(key)
		var cut: int = key.rfind("#")
		if cut < 0:
			continue
		var id: String = key.substr(0, cut)
		var pass_index: int = int(key.substr(cut + 1))
		_warmed[key] = true
		var mat: ShaderMaterial = reg.call("make_material", id, pass_index)
		if mat == null:
			continue
		_slot(done).material = mat
		done += 1
	for i: int in range(done, _rects.size()):
		_rects[i].material = null
