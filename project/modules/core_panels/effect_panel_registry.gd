extends RefCounted

const MODULES_ROOT := "res://modules/"
const FOLDER := "effect_panels"
const BASE_PATH := "res://modules/core_panels/effect_panel_kind.gd"

static var _kinds: Dictionary = {}
static var _paths: Dictionary = {}
static var _scanned: bool = false
static var extra_roots: PackedStringArray = PackedStringArray()
static var plant_skip_check: bool = false


static func folders() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var da: DirAccess = DirAccess.open(MODULES_ROOT)
	if da != null:
		var mods: PackedStringArray = da.get_directories()
		mods.sort()
		if mods.has("core_panels"):
			mods.remove_at(mods.find("core_panels"))
			mods.insert(0, "core_panels")
		for m: String in mods:
			var dir: String = MODULES_ROOT + m + "/" + FOLDER + "/"
			if DirAccess.dir_exists_absolute(dir):
				out.append(dir)
	for r: String in extra_roots:
		out.append(r if r.ends_with("/") else r + "/")
	return out


static func _scripts_in(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return out
	for f: String in da.get_files():
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".gd") and not name.begins_with("_") and not out.has(dir + name):
			out.append(dir + name)
	out.sort()
	return out


static func rescan() -> void:
	_kinds = {}
	_paths = {}
	_scanned = true
	var base: Variant = load(BASE_PATH)
	for dir: String in folders():
		for path: String in _scripts_in(dir):
			var id: String = path.get_file().get_basename()
			if _kinds.has(id):
				continue
			var sc: Variant = load(path)
			if not (sc is GDScript) or not (sc as GDScript).can_instantiate():
				continue
			if not _extends(sc as GDScript, base):
				continue
			_kinds[id] = sc
			_paths[id] = path


static func _extends(sc: GDScript, base: Variant) -> bool:
	var at: Script = sc
	while at != null:
		if at == base:
			return true
		at = at.get_base_script()
	return false


static func kinds() -> Dictionary:
	if not _scanned:
		rescan()
	return _kinds


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(kinds().keys())
	out.sort()
	return out


static func has(id: String) -> bool:
	return kinds().has(id)


static func path_of(id: String) -> String:
	kinds()
	return String(_paths.get(id, ""))


static func make(id: String) -> RefCounted:
	var sc: Variant = kinds().get(id, null)
	if not (sc is GDScript):
		return null
	var inst: Variant = (sc as GDScript).new()
	return inst if inst is RefCounted else null


static func _params_by_key(def: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in def.get("params", []):
		if p is Dictionary:
			out[String((p as Dictionary).get("key", ""))] = p
	return out


## Checks one declaration against the effect's params. Returns
## {"ok": bool, "kind": String, "bind": role -> key (only the good ones),
##  "options": Dictionary, "problems": PackedStringArray}.
static func check(decl: Variant, def: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "kind": "", "bind": {}, "options": {}, "problems": PackedStringArray()}
	var problems: PackedStringArray = out["problems"]
	var who: String = String(def.get("id", "?"))
	if not (decl is Dictionary):
		problems.append(who + ": a panel declaration is not an object")
		return out
	var d: Dictionary = decl
	var kind_id: String = String(d.get("kind", ""))
	out["kind"] = kind_id
	if not has(kind_id):
		problems.append(who + ": there is no panel kind called \"" + kind_id + "\"")
		return out
	var inst: RefCounted = make(kind_id)
	var roles: Dictionary = inst.call("roles") if inst != null else {}
	var params: Dictionary = _params_by_key(def)
	var raw_bind: Variant = d.get("bind", {})
	if not (raw_bind is Dictionary):
		problems.append(who + ": the " + kind_id + " panel's bind is not an object")
		raw_bind = {}
	var bind: Dictionary = {}
	for r: Variant in (raw_bind as Dictionary).keys():
		var role_name: String = String(r)
		var key: String = String((raw_bind as Dictionary)[r])
		if not roles.has(role_name):
			problems.append(who + ": the " + kind_id + " panel has no role \"" + role_name + "\"")
			continue
		if not params.has(key):
			problems.append(who + ": the " + kind_id + " panel binds " + role_name + " to \"" + key + "\", which the effect does not have")
			continue
		var types: PackedStringArray = (roles[role_name] as Dictionary).get("types", PackedStringArray(["float", "int"]))
		var ptype: String = String((params[key] as Dictionary).get("type", "float"))
		if not types.has(ptype):
			problems.append(who + ": the " + kind_id + " panel's " + role_name + " wants " + "/".join(types) + " but \"" + key + "\" is " + ptype)
			continue
		bind[role_name] = key
	for r2: Variant in roles.keys():
		if bool((roles[r2] as Dictionary).get("need", false)) and not bind.has(String(r2)):
			problems.append(who + ": the " + kind_id + " panel needs its " + String(r2) + " role bound")
	var opts: Variant = d.get("options", {})
	out["options"] = (opts as Dictionary).duplicate(true) if opts is Dictionary else {}
	out["bind"] = bind
	var need_ok: bool = true
	for r3: Variant in roles.keys():
		if bool((roles[r3] as Dictionary).get("need", false)) and not bind.has(String(r3)):
			need_ok = false
	out["ok"] = need_ok and not bind.is_empty()
	return out


## The panels an effect shows: only declarations that passed, with bad roles dropped.
static func panels_of(def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = def.get("panels", null)
	if not (raw is Array):
		return out
	for decl: Variant in raw:
		var r: Dictionary = check(decl, def)
		if plant_skip_check and decl is Dictionary:
			r["ok"] = true
			r["bind"] = ((decl as Dictionary).get("bind", {}) as Dictionary).duplicate() if (decl as Dictionary).get("bind") is Dictionary else {}
		if bool(r["ok"]) and (not plant_skip_check or has(String(r["kind"]))):
			out.append(r)
	return out


static func problems_of(def: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = def.get("panels", null)
	if raw == null:
		return out
	if not (raw is Array):
		out.append(String(def.get("id", "?")) + ": \"panels\" is not a list")
		return out
	for decl: Variant in raw:
		out.append_array(check(decl, def)["problems"] as PackedStringArray)
	return out
