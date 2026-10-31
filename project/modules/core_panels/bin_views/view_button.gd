extends "res://ui/kit/pm_button.gd"

const ViewIcons := preload("res://modules/core_panels/bin_views/view_icons.gd")
const SIZE_KEY := "bin_view_switch"

var glyph: String = "views":
	set(v):
		glyph = v
		queue_redraw()
var chevron: bool = true


static func make_switch(glyph_: String) -> Button:
	var script: GDScript = load("res://modules/core_panels/bin_views/view_button.gd")
	var b: Button = script.new()
	b.set("icon_name", SIZE_KEY)
	b.set("glyph", glyph_)
	b.toggle_mode = true
	b.set("quiet", true)
	return b


func _draw() -> void:
	var side: float = _icon_side()
	var pos: Vector2 = ((size - Vector2(side, side)) * 0.5).round()
	var tint: Color = _icon_tint()
	ViewIcons.draw(self, glyph, Rect2(pos, Vector2(side, side)), tint)
	if not chevron:
		return
	var s: float = maxf(2.0, float(Tk.px(2.5)))
	var c: Vector2 = Vector2(size.x - float(Tk.px(5.0)), size.y - float(Tk.px(5.0))).round()
	draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(0.0, s * 0.5), c + Vector2(s, -s * 0.5)]), tint, maxf(1.0, float(Tk.px(1.2))), true)
