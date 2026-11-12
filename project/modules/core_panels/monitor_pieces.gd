extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Verbs := preload("res://doc/verbs.gd")
const PIECE_EFFECTS: PackedStringArray = ["crumble_3d", "glass_break"]
const GLOW := Color(1.0, 0.78, 0.32)
const HOVER := Color(1.0, 1.0, 1.0, 0.55)
const MARK := Color(0.45, 0.85, 1.0)
const M_HEAD := "piece_head"
const M_SET := "piece_set"
const M_PIN := "piece_pin"
const M_FLOAT := "piece_float"
const M_HEAVY := "piece_heavy"
const M_RESET := "piece_reset"
const M_RESET_ALL := "piece_reset_all"

static var selected: Dictionary = {}
static var hover_index: int = -1
static var _faces: Dictionary = {}
static var plant_no_inverse: bool = false


static func ray_for(cam_pos: Vector3, fov_deg: float, asp: float, uv: Vector2) -> Array:
	var th: float = tan(deg_to_rad(fov_deg) * 0.5)
	var ndc := Vector2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0)
	var dir := Vector3(ndc.x * th * asp, ndc.y * th, -1.0).normalized()
	return [cam_pos, dir]


static func project_uv(cam_pos: Vector3, fov_deg: float, asp: float, w: Vector3) -> Vector2:
	var th: float = tan(deg_to_rad(fov_deg) * 0.5)
	var r: Vector3 = w - cam_pos
	var depth: float = maxf(-r.z, 0.0001)
	var ndc := Vector2(r.x / (depth * th * asp), r.y / (depth * th))
	return Vector2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5)


static func faces_of(mesh: Mesh) -> PackedVector3Array:
	if mesh == null:
		return PackedVector3Array()
	var id: int = mesh.get_instance_id()
	if _faces.has(id):
		return _faces[id]
	if _faces.size() > 4096:
		_faces.clear()
	var f: PackedVector3Array = mesh.get_faces()
	_faces[id] = f
	return f


static func ray_triangle(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1: Vector3 = b - a
	var e2: Vector3 = c - a
	var pv: Vector3 = d.cross(e2)
	var det: float = e1.dot(pv)
	if absf(det) < 1e-9:
		return -1.0
	var inv: float = 1.0 / det
	var tv: Vector3 = o - a
	var u: float = tv.dot(pv) * inv
	if u < 0.0 or u > 1.0:
		return -1.0
	var qv: Vector3 = tv.cross(e1)
	var v: float = d.dot(qv) * inv
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t: float = e2.dot(qv) * inv
	return t if t > 0.0 else -1.0


static func pick(transforms: Array, meshes: Array, o: Vector3, d: Vector3) -> int:
	var best: int = -1
	var best_t: float = INF
	for i: int in mini(transforms.size(), meshes.size()):
		var mesh: Mesh = meshes[i]
		if mesh == null:
			continue
		var xf: Transform3D = transforms[i]
		var box: AABB = mesh.get_aabb()
		var centre: Vector3 = xf * box.get_center()
		var rad: float = box.size.length() * 0.5 * maxf(xf.basis.get_scale().x, maxf(xf.basis.get_scale().y, xf.basis.get_scale().z))
		var along: float = (centre - o).dot(d)
		if (o + d * along - centre).length() > rad:
			continue
		var inv: Transform3D = xf if plant_no_inverse else xf.affine_inverse()
		var lo: Vector3 = inv * o
		var ld: Vector3 = inv.basis * d
		var f: PackedVector3Array = faces_of(mesh)
		var k: int = 0
		while k + 2 < f.size():
			var t: float = ray_triangle(lo, ld, f[k], f[k + 1], f[k + 2])
			if t > 0.0 and t < best_t:
				best_t = t
				best = i
			k += 3
	return best


static func hull_uv(xf: Transform3D, mesh: Mesh, cam_pos: Vector3, fov_deg: float, asp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var f: PackedVector3Array = faces_of(mesh)
	var seen: Dictionary = {}
	for v: Vector3 in f:
		if seen.has(v):
			continue
		seen[v] = true
		pts.append(project_uv(cam_pos, fov_deg, asp, xf * v))
	if pts.size() < 3:
		return pts
	return Geometry2D.convex_hull(pts)


static func target(panel: Object) -> Dictionary:
	var hs: Object = panel.call("monitor_handles")
	if hs == null:
		return {}
	var fe: Dictionary = hs.call("focused_entry", panel)
	if fe.is_empty():
		return {}
	var e: Dictionary = fe["entry"]
	if not PIECE_EFFECTS.has(String(e.get("id", ""))):
		return {}
	var c: Clip = fe["clip"]
	var p: Object = stage_pass(c.id, String(e.get("uid", "")))
	if p == null:
		return {}
	return {"clip": c, "entry": e, "pass": p}


static func stage_pass(clip_id: String, uid: String) -> Object:
	var comp: Object = Session.compositor
	if comp == null or not is_instance_valid(comp):
		return null
	var layers: Variant = comp.get("layers")
	if not (layers is Dictionary) or not (layers as Dictionary).has(clip_id):
		return null
	var l: Object = (layers as Dictionary)[clip_id]
	if l == null or not is_instance_valid(l):
		return null
	for pd: Dictionary in l.get("passes"):
		if String(pd.get("uid", "")) == uid:
			var p: Object = pd.get("pass", null)
			if p != null and is_instance_valid(p) and p.get("pieces") != null and p.get("cam") != null:
				return p
	return null


static func _scene(p: Object) -> Dictionary:
	var cam: Camera3D = p.get("cam")
	var sz: Vector2 = Vector2(p.get("size"))
	var transforms: Array = []
	var meshes: Array = []
	for mi: Variant in p.get("pieces"):
		if mi is MeshInstance3D and is_instance_valid(mi):
			transforms.append((mi as MeshInstance3D).transform)
			meshes.append((mi as MeshInstance3D).mesh)
		else:
			transforms.append(Transform3D())
			meshes.append(null)
	return {"cam_pos": cam.position, "fov": cam.fov, "asp": sz.x / maxf(sz.y, 1.0), "transforms": transforms, "meshes": meshes}


static func _xf(panel: Object, c: Clip) -> Transform2D:
	var made: Dictionary = panel.call("quad_for", c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4:
		return Transform2D()
	var qq: PackedVector2Array = q
	return Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])


static func _k(panel: Object, pic: Rect2) -> float:
	var s: Sequence = panel.call("seq")
	return pic.size.x / maxf(float(s.width), 1.0) if s != null else 1.0


static func uv_at(panel: Object, pic: Rect2, c: Clip, at: Vector2) -> Vector2:
	var xf: Transform2D = _xf(panel, c)
	if absf(xf.determinant()) < 1e-6:
		return Vector2(-1.0, -1.0)
	var sq: Vector2 = (at - pic.position) / maxf(_k(panel, pic), 0.0001)
	return xf.affine_inverse() * sq


static func piece_at(panel: Object, pic: Rect2, tg: Dictionary, at: Vector2) -> int:
	var uv: Vector2 = uv_at(panel, pic, tg["clip"], at)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return -1
	var sc: Dictionary = _scene(tg["pass"])
	var ray: Array = ray_for(sc["cam_pos"], float(sc["fov"]), float(sc["asp"]), uv)
	return pick(sc["transforms"], sc["meshes"], ray[0], ray[1])


static func _on_handle(panel: Object, pic: Rect2, at: Vector2) -> bool:
	var hs: Object = panel.call("monitor_handles")
	return hs != null and not (hs.call("hit", panel, pic, at) as Dictionary).is_empty()


static func is_selected(c: Clip, uid: String) -> int:
	if selected.is_empty() or c == null:
		return -1
	if String(selected.get("clip", "")) != c.id or String(selected.get("uid", "")) != uid:
		return -1
	return int(selected.get("index", -1))


static func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	var tg: Dictionary = target(panel)
	if tg.is_empty():
		if hover_index >= 0:
			hover_index = -1
		return false
	var view: Control = panel.get("view")
	var c: Clip = tg["clip"]
	var uid: String = String((tg["entry"] as Dictionary).get("uid", ""))
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if mm.button_mask != 0:
			return false
		var h: int = -1 if _on_handle(panel, pic, mm.position) else piece_at(panel, pic, tg, mm.position)
		if h != hover_index:
			hover_index = h
			if view != null:
				view.call("redraw_overlay")
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if not mb.pressed or (mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT):
		return false
	if _on_handle(panel, pic, mb.position):
		return false
	var i: int = piece_at(panel, pic, tg, mb.position)
	if i < 0:
		if mb.button_index == MOUSE_BUTTON_LEFT and not selected.is_empty():
			selected = {}
			if view != null:
				view.call("redraw_overlay")
		return false
	selected = {"clip": c.id, "uid": uid, "index": i}
	if view != null:
		view.call("redraw_overlay")
		view.accept_event()
	if mb.button_index == MOUSE_BUTTON_RIGHT and view != null:
		open_menu(panel, view, mb.global_position, c, tg["entry"], i)
	return true


static func override_of(e: Dictionary, index: int) -> Dictionary:
	var pieces: Variant = e.get("pieces", null)
	if not (pieces is Dictionary):
		return {}
	var ov: Variant = (pieces as Dictionary).get(str(index), null)
	return ov if ov is Dictionary else {}


static func describe(ov: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if ov.has("weight"):
		parts.append("pinned" if float(ov["weight"]) <= 0.0 else "weight " + String.num(float(ov["weight"]), 2))
	if ov.has("gravity"):
		parts.append("floats" if float(ov["gravity"]) <= 0.0 else "gravity " + String.num(float(ov["gravity"]), 2))
	return ", ".join(parts)


static func menu_items(e: Dictionary, index: int) -> Array:
	var ov: Dictionary = override_of(e, index)
	var head: String = "Piece " + str(index + 1)
	if not ov.is_empty():
		head += " (" + describe(ov) + ")"
	var head_item: Dictionary = PmMenu.item(M_HEAD, head)
	head_item["disabled"] = true
	var items: Array = [head_item, PmMenu.separator()]
	items.append(PmMenu.item(M_SET, "Weight and gravity of this piece..."))
	items.append(PmMenu.item(M_PIN, "Pin it in place"))
	items.append(PmMenu.item(M_FLOAT, "Let it float"))
	items.append(PmMenu.item(M_HEAVY, "Make it heavy"))
	items.append(PmMenu.separator())
	var reset: Dictionary = PmMenu.item(M_RESET, "Reset this piece")
	reset["disabled"] = ov.is_empty()
	items.append(reset)
	var reset_all: Dictionary = PmMenu.item(M_RESET_ALL, "Reset every piece")
	reset_all["disabled"] = not (e.get("pieces", null) is Dictionary) or (e["pieces"] as Dictionary).is_empty()
	items.append(reset_all)
	return items


static func open_menu(panel: Object, anchor: Control, at: Vector2, c: Clip, e: Dictionary, index: int) -> Control:
	var m: Control = PmMenu.open(anchor, menu_items(e, index), at)
	var uid: String = String(e.get("uid", ""))
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: on_menu(panel, anchor, id, c.id, uid, index))
	return m


static func apply(d: Project, s: Sequence, clip_id: String, uid: String, id: String, index: int) -> bool:
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	var ov: Dictionary = override_of(e, index).duplicate(true)
	if id == M_PIN:
		ov["weight"] = 0.0
		ov.erase("gravity")
	elif id == M_FLOAT:
		ov["gravity"] = 0.0
		if ov.has("weight") and float(ov["weight"]) <= 0.0:
			ov.erase("weight")
	elif id == M_HEAVY:
		ov["weight"] = 8.0
	elif id == M_RESET:
		ov = {}
	elif id == M_RESET_ALL:
		var cmd := EffectCmds.SetEffectEntry.new(s.id, c.id, uid, {"pieces": null}, c.is_audio_effect(uid), "Reset every piece")
		return Verbs.run(d, cmd.label, [cmd])
	else:
		return false
	return Verbs.set_piece_override(d, s, clip_id, uid, index, ov)


static func set_values(d: Project, s: Sequence, clip_id: String, uid: String, index: int, weight_text: String, gravity_text: String) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var ov: Dictionary = {}
	var w: Dictionary = PmField.parse_text(weight_text, false)
	if not weight_text.strip_edges().is_empty() and bool(w["ok"]):
		ov["weight"] = maxf(0.0, float(w["value"]))
	var g: Dictionary = PmField.parse_text(gravity_text, false)
	if not gravity_text.strip_edges().is_empty() and bool(g["ok"]):
		ov["gravity"] = maxf(0.0, float(g["value"]))
	return Verbs.set_piece_override(d, s, clip_id, uid, index, ov)


static func on_menu(panel: Object, anchor: Control, id: String, clip_id: String, uid: String, index: int) -> void:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if id == M_SET:
		_ask(anchor, d, s, clip_id, uid, index)
		return
	apply(d, s, clip_id, uid, id, index)


static func _ask(anchor: Control, d: Project, s: Sequence, clip_id: String, uid: String, index: int) -> void:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return
	var ov: Dictionary = override_of(c.effect_by_uid(uid), index)
	var fields: Array[Dictionary] = [
		{"key": "note", "type": "note", "default": "Leave a box empty to use the effect's own value. Weight 0 pins the piece where it is; gravity 0 lets it float."},
		{"key": "weight", "label": "Weight", "type": "string", "default": String.num(float(ov["weight"]), 3) if ov.has("weight") else ""},
		{"key": "gravity", "label": "Gravity", "type": "string", "default": String.num(float(ov["gravity"]), 3) if ov.has("gravity") else ""},
	]
	var answered: Signal = PmUI.form(anchor, "Piece " + str(index + 1), fields, "Set", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary and not (result as Dictionary).is_empty():
			set_values(d, s, clip_id, uid, index, String((result as Dictionary).get("weight", "")), String((result as Dictionary).get("gravity", "")))
	)


static func _to_screen(panel: Object, pic: Rect2, xf: Transform2D, uv: Vector2) -> Vector2:
	return pic.position + (xf * uv) * _k(panel, pic)


static func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	var tg: Dictionary = target(panel)
	if tg.is_empty():
		return
	var c: Clip = tg["clip"]
	var e: Dictionary = tg["entry"]
	var uid: String = String(e.get("uid", ""))
	var sc: Dictionary = _scene(tg["pass"])
	var xf: Transform2D = _xf(panel, c)
	var transforms: Array = sc["transforms"]
	var meshes: Array = sc["meshes"]
	var pieces: Variant = e.get("pieces", null)
	if pieces is Dictionary:
		for k: Variant in (pieces as Dictionary).keys():
			var i: int = int(String(k))
			if i < 0 or i >= meshes.size() or meshes[i] == null:
				continue
			var box: AABB = (meshes[i] as Mesh).get_aabb()
			var at: Vector2 = _to_screen(panel, pic, xf, project_uv(sc["cam_pos"], float(sc["fov"]), float(sc["asp"]), (transforms[i] as Transform3D) * box.get_center()))
			ci.draw_circle(at, 4.0, Color(0, 0, 0, 0.5))
			ci.draw_circle(at, 2.5, MARK)
	var sel: int = is_selected(c, uid)
	if hover_index >= 0 and hover_index != sel and hover_index < meshes.size() and meshes[hover_index] != null:
		_outline(ci, panel, pic, xf, hull_uv(transforms[hover_index], meshes[hover_index], sc["cam_pos"], float(sc["fov"]), float(sc["asp"])), HOVER, false)
	if sel >= 0 and sel < meshes.size() and meshes[sel] != null:
		var hull: PackedVector2Array = hull_uv(transforms[sel], meshes[sel], sc["cam_pos"], float(sc["fov"]), float(sc["asp"]))
		_outline(ci, panel, pic, xf, hull, GLOW, true)
		var top := Vector2(INF, INF)
		for uv: Vector2 in hull:
			var p: Vector2 = _to_screen(panel, pic, xf, uv)
			if p.y < top.y:
				top = p
		var text: String = "Piece " + str(sel + 1)
		var ov: Dictionary = override_of(e, sel)
		if not ov.is_empty():
			text += ": " + describe(ov)
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		var tw: float = PmText.width_of(font, text, fs)
		var pad: float = PmText.pad()
		var box_r := Rect2(top + Vector2(-tw * 0.5 - pad, -26.0), Vector2(tw + pad * 2.0, 20.0))
		ci.draw_rect(box_r, Color(0, 0, 0, 0.7))
		PmText.draw(ci, font, box_r, text, fs, GLOW)


static func _outline(ci: CanvasItem, panel: Object, pic: Rect2, xf: Transform2D, hull: PackedVector2Array, col: Color, strong: bool) -> void:
	if hull.size() < 3:
		return
	var pts := PackedVector2Array()
	for uv: Vector2 in hull:
		pts.append(_to_screen(panel, pic, xf, uv))
	if strong:
		ci.draw_colored_polygon(pts, Color(col, 0.22))
	var ring: PackedVector2Array = pts.duplicate()
	if ring[ring.size() - 1] != ring[0]:
		ring.append(ring[0])
	if strong:
		ci.draw_polyline(ring, Color(col, 0.28), 7.0, true)
		ci.draw_polyline(ring, Color(col, 0.5), 3.5, true)
		ci.draw_polyline(ring, col, 1.5, true)
	else:
		ci.draw_polyline(ring, col, 1.2, true)
