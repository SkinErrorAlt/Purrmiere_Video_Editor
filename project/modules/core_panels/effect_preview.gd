extends Node

const PmCompositor := preload("res://engine/compositor.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PREVIEW_W := 256
const FALLBACK_SOURCE_W := 1920
const PX_UNITS: PackedStringArray = ["px", "px/s"]
const SCALED_TYPES: PackedStringArray = ["float", "int", "vec2"]
const FRAME_DIR := "user://purr_preview/"

var comp: Node = null
var doc: Project = null
var seq: Sequence = null
var clip: Clip = null
var frame_path: String = ""
var effect_id: String = ""
var source_width: int = 0
var _serial: int = 0
var _reads_px_scale: Dictionary = {}


static func available() -> bool:
	return PmCompositor.has_gpu()


static func sample_frame(w: int, h: int) -> Image:
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, FrameSource.pattern_bytes(0.35, w, h))


static func is_blank(img: Image) -> bool:
	if img == null or img.is_empty():
		return true
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in range(0, h, maxi(h / 12, 1)):
		for x: int in range(0, w, maxi(w / 12, 1)):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.05 and (c.r > 0.02 or c.g > 0.02 or c.b > 0.02):
				return false
	return true


func _init() -> void:
	name = "EffectPreview"


func set_source_width(w: int) -> void:
	source_width = maxi(w, 0)


func host_sequence() -> Sequence:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var node: Node = (loop as SceneTree).root.get_node_or_null("Session")
	if node == null or not node.has_method("seq"):
		return null
	var s: Variant = node.call("seq")
	if s is Sequence:
		return s
	return null


func sequence_width() -> int:
	if source_width > 0:
		return source_width
	var s: Sequence = host_sequence()
	if s != null and s.width > 0:
		return s.width
	return FALLBACK_SOURCE_W


func px_ratio() -> float:
	if seq == null or seq.width <= 0:
		return 1.0
	return clampf(float(seq.width) / float(maxi(sequence_width(), 1)), 0.001, 100.0)


func set_frame(img: Image) -> bool:
	if not available():
		return false
	var src: Image = img
	if is_blank(src):
		src = sample_frame(PREVIEW_W, int(round(float(PREVIEW_W) * 9.0 / 16.0)))
	var small: Image = src.duplicate()
	small.convert(Image.FORMAT_RGBA8)
	var aspect: float = float(small.get_height()) / maxf(float(small.get_width()), 1.0)
	var h: int = clampi(int(round(float(PREVIEW_W) * aspect)), 16, PREVIEW_W * 2)
	small.resize(PREVIEW_W, h, Image.INTERPOLATE_BILINEAR)
	var opaque: Image = Image.create(small.get_width(), small.get_height(), false, Image.FORMAT_RGBA8)
	opaque.fill(Color.BLACK)
	opaque.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i.ZERO)
	small = opaque
	_serial += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	var path: String = ProjectSettings.globalize_path(FRAME_DIR + "frame_" + str(get_instance_id()) + "_" + str(_serial) + ".png")
	if small.save_png(path) != OK:
		return false
	if not frame_path.is_empty():
		DirAccess.remove_absolute(frame_path)
	frame_path = path
	_build(small.get_width(), small.get_height())
	return true


func _build(w: int, h: int) -> void:
	if doc == null:
		doc = Project.create("effect preview", 1, 0, 30.0)
		seq = doc.active_sequence()
	seq.width = w
	seq.height = h
	var m: MediaItem = MediaItem.new()
	m.id = "preview_frame_" + str(_serial)
	m.kind = "image"
	m.path = frame_path
	m.width = w
	m.height = h
	m.duration = 10.0
	m.probed = true
	doc.media.clear()
	doc.media.append(m)
	if clip == null:
		clip = Clip.new()
		clip.id = "preview_clip"
		clip.start = 0.0
		clip.duration = 10.0
		seq.video_tracks[0].clips.append(clip)
	clip.media_id = m.id
	seq.invalidate()
	if comp == null:
		comp = PmCompositor.new()
		add_child(comp)
		if "backdrop_hidden" in comp:
			comp.set("backdrop_hidden", true)
		comp.call("set_sequence", seq, doc)
		comp.call("set_quality", 0)
	else:
		comp.call("set_sequence", seq, doc)
	_apply_px_ratio()


func _apply_px_ratio() -> void:
	if comp != null and comp.has_method("set_px_scale_bias"):
		comp.call("set_px_scale_bias", px_ratio())


func reads_px_scale(def: Dictionary) -> bool:
	var id: String = String(def.get("id", ""))
	if _reads_px_scale.has(id):
		return bool(_reads_px_scale[id])
	var found: bool = false
	var reg: RefCounted = EffectSource.registry()
	var passes: Array = def.get("passes", [])
	for i: int in passes.size():
		if reg != null and reg.has_method("uniform_types"):
			var types: Dictionary = reg.call("uniform_types", id, i)
			if types.has("px_scale"):
				found = true
				break
		var path: String = String((passes[i] as Dictionary).get("shader", ""))
		if not path.is_empty() and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("px_scale"):
			found = true
			break
	if not id.is_empty():
		_reads_px_scale[id] = found
	return found


static func scaled_value(type: String, base: Variant, r: float) -> Variant:
	if type == "vec2":
		if base is Array and (base as Array).size() >= 2:
			return [float(base[0]) * r, float(base[1]) * r]
		return base
	if base is Array or base is Dictionary or base is String or base is bool:
		return base
	var f: float = float(base) * r
	if type == "int":
		var n: int = int(round(f))
		if n < 1 and float(base) >= 1.0:
			n = 1
		return float(n)
	return f


func preview_entry(def: Dictionary) -> Dictionary:
	var entry: Dictionary = EffectCmds.EffectCommand.entry_from_def(def, "preview_fx")
	var r: float = px_ratio()
	if is_equal_approx(r, 1.0) or reads_px_scale(def):
		return entry
	var params: Dictionary = entry.get("params", {})
	for p: Variant in def.get("params", []):
		var spec: Dictionary = p
		var key: String = String(spec.get("key", ""))
		if key.is_empty() or not params.has(key):
			continue
		if not PX_UNITS.has(String(spec.get("unit", "")).strip_edges()):
			continue
		var type: String = String(spec.get("type", "float"))
		if not SCALED_TYPES.has(type):
			continue
		params[key] = AnimProp.make(scaled_value(type, spec.get("default", 0.0), r))
	return entry


func show_effect(id: String) -> bool:
	if comp == null or clip == null:
		return false
	var def: Dictionary = EffectSource.get_def(id)
	if def.is_empty() or bool(def.get("audio", false)):
		return false
	effect_id = id
	clip.effects = [preview_entry(def)]
	_apply_px_ratio()
	comp.call("render_time", 1.0, true)
	return true


func texture() -> Texture2D:
	if comp == null:
		return null
	return comp.call("texture")


func size_px() -> Vector2i:
	if seq == null:
		return Vector2i(PREVIEW_W, PREVIEW_W * 9 / 16)
	return Vector2i(seq.width, seq.height)


func _exit_tree() -> void:
	if not frame_path.is_empty():
		DirAccess.remove_absolute(frame_path)
		frame_path = ""
