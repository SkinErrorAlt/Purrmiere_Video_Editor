extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Health := preload("res://doc/health.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Sheet := preload("res://modules/core_panels/sheet.gd")
const PaletteSheet := preload("res://modules/core_panels/palette_sheet.gd")
const FindSheet := preload("res://modules/core_panels/find_sheet.gd")
const ShortcutsSheet := preload("res://modules/core_panels/shortcuts_sheet.gd")
const RelinkSheet := preload("res://modules/core_panels/relink_sheet.gd")
const RestoreSheet := preload("res://modules/core_panels/restore_sheet.gd")
const PropertiesSheet := preload("res://modules/core_panels/properties_sheet.gd")
const StreamRolesSheet := preload("res://modules/core_panels/stream_roles_sheet.gd")
const UnusedSheet := preload("res://modules/core_panels/unused_sheet.gd")
const AssetPacksSheet := preload("res://modules/core_panels/asset_packs_sheet.gd")
const ScatterSheet := preload("res://modules/core_panels/scatter_sheet.gd")
const SELF_PATH := "res://modules/core_panels/systems.gd"
const FIX_PREFIX := "health.fix:"
const FIX_ALL := "health.fix_all"
const MAX_POSTED := 40
const DOC_COMMANDS: PackedStringArray = ["edit.find", "file.relink", "file.restore", "help.health", "file.remove_unused", "audio.scatter_sounds", "file.asset_packs"]
const TARGET_COMMANDS: PackedStringArray = ["file.properties"]
const FILE_COMMANDS: PackedStringArray = ["file.reveal", "file.edit_original"]

static var launcher: Callable = Callable()
static var last_sheet: Node = null
static var _checked_doc: WeakRef = null


static func script_ref() -> GDScript:
	return load(SELF_PATH)


static func register_all(owner: String) -> void:
	var me: GDScript = script_ref()
	_reg("app.palette", Callable(me, "open_palette"), owner, Callable())
	_reg("edit.keyboard_shortcuts", Callable(me, "open_shortcuts"), owner, Callable())
	_reg("edit.find", Callable(me, "open_find"), owner, Callable(me, "has_doc"))
	_reg("file.relink", Callable(me, "open_relink"), owner, Callable(me, "has_doc"))
	_reg("file.restore", Callable(me, "open_restore"), owner, Callable(me, "has_doc"))
	_reg("help.health", Callable(me, "run_health"), owner, Callable(me, "has_doc"))
	_reg("file.remove_unused", Callable(me, "open_unused"), owner, Callable(me, "has_doc"))
	_reg("audio.scatter_sounds", Callable(me, "open_scatter"), owner, Callable(me, "has_doc"))
	_reg("file.asset_packs", Callable(me, "open_asset_packs"), owner, Callable(me, "has_doc"))
	_reg("file.properties", Callable(me, "open_properties"), owner, Callable(me, "has_target"))
	_reg("file.reveal", Callable(me, "reveal_target"), owner, Callable(me, "has_target_file"))
	_reg("file.edit_original", Callable(me, "edit_target"), owner, Callable(me, "has_target_file"))
	var hook: Callable = Callable(me, "on_project_changed")
	if not Session.project_changed.is_connected(hook):
		Session.project_changed.connect(hook)
	if Session.doc != null:
		hook.call_deferred()


static func _reg(id: String, handler: Callable, owner: String, enabled: Callable) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "File"
	var scope: String = "global"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
		scope = String(cat[id]["scope"])
	var spec: Dictionary = {"label": label, "category": category, "scope": scope, "handler": handler, "owner": owner}
	if enabled.is_valid():
		spec["enabled"] = enabled
	Cmd.register(id, spec)


static func host() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func has_doc() -> bool:
	return Session.doc != null


static func target_media() -> MediaItem:
	var doc: Project = Session.doc
	if doc == null:
		return null
	var bus: RefCounted = Bus.instance()
	var bin: Object = bus.call("panel", "bin")
	var bin_sel: PackedStringArray = PackedStringArray()
	if bin != null:
		var raw: Variant = bin.get("selected_ids")
		if raw is PackedStringArray:
			bin_sel = raw
	var s: Sequence = Session.seq()
	var c: Clip = Bus.selected_clip(s)
	if String(bus.get("focused_panel")) == "bin" and not bin_sel.is_empty():
		return doc.media_by_id(bin_sel[0])
	if c != null:
		return doc.media_by_id(c.media_id)
	if not bin_sel.is_empty():
		return doc.media_by_id(bin_sel[0])
	return null


static func has_target() -> bool:
	return target_media() != null


static func has_target_file() -> bool:
	var m: MediaItem = target_media()
	return m != null and not m.path.is_empty()


static func open_palette() -> Node:
	Sheet.close_all()
	last_sheet = PaletteSheet.open(host())
	return last_sheet


static func open_find() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = FindSheet.open(host())
	return last_sheet


static func open_shortcuts() -> Node:
	Sheet.close_all()
	last_sheet = ShortcutsSheet.open(host())
	return last_sheet


static func open_relink() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = RelinkSheet.open(host())
	return last_sheet


static func open_restore() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = RestoreSheet.open(host())
	return last_sheet


static func open_unused() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = UnusedSheet.open(host())
	return last_sheet


static func open_scatter() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = ScatterSheet.open(host())
	return last_sheet


static func open_properties() -> Node:
	return open_properties_for(target_media())


static func open_properties_for(m: MediaItem) -> Node:
	if Session.doc == null or m == null:
		Events.toast("Select a bin item or a clip first")
		return null
	Sheet.close_all()
	var me: GDScript = script_ref()
	last_sheet = PropertiesSheet.open(host(), Session.doc, m, Callable(me, "reveal_media"), Callable(me, "edit_media"))
	return last_sheet


static func open_asset_packs() -> Node:
	if Session.doc == null:
		return null
	Sheet.close_all()
	last_sheet = AssetPacksSheet.open(host())
	return last_sheet


static func open_asset_pack_save(ids: PackedStringArray) -> Node:
	if Session.doc == null:
		return null
	if ids.is_empty():
		Events.toast("Mark the bin items you want in the package first")
		return null
	Sheet.close_all()
	last_sheet = AssetPacksSheet.open_save(host(), ids)
	return last_sheet


static func open_stream_roles_for(m: MediaItem) -> Node:
	if Session.doc == null or m == null:
		Events.toast("Select a bin item first")
		return null
	Sheet.close_all()
	last_sheet = StreamRolesSheet.open(host(), Session.doc, m)
	return last_sheet


static func file_path_of(m: MediaItem) -> String:
	if m == null or m.path.is_empty():
		return ""
	return ProjectSettings.globalize_path(m.path)


static func launch(action: String, path: String) -> void:
	if launcher.is_valid():
		launcher.call(action, path)
		return
	if action == "reveal":
		OS.shell_show_in_file_manager(path)
	else:
		OS.shell_open(path)


static func _file_action(m: MediaItem, action: String) -> bool:
	if m == null:
		Events.toast("Select a bin item or a clip first")
		return false
	var path: String = file_path_of(m)
	if path.is_empty():
		Events.toast(m.label + " has no file on disk")
		return false
	if not FileAccess.file_exists(path):
		Events.warn(m.label + " is missing", path, PackedStringArray(["file.relink"]))
		return false
	launch(action, path)
	return true


static func reveal_media(media_id: String) -> bool:
	var doc: Project = Session.doc
	return _file_action(doc.media_by_id(media_id) if doc != null else null, "reveal")


static func edit_media(media_id: String) -> bool:
	var doc: Project = Session.doc
	return _file_action(doc.media_by_id(media_id) if doc != null else null, "open")


static func reveal_target() -> bool:
	return _file_action(target_media(), "reveal")


static func edit_target() -> bool:
	return _file_action(target_media(), "open")


static func on_project_changed() -> void:
	var doc: Project = Session.doc
	if doc == null:
		_checked_doc = null
		return
	if _checked_doc != null and _checked_doc.get_ref() == doc:
		return
	_checked_doc = weakref(doc)
	post_health(doc, false)


static func run_health() -> int:
	var doc: Project = Session.doc
	if doc == null:
		return 0
	var n: int = post_health(doc, true)
	FindSheet._show_panel("events")
	return n


static func post_health(doc: Project, on_demand: bool) -> int:
	var findings: Array[Dictionary] = Health.check(doc)
	if findings.is_empty():
		if on_demand:
			Events.info("Health check: no problems found in " + doc.name)
			Events.toast("Health check: no problems found")
		return 0
	var missing: PackedStringArray = PackedStringArray()
	var others: Array[Dictionary] = []
	for f: Dictionary in findings:
		if String(f.get("kind", "")) == "missing_media":
			missing.append(String(f.get("text", "")))
		else:
			others.append(f)
	if not missing.is_empty():
		var n: int = missing.size()
		var shown: PackedStringArray = missing.slice(0, 8)
		var detail: String = "\n".join(shown) + ("\n" + str(n - shown.size()) + " more" if n > shown.size() else "")
		Events.warn(str(n) + (" media file is" if n == 1 else " media files are") + " missing", detail, PackedStringArray(["file.relink"]))
	var fixable: int = 0
	var posted: int = 0
	for f: Dictionary in others:
		var fixes: PackedStringArray = PackedStringArray()
		if Health.has_fix(f):
			fixable += 1
			fixes.append(FIX_PREFIX + Health.key_of(f))
		if posted < MAX_POSTED:
			Events.warn("Health check: " + String(f.get("text", "")), "", fixes)
			posted += 1
	if others.size() > posted:
		Events.warn("Health check: " + str(others.size() - posted) + " more problems not listed", "")
	if fixable >= 2:
		Events.warn("Health check found " + str(fixable) + " problems it can fix", "Fix all runs every fix as one step you can undo.", PackedStringArray([FIX_ALL]))
	if on_demand:
		Events.toast("Health check: " + str(findings.size()) + (" finding, see Events" if findings.size() == 1 else " findings, see Events"))
	return findings.size()


static func is_fix(id: String) -> bool:
	return id == FIX_ALL or id.begins_with(FIX_PREFIX)


static func fix_label(id: String) -> String:
	if id == FIX_ALL:
		return "Fix all"
	if id.begins_with(FIX_PREFIX):
		return "Fix"
	return id


static func run_fix(id: String) -> bool:
	var doc: Project = Session.doc
	if doc == null:
		return false
	if id == FIX_ALL:
		var n: int = Health.fix_everything(doc)
		Events.toast("Fixed " + str(n) + (" problem" if n == 1 else " problems") if n > 0 else "Nothing left to fix")
		return n > 0
	if id.begins_with(FIX_PREFIX):
		var ok: bool = Health.fix_one(doc, id.substr(FIX_PREFIX.length()))
		Events.toast("Fixed, Undo puts it back" if ok else "Already fixed")
		return ok
	return false
