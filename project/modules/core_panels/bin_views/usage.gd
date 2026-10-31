extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")


static func collect(doc: Project, seq_ids: PackedStringArray) -> Dictionary:
	var raw: Dictionary = {}
	if doc == null:
		return raw
	for s: Sequence in doc.sequences:
		if not seq_ids.is_empty() and not seq_ids.has(s.id):
			continue
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if c.media_id.is_empty():
					continue
				var rec: Dictionary = raw.get(c.media_id, {})
				if rec.is_empty():
					rec = {"uses": {}, "spans": PackedVector2Array()}
					raw[c.media_id] = rec
				var use_key: String = s.id + "|" + (c.link_id if not c.link_id.is_empty() else c.id)
				(rec["uses"] as Dictionary)[use_key] = true
				var spans: PackedVector2Array = rec["spans"]
				spans.append(Vector2(c.source_in(), c.source_out()))
				rec["spans"] = spans
	var out: Dictionary = {}
	for id: Variant in raw.keys():
		var r: Dictionary = raw[id]
		var merged: PackedVector2Array = merge(r["spans"])
		out[String(id)] = {"count": (r["uses"] as Dictionary).size(), "spans": merged, "total": total(merged)}
	return out


static func merge(spans: PackedVector2Array) -> PackedVector2Array:
	var list: Array[Vector2] = []
	for v: Vector2 in spans:
		list.append(Vector2(minf(v.x, v.y), maxf(v.x, v.y)))
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out := PackedVector2Array()
	for v: Vector2 in list:
		if out.is_empty() or v.x > out[out.size() - 1].y + 0.0005:
			out.append(v)
		else:
			var last: Vector2 = out[out.size() - 1]
			out[out.size() - 1] = Vector2(last.x, maxf(last.y, v.y))
	return out


static func total(spans: PackedVector2Array) -> float:
	var sum: float = 0.0
	for v: Vector2 in spans:
		sum += maxf(0.0, v.y - v.x)
	return sum


static func fraction(rec: Dictionary, duration: float) -> float:
	if rec.is_empty():
		return 0.0
	if duration <= 0.0:
		return 1.0
	var spans: PackedVector2Array = rec.get("spans", PackedVector2Array())
	var sum: float = 0.0
	for v: Vector2 in spans:
		sum += maxf(0.0, minf(v.y, duration) - maxf(v.x, 0.0))
	return clampf(sum / duration, 0.0, 1.0)


static func status_text(rec: Dictionary, duration: float, timed: bool) -> String:
	var n: int = int(rec.get("count", 0))
	if n <= 0:
		return "Not used"
	var times: String = "Used once" if n == 1 else "Used " + str(n) + " times"
	if not timed:
		return times
	var f: float = fraction(rec, duration)
	if f >= 0.995:
		return times + " · all"
	return times + " · " + str(maxi(1, int(round(f * 100.0)))) + "%"
