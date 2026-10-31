extends RefCounted

const Filmcraft := preload("res://ui/kit/icons_filmcraft.gd")
const GRID := 24.0
const STROKE := 1.6
const PREF_STYLE := "ui.icon_style"
const STYLE_FILMCRAFT := "FilmCraft"
const STYLE_PURRMIERE := "Purrmiere"
const STYLES: PackedStringArray = [STYLE_FILMCRAFT, STYLE_PURRMIERE]

static var filmcraft: bool = true
static var serial: int = 0

const PATHS: Dictionary = {
	"select": [["o", [6, 3, 18, 12, 13, 13, 16, 19, 14, 20, 11, 14, 7, 18]]],
	"track_fwd": [["l", 4, 4, 4, 20], ["o", [9, 6, 18, 12, 9, 18]]],
	"track_back": [["l", 20, 4, 20, 20], ["o", [15, 6, 6, 12, 15, 18]]],
	"ripple": [["r", 4, 6, 6, 12], ["r", 14, 6, 6, 12], ["l", 11, 12, 13, 12]],
	"roll": [["r", 3, 6, 7, 12], ["r", 14, 6, 7, 12], ["l", 12, 9, 12, 15], ["p", [9, 12, 12, 10, 15, 12]]],
	"rate": [["l", 4, 8, 20, 8], ["l", 4, 16, 20, 16], ["p", [8, 5, 5, 8, 8, 11]], ["p", [16, 13, 19, 16, 16, 19]]],
	"razor": [["l", 5, 19, 14, 10], ["o", [12, 6, 18, 12, 15, 15, 9, 9]], ["l", 10, 9, 8, 11]],
	"slip": [["r", 3, 8, 18, 8], ["l", 8, 12, 16, 12], ["p", [14, 10, 16, 12, 14, 14]], ["p", [10, 10, 8, 12, 10, 14]]],
	"slide": [["r", 3, 8, 5, 8], ["r", 16, 8, 5, 8], ["l", 8, 12, 16, 12], ["p", [13, 9, 16, 12, 13, 15]]],
	"realign": [["r", 3, 5, 18, 10], ["p", [6, 10, 8, 7.5, 10, 12.5, 12, 8.5, 14, 11.5, 16, 9, 18, 10]], ["l", 5, 19.5, 19, 19.5], ["p", [7, 17.5, 5, 19.5, 7, 21.5]], ["p", [17, 17.5, 19, 19.5, 17, 21.5]]],
	"pen": [["o", [4, 20, 8, 19, 19, 8, 16, 5, 5, 16]], ["l", 13, 8, 16, 11]],
	"hand": [
		["p", [8, 12, 8, 6, 9.5, 4.5, 11, 6, 11, 11]],
		["p", [11, 11, 11, 5, 12.5, 3.5, 14, 5, 14, 11]],
		["p", [14, 11, 14, 7, 15.5, 5.5, 17, 7, 17, 14, 16, 17, 14, 19, 10, 19, 8, 17, 6, 13, 5, 11, 6, 10, 7.5, 10.5, 8, 12]],
	],
	"zoom": [["c", 10, 10, 6], ["l", 14.5, 14.5, 20, 20], ["l", 8, 10, 12, 10], ["l", 10, 8, 10, 12]],
	"type": [["l", 5, 6, 19, 6], ["l", 12, 6, 12, 19], ["l", 9, 19, 15, 19]],
	"play": [["f", [7, 5, 19, 12, 7, 19]]],
	"pause": [["fr", 7, 5, 4, 14], ["fr", 13, 5, 4, 14]],
	"step_back": [["f", [9, 12, 17, 6, 17, 18]], ["l", 6, 6, 6, 18]],
	"step_fwd": [["f", [15, 12, 7, 6, 7, 18]], ["l", 18, 6, 18, 18]],
	"to_start": [["l", 5, 5, 5, 19], ["o", [19, 6, 8, 12, 19, 18]]],
	"to_end": [["l", 19, 5, 19, 19], ["o", [5, 6, 16, 12, 5, 18]]],
	"mark_in": [["l", 5, 6, 5, 18], ["l", 5, 12, 17, 12], ["p", [13, 8, 17, 12, 13, 16]]],
	"mark_out": [["l", 19, 6, 19, 18], ["l", 7, 12, 19, 12], ["p", [11, 8, 7, 12, 11, 16]]],
	"lift": [["l", 4, 18, 20, 18], ["p", [8, 13, 12, 9, 16, 13]], ["l", 12, 9, 12, 17]],
	"extract": [["l", 4, 18, 9, 18], ["l", 15, 18, 20, 18], ["p", [8, 8, 12, 12, 16, 8]], ["l", 12, 4, 12, 12]],
	"marker": [["o", [6, 4, 18, 4, 18, 15, 12, 20, 6, 15]]],
	"camera": [["o", [4, 8, 8, 8, 10, 5, 14, 5, 16, 8, 20, 8, 20, 19, 4, 19]], ["c", 12, 13, 3]],
	"loop": [["a", 12, 12, 8, 180, 320], ["a", 12, 12, 8, 0, 140], ["p", [18, 3, 18, 7, 14, 7]], ["p", [6, 21, 6, 17, 10, 17]]],
	"plus": [["l", 12, 5, 12, 19], ["l", 5, 12, 19, 12]],
	"snap": [["l", 8, 4, 8, 10], ["a", 12, 10, 4, 180, 0], ["l", 16, 10, 16, 4], ["l", 6, 4, 10, 4], ["l", 14, 4, 18, 4], ["l", 12, 14, 12, 20]],
	"link": [
		["p", [10, 14, 11.4, 15.3, 13.3, 15.5, 15, 14.5, 17.8, 11.7, 18.5, 9.5, 17.8, 7.5, 16, 6, 14, 5.7, 12.2, 6.4, 11.5, 7]],
		["p", [14, 10, 12.6, 8.7, 10.7, 8.5, 9, 9.5, 6.2, 12.3, 5.5, 14.5, 6.2, 16.5, 8, 18, 10, 18.3, 11.8, 17.6, 13.1, 16.3]],
	],
	"inside": [["r", 4, 6, 16, 12], ["l", 8, 10, 16, 10], ["l", 8, 14, 13, 14]],
	"pin": [["o", [9, 4, 15, 4, 14, 10, 17, 13, 7, 13, 10, 10]], ["l", 12, 13, 12, 20]],
	"region": [["l", 4, 6, 4, 18], ["l", 20, 6, 20, 18], ["l", 4, 12, 20, 12], ["p", [8, 9, 5, 12, 8, 15]], ["p", [16, 9, 19, 12, 16, 15]]],
	"stopwatch": [["c", 12, 13, 7], ["p", [12, 9, 12, 13, 15, 15]], ["l", 10, 3, 14, 3], ["l", 12, 3, 12, 6]],
	"diamond": [["f", [12, 5, 19, 12, 12, 19, 5, 12]]],
	"diamond_o": [["o", [12, 5, 19, 12, 12, 19, 5, 12]]],
	"prev_key": [["p", [14, 6, 8, 12, 14, 18]]],
	"next_key": [["p", [10, 6, 16, 12, 10, 18]]],
	"eye": [["o", [2, 12, 5, 8.5, 8.5, 6.5, 12, 6, 15.5, 6.5, 19, 8.5, 22, 12, 19, 15.5, 15.5, 17.5, 12, 18, 8.5, 17.5, 5, 15.5]], ["c", 12, 12, 3]],
	"eye_off": [["o", [2, 12, 5, 8.5, 8.5, 6.5, 12, 6, 15.5, 6.5, 19, 8.5, 22, 12, 19, 15.5, 15.5, 17.5, 12, 18, 8.5, 17.5, 5, 15.5]], ["c", 12, 12, 3], ["l", 4, 20, 20, 4]],
	"speaker": [["o", [4, 10, 8, 10, 13, 6, 13, 18, 8, 14, 4, 14]], ["a", 16.5, 12, 3.4, -60, 60]],
	"speaker_off": [["o", [4, 10, 8, 10, 13, 6, 13, 18, 8, 14, 4, 14]], ["l", 16, 9, 20, 15], ["l", 20, 9, 16, 15]],
	"bleep": [["r", 3, 6, 18, 12], ["p", [5, 14, 8, 14, 8, 10, 12, 10, 12, 14, 16, 14, 16, 10, 19, 10]]],
	"lock": [["r", 6, 11, 12, 9], ["p", [8, 11, 8, 8, 8.6, 6, 10, 4.6, 12, 4, 14, 4.6, 15.4, 6, 16, 8, 16, 11]]],
	"unlock": [["r", 6, 11, 12, 9], ["p", [8, 11, 8, 8, 8.6, 6, 10, 4.6, 12, 4, 14, 4.6, 15.4, 6, 16, 7.5]]],
	"target": [["fr", 6, 6, 12, 12]],
	"target_off": [["r", 6, 6, 12, 12]],
	"chain": [["l", 9, 12, 15, 12], ["p", [8, 9, 6, 9, 4.3, 9.9, 3.2, 11.5, 3.2, 12.5, 4.3, 14.1, 6, 15, 8, 15]], ["p", [16, 9, 18, 9, 19.7, 9.9, 20.8, 11.5, 20.8, 12.5, 19.7, 14.1, 18, 15, 16, 15]]],
	"chev_d": [["p", [6, 9, 12, 15, 18, 9]]],
	"chev_r": [["p", [9, 6, 15, 12, 9, 18]]],
	"chev_u": [["p", [6, 15, 12, 9, 18, 15]]],
	"chev_l": [["p", [15, 6, 9, 12, 15, 18]]],
	"fx": [["p", [11, 7, 5, 7, 5, 17]], ["l", 5, 12, 10, 12], ["l", 13, 7, 19, 17], ["l", 19, 7, 13, 17]],
	"combo": [["p", [4, 12, 7, 12, 9, 8, 12, 16, 14, 11, 16, 13, 20, 13]], ["r", 3, 5, 18, 14]],
	"warn": [["o", [12, 4, 21, 20, 3, 20]], ["l", 12, 10, 12, 14], ["d", 12, 17, 0.9]],
	"error": [["f", [12, 4, 21, 20, 3, 20]]],
	"more": [["d", 6, 12, 1.4], ["d", 12, 12, 1.4], ["d", 18, 12, 1.4]],
	"close": [["l", 6, 6, 18, 18], ["l", 18, 6, 6, 18]],
	"search": [["c", 10, 10, 6], ["l", 14.5, 14.5, 20, 20]],
	"folder": [["o", [3, 6, 10, 6, 12, 8, 21, 8, 21, 19, 3, 19]]],
	"folder_new": [["o", [3, 6, 10, 6, 12, 8, 21, 8, 21, 19, 3, 19]], ["l", 12, 11, 12, 17], ["l", 9, 14, 15, 14]],
	"film": [["r", 4, 5, 16, 14], ["l", 4, 9, 20, 9], ["l", 4, 15, 20, 15], ["l", 8, 5, 8, 19], ["l", 16, 5, 16, 19]],
	"audio": [["p", [4, 12, 6, 12, 8, 7, 11, 17, 14, 9, 16, 14, 18, 12, 20, 12]]],
	"image": [["r", 4, 5, 16, 14], ["p", [4, 16, 9, 11, 13, 15, 16, 12, 20, 16]], ["c", 16, 9, 1.5]],
	"seq": [["r", 3, 6, 18, 12], ["l", 3, 12, 21, 12], ["l", 8, 6, 8, 12], ["l", 14, 12, 14, 18]],
	"list": [["l", 5, 7, 19, 7], ["l", 5, 12, 19, 12], ["l", 5, 17, 19, 17]],
	"grid": [["r", 4, 4, 7, 7], ["r", 13, 4, 7, 7], ["r", 4, 13, 7, 7], ["r", 13, 13, 7, 7]],
	"trash": [["l", 5, 7, 19, 7], ["p", [8, 7, 8, 4, 16, 4, 16, 7]], ["p", [7, 7, 8, 20, 16, 20, 17, 7]]],
	"wrench": [["o", [14, 4, 10.5, 5.2, 9, 8.5, 9, 10, 4, 15, 7, 18, 12, 13, 13.5, 13.2, 17, 12, 18.5, 8.5, 15, 12, 12, 9, 15, 6]]],
	"export": [["l", 12, 4, 12, 15], ["p", [8, 8, 12, 4, 16, 8]], ["p", [4, 15, 4, 20, 20, 20, 20, 15]]],
	"import": [["l", 12, 4, 12, 15], ["p", [8, 11, 12, 15, 16, 11]], ["p", [4, 15, 4, 20, 20, 20, 20, 15]]],
	"undo": [["p", [9, 7, 4, 12, 9, 17]], ["l", 4, 12, 15, 12], ["a", 15, 16, 4, -90, 90], ["l", 15, 20, 10, 20]],
	"redo": [["p", [15, 7, 20, 12, 15, 17]], ["l", 20, 12, 9, 12], ["a", 9, 16, 4, -90, -270], ["l", 9, 20, 14, 20]],
	"maximize": [["r", 4, 4, 16, 16], ["l", 4, 7, 20, 7]],
	"restore": [["r", 4, 9, 11, 11], ["p", [8, 9, 8, 5, 20, 5, 20, 17, 15, 17]]],
	"float_panel": [["r", 3, 4, 13, 11], ["r", 8, 9, 13, 11]],
	"dock_panel": [["r", 3, 4, 18, 16], ["l", 3, 9, 21, 9], ["l", 10, 9, 10, 20]],
	"check": [["p", [5, 12.5, 10, 17.5, 19, 7]]],
	"minus": [["l", 5, 12, 19, 12]],
	"paw": [["d", 6.2, 9.1, 2.7], ["d", 11.5, 6.8, 2.95], ["d", 16.8, 9.1, 2.7], ["d", 20.2, 13.8, 2.1], ["e", 10.8, 16.7, 5.7, 4.45]],
	"sun": [["c", 12, 12, 3.5], ["l", 12, 3, 12, 5.5], ["l", 12, 18.5, 12, 21], ["l", 3, 12, 5.5, 12], ["l", 18.5, 12, 21, 12], ["l", 5.6, 5.6, 7.4, 7.4], ["l", 16.6, 16.6, 18.4, 18.4], ["l", 5.6, 18.4, 7.4, 16.6], ["l", 16.6, 7.4, 18.4, 5.6]],
	"follow": [["p", [2, 13, 5, 13, 7.5, 7, 10.5, 18, 13.5, 6, 15.5, 13, 19, 13]], ["p", [17, 10, 20, 13, 17, 16]]],
	"moon": [["a", 12, 12, 7, 40, 320], ["a", 15.5, 9.5, 5, 130, 250]],
	"full_quality": [["r", 3, 5, 18, 14], ["f", [12, 7.5, 13.3, 10.7, 16.5, 12, 13.3, 13.3, 12, 16.5, 10.7, 13.3, 7.5, 12, 10.7, 10.7]], ["l", 9, 21, 15, 21]],
}


static func draw_mark(ci: CanvasItem, rect: Rect2, tile: bool = false) -> void:
	var side: float = minf(rect.size.x, rect.size.y)
	if side <= 0.0:
		return
	var origin: Vector2 = rect.position + (rect.size - Vector2(side, side)) * 0.5
	if not tile:
		draw(ci, "paw", Rect2(origin, Vector2(side, side)), Tk.c["text_bright"])
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["sol"]
	sb.set_corner_radius_all(int(round(side * 0.25)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(origin, Vector2(side, side)))
	var inner: float = side * 0.68
	draw(ci, "paw", Rect2(origin + Vector2((side - inner) * 0.5, (side - inner) * 0.5 + side * 0.02), Vector2(inner, inner)), Tk.c["inv"])


static func register(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_STYLE)):
		prefs.call("register", PREF_STYLE, STYLE_FILMCRAFT, {"label": "Icon style for buttons and tool pointers", "type": "enum", "choices": Array(STYLES)})
	apply_style(prefs)


static func apply_style(prefs: Node) -> bool:
	var want: bool = prefs == null or String(prefs.call("get_value", PREF_STYLE)) != STYLE_PURRMIERE
	if want == filmcraft:
		return false
	filmcraft = want
	serial += 1
	return true


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in PATHS.keys():
		out.append(k)
	for k2: String in Filmcraft.PATHS.keys():
		if not out.has(k2):
			out.append(k2)
	out.sort()
	return out


static func has(name: String) -> bool:
	return PATHS.has(name) or Filmcraft.PATHS.has(name)


static func ops_of(name: String) -> Array:
	if filmcraft and Filmcraft.PATHS.has(name):
		return Filmcraft.PATHS[name]
	if PATHS.has(name):
		return PATHS[name]
	return Filmcraft.PATHS.get(name, [])


static func grid_of(name: String) -> float:
	return Filmcraft.GRID if (filmcraft or not PATHS.has(name)) and Filmcraft.PATHS.has(name) else GRID


static func stroke_of(name: String) -> float:
	return Filmcraft.STROKE if (filmcraft or not PATHS.has(name)) and Filmcraft.PATHS.has(name) else STROKE


static func _pts(raw: Array, origin: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i: int = 0
	while i + 1 < raw.size():
		out.append(origin + Vector2(float(raw[i]), float(raw[i + 1])) * k)
		i += 2
	return out


static func draw(ci: CanvasItem, name: String, rect: Rect2, tint: Color, bold: float = 1.0) -> void:
	var side: float = minf(rect.size.x, rect.size.y)
	if side <= 0.0:
		return
	var k: float = side / grid_of(name)
	var origin: Vector2 = rect.position + (rect.size - Vector2(side, side)) * 0.5
	var w: float = maxf(1.0, stroke_of(name) * k * bold)
	if not has(name):
		var inset: float = 4.0 * k
		ci.draw_rect(Rect2(origin + Vector2(inset, inset), Vector2(side - inset * 2.0, side - inset * 2.0)), tint, false, w)
		return
	for op: Array in ops_of(name):
		var kind: String = op[0]
		if kind == "l":
			ci.draw_line(origin + Vector2(float(op[1]), float(op[2])) * k, origin + Vector2(float(op[3]), float(op[4])) * k, tint, w, true)
		elif kind == "p":
			var pts: PackedVector2Array = _pts(op[1], origin, k)
			if pts.size() >= 2:
				ci.draw_polyline(pts, tint, w, true)
		elif kind == "o":
			var pts: PackedVector2Array = _pts(op[1], origin, k)
			if pts.size() >= 2:
				pts.append(pts[0])
				ci.draw_polyline(pts, tint, w, true)
		elif kind == "f":
			var pts: PackedVector2Array = _pts(op[1], origin, k)
			if pts.size() >= 3:
				ci.draw_colored_polygon(pts, tint)
		elif kind == "c":
			ci.draw_arc(origin + Vector2(float(op[1]), float(op[2])) * k, float(op[3]) * k, 0.0, TAU, 32, tint, w, true)
		elif kind == "d":
			ci.draw_circle(origin + Vector2(float(op[1]), float(op[2])) * k, maxf(1.0, float(op[3]) * k), tint)
		elif kind == "e":
			var centre: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			var rx: float = float(op[3]) * k
			var ry: float = float(op[4]) * k
			var pts := PackedVector2Array()
			for i: int in range(40):
				var a: float = TAU * float(i) / 40.0
				pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
			ci.draw_colored_polygon(pts, tint)
		elif kind == "r":
			ci.draw_rect(Rect2(origin + Vector2(float(op[1]), float(op[2])) * k, Vector2(float(op[3]), float(op[4])) * k), tint, false, w)
		elif kind == "fr":
			ci.draw_rect(Rect2(origin + Vector2(float(op[1]), float(op[2])) * k, Vector2(float(op[3]), float(op[4])) * k), tint, true)
		elif kind == "a":
			ci.draw_arc(origin + Vector2(float(op[1]), float(op[2])) * k, float(op[3]) * k, deg_to_rad(float(op[4])), deg_to_rad(float(op[5])), 24, tint, w, true)
