extends Node

signal registry_changed
signal keymap_changed(name: String)

const KEYMAP_DIR := "res://host/keymaps/"
const CATALOGUE_PATH := "res://host/keymaps/catalogue.json"
const KEYMAP_FILES: Dictionary = {"premiere": "premiere.json", "classic": "classic.json"}
const SCOPES: PackedStringArray = ["global", "timeline", "program", "source", "bin", "keys", "controls"]
const USER_DIR := "keymaps"
const USER_FILE := "user.json"
const DEFAULT_KEYMAP := "premiere"
const NO_REPEAT: PackedStringArray = ["view.fullscreen", "view.program_fullscreen", "view.program_popout", "play.toggle", "play.around", "play.in_to_out", "play.in_to_out_roll", "play.to_out", "play.full_quality"]

var _commands: Dictionary = {}
var _holds: Dictionary = {}
var _keymaps: Dictionary = {}
var _keymap: String = "premiere"
var _catalogue: Dictionary = {}
var _catalogue_loaded: bool = false
var _user: Dictionary = {}
var _user_path: String = ""


func _ready() -> void:
	_load_keymaps()
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null:
		prefs.register("keys.keymap", "premiere", {"label": "Keymap", "type": "enum", "choices": ["premiere", "classic"]})
		var wanted: String = String(prefs.get_value("keys.keymap"))
		if _keymaps.has(wanted):
			_keymap = wanted
	if not _running_suite():
		_load_user()


func _running_suite() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null


func user_keymap_path() -> String:
	if not _user_path.is_empty():
		return _user_path
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null and prefs.has_method("data_path"):
		return String(prefs.call("data_path", USER_DIR)).path_join(USER_FILE)
	return ProjectSettings.globalize_path("user://" + USER_DIR).path_join(USER_FILE)


func use_user_keymap(path: String) -> void:
	_user_path = path
	_load_user()
	registry_changed.emit()


func _load_user() -> void:
	_user = {}
	var d: Dictionary = _read_json(user_keymap_path())
	var raw: Variant = d.get("keys", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for id: Variant in (raw as Dictionary).keys():
		_user[String(id)] = _string_list(raw[id])


func save_user_keymap() -> bool:
	var path: String = user_keymap_path()
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var keys: Dictionary = {}
	var ids: Array = _user.keys()
	ids.sort()
	for id: Variant in ids:
		keys[String(id)] = Array(_user[id])
	var text: String = JSON.stringify({"name": "User", "version": 1, "base": _keymap, "keys": keys}, " ", false)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


func user_keys() -> Dictionary:
	return _user.duplicate(true)


func has_user_keys(id: String) -> bool:
	return _user.has(id)


func set_user_keys(id: String, keys: Array[String]) -> void:
	if id.is_empty():
		return
	var clean: Array[String] = []
	for k: String in keys:
		if not k.is_empty() and not (k in clean):
			clean.append(k)
	if clean == default_keys_for(id):
		_user.erase(id)
	else:
		_user[id] = clean
	save_user_keymap()
	keymap_changed.emit(_keymap)
	registry_changed.emit()


func clear_user_keys(id: String) -> void:
	if not _user.erase(id):
		return
	save_user_keymap()
	keymap_changed.emit(_keymap)
	registry_changed.emit()


func reset_user_keymap() -> void:
	_user = {}
	save_user_keymap()
	if _keymaps.has(DEFAULT_KEYMAP) and _keymap != DEFAULT_KEYMAP:
		set_keymap(DEFAULT_KEYMAP)
		return
	keymap_changed.emit(_keymap)
	registry_changed.emit()


func default_keys_for(id: String) -> Array[String]:
	var map: Dictionary = _keymaps.get(_keymap, {})
	if map.has(id):
		return map[id]
	if _commands.has(id):
		var spec_keys: Dictionary = _commands[id]["keys"]
		if spec_keys.has(_keymap):
			return spec_keys[_keymap]
	return []


func scope_of(id: String) -> String:
	if _commands.has(id):
		return String(_commands[id]["scope"])
	var cat: Dictionary = catalogue()
	if cat.has(id):
		return String(cat[id]["scope"])
	return "global"


func command_ids() -> PackedStringArray:
	var seen: Dictionary = {}
	for id: Variant in _commands.keys():
		seen[String(id)] = true
	for id: Variant in catalogue().keys():
		seen[String(id)] = true
	var out: PackedStringArray = PackedStringArray()
	for id: Variant in seen.keys():
		out.append(String(id))
	out.sort()
	return out


func clashes(key: String, scope: String, except_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if key.is_empty():
		return out
	for id: String in command_ids():
		if id == except_id:
			continue
		if not (key in keys_for(id)):
			continue
		var s: String = scope_of(id)
		if s == scope or s == "global" or scope == "global":
			out.append({"id": id, "label": label(id), "scope": s})
	return out


func _load_keymaps() -> void:
	for name: String in KEYMAP_FILES.keys():
		var d: Dictionary = _read_json(KEYMAP_DIR + String(KEYMAP_FILES[name]))
		var keys: Dictionary = {}
		var raw: Variant = d.get("keys", {})
		if typeof(raw) == TYPE_DICTIONARY:
			for id: String in raw.keys():
				keys[id] = _string_list(raw[id])
		_keymaps[name] = keys


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _string_list(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_STRING:
		out.append(String(v))
	elif typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			if typeof(item) == TYPE_STRING:
				out.append(String(item))
	return out


func catalogue() -> Dictionary:
	if not _catalogue_loaded:
		_catalogue_loaded = true
		var d: Dictionary = _read_json(CATALOGUE_PATH)
		var raw: Variant = d.get("commands", {})
		if typeof(raw) == TYPE_DICTIONARY:
			for id: String in raw.keys():
				var e: Variant = raw[id]
				if typeof(e) != TYPE_DICTIONARY:
					continue
				_catalogue[id] = {
					"label": String(e.get("label", id)),
					"category": String(e.get("category", "Edit")),
					"scope": String(e.get("scope", "global")),
				}
	return _catalogue


func register(id: String, spec: Dictionary) -> void:
	if id.is_empty():
		return
	var scope: String = String(spec.get("scope", "global"))
	if not (scope in SCOPES):
		scope = "global"
	var keys_spec: Dictionary = {}
	var raw_keys: Variant = spec.get("keys", {})
	if typeof(raw_keys) == TYPE_DICTIONARY:
		for name: String in raw_keys.keys():
			keys_spec[name] = _string_list(raw_keys[name])
	var handler: Variant = spec.get("handler", Callable())
	var enabled: Variant = spec.get("enabled", Callable())
	var toggle: Variant = spec.get("toggle", Callable())
	_commands[id] = {
		"id": id,
		"label": String(spec.get("label", id)),
		"category": String(spec.get("category", "Edit")),
		"scope": scope,
		"keys": keys_spec,
		"handler": handler if typeof(handler) == TYPE_CALLABLE else Callable(),
		"enabled": enabled if typeof(enabled) == TYPE_CALLABLE else Callable(),
		"toggle": toggle if typeof(toggle) == TYPE_CALLABLE else Callable(),
		"owner": String(spec.get("owner", "")),
		"repeat": bool(spec.get("repeat", true)),
	}
	registry_changed.emit()


func unregister(id: String) -> void:
	if _commands.erase(id):
		registry_changed.emit()


func unregister_owner(owner: String) -> void:
	var gone: bool = false
	for id: String in _commands.keys().duplicate():
		if String(_commands[id]["owner"]) == owner:
			_commands.erase(id)
			gone = true
	if gone:
		registry_changed.emit()


func has(id: String) -> bool:
	return _commands.has(id)


func is_enabled(id: String) -> bool:
	if not _commands.has(id):
		return false
	var c: Dictionary = _commands[id]
	var en: Callable = c["enabled"]
	if en.is_valid():
		return bool(en.call())
	return true


func is_toggled(id: String) -> bool:
	if not _commands.has(id):
		return false
	var tg: Callable = _commands[id]["toggle"]
	if tg.is_valid():
		return bool(tg.call())
	return false


func has_toggle(id: String) -> bool:
	if not _commands.has(id):
		return false
	var tg: Callable = _commands[id]["toggle"]
	return tg.is_valid()


func run(id: String) -> bool:
	if not _commands.has(id):
		return false
	if not is_enabled(id):
		return false
	var h: Callable = _commands[id]["handler"]
	if not h.is_valid():
		return false
	h.call()
	return true


func label(id: String) -> String:
	if _commands.has(id):
		return String(_commands[id]["label"])
	var cat: Dictionary = catalogue()
	if cat.has(id):
		return String(cat[id]["label"])
	return id


func category(id: String) -> String:
	if _commands.has(id):
		return String(_commands[id]["category"])
	return ""


func keys_for(id: String) -> Array[String]:
	if _user.has(id):
		return _user[id]
	return default_keys_for(id)


func keys_text(id: String) -> String:
	var ks: Array[String] = keys_for(id)
	if ks.is_empty():
		return ""
	return ks[0]


func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = _commands.keys()
	ids.sort()
	for id: String in ids:
		var c: Dictionary = _commands[id]
		out.append({
			"id": id,
			"label": c["label"],
			"category": c["category"],
			"scope": c["scope"],
			"keys": keys_for(id),
			"enabled": is_enabled(id),
			"toggle": has_toggle(id),
			"toggled": is_toggled(id),
		})
	return out


func by_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in all():
		if String(c["category"]) == cat:
			out.append(c)
	return out


func set_keymap(name: String) -> void:
	if not _keymaps.has(name):
		print("Cmd: no keymap named \"" + name + "\"")
		return
	_keymap = name
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs != null:
		prefs.set_value("keys.keymap", name)
	keymap_changed.emit(name)
	registry_changed.emit()


func keymap_name() -> String:
	return _keymap


func keymap_names() -> PackedStringArray:
	var out := PackedStringArray()
	for n: String in _keymaps.keys():
		out.append(n)
	out.sort()
	return out


func keymap_ids(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var map: Dictionary = _keymaps.get(name, {})
	for id: String in map.keys():
		out.append(id)
	return out


func key_string(event: InputEventKey) -> String:
	var parts := PackedStringArray()
	if event.ctrl_pressed or event.meta_pressed:
		parts.append("Ctrl")
	if event.alt_pressed:
		parts.append("Alt")
	if event.shift_pressed:
		parts.append("Shift")
	var name: String = key_name(event)
	if name.is_empty():
		return ""
	parts.append(name)
	return "+".join(parts)


func key_name(event: InputEventKey) -> String:
	var code: Key = event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	return key_name_for(code)


func key_name_for(code: Key) -> String:
	if code >= KEY_A and code <= KEY_Z:
		return char(code)
	if code >= KEY_0 and code <= KEY_9:
		return char(code)
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return str(int(code) - int(KEY_KP_0))
	if code >= KEY_F1 and code <= KEY_F12:
		return "F" + str(int(code) - int(KEY_F1) + 1)
	var table: Dictionary = {
		KEY_LEFT: "Left", KEY_RIGHT: "Right", KEY_UP: "Up", KEY_DOWN: "Down",
		KEY_HOME: "Home", KEY_END: "End", KEY_SPACE: "Space", KEY_DELETE: "Delete",
		KEY_BACKSPACE: "Backspace", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter", KEY_ESCAPE: "Escape",
		KEY_PAGEUP: "PageUp", KEY_PAGEDOWN: "PageDown", KEY_TAB: "Tab", KEY_INSERT: "Insert",
		KEY_QUOTELEFT: "`", KEY_BACKSLASH: "\\", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
		KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_SLASH: "/",
		KEY_EQUAL: "=", KEY_MINUS: "-", KEY_KP_ADD: "=", KEY_KP_SUBTRACT: "-", KEY_KP_DIVIDE: "/",
		KEY_KP_MULTIPLY: "*", KEY_KP_PERIOD: ".", KEY_ASCIITILDE: "`", KEY_QUESTION: "/",
		KEY_PLUS: "=", KEY_UNDERSCORE: "-", KEY_BAR: "\\", KEY_COLON: ";", KEY_QUOTEDBL: "'",
		KEY_LESS: ",", KEY_GREATER: ".", KEY_BRACELEFT: "[", KEY_BRACERIGHT: "]",
		KEY_EXCLAM: "1", KEY_AT: "2", KEY_NUMBERSIGN: "3", KEY_DOLLAR: "4", KEY_PERCENT: "5",
		KEY_ASCIICIRCUM: "6", KEY_AMPERSAND: "7", KEY_ASTERISK: "8", KEY_PARENLEFT: "9", KEY_PARENRIGHT: "0",
	}
	if table.has(code):
		return String(table[code])
	return ""


func _matches(id: String, key: String, scope: String) -> bool:
	var ks: Array[String] = keys_for(id)
	if not (key in ks):
		return false
	var c: Dictionary = _commands[id]
	var s: String = c["scope"]
	return s == "global" or s == scope


func find_for_key(key: String, scope: String) -> String:
	if key.is_empty():
		return ""
	var global_hit: String = ""
	for id: String in _commands.keys():
		var c: Dictionary = _commands[id]
		var ks: Array[String] = keys_for(id)
		if not (key in ks):
			continue
		var s: String = c["scope"]
		if s == scope and scope != "global":
			return id
		if s == "global" and global_hit.is_empty():
			global_hit = id
	return global_hit


func dispatch_key(event: InputEventKey, scope: String) -> bool:
	if not event.pressed:
		return false
	var key: String = key_string(event)
	if key.is_empty():
		return false
	var id: String = find_for_key(key, scope)
	if id.is_empty():
		return false
	if event.echo and not repeats(id):
		return true
	if _holds.has(id) and is_enabled(id) and (_holds[id] as Callable).is_valid():
		return bool((_holds[id] as Callable).call(event))
	return run(id)


func set_hold(id: String, handler: Callable) -> void:
	if handler.is_valid():
		_holds[id] = handler
	else:
		_holds.erase(id)


func repeats(id: String) -> bool:
	if id in NO_REPEAT:
		return false
	if _commands.has(id):
		return bool((_commands[id] as Dictionary).get("repeat", true))
	return true
