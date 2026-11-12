extends RefCounted
## What modules add to Purrmiere beyond panels: menu items, workspaces, file formats they open and save, document
## kinds they own, and folders of effects and transitions. Every entry remembers its module so unloading removes
## it. The menu bar, the workspace tabs, the dock, the registries and the file drop all read from here.

signal changed(what: String)

static var _shared: RefCounted = null

var menus: Array[Dictionary] = []
var workspaces: Array[Dictionary] = []
var formats: Array[Dictionary] = []
var documents: Array[Dictionary] = []
var effect_roots: Array[Dictionary] = []
var transition_roots: Array[Dictionary] = []
var drop_handlers: Array[Dictionary] = []


static func shared() -> RefCounted:
	if _shared == null:
		var script: GDScript = load("res://host/module_extras.gd")
		_shared = script.new()
	return _shared


## Clears everything, for suites.
static func reset() -> void:
	_shared = null


func add_menu_item(owner: String, menu: String, command_id: String, after: String = "") -> void:
	for m: Dictionary in menus:
		if String(m["menu"]) == menu and String(m["command"]) == command_id:
			return
	menus.append({"owner": owner, "menu": menu, "command": command_id, "after": after})
	changed.emit("menus")


func menu_items(menu: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: Dictionary in menus:
		if String(m["menu"]) == menu:
			out.append(String(m["command"]))
	return out


func add_workspace(owner: String, id: String, label: String, layout: Dictionary) -> void:
	remove_where(workspaces, "id", id)
	var d: Dictionary = layout.duplicate(true)
	d["name"] = id
	workspaces.append({"owner": owner, "id": id, "label": label, "layout": d})
	changed.emit("workspaces")


func workspace(id: String) -> Dictionary:
	for w: Dictionary in workspaces:
		if String(w["id"]) == id:
			return w
	return {}


func layout(id: String) -> Dictionary:
	var w: Dictionary = workspace(id)
	return (w["layout"] as Dictionary).duplicate(true) if not w.is_empty() else {}


## A file format a module opens and or saves: exts without dots, open(path) -> bool, save(path, what) -> bool.
func add_format(owner: String, id: String, label: String, exts: PackedStringArray, open: Callable, save: Callable) -> void:
	remove_where(formats, "id", id)
	var lower: PackedStringArray = PackedStringArray()
	for e: String in exts:
		lower.append(e.trim_prefix(".").to_lower())
	formats.append({"owner": owner, "id": id, "label": label, "exts": lower, "open": open, "save": save})
	changed.emit("formats")


## The module format that opens this file, or {}.
func format_for(path: String) -> Dictionary:
	var ext: String = path.get_extension().to_lower()
	for f: Dictionary in formats:
		if (f["exts"] as PackedStringArray).has(ext) and (f["open"] as Callable).is_valid():
			return f
	return {}


## A kind of document a module owns (an image, a board): new() and open(path) callables, and a file extension.
func add_document_kind(owner: String, kind: String, label: String, ext: String, make_new: Callable, open: Callable) -> void:
	remove_where(documents, "kind", kind)
	documents.append({"owner": owner, "kind": kind, "label": label, "ext": ext.trim_prefix(".").to_lower(), "new": make_new, "open": open})
	changed.emit("documents")


func document_kind(kind: String) -> Dictionary:
	for d: Dictionary in documents:
		if String(d["kind"]) == kind:
			return d
	return {}


## Files dropped on the window while this workspace shows go to handler(paths) -> the paths it did not take.
func add_drop_handler(owner: String, workspace: String, handler: Callable) -> void:
	remove_where(drop_handlers, "workspace", workspace)
	drop_handlers.append({"owner": owner, "workspace": workspace, "handler": handler})
	changed.emit("drops")


func drop_handler_for(workspace: String) -> Callable:
	for d: Dictionary in drop_handlers:
		if String(d["workspace"]) == workspace and (d["handler"] as Callable).is_valid():
			return d["handler"]
	return Callable()


func add_effect_root(owner: String, path: String) -> void:
	var p: String = path.trim_suffix("/") + "/"
	for r: Dictionary in effect_roots:
		if String(r["path"]) == p:
			return
	effect_roots.append({"owner": owner, "path": p})
	changed.emit("effects")


func add_transition_root(owner: String, path: String) -> void:
	var p: String = path.trim_suffix("/") + "/"
	for r: Dictionary in transition_roots:
		if String(r["path"]) == p:
			return
	transition_roots.append({"owner": owner, "path": p})
	changed.emit("transitions")


func effect_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in effect_roots:
		out.append(String(r["path"]))
	return out


func transition_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in transition_roots:
		out.append(String(r["path"]))
	return out


## Removes everything one module added. Returns what kinds changed.
func drop_owner(owner: String) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for pair: Array in [[menus, "menus"], [workspaces, "workspaces"], [formats, "formats"], [documents, "documents"], [effect_roots, "effects"], [transition_roots, "transitions"], [drop_handlers, "drops"]]:
		var list: Array = pair[0]
		var before: int = list.size()
		remove_where(list, "owner", owner)
		if list.size() != before:
			kinds.append(String(pair[1]))
	for k: String in kinds:
		changed.emit(k)
	return kinds


func count_for(owner: String) -> int:
	var n: int = 0
	for list: Array in [menus, workspaces, formats, documents, effect_roots, transition_roots, drop_handlers]:
		for e: Dictionary in list:
			if String(e["owner"]) == owner:
				n += 1
	return n


static func remove_where(list: Array, key: String, value: String) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		if String((list[i] as Dictionary).get(key, "")) == value:
			list.remove_at(i)
