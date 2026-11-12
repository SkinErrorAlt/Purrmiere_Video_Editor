extends RefCounted

signal changed

const Io := preload("res://doc/io.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const FrameCanvas := preload("res://engine/frame_canvas.gd")
const ShaderConvert := preload("res://engine/gdshader_convert.gd")
const OFFICIAL_ROOT := "res://effects/"
const MODULES_ROOT := "res://modules/"
const DEF_FILE := "effect.json"
const SINGLE_SHADER := "effect.gdshader"
const ENGINE_UNIFORMS: PackedStringArray = ["tex_size", "seq_size", "time", "clip_time", "clip_duration", "source_tex", "layer_tex", "effect_tex", "px_scale", "pass_scale", "mask_tex", "screen_tex", "spill_out", "TEXTURE", "pm_compile_probe", "history_tex", "history_layer", "history_count", "history_fps"]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "enum", "vec2", "vec3", "color", "texture", "layer", "curve", "string", "sound"]
const AUDIO_REACT := "res://engine/audio_react.gd"
const PROBE_LINE := "\nuniform float pm_compile_probe = 0.0;\n"
const CURVE_WIDTH := 256
const CURVE_CACHE_MAX := 64

static var _shared: RefCounted = null
static var _curve_cache: Dictionary = {}
static var _memory: Dictionary = {}

var _defs: Dictionary = {}
var _shaders: Dictionary = {}
var _shader_ok: Dictionary = {}
var _shader_why: Dictionary = {}
var _broken: Array[Dictionary] = []
var _loaded: bool = false
var _embedded: Dictionary = {}
var _embedded_shown: Dictionary = {}


static func shared() -> RefCounted:
	if _shared == null:
		var script: GDScript = load("res://engine/effect_registry.gd")
		_shared = script.new()
		_shared.call("load_all")
	return _shared


static func _read_text(path: String) -> String:
	if _memory.has(path):
		return String(_memory[path])
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func _list_dir(root: String) -> Dictionary:
	var dirs: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return {"dirs": dirs, "files": files}
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			if dir.current_is_dir():
				dirs.append(entry)
			else:
				files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	dirs.sort()
	files.sort()
	return {"dirs": dirs, "files": files}


func is_loaded() -> bool:
	return _loaded


static func user_root() -> String:
	return Io.data_path("effects") + "/"


static func folder_stamp(root: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full: String = root + entry
			parts.append(entry + ":" + str(FileAccess.get_modified_time(full)))
			if dir.current_is_dir():
				var inner: DirAccess = DirAccess.open(full)
				if inner != null:
					inner.list_dir_begin()
					var f: String = inner.get_next()
					while not f.is_empty():
						parts.append(entry + "/" + f + ":" + str(FileAccess.get_modified_time(full + "/" + f)))
						f = inner.get_next()
					inner.list_dir_end()
		entry = dir.get_next()
	dir.list_dir_end()
	parts.sort()
	return "|".join(parts)


static func user_stamp() -> String:
	return folder_stamp(user_root())


func load_all() -> void:
	_defs = {}
	_broken = []
	_scan_root(OFFICIAL_ROOT, "official")
	var mods: Dictionary = _list_dir(MODULES_ROOT)
	for m: String in mods["dirs"]:
		_scan_root(MODULES_ROOT + m + "/effects/", "module")
	var extras: GDScript = load("res://host/module_extras.gd")
	for extra_root: String in (extras.call("shared") as Object).call("effect_paths"):
		_scan_root(extra_root, "module")
	_scan_root(user_root(), "user")
	_scan_loose_shaders(user_root())
	_merge_embedded()
	_loaded = true
	for b: Dictionary in _broken:
		_report_broken(b)
	changed.emit()


func reload() -> void:
	_shaders = {}
	_shader_ok = {}
	load_all()


func add_embedded(id: String, code: String, raw: Dictionary) -> Dictionary:
	if not _valid_id(id) or code.is_empty():
		return {}
	var folder: String = "mem://" + id + "/" + code.sha256_text().substr(0, 12) + "/"
	_memory[folder + SINGLE_SHADER] = code
	var full: Dictionary = raw.duplicate(true)
	full["id"] = id
	full["passes"] = [{"shader": SINGLE_SHADER}]
	var def: Dictionary = _normalise(full, folder, id, "project")
	if def.is_empty():
		return {}
	def["embedded"] = true
	_embedded[id] = def
	if not _defs.has(id) or bool((_defs[id] as Dictionary).get("embedded", false)):
		_defs[id] = def
	return def


func _merge_embedded() -> void:
	for id: Variant in _embedded.keys():
		if not _defs.has(id):
			_defs[id] = _embedded[id]


func set_embedded_shown(ids: PackedStringArray) -> void:
	_embedded_shown = {}
	for id: String in ids:
		_embedded_shown[id] = true


func is_embedded(id: String) -> bool:
	return _defs.has(id) and bool((_defs[id] as Dictionary).get("embedded", false))


func _report_broken(b: Dictionary) -> void:
	var events: Node = _events()
	if events != null:
		events.error("An effect definition is broken: " + String(b["reason"]), String(b["path"]))
	else:
		print("effect_registry: ", String(b["reason"]), " at ", String(b["path"]))


func _events() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Events")
	return null


func _scan_root(root: String, source: String) -> void:
	var listing: Dictionary = _list_dir(root)
	for folder: String in listing["dirs"]:
		if folder.begins_with("_"):
			continue
		var path: String = root + folder + "/"
		var def_path: String = path + DEF_FILE
		var def: Dictionary = {}
		if FileAccess.file_exists(def_path):
			var parsed: Variant = JSON.parse_string(_read_text(def_path))
			if typeof(parsed) != TYPE_DICTIONARY:
				_broken.append({"path": def_path, "reason": "effect.json is not a JSON object"})
				continue
			def = _normalise(parsed, path, folder, source)
		elif FileAccess.file_exists(path + SINGLE_SHADER):
			def = _normalise({"id": folder, "passes": "single"}, path, folder, source)
		else:
			continue
		if def.is_empty():
			continue
		var id: String = String(def["id"])
		if _defs.has(id):
			_broken.append({"path": path, "reason": "the effect id \"" + id + "\" is already used by " + String(_defs[id]["path"])})
			continue
		_defs[id] = def


func _scan_loose_shaders(root: String) -> void:
	var listing: Dictionary = _list_dir(root)
	for f: String in listing["files"]:
		if f.get_extension() != "gdshader":
			continue
		var id: String = f.get_basename().to_lower()
		var def: Dictionary = _normalise({"id": id, "label": f.get_basename().capitalize(), "category": "User", "passes": "single", "single_file": f}, root, id, "user")
		if def.is_empty():
			continue
		if _defs.has(id):
			_broken.append({"path": root + f, "reason": "the effect id \"" + id + "\" is already used by " + String(_defs[id]["path"])})
			continue
		_defs[id] = def


static func clean_tags(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_STRING:
		var one: String = String(raw).strip_edges().to_lower()
		if not one.is_empty():
			out.append(one)
		return out
	if typeof(raw) != TYPE_ARRAY and typeof(raw) != TYPE_PACKED_STRING_ARRAY:
		return out
	for t: Variant in raw:
		var tag: String = str(t).strip_edges().to_lower()
		if tag.is_empty() or out.has(tag):
			continue
		out.append(tag)
	out.sort()
	return out


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for ch: String in id:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789_"):
			return false
	return true


func _normalise(raw: Dictionary, folder: String, fallback_id: String, source: String) -> Dictionary:
	var id: String = String(raw.get("id", fallback_id)).strip_edges().to_lower()
	if not _valid_id(id):
		_broken.append({"path": folder, "reason": "the effect id \"" + id + "\" has characters outside a-z, 0-9 and _"})
		return {}
	var def: Dictionary = {
		"id": id,
		"label": String(raw.get("label", id.capitalize())),
		"category": String(raw.get("category", "User" if source == "user" else "Other")),
		"version": int(raw.get("version", 1)),
		"blurb": String(raw.get("blurb", "")),
		"params": [],
		"passes": [],
		"path": folder,
		"source": source,
		"ok": true,
		"pairs_with": PackedStringArray(),
		"tags": PackedStringArray(),
	}
	def["tags"] = clean_tags(raw.get("tags", []))
	var raw_pairs: Variant = raw.get("pairs_with", [])
	if typeof(raw_pairs) == TYPE_ARRAY:
		var pairs: PackedStringArray = PackedStringArray()
		for pw: Variant in raw_pairs:
			pairs.append(String(pw))
		def["pairs_with"] = pairs
	if typeof(raw.get("handles", null)) == TYPE_ARRAY:
		def["handles"] = (raw["handles"] as Array).duplicate(true)
	if typeof(raw.get("depth", null)) == TYPE_DICTIONARY:
		def["depth"] = (raw["depth"] as Dictionary).duplicate(true)
	if typeof(raw.get("panels", null)) == TYPE_ARRAY:
		def["panels"] = (raw["panels"] as Array).duplicate(true)
	if typeof(raw.get("history", null)) == TYPE_DICTIONARY:
		def["history"] = (raw["history"] as Dictionary).duplicate(true)
	if typeof(raw.get("applies_to", null)) == TYPE_STRING:
		def["applies_to"] = String(raw["applies_to"])
		def["text_transform"] = String(raw.get("text_transform", ""))
	FrameCanvas.note(def, raw)
	var raw_passes: Variant = raw.get("passes", [])
	var passes: Array = []
	var discovered: Array = []
	if typeof(raw_passes) == TYPE_STRING and String(raw_passes) == "single":
		var shader_file: String = String(raw.get("single_file", SINGLE_SHADER))
		var shader_path: String = folder + shader_file
		if not FileAccess.file_exists(shader_path):
			_broken.append({"path": shader_path, "reason": "the single pass shader file is missing"})
			return {}
		passes.append({"shader": shader_path, "scale": 1.0, "input": "prev", "inputs": {}, "repeat": {}, "when": {}, "set": {}, "map": {}})
		discovered = discover_params(_read_text(shader_path))
	elif typeof(raw_passes) == TYPE_ARRAY:
		for p: Variant in raw_passes:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var pd: Dictionary = p
			var shader_name: String = String(pd.get("shader", ""))
			if shader_name.is_empty():
				_broken.append({"path": folder, "reason": "a pass has no shader file"})
				return {}
			var shader_path: String = shader_name if shader_name.begins_with("res://") or shader_name.begins_with("user://") else folder + shader_name
			if not FileAccess.file_exists(shader_path) and not _memory.has(shader_path):
				_broken.append({"path": shader_path, "reason": "a pass shader file is missing"})
				return {}
			var sets: Dictionary = {}
			var raw_sets: Variant = pd.get("set", {})
			if typeof(raw_sets) == TYPE_DICTIONARY:
				for k: Variant in (raw_sets as Dictionary).keys():
					sets[String(k)] = raw_sets[k]
			var maps: Dictionary = {}
			var raw_maps: Variant = pd.get("map", {})
			if typeof(raw_maps) == TYPE_DICTIONARY:
				for k: Variant in (raw_maps as Dictionary).keys():
					maps[String(k)] = String(raw_maps[k])
			var inputs: Dictionary = {}
			var raw_inputs: Variant = pd.get("inputs", {})
			if typeof(raw_inputs) == TYPE_DICTIONARY:
				for k: Variant in (raw_inputs as Dictionary).keys():
					inputs[String(k)] = int(raw_inputs[k])
			passes.append({
				"shader": shader_path,
				"scale": float(pd.get("scale", 1.0)),
				"input": String(pd.get("input", "prev")),
				"inputs": inputs,
				"repeat": pd.get("repeat", {}) if typeof(pd.get("repeat", {})) == TYPE_DICTIONARY else {},
				"when": pd.get("when", {}) if typeof(pd.get("when", {})) == TYPE_DICTIONARY else {},
				"set": sets,
				"map": maps,
			})
	else:
		_broken.append({"path": folder, "reason": "passes must be a list or \"single\""})
		return {}
	var params: Array = []
	var raw_params: Variant = raw.get("params", [])
	if raw.get("reactive") is Dictionary:
		def["reactive"] = (raw["reactive"] as Dictionary).duplicate(true)
		raw_params = load(AUDIO_REACT).call("wrap_params", raw_params, (raw["reactive"] as Dictionary).get("defaults", {}), raw["reactive"])
	if typeof(raw_params) == TYPE_ARRAY:
		for p: Variant in raw_params:
			if typeof(p) == TYPE_DICTIONARY:
				var np: Dictionary = _normalise_param(p)
				if not np.is_empty():
					params.append(np)
	var seen: Dictionary = {}
	for p: Dictionary in params:
		seen[String(p["key"])] = true
	var masked: PackedStringArray = PackedStringArray()
	var raw_masked: Variant = raw.get("hidden_uniforms", [])
	if typeof(raw_masked) == TYPE_ARRAY:
		for pat: Variant in raw_masked:
			if typeof(pat) == TYPE_STRING:
				masked.append(String(pat))
	for dp: Dictionary in discovered:
		if not seen.has(String(dp["key"])):
			if _uniform_masked(String(dp["key"]), masked):
				dp["hidden"] = true
				dp["keyable"] = false
			params.append(dp)
	def["params"] = params
	def["passes"] = passes
	return def


static func _uniform_masked(key: String, patterns: PackedStringArray) -> bool:
	for pat: String in patterns:
		if key == pat or key.match(pat):
			return true
	return false


static func _normalise_param(p: Dictionary) -> Dictionary:
	var key: String = String(p.get("key", "")).strip_edges()
	if key.is_empty():
		return {}
	var type: String = String(p.get("type", "float"))
	if type == "colour":
		type = "color"
	if not PARAM_TYPES.has(type):
		type = "float"
	var out: Dictionary = {
		"key": key,
		"label": String(p.get("label", key.capitalize())),
		"type": type,
		"min": float(p.get("min", 0.0)),
		"max": float(p.get("max", 1.0)),
		"step": float(p.get("step", 0.01)),
		"default": _default_for(type, p.get("default", null)),
		"choices": [],
		"writes": {},
		"keyable": bool(p.get("keyable", true)) and type != "texture" and type != "layer" and (type != "string" or p.get("keyable") == true) and type != "curve" and type != "sound",
		"unit": String(p.get("unit", "")),
		"hidden": bool(p.get("hidden", false)),
		"group": String(p.get("group", "")),
	}
	if type == "enum":
		var ch: Array = []
		for c: Variant in p.get("choices", []):
			ch.append(String(c))
		out["choices"] = ch
		out["max"] = float(maxi(ch.size() - 1, 0))
		out["step"] = 1.0
	if type == "int":
		out["step"] = maxf(1.0, float(p.get("step", 1.0)))
	if p.get("writes") is Dictionary:
		out["writes"] = (p["writes"] as Dictionary).duplicate(true)
	return out


static func _default_for(type: String, v: Variant) -> Variant:
	if type == "bool":
		return bool(v) if v != null else false
	if type == "int" or type == "enum":
		return float(int(v)) if v != null else 0.0
	if type == "vec2":
		if v is Array and (v as Array).size() >= 2:
			return [float(v[0]), float(v[1])]
		return [0.0, 0.0]
	if type == "vec3":
		if v is Array and (v as Array).size() >= 3:
			return [float(v[0]), float(v[1]), float(v[2])]
		return [0.0, 0.0, 0.0]
	if type == "color":
		if v is Array and (v as Array).size() >= 3:
			var a: float = float(v[3]) if (v as Array).size() >= 4 else 1.0
			return [float(v[0]), float(v[1]), float(v[2]), a]
		return [1.0, 1.0, 1.0, 1.0]
	if type == "curve":
		if v is Dictionary and (v as Dictionary).get("points") is Array:
			return (v as Dictionary).duplicate(true)
		return {"points": [[0.0, 0.0], [1.0, 1.0]]}
	if type == "texture" or type == "layer" or type == "string" or type == "sound":
		return String(v) if v != null else ""
	if v == null:
		return 0.0
	return float(v)


static func discover_params(code: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("uniform\\s+(float|int|bool|vec2|vec3|vec4|sampler2D)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([^;=]*))?(?:=\\s*([^;]*))?;")
	for m: RegExMatch in re.search_all(code):
		var gtype: String = m.get_string(1)
		var name: String = m.get_string(2)
		if ENGINE_UNIFORMS.has(name):
			continue
		var hints: String = m.get_string(3).strip_edges()
		var default_text: String = m.get_string(4).strip_edges()
		var p: Dictionary = {"key": name, "label": name.capitalize(), "type": "float", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.0, "choices": [], "writes": {}, "keyable": true, "unit": ""}
		if gtype == "float":
			p["min"] = -100.0
			p["max"] = 100.0
			p["step"] = 0.01
		elif gtype == "int":
			p["type"] = "int"
			p["min"] = -100.0
			p["max"] = 100.0
			p["step"] = 1.0
		elif gtype == "bool":
			p["type"] = "bool"
			p["default"] = false
		elif gtype == "vec2":
			p["type"] = "vec2"
			p["default"] = [0.0, 0.0]
			p["min"] = -4096.0
			p["max"] = 4096.0
		elif gtype == "vec3":
			p["type"] = "vec3"
			p["default"] = [0.0, 0.0, 0.0]
		elif gtype == "vec4":
			p["type"] = "color"
			p["default"] = [1.0, 1.0, 1.0, 1.0]
		elif gtype == "sampler2D":
			if hints.contains("hint_screen_texture"):
				continue
			p["type"] = "texture"
			p["default"] = ""
			p["keyable"] = false
		if hints.contains("source_color"):
			p["type"] = "color"
			p["default"] = [1.0, 1.0, 1.0, 1.0]
		var hr := RegEx.new()
		hr.compile("hint_range\\(\\s*([-+0-9.eE]+)\\s*,\\s*([-+0-9.eE]+)\\s*(?:,\\s*([-+0-9.eE]+))?\\s*\\)")
		var hm: RegExMatch = hr.search(hints)
		if hm != null:
			p["min"] = float(hm.get_string(1))
			p["max"] = float(hm.get_string(2))
			if not hm.get_string(3).is_empty():
				p["step"] = float(hm.get_string(3))
			elif p["type"] == "float":
				p["step"] = 0.01
		if not default_text.is_empty():
			var parsed: Variant = _parse_default(gtype, default_text)
			if parsed != null:
				if p["type"] == "color" and parsed is Array and (parsed as Array).size() == 4:
					p["default"] = parsed
				elif p["type"] == "vec2" or p["type"] == "vec3":
					p["default"] = parsed
				elif p["type"] == "bool":
					p["default"] = bool(parsed)
				elif parsed is float:
					p["default"] = parsed
		out.append(p)
	return out


static func _parse_default(gtype: String, text: String) -> Variant:
	var t: String = text.strip_edges()
	if gtype == "bool":
		return t == "true"
	if gtype == "float" or gtype == "int":
		var clean: String = t.trim_suffix("f")
		if clean.is_valid_float():
			return float(clean)
		return null
	var open: int = t.find("(")
	var close: int = t.rfind(")")
	if open < 0 or close < open:
		return null
	var inner: String = t.substr(open + 1, close - open - 1)
	var parts: PackedStringArray = inner.split(",")
	var nums: Array = []
	for part: String in parts:
		var s: String = part.strip_edges().trim_suffix("f")
		if s.is_valid_float():
			nums.append(float(s))
	var want: int = 2 if gtype == "vec2" else (3 if gtype == "vec3" else 4)
	if nums.size() == 1:
		var filled: Array = []
		for _i: int in want:
			filled.append(nums[0])
		return filled
	if nums.size() == want:
		return nums
	if gtype == "vec4" and nums.size() == 3:
		nums.append(1.0)
		return nums
	return null


func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _defs.keys():
		if bool((_defs[id] as Dictionary).get("embedded", false)) and not _embedded_shown.has(id):
			continue
		out.append(_defs[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["category"]) == String(b["category"]):
			return String(a["label"]) < String(b["label"])
		return String(a["category"]) < String(b["category"]))
	return out


func tags_of(id: String) -> PackedStringArray:
	var def: Dictionary = get_def(id)
	var raw: Variant = def.get("tags", null)
	if raw is PackedStringArray:
		return raw
	return clean_tags(raw)


func has_tag(id: String, tag: String) -> bool:
	return tags_of(id).has(tag.strip_edges().to_lower())


func tags() -> PackedStringArray:
	var seen: Dictionary = {}
	for d: Dictionary in list():
		for t: String in clean_tags(d.get("tags", [])):
			seen[t] = true
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in seen.keys():
		out.append(String(k))
	out.sort()
	return out


func with_tag(tag: String) -> PackedStringArray:
	var want: String = tag.strip_edges().to_lower()
	var out: PackedStringArray = PackedStringArray()
	for d: Dictionary in list():
		if clean_tags(d.get("tags", [])).has(want):
			out.append(String(d.get("id", "")))
	return out


func categories() -> PackedStringArray:
	var seen: Dictionary = {}
	for d: Dictionary in list():
		seen[String(d["category"])] = true
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in seen.keys():
		out.append(String(k))
	out.sort()
	return out


func has(id: String) -> bool:
	return _defs.has(id)


func get_def(id: String) -> Dictionary:
	if _defs.has(id):
		return _defs[id]
	return {}


func broken() -> Array[Dictionary]:
	return _broken.duplicate()


func default_params(id: String) -> Dictionary:
	var out: Dictionary = {}
	var def: Dictionary = get_def(id)
	for p: Variant in def.get("params", []):
		var pd: Dictionary = p
		out[String(pd["key"])] = AnimProp.make(pd["default"])
	return out


func param_spec(id: String, key: String) -> Dictionary:
	var def: Dictionary = get_def(id)
	for p: Variant in def.get("params", []):
		if String((p as Dictionary)["key"]) == key:
			return p
	return {}


func enum_writes(id: String, key: String, index: int) -> Dictionary:
	var spec: Dictionary = param_spec(id, key)
	var writes: Dictionary = spec.get("writes", {})
	var by_index: Variant = writes.get(str(index), null)
	if typeof(by_index) == TYPE_DICTIONARY:
		return (by_index as Dictionary).duplicate(true)
	var choices: Array = spec.get("choices", [])
	if index >= 0 and index < choices.size():
		var by_name: Variant = writes.get(String(choices[index]), null)
		if typeof(by_name) == TYPE_DICTIONARY:
			return (by_name as Dictionary).duplicate(true)
	return {}


static func prepare_code(code: String) -> String:
	var out: String = code
	var has_blend: bool = false
	var rm := RegEx.new()
	rm.compile("render_mode\\s+[^;]*blend_[a-z_]+")
	if rm.search(out) != null:
		has_blend = true
	if not has_blend:
		var st := RegEx.new()
		st.compile("shader_type\\s+canvas_item\\s*;")
		var m: RegExMatch = st.search(out)
		if m != null:
			out = out.substr(0, m.get_end()) + "\nrender_mode blend_disabled;" + out.substr(m.get_end())
	return out


func shader_for(path: String) -> Shader:
	if _shaders.has(path):
		return _shaders[path]
	var code: String = _read_text(path)
	var ok: bool = true
	var reason: String = ""
	if code.is_empty():
		ok = false
		reason = "the shader file is empty or missing"
	elif not code.contains("canvas_item"):
		ok = false
		reason = "the shader must be a canvas_item shader"
	var sh: Shader = null
	if ok:
		sh = Shader.new()
		var prepared: String = prepare_code(code)
		var caught: Dictionary = ShaderConvert.caught_uniforms(sh, prepared + PROBE_LINE)
		var found: bool = false
		for u: Dictionary in caught["uniforms"]:
			if String(u.get("name", "")) == "pm_compile_probe":
				found = true
				break
		if not found:
			ok = false
			var said: String = ShaderConvert.compiler_text_for(caught["errors"], code, prepared)
			reason = "the shader did not compile, " + (said if not said.is_empty() else "the compiler gave no message")
			sh = null
	_shaders[path] = sh
	_shader_ok[path] = ok
	_shader_why[path] = reason
	if not ok:
		var events: Node = _events()
		if events != null:
			events.error("A shader pass failed and its effect is disabled: " + reason, path)
		else:
			print("effect_registry: ", reason, " at ", path)
	return sh


func shader_reason(path: String) -> String:
	if not _shader_ok.has(path):
		shader_for(path)
	return String(_shader_why.get(path, ""))


func shader_ok(path: String) -> bool:
	if not _shader_ok.has(path):
		shader_for(path)
	return bool(_shader_ok.get(path, false))


func make_material(id: String, pass_index: int) -> ShaderMaterial:
	var def: Dictionary = get_def(id)
	var passes: Array = def.get("passes", [])
	if pass_index < 0 or pass_index >= passes.size():
		return null
	var sh: Shader = shader_for(String(passes[pass_index]["shader"]))
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func float_shader_for(path: String) -> Shader:
	var key: String = path + "#float"
	if _shaders.has(key):
		return _shaders[key]
	var sh: Shader = null
	if shader_for(path) != null:
		var FloatPasses: GDScript = load("res://engine/float_passes.gd")
		sh = Shader.new()
		var caught: Dictionary = ShaderConvert.caught_uniforms(sh, String(FloatPasses.call("float_code", prepare_code(_read_text(path)))) + PROBE_LINE)
		var found: bool = false
		for u: Dictionary in caught["uniforms"]:
			if String(u.get("name", "")) == "pm_compile_probe":
				found = true
				break
		if not found:
			sh = null
	_shaders[key] = sh
	return sh


func make_float_material(id: String, pass_index: int) -> ShaderMaterial:
	var passes: Array = get_def(id).get("passes", [])
	if pass_index < 0 or pass_index >= passes.size():
		return null
	var sh: Shader = float_shader_for(String(passes[pass_index]["shader"]))
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func uniform_types(id: String, pass_index: int) -> Dictionary:
	var out: Dictionary = {}
	var def: Dictionary = get_def(id)
	var passes: Array = def.get("passes", [])
	if pass_index < 0 or pass_index >= passes.size():
		return out
	var sh: Shader = shader_for(String(passes[pass_index]["shader"]))
	if sh == null:
		return out
	for u: Dictionary in sh.get_shader_uniform_list(true):
		out[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	return out


static func curve_texture(points: Variant) -> ImageTexture:
	var pts: Array = []
	if points is Dictionary and (points as Dictionary).get("points") is Array:
		pts = (points as Dictionary)["points"]
	elif points is Array:
		pts = points
	var key: String = str(pts)
	if _curve_cache.has(key):
		return _curve_cache[key]
	var clean: Array = []
	for p: Variant in pts:
		if p is Array and (p as Array).size() >= 2:
			clean.append(Vector2(clampf(float(p[0]), 0.0, 1.0), clampf(float(p[1]), 0.0, 1.0)))
	if clean.is_empty():
		clean = [Vector2(0.0, 0.0), Vector2(1.0, 1.0)]
	clean.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var img: Image = Image.create(CURVE_WIDTH, 1, false, Image.FORMAT_RGBA8)
	for i: int in CURVE_WIDTH:
		var x: float = float(i) / float(CURVE_WIDTH - 1)
		var y: float = _curve_eval(clean, x)
		img.set_pixel(i, 0, Color(y, y, y, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if _curve_cache.size() >= CURVE_CACHE_MAX:
		_curve_cache = {}
	_curve_cache[key] = tex
	return tex


static func _curve_eval(pts: Array, x: float) -> float:
	var n: int = pts.size()
	if n == 1:
		return (pts[0] as Vector2).y
	if x <= (pts[0] as Vector2).x:
		return (pts[0] as Vector2).y
	if x >= (pts[n - 1] as Vector2).x:
		return (pts[n - 1] as Vector2).y
	var i: int = 0
	while i < n - 2 and x > (pts[i + 1] as Vector2).x:
		i += 1
	var p1: Vector2 = pts[i]
	var p2: Vector2 = pts[i + 1]
	var p0: Vector2 = pts[i - 1] if i > 0 else p1 + (p1 - p2)
	var p3: Vector2 = pts[i + 2] if i + 2 < n else p2 + (p2 - p1)
	var span: float = p2.x - p1.x
	if span <= 0.0:
		return p1.y
	var u: float = (x - p1.x) / span
	var m1: float = (p2.y - p0.y) / maxf(p2.x - p0.x, 0.0001) * span
	var m2: float = (p3.y - p1.y) / maxf(p3.x - p1.x, 0.0001) * span
	var u2: float = u * u
	var u3: float = u2 * u
	var y: float = (2.0 * u3 - 3.0 * u2 + 1.0) * p1.y + (u3 - 2.0 * u2 + u) * m1 + (-2.0 * u3 + 3.0 * u2) * p2.y + (u3 - u2) * m2
	return clampf(y, 0.0, 1.0)
