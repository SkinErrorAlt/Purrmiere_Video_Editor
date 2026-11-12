extends RefCounted
## Hides a picture in sound: each column of the picture becomes a moment, each row a sine at its own frequency,
## loud where the picture is bright, so the sound's spectrogram draws the picture.

const Glsl := preload("res://modules/core_panels/spectro/spectro_glsl.gd")
const SpectroSource := preload("res://modules/core_panels/spectro/spectro_source.gd")
const STEP_BITS := 20
const STEP_ONE := 1 << STEP_BITS
const GROUP := 256
const ROW_GROUPS := 65535
const CHUNK := 1 << 18
const MAX_ROWS := 1024
const MAX_COLS := 4096
const CPU_MAX_ROWS := 96
const FADE_SECONDS := 0.01


static func defaults() -> Dictionary:
	return {
		"seconds": 6.0,
		"low": 2000.0,
		"high": 14000.0,
		"log": false,
		"rate": 48000,
		"contrast": 50.0,
		"invert": "auto",
		"rows": 0,
		"cols": 0,
		"seed": 1,
	}


static func rows_for(spec: Dictionary) -> int:
	var want: int = int(spec.get("rows", 0))
	if want > 0:
		return clampi(want, 8, MAX_ROWS)
	var band: float = float(spec.get("high", 14000.0)) - float(spec.get("low", 2000.0))
	return clampi(int(round(band / 20.0)), 32, MAX_ROWS)


static func cols_for(spec: Dictionary) -> int:
	var want: int = int(spec.get("cols", 0))
	if want > 0:
		return clampi(want, 4, MAX_COLS)
	return clampi(int(round(float(spec.get("seconds", 6.0)) * 40.0)), 16, MAX_COLS)


## Brightness of the picture as amplitudes, column by column (index c * rows + r, row 0 at the top).
static func picture_amps(img: Image, rows: int, cols: int, contrast_db: float, invert: String) -> PackedFloat32Array:
	var src: Image = img.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(cols, rows, Image.INTERPOLATE_LANCZOS)
	var data: PackedByteArray = src.get_data()
	var lum := PackedFloat32Array()
	lum.resize(rows * cols)
	var total: float = 0.0
	for y: int in rows:
		for x: int in cols:
			var i: int = (y * cols + x) * 4
			var a: float = float(data[i + 3]) / 255.0
			var l: float = (0.2126 * float(data[i]) + 0.7152 * float(data[i + 1]) + 0.0722 * float(data[i + 2])) / 255.0 * a
			lum[x * rows + y] = l
			total += l
	var flip: bool = invert == "yes" or (invert == "auto" and total / float(maxi(rows * cols, 1)) > 0.6)
	var out := PackedFloat32Array()
	out.resize(rows * cols)
	for k: int in lum.size():
		var b: float = clampf(1.0 - lum[k] if flip else lum[k], 0.0, 1.0)
		out[k] = 0.0 if b < 0.02 else pow(10.0, (b - 1.0) * contrast_db / 20.0)
	return out


## Frequency of each row (row 0 the highest), in the same mapping the spectrogram draws.
static func row_freqs(rows: int, low: float, high: float, log_freq: bool) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(rows)
	var lo: float = maxf(low, 1.0) if log_freq else low
	for r: int in rows:
		var v: float = 1.0 - (float(r) + 0.5) / float(rows)
		out[r] = lo * pow(high / lo, v) if log_freq else lerpf(lo, high, v)
	return out


static func row_steps(freqs: PackedFloat64Array, rate: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(freqs.size())
	for r: int in freqs.size():
		out[r] = int(round(freqs[r] / rate * float(STEP_ONE)))
	return out


static func row_phases(rows: int, seed_: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var out := PackedFloat32Array()
	out.resize(rows)
	for r: int in rows:
		out[r] = rng.randf() * TAU
	return out


## Makes the sound. Returns {"samples", "rate", "rows", "cols", "ms", "gpu"} or {"error"}.
static func synth_picture(img: Image, spec_in: Dictionary) -> Dictionary:
	var spec: Dictionary = defaults()
	spec.merge(spec_in, true)
	if img == null or img.is_empty():
		return {"error": "There is no picture to hide"}
	var rate: int = clampi(int(spec["rate"]), 8000, 192000)
	var seconds: float = clampf(float(spec["seconds"]), 0.2, 600.0)
	var low: float = clampf(float(spec["low"]), 1.0, rate * 0.5 - 10.0)
	var high: float = clampf(float(spec["high"]), low + 10.0, rate * 0.5)
	var rd: RenderingDevice = RenderingServer.create_local_rendering_device() if RenderingServer.get_rendering_device() != null else null
	var rows: int = rows_for(spec) if rd != null else mini(rows_for(spec), CPU_MAX_ROWS)
	var cols: int = cols_for(spec)
	var amps: PackedFloat32Array = picture_amps(img, rows, cols, float(spec["contrast"]), String(spec["invert"]))
	var freqs: PackedFloat64Array = row_freqs(rows, low, high, bool(spec["log"]))
	var steps: PackedInt32Array = row_steps(freqs, float(rate))
	var phases: PackedFloat32Array = row_phases(rows, int(spec["seed"]))
	var count: int = int(round(seconds * float(rate)))
	var started: int = Time.get_ticks_usec()
	var samples := PackedFloat32Array()
	var on_gpu: bool = false
	if rd != null:
		samples = _synth_gpu(rd, amps, steps, phases, rows, cols, count, float(rate))
		rd.free()
		on_gpu = not samples.is_empty()
	if samples.is_empty():
		samples = synth_cpu(amps, steps, phases, rows, cols, count, float(rate))
	return {"samples": samples, "rate": rate, "rows": rows, "cols": cols, "gpu": on_gpu, "ms": float(Time.get_ticks_usec() - started) / 1000.0, "low": low, "high": high, "seconds": seconds}


static func _synth_gpu(rd: RenderingDevice, amps: PackedFloat32Array, steps: PackedInt32Array, phases: PackedFloat32Array, rows: int, cols: int, count: int, rate: float) -> PackedFloat32Array:
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = Glsl.SYNTH
	var spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(src)
	if spirv == null or not spirv.compile_error_compute.is_empty():
		push_error("hidden sound shader: " + (spirv.compile_error_compute if spirv != null else "no compiler"))
		return PackedFloat32Array()
	var shader: RID = rd.shader_create_from_spirv(spirv, "Hidden picture synth")
	var pipeline: RID = rd.compute_pipeline_create(shader)
	var groups_total: int = int(ceil(float(count) / float(GROUP)))
	var amp_buf: RID = rd.storage_buffer_create(amps.size() * 4, amps.to_byte_array())
	var step_buf: RID = rd.storage_buffer_create(steps.size() * 4, steps.to_byte_array())
	var phase_buf: RID = rd.storage_buffer_create(phases.size() * 4, phases.to_byte_array())
	var out_buf: RID = rd.storage_buffer_create(count * 4)
	var max_buf: RID = rd.storage_buffer_create(maxi(groups_total, 1) * 4)
	var uniforms: Array[RDUniform] = []
	var bufs: Array[RID] = [amp_buf, step_buf, phase_buf, out_buf, max_buf]
	for i: int in bufs.size():
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		u.add_id(bufs[i])
		uniforms.append(u)
	var uset: RID = rd.uniform_set_create(uniforms, shader, 0)
	var fade: float = FADE_SECONDS * rate
	var per_col: float = float(count) / float(cols)
	var first: int = 0
	while first < count:
		var chunk: int = mini(CHUNK, count - first)
		var cl: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uset, 0)
		_push(rd, cl, 0, rows, cols, count, per_col, fade, 1.0, first, chunk)
		_go(rd, cl, chunk)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		first += chunk
	var cl2: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl2, pipeline)
	rd.compute_list_bind_uniform_set(cl2, uset, 0)
	_push(rd, cl2, 1, rows, cols, count, per_col, fade, 1.0, 0, count)
	_go(rd, cl2, groups_total * GROUP)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var maxima: PackedFloat32Array = rd.buffer_get_data(max_buf).to_float32_array()
	var peak: float = 0.0
	for m: float in maxima:
		peak = maxf(peak, m)
	var scale: float = 0.891 / peak if peak > 1e-9 else 1.0
	var cl3: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl3, pipeline)
	rd.compute_list_bind_uniform_set(cl3, uset, 0)
	_push(rd, cl3, 2, rows, cols, count, per_col, fade, scale, 0, count)
	_go(rd, cl3, count)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var out: PackedFloat32Array = rd.buffer_get_data(out_buf).to_float32_array()
	for rid: RID in [uset, amp_buf, step_buf, phase_buf, out_buf, max_buf, pipeline, shader]:
		if rid.is_valid():
			rd.free_rid(rid)
	return out


static func _push(rd: RenderingDevice, cl: int, mode: int, rows: int, cols: int, count: int, per_col: float, fade: float, scale: float, first: int, chunk: int) -> void:
	var bytes: PackedByteArray = PackedInt32Array([mode, rows, cols, count]).to_byte_array()
	bytes.append_array(PackedFloat32Array([per_col, fade, scale]).to_byte_array())
	bytes.append_array(PackedInt32Array([first, chunk, 0, 0, 0]).to_byte_array())
	rd.compute_list_set_push_constant(cl, bytes, bytes.size())


static func _go(rd: RenderingDevice, cl: int, threads: int) -> void:
	var groups: int = maxi(1, int(ceil(float(threads) / float(GROUP))))
	rd.compute_list_dispatch(cl, mini(groups, ROW_GROUPS), int(ceil(float(groups) / float(ROW_GROUPS))), 1)


## The same sound made on the CPU, for machines without the GPU renderer. Much slower.
static func synth_cpu(amps: PackedFloat32Array, steps: PackedInt32Array, phases: PackedFloat32Array, rows: int, cols: int, count: int, rate: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var per_col: float = float(count) / float(cols)
	var fade: float = FADE_SECONDS * rate
	for r: int in rows:
		var w: float = TAU * float(steps[r]) / float(STEP_ONE)
		var cr: float = cos(w)
		var sr: float = sin(w)
		var re: float = cos(phases[r])
		var im: float = sin(phases[r])
		var lit: bool = false
		for c: int in cols:
			if amps[c * rows + r] > 0.0:
				lit = true
				break
		if not lit:
			continue
		for i: int in count:
			var u: float = (float(i) + 0.5) / per_col - 0.5
			var c0: int = clampi(int(floor(u)), 0, cols - 1)
			var c1: int = mini(c0 + 1, cols - 1)
			var fr: float = clampf(u - floor(u), 0.0, 1.0) if u >= 0.0 else 0.0
			fr = fr * fr * (3.0 - 2.0 * fr)
			var a: float = lerpf(amps[c0 * rows + r], amps[c1 * rows + r], fr)
			out[i] += a * im
			var nre: float = re * cr - im * sr
			im = re * sr + im * cr
			re = nre
	var peak: float = 0.0
	for i2: int in count:
		var env: float = clampf(minf(float(i2), float(count - 1 - i2)) / maxf(fade, 1.0), 0.0, 1.0)
		out[i2] *= env
		peak = maxf(peak, absf(out[i2]))
	var scale: float = 0.891 / peak if peak > 1e-9 else 1.0
	for i3: int in count:
		out[i3] *= scale
	return out


## Draws words as a white on black picture, for hiding text.
static func text_picture(host: Node, text: String, height_px: int = 160) -> Image:
	var lines: PackedStringArray = text.strip_edges().split("\n")
	var font: Font = Tk.font("body_bold")
	var fs: int = maxi(8, int(float(height_px) * 0.72 / float(maxi(lines.size(), 1))))
	var width: float = 8.0
	for l: String in lines:
		width = maxf(width, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x)
	var line_h: float = font.get_height(fs)
	var pad: float = float(fs) * 0.35
	var vp := SubViewport.new()
	vp.size = Vector2i(int(ceil(width + pad * 2.0)), int(ceil(line_h * float(lines.size()) + pad * 2.0)))
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var label := Label.new()
	label.text = "\n".join(lines)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(pad, pad)
	label.size = Vector2(width, line_h * float(lines.size()))
	vp.add_child(label)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img


static func out_dir() -> String:
	return String((load("res://doc/io.gd") as GDScript).call("data_path", "hidden_sounds"))


static func save(result: Dictionary, base_name: String) -> String:
	var stem: String = ""
	for ch: String in base_name.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-":
			stem += ch
		elif not stem.ends_with("_"):
			stem += "_"
	stem = stem.strip_edges().trim_suffix("_")
	if stem.is_empty():
		stem = "hidden"
	var path: String = out_dir().path_join(stem.left(32) + "_" + str(Time.get_unix_time_from_system()).replace(".", "") + ".wav")
	if not SpectroSource.write_wav(path, result["samples"], int(result["rate"])):
		return ""
	return path
