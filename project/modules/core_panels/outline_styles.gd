extends RefCounted

signal changed

const Io := preload("res://doc/io.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const ShaderConvert := preload("res://engine/gdshader_convert.gd")
const BUILT_IN_ROOT := "res://outlines/"
const USER_SUB := "outlines"
const DEF_FILE := "outline.json"
const SHADER_FILE := "outline.gdshader"
const LIBRARY := "res://outlines/outline.gdshaderinc"
const FALLBACK := "solid"
const PROBE := "pm_outline_probe"
const ENGINE_UNIFORMS: PackedStringArray = ["colour", "thickness", "time", "outline_corners", "outline_perimeter", "pm_outline_probe"]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "colour"]
const PREF_SHOW := "program.outline.show"
const PREF_STYLE := "program.outline.style"
const PREF_COLOUR := "program.outline.colour"
const PREF_THICKNESS := "program.outline.thickness"
const PREF_PARAM := "program.outline."
const DEFAULT_REACH := 1.5
const LOOK_EVERY := 2.0
const THICK_MIN := 0.5
const THICK_MAX := 8.0

static var _shared: RefCounted = null
static var user_root_override: String = ""

var _defs: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _broken: Array[Dictionary] = []
var _shaders: Dictionary = {}
var _noted: Dictionary = {}
var _stamp: String = ""
var _since_look: float = 0.0
var loads: int = 0


static func shared() -> RefCounted:
	if _shared == null:
		var script: GDScript = load("res://modules/core_panels/outline_styles.gd")
		_shared = script.new()
		_shared.call("load_all")
	return _shared


static func user_root() -> String:
	if not user_root_override.is_empty():
		return user_root_override.trim_suffix("/") + "/"
	return Io.data_path(USER_SUB) + "/"


static func pref_key(style_id: String, key: String) -> String:
	return PREF_PARAM + style_id + "." + key


static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for ch: String in id:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789_"):
			return false
	return true


func load_all() -> void:
	_defs = {}
	_broken = []
	_scan(BUILT_IN_ROOT, "built_in")
	_scan(user_root(), "user")
	_scan_loose(user_root())
	_sort()
	_stamp = EffectRegistry.folder_stamp(user_root())
	loads += 1
	for b: Dictionary in _broken:
		_note("An outline style could not be loaded: " + String(b["reason"]), String(b["path"]))
	changed.emit()


func reload() -> void:
	_shaders = {}
	load_all()


func refresh_if_changed() -> bool:
	var now: String = EffectRegistry.folder_stamp(user_root())
	if now == _stamp:
		return false
	reload()
	return true


func tick(dt: float) -> bool:
	_since_look += dt
	if _since_look < LOOK_EVERY:
		return false
	_since_look = 0.0
	return refresh_if_changed()


func ids() -> PackedStringArray:
	return _order.duplicate()


func has(id: String) -> bool:
	return _defs.has(id)


func get_def(id: String) -> Dictionary:
	return _defs.get(id, {})


func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in _order:
		out.append(_defs[id])
	return out


func broken() -> Array[Dictionary]:
	return _broken.duplicate()


func label_of(id: String) -> String:
	return String(get_def(id).get("label", id.capitalize()))


func _scan(root: String, source: String) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	var folders: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with(".") and not entry.begins_with("_"):
			folders.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	folders.sort()
	for folder: String in folders:
		var path: String = root + folder + "/"
		var raw: Dictionary = {}
		if FileAccess.file_exists(path + DEF_FILE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + DEF_FILE))
			if typeof(parsed) != TYPE_DICTIONARY:
				_broken.append({"path": path + DEF_FILE, "id": folder, "reason": "outline.json is not a JSON object"})
				continue
			raw = parsed
		elif not FileAccess.file_exists(path + SHADER_FILE):
			continue
		_add(_normalise(raw, path, folder, source, String(raw.get("shader", SHADER_FILE))))


func _scan_loose(root: String) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	var files: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.get_extension() == "gdshader":
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f: String in files:
		_add(_normalise({"label": f.get_basename().capitalize()}, root, f.get_basename().to_lower(), "user", f))


func _add(def: Dictionary) -> void:
	if def.is_empty():
		return
	var id: String = String(def["id"])
	if _defs.has(id):
		_broken.append({"path": String(def["shader"]), "id": id, "reason": "the id \"" + id + "\" is already used by " + String(_defs[id]["shader"])})
		return
	_defs[id] = def


func _normalise(raw: Dictionary, folder: String, fallback_id: String, source: String, shader_name: String) -> Dictionary:
	var id: String = String(raw.get("id", fallback_id)).strip_edges().to_lower()
	if not valid_id(id):
		_broken.append({"path": folder, "id": id, "reason": "the id \"" + id + "\" has characters outside a-z, 0-9 and _"})
		return {}
	var shader_path: String = folder + shader_name
	if not FileAccess.file_exists(shader_path):
		_broken.append({"path": shader_path, "id": id, "reason": "the shader file is missing"})
		return {}
	var params: Array[Dictionary] = []
	var seen: Dictionary = {}
	var raw_params: Variant = raw.get("params", [])
	if raw_params is Array:
		for p: Variant in raw_params:
			if p is Dictionary:
				var np: Dictionary = _normalise_param(p)
				if not np.is_empty() and not seen.has(String(np["key"])):
					seen[String(np["key"])] = true
					params.append(np)
	for dp: Dictionary in _discovered(FileAccess.get_file_as_string(shader_path)):
		if not seen.has(String(dp["key"])):
			seen[String(dp["key"])] = true
			params.append(dp)
	return {
		"id": id,
		"label": String(raw.get("label", id.capitalize())),
		"blurb": String(raw.get("blurb", "")),
		"order": int(raw.get("order", 100)),
		"reach": raw.get("reach", DEFAULT_REACH),
		"params": params,
		"shader": shader_path,
		"folder": folder,
		"source": source,
	}


static func _normalise_param(p: Dictionary) -> Dictionary:
	var key: String = String(p.get("key", "")).strip_edges()
	if key.is_empty() or ENGINE_UNIFORMS.has(key) or key.begins_with("outline_"):
		return {}
	var type: String = String(p.get("type", "float"))
	if type == "color":
		type = "colour"
	if not PARAM_TYPES.has(type):
		type = "float"
	var out: Dictionary = {
		"key": key,
		"label": String(p.get("label", key.capitalize())),
		"type": type,
		"min": float(p.get("min", 0.0)),
		"max": float(p.get("max", 100.0)),
		"step": float(p.get("step", 0.1 if type == "float" else 1.0)),
		"unit": String(p.get("unit", "")),
		"default": 0.0,
	}
	var d: Variant = p.get("default", null)
	if type == "bool":
		out["default"] = bool(d) if d != null else false
	elif type == "colour":
		out["default"] = colour_text(d)
	elif type == "int":
		out["default"] = int(d) if d != null else 0
	else:
		out["default"] = float(d) if d != null else 0.0
	return out


static func _discovered(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in EffectRegistry.discover_params(code):
		var pd: Dictionary = p
		var key: String = String(pd.get("key", ""))
		if ENGINE_UNIFORMS.has(key) or key.begins_with("outline_"):
			continue
		var type: String = String(pd.get("type", "float"))
		if type == "color":
			type = "colour"
		if not PARAM_TYPES.has(type):
			continue
		var d: Variant = pd.get("default", 0.0)
		var np: Dictionary = {"key": key, "label": key.capitalize(), "type": type, "min": float(pd.get("min", 0.0)), "max": float(pd.get("max", 100.0)), "step": float(pd.get("step", 0.1)), "unit": "", "default": d}
		if type == "colour":
			np["default"] = colour_text(d)
		elif type == "int":
			np["default"] = int(d)
		elif type == "bool":
			np["default"] = bool(d)
		else:
			np["default"] = float(d)
		out.append(np)
	return out


static func colour_text(v: Variant) -> String:
	if v is String and not (v as String).is_empty():
		return "#" + Color.from_string(String(v), Color.WHITE).to_html(true)
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var c: Color = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() >= 4 else 1.0)
		return "#" + c.to_html(true)
	return "#ffffffff"


func _sort() -> void:
	var list: Array[Dictionary] = []
	for id: Variant in _defs.keys():
		list.append(_defs[id])
	list.sort_custom(_before)
	_order = PackedStringArray()
	for d: Dictionary in list:
		_order.append(String(d["id"]))


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = 0 if String(a["source"]) == "built_in" else 1
	var sb: int = 0 if String(b["source"]) == "built_in" else 1
	if sa != sb:
		return sa < sb
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return String(a["label"]) < String(b["label"])


func ensure_prefs(prefs: Node) -> void:
	if prefs == null:
		return
	var specs: Array = [
		[PREF_SHOW, true, {"label": "Show the transform outline", "type": "bool"}],
		[PREF_STYLE, FALLBACK, {"label": "Transform outline style", "type": "enum", "choices": Array(ids())}],
		[PREF_COLOUR, "", {"label": "Transform outline colour (empty follows the theme)", "type": "string"}],
		[PREF_THICKNESS, 1.0, {"label": "Transform outline thickness in pixels", "type": "float", "min": THICK_MIN, "max": THICK_MAX}],
	]
	for spec: Array in specs:
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])
	var style_spec: Variant = prefs.call("spec", PREF_STYLE)
	if style_spec is Dictionary:
		(style_spec as Dictionary)["choices"] = Array(ids())
	for d: Dictionary in list():
		for p: Dictionary in d["params"]:
			var key: String = pref_key(String(d["id"]), String(p["key"]))
			if bool(prefs.call("is_registered", key)):
				continue
			var label: String = "Transform outline, " + String(d["label"]) + ": " + String(p["label"]).to_lower()
			var type: String = String(p["type"])
			if type == "colour":
				prefs.call("register", key, String(p["default"]), {"label": label + " (colour)", "type": "string"})
			elif type == "bool":
				prefs.call("register", key, bool(p["default"]), {"label": label, "type": "bool"})
			elif type == "int":
				prefs.call("register", key, int(p["default"]), {"label": label, "type": "int", "min": p["min"], "max": p["max"]})
			else:
				prefs.call("register", key, float(p["default"]), {"label": label, "type": "float", "min": p["min"], "max": p["max"]})


func param_value(prefs: Node, style_id: String, p: Dictionary) -> Variant:
	var key: String = pref_key(style_id, String(p["key"]))
	var v: Variant = prefs.call("get_value", key) if prefs != null and bool(prefs.call("is_registered", key)) else p["default"]
	var type: String = String(p["type"])
	if type == "colour":
		return Color.from_string(String(v), Color.WHITE)
	if type == "bool":
		return bool(v)
	if type == "int":
		return int(v)
	return float(v)


func param_values(prefs: Node, style_id: String) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in get_def(style_id).get("params", []):
		out[String(p["key"])] = param_value(prefs, style_id, p)
	return out


func reach_of(style_id: String, values: Dictionary) -> float:
	var r: Variant = get_def(style_id).get("reach", DEFAULT_REACH)
	if r is Dictionary:
		var pv: Variant = values.get(String((r as Dictionary).get("param", "")), null)
		var k: float = float((r as Dictionary).get("scale", 1.0))
		if pv is float or pv is int:
			return clampf(float(pv) * k, 0.0, 400.0)
		return DEFAULT_REACH
	if r is float or r is int:
		return clampf(float(r), 0.0, 400.0)
	return DEFAULT_REACH


static func compose_code(text: String) -> String:
	var st := RegEx.new()
	st.compile("shader_type\\s+canvas_item\\s*;")
	var m: RegExMatch = st.search(text)
	if m == null:
		return ""
	if text.contains(LIBRARY):
		return text
	var at: int = m.get_end()
	var rm := RegEx.new()
	rm.compile("^\\s*render_mode[^;]*;")
	var rmm: RegExMatch = rm.search(text.substr(at))
	if rmm != null:
		at += rmm.get_end()
	return text.substr(0, at) + "\n#include \"" + LIBRARY + "\"\n" + text.substr(at)


func shader_info(style_id: String) -> Dictionary:
	var def: Dictionary = get_def(style_id)
	if def.is_empty():
		return {"ok": false, "reason": "there is no style called \"" + style_id + "\"", "shader": null, "uniforms": {}}
	var path: String = String(def["shader"])
	var stamp: int = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	if _shaders.has(path) and int((_shaders[path] as Dictionary).get("stamp", -2)) == stamp:
		return _shaders[path]
	var info: Dictionary = compile(FileAccess.get_file_as_string(path) if stamp >= 0 else "")
	info["stamp"] = stamp
	_shaders[path] = info
	return info


static func compile(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"ok": false, "reason": "the shader file is empty or missing", "shader": null, "uniforms": {}}
	var code: String = compose_code(text)
	if code.is_empty():
		return {"ok": false, "reason": "the shader must start with shader_type canvas_item;", "shader": null, "uniforms": {}}
	var sh: Shader = Shader.new()
	var caught: Dictionary = ShaderConvert.caught_uniforms(sh, code + "\nuniform float " + PROBE + " = 0.0;\n")
	var uniforms: Dictionary = {}
	for u: Dictionary in caught["uniforms"]:
		uniforms[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	if not uniforms.has(PROBE):
		var said: String = ShaderConvert.compiler_text_for(caught["errors"], text, code)
		return {"ok": false, "reason": "the shader did not compile, " + (said if not said.is_empty() else "the compiler gave no message"), "shader": null, "uniforms": {}}
	if not uniforms.has("outline_corners"):
		return {"ok": false, "reason": "the shader does not use the outline library", "shader": null, "uniforms": {}}
	return {"ok": true, "reason": "", "shader": sh, "uniforms": uniforms}


func resolve(style_id: String) -> Dictionary:
	var want: String = style_id if has(style_id) else FALLBACK
	var reason: String = ""
	if not has(style_id):
		reason = "it is not in the outlines folders any more"
		for b: Dictionary in _broken:
			if String(b.get("id", "")) == style_id:
				reason = String(b["reason"])
	var info: Dictionary = shader_info(want)
	if not bool(info.get("ok", false)) and want != FALLBACK:
		reason = String(info.get("reason", ""))
		want = FALLBACK
		info = shader_info(want)
	if want != style_id and not style_id.is_empty():
		_note("The outline style \"" + style_id + "\" could not be used, so Solid is drawn instead: " + reason, String(get_def(style_id).get("shader", user_root())))
	return {
		"id": want,
		"asked": style_id,
		"ok": bool(info.get("ok", false)),
		"reason": reason,
		"shader": info.get("shader", null),
		"uniforms": info.get("uniforms", {}),
		"animated": (info.get("uniforms", {}) as Dictionary).has("time"),
	}


func _note(text: String, detail: String) -> void:
	var key: String = text + "|" + detail
	if _noted.has(key):
		return
	_noted[key] = true
	var loop: MainLoop = Engine.get_main_loop()
	var events: Node = (loop as SceneTree).root.get_node_or_null("Events") if loop is SceneTree else null
	if events != null:
		events.call("warn", text, detail)
	else:
		print("outline styles: ", text, " (", detail, ")")


func noted() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in _noted.keys():
		out.append(String(k))
	return out
