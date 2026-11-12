extends Node

const PAGE := 1024
const LINES_META := "pm_icon_lines"
const ATLAS_SHADER := "shader_type canvas_item;\nrender_mode blend_premul_alpha;\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, COLOR.a);\n}\n"

static var enabled: bool = true
static var plant_vector: bool = false
static var _inst: Node = null
static var _cells: Dictionary = {}
static var _wanted: Dictionary = {}
static var _waiting: Dictionary = {}
static var drawn_from_atlas: int = 0
static var drawn_as_lines: int = 0

var _pages: Array[SubViewport] = []
var _painters: Array[Control] = []
var _jobs: Array[Array] = []
var _shelf: Vector3i = Vector3i.ZERO
var _rendering: Array[String] = []
var _material: ShaderMaterial = null


class Painter:
	extends Control

	var jobs: Array = []
	var draw_vector: Callable = Callable()

	func _draw() -> void:
		for j: Dictionary in jobs:
			draw_vector.call(self, String(j["name"]), Rect2(j["at"], Vector2(float(j["side"]), float(j["side"]))), Color.WHITE, float(j["bold"]))


static func aligned(ci: CanvasItem) -> bool:
	var xf: Transform2D = ci.get_global_transform_with_canvas()
	if not xf.x.is_equal_approx(Vector2.RIGHT) or not xf.y.is_equal_approx(Vector2.DOWN):
		return false
	return absf(xf.origin.x - roundf(xf.origin.x)) < 0.001 and absf(xf.origin.y - roundf(xf.origin.y)) < 0.001


static func spill(width: float) -> int:
	return int(ceil(width)) + 2


static func key_of(name: String, side: float, frac: Vector2, bold: float, style: int) -> String:
	return "%s|%.4f|%.4f|%.4f|%.4f|%d" % [name, side, frac.x, frac.y, bold, style]


static func try_draw(ci: CanvasItem, name: String, side: float, origin: Vector2, width: float, tint: Color, bold: float, style: int) -> bool:
	if not enabled or plant_vector or ci == null or not ci.is_inside_tree() or side <= 0.0 or side > 256.0 or tint.a < 1.0:
		return false
	if ci.has_meta(LINES_META) or not aligned(ci):
		return false
	var base: Vector2 = origin.floor()
	var frac: Vector2 = origin - base
	var key: String = key_of(name, side, frac, bold, style)
	var cell: Variant = _cells.get(key, null)
	if cell is Dictionary:
		var c: Dictionary = cell
		var m: int = int(c["spill"])
		var src: Rect2 = c["src"]
		ci.draw_texture_rect_region(c["tex"], Rect2(base - Vector2(m, m), src.size), src, tint)
		drawn_from_atlas += 1
		return true
	if not _wanted.has(key):
		_wanted[key] = {"name": name, "side": side, "frac": frac, "bold": bold, "spill": spill(width)}
	_waiting[ci.get_instance_id()] = true
	_ensure(ci)
	return false


static func _ensure(ci: CanvasItem) -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	var tree: SceneTree = ci.get_tree()
	if tree == null:
		return
	var script: GDScript = load("res://ui/kit/icon_atlas.gd")
	_inst = script.new()
	_inst.name = "IconAtlas"
	tree.root.call_deferred("add_child", _inst)


static func forget() -> void:
	_cells = {}
	_wanted = {}
	_waiting = {}
	if _inst != null and is_instance_valid(_inst):
		_inst.call("_reset")


static func cell_count() -> int:
	return _cells.size()


static func pending() -> int:
	return _wanted.size()


func _ready() -> void:
	var sh: Shader = Shader.new()
	sh.code = ATLAS_SHADER
	_material = ShaderMaterial.new()
	_material.shader = sh
	process_priority = 400


func _reset() -> void:
	for vp: SubViewport in _pages:
		vp.queue_free()
	_pages.clear()
	_painters.clear()
	_jobs.clear()
	_shelf = Vector3i.ZERO
	_rendering.clear()


func _page(i: int) -> void:
	while _pages.size() <= i:
		var vp: SubViewport = SubViewport.new()
		vp.name = "IconPage" + str(_pages.size())
		vp.size = Vector2i(PAGE, PAGE)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var p: Painter = Painter.new()
		p.size = Vector2(PAGE, PAGE)
		p.material = _material
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.draw_vector = Callable(load("res://ui/kit/icons.gd"), "draw_lines")
		vp.add_child(p)
		add_child(vp)
		_pages.append(vp)
		_painters.append(p)
		_jobs.append([])


func _place(cell_size: Vector2i) -> Vector3i:
	if _pages.is_empty():
		_page(0)
	var page: int = _pages.size() - 1
	var x: int = _shelf.x
	var y: int = _shelf.y
	var h: int = _shelf.z
	if x + cell_size.x > PAGE:
		x = 0
		y += h
		h = 0
	if y + cell_size.y > PAGE:
		page += 1
		_page(page)
		x = 0
		y = 0
		h = 0
	_shelf = Vector3i(x + cell_size.x, y, maxi(h, cell_size.y))
	return Vector3i(page, x, y)


func _process(_dt: float) -> void:
	if not _rendering.is_empty():
		_finish()
	if _wanted.is_empty():
		return
	var touched: Dictionary = {}
	for key: String in _wanted.keys():
		var w: Dictionary = _wanted[key]
		var m: int = int(w["spill"])
		var side: float = float(w["side"])
		var frac: Vector2 = w["frac"]
		var span: int = int(ceil(side + maxf(frac.x, frac.y))) + m * 2
		var at: Vector3i = _place(Vector2i(span, span))
		var page: int = at.x
		(_jobs[page] as Array).append({"name": w["name"], "side": side, "bold": float(w["bold"]), "at": Vector2(at.y + m, at.z + m) + frac})
		w["page"] = page
		w["src"] = Rect2(at.y, at.z, span, span)
		touched[page] = true
		_rendering.append(key)
	for page: Variant in touched.keys():
		var p: Painter = _painters[int(page)]
		p.jobs = _jobs[int(page)]
		p.queue_redraw()
		_pages[int(page)].render_target_update_mode = SubViewport.UPDATE_ONCE


func _finish() -> void:
	for key: String in _rendering:
		var w: Dictionary = _wanted.get(key, {})
		if w.is_empty():
			continue
		_cells[key] = {"tex": _pages[int(w["page"])].get_texture(), "src": w["src"], "spill": int(w["spill"])}
		_wanted.erase(key)
	_rendering.clear()
	for id: Variant in _waiting.keys():
		var o: Object = instance_from_id(int(id))
		if o is CanvasItem and is_instance_valid(o):
			(o as CanvasItem).queue_redraw()
	_waiting.clear()
