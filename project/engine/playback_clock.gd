extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const Clip := preload("res://doc/clip.gd")
const LIMIT_EFFECT_ID := "time_fps_limit"
const COMPRESSION_EFFECT_ID := "compression"
const OFF_ABOVE := 240.0
const SNAP_EPS := 0.001
const GRID_EPS := 0.000001
const PICK_KEYS: PackedStringArray = ["view", "view_mode", "grid", "layout", "view2", "group"]

static var _plant_raw_local: bool = false
static var _plant_jump_back: bool = false
static var _phases: Dictionary = {}
const PHASE_STEPS_PER_SECOND := 480.0
const PHASE_CACHE_MAX := 64
const MODE_SOURCE := 0
const MODE_TIMELINE := 1


static func hold(src_t: float, fps: float, src_fps: float = 0.0) -> float:
	if fps <= 0.0 or fps >= OFF_ABOVE:
		return src_t
	if src_t <= 0.0:
		return 0.0
	var held: float = floor(src_t * fps) / fps
	if src_fps <= 0.0:
		return held
	return floor(held * src_fps + SNAP_EPS) / src_fps


static func step_of(fps: float) -> float:
	return 1.0 / clampf(fps, 1.0, OFF_ABOVE)


static func limiters_of(clip: Clip, local_t: float, fps: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if clip == null:
		return out
	for e: Dictionary in clip.effects:
		if not bool(e.get("enabled", true)):
			continue
		var id: String = str(e.get("id", ""))
		var params: Dictionary = e.get("params", {})
		if id == LIMIT_EFFECT_ID:
			var rate: float = 12.0
			if params.get("fps") is Dictionary:
				rate = AnimProp.evaluate_float(params["fps"], clip.fx_time(e, "fps", local_t), clip.duration, fps)
			var mode: int = MODE_SOURCE
			if params.get("mode") is Dictionary:
				mode = int(round(AnimProp.evaluate_float(params["mode"], clip.fx_time(e, "mode", local_t), clip.duration, fps)))
			var lim: Dictionary = {"fps": rate, "mode": mode}
			if smooths(e):
				lim["held_local"] = held_local(clip, e, local_t, fps)
			out.append(lim)
		elif id == COMPRESSION_EFFECT_ID:
			var lim: float = 0.0
			if params.get("fps_limit") is Dictionary:
				lim = AnimProp.evaluate_float(params["fps_limit"], clip.fx_time(e, "fps_limit", local_t), clip.duration, fps)
			if lim > 0.0:
				out.append({"fps": lim, "mode": MODE_SOURCE})
	return out


static func lowest_rate(list: Array[Dictionary], mode: int) -> float:
	var lowest: float = 0.0
	for l: Dictionary in list:
		var r: float = float(l["fps"])
		if int(l["mode"]) != mode or r <= 0.0 or r >= OFF_ABOVE:
			continue
		if lowest <= 0.0 or r < lowest:
			lowest = r
	return lowest


static func smooths(e: Dictionary) -> bool:
	var params: Dictionary = e.get("params", {})
	if not (params.get("fps") is Dictionary) or not AnimProp.is_animated(params["fps"]):
		return false
	var on: Variant = params.get("smooth", null)
	if on is Dictionary:
		return bool(AnimProp.static_value(on))
	if on is bool:
		return bool(on)
	return true


static func _phase_table(clip: Clip, e: Dictionary, seq_fps: float) -> Dictionary:
	var params: Dictionary = e.get("params", {})
	var sig: String = clip.id + "|" + str(e.get("uid", "")) + "|" + str(clip.duration) + "|" + str(seq_fps) + "|" + var_to_str(params.get("fps")) + "|" + var_to_str(e.get("time", null))
	var cached: Variant = _phases.get(sig, null)
	if cached is Dictionary:
		return cached
	var dt: float = 1.0 / PHASE_STEPS_PER_SECOND
	var n: int = int(ceil(maxf(clip.duration, 0.0) / dt)) + 2
	var phase: PackedFloat64Array = PackedFloat64Array()
	phase.resize(n)
	var acc: float = 0.0
	var prev: float = clampf(AnimProp.evaluate_float(params["fps"], clip.fx_time(e, "fps", 0.0), clip.duration, seq_fps), 0.0, OFF_ABOVE)
	phase[0] = 0.0
	for i: int in range(1, n):
		var r: float = clampf(AnimProp.evaluate_float(params["fps"], clip.fx_time(e, "fps", float(i) * dt), clip.duration, seq_fps), 0.0, OFF_ABOVE)
		acc += (prev + r) * 0.5 * dt
		phase[i] = acc
		prev = r
	if _phases.size() >= PHASE_CACHE_MAX:
		_phases.clear()
	var table: Dictionary = {"dt": dt, "phase": phase}
	_phases[sig] = table
	return table


static func held_local(clip: Clip, e: Dictionary, local_t: float, seq_fps: float) -> float:
	if local_t <= 0.0:
		return 0.0
	var table: Dictionary = _phase_table(clip, e, seq_fps)
	var dt: float = float(table["dt"])
	var phase: PackedFloat64Array = table["phase"]
	var n: int = phase.size()
	var at: float = local_t / dt
	var i: int = clampi(int(floor(at)), 0, n - 2)
	var now: float = lerpf(phase[i], phase[i + 1], clampf(at - float(i), 0.0, 1.0))
	if _plant_jump_back:
		return local_t
	var target: float = floor(now + SNAP_EPS)
	if target <= 0.0:
		return 0.0
	var lo: int = 0
	var hi: int = i + 1
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if phase[mid] < target:
			lo = mid + 1
		else:
			hi = mid
	if lo <= 0:
		return 0.0
	var a: float = phase[lo - 1]
	var b: float = phase[lo]
	var u: float = 0.0 if b <= a else clampf((target - a) / (b - a), 0.0, 1.0)
	return minf((float(lo - 1) + u) * dt, local_t)


static func _smooth_held(lims: Array[Dictionary], mode: int) -> float:
	var best: float = -1.0
	var lowest: float = lowest_rate(lims, mode)
	for l: Dictionary in lims:
		if int(l["mode"]) != mode or not l.has("held_local"):
			continue
		if float(l["fps"]) <= lowest + 0.000001:
			best = float(l["held_local"])
	return best


static func source_time_for(clip: Clip, t: float, media_fps: float, seq_fps: float) -> float:
	if clip == null:
		return 0.0
	var local_t: float = t - clip.start
	var lims: Array[Dictionary] = limiters_of(clip, local_t, seq_fps)
	var held_tl: float = _smooth_held(lims, MODE_TIMELINE)
	var held_src: float = _smooth_held(lims, MODE_SOURCE)
	if held_tl >= 0.0 or held_src >= 0.0:
		var at_local: float = held_tl if held_tl >= 0.0 else held_src
		var src_s: float = clip.source_time(clip.start + at_local)
		if held_src >= 0.0 and media_fps > 0.0:
			src_s = floor(src_s * media_fps + SNAP_EPS) / media_fps
		return src_s
	var timeline_rate: float = lowest_rate(lims, MODE_TIMELINE)
	var tt: float = t
	if timeline_rate > 0.0:
		tt = clip.start + hold(local_t, timeline_rate, 0.0)
	var src: float = clip.source_time(tt)
	var source_rate: float = lowest_rate(lims, MODE_SOURCE)
	if source_rate > 0.0:
		src = hold(src, source_rate, media_fps)
	return src


static func is_limited(clip: Clip) -> bool:
	if clip == null:
		return false
	for e: Dictionary in clip.effects:
		if not bool(e.get("enabled", true)):
			continue
		var id: String = str(e.get("id", ""))
		if id == LIMIT_EFFECT_ID:
			return true
		if id == COMPRESSION_EFFECT_ID:
			var params: Dictionary = e.get("params", {})
			if params.get("fps_limit") is Dictionary and AnimProp.evaluate_float(params["fps_limit"], clip.fx_time(e, "fps_limit", 0.0), clip.duration) > 0.0:
				return true
	return false


static func frame_index(t: float, fps: float) -> int:
	if fps <= 0.0:
		return 0
	return int(floor(t * fps + SNAP_EPS))


static func frame_time(index: int, fps: float) -> float:
	if fps <= 0.0:
		return 0.0
	return float(index) / fps


static func clip_local(t: float, start: float, fps: float) -> float:
	var local: float = t - start
	if fps <= 0.0 or _plant_raw_local:
		return local
	var on_grid: float = round(local * fps) / fps
	return on_grid if absf(local - on_grid) < GRID_EPS else local


class Follower:
	extends RefCounted

	const SETTLE_SECONDS := 0.5
	const MAX_SLEW := 0.01
	const RESYNC_SECONDS := 0.05
	const JUMP_BACK_SECONDS := 0.5
	const HOLD_SECONDS := 0.025
	const REACH_SECONDS := 0.1
	const PACE_BAND := 0.3
	const PACE_EASE := 0.02
	const ERROR_SECONDS := 0.5
	const PACE_WARM := 20

	var shown: float = 0.0
	var rate: float = 1.0
	var wall: float = 0.0
	var pace: float = 0.0
	var pace_count: int = 0
	var error_avg: float = 0.0
	var anchor_clock: float = 0.0
	var anchor_wall: float = 0.0
	var last_clock: float = 0.0
	var resyncs: int = 0
	var holds: int = 0

	func reset(t: float, now: float, r: float) -> void:
		shown = t
		rate = r
		wall = now
		anchor_clock = t
		anchor_wall = now
		last_clock = t
		error_avg = 0.0

	func goal(now: float) -> float:
		return anchor_clock + clampf(now - anchor_wall, 0.0, REACH_SECONDS) * rate

	func frame_step(gap: float) -> float:
		if pace_count > 0 and absf(gap - pace) > pace * PACE_BAND:
			if pace_count < PACE_WARM:
				pace_count = 0
			return gap
		pace_count += 1
		pace += (gap - pace) * maxf(PACE_EASE, 1.0 / float(pace_count))
		return pace if pace_count >= PACE_WARM else gap

	func step(clock: float, now: float) -> float:
		var gap: float = maxf(now - wall, 0.0)
		var dt: float = frame_step(gap)
		wall = now
		if absf(clock - last_clock) > 0.0000001:
			anchor_clock = clock
			anchor_wall = now - gap * 0.5
			last_clock = clock
		var dir: float = -1.0 if rate < 0.0 else 1.0
		var aim: float = goal(now)
		var next: float = shown + dt * rate
		var behind: float = (aim - next) * dir
		if behind > RESYNC_SECONDS or behind < -JUMP_BACK_SECONDS:
			resyncs += 1
			shown = aim
			return shown
		if behind < -HOLD_SECONDS:
			holds += 1
			return shown
		error_avg += (behind - error_avg) * clampf(dt / ERROR_SECONDS, 0.0, 1.0)
		var room: float = MAX_SLEW * dt * absf(rate)
		next += clampf(error_avg * clampf(dt / SETTLE_SECONDS, 0.0, 1.0), -room, room) * dir
		if (next - shown) * dir < 0.0:
			next = shown
		shown = next
		return shown
