extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Parenting := preload("res://doc/parenting.gd")
const Puppet := preload("res://doc/puppet.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SELF_PATH := "res://modules/core_panels/onion_skin.gd"
const PREF_ON := "program.onion.on"
const PREF_COUNT := "program.onion.count"
const PREF_SPACING := "program.onion.spacing"
const PREF_STEP := "program.onion.step"
const PREF_OPACITY := "program.onion.opacity"
const PREF_TINT := "program.onion.tint"
const COMMAND_ID := "view.onion_skin"
const SPACINGS: PackedStringArray = ["frames", "keys"]
const TINTS: Dictionary = {"red_green": [Color(1.0, 0.35, 0.3), Color(0.35, 1.0, 0.45)], "blue_orange": [Color(0.35, 0.6, 1.0), Color(1.0, 0.6, 0.25)], "plain": [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0)]}
const TINT_LABELS: Dictionary = {"red_green": "Red before, green after", "blue_orange": "Blue before, orange after", "plain": "No tint"}
const COUNTS: Array[int] = [1, 2, 3, 4, 5]
const STEPS: Array[int] = [1, 2, 3, 5, 10]
const OPACITIES: Array[float] = [0.2, 0.35, 0.5, 0.7]
const KEY_PATHS: PackedStringArray = ["transform.pos", "transform.rotation", "transform.scale", "transform.anchor"]
const FADE := 0.6

static var _registered: bool = false
static var last_ms: float = 0.0
static var last_count: int = 0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func ensure_prefs() -> void:
	if _registered:
		return
	_registered = true
	for spec: Array in [[PREF_ON, false, {"label": "Program onion skin", "type": "bool"}], [PREF_COUNT, 2, {"label": "Onion skin: ghosts each side", "type": "int", "min": 1, "max": 5}], [PREF_SPACING, "frames", {"label": "Onion skin spacing (frames, keys)", "type": "enum", "choices": Array(SPACINGS)}], [PREF_STEP, 2, {"label": "Onion skin: frames between ghosts", "type": "int", "min": 1, "max": 30}], [PREF_OPACITY, 0.35, {"label": "Onion skin opacity", "type": "float", "min": 0.05, "max": 1.0}], [PREF_TINT, "red_green", {"label": "Onion skin tint (red_green, blue_orange, plain)", "type": "enum", "choices": TINTS.keys()}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	if not Cmd.has(COMMAND_ID):
		var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
		Cmd.register(COMMAND_ID, {"label": "Onion skin on the Program monitor", "category": "View", "scope": "global", "handler": Callable(_script(), "toggle"), "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static"), "toggle": Callable(_script(), "is_on")})


static func is_on() -> bool:
	ensure_prefs()
	return bool(Prefs.get_value(PREF_ON))


static func toggle() -> void:
	ensure_prefs()
	Prefs.set_value(PREF_ON, not is_on())
	_redraw()


static func _redraw() -> void:
	var bus: Object = load("res://modules/core_panels/panel_bus.gd").call("instance")
	var p: Object = bus.call("panel", "program") if bus != null else null
	var v: Variant = p.get("view") if p != null else null
	if v is Control and is_instance_valid(v):
		(v as Control).call("redraw_overlay")


static func menu_items() -> Array:
	ensure_prefs()
	var items: Array = [PmMenu.check_item("onion:on", "Show onion skin", is_on(), Cmd.keys_text(COMMAND_ID))]
	var counts: Array = []
	for n: int in COUNTS:
		counts.append(PmMenu.check_item("onion:count:" + str(n), str(n) + (" ghost" if n == 1 else " ghosts") + " each side", int(Prefs.get_value(PREF_COUNT)) == n))
	items.append(PmMenu.sub_item("onion_count", "How many", counts))
	var spacing: String = String(Prefs.get_value(PREF_SPACING))
	items.append(PmMenu.check_item("onion:spacing:frames", "Spaced by frames", spacing == "frames"))
	items.append(PmMenu.check_item("onion:spacing:keys", "At the keyframes", spacing == "keys"))
	var steps: Array = []
	for st: int in STEPS:
		steps.append(PmMenu.check_item("onion:step:" + str(st), "Every " + str(st) + (" frame" if st == 1 else " frames"), int(Prefs.get_value(PREF_STEP)) == st))
	items.append(PmMenu.sub_item("onion_step", "Frames between ghosts", steps))
	var ops: Array = []
	for o: float in OPACITIES:
		ops.append(PmMenu.check_item("onion:opacity:" + str(o), str(int(round(o * 100.0))) + " percent", absf(float(Prefs.get_value(PREF_OPACITY)) - o) < 0.001))
	items.append(PmMenu.sub_item("onion_opacity", "Opacity", ops))
	var tints: Array = []
	for k: Variant in TINTS.keys():
		tints.append(PmMenu.check_item("onion:tint:" + String(k), String(TINT_LABELS[k]), String(Prefs.get_value(PREF_TINT)) == String(k)))
	items.append(PmMenu.sub_item("onion_tint", "Tint", tints))
	return items


static func on_menu(id: String) -> bool:
	if not id.begins_with("onion:"):
		return false
	ensure_prefs()
	var parts: PackedStringArray = id.split(":")
	if parts.size() == 2 and parts[1] == "on":
		Prefs.set_value(PREF_ON, not is_on())
	elif parts.size() == 3 and parts[1] == "count":
		Prefs.set_value(PREF_COUNT, int(parts[2]))
	elif parts.size() == 3 and parts[1] == "spacing":
		Prefs.set_value(PREF_SPACING, parts[2])
	elif parts.size() == 3 and parts[1] == "step":
		Prefs.set_value(PREF_STEP, int(parts[2]))
	elif parts.size() == 3 and parts[1] == "opacity":
		Prefs.set_value(PREF_OPACITY, float(parts[2]))
	elif parts.size() == 3 and parts[1] == "tint":
		Prefs.set_value(PREF_TINT, parts[2])
	_redraw()
	return true


static func key_times(c: Clip) -> PackedFloat64Array:
	var seen: Dictionary = {}
	var paths: PackedStringArray = KEY_PATHS.duplicate()
	var e: Dictionary = Puppet.effect_of(c)
	if not e.is_empty():
		paths.append("effects." + String(e.get("uid", "")) + "." + Puppet.KEY_PINS)
	for path: String in paths:
		for k: Dictionary in AnimProp.keys(c.get_param(path)):
			var times: PackedFloat64Array = c.played_times_for(path, float(k.get("t", 0.0)))
			for lt: float in times:
				seen[snappedf(c.start + lt, 0.00001)] = true
	var out: PackedFloat64Array = PackedFloat64Array()
	for t: Variant in seen.keys():
		out.append(float(t))
	out.sort()
	return out


static func ghost_times(c: Clip, now: float, fps: float, count: int, spacing: String, step: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo: float = c.start
	var hi: float = c.end()
	if spacing == "keys":
		var keys: PackedFloat64Array = key_times(c)
		var before: Array[float] = []
		var after: Array[float] = []
		for t: float in keys:
			if t < now - 0.0005 and t >= lo:
				before.append(t)
			elif t > now + 0.0005 and t < hi:
				after.append(t)
		before.reverse()
		for i: int in mini(count, before.size()):
			out.append({"t": before[i], "side": -1, "rank": i + 1})
		for j: int in mini(count, after.size()):
			out.append({"t": after[j], "side": 1, "rank": j + 1})
		return out
	var dt: float = float(maxi(step, 1)) / (fps if fps > 0.0 else 30.0)
	for k: int in range(1, count + 1):
		var tb: float = now - dt * float(k)
		if tb >= lo:
			out.append({"t": tb, "side": -1, "rank": k})
		var ta: float = now + dt * float(k)
		if ta < hi:
			out.append({"t": ta, "side": 1, "rank": k})
	return out


static func layer_size(d: Project, s: Sequence, c: Clip) -> Vector2:
	var pick: GDScript = load("res://modules/core_panels/monitor_pick.gd")
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return PairLayout.picture_size(c, pick.call("layer_size", c, m, s, d), Vector2(float(s.width), float(s.height)))


static func plan(panel: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_on():
		return out
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var c: Clip = panel.call("gizmo_clip")
	if s == null or c == null:
		return out
	var count: int = clampi(int(Prefs.get_value(PREF_COUNT)), 1, 5)
	var opacity: float = clampf(float(Prefs.get_value(PREF_OPACITY)), 0.0, 1.0)
	var tint: Array = TINTS.get(String(Prefs.get_value(PREF_TINT)), TINTS["red_green"])
	var base: Vector2 = layer_size(d, s, c)
	var pick: GDScript = load("res://modules/core_panels/monitor_pick.gd")
	var e: Dictionary = Puppet.effect_of(c)
	for g: Dictionary in ghost_times(c, s.playhead, s.fps, count, String(Prefs.get_value(PREF_SPACING)), int(Prefs.get_value(PREF_STEP))):
		var t: float = float(g["t"])
		var col: Color = tint[0] if int(g["side"]) < 0 else tint[1]
		col.a = opacity * (1.0 - FADE * float(int(g["rank"]) - 1) / float(maxi(count, 1)))
		var row: Dictionary = {"t": t, "side": int(g["side"]), "colour": col, "quad": pick.call("quad_from_tf", Parenting.world_tf(c, s, t, s.fps), base, s)}
		if not e.is_empty():
			var made: Dictionary = Puppet.deformed_at(c, e, t, s.fps, Puppet.size_of(e, base))
			var w: Transform2D = Parenting.world_frame(c, s, t, s.fps)
			var anchor: Vector2 = Parenting.local_tf(c, t, s.fps)["anchor"]
			var pts: PackedVector2Array = PackedVector2Array()
			for q: Vector2 in (made["verts"] as PackedVector2Array):
				pts.append(Vector2(float(s.width), float(s.height)) * 0.5 + w * (q - anchor))
			row["mesh_pts"] = pts
			row["mesh"] = made["mesh"]
		out.append(row)
	return out


static func textures(c: Clip) -> Dictionary:
	var comp: Node = Session.compositor
	var layers: Variant = comp.get("layers") if comp != null else null
	if not (layers is Dictionary) or not (layers as Dictionary).has(c.id):
		return {}
	var l: Node = (layers as Dictionary)[c.id]
	if l == null or not is_instance_valid(l):
		return {}
	var out: Dictionary = {}
	var outer: Variant = l.get("outer_tex")
	if outer is Texture2D:
		out["layer"] = outer
	for mi: Node in l.find_children("PuppetMesh", "MeshInstance2D", true, false):
		var tex: Texture2D = (mi as MeshInstance2D).texture
		if tex != null:
			out["unbent"] = tex
			break
	return out


static func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if pic.size.x <= 0.0 or not is_on():
		return
	var t0: int = Time.get_ticks_usec()
	var rows: Array[Dictionary] = plan(panel)
	last_count = rows.size()
	if rows.is_empty():
		last_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		return
	var c: Clip = panel.call("gizmo_clip")
	var tex: Dictionary = textures(c)
	var s: Sequence = panel.call("seq")
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	for row: Dictionary in rows:
		var col: Color = row["colour"]
		if row.has("mesh_pts") and tex.has("unbent"):
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in (row["mesh_pts"] as PackedVector2Array):
				pts.append(pic.position + p * k)
			var mesh: Dictionary = row["mesh"]
			var cols: PackedColorArray = PackedColorArray()
			cols.resize(pts.size())
			cols.fill(col)
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), mesh["tris"], pts, cols, mesh["uv"], PackedInt32Array(), PackedFloat32Array(), (tex["unbent"] as Texture2D).get_rid())
			continue
		var q: PackedVector2Array = row["quad"]
		if q.size() != 4:
			continue
		var a: Vector2 = pic.position + q[0] * k
		var xf: Transform2D = Transform2D((q[1] - q[0]) * k, (q[3] - q[0]) * k, a)
		if tex.has("layer"):
			ci.draw_set_transform_matrix(xf)
			ci.draw_texture_rect(tex["layer"], Rect2(0.0, 0.0, 1.0, 1.0), false, col)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		var closed: PackedVector2Array = PackedVector2Array()
		for p2: Vector2 in q:
			closed.append(pic.position + p2 * k)
		closed.append(closed[0])
		ci.draw_polyline(closed, Color(col.r, col.g, col.b, minf(col.a * 1.6, 1.0)), 1.0, true)
	last_ms = float(Time.get_ticks_usec() - t0) / 1000.0
