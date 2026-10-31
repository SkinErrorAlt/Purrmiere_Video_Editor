extends RefCounted

const CHUNK := 24
const MAX_FACTOR := 16
const GRID_TOLERANCE := 0.05
const SPEED_SAMPLES := 64
const SCENE_THRESHOLD := 0.16
const SCENE_W := 64
const SCENE_H := 36
const SCENE_SKIP := "Skip"
const SCENE_BLEND := "Blend"
const SCENE_OFF := "Off"
const EPS := 0.000001

static var loose_keys: bool = false


static func frames_per_output(clip: RefCounted, media_fps: float, seq_fps: float) -> float:
	if clip == null or media_fps <= 0.0 or seq_fps <= 0.0:
		return 0.0
	var lowest: float = INF
	if bool(clip.call("is_speed_static")):
		lowest = absf(float(clip.call("static_speed")))
	else:
		var dur: float = float(clip.get("duration"))
		for i: int in SPEED_SAMPLES + 1:
			var u: float = dur * float(i) / float(SPEED_SAMPLES)
			var s: float = absf(float(clip.call("speed_at", u)))
			if s > EPS:
				lowest = minf(lowest, s)
	if lowest == INF or lowest <= EPS:
		return 0.0
	return lowest * media_fps / seq_fps


static func factor_for_rate(r: float, keyed: bool) -> int:
	if r <= EPS or r >= 1.0 - EPS:
		return 0
	var base: int = clampi(int(ceil(1.0 / r - EPS)), 2, MAX_FACTOR)
	if keyed:
		return base
	for n: int in range(base, MAX_FACTOR + 1):
		var x: float = r * float(n)
		if absf(x - round(x)) < GRID_TOLERANCE:
			return n
	return base


static func factor_for(clip: RefCounted, media_fps: float, seq_fps: float) -> int:
	var r: float = frames_per_output(clip, media_fps, seq_fps)
	return factor_for_rate(r, not bool(clip.call("is_speed_static")))


static func frame_count(media_duration: float, fps: float) -> int:
	if media_duration <= 0.0 or fps <= 0.0:
		return 0
	return maxi(int(floor(media_duration * fps + 0.5)), 1)


static func frame_range(reach: Vector2, fps: float, total: int) -> Vector2i:
	var lo: int = maxi(int(floor(reach.x * fps + EPS)), 0)
	var hi: int = int(ceil(reach.y * fps - EPS))
	if total > 0:
		hi = mini(hi, total - 1)
		lo = mini(lo, total - 1)
	return Vector2i(lo, maxi(hi, lo))


static func chunks_for_range(frames: Vector2i) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var first: int = frames.x / CHUNK
	var last: int = maxi(frames.y - 1, frames.x) / CHUNK
	for c: int in range(first, last + 1):
		out.append(c)
	return out


static func chunk_inputs(chunk: int, total: int) -> Vector2i:
	var first: int = chunk * CHUNK
	var last: int = first + CHUNK
	if total > 0:
		last = mini(last, total - 1)
	return Vector2i(first, maxi(last, first))


static func output_count(inputs: Vector2i, factor: int) -> int:
	return (inputs.y - inputs.x) * factor + 1


static func asked_count(inputs: Vector2i, factor: int) -> int:
	return (inputs.y - inputs.x + 1) * factor


static func key(media_sig: String, chunk: int, factor: int, fps: float, settings: Dictionary) -> String:
	if loose_keys:
		return (media_sig + "|" + str(chunk)).sha1_text().left(24)
	var parts: PackedStringArray = PackedStringArray([
		media_sig,
		str(chunk),
		str(CHUNK),
		str(factor),
		"%.4f" % fps,
		String(settings.get("model", "")),
		"uhd" if bool(settings.get("uhd", false)) else "sd",
		String(settings.get("scene", SCENE_SKIP)),
	])
	return "|".join(parts).sha1_text().left(24)


static func media_sig(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return path
	var size: int = 0
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f != null:
		size = f.get_length()
		f.close()
	return path.simplify_path().to_lower() + "#" + str(size) + "#" + str(FileAccess.get_modified_time(path))


static func locate(src_seconds: float, fps: float, factor: int) -> Dictionary:
	if fps <= 0.0 or factor < 2:
		return {"on_grid": true, "frame": 0, "chunk": -1, "index": -1, "amount": 0.0}
	var p: float = maxf(src_seconds, 0.0) * fps
	var a: int = int(floor(p + EPS))
	var f: float = clampf(p - float(a), 0.0, 1.0)
	var q: int = int(round(f * float(factor)))
	if q <= 0:
		return {"on_grid": true, "frame": a, "chunk": -1, "index": -1, "amount": 0.0}
	if q >= factor:
		return {"on_grid": true, "frame": a + 1, "chunk": -1, "index": -1, "amount": 0.0}
	var c: int = a / CHUNK
	return {"on_grid": false, "frame": a, "chunk": c, "index": (a - c * CHUNK) * factor + q, "amount": float(q) / float(factor)}


static func grid_error(weight: float, factor: int) -> float:
	if factor < 2:
		return INF
	var x: float = weight * float(factor)
	return absf(x - round(x)) / float(factor)


static func pick_factor(weight: float, factors: PackedInt32Array) -> int:
	var best: int = 0
	var best_e: float = INF
	for f: int in factors:
		var e: float = grid_error(weight, f)
		if e < best_e - EPS or (absf(e - best_e) <= EPS and f > best):
			best_e = e
			best = f
	return best


static func frame_seconds(frame: int, fps: float) -> float:
	return (float(frame) + 0.5) / fps


static func scene_diff(a: Image, b: Image) -> float:
	if a == null or b == null or a.is_empty() or b.is_empty():
		return 0.0
	var sa: Image = a.duplicate() as Image
	var sb: Image = b.duplicate() as Image
	sa.convert(Image.FORMAT_L8)
	sb.convert(Image.FORMAT_L8)
	sa.resize(SCENE_W, SCENE_H, Image.INTERPOLATE_BILINEAR)
	sb.resize(SCENE_W, SCENE_H, Image.INTERPOLATE_BILINEAR)
	var da: PackedByteArray = sa.get_data()
	var db: PackedByteArray = sb.get_data()
	var n: int = mini(da.size(), db.size())
	if n == 0:
		return 0.0
	var total: int = 0
	for i: int in n:
		total += absi(int(da[i]) - int(db[i]))
	return float(total) / (255.0 * float(n))


static func is_cut(diff: float) -> bool:
	return diff > SCENE_THRESHOLD


static func blend_images(a: Image, b: Image, amount: float) -> Image:
	var base: Image = a.duplicate() as Image
	base.convert(Image.FORMAT_RGBA8)
	var top: Image = b.duplicate() as Image
	top.convert(Image.FORMAT_RGBA8)
	if top.get_size() != base.get_size():
		top.resize(base.get_width(), base.get_height(), Image.INTERPOLATE_BILINEAR)
	var data: PackedByteArray = top.get_data()
	var alpha: int = clampi(int(round(amount * 255.0)), 0, 255)
	var i: int = 3
	var n: int = data.size()
	while i < n:
		data[i] = alpha
		i += 4
	var over: Image = Image.create_from_data(top.get_width(), top.get_height(), false, Image.FORMAT_RGBA8, data)
	base.blend_rect(over, Rect2i(Vector2i.ZERO, over.get_size()), Vector2i.ZERO)
	base.convert(Image.FORMAT_RGB8)
	return base
