extends RefCounted

const GifFrames := preload("res://doc/gif_frames.gd")
const MOVING_EXTS: PackedStringArray = ["gif", "mp4", "mov", "m4v", "webm", "mkv", "avi", "mpg", "mpeg", "ts", "wmv", "flv"]
const PICTURE_FILTERS: PackedStringArray = ["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga,*.cube ; Pictures and LUTs", "*.cube ; LUTs"]
const FRAME_FILTERS: PackedStringArray = ["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga,*.gif,*.mp4,*.mov,*.m4v,*.webm,*.mkv,*.avi ; Pictures, GIFs and videos", "*.gif ; GIFs", "*.mp4,*.mov,*.m4v,*.webm,*.mkv,*.avi ; Videos", "*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga ; Pictures"]
const REEL_META := "reel_path"
const MAX_SIDE := 512
const MAX_BYTES := 96 * 1024 * 1024
const MAX_FRAMES := 240
const VIDEO_RATE := 30.0
const OPEN_WAIT_MS := 4000
const CHUNK := 24
const CACHE_MAX := 6
const PACK_CACHE_MAX := 4

static var _reels: Dictionary = {}
static var _posters: Dictionary = {}
static var _packs: Dictionary = {}
static var decode_count: int = 0
static var last_decode_ms: float = 0.0


static func is_moving(path: String) -> bool:
	var p: String = path.strip_edges()
	if p.is_empty():
		return false
	return MOVING_EXTS.has(p.get_extension().to_lower())


static func is_border_path(param_path: String) -> bool:
	var key: String = param_path.get_slice(".", param_path.get_slice_count(".") - 1)
	return key.begins_with("border") and key.trim_prefix("border").is_valid_int()


static func dialog_filters(param_path: String) -> PackedStringArray:
	return FRAME_FILTERS if is_border_path(param_path) else PICTURE_FILTERS


static func _real(path: String) -> String:
	var p: String = path.strip_edges()
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p


static func _stamp(real: String) -> String:
	return real + "|" + str(FileAccess.get_modified_time(real))


static func forget() -> void:
	_reels.clear()
	_posters.clear()
	_packs.clear()


static func reel_of(path: String) -> Dictionary:
	var real: String = _real(path)
	if real.is_empty() or not FileAccess.file_exists(real):
		return {}
	var key: String = _stamp(real)
	if _reels.has(key):
		return _reels[key]
	var t0: int = Time.get_ticks_usec()
	var made: Dictionary = _decode_gif(real) if real.get_extension().to_lower() == "gif" else _decode_video(real)
	last_decode_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	decode_count += 1
	if _reels.size() >= CACHE_MAX:
		_reels.clear()
		_packs.clear()
	_reels[key] = made
	return made


static func poster(path: String) -> Texture2D:
	var real: String = _real(path)
	if real.is_empty():
		return null
	var key: String = _stamp(real)
	if _posters.has(key):
		return _posters[key]
	var reel: Dictionary = reel_of(real)
	var tex: Texture2D = null
	var frames: Array = reel.get("frames", [])
	if not frames.is_empty():
		var it: ImageTexture = ImageTexture.create_from_image(frames[0])
		it.set_meta(REEL_META, real)
		tex = it
	_posters[key] = tex
	return tex


static func reel_path_of(tex: Variant) -> String:
	if tex is Texture2D and (tex as Texture2D).has_meta(REEL_META):
		return String((tex as Texture2D).get_meta(REEL_META))
	return ""


static func _fit(size: Vector2i) -> Vector2i:
	var longest: int = maxi(size.x, size.y)
	if longest <= MAX_SIDE:
		return size
	var k: float = float(MAX_SIDE) / float(longest)
	return Vector2i(maxi(int(round(float(size.x) * k)), 1), maxi(int(round(float(size.y) * k)), 1))


static func _frame_budget(size: Vector2i) -> int:
	var per: int = maxi(size.x * size.y * 4 * 4 / 3, 1)
	return clampi(MAX_BYTES / per, 1, MAX_FRAMES)


static func _finish(frames: Array[Image], delays: PackedFloat64Array, source: String) -> Dictionary:
	var times: PackedFloat64Array = PackedFloat64Array()
	var at: float = 0.0
	for d: float in delays:
		times.append(at)
		at += maxf(d, 0.001)
	var size: Vector2i = frames[0].get_size() if not frames.is_empty() else Vector2i.ZERO
	return {"frames": frames, "times": times, "duration": at, "size": size, "source": source, "count": frames.size()}


static func _decode_gif(real: String) -> Dictionary:
	var got: Dictionary = GifFrames.read_file(real, GifFrames.MAX_FRAMES)
	if not bool(got.get("ok", false)):
		return {}
	var all: Array = got["frames"]
	var delays: PackedFloat64Array = got["delays"]
	var size: Vector2i = _fit(got["size"])
	var budget: int = _frame_budget(size)
	var step: int = maxi(int(ceil(float(all.size()) / float(budget))), 1)
	var frames: Array[Image] = []
	var kept: PackedFloat64Array = PackedFloat64Array()
	var i: int = 0
	while i < all.size():
		var img: Image = all[i]
		if img.get_size() != size:
			img.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		img.generate_mipmaps()
		frames.append(img)
		var span: float = 0.0
		for k: int in range(i, mini(i + step, delays.size())):
			span += delays[k]
		kept.append(span)
		i += step
	return _finish(frames, kept, "gif")


static func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PurrBridge")
	return null


static func _decode_video(real: String) -> Dictionary:
	var b: Node = _bridge()
	if b == null or not bool(b.get("available")) or not b.has_method("snapshot_run"):
		return {}
	var h: int = int(b.call("open_media", real, {}))
	if h < 0:
		return {}
	var info: Dictionary = {}
	var until: int = Time.get_ticks_msec() + OPEN_WAIT_MS
	while Time.get_ticks_msec() < until:
		info = b.call("media_info", h)
		if bool(info.get("ok", false)) and float(info.get("duration", 0.0)) > 0.0:
			break
		OS.delay_msec(5)
	var duration: float = float(info.get("duration", 0.0))
	var fps: float = float(info.get("fps", 0.0))
	var w: int = int(info.get("width", 0))
	var hh: int = int(info.get("height", 0))
	if duration <= 0.0 or w <= 0 or hh <= 0:
		b.call("close_media", h)
		return {}
	var size: Vector2i = _fit(Vector2i(w, hh))
	var rate: float = minf(fps if fps > 0.0 else VIDEO_RATE, VIDEO_RATE)
	var count: int = clampi(int(floor(duration * rate)), 1, _frame_budget(size))
	var span: float = duration / float(count)
	var times: PackedFloat64Array = PackedFloat64Array()
	for i: int in count:
		times.append((float(i) + 0.5) * span)
	var frames: Array[Image] = []
	var delays: PackedFloat64Array = PackedFloat64Array()
	var at: int = 0
	var last: Image = null
	while at < count:
		var chunk: PackedFloat64Array = times.slice(at, mini(at + CHUNK, count))
		var imgs: Array = b.call("snapshot_run", h, chunk, size.x)
		for k: int in chunk.size():
			var img: Variant = imgs[k] if k < imgs.size() else null
			var pic: Image = null
			if img is Image and not (img as Image).is_empty():
				pic = (img as Image).duplicate()
				if pic.get_format() != Image.FORMAT_RGBA8:
					pic.convert(Image.FORMAT_RGBA8)
				if pic.get_size() != size:
					pic.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
				pic.generate_mipmaps()
				last = pic
			elif last != null:
				pic = last
			if pic != null:
				frames.append(pic)
				delays.append(span)
		at += chunk.size()
	b.call("close_media", h)
	if frames.is_empty():
		return {}
	return _finish(frames, delays, "video")


static func frame_at(reel: Dictionary, t: float, loop: bool) -> int:
	var times: PackedFloat64Array = reel.get("times", PackedFloat64Array())
	var n: int = times.size()
	if n <= 1:
		return 0
	var dur: float = float(reel.get("duration", 0.0))
	if dur <= 0.0:
		return 0
	var at: float = fposmod(t + 0.000001, dur) if loop else clampf(t, 0.0, dur)
	if not loop and at >= dur:
		return n - 1
	var lo: int = 0
	var hi: int = n - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if times[mid] <= at + 0.000001:
			lo = mid
		else:
			hi = mid - 1
	return lo


static func pack(paths: PackedStringArray) -> Dictionary:
	var key: String = "\n".join(paths)
	if _packs.has(key):
		return _packs[key]
	var bases: Dictionary = {}
	var reels: Dictionary = {}
	var full: Vector2i = Vector2i.ZERO
	for p: String in paths:
		var r: Dictionary = reel_of(p)
		if (r.get("frames", []) as Array).is_empty():
			continue
		reels[p] = r
		full = full.max(r["size"])
	var layers: Array[Image] = []
	for p2: String in paths:
		if not reels.has(p2):
			continue
		bases[p2] = layers.size()
		for img: Image in (reels[p2]["frames"] as Array):
			layers.append(_padded(img, full))
	var out: Dictionary = {"tex": null, "bases": bases, "reels": reels}
	if not layers.is_empty():
		var arr: Texture2DArray = Texture2DArray.new()
		if arr.create_from_images(layers) == OK:
			out["tex"] = arr
	if _packs.size() >= PACK_CACHE_MAX:
		_packs.clear()
	_packs[key] = out
	return out


static func _padded(pic: Image, full: Vector2i) -> Image:
	if pic.get_size() == full:
		return pic
	var flat: Image = pic.duplicate()
	if flat.has_mipmaps():
		flat.clear_mipmaps()
	var out: Image = Image.create_empty(full.x, full.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(flat, Rect2i(Vector2i.ZERO, flat.get_size()), Vector2i.ZERO)
	out.generate_mipmaps()
	return out
