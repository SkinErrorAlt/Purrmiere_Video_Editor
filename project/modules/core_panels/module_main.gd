extends RefCounted

const MANIFEST := "res://modules/core_panels/module.json"
const SHELL := "res://modules/core_panels/shell.gd"
const COMMANDS := "res://modules/core_panels/commands.gd"
const MARKER_LANE := "res://ui/timeline/marker_lane_kind.gd"

var _host: Node = null
var _registered: PackedStringArray = PackedStringArray()
var _shell: Node = null


static func read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func panel_map() -> Dictionary:
	var m: Dictionary = read_manifest()
	var raw: Variant = m.get("panels", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = {}
	for k: Variant in (raw as Dictionary).keys():
		if typeof(k) == TYPE_STRING and typeof(raw[k]) == TYPE_STRING:
			out[String(k)] = String(raw[k])
	return out


static func title_map() -> Dictionary:
	var m: Dictionary = read_manifest()
	var raw: Variant = m.get("titles", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


static func make_panel(id: String, script_path: String, title: String) -> Object:
	if not FileAccess.file_exists(script_path):
		print("core_panels: the script for panel \"" + id + "\" is missing: " + script_path)
		return null
	var script: Variant = load(script_path)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		print("core_panels: the script for panel \"" + id + "\" did not compile: " + script_path)
		return null
	var gd: GDScript = script
	var has_make: bool = false
	for m: Dictionary in gd.get_script_method_list():
		if String(m.get("name", "")) == "make":
			has_make = true
			break
	var impl: Object = null
	if has_make:
		impl = gd.call("make", id, title)
	else:
		impl = gd.new()
		if impl.has_method("setup"):
			impl.call("setup", id, title)
		elif impl.has_method("set_id"):
			impl.call("set_id", id)
	return impl


func register(host: Node) -> void:
	_host = host
	var panels: Dictionary = panel_map()
	var titles: Dictionary = title_map()
	var ids: Array = panels.keys()
	ids.sort()
	for id: String in ids:
		var impl: Object = make_panel(id, String(panels[id]), String(titles.get(id, id.capitalize())))
		if impl == null:
			continue
		host.register("IPanel", id, impl, {"title": String(titles.get(id, id.capitalize())), "official": true})
		_registered.append(id)
	_register_track_kinds(host)
	_register_commands()
	_add_shell(host)


func _register_track_kinds(host: Node) -> void:
	var script: Variant = load(MARKER_LANE)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		print("core_panels: the marker lane track kind did not compile")
		return
	var kind: Object = (script as GDScript).new()
	host.register("ITrackKind", String(kind.call("id")), kind, {"title": String(kind.call("label")), "official": true})


func _register_commands() -> void:
	var script: Variant = load(COMMANDS)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		print("core_panels: commands.gd did not compile")
		return
	(script as GDScript).call("register_all")


func _add_shell(host: Node) -> void:
	if _shell != null and is_instance_valid(_shell):
		return
	var tree: SceneTree = host.get_tree() if host.is_inside_tree() else null
	if tree == null:
		return
	var script: Variant = load(SHELL)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		print("core_panels: shell.gd did not compile")
		return
	_shell = (script as GDScript).new()
	tree.root.call_deferred("add_child", _shell)


func unregister() -> void:
	if _host == null:
		return
	for id: String in _registered:
		_host.unregister("IPanel", id)
	_host.unregister("ITrackKind", "marker_lane")
	_registered.clear()
	if _shell != null and is_instance_valid(_shell):
		var parent: Node = _shell.get_parent()
		if parent != null:
			parent.remove_child(_shell)
		_shell.queue_free()
	_shell = null
