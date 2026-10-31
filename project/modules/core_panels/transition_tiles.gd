extends RefCounted

const PmText := preload("res://ui/kit/pm_text.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const CLASSIC_SHADER := "res://engine/transition_classic_preview.gdshader"
const THUMB_W := 116.0
const PIC_W := 192
const PIC_H := 108
const PER_FRAME := 3
const LOOP_S := 1.4
const HOLD_S := 0.4
const REST_PROGRESS := 0.45
const ID_META := "transition_id"

static var _pics: Array[Texture2D] = []
static var _frame: int = -1
static var _used: int = 0
static var renders: int = 0
static var _classic: Dictionary = {}


static func pictures() -> Array[Texture2D]:
	if _pics.size() == 2:
		return _pics
	var a: Image = Image.create(PIC_W, PIC_H, false, Image.FORMAT_RGBA8)
	var b: Image = Image.create(PIC_W, PIC_H, false, Image.FORMAT_RGBA8)
	var sun: Vector2 = Vector2(PIC_W * 0.68, PIC_H * 0.42)
	var moon: Vector2 = Vector2(PIC_W * 0.3, PIC_H * 0.38)
	for y: int in PIC_H:
		for x: int in PIC_W:
			var u: float = float(x) / float(PIC_W - 1)
			var v: float = float(y) / float(PIC_H - 1)
			var sky: Color = Color(0.98, 0.62, 0.33).lerp(Color(0.86, 0.33, 0.48), v)
			var hill: float = 0.72 + 0.08 * sin(u * 6.0 + 0.6) + 0.04 * sin(u * 15.0)
			var ca: Color = sky
			if (Vector2(x, y) - sun).length() < PIC_H * 0.16:
				ca = Color(1.0, 0.92, 0.62)
			if v > hill:
				ca = Color(0.26, 0.15, 0.27).lerp(Color(0.16, 0.09, 0.18), (v - hill) * 3.0)
			var cb: Color = Color(0.12, 0.42, 0.62).lerp(Color(0.05, 0.18, 0.36), v)
			if v > 0.66 + 0.05 * sin(u * 9.0 + 1.3):
				cb = Color(0.07, 0.55, 0.52).lerp(Color(0.03, 0.3, 0.32), v)
			if (Vector2(x, y) - moon).length() < PIC_H * 0.14:
				cb = Color(0.93, 0.96, 1.0)
			a.set_pixel(x, y, ca)
			b.set_pixel(x, y, cb)
	_pics = [ImageTexture.create_from_image(a), ImageTexture.create_from_image(b)]
	return _pics


static func claim() -> bool:
	var f: int = Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_used = 0
	if _used >= PER_FRAME:
		return false
	_used += 1
	renders += 1
	return true


static func thumb_size() -> Vector2:
	var w: float = round(float(Tk.px(THUMB_W)))
	return Vector2(w, round(w * 0.5625))


static func preview_info(def: Dictionary) -> Dictionary:
	var id: String = String(def.get("preview_id", def.get("id", "")))
	if bool(def.get("classic", false)):
		if _classic.is_empty():
			var sh: Shader = load(CLASSIC_SHADER)
			var uniforms: Dictionary = {}
			if sh != null:
				for u: Dictionary in sh.get_shader_uniform_list(true):
					uniforms[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
			_classic = {"ok": sh != null, "shader": sh, "uniforms": uniforms, "reason": ""}
		var out: Dictionary = _classic.duplicate()
		out["values"] = {"kind": int(LayerChain.TRANSITION_KINDS.get(id, 1))}
		return out
	if not bool(TransitionRegistry.shared().call("has", id)) and TransitionRegistry.is_classic(id):
		var cdef: Dictionary = def.duplicate()
		cdef["classic"] = true
		cdef["id"] = id
		cdef.erase("preview_id")
		return preview_info(cdef)
	var reg: RefCounted = TransitionRegistry.shared()
	var info: Dictionary = reg.call("shader_info", id)
	var values: Dictionary = {}
	for p: Variant in def.get("params", []):
		values[String((p as Dictionary)["key"])] = (p as Dictionary)["default"]
	var res: Dictionary = info.duplicate()
	res["values"] = values
	return res


static func make_tile(def: Dictionary, current: bool, is_default: bool) -> Control:
	var id: String = String(def.get("id", ""))
	var tile: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	var side: Vector2 = thumb_size()
	tile.custom_minimum_size = Vector2(side.x, 0.0)
	tile.set_meta(ID_META, id)
	tile.name = "Tile_" + id
	var thumb: Control = _Thumb.new()
	thumb.name = "Thumb"
	thumb.custom_minimum_size = side
	thumb.call("setup", def, current, is_default)
	tile.add_child(thumb)
	var name_label: Label = PmLabel.trim(String(def.get("label", id)), "text_bright" if current else "text")
	name_label.name = "Name"
	name_label.custom_minimum_size.x = side.x
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_child(name_label)
	PmUI.tip(thumb, tip_for(def, is_default))
	return tile


static func tip_for(def: Dictionary, is_default: bool) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(String(def.get("label", "")) + " (" + String(def.get("group", "")) + ", " + String(def.get("space", "2D")) + ")")
	var blurb: String = String(def.get("blurb", ""))
	if not blurb.is_empty():
		parts.append(blurb)
	var from: Array = def.get("from", [])
	if not from.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for f: Variant in from:
			names.append(String(f))
		parts.append("Like: " + ", ".join(names))
	if is_default:
		parts.append("This is the default transition.")
	return "\n".join(parts)


static func thumb_of(tile: Control) -> Control:
	return tile.get_node_or_null("Thumb") as Control


class _Thumb:
	extends Control

	const Tiles := preload("res://modules/core_panels/transition_tiles.gd")
	const TransitionRegistry := preload("res://engine/transition_registry.gd")

	var transition_id: String = ""
	var current: bool = false
	var is_default: bool = false
	var space: String = "2D"
	var broken: String = ""
	var rendered: bool = false
	var live: bool = false
	var progress: float = Tiles.REST_PROGRESS
	var _clock: float = 0.0
	var _hover: bool = false
	var _def: Dictionary = {}
	var vp: SubViewport = null
	var rect: ColorRect = null
	var mat: ShaderMaterial = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))

	func setup(def: Dictionary, current_: bool, default_: bool) -> void:
		_def = def
		transition_id = String(def.get("id", ""))
		current = current_
		is_default = default_
		space = String(def.get("space", "2D"))

	func _ready() -> void:
		var px: Vector2 = custom_minimum_size
		vp = SubViewport.new()
		vp.name = "Preview"
		vp.size = Vector2i(maxi(int(px.x), 8), maxi(int(px.y), 8))
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		rect = ColorRect.new()
		rect.color = Color.WHITE
		rect.size = Vector2(vp.size)
		vp.add_child(rect)
		var info: Dictionary = Tiles.preview_info(_def)
		var sh: Shader = info.get("shader", null)
		if not bool(info.get("ok", false)) or sh == null:
			broken = String(info.get("reason", "it did not compile"))
			info = (TransitionRegistry.shared().call("fallback") as Dictionary).duplicate()
			info["values"] = {}
			sh = info.get("shader", null)
		mat = ShaderMaterial.new()
		mat.shader = sh
		var pics: Array[Texture2D] = Tiles.pictures()
		mat.set_shader_parameter("from_tex", pics[0])
		mat.set_shader_parameter("to_tex", pics[1])
		mat.set_shader_parameter("frame_px", Vector2(vp.size))
		mat.set_shader_parameter("px_scale", float(vp.size.x) / 1920.0)
		mat.set_shader_parameter("seed", float(absi(transition_id.hash()) % 97))
		mat.set_shader_parameter("duration", 1.0)
		var types: Dictionary = info.get("uniforms", {})
		var values: Dictionary = info.get("values", {})
		for k: Variant in values.keys():
			if types.has(String(k)):
				mat.set_shader_parameter(String(k), TransitionRegistry.shader_value(values[k], int(types[String(k)])))
		rect.material = mat
		_set_progress(Tiles.REST_PROGRESS)
		if not broken.is_empty():
			PmUI.tip(self, "This transition is broken: " + broken)

	func _set_progress(p: float) -> void:
		progress = p
		if mat != null:
			mat.set_shader_parameter("progress", p)
			mat.set_shader_parameter("time", _clock)

	func _process(delta: float) -> void:
		if vp == null:
			return
		if live:
			_clock += delta
			var cycle: float = Tiles.LOOP_S + Tiles.HOLD_S * 2.0
			var at: float = fmod(_clock, cycle)
			_set_progress(clampf((at - Tiles.HOLD_S) / Tiles.LOOP_S, 0.0, 1.0))
			queue_redraw()
			return
		if not rendered and is_visible_in_tree() and Tiles.claim():
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			rendered = true
			queue_redraw()
			set_process(false)

	func _on_hover(inside: bool) -> void:
		_hover = inside
		live = inside and vp != null
		if live:
			_clock = 0.0
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			set_process(true)
		elif vp != null:
			_set_progress(Tiles.REST_PROGRESS)
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			rendered = true
		queue_redraw()

	func _draw() -> void:
		var box: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(box, Tk.c["bg_field"], true)
		if vp != null and rendered:
			draw_texture_rect(vp.get_texture(), box, false)
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		if space == "3D":
			var tag: Rect2 = Rect2(Vector2(3.0, 3.0), Vector2(float(fs) * 1.6, float(fs) + 4.0))
			draw_rect(tag, Color(Tk.c["bg_app"], 0.75), true)
			PmText.draw_at(self, font, tag.position + Vector2(3.0, float(fs) + 1.0), "3D", fs, Tk.c["text_bright"], tag.size.x - 4.0)
		if is_default:
			var dw: float = font.get_string_size("Default", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x + 8.0
			var dtag: Rect2 = Rect2(Vector2(size.x - dw - 3.0, size.y - float(fs) - 7.0), Vector2(dw, float(fs) + 4.0))
			draw_rect(dtag, Tk.c["accent"], true)
			PmText.draw_at(self, font, dtag.position + Vector2(4.0, float(fs) + 1.0), "Default", fs, Tk.c["inv"], dtag.size.x - 6.0)
		if not broken.is_empty():
			draw_rect(Rect2(Vector2(size.x - 14.0, 3.0), Vector2(11.0, 11.0)), Tk.c["key_negative"], true)
		var edge: Color = Tk.c["accent"] if current else (Tk.c["text_dim"] if _hover else Tk.c["border_soft"])
		draw_rect(box, edge, false, 2.0 if current else 1.0)
