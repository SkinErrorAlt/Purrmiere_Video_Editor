extends RefCounted

const Clip := preload("res://doc/clip.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const IN_SHADER := "res://engine/region_in.gdshader"
const OUT_SHADER := "res://engine/region_out.gdshader"
const KIND_IN := "region_in"
const KIND_OUT := "region_out"
const KIND_END := "region_end"
const BLOCK_META := "region_block"
const TEX_PREFIX := "region_tex"
const BITS := "region_own"

static var _shaders: Dictionary = {}

var base_tex: Texture2D = null
var base_scale: float = 1.0
var outs: Dictionary = {}
var _block_base: Vector2 = Vector2.ZERO
var _block_eff: float = 1.0


static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


static func is_marker(kind: String) -> bool:
	return kind == KIND_IN or kind == KIND_OUT


static func block_of(c: Clip) -> Dictionary:
	if c == null or not c.has_meta(BLOCK_META):
		return {}
	var v: Variant = c.get_meta(BLOCK_META)
	return v if v is Dictionary else {}


static func steps(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var block: Dictionary = block_of(c)
	if not block.is_empty():
		var members: PackedStringArray = block.get("members", PackedStringArray())
		var member_steps: Array[Dictionary] = []
		for k: int in c.effects.size():
			var e: Dictionary = c.effects[k]
			if members.has(String(e.get("uid", ""))):
				member_steps.append({"e": _stripped(e), "index": k})
			else:
				out.append({"e": e, "index": k})
		_emit(out, String((block["pv"] as Dictionary).get("uid", "")), int(block["index"]), member_steps)
		return out
	var links: Dictionary = RegionFx.links(c)
	for k2: int in c.effects.size():
		var e2: Dictionary = c.effects[k2]
		var uid: String = String(e2.get("uid", ""))
		if links.has(uid):
			continue
		if not links.is_empty() and RegionFx.is_pair_view(e2) and bool(e2.get("enabled", true)):
			_emit_pair(out, c, uid, links)
		out.append({"e": e2, "index": k2})
	return out


static func _stripped(e: Dictionary) -> Dictionary:
	var s: Dictionary = e.duplicate()
	s["mask"] = ""
	return s


static func _emit(out: Array[Dictionary], pv_uid: String, index: int, members: Array[Dictionary]) -> bool:
	var any_on: bool = false
	for m: Dictionary in members:
		if bool((m["e"] as Dictionary).get("enabled", true)):
			any_on = true
	if not any_on:
		return false
	var region: Dictionary = {"pv": pv_uid, "index": index}
	out.append({"marker": KIND_IN, "region": region})
	for m2: Dictionary in members:
		m2["region"] = region
		out.append(m2)
	out.append({"marker": KIND_OUT, "region": region})
	return true


static func _emit_pair(out: Array[Dictionary], c: Clip, pv_uid: String, links: Dictionary) -> void:
	var by_region: Dictionary = {}
	for k: int in c.effects.size():
		var e: Dictionary = c.effects[k]
		var link: Dictionary = links.get(String(e.get("uid", "")), {})
		if link.is_empty() or String(link["pv"]) != pv_uid:
			continue
		var i: int = int(link["index"])
		if not by_region.has(i):
			var fresh: Array[Dictionary] = []
			by_region[i] = fresh
		(by_region[i] as Array).append({"e": _stripped(e), "index": k})
	var order: Array = by_region.keys()
	order.sort()
	var any: bool = false
	for i2: Variant in order:
		var members: Array[Dictionary] = by_region[i2]
		if _emit(out, pv_uid, int(i2), members):
			any = true
	if any:
		out.append({"marker": KIND_END, "region": {"pv": pv_uid, "index": -1}})


static func signature(c: Clip) -> String:
	var block: Dictionary = block_of(c)
	if not block.is_empty():
		return "b" + str(int(block["index"])) + ":" + ",".join(block.get("members", PackedStringArray()))
	if c == null or c.masks.is_empty():
		return ""
	var links: Dictionary = RegionFx.links(c)
	if links.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for uid: Variant in links.keys():
		var link: Dictionary = links[uid]
		parts.append(String(uid) + "@" + String(link["pv"]) + ":" + str(int(link["index"])))
	return ",".join(parts)


static func structure(c: Clip) -> Array:
	if c == null:
		return [[] as Array[Dictionary], ""]
	var block: Dictionary = block_of(c)
	if not block.is_empty():
		return [c.masks, signature(c)]
	if not _any_link(c):
		return [c.masks, ""]
	var links: Dictionary = RegionFx.links(c)
	var gone: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = PackedStringArray()
	for uid: Variant in links.keys():
		var link: Dictionary = links[uid]
		parts.append(String(uid) + "@" + String(link["pv"]) + ":" + str(int(link["index"])))
		if not gone.has(String(link["mask"])):
			gone.append(String(link["mask"]))
	return [_kept_masks(c, gone), ",".join(parts)]


static func _any_link(c: Clip) -> bool:
	for m: Dictionary in c.masks:
		if not String(m.get(RegionFx.LINK_KEY, "")).is_empty():
			return true
	return false


static func chain_masks(c: Clip) -> Array[Dictionary]:
	if c == null:
		return []
	if not _any_link(c):
		return c.masks
	return _kept_masks(c, RegionFx.linked_mask_ids(c))


static func _kept_masks(c: Clip, gone: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m2: Dictionary in c.masks:
		var mid: String = String(m2.get("id", ""))
		if gone.has(mid) or (not String(m2.get(RegionFx.LINK_KEY, "")).is_empty() and not _bound(c, mid)):
			continue
		out.append(m2)
	return out


static func _bound(c: Clip, mid: String) -> bool:
	if mid.is_empty():
		return false
	for e: Dictionary in c.effects:
		if String(e.get("mask", "")) == mid:
			return true
	return false


static func shape_shadow(shadow: Clip, c: Clip, e: Dictionary, index: int) -> void:
	if shadow == null:
		return
	var links: Dictionary = RegionFx.links(c)
	if links.is_empty():
		if shadow.has_meta(BLOCK_META):
			shadow.remove_meta(BLOCK_META)
		return
	var pv_uid: String = String(e.get("uid", ""))
	var fx: Array[Dictionary] = []
	for se: Dictionary in shadow.effects:
		if not links.has(String(se.get("uid", ""))):
			fx.append(se)
	var members: PackedStringArray = PackedStringArray()
	for ce: Dictionary in c.effects:
		var uid: String = String(ce.get("uid", ""))
		var link: Dictionary = links.get(uid, {})
		if not link.is_empty() and String(link["pv"]) == pv_uid and int(link["index"]) == index:
			fx.append(ce)
			members.append(uid)
	shadow.effects = fx
	var gone: PackedStringArray = RegionFx.linked_mask_ids(c)
	var ms: Array[Dictionary] = []
	for m: Dictionary in shadow.masks:
		if not gone.has(String(m.get("id", ""))):
			ms.append(m)
	shadow.masks = ms
	if members.is_empty():
		if shadow.has_meta(BLOCK_META):
			shadow.remove_meta(BLOCK_META)
		return
	shadow.set_meta(BLOCK_META, {"pv": e, "index": index, "members": members})


static func _types(sh: Shader) -> Dictionary:
	var out: Dictionary = {}
	if sh == null:
		return out
	for u: Dictionary in sh.get_shader_uniform_list(true):
		out[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	return out


static func _px(v: Vector2) -> Vector2i:
	return Vector2i(maxi(int(round(v.x)), 2), maxi(int(round(v.y)), 2))


static func tag(made: Array[Dictionary], step: Dictionary) -> void:
	if not step.has("region"):
		return
	for pd: Dictionary in made:
		pd["region"] = step["region"]


func begin() -> void:
	base_tex = null
	base_scale = 1.0
	outs = {}
	_block_base = Vector2.ZERO
	_block_eff = 1.0


func marker(step: Dictionary, prev_node: Node, prev_tex: Texture2D, scale: float, passes: Array[Dictionary]) -> Dictionary:
	var kind: String = String(step["marker"])
	var region: Dictionary = step["region"]
	if kind == KIND_END:
		var back: Texture2D = base_tex if base_tex != null else prev_tex
		var back_scale: float = base_scale if base_tex != null else scale
		base_tex = null
		return {"node": prev_node, "tex": back, "scale": back_scale}
	if base_tex == null:
		base_tex = prev_tex
		base_scale = scale
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader(IN_SHADER if kind == KIND_IN else OUT_SHADER)
	var p: EffectPass = EffectPass.new()
	p.name = kind + "_" + String(region["pv"]) + "_" + str(int(region["index"]))
	p.setup(mat, _types(mat.shader))
	if prev_node != null:
		var parent: Node = prev_node.get_parent()
		if parent != null:
			parent.remove_child(prev_node)
		p.add_child(prev_node)
	p.set_input(base_tex if kind == KIND_IN else prev_tex)
	var out_scale: float = scale
	if kind == KIND_OUT:
		p.set_param("base_tex", base_tex)
		var pv: String = String(region["pv"])
		if not outs.has(pv):
			outs[pv] = {}
		(outs[pv] as Dictionary)[int(region["index"])] = p.output()
		out_scale = base_scale
	passes.append({"pass": p, "uid": "", "effect_id": "", "effect_index": -1, "pass_index": -1, "repeat_index": 0, "spec": {}, "scale_in": scale, "scale_out": out_scale, "kind": kind, "effect_in_tex": null, "region": region})
	return {"node": p, "tex": p.output(), "scale": out_scale}


func wire(passes: Array[Dictionary]) -> void:
	if outs.is_empty():
		return
	for pd: Dictionary in passes:
		if String(pd.get("kind", "")) != "effect" or String(pd.get("effect_id", "")) != RegionFx.PAIR_VIEW_ID:
			continue
		var mine: Dictionary = outs.get(String(pd.get("uid", "")), {})
		if mine.is_empty():
			continue
		var p: EffectPass = pd["pass"]
		var bits: int = 0
		for key: Variant in mine.keys():
			p.set_param(TEX_PREFIX + str(int(key)), mine[key])
			bits |= 1 << int(key)
		p.set_param(BITS, bits)


func merge(e: Dictionary, p: EffectPass, bits: int, raw: Dictionary) -> int:
	if outs.is_empty() or p == null:
		return bits
	var mine: Dictionary = outs.get(String(e.get("uid", "")), {})
	if mine.is_empty():
		return bits
	var out_bits: int = bits
	for key: Variant in mine.keys():
		var i: int = int(key)
		if (bits >> i) & 1 == 1:
			var own: Variant = p.param_value(TEX_PREFIX + str(i))
			if own is Texture2D:
				raw[i] = own
			continue
		p.set_param(TEX_PREFIX + str(i), mine[key])
		raw[i] = mine[key]
		out_bits |= 1 << i
	return out_bits


func _pair_for(c: Clip, uid: String) -> Dictionary:
	var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
	if not e.is_empty():
		return e
	var block: Dictionary = block_of(c)
	if not block.is_empty():
		return block["pv"]
	return {}


func update_marker(c: Clip, pd: Dictionary, eff: float, chain_px: Vector2i) -> float:
	var p: EffectPass = pd["pass"]
	var region: Dictionary = pd["region"]
	var cr: Dictionary = RegionFx.crop(_pair_for(c, String(region["pv"])), int(region["index"]))
	var rect: Rect2 = cr.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
	var full: Vector2 = Vector2(chain_px)
	p.set_param("region_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	p.set_param("region_rot", deg_to_rad(float(cr.get("rot", 0.0))))
	if String(pd["kind"]) == KIND_IN:
		_block_eff = eff
		_block_base = full * rect.size
		p.set_param("src_size", full * eff)
		p.set_size_px(_px(_block_base * eff))
		return eff
	p.set_param("src_size", full * _block_eff)
	p.set_size_px(_px(full * _block_eff))
	_block_base = Vector2.ZERO
	return _block_eff


func block_size(chain_px: Vector2i) -> Vector2i:
	if _block_base == Vector2.ZERO:
		return chain_px
	return _px(_block_base)
