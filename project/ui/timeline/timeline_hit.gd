extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Marker := preload("res://doc/marker.gd")
const Follow := preload("res://doc/marker_follow.gd")
const Layers := preload("res://doc/marker_layers.gd")
const LaneKind := preload("res://ui/timeline/marker_lane_kind.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const Tracks := preload("res://ui/timeline/timeline_tracks.gd")
const SpeedBand := preload("res://ui/timeline/timeline_speed_band.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Fold := preload("res://ui/timeline/timeline_fold.gd")
const NO_FOLD: Dictionary = {}
const EDGE_REACH := 6.0
const MARKER_REACH := 6.0
const MARKER_BAND := 12.0
const MARKER_BAR := 5.0
const PLAYHEAD_REACH := 4.0
const LEVEL_REACH := 5.0
const TRACK_GRIP := 5.0
const HEADER_EDGE := 4.0
const FadeTools := preload("res://doc/commands/edit_tools.gd")
const FADE_HANDLE := 7.0
const FADE_BAND := 9.0
const FADE_REACH := 6.0
const FADE_MIN_CLIP_W := 28.0


static func empty() -> Dictionary:
	return {"zone": "", "set": "", "lane": {}, "track": null, "clip": null, "edge": "", "t": 0.0, "x": 0.0, "y": 0.0, "button": "", "transition": false, "tr_edge": "", "tr_side": "", "free": {}, "free_edge": "", "level": false, "grip": false, "nest": false, "playhead": false, "marker": null, "marker_edge": "", "marker_band": false, "lane_y": 0.0, "fade": "", "layer": ""}


static func row_at(geom: Dictionary, y: float) -> Dictionary:
	for r: Dictionary in geom.get("marker_rows", []):
		if y >= float(r["y"]) and y < float(r["y"]) + float(r["h"]):
			return r
	return {}


static func row_span(geom: Dictionary, y: float) -> Vector2:
	var rh: float = float(geom["ruler_h"])
	if y < rh:
		return Vector2(0.0, rh)
	var r: Dictionary = row_at(geom, y)
	if r.is_empty():
		return Vector2(0.0, rh)
	return Vector2(float(r["y"]), float(r["y"]) + float(r["h"]))


static func _open_lane(seq: Sequence, lane: String) -> bool:
	return Layers.shown(seq, lane) and not Layers.locked(seq, lane)


static func marker_at(geom: Dictionary, seq: Sequence, pos: Vector2, row: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"marker": null, "edge": ""}
	if seq == null:
		return out
	var want: String = String(row.get("id", Layers.RULER))
	if not _open_lane(seq, want):
		return out
	var idx: Dictionary = Layers.index(seq)
	var rh: float = float(geom["ruler_h"])
	var in_lane: bool = not row.is_empty()
	var best: Marker = null
	var best_edge: String = ""
	var best_d: float = MARKER_REACH + 1.0
	var body: Marker = null
	for m: Marker in seq.markers:
		if Layers.lane_in(idx, m) != want:
			continue
		var t0: float = Follow.resolved_time(seq, m) if m.follows() else m.time
		var mx: float = x_of(geom, t0)
		var mex: float = x_of(geom, t0 + m.duration)
		var in_band: bool = in_lane or pos.y < MARKER_BAND
		var in_bar: bool = m.duration > 0.0 and (in_lane or pos.y >= rh - MARKER_BAR)
		if not in_band and not in_bar:
			continue
		var head_d: float = absf(pos.x - mx)
		var tail_d: float = absf(pos.x - mex)
		if m.duration > 0.0 and tail_d <= MARKER_REACH and tail_d < best_d:
			best_d = tail_d
			best = m
			best_edge = "tail"
		if head_d <= MARKER_REACH and head_d < best_d:
			best_d = head_d
			best = m
			best_edge = "head" if m.duration > 0.0 else "tail"
		if body == null and m.duration > 0.0 and pos.x >= mx and pos.x <= mex:
			body = m
	if best != null:
		out["marker"] = best
		out["edge"] = best_edge
		return out
	out["marker"] = body
	return out


static func markers_in(geom: Dictionary, seq: Sequence, r: Rect2) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var rh: float = float(geom["ruler_h"])
	var lanes_hit: Dictionary = {}
	if r.position.y < rh and r.end.y > 0.0 and _open_lane(seq, Layers.RULER):
		lanes_hit[Layers.RULER] = true
	for row: Dictionary in geom.get("marker_rows", []):
		var y0: float = float(row["y"])
		if r.position.y < y0 + float(row["h"]) and r.end.y > y0 and _open_lane(seq, String(row["id"])):
			lanes_hit[String(row["id"])] = true
	if lanes_hit.is_empty():
		return out
	var idx: Dictionary = Layers.index(seq)
	for m: Marker in seq.markers:
		if not lanes_hit.has(Layers.lane_in(idx, m)):
			continue
		var t0: float = Follow.resolved_time(seq, m) if m.follows() else m.time
		var mx: float = x_of(geom, t0)
		var mex: float = x_of(geom, t0 + m.duration)
		if mex >= r.position.x - MARKER_REACH and mx <= r.end.x + MARKER_REACH:
			out.append(m.id)
	return out


static func fade_handle_x(x0: float, x1: float, fade_px: float, head: bool) -> float:
	var inset: float = FADE_HANDLE * 0.5 + 1.0
	if head:
		return clampf(x0 + fade_px, x0 + inset, x1 - inset)
	return clampf(x1 - fade_px, x0 + inset, x1 - inset)


static func fade_side_at(c: Clip, track_kind: String, x0: float, x1: float, clip_top: float, pps: float, pos: Vector2) -> String:
	if c == null or x1 - x0 < FADE_MIN_CLIP_W:
		return ""
	if pos.y < clip_top - 1.0 or pos.y > clip_top + FADE_BAND:
		return ""
	var xi: float = fade_handle_x(x0, x1, FadeTools.fade_value(c, track_kind, "in") * pps, true)
	var xo: float = fade_handle_x(x0, x1, FadeTools.fade_value(c, track_kind, "out") * pps, false)
	var di: float = absf(pos.x - xi)
	var d_out: float = absf(pos.x - xo)
	if di <= FADE_REACH and di <= d_out:
		return "in"
	if d_out <= FADE_REACH:
		return "out"
	return ""


static func transition_spot(tr: Track, t: float) -> Dictionary:
	var i: int = tr.index_of_last_starting_before(t)
	for k: int in [i, i + 1]:
		if k < 0 or k >= tr.clips.size():
			continue
		var c: Clip = tr.clips[k]
		if c.has_transition():
			var span: Vector2 = c.transition_span()
			if t >= span.x and t <= span.y:
				return {"clip": c, "side": "in", "span": span}
		if c.has_transition_out():
			var so: Vector2 = c.transition_out_span()
			if t >= so.x and t <= so.y:
				return {"clip": c, "side": "out", "span": so}
	return {}


static func free_spot(tr: Track, t: float) -> Dictionary:
	if tr == null or tr.free_transitions.is_empty():
		return {}
	var ft: Dictionary = FreeTransition.at_point(tr.free_transitions, t)
	if ft.is_empty():
		return {}
	return {"free": ft, "span": FreeTransition.span(ft)}


static func transition_at(tr: Track, t: float) -> Clip:
	var i: int = tr.index_of_last_starting_before(t)
	for k: int in [i, i + 1]:
		if k < 0 or k >= tr.clips.size():
			continue
		var c: Clip = tr.clips[k]
		if not c.has_transition():
			continue
		var span: Vector2 = c.transition_span()
		if t >= span.x and t <= span.y:
			return c
	return null


static func x_of(geom: Dictionary, t: float) -> float:
	return Fold.x_of(geom.get("fold", NO_FOLD), t, float(geom["header_w"]), float(geom["pps"]), float(geom["scroll_x"]))


static func t_of(geom: Dictionary, x: float) -> float:
	return Fold.t_of(geom.get("fold", NO_FOLD), x, float(geom["header_w"]), float(geom["pps"]), float(geom["scroll_x"]))


static func lane_screen_y(geom: Dictionary, l: Dictionary) -> float:
	var set_name: String = String(l["set"])
	var r: Rect2 = geom["main_rect"] if set_name == "main" else geom["band_rect"]
	var sy: float = float(geom["scroll_y"]) if set_name == "main" else float(geom["band_scroll_y"])
	return r.position.y + float(l["y"]) - sy


static func clip_rect(geom: Dictionary, l: Dictionary, c: Clip) -> Rect2:
	var y: float = lane_screen_y(geom, l)
	var x0: float = x_of(geom, c.start)
	var x1: float = x_of(geom, c.end())
	return Rect2(x0, y, x1 - x0, float(l["h"]))


static func test(geom: Dictionary, lanes: Dictionary, seq: Sequence, pos: Vector2, playhead: float) -> Dictionary:
	var out: Dictionary = empty()
	out["x"] = pos.x
	out["y"] = pos.y
	var header_w: float = float(geom["header_w"])
	var ruler_h: float = float(geom["ruler_h"])
	var hscroll: Rect2 = geom["hscroll_rect"]
	var divider: Rect2 = geom["divider_rect"]
	var band: Rect2 = geom["band_rect"]
	var main: Rect2 = geom["main_rect"]
	out["t"] = maxf(t_of(geom, pos.x), 0.0)
	if pos.y < ruler_h:
		if pos.x < header_w:
			out["zone"] = "corner"
		else:
			out["zone"] = "ruler"
			out["marker_band"] = pos.y < MARKER_BAND
			if seq != null:
				var mh: Dictionary = marker_at(geom, seq, pos)
				out["marker"] = mh["marker"]
				out["marker_edge"] = String(mh["edge"])
		return out
	var mrow: Dictionary = row_at(geom, pos.y)
	if not mrow.is_empty():
		out["zone"] = "marker_lane"
		out["layer"] = String(mrow["id"])
		out["lane_y"] = float(mrow["y"])
		if pos.x < header_w:
			out["button"] = LaneKind.header_button_at(Rect2(0.0, float(mrow["y"]), header_w, float(mrow["h"])), mrow["layer"], pos)
		elif seq != null:
			out["marker_band"] = _open_lane(seq, String(mrow["id"]))
			var lh: Dictionary = marker_at(geom, seq, pos, mrow)
			out["marker"] = lh["marker"]
			out["marker_edge"] = String(lh["edge"])
		return out
	if hscroll.size.y > 0.0 and hscroll.has_point(pos):
		out["zone"] = "hscroll"
		return out
	if divider.size.y > 0.0 and divider.has_point(pos):
		out["zone"] = "divider"
		return out
	if absf(pos.x - header_w) <= HEADER_EDGE:
		out["zone"] = "header_edge"
		return out
	var set_name: String = ""
	var set_rect: Rect2 = Rect2()
	var lane_list: Array[Dictionary] = []
	var sy: float = 0.0
	if band.size.y > 0.0 and band.has_point(pos):
		set_name = "band"
		set_rect = band
		lane_list = lanes["band"]
		sy = float(geom["band_scroll_y"])
	elif main.has_point(pos):
		set_name = "main"
		set_rect = main
		lane_list = lanes["main"]
		sy = float(geom["scroll_y"])
	else:
		out["zone"] = "outside"
		return out
	out["set"] = set_name
	var content_y: float = pos.y - set_rect.position.y + sy
	var l: Dictionary = Lanes.lane_at(lane_list, content_y)
	if l.is_empty():
		if set_name == "main" and pos.x >= header_w:
			out["zone"] = "new_track"
		else:
			out["zone"] = "empty"
		return out
	out["lane"] = l
	out["track"] = l["track"]
	out["nest"] = bool(l["nest"])
	var lane_y: float = set_rect.position.y + float(l["y"]) - sy
	out["lane_y"] = lane_y
	var lane_h: float = float(l["h"])
	if pos.x < header_w:
		out["zone"] = "header"
		if pos.y >= lane_y + lane_h - TRACK_GRIP:
			out["grip"] = true
			return out
		var r: Rect2 = Rect2(0.0, lane_y, header_w, lane_h)
		if not bool(l["nest"]):
			out["button"] = Tracks.button_at(l["track"], r, set_name == "band", pos)
		return out
	out["zone"] = "lane"
	var t: float = float(out["t"])
	var tr: Track = l["track"]
	var pps: float = float(geom["pps"])
	var c: Clip = tr.clip_at(t)
	if not bool(l["nest"]):
		var tspot: Dictionary = transition_spot(tr, t)
		if not tspot.is_empty():
			var tclip: Clip = tspot["clip"]
			var span: Vector2 = tspot["span"]
			var sx0: float = x_of(geom, span.x)
			var sx1: float = x_of(geom, span.y)
			out["clip"] = tclip
			out["transition"] = true
			out["tr_side"] = String(tspot["side"])
			if pos.x - sx0 <= EDGE_REACH:
				out["tr_edge"] = "head"
			elif sx1 - pos.x <= EDGE_REACH:
				out["tr_edge"] = "tail"
			return out
		var fspot: Dictionary = free_spot(tr, t)
		if not fspot.is_empty():
			var fspan: Vector2 = fspot["span"]
			var fx0: float = x_of(geom, fspan.x)
			var fx1: float = x_of(geom, fspan.y)
			out["free"] = fspot["free"]
			if pos.x - fx0 <= EDGE_REACH:
				out["free_edge"] = "head"
			elif fx1 - pos.x <= EDGE_REACH:
				out["free_edge"] = "tail"
			return out
	if c != null:
		out["clip"] = c
		var x0: float = x_of(geom, c.start)
		var x1: float = x_of(geom, c.end())
		var w: float = x1 - x0
		var reach: float = minf(EDGE_REACH, w * 0.3)
		if pos.x - x0 <= reach:
			out["edge"] = "head"
		elif x1 - pos.x <= reach:
			out["edge"] = "tail"
		if not bool(l["nest"]):
			out["fade"] = fade_side_at(c, tr.clip_kind(c), x0, x1, lane_y + 1.0, pps, pos)
		if not c.props.is_empty() and SpeedBand.shown(c) and not bool(l["nest"]):
			if out["edge"] == "" and out["fade"] == "":
				var bh: Dictionary = SpeedBand.hit_clip(c, x0, pps, lane_y, lane_h, pos)
				if not bh.is_empty() and String(bh["what"]) != "inside":
					out["level"] = true
					out["band_key"] = String(bh["what"]) == "key"
			return out
		if tr.is_sound(c) and lane_h >= Paint.LEVEL_MIN_H and out["edge"] == "":
			var inner_top: float = lane_y + Paint.name_row_h() + 2.0
			var inner_h: float = lane_h - Paint.name_row_h() - 4.0
			var prop: Dictionary = c.audio.get("volume", {})
			var lt: float = t - c.start
			var v: float = clampf(AnimProp.evaluate_float(prop, c.param_time("audio.volume", lt), c.duration), 0.0, 2.0)
			var ly: float = inner_top + inner_h - v / 2.0 * inner_h
			if absf(pos.y - ly) <= LEVEL_REACH:
				out["level"] = true
		if not bool(out["level"]) and tr.is_picture(c) and not bool(l["nest"]) and out["edge"] == "" and opacity_line_hit(c, lane_y, lane_h, t, pos):
			out["level"] = true
		return out
	var i: int = tr.index_of_last_starting_before(t)
	var best: Clip = null
	var best_d: float = EDGE_REACH + 1.0
	var best_edge: String = ""
	if i >= 0:
		var prev: Clip = tr.clips[i]
		var d: float = pos.x - x_of(geom, prev.end())
		if d >= 0.0 and d < best_d:
			best = prev
			best_d = d
			best_edge = "tail"
	if i + 1 < tr.clips.size():
		var nxt: Clip = tr.clips[i + 1]
		var d2: float = x_of(geom, nxt.start) - pos.x
		if d2 >= 0.0 and d2 < best_d:
			best = nxt
			best_d = d2
			best_edge = "head"
	if best != null:
		out["clip"] = best
		out["edge"] = best_edge
		return out
	if absf(pos.x - x_of(geom, playhead)) <= PLAYHEAD_REACH:
		out["playhead"] = true
	return out


static func marquee_clips(geom: Dictionary, lanes: Dictionary, r: Rect2) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var t0: float = t_of(geom, r.position.x)
	var t1: float = t_of(geom, r.end.x)
	for key: String in ["main", "band"]:
		for l: Dictionary in lanes[key]:
			if bool(l["nest"]):
				continue
			var y: float = lane_screen_y(geom, l)
			var h: float = float(l["h"])
			if y + h < r.position.y or y > r.end.y:
				continue
			var tr: Track = l["track"]
			for c: Clip in tr.clips_in_range(t0, t1):
				if c.end() > t0 and c.start < t1:
					out.append(c.id)
	return out


static func opacity_line_y(c: Clip, lane_y: float, lane_h: float, t: float) -> float:
	var inner_top: float = lane_y + Paint.name_row_h() + 2.0
	var inner_h: float = lane_h - Paint.name_row_h() - 4.0
	var prop: Dictionary = c.get_param("transform.opacity")
	var v: float = clampf(AnimProp.evaluate_float(prop, c.param_time("transform.opacity", t - c.start), c.duration) if not prop.is_empty() else 1.0, 0.0, 1.0)
	return inner_top + inner_h - v * inner_h


static func opacity_line_hit(c: Clip, lane_y: float, lane_h: float, t: float, pos: Vector2) -> bool:
	if lane_h < Paint.KEY_MIN_H:
		return false
	var inner_top: float = lane_y + Paint.name_row_h() + 2.0
	if pos.y < inner_top - 1.0:
		return false
	return absf(pos.y - opacity_line_y(c, lane_y, lane_h, t)) <= LEVEL_REACH
