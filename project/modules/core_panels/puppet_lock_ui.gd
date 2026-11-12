extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Puppet := preload("res://doc/puppet.gd")
const PuppetLocks := preload("res://doc/puppet_locks.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const UI_PATH := "res://modules/core_panels/puppet_ui.gd"
const SELF_PATH := "res://modules/core_panels/puppet_lock_ui.gd"
const BRUSH_MIN := 2.0
const BRUSH_MAX := 600.0
const BRUSH_STEP := 1.25
const AREA_REACH := 8.0
const RING_REACH := 6.0
const AREA_HALF := 5.0
const AREA_INK := Color(1.0, 0.3, 0.3, 1.0)
const AREA_RING := Color(1.0, 0.45, 0.35, 0.9)
const CURSOR_INK := Color(1.0, 1.0, 1.0, 0.9)
const CURSOR_SOFT := Color(1.0, 1.0, 1.0, 0.45)
const CURSOR_ERASE := Color(0.55, 0.85, 1.0, 0.9)
const RIM := Color(0.0, 0.0, 0.0, 0.7)
const PICK_INK := Color(1.0, 1.0, 1.0, 1.0)
const LEAST_AREA := 4.0

static var brush_px: float = 40.0
static var strength: float = 100.0
static var softness: float = 50.0
static var hover: Vector2 = Vector2(-1.0e9, -1.0e9)
static var hover_erase: bool = false
static var sel_areas: PackedInt32Array = PackedInt32Array()
static var _drag: Dictionary = {}


static func _ui() -> GDScript:
	return load(UI_PATH)


static func painting() -> bool:
	return String(_drag.get("kind", "")) == "paint"


static func dragging() -> bool:
	return not _drag.is_empty()


static func clear() -> void:
	_drag = {}
	sel_areas = PackedInt32Array()


static func brush_layer_px(panel: Object, pic: Rect2, c: Clip) -> float:
	var xf: Transform2D = _ui().call("layer_xf", panel, pic, c)
	var k: float = sqrt(absf(xf.determinant()))
	return brush_px / maxf(k, 0.0001)


static func grow_brush(up: bool) -> void:
	brush_px = clampf(brush_px * (BRUSH_STEP if up else 1.0 / BRUSH_STEP), BRUSH_MIN, BRUSH_MAX)


static func area_spots(d: Project, s: Sequence, c: Clip, e: Dictionary) -> PackedVector2Array:
	return _ui().call("spots_of", d, s, c, e, PuppetLocks.areas_of(e))


static func hit_area(panel: Object, pic: Rect2, c: Clip, screen: Vector2) -> Dictionary:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return {}
	var spots: PackedVector2Array = area_spots(d, s, c, e)
	var xf: Transform2D = _ui().call("layer_xf", panel, pic, c)
	var best: int = -1
	var best_d: float = AREA_REACH
	for i: int in spots.size():
		var dd: float = (xf * spots[i]).distance_to(screen)
		if dd <= best_d:
			best_d = dd
			best = i
	if best >= 0:
		return {"kind": "area", "index": best}
	var av: Dictionary = PuppetLocks.area_values(e)
	var radii: PackedFloat64Array = av["r"]
	for j: int in sel_areas:
		if j >= spots.size() or j >= radii.size():
			continue
		var centre: Vector2 = xf * spots[j]
		var rp: float = (xf * (spots[j] + Vector2(radii[j], 0.0))).distance_to(centre)
		if absf(centre.distance_to(screen) - rp) <= RING_REACH:
			return {"kind": "area_ring", "index": j}
	return {}


static func paint_target(panel: Object, pic: Rect2, at_screen: Vector2) -> Clip:
	var s: Sequence = panel.call("seq")
	var at_seq: Vector2 = (at_screen - pic.position) / maxf(pic.size.x / maxf(float(s.width), 1.0), 0.0001)
	var c: Clip = _ui().call("target_clip", panel, at_seq, pic, at_screen)
	if c == null or Puppet.any_effect_of(c).is_empty():
		var focus: Clip = panel.call("gizmo_clip")
		if focus != null and not Puppet.any_effect_of(focus).is_empty():
			return focus
		return null
	return c


static func _rest_at(d: Project, s: Sequence, c: Clip, e: Dictionary, layer_p: Vector2) -> Vector2:
	var made: Dictionary = _ui().call("_bent", d, s, c, e)
	return Puppet.rest_point(made["mesh"], made["verts"], layer_p, made["drawn"])


static func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		hover = mm.position
		hover_erase = mm.alt_pressed
		if _drag.is_empty():
			_ui().call("_redraw", panel)
			return false
		_motion(d, s, panel, pic, mm.position)
		_ui().call("_redraw", panel)
		return true
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not mb.pressed:
		_release(d, s, panel, pic, mb.position)
		Puppet.draft_ok = false
		_ui().call("_redraw", panel)
		return true
	var c: Clip = paint_target(panel, pic, mb.position)
	if c == null:
		Events.toast("Put a pin on the picture first, then paint locks on it")
		return true
	var e: Dictionary = Puppet.any_effect_of(c)
	var hit: Dictionary = hit_area(panel, pic, c, mb.position)
	var kind: String = String(hit.get("kind", ""))
	var index: int = int(hit.get("index", -1))
	var layer_p: Vector2 = _ui().call("screen_to_layer", panel, pic, c, mb.position)
	Puppet.draft_ok = true
	if kind == "area" and mb.alt_pressed:
		drop_area(d, s, c, index)
	elif kind == "area":
		_pick(index, mb.shift_pressed)
		_drag = {"clip_id": c.id, "kind": "area", "index": index}
	elif kind == "area_ring":
		_drag = {"clip_id": c.id, "kind": "area_ring", "index": index}
	elif mb.shift_pressed:
		var at: Vector2 = _rest_at(d, s, c, e, layer_p)
		_drag = {"clip_id": c.id, "kind": "new_area", "at": at, "from": mb.position, "to": mb.position, "layer_from": layer_p}
	else:
		var size: Vector2 = Puppet.size_of(e, _ui().call("layer_size", d, s, c))
		var dims: Vector2i = PuppetLocks.map_size(size)
		var start: PackedByteArray = PuppetLocks.start_bytes(e, size)
		var at2: Vector2 = _rest_at(d, s, c, e, layer_p)
		var radius: float = brush_layer_px(panel, pic, c)
		var bytes: PackedByteArray = PuppetLocks.stamp(start, dims.x, dims.y, size, at2, radius, strength / 100.0, softness / 100.0, mb.alt_pressed)
		_drag = {"clip_id": c.id, "kind": "paint", "bytes": bytes, "w": dims.x, "h": dims.y, "size": size, "last": at2, "erase": mb.alt_pressed, "radius": radius, "uid": String(e.get("uid", ""))}
	_ui().call("_redraw", panel)
	return true


static func _pick(index: int, add: bool) -> void:
	if add:
		if sel_areas.has(index):
			sel_areas.remove_at(sel_areas.find(index))
		else:
			sel_areas.append(index)
	elif not sel_areas.has(index):
		sel_areas = PackedInt32Array([index])


static func _motion(d: Project, s: Sequence, panel: Object, pic: Rect2, at: Vector2) -> void:
	var c: Clip = s.clip_by_id(String(_drag.get("clip_id", "")))
	if c == null:
		_drag = {}
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		_drag = {}
		return
	var layer_p: Vector2 = _ui().call("screen_to_layer", panel, pic, c, at)
	var kind: String = String(_drag["kind"])
	if kind == "paint":
		var to: Vector2 = _rest_at(d, s, c, e, layer_p)
		_drag["bytes"] = PuppetLocks.stroke(_drag["bytes"], int(_drag["w"]), int(_drag["h"]), _drag["size"], _drag["last"], to, float(_drag["radius"]), strength / 100.0, softness / 100.0, bool(_drag["erase"]))
		_drag["last"] = to
	elif kind == "new_area":
		_drag["to"] = at
		_drag["radius"] = maxf((layer_p - Vector2(_drag["layer_from"])).length(), 1.0)
	elif kind == "area":
		move_area_live(d, s, c, int(_drag["index"]), _rest_at(d, s, c, e, layer_p))
	elif kind == "area_ring":
		var spots: PackedVector2Array = area_spots(d, s, c, e)
		var j: int = int(_drag["index"])
		if j < spots.size():
			value_live(d, s, c, PuppetLocks.area_key(j, "r"), snappedf(maxf(spots[j].distance_to(layer_p), 1.0), 0.1))


static func _release(d: Project, s: Sequence, panel: Object, pic: Rect2, at: Vector2) -> void:
	if _drag.is_empty():
		return
	var was: Dictionary = _drag
	_drag = {}
	var c: Clip = s.clip_by_id(String(was.get("clip_id", "")))
	if c == null:
		return
	var kind: String = String(was["kind"])
	if kind == "paint":
		commit_map(d, s, c, was["bytes"], int(was["w"]), int(was["h"]), "Erase locks" if bool(was["erase"]) else "Paint locks")
	elif kind == "new_area":
		var r: float = float(was.get("radius", 0.0))
		if (at - Vector2(was["from"])).length() < LEAST_AREA:
			r = maxf(brush_layer_px(panel, pic, c), 4.0)
		var made: int = add_area(d, s, c, was["at"], r)
		if made >= 0:
			sel_areas = PackedInt32Array([made])
	elif kind == "area":
		d.undo.commit_live("Move lock area")
	elif kind == "area_ring":
		d.undo.commit_live("Change lock area size")


static func commit_map(d: Project, s: Sequence, c: Clip, bytes: PackedByteArray, w: int, h: int, label: String) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return false
	var cmds: Array[Command] = [EffectCmds.SetEffectEntry.new(s.id, c.id, String(e.get("uid", "")), {PuppetLocks.FIELD: PuppetLocks.encode(bytes, w, h)}, false, label)]
	if not (e.get("params", {}) as Dictionary).has(PuppetLocks.KEY_AMOUNT):
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, _ui().call("path_of", e, PuppetLocks.KEY_AMOUNT), AnimProp.make(PuppetLocks.AMOUNT_DEFAULT)))
	return bool(_ui().call("_run", d, label, cmds))


static func clear_map(d: Project, s: Sequence, c: Clip) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty() or PuppetLocks.info_of(e).is_empty():
		return false
	var cmds: Array[Command] = [EffectCmds.SetEffectEntry.new(s.id, c.id, String(e.get("uid", "")), {PuppetLocks.FIELD: {}}, false, "Clear painted locks")]
	return bool(_ui().call("_run", d, "Clear painted locks", cmds))


static func add_area(d: Project, s: Sequence, c: Clip, at: Vector2, radius: float) -> int:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return -1
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var areas: PackedVector2Array = PuppetLocks.areas_of(e)
	var j: int = areas.size()
	areas.append(at)
	params[PuppetLocks.KEY_AREAS] = AnimProp.make(Puppet.flat(areas))
	params[PuppetLocks.area_key(j, "r")] = AnimProp.make(snappedf(radius, 0.1))
	params[PuppetLocks.area_key(j, "s")] = AnimProp.make(strength)
	params[PuppetLocks.area_key(j, "f")] = AnimProp.make(softness)
	if not params.has(PuppetLocks.KEY_AMOUNT):
		params[PuppetLocks.KEY_AMOUNT] = AnimProp.make(PuppetLocks.AMOUNT_DEFAULT)
	_ui().call("_set_params", d, s, c, e, params, "Add lock area")
	return j


static func drop_area(d: Project, s: Sequence, c: Clip, index: int) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	var areas: PackedVector2Array = PuppetLocks.areas_of(e)
	if e.is_empty() or index < 0 or index >= areas.size():
		return false
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var kept: PackedVector2Array = PackedVector2Array()
	var props: Array = []
	for i: int in areas.size():
		var row: Array = []
		for part: String in ["r", "s", "f"]:
			row.append(params.get(PuppetLocks.area_key(i, part), null))
			params.erase(PuppetLocks.area_key(i, part))
		if i == index:
			continue
		kept.append(areas[i])
		props.append(row)
	for n: int in props.size():
		var parts: PackedStringArray = ["r", "s", "f"]
		for q: int in 3:
			if props[n][q] != null:
				params[PuppetLocks.area_key(n, parts[q])] = props[n][q]
	if kept.is_empty():
		params.erase(PuppetLocks.KEY_AREAS)
	else:
		params[PuppetLocks.KEY_AREAS] = AnimProp.make(Puppet.flat(kept))
	sel_areas = PackedInt32Array()
	return bool(_ui().call("_set_params", d, s, c, e, params, "Remove lock area"))


static func move_area_live(d: Project, s: Sequence, c: Clip, index: int, at: Vector2) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	var areas: PackedVector2Array = PuppetLocks.areas_of(e)
	if e.is_empty() or index < 0 or index >= areas.size():
		return
	areas[index] = at
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, _ui().call("path_of", e, PuppetLocks.KEY_AREAS), AnimProp.make(Puppet.flat(areas))))


static func value_live(d: Project, s: Sequence, c: Clip, key: String, v: float) -> void:
	_ui().call("value_live", d, s, c, key, v)


static func shown_effect(c: Clip, e: Dictionary) -> Dictionary:
	if not painting() or String(_drag.get("clip_id", "")) != c.id:
		return e
	var fake: Dictionary = e.duplicate()
	fake[PuppetLocks.FIELD] = PuppetLocks.encode(_drag["bytes"], int(_drag["w"]), int(_drag["h"]))
	return fake


static func draw_overlay(ci: CanvasItem, c: Clip, e: Dictionary, made: Dictionary, screen: PackedVector2Array) -> void:
	var shown: Dictionary = shown_effect(c, e)
	if not PuppetLocks.has_locks(shown):
		return
	var mesh: Dictionary = made["mesh"]
	var tex: ImageTexture = PuppetLocks.texture(shown, mesh["size"])
	var tris: PackedInt32Array = mesh["tris"]
	var uv: PackedVector2Array = mesh["uv"]
	if screen.size() != uv.size() or tris.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tris, screen, PackedColorArray([Color.WHITE]), uv, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


static func draw_marks(ci: CanvasItem, panel: Object, pic: Rect2, d: Project, s: Sequence, c: Clip, e: Dictionary, xf: Transform2D, in_mode: bool) -> void:
	var spots: PackedVector2Array = area_spots(d, s, c, e)
	var av: Dictionary = PuppetLocks.area_values(e)
	var radii: PackedFloat64Array = av["r"]
	var soft: PackedFloat64Array = av["f"]
	for i: int in spots.size():
		var p: Vector2 = xf * spots[i]
		var picked: bool = sel_areas.has(i)
		if in_mode and i < radii.size():
			var rp: float = (xf * (spots[i] + Vector2(radii[i], 0.0))).distance_to(p)
			ci.draw_arc(p, rp, 0.0, TAU, 64, RIM, 3.0, true)
			ci.draw_arc(p, rp, 0.0, TAU, 64, AREA_RING if picked else Color(AREA_RING, 0.45), 1.5, true)
			if picked and i < soft.size() and soft[i] > 0.01:
				ci.draw_arc(p, rp * (1.0 - soft[i]), 0.0, TAU, 48, Color(AREA_RING, 0.4), 1.0, true)
		var h: float = AREA_HALF
		ci.draw_rect(Rect2(p - Vector2(h + 1.5, h + 1.5), Vector2(h + 1.5, h + 1.5) * 2.0), RIM)
		ci.draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), AREA_INK)
		ci.draw_line(p + Vector2(-h * 0.6, 0.0), p + Vector2(h * 0.6, 0.0), RIM, 1.5)
		if picked:
			ci.draw_rect(Rect2(p - Vector2(h + 3.0, h + 3.0), Vector2(h + 3.0, h + 3.0) * 2.0), PICK_INK, false, 1.5)
	if String(_drag.get("kind", "")) == "new_area" and String(_drag.get("clip_id", "")) == c.id:
		var centre: Vector2 = Vector2(_drag["from"])
		var rad: float = centre.distance_to(Vector2(_drag["to"]))
		ci.draw_arc(centre, rad, 0.0, TAU, 64, RIM, 3.0, true)
		ci.draw_arc(centre, rad, 0.0, TAU, 64, AREA_RING, 1.5, true)
	if in_mode and hover.x > -1.0e8 and pic.has_point(hover) and String(_drag.get("kind", "")) != "new_area":
		var ink: Color = CURSOR_ERASE if (hover_erase or bool(_drag.get("erase", false))) else CURSOR_INK
		ci.draw_arc(hover, brush_px, 0.0, TAU, 48, RIM, 3.0, true)
		ci.draw_arc(hover, brush_px, 0.0, TAU, 48, ink, 1.5, true)
		var inner: float = brush_px * (1.0 - softness / 100.0)
		if inner > 1.0 and inner < brush_px - 1.0:
			ci.draw_arc(hover, inner, 0.0, TAU, 40, CURSOR_SOFT, 1.0, true)
