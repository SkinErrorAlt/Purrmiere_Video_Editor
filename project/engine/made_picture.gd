extends Control

const PATTERN_PROP := "pattern"
const BARS := "bars"
const LEADER := "countdown"
const CLEAR := "clear"
const PATTERNS: PackedStringArray = [BARS, LEADER, CLEAR]
const CLOCK_PROP := "media_clock"
const DECODE_PROP := "decode_clock"
const FPS_PROP := "leader_fps"
const FIRST_NUMBER := 8
const LAST_NUMBER := 2
const TOP: Array[Color] = [Color8(192, 192, 192), Color8(192, 192, 0), Color8(0, 192, 192), Color8(0, 192, 0), Color8(192, 0, 192), Color8(192, 0, 0), Color8(0, 0, 192)]
const MIDDLE: Array[Color] = [Color8(0, 0, 192), Color8(19, 19, 19), Color8(192, 0, 192), Color8(19, 19, 19), Color8(0, 192, 192), Color8(19, 19, 19), Color8(192, 192, 192)]
const MINUS_I := Color8(0, 33, 76)
const WHITE := Color8(255, 255, 255)
const PLUS_Q := Color8(50, 0, 106)
const BLACK := Color8(19, 19, 19)
const SUPER_BLACK := Color8(9, 9, 9)
const LIFTED_BLACK := Color8(29, 29, 29)
const TOP_SHARE := 0.67
const MIDDLE_SHARE := 0.08
const LEADER_BACK := Color(0.29, 0.29, 0.29)
const LEADER_WIPE := Color(0.58, 0.58, 0.58)
const LEADER_LINE := Color(0.06, 0.06, 0.06)
const LEADER_RING := Color(0.96, 0.96, 0.96)
const LEADER_NUMBER := Color(0.04, 0.04, 0.04)
const OUTER_RING := 0.40
const INNER_RING := 0.335
const SWEEP_STEPS := 96
const FONT_PATH := "res://fonts/body.ttf"

static var _numeral_font: Font = null

var pattern: String = ""
var clock: float = 0.0
var fps: float = 30.0


func _init() -> void:
	name = "MadePicture"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


static func pattern_of(props: Dictionary) -> String:
	var p: String = String(props.get(PATTERN_PROP, ""))
	return p if PATTERNS.has(p) else ""


static func clock_of(props: Dictionary) -> float:
	if props.has(CLOCK_PROP):
		return float(props[CLOCK_PROP])
	return float(props.get(DECODE_PROP, 0.0))


static func apply(vp: SubViewport, rect: ColorRect, node: Control, props: Dictionary) -> void:
	var p: String = pattern_of(props)
	if vp != null:
		vp.transparent_bg = p == CLEAR
	if rect != null:
		rect.visible = p.is_empty()
	if node == null:
		return
	node.set("pattern", p)
	node.set("clock", clock_of(props))
	node.set("fps", maxf(float(props.get(FPS_PROP, 30.0)), 1.0))
	node.visible = p == BARS or p == LEADER
	node.queue_redraw()


static func bar_cells(w: float, h: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bw: float = w / 7.0
	var top_h: float = round(h * TOP_SHARE)
	var mid_h: float = round(h * (TOP_SHARE + MIDDLE_SHARE)) - top_h
	for i: int in 7:
		var x0: float = round(bw * float(i))
		var x1: float = round(bw * float(i + 1))
		out.append({"rect": Rect2(x0, 0.0, x1 - x0, top_h), "colour": TOP[i]})
		out.append({"rect": Rect2(x0, top_h, x1 - x0, mid_h), "colour": MIDDLE[i]})
	var low_y: float = top_h + mid_h
	var low_h: float = h - low_y
	var wide: float = bw * 5.0 / 4.0
	var bottom: Array[Color] = [MINUS_I, WHITE, PLUS_Q, BLACK]
	var x: float = 0.0
	for k: int in 4:
		var nx: float = round(wide * float(k + 1))
		out.append({"rect": Rect2(x, low_y, nx - x, low_h), "colour": bottom[k]})
		x = nx
	var pluge: Array[Color] = [SUPER_BLACK, BLACK, LIFTED_BLACK]
	var narrow: float = bw / 3.0
	var start: float = round(bw * 5.0)
	for k2: int in 3:
		var a: float = round(start + narrow * float(k2))
		var b: float = round(start + narrow * float(k2 + 1))
		out.append({"rect": Rect2(a, low_y, b - a, low_h), "colour": pluge[k2]})
	var tail: float = round(bw * 6.0)
	out.append({"rect": Rect2(tail, low_y, w - tail, low_h), "colour": BLACK})
	return out


static func leader_state(t: float, frame_rate: float) -> Dictionary:
	var counted: float = float(FIRST_NUMBER - LAST_NUMBER)
	var frame: float = 1.0 / maxf(frame_rate, 1.0)
	if t < 0.0:
		return {"number": FIRST_NUMBER, "sweep": 0.0, "black": false}
	if t < counted:
		var whole: float = floor(t + 0.000001)
		return {"number": FIRST_NUMBER - int(whole), "sweep": clampf(t - whole, 0.0, 1.0), "black": false}
	if t < counted + frame - 0.000001:
		return {"number": LAST_NUMBER, "sweep": 0.0, "black": false}
	return {"number": -1, "sweep": 0.0, "black": true}


static func numeral_font() -> Font:
	if _numeral_font == null:
		var base: Font = load(FONT_PATH) as Font
		if base == null:
			base = ThemeDB.fallback_font
		var fv: FontVariation = FontVariation.new()
		fv.base_font = base
		fv.variation_embolden = 0.9
		_numeral_font = fv
	return _numeral_font


func _draw() -> void:
	if pattern == BARS:
		for cell: Dictionary in bar_cells(size.x, size.y):
			draw_rect(cell["rect"], cell["colour"], true)
	elif pattern == LEADER:
		_draw_leader()


func _draw_leader() -> void:
	var w: float = size.x
	var h: float = size.y
	var st: Dictionary = leader_state(clock, fps)
	if bool(st["black"]):
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)
		return
	draw_rect(Rect2(Vector2.ZERO, size), LEADER_BACK, true)
	var centre: Vector2 = size * 0.5
	var reach: float = Vector2(w, h).length()
	var sweep: float = float(st["sweep"])
	if sweep > 0.0:
		var pts: PackedVector2Array = PackedVector2Array([centre])
		var steps: int = maxi(int(ceil(float(SWEEP_STEPS) * sweep)), 2)
		for i: int in steps + 1:
			var a: float = -PI * 0.5 + TAU * sweep * float(i) / float(steps)
			pts.append(centre + Vector2(cos(a), sin(a)) * reach)
		draw_colored_polygon(pts, LEADER_WIPE)
		var edge: float = -PI * 0.5 + TAU * sweep
		draw_line(centre, centre + Vector2(cos(edge), sin(edge)) * reach, LEADER_LINE, maxf(h * 0.004, 1.0), true)
	var line_w: float = maxf(h * 0.003, 1.0)
	draw_line(Vector2(0.0, centre.y), Vector2(w, centre.y), LEADER_LINE, line_w, true)
	draw_line(Vector2(centre.x, 0.0), Vector2(centre.x, h), LEADER_LINE, line_w, true)
	var ring_w: float = maxf(h * 0.009, 1.5)
	draw_arc(centre, h * OUTER_RING, 0.0, TAU, 160, LEADER_RING, ring_w, true)
	draw_arc(centre, h * INNER_RING, 0.0, TAU, 160, LEADER_RING, ring_w * 0.7, true)
	var n: int = int(st["number"])
	if n < 0:
		return
	var font: Font = numeral_font()
	var fs: int = maxi(int(round(h * 0.5)), 8)
	var text: String = str(n)
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc: float = font.get_ascent(fs)
	var desc: float = font.get_descent(fs)
	var base: Vector2 = Vector2(centre.x - ts.x * 0.5, centre.y + (asc - desc) * 0.5 - h * 0.012)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(int(round(h * 0.012)), 1), Color(0.85, 0.85, 0.85, 0.55))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LEADER_NUMBER)


static func thumb_image(pattern_: String, colour: Color, w: int, h: int) -> Image:
	var img: Image = Image.create_empty(maxi(w, 2), maxi(h, 2), false, Image.FORMAT_RGBA8)
	if pattern_ == BARS:
		for cell: Dictionary in bar_cells(float(img.get_width()), float(img.get_height())):
			var r: Rect2 = cell["rect"]
			img.fill_rect(Rect2i(int(r.position.x), int(r.position.y), maxi(int(r.size.x), 1), maxi(int(r.size.y), 1)), cell["colour"])
		return img
	if pattern_ == CLEAR:
		var sq: int = maxi(img.get_height() / 8, 2)
		for y: int in img.get_height():
			for x: int in img.get_width():
				var light: bool = ((x / sq) + (y / sq)) % 2 == 0
				img.set_pixel(x, y, Color(0.42, 0.42, 0.42) if light else Color(0.3, 0.3, 0.3))
		return img
	if pattern_ == LEADER:
		var c: Vector2 = Vector2(float(img.get_width()), float(img.get_height())) * 0.5
		var hh: float = float(img.get_height())
		var wipe_to: float = -PI * 0.5 + TAU * 0.3
		for y2: int in img.get_height():
			for x2: int in img.get_width():
				var p: Vector2 = Vector2(float(x2) + 0.5, float(y2) + 0.5) - c
				var ang: float = atan2(p.y, p.x)
				var from_top: float = fposmod(ang + PI * 0.5, TAU)
				var col: Color = LEADER_WIPE if from_top <= fposmod(wipe_to + PI * 0.5, TAU) else LEADER_BACK
				var d: float = p.length()
				if absf(d - hh * OUTER_RING) < maxf(hh * 0.012, 0.8) or absf(d - hh * INNER_RING) < maxf(hh * 0.008, 0.6):
					col = LEADER_RING
				elif absf(p.x) < 0.7 or absf(p.y) < 0.7:
					col = LEADER_LINE
				img.set_pixel(x2, y2, col)
		return img
	img.fill(colour)
	return img
