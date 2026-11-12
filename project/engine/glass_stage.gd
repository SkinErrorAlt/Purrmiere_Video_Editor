extends RefCounted


const Clip := preload("res://doc/clip.gd")
const GlassPass := preload("res://engine/glass_pass.gd")
const FractureMesh := preload("res://engine/fracture_mesh.gd")
const PieceValues := preload("res://engine/piece_values.gd")
const EFFECT_ID := "glass_break"
const H := 5.0


static func build(chain: Object, prev_node: Node, prev_tex: Texture2D) -> GlassPass:
	var p := GlassPass.new()
	p.name = "glass_break"
	if prev_node != null:
		chain._detach(prev_node)
		p.add_child(prev_node)
	p.set_input(prev_tex)
	return p


static func update(p: GlassPass, c: Clip, e: Dictionary, values: Dictionary, local_t: float, clip_dur: float, layer_size: Vector2) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p.mat3d != null:
		p.mat3d.set_shader_parameter("refraction", _f(values, "refraction", 0.35))
		p.mat3d.set_shader_parameter("fresnel_power", _f(values, "fresnel", 3.0))
		p.mat3d.set_shader_parameter("highlight", _f(values, "highlight", 0.9))
		p.mat3d.set_shader_parameter("tint_amt", _f(values, "tint_amt", 0.14))
		p.mat3d.set_shader_parameter("dispersion", _f(values, "dispersion", 0.35))
		var t: Variant = values.get("tint", null)
		if t is Color:
			p.mat3d.set_shader_parameter("tint", Vector4(t.r, t.g, t.b, t.a))
		elif t is Array and (t as Array).size() >= 3:
			p.mat3d.set_shader_parameter("tint", Vector4(float(t[0]), float(t[1]), float(t[2]), 1.0))

	var asp: float = layer_size.x / maxf(layer_size.y, 1.0)
	var chunks: int = clampi(int(round(_f(values, "chunks", 14.0))), 4, 40)
	var seed: int = int(round(_f(values, "seed", 0.0)))
	var fly: float = _f(values, "fly", 0.9)
	var spread: float = _f(values, "spread", 0.5)
	var gravity: float = _f(values, "gravity", 9.8)
	var restitution: float = _f(values, "restitution", 0.2)
	var drag: float = _f(values, "drag", 0.1)
	var floor_mode: int = int(round(_f(values, "floor_mode", 0.0)))
	var duration: float = maxf(_f(values, "duration", 0.9), 0.1)
	var impact: Vector2 = _v2(values, "impact", Vector2(0.5, 0.45))
	var action: int = int(round(_f(values, "action", 0.0)))
	var spin: float = _f(values, "spin", 0.6)
	var overrides: Dictionary = e.get("pieces", {}) if e.get("pieces", null) is Dictionary else {}
	var ranges: Dictionary = PieceValues.ranges_of(e)
	var weight: float = _f(values, "weight", 1.0)

	var key: String = "%.4f|%d|%d|%.3f|%.3f|%.3f|%.3f|%.3f|%d|%.3f|%.3f|%.3f|%d|%.3f|%s" % [
		asp, chunks, seed, fly, spread, gravity, restitution, drag, floor_mode, duration, impact.x, impact.y, action, spin, _ov_stamp(overrides) + PieceValues.stamp(ranges) + ("w%.3f" % weight)]
	if key != p.bake_key:
		_bake(p, asp, chunks, seed, fly, spread, gravity, restitution, drag, floor_mode, duration, impact, action, spin, overrides, ranges, weight)
		p.bake_key = key

	var g: float = _trans_amount(values, local_t, clip_dur)
	if g <= 0.0015:
		_apply_intact(p)
	else:
		_apply(p, g, _f(values, "motion_blur", 0.0))


static func _ov_stamp(overrides: Dictionary) -> String:
	if overrides.is_empty():
		return ""
	var ks: Array = overrides.keys()
	ks.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in ks:
		var ov: Dictionary = overrides[k] if overrides[k] is Dictionary else {}
		var wv: String = ("w%.3f" % float(ov["weight"])) if ov.has("weight") else ""
		var gv: String = ("g%.3f" % float(ov["gravity"])) if ov.has("gravity") else ""
		parts.append(String(k) + ":" + wv + gv)
	return "|".join(parts)


static func _piece_arrays(overrides: Dictionary, n: int, gravity: float) -> Dictionary:
	var masses := PackedFloat32Array()
	var gravities := PackedFloat32Array()
	masses.resize(n)
	gravities.resize(n)
	for i: int in n:
		masses[i] = 1.0
		gravities[i] = gravity
	for k: Variant in overrides.keys():
		var idx: int = int(String(k))
		if idx < 0 or idx >= n:
			continue
		var ov: Dictionary = overrides[k] if overrides[k] is Dictionary else {}
		if ov.has("weight"):
			masses[idx] = maxf(0.0, float(ov["weight"]))
		if ov.has("gravity"):
			gravities[idx] = maxf(0.0, float(ov["gravity"]))
	return {"masses": masses, "gravities": gravities}


static func _bake(p: GlassPass, asp: float, chunks: int, seed: int, fly: float, spread: float, gravity: float, restitution: float, drag: float, floor_mode: int, duration: float, impact: Vector2, action: int, spin: float, overrides: Dictionary = {}, ranges: Dictionary = {}, weight: float = 1.0) -> void:
	if p.phys == null:
		if not ClassDB.class_exists("PurrPhysics"):
			return
		p.phys = ClassDB.instantiate("PurrPhysics")
	var seeds: int = clampi(int(round(float(chunks) * 14.0)), 48, 480)
	var thickness: float = 0.11
	var img: Image = null
	if p.src_tex != null:
		img = p.src_tex.get_image()
	var shards: Array = FractureMesh.build({
		"asp": asp, "h": H, "seeds": seeds, "impact": impact, "pattern": "radial",
		"thickness": thickness, "seed": seed, "alpha_img": img, "alpha_threshold": 0.04,
	})

	var mk: String = "%d|%d|%.4f|%.4f|%.4f|%.3f" % [chunks, seed, asp, impact.x, impact.y, thickness]
	var need_pieces: bool = p.pieces.size() != shards.size() or mk != p.mesh_key
	if need_pieces:
		p.clear_pieces()
		p.mesh_key = mk

	var imp_w := Vector3((impact.x - 0.5) * H * asp, (0.5 - impact.y) * H, 0.0)
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var ang := PackedVector3Array()
	var radii := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 2654435761 + 131
	var norm: float = H * sqrt(asp * asp + 1.0) * 0.5
	p.delay = PackedFloat32Array()
	for i: int in shards.size():
		var p_force: float = PieceValues.value(ranges, "fly", i, fly)
		var p_spin: float = PieceValues.value(ranges, "spin", i, spin)
		var p_spread: float = PieceValues.value(ranges, "spread", i, spread)
		var sh: Dictionary = shards[i]
		var pos: Vector3 = sh["centroid"]
		positions.append(pos)
		var away: Vector3 = pos - imp_w
		var dist: float = away.length()
		var dir: Vector3 = away / dist if dist > 0.0001 else Vector3(0, 1, 0)
		var near: float = clampf(1.0 - dist / (H * 0.9), 0.0, 1.0)
		var jit := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
		var vel: Vector3
		var w := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * p_spin * 16.0
		if action == 1:
			vel = -dir * p_force * H * (0.42 - 0.22 * near) + Vector3(0, 0, p_force * H * 0.5 * (0.5 + 0.5 * rng.randf())) + jit * p_spread * H * 0.18
		elif action == 2:
			vel = Vector3((rng.randf() - 0.5) * H * 0.05, -p_force * H * 0.04, (rng.randf() - 0.5) * H * 0.04) + jit * H * 0.04
			w = Vector3((0.6 + 0.5 * rng.randf()) * 7.0 * p_spin, (rng.randf() - 0.5) * 3.0 * p_spin, (rng.randf() - 0.5) * 3.0 * p_spin)
		elif action == 3:
			var rdir := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() * 0.7 + 0.2).normalized()
			vel = rdir * p_force * H * (0.4 + 0.5 * near) + jit * p_spread * H * 0.3
		else:
			var toward_cam: float = p_force * H * (0.22 + 0.5 * near) * (0.4 + 0.6 * rng.randf())
			vel = dir * p_force * H * (0.18 + 0.4 * near) + Vector3(0, 0, toward_cam) + jit * p_spread * H * 0.3
		velocities.append(vel)
		ang.append(w)
		radii.append(float(sh["radius"]))
		p.delay.append(clampf(dist / norm, 0.0, 1.0) * 0.35 + (rng.randf() - 0.5) * 0.03)
		if need_pieces:
			var mi := MeshInstance3D.new()
			mi.mesh = sh["mesh"]
			mi.material_override = p.mat3d
			p.world.add_child(mi)
			p.pieces.append(mi)

	p.home = positions
	var sim_t: float = duration
	if floor_mode == 0:
		var g_eff: float = maxf(gravity, 0.001)
		var fall_d: float = H * 1.8
		if g_eff > 0.01:
			sim_t = sqrt(2.0 * fall_d / g_eff)
		else:
			sim_t = 3.0
		sim_t = clampf(maxf(sim_t, duration), 0.4, 4.0)
	var steps: int = clampi(int(ceil(sim_t * 60.0)) + 4, 24, 300)
	var floor_y: float = -H * 1.4 if floor_mode == 0 else -H * 0.5
	var spec := {
		"count": positions.size(), "steps": steps, "dt": 1.0 / 60.0, "gravity": gravity,
		"restitution": restitution, "drag": drag, "floor_y": floor_y,
		"positions": positions, "velocities": velocities, "radii": radii, "ang_vel": ang,
	}
	if not overrides.is_empty() or not ranges.is_empty() or weight != 1.0:
		var pa: Dictionary = PieceValues.arrays(overrides, ranges, positions.size(), gravity, weight)
		spec["masses"] = pa["masses"]
		spec["gravities"] = pa["gravities"]
	var baked: Dictionary = p.phys.call("bake", spec)
	p.baked = baked.get("transforms", PackedFloat32Array())
	p.baked_count = int(baked.get("count", 0))
	p.baked_steps = int(baked.get("steps", 0))

	var cam_d: float = H * 1.5
	p.cam.position = Vector3(0, 0, cam_d)
	p.cam.fov = rad_to_deg(2.0 * atan((H * 0.5) / cam_d))
	p.cam.near = 0.05
	p.cam.far = cam_d * 6.0


static func _apply(p: GlassPass, g: float, mb: float = 0.0) -> void:
	var count: int = p.baked_count
	if count <= 0 or p.pieces.size() < count:
		return
	var smax: int = maxi(p.baked_steps - 1, 0)
	for i: int in count:
		var dl: float = p.delay[i] if i < p.delay.size() else 0.0
		var ge: float = clampf((g - dl) / maxf(1.0 - dl, 0.001), 0.0, 1.0)
		var step: int = clampi(int(round(ge * float(maxi(smax, 1)))), 0, smax)
		var base: int = (step * count + i) * 7
		if base + 6 >= p.baked.size():
			continue
		var pos := Vector3(p.baked[base + 0], p.baked[base + 1], p.baked[base + 2])
		var q := Quaternion(p.baked[base + 3], p.baked[base + 4], p.baked[base + 5], p.baked[base + 6])
		var mi: MeshInstance3D = p.pieces[i]
		if not is_instance_valid(mi):
			continue
		mi.transform = Transform3D(_blur_basis(p, i, step, count, Basis(q.normalized()), pos, mb), pos)


static func _blur_basis(p: Object, i: int, step: int, count: int, basis: Basis, pos: Vector3, mb: float) -> Basis:
	if mb <= 0.0 or step <= 0:
		return basis
	var pbase: int = ((step - 1) * count + i) * 7
	if pbase + 2 >= p.baked.size():
		return basis
	var v := pos - Vector3(p.baked[pbase + 0], p.baked[pbase + 1], p.baked[pbase + 2])
	var speed: float = v.length()
	if speed < 0.0001:
		return basis
	var dir := v / speed
	var sfac: float = 1.0 + clampf(speed * 60.0 * mb * 0.06, 0.0, 3.2)
	var k: float = sfac - 1.0
	var cx := basis.x + dir * (k * dir.dot(basis.x))
	var cy := basis.y + dir * (k * dir.dot(basis.y))
	var cz := basis.z + dir * (k * dir.dot(basis.z))
	return Basis(cx, cy, cz)


static func _apply_intact(p: GlassPass) -> void:
	for i: int in p.pieces.size():
		if i < p.home.size():
			var mi: MeshInstance3D = p.pieces[i]
			if is_instance_valid(mi):
				mi.transform = Transform3D(Basis(), p.home[i])


static func _trans_amount(values: Dictionary, local_t: float, clip_dur: float) -> float:
	var when: int = int(round(_f(values, "when", 2.0)))
	var d: float = maxf(_f(values, "duration", 0.9), 0.01)
	if when == 3:
		return clampf(_f(values, "progress", 0.0), 0.0, 1.0)
	var a_in: float = 0.0
	var a_out: float = 0.0
	if when == 0 or when == 1:
		a_in = clampf(1.0 - local_t / d, 0.0, 1.0)
	if when == 0 or when == 2:
		a_out = clampf(1.0 - (clip_dur - local_t) / d, 0.0, 1.0)
	return maxf(a_in, a_out)


static func _quad(w: float, h: float, u0: float, v0: float, u1: float, v1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bl := Vector3(-w * 0.5, -h * 0.5, 0)
	var br := Vector3(w * 0.5, -h * 0.5, 0)
	var tr := Vector3(w * 0.5, h * 0.5, 0)
	var tl := Vector3(-w * 0.5, h * 0.5, 0)
	_vert(st, bl, Vector2(u0, v1))
	_vert(st, br, Vector2(u1, v1))
	_vert(st, tr, Vector2(u1, v0))
	_vert(st, bl, Vector2(u0, v1))
	_vert(st, tr, Vector2(u1, v0))
	_vert(st, tl, Vector2(u0, v0))
	return st.commit()


static func _vert(st: SurfaceTool, pos: Vector3, uv: Vector2) -> void:
	st.set_normal(Vector3(0, 0, 1))
	st.set_uv(uv)
	st.add_vertex(pos)


static func _f(values: Dictionary, key: String, def: float) -> float:
	var v: Variant = values.get(key, def)
	if v is float or v is int:
		return float(v)
	if v is Array and not (v as Array).is_empty():
		return float((v as Array)[0])
	return def


static func _v2(values: Dictionary, key: String, def: Vector2) -> Vector2:
	var v: Variant = values.get(key, def)
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return def
