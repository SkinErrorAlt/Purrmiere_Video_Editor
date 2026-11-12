extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const NestAudio := preload("res://engine/nest_audio.gd")
const EDGE := 0.0005
const BISECT := 48


static func repeat_times(n: Clip, inner: Sequence, s: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var first: float = NestAudio.parent_time(n, s)
	var win: Vector2 = NestAudio.loop_window_of(n, inner)
	if win == Vector2.ZERO or s < win.x - EDGE or s > win.y + EDGE:
		out.append(first)
		return out
	var forward: bool = n.loop_forward()
	var p: float = win.y - win.x
	var bounds: PackedFloat64Array = PackedFloat64Array([0.0])
	bounds.append_array(n.loop_seams_in(win))
	bounds.append(n.duration)
	for i: int in bounds.size() - 1:
		var ta: float = n.start + bounds[i] + EDGE
		var tb: float = n.start + bounds[i + 1] - EDGE
		if tb <= ta:
			continue
		var ua: float = n.source_time(ta)
		var ub: float = n.source_time(tb)
		var k: int = Clip.cycle_in(n.source_time((ta + tb) * 0.5), win, forward)
		var target: float = (win.x + float(k) * p + (s - win.x)) if forward else (win.y - float(k) * p - (win.y - s))
		if target < minf(ua, ub) - EDGE or target > maxf(ua, ub) + EDGE:
			continue
		var lo: float = ta
		var hi: float = tb
		var rising: bool = ub >= ua
		for _j: int in BISECT:
			var mid: float = (lo + hi) * 0.5
			var u: float = n.source_time(mid)
			if (u < target) == rising:
				lo = mid
			else:
				hi = mid
		out.append((lo + hi) * 0.5)
	if out.is_empty():
		out.append(first)
	return out


static func parent_time(doc: Object, n: Clip, s: float, hint: float) -> float:
	if n == null:
		return s
	var inner: Sequence = doc.call("sequence_by_id", NestAudio.nest_sequence_id(doc, n)) if doc != null else null
	var list: PackedFloat64Array = repeat_times(n, inner, s)
	var best: float = list[0]
	for t: float in list:
		if absf(t - hint) < absf(best - hint):
			best = t
	return best
