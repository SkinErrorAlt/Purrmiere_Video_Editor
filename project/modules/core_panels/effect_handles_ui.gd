extends RefCounted

const Clip := preload("res://doc/clip.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PanelBus := preload("res://modules/core_panels/panel_bus.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SELF_PATH := "res://modules/core_panels/effect_handles_ui.gd"
const HANDLES_PATH := "res://modules/core_panels/monitor_handles.gd"
const PREF_ON := "program.effect_controls.on"
const COMMAND_ID := "view.effect_controls_on_program"
const MENU_ON := "fxh:on"
const MENU_BACK := "fxh:back"
const MENU_LABEL := "Show effect controls on the Program"
const BACK_LABEL := "Back to the clip's own handles"
const KIND_RING := "ring"
const KIND_BAND := "band"
const BAND_STEPS := 32
const BAND_KNOB_W := 0.38
const BAND_KNOB_F := 0.62
const RING_STEPS := 72
const DASH_EVERY := 2
const KNOB := 6.5
const SHADE := Color(0.0, 0.0, 0.0, 0.55)
const FILL := Color(1.0, 1.0, 1.0, 1.0)
const PICK_REACH := 22.0
const ARM_MIN := 0.0001
const INSIDE_PAD := 0.03
const FEATHER_SHIFT := 22.0
const KNOB_TRIES: PackedFloat64Array = [-90.0, -45.0, -135.0, 0.0, 180.0, 45.0, 135.0, 90.0]
const SIDE_TRIES: PackedFloat64Array = [0.0, 180.0]
const CORNER_TRIES: PackedFloat64Array = [-45.0, -135.0, 45.0, 135.0]
const ROUND_TRIES: PackedFloat64Array = [-90.0, -45.0, -135.0, 45.0, 135.0, 90.0]
const POINT_WORDS: PackedStringArray = ["centre", "center", "position", "pos", "point", "focus", "light", "origin", "target", "anchor", "pivot", "start", "end", "source", "sun", "moon", "spot", "at", "from", "to", "tip", "base"]
const NOT_POINT_WORDS: PackedStringArray = ["offset", "drift", "travel", "shift", "scale", "size", "speed", "dir", "direction", "velocity", "red", "green", "blue", "amount", "stretch", "tiles", "repeat", "count", "range"]
const ANGLE_WORDS: PackedStringArray = ["angle", "direction", "rotation", "heading"]
const RADIUS_KEYS: PackedStringArray = ["radius", "size"]
const RADIUS_WORDS: PackedStringArray = ["radius"]
const CENTRE_WORDS: PackedStringArray = ["centre", "center", "position", "pos", "origin", "focus"]
const COLOUR_WORDS: PackedStringArray = ["colour", "color", "colours", "colors", "tint", "hue", "saturation", "red", "green", "blue", "cyan", "magenta", "yellow", "luma", "chroma", "gamma", "lift", "gain", "midtones", "highlights", "temperature", "grey", "gray", "black", "white", "rgb"]
const COLOUR_TYPES: PackedStringArray = ["color", "colour", "gradient"]
const SKIP_CATEGORIES: PackedStringArray = ["colour correction", "color correction", "colour", "color", "channel", "keying", "audio"]
const LINE_PAIRS: Array = [["start", "end"], ["from", "to"], ["begin", "finish"], ["a", "b"], ["head", "tail"], ["source", "target"], ["1", "2"]]

static var _registered: bool = false
static var _seen_clip: int = 0
static var _seen_uids: PackedStringArray = PackedStringArray()


static func _script() -> GDScript:
	return load(SELF_PATH)


static func _handles() -> GDScript:
	return load(HANDLES_PATH)


static func ensure_prefs() -> void:
	if _registered:
		return
	_registered = true
	if not Prefs.is_registered(PREF_ON):
		Prefs.register(PREF_ON, true, {"label": "Program: show the picked effect's controls on the picture", "type": "bool"})
	if not Cmd.has(COMMAND_ID):
		var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
		Cmd.register(COMMAND_ID, {"label": MENU_LABEL, "category": "View", "scope": "global", "handler": Callable(_script(), "toggle"), "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static"), "toggle": Callable(_script(), "is_on")})


static func is_on() -> bool:
	ensure_prefs()
	return bool(Prefs.get_value(PREF_ON))


static func set_on(on: bool) -> void:
	ensure_prefs()
	Prefs.set_value(PREF_ON, on)
	if not on:
		_handles().call("clear_focus")
		return
	_handles().call("_redraw_program")


static func toggle() -> void:
	set_on(not is_on())


static func menu_item() -> Dictionary:
	return PmMenu.check_item(MENU_ON, MENU_LABEL, is_on(), Cmd.keys_text(COMMAND_ID))


static func on_menu(id: String, clip_id: String = "") -> bool:
	if id == MENU_ON:
		toggle()
		return true
	if id == MENU_BACK:
		back_to_clip(clip_id)
		return true
	return false


static func open_menu(anchor: Control, at: Vector2, clip_id: String) -> Control:
	if anchor == null:
		return null
	var items: Array = [menu_item(), PmMenu.item(MENU_BACK, BACK_LABEL, "Esc")]
	var m: Control = PmMenu.open(anchor, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: on_menu(id, clip_id))
	return m


static func back_to_clip(clip_id: String) -> bool:
	var hs: GDScript = _handles()
	var uid: String = String(hs.call("focus_of", clip_id))
	if clip_id.is_empty() or uid.is_empty():
		return false
	hs.call("set_focus", clip_id, uid, false)
	return true


static func back_from(c: Clip) -> bool:
	return c != null and back_to_clip(c.id)


static func motion_header_input(event: InputEvent, c: Clip) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.double_click and back_from(c)


static func watch_added(c: Clip) -> bool:
	if c == null:
		_seen_clip = 0
		_seen_uids = PackedStringArray()
		return false
	var uids: PackedStringArray = PackedStringArray()
	for e: Dictionary in c.effects:
		uids.append(String(e.get("uid", "")))
	var fresh: String = ""
	if c.get_instance_id() == _seen_clip:
		for i: int in range(uids.size() - 1, -1, -1):
			if not _seen_uids.has(uids[i]):
				fresh = uids[i]
				break
	_seen_clip = c.get_instance_id()
	_seen_uids = uids
	return not fresh.is_empty() and pick(c, fresh)


static func pick(c: Clip, uid: String) -> bool:
	if c == null or uid.is_empty() or not is_on():
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty():
		return false
	var hs: GDScript = _handles()
	if not bool(hs.call("has_handles", String(e.get("id", "")))):
		return false
	if String(hs.call("focus_of", c.id)) == uid:
		return false
	hs.call("set_focus", c.id, uid, true)
	return true


static func pick_path(c: Clip, path: String) -> bool:
	if c == null:
		return false
	var parts: PackedStringArray = path.get_slice("#", 0).split(".")
	if parts.size() >= 3 and parts[0] == "effects":
		return pick(c, parts[1])
	if parts.size() >= 2 and parts[0] == "transform":
		return back_to_clip(c.id)
	return false


static func _fold_of(header: Control) -> Object:
	var n: Node = header.get_parent() if header != null else null
	var steps: int = 0
	while n != null and steps < 8:
		if n.get("header") == header and n.get("open") != null:
			return n
		n = n.get_parent()
		steps += 1
	return null


static func header_pressed(c: Clip, uid: String, header: Control) -> bool:
	if not pick(c, uid):
		return false
	var f: Object = _fold_of(header)
	return f != null and bool(f.get("open"))


static func _target_clip() -> Clip:
	var b: RefCounted = PanelBus.instance()
	if b == null:
		return null
	var ec: Object = b.call("panel", "effect_controls")
	if ec != null and ec.has_method("target_clip"):
		var c: Variant = ec.call("target_clip")
		if c is Clip:
			return c
	var pp: Object = b.call("panel", "program")
	if pp != null and pp.has_method("gizmo_clip"):
		var g: Variant = pp.call("gizmo_clip")
		if g is Clip:
			return g
	return null


static func pick_from_browser(eid: String, on_clip: Clip = null, ec_panel: Object = null) -> bool:
	if eid.is_empty() or eid.contains(":"):
		return false
	var c: Clip = on_clip if on_clip != null else _target_clip()
	if c == null:
		return false
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == eid:
			var uid: String = String(e.get("uid", ""))
			var picked: bool = pick(c, uid)
			if picked:
				reveal(e, ec_panel)
			return picked
	return false


static func reveal(e: Dictionary, ec_panel: Object = null) -> void:
	var ec: Object = ec_panel
	if ec == null:
		var b: RefCounted = PanelBus.instance()
		ec = b.call("panel", "effect_controls") if b != null else null
	if ec == null or not ec.has_method("scroll_to_value") or not ec.has_method("_row_by_pick"):
		return
	var keys: Array = (e.get("params", {}) as Dictionary).keys()
	for p0: Variant in EffectSource.get_def(String(e.get("id", ""))).get("params", []):
		if p0 is Dictionary and not keys.has(String((p0 as Dictionary).get("key", ""))):
			keys.append(String((p0 as Dictionary).get("key", "")))
	for k: Variant in keys:
		var path: String = "effects." + String(e.get("uid", "")) + "." + String(k)
		for p: String in [path, path + "#0"]:
			if not (ec.call("_row_by_pick", p) as Dictionary).is_empty():
				ec.call("scroll_to_value", p)
				return


static func highlight(panel: Object, uid: String, key: String) -> void:
	if key.is_empty():
		return
	var ec: Object = null
	var b: Variant = panel.call("bus") if panel != null and panel.has_method("bus") else null
	if b is Object and (b as Object).has_method("panel"):
		ec = (b as Object).call("panel", "effect_controls")
	if ec == null or not ec.has_method("pick_value"):
		return
	var path: String = ("transition." if uid == "__transition" else "effects." + uid + ".") + key
	if ec.has_method("_row_by_pick") and (ec.call("_row_by_pick", path) as Dictionary).is_empty() and not (ec.call("_row_by_pick", path + "#0") as Dictionary).is_empty():
		path += "#0"
	ec.call("pick_value", path)


static func _words(key: String) -> PackedStringArray:
	return key.to_lower().split("_", false)


static func _any(words: PackedStringArray, pool: PackedStringArray) -> bool:
	for w: String in words:
		if pool.has(w):
			return true
	return false


static func refuses(def: Dictionary) -> bool:
	if bool(def.get("audio", false)):
		return true
	return SKIP_CATEGORIES.has(String(def.get("category", "")).strip_edges().to_lower())


static func colourish(p: Dictionary) -> bool:
	if COLOUR_TYPES.has(String(p.get("type", "")).strip_edges().to_lower()):
		return true
	return _any(_words(String(p.get("key", ""))), COLOUR_WORDS)


static func _partner(key: String, from: String, to: String) -> String:
	if from.is_valid_int():
		if key.length() < 2 or not key.ends_with(from) or key.substr(key.length() - 2, 1).is_valid_int():
			return ""
		return key.substr(0, key.length() - 1) + to
	var words: PackedStringArray = key.split("_", false)
	for i: int in words.size():
		if words[i].to_lower() == from:
			words[i] = to
			return "_".join(words)
	return ""


static func line_pairs(keys: PackedStringArray) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	for k: String in keys:
		if used.has(k):
			continue
		for pair: Variant in LINE_PAIRS:
			var from: String = String((pair as Array)[0])
			var other: String = _partner(k, from, String((pair as Array)[1]))
			if other.is_empty() or other == k or not keys.has(other) or used.has(other):
				continue
			if from.is_valid_int() and keys.has(_partner(k, from, "3")):
				continue
			out.append([k, other])
			used[k] = true
			used[other] = true
			break
	return out


static func _is_place(p: Dictionary) -> bool:
	if String(p.get("type", "")) != "vec2" or colourish(p):
		return false
	var words: PackedStringArray = _words(String(p.get("key", "")))
	if not _any(words, POINT_WORDS) or _any(words, NOT_POINT_WORDS):
		return false
	if p.has("min") and float(p["min"]) < -1.0:
		return false
	if p.has("max") and float(p["max"]) > 2.0:
		return false
	var dv: Variant = p.get("default", [0.5, 0.5])
	if dv is Array and (dv as Array).size() >= 2:
		for i: int in 2:
			var f: float = float((dv as Array)[i])
			if f < -0.5 or f > 1.5:
				return false
	return true


static func _is_angle(p: Dictionary) -> bool:
	if String(p.get("type", "")) != "float" or colourish(p):
		return false
	var unit: String = String(p.get("unit", "")).strip_edges().to_lower()
	if unit != "deg" and unit != "°":
		return false
	if not _any(_words(String(p.get("key", ""))), ANGLE_WORDS):
		return false
	return float(p.get("max", 360.0)) - float(p.get("min", 0.0)) >= 90.0


static func radius_unit(p: Dictionary, exact: bool) -> String:
	if String(p.get("type", "")) != "float" or colourish(p):
		return ""
	var key: String = String(p.get("key", ""))
	if not RADIUS_KEYS.has(key) and (exact or not _any(_words(key), RADIUS_WORDS)):
		return ""
	if float(p.get("min", 0.0)) < 0.0:
		return ""
	var unit: String = String(p.get("unit", "")).strip_edges().to_lower()
	if unit.is_empty():
		return "h" if float(p.get("max", 1.0)) <= 2.0 else ""
	return "px" if unit == "px" else ""


static func guess(def: Dictionary) -> Array:
	var out: Array = []
	if refuses(def):
		return out
	var places: PackedStringArray = PackedStringArray()
	var params: Array = def.get("params", []) if def.get("params") is Array else []
	for p: Variant in params:
		if p is Dictionary and _is_place(p):
			places.append(String((p as Dictionary)["key"]))
	var paired: Dictionary = {}
	for pr: Variant in line_pairs(places):
		out.append({"kind": "line", "keys": [String((pr as Array)[0]), String((pr as Array)[1])], "auto": true})
		paired[String((pr as Array)[0])] = true
		paired[String((pr as Array)[1])] = true
	var pts: PackedStringArray = PackedStringArray()
	for k0: String in places:
		if not paired.has(k0):
			pts.append(k0)
	for k: String in pts:
		out.append({"kind": "point", "key": k, "auto": true})
	var about: String = ""
	for k2: String in pts:
		if _any(_words(k2), CENTRE_WORDS):
			about = k2
			break
	if about.is_empty() and pts.size() == 1:
		about = pts[0]
	for p2: Variant in params:
		if p2 is Dictionary and _is_angle(p2):
			var a: Dictionary = {"kind": "angle", "key": String((p2 as Dictionary)["key"]), "auto": true}
			if not about.is_empty():
				a["about"] = about
			out.append(a)
			break
	if about.is_empty():
		return out
	for exact: bool in [true, false]:
		for p3: Variant in params:
			if not (p3 is Dictionary):
				continue
			var unit: String = radius_unit(p3, exact)
			if not unit.is_empty():
				out.append({"kind": KIND_RING, "key": String((p3 as Dictionary)["key"]), "about": about, "unit": unit, "auto": true})
				return out
	return out


static func param_spec(def: Dictionary, key: String) -> Dictionary:
	for p: Variant in def.get("params", []):
		if p is Dictionary and String((p as Dictionary).get("key", "")) == key:
			return p
	return {}


static func label_of(def: Dictionary, key: String) -> String:
	return String(param_spec(def, key).get("label", key.capitalize()))


static func clamp_value(def: Dictionary, key: String, v: float) -> float:
	var p: Dictionary = param_spec(def, key)
	var lo: float = float(p.get("min", -INF))
	var hi: float = float(p.get("max", INF))
	if hi < lo:
		return v
	return clampf(v, lo, hi)


static func value_text(def: Dictionary, key: String, v: float) -> String:
	var p: Dictionary = param_spec(def, key)
	var step: float = float(p.get("step", 0.01))
	var unit: String = String(p.get("unit", ""))
	if unit.strip_edges() == "deg":
		unit = " deg"
	var shown: float = snappedf(v, step) if step > 0.0 else v
	return label_of(def, key) + " " + str(shown) + unit


static func point_text(def: Dictionary, key: String, v: Vector2) -> String:
	return label_of(def, key) + " " + str(snappedf(v.x * 100.0, 0.1)) + " %, " + str(snappedf(v.y * 100.0, 0.1)) + " %"


static func unit_axes(unit: String, aspect: float, px: Vector2, roundness: float, has_round: bool) -> Vector2:
	var asp: float = maxf(aspect, 0.0001)
	if unit == "w":
		return Vector2(1.0, 1.0 / asp)
	if unit == "uv":
		return Vector2(lerpf(1.0, asp, clampf(roundness, 0.0, 1.0)) if has_round else 1.0, 1.0)
	if unit == "px":
		return Vector2(maxf(px.x, 1.0), maxf(px.y, 1.0))
	if unit == "d":
		var dg: float = sqrt(asp * asp + 1.0)
		return Vector2(asp / dg, 1.0 / dg)
	return Vector2(asp, 1.0)


static func feather_of(mode: String, r: float, f: float) -> float:
	if mode == "minus":
		return r - f
	if mode == "inner":
		return r * (1.0 - f)
	if mode == "outer":
		return r * (1.0 + f)
	return r + f


static func feather_from(mode: String, r: float, d: float) -> float:
	if mode == "minus":
		return r - d
	if mode == "inner":
		return 1.0 - d / r if absf(r) > ARM_MIN else 0.0
	if mode == "outer":
		return d / r - 1.0 if absf(r) > ARM_MIN else 0.0
	return d - r


static func ring_at(g: Dictionary, deg: float) -> Vector2:
	var a: float = deg_to_rad(deg)
	var dir: Vector2 = Vector2(cos(a), sin(a))
	if bool(g["box"]):
		dir = dir / maxf(maxf(absf(dir.x), absf(dir.y)), ARM_MIN)
	var m: Vector2 = (Vector2(dir.x * float(g["rx"]), dir.y * float(g["ry"])) + Vector2(g.get("o", Vector2.ZERO))).rotated(float(g["rot"]))
	var ax: Vector2 = g["ax"]
	var c: Vector2 = g["c"]
	return c + Vector2(m.x / ax.x, m.y / ax.y) / float(g["scale"])


static func ring_local(g: Dictionary, uv: Vector2) -> Vector2:
	var ax: Vector2 = g["ax"]
	var off: Vector2 = uv - Vector2(g["c"])
	return (Vector2(off.x * ax.x, off.y * ax.y) * float(g["scale"])).rotated(-float(g["rot"]))


static func _inside(p: Vector2) -> bool:
	return p.x >= INSIDE_PAD and p.y >= INSIDE_PAD and p.x <= 1.0 - INSIDE_PAD and p.y <= 1.0 - INSIDE_PAD


static func _choose(g: Dictionary, tries: PackedFloat64Array) -> float:
	for deg: float in tries:
		if _inside(ring_at(g, deg)):
			return deg
	var best: float = tries[0]
	var best_d: float = INF
	for deg2: float in tries:
		var dd: float = ring_at(g, deg2).distance_to(Vector2(0.5, 0.5))
		if dd < best_d:
			best_d = dd
			best = deg2
	return best


static func _ring_line(xf: Transform2D, g: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if bool(g["box"]):
		for deg: float in [-135.0, -45.0, 45.0, 135.0, -135.0]:
			out.append(xf * ring_at(g, deg))
		return out
	for i: int in RING_STEPS + 1:
		out.append(xf * ring_at(g, 360.0 * float(i) / float(RING_STEPS)))
	return out


static func _geo(c: Vector2, rx: float, ry: float, rot: float, scale: float, ax: Vector2, box: bool, o: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"c": c, "rx": maxf(rx, 0.0), "ry": maxf(ry, 0.0), "rot": rot, "scale": scale, "ax": ax, "box": box, "o": o}


static func shape_entry(sd: Dictionary, pick: int) -> Dictionary:
	var out: Dictionary = {"box": String(sd.get("shape", "circle")) == "box", "fit": sd.get("fit", null), "frame": bool(sd.get("frame", false)), "stretch": true}
	var shapes: Variant = sd.get("shapes", null)
	if shapes is Array and pick >= 0 and pick < (shapes as Array).size() and (shapes as Array)[pick] is Dictionary:
		var en: Dictionary = (shapes as Array)[pick]
		if en.has("shape"):
			out["box"] = String(en["shape"]) == "box"
		if en.has("fit"):
			out["fit"] = en["fit"]
		if en.has("frame"):
			out["frame"] = bool(en["frame"])
		if en.has("stretch"):
			out["stretch"] = bool(en["stretch"])
	var fit: PackedFloat64Array = PackedFloat64Array([-1.0, -1.0, 1.0, 1.0])
	var raw: Variant = out["fit"]
	if raw is Array and (raw as Array).size() == 4:
		fit = PackedFloat64Array([float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3])])
	out["fit"] = fit
	return out


static func corner_unit(deg: float, box: bool) -> Vector2:
	var a: float = deg_to_rad(deg)
	var dir: Vector2 = Vector2(cos(a), sin(a))
	if box:
		dir = dir / maxf(maxf(absf(dir.x), absf(dir.y)), ARM_MIN)
	return dir


static func _axis_scale(v: float, lo: float, hi: float) -> float:
	if v >= 0.0:
		return v / hi if hi > ARM_MIN else 0.0
	return v / lo if lo < -ARM_MIN else 0.0


static func ring_target(t: Dictionary, def: Dictionary, vals: Dictionary, aspect: float, px: Vector2) -> bool:
	var sd: Dictionary = t["spec"]
	var key: String = String(sd.get("key", ""))
	if key.is_empty():
		return false
	var key_y: String = String(sd.get("key_y", ""))
	var fkey: String = String(sd.get("feather", ""))
	var qkey: String = String(sd.get("round", ""))
	var skey: String = String(sd.get("stretch", ""))
	var unit: String = String(sd.get("unit", "h"))
	var look: Dictionary = shape_entry(sd, int(vals.get("pick", -1)))
	var box: bool = bool(look["box"])
	var fit: PackedFloat64Array = look["fit"]
	var fa: float = maxf(aspect, ARM_MIN) if bool(look["frame"]) else 1.0
	var has_st: bool = not skey.is_empty() and bool(look["stretch"])
	var scale: float = maxf(absf(float(sd.get("scale", 1.0))), ARM_MIN)
	var fscale: float = float(sd.get("feather_scale", 1.0))
	var mode: String = String(sd.get("feather_mode", "add"))
	var raw: Variant = vals.get("r", 0.0)
	var pair: bool = raw is Vector2
	var r: float = (raw as Vector2).x if pair else float(raw)
	var ry: float = (raw as Vector2).y if pair else (float(vals.get("ry", r)) if not key_y.is_empty() else r)
	var st: float = float(vals.get("st", 1.0)) if bool(look["stretch"]) else 1.0
	var rot: float = deg_to_rad(float(vals.get("rot", 0.0))) * (-1.0 if String(sd.get("rotate_turn", "cw")) == "ccw" else 1.0)
	var q: float = float(vals.get("q", 1.0))
	var c: Vector2 = vals.get("c", Vector2(0.5, 0.5))
	var ax: Vector2 = unit_axes(unit, aspect, px, q, not qkey.is_empty())
	var hx: float = (fit[2] - fit[0]) * 0.5
	var hy: float = (fit[3] - fit[1]) * 0.5
	var cx: float = (fit[0] + fit[2]) * 0.5
	var cy: float = (fit[1] + fit[3]) * 0.5
	var kx: float = st * fa * hx
	var g: Dictionary = _geo(c, r * kx, ry * hy, rot, scale, ax, box, Vector2(r * st * fa * cx, ry * cy))
	var xf: Transform2D = t["xf"]
	var lines: Array[Dictionary] = [{"pts": _ring_line(xf, g), "dashed": false}]
	var hs: Array[Dictionary] = []
	var two: bool = pair or not key_y.is_empty()
	if not two:
		var tries: PackedFloat64Array = KNOB_TRIES
		if not qkey.is_empty():
			tries = ROUND_TRIES
		elif String(sd.get("knob", "")) == "corner":
			tries = CORNER_TRIES
		var deg: float = _choose(g, tries)
		t["knob_deg"] = deg
		hs.append({"id": "r", "at": xf * ring_at(g, deg), "look": "knob", "name": label_of(def, key), "tip": value_text(def, key, r)})
	else:
		var dx: float = _choose(g, SIDE_TRIES)
		var dy: float = _choose(g, PackedFloat64Array([-90.0, 90.0]))
		t["knob_deg"] = dy
		hs.append({"id": "rx", "at": xf * ring_at(g, dx), "look": "knob", "name": label_of(def, key) + (" across" if pair else ""), "tip": value_text(def, key, r)})
		hs.append({"id": "ry", "at": xf * ring_at(g, dy), "look": "knob", "name": label_of(def, key) + " down" if pair else label_of(def, key_y), "tip": value_text(def, key if pair else key_y, ry)})
	var corner_deg: float = 0.0
	if bool(sd.get("corner", false)) and (two or has_st):
		corner_deg = _choose(g, CORNER_TRIES)
		var other: String = key_y if not key_y.is_empty() else skey
		var cname: String = label_of(def, key) + (" across and down" if pair else " and " + label_of(def, other))
		var ctip: String = ""
		if pair:
			ctip = label_of(def, key) + " " + str(snappedf(r, 0.001)) + ", " + str(snappedf(ry, 0.001))
		else:
			ctip = value_text(def, key, r) + ", " + value_text(def, other, ry if not key_y.is_empty() else st)
		hs.append({"id": "rc", "at": xf * ring_at(g, corner_deg), "look": "square", "name": cname, "tip": ctip})
	if not qkey.is_empty():
		var side: float = _choose(g, SIDE_TRIES)
		hs.append({"id": "q", "at": xf * ring_at(g, side), "look": "knob_bar", "dir": xf.basis_xform(ring_at(g, 90.0) - ring_at(g, -90.0)), "name": label_of(def, qkey), "tip": value_text(def, qkey, q)})
	var fg: Dictionary = {}
	if not fkey.is_empty():
		var f: float = float(vals.get("f", 0.0)) * fscale
		fg = _geo(c, feather_of(mode, r, f) * kx, feather_of(mode, ry, f) * hy, rot, scale, ax, box, Vector2(g["o"]))
		lines.append({"pts": _ring_line(xf, fg), "dashed": true})
		hs.append({"id": "f", "at": xf * ring_at(fg, float(t["knob_deg"]) + FEATHER_SHIFT), "look": "knob_hollow", "name": label_of(def, fkey), "tip": value_text(def, fkey, float(vals.get("f", 0.0)))})
	t["lines"] = lines
	t["handles"] = hs
	t["centre_uv"] = c
	t["geo"] = g
	t["ring"] = {"r": r, "ry": ry, "st": st, "pair": pair, "q": q, "f": float(vals.get("f", 0.0)), "fscale": fscale, "mode": mode, "aspect": aspect, "key": key, "key_y": key_y, "feather": fkey, "round": qkey, "stretch": skey if has_st else "", "kx": kx, "hy": hy, "fa": fa, "fit": fit, "corner_deg": corner_deg}
	t["movable"] = false
	return true


static func ring_keys(sd: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in ["key", "key_y", "feather", "round", "stretch"]:
		var k: String = String(sd.get(f, ""))
		if not k.is_empty():
			out.append(k)
	return out


static func ring_drag(t: Dictionary, def: Dictionary, handle: String, uv: Vector2) -> Dictionary:
	var g: Dictionary = t["geo"]
	var info: Dictionary = t["ring"]
	var m: Vector2 = ring_local(g, uv)
	var st: float = maxf(absf(float(info["st"])), ARM_MIN)
	var kx: float = maxf(absf(float(info.get("kx", st))), ARM_MIN)
	var hy: float = maxf(absf(float(info.get("hy", 1.0))), ARM_MIN)
	var fa: float = float(info.get("fa", 1.0))
	var fit: PackedFloat64Array = info.get("fit", PackedFloat64Array([-1.0, -1.0, 1.0, 1.0]))
	var box: bool = bool(g["box"])
	var pair: bool = bool(info["pair"])
	var out: Dictionary = {}
	var chip: String = ""
	var k: String = String(info["key"])
	if handle == "r":
		var rr: float = Vector2(m.x / kx, m.y / hy).length()
		if box:
			var sx: float = st * fa
			rr = maxf(_axis_scale(m.x, sx * fit[0], sx * fit[2]), _axis_scale(m.y, fit[1], fit[3]))
		var r: float = clamp_value(def, k, rr)
		out[k] = r
		chip = value_text(def, k, r)
	elif handle == "rx" or handle == "ry":
		if pair:
			var v: Vector2 = Vector2(absf(m.x) / kx if handle == "rx" else float(info["r"]), absf(m.y) / hy if handle == "ry" else float(info["ry"]))
			v = Vector2(clamp_value(def, k, v.x), clamp_value(def, k, v.y))
			out[k] = [v.x, v.y]
			chip = label_of(def, k) + " " + str(snappedf(v.x, 0.001)) + ", " + str(snappedf(v.y, 0.001))
		else:
			var kk: String = k if handle == "rx" else String(info["key_y"])
			var rv: float = clamp_value(def, kk, absf(m.x) / kx if handle == "rx" else absf(m.y) / hy)
			out[kk] = rv
			chip = value_text(def, kk, rv)
	elif handle == "rc":
		var u: Vector2 = corner_unit(float(info.get("corner_deg", -45.0)), box)
		var bx: float = fa * ((fit[0] + fit[2]) * 0.5 + u.x * (fit[2] - fit[0]) * 0.5)
		var by: float = (fit[1] + fit[3]) * 0.5 + u.y * (fit[3] - fit[1]) * 0.5
		var big_x: float = maxf(m.x / bx, 0.0) if absf(bx) > ARM_MIN else 0.0
		var big_y: float = maxf(m.y / by, 0.0) if absf(by) > ARM_MIN else 0.0
		var ky: String = String(info["key_y"])
		var sk: String = String(info.get("stretch", ""))
		if pair:
			var pv: Vector2 = Vector2(clamp_value(def, k, big_x / st), clamp_value(def, k, big_y))
			out[k] = [pv.x, pv.y]
			chip = label_of(def, k) + " " + str(snappedf(pv.x, 0.001)) + ", " + str(snappedf(pv.y, 0.001))
		elif not ky.is_empty():
			var vx: float = clamp_value(def, k, big_x / st)
			var vy: float = clamp_value(def, ky, big_y)
			out[k] = vx
			out[ky] = vy
			chip = value_text(def, k, vx) + ", " + value_text(def, ky, vy)
		elif not sk.is_empty():
			var r2: float = clamp_value(def, k, big_y)
			var s2: float = clamp_value(def, sk, big_x / maxf(r2, ARM_MIN))
			out[k] = r2
			out[sk] = s2
			chip = value_text(def, k, r2) + ", " + value_text(def, sk, s2)
	elif handle == "q":
		var kq: String = String(info["round"])
		var asp: float = float(info["aspect"])
		var ex: float = absf(uv.x - Vector2(g["c"]).x)
		var want: float = float(info["r"]) / maxf(float(g["scale"]) * ex, ARM_MIN)
		var q: float = (want - 1.0) / (asp - 1.0) if absf(asp - 1.0) > 0.001 else float(info["q"])
		q = clamp_value(def, kq, clampf(q, 0.0, 1.0))
		out[kq] = q
		chip = value_text(def, kq, q)
	elif handle == "f":
		var kf: String = String(info["feather"])
		var r0: float = float(info["r"])
		var d: float = maxf(absf(m.x) / kx, absf(m.y) / hy) if box else Vector2(m.x / kx, m.y / hy).length()
		var rx_m: float = float(g["rx"])
		var ry_m: float = float(g["ry"])
		if rx_m > ARM_MIN and ry_m > ARM_MIN and absf(rx_m / kx - ry_m / hy) > ARM_MIN:
			var n: Vector2 = Vector2(m.x / rx_m, m.y / ry_m)
			d = r0 * (maxf(absf(n.x), absf(n.y)) if box else n.length())
		var fs: float = float(info["fscale"])
		var f: float = feather_from(String(info["mode"]), r0, d) / (fs if absf(fs) > ARM_MIN else 1.0)
		f = clamp_value(def, kf, f)
		out[kf] = f
		chip = value_text(def, kf, f)
	return {"values": out, "chip": chip}


static func band_at(vertical: bool, pos: float, s: float) -> Vector2:
	return Vector2(pos, s) if vertical else Vector2(s, pos)


static func _band_line(xf: Transform2D, vertical: bool, pos: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in BAND_STEPS + 1:
		out.append(xf * band_at(vertical, pos, float(i) / float(BAND_STEPS)))
	return out


static func band_target(t: Dictionary, def: Dictionary, vals: Dictionary) -> bool:
	var sd: Dictionary = t["spec"]
	var key: String = String(sd.get("key", ""))
	if key.is_empty():
		return false
	var wkey: String = String(sd.get("width", ""))
	var fkey: String = String(sd.get("feather", ""))
	var vertical: bool = bool(vals.get("vertical", false))
	var pos: float = float(vals.get("pos", 0.5))
	var w: float = float(vals.get("w", 0.0))
	var f: float = float(vals.get("f", 0.0))
	var ws: float = float(sd.get("width_scale", 0.5))
	var half: float = w * ws
	var xf: Transform2D = t["xf"]
	var across: Vector2 = xf.basis_xform(band_at(vertical, 1.0, 0.0) - band_at(vertical, 0.0, 0.0))
	var lines: Array[Dictionary] = []
	var hs: Array[Dictionary] = []
	if wkey.is_empty():
		lines.append({"pts": _band_line(xf, vertical, pos), "dashed": false, "handle": "m"})
	else:
		for i: int in 2:
			lines.append({"pts": _band_line(xf, vertical, pos + (half if i == 1 else -half)), "dashed": false, "handle": "w" + str(i)})
		if not fkey.is_empty():
			for i2: int in 2:
				lines.append({"pts": _band_line(xf, vertical, pos + (half + f) * (1.0 if i2 == 1 else -1.0)), "dashed": true, "handle": "f" + str(i2)})
		t["shape"] = PackedVector2Array([xf * band_at(vertical, pos - half, 0.0), xf * band_at(vertical, pos - half, 1.0), xf * band_at(vertical, pos + half, 1.0), xf * band_at(vertical, pos + half, 0.0)])
		t["movable"] = true
	hs.append({"id": "m", "at": xf * band_at(vertical, pos, 0.5), "look": "knob_bar", "dir": across, "name": label_of(def, key), "tip": value_text(def, key, pos)})
	if not wkey.is_empty():
		for i3: int in 2:
			hs.append({"id": "w" + str(i3), "at": xf * band_at(vertical, pos + (half if i3 == 1 else -half), BAND_KNOB_W), "look": "knob", "name": label_of(def, wkey), "tip": value_text(def, wkey, w)})
		if not fkey.is_empty():
			for i4: int in 2:
				hs.append({"id": "f" + str(i4), "at": xf * band_at(vertical, pos + (half + f) * (1.0 if i4 == 1 else -1.0), BAND_KNOB_F), "look": "knob_hollow", "name": label_of(def, fkey), "tip": value_text(def, fkey, f)})
	t["lines"] = lines
	t["handles"] = hs
	t["band"] = {"pos": pos, "w": w, "f": f, "vertical": vertical, "ws": ws, "key": key, "width": wkey, "feather": fkey}
	if not t.has("movable"):
		t["movable"] = false
	return true


static func band_keys(sd: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in ["key", "width", "feather"]:
		var k: String = String(sd.get(f, ""))
		if not k.is_empty():
			out.append(k)
	return out


static func band_key_of(sd: Dictionary, handle: String) -> String:
	if handle.begins_with("w"):
		return String(sd.get("width", ""))
	if handle.begins_with("f"):
		return String(sd.get("feather", ""))
	return String(sd.get("key", ""))


static func band_drag(t: Dictionary, def: Dictionary, handle: String, uv: Vector2, uv0: Vector2) -> Dictionary:
	var info: Dictionary = t["band"]
	var vertical: bool = bool(info["vertical"])
	var along: float = uv.x if vertical else uv.y
	var along0: float = uv0.x if vertical else uv0.y
	var pos: float = float(info["pos"])
	var ws: float = maxf(absf(float(info["ws"])), ARM_MIN)
	var out: Dictionary = {}
	var k: String = String(info["key"])
	var chip: String = ""
	if handle.begins_with("w"):
		var kw: String = String(info["width"])
		var w: float = clamp_value(def, kw, absf(along - pos) / ws)
		out[kw] = w
		chip = value_text(def, kw, w)
	elif handle.begins_with("f"):
		var kf: String = String(info["feather"])
		var f: float = clamp_value(def, kf, absf(along - pos) - float(info["w"]) * ws)
		out[kf] = f
		chip = value_text(def, kf, f)
	else:
		var p: float = clamp_value(def, k, pos + along - along0)
		out[k] = p
		chip = value_text(def, k, p)
	return {"values": out, "chip": chip}


static func near_lines(t: Dictionary, at: Vector2, to_screen: Callable, reach: float) -> String:
	var lines: Variant = t.get("lines", [])
	if not (lines is Array):
		return ""
	var best: String = ""
	var best_d: float = reach
	for ln: Variant in lines:
		var ld: Dictionary = ln
		var id: String = String(ld.get("handle", ""))
		if id.is_empty():
			continue
		var pts: PackedVector2Array = ld["pts"]
		for i: int in range(1, pts.size()):
			var a: Vector2 = to_screen.call(pts[i - 1])
			var b: Vector2 = to_screen.call(pts[i])
			var dd: float = at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
			if dd <= best_d:
				best_d = dd
				best = id
	return best


static func near_line(t: Dictionary, at: Vector2, to_screen: Callable, reach: float) -> bool:
	var lines: Variant = t.get("lines", [])
	if not (lines is Array) or (lines as Array).is_empty():
		return false
	var pts: PackedVector2Array = ((lines as Array)[0] as Dictionary)["pts"]
	for i: int in range(1, pts.size()):
		var a: Vector2 = to_screen.call(pts[i - 1])
		var b: Vector2 = to_screen.call(pts[i])
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) <= reach:
			return true
	return false


static func arm_dir(xf: Transform2D, deg: float, sd: Dictionary) -> Vector2:
	var l: Vector2 = _local_dir(deg, sd)
	var space: String = String(sd.get("space", ""))
	var d: Vector2 = xf.x.normalized() * l.x + xf.y.normalized() * l.y
	if space == "uv":
		d = xf.x * l.x + xf.y * l.y
	elif space == "uv_normal":
		var inv: Transform2D = Transform2D(xf.x, xf.y, Vector2.ZERO).affine_inverse()
		d = Vector2(inv.x.dot(l), inv.y.dot(l))
	return d.normalized() if d.length() > 0.000001 else Vector2.UP


static func arm_angle(xf: Transform2D, v: Vector2, sd: Dictionary) -> float:
	var z: Vector2 = _zero_of(String(sd.get("zero", "up")))
	var p: Vector2 = Vector2(-z.y, z.x) if String(sd.get("turn", "cw")) != "ccw" else Vector2(z.y, -z.x)
	var space: String = String(sd.get("space", ""))
	var l: Vector2 = Vector2(v.dot(xf.x.normalized()), v.dot(xf.y.normalized()))
	if space == "uv":
		l = Transform2D(xf.x, xf.y, Vector2.ZERO).affine_inverse().basis_xform(v)
	elif space == "uv_normal":
		l = Vector2(v.dot(xf.x), v.dot(xf.y))
	return rad_to_deg(atan2(l.dot(p), l.dot(z)))


static func _zero_of(name: String) -> Vector2:
	if name == "right":
		return Vector2(1.0, 0.0)
	if name == "down":
		return Vector2(0.0, 1.0)
	if name == "left":
		return Vector2(-1.0, 0.0)
	return Vector2(0.0, -1.0)


static func _local_dir(deg: float, sd: Dictionary) -> Vector2:
	var z: Vector2 = _zero_of(String(sd.get("zero", "up")))
	var p: Vector2 = Vector2(-z.y, z.x) if String(sd.get("turn", "cw")) != "ccw" else Vector2(z.y, -z.x)
	var a: float = deg_to_rad(deg)
	return z * cos(a) + p * sin(a)


static func _len_axes(unit: String, aspect: float, px: Vector2) -> Vector2:
	if unit == "uv":
		return Vector2(1.0, 1.0)
	return unit_axes(unit, aspect, px, 0.0, false)


static func arm_end_uv(about: Vector2, deg: float, length: float, sd: Dictionary, aspect: float, px: Vector2) -> Vector2:
	var ax: Vector2 = _len_axes(String(sd.get("length_unit", "px")), aspect, px)
	var l: Vector2 = _local_dir(deg, sd) * length * float(sd.get("length_scale", 1.0))
	return about + Vector2(l.x / ax.x, l.y / ax.y)


static func arm_from_uv(about: Vector2, uv: Vector2, sd: Dictionary, aspect: float, px: Vector2) -> Dictionary:
	var ax: Vector2 = _len_axes(String(sd.get("length_unit", "px")), aspect, px)
	var off: Vector2 = uv - about
	var m: Vector2 = Vector2(off.x * ax.x, off.y * ax.y)
	var z: Vector2 = _zero_of(String(sd.get("zero", "up")))
	var p: Vector2 = Vector2(-z.y, z.x) if String(sd.get("turn", "cw")) != "ccw" else Vector2(z.y, -z.x)
	var ls: float = float(sd.get("length_scale", 1.0))
	return {"angle": rad_to_deg(atan2(m.dot(p), m.dot(z))), "length": m.length() / (ls if absf(ls) > ARM_MIN else 1.0)}


static func draw_lines(ci: CanvasItem, t: Dictionary, to_screen: Callable, ink: Color, lit: bool) -> void:
	var lines: Variant = t.get("lines", [])
	if not (lines is Array):
		return
	for ln: Variant in lines:
		var pts: PackedVector2Array = (ln as Dictionary)["pts"]
		var scr: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			scr.append(to_screen.call(p))
		if scr.size() < 2:
			continue
		if bool((ln as Dictionary).get("dashed", false)):
			for i: int in range(1, scr.size()):
				if i % DASH_EVERY == 0:
					ci.draw_line(scr[i - 1], scr[i], SHADE, 3.0, true)
					ci.draw_line(scr[i - 1], scr[i], Color(ink, 0.9), 1.25, true)
			continue
		ci.draw_polyline(scr, SHADE, 3.5 if lit else 3.0, true)
		ci.draw_polyline(scr, ink, 2.0 if lit else 1.25, true)


static func draw_knob(ci: CanvasItem, at: Vector2, ink: Color, lit: bool, hollow: bool) -> void:
	var r: float = KNOB - 1.0 + (1.5 if lit else 0.0)
	ci.draw_circle(at, r + 1.5, SHADE)
	if hollow:
		ci.draw_arc(at, r - 0.5, 0.0, TAU, 24, FILL, 2.5, true)
		ci.draw_arc(at, r - 0.5, 0.0, TAU, 24, ink, 1.0, true)
		return
	ci.draw_circle(at, r, ink if lit else FILL)
	ci.draw_arc(at, r, 0.0, TAU, 24, ink, 1.5, true)
	ci.draw_circle(at, 1.5, ink if not lit else FILL)


static func draw_pill(ci: CanvasItem, at: Vector2, dir: Variant, ink: Color, lit: bool) -> void:
	var d: Vector2 = (dir as Vector2).normalized() if dir is Vector2 and (dir as Vector2).length() > ARM_MIN else Vector2.DOWN
	var half: float = KNOB * 1.4 + (1.5 if lit else 0.0)
	ci.draw_line(at - d * half, at + d * half, SHADE, 8.0 + (1.5 if lit else 0.0), true)
	ci.draw_line(at - d * (half - 0.5), at + d * (half - 0.5), ink, 6.0 + (1.0 if lit else 0.0), true)
	ci.draw_line(at - d * (half - 1.5), at + d * (half - 1.5), ink if lit else FILL, 3.5, true)
