extends Control

signal picture_input(event: InputEvent, picture_rect: Rect2)
signal zoom_changed(zoom: String)

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const ZOOMS: Array = ["fit", "0.1", "0.25", "0.5", "0.75", "1", "1.5", "2", "4"]
const ZOOM_LABELS: Dictionary = {"fit": "Fit", "fill": "Fill", "0.1": "10%", "0.25": "25%", "0.5": "50%", "0.75": "75%", "1": "100%", "1.5": "150%", "2": "200%", "4": "400%"}
const OVERLAY_IDS: PackedStringArray = ["safe", "thirds", "centre", "crop_1x1", "crop_4x5", "shorts", "tiktok", "reels"]
const OVERLAY_LABELS: Dictionary = {
	"safe": "Title and action safe (16:9)",
	"thirds": "Rule of thirds grid",
	"centre": "Centre cross",
	"crop_1x1": "1:1 crop guide",
	"crop_4x5": "4:5 crop guide",
	"shorts": "YouTube Shorts buttons and caption (9:16)",
	"tiktok": "TikTok buttons and caption (9:16)",
	"reels": "Instagram Reels buttons and caption (9:16)",
}
const ACTION_SAFE := 0.93
const TITLE_SAFE := 0.90
const VERTICAL_REF := Vector2(1080.0, 1920.0)
const PLATFORM_ZONES: Dictionary = {
	"shorts": [["Top bar", 0.0, 0.0, 1080.0, 150.0], ["Buttons", 950.0, 880.0, 130.0, 800.0], ["Title and channel", 0.0, 1500.0, 940.0, 420.0]],
	"tiktok": [["Top bar", 0.0, 0.0, 1080.0, 160.0], ["Buttons", 950.0, 700.0, 130.0, 900.0], ["Caption and sound", 0.0, 1500.0, 940.0, 280.0], ["Menu bar", 0.0, 1780.0, 1080.0, 140.0]],
	"reels": [["Top bar", 0.0, 0.0, 1080.0, 200.0], ["Buttons", 960.0, 980.0, 120.0, 760.0], ["Caption and audio", 0.0, 1540.0, 960.0, 380.0]],
}
const PAD := 10.0

var texture: Texture2D = null
var frame_size: Vector2 = Vector2(1920.0, 1080.0)
var zoom: String = "fit"
var show_frame: bool = true
var safe_margins: bool = false
var overlays: Dictionary = {}
var empty_text: String = "No engine"
var overlay_draw: Callable = Callable()
var backing: Color = Color.BLACK
var pan: Vector2 = Vector2.ZERO
var left_pans: bool = false
var wheel_zoom: bool = false
var pan_count: int = 0
var _pan_drag: Dictionary = {}
var _rect_tex: TextureRect = null
var _overlay: Control = null
var _font: Font = null


func _init() -> void:
	name = "MonitorView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_rect_tex = TextureRect.new()
	_rect_tex.name = "Picture"
	_rect_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_rect_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_rect_tex)
	_outline = MonitorOutline.new()
	add_child(_outline)
	_overlay = _Overlay.new()
	_overlay.view = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	resized.connect(_relayout)
	gui_input.connect(_on_input)


func _ready() -> void:
	_font = Tk.font("body")
	_relayout()


func set_texture(t: Texture2D) -> void:
	texture = t
	_rect_tex.texture = t
	_rect_tex.visible = t != null
	_relayout()


func set_frame_size(w: float, h: float) -> void:
	frame_size = Vector2(maxf(w, 1.0), maxf(h, 1.0))
	_relayout()


func set_zoom(z: String) -> void:
	zoom = z if (z in ZOOMS or z == ZOOM_FILL) else "fit"
	if zoom == "fit" or zoom == ZOOM_FILL:
		pan = Vector2.ZERO
	_relayout()


func set_overlay(id: String, on: bool) -> void:
	if id == "safe":
		safe_margins = on
	overlays[id] = on
	_overlay.queue_redraw()


func overlay_on(id: String) -> bool:
	if id == "safe":
		return safe_margins
	return bool(overlays.get(id, false))


func zoom_factor() -> float:
	var avail: Vector2 = avail_size()
	if zoom == "fit":
		if avail.x <= 1.0 or avail.y <= 1.0:
			return 0.0
		return minf(avail.x / frame_size.x, avail.y / frame_size.y)
	if zoom == ZOOM_FILL:
		return fill_factor()
	return float(zoom)


static func clamp_pan(p: Vector2, shown: Vector2, avail: Vector2) -> Vector2:
	var limit: Vector2 = ((shown - avail) * 0.5).max(Vector2.ZERO)
	return Vector2(clampf(p.x, -limit.x, limit.x), clampf(p.y, -limit.y, limit.y))


func picture_rect() -> Rect2:
	var avail: Vector2 = avail_size()
	if avail.x <= 1.0 or avail.y <= 1.0:
		return Rect2(Vector2(pad_px, pad_px), Vector2.ZERO)
	var ds: Vector2 = (frame_size * zoom_factor()).round()
	var pos: Vector2 = Vector2(pad_px, pad_px) + (avail - ds) * 0.5
	if zoom != "fit":
		pos += clamp_pan(pan, ds, avail)
	return Rect2(pos.round(), ds)


func can_pan() -> bool:
	if zoom == "fit":
		return false
	var avail: Vector2 = avail_size()
	var ds: Vector2 = frame_size * zoom_factor()
	return ds.x > avail.x + 0.5 or ds.y > avail.y + 0.5


func pan_by(delta: Vector2) -> void:
	var avail: Vector2 = avail_size()
	pan = clamp_pan(pan + delta, (frame_size * zoom_factor()).round(), avail)
	_relayout()


static func next_zoom(here: float, steps: int) -> String:
	var levels: Array = ZOOMS.slice(1)
	if steps > 0:
		for z: Variant in levels:
			if float(z) > here + 0.0001:
				return String(z)
		return String(levels[levels.size() - 1])
	var found: String = ""
	for z: Variant in levels:
		if float(z) < here - 0.0001:
			found = String(z)
	return found if not found.is_empty() else String(levels[0])


func zoom_step(steps: int, about: Vector2) -> void:
	var here: float = zoom_factor()
	var next_z: String = next_zoom(here, steps)
	if next_z.is_empty() or next_z == zoom:
		return
	var before: Rect2 = picture_rect()
	var at_frame: Vector2 = (about - before.position) / maxf(here, 0.0001)
	zoom = next_z
	var k: float = float(zoom)
	var avail: Vector2 = avail_size()
	var ds: Vector2 = (frame_size * k).round()
	var centred: Vector2 = Vector2(pad_px, pad_px) + (avail - ds) * 0.5
	pan = clamp_pan(about - at_frame * k - centred, ds, avail)
	_relayout()
	zoom_changed.emit(zoom)


func wants_left_pan() -> bool:
	return can_pan() and (left_pans or Input.is_key_pressed(KEY_SPACE))


func panning() -> bool:
	return not _pan_drag.is_empty()


func _relayout() -> void:
	var r: Rect2 = texture_rect()
	_rect_tex.position = r.position
	_rect_tex.size = r.size
	_sync_outside()
	_overlay.queue_redraw()
	queue_redraw()


func redraw_overlay() -> void:
	_overlay.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var pan_button: bool = mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and (panning() or (mb.pressed and wants_left_pan())))
		if pan_button:
			if mb.pressed and can_pan():
				_pan_drag = {"press": mb.position, "pan": pan, "button": mb.button_index}
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			elif not mb.pressed and panning() and int(_pan_drag.get("button", -1)) == mb.button_index:
				_pan_drag = {}
				pan_count += 1
				mouse_default_cursor_shape = Control.CURSOR_ARROW
			accept_event()
			return
		if wheel_zoom and mb.pressed and mb.ctrl_pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_step(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, mb.position)
			accept_event()
			return
	if event is InputEventMouseMotion and panning():
		var mm: InputEventMouseMotion = event
		var avail: Vector2 = avail_size()
		pan = clamp_pan((_pan_drag["pan"] as Vector2) + mm.position - (_pan_drag["press"] as Vector2), (frame_size * zoom_factor()).round(), avail)
		_relayout()
		accept_event()
		return
	picture_input.emit(event, picture_rect())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_app"], true)
	var r: Rect2 = picture_rect()
	draw_rect(r, backing if texture != null else Tk.c["bg_field"], true)
	if texture == null:
		var fs: int = Tk.fs(Tk.sz("font_body"))
		PmText.draw(self, _font, r, empty_text, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_CENTER, PmText.pad(), r.position.y + r.size.y * 0.5 + fs * 0.35)


static func safe_rects(pic: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k: float in [ACTION_SAFE, TITLE_SAFE]:
		out.append(Rect2(pic.position + pic.size * (1.0 - k) * 0.5, pic.size * k))
	return out


static func crop_rect(pic: Rect2, aspect: float) -> Rect2:
	if pic.size.x <= 0.0 or pic.size.y <= 0.0 or aspect <= 0.0:
		return pic
	var w: float = pic.size.x
	var h: float = w / aspect
	if h > pic.size.y:
		h = pic.size.y
		w = h * aspect
	return Rect2(pic.position + (pic.size - Vector2(w, h)) * 0.5, Vector2(w, h))


static func vertical_area(pic: Rect2) -> Rect2:
	return crop_rect(pic, VERTICAL_REF.x / VERTICAL_REF.y)


static func zone_rects(platform: String, pic: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var area: Rect2 = vertical_area(pic)
	var k: Vector2 = area.size / VERTICAL_REF
	for z: Array in PLATFORM_ZONES.get(platform, []):
		var r: Rect2 = Rect2(area.position + Vector2(float(z[1]), float(z[2])) * k, Vector2(float(z[3]), float(z[4])) * k)
		out.append({"label": String(z[0]), "rect": r})
	return out


func overlay_shapes(pic: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pic.size.x < 8.0 or pic.size.y < 8.0:
		return out
	if overlay_on("safe"):
		var rs: Array[Rect2] = safe_rects(pic)
		out.append({"id": "safe", "kind": "box", "rect": rs[0], "label": "Action safe"})
		out.append({"id": "safe", "kind": "box", "rect": rs[1], "label": "Title safe"})
	if overlay_on("thirds"):
		for i: int in [1, 2]:
			var fx: float = pic.position.x + pic.size.x * float(i) / 3.0
			var fy: float = pic.position.y + pic.size.y * float(i) / 3.0
			out.append({"id": "thirds", "kind": "line", "from": Vector2(fx, pic.position.y), "to": Vector2(fx, pic.end.y), "label": ""})
			out.append({"id": "thirds", "kind": "line", "from": Vector2(pic.position.x, fy), "to": Vector2(pic.end.x, fy), "label": ""})
	if overlay_on("centre"):
		var c: Vector2 = pic.get_center()
		var arm: float = clampf(minf(pic.size.x, pic.size.y) * 0.03, 6.0, 24.0)
		out.append({"id": "centre", "kind": "line", "from": c - Vector2(arm, 0.0), "to": c + Vector2(arm, 0.0), "label": ""})
		out.append({"id": "centre", "kind": "line", "from": c - Vector2(0.0, arm), "to": c + Vector2(0.0, arm), "label": ""})
	if overlay_on("crop_1x1"):
		out.append({"id": "crop_1x1", "kind": "box", "rect": crop_rect(pic, 1.0), "label": "1:1"})
	if overlay_on("crop_4x5"):
		out.append({"id": "crop_4x5", "kind": "box", "rect": crop_rect(pic, 0.8), "label": "4:5"})
	for platform: String in ["shorts", "tiktok", "reels"]:
		if not overlay_on(platform):
			continue
		var area: Rect2 = vertical_area(pic)
		if absf(area.size.x - pic.size.x) > 1.0 or absf(area.size.y - pic.size.y) > 1.0:
			out.append({"id": platform, "kind": "box", "rect": area, "label": "9:16"})
		for z: Dictionary in zone_rects(platform, pic):
			out.append({"id": platform, "kind": "zone", "rect": z["rect"], "label": String(z["label"])})
	return out


const ZOOM_FILL := "fill"
const OUTSIDE_SHADER := "res://modules/core_panels/monitor_outside.gdshader"
const MAX_REVEAL := 8

var pad_px: float = PAD
var canvas_rect: Rect2 = Rect2()
var outside_mode: int = 0
var outside_amount: float = 0.5
var outside_tint: Color = Color(1.0, 0.0, 0.0, 1.0)
var reveal_only: bool = false
var reveal_quads: Array[PackedVector2Array] = []
var _outside_mat: ShaderMaterial = null


static func zoom_choice_ids() -> Array:
	var out: Array = ["fit", ZOOM_FILL]
	out.append_array(ZOOMS.slice(1))
	return out


func avail_size() -> Vector2:
	return size - Vector2(pad_px, pad_px) * 2.0


func set_pad(px: float) -> void:
	pad_px = maxf(px, 0.0)
	_relayout()


func fill_factor() -> float:
	var avail: Vector2 = avail_size()
	if avail.x <= 1.0 or avail.y <= 1.0:
		return 0.0
	return maxf(avail.x / frame_size.x, avail.y / frame_size.y)


func set_canvas_rect(r: Rect2) -> void:
	if r.is_equal_approx(canvas_rect):
		return
	canvas_rect = r
	_relayout()


func has_margin() -> bool:
	return canvas_rect.size.x > 0.0 and canvas_rect.size.y > 0.0 and not canvas_rect.is_equal_approx(Rect2(Vector2.ZERO, frame_size))


func texture_rect() -> Rect2:
	var pic: Rect2 = picture_rect()
	if not has_margin() or pic.size.x <= 0.0:
		return pic
	var k: Vector2 = pic.size / frame_size
	return Rect2(pic.position + canvas_rect.position * k, canvas_rect.size * k)


func frame_uv() -> Rect2:
	if not has_margin():
		return Rect2(0.0, 0.0, 1.0, 1.0)
	return Rect2(-canvas_rect.position / canvas_rect.size, frame_size / canvas_rect.size)


func set_outside(mode: int, amount: float, tint: Color) -> void:
	outside_mode = clampi(mode, 0, 4)
	outside_amount = clampf(amount, 0.0, 1.0)
	outside_tint = tint
	show_frame = outside_mode != 0
	_sync_outside()
	_overlay.queue_redraw()


func set_reveal(on: bool, quads: Array[PackedVector2Array]) -> void:
	reveal_only = on
	reveal_quads = quads
	_sync_outside()


func shading_on() -> bool:
	return outside_mode != 0 and has_margin() and texture != null


func _sync_outside() -> void:
	if _rect_tex == null:
		return
	if not shading_on():
		if _rect_tex.material != null:
			_rect_tex.material = null
		return
	if _outside_mat == null:
		_outside_mat = ShaderMaterial.new()
		_outside_mat.shader = load(OUTSIDE_SHADER)
	if _rect_tex.material != _outside_mat:
		_rect_tex.material = _outside_mat
	var uv: Rect2 = frame_uv()
	_outside_mat.set_shader_parameter("frame_uv", Vector4(uv.position.x, uv.position.y, uv.end.x, uv.end.y))
	_outside_mat.set_shader_parameter("mode", outside_mode)
	_outside_mat.set_shader_parameter("amount", outside_amount)
	_outside_mat.set_shader_parameter("tint", outside_tint)
	_outside_mat.set_shader_parameter("reveal_only", reveal_only)
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 0
	for q: PackedVector2Array in reveal_quads:
		if n >= MAX_REVEAL or q.size() != 4:
			continue
		for p: Vector2 in q:
			pts.append((p - canvas_rect.position) / canvas_rect.size)
		n += 1
	while pts.size() < MAX_REVEAL * 4:
		pts.append(Vector2.ZERO)
	_outside_mat.set_shader_parameter("reveal_pts", pts)
	_outside_mat.set_shader_parameter("reveal_count", n)


const MonitorOutline := preload("res://modules/core_panels/monitor_outline.gd")

var _outline: Control = null


func outline_layer() -> Control:
	return _outline


func show_outline(quads: Array[PackedVector2Array]) -> void:
	_outline.call("show_quads", quads)


func hide_outline() -> void:
	_outline.call("hide_all")


func visible_outside_seq() -> Vector2:
	var pic: Rect2 = picture_rect()
	if pic.size.x <= 0.0 or frame_size.x <= 0.0:
		return Vector2.ZERO
	var k: float = pic.size.x / frame_size.x
	var l: float = pic.position.x - pad_px
	var r: float = size.x - pad_px - pic.end.x
	var t: float = pic.position.y - pad_px
	var b: float = size.y - pad_px - pic.end.y
	return Vector2(maxf(maxf(l, r), 0.0), maxf(maxf(t, b), 0.0)) / k


class _Overlay:
	extends Control

	var view: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _label_shape(s: Dictionary, box: Rect2, font: Font, fs: int, col: Color) -> void:
		var label: String = String(s.get("label", ""))
		if label.is_empty() or box.size.y <= font.get_height(fs) + 4.0:
			return
		var kind: String = String(s["kind"])
		var bottom: bool = String(s.get("id", "")) == "safe" and label.begins_with("Title")
		var right: bool = kind == "box" and String(s.get("id", "")) != "safe"
		var base: float = box.end.y - 2.0 - font.get_descent(fs) if bottom else box.position.y + 2.0 + font.get_ascent(fs)
		var drawn: Rect2 = PmText.draw(self, font, box, label, fs, col, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), base, PmText.WHOLE)
		if drawn.has_area():
			PmText.keep_out(self, [drawn] as Array[Rect2])

	func _draw() -> void:
		if view == null:
			return
		var r: Rect2 = view.call("picture_rect")
		if bool(view.get("show_frame")):
			draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
		var guide: Color = Color(Tk.c["text_bright"], 0.6)
		var shade: Color = Color(0.0, 0.0, 0.0, 0.32)
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		for s: Dictionary in view.call("overlay_shapes", r):
			var kind: String = String(s["kind"])
			if kind == "line":
				draw_line(s["from"], s["to"], guide, 1.0)
				continue
			var box: Rect2 = s["rect"]
			if kind == "zone":
				draw_rect(box, shade, true)
				draw_rect(Rect2(box.position + Vector2(0.5, 0.5), box.size - Vector2(1.0, 1.0)), Color(guide, 0.45), false, 1.0)
			else:
				draw_rect(Rect2(box.position + Vector2(0.5, 0.5), box.size - Vector2(1.0, 1.0)), guide, false, 1.0)
			_label_shape(s, box, font, fs, guide)
		var cb: Callable = view.get("overlay_draw")
		if cb.is_valid():
			cb.call(self, r)
