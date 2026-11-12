extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const SCAN_MAX := 400

static var stats: Dictionary = {"scans": 0, "times": 0}


static func time_of(c: Clip, s: Sequence, frame: int) -> float:
	return c.start + float(frame) / maxf(s.fps, 1.0)


static func spans_of(c: Clip, s: Sequence) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if c == null or s == null:
		return out
	for m: Dictionary in c.masks:
		if not ObjectMask.is_object(m) or not bool(m.get("enabled", true)):
			continue
		var frames: PackedInt32Array = ObjectMask.key_frames(m)
		var lo: int = frames[0] if not frames.is_empty() else -1
		var hi: int = frames[frames.size() - 1] if not frames.is_empty() else -1
		var tracked: Vector2i = ObjectMatte.span_of_mask(m)
		if tracked.x >= 0:
			lo = tracked.x if lo < 0 else mini(lo, tracked.x)
			hi = maxi(hi, tracked.y)
		if lo < 0:
			continue
		var a: float = clampf(time_of(c, s, lo), c.start, c.end())
		var b: float = clampf(time_of(c, s, hi), c.start, c.end())
		out.append(a)
		if absf(b - a) > 0.0001:
			out.append(b)
	return out


static func snap_times(canvas: Control, s: Sequence, t0: float, t1: float, excluded: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if s == null or canvas == null:
		return out
	stats["scans"] = int(stats["scans"]) + 1
	for tr: Track in s.picture_tracks():
		if tr.hidden:
			continue
		var i: int = tr.index_of_first_visible(t0)
		var n: int = 0
		while i < tr.clips.size() and tr.clips[i].start < t1 and n < SCAN_MAX:
			var c: Clip = tr.clips[i]
			i += 1
			n += 1
			if c.masks.is_empty() or excluded.has(c.id):
				continue
			for at: float in spans_of(c, s):
				if at >= t0 and at <= t1:
					out.append(at)
	stats["times"] = int(stats["times"]) + out.size()
	return out
