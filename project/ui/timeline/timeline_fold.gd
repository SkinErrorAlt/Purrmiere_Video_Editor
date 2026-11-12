extends RefCounted

const SEAM_PX := 8.0
const EPS := 0.000001

static var stats: Dictionary = {"builds": 0}


static func make(spans: Array[Vector2], keep: float) -> Dictionary:
	if spans.is_empty() or keep <= 0.0:
		return {}
	var sorted: Array[Vector2] = spans.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var merged: Array[Vector2] = []
	for sp: Vector2 in sorted:
		if sp.y <= sp.x:
			continue
		if not merged.is_empty() and sp.x <= merged[merged.size() - 1].y + EPS:
			var last: Vector2 = merged[merged.size() - 1]
			merged[merged.size() - 1] = Vector2(last.x, maxf(last.y, sp.y))
		else:
			merged.append(sp)
	var a := PackedFloat64Array()
	var b := PackedFloat64Array()
	var da := PackedFloat64Array()
	var cut := PackedFloat64Array([0.0])
	for sp: Vector2 in merged:
		if sp.y - sp.x <= keep + EPS:
			continue
		var removed: float = cut[cut.size() - 1]
		a.append(sp.x)
		b.append(sp.y)
		da.append(sp.x - removed)
		cut.append(removed + (sp.y - sp.x - keep))
	if a.is_empty():
		return {}
	stats["builds"] = int(stats["builds"]) + 1
	return {"a": a, "b": b, "da": da, "cut": cut, "keep": keep}


static func for_pps(spans: Array[Vector2], pps: float) -> Dictionary:
	return make(spans, SEAM_PX / maxf(pps, 0.000001))


static func shown(fold: Dictionary, t: float) -> float:
	if fold.is_empty():
		return t
	var a: PackedFloat64Array = fold["a"]
	var k: int = a.bsearch(t, true)
	if k == 0:
		return t
	var i: int = k - 1
	var b: PackedFloat64Array = fold["b"]
	var cut: PackedFloat64Array = fold["cut"]
	if t < b[i]:
		return a[i] - cut[i] + (t - a[i]) * float(fold["keep"]) / (b[i] - a[i])
	return t - cut[i + 1]


static func real(fold: Dictionary, v: float) -> float:
	if fold.is_empty():
		return v
	var da: PackedFloat64Array = fold["da"]
	var k: int = da.bsearch(v, true)
	if k == 0:
		return v
	var i: int = k - 1
	var keep: float = float(fold["keep"])
	var a: PackedFloat64Array = fold["a"]
	var b: PackedFloat64Array = fold["b"]
	if v < da[i] + keep:
		return a[i] + (v - da[i]) * (b[i] - a[i]) / keep
	var cut: PackedFloat64Array = fold["cut"]
	return v + cut[i + 1]


static func x_of(fold: Dictionary, t: float, header_w: float, pps: float, scroll_x: float) -> float:
	if fold.is_empty():
		return header_w + t * pps - scroll_x
	return header_w + shown(fold, t) * pps - scroll_x


static func t_of(fold: Dictionary, x: float, header_w: float, pps: float, scroll_x: float) -> float:
	if fold.is_empty():
		return (x - header_w + scroll_x) / pps
	return real(fold, (x - header_w + scroll_x) / pps)


static func moved(fold: Dictionary, t: float, dx: float, pps: float) -> float:
	if fold.is_empty():
		return t + dx / pps
	return real(fold, shown(fold, t) + dx / pps)


static func px_between(fold: Dictionary, t0: float, t1: float, pps: float) -> float:
	if fold.is_empty():
		return (t1 - t0) * pps
	return (shown(fold, t1) - shown(fold, t0)) * pps


static func count(fold: Dictionary) -> int:
	if fold.is_empty():
		return 0
	return (fold["a"] as PackedFloat64Array).size()


static func seams(fold: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if fold.is_empty():
		return out
	var a: PackedFloat64Array = fold["a"]
	var b: PackedFloat64Array = fold["b"]
	for i: int in a.size():
		out.append(Vector2(a[i], b[i]))
	return out


static func pieces(fold: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if fold.is_empty():
		out.append({"lo": 0.0, "hi": INF, "cut": 0.0})
		return out
	var a: PackedFloat64Array = fold["a"]
	var b: PackedFloat64Array = fold["b"]
	var cut: PackedFloat64Array = fold["cut"]
	var lo: float = 0.0
	for i: int in a.size():
		out.append({"lo": lo, "hi": a[i], "cut": cut[i]})
		lo = b[i]
	out.append({"lo": lo, "hi": INF, "cut": cut[a.size()]})
	return out


static func hidden_time(fold: Dictionary) -> float:
	if fold.is_empty():
		return 0.0
	var cut: PackedFloat64Array = fold["cut"]
	return cut[cut.size() - 1]
