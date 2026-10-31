extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Puppet := preload("res://doc/puppet.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const EFFECT_ID := "puppet"
const MESH_NODE := "PuppetMesh"
const META_KEY := "puppet_key"
const ROOM_STEPS := 16.0
const ROOM_MAX := 16.0
const ROOM_PX_MAX := 16384.0
const ROOM_EDGE := 2.0
const ROOM_SLACK := 0.5
const ROOM_BUDGET := 16777216.0
const ROOM_SCALE_STEP := 0.125
const ROOM_SCALE_MIN := 0.125

static var builds: int = 0
static var room_budget: float = ROOM_BUDGET


static func attach(p: EffectPass, tex: Texture2D) -> void:
	var mi: MeshInstance2D = MeshInstance2D.new()
	mi.name = MESH_NODE
	mi.texture = tex
	mi.material = p.mat
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	p.add_child(mi)
	p.rect.visible = false


static func plain(p: EffectPass) -> void:
	var mi: MeshInstance2D = p.get_node_or_null(MESH_NODE) as MeshInstance2D
	if mi != null:
		mi.visible = false
	p.rect.visible = true


static func room_for(c: Clip, e: Dictionary, t: float, fps: float, layer_size: Vector2) -> Vector2i:
	return Vector2i(room_box_for(c, e, t, fps, layer_size).size.round())


static func room_box_for(c: Clip, e: Dictionary, t: float, fps: float, layer_size: Vector2) -> Rect2:
	var made: Dictionary = Puppet.deformed_at(c, e, t, fps, layer_size)
	return room_rect(made["mesh"], made["verts"], layer_size)


static func room_of(mesh: Dictionary, verts: PackedVector2Array, layer_size: Vector2) -> Vector2i:
	return Vector2i(room_rect(mesh, verts, layer_size).size.round())


static func room_rect(mesh: Dictionary, verts: PackedVector2Array, layer_size: Vector2) -> Rect2:
	var msize: Vector2 = mesh.get("size", layer_size)
	var k: Vector2 = Vector2(layer_size.x / maxf(msize.x, 1.0), layer_size.y / maxf(msize.y, 1.0))
	var base: Vector2 = Vector2(maxf(round(layer_size.x), 1.0), maxf(round(layer_size.y), 1.0))
	var lo: Vector2 = -base * 0.5
	var hi: Vector2 = base * 0.5
	var inside: Vector2 = base * 0.5 + Vector2(ROOM_SLACK, ROOM_SLACK)
	for v: Vector2 in verts:
		var q: Vector2 = Vector2(v.x * k.x, v.y * k.y)
		for axis: int in 2:
			if q[axis] < -inside[axis]:
				lo[axis] = minf(lo[axis], q[axis] - ROOM_EDGE)
			elif q[axis] > inside[axis]:
				hi[axis] = maxf(hi[axis], q[axis] + ROOM_EDGE)
	var pos: Vector2 = -base * 0.5
	var size: Vector2 = base
	for axis: int in 2:
		var b: float = base[axis]
		var step: float = maxf(ceilf(b / ROOM_STEPS), 8.0)
		var side_max: float = b * (ROOM_MAX - 1.0) * 0.5
		var need_lo: float = -lo[axis] - b * 0.5
		var need_hi: float = hi[axis] - b * 0.5
		var grow_lo: float = 0.0 if need_lo <= 0.001 else minf(ceilf(need_lo / step) * step, side_max)
		var grow_hi: float = 0.0 if need_hi <= 0.001 else minf(ceilf(need_hi / step) * step, side_max)
		pos[axis] = -b * 0.5 - grow_lo
		size[axis] = b + grow_lo + grow_hi
	return Rect2(pos, size)


static func room_scale(room: Vector2, base: Vector2) -> float:
	if room.x <= base.x + 0.5 and room.y <= base.y + 0.5:
		return 1.0
	var area: float = maxf(room.x, 1.0) * maxf(room.y, 1.0)
	var budget: float = maxf(room_budget, base.x * base.y)
	var k: float = 1.0
	if area > budget:
		k = sqrt(budget / area)
	k = minf(k, minf(ROOM_PX_MAX / maxf(room.x, 1.0), ROOM_PX_MAX / maxf(room.y, 1.0)))
	if k >= 1.0:
		return 1.0
	return maxf(floorf(k / ROOM_SCALE_STEP) * ROOM_SCALE_STEP, ROOM_SCALE_MIN)


static func update(p: EffectPass, c: Clip, e: Dictionary, t: float, fps: float, layer_size: Vector2, room: Vector2 = Vector2.ZERO, shift: Vector2 = Vector2.ZERO) -> void:
	var mi: MeshInstance2D = p.get_node_or_null(MESH_NODE) as MeshInstance2D
	if mi == null:
		return
	if p.rect.material != p.mat:
		plain(p)
		return
	p.rect.visible = false
	mi.visible = true
	var made: Dictionary = Puppet.deformed_at(c, e, t, fps, layer_size)
	var mesh: Dictionary = made["mesh"]
	var verts: PackedVector2Array = made["verts"]
	var drawn: PackedInt32Array = made.get("drawn", mesh["tris"])
	var out_px: Vector2 = Vector2(p.size)
	var space: Vector2 = room if room.x >= 1.0 and room.y >= 1.0 else layer_size
	var key: String = String(mesh.get("key", "")) + "|" + str(hash(verts)) + "|" + str(hash(drawn)) + "|" + str(out_px) + "|" + str(space) + "|" + str(layer_size) + "|" + str(shift)
	if mi.mesh != null and String(mi.get_meta(META_KEY, "")) == key:
		return
	mi.mesh = mesh_of(mesh, verts, out_px, layer_size, space, drawn, shift)
	mi.set_meta(META_KEY, key)
	builds += 1


static func mesh_of(mesh: Dictionary, verts: PackedVector2Array, out_px: Vector2, layer_size: Vector2 = Vector2.ZERO, space: Vector2 = Vector2.ZERO, drawn: PackedInt32Array = PackedInt32Array(), shift: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var msize: Vector2 = mesh["size"]
	var base: Vector2 = layer_size if layer_size.x >= 1.0 and layer_size.y >= 1.0 else msize
	var room: Vector2 = space if space.x >= 1.0 and space.y >= 1.0 else base
	var tris: PackedInt32Array = drawn if not drawn.is_empty() and drawn.size() == (mesh["tris"] as PackedInt32Array).size() else mesh["tris"]
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(verts.size())
	for i: int in verts.size():
		var layer_p: Vector2 = verts[i] / msize * base
		pts[i] = ((layer_p - shift) / room + Vector2(0.5, 0.5)) * out_px
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_TEX_UV] = mesh["uv"]
	arrays[Mesh.ARRAY_INDEX] = tris
	var am: ArrayMesh = ArrayMesh.new()
	if not pts.is_empty() and not tris.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
