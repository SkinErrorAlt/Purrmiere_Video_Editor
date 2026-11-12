extends Control
## Shows one scope: the trace from a ScopeRenderer through a glow tone, or histogram bars, over its graticule
## (0 to 100 levels for waveforms, colour targets and the skin tone line for the vectorscope).

const ScopeRenderer := preload("res://modules/core_panels/scopes/scope_renderer.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const LEVELS: Array = [0, 25, 50, 75, 100]
## BT.709 75% colour bar targets, as (label, rgb).
const TARGETS: Array = [["R", Color(0.75, 0, 0)], ["Mg", Color(0.75, 0, 0.75)], ["B", Color(0, 0, 0.75)], ["Cy", Color(0, 0.75, 0.75)], ["G", Color(0, 0.75, 0)], ["Yl", Color(0.75, 0.75, 0)]]

var renderer: Node = null
var gain: float = 1.0
var _trace: TextureRect = null
var _tone: ShaderMaterial = null
var _bars: ColorRect = null
var _bars_mat: ShaderMaterial = null


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trace = TextureRect.new()
	_trace.name = "Trace"
	_trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trace.stretch_mode = TextureRect.STRETCH_SCALE
	_trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tone = ShaderMaterial.new()
	_tone.shader = load("res://modules/core_panels/scopes/scope_tone.gdshader")
	_trace.material = _tone
	add_child(_trace)
	_bars = ColorRect.new()
	_bars.name = "Bars"
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_mat = ShaderMaterial.new()
	_bars_mat.shader = load("res://modules/core_panels/scopes/scope_bars.gdshader")
	_bars.material = _bars_mat
	add_child(_bars)
	resized.connect(_layout)
	_layout()


func attach(r: Node) -> void:
	renderer = r
	_trace.texture = r.call("texture")
	_bars_mat.set_shader_parameter("counts", r.call("texture"))
	_layout()


func _mode() -> String:
	return String(renderer.get("mode")) if renderer != null else "luma"


## Where the trace sits inside the control, keeping the scope's shape.
func plot_rect() -> Rect2:
	var f: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var pad: float = PmText.width_of(f, "100", fs) + float(Tk.px(10.0)) + PmText.pad() * 2.0
	var area: Rect2 = Rect2(Vector2(pad, 8.0), size - Vector2(pad + 8.0, 16.0))
	if _mode() == "vector":
		var s: float = maxf(minf(area.size.x, area.size.y), 8.0)
		return Rect2(area.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
	return area


func _layout() -> void:
	if _trace == null:
		return
	var r: Rect2 = plot_rect()
	var hist: bool = _mode() == "histogram"
	_trace.visible = not hist
	_bars.visible = hist
	_trace.position = r.position
	_trace.size = r.size
	_bars.position = r.position
	_bars.size = r.size
	_tone.set_shader_parameter("gain", gain)
	if renderer != null:
		_bars_mat.set_shader_parameter("norm", float(renderer.call("hist_norm")))
		_bars_mat.set_shader_parameter("rows", ScopeRenderer.HIST_ROWS)
	queue_redraw()


func refresh() -> void:
	_layout()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.06, 0.07), true)
	var r: Rect2 = plot_rect()
	var line: Color = Color(1, 1, 1, 0.13)
	var label: Color = Color(1, 1, 1, 0.45)
	var f: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	match _mode():
		"vector":
			_draw_vector(r, line, label, f, fs)
		"histogram":
			for q: int in 5:
				var x: float = r.position.x + r.size.x * float(q) / 4.0
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), line, 1.0)
			draw_rect(r, line, false, 1.0)
		_:
			var parade: bool = _mode() == "parade"
			for lv: int in LEVELS:
				var y: float = r.end.y - r.size.y * float(lv) / 100.0
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 1.0)
				PmText.draw(self, f, Rect2(0.0, y - float(fs), r.position.x - float(Tk.px(3.0)), float(fs) * 2.0), str(lv), fs, label, HORIZONTAL_ALIGNMENT_RIGHT)
			if parade:
				for k: int in [1, 2]:
					var x2: float = r.position.x + r.size.x * float(k) / 3.0
					draw_line(Vector2(x2, r.position.y), Vector2(x2, r.end.y), Color(1, 1, 1, 0.22), 1.0)


func _draw_vector(r: Rect2, line: Color, label: Color, f: Font, fs: int) -> void:
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.5
	draw_arc(c, rad, 0.0, TAU, 96, line, 1.0, true)
	draw_arc(c, rad * 0.5, 0.0, TAU, 64, Color(line.r, line.g, line.b, line.a * 0.6), 1.0, true)
	draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), line, 1.0)
	draw_line(c - Vector2(0, rad), c + Vector2(0, rad), line, 1.0)
	var skin: Vector2 = vector_point(c, rad, Color(0.85, 0.62, 0.5))
	var dir: Vector2 = (skin - c).normalized()
	draw_line(c, c + dir * rad, Color(1.0, 0.8, 0.6, 0.35), 1.0, true)
	for t: Array in TARGETS:
		var p: Vector2 = vector_point(c, rad, t[1])
		var box: float = float(Tk.px(7.0))
		draw_rect(Rect2(p - Vector2(box, box) * 0.5, Vector2(box, box)), Color(1, 1, 1, 0.35), false, 1.0)
		var away: Vector2 = (p - c).normalized() * float(Tk.px(12.0))
		PmText.draw(self, f, Rect2(p + away - Vector2(14.0, float(fs)), Vector2(28.0, float(fs) * 2.0)), String(t[0]), fs, label, HORIZONTAL_ALIGNMENT_CENTER)


## Where a colour lands on the vectorscope, the same maths as the shader (BT.709 Cb and Cr).
static func vector_point(c: Vector2, rad: float, col: Color) -> Vector2:
	var y: float = col.r * 0.2126 + col.g * 0.7152 + col.b * 0.0722
	var cb: float = (col.b - y) / 1.8556
	var cr: float = (col.r - y) / 1.5748
	return c + Vector2(cb, -cr) * 2.0 * rad
