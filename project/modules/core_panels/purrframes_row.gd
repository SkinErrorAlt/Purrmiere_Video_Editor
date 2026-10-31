extends RefCounted

const TimeInterp := preload("res://engine/time_interp.gd")
const Clip := preload("res://doc/clip.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const REFRESH := 0.3
const BAR_W := 90.0
const LEFT := 160.0


class StatusLine:
	extends HBoxContainer

	var clip_id: String = ""
	var bar_bg: ColorRect = null
	var bar_fill: ColorRect = null
	var text_label: Label = null
	var _acc: float = 0.0
	var _last: String = ""

	func _ready() -> void:
		refresh()

	func _process(dt: float) -> void:
		_acc += dt
		if _acc < REFRESH:
			return
		_acc = 0.0
		refresh()

	func refresh() -> void:
		var st: Dictionary = status()
		var sig: String = str(st)
		if sig == _last:
			return
		_last = sig
		var state: String = String(st.get("state", ""))
		text_label.text = String(st.get("text", ""))
		PmUI.tip(text_label, String(st.get("text", "")))
		var colour: String = "text_dim"
		if state == "ready":
			colour = "text"
		elif state == "failed" or state == "missing":
			colour = "key_over"
		PmLabel.set_colour(text_label, colour)
		bar_bg.visible = state == "rendering"
		bar_fill.size = Vector2(float(Tk.px(BAR_W)) * clampf(float(st.get("progress", 0.0)), 0.0, 1.0), bar_bg.size.y)

	func status() -> Dictionary:
		var loop: MainLoop = Engine.get_main_loop()
		if not (loop is SceneTree):
			return {}
		var root: Window = (loop as SceneTree).root
		var pf: Node = root.get_node_or_null("Purrframes")
		var session: Node = root.get_node_or_null("Session")
		if pf == null or session == null:
			return {}
		var d: Object = session.get("doc")
		if d == null:
			return {}
		var c: Clip = d.call("clip_by_id", clip_id)
		if c == null:
			return {}
		return pf.call("status_for", c)


static func wanted(c: Clip) -> bool:
	return c != null and TimeInterp.mode_of(c) == TimeInterp.RIFE


static func add(panel: Object, body: VBoxContainer, c: Clip) -> void:
	if not wanted(c) or bool(panel.get("_many_on")):
		return
	var line: StatusLine = StatusLine.new()
	line.name = "PurrframesStatus"
	line.clip_id = c.id
	line.custom_minimum_size = Vector2(0.0, float(Tk.px(22.0)))
	line.add_theme_constant_override("separation", Tk.px(8.0))
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(float(Tk.px(LEFT)), 0.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pad)
	line.bar_bg = ColorRect.new()
	line.bar_bg.color = Tk.c["bg_panel_high"]
	line.bar_bg.custom_minimum_size = Vector2(float(Tk.px(BAR_W)), float(Tk.px(4.0)))
	line.bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.bar_fill = ColorRect.new()
	line.bar_fill.color = Tk.c["key_low"]
	line.bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.bar_fill.size = Vector2(0.0, float(Tk.px(4.0)))
	line.bar_bg.add_child(line.bar_fill)
	line.add_child(line.bar_bg)
	line.text_label = PmLabel.trim("", "text_dim")
	line.text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(line.text_label)
	body.add_child(line)
