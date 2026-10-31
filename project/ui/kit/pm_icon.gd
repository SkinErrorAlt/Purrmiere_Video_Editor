extends Control

const Icons := preload("res://ui/kit/icons.gd")

var name_: String = "":
	set(v):
		name_ = v
		queue_redraw()
var size_px: float = 16.0:
	set(v):
		size_px = v
		custom_minimum_size = Vector2(size_px, size_px)
		queue_redraw()
var tint: Color = Color.WHITE:
	set(v):
		tint = v
		queue_redraw()
var use_text_colour: bool = true
var bold: float = 1.0
var mark: bool = false
var tile: bool = false


static func paw(px: float = 20.0, tile_: bool = false) -> Control:
	var script: GDScript = load("res://ui/kit/pm_icon.gd")
	var ic: Control = script.new()
	ic.set("name_", "paw")
	ic.set("size_px", px)
	ic.set("mark", true)
	ic.set("tile", tile_)
	return ic


static func make(icon_name: String, px: float = 16.0, colour: Color = Color(0, 0, 0, 0)) -> Control:
	var script: GDScript = load("res://ui/kit/pm_icon.gd")
	var ic: Control = script.new()
	ic.set("name_", icon_name)
	ic.set("size_px", px)
	if colour.a > 0.0:
		ic.set("tint", colour)
		ic.set("use_text_colour", false)
	return ic


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(size_px, size_px)


func _ready() -> void:
	if use_text_colour:
		tint = Tk.c["text"]
	queue_redraw()


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	if mark:
		Icons.draw_mark(self, rect, tile)
		return
	Icons.draw(self, name_, rect, tint, bold)
