extends Node

signal registry_changed(iface: String)
signal modules_changed

const ModuleLoader := preload("res://host/module_loader.gd")
const ModuleExtras := preload("res://host/module_extras.gd")
const IFACES: PackedStringArray = ["IPanel", "ITool", "IExporter", "ITimelineView", "IBinView", "IMonitor", "IKeymap", "ILayout", "ITheme", "IPresetKind", "ITrackKind", "IEffect", "ITransition", "IAudioEffect", "IInterpolator", "IGenerator", "ICommandSet", "IRenderScheduler"]

var version: String = "0.2.0"
var _registry: Dictionary = {}
var _loader: RefCounted = ModuleLoader.new()
var _current_module: String = ""
var _module_items: Dictionary = {}
var _loaded: bool = false
var _repaired: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for iface: String in IFACES:
		_registry[iface] = {}


func register(iface: String, id: String, impl: Object, meta: Dictionary = {}) -> void:
	if iface.is_empty() or id.is_empty() or impl == null:
		print("Host: refused a registration with an empty interface, id or object")
		return
	if not _registry.has(iface):
		_registry[iface] = {}
	var table: Dictionary = _registry[iface]
	if table.has(id):
		var old: Dictionary = table[id]
		var old_owner: String = String(old["meta"].get("module", ""))
		if old_owner != _current_module:
			print("Host: ", iface, " \"", id, "\" is already registered by ", old_owner if not old_owner.is_empty() else "the app", ", the new one was refused")
			return
	var m: Dictionary = meta.duplicate()
	m["module"] = _current_module
	table[id] = {"id": id, "impl": impl, "meta": m}
	if not _current_module.is_empty():
		if not _module_items.has(_current_module):
			_module_items[_current_module] = []
		(_module_items[_current_module] as Array).append({"iface": iface, "id": id})
	registry_changed.emit(iface)


func unregister(iface: String, id: String) -> void:
	if not _registry.has(iface):
		return
	var table: Dictionary = _registry[iface]
	if table.erase(id):
		registry_changed.emit(iface)


func get_impl(iface: String, id: String) -> Object:
	if not _registry.has(iface):
		return null
	var table: Dictionary = _registry[iface]
	if table.has(id):
		return table[id]["impl"]
	return null


func has_impl(iface: String, id: String) -> bool:
	return get_impl(iface, id) != null


func list(iface: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _registry.has(iface):
		return out
	var table: Dictionary = _registry[iface]
	var ids: Array = table.keys()
	ids.sort()
	for id: String in ids:
		out.append({"id": id, "impl": table[id]["impl"], "meta": table[id]["meta"]})
	return out


func default_impl(iface: String) -> Object:
	var entries: Array[Dictionary] = list(iface)
	if entries.is_empty():
		return null
	var prefs: Node = get_node_or_null("/root/Prefs")
	var key: String = "host.default." + iface
	if prefs != null:
		if not prefs.is_registered(key):
			prefs.register(key, "", {"label": "Default " + iface, "type": "string"})
		var wanted: String = String(prefs.get_value(key))
		if not wanted.is_empty():
			for e: Dictionary in entries:
				if String(e["id"]) == wanted:
					return e["impl"]
	return entries[0]["impl"]


func set_default(iface: String, id: String) -> void:
	var prefs: Node = get_node_or_null("/root/Prefs")
	var key: String = "host.default." + iface
	if prefs != null:
		if not prefs.is_registered(key):
			prefs.register(key, "", {"label": "Default " + iface, "type": "string"})
		prefs.set_value(key, id)
		registry_changed.emit(iface)


func interfaces() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in _registry.keys():
		out.append(k)
	out.sort()
	return out


func modules() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _loader.records:
		out.append({
			"id": r["id"],
			"label": r["label"],
			"kind": r["kind"],
			"version": r["version"],
			"state": r["state"],
			"reason": r["reason"],
			"path": r["path"],
			"official": r["official"],
			"core": bool(r.get("core", false)),
		})
	return out


func is_core(id: String) -> bool:
	var r: Dictionary = _loader.record_for(id)
	return not r.is_empty() and bool(r.get("core", false))


func repaired_core() -> PackedStringArray:
	return _repaired


func _repair_core(prefs: Node, r: Dictionary) -> bool:
	if not bool(r.get("core", false)):
		return false
	var key: String = _enabled_key(String(r["id"]))
	if bool(prefs.get_value(key)):
		return false
	prefs.set_value(key, true)
	_repaired.append(String(r["id"]))
	print("Host: the core module " + String(r["id"]) + " was turned off in the settings, it is back on")
	var events: Node = get_node_or_null("/root/Events")
	if events != null and events.has_method("info"):
		events.call("info", "Turned " + String(r["label"]) + " back on", "It is a core module, the editor needs it, so it cannot be turned off.")
	return true


func _watch_core_prefs(prefs: Node) -> void:
	if prefs.has_signal("changed") and not prefs.is_connected("changed", _on_core_pref_changed):
		prefs.connect("changed", _on_core_pref_changed)


func _on_core_pref_changed(key: String) -> void:
	if not key.begins_with("modules.enabled."):
		return
	var r: Dictionary = _loader.record_for(key.trim_prefix("modules.enabled."))
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null and not r.is_empty():
		_repair_core(prefs, r)


func module_state(id: String) -> String:
	var r: Dictionary = _loader.record_for(id)
	if r.is_empty():
		return "missing"
	return String(r["state"])


func _enabled_key(id: String) -> String:
	return "modules.enabled." + id


func _no_modules_flag() -> bool:
	for a: String in OS.get_cmdline_args():
		if a == "--no-modules":
			return true
	return false


func load_modules() -> void:
	if _loaded:
		for r: Dictionary in _loader.records:
			_loader.unload(r)
			_drop_module_items(String(r["id"]))
	_loaded = true
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null:
		_watch_core_prefs(prefs)
		if not bool(prefs.call("is_registered", ModuleLoader.DEV_FOLDER_PREF)):
			prefs.call("register", ModuleLoader.DEV_FOLDER_PREF, "", {"label": "Also load modules from this folder", "type": "string", "note": "For building a module: it runs straight from its own folder or repository, no copying. Several folders can be separated with ;. Use Reload Modules after changing its code."})
	var records: Array[Dictionary] = _loader.scan(_no_modules_flag())
	for r: Dictionary in records:
		if String(r["state"]) == "broken":
			continue
		var id: String = r["id"]
		var official: bool = r["official"]
		var enabled: bool = official
		if prefs != null:
			var key: String = _enabled_key(id)
			if not prefs.is_registered(key):
				prefs.register(key, official, {"label": "Module on: " + String(r["label"]), "type": "bool"})
			_repair_core(prefs, r)
			enabled = bool(prefs.get_value(key))
		if not enabled:
			r["state"] = "off"
			continue
		_activate(r)
	modules_changed.emit()


func _activate(r: Dictionary) -> void:
	var id: String = r["id"]
	_current_module = id
	if not bool(r["official"]):
		_add_folders(r)
	if String(r["kind"]) == "code":
		_loader.load_code(r, self)
	else:
		r["state"] = "on"
	_current_module = ""
	if String(r["state"]) != "on":
		_drop_module_items(id)


## A module's effects and transitions folders load with it, whatever its kind.
func _add_folders(r: Dictionary) -> void:
	var path: String = String(r["path"])
	var extras: RefCounted = ModuleExtras.shared()
	if DirAccess.dir_exists_absolute(path + "effects"):
		extras.call("add_effect_root", String(r["id"]), path + "effects")
		(load("res://engine/effect_registry.gd").call("shared") as Object).call("reload")
	if DirAccess.dir_exists_absolute(path + "transitions"):
		extras.call("add_transition_root", String(r["id"]), path + "transitions")
		(load("res://engine/transition_registry.gd").call("shared") as Object).call("reload")


## The loaded record of a module, with its api object, for the module card and suites.
func module_record(id: String) -> Dictionary:
	return _loader.record_for(id)


## Scans the installed and developer module folders again: new ones appear, ones that are on load fresh from
## disk. Purrmiere's own modules keep running untouched.
func reload_modules() -> void:
	if not _loaded:
		load_modules()
		return
	for r: Dictionary in _loader.records:
		if not bool(r["official"]):
			_loader.unload(r)
			_drop_module_items(String(r["id"]))
	var prefs: Node = get_node_or_null("/root/Prefs")
	for r2: Dictionary in _loader.rescan_others():
		if bool(r2["official"]) or String(r2["state"]) == "broken":
			continue
		var key: String = _enabled_key(String(r2["id"]))
		if prefs != null and not prefs.is_registered(key):
			prefs.register(key, false, {"label": "Module on: " + String(r2["label"]), "type": "bool"})
		if prefs != null and bool(prefs.get_value(key)):
			_activate(r2)
		else:
			r2["state"] = "off"
	modules_changed.emit()


func _drop_module_items(id: String) -> void:
	var dropped: PackedStringArray = ModuleExtras.shared().call("drop_owner", id)
	if dropped.has("effects"):
		(load("res://engine/effect_registry.gd").call("shared") as Object).call("reload")
	if dropped.has("transitions"):
		(load("res://engine/transition_registry.gd").call("shared") as Object).call("reload")
	if not _module_items.has(id):
		return
	for item: Dictionary in _module_items[id]:
		unregister(String(item["iface"]), String(item["id"]))
	_module_items.erase(id)
	var cmd: Node = get_node_or_null("/root/Cmd")
	if cmd != null and cmd.has_method("unregister_owner"):
		cmd.unregister_owner(id)


func set_module_enabled(id: String, on: bool) -> void:
	var r: Dictionary = _loader.record_for(id)
	if r.is_empty():
		return
	if not on and bool(r.get("core", false)):
		print("Host: " + id + " is a core module and stays on")
		modules_changed.emit()
		return
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null:
		var key: String = _enabled_key(id)
		if not prefs.is_registered(key):
			prefs.register(key, bool(r["official"]), {"label": "Module on: " + String(r["label"]), "type": "bool"})
		prefs.set_value(key, on)
	if on and String(r["state"]) != "on":
		_activate(r)
	elif not on and String(r["state"]) == "on":
		_loader.unload(r)
		_drop_module_items(id)
	modules_changed.emit()


func current_module() -> String:
	return _current_module
