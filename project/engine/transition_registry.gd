extends RefCounted

signal changed

const Io := preload("res://doc/io.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const ShaderConvert := preload("res://engine/gdshader_convert.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const Timing := preload("res://doc/transition_timing.gd")
const SELF_PATH := "res://engine/transition_registry.gd"
const BUILT_IN_ROOT := "res://transitions/"
const USER_SUB := "transitions"
const DEF_FILE := "transition.json"
const SHADER_FILE := "transition.gdshader"
const LIBRARY := "res://transitions/_lib/transition.gdshaderinc"
const FALLBACK_SHADER := "res://engine/transition_fallback.gdshader"
const PROBE := "pm_transition_probe"
const ENGINE_UNIFORMS: PackedStringArray = ["from_tex", "to_tex", "progress", "frame_px", "px_scale", "seed", "duration", "time", "pm_transition_probe"]
const GROUPS: PackedStringArray = ["Dissolve", "Light and Film", "Wipe", "Shape", "Slide and Push", "Zoom and Camera", "Distort", "Glitch", "Particles", "3D"]
const OTHER_GROUP := "Other"
const CLASSIC_GROUP := "Classic"
const CLASSIC: Array = [["dissolve", "Cross dissolve"], ["dip_black", "Dip to black"], ["dip_white", "Dip to white"], ["wipe_left", "Wipe left"], ["wipe_right", "Wipe right"], ["wipe_up", "Wipe up"], ["wipe_down", "Wipe down"], ["push_left", "Push left"], ["push_right", "Push right"], ["push_up", "Push up"], ["push_down", "Push down"], ["slide_left", "Slide left"], ["slide_right", "Slide right"], ["slide_up", "Slide up"], ["slide_down", "Slide down"]]
const AUDIO_KIND := "crossfade"
const LIB_KEY := "lib"
const PARAMS_KEY := "params"
const PATH_PREFIX := "transition."
const PREF_DEFAULT := "edit.default_video_transition"
const CLASSIC_DEFAULT := "dissolve"
const DEFAULT_DURATION := 1.0
const LOOK_EVERY := 2.0
const SEED_RANGE := 9973

static var _shared: RefCounted = null
static var user_root_override: String = ""

var _defs: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _broken: Array[Dictionary] = []
var _shaders: Dictionary = {}
var _noted: Dictionary = {}
var _stamp: String = ""
var _since_look: float = 0.0
var _fallback: Dictionary = {}
var loads: int = 0
var compiles: int = 0


static func shared() -> RefCounted:
	if _shared == null:
		var script: GDScript = load(SELF_PATH)
		_shared = script.new()
		_shared.call("load_all")
	return _shared


static func user_root() -> String:
	if not user_root_override.is_empty():
		return user_root_override.trim_suffix("/") + "/"
	return Io.data_path(USER_SUB) + "/"


static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for ch: String in id:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789_"):
			return false
	return true


static func is_classic(kind: String) -> bool:
	return LayerChain.TRANSITION_KINDS.has(kind) or kind == AUDIO_KIND


static func classic_label(kind: String) -> String:
	for pair: Array in CLASSIC:
		if String(pair[0]) == kind:
			return String(pair[1])
	if kind == AUDIO_KIND:
		return "Crossfade"
	return kind.replace("_", " ").capitalize()


static func classic_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for pair: Array in CLASSIC:
		out.append(String(pair[0]))
	return out


static func library_id(tr: Dictionary) -> String:
	var kind: String = str(tr.get("kind", ""))
	if kind.is_empty() or kind == "none" or kind == AUDIO_KIND:
		return ""
	if bool(tr.get(LIB_KEY, false)):
		return kind
	if LayerChain.TRANSITION_KINDS.has(kind):
		return ""
	return kind


static func is_param_path(path: String) -> bool:
	return path.begins_with(PATH_PREFIX)


static func param_path(key: String) -> String:
	return PATH_PREFIX + key


static func seed_for(clip_id: String) -> float:
	return float(absi(clip_id.hash()) % SEED_RANGE)


func load_all() -> void:
	_defs = {}
	_broken = []
	_scan(BUILT_IN_ROOT, "built_in")
	_scan(user_root(), "user")
	_sort()
	_stamp = EffectRegistry.folder_stamp(user_root())
	loads += 1
	for b: Dictionary in _broken:
		_note("A transition could not be loaded: " + String(b["reason"]), String(b["path"]), true)
	changed.emit()


func reload() -> void:
	_shaders = {}
	_noted = {}
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
	if _defs.has(id):
		return String((_defs[id] as Dictionary)["label"])
	return classic_label(id)


func label_for(tr: Dictionary) -> String:
	var lib: String = library_id(tr)
	if lib.is_empty():
		return classic_label(str(tr.get("kind", "")))
	return label_of(lib)


func groups() -> PackedStringArray:
	var seen: Dictionary = {}
	for id: String in _order:
		seen[String((_defs[id] as Dictionary)["group"])] = true
	var out: PackedStringArray = PackedStringArray()
	for g: String in GROUPS:
		if seen.has(g):
			out.append(g)
	var rest: Array = []
	for k: Variant in seen.keys():
		if not GROUPS.has(String(k)):
			rest.append(String(k))
	rest.sort()
	for r: Variant in rest:
		out.append(String(r))
	return out


func in_group(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in _order:
		var d: Dictionary = _defs[id]
		if String(d["group"]) == group:
			out.append(d)
	return out


static func matches(d: Dictionary, text: String) -> bool:
	var q: String = text.strip_edges().to_lower()
	if q.is_empty():
		return true
	var hay: PackedStringArray = PackedStringArray([String(d.get("id", "")), String(d.get("label", "")), String(d.get("group", "")), String(d.get("blurb", ""))])
	for f: Variant in d.get("from", []):
		hay.append(String(f))
	var all: String = " ".join(hay).to_lower()
	for word: String in q.split(" ", false):
		if not all.contains(word):
			return false
	return true


func search(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in list():
		if matches(d, text):
			out.append(d)
	return out


func classic_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair: Array in CLASSIC:
		out.append({"id": String(pair[0]), "label": String(pair[1]), "group": CLASSIC_GROUP, "space": "2D", "from": ["Purrmiere before the library"], "blurb": "The built in transition from earlier versions; it looks exactly as it always did.", "default_duration": DEFAULT_DURATION, "params": [], "classic": true, "source": "classic"})
	return out


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
				_broken.append({"path": path + DEF_FILE, "id": folder, "reason": "transition.json is not a JSON object"})
				continue
			raw = parsed
		elif not FileAccess.file_exists(path + SHADER_FILE):
			continue
		_add(_normalise(raw, path, folder, source))


func _add(def: Dictionary) -> void:
	if def.is_empty():
		return
	var id: String = String(def["id"])
	if _defs.has(id) or is_classic(id):
		var by: String = String((_defs[id] as Dictionary)["folder"]) if _defs.has(id) else "a built in transition"
		_broken.append({"path": String(def["folder"]), "id": id, "reason": "the id \"" + id + "\" is already used by " + by})
		return
	_defs[id] = def


func _normalise(raw: Dictionary, folder: String, fallback_id: String, source: String) -> Dictionary:
	var id: String = String(raw.get("id", fallback_id)).strip_edges().to_lower()
	if not valid_id(id):
		_broken.append({"path": folder, "id": id, "reason": "the id \"" + id + "\" has characters outside a-z, 0-9 and _"})
		return {}
	var shader_path: String = folder + String(raw.get("shader", SHADER_FILE))
	if not FileAccess.file_exists(shader_path):
		_broken.append({"path": shader_path, "id": id, "reason": "the shader file is missing"})
		return {}
	var params: Array = []
	var seen: Dictionary = {}
	var raw_params: Variant = raw.get("params", [])
	if raw_params is Array:
		for p: Variant in raw_params:
			if not (p is Dictionary):
				continue
			var np: Dictionary = EffectRegistry._normalise_param(p)
			if np.is_empty() or ENGINE_UNIFORMS.has(String(np["key"])) or seen.has(String(np["key"])):
				continue
			seen[String(np["key"])] = true
			params.append(np)
	var from: Array = []
	var raw_from: Variant = raw.get("from", [])
	if raw_from is Array:
		for f: Variant in raw_from:
			from.append(String(f))
	elif raw_from is String:
		from.append(String(raw_from))
	var group: String = String(raw.get("group", "")).strip_edges()
	if group.is_empty():
		group = OTHER_GROUP
	return {
		"id": id,
		"label": String(raw.get("label", id.replace("_", " ").capitalize())),
		"group": group,
		"space": "3D" if String(raw.get("space", "2D")).to_upper() == "3D" else "2D",
		"from": from,
		"blurb": String(raw.get("blurb", "")),
		"default_duration": clampf(float(raw.get("default_duration", DEFAULT_DURATION)), 0.04, 30.0),
		"steps": bool(raw.get("steps", false)),
		"handles": (raw["handles"] as Array).duplicate(true) if raw.get("handles") is Array else [],
		"pyramid": bool(raw.get("pyramid", false)),
		"params": params,
		"shader": shader_path,
		"folder": folder,
		"source": source,
	}


func _sort() -> void:
	var all: Array[Dictionary] = []
	for id: Variant in _defs.keys():
		all.append(_defs[id])
	all.sort_custom(_before)
	_order = PackedStringArray()
	for d: Dictionary in all:
		_order.append(String(d["id"]))


static func _group_rank(g: String) -> int:
	var i: int = GROUPS.find(g)
	return i if i >= 0 else GROUPS.size()


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var ga: int = _group_rank(String(a["group"]))
	var gb: int = _group_rank(String(b["group"]))
	if ga != gb:
		return ga < gb
	if String(a["group"]) != String(b["group"]):
		return String(a["group"]) < String(b["group"])
	var sa: int = 0 if String(a["source"]) == "built_in" else 1
	var sb: int = 0 if String(b["source"]) == "built_in" else 1
	if sa != sb:
		return sa < sb
	return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0


static func compile(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"ok": false, "reason": "the shader file is empty or missing", "shader": null, "uniforms": {}}
	if not text.contains("canvas_item"):
		return {"ok": false, "reason": "the shader must be a canvas_item shader", "shader": null, "uniforms": {}}
	var sh: Shader = Shader.new()
	var code: String = text + "\nuniform float " + PROBE + " = 0.0;\n"
	var caught: Dictionary = ShaderConvert.caught_uniforms(sh, code)
	var uniforms: Dictionary = {}
	for u: Dictionary in caught["uniforms"]:
		uniforms[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	if not uniforms.has(PROBE):
		var said: String = ShaderConvert.compiler_text_for(caught["errors"], text, code)
		return {"ok": false, "reason": "the shader did not compile, " + (said if not said.is_empty() else "the compiler gave no message"), "shader": null, "uniforms": {}}
	if not uniforms.has("from_tex") or not uniforms.has("to_tex") or not uniforms.has("progress"):
		return {"ok": false, "reason": "the shader does not include the transition library", "shader": null, "uniforms": {}}
	return {"ok": true, "reason": "", "shader": sh, "uniforms": uniforms}


func shader_info(id: String) -> Dictionary:
	var def: Dictionary = get_def(id)
	if def.is_empty():
		return {"ok": false, "reason": "there is no transition called \"" + id + "\"", "shader": null, "uniforms": {}}
	var path: String = String(def["shader"])
	if _shaders.has(path):
		return _shaders[path]
	compiles += 1
	var info: Dictionary = compile(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	_shaders[path] = info
	if not bool(info["ok"]):
		_note("The transition \"" + String(def["label"]) + "\" is broken, so a plain dissolve is drawn instead: " + String(info["reason"]), path, true)
	return info


func validate_all() -> Array[Dictionary]:
	var bad: Array[Dictionary] = []
	for id: String in _order:
		var info: Dictionary = shader_info(id)
		if not bool(info["ok"]):
			bad.append({"id": id, "reason": String(info["reason"])})
	return bad


func fallback() -> Dictionary:
	if _fallback.is_empty():
		var sh: Shader = load(FALLBACK_SHADER)
		var uniforms: Dictionary = {}
		if sh != null:
			for u: Dictionary in sh.get_shader_uniform_list(true):
				uniforms[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
		_fallback = {"ok": sh != null, "reason": "", "shader": sh, "uniforms": uniforms}
	return _fallback


func resolve(id: String) -> Dictionary:
	if not has(id):
		var reason: String = "it is not in the transitions folders"
		for b: Dictionary in _broken:
			if String(b.get("id", "")) == id:
				reason = String(b["reason"])
		_note("The transition \"" + id + "\" could not be used, so a plain dissolve is drawn instead: " + reason, user_root(), false)
		var fb: Dictionary = fallback().duplicate()
		fb["id"] = ""
		fb["asked"] = id
		fb["fell_back"] = true
		return fb
	var info: Dictionary = shader_info(id)
	if not bool(info["ok"]):
		var fb2: Dictionary = fallback().duplicate()
		fb2["id"] = ""
		fb2["asked"] = id
		fb2["fell_back"] = true
		return fb2
	var out: Dictionary = info.duplicate()
	out["id"] = id
	out["asked"] = id
	out["fell_back"] = false
	out["pyramid"] = bool(get_def(id).get("pyramid", false))
	return out


func default_params(id: String) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in get_def(id).get("params", []):
		var pd: Dictionary = p
		out[String(pd["key"])] = AnimProp.make(pd["default"])
	return out


func default_duration(id: String) -> float:
	return float(get_def(id).get("default_duration", DEFAULT_DURATION))


func make_spec(id: String, duration: float, offset: float) -> Dictionary:
	var spec: Dictionary = {"kind": id, "duration": duration, "offset": offset}
	if has(id) or not is_classic(id):
		spec[LIB_KEY] = true
		spec[PARAMS_KEY] = default_params(id)
	return Timing.with_progress(spec)


func changed_spec(tr: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = tr.duplicate(true)
	out["kind"] = id
	var keep: Variant = (out.get(PARAMS_KEY, {}) as Dictionary).get(Timing.PROGRESS, null) if out.get(PARAMS_KEY) is Dictionary else null
	out.erase(PARAMS_KEY)
	out.erase(LIB_KEY)
	if has(id) or not is_classic(id):
		out[LIB_KEY] = true
		out[PARAMS_KEY] = default_params(id)
	if keep is Dictionary:
		if not (out.get(PARAMS_KEY) is Dictionary):
			out[PARAMS_KEY] = {}
		(out[PARAMS_KEY] as Dictionary)[Timing.PROGRESS] = (keep as Dictionary).duplicate(true)
	return Timing.with_progress(out)


func values_at(id: String, tr: Dictionary, span_t: float, span_dur: float, fps: float) -> Dictionary:
	var out: Dictionary = {}
	var params: Variant = tr.get(PARAMS_KEY, {})
	var have: Dictionary = params if params is Dictionary else {}
	for p: Variant in get_def(id).get("params", []):
		var pd: Dictionary = p
		var key: String = String(pd["key"])
		var raw: Variant = have.get(key, null)
		if raw is Dictionary and ((raw as Dictionary).has("v") or (raw as Dictionary).has("a")):
			out[key] = AnimProp.evaluate(raw, span_t, span_dur, fps)
		elif raw != null and not (raw is Dictionary):
			out[key] = raw
		else:
			out[key] = pd["default"]
	return out


static func shader_value(v: Variant, type: int) -> Variant:
	if type == TYPE_COLOR:
		if v is Array and (v as Array).size() >= 3:
			var a: Array = v
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
		if v is Color:
			return v
		return Color.BLACK
	if type == TYPE_VECTOR4:
		if v is Array and (v as Array).size() >= 4:
			return Vector4(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		if v is Color:
			var c: Color = v
			return Vector4(c.r, c.g, c.b, c.a)
		return Vector4.ZERO
	if type == TYPE_VECTOR2:
		if v is Array and (v as Array).size() >= 2:
			return Vector2(float(v[0]), float(v[1]))
		return v if v is Vector2 else Vector2.ZERO
	if type == TYPE_VECTOR3:
		if v is Array and (v as Array).size() >= 3:
			return Vector3(float(v[0]), float(v[1]), float(v[2]))
		return v if v is Vector3 else Vector3.ZERO
	if type == TYPE_INT:
		if v is bool:
			return 1 if bool(v) else 0
		return int(round(float(v))) if (v is float or v is int) else 0
	if type == TYPE_BOOL:
		if v is float or v is int:
			return float(v) != 0.0
		return bool(v) if v is bool else false
	if type == TYPE_FLOAT:
		if v is bool:
			return 1.0 if bool(v) else 0.0
		return float(v) if (v is float or v is int) else 0.0
	return v


func default_kind() -> String:
	var prefs: Node = _prefs()
	if prefs != null and bool(prefs.call("is_registered", PREF_DEFAULT)):
		var k: String = String(prefs.call("get_value", PREF_DEFAULT))
		if has(k) or classic_ids().has(k):
			return k
	return CLASSIC_DEFAULT


func set_default_kind(id: String) -> bool:
	if not has(id) and not classic_ids().has(id):
		return false
	var prefs: Node = _prefs()
	if prefs == null:
		return false
	ensure_prefs()
	prefs.call("set_value", PREF_DEFAULT, id)
	return true


func ensure_prefs() -> void:
	var prefs: Node = _prefs()
	if prefs == null or bool(prefs.call("is_registered", PREF_DEFAULT)):
		return
	prefs.call("register", PREF_DEFAULT, CLASSIC_DEFAULT, {"label": "Default video transition (its id, set from the Transitions panel)", "type": "string"})


func default_spec(clip_duration: float) -> Dictionary:
	var kind: String = default_kind()
	var spec: Dictionary = {"kind": kind, "duration": minf(DEFAULT_DURATION, clip_duration * 0.5), "align": "centre"}
	if has(kind):
		spec[LIB_KEY] = true
		spec[PARAMS_KEY] = default_params(kind)
	return Timing.with_progress(spec)


func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


func _note(text: String, detail: String, as_error: bool) -> void:
	var key: String = text + "|" + detail
	if _noted.has(key):
		return
	_noted[key] = true
	var loop: MainLoop = Engine.get_main_loop()
	var events: Node = (loop as SceneTree).root.get_node_or_null("Events") if loop is SceneTree else null
	if events != null:
		events.call("error" if as_error else "warn", text, detail)
	else:
		print("transitions: ", text, " (", detail, ")")


func noted() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in _noted.keys():
		out.append(String(k))
	return out
