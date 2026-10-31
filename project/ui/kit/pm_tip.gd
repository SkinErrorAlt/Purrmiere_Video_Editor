extends Control

const GROUP := "pm_tip"
const OVERLAY_GROUP := "pm_overlay"
const WINDOW_TIP_META := "pm_window_tip_node"
const PREF_DELAY := "ui.tip_delay"
const OFFSET := Vector2(14.0, 14.0)
const CLEARANCE := 4.0
const MAX_W := 420.0

var text: String = ""
var keys: String = ""
var target: Control = null
var _wait: float = 0.0
var _armed: bool = false
var _para: TextParagraph = null


static func attach(control: Control, text_: String, keys_: String = "") -> void:
	if control == null:
		return
	control.set_meta("pm_tip_text", text_)
	control.set_meta("pm_tip_keys", keys_)
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE and not text_.is_empty():
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control.has_meta("pm_tip_bound"):
		return
	control.set_meta("pm_tip_bound", true)
	var script: GDScript = load("res://ui/kit/pm_tip.gd")
	control.mouse_entered.connect(Callable(script, "_target_entered").bind(control))
	control.mouse_exited.connect(Callable(script, "_target_exited").bind(control))
	control.tree_exiting.connect(Callable(script, "_target_exited").bind(control))


static func text_of(control: Control) -> String:
	if control == null or not control.has_meta("pm_tip_text"):
		return ""
	return String(control.get_meta("pm_tip_text"))


static func instance_for(node: Node) -> Control:
	if node == null or not node.is_inside_tree():
		return null
	var own: Control = window_tip(node)
	if own != null:
		return own
	var tree: SceneTree = node.get_tree()
	var found: Node = tree.get_first_node_in_group(GROUP)
	if found != null and found is Control:
		return found
	var overlay: Node = tree.get_first_node_in_group(OVERLAY_GROUP)
	if overlay == null:
		overlay = tree.root
	var script: GDScript = load("res://ui/kit/pm_tip.gd")
	var tip: Control = script.new()
	overlay.add_child(tip)
	return tip


static func _target_entered(control: Control) -> void:
	var tip: Control = instance_for(control)
	if tip != null:
		tip.call("arm", control)


static func _target_exited(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	var own: Control = window_tip(control)
	if own != null:
		own.call("disarm", control)
		return
	var tree: SceneTree = control.get_tree()
	var found: Node = tree.get_first_node_in_group(GROUP)
	if found != null:
		found.call("disarm", control)


static func window_tip(node: Node) -> Control:
	var w: Window = node.get_window()
	if w == null or not w.has_meta(WINDOW_TIP_META):
		return null
	var t: Variant = w.get_meta(WINDOW_TIP_META)
	if is_instance_valid(t) and t is Control and (t as Control).is_inside_tree():
		return t
	return null


func _init() -> void:
	name = "PmTip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	add_to_group(GROUP)
	set_process(true)


func delay() -> float:
	if not Prefs.is_registered(PREF_DELAY):
		Prefs.register(PREF_DELAY, 0.5, {"label": "Tooltip delay", "type": "float", "min": 0.0, "max": 3.0})
	return clampf(float(Prefs.get_value(PREF_DELAY)), 0.0, 3.0)


func arm(control: Control) -> void:
	target = control
	text = text_of(control)
	keys = String(control.get_meta("pm_tip_keys")) if control.has_meta("pm_tip_keys") else ""
	_wait = delay()
	_armed = not text.is_empty()
	visible = false


func disarm(control: Control) -> void:
	if target == control:
		target = null
		_armed = false
		visible = false


func hide_now() -> void:
	_armed = false
	visible = false


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		target = null
		_armed = false
		visible = false
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_armed = false
		visible = false
		return
	if _armed:
		_wait -= dt
		if _wait <= 0.0:
			_armed = false
			measure()
			visible = true
			_reveal()
			queue_redraw()
	if visible:
		place(get_viewport().get_mouse_position())


func _reveal() -> void:
	var d: float = Tk.dur("fast")
	if d <= 0.0 or not is_inside_tree():
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	var tw: Tween = Tk.ease(create_tween())
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, d)
	tw.tween_property(self, "scale", Vector2.ONE, d)


func measure() -> void:
	var f: Font = Tk.font("body")
	var mono: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 2.0
	var gap: float = float(Tk.px(Tk.sz("gap")))
	var key_w: float = 0.0
	if not keys.is_empty():
		key_w = gap * 2.0 + mono.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_para = TextParagraph.new()
	_para.add_string(text, f, fs)
	_para.width = -1.0
	var natural: float = _para.get_size().x
	var limit: float = float(Tk.px(MAX_W)) - key_w
	if natural > limit:
		_para.width = limit
		_para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_size: Vector2 = _para.get_size()
	var w: float = minf(natural, maxf(limit, 1.0)) + key_w
	var h: float = maxf(text_size.y, f.get_height(fs)) + gap * 2.0 + 2.0
	size = Vector2(ceil(w + pad * 2.0), ceil(h))


func place(mouse: Vector2) -> void:
	var vp: Rect2 = get_viewport_rect()
	var p: Vector2 = mouse + OFFSET
	if p.x + size.x > vp.size.x - 2.0:
		p.x = vp.size.x - 2.0 - size.x
	if p.y + size.y > vp.size.y - 2.0:
		p.y = mouse.y - OFFSET.y - size.y
	if target != null:
		var tr: Rect2 = target.get_global_rect()
		if Rect2(p, size).intersects(tr):
			p.y = tr.end.y + CLEARANCE
			if p.y + size.y > vp.size.y - 2.0:
				p.y = tr.position.y - CLEARANCE - size.y
			if p.y < 0.0:
				p.y = mouse.y + OFFSET.y
	p.x = maxf(0.0, p.x)
	p.y = maxf(0.0, p.y)
	global_position = p.round()


func _draw() -> void:
	var radius: float = float(Tk.px(Tk.sz("radius")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(6.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(2.0)))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f: Font = Tk.font("body")
	var mono: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 2.0
	var gap: float = float(Tk.px(Tk.sz("gap")))
	if _para == null:
		measure()
	var top: float = (size.y - _para.get_size().y) * 0.5
	_para.draw(get_canvas_item(), Vector2(pad, top), Tk.c["text"])
	if not keys.is_empty():
		var first_w: float = _para.get_line_width(0) if _para.get_line_count() > 0 else 0.0
		var y: float = top + _para.get_line_ascent(0) if _para.get_line_count() > 0 else top + f.get_ascent(fs)
		draw_string(mono, Vector2(pad + first_w + gap * 2.0, y), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tk.c["text_faint"])


func fit_texts() -> Array:
	if _para == null or text.is_empty():
		return []
	var pad: float = float(Tk.px(Tk.sz("pad"))) + 2.0
	var gap: float = float(Tk.px(Tk.sz("gap")))
	var widest: float = 0.0
	for i: int in _para.get_line_count():
		widest = maxf(widest, _para.get_line_width(i))
	var out: Array = [{"text": text, "rect": Rect2(pad, 0.0, widest, size.y), "need": widest}]
	if not keys.is_empty():
		var kw: float = Tk.font("mono").get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, Tk.fs(Tk.sz("font_small"))).x
		var first_w: float = _para.get_line_width(0) if _para.get_line_count() > 0 else 0.0
		out.append({"text": keys, "rect": Rect2(pad + first_w + gap * 2.0, 0.0, kw, size.y), "need": kw})
	return out
