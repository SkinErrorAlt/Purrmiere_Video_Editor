extends RefCounted


const ShatterPass := preload("res://engine/shatter_pass.gd")
const FractureMesh := preload("res://engine/fracture_mesh.gd")
const H := 5.0


static func make() -> ShatterPass:
	var p := ShatterPass.new()
	p.name = "shatter3d"
	p.h = H
	return p


static func drive(p: ShatterPass, progress: float, asp: float, values: Dictionary) -> void:
	if p == null or not is_instance_valid(p):
		return
	var chunks: int = clampi(int(round(_f(values, "chunks", 14.0))), 4, 44)
	var seed: int = int(round(_f(values, "variant", 0.0)))
	var force: float = _f(values, "force", 0.9)
	var spread: float = _f(values, "spread", 0.5)
	var gravity: float = _f(values, "gravity", 9.8)
	var restitution: float = _f(values, "restitution", 0.2)
	var drag: float = _f(values, "drag", 0.12)
	var impact: Vector2 = _v2(values, "impact", Vector2(0.5, 0.45))
	var action: int = int(round(_f(values, "action", 0.0)))
	var spin: float = _f(values, "spin", 0.6)
	var pattern: int = int(round(_f(values, "pattern", 0.0)))
	var glass: bool = _f(values, "glass", 0.0) >= 0.5
	var dust: bool = _f(values, "dust", 1.0 if glass else 0.0) >= 0.5
	var dust_amt: float = _f(values, "dust_amt", 1.0)

	if glass:
		p.glass_mat.set_shader_parameter("refraction", _f(values, "refraction", 0.35))
		p.glass_mat.set_shader_parameter("fresnel_power", _f(values, "fresnel", 3.0))
		p.glass_mat.set_shader_parameter("highlight", _f(values, "highlight", 0.9))
		p.glass_mat.set_shader_parameter("tint_amt", _f(values, "tint_amt", 0.14))
		p.glass_mat.set_shader_parameter("dispersion", _f(values, "dispersion", 0.35))
		var tint: Variant = values.get("tint", null)
		if tint is Color:
			p.glass_mat.set_shader_parameter("tint", tint)
		elif tint is Array and (tint as Array).size() >= 3:
			var ta: Array = tint
			p.glass_mat.set_shader_parameter("tint", Color(float(ta[0]), float(ta[1]), float(ta[2]), float(ta[3]) if ta.size() > 3 else 1.0))

	if dust and p.dust_mat != null:
		var dcol: Color = Color(0.82, 0.9, 0.86, 1.0)
		var tv: Variant = values.get("tint", null)
		if glass and tv is Array and (tv as Array).size() >= 3:
			dcol = Color(float(tv[0]), float(tv[1]), float(tv[2]), 1.0).lerp(Color(1, 1, 1, 1), 0.4)
		p.dust_mat.set_shader_parameter("tint", dcol)
		p.dust_mat.set_shader_parameter("brightness", 1.4)

	var key: String = "%.4f|%d|%d|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%d|%.3f|%d|%d|%d|%.3f" % [
		asp, chunks, seed, force, spread, gravity, restitution, drag, impact.x, impact.y, action, spin, pattern, 1 if glass else 0, 1 if dust else 0, dust_amt]
	if key != p.bake_key:
		_bake(p, asp, chunks, seed, force, spread, gravity, restitution, drag, impact, action, spin, pattern, glass)
		_bake_dust(p, asp, impact, gravity, force, seed, dust, dust_amt)
		p.bake_key = key

	var g: float = clampf(progress, 0.0, 1.0)
	if g <= 0.0015:
		_apply_intact(p)
	else:
		_apply(p, g, _f(values, "motion_blur", 0.0))
	_drive_dust(p, g)


static func _bake_dust(p: ShatterPass, asp: float, impact: Vector2, gravity: float, force: float, seed: int, dust: bool, amt: float) -> void:
	p.dust_p0 = PackedVector3Array()
	p.dust_v = PackedVector3Array()
	p.dust_delay = PackedFloat32Array()
	p.dust_size = PackedFloat32Array()
	p.dust_g = gravity
	if p.dust_mm == null:
		return
	if not dust:
		p.dust_mm.multimesh.instance_count = 0
		p.dust_mm.visible = false
		return
	var count: int = clampi(int(round(90.0 * clampf(amt, 0.0, 3.0))), 0, 320)
	var imp_w := Vector3((impact.x - 0.5) * H * asp, (0.5 - impact.y) * H, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 2654435761 + 613
	for i: int in count:
		var dir := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() * 0.85 + 0.2).normalized()
		var spd: float = force * H * (0.5 + 1.5 * rng.randf())
		var jit := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * H * 0.5
		p.dust_p0.append(imp_w + jit)
		p.dust_v.append(dir * spd + Vector3(0.0, H * 0.12, 0.0))
		p.dust_delay.append(rng.randf() * 0.12)
		p.dust_size.append((0.03 + 0.06 * rng.randf()) * H)
	p.dust_mm.multimesh.instance_count = count


static func _drive_dust(p: ShatterPass, g: float) -> void:
	if p.dust_mm == null:
		return
	var mm: MultiMesh = p.dust_mm.multimesh
	var count: int = mm.instance_count
	if count <= 0:
		p.dust_mm.visible = false
		return
	var vis: bool = g > 0.001 and g < 0.97
	p.dust_mm.visible = vis
	if not vis:
		return
	for i: int in count:
		var dl: float = p.dust_delay[i]
		var tt: float = maxf(g - dl, 0.0) * 2.2
		var pos: Vector3 = p.dust_p0[i] + p.dust_v[i] * tt + Vector3(0.0, -0.5 * p.dust_g * tt * tt, 0.0)
		var life: float = clampf((g - dl) / 0.6, 0.0, 1.0)
		var sz: float = p.dust_size[i] * (0.4 + 0.6 * (1.0 - life))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sz, sz, sz)), pos))
	p.dust_mat.set_shader_parameter("fade", clampf(1.0 - smoothstep(0.35, 0.78, g), 0.0, 1.0))


static func _apply_intact(p: ShatterPass) -> void:
	for i: int in p.pieces.size():
		if i < p.home.size():
			var mi: MeshInstance3D = p.pieces[i]
			if is_instance_valid(mi):
				mi.transform = Transform3D(Basis(), p.home[i])


static func _bake(p: ShatterPass, asp: float, chunks: int, seed: int, force: float, spread: float, gravity: float, restitution: float, drag: float, impact: Vector2, action: int, spin: float, pattern: int, glass: bool) -> void:
	if p.phys == null:
		if not ClassDB.class_exists("PurrPhysics"):
			return
		p.phys = ClassDB.instantiate("PurrPhysics")
	var pat: String = "radial" if pattern == 1 else "uniform"
	var seeds: int
	if pattern == 1:
		seeds = clampi(chunks * 16, 48, 460)
	else:
		seeds = clampi(int(round(float(chunks) * float(chunks) / maxf(asp, 0.5))), 16, 360)
	var thickness: float = 0.1
	var shards: Array = FractureMesh.build({
		"asp": asp, "h": H, "seeds": seeds, "impact": impact, "pattern": pat,
		"thickness": thickness, "seed": seed, "alpha_img": null, "alpha_threshold": 0.04,
	})

	var mk: String = "%d|%d|%.4f|%.3f|%d|%d" % [chunks, seed, asp, thickness, pattern, 1 if glass else 0]
	var need_pieces: bool = p.pieces.size() != shards.size() or mk != p.mesh_key
	if need_pieces:
		p.clear_pieces()
		p.mesh_key = mk
	var shard_mat: Material = p.glass_mat if glass else p.mat3d

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
		var sh: Dictionary = shards[i]
		var pos: Vector3 = sh["centroid"]
		positions.append(pos)
		var away: Vector3 = pos - imp_w
		var dist: float = away.length()
		var near: float = clampf(1.0 - dist / (H * 0.9), 0.0, 1.0)
		if away.length() > 0.0001:
			away = away.normalized()
		else:
			away = Vector3(0, -1, 0)
		var jit := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
		var w := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * spin * 15.0
		var vel: Vector3
		if action == 1:
			vel = -away * force * H * (0.45 - 0.2 * near) + Vector3(0, 0, force * H * 0.55 * (0.5 + 0.5 * rng.randf())) + jit * spread * H * 0.2
		elif action == 2:
			vel = Vector3((rng.randf() - 0.5) * H * 0.05, -force * H * 0.04, (rng.randf() - 0.5) * H * 0.04) + jit * H * 0.04
			w = Vector3((0.6 + 0.5 * rng.randf()) * 6.5 * spin, (rng.randf() - 0.5) * 3.0 * spin, (rng.randf() - 0.5) * 3.0 * spin)
		elif action == 3:
			var rdir := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() * 0.8 + 0.2).normalized()
			vel = rdir * force * H * (0.45 + 0.55 * near) + jit * spread * H * 0.32
		elif action == 4:
			var tang := Vector3(-away.y, away.x, 0.0)
			if tang.length() > 0.0001:
				tang = tang.normalized()
			var dn: float = clampf(dist / norm, 0.0, 1.0)
			vel = tang * force * H * (0.35 + 0.65 * dn) - away * force * H * 0.12 + Vector3(0, 0, force * H * 0.35 * (0.3 + 0.7 * near)) + jit * spread * H * 0.18
			w = Vector3(0, 0, (0.8 + 0.6 * rng.randf()) * 9.0 * spin) + Vector3(rng.randf() - 0.5, rng.randf() - 0.5, 0.0) * spin * 6.0
		else:
			vel = away * (spread * H * 0.4 + force * H * 0.3 * near) + Vector3(0, 0, force * H * 0.5 * (0.4 + 0.6 * near)) + jit * H * 0.2
		velocities.append(vel)
		ang.append(w)
		radii.append(float(sh["radius"]) * 0.6)
		p.delay.append(clampf(dist / norm, 0.0, 1.0) * 0.32 + (rng.randf() - 0.5) * 0.03)
		if need_pieces:
			var mi := MeshInstance3D.new()
			mi.mesh = sh["mesh"]
			mi.material_override = shard_mat
			p.world.add_child(mi)
			p.pieces.append(mi)

	p.home = positions
	var steps: int = clampi(int(ceil(2.2 * 60.0)) + 4, 24, 240)
	var floor_y: float = -H * 2.4
	var spec := {
		"count": positions.size(), "steps": steps, "dt": 1.0 / 60.0, "gravity": gravity,
		"restitution": restitution, "drag": drag, "floor_y": floor_y,
		"positions": positions, "velocities": velocities, "radii": radii, "ang_vel": ang,
	}
	var baked: Dictionary = p.phys.call("bake", spec)
	p.baked = baked.get("transforms", PackedFloat32Array())
	p.baked_count = int(baked.get("count", 0))
	p.baked_steps = int(baked.get("steps", 0))

	var cam_d: float = H * 1.5
	p.cam.position = Vector3(0, 0, cam_d)
	p.cam.fov = rad_to_deg(2.0 * atan((H * 0.5) / cam_d))
	p.cam.near = 0.05
	p.cam.far = cam_d * 6.0
	_fit_back(p, asp, cam_d)


static func _fit_back(p: ShatterPass, asp: float, cam_d: float) -> void:
	var bz: float = H * 0.06
	var scale: float = (cam_d + bz) / cam_d
	var w: float = H * asp * scale * 1.02
	var hh: float = H * scale * 1.02
	p.back_mi.mesh = _quad(w, hh)
	p.back_mi.position = Vector3(0, 0, -bz)


static func _apply(p: ShatterPass, g: float, mb: float) -> void:
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


static func _quad(w: float, hh: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bl := Vector3(-w * 0.5, -hh * 0.5, 0)
	var br := Vector3(w * 0.5, -hh * 0.5, 0)
	var tr := Vector3(w * 0.5, hh * 0.5, 0)
	var tl := Vector3(-w * 0.5, hh * 0.5, 0)
	_vert(st, bl, Vector2(0, 1))
	_vert(st, br, Vector2(1, 1))
	_vert(st, tr, Vector2(1, 0))
	_vert(st, bl, Vector2(0, 1))
	_vert(st, tr, Vector2(1, 0))
	_vert(st, tl, Vector2(0, 0))
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
