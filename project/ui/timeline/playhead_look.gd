extends RefCounted

const SELF_PATH := "res://ui/timeline/playhead_look.gd"
const PREF_COLOUR := "timeline.playhead_colour"
const PREF_WIDTH := "timeline.playhead_width"
const PREF_HEAD := "timeline.playhead_head"
const PREF_BAND := "timeline.playhead_frame_band"
const PREF_BAND_OPACITY := "timeline.playhead_band_opacity"
const PREF_TINT := "timeline.playhead_marker_tint"
const HEADS: PackedStringArray = ["pentagon", "triangle", "none"]
const DEFAULT_WIDTH := 2.0
const DEFAULT_BAND_OPACITY := 0.22
const BAND_MIN_PX := 4.0
const WIDTH_MIN := 1.0
const WIDTH_MAX := 6.0

static var _look: Dictionary = {}
static var _watching: bool = false
static var bands_drawn: int = 0
static var heads_drawn: Dictionary = {}


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func register_prefs() -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	var specs: Array = [
		[PREF_COLOUR, "", {"label": "Playhead colour", "type": "colour", "hint": "Empty uses the theme's playhead colour."}],
		[PREF_WIDTH, DEFAULT_WIDTH, {"label": "Playhead line width (px)", "type": "float", "min": WIDTH_MIN, "max": WIDTH_MAX}],
		[PREF_HEAD, "pentagon", {"label": "Playhead head shape", "type": "enum", "choices": Array(HEADS)}],
		[PREF_BAND, true, {"label": "Show the whole frame at the playhead", "type": "bool", "hint": "When zoomed in far enough that one frame is a few pixels wide, a band shows the full frame under the playhead, not only its start."}],
		[PREF_BAND_OPACITY, DEFAULT_BAND_OPACITY, {"label": "Frame band opacity", "type": "float", "min": 0.05, "max": 1.0}],
		[PREF_TINT, true, {"label": "Playhead turns the opposite colour over a marker of its own colour", "type": "bool"}],
	]
	for spec: Array in specs:
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])
	if not _watching and prefs.has_signal("changed"):
		_watching = true
		prefs.connect("changed", Callable(load(SELF_PATH), "_on_pref"))


static func _on_pref(key: String) -> void:
	if key.begins_with("timeline.playhead_"):
		_look = {}


static func forget() -> void:
	_look = {}


static func look() -> Dictionary:
	if not _look.is_empty():
		return _look
	register_prefs()
	var prefs: Node = _prefs()
	var out: Dictionary = {"colour": Tk.c["sol"], "themed": true, "width": DEFAULT_WIDTH, "head": "pentagon", "band": true, "band_opacity": DEFAULT_BAND_OPACITY, "tint": true}
	if prefs != null and bool(prefs.call("is_registered", PREF_WIDTH)):
		var raw: String = String(prefs.call("get_value", PREF_COLOUR)).strip_edges()
		if not raw.is_empty():
			out["colour"] = Color.from_string(raw, Tk.c["sol"])
			out["themed"] = false
		out["width"] = clampf(float(prefs.call("get_value", PREF_WIDTH)), WIDTH_MIN, WIDTH_MAX)
		var head: String = String(prefs.call("get_value", PREF_HEAD))
		out["head"] = head if HEADS.has(head) else "pentagon"
		out["band"] = bool(prefs.call("get_value", PREF_BAND))
		out["band_opacity"] = clampf(float(prefs.call("get_value", PREF_BAND_OPACITY)), 0.0, 1.0)
		out["tint"] = bool(prefs.call("get_value", PREF_TINT))
	_look = out
	return out


static func colour() -> Color:
	var l: Dictionary = look()
	return Tk.c["sol"] if bool(l["themed"]) else l["colour"]


static func width_px() -> float:
	return float(Tk.px(float(look()["width"])))


static func tint_on() -> bool:
	return bool(look()["tint"])


static func band_rect(x: float, y0: float, y1: float, frame_px: float) -> Rect2:
	var l: Dictionary = look()
	if not bool(l["band"]) or frame_px < BAND_MIN_PX:
		return Rect2()
	return Rect2(round(x), y0, round(frame_px), y1 - y0)


static func head_points(shape: String, x: float, y0: float, inv: bool = false) -> PackedVector2Array:
	if shape == "triangle":
		return PackedVector2Array([Vector2(x - 5.0, y0), Vector2(x + 6.0, y0), Vector2(x + 0.5, y0 + 8.0)])
	if shape == "none":
		return PackedVector2Array()
	return PackedVector2Array([Vector2(x - 5.0, y0), Vector2(x + 6.0, y0), Vector2(x + 6.0, y0 + 4.0), Vector2(x + 0.5, y0 + 9.0), Vector2(x - 5.0, y0 + 4.0)])


static func draw(ci: CanvasItem, x: float, y0: float, y1: float, opts: Dictionary = {}) -> void:
	var l: Dictionary = look()
	var col: Color = colour()
	var px: float = round(x)
	var w: float = float(opts.get("width", width_px()))
	var x0: float = px - floor(w * 0.5)
	var band: Rect2 = band_rect(px, float(opts.get("band_top", y0)), y1, float(opts.get("frame_px", 0.0)))
	if band.size.x > 0.0:
		ci.draw_rect(band, Color(col, float(l["band_opacity"])), true)
		ci.draw_rect(Rect2(band.end.x - 1.0, band.position.y, 1.0, band.size.y), Color(col, minf(float(l["band_opacity"]) * 2.0, 1.0)), true)
		bands_drawn += 1
	ci.draw_rect(Rect2(x0, y0, w, y1 - y0), col, true)
	var clash: Array = opts.get("clash", [])
	var inv: Color = Tk.c["inv"]
	var head_clash: bool = false
	for span: Vector2 in clash:
		ci.draw_rect(Rect2(x0 - 1.0, span.x, w + 2.0, span.y - span.x), col, true)
		ci.draw_rect(Rect2(x0, span.x, w, span.y - span.x), inv, true)
		if span.x <= y0 + 0.5:
			head_clash = true
	if not bool(opts.get("head", true)):
		return
	var shape: String = String(opts.get("shape", l["head"]))
	var head: PackedVector2Array = head_points(shape, px, float(opts.get("head_y", y0)))
	heads_drawn[shape] = int(heads_drawn.get(shape, 0)) + 1
	if head.is_empty():
		return
	ci.draw_colored_polygon(head, inv if head_clash else col)
	if head_clash:
		head.append(head[0])
		ci.draw_polyline(head, col, 1.0)
