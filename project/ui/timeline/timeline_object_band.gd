extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const ObjectStore := preload("res://engine/object_store.gd")
const TOOL_ID := "object_select"
const BAND_H := 4.0
const BOTTOM_GAP := 12.0
const KEY_W := 3.0
const GONE_INK := Color(0.90, 0.29, 0.31, 1.0)
const CHECK_INK := Color(0.98, 0.78, 0.26, 1.0)
const MIN_LANE_H := 22.0

static var bands_drawn: int = 0


static func ink() -> Color:
	return Color(0.42, 0.95, 0.72, 1.0)


static func any_objects(canvas: Control) -> bool:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if s == null:
		return false
	var key: String = s.id + "|" + str(d.serial if d != null else 0)
	if String(canvas.get_meta("object_any_key", "")) == key:
		return bool(canvas.get_meta("object_any", false))
	var found: bool = false
	for tr: Track in s.all_tracks():
		for c: Clip in tr.clips:
			if not object_of(c).is_empty():
				found = true
				break
		if found:
			break
	canvas.set_meta("object_any_key", key)
	canvas.set_meta("object_any", found)
	return found


static func bands(canvas: Control) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or not any_objects(canvas):
		return out
	var geom: Dictionary = canvas.call("geometry")
	var ln: Dictionary = canvas.call("lanes")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var t0: float = Hit.t_of(geom, header_w)
	var t1: float = Hit.t_of(geom, width)
	for set_name: String in ["main", "band"]:
		var area: Rect2 = geom["main_rect"] if set_name == "main" else geom["band_rect"]
		if area.size.y <= 0.0:
			continue
		for l: Dictionary in ln[set_name]:
			if bool(l["nest"]):
				continue
			var tr: Track = l["track"]
			var y: float = Hit.lane_screen_y(geom, l)
			var h: float = float(l["h"])
			var by: float = y + h - BAND_H - BOTTOM_GAP
			if by < area.position.y or by + BAND_H > area.end.y or h < MIN_LANE_H:
				continue
			for c: Clip in tr.clips_in_range(t0, t1):
				var mask: Dictionary = object_of(c)
				if mask.is_empty():
					continue
				out.append({"clip": c, "mask": mask, "y": by, "x0": maxf(area.position.x, header_w), "x1": area.end.x, "fps": s.fps})
	return out


static func object_of(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for m: Dictionary in c.masks:
		if ObjectMask.is_object(m) and bool(m.get("enabled", true)):
			return m
	return {}


static func tracked_span(mask: Dictionary) -> Vector2i:
	var id: String = str(mask.get("id", ""))
	var store: String = ObjectMatte.bound(id)
	if store.is_empty():
		return Vector2i(-1, -1)
	var frames: PackedInt32Array = ObjectStore.frame_list(store)
	if frames.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(frames[0], frames[frames.size() - 1])


static func draw(canvas: Control) -> void:
	bands_drawn = 0
	var list: Array[Dictionary] = bands(canvas)
	if list.is_empty():
		return
	var geom: Dictionary = canvas.call("geometry")
	for bd: Dictionary in list:
		var c: Clip = bd["clip"]
		var mask: Dictionary = bd["mask"]
		var fps: float = maxf(float(bd["fps"]), 1.0)
		var y: float = float(bd["y"])
		var cx0: float = maxf(Hit.x_of(geom, c.start), float(bd["x0"]))
		var cx1: float = minf(Hit.x_of(geom, c.start + c.duration), float(bd["x1"]))
		if cx1 <= cx0:
			continue
		canvas.draw_rect(Rect2(cx0, y, cx1 - cx0, BAND_H), Color(ink(), 0.18), true)
		var span: Vector2i = tracked_span(mask)
		if span.x >= 0:
			var sx0: float = maxf(Hit.x_of(geom, c.start + float(span.x) / fps), cx0)
			var sx1: float = minf(Hit.x_of(geom, c.start + float(span.y + 1) / fps), cx1)
			if sx1 > sx0:
				canvas.draw_rect(Rect2(sx0, y, sx1 - sx0, BAND_H), Color(ink(), 0.55), true)
		for flagged: int in ObjectMask.flagged(mask):
			var fx: float = Hit.x_of(geom, c.start + float(flagged) / fps)
			if fx < cx0 - KEY_W or fx > cx1 + KEY_W:
				continue
			var tone: Color = GONE_INK if ObjectMask.flag_at(mask, flagged) == ObjectMask.GONE else CHECK_INK
			canvas.draw_rect(Rect2(fx - KEY_W * 0.5, y, KEY_W, BAND_H), tone, true)
		for key: int in ObjectMask.key_frames(mask):
			var kx: float = Hit.x_of(geom, c.start + float(key) / fps)
			if kx < cx0 - KEY_W or kx > cx1 + KEY_W:
				continue
			canvas.draw_rect(Rect2(kx - KEY_W * 0.5, y - 1.0, KEY_W, BAND_H + 2.0), ink(), true)
		bands_drawn += 1
