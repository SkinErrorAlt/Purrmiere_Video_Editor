extends "res://modules/core_panels/effect_panel_kind.gd"

## A room drawn as a see-through box, with the listener in it as a red ball. Drag the
## handles on the side wall, the far wall or the ceiling to make it wider, deeper
## or taller. With only a "size" role the whole box grows and shrinks together.
## The walls take their look from what they are made of or how soft they are,
## and the lines bouncing off them get stronger the longer the room rings.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const YAW := 0.52
const PITCH := 0.46
const EAR := 1.25
const WIDE := "wide"
const DEEP := "deep"
const TALL := "tall"
const CORNER := "corner"
const SOURCE := "source"
const LOOKS: PackedStringArray = ["soft", "wood", "plaster", "tile", "concrete", "studio"]
const ABSORB: Array = [0.30, 0.13, 0.05, 0.013, 0.037, 0.62]
const LISTENER_RED := Color(0.93, 0.26, 0.24)
## Waves are slowed so the eye can follow them: a wave crosses the room's longest side in about this long.
const CROSS_SECONDS := 0.42
const MAX_PULSES := 10
const PULSE_EVERY := 0.16
const CIRCLE_STEPS := 72

var pulses: Array[Dictionary] = []
var _since: float = 0.0
var _last_level: float = 0.0


func title() -> String:
	return "Room"


func roles() -> Dictionary:
	return {
		"width": role("Room width", false),
		"depth": role("Room depth", false),
		"height": role("Ceiling height", false),
		"size": role("Room size", false),
		"across": role("Sound across", false),
		"distance": role("Distance from you", false),
		"decay": role("How long it rings", false),
		"damp": role("Soft above", false),
		"early": role("Early reflections", false),
		"walls": role("Walls", false, TYPES_CHOICE),
		"furnished": role("Furniture and people", false),
	}


func height() -> float:
	return 216.0


func live() -> bool:
	return true


func toggles() -> Array:
	return [
		["waves", "Waves bouncing off the walls while playing", true],
		["reflections", "Reflection lines", true],
		["guides", "Guide lines on the listener", true],
		["walls", "Wall look", true],
		["furniture", "Furniture", true],
		["grid", "Floor grid", true],
		["labels", "Sizes", true],
	]


## Starts a wave when the sound gets louder, and keeps sending them while it stays loud, each as strong as the
## sound was. Old ones die away as fast as the room stops ringing.
func tick(view: PanelView, dt: float) -> void:
	_since += dt
	if not view.toggle("waves"):
		pulses.clear()
		return
	var lv: float = view.live_level
	var life: float = _life(view)
	for i: int in range(pulses.size() - 1, -1, -1):
		if view.live_clock - float(pulses[i]["born"]) > life:
			pulses.remove_at(i)
	var onset: bool = lv > _last_level * 1.3 + 0.03
	if lv > 0.04 and (onset or _since >= PULSE_EVERY) and view.toggle("waves"):
		pulses.append({"born": view.live_clock, "strength": clampf(lv, 0.0, 1.0)})
		_since = 0.0
		while pulses.size() > MAX_PULSES:
			pulses.remove_at(0)
	_last_level = lv


func live_stop(_view: PanelView) -> void:
	pulses.clear()
	_since = 0.0
	_last_level = 0.0


func _life(view: PanelView) -> float:
	return 0.35 + 1.6 * _lively(view, _dims(view))


func undo_label(part: String) -> String:
	match part:
		WIDE:
			return "Make the room wider or narrower"
		DEEP:
			return "Make the room deeper or shallower"
		TALL:
			return "Raise or lower the ceiling"
		CORNER:
			return "Make the room bigger or smaller"
		SOURCE:
			return "Move the sound in the room"
	return "Change the room"


func tip(view: PanelView, part: String) -> String:
	if _sized(view) and (part == WIDE or part == DEEP or part == TALL or part == CORNER):
		return "Drag to make the whole room bigger or smaller"
	match part:
		WIDE:
			return "Drag the side wall to make the room wider or narrower"
		DEEP:
			return "Drag the far wall to make the room deeper"
		TALL:
			return "Drag the ceiling up or down"
		SOURCE:
			return "Drag the sound around the room"
	return "The room the sound is in. Drag the handles on its walls to change it."


func _sized(view: PanelView) -> bool:
	return view.has("size") and not (view.has("width") or view.has("depth") or view.has("height"))


func _shape(view: PanelView) -> Vector3:
	var base: Array = view.option("shape", [8.0, 10.0, 3.6]) as Array
	return Vector3(float(base[0]), float(base[1]), float(base[2]))


func _scale_of(view: PanelView, t: float) -> float:
	var span: Array = view.option("scale", [0.35, 1.0]) as Array
	return lerpf(float(span[0]), float(span[1]), clampf(t, 0.0, 1.0))


func _t_of_scale(view: PanelView, sc: float) -> float:
	var span: Array = view.option("scale", [0.35, 1.0]) as Array
	var lo: float = float(span[0])
	var hi: float = float(span[1])
	return clampf((sc - lo) / (hi - lo), 0.0, 1.0) if hi > lo else 0.0


func _dims(view: PanelView) -> Vector3:
	if _sized(view):
		return _shape(view) * _scale_of(view, view.norm("size"))
	var fallback: Vector3 = _shape(view) * 0.6
	return Vector3(view.value("width", fallback.x) if view.has("width") else fallback.x, view.value("depth", fallback.y) if view.has("depth") else fallback.y, view.value("height", fallback.z) if view.has("height") else fallback.z)


func _listener(dims: Vector3) -> Vector3:
	return Vector3(0.0, clampf(0.25 * dims.y, minf(0.5, dims.y * 0.5), maxf(dims.y - 0.5, dims.y * 0.5)), 0.0)


func _source(view: PanelView, dims: Vector3) -> Vector3:
	var me: Vector3 = _listener(dims)
	var x: float = 0.0
	var y: float = me.y + 0.5 * (dims.y - me.y)
	if view.has("across"):
		x = view.value("across") * maxf(0.0, dims.x * 0.5 - 0.3)
	if view.has("distance"):
		y = minf(dims.y - 0.3, me.y + view.value("distance"))
	return Vector3(x, y, EAR)


func _axes(k: float) -> Array[Vector2]:
	var ax: Vector2 = Vector2(cos(YAW), -sin(YAW) * sin(PITCH)) * k
	var ay: Vector2 = Vector2(-sin(YAW), -cos(YAW) * sin(PITCH)) * k
	var az: Vector2 = Vector2(0.0, -cos(PITCH)) * k
	return [ax, ay, az]


func _area(view: PanelView) -> Rect2:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(10.0)
	return Rect2(r.position.x + D.s(14.0), r.position.y + D.s(12.0), r.size.x - D.s(28.0), r.size.y - D.s(24.0) - foot)


func _view(view: PanelView, dims: Vector3) -> Dictionary:
	if view.frozen.has("k"):
		return {"k": view.frozen["k"], "o": view.frozen["o"]}
	var fit: Vector3 = _shape(view) * _scale_of(view, 1.0) if _sized(view) else Vector3(maxf(dims.x * 1.12, 4.0), maxf(dims.y * 1.12, 5.0), maxf(dims.z * 1.12, 2.6))
	var unit: Array[Vector2] = _axes(1.0)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for cx: float in [-0.5, 0.5]:
		for cy: float in [0.0, 1.0]:
			for cz: float in [0.0, 1.0]:
				var p: Vector2 = unit[0] * cx * fit.x + unit[1] * cy * fit.y + unit[2] * cz * fit.z
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var area: Rect2 = _area(view)
	var span: Vector2 = hi - lo
	var k: float = minf(area.size.x / maxf(span.x, 0.001), area.size.y / maxf(span.y, 0.001))
	var o: Vector2 = area.get_center() - (lo + hi) * 0.5 * k
	if not _sized(view):
		var now_lo: Vector2 = Vector2(INF, INF)
		var now_hi: Vector2 = Vector2(-INF, -INF)
		for cx2: float in [-0.5, 0.5]:
			for cy2: float in [0.0, 1.0]:
				for cz2: float in [0.0, 1.0]:
					var q: Vector2 = (unit[0] * cx2 * dims.x + unit[1] * cy2 * dims.y + unit[2] * cz2 * dims.z) * k
					now_lo = Vector2(minf(now_lo.x, q.x), minf(now_lo.y, q.y))
					now_hi = Vector2(maxf(now_hi.x, q.x), maxf(now_hi.y, q.y))
		o = area.get_center() - (now_lo + now_hi) * 0.5
	return {"k": k, "o": o}


func _p(v: Dictionary, x: float, y: float, z: float) -> Vector2:
	var a: Array[Vector2] = _axes(float(v["k"]))
	return (v["o"] as Vector2) + a[0] * x + a[1] * y + a[2] * z


func _look(view: PanelView) -> String:
	if view.has("walls"):
		var looks: Array = view.option("wall_looks", Array(LOOKS)) as Array
		var i: int = int(round(view.value("walls")))
		if i >= 0 and i < looks.size():
			return String(looks[i])
	return "plaster"


func _lively(view: PanelView, dims: Vector3) -> float:
	if view.has("decay"):
		return clampf(0.15 + 0.85 * view.norm("decay"), 0.0, 1.0)
	if view.has("walls"):
		var absorb: Array = view.option("wall_absorb", ABSORB) as Array
		var i: int = clampi(int(round(view.value("walls"))), 0, absorb.size() - 1)
		var a: float = float(absorb[i]) + (view.value("furnished") * 0.16 if view.has("furnished") else 0.0)
		var rt: float = _ring_time(dims, a)
		return clampf(log(1.0 + rt * 2.0) / log(9.0), 0.05, 1.0)
	return 0.5


func _ring_time(dims: Vector3, absorb: float) -> float:
	var vol: float = dims.x * dims.y * dims.z
	var surf: float = 2.0 * (dims.x * dims.y + dims.x * dims.z + dims.y * dims.z)
	return 0.161 * vol / maxf(surf * maxf(absorb, 0.005), 0.001)


func _wall_tint(view: PanelView) -> Color:
	var base: Color = view.col("bg_panel_high")
	var look: String = _look(view)
	if not view.has("walls") and view.has("damp"):
		var t: float = view.norm("damp")
		return base.lerp(view.col("key_over").lerp(view.col("key_low"), t), 0.22)
	match look:
		"soft":
			return base.lerp(view.col("key_over"), 0.2)
		"wood":
			return base.lerp(view.col("key_over"), 0.32).darkened(0.08)
		"tile":
			return base.lerp(view.col("key_low"), 0.3)
		"concrete":
			return base.darkened(0.12)
		"studio":
			return base.lerp(view.col("zone_over"), 0.22)
	return base


func draw(view: PanelView) -> void:
	var dims: Vector3 = _dims(view)
	var v: Dictionary = _view(view, dims)
	var hw: float = dims.x * 0.5
	var dd: float = dims.y
	var hh: float = dims.z
	var floor_pts := PackedVector2Array([_p(v, -hw, 0, 0), _p(v, hw, 0, 0), _p(v, hw, dd, 0), _p(v, -hw, dd, 0)])
	view.draw_colored_polygon(floor_pts, view.col("bg_panel"))
	if view.toggle("grid"):
		_floor_grid(view, v, dims)
	var tint: Color = _wall_tint(view)
	var lively: float = _lively(view, dims)
	var far := PackedVector2Array([_p(v, -hw, dd, 0), _p(v, hw, dd, 0), _p(v, hw, dd, hh), _p(v, -hw, dd, hh)])
	var side := PackedVector2Array([_p(v, hw, 0, 0), _p(v, hw, dd, 0), _p(v, hw, dd, hh), _p(v, hw, 0, hh)])
	var left := PackedVector2Array([_p(v, -hw, 0, 0), _p(v, -hw, dd, 0), _p(v, -hw, dd, hh), _p(v, -hw, 0, hh)])
	view.draw_colored_polygon(left, Color(tint, 0.35))
	view.draw_colored_polygon(far, Color(tint, 0.95))
	view.draw_colored_polygon(side, Color(tint.darkened(0.1), 0.95))
	if view.toggle("walls"):
		_pattern(view, v, dims, _look(view) if view.has("walls") else "")
	var hl: String = view.grab if not view.grab.is_empty() else view.hover
	var glow: Color = view.col("accent", 0.09)
	if hl == WIDE or hl == CORNER:
		view.draw_colored_polygon(side, glow)
	if hl == DEEP or hl == CORNER:
		view.draw_colored_polygon(far, glow)
	if view.has("furnished") and view.toggle("furniture"):
		_furniture(view, v, dims, view.value("furnished"))
	var me: Vector3 = _listener(dims)
	var src: Vector3 = _source(view, dims)
	if view.toggle("reflections"):
		_reflections(view, v, dims, me, src, lively)
	if view.live_on and view.toggle("waves") and not pulses.is_empty():
		_waves(view, v, dims, me, src, lively)
	var soft: Color = view.col("border_text", 0.55)
	for e: Array in [[Vector3(-hw, 0, 0), Vector3(-hw, dd, 0)], [Vector3(-hw, dd, 0), Vector3(hw, dd, 0)], [Vector3(hw, dd, 0), Vector3(hw, 0, 0)], [Vector3(hw, 0, 0), Vector3(-hw, 0, 0)], [Vector3(-hw, dd, 0), Vector3(-hw, dd, hh)], [Vector3(hw, dd, 0), Vector3(hw, dd, hh)], [Vector3(hw, 0, 0), Vector3(hw, 0, hh)]]:
		var a3: Vector3 = e[0]
		var b3: Vector3 = e[1]
		view.draw_line(_p(v, a3.x, a3.y, a3.z), _p(v, b3.x, b3.y, b3.z), soft, 1.0, true)
	_listener_ball(view, v, dims, me, src)
	var src_floor: Vector2 = _p(v, src.x, src.y, 0.0)
	var src_at: Vector2 = _p(v, src.x, src.y, src.z)
	D.ellipse_fill(view, src_floor, D.s(5.0), D.s(2.2), view.shadow(0.5))
	D.dashed(view, src_floor, src_at, view.col("text_dim", 0.8), 1.0, D.s(2.0), D.s(2.0))
	var src_lit: bool = hl == SOURCE
	var beat: float = 1.0 + (view.live_level * 0.6 if view.live_on else 0.0)
	if view.has("across") or view.has("distance"):
		D.glow_dot(view, src_at, D.s(5.0) * beat, view.col("accent"), src_lit or (view.live_on and view.live_level > 0.3))
	else:
		D.glow_dot(view, src_at, D.s(3.5) * beat, view.col("accent", 0.8), false)
	var top: Color = view.col("text_dim", 0.9)
	for e2: Array in [[Vector3(-hw, 0, hh), Vector3(hw, 0, hh)], [Vector3(hw, 0, hh), Vector3(hw, dd, hh)], [Vector3(hw, dd, hh), Vector3(-hw, dd, hh)], [Vector3(-hw, dd, hh), Vector3(-hw, 0, hh)], [Vector3(-hw, 0, 0), Vector3(-hw, 0, hh)]]:
		var a4: Vector3 = e2[0]
		var b4: Vector3 = e2[1]
		view.draw_line(_p(v, a4.x, a4.y, a4.z), _p(v, b4.x, b4.y, b4.z), top if hl != TALL else view.col("accent"), 1.2 if hl == TALL else 1.0, true)
	if hl == TALL:
		view.draw_colored_polygon(PackedVector2Array([_p(v, -hw, 0, hh), _p(v, hw, 0, hh), _p(v, hw, dd, hh), _p(v, -hw, dd, hh)]), view.col("accent", 0.06))
	if view.toggle("labels"):
		_labels(view, v, dims)
	for part: String in _handle_parts(view):
		_handle(view, _handle_base(v, dims, part), _handle_at(v, dims, part), _handle_dir(v, part), part == hl)
	var r: Rect2 = view.stage()
	view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(8.0)), _words(view, dims), "text", "font_small", r.size.x - D.s(16.0))


func _floor_grid(view: PanelView, v: Dictionary, dims: Vector3) -> void:
	var step_: float = 1.0
	while dims.x / step_ > 14.0 or dims.y / step_ > 14.0:
		step_ *= 2.0
	var c: Color = view.col("lane_line")
	var hw: float = dims.x * 0.5
	var x: float = -hw + fmod(hw, step_)
	while x < hw - 0.01:
		if absf(x + hw) > 0.01:
			view.draw_line(_p(v, x, 0, 0), _p(v, x, dims.y, 0), c, 1.0, true)
		x += step_
	var y: float = step_
	while y < dims.y - 0.01:
		view.draw_line(_p(v, -hw, y, 0), _p(v, hw, y, 0), c, 1.0, true)
		y += step_


func _pattern(view: PanelView, v: Dictionary, dims: Vector3, look: String) -> void:
	var hw: float = dims.x * 0.5
	var dd: float = dims.y
	var hh: float = dims.z
	var line: Color = view.shadow(0.22)
	var light: Color = view.col("text", 0.07)
	match look:
		"tile":
			var n: int = clampi(int(hh / 0.6), 3, 10)
			for i: int in range(1, n):
				var z: float = hh * float(i) / float(n)
				view.draw_line(_p(v, -hw, dd, z), _p(v, hw, dd, z), light, 1.0, true)
				view.draw_line(_p(v, hw, 0, z), _p(v, hw, dd, z), light, 1.0, true)
			var cols: int = clampi(int(dims.x / 0.6), 4, 24)
			for j: int in range(1, cols):
				var x: float = -hw + dims.x * float(j) / float(cols)
				view.draw_line(_p(v, x, dd, 0), _p(v, x, dd, hh), light, 1.0, true)
			var rows: int = clampi(int(dd / 0.6), 4, 24)
			for k: int in range(1, rows):
				var y: float = dd * float(k) / float(rows)
				view.draw_line(_p(v, hw, y, 0), _p(v, hw, y, hh), light, 1.0, true)
		"wood":
			var planks: int = clampi(int(hh / 0.25), 5, 14)
			for i2: int in range(1, planks):
				var z2: float = hh * float(i2) / float(planks)
				view.draw_line(_p(v, -hw, dd, z2), _p(v, hw, dd, z2), line, 1.0, true)
				view.draw_line(_p(v, hw, 0, z2), _p(v, hw, dd, z2), line, 1.0, true)
		"soft":
			var folds: int = clampi(int(dims.x / 0.35), 6, 30)
			for f: int in range(1, folds):
				var fx: float = -hw + dims.x * float(f) / float(folds)
				view.draw_line(_p(v, fx, dd, 0.05), _p(v, fx, dd, hh * 0.92), line if f % 2 == 0 else light, 1.0, true)
			var folds2: int = clampi(int(dd / 0.35), 6, 30)
			for f2: int in range(1, folds2):
				var fy: float = dd * float(f2) / float(folds2)
				view.draw_line(_p(v, hw, fy, 0.05), _p(v, hw, fy, hh * 0.92), line if f2 % 2 == 0 else light, 1.0, true)
		"studio":
			var across: int = clampi(int(dims.x / 1.2), 2, 8)
			for a: int in across:
				var x0: float = -hw + dims.x * (float(a) + 0.12) / float(across)
				var x1: float = -hw + dims.x * (float(a) + 0.88) / float(across)
				var panel_pts := PackedVector2Array([_p(v, x0, dd, hh * 0.25), _p(v, x1, dd, hh * 0.25), _p(v, x1, dd, hh * 0.8), _p(v, x0, dd, hh * 0.8)])
				view.draw_colored_polygon(panel_pts, view.shadow(0.18))
			var deep: int = clampi(int(dd / 1.2), 2, 8)
			for b: int in deep:
				var y0: float = dd * (float(b) + 0.12) / float(deep)
				var y1: float = dd * (float(b) + 0.88) / float(deep)
				var panel2 := PackedVector2Array([_p(v, hw, y0, hh * 0.25), _p(v, hw, y1, hh * 0.25), _p(v, hw, y1, hh * 0.8), _p(v, hw, y0, hh * 0.8)])
				view.draw_colored_polygon(panel2, view.shadow(0.18))
		"concrete":
			for i3: int in range(1, 4):
				var z3: float = hh * float(i3) / 4.0
				view.draw_line(_p(v, -hw, dd, z3), _p(v, hw, dd, z3), light, 1.0, true)
				view.draw_line(_p(v, hw, 0, z3), _p(v, hw, dd, z3), light, 1.0, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for s_: int in 40:
				var px: float = rng.randf_range(-hw, hw)
				var pz: float = rng.randf_range(0.1, hh - 0.1)
				view.draw_circle(_p(v, px, dd, pz), 0.8, line)


func _furniture(view: PanelView, v: Dictionary, dims: Vector3, amount: float) -> void:
	var count: int = int(round(clampf(amount, 0.0, 1.0) * 4.0))
	var spots: Array[Vector3] = [Vector3(-0.32, 0.72, 0.0), Vector3(0.3, 0.86, 0.0), Vector3(-0.36, 0.3, 0.0), Vector3(0.34, 0.45, 0.0)]
	var sizes: Array[Vector3] = [Vector3(1.8, 0.8, 0.8), Vector3(1.2, 0.8, 0.75), Vector3(0.6, 1.4, 1.0), Vector3(0.9, 0.9, 0.45)]
	var top: Color = view.col("bg_panel_high").lightened(0.06)
	var front: Color = view.col("bg_panel_high").darkened(0.12)
	var edge: Color = view.col("border_text", 0.5)
	for i: int in count:
		var sz: Vector3 = Vector3(minf(sizes[i].x, dims.x * 0.3), minf(sizes[i].y, dims.y * 0.2), minf(sizes[i].z, dims.z * 0.4))
		var cx: float = spots[i].x * dims.x
		var cy: float = spots[i].y * dims.y
		var x0: float = cx - sz.x * 0.5
		var x1: float = cx + sz.x * 0.5
		var y0: float = cy - sz.y * 0.5
		var y1: float = cy + sz.y * 0.5
		var z1: float = sz.z
		view.draw_colored_polygon(PackedVector2Array([_p(v, x0, y0, 0), _p(v, x1, y0, 0), _p(v, x1, y0, z1), _p(v, x0, y0, z1)]), front)
		view.draw_colored_polygon(PackedVector2Array([_p(v, x0, y0, 0), _p(v, x0, y1, 0), _p(v, x0, y1, z1), _p(v, x0, y0, z1)]), front.darkened(0.1))
		var lid := PackedVector2Array([_p(v, x0, y0, z1), _p(v, x1, y0, z1), _p(v, x1, y1, z1), _p(v, x0, y1, z1)])
		view.draw_colored_polygon(lid, top)
		lid.append(lid[0])
		view.draw_polyline(lid, edge, 1.0, true)


func _reflections(view: PanelView, v: Dictionary, dims: Vector3, me: Vector3, src: Vector3, lively: float) -> void:
	var hw: float = dims.x * 0.5
	var bright: float = view.norm("early") * 0.7 + 0.3 if view.has("early") else 1.0
	var alpha: float = (0.12 + 0.5 * lively) * bright
	var ear: Vector3 = Vector3(me.x, me.y, EAR)
	var images: Array[Vector3] = [Vector3(2.0 * hw - src.x, src.y, src.z), Vector3(-2.0 * hw - src.x, src.y, src.z), Vector3(src.x, 2.0 * dims.y - src.y, src.z), Vector3(src.x, -src.y, src.z), Vector3(src.x, src.y, 2.0 * dims.z - src.z)]
	var planes: Array[Array] = [[0, hw], [0, -hw], [1, dims.y], [1, 0.0], [2, dims.z]]
	var c: Color = view.col("accent")
	for i: int in images.size():
		var img: Vector3 = images[i]
		var axis: int = int(planes[i][0])
		var at: float = float(planes[i][1])
		var span: float = img[axis] - ear[axis]
		if absf(span) < 0.0001:
			continue
		var t: float = (at - ear[axis]) / span
		var hit: Vector3 = ear.lerp(img, t)
		var faded: float = alpha * (0.55 if i == 1 or i == 3 else 1.0)
		view.draw_line(_p(v, src.x, src.y, src.z), _p(v, hit.x, hit.y, hit.z), Color(c, faded), 1.0, true)
		view.draw_line(_p(v, hit.x, hit.y, hit.z), _p(v, ear.x, ear.y, ear.z), Color(c, faded * 0.8), 1.0, true)
		view.draw_circle(_p(v, hit.x, hit.y, hit.z), D.s(1.6), Color(c, minf(1.0, faded * 1.6)))
	if lively > 0.55:
		var img2: Vector3 = Vector3(2.0 * hw - src.x, 2.0 * dims.y - src.y, src.z)
		var t1: float = (dims.y - ear.y) / (img2.y - ear.y) if absf(img2.y - ear.y) > 0.0001 else 0.5
		var mid: Vector3 = ear.lerp(img2, t1)
		var corner: Vector3 = Vector3(hw, mid.y - (mid.x - hw) * (dims.y - mid.y) / maxf(absf(mid.x - hw), 0.0001), src.z)
		var second: float = alpha * 0.55 * (lively - 0.55) / 0.45
		if absf(corner.x) <= hw + 0.001 and corner.y >= 0.0 and corner.y <= dims.y:
			view.draw_polyline(PackedVector2Array([_p(v, src.x, src.y, src.z), _p(v, corner.x, corner.y, corner.z), _p(v, mid.x, dims.y, mid.z), _p(v, ear.x, ear.y, ear.z)]), Color(c, second), 1.0, true)


## The listener: a red ball at ear height with a ring around it that does not touch it, and guide lines out to
## the side walls, down to the floor and up to the ceiling, so its place in the room reads in perspective.
func _listener_ball(view: PanelView, v: Dictionary, dims: Vector3, me: Vector3, src: Vector3) -> void:
	var hw: float = dims.x * 0.5
	var at: Vector2 = _p(v, me.x, me.y, EAR)
	var k: float = float(v["k"])
	var r: float = clampf(0.16 * k, D.s(3.5), D.s(7.0))
	var ring_r: float = r * 1.9
	var floor_at: Vector2 = _p(v, me.x, me.y, 0.0)
	D.ellipse_fill(view, floor_at, r * 1.6, r * 0.6, view.shadow(0.45))
	if view.toggle("guides"):
		var guide: Color = Color(LISTENER_RED, 0.55)
		var faint: Color = Color(LISTENER_RED, 0.28)
		var left_wall: Vector2 = _p(v, -hw, me.y, EAR)
		var right_wall: Vector2 = _p(v, hw, me.y, EAR)
		var ceiling: Vector2 = _p(v, me.x, me.y, dims.z)
		var side: Vector2 = (right_wall - at).normalized()
		var up: Vector2 = (ceiling - at).normalized()
		D.dashed(view, at + side * ring_r, right_wall, faint, 1.0, D.s(3.0), D.s(3.0))
		D.dashed(view, at - side * ring_r, left_wall, faint, 1.0, D.s(3.0), D.s(3.0))
		D.dashed(view, at + up * ring_r, ceiling, faint, 1.0, D.s(3.0), D.s(3.0))
		view.draw_line(at - up * ring_r, floor_at, guide, 1.0, true)
		view.draw_line(at + side * ring_r, at + side * (ring_r + D.s(6.0)), guide, 1.2, true)
		view.draw_line(at - side * ring_r, at - side * (ring_r + D.s(6.0)), guide, 1.2, true)
		view.draw_line(at + up * ring_r, at + up * (ring_r + D.s(6.0)), guide, 1.2, true)
		view.draw_line(at - up * ring_r, at - up * (ring_r + D.s(6.0)), guide, 1.2, true)
		for wall: Vector2 in [left_wall, right_wall]:
			view.draw_circle(wall, D.s(1.6), faint)
	var arrive: float = _arrival(view, dims, me, src) if view.live_on else 0.0
	view.draw_arc(at, ring_r, 0.0, TAU, 40, Color(LISTENER_RED, 0.7 + 0.3 * arrive), 1.2 + 1.3 * arrive, true)
	view.draw_circle(at, r, LISTENER_RED)
	view.draw_circle(at - Vector2(r, r) * 0.32, r * 0.32, Color(1.0, 1.0, 1.0, 0.35))


## How strongly a wave front is passing the listener right now (0 to 1), so the ring flashes when the sound and
## its first reflections reach it.
func _arrival(view: PanelView, dims: Vector3, me: Vector3, src: Vector3) -> float:
	var speed: float = _wave_speed(dims)
	var best: float = 0.0
	for c: Dictionary in _centres(dims, src, _lively(view, dims)):
		var gap: float = Vector2(me.x, me.y).distance_to(Vector2((c["at"] as Vector3).x, (c["at"] as Vector3).y))
		for pl: Dictionary in pulses:
			var radius: float = speed * (view.live_clock - float(pl["born"]))
			var near: float = exp(-pow((radius - gap) / 0.35, 2.0))
			best = maxf(best, near * float(pl["strength"]) * float(c["gain"]))
	return clampf(best * 1.6, 0.0, 1.0)


func _wave_speed(dims: Vector3) -> float:
	return maxf(dims.x, dims.y) / CROSS_SECONDS


## The sound and its mirror images in the walls (the image source picture of reflections): a wave from a mirror
## image, cut to the room, is exactly the wave that bounced off that wall. Livelier rooms show second bounces.
func _centres(dims: Vector3, src: Vector3, lively: float) -> Array[Dictionary]:
	var hw: float = dims.x * 0.5
	var dd: float = dims.y
	var wall: float = 0.35 + 0.55 * lively
	var out: Array[Dictionary] = [{"at": src, "gain": 1.0}]
	for img: Vector3 in [Vector3(2.0 * hw - src.x, src.y, src.z), Vector3(-2.0 * hw - src.x, src.y, src.z), Vector3(src.x, 2.0 * dd - src.y, src.z), Vector3(src.x, -src.y, src.z)]:
		out.append({"at": img, "gain": wall})
	if lively > 0.45:
		var second: float = wall * wall
		for img2: Vector3 in [Vector3(2.0 * hw - src.x, 2.0 * dd - src.y, src.z), Vector3(-2.0 * hw - src.x, 2.0 * dd - src.y, src.z), Vector3(2.0 * hw - src.x, -src.y, src.z), Vector3(-2.0 * hw - src.x, -src.y, src.z), Vector3(src.x + 4.0 * hw, src.y, src.z), Vector3(src.x - 4.0 * hw, src.y, src.z), Vector3(src.x, src.y + 2.0 * dd, src.z), Vector3(src.x, src.y - 2.0 * dd, src.z)]:
			out.append({"at": img2, "gain": second})
	return out


## Wave fronts on the plane at ear height, cut to the inside of the room, fading as the room stops ringing and
## as each bounce loses to the walls.
func _waves(view: PanelView, v: Dictionary, dims: Vector3, me: Vector3, src: Vector3, lively: float) -> void:
	var hw: float = dims.x * 0.5
	var dd: float = dims.y
	var speed: float = _wave_speed(dims)
	var life: float = _life(view)
	var base: Color = view.col("accent")
	var centres: Array[Dictionary] = _centres(dims, src, lively)
	for pl: Dictionary in pulses:
		var age: float = view.live_clock - float(pl["born"])
		var radius: float = speed * age
		if radius <= 0.02:
			continue
		var fade: float = pow(clampf(1.0 - age / life, 0.0, 1.0), 1.4) * float(pl["strength"])
		for c: Dictionary in centres:
			var a: float = fade * float(c["gain"])
			if a < 0.03:
				continue
			var at: Vector3 = c["at"]
			var run: PackedVector2Array = PackedVector2Array()
			for i: int in CIRCLE_STEPS + 1:
				var th: float = TAU * float(i) / float(CIRCLE_STEPS)
				var x: float = at.x + cos(th) * radius
				var y: float = at.y + sin(th) * radius
				if absf(x) <= hw and y >= 0.0 and y <= dd:
					run.append(_p(v, x, y, EAR))
				else:
					if run.size() > 1:
						view.draw_polyline(run, Color(base, minf(a, 0.9)), 1.2 + a, true)
					run = PackedVector2Array()
			if run.size() > 1:
				view.draw_polyline(run, Color(base, minf(a, 0.9)), 1.2 + a, true)


func _labels(view: PanelView, v: Dictionary, dims: Vector3) -> void:
	var hw: float = dims.x * 0.5
	if _sized(view):
		var at: Vector2 = _p(v, hw, 0.0, dims.z) + Vector2(D.s(10.0), D.s(4.0))
		view.text(at, view.label("size") + " " + view.shown("size"), "text_dim")
		return
	if view.has("width"):
		var a: Vector2 = _p(v, 0.0, 0.0, 0.0)
		view.text(a + Vector2(-D.s(24.0), D.s(14.0)), view.shown("width"), "text_dim", "font_tiny", D.s(48.0), HORIZONTAL_ALIGNMENT_CENTER)
	if view.has("depth"):
		var b: Vector2 = _p(v, hw, dims.y * 0.72, 0.0)
		view.text(b + Vector2(D.s(8.0), D.s(12.0)), view.shown("depth"), "text_dim")
	if view.has("height"):
		var c: Vector2 = _p(v, hw, 0.0, dims.z * 0.45)
		view.text(c + Vector2(D.s(7.0), D.s(4.0)), view.shown("height"), "text_dim")


func _handle_parts(view: PanelView) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if _sized(view):
		out.append(CORNER)
		return out
	if view.has("width"):
		out.append(WIDE)
	if view.has("depth"):
		out.append(DEEP)
	if view.has("height"):
		out.append(TALL)
	return out


func _handle_base(v: Dictionary, dims: Vector3, part: String) -> Vector2:
	var hw: float = dims.x * 0.5
	match part:
		WIDE:
			return _p(v, hw, dims.y * 0.5, dims.z * 0.5)
		DEEP:
			return _p(v, 0.0, dims.y, dims.z * 0.5)
		TALL, CORNER:
			return _p(v, hw, 0.0, dims.z)
	return Vector2.ZERO


func _handle_dir(v: Dictionary, part: String) -> Vector2:
	var a: Array[Vector2] = _axes(float(v["k"]))
	match part:
		WIDE:
			return a[0].normalized()
		DEEP:
			return a[1].normalized()
		TALL:
			return a[2].normalized()
	return (a[0] - a[1] + a[2]).normalized()


func _handle_at(v: Dictionary, dims: Vector3, part: String) -> Vector2:
	var base: Vector2 = _handle_base(v, dims, part)
	if part == CORNER:
		return base
	return base + _handle_dir(v, part) * D.s(24.0)


func _handle(view: PanelView, base: Vector2, at: Vector2, dir: Vector2, lit: bool) -> void:
	var r: float = D.s(5.5 if lit else 4.5)
	if base.distance_to(at) > r:
		view.draw_line(base, at - dir * r, view.col("accent", 0.7), 1.0, true)
		view.draw_circle(base, D.s(1.8), view.col("accent", 0.8))
	if lit:
		view.draw_circle(at, r + D.s(4.0), view.col("accent", 0.14))
	view.draw_circle(at, r, view.col("accent") if lit else view.col("bg_shell"))
	view.draw_arc(at, r, 0.0, TAU, 20, view.col("accent"), 1.3, true)
	var side: Vector2 = dir * (r * 0.55)
	var ink: Color = view.col("bg_shell") if lit else view.col("accent")
	D.arrow_head(view, at + side * 1.2, dir, r * 0.7, ink)
	D.arrow_head(view, at - side * 1.2, -dir, r * 0.7, ink)


func _words(view: PanelView, dims: Vector3) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _sized(view):
		parts.append(view.label("size") + " " + view.shown("size"))
	else:
		if view.has("width"):
			parts.append(view.shown("width") + " wide")
		if view.has("depth"):
			parts.append(view.shown("depth") + " deep")
		if view.has("height"):
			parts.append(view.shown("height") + " high")
	if view.has("walls"):
		parts.append(view.shown("walls").to_lower() + " walls")
		var absorb: Array = view.option("wall_absorb", ABSORB) as Array
		var i: int = clampi(int(round(view.value("walls"))), 0, absorb.size() - 1)
		var a: float = float(absorb[i]) + (view.value("furnished") * 0.16 if view.has("furnished") else 0.0)
		if view.has("width") and view.has("depth") and view.has("height"):
			parts.append("rings for about " + String.num(_ring_time(dims, a), 1) + " s")
	elif view.has("decay"):
		parts.append(view.label("decay").to_lower() + " " + view.shown("decay"))
	return ", ".join(parts)


func _hit(view: PanelView, at: Vector2) -> String:
	var dims: Vector3 = _dims(view)
	var v: Dictionary = _view(view, dims)
	for part: String in _handle_parts(view):
		if at.distance_to(_handle_at(v, dims, part)) < D.s(10.0):
			return part
	if view.has("across") or view.has("distance"):
		var src: Vector3 = _source(view, dims)
		if at.distance_to(_p(v, src.x, src.y, src.z)) < D.s(12.0) or at.distance_to(_p(v, src.x, src.y, 0.0)) < D.s(9.0):
			return SOURCE
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _hit(view, at)


func press(view: PanelView, at: Vector2) -> String:
	var part: String = _hit(view, at)
	if part.is_empty():
		return ""
	var dims: Vector3 = _dims(view)
	var v: Dictionary = _view(view, dims)
	view.frozen["k"] = v["k"]
	view.frozen["o"] = v["o"]
	view.frozen["dims"] = dims
	view.frozen["src"] = _source(view, dims)
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var dims0: Vector3 = view.frozen.get("dims", _dims(view))
	var a: Array[Vector2] = _axes(float(view.frozen.get("k", 1.0)))
	var move: Vector2 = at - view.press_at
	var out: Dictionary = {}
	if part == SOURCE:
		var det: float = a[0].x * a[1].y - a[0].y * a[1].x
		if absf(det) < 0.0001:
			return out
		var dx: float = (move.x * a[1].y - move.y * a[1].x) / det
		var dy: float = (a[0].x * move.y - a[0].y * move.x) / det
		var s0: Vector3 = view.frozen.get("src", _source(view, dims0))
		var me: Vector3 = _listener(dims0)
		if view.has("across"):
			var room_x: float = maxf(0.0, dims0.x * 0.5 - 0.3)
			out["across"] = clampf((s0.x + dx) / room_x, -1.0, 1.0) if room_x > 0.0 else 0.0
		if view.has("distance"):
			out["distance"] = clampf(s0.y + dy, me.y, dims0.y - 0.3) - me.y
		return out
	var axis: Vector2 = a[0] if part == WIDE else (a[1] if part == DEEP else a[2])
	if part == CORNER:
		axis = a[0] + a[1] + a[2]
	var amount: float = move.dot(axis) / maxf(axis.length_squared(), 0.0001)
	if _sized(view):
		var grow: float = 1.0
		match part:
			WIDE:
				grow = (dims0.x + 2.0 * amount) / maxf(dims0.x, 0.001)
			DEEP:
				grow = (dims0.y + amount) / maxf(dims0.y, 0.001)
			TALL:
				grow = (dims0.z + amount) / maxf(dims0.z, 0.001)
			CORNER:
				grow = 1.0 + amount * 3.0 / maxf(dims0.x * 0.5 + dims0.y + dims0.z, 0.001)
		var sc0: float = _scale_of(view, (view.start_value("size") - view.low("size")) / maxf(view.high("size") - view.low("size"), 0.0001))
		out["size"] = view.denorm("size", _t_of_scale(view, sc0 * maxf(grow, 0.05)))
		return out
	match part:
		WIDE:
			out["width"] = dims0.x + 2.0 * amount
		DEEP:
			out["depth"] = dims0.y + amount
		TALL:
			out["height"] = dims0.z + amount
	return out
