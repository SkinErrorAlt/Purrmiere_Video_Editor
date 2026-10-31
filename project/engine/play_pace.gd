extends RefCounted

const Clip := preload("res://doc/clip.gd")
const FullQuality := preload("res://engine/full_quality.gd")
const SAME_FRAME_RATE := 1.5
const FAST_RATE := 1.02
const PROBE := 0.004
const PLAN_SECONDS := 1.0
const PLAN_SOURCE_MAX := 2.5
const PLAN_EVERY_MS := 120
const GRID_EPS := 0.0001
const TAP_MAX_FRAMES := 2.0
const BACK_LIMIT := 0.5

static var transport_rate: float = 1.0
static var playing: bool = false
static var enabled: bool = true
static var plans_sent: int = 0
static var plans_cleared: int = 0


static func clip_rate(c: Clip, t: float) -> float:
	if c == null:
		return 1.0
	return (c.source_time(t + PROBE) - c.source_time(t - PROBE)) / (2.0 * PROBE)


static func fast(c: Clip, t: float) -> bool:
	if not enabled or c == null or transport_rate <= 0.0:
		return false
	return clip_rate(c, t) * transport_rate > FAST_RATE


static func grid_time(c: Clip, t: float, seq_fps: float) -> float:
	if c == null or seq_fps <= 0.0:
		return t
	var g: float = floor(t * seq_fps + GRID_EPS) / seq_fps
	return clampf(g, c.start, t)


static func shown_time(c: Clip, t: float, seq_fps: float, playing: bool) -> float:
	if not playing or not fast(c, t):
		return t
	return grid_time(c, t, seq_fps)


static func plan_times(c: Clip, t: float, seq_fps: float, source_of: Callable, offsets: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if c == null or seq_fps <= 0.0:
		return out
	var n0: int = int(floor(t * seq_fps + GRID_EPS))
	var first: float = -1.0
	var count: int = int(ceil(PLAN_SECONDS * seq_fps))
	for k: int in count + 1:
		var tk: float = float(n0 + k) / seq_fps
		if tk >= c.end():
			break
		var s: float = float(source_of.call(maxf(tk, c.start)))
		if first < 0.0:
			first = s
		elif s - first > PLAN_SOURCE_MAX:
			break
		out.append(s)
		for o: float in offsets:
			if s - o >= 0.0:
				out.append(s - o)
	return out


static func view_offset(c: Clip, offset: float, t: float, media_fps: float) -> float:
	var fps: float = media_fps if media_fps > 0.0 else 30.0
	if not enabled or not playing or c == null or absf(offset) * fps >= 1.0:
		return offset
	if clip_rate(c, t) * transport_rate < SAME_FRAME_RATE or FullQuality.is_on():
		return offset
	return 0.0


static func tap_fits(offset: float, media_fps: float) -> bool:
	var fps: float = media_fps if media_fps > 0.0 else 30.0
	return absf(offset) * fps <= TAP_MAX_FRAMES
