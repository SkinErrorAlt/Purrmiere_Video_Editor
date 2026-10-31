extends Node

const AnimProp := preload("res://doc/anim_prop.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const MaskPass := preload("res://engine/mask_pass.gd")
const PlaybackClock := preload("res://engine/playback_clock.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const CubeLut := preload("res://engine/cube_lut.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const FrameCanvas := preload("res://engine/frame_canvas.gd")
const RegionBlocks := preload("res://engine/region_blocks.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const Parenting := preload("res://doc/parenting.gd")
const PuppetStage := preload("res://engine/puppet_stage.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const AudioReact := preload("res://engine/audio_react.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const OWNER_WALK := 8
const TRANSFORM_SHADER := "res://engine/transform.gdshader"
const ACCUM_SHADER := "res://engine/accum.gdshader"
const MOTION_BLUR_SHADER := "res://engine/motion_blur.gdshader"
const COPY_SHADER := "res://engine/copy.gdshader"
const MASK_APPLY_SHADER := "res://engine/mask_apply.gdshader"
const MASK_MIX_SHADER := "res://engine/mask_mix.gdshader"
const MIX_MODE_KEEP := 0
const MIX_MODE_ISOLATE := 1
const MIX_MODE_SPILL := 2
const SPILL_UNIFORM := "spill_out"
const TRANSITION_SHADER := "res://engine/transition.gdshader"
const BLEND_MODES: Dictionary = {"normal": 0, "add": 1, "multiply": 2, "screen": 3, "overlay": 4, "darken": 5, "lighten": 6, "difference": 7, "subtract": 8, "soft_light": 9, "hard_light": 10, "colour_dodge": 11, "colour_burn": 12, "linear_burn": 13, "linear_light": 14, "vivid_light": 15, "pin_light": 16, "exclusion": 17, "divide": 18, "hue": 19, "saturation": 20, "colour": 21, "luminosity": 22}
const TRANSITION_KINDS: Dictionary = {"": 0, "none": 0, "dissolve": 1, "cross_dissolve": 1, "dip_black": 2, "dip_to_black": 2, "dip_white": 3, "dip_to_white": 3, "wipe_left": 4, "wipe": 4, "wipe_right": 5, "wipe_up": 6, "wipe_down": 7, "push": 8, "push_left": 8, "push_right": 9, "push_up": 10, "push_down": 11, "slide": 12, "slide_left": 12, "slide_right": 13, "slide_up": 14, "slide_down": 15}
const MAX_BLUR_SAMPLES := 64
const SMOOTH_KEYS := 33
const SMOOTH_TAPS_PER_SAMPLE := 16
const SMOOTH_TAPS_PER_PX := 0.4
const SMOOTH_KEY_SPACING_PX := 32.0
const SMOOTH_KEY_SPACING_DEG := 10.0
const SMOOTH_MAX_TAPS := 512
const MAX_REPEAT := 8
const ENGINE_UNIFORM_NAMES: PackedStringArray = ["tex_size", "seq_size", "time", "clip_time", "clip_duration", "px_scale", "source_tex", "effect_tex", "layer_tex"]

static var _shaders: Dictionary = {}
static var _texture_cache: Dictionary = {}

var clip_id: String = ""
var clip: Clip = null
var media: MediaItem = null
var registry: RefCounted = null
var source: FrameSource = null
var mask: MaskPass = null
var quad: TextureRect = null
var quad_mat: ShaderMaterial = null
var backbuffer: BackBufferCopy = null
var accum: SubViewport = null
var accum_quads: Array[TextureRect] = []
var blur_quad: TextureRect = null
var smooth_rect: ColorRect = null
var passes: Array[Dictionary] = []
var outer_node: Node = null
var outer_tex: Texture2D = null
var quality_scale: float = 1.0
var px_scale_bias: float = 1.0
var seq_size: Vector2i = Vector2i(1920, 1080)
var seq_fps: float = 30.0
var media_fps: float = 0.0
var media_duration: float = 0.0
var loop_length: float = 0.0
var last_rect: Rect2 = Rect2()
var last_quad: PackedVector2Array = PackedVector2Array()
var last_pivot: Vector2 = Vector2.ZERO
var order: int = 0
var disabled_effects: PackedStringArray = PackedStringArray()
var track_index: int = -1
var waiting: bool = false
var due_ms: int = -1
var _parked: Array = []
var _structure_sig: String = ""
var _events: Node = null
var regions: RegionBlocks = RegionBlocks.new()


static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


static func material_for(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(path)
	return m


static func types_of(sh: Shader) -> Dictionary:
	var out: Dictionary = {}
	if sh == null:
		return out
	for u: Dictionary in sh.get_shader_uniform_list(true):
		out[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	return out


static func texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var img: Image = Image.new()
	var real: String = ProjectSettings.globalize_path(path) if (path.begins_with("res://") or path.begins_with("user://")) else path
	var tex: Texture2D = null
	if CubeLut.is_cube_path(real):
		tex = CubeLut.load_texture(real)
	elif img.load(real) == OK:
		tex = ImageTexture.create_from_image(img)
	_texture_cache[path] = tex
	return tex


func _init() -> void:
	name = "Layer"
	source = FrameSource.new()
	source.name = "Source"
	add_child(source)
	mask = MaskPass.new()
	mask.name = "Masks"
	add_child(mask)
	backbuffer = BackBufferCopy.new()
	backbuffer.name = "BackBuffer"
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(backbuffer)
	quad = TextureRect.new()
	quad.name = "Quad"
	quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quad.stretch_mode = TextureRect.STRETCH_SCALE
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quad_mat = material_for(TRANSFORM_SHADER)
	quad.material = quad_mat
	add_child(quad)


func events() -> Node:
	if _events == null:
		var loop: MainLoop = Engine.get_main_loop()
		if loop is SceneTree:
			_events = (loop as SceneTree).root.get_node_or_null("Events")
	return _events


func setup(c: Clip, m: MediaItem, reg: RefCounted, source_kind: String, source_size: Vector2i, handle: int) -> void:
	clip = c
	clip_id = c.id
	media = m
	registry = reg
	media_fps = m.fps if m != null else 0.0
	media_duration = m.duration if m != null else 0.0
	source.setup(source_kind, m, source_size, handle)
	_structure_sig = ""
	if waiting:
		_park()


func set_waiting(on: bool) -> void:
	if on == waiting:
		return
	waiting = on
	due_ms = -1
	if on:
		_park()
	else:
		_unpark()
	set_visible_in_stage(not on)


func _park() -> void:
	for n: Node in find_children("*", "SubViewport", true, false):
		var vp: SubViewport = n as SubViewport
		if vp != null and vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_parked.append(vp)


func _unpark() -> void:
	for v: Variant in _parked:
		if is_instance_valid(v):
			(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_parked = []


func hand_to(c: Clip) -> void:
	clip = c
	clip_id = c.id
	name = "Layer_" + c.id


func set_nest_texture(tex: Texture2D, size: Vector2i) -> void:
	source.set_nest_texture(tex, size)


static func effect_mask_ids(c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in c.effects:
		var mid: String = str(e.get("mask", ""))
		if not mid.is_empty() and not out.has(mid):
			out.append(mid)
	return out


func structure_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(source.kind)
	parts.append(str(source.native_size))
	parts.append(str(quality_scale))
	parts.append("src:" + str(source.texture() != null))
	for e: Dictionary in clip.effects:
		parts.append(str(e.get("uid", "")) + "/" + str(e.get("id", "")) + "/" + str(bool(e.get("enabled", true))) + "/" + str(e.get("mask", "")) + "/" + str(mixes_back(e)) + ("/spill" if Clip.mask_spills(e) else ""))
	var region_parts: Array = RegionBlocks.structure(clip)
	parts.append("m:" + MaskPass.signature(region_parts[0], effect_mask_ids(clip)))
	parts.append("rg:" + String(region_parts[1]))
	parts.append("t:" + str(clip.transition_in.get("kind", "")))
	parts.append("mb:" + str(bool(clip.motion_blur.get("on", false))) + "/" + blur_mode() + "/" + str(copies_limit()))
	parts.append("cv:" + (str(canvas_size()) if PairLayout.has_pair(clip) or FrameCanvas.wants(clip.effects) else "-"))
	parts.append_array(_interp_sig())
	return "|".join(parts)


func _detach(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var p: Node = n.get_parent()
	if p != null:
		p.remove_child(n)


func _free_node(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	_detach(n)
	n.queue_free()


func chain_size() -> Vector2i:
	var s: Vector2 = Vector2(source.native_size) * quality_scale
	return Vector2i(maxi(int(round(s.x)), 2), maxi(int(round(s.y)), 2))


func _tear_down_passes() -> void:
	var src_vp: SubViewport = source.viewport()
	if src_vp != null:
		_detach(src_vp)
		source.add_child(src_vp)
	_interp_release()
	for pd: Dictionary in passes:
		_keep_regions(pd["pass"])
		_free_node(pd["pass"])
	passes = []
	if accum != null:
		_free_node(accum)
		accum = null
		accum_quads = []
		smooth_rect = null
	if blur_quad != null:
		_free_node(blur_quad)
		blur_quad = null
	outer_node = null
	outer_tex = null


func keep_regions() -> void:
	for pd: Dictionary in passes:
		_keep_regions(pd["pass"])


func _keep_regions(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	for ch: Node in p.get_children():
		if ch.get_script() == get_script():
			p.remove_child(ch)


func _place_unit(p: EffectPass, mid: String, placed: Dictionary) -> void:
	if placed.has(mid):
		return
	var unit: Node = mask.unit_root(mid)
	_detach(unit)
	p.add_child(unit)
	placed[mid] = true


func _make_pass(mat: ShaderMaterial, types: Dictionary, prev_node: Node, prev_tex: Texture2D, label: String) -> EffectPass:
	var p: EffectPass = EffectPass.new()
	p.name = label
	p.setup(mat, types)
	if prev_node != null:
		_detach(prev_node)
		p.add_child(prev_node)
	p.set_input(prev_tex)
	return p


func _mask_apply_pass(prev_node: Node, prev_tex: Texture2D, abs_scale: float) -> EffectPass:
	var apply_mat: ShaderMaterial = material_for(MASK_APPLY_SHADER)
	var ap: EffectPass = _make_pass(apply_mat, types_of(apply_mat.shader), prev_node, prev_tex, "mask_apply")
	var aroot: Node = mask.alpha_root()
	_detach(aroot)
	ap.add_child(aroot)
	ap.set_param("mask_tex", mask.alpha_texture())
	passes.append({"pass": ap, "uid": "", "effect_id": "", "effect_index": -1, "pass_index": -1, "repeat_index": 0, "spec": {}, "scale_in": abs_scale, "scale_out": abs_scale, "kind": "mask_apply", "effect_in_tex": null})
	return ap


func rebuild() -> void:
	_tear_down_passes()
	source.set_quality_scale(quality_scale)
	mask.rebuild(RegionBlocks.chain_masks(clip), effect_mask_ids(clip), chain_size(), true)
	disabled_effects = PackedStringArray()
	regions.begin()
	var prev_tex: Texture2D = source.texture()
	var prev_node: Node = source.viewport()
	if prev_node != null:
		_detach(prev_node)
	var ti_made: Array = _interp_wire(prev_node, prev_tex)
	prev_node = ti_made[0]
	prev_tex = ti_made[1]
	var source_tex: Texture2D = prev_tex
	var abs_scale: float = 1.0
	var effect_index: int = 0
	var copy_types: Dictionary = types_of(shader(COPY_SHADER))
	var masks_done: bool = false
	var placed: Dictionary = {}
	for step: Dictionary in RegionBlocks.steps(clip):
		if step.has("marker"):
			var made: Dictionary = regions.marker(step, prev_node, prev_tex, abs_scale, passes)
			prev_node = made["node"]
			prev_tex = made["tex"]
			abs_scale = float(made["scale"])
			continue
		var e: Dictionary = step["e"]
		var eid: String = str(e.get("id", ""))
		var uid: String = str(e.get("uid", ""))
		effect_index = int(step["index"]) + 1
		if not bool(e.get("enabled", true)):
			continue
		var def: Dictionary = registry.get_def(eid) if registry != null else {}
		if def.is_empty():
			continue
		var specs: Array = def.get("passes", [])
		if specs.is_empty():
			continue
		if eid == PuppetStage.EFFECT_ID and not masks_done and mask.has_alpha_masks():
			masks_done = true
			var early: EffectPass = _mask_apply_pass(prev_node, prev_tex, abs_scale)
			prev_node = early
			prev_tex = early.output()
		var effect_passes: Array[Dictionary] = []
		var ok: bool = true
		var start_scale: float = abs_scale
		for j: int in specs.size():
			if not registry.shader_ok(String(specs[j]["shader"])):
				ok = false
				break
		if not ok:
			disabled_effects.append(uid)
			continue
		var mid: String = str(e.get("mask", ""))
		var has_mask: bool = not mid.is_empty() and mask.unit_root(mid) != null
		var spill: bool = has_mask and Clip.mask_spills(e)
		var before_tex: Texture2D = prev_tex
		if spill:
			var iso_mat: ShaderMaterial = material_for(MASK_MIX_SHADER)
			var iso: EffectPass = _make_pass(iso_mat, types_of(iso_mat.shader), prev_node, prev_tex, "mask_isolate_" + uid)
			_place_unit(iso, mid, placed)
			iso.set_param("mask_tex", mask.mask_texture(mid))
			iso.set_param("use_mask", true)
			iso.set_param("have_effect_tex", false)
			iso.set_param("mode", MIX_MODE_ISOLATE)
			effect_passes.append({"pass": iso, "uid": uid, "effect_id": eid, "effect_index": effect_index - 1, "pass_index": -1, "repeat_index": 0, "spec": {}, "scale_in": abs_scale, "scale_out": abs_scale, "kind": "mask_isolate", "effect_in_tex": null})
			prev_node = iso
			prev_tex = iso.output()
		var effect_in_tex: Texture2D = prev_tex
		var pass_outputs: Array = []
		for j: int in specs.size():
			var spec: Dictionary = specs[j]
			var repeat_max: int = 1
			var rep: Dictionary = spec.get("repeat", {})
			if not rep.is_empty():
				repeat_max = clampi(int(rep.get("max", 1)), 1, MAX_REPEAT)
			for r: int in repeat_max:
				var mat: ShaderMaterial = registry.make_material(eid, j)
				var types: Dictionary = registry.uniform_types(eid, j)
				var p: EffectPass = _make_pass(mat, types, prev_node, prev_tex, eid + "_" + str(j) + "_" + str(r))
				p.effect_uid = uid
				if eid == PuppetStage.EFFECT_ID:
					PuppetStage.attach(p, prev_tex)
				p.index = j
				p.set_meta("bypass_mat", material_for(COPY_SHADER))
				p.set_meta("copy_types", copy_types)
				for uname: Variant in (spec.get("inputs", {}) as Dictionary).keys():
					var src_index: int = int(spec["inputs"][uname])
					if src_index >= 0 and src_index < pass_outputs.size():
						p.set_param(String(uname), pass_outputs[src_index])
				for sk: Variant in (spec.get("set", {}) as Dictionary).keys():
					p.set_param(String(sk), spec["set"][sk])
				if p.has_uniform("source_tex"):
					p.set_param("source_tex", source_tex)
				if p.has_uniform("effect_tex"):
					p.set_param("effect_tex", effect_in_tex)
				if spill and p.has_uniform(SPILL_UNIFORM):
					p.set_param(SPILL_UNIFORM, true)
				var rel: float = float(spec.get("scale", 1.0))
				var scale_in: float = abs_scale
				abs_scale = clampf(abs_scale * (rel if rel > 0.0 else 1.0), 0.03125, 1.0)
				effect_passes.append({"pass": p, "uid": uid, "effect_id": eid, "effect_index": effect_index - 1, "pass_index": j, "repeat_index": r, "spec": spec, "scale_in": scale_in, "scale_out": abs_scale, "kind": "effect", "effect_in_tex": effect_in_tex})
				prev_node = p
				prev_tex = p.output()
				if r == repeat_max - 1:
					pass_outputs.append(prev_tex)
		if has_mask or mixes_back(e):
			var mix_mat: ShaderMaterial = material_for(MASK_MIX_SHADER)
			var mix: EffectPass = _make_pass(mix_mat, types_of(mix_mat.shader), prev_node, prev_tex, "mask_mix_" + uid)
			mix.set_param("mode", MIX_MODE_SPILL if spill else MIX_MODE_KEEP)
			if has_mask and not spill:
				_place_unit(mix, mid, placed)
				mix.set_param("mask_tex", mask.mask_texture(mid))
			mix.set_param("use_mask", has_mask and not spill)
			mix.set_param("have_effect_tex", before_tex != null)
			if before_tex != null:
				mix.set_param("effect_tex", before_tex)
			effect_passes.append({"pass": mix, "uid": uid, "effect_id": eid, "effect_index": effect_index - 1, "pass_index": -1, "repeat_index": 0, "spec": {}, "scale_in": abs_scale, "scale_out": start_scale, "kind": "mask_mix", "effect_in_tex": before_tex})
			abs_scale = start_scale
			prev_node = mix
			prev_tex = mix.output()
		RegionBlocks.tag(effect_passes, step)
		passes.append_array(effect_passes)
	regions.wire(passes)
	if mask.has_alpha_masks() and not masks_done:
		var ap: EffectPass = _mask_apply_pass(prev_node, prev_tex, abs_scale)
		prev_node = ap
		prev_tex = ap.output()
	if transition_kind() > 0:
		var tmat: ShaderMaterial = material_for(TRANSITION_SHADER)
		var tp: EffectPass = _make_pass(tmat, types_of(tmat.shader), prev_node, prev_tex, "transition")
		passes.append({"pass": tp, "uid": "", "effect_id": "", "effect_index": -1, "pass_index": -1, "repeat_index": 0, "spec": {}, "scale_in": abs_scale, "scale_out": abs_scale, "kind": "transition", "effect_in_tex": null})
		prev_node = tp
		prev_tex = tp.output()
	for mid_key: Variant in mask.units.keys():
		var unit_node: Node = mask.unit_root(String(mid_key))
		if unit_node != null and unit_node.get_parent() == null:
			mask.add_child(unit_node)
	var aroot_left: Node = mask.alpha_root()
	if aroot_left != null and aroot_left.get_parent() == null:
		mask.add_child(aroot_left)
	outer_node = prev_node
	outer_tex = prev_tex
	var mb_on: bool = bool(clip.motion_blur.get("on", false))
	if mb_on:
		accum = SubViewport.new()
		accum.name = "Accum"
		accum.transparent_bg = true
		accum.disable_3d = true
		accum.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_fit_accum()
		add_child(accum)
		if outer_node != null:
			_detach(outer_node)
			accum.add_child(outer_node)
		accum_quads = []
		smooth_rect = null
		if blur_mode() == "smooth":
			smooth_rect = ColorRect.new()
			smooth_rect.name = "SmoothBlur"
			smooth_rect.color = Color.WHITE
			smooth_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sm: ShaderMaterial = material_for(MOTION_BLUR_SHADER)
			sm.set_shader_parameter("layer_tex", outer_tex)
			smooth_rect.material = sm
			accum.add_child(smooth_rect)
		else:
			for i: int in copies_limit():
				var q := TextureRect.new()
				q.name = "Sample" + str(i)
				q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				q.stretch_mode = TextureRect.STRETCH_SCALE
				q.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				q.mouse_filter = Control.MOUSE_FILTER_IGNORE
				q.material = material_for(ACCUM_SHADER)
				q.texture = outer_tex
				accum.add_child(q)
				accum_quads.append(q)
		blur_quad = TextureRect.new()
		blur_quad.name = "BlurQuad"
		blur_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		blur_quad.stretch_mode = TextureRect.STRETCH_SCALE
		blur_quad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		blur_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blur_quad.material = quad_mat
		blur_quad.texture = accum.get_texture()
		add_child(blur_quad)
		quad.visible = false
	else:
		if outer_node != null:
			_detach(outer_node)
			add_child(outer_node)
		quad.visible = true
	quad.texture = outer_tex
	_mark_canvas()
	_apply_sizes()
	_structure_sig = structure_signature()
	if waiting:
		_park()
		set_visible_in_stage(false)


func blur_mode() -> String:
	return "copies" if String(clip.motion_blur.get("mode", "smooth")) == "copies" else "smooth"


func copies_limit() -> int:
	if blur_mode() != "copies":
		return 0
	return clampi(int(round(clip.motion_blur_value("samples", 0.0, seq_fps))), 2, MAX_BLUR_SAMPLES)


func stage_size() -> Vector2i:
	var s: Vector2 = Vector2(seq_size) * quality_scale
	return Vector2i(maxi(int(round(s.x)), 2), maxi(int(round(s.y)), 2))


func _apply_sizes() -> void:
	for pd: Dictionary in passes:
		var base: Vector2i = _base_size(bool(pd.get("canvas", false)))
		var p: EffectPass = pd["pass"]
		var s: float = float(pd["scale_out"])
		p.set_size_px(Vector2i(maxi(int(round(float(base.x) * s)), 2), maxi(int(round(float(base.y) * s)), 2)))
	_fit_accum()


var overscan_px: Vector2i = Vector2i.ZERO


func _fit_accum() -> void:
	if accum == null:
		return
	var want: Vector2i = stage_size() + overscan_px * 2
	if accum.size != want:
		accum.size = want
	var xf: Transform2D = Transform2D(0.0, Vector2(overscan_px))
	if accum.is_inside_tree() and accum.canvas_transform != xf:
		accum.canvas_transform = xf


func transition_kind() -> int:
	if clip == null or clip.transition_in.is_empty():
		return 0
	return int(TRANSITION_KINDS.get(str(clip.transition_in.get("kind", "")), 0))


func forget_structure() -> void:
	_structure_sig = ""


func has_structure() -> bool:
	return not _structure_sig.is_empty()


func ensure_structure() -> void:
	if _structure_sig != structure_signature():
		rebuild()


static func mixes_back(e: Dictionary) -> bool:
	var m: Variant = e.get("mix", null)
	if not (m is Dictionary):
		return false
	if AnimProp.is_animated(m):
		return true
	return absf(float(AnimProp.static_value(m)) - 1.0) > 0.0001


func mix_at(e: Dictionary, local_t: float) -> float:
	var m: Variant = e.get("mix", null)
	if not (m is Dictionary):
		return 1.0
	return clampf(AnimProp.evaluate_float(m, clip.fx_time(e, "mix", local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else clip.anim_time(local_t), clip.duration, seq_fps), 0.0, 1.0)


func _eval_param(e: Dictionary, spec: Dictionary, local_t: float) -> Variant:
	var key: String = String(spec["key"])
	var params: Dictionary = e.get("params", {})
	var p: Variant = params.get(key, null)
	var type: String = String(spec["type"])
	if not (p is Dictionary):
		return spec["default"]
	var kt: float = clip.fx_time(e, key, local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else clip.anim_time(local_t)
	if type == "curve":
		return EffectRegistry.curve_texture(curve_value(p, kt))
	var raw: Variant = AnimProp.evaluate(p, kt, clip.duration, seq_fps)
	if type == "texture":
		return texture_from_path(String(raw))
	if type == "layer":
		return null
	return raw


static func curve_value(p: Dictionary, t: float) -> Variant:
	if not AnimProp.is_animated(p):
		return AnimProp.static_value(p)
	var held: Variant = null
	for k: Dictionary in AnimProp.keys(p):
		var v: Variant = k.get("v", null)
		if not (v is Dictionary):
			continue
		if held == null or float(k.get("t", 0.0)) <= t + AnimProp.KEY_TOLERANCE:
			held = v
	if held == null:
		var base: Variant = p.get("base", null)
		return base if base is Dictionary else AnimProp.static_value(p)
	return held


static func _when_passes(when: Dictionary, value: float) -> bool:
	if when.has("gt") and not (value > float(when["gt"])):
		return false
	if when.has("gte") and not (value >= float(when["gte"])):
		return false
	if when.has("lt") and not (value < float(when["lt"])):
		return false
	if when.has("lte") and not (value <= float(when["lte"])):
		return false
	if when.has("eq") and not is_equal_approx(value, float(when["eq"])):
		return false
	if when.has("ne") and is_equal_approx(value, float(when["ne"])):
		return false
	return true


func _set_bypass(p: EffectPass, on: bool) -> void:
	var was: bool = bool(p.get_meta("bypassed", false))
	if was == on:
		return
	p.set_meta("bypassed", on)
	if on:
		p.rect.material = p.get_meta("bypass_mat")
	else:
		p.rect.material = p.mat


func _size_for(scale: float) -> Vector2i:
	var base: Vector2i = chain_size()
	return Vector2i(maxi(int(round(float(base.x) * scale)), 2), maxi(int(round(float(base.y) * scale)), 2))


static var placing_uid: String = ""
static var _crops_cache: Dictionary = {}


static func split_grid(n: int) -> Vector2i:
	var count: int = clampi(n, 1, 8)
	if count <= 1:
		return Vector2i(1, 1)
	if count <= 3:
		return Vector2i(count, 1)
	if count == 4:
		return Vector2i(2, 2)
	if count <= 6:
		return Vector2i(3, 2)
	return Vector2i(4, 2)


static func even_split(n: int) -> Array:
	var count: int = clampi(n, 1, 8)
	var grid: Vector2i = split_grid(count)
	var out: Array = []
	var w: float = 1.0 / float(grid.x)
	var h: float = 1.0 / float(grid.y)
	for i: int in count:
		var col: int = i % grid.x
		var row: int = i / grid.x
		out.append({"name": "View " + str(i + 1), "rect": [float(col) * w, float(row) * h, w, h], "rot": 0.0, "auto": true})
	return out


static func resplit(crops: Array, n: int) -> Array:
	var count: int = clampi(n, 1, 8)
	if count == crops.size():
		return crops.duplicate(true)
	var all_auto: bool = true
	for cr: Variant in crops:
		if not bool((cr as Dictionary).get("auto", false)):
			all_auto = false
	if all_auto:
		return even_split(count)
	var out: Array = crops.duplicate(true)
	while out.size() > count:
		out.remove_at(out.size() - 1)
	if out.size() < count:
		var gap: Rect2 = uncovered_box(out)
		var extra: int = count - out.size()
		var w: float = gap.size.x / float(extra)
		for i: int in extra:
			out.append({"name": "View " + str(out.size() + 1), "rect": [gap.position.x + float(i) * w, gap.position.y, w, gap.size.y], "rot": 0.0, "auto": true})
	return out


static func uncovered_box(crops: Array) -> Rect2:
	var used: Rect2 = Rect2()
	var first: bool = true
	for cr: Variant in crops:
		var r: Array = (cr as Dictionary).get("rect", [0.0, 0.0, 1.0, 1.0])
		var box: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		used = box if first else used.merge(box)
		first = false
	if first:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var right: float = 1.0 - used.end.x
	var below: float = 1.0 - used.end.y
	if right >= below and right > 0.01:
		return Rect2(used.end.x, 0.0, right, 1.0)
	if below > 0.01:
		return Rect2(0.0, used.end.y, 1.0, below)
	return Rect2(used.position.x, used.position.y, maxf(used.size.x, 0.01), maxf(used.size.y, 0.01))


static func parse_crops(text: String) -> Array:
	if _crops_cache.has(text):
		return _crops_cache[text]
	var out: Array = []
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		for e: Variant in parsed:
			if e is Dictionary and (e as Dictionary).get("rect") is Array and ((e as Dictionary)["rect"] as Array).size() >= 4:
				var r: Array = (e as Dictionary)["rect"]
				out.append({"name": String((e as Dictionary).get("name", "")), "rect": Rect2(float(r[0]), float(r[1]), maxf(float(r[2]), 0.001), maxf(float(r[3]), 0.001)), "rot": float((e as Dictionary).get("rot", 0.0)), "auto": bool((e as Dictionary).get("auto", false)), PairLayout.OUT_KEY: bool((e as Dictionary).get(PairLayout.OUT_KEY, false))})
				PairLayout.PairCrop.carry(out[out.size() - 1], e)
	if out.is_empty():
		out.append({"name": "Full", "rect": Rect2(0.0, 0.0, 1.0, 1.0), "rot": 0.0, "auto": true})
	if _crops_cache.size() > 256:
		_crops_cache.clear()
	_crops_cache[text] = out
	return out


func paired_effect(effect_index: int, pairs: PackedStringArray) -> Dictionary:
	for k: int in range(effect_index - 1, -1, -1):
		var other: Dictionary = clip.effects[k]
		if not bool(other.get("enabled", true)):
			continue
		if pairs.has(String(other.get("id", ""))):
			return other
	return {}


func _inject_pair(values: Dictionary, pairs: PackedStringArray, effect_index: int, local_t: float) -> void:
	values["paired"] = 0
	var other: Dictionary = paired_effect(effect_index, pairs)
	if other.is_empty():
		return
	var odef: Dictionary = registry.get_def(String(other.get("id", ""))) if registry != null else {}
	if odef.is_empty():
		return
	var shared: Dictionary = {}
	for ps: Variant in odef.get("params", []):
		var spec: Dictionary = ps
		var key: String = String(spec["key"])
		if key == "crops" or key == "view" or key == "view_mode" or key == "view2" or key == "group" or key == "groups":
			shared[key] = _eval_param(other, spec, local_t)
	if shared.has("crops"):
		expand_crops(shared)
		PairLayout.PairCrop.fill_uniforms(shared, String(shared["crops"]) if shared["crops"] is String else "")
	PairLayout.group_uniforms(shared)
	shared.erase("view2")
	shared.erase("group")
	shared.erase("groups")
	for k: Variant in shared.keys():
		values[k] = shared[k]
	values["paired"] = 1


static func expand_crops(values: Dictionary) -> void:
	var raw: Variant = values.get("crops", null)
	if not (raw is String):
		return
	var crops: Array = parse_crops(String(raw))
	var n: int = mini(crops.size(), 8)
	values["crop_count"] = n
	for i: int in 8:
		var r: Rect2 = (crops[i] as Dictionary)["rect"] if i < n else Rect2(0.0, 0.0, 1.0, 1.0)
		values["crop" + str(i)] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		values["crop_rot" + str(i)] = deg_to_rad(float((crops[i] as Dictionary).get("rot", 0.0))) if i < n else 0.0


func update_passes(t: float) -> void:
	var local_t: float = t - clip.start
	var pick_t: float = PlaybackClock.clip_local(t, clip.start, seq_fps)
	var eval_cache: Dictionary = {}
	var eff: float = 1.0
	var out_canvas: bool = false
	_room = Vector2i.ZERO
	_room_shift = Vector2.ZERO
	_room_uid = ""
	_in_room = false
	for pd: Dictionary in passes:
		var p: EffectPass = pd["pass"]
		var kind: String = String(pd["kind"])
		if RegionBlocks.is_marker(kind):
			eff = regions.update_marker(clip, pd, eff, chain_size())
			continue
		var in_size: Vector2 = Vector2(_size_in(out_canvas, eff))
		out_canvas = bool(pd.get("canvas", false))
		if kind != "effect":
			p.set_size_px(_size_in(out_canvas, eff))
			p.set_param("tex_size", in_size)
			if kind == "mask_mix":
				var mi: int = int(pd["effect_index"])
				if mi >= 0 and mi < clip.effects.size():
					p.set_param("mix_amount", mix_at(clip.effects[mi], local_t))
				var in_tex: Variant = pd.get("effect_in_tex", null)
				p.set_param("have_effect_tex", in_tex != null)
				var inner: Vector4 = room_box() if _in_room else FULL_BOX
				p.set_param("mask_box", inner)
				p.set_param("before_box", inner if _in_room and String(pd.get("uid", "")) == _room_uid else FULL_BOX)
				_mask_look(p, pd, t)
			elif kind == "mask_isolate":
				p.set_param("mask_box", room_box() if _in_room else FULL_BOX)
				_mask_look(p, pd, t)
			continue
		var ei: int = int(pd["effect_index"])
		if ei < 0 or ei >= clip.effects.size():
			continue
		var e: Dictionary = clip.effects[ei]
		var def: Dictionary = registry.get_def(String(pd["effect_id"]))
		var cache_key: String = String(pd["uid"])
		var values: Dictionary = {}
		if eval_cache.has(cache_key):
			values = eval_cache[cache_key]
		else:
			for ps: Variant in def.get("params", []):
				var spec: Dictionary = ps
				values[String(spec["key"])] = _eval_param(e, spec, pick_t if PlaybackClock.PICK_KEYS.has(String(spec["key"])) else local_t)
			if values.has("crops"):
				expand_crops(values)
			var pairs: PackedStringArray = def.get("pairs_with", PackedStringArray())
			if not pairs.is_empty():
				_inject_pair(values, pairs, ei, pick_t)
			if String(pd["effect_id"]) == PairLayout.PAIR_VIEW_ID:
				PairLayout.fill_uniforms(values, source.native_size, canvas_size(), seq_size)
			if def.has("reactive"):
				AudioReact.fill(values, def, e, self, t)
			eval_cache[cache_key] = values
		var spec_pass: Dictionary = pd["spec"]
		var bypass: bool = not placing_uid.is_empty() and placing_uid == String(pd["uid"])
		if String(pd["effect_id"]) == PairLayout.PAIR_VIEW_ID:
			p.set_param("placing", bypass)
			bypass = false
		var when: Dictionary = spec_pass.get("when", {})
		if not when.is_empty():
			var pk: String = String(when.get("param", ""))
			var pv: Variant = values.get(pk, 0.0)
			bypass = not _when_passes(when, EffectPass._to_float(pv))
		var rep: Dictionary = spec_pass.get("repeat", {})
		if not rep.is_empty():
			var count: int = clampi(int(round(EffectPass._to_float(values.get(String(rep.get("param", "")), 1.0)))), 1, MAX_REPEAT)
			if int(pd["repeat_index"]) >= count:
				bypass = true
		_set_bypass(p, bypass)
		if bypass:
			p.set_size_px(_size_in(out_canvas, eff))
			if String(pd["effect_id"]) == PuppetStage.EFFECT_ID:
				PuppetStage.plain(p)
			continue
		var rel: float = float(spec_pass.get("scale", 1.0))
		var out_scale: float = clampf(eff * (rel if rel > 0.0 else 1.0), 0.03125, 1.0)
		var bend_base: Vector2 = Vector2(picture_size())
		if String(pd["effect_id"]) == PuppetStage.EFFECT_ID and not _in_room:
			var room_box_now: Rect2 = PuppetStage.room_box_for(clip, e, t, seq_fps, bend_base)
			_room = Vector2i(room_box_now.size.round())
			_room_shift = room_box_now.get_center()
			_room_uid = String(pd["uid"])
			_in_room = true
		p.set_size_px(_size_in(out_canvas, out_scale))
		p.set_param("tex_size", in_size)
		p.set_param("seq_size", Vector2(seq_size))
		p.set_param("time", t)
		p.set_param("clip_time", local_t)
		p.set_param("clip_duration", clip.duration)
		p.set_param("px_scale", eff * quality_scale * px_scale_bias)
		for key: Variant in values.keys():
			var v: Variant = values[key]
			if v == null:
				continue
			p.set_param(String(key), v)
		var maps: Dictionary = spec_pass.get("map", {})
		for uname: Variant in maps.keys():
			var mv: Variant = values.get(String(maps[uname]), null)
			if mv != null:
				p.set_param(String(uname), mv)
		if out_canvas and FrameCanvas.is_canvas_def(def):
			FrameCanvas.fill(p, bool(pd.get("canvas_first", false)), source.native_size, canvas_size())
		p.set_param("seq_fps", seq_fps)
		if String(pd["effect_id"]) == PuppetStage.EFFECT_ID:
			PuppetStage.update(p, clip, e, t, seq_fps, bend_base, Vector2(picture_size()), _room_shift)
		eff = out_scale


func _mask_look(p: EffectPass, pd: Dictionary, t: float) -> void:
	var inv: bool = false
	var op: float = 1.0
	var mi: int = int(pd["effect_index"])
	if mi >= 0 and mi < clip.effects.size():
		var masks: Array[Dictionary] = RegionBlocks.chain_masks(clip)
		var at: int = MaskShape.index_of(masks, str(clip.effects[mi].get("mask", "")))
		if at >= 0:
			var mt: float = clip.anim_time(t - clip.start)
			inv = MaskPass.invert_of(masks[at], mt, clip.duration, seq_fps)
			op = clampf(float(MaskShape.value_at(masks[at], "opacity", mt, clip.duration, seq_fps)), 0.0, 1.0)
	p.set_param("mask_invert", inv)
	p.set_param("mask_opacity", op)


func update_masks(t: float) -> void:
	if mask.units.is_empty():
		return
	var masks: Array = RegionBlocks.chain_masks(clip)
	var host: Node = _owner_comp()
	var d: Variant = host.get("doc") if host != null else null
	if d is Object:
		masks = TrackingEval.masks_at(d, clip, masks, t, seq_fps)
	mask.update(masks, clip.anim_time(t - clip.start), clip.duration, seq_fps, quality_scale)


func update_transition(progress: float, kind: int) -> void:
	for pd: Dictionary in passes:
		if String(pd["kind"]) == "transition":
			var p: EffectPass = pd["pass"]
			p.set_param("kind", kind)
			p.set_param("progress", clampf(progress, 0.0, 1.0))


func transform_at(t: float) -> Dictionary:
	if not clip.parent.is_empty():
		return _world_transform_at(t)
	var local_t: float = clip.anim_time(t - clip.start)
	var tr: Dictionary = clip.transform
	var own: bool = not clip.speeds.is_empty()
	var pos: Vector2 = AnimProp.evaluate_vec2(tr.get("pos", AnimProp.make([0.0, 0.0])), clip.inner_time("transform.pos", local_t) if own else local_t, clip.duration, seq_fps)
	var anchor: Vector2 = AnimProp.evaluate_vec2(tr.get("anchor", AnimProp.make([0.0, 0.0])), clip.inner_time("transform.anchor", local_t) if own else local_t, clip.duration, seq_fps)
	var scale: Vector2 = AnimProp.evaluate_vec2(tr.get("scale", AnimProp.make([1.0, 1.0])), clip.inner_time("transform.scale", local_t) if own else local_t, clip.duration, seq_fps)
	if bool(tr.get("scale_linked", true)):
		scale.y = scale.x
	var rotation: float = AnimProp.evaluate_float(tr.get("rotation", AnimProp.make(0.0)), clip.inner_time("transform.rotation", local_t) if own else local_t, clip.duration, seq_fps)
	var opacity: float = AnimProp.evaluate_float(tr.get("opacity", AnimProp.make(1.0)), clip.inner_time("transform.opacity", local_t) if own else local_t, clip.duration, seq_fps)
	var tf: Dictionary = {"pos": pos, "anchor": anchor, "scale": scale, "rotation": rotation, "opacity": clampf(opacity, 0.0, 1.0)}
	if not clip.props.is_empty() and clip.props.has(TrackingEval.STAB_KEY):
		return TrackingEval.stabilised(clip, tf, t)
	return tf


func _world_transform_at(t: float) -> Dictionary:
	var host: Node = _owner_comp()
	var s: Variant = host.get("seq") if host != null else null
	var d: Variant = host.get("doc") if host != null else null
	if not (s is Sequence):
		return Parenting.local_tf(clip, t, seq_fps)
	return Parenting.world_tf(clip, s, t, seq_fps, Parenting.token_of(d) if d is Project else -1)


func _owner_comp() -> Node:
	var n: Node = get_parent()
	var steps: int = 0
	while n != null and steps < OWNER_WALK:
		if n.get("seq") is Sequence:
			return n
		n = n.get_parent()
		steps += 1
	return null

func _place(node: Control, tf: Dictionary, extra_offset: Vector2) -> void:
	var q: float = quality_scale
	var layer_px: Vector2 = Vector2(picture_size())
	var pivot: Vector2 = layer_px * 0.5 - _room_shift + (tf["anchor"] as Vector2)
	var centre: Vector2 = Vector2(seq_size) * 0.5 + (tf["pos"] as Vector2) + extra_offset
	node.size = layer_px * q
	node.pivot_offset = pivot * q
	node.position = (centre - pivot) * q
	node.rotation = deg_to_rad(float(tf["rotation"]))
	node.scale = tf["scale"]


func rect_of(tf: Dictionary, extra_offset: Vector2) -> Rect2:
	var layer_px: Vector2 = Vector2(frame_px())
	var pivot: Vector2 = layer_px * 0.5 + (tf["anchor"] as Vector2)
	var centre: Vector2 = Vector2(seq_size) * 0.5 + (tf["pos"] as Vector2) + extra_offset
	var xf: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, centre)
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(layer_px.x, 0.0), layer_px, Vector2(0.0, layer_px.y)]
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for c: Vector2 in corners:
		var p: Vector2 = xf * (c - pivot)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


func quad_of(tf: Dictionary, extra_offset: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _corners(tf, extra_offset, Vector2(frame_px())):
		out.append(p)
	return out


func pivot_of(tf: Dictionary, extra_offset: Vector2) -> Vector2:
	return Vector2(seq_size) * 0.5 + (tf["pos"] as Vector2) + extra_offset


func _corners(tf: Dictionary, extra_offset: Vector2, size_px: Vector2 = Vector2.ZERO) -> Array[Vector2]:
	var layer_px: Vector2 = size_px if size_px.x > 0.0 else Vector2(picture_size())
	var pivot: Vector2 = layer_px * 0.5 + (tf["anchor"] as Vector2) - (_room_shift if size_px.x <= 0.0 else Vector2.ZERO)
	var centre: Vector2 = Vector2(seq_size) * 0.5 + (tf["pos"] as Vector2) + extra_offset
	var xf: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, centre)
	var out: Array[Vector2] = []
	for c: Vector2 in [Vector2.ZERO, Vector2(layer_px.x, 0.0), layer_px, Vector2(0.0, layer_px.y)]:
		out.append(xf * (c - pivot))
	return out


func update_transform(t: float, extra_offset: Vector2, opacity_mul: float) -> void:
	var tf: Dictionary = transform_at(t)
	var blend: int = int(BLEND_MODES.get(str(clip.transform.get("blend", "normal")), 0))
	var opacity: float = float(tf["opacity"]) * opacity_mul
	quad_mat.set_shader_parameter("opacity", opacity)
	quad_mat.set_shader_parameter("blend", blend)
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if blend != 0 else BackBufferCopy.COPY_MODE_DISABLED
	last_rect = rect_of(tf, extra_offset)
	last_quad = quad_of(tf, extra_offset)
	last_pivot = pivot_of(tf, extra_offset)
	if accum == null:
		_place(quad, tf, extra_offset)
		quad.z_index = 0
		return
	var mb: Dictionary = clip.motion_blur
	var frame_dt: float = 1.0 / maxf(seq_fps, 1.0)
	var local_mb: float = t - clip.start
	var interval: float = frame_dt * clampf(clip.motion_blur_value("shutter_angle", local_mb, seq_fps), 0.0, 720.0) / 360.0
	var t0: float = t + frame_dt * clampf(clip.motion_blur_value("shutter_phase", local_mb, seq_fps), -360.0, 360.0) / 360.0
	var with_rotation: bool = bool(mb.get("rotation", false))
	var tf_a: Dictionary = transform_at(t0)
	var tf_b: Dictionary = transform_at(t0 + interval)
	if not with_rotation:
		tf_a["rotation"] = tf["rotation"]
		tf_b["rotation"] = tf["rotation"]
	var ca: Array[Vector2] = _corners(tf_a, extra_offset)
	var cb: Array[Vector2] = _corners(tf_b, extra_offset)
	var disp: float = 0.0
	for i: int in 4:
		disp = maxf(disp, (ca[i] - cb[i]).length())
	if smooth_rect != null:
		var turn: float = absf(float(tf_b["rotation"]) - float(tf_a["rotation"]))
		var keys: int = 2
		if interval > 0.0:
			keys = clampi(maxi(int(ceil(disp / SMOOTH_KEY_SPACING_PX)), int(ceil(turn / SMOOTH_KEY_SPACING_DEG))) + 2, 2, SMOOTH_KEYS)
		_update_smooth(tf, tf_a, tf_b, t0, interval, keys, with_rotation, extra_offset, local_mb)
		_fill_stage(blur_quad)
		return
	var n: int = clampi(int(ceil(disp / 1.5)), 2, accum_quads.size())
	if interval <= 0.0:
		n = 1
	for i: int in accum_quads.size():
		var q: TextureRect = accum_quads[i]
		if i >= n:
			q.visible = false
			continue
		q.visible = true
		var ti: float = t0 + interval * (float(i) + 0.5) / float(n)
		var tfi: Dictionary = transform_at(ti)
		if not with_rotation:
			tfi["rotation"] = tf["rotation"]
		tfi["opacity"] = tf["opacity"]
		_place(q, tfi, extra_offset)
		(q.material as ShaderMaterial).set_shader_parameter("weight", 1.0 / float(n))
	_fill_stage(blur_quad)


static func _same_place(a: Dictionary, b: Dictionary) -> bool:
	return (a["pos"] as Vector2).is_equal_approx(b["pos"]) and (a["scale"] as Vector2).is_equal_approx(b["scale"]) and (a["anchor"] as Vector2).is_equal_approx(b["anchor"]) and is_equal_approx(float(a["rotation"]), float(b["rotation"]))


func _fill_stage(node: Control) -> void:
	_fit_accum()
	node.size = Vector2(stage_size() + overscan_px * 2)
	node.position = -Vector2(overscan_px)
	node.pivot_offset = Vector2.ZERO
	node.rotation = 0.0
	node.scale = Vector2.ONE


static func _non_zero(v: float) -> float:
	if absf(v) >= 0.00001:
		return v
	return 0.00001 if v >= 0.0 else -0.00001


func stage_to_uv(tf: Dictionary, extra_offset: Vector2) -> Transform2D:
	var q: float = maxf(quality_scale, 0.0001)
	var layer_px: Vector2 = Vector2(picture_size())
	var pivot: Vector2 = layer_px * 0.5 - _room_shift + (tf["anchor"] as Vector2)
	var centre: Vector2 = Vector2(seq_size) * 0.5 + (tf["pos"] as Vector2) + extra_offset
	var sc: Vector2 = tf["scale"]
	var fwd: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), Vector2(_non_zero(sc.x), _non_zero(sc.y)), 0.0, centre)
	var to_uv: Transform2D = Transform2D(Vector2(1.0 / maxf(layer_px.x, 1.0), 0.0), Vector2(0.0, 1.0 / maxf(layer_px.y, 1.0)), Vector2.ZERO)
	var add_pivot: Transform2D = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), pivot)
	var from_stage: Transform2D = Transform2D(Vector2(1.0 / q, 0.0), Vector2(0.0, 1.0 / q), Vector2.ZERO)
	return to_uv * add_pivot * fwd.affine_inverse() * from_stage


func _update_smooth(tf: Dictionary, tf_a: Dictionary, tf_b: Dictionary, t0: float, interval: float, keys: int, with_rotation: bool, extra_offset: Vector2, local_t: float) -> void:
	var moving: bool = interval > 0.0 and not _same_place(tf_a, tf_b)
	var gm: PackedVector4Array = PackedVector4Array()
	var go: PackedVector2Array = PackedVector2Array()
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	var travel: float = 0.0
	var prev: Array[Vector2] = []
	if not moving:
		keys = 2
	for k: int in keys:
		var tfk: Dictionary = tf.duplicate()
		if moving:
			if k == 0:
				tfk = tf_a
			elif k == keys - 1:
				tfk = tf_b
			else:
				tfk = transform_at(t0 + interval * float(k) / float(keys - 1))
				if not with_rotation:
					tfk["rotation"] = tf["rotation"]
		var corners: Array[Vector2] = _corners(tfk, extra_offset)
		var step_len: float = 0.0
		for i: int in 4:
			lo = Vector2(minf(lo.x, corners[i].x), minf(lo.y, corners[i].y))
			hi = Vector2(maxf(hi.x, corners[i].x), maxf(hi.y, corners[i].y))
			if not prev.is_empty():
				step_len = maxf(step_len, (corners[i] - prev[i]).length())
		travel += step_len
		prev = corners
		var g: Transform2D = stage_to_uv(tfk, extra_offset)
		gm.append(Vector4(g.x.x, g.x.y, g.y.x, g.y.y))
		go.append(g.origin)
	while gm.size() < SMOOTH_KEYS:
		gm.append(gm[gm.size() - 1])
		go.append(go[go.size() - 1])
	var q: float = quality_scale
	var travel_px: float = travel * q
	var cap: int = clampi(int(round(clip.motion_blur_value("samples", local_t, seq_fps))) * SMOOTH_TAPS_PER_SAMPLE, SMOOTH_TAPS_PER_SAMPLE, SMOOTH_MAX_TAPS)
	var taps: int = 1
	if moving and travel_px >= 0.5:
		taps = clampi(int(ceil(travel_px * SMOOTH_TAPS_PER_PX)), 2, cap)
	var stage: Vector2 = Vector2(stage_size())
	var r0: Vector2 = Vector2(maxf(floorf(lo.x * q) - 2.0, -float(overscan_px.x)), maxf(floorf(lo.y * q) - 2.0, -float(overscan_px.y)))
	var r1: Vector2 = Vector2(minf(ceilf(hi.x * q) + 2.0, stage.x + float(overscan_px.x)), minf(ceilf(hi.y * q) + 2.0, stage.y + float(overscan_px.y)))
	if r1.x <= r0.x or r1.y <= r0.y:
		smooth_rect.visible = false
		return
	smooth_rect.visible = true
	smooth_rect.position = r0
	smooth_rect.size = r1 - r0
	var sm: ShaderMaterial = smooth_rect.material
	sm.set_shader_parameter("rect_origin", r0)
	sm.set_shader_parameter("rect_size", r1 - r0)
	sm.set_shader_parameter("keys", keys)
	sm.set_shader_parameter("taps", taps)
	sm.set_shader_parameter("gm", gm)
	sm.set_shader_parameter("go", go)


func source_time(t: float) -> float:
	if media != null and media.props.has("still_time"):
		return maxf(float(media.props["still_time"]), 0.0)
	var src: float = PlaybackClock.source_time_for(clip, t, media_fps, seq_fps)
	if clip != null and clip.loop:
		src = clip.loop_source(src, media_duration if media_duration > 0.0 else loop_length)
	if media_duration > 0.0:
		src = clampf(src, 0.0, media_duration)
	return maxf(src, 0.0)


func request_source(t: float, quality: int, hint: int) -> void:
	if _interp_request(t, quality, hint):
		return
	if hint != PACE_HINT_PLAY or source.kind != FrameSource.KIND_NATIVE or not PlayPace.fast(clip, t):
		_paced_src = -1.0
		source.request(source_time(t), quality, hint)
		_end_plan()
		return
	var src: float = source_time(PlayPace.grid_time(clip, t, seq_fps))
	if _paced_clip == clip_id and _paced_src >= 0.0 and src < _paced_src and src > _paced_src - PlayPace.BACK_LIMIT:
		src = _paced_src
	_paced_src = src
	_paced_clip = clip_id
	paced_requests += 1
	source.request(src, quality, hint)
	_send_plan(t)


const PlayPace := preload("res://engine/play_pace.gd")
const PACE_HINT_PLAY := 1

var _paced_src: float = -1.0
var _paced_clip: String = ""
var _plan_ms: int = -1000000
var _plan_clip: String = ""
var _plan_handle: int = -1
var paced_requests: int = 0


func _plan_bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
		if b != null and bool(b.get("available")) and b.has_method("can_tap") and bool(b.call("can_tap")):
			return b
	return null


func _send_plan(t: float) -> void:
	if source.tap_handle >= 0 or source.proxy_on or source.handle < 0:
		_end_plan()
		return
	var now: int = Time.get_ticks_msec()
	if now - _plan_ms < PlayPace.PLAN_EVERY_MS and _plan_clip == clip_id and _plan_handle == source.handle:
		return
	var b: Node = _plan_bridge()
	if b == null:
		return
	if _plan_handle >= 0 and _plan_handle != source.handle:
		b.call("set_play_plan", _plan_handle, PackedFloat64Array())
	var times: PackedFloat64Array = PlayPace.plan_times(clip, t, seq_fps, source_time, source.tap_offsets)
	b.call("set_play_plan", source.handle, times)
	PlayPace.plans_sent += 1
	_plan_ms = now
	_plan_clip = clip_id
	_plan_handle = source.handle


func _end_plan() -> void:
	if _plan_handle < 0:
		return
	var b: Node = _plan_bridge()
	if b != null:
		b.call("set_play_plan", _plan_handle, PackedFloat64Array())
	PlayPace.plans_cleared += 1
	_plan_handle = -1
	_plan_ms = -1000000
	_plan_clip = ""


func state() -> String:
	if interp != null and interp.active():
		return interp.state_of(source.state, _interp_hint)
	return source.state


func layer_rect() -> Rect2:
	return last_rect


func layer_quad() -> PackedVector2Array:
	return last_quad


func layer_pivot() -> Vector2:
	return last_pivot


func set_visible_in_stage(on: bool) -> void:
	if accum != null:
		blur_quad.visible = on
	else:
		quad.visible = on


var _canvas_on: bool = false
var _room: Vector2i = Vector2i.ZERO
var _room_shift: Vector2 = Vector2.ZERO
var _room_uid: String = ""
var _in_room: bool = false
const FULL_BOX := Vector4(0.0, 0.0, 1.0, 1.0)


func _mark_canvas() -> void:
	var on: bool = false
	var first_uid: String = ""
	for pd: Dictionary in passes:
		if not on and String(pd.get("kind", "")) == "effect" and (String(pd.get("effect_id", "")) == PairLayout.PAIR_VIEW_ID or _frame_canvas(String(pd.get("effect_id", "")))):
			on = true
			first_uid = String(pd.get("uid", ""))
		pd["canvas"] = on
		pd["canvas_first"] = on and String(pd.get("uid", "")) == first_uid
	_canvas_on = on


func _frame_canvas(eid: String) -> bool:
	return registry != null and FrameCanvas.is_canvas_def(registry.get_def(eid))


func canvas_size() -> Vector2i:
	return PairLayout.canvas_for(source.native_size, seq_size)


func picture_size() -> Vector2i:
	if _room != Vector2i.ZERO:
		return _room
	return frame_px()


func frame_px() -> Vector2i:
	return canvas_size() if _canvas_on else source.native_size


func room_box() -> Vector4:
	var r: Vector2 = Vector2(picture_size())
	var b: Vector2 = Vector2(frame_px())
	if r.x < 1.0 or r.y < 1.0:
		return FULL_BOX
	return Vector4(((r.x - b.x) * 0.5 - _room_shift.x) / r.x, ((r.y - b.y) * 0.5 - _room_shift.y) / r.y, b.x / r.x, b.y / r.y)


func _base_size(canvas: bool) -> Vector2i:
	if _in_room:
		var rs: Vector2 = Vector2(_room) * quality_scale * PuppetStage.room_scale(Vector2(_room), Vector2(frame_px()))
		return Vector2i(maxi(int(round(rs.x)), 2), maxi(int(round(rs.y)), 2))
	if not canvas:
		return regions.block_size(chain_size())
	var s: Vector2 = Vector2(canvas_size()) * quality_scale
	return Vector2i(maxi(int(round(s.x)), 2), maxi(int(round(s.y)), 2))


func _size_in(canvas: bool, scale: float) -> Vector2i:
	var base: Vector2i = _base_size(canvas)
	return Vector2i(maxi(int(round(float(base.x) * scale)), 2), maxi(int(round(float(base.y) * scale)), 2))


const TimeInterp := preload("res://engine/time_interp.gd")
const InterpStage := preload("res://engine/interp_stage.gd")

var interp: InterpStage = null
var _interp_hint: int = 0


func _interp_sig() -> PackedStringArray:
	var want: String = TimeInterp.active_mode(clip, media, media_fps) if clip != null else ""
	if want.is_empty():
		if interp != null:
			interp.mode = ""
		return PackedStringArray()
	if interp == null:
		interp = InterpStage.new()
		add_child(interp)
	return interp.sync(source, media, want)


func _interp_wire(prev_node: Node, prev_tex: Texture2D) -> Array:
	if interp == null or interp.mode.is_empty():
		return [prev_node, prev_tex]
	return interp.wire(prev_node, prev_tex, chain_size(), quality_scale)


func _interp_release() -> void:
	if interp != null:
		interp.release()


func _interp_request(t: float, quality: int, hint: int) -> bool:
	if interp == null or not interp.active():
		return false
	_interp_hint = hint
	interp.request(source, source_time(t), media_fps, media_duration, quality, hint)
	return true
