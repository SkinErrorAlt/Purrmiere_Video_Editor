extends Control

const EffectRegistry := preload("res://engine/effect_registry.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const TYPES: PackedStringArray = ["black", "colour", "checkerboard", "picture", "video", "generator"]
const TYPE_LABELS: Dictionary = {"black": "Black", "colour": "Colour", "checkerboard": "Checkerboard", "picture": "Picture", "video": "Video", "generator": "Generator"}
const FITS: PackedStringArray = ["fill", "fit", "stretch", "tile"]
const FIT_LABELS: Dictionary = {"fill": "Fill", "fit": "Fit", "stretch": "Stretch", "tile": "Tile"}
const PREF_TYPE := "program.backdrop.type"
const PREF_COLOUR := "program.backdrop.colour"
const PREF_PICTURE := "program.backdrop.picture"
const PREF_VIDEO := "program.backdrop.video"
const PREF_GENERATOR := "program.backdrop.generator"
const PREF_FIT := "program.backdrop.fit"
const PREF_IN_EXPORT := "program.backdrop.in_export"
const DEFAULT_COLOUR := "#808080"
const DEFAULT_GENERATOR := "plasma"
const GENERATE_CATEGORY := "Generate"
const CHECKER_SQUARE := 16
const CHECKER_LIGHT := Color(0.42, 0.42, 0.42, 1.0)
const CHECKER_DARK := Color(0.27, 0.27, 0.27, 1.0)
const Z_BOTTOM := -4000
const VIDEO_QUALITY := 0

var spec: Dictionary = {}
var stage_px: Vector2i = Vector2i(2, 2)
var seq_px: Vector2i = Vector2i(2, 2)
var quality_scale: float = 1.0
var drawn_type: String = "black"
var fallback_reason: String = ""
var pending: bool = false
var _registry: RefCounted = null
var _picture: Texture2D = null
var _checker: ImageTexture = null
var _source: FrameSource = null
var _video_handle: int = -1
var _video_duration: float = 0.0
var _gen_pass: EffectPass = null
var _gen_def: Dictionary = {}
var _gen_input: ImageTexture = null
var _warned: Dictionary = {}
var _stamp: String = ""


static func ensure_prefs(prefs: Node, registry: RefCounted = null) -> void:
	if prefs == null or not prefs.has_method("is_registered"):
		return
	var gens: PackedStringArray = generator_ids(registry)
	if gens.is_empty():
		gens.append(DEFAULT_GENERATOR)
	var specs: Array = [
		[PREF_TYPE, "black", {"label": "Backdrop: what shows where no clip covers the frame", "type": "enum", "choices": Array(TYPES)}],
		[PREF_COLOUR, DEFAULT_COLOUR, {"label": "Backdrop colour (hex, for example #808080)", "type": "string"}],
		[PREF_PICTURE, "", {"label": "Backdrop picture file", "type": "string"}],
		[PREF_VIDEO, "", {"label": "Backdrop video file (it loops)", "type": "string"}],
		[PREF_GENERATOR, DEFAULT_GENERATOR if gens.has(DEFAULT_GENERATOR) else gens[0], {"label": "Backdrop generator effect", "type": "enum", "choices": Array(gens)}],
		[PREF_FIT, "fill", {"label": "Backdrop picture and video fit", "type": "enum", "choices": Array(FITS)}],
		[PREF_IN_EXPORT, false, {"label": "Render the backdrop into exports", "type": "bool"}],
	]
	for s: Array in specs:
		if not bool(prefs.call("is_registered", String(s[0]))):
			prefs.call("register", String(s[0]), s[1], s[2])


static func generator_ids(registry: RefCounted = null) -> PackedStringArray:
	var reg: RefCounted = registry if registry != null else EffectRegistry.shared()
	var out: PackedStringArray = PackedStringArray()
	if reg == null:
		return out
	for d: Dictionary in reg.call("list"):
		if String(d.get("category", "")) == GENERATE_CATEGORY and not (d.get("passes", []) as Array).is_empty():
			out.append(String(d["id"]))
	out.sort()
	return out


static func parse_colour(text: String, fallback: Color = Color(0.5, 0.5, 0.5, 1.0)) -> Color:
	var t: String = text.strip_edges()
	if t.is_empty():
		return fallback
	if not t.begins_with("#"):
		t = "#" + t
	if not Color.html_is_valid(t):
		return fallback
	var c: Color = Color.html(t)
	c.a = 1.0
	return c


static func spec_from_prefs(prefs: Node) -> Dictionary:
	if prefs == null or not bool(prefs.call("is_registered", PREF_TYPE)):
		return {"type": "black", "colour": Color.BLACK, "picture": "", "video": "", "generator": DEFAULT_GENERATOR, "fit": "fill", "in_export": false}
	var t: String = String(prefs.call("get_value", PREF_TYPE))
	var f: String = String(prefs.call("get_value", PREF_FIT))
	return {
		"type": t if TYPES.has(t) else "black",
		"colour": parse_colour(String(prefs.call("get_value", PREF_COLOUR))),
		"picture": String(prefs.call("get_value", PREF_PICTURE)),
		"video": String(prefs.call("get_value", PREF_VIDEO)),
		"generator": String(prefs.call("get_value", PREF_GENERATOR)),
		"fit": f if FITS.has(f) else "fill",
		"in_export": bool(prefs.call("get_value", PREF_IN_EXPORT)),
	}


static func fit_rect(content: Vector2, frame: Vector2, fit: String) -> Rect2:
	if content.x <= 0.0 or content.y <= 0.0 or fit == "stretch":
		return Rect2(Vector2.ZERO, frame)
	var k: float = 1.0
	if fit == "fit":
		k = minf(frame.x / content.x, frame.y / content.y)
	elif fit == "tile":
		k = 1.0
	else:
		k = maxf(frame.x / content.x, frame.y / content.y)
	var sz: Vector2 = content * k
	if fit == "tile":
		return Rect2(Vector2.ZERO, frame)
	return Rect2((frame - sz) * 0.5, sz)


static func stamp_of(s: Dictionary) -> String:
	var t: String = String(s.get("type", "black"))
	var parts: PackedStringArray = PackedStringArray([t])
	if t == "picture":
		parts.append(String(s.get("picture", "")))
	elif t == "video":
		parts.append(String(s.get("video", "")))
	elif t == "generator":
		parts.append(String(s.get("generator", "")))
	return "|".join(parts)


func _init() -> void:
	name = "Backdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z_BOTTOM
	z_as_relative = false
	position = Vector2.ZERO


func _events() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Events")
	return null


func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PurrBridge")
	return null


func _warn(key: String, text: String, detail: String) -> void:
	fallback_reason = text
	if _warned.has(key):
		return
	_warned[key] = true
	var ev: Node = _events()
	if ev != null:
		ev.call("warn", text, detail)


func requested_type() -> String:
	return String(spec.get("type", "black"))


func apply(s: Dictionary, registry: RefCounted = null) -> void:
	if registry != null:
		_registry = registry
	if _registry == null:
		_registry = EffectRegistry.shared()
	var next_stamp: String = stamp_of(s)
	spec = s.duplicate(true)
	if next_stamp != _stamp:
		_stamp = next_stamp
		_rebuild()
	_apply_sampling()
	queue_redraw()


func _apply_sampling() -> void:
	var fit: String = String(spec.get("fit", "fill"))
	var repeat: bool = drawn_type == "checkerboard" or ((drawn_type == "picture" or drawn_type == "video") and fit == "tile")
	var want_repeat: CanvasItem.TextureRepeat = CanvasItem.TEXTURE_REPEAT_ENABLED if repeat else CanvasItem.TEXTURE_REPEAT_DISABLED
	var want_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST if drawn_type == "checkerboard" else CanvasItem.TEXTURE_FILTER_LINEAR
	if texture_repeat != want_repeat:
		texture_repeat = want_repeat
	if texture_filter != want_filter:
		texture_filter = want_filter


func _release() -> void:
	_picture = null
	if _source != null and is_instance_valid(_source):
		remove_child(_source)
		_source.queue_free()
	_source = null
	if _video_handle >= 0:
		var b: Node = _bridge()
		if b != null:
			b.call("close_media", _video_handle)
	_video_handle = -1
	_video_duration = 0.0
	if _gen_pass != null and is_instance_valid(_gen_pass):
		remove_child(_gen_pass)
		_gen_pass.queue_free()
	_gen_pass = null
	_gen_def = {}


func _rebuild() -> void:
	_release()
	fallback_reason = ""
	pending = false
	var t: String = requested_type()
	drawn_type = t if TYPES.has(t) else "black"
	if drawn_type == "picture":
		_load_picture(String(spec.get("picture", "")))
	elif drawn_type == "video":
		_open_video(String(spec.get("video", "")))
	elif drawn_type == "generator":
		_build_generator(String(spec.get("generator", "")))
	elif drawn_type == "checkerboard":
		_ensure_checker()
	_apply_sampling()


func _fall_back(key: String, text: String, detail: String) -> void:
	_release()
	drawn_type = "black"
	pending = false
	_warn(key, text, detail)
	_apply_sampling()


static func _real_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _load_picture(path: String) -> void:
	if path.strip_edges().is_empty():
		_fall_back("picture:none", "The backdrop is set to a picture, but no picture file is chosen, so it is black", "Pick one in the Program menu, Backdrop, Picture")
		return
	var img: Image = Image.new()
	if not FileAccess.file_exists(_real_path(path)) or img.load(_real_path(path)) != OK or img.is_empty():
		_fall_back("picture:" + path, "The backdrop picture could not be opened, so the backdrop is black", path)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.premultiply_alpha()
	_picture = ImageTexture.create_from_image(img)


func _open_video(path: String) -> void:
	if path.strip_edges().is_empty():
		_fall_back("video:none", "The backdrop is set to a video, but no video file is chosen, so it is black", "Pick one in the Program menu, Backdrop, Video")
		return
	if not FileAccess.file_exists(_real_path(path)):
		_fall_back("video:" + path, "The backdrop video could not be opened, so the backdrop is black", path)
		return
	var b: Node = _bridge()
	if b == null or not bool(b.get("available")):
		_fall_back("video:engine", "A video backdrop needs the engine (purrcore), so the backdrop is black", path)
		return
	var h: int = int(b.call("open_media", _real_path(path), {}))
	if h < 0:
		_fall_back("video:" + path, "The backdrop video could not be opened, so the backdrop is black", path)
		return
	_video_handle = h
	if b.has_signal("media_failed") and not b.is_connected("media_failed", _on_media_failed):
		b.connect("media_failed", _on_media_failed)
	_source = FrameSource.new()
	_source.name = "BackdropVideo"
	add_child(_source)
	_source.setup(FrameSource.KIND_NATIVE, null, stage_px, h)
	pending = true


func _on_media_failed(h: int, why: String) -> void:
	if h != _video_handle or _video_handle < 0:
		return
	var path: String = String(spec.get("video", ""))
	_video_handle = -1
	_fall_back("video:" + path, "The backdrop video could not be opened, so the backdrop is black", path + (": " + why if not why.is_empty() else ""))
	queue_redraw()


func _build_generator(id: String) -> void:
	var def: Dictionary = _registry.call("get_def", id) if _registry != null else {}
	if def.is_empty() or String(def.get("category", "")) != GENERATE_CATEGORY or (def.get("passes", []) as Array).is_empty():
		_fall_back("gen:" + id, "The backdrop generator " + (id if not id.is_empty() else "(none)") + " is not an effect in the Generate category, so the backdrop is black", id)
		return
	var first: Dictionary = (def["passes"] as Array)[0]
	if not bool(_registry.call("shader_ok", String(first.get("shader", "")))):
		_fall_back("gen:" + id, "The backdrop generator " + id + " did not compile, so the backdrop is black", String(first.get("shader", "")))
		return
	var mat: ShaderMaterial = _registry.call("make_material", id, 0)
	if mat == null:
		_fall_back("gen:" + id, "The backdrop generator " + id + " could not be built, so the backdrop is black", id)
		return
	_gen_def = def
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	_gen_input = ImageTexture.create_from_image(img)
	_gen_pass = EffectPass.new()
	_gen_pass.name = "BackdropGenerator"
	_gen_pass.setup(mat, _registry.call("uniform_types", id, 0))
	_gen_pass.set_input(_gen_input)
	_gen_pass.set_size_px(stage_px)
	for p: Variant in def.get("params", []):
		var pd: Dictionary = p
		var type: String = String(pd.get("type", ""))
		if type == "texture" or type == "layer" or type == "curve":
			continue
		_gen_pass.set_param(String(pd["key"]), pd.get("default"))
	add_child(_gen_pass)


func _ensure_checker() -> void:
	if _checker != null:
		return
	var n: int = CHECKER_SQUARE * 2
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var light: bool = ((x / CHECKER_SQUARE) + (y / CHECKER_SQUARE)) % 2 == 0
			img.set_pixel(x, y, CHECKER_LIGHT if light else CHECKER_DARK)
	_checker = ImageTexture.create_from_image(img)


func update(t: float, exact: bool, playing_: bool, stage: Vector2i, seq_size: Vector2i, q: float) -> void:
	var resized: bool = stage != stage_px or seq_size != seq_px or not is_equal_approx(q, quality_scale)
	stage_px = stage
	seq_px = seq_size
	quality_scale = q
	size = Vector2(stage)
	position = Vector2.ZERO
	if not visible:
		pending = false
		return
	if drawn_type == "video" and _source != null and _video_handle >= 0:
		_update_video(t, exact, playing_)
	elif drawn_type == "generator" and _gen_pass != null:
		_update_generator(t)
	else:
		pending = false
	if resized or drawn_type == "video":
		queue_redraw()


func _update_video(t: float, exact: bool, playing_: bool) -> void:
	var b: Node = _bridge()
	if b == null:
		return
	if _video_duration <= 0.0:
		var info: Dictionary = b.call("media_info", _video_handle)
		_video_duration = float(info.get("duration", 0.0))
	var local: float = fposmod(t, _video_duration) if _video_duration > 0.0 else maxf(t, 0.0)
	var hint: int = 2 if exact else (1 if playing_ else 0)
	_source.request(local, VIDEO_QUALITY, hint)
	pending = _source.state == "pending" or _source.state == "none" or _source.state == "approx"


func _update_generator(t: float) -> void:
	_gen_pass.set_size_px(stage_px)
	_gen_pass.set_param("tex_size", Vector2(stage_px))
	_gen_pass.set_param("seq_size", Vector2(seq_px))
	_gen_pass.set_param("time", t)
	_gen_pass.set_param("clip_time", t)
	_gen_pass.set_param("clip_duration", maxf(t, 1.0))
	_gen_pass.set_param("px_scale", quality_scale)
	pending = false


func content_texture() -> Texture2D:
	if drawn_type == "picture":
		return _picture
	if drawn_type == "video" and _source != null:
		return _source.texture()
	if drawn_type == "generator" and _gen_pass != null:
		return _gen_pass.output()
	if drawn_type == "checkerboard":
		return _checker
	return null


func content_size() -> Vector2:
	if drawn_type == "picture" and _picture != null:
		return Vector2(_picture.get_size())
	if drawn_type == "video" and _source != null:
		return Vector2(_source.native_size)
	return Vector2(seq_px)


func _draw() -> void:
	var frame: Vector2 = Vector2(seq_px)
	var q: float = maxf(quality_scale, 0.0001)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(q, q))
	if drawn_type == "colour":
		draw_rect(Rect2(Vector2.ZERO, frame), spec.get("colour", Color.BLACK), true)
		return
	draw_rect(Rect2(Vector2.ZERO, frame), Color.BLACK, true)
	var tex: Texture2D = content_texture()
	if tex == null:
		return
	if drawn_type == "checkerboard":
		draw_texture_rect(tex, Rect2(Vector2.ZERO, frame), true)
		return
	if drawn_type == "generator":
		draw_texture_rect(tex, Rect2(Vector2.ZERO, frame), false)
		return
	var fit: String = String(spec.get("fit", "fill"))
	if fit == "tile":
		var tile_px: Vector2 = content_size()
		var tiles: Vector2 = Vector2(frame.x / maxf(tile_px.x, 1.0), frame.y / maxf(tile_px.y, 1.0))
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, frame), Rect2(Vector2.ZERO, Vector2(tex.get_size()) * tiles))
		return
	draw_texture_rect(tex, fit_rect(content_size(), frame, fit), false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _video_handle >= 0:
			var b: Node = _bridge()
			if b != null:
				b.call("close_media", _video_handle)
			_video_handle = -1
