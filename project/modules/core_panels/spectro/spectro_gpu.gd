extends RefCounted
## Computes a spectrogram for exactly the area on screen: one windowed FFT per pixel column, run on the GPU as a
## batched Stockham FFT, then each pixel row picks the strongest bin in its frequency span (or interpolates
## between bins when zoomed in past them). The result is a float texture of decibels; colouring is done when drawn.

const Glsl := preload("res://modules/core_panels/spectro/spectro_glsl.gd")
const BATCH_COMPLEX := 1 << 21
const GROUP := 256
const ROW_GROUPS := 65535
const MIN_N := 64
const MAX_N := 16384
const WINDOWS: PackedStringArray = ["hann", "hamming", "blackman", "blackman_harris", "flat_top", "kaiser", "rectangle"]
const WINDOW_LABELS: PackedStringArray = ["Hann", "Hamming", "Blackman", "Blackman-Harris", "Flat top", "Kaiser", "Rectangle"]
const OUTSIDE_DB := -999.0

var rd: RenderingDevice = null
var texture: Texture2DRD = null
var computes: int = 0
var last_cpu_ms: float = 0.0
var sample_rate: float = 48000.0
var sample_count: int = 0
var n: int = 0
var window_kind: String = ""
var norm2: float = 1.0
var out_size: Vector2i = Vector2i.ZERO
var columns: PackedInt32Array = PackedInt32Array()

var _shader: RID = RID()
var _pipeline: RID = RID()
var _sample_tex: RID = RID()
var _tex_w: int = 1
var _win_buf: RID = RID()
var _tw_buf: RID = RID()
var _buf_a: RID = RID()
var _buf_b: RID = RID()
var _col_buf: RID = RID()
var _col_cap: int = 0
var _out_tex: RID = RID()
var _set: RID = RID()
var _set_dirty: bool = true
var _failed: String = ""


static func available() -> bool:
	return RenderingServer.get_rendering_device() != null


func _init(device: RenderingDevice = null) -> void:
	rd = device if device != null else RenderingServer.get_rendering_device()
	if rd == null:
		_failed = "The spectrogram needs the GPU renderer"
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = Glsl.FFT
	var spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(src)
	if spirv == null or not spirv.compile_error_compute.is_empty():
		_failed = "The spectrogram shader did not compile: " + (spirv.compile_error_compute if spirv != null else "")
		push_error(_failed)
		return
	_shader = rd.shader_create_from_spirv(spirv, "Spectrogram FFT")
	if not _shader.is_valid():
		_failed = "The spectrogram shader could not be created"
		return
	_pipeline = rd.compute_pipeline_create(_shader)
	if device == null:
		texture = Texture2DRD.new()


func error() -> String:
	return _failed


func ready_to_draw() -> bool:
	return _failed.is_empty() and _sample_tex.is_valid() and n > 0 and _out_tex.is_valid()


func max_n() -> int:
	return MAX_N


func set_samples(samples: PackedFloat32Array, rate: float) -> void:
	if not _failed.is_empty():
		return
	_free(_sample_tex)
	_sample_tex = RID()
	sample_rate = maxf(rate, 1.0)
	sample_count = samples.size()
	var limit: int = maxi(rd.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D), 1024)
	_tex_w = mini(limit, 16384)
	var rows: int = maxi(1, int(ceil(float(maxi(sample_count, 1)) / float(_tex_w))))
	if rows > limit:
		sample_count = limit * _tex_w
		rows = limit
	var data: PackedFloat32Array = samples.slice(0, sample_count) if samples.size() > sample_count else samples
	var bytes: PackedByteArray = data.to_byte_array()
	bytes.resize(_tex_w * rows * 4)
	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.width = _tex_w
	fmt.height = rows
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_sample_tex = rd.texture_create(fmt, RDTextureView.new(), [bytes])
	_set_dirty = true


func clear_samples() -> void:
	_free(_sample_tex)
	_sample_tex = RID()
	sample_count = 0
	_set_dirty = true


func has_samples() -> bool:
	return _sample_tex.is_valid() and sample_count > 0


func set_window(size_: int, kind: String) -> void:
	if not _failed.is_empty():
		return
	var size_n: int = clampi(nearest_po2(size_), MIN_N, MAX_N)
	if size_n == n and kind == window_kind:
		return
	var resized: bool = size_n != n
	n = size_n
	window_kind = kind if WINDOWS.has(kind) else "hann"
	var w: PackedFloat32Array = window_values(n, window_kind)
	var total: float = 0.0
	for v: float in w:
		total += v
	norm2 = pow(total * 0.5, 2.0)
	_free(_win_buf)
	_win_buf = rd.storage_buffer_create(n * 4, w.to_byte_array())
	if resized:
		_free(_tw_buf)
		_tw_buf = rd.storage_buffer_create(n * 4, twiddles(n).to_byte_array())
		_free(_buf_a)
		_free(_buf_b)
		var cap: int = maxi(BATCH_COMPLEX, n * 2)
		_buf_a = rd.storage_buffer_create(cap * 8)
		_buf_b = rd.storage_buffer_create(cap * 8)
	_set_dirty = true


func set_out_size(s: Vector2i) -> void:
	if not _failed.is_empty():
		return
	var want := Vector2i(clampi(s.x, 1, 8192), clampi(s.y, 1, 8192))
	if want == out_size and _out_tex.is_valid():
		return
	out_size = want
	var old: RID = _out_tex
	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.width = out_size.x
	fmt.height = out_size.y
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_out_tex = rd.texture_create(fmt, RDTextureView.new())
	if texture != null:
		texture.texture_rd_rid = _out_tex
	_free(old)
	if _col_cap < out_size.x:
		_free(_col_buf)
		_col_cap = maxi(out_size.x, 256)
		_col_buf = rd.storage_buffer_create(_col_cap * 4)
	_set_dirty = true


## Window start (in samples) for each pixel column. hop > 0 snaps column centres to multiples of hop samples.
static func column_starts(width: int, t0: float, t1: float, rate: float, size_n: int, hop: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(width)
	var span: float = t1 - t0
	for x: int in width:
		var c: float = (t0 + (float(x) + 0.5) / float(width) * span) * rate
		if hop >= 1.0:
			c = round(c / hop) * hop
		out[x] = int(round(c)) - size_n / 2
	return out


func compute(t0: float, t1: float, f0: float, f1: float, log_freq: bool, hop: float) -> bool:
	if not ready_to_draw():
		return false
	var started: int = Time.get_ticks_usec()
	var w: int = out_size.x
	var h: int = out_size.y
	columns = column_starts(w, t0, t1, sample_rate, n, hop)
	rd.buffer_update(_col_buf, 0, w * 4, columns.to_byte_array())
	if _set_dirty or not _set.is_valid() or not rd.uniform_set_is_valid(_set):
		_build_set()
	var lo: float = f0
	var hi: float = f1
	if log_freq:
		lo = maxf(lo, 1.0)
		hi = maxf(hi, lo * 1.001)
	var log2n: int = int(round(log(float(n)) / log(2.0)))
	var pairs_max: int = maxi(1, BATCH_COMPLEX / n)
	var cl: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipeline)
	rd.compute_list_bind_uniform_set(cl, _set, 0)
	var col0: int = 0
	while col0 < w:
		var pairs: int = mini(pairs_max, (w - col0 + 1) / 2)
		_dispatch(cl, _params(0, log2n, 0, pairs, col0, w, h, 0, log_freq, lo, hi), pairs * n)
		for s: int in log2n:
			_dispatch(cl, _params(1, log2n, s, pairs, col0, w, h, 0, log_freq, lo, hi), pairs * n / 2)
		_dispatch(cl, _params(2, log2n, 0, pairs, col0, w, h, log2n % 2, log_freq, lo, hi), pairs * 2 * h)
		col0 += pairs * 2
	rd.compute_list_end()
	computes += 1
	last_cpu_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return true


func _dispatch(cl: int, params: PackedByteArray, threads: int) -> void:
	var groups: int = maxi(1, int(ceil(float(threads) / float(GROUP))))
	var gx: int = mini(groups, ROW_GROUPS)
	var gy: int = int(ceil(float(groups) / float(ROW_GROUPS)))
	rd.compute_list_set_push_constant(cl, params, params.size())
	rd.compute_list_dispatch(cl, gx, gy, 1)
	rd.compute_list_add_barrier(cl)


func _params(mode: int, log2n: int, stage: int, pairs: int, col0: int, cols: int, height: int, from_b: int, log_freq: bool, lo: float, hi: float) -> PackedByteArray:
	var ints := PackedInt32Array([mode, n, log2n, stage, pairs, col0, cols, height, _tex_w, sample_count, from_b, 1 if log_freq else 0])
	var floats := PackedFloat32Array([lo, hi, sample_rate, norm2])
	var out: PackedByteArray = ints.to_byte_array()
	out.append_array(floats.to_byte_array())
	return out


func _build_set() -> void:
	if _set.is_valid() and rd.uniform_set_is_valid(_set):
		rd.free_rid(_set)
	var u: Array[RDUniform] = [
		_image_uniform(0, _sample_tex),
		_buffer_uniform(1, _win_buf),
		_buffer_uniform(2, _tw_buf),
		_buffer_uniform(3, _buf_a),
		_buffer_uniform(4, _buf_b),
		_image_uniform(5, _out_tex),
		_buffer_uniform(6, _col_buf),
	]
	_set = rd.uniform_set_create(u, _shader, 0)
	_set_dirty = false


static func _image_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(rid)
	return u


static func _buffer_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u


## Reads the decibel image back (row 0 is the top, the highest frequency). Slow; for tests and level checks.
func read_db() -> PackedFloat32Array:
	if not _out_tex.is_valid():
		return PackedFloat32Array()
	return rd.texture_get_data(_out_tex, 0).to_float32_array()


func read_db_async(done: Callable) -> bool:
	if not _out_tex.is_valid():
		return false
	var relay: Callable = func(bytes: PackedByteArray) -> void: done.call(bytes.to_float32_array())
	return rd.texture_get_data_async(_out_tex, 0, relay) == OK


func release() -> void:
	if rd == null:
		return
	if _set.is_valid() and rd.uniform_set_is_valid(_set):
		rd.free_rid(_set)
	_set = RID()
	if texture != null:
		texture.texture_rd_rid = RID()
	for rid: RID in [_out_tex, _col_buf, _buf_a, _buf_b, _tw_buf, _win_buf, _sample_tex, _pipeline, _shader]:
		_free(rid)
	_out_tex = RID()
	_col_buf = RID()
	_buf_a = RID()
	_buf_b = RID()
	_tw_buf = RID()
	_win_buf = RID()
	_sample_tex = RID()
	_pipeline = RID()
	_shader = RID()
	_col_cap = 0
	n = 0
	out_size = Vector2i.ZERO


func _free(rid: RID) -> void:
	if rd != null and rid.is_valid():
		rd.free_rid(rid)


static func window_values(size_n: int, kind: String) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(size_n)
	var beta: float = 8.6
	var i0b: float = _bessel_i0(beta)
	for k: int in size_n:
		var x: float = TAU * float(k) / float(size_n)
		var v: float = 1.0
		match kind:
			"hann":
				v = 0.5 - 0.5 * cos(x)
			"hamming":
				v = 0.54 - 0.46 * cos(x)
			"blackman":
				v = 0.42 - 0.5 * cos(x) + 0.08 * cos(2.0 * x)
			"blackman_harris":
				v = 0.35875 - 0.48829 * cos(x) + 0.14128 * cos(2.0 * x) - 0.01168 * cos(3.0 * x)
			"flat_top":
				v = 0.21557895 - 0.41663158 * cos(x) + 0.277263158 * cos(2.0 * x) - 0.083578947 * cos(3.0 * x) + 0.006947368 * cos(4.0 * x)
			"kaiser":
				var r: float = 2.0 * float(k) / float(size_n) - 1.0
				v = _bessel_i0(beta * sqrt(maxf(0.0, 1.0 - r * r))) / i0b
			_:
				v = 1.0
		w[k] = v
	return w


static func _bessel_i0(x: float) -> float:
	var sum: float = 1.0
	var term: float = 1.0
	var q: float = x * x * 0.25
	for k: int in range(1, 60):
		term *= q / float(k * k)
		sum += term
		if term < sum * 1e-12:
			break
	return sum


static func twiddles(size_n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size_n)
	for m: int in size_n / 2:
		var a: float = TAU * float(m) / float(size_n)
		out[m * 2] = cos(a)
		out[m * 2 + 1] = -sin(a)
	return out
