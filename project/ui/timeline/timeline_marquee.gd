extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const MoveRule := preload("res://doc/move_rule.gd")
const MAIN := "main"
const BAND := "band"


static func set_rect(g: Dictionary, set_name: String) -> Rect2:
	return g["band_rect"] if set_name == BAND else g["main_rect"]


static func set_scroll(g: Dictionary, set_name: String) -> float:
	return float(g["band_scroll_y"]) if set_name == BAND else float(g["scroll_y"])


static func lane_x(g: Dictionary, x: float) -> float:
	return clampf(x, float(g["header_w"]), maxf(float(g["width"]), float(g["header_w"])))


static func anchor_at(g: Dictionary, pos: Vector2, hit: Dictionary, mods: Dictionary) -> Dictionary:
	var set_name: String = BAND if String(hit.get("set", "")) == BAND else MAIN
	var r: Rect2 = set_rect(g, set_name)
	return {"t": Hit.t_of(g, lane_x(g, pos.x)), "set": set_name, "cy": pos.y - r.position.y + set_scroll(g, set_name), "add": bool(mods.get("shift", false))}


static func anchor_screen(g: Dictionary, anchor: Dictionary) -> Vector2:
	var set_name: String = String(anchor.get("set", MAIN))
	var r: Rect2 = set_rect(g, set_name)
	return Vector2(Hit.x_of(g, float(anchor.get("t", 0.0))), r.position.y + float(anchor.get("cy", 0.0)) - set_scroll(g, set_name))


static func spans(g: Dictionary, anchor: Dictionary, pos: Vector2) -> Dictionary:
	var a_set: String = String(anchor.get("set", MAIN))
	var o_set: String = MAIN if a_set == BAND else BAND
	var a_rect: Rect2 = set_rect(g, a_set)
	var o_rect: Rect2 = set_rect(g, o_set)
	var ta: float = float(anchor.get("t", 0.0))
	var tb: float = Hit.t_of(g, lane_x(g, pos.x))
	var a_cy: float = float(anchor.get("cy", 0.0))
	var b_cy: float = clampf(pos.y, a_rect.position.y, a_rect.end.y) - a_rect.position.y + set_scroll(g, a_set)
	var sets: Dictionary = {a_set: Vector2(minf(a_cy, b_cy), maxf(a_cy, b_cy))}
	if o_rect.size.y > 0.0 and a_rect.size.y > 0.0:
		var o_scroll: float = set_scroll(g, o_set)
		if o_rect.position.y >= a_rect.end.y - 0.5 and pos.y > o_rect.position.y:
			sets[o_set] = Vector2(o_scroll, minf(pos.y, o_rect.end.y) - o_rect.position.y + o_scroll)
		elif o_rect.end.y <= a_rect.position.y + 0.5 and pos.y < o_rect.end.y:
			sets[o_set] = Vector2(maxf(pos.y, o_rect.position.y) - o_rect.position.y + o_scroll, o_rect.size.y + o_scroll)
	return {"t0": minf(ta, tb), "t1": maxf(ta, tb), "sets": sets}


static func screen_rect(g: Dictionary, anchor: Dictionary, pos: Vector2) -> Rect2:
	var sp: Dictionary = spans(g, anchor, pos)
	var x0: float = lane_x(g, Hit.x_of(g, float(sp["t0"])))
	var x1: float = lane_x(g, Hit.x_of(g, float(sp["t1"])))
	var y_lo: float = INF
	var y_hi: float = -INF
	var sets: Dictionary = sp["sets"]
	for set_name: String in sets.keys():
		var r: Rect2 = set_rect(g, set_name)
		var sc: float = set_scroll(g, set_name)
		var span: Vector2 = sets[set_name]
		y_lo = minf(y_lo, clampf(r.position.y + span.x - sc, r.position.y, r.end.y))
		y_hi = maxf(y_hi, clampf(r.position.y + span.y - sc, r.position.y, r.end.y))
	if y_lo == INF:
		return Rect2(x0, pos.y, x1 - x0, 0.0)
	return Rect2(x0, y_lo, x1 - x0, y_hi - y_lo)


static func clips(g: Dictionary, lanes: Dictionary, anchor: Dictionary, pos: Vector2) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var sp: Dictionary = spans(g, anchor, pos)
	var t0: float = float(sp["t0"])
	var t1: float = float(sp["t1"])
	var sets: Dictionary = sp["sets"]
	for set_name: String in sets.keys():
		var span: Vector2 = sets[set_name]
		for l: Dictionary in lanes.get(set_name, []):
			if bool(l["nest"]):
				continue
			var y: float = float(l["y"])
			if y + float(l["h"]) < span.x or y > span.y:
				continue
			var tr: Track = l["track"]
			for c: Clip in tr.clips_in_range(t0, t1):
				if c.end() > t0 and c.start < t1 and not out.has(c.id):
					out.append(c.id)
	return out


static func selection(host: Control, anchor: Dictionary, pos: Vector2) -> PackedStringArray:
	var s: Sequence = host.call("seq")
	if s == null:
		return PackedStringArray()
	var found: PackedStringArray = clips(host.call("geometry"), host.call("lanes"), anchor, pos)
	return MoveRule.pick(s, found) if bool(host.get("linked_selection")) else found


static func autoscroll_y(g: Dictionary, pos: Vector2, band: float, most: float) -> Dictionary:
	var main_rect: Rect2 = g["main_rect"]
	var band_rect: Rect2 = g["band_rect"]
	var top_set: String = MAIN
	var bottom_set: String = MAIN
	if band_rect.size.y > 0.0:
		if band_rect.position.y < main_rect.position.y:
			top_set = BAND
		else:
			bottom_set = BAND
	var top: Rect2 = set_rect(g, top_set)
	var bottom: Rect2 = set_rect(g, bottom_set)
	if pos.y < top.position.y + band:
		return {"set": top_set, "dy": -minf(240.0 + 6.0 * (top.position.y + band - pos.y), most)}
	if pos.y > bottom.end.y - band:
		return {"set": bottom_set, "dy": minf(240.0 + 6.0 * (pos.y - bottom.end.y + band), most)}
	return {"set": MAIN, "dy": 0.0}
