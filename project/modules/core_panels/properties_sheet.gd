extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Timecode := preload("res://doc/timecode.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const SELF_PATH := "res://modules/core_panels/properties_sheet.gd"
const MADE_KINDS: PackedStringArray = ["title", "shape", "adjust", "generator"]
const NOT_REPORTED := "not reported by the engine"

var sheet: Control = null
var media_id: String = ""
var rows: Array[Dictionary] = []


static func open(host: Node, doc: Project, m: MediaItem, reveal: Callable, edit: Callable) -> Node:
	var script: GDScript = load(SELF_PATH)
	var p: Node = script.new()
	p.call("build", host, doc, m, reveal, edit)
	return p


static func handle_of(m: MediaItem) -> int:
	var h: Variant = Session.media_handles.get(m.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		return int(h)
	return m.handle


static func uses(doc: Project, m: MediaItem) -> int:
	var n: int = 0
	for s: Sequence in doc.sequences:
		for c: Clip in s.all_clips():
			if c.media_id == m.id:
				n += 1
	return n


static func size_text(bytes: int) -> String:
	if bytes < 0:
		return "unknown"
	if bytes < 1024:
		return str(bytes) + " bytes"
	if bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	if bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (float(bytes) / 1048576.0)
	return "%.2f GB" % (float(bytes) / 1073741824.0)


static func file_size(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return -1
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n: int = f.get_length()
	f.close()
	return n


static func wav_bits(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	if f.get_length() < 36:
		f.close()
		return 0
	var riff: String = f.get_buffer(4).get_string_from_ascii()
	f.get_32()
	var wave: String = f.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF" or wave != "WAVE":
		f.close()
		return 0
	var guard: int = 0
	while f.get_position() + 8 <= f.get_length() and guard < 64:
		guard += 1
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var size: int = f.get_32()
		if id == "fmt ":
			f.get_16()
			f.get_16()
			f.get_32()
			f.get_32()
			f.get_16()
			var bits: int = f.get_16()
			f.close()
			return bits
		f.seek(f.get_position() + size + (size & 1))
	f.close()
	return 0


static func image_bits(path: String) -> String:
	var img: Image = Image.new()
	if img.load(path) != OK:
		return ""
	var fmt: Image.Format = img.get_format()
	if fmt == Image.FORMAT_RGBAF or fmt == Image.FORMAT_RGBF or fmt == Image.FORMAT_RF or fmt == Image.FORMAT_RGF:
		return "32-bit float"
	if fmt == Image.FORMAT_RGBAH or fmt == Image.FORMAT_RGBH or fmt == Image.FORMAT_RH or fmt == Image.FORMAT_RGH:
		return "16-bit float"
	var alpha: bool = fmt == Image.FORMAT_RGBA8 or fmt == Image.FORMAT_LA8
	return "8-bit" + (" with alpha" if alpha else "")


static func bit_depth(m: MediaItem, raw: Dictionary) -> String:
	var reported: int = int(raw.get("bit_depth", 0))
	if reported > 0:
		return str(reported) + "-bit"
	if m.kind == "image" and not m.path.is_empty() and FileAccess.file_exists(m.path):
		var t: String = image_bits(m.path)
		if not t.is_empty():
			return t
	if m.path.get_extension().to_lower() == "wav" and FileAccess.file_exists(m.path):
		var b: int = wav_bits(m.path)
		if b > 0:
			return str(b) + "-bit"
	if m.kind == "sequence" or m.kind in MADE_KINDS:
		return "8-bit"
	return NOT_REPORTED


static func codec_text(m: MediaItem, raw: Dictionary) -> String:
	if m.kind == "sequence":
		return "Purrmiere sequence"
	if m.kind in MADE_KINDS:
		return "Made in Purrmiere"
	if m.kind == "image":
		return m.path.get_extension().to_upper() + " image"
	var codec: String = String(raw.get("codec", ""))
	var container: String = String(raw.get("container", ""))
	if codec.is_empty():
		if not m.path.is_empty() and not FileAccess.file_exists(m.path):
			return "the file is missing"
		if not PurrBridge.available:
			return "the engine is not loaded"
		return "not read yet"
	return codec + (" in " + container if not container.is_empty() else "")


static func streams_text(m: MediaItem) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if m.kind == "video" and not m.audio_only:
		parts.append("1 video")
	var audio: int = m.audio_streams.size()
	if audio == 0 and (m.has_audio or m.kind == "audio"):
		audio = 1
	if audio > 0:
		parts.append(str(audio) + " audio")
	if parts.is_empty():
		return "picture only" if m.kind != "audio" else "none"
	return ", ".join(parts)


static func sample_text(m: MediaItem) -> String:
	if m.audio_streams.is_empty():
		return "no sound" if not m.has_audio else NOT_REPORTED
	var sd: Dictionary = m.audio_streams[0]
	var rate: int = int(sd.get("sample_rate", 0))
	var ch: int = int(sd.get("channels", 0))
	var rate_t: String = (String.num(float(rate) / 1000.0, 1).trim_suffix(".0") + " kHz") if rate > 0 else "unknown rate"
	var ch_t: String = "mono" if ch == 1 else ("stereo" if ch == 2 else str(ch) + " channels")
	return rate_t + ", " + ch_t


static func facts(doc: Project, m: MediaItem) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or m == null:
		return out
	var h: int = handle_of(m)
	var raw: Dictionary = MediaLoader.raw_info(h) if h >= 0 and PurrBridge.available else {}
	var w: int = m.width
	var ht: int = m.height
	var fps: float = m.fps
	if m.kind == "sequence":
		var s: Sequence = doc.sequence_by_id(m.sequence_id)
		if s != null:
			w = s.width
			ht = s.height
			fps = s.fps
	out.append({"key": "Codec", "value": codec_text(m, raw)})
	out.append({"key": "Frame size", "value": (str(w) + " x " + str(ht)) if w > 0 and ht > 0 else "none", "mono": true})
	out.append({"key": "Frame rate", "value": String.num(fps, 3) if fps > 0.0 else "none", "mono": true})
	var dur: float = doc.media_duration(m)
	out.append({"key": "Duration", "value": Timecode.format(dur, fps if fps > 0.0 else 30.0, false), "mono": true})
	out.append({"key": "Streams", "value": streams_text(m)})
	var roles: String = StreamRoles.summary(m)
	if not roles.is_empty():
		out.append({"key": "Audio track names", "value": roles, "wrap": true})
	out.append({"key": "Bit depth", "value": bit_depth(m, raw)})
	if raw.has("colorspace"):
		out.append({"key": "Colour", "value": String(raw["colorspace"]) + (", full range" if bool(raw.get("full_range", false)) else ", limited range")})
	out.append({"key": "Sample rate", "value": sample_text(m)})
	var bytes: int = file_size(m.path)
	out.append({"key": "Size on disk", "value": size_text(bytes) if bytes >= 0 else ("missing" if not m.path.is_empty() else "no file"), "mono": bytes >= 0})
	out.append({"key": "Path", "value": m.path if not m.path.is_empty() else "no file on disk", "wrap": true, "mono": not m.path.is_empty()})
	return out


func value_of(key: String) -> String:
	for r: Dictionary in rows:
		if String(r["key"]) == key:
			return String(r["value"])
	return ""


func build(host: Node, doc: Project, m: MediaItem, reveal: Callable, edit: Callable) -> void:
	name = "PropertiesSheet"
	media_id = m.id
	rows = facts(doc, m)
	sheet = Sheet.open(host, m.label, 480.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var n: int = uses(doc, m)
	col.add_child(PmLabel.meta(m.kind + ", used by " + str(n) + (" clip" if n == 1 else " clips")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tk.px(10.0))
	grid.add_theme_constant_override("v_separation", Tk.px(5.0))
	for r: Dictionary in rows:
		var k: Label = PmLabel.body(String(r["key"]), "text_dim")
		k.custom_minimum_size.x = float(Tk.px(110.0))
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(k)
		var v: Label
		if bool(r.get("wrap", false)):
			v = PmLabel.wrap(String(r["value"]))
			v.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			v.custom_minimum_size.x = float(Tk.px(320.0))
		else:
			v = PmLabel.body(String(r["value"]))
		if bool(r.get("mono", false)):
			v.add_theme_font_override("font", Tk.font("mono"))
		grid.add_child(v)
	col.add_child(grid)
	var has_file: bool = not m.path.is_empty() and FileAccess.file_exists(m.path)
	var rb: Button = sheet.call("add_button", "Reveal in Explorer")
	rb.disabled = not has_file
	if reveal.is_valid():
		rb.pressed.connect(reveal.bind(m.id))
	var eb: Button = sheet.call("add_button", "Edit original")
	eb.disabled = not has_file
	if edit.is_valid():
		eb.pressed.connect(edit.bind(m.id))
	var cb: Button = sheet.call("add_button", "Close", true)
	cb.pressed.connect(_on_close)


func _on_close() -> void:
	sheet.call("close")
