extends Node
## Draws one scope of a frame texture on the GPU. Every sampled pixel (and channel) is a point that the vertex
## shader places where the scope plots it; additive blending in a float target counts them. The result is a
## texture to show through scope_tone.gdshader, or for the histogram a strip of counts for scope_bars.gdshader.

const MODES: PackedStringArray = ["luma", "rgb", "parade", "vector", "histogram"]
const MODE_LABELS: PackedStringArray = ["Waveform", "RGB waveform", "Parade", "Vectorscope", "Histogram"]
const DETAILS: Array = [Vector2i(160, 90), Vector2i(256, 144), Vector2i(384, 216)]
const OUT_WAVE := Vector2i(512, 256)
const OUT_VECTOR := Vector2i(320, 320)
const BINS := 256
## Each bin is spread over this many rows so whole number counts stay exact in the half float target.
const HIST_ROWS := 64

var mode: String = "luma"
var detail: int = 1
var source: Texture2D = null
var renders: int = 0
var _vp: SubViewport = null
var _mm: MultiMeshInstance2D = null
var _mat: ShaderMaterial = null
var _count: int = -1


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.name = "ScopeTarget"
	_vp.transparent_bg = true
	_vp.use_hdr_2d = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_vp)
	_mm = MultiMeshInstance2D.new()
	_mm.name = "Points"
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://modules/core_panels/scopes/scope_points.gdshader")
	_mm.material = _mat
	_mm.texture = PlaceholderTexture2D.new()
	_vp.add_child(_mm)
	_configure()


func channels() -> int:
	return 1 if mode == "luma" or mode == "vector" else 3


func out_size() -> Vector2i:
	if mode == "vector":
		return OUT_VECTOR
	if mode == "histogram":
		return Vector2i(BINS, HIST_ROWS)
	return OUT_WAVE


func grid() -> Vector2i:
	return DETAILS[clampi(detail, 0, DETAILS.size() - 1)]


func set_mode(m: String) -> void:
	if not MODES.has(m) or m == mode:
		return
	mode = m
	_configure()


func set_detail(d: int) -> void:
	d = clampi(d, 0, DETAILS.size() - 1)
	if d == detail:
		return
	detail = d
	_configure()


func _configure() -> void:
	if _vp == null:
		return
	var g: Vector2i = grid()
	var n: int = g.x * g.y * channels()
	_vp.size = out_size()
	if n != _count:
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = Vector2.ONE
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_2D
		multi.mesh = mesh
		multi.instance_count = n
		var buf: PackedFloat32Array = PackedFloat32Array()
		buf.resize(n * 8)
		for i: int in n:
			var o: int = i * 8
			buf[o] = 1.0
			buf[o + 5] = 1.0
		multi.buffer = buf
		_mm.multimesh = multi
		_count = n
	var samples: float = float(g.x * g.y)
	var w: float = 0.0
	match mode:
		"histogram":
			w = 1.0
		"vector":
			w = clampf(9000.0 / samples, 0.004, 0.2) * 0.35
		_:
			w = clampf(float(g.x) * float(OUT_WAVE.y) / samples * 0.12, 0.01, 0.6)
	_mat.set_shader_parameter("grid", Vector2(g))
	_mat.set_shader_parameter("out_size", Vector2(out_size()))
	_mat.set_shader_parameter("mode", MODES.find(mode))
	_mat.set_shader_parameter("channels", channels())
	_mat.set_shader_parameter("weight", w)
	_mat.set_shader_parameter("hist_rows", float(HIST_ROWS))


func set_source(t: Texture2D) -> void:
	source = t
	_mat.set_shader_parameter("frame", t)


## Draws the scope of the current source on the next frame.
func render() -> void:
	if source == null or _vp == null:
		return
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


## What one sample is worth on the histogram, so a level holding everything reads as BINS.
func hist_norm() -> float:
	var g: Vector2i = grid()
	return float(BINS) / float(maxi(g.x * g.y, 1))


## Count of samples in one histogram bin for one channel (0 red, 1 green, 2 blue), from a read back image.
static func bin_count(img: Image, bin: int, ch: int = 0) -> float:
	var s: float = 0.0
	for y: int in img.get_height():
		s += img.get_pixel(bin, y)[ch]
	return s


func texture() -> Texture2D:
	return _vp.get_texture() if _vp != null else null
