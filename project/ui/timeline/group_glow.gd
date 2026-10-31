extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const RING := 2.0
const WASH := 0.18

static var ids: Dictionary = {}
static var colour: Color = Color(1, 1, 1)
static var owner_id: String = ""
static var drawn_last: int = 0
static var tag_texts: PackedStringArray = PackedStringArray()


static func light(clip_ids: PackedStringArray, col: Color, from: String) -> void:
	var fresh: Dictionary = {}
	for id: String in clip_ids:
		fresh[id] = true
	ids = fresh
	colour = col
	owner_id = from


static func clear(from: String = "") -> void:
	if not from.is_empty() and from != owner_id:
		return
	ids = {}
	owner_id = ""


static func lit() -> PackedStringArray:
	return PackedStringArray(ids.keys())


static func draw(canvas: Control) -> int:
	tag_texts = PackedStringArray()
	if ids.is_empty() or canvas == null:
		drawn_last = 0
		return 0
	var s: Sequence = canvas.call("seq")
	if s == null:
		return 0
	var geom: Dictionary = canvas.call("geometry")
	var ln: Dictionary = canvas.call("lanes")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var wash: Color = Color(colour.r, colour.g, colour.b, WASH)
	var drawn: int = 0
	for tr: Track in s.all_tracks():
		var l: Dictionary = Lanes.lane_for_track(ln, tr.id)
		if l.is_empty():
			continue
		var region: Rect2 = geom["main_rect"] if String(l["set"]) == "main" else geom["band_rect"]
		for c: Clip in tr.clips:
			if not ids.has(c.id):
				continue
			var r: Rect2 = Hit.clip_rect(geom, l, c)
			var x0: float = maxf(r.position.x, header_w)
			var x1: float = minf(r.end.x, width)
			var y0: float = maxf(r.position.y, region.position.y)
			var y1: float = minf(r.end.y, region.end.y)
			if x1 <= x0 or y1 <= y0:
				continue
			var box: Rect2 = Rect2(x0, y0, x1 - x0, y1 - y0)
			canvas.draw_rect(box, wash, true)
			canvas.draw_rect(box.grow(-RING * 0.5), colour, false, RING)
			drawn += 1
	drawn_last = drawn
	return drawn


static func tag_text(canvas: Control, font: Font, area: Rect2, text: String, fs: int, ink: Color) -> Rect2:
	if canvas == null or font == null or text.is_empty() or area.size.x < 1.0:
		return Rect2()
	var shown: String = PmText.elide(font, text, area.size.x, fs)
	if shown.is_empty():
		return Rect2()
	var r: Rect2 = PmText.draw_on_kept(canvas, font, area, text, fs, ink)
	if r.has_area():
		tag_texts.append(shown)
	return r
