extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const MaskPass := preload("res://engine/mask_pass.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TitleBounds := preload("res://doc/title_bounds.gd")
const TextFrame := preload("res://doc/text_frame.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const Parenting := preload("res://doc/parenting.gd")
const Puppet := preload("res://doc/puppet.gd")
const ViewHide := preload("res://engine/view_hide.gd")
const TextFx := preload("res://doc/text_fx/text_fx.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const ALPHA_MIN := 0.1
const OPACITY_MIN := 0.01
const ALPHA_SIDE := 256
const ALPHA_CACHE_MAX := 32
const CROP_ID := "crop"
const LINE_MIN_PX := 6.0
const OUTSIDE := Vector2(-1.0, -1.0)

static var _alpha: Dictionary = {}
static var _tasks: Dictionary = {}
static var _lock: Mutex = Mutex.new()
static var alpha_loads: int = 0


static func candidates(s: Sequence, d: Project, t: float) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	var tracks: Array[Track] = s.picture_tracks()
	var any_solo: bool = false
	for tr: Track in tracks:
		if tr.solo:
			any_solo = true
	for ti: int in range(tracks.size() - 1, -1, -1):
		var tr: Track = tracks[ti]
		if tr.muted or tr.locked or (any_solo and not tr.solo):
			continue
		var here: Array[Clip] = tr.clips_at(t)
		for i: int in range(here.size() - 1, -1, -1):
			var c: Clip = here[i]
			if not c.enabled or not tr.is_picture(c) or ViewHide.is_hidden(c, tr):
				continue
			var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
			if m != null and m.kind == "audio":
				continue
			out.append(c)
	return out


static func hits(s: Sequence, d: Project, t: float, at: Vector2, quad_of: Callable = Callable()) -> PackedStringArray:
	var strong: PackedStringArray = PackedStringArray()
	var weak: PackedStringArray = PackedStringArray()
	if s == null:
		return strong
	for c: Clip in candidates(s, d, t):
		var q: PackedVector2Array = PackedVector2Array()
		if quad_of.is_valid():
			var got: Variant = quad_of.call(c)
			if got is PackedVector2Array:
				q = got
		if q.size() != 4:
			q = quad_of_clip(c, s, d, t)
		if not picture_at(c, s, d, t, q, at):
			continue
		var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
		if is_weak(c, m, t, s.fps):
			weak.append(c.id)
		else:
			strong.append(c.id)
	strong.append_array(weak)
	return strong


static func picture_at(c: Clip, s: Sequence, d: Project, t: float, q: PackedVector2Array, at: Vector2) -> bool:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var size: Vector2 = layer_size(c, m, s, d)
	var bent: Dictionary = Puppet.effect_of(c) if not c.effects.is_empty() else {}
	var uv: Vector2 = uv_in(q, at) if bent.is_empty() else puppet_uv(c, s, d, t, at, bent, PairLayout.picture_size(c, size, Vector2(float(s.width), float(s.height))))
	if uv == OUTSIDE:
		return false
	if not PairLayout.hits(c, t, Vector2i(s.width, s.height), Vector2i(size), uv, s.fps):
		return false
	var local: float = c.anim_time(t - c.start)
	if not inside_crops(c, uv, local, s.fps):
		return false
	if mask_alpha(c, uv, size, local, s.fps) < ALPHA_MIN:
		return false
	return content_alpha(c, m, uv, size, t, s) >= ALPHA_MIN


static func puppet_uv(c: Clip, s: Sequence, d: Project, t: float, at: Vector2, e: Dictionary, base: Vector2) -> Vector2:
	var w: Transform2D = Parenting.world_frame(c, s, t, s.fps, Parenting.token_of(d))
	if absf(w.determinant()) < 0.000001:
		return OUTSIDE
	var anchor: Vector2 = Parenting.local_tf(c, t, s.fps)["anchor"]
	var p: Vector2 = w.affine_inverse() * (at - Vector2(float(s.width), float(s.height)) * 0.5) + anchor
	var made: Dictionary = Puppet.deformed_at(c, e, t, s.fps, Puppet.size_of(e, base))
	var mesh: Dictionary = made["mesh"]
	var tris: PackedInt32Array = made.get("drawn", mesh["tris"])
	var got: Dictionary = Puppet.locate_top(made["verts"], tris, p)
	if got.is_empty() or not bool(got["inside"]):
		return OUTSIDE
	var ti: int = int(got["tri"])
	var bw: Vector3 = got["w"]
	var uvs: PackedVector2Array = mesh["uv"]
	return uvs[tris[ti * 3]] * bw.x + uvs[tris[ti * 3 + 1]] * bw.y + uvs[tris[ti * 3 + 2]] * bw.z


static func uv_in(q: PackedVector2Array, p: Vector2) -> Vector2:
	if q.size() != 4:
		return OUTSIDE
	var ex: Vector2 = q[1] - q[0]
	var ey: Vector2 = q[3] - q[0]
	var det: float = ex.x * ey.y - ex.y * ey.x
	if absf(det) < 0.000001:
		return OUTSIDE
	var dp: Vector2 = p - q[0]
	var u: float = (dp.x * ey.y - dp.y * ey.x) / det
	var v: float = (ex.x * dp.y - ex.y * dp.x) / det
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return OUTSIDE
	return Vector2(u, v)


static func layer_size(c: Clip, m: MediaItem, s: Sequence, d: Project) -> Vector2:
	if c.is_nest() or (m != null and m.kind == "sequence"):
		var ns: Sequence = d.sequence_by_id(c.sequence_id if c.is_nest() else m.sequence_id) if d != null else null
		if ns != null:
			return Vector2(float(ns.width), float(ns.height))
	if m != null and m.width > 0 and m.height > 0 and m.kind != "adjust":
		return Vector2(float(m.width), float(m.height))
	return Vector2(float(s.width), float(s.height))


static func quad_of_clip(c: Clip, s: Sequence, d: Project, t: float) -> PackedVector2Array:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var base: Vector2 = PairLayout.picture_size(c, layer_size(c, m, s, d), Vector2(float(s.width), float(s.height)))
	return quad_from_tf(Parenting.world_tf(c, s, t, s.fps, Parenting.token_of(d)), base, s)


static func quad_from_tf(tf: Dictionary, base: Vector2, s: Sequence) -> PackedVector2Array:
	return quad_from_tf_rect(tf, base, Rect2(Vector2.ZERO, base), s)


static func quad_from_tf_rect(tf: Dictionary, base: Vector2, r: Rect2, s: Sequence) -> PackedVector2Array:
	var pivot_px: Vector2 = base * 0.5 + (tf["anchor"] as Vector2)
	var centre: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5 + (tf["pos"] as Vector2)
	var xf: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, centre)
	var out: PackedVector2Array = PackedVector2Array()
	for cn: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out.append(xf * (cn - pivot_px))
	return out


static func words_only(c: Clip, m: MediaItem, size: Vector2, t: float, s: Sequence) -> Rect2:
	var whole: Rect2 = Rect2(Vector2.ZERO, size)
	if m == null or c == null or c.is_nest() or m.kind != "title":
		return whole
	var props: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(t - c.start, s.fps)
	for k: Variant in now.keys():
		props[k] = now[k]
	TextFx.apply_to_props(c, EffectSource.registry(), props, m.label, t - c.start, s.fps)
	var merged: Dictionary = TitleStyle.merged("title", {}, props, m.label)
	if TextFrame.is_box(merged):
		return TextFrame.box_rect(merged, size)
	if TextFrame.is_point(merged):
		var tight: Rect2 = TextGlyphs.bounds(merged, size)
		return tight if tight.has_area() else Rect2(size * 0.5, Vector2(1.0, 1.0))
	var r: Rect2 = title_rect(merged, size)
	if not r.has_area():
		return whole
	var cut: Rect2 = r.intersection(whole)
	return cut if cut.has_area() else whole


static func snaps_by_words(c: Clip, d: Project) -> bool:
	if c == null or d == null or c.is_nest():
		return false
	var m: MediaItem = d.media_by_id(c.media_id)
	return m != null and m.kind == "title"


static func words_quad_of_clip(c: Clip, s: Sequence, d: Project, t: float) -> PackedVector2Array:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var base: Vector2 = PairLayout.picture_size(c, layer_size(c, m, s, d), Vector2(float(s.width), float(s.height)))
	return quad_from_tf_rect(Parenting.world_tf(c, s, t, s.fps, Parenting.token_of(d)), base, words_only(c, m, base, t, s), s)


static func _param(params: Dictionary, key: String, t: float, dur: float, fps: float) -> float:
	var p: Variant = params.get(key, null)
	if p is Dictionary:
		return AnimProp.evaluate_float(p, t, dur, fps)
	if p is float or p is int:
		return float(p)
	return 0.0


static func inside_crops(c: Clip, uv: Vector2, local: float, fps: float) -> bool:
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) != CROP_ID or not bool(e.get("enabled", true)):
			continue
		var params: Dictionary = e.get("params", {})
		var l: float = _param(params, "left", c.fx_inner(e, "left", local), c.duration, fps)
		var tp: float = _param(params, "top", c.fx_inner(e, "top", local), c.duration, fps)
		var r: float = _param(params, "right", c.fx_inner(e, "right", local), c.duration, fps)
		var b: float = _param(params, "bottom", c.fx_inner(e, "bottom", local), c.duration, fps)
		if uv.x < l or uv.x > 1.0 - r or uv.y < tp or uv.y > 1.0 - b:
			return false
	return true


static func mask_alpha(c: Clip, uv: Vector2, size: Vector2, local: float, fps: float) -> float:
	if c.masks.is_empty():
		return 1.0
	var bound: PackedStringArray = LayerChain.effect_mask_ids(c)
	var px: Vector2 = uv * size
	var aspect: float = size.x / maxf(size.y, 1.0)
	var out: float = 1.0
	var first: bool = true
	for i: int in c.masks.size():
		var m: Dictionary = c.masks[i]
		if not bool(m.get("enabled", true)) or bound.has(MaskPass.mask_id(m, i)):
			continue
		var box_kind: bool = MaskShape.BOX_KINDS.has(str(m.get("kind", "")))
		var expand: float = float(MaskShape.value_at(m, "expand", local, c.duration, fps))
		var grow: Vector2 = Vector2(expand / maxf(size.x, 1.0), expand / maxf(size.y, 1.0)) if box_kind else Vector2.ZERO
		var pts: PackedVector2Array = MaskPass.shape_points(m, local, c.duration, fps, aspect, grow)
		var v: float = 0.0
		if pts.size() >= 3:
			var poly: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in pts:
				poly.append(p * size)
			if not box_kind:
				poly = MaskPass.offset_polygon(poly, expand)
			v = 1.0 if Geometry2D.is_point_in_polygon(px, poly) else 0.0
		if MaskPass.invert_of(m, local, c.duration, fps):
			v = 1.0 - v
		v *= clampf(float(MaskShape.value_at(m, "opacity", local, c.duration, fps)), 0.0, 1.0)
		var mode: int = MaskPass.mode_of(m, local, c.duration, fps)
		if first:
			out = 1.0 - v if mode == 1 else v
			first = false
		elif mode == 1:
			out *= 1.0 - v
		elif mode == 2:
			out *= v
		else:
			out = maxf(out, v)
	return out


static func content_alpha(c: Clip, m: MediaItem, uv: Vector2, size: Vector2, t: float, s: Sequence) -> float:
	if m == null or c.is_nest():
		return 1.0
	if m.kind == "image":
		return image_alpha(m.path, uv)
	if m.kind != "title" and m.kind != "shape":
		return 1.0
	var props: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(t - c.start, s.fps)
	for k: Variant in now.keys():
		props[k] = now[k]
	if m.kind == "title":
		var merged: Dictionary = TitleStyle.merged("title", {}, props, m.label)
		if TextFrame.is_box(merged):
			return 1.0 if TextFrame.box_rect(merged, size).has_point(uv * size) else 0.0
		if TextGlyphs.active(merged):
			var slack: float = maxf(float(merged.get("box_pad", 12.0)), 0.0) * size.y / 1080.0
			return 1.0 if TextGlyphs.hit(merged, size, uv * size, slack) else 0.0
		return 1.0 if title_rect(merged, size).has_point(uv * size) else 0.0
	return shape_alpha(TitleStyle.merged("shape", {}, props), uv, size)


static func title_rect(props: Dictionary, size: Vector2) -> Rect2:
	if TextGlyphs.active(props):
		var pad: float = maxf(float(props.get("box_pad", 12.0)), 0.0) * size.y / 1080.0
		var r: Rect2 = TextGlyphs.bounds(props, size)
		return r.grow(pad) if r.has_area() else Rect2()
	return TitleBounds.rect(props, size)


static func shape_alpha(props: Dictionary, uv: Vector2, size: Vector2) -> float:
	var w: float = clampf(float(props.get("width", 0.5)), 0.001, 1.0)
	var h: float = clampf(float(props.get("height", 0.5)), 0.001, 1.0)
	var shape: String = String(props.get("shape", "rect"))
	var off: Vector2 = uv - Vector2(0.5, 0.5)
	if shape == "ellipse":
		var e: Vector2 = off / (Vector2(w, h) * 0.5)
		return 1.0 if e.length_squared() <= 1.0 else 0.0
	if shape == "line":
		var half_h: float = maxf(h * size.y * 0.5, LINE_MIN_PX)
		return 1.0 if absf(off.x) <= w * 0.5 and absf(off.y * size.y) <= half_h else 0.0
	return 1.0 if absf(off.x) <= w * 0.5 and absf(off.y) <= h * 0.5 else 0.0


static func image_alpha(path: String, uv: Vector2) -> float:
	var img: Image = alpha_image(path)
	if img == null:
		return 1.0
	var x: int = clampi(int(uv.x * float(img.get_width())), 0, img.get_width() - 1)
	var y: int = clampi(int(uv.y * float(img.get_height())), 0, img.get_height() - 1)
	return img.get_pixel(x, y).a


static func _full_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


static func _alpha_key(full: String) -> String:
	return full + "|" + str(FileAccess.get_modified_time(full) if FileAccess.file_exists(full) else 0)


static func read_alpha(full: String) -> Image:
	var img: Image = Image.new()
	if not FileAccess.file_exists(full) or img.load(full) != OK or img.get_width() < 1 or img.get_height() < 1 or img.detect_alpha() == Image.ALPHA_NONE:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > ALPHA_SIDE:
		var k: float = float(ALPHA_SIDE) / float(longest)
		img.resize(maxi(1, int(round(float(img.get_width()) * k))), maxi(1, int(round(float(img.get_height()) * k))), Image.INTERPOLATE_BILINEAR)
	return img


static func _store(key: String, img: Image) -> void:
	_lock.lock()
	if _alpha.size() >= ALPHA_CACHE_MAX:
		_alpha.clear()
	_alpha[key] = img
	alpha_loads += 1
	_lock.unlock()


static func alpha_image(path: String) -> Image:
	if path.is_empty():
		return null
	var full: String = _full_path(path)
	var key: String = _alpha_key(full)
	_reap()
	_lock.lock()
	var cached: bool = _alpha.has(key)
	var have: Image = _alpha.get(key, null)
	var task: int = int(_tasks.get(key, -1))
	_lock.unlock()
	if cached:
		return have
	if task >= 0:
		WorkerThreadPool.wait_for_task_completion(task)
		_lock.lock()
		_tasks.erase(key)
		have = _alpha.get(key, null)
		_lock.unlock()
		return have
	var out: Image = read_alpha(full)
	_store(key, out)
	return out


static func _reap() -> void:
	_lock.lock()
	var keys: Array = _tasks.keys()
	_lock.unlock()
	for key: Variant in keys:
		_lock.lock()
		var id: int = int(_tasks.get(key, -1))
		_lock.unlock()
		if id >= 0 and WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_lock.lock()
			_tasks.erase(key)
			_lock.unlock()


static func warm(s: Sequence, d: Project, t: float) -> int:
	var started: int = 0
	if s == null or d == null:
		return started
	_reap()
	for c: Clip in candidates(s, d, t):
		var m: MediaItem = d.media_by_id(c.media_id)
		if m == null or m.kind != "image" or m.path.is_empty():
			continue
		var full: String = _full_path(m.path)
		var key: String = _alpha_key(full)
		_lock.lock()
		var known: bool = _alpha.has(key) or _tasks.has(key)
		_lock.unlock()
		if known:
			continue
		var id: int = WorkerThreadPool.add_task(_warm_task.bind(full, key), false, "Read a picture's see through parts")
		_lock.lock()
		_tasks[key] = id
		_lock.unlock()
		started += 1
	return started


static func _warm_task(full: String, key: String) -> void:
	_store(key, read_alpha(full))


static func settle_warm() -> void:
	_lock.lock()
	var ids: Array = _tasks.values()
	_lock.unlock()
	for id: Variant in ids:
		WorkerThreadPool.wait_for_task_completion(int(id))
	_lock.lock()
	_tasks.clear()
	_lock.unlock()


static func is_weak(c: Clip, m: MediaItem, t: float, fps: float) -> bool:
	if m != null and m.kind == "adjust":
		return true
	var local: float = c.anim_time(t - c.start)
	var op: float = AnimProp.evaluate_float(c.transform.get("opacity", AnimProp.make(1.0)), c.inner_time("transform.opacity", local), c.duration, fps)
	return op * c.video_fade_mul(t) < OPACITY_MIN


static func forget_alpha() -> void:
	settle_warm()
	_lock.lock()
	_alpha.clear()
	_lock.unlock()
