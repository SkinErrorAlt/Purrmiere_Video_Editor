extends RefCounted
## How locked regions (doc/fences.gd) look and are made on the timeline: a hatched band over the tracks with solid
## edges and a lock strip in the ruler, and the ruler's right click items (lock in to out, unlock here, unlock all).

const Fences := preload("res://doc/fences.gd")
const HATCH := 10.0
const STRIP_H := 4.0


static func draw(ci: CanvasItem, canvas: Object, g: Dictionary) -> void:
	var s: Object = canvas.call("seq")
	if s == null:
		return
	var fences: Array = s.get("fences")
	if fences.is_empty():
		return
	var header_w: float = float(g["header_w"])
	var rh: float = float(g["ruler_h"])
	var hs: Rect2 = g["hscroll_rect"]
	var top: float = rh
	var bottom: float = hs.position.y
	var right: float = float(g["width"])
	var ink: Color = Tk.c["warn"] if Tk.c.has("warn") else Color(1.0, 0.75, 0.3, 1.0)
	for f: Variant in fences:
		if not (f is Dictionary):
			continue
		var x0: float = maxf(float(canvas.call("x_of", float((f as Dictionary).get("start", 0.0)))), header_w)
		var x1: float = minf(float(canvas.call("x_of", float((f as Dictionary).get("end", 0.0)))), right)
		if x1 <= header_w or x0 >= right or x1 - x0 < 0.5:
			continue
		ci.draw_rect(Rect2(x0, top, x1 - x0, bottom - top), Color(ink, 0.06), true)
		var lines: PackedVector2Array = PackedVector2Array()
		var start: float = x0 - fmod(x0 + top, HATCH) - (bottom - top)
		var x: float = start
		while x < x1:
			var a: Vector2 = Vector2(x, bottom)
			var b: Vector2 = Vector2(x + (bottom - top), top)
			var clipped: Array = _clip_segment(a, b, x0, x1)
			if not clipped.is_empty():
				lines.append(clipped[0])
				lines.append(clipped[1])
			x += HATCH
		if not lines.is_empty():
			ci.draw_multiline(lines, Color(ink, 0.13), 1.0)
		var sx0: float = float(canvas.call("x_of", float((f as Dictionary).get("start", 0.0))))
		var sx1: float = float(canvas.call("x_of", float((f as Dictionary).get("end", 0.0))))
		if sx0 >= header_w:
			ci.draw_rect(Rect2(sx0, 0.0, 1.0, bottom), Color(ink, 0.8), true)
		if sx1 <= right:
			ci.draw_rect(Rect2(sx1 - 1.0, 0.0, 1.0, bottom), Color(ink, 0.8), true)
		ci.draw_rect(Rect2(x0, rh - STRIP_H - 1.0, x1 - x0, STRIP_H), Color(ink, 0.75), true)


static func _clip_segment(a: Vector2, b: Vector2, x0: float, x1: float) -> Array:
	var dx: float = b.x - a.x
	if absf(dx) < 0.0001:
		return [a, b] if a.x >= x0 and a.x <= x1 else []
	var t0: float = clampf((x0 - a.x) / dx, 0.0, 1.0)
	var t1: float = clampf((x1 - a.x) / dx, 0.0, 1.0)
	if t1 <= t0:
		return []
	return [a.lerp(b, t0), a.lerp(b, t1)]


## Ruler right click items for the time `t`.
static func menu_items(s: Object, t: float) -> Array:
	var out: Array = []
	var have_range: bool = s != null and float(s.get("in_point")) >= 0.0 and float(s.get("out_point")) > float(s.get("in_point"))
	var lock_in_out: Dictionary = PmMenu.item("fence_in_out", "Lock in to out (nothing ripples through)")
	lock_in_out["disabled"] = not have_range
	out.append(lock_in_out)
	if s != null and not Fences.at(s, t).is_empty():
		out.append(PmMenu.item("fence_remove", "Unlock this region"))
	if s != null and not (s.get("fences") as Array).is_empty():
		out.append(PmMenu.item("fence_clear", "Unlock every region"))
	return out


static func on_menu(id: String, doc: Object, s: Object, t: float) -> bool:
	if id == "fence_in_out":
		return Fences.add_in_out(doc, s)
	if id == "fence_remove":
		return Fences.remove_at(doc, s, t)
	if id == "fence_clear":
		return Fences.clear(doc, s)
	return false


const PmMenu := preload("res://ui/kit/pm_menu.gd")
