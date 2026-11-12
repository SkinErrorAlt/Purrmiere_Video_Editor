extends Node

const EffectPass := preload("res://engine/effect_pass.gd")
const MAX_LAYERS := 64
const LAYER_STEP := 8
const BUDGET_BYTES := 1610612736
const FRAME_EPS := 0.0001
const FILL_KEEP_MS := 3000
const FILL_GIVE_UP_MS := 5000
const HINT_STEP := 2
const HINT_EXPORT := 3
const KIND_NEST := "nest"
const EXACT_STATES: PackedStringArray = ["exact", "static", "none"]
const U_TEX := "history_tex"
const U_LAYER := "history_layer"
const U_COUNT := "history_count"
const U_FPS := "history_fps"

static var disabled: bool = false
static var plant_play_only: bool = false
static var captures: int = 0
static var fill_frames: int = 0
static var allocations: int = 0


class Tap extends RefCounted:
	var uid: String = ""
	var effect_index: int = -1
	var spec: Dictionary = {}
	var in_tex: Texture2D = null
	var passes: Array = []
	var freeze_from: int = -1
	var reach: int = 0
	var sig: int = 0
	var rid: RID = RID()
	var tex: Texture2DArrayRD = null
	var size: Vector2i = Vector2i.ZERO
	var format: int = -1
	var slots: int = 0
	var frames: PackedInt64Array = PackedInt64Array()
	var sigs: PackedInt64Array = PackedInt64Array()
	var exacts: PackedByteArray = PackedByteArray()

	func valid(f: int, need_exact: bool) -> bool:
		if slots <= 0 or not rid.is_valid():
			return false
		var s: int = posmod(f, slots)
		if frames[s] != f or sigs[s] != sig:
			return false
		return not need_exact or exacts[s] == 1

	func slot_of(f: int) -> int:
		return posmod(f, slots) if slots > 0 else -1


var chain: Node = null
var taps: Array[Tap] = []
var filling: bool = false
var fill_frame: int = -1
var real_t: float = 0.0
var frame_now: int = 0
var exact_now: bool = false
var _frozen: Array = []
var _cap: Dictionary = {}
var _connected: bool = false
var _raw: bool = false
var _wait_frame: int = -1
var _wait_ms: int = 0
var gave_up: int = 0
var _drawn: bool = false
var _wanted_fill: bool = false
const DRAWN_META := "pm_history_drawn"


func _init() -> void:
	name = "History"


static func wants(def: Dictionary) -> bool:
	return def.get("history") is Dictionary


static func frame_of(t: float, fps: float) -> int:
	return int(floor(t * fps + FRAME_EPS))


static func max_of(spec: Dictionary) -> int:
	return clampi(int(spec.get("max", 16)), 1, MAX_LAYERS - 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for tap: Tap in taps:
			_free_ring(tap)
		taps = []


func wire(passes: Array[Dictionary], registry: RefCounted) -> void:
	var old: Dictionary = {}
	for tap: Tap in taps:
		old[tap.uid] = tap
	var made: Dictionary = {}
	var list: Array[Tap] = []
	for i: int in passes.size():
		var pd: Dictionary = passes[i]
		if String(pd.get("kind", "")) != "effect":
			continue
		var def: Dictionary = registry.call("get_def", String(pd.get("effect_id", ""))) if registry != null else {}
		if not wants(def):
			continue
		var uid: String = String(pd.get("uid", ""))
		var tap: Tap = made.get(uid, null)
		if tap == null:
			tap = old.get(uid, null)
			if tap == null:
				tap = Tap.new()
			old.erase(uid)
			tap.uid = uid
			tap.effect_index = int(pd.get("effect_index", -1))
			tap.spec = def["history"]
			tap.in_tex = pd.get("effect_in_tex", null)
			tap.freeze_from = i
			tap.passes = []
			made[uid] = tap
			list.append(tap)
		tap.passes.append(pd["pass"])
	for k: Variant in old.keys():
		_free_ring(old[k])
	taps = list
	_frozen = []
	filling = false
	_wanted_fill = false
	_drawn = false
	_cap = {}
	if not taps.is_empty() and not _connected:
		RenderingServer.frame_post_draw.connect(_on_post_draw)
		_connected = true
	elif taps.is_empty() and _connected:
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
		_connected = false


func active() -> bool:
	return not taps.is_empty() and not disabled


func holds() -> bool:
	return (filling or _wanted_fill) and not _raw


func raw_state() -> String:
	_raw = true
	var st: String = String(chain.call("state"))
	_raw = false
	return st


func first_frame() -> int:
	var c: Object = chain.get("clip")
	var fps: float = float(chain.get("seq_fps"))
	return int(ceil(float(c.get("start")) * fps - FRAME_EPS))


func can_fill() -> bool:
	if RenderingServer.get_rendering_device() == null:
		return false
	var src: Object = chain.get("source")
	if src == null:
		return false
	var m: Object = chain.get("media")
	if String(src.get("kind")) == KIND_NEST and m != null and String(m.get("kind")) == "adjust":
		return false
	return not bool(chain.get("waiting"))


func _nest_settled() -> bool:
	for ch: Node in chain.get_children():
		if ch.has_method("unsettled") and ch.has_method("render_time"):
			return not bool(ch.call("unsettled"))
	return true


func begin(t: float, hint: int) -> float:
	real_t = t
	if not active():
		filling = false
		_thaw()
		return t
	var fps: float = float(chain.get("seq_fps"))
	frame_now = frame_of(t, fps)
	exact_now = hint == HINT_STEP or hint == HINT_EXPORT
	var first: int = first_frame()
	var want: PackedInt64Array = PackedInt64Array()
	for tap: Tap in taps:
		tap.sig = _sig(tap)
		tap.reach = _reach(tap, t)
		for j: int in range(1, tap.reach + 1):
			var f: int = maxi(frame_now - j, first)
			if f < frame_now and not want.has(f):
				want.append(f)
	want.sort()
	filling = false
	if exact_now and not plant_play_only and can_fill():
		for f: int in want:
			var all_ok: bool = true
			for tap: Tap in taps:
				var needed: bool = f >= frame_now - tap.reach or (f == first and frame_now - tap.reach < first)
				if needed:
					if not tap.valid(f, true):
						all_ok = false
						break
			if not all_ok:
				filling = true
				fill_frame = f
				break
	_wanted_fill = false
	if filling and not _drawn:
		filling = false
		_wanted_fill = true
		_keep_settling()
	if filling:
		_freeze()
		_keep_settling()
		return float(fill_frame) / fps
	_thaw()
	return t


func time_for(t: float) -> float:
	if filling and absf(t - real_t) < 0.000001:
		return float(fill_frame) / float(chain.get("seq_fps"))
	return t


func after_update() -> void:
	if not active():
		return
	if filling and not _sizes_kept():
		_thaw()
	var k: int = fill_frame if filling else frame_now
	var sigs: Dictionary = {}
	for tap: Tap in taps:
		sigs[tap.uid] = tap.sig
		if not filling:
			_bind(tap, k)
	var st: String = raw_state()
	var src: Object = chain.get("source")
	var on_proxy: bool = src != null and bool(src.get("proxy_on"))
	if src != null and String(src.get("kind")) == KIND_NEST and not _nest_settled():
		st = "pending"
	var exact: bool = exact_now and EXACT_STATES.has(st) and not on_proxy
	var ok: bool = EXACT_STATES.has(st) or st == "approx" or st == "near"
	if filling and not exact:
		if _wait_frame != k:
			_wait_frame = k
			_wait_ms = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _wait_ms > FILL_GIVE_UP_MS:
			exact = true
			ok = true
			gave_up += 1
	_cap = {"frame": k, "exact": exact, "ok": ok, "sigs": sigs}


func _bind(tap: Tap, k: int) -> void:
	var first: int = first_frame()
	var layers: PackedInt32Array = PackedInt32Array()
	layers.resize(MAX_LAYERS)
	layers.fill(-1)
	var count: int = mini(tap.reach, MAX_LAYERS)
	for j: int in range(1, count + 1):
		var f: int = maxi(k - j, first)
		if f >= k:
			continue
		layers[j - 1] = _nearest(tap, f, k)
	for p: Variant in tap.passes:
		var ep: EffectPass = p as EffectPass
		if ep == null or not is_instance_valid(ep) or ep.mat == null:
			continue
		if tap.tex != null:
			ep.mat.set_shader_parameter(U_TEX, tap.tex)
		ep.mat.set_shader_parameter(U_LAYER, layers)
		ep.mat.set_shader_parameter(U_COUNT, count if tap.tex != null else 0)
		ep.mat.set_shader_parameter(U_FPS, float(chain.get("seq_fps")))


func _nearest(tap: Tap, f: int, k: int) -> int:
	if tap.slots <= 0:
		return -1
	if tap.valid(f, exact_now):
		return tap.slot_of(f)
	var best: int = -1
	var best_d: int = 1 << 30
	for s: int in tap.slots:
		var g: int = tap.frames[s]
		if g < 0 or g >= k or tap.sigs[s] != tap.sig:
			continue
		var d: int = absi(g - f)
		if d < best_d:
			best_d = d
			best = s
	return best


func layer_for_age(uid: String, age: int) -> int:
	for tap: Tap in taps:
		if tap.uid != uid:
			continue
		var k: int = frame_now
		var f: int = maxi(k - age, first_frame())
		if f >= k:
			return -1
		return _nearest(tap, f, k)
	return -1


func stamps(uid: String) -> Dictionary:
	for tap: Tap in taps:
		if tap.uid == uid:
			return {"frames": tap.frames, "exacts": tap.exacts, "slots": tap.slots, "reach": tap.reach, "size": tap.size}
	return {}


func _on_post_draw() -> void:
	if _cap.is_empty():
		return
	var cap: Dictionary = _cap
	_cap = {}
	if chain == null or not is_instance_valid(chain) or bool(chain.get("waiting")):
		return
	if not filling:
		_note_drawn()
	if not bool(cap.get("ok", false)):
		return
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd == null:
		return
	for tap: Tap in taps:
		_capture(rd, tap, int(cap["frame"]), int((cap["sigs"] as Dictionary).get(tap.uid, 0)), bool(cap["exact"]))


func _capture(rd: RenderingDevice, tap: Tap, frame: int, sig: int, exact: bool) -> void:
	if tap.in_tex == null or not is_instance_valid(tap.in_tex):
		return
	var src: RID = RenderingServer.texture_get_rd_texture(tap.in_tex.get_rid())
	if not src.is_valid():
		return
	var fmt: RDTextureFormat = rd.texture_get_format(src)
	if fmt == null or fmt.array_layers != 1 or fmt.width < 2 or fmt.height < 2:
		return
	var size: Vector2i = Vector2i(int(fmt.width), int(fmt.height))
	var need: int = _slots_for(tap, size, int(fmt.format))
	if need <= 0:
		return
	if tap.size != size or tap.format != int(fmt.format) or tap.slots < need or not tap.rid.is_valid():
		if not _alloc(rd, tap, size, int(fmt.format), need):
			return
	var slot: int = tap.slot_of(frame)
	if rd.texture_copy(src, tap.rid, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 1), 0, 0, 0, slot) != OK:
		return
	tap.frames[slot] = frame
	tap.sigs[slot] = sig
	tap.exacts[slot] = 1 if exact else 0
	captures += 1
	if filling and frame == fill_frame and exact:
		fill_frames += 1


func _slots_for(tap: Tap, size: Vector2i, _format: int) -> int:
	var want: int = mini(int(ceil(float(tap.reach + 2) / float(LAYER_STEP))) * LAYER_STEP, MAX_LAYERS)
	var per: int = maxi(size.x * size.y * 8, 1)
	var cap: int = maxi(BUDGET_BYTES / per, 3)
	return clampi(maxi(want, tap.slots if tap.size == size else 0), 3, mini(cap, MAX_LAYERS))


func _alloc(rd: RenderingDevice, tap: Tap, size: Vector2i, format: int, slots: int) -> bool:
	_free_ring(tap)
	var f: RDTextureFormat = RDTextureFormat.new()
	f.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	f.width = size.x
	f.height = size.y
	f.depth = 1
	f.array_layers = slots
	f.mipmaps = 1
	f.format = format
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var rid: RID = rd.texture_create(f, RDTextureView.new(), [])
	if not rid.is_valid():
		return false
	tap.rid = rid
	tap.tex = Texture2DArrayRD.new()
	tap.tex.texture_rd_rid = rid
	tap.size = size
	tap.format = format
	tap.slots = slots
	tap.frames = PackedInt64Array()
	tap.frames.resize(slots)
	tap.frames.fill(-1)
	tap.sigs = PackedInt64Array()
	tap.sigs.resize(slots)
	tap.exacts = PackedByteArray()
	tap.exacts.resize(slots)
	allocations += 1
	for p: Variant in tap.passes:
		var ep: EffectPass = p as EffectPass
		if ep != null and is_instance_valid(ep) and ep.mat != null:
			ep.mat.set_shader_parameter(U_TEX, tap.tex)
	return true


func _free_ring(tap: Tap) -> void:
	if tap == null:
		return
	if tap.tex != null:
		tap.tex.texture_rd_rid = RID()
	if tap.rid.is_valid():
		var rd: RenderingDevice = RenderingServer.get_rendering_device()
		if rd != null:
			rd.free_rid(tap.rid)
	tap.rid = RID()
	tap.tex = null
	tap.slots = 0
	tap.size = Vector2i.ZERO


func _reach(tap: Tap, t: float) -> int:
	var spec: Dictionary = tap.spec
	var mx: int = max_of(spec)
	var keys: Variant = spec.get("reach", null)
	if keys == null:
		return mx
	var list: Array = keys if keys is Array else [keys]
	var secs: Array = spec.get("seconds", []) if spec.get("seconds", []) is Array else []
	var c: Object = chain.get("clip")
	var effects: Array = c.get("effects")
	if tap.effect_index < 0 or tap.effect_index >= effects.size():
		return mx
	var e: Dictionary = effects[tap.effect_index]
	var registry: RefCounted = chain.get("registry")
	var def: Dictionary = registry.call("get_def", String(e.get("id", ""))) if registry != null else {}
	var fps: float = float(chain.get("seq_fps"))
	var local_t: float = t - float(c.get("start"))
	var product: float = 1.0
	for k: Variant in list:
		if k is int or k is float:
			product *= float(k)
			continue
		var key: String = String(k)
		var spec_p: Dictionary = {}
		for ps: Variant in def.get("params", []):
			if String((ps as Dictionary).get("key", "")) == key:
				spec_p = ps
				break
		if spec_p.is_empty():
			continue
		var v: float = EffectPass._to_float(chain.call("_eval_param", e, spec_p, local_t))
		if secs.has(key):
			v *= fps
		product *= absf(v)
	return clampi(int(ceil(product - 0.001)), 1, mx)


func _sig(tap: Tap) -> int:
	var c: Object = chain.get("clip")
	var src: Object = chain.get("source")
	var parts: Array = [String(src.get("kind")) if src != null else "", c.get("media_id"), c.get("start"), c.get("in_offset"), c.get("speed"), c.get("loop"), c.get("loop_in"), c.get("speeds"), (c.get("props") as Dictionary).get("time_interp", ""), chain.get("quality_scale"), chain.get("seq_fps"), c.get("masks")]
	var effects: Array = c.get("effects")
	for i: int in mini(tap.effect_index, effects.size()):
		parts.append(effects[i])
	return hash(var_to_str(parts))


func _freeze() -> void:
	var passes: Array = chain.get("passes")
	var from: int = 1 << 30
	for tap: Tap in taps:
		from = mini(from, tap.freeze_from)
	for i: int in range(maxi(from, 0), passes.size()):
		var vp: SubViewport = (passes[i] as Dictionary).get("pass", null)
		if vp == null or not is_instance_valid(vp):
			continue
		if vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_frozen.append(vp)


func _thaw() -> void:
	for v: Variant in _frozen:
		if is_instance_valid(v) and (v as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
			(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_frozen = []


func _keep_settling() -> void:
	var comp: Node = chain.call("_owner_comp") if chain.has_method("_owner_comp") else null
	if comp != null and "_settle_until_ms" in comp:
		comp.set("_settle_until_ms", maxi(int(comp.get("_settle_until_ms")), Time.get_ticks_msec() + FILL_KEEP_MS))


func _frozen_range() -> Array:
	var passes: Array = chain.get("passes")
	var from: int = 1 << 30
	for tap: Tap in taps:
		from = mini(from, tap.freeze_from)
	var out: Array = []
	for i: int in range(maxi(from, 0), passes.size()):
		var vp: SubViewport = (passes[i] as Dictionary).get("pass", null)
		if vp != null and is_instance_valid(vp):
			out.append(vp)
	return out


func _note_drawn() -> void:
	for vp: Variant in _frozen_range():
		(vp as SubViewport).set_meta(DRAWN_META, (vp as SubViewport).size)
	_drawn = true


func _sizes_kept() -> bool:
	for vp: Variant in _frozen_range():
		var v: SubViewport = vp
		if not v.has_meta(DRAWN_META) or Vector2i(v.get_meta(DRAWN_META)) != v.size:
			return false
	return true
