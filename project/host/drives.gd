extends RefCounted

const PARK_PREF := "media.park_unused"
const PARK_LABEL := "Park videos that are not being viewed (frees the drive, keeps the picture on screen)"
const READERS_SUFFIX := ".files_at_once"
const KEEP_SUFFIX := ".videos_kept_open"
const MAX_READERS := 16
const MAX_KEEP := 64
const KINDS: Dictionary = {
	"ssd": "solid state",
	"spinning": "spinning disk",
	"removable": "removable",
	"network": "network",
	"optical": "optical",
	"ram": "memory disk",
	"unknown": "not measured",
}

static var _cb: Callable = Callable()
static var _seen: Dictionary = {}


static func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


static func slug(root: String) -> String:
	var out: String = ""
	for i: int in root.length():
		var c: String = root[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif c >= "A" and c <= "Z":
			out += c.to_lower()
		elif not out.is_empty() and not out.ends_with("_"):
			out += "_"
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out if not out.is_empty() else "drive"


static func kind_text(kind: String) -> String:
	return String(KINDS.get(kind, kind))


static func describe(v: Dictionary) -> String:
	var kind: String = kind_text(String(v.get("kind", "unknown")))
	var bus: String = String(v.get("bus", "unknown"))
	if bus != "unknown" and bus != "":
		kind += " over " + bus
	if not bool(v.get("measured", false)):
		kind += ", guessed"
	return kind


static func readers_key(root: String) -> String:
	return "drives." + slug(root) + READERS_SUFFIX


static func keep_key(root: String) -> String:
	return "drives." + slug(root) + KEEP_SUFFIX


static func register() -> void:
	var prefs: Node = _root_node("Prefs")
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PARK_PREF)):
		prefs.call("register", PARK_PREF, true, {"label": PARK_LABEL, "type": "bool"})
	if not _cb.is_valid():
		_cb = func(key: String) -> void:
			if key == PARK_PREF or key.begins_with("drives."):
				apply()
	var sig: Signal = prefs.get("changed")
	if not sig.is_connected(_cb):
		sig.connect(_cb)
	refresh()


static func parking_on() -> bool:
	var prefs: Node = _root_node("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PARK_PREF)):
		return true
	return bool(prefs.call("get_value", PARK_PREF))


static func note_path(path: String) -> void:
	if path.is_empty():
		return
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bridge.has_method("has_drives") or not bool(bridge.call("has_drives")):
		return
	var v: Dictionary = bridge.call("volume_for_path", path)
	var root: String = String(v.get("root", ""))
	if root.is_empty() or _seen.has(root):
		return
	_register_drive(v)
	apply()


static func _register_drive(v: Dictionary) -> void:
	var prefs: Node = _root_node("Prefs")
	var root: String = String(v.get("root", ""))
	if prefs == null or root.is_empty():
		return
	_seen[root] = v
	var label: String = String(v.get("label", root))
	var detail: String = describe(v)
	var rk: String = readers_key(root)
	if not bool(prefs.call("is_registered", rk)):
		prefs.call("register", rk, 0, {
			"label": label + ": files read at once (0 measures the drive, now " + str(int(v.get("measured_limit", 1))) + ", " + detail + ")",
			"type": "int", "min": 0, "max": MAX_READERS,
		})
	var kk: String = keep_key(root)
	if not bool(prefs.call("is_registered", kk)):
		prefs.call("register", kk, 0, {
			"label": label + ": videos kept open (0 follows the drive)",
			"type": "int", "min": 0, "max": MAX_KEEP,
		})


static func refresh() -> void:
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bridge.has_method("has_drives") or not bool(bridge.call("has_drives")):
		return
	for v: Dictionary in bridge.call("volumes"):
		_register_drive(v)
	apply()


static func known() -> Array[Dictionary]:
	var bridge: Node = _root_node("PurrBridge")
	var out: Array[Dictionary] = []
	if bridge == null or not bridge.has_method("has_drives") or not bool(bridge.call("has_drives")):
		return out
	for v: Dictionary in bridge.call("volumes"):
		out.append(v)
	return out


static func apply() -> void:
	var bridge: Node = _root_node("PurrBridge")
	var prefs: Node = _root_node("Prefs")
	if bridge == null or prefs == null or not bridge.has_method("has_drives") or not bool(bridge.call("has_drives")):
		return
	bridge.call("set_residency", parking_on())
	for root: Variant in _seen.keys():
		var r: String = String(root)
		var rk: String = readers_key(r)
		var kk: String = keep_key(r)
		if bool(prefs.call("is_registered", rk)):
			bridge.call("set_volume_limit", r, clampi(int(prefs.call("get_value", rk)), 0, MAX_READERS))
		if bool(prefs.call("is_registered", kk)):
			bridge.call("set_volume_keep", r, clampi(int(prefs.call("get_value", kk)), 0, MAX_KEEP))


static func remeasure() -> void:
	var bridge: Node = _root_node("PurrBridge")
	if bridge != null and bridge.has_method("remeasure_volumes"):
		bridge.call("remeasure_volumes")
	refresh()
