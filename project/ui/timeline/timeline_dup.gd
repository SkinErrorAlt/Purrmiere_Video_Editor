extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const MARK_PX := 14.0


static func ghost(canvas: Control, s: Sequence, t: Track, c: Clip, x0: float, x1: float, lane_y: float, lane_h: float, move_steps: int) -> Dictionary:
	var drag: Object = canvas.get("drag")
	var pps: float = float(canvas.get("pps"))
	var header_w: float = float(canvas.get("header_w"))
	var dx: float = float(drag.get("delta_t")) * pps
	var gx0: float = x0 + dx
	var gx1: float = x1 + dx
	if canvas.has_method("fold") and not (canvas.call("fold") as Dictionary).is_empty():
		gx0 = float(canvas.call("x_of", c.start + float(drag.get("delta_t"))))
		gx1 = float(canvas.call("x_of", c.end() + float(drag.get("delta_t"))))
	var body_y: float = lane_y
	var own_steps: int = s.visual_track_delta(t.kind, move_steps) if move_steps != 0 and s.was_picked(c.id) else 0
	if own_steps != 0:
		var dest: Track = s.track_at_offset(t, own_steps)
		var dl: Dictionary = Lanes.lane_for_track(canvas.call("lanes"), dest.id)
		if not dl.is_empty():
			body_y = Hit.lane_screen_y(canvas.call("geometry"), dl)
	var r: Rect2 = Rect2(maxf(gx0, header_w), body_y + 1.0, minf(gx1, canvas.size.x) - maxf(gx0, header_w), lane_h - 2.0)
	r.size.x = maxf(r.size.x, 1.0)
	var d: Project = canvas.call("doc")
	var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return {"r": r, "col": Paint.clip_colour(c, item, t), "sel": true, "enabled": c.enabled, "label": StreamRoles.shown_label(item, c, t.is_sound(c)), "dup": true}


static func draw_mark(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Tk.c["accent"], false, 2.0)
	if r.size.x < MARK_PX + 4.0 or r.size.y < MARK_PX + 2.0:
		return
	var box: Rect2 = Rect2(r.end.x - MARK_PX - 3.0, r.position.y + 2.0, MARK_PX, MARK_PX)
	ci.draw_rect(box, Tk.c["accent"], true)
	var mid: Vector2 = box.get_center()
	var arm: float = MARK_PX * 0.3
	var ink: Color = Tk.c["bg_shell"]
	ci.draw_line(mid - Vector2(arm, 0.0), mid + Vector2(arm, 0.0), ink, 2.0)
	ci.draw_line(mid - Vector2(0.0, arm), mid + Vector2(0.0, arm), ink, 2.0)
