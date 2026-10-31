extends RefCounted

const MODE := "scrub"
const MOVE_PX := 4.0


static func _drag_of(canvas: Control) -> RefCounted:
	return canvas.get("drag")


static func press(canvas: Control) -> void:
	var drag: RefCounted = _drag_of(canvas)
	if drag == null or String(drag.get("mode")) != MODE:
		return
	var t: float = float(drag.get("scrub_t"))
	if t < 0.0:
		return
	canvas.set("_last_scrub", t)
	canvas.call("_click_to", t)


static func release(canvas: Control, t: float, moved: bool) -> void:
	if bool(canvas.call("gliding")):
		return
	if moved and t >= 0.0 and t != float(canvas.get("_last_scrub")):
		canvas.set("_last_scrub", t)
		Session.scrub_to(t)
	Session.scrub_done()


static func pointer_moved(drag: RefCounted) -> bool:
	return ((drag.get("last") as Vector2) - (drag.get("press") as Vector2)).length() >= float(Tk.px(MOVE_PX))


static func may_autoscroll(drag: RefCounted) -> bool:
	if String(drag.get("mode")) != MODE:
		return true
	return pointer_moved(drag)


static func may_follow(canvas: Control) -> bool:
	var drag: RefCounted = _drag_of(canvas)
	if drag == null:
		return true
	return not (bool(drag.call("in_progress")) and String(drag.get("mode")) == MODE)
