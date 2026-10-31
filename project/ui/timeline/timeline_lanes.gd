extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const NEST_SCALE := 0.7
const NEST_MAX_H := 240.0
const NAME_ROW := 14.0
const LANE_GAP := 1.0
const VIEW_KEY_PINNED_ORDER := "pinned_order"
const TIER_RATES: Array = [100.0, 12.5, 1.5625]
const TIER_MAX_BPP := 4.0
const CHUNK_SECONDS := 120.0


static func default_height(kind: String) -> float:
	return float(Tk.px(Tk.sz("track_h_video") if kind == "video" else Tk.sz("track_h_audio")))


static func clamp_height(h: float) -> float:
	return clampf(h, float(Tk.px(Tk.sz("track_h_min"))), float(Tk.px(Tk.sz("track_h_max"))))


static func nest_rows_height(c: Clip, doc: Project) -> float:
	if doc == null or c == null or not c.is_nest() or not bool(c.nest.get("see_inside", false)):
		return 0.0
	var s: Sequence = doc.sequence_by_id(c.sequence_id)
	if s == null:
		return 0.0
	var total: float = 0.0
	for t: Track in s.all_tracks():
		if t.hidden:
			continue
		total += default_height(t.kind) * NEST_SCALE * 0.5
	return minf(total, float(Tk.px(NEST_MAX_H)))


static func track_height(t: Track, doc: Project, t0: float, t1: float) -> float:
	var base: float = clamp_height(float(Tk.px(t.height)) if t.height > 0.0 else default_height(t.kind))
	if t.kind != "video":
		return base
	var need: float = 0.0
	for c: Clip in t.clips_in_range(t0, t1):
		if c.is_nest() and bool(c.nest.get("see_inside", false)):
			need = maxf(need, nest_rows_height(c, doc) + float(Tk.px(NAME_ROW)) + 8.0)
	return maxf(base, need)


static func pinned_order(doc: Project, seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null:
		return out
	var raw: Variant = doc.view.get(VIEW_KEY_PINNED_ORDER, {})
	if typeof(raw) == TYPE_DICTIONARY:
		var per: Variant = (raw as Dictionary).get(seq.id, [])
		if typeof(per) == TYPE_ARRAY:
			for v: Variant in per:
				out.append(String(v))
	return out


static func set_pinned_order(doc: Project, seq: Sequence, ids: PackedStringArray) -> void:
	if doc == null or seq == null:
		return
	var raw: Variant = doc.view.get(VIEW_KEY_PINNED_ORDER, {})
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	d[seq.id] = Array(ids)
	doc.view[VIEW_KEY_PINNED_ORDER] = d


static func lane(t: Track, y: float, h: float, set_name: String) -> Dictionary:
	return {"track": t, "y": y, "h": h, "kind": t.kind, "set": set_name, "nest": false, "owner": null, "sub_seq": null, "sub_track": null}


static func build(doc: Project, seq: Sequence, t0: float, t1: float) -> Dictionary:
	var main: Array[Dictionary] = []
	var band: Array[Dictionary] = []
	var out: Dictionary = {"main": main, "band": band, "main_h": 0.0, "band_h": 0.0, "hidden": 0, "nested_audio_y": -1.0}
	if seq == null:
		return out
	var y: float = 0.0
	var hidden: int = 0
	var pinned: Array[Track] = []
	for i: int in range(seq.video_tracks.size() - 1, -1, -1):
		var t: Track = seq.video_tracks[i]
		if t.hidden:
			hidden += 1
			continue
		if t.pinned:
			pinned.append(t)
			continue
		var h: float = track_height(t, doc, t0, t1)
		main.append(lane(t, y, h, "main"))
		y += h + LANE_GAP
	for t: Track in seq.audio_tracks:
		if t.hidden:
			hidden += 1
			continue
		if t.pinned:
			pinned.append(t)
			continue
		var h: float = track_height(t, doc, t0, t1)
		main.append(lane(t, y, h, "main"))
		y += h + LANE_GAP
	var nested_y: float = -1.0
	if doc != null:
		for t: Track in seq.video_tracks:
			if t.hidden:
				continue
			for c: Clip in t.clips_in_range(t0, t1):
				if not c.is_nest() or not bool(c.nest.get("show_audio_below", false)):
					continue
				var sub: Sequence = doc.sequence_by_id(c.sequence_id)
				if sub == null:
					continue
				for st: Track in sub.audio_tracks:
					if st.hidden:
						continue
					if nested_y < 0.0:
						nested_y = y
						y += float(Tk.px(NAME_ROW)) + 2.0
					var h: float = clamp_height(default_height("audio") * NEST_SCALE)
					var l: Dictionary = lane(st, y, h, "main")
					l["nest"] = true
					l["owner"] = c
					l["sub_seq"] = sub
					l["sub_track"] = st
					main.append(l)
					y += h + LANE_GAP
	out["main_h"] = y
	out["hidden"] = hidden
	out["nested_audio_y"] = nested_y
	var order: PackedStringArray = pinned_order(doc, seq)
	var ordered: Array[Track] = []
	for id: String in order:
		for t: Track in pinned:
			if t.id == id and not (t in ordered):
				ordered.append(t)
	for t: Track in pinned:
		if not (t in ordered):
			ordered.append(t)
	var by: float = 0.0
	for t: Track in ordered:
		var h: float = track_height(t, doc, t0, t1)
		band.append(lane(t, by, h, "band"))
		by += h + LANE_GAP
	out["band_h"] = by
	return out


static func lane_at(lanes: Array[Dictionary], content_y: float) -> Dictionary:
	for l: Dictionary in lanes:
		var y: float = float(l["y"])
		if content_y >= y and content_y < y + float(l["h"]) + LANE_GAP:
			return l
	return {}


static func lane_for_track(lanes: Dictionary, track_id: String) -> Dictionary:
	for key: String in ["main", "band"]:
		for l: Dictionary in lanes[key]:
			var t: Track = l["track"]
			if t.id == track_id and not bool(l["nest"]):
				return l
	return {}


static func visible_range(t: Track, t0: float, t1: float) -> Vector2i:
	var i: int = t.index_of_first_visible(t0)
	var j: int = t.index_of_last_starting_before(t1)
	return Vector2i(i, j)


static func tier_for_pps(pps: float) -> int:
	for tier: int in TIER_RATES.size():
		var bpp: float = float(TIER_RATES[tier]) / maxf(pps, 0.000001)
		if bpp <= TIER_MAX_BPP:
			return tier
	return TIER_RATES.size() - 1


static func tier_rate(tier: int) -> float:
	return float(TIER_RATES[clampi(tier, 0, TIER_RATES.size() - 1)])


static func nice_tick(pps: float, min_px: float) -> float:
	var steps: Array = [0.0333, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0, 7200.0, 14400.0, 43200.0, 86400.0]
	for s: float in steps:
		if s * pps >= min_px:
			return s
	return 86400.0 * ceil(min_px / (pps * 86400.0))


static func ruler_label(t: float, fps: float, pps: float) -> String:
	var total: int = int(floor(t + 0.0001))
	var hh: int = total / 3600
	var mm: int = (total / 60) % 60
	var ss: int = total % 60
	if pps >= 90.0 and fps > 0.0:
		var ff: int = int(round((t - floor(t)) * fps)) % maxi(1, int(round(fps)))
		return "%02d:%02d:%02d" % [mm, ss, ff] if hh == 0 else "%d:%02d:%02d:%02d" % [hh, mm, ss, ff]
	if hh > 0:
		return "%d:%02d:%02d" % [hh, mm, ss]
	return "%02d:%02d" % [mm, ss]
