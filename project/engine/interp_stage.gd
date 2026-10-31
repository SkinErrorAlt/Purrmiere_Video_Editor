extends Node

const FrameSource := preload("res://engine/frame_source.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const TimeInterp := preload("res://engine/time_interp.gd")
const MediaItem := preload("res://doc/media_item.gd")
const BLEND_SHADER := "res://engine/interp_blend.gdshader"
const LUMA_SHADER := "res://engine/interp_luma.gdshader"
const SEARCH_SHADER := "res://engine/interp_search.gdshader"
const REFINE_SHADER := "res://engine/interp_refine.gdshader"
const WARP_SHADER := "res://engine/interp_warp.gdshader"
const HINT_STEP := 2
const HINT_EXPORT := 3
const LANE_PREFIX := "interp_"
const LANE_IDLE_MS := 15000
const PRUNE_EVERY_MS := 2000

static var _shaders: Dictionary = {}
static var _live: Dictionary = {}
static var _lanes: Dictionary = {}
static var _prune_ms: int = 0

var mode: String = ""
var partner: FrameSource = null
var partner_handle: int = -1
var out_pass: EffectPass = null
var luma_passes: Array[EffectPass] = []
var search_pass: EffectPass = null
var refine_passes: Array[EffectPass] = []
var weight: float = 0.0
var pair_weight: float = 0.0
var src_time: float = 0.0
var a_pts: float = 0.0
var b_pts: float = 0.0
var waiting_partner: bool = false
var flow_running: bool = true
var given_state: String = ""
var built_size: Vector2i = Vector2i.ZERO


static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


static func _pass(path: String, label: String) -> EffectPass:
	var m := ShaderMaterial.new()
	m.shader = shader(path)
	var types: Dictionary = {}
	for u: Dictionary in m.shader.get_shader_uniform_list(true):
		types[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	var p: EffectPass = EffectPass.new()
	p.name = label
	p.setup(m, types)
	return p


func _init() -> void:
	name = "TimeInterp"
	partner = FrameSource.new()
	partner.name = "Partner"
	add_child(partner)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_live.erase(get_instance_id())


func sync(source: FrameSource, media: MediaItem, want: String) -> PackedStringArray:
	mode = want
	if mode.is_empty():
		_live.erase(get_instance_id())
		return PackedStringArray()
	var kind: String = source.kind
	var handle: int = -1
	if kind == FrameSource.KIND_NATIVE:
		handle = _lane_for(media, source.handle)
		if handle < 0:
			mode = ""
			return PackedStringArray()
	elif kind != FrameSource.KIND_PATTERN:
		mode = ""
		return PackedStringArray()
	if partner.kind != kind or partner.media != media or partner_handle != handle or partner.native_size != source.native_size:
		partner.setup(kind, media, source.native_size, handle)
		partner_handle = handle
	partner.use_proxy = source.use_proxy
	var vp: SubViewport = partner.viewport()
	return PackedStringArray(["ti:" + mode + ":" + str(handle) + ":" + str(partner.texture() != null) + ":" + str(vp.get_instance_id() if vp != null else 0)])


func _lane_for(media: MediaItem, main_handle: int) -> int:
	if media == null or media.path.is_empty() or main_handle < 0:
		return -1
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return -1
	var s: Node = (loop as SceneTree).root.get_node_or_null("/root/Session")
	if s == null or not s.has_method("lane_handle"):
		return -1
	var lane: String = LANE_PREFIX + str(main_handle)
	var key: String = media.path + "|" + lane
	_live[get_instance_id()] = key
	_lanes[key] = {"path": media.path, "lane": lane, "ms": Time.get_ticks_msec()}
	return int(s.call("lane_handle", media.path, lane))


static func prune_lanes(now: int, force: bool = false) -> int:
	if not force and now - _prune_ms < PRUNE_EVERY_MS:
		return 0
	_prune_ms = now
	var loop: MainLoop = Engine.get_main_loop()
	var s: Node = (loop as SceneTree).root.get_node_or_null("/root/Session") if loop is SceneTree else null
	var held: Array = _live.values()
	var closed: int = 0
	for key: Variant in _lanes.keys():
		var e: Dictionary = _lanes[key]
		if held.has(key) or now - int(e["ms"]) < LANE_IDLE_MS:
			continue
		_lanes.erase(key)
		closed += 1
		if s != null and s.has_method("forget_lane"):
			s.call("forget_lane", String(e["path"]), String(e["lane"]))
	return closed


func _touch_lane(now: int) -> void:
	var key: Variant = _live.get(get_instance_id(), null)
	if key != null and _lanes.has(key):
		(_lanes[key] as Dictionary)["ms"] = now
	prune_lanes(now)


func active() -> bool:
	return not mode.is_empty() and out_pass != null


func wire(a_node: Node, a_tex: Texture2D, chain: Vector2i, quality_scale: float) -> Array:
	release()
	if mode.is_empty() or a_tex == null:
		return [a_node, a_tex]
	partner.set_quality_scale(quality_scale)
	var b_tex: Texture2D = partner.texture()
	if b_tex == null:
		return [a_node, a_tex]
	return wire_textures(a_node, a_tex, partner.viewport(), b_tex, chain)


func wire_textures(a_node: Node, a_tex: Texture2D, b_node: Node, b_tex: Texture2D, chain: Vector2i) -> Array:
	built_size = chain
	if mode == TimeInterp.BLEND:
		out_pass = _pass(BLEND_SHADER, "InterpBlend")
		_adopt(out_pass, a_node)
		_adopt(out_pass, b_node)
		out_pass.set_input(a_tex)
		out_pass.set_param("a_tex", a_tex)
		out_pass.set_param("b_tex", b_tex)
		out_pass.set_param("w", 0.0)
		out_pass.set_size_px(chain)
		return [out_pass, out_pass.output()]
	var prev: EffectPass = null
	for level: int in range(1, TimeInterp.FLOW_LEVELS + 1):
		var lp: EffectPass = _pass(LUMA_SHADER, "InterpLuma" + str(level))
		var ls: Vector2i = TimeInterp.level_size(chain, level)
		var in_s: Vector2i = TimeInterp.level_size(chain, level - 1) if level > 1 else chain
		if prev == null:
			_adopt(lp, a_node)
			_adopt(lp, b_node)
			lp.set_input(a_tex)
			lp.set_param("a_tex", a_tex)
			lp.set_param("b_tex", b_tex)
			lp.set_param("from_source", true)
		else:
			_adopt(lp, prev)
			lp.set_input(prev.output())
			lp.set_param("prev_tex", prev.output())
			lp.set_param("from_source", false)
		lp.set_param("in_size", Vector2(in_s))
		lp.set_param("out_size", Vector2(ls))
		lp.set_size_px(ls)
		luma_passes.append(lp)
		prev = lp
	var top: int = TimeInterp.FLOW_LEVELS
	var top_size: Vector2i = TimeInterp.level_size(chain, top)
	search_pass = _pass(SEARCH_SHADER, "InterpSearch")
	_adopt(search_pass, prev)
	search_pass.set_input(prev.output())
	search_pass.set_param("luma_tex", prev.output())
	search_pass.set_param("size", Vector2(top_size))
	search_pass.set_param("radius", TimeInterp.FLOW_RADIUS)
	search_pass.set_param("lambda", TimeInterp.FLOW_LAMBDA)
	search_pass.set_param("scale", pow(2.0, float(top)))
	search_pass.set_param("patch", TimeInterp.SEARCH_PATCH)
	search_pass.set_size_px(top_size)
	var flow_prev: EffectPass = search_pass
	var flow_size: Vector2i = top_size
	for level: int in range(top - 1, 0, -1):
		var rp: EffectPass = _pass(REFINE_SHADER, "InterpRefine" + str(level))
		var rs: Vector2i = TimeInterp.level_size(chain, level)
		_adopt(rp, flow_prev)
		rp.set_input(luma_passes[level - 1].output())
		rp.set_param("luma_tex", luma_passes[level - 1].output())
		rp.set_param("prev_tex", flow_prev.output())
		rp.set_param("size", Vector2(rs))
		rp.set_param("prev_size", Vector2(flow_size))
		rp.set_param("lambda", TimeInterp.FLOW_LAMBDA)
		rp.set_param("scale", pow(2.0, float(level)))
		rp.set_param("half_step", level == 1)
		rp.set_param("patch", TimeInterp.REFINE_PATCH)
		rp.set_size_px(rs)
		refine_passes.append(rp)
		flow_prev = rp
		flow_size = rs
	out_pass = _pass(WARP_SHADER, "InterpWarp")
	_adopt(out_pass, flow_prev)
	out_pass.set_input(a_tex)
	out_pass.set_param("a_tex", a_tex)
	out_pass.set_param("b_tex", b_tex)
	out_pass.set_param("flow_tex", flow_prev.output())
	out_pass.set_param("size", Vector2(chain))
	out_pass.set_param("flow_size", Vector2(flow_size))
	out_pass.set_param("fall_lo", TimeInterp.FALLBACK_LO)
	out_pass.set_param("fall_hi", TimeInterp.FALLBACK_HI)
	out_pass.set_param("w", 0.0)
	out_pass.set_size_px(chain)
	flow_running = true
	return [out_pass, out_pass.output()]


func _adopt(p: Node, child: Node) -> void:
	if child == null or not is_instance_valid(child):
		return
	var old: Node = child.get_parent()
	if old != null:
		old.remove_child(child)
	p.add_child(child)


func release() -> void:
	var b_node: SubViewport = partner.viewport()
	if b_node != null and b_node.get_parent() != partner:
		if b_node.get_parent() != null:
			b_node.get_parent().remove_child(b_node)
		partner.add_child(b_node)
	var all: Array[EffectPass] = []
	all.append_array(luma_passes)
	if search_pass != null:
		all.append(search_pass)
	all.append_array(refine_passes)
	if out_pass != null:
		all.append(out_pass)
	for p: EffectPass in all:
		if p == null or not is_instance_valid(p):
			continue
		for ch: Node in p.get_children():
			if ch != p.rect and not all.has(ch):
				p.remove_child(ch)
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		p.queue_free()
	luma_passes = []
	search_pass = null
	refine_passes = []
	out_pass = null
	built_size = Vector2i.ZERO


func request(main: FrameSource, s: float, fps: float, duration: float, quality: int, hint: int) -> void:
	src_time = s
	var pair: Dictionary = TimeInterp.frame_pair(s, fps)
	pair_weight = float(pair["w"])
	if main.kind == FrameSource.KIND_PATTERN:
		main.request(float(pair["a"]), quality, hint)
		partner.request(float(pair["b"]), quality, hint)
		a_pts = float(pair["a"])
		b_pts = float(pair["b"])
		weight = pair_weight
		waiting_partner = false
	else:
		_touch_lane(Time.get_ticks_msec())
		main.request(s, quality, hint)
		partner.request(TimeInterp.partner_request_time(pair, fps, duration), quality, hint)
		a_pts = main.shown_pts
		b_pts = partner.shown_pts
		var both: bool = main.has_picture and partner.has_picture
		weight = TimeInterp.weight_from_pts(s, a_pts, b_pts, fps) if both else 0.0
		waiting_partner = pair_weight > 0.0 and not partner.is_exact()
		if waiting_partner:
			weight = 0.0
	_ask_given(main, hint)
	apply_weight()


func _ask_given(main: FrameSource, hint: int) -> void:
	given_state = ""
	if out_pass == null or mode == TimeInterp.BLEND or mode == TimeInterp.FLOW:
		return
	var prov: Object = TimeInterp.provider_for(mode)
	var use: bool = false
	if prov != null and prov.has_method("frame") and weight > 0.0:
		var r: Variant = prov.call("frame", main.media.path if main.media != null else "", a_pts, b_pts, weight, built_size, hint == HINT_STEP or hint == HINT_EXPORT)
		if r is Dictionary:
			given_state = String((r as Dictionary).get("state", ""))
			var tex: Variant = (r as Dictionary).get("texture", null)
			if given_state == "exact" and tex is Texture2D:
				out_pass.set_param("given_tex", tex)
				out_pass.set_param("given_matrix", int(load("res://engine/purrframes/purrframes.gd").given_matrix(main, r)))
				use = true
	out_pass.set_param("use_given", use)


func apply_weight() -> void:
	if out_pass == null:
		return
	out_pass.set_param("w", weight)
	if mode == TimeInterp.BLEND:
		return
	for rp: EffectPass in refine_passes:
		rp.set_param("w", weight)
	if search_pass != null:
		search_pass.set_param("w", weight)
	_run_flow(weight > 0.0)


func _run_flow(on: bool) -> void:
	if on == flow_running:
		return
	flow_running = on
	var list: Array[EffectPass] = []
	list.append_array(luma_passes)
	if search_pass != null:
		list.append(search_pass)
	list.append_array(refine_passes)
	for p: EffectPass in list:
		if on and p.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			p.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif not on and p.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			p.render_target_update_mode = SubViewport.UPDATE_DISABLED


func state_of(main_state: String, hint: int) -> String:
	if out_pass == null:
		return main_state
	if (hint == HINT_STEP or hint == HINT_EXPORT) and (waiting_partner or given_state == "pending"):
		if main_state == "exact" or main_state == "static":
			return "pending"
	return main_state


func passes_count() -> int:
	var n: int = luma_passes.size() + refine_passes.size()
	if search_pass != null:
		n += 1
	if out_pass != null:
		n += 1
	return n
