extends Node

const PmUI := preload("res://ui/kit/pm_ui.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Io := preload("res://doc/io.gd")
const Verbs := preload("res://doc/verbs.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const EditTools := preload("res://doc/commands/edit_tools.gd")
const SaveAfterEdit := preload("res://modules/core_panels/save_after_edit.gd")
const OWNER := "core_panels"
const EXIT_GUARD_SECONDS := 20.0
const OVERRIDE_IDS: PackedStringArray = ["file.new_project", "file.open", "file.close", "file.quit"]
const PREF_AUTOSAVE := "project.autosave_seconds"
const PROJECT_EXT := "purrmiere"

var _timer: Timer = null
var _dialog: FileDialog = null
var _folder_dialog: FileDialog = null
var _dialog_mode: String = ""
var _hooked_home: Array[Node] = []
var _crash_asked: bool = false
var _reasserting: bool = false
var _quit_confirmed: bool = false
var _saver: Node = null


func _ready() -> void:
	name = "CorePanelsShell"
	if not Prefs.is_registered(PREF_AUTOSAVE):
		Prefs.register(PREF_AUTOSAVE, 120.0, {"label": "Autosave snapshot every (seconds)", "type": "float", "min": 15.0, "max": 3600.0})
	_register_commands()
	get_tree().auto_accept_quit = false
	_timer = Timer.new()
	_timer.wait_time = 5.0
	_timer.autostart = true
	_timer.timeout.connect(_on_autosave_tick)
	add_child(_timer)
	_saver = SaveAfterEdit.new()
	add_child(_saver)
	add_child(load("res://modules/core_panels/shader_file_drop.gd").new())
	Cmd.registry_changed.connect(_on_registry_changed)
	Session.project_changed.connect(_on_project_changed)
	var main: Node = _main()
	if main != null:
		main.child_entered_tree.connect(_on_main_child)
		for c: Node in main.get_children():
			_hook_home(c)
	call_deferred("_start_checks")


func _process(dt: float) -> void:
	var bus: RefCounted = Bus.instance()
	for id: String in bus.panels.keys():
		var p: Variant = bus.panels[id]
		if p is Object and (p as Object).has_method("tick"):
			(p as Object).call("tick", dt)


func _main() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("Main")


func _on_main_child(n: Node) -> void:
	_hook_home(n)


func _hook_home(n: Node) -> void:
	if n == null or n in _hooked_home:
		return
	if n.has_signal("new_project") and n.has_signal("open_project"):
		_hooked_home.append(n)
		n.connect("new_project", _on_home_new)
		n.connect("open_project", _on_home_open)
		n.tree_exiting.connect(_on_home_gone.bind(n))


func _on_home_gone(n: Node) -> void:
	_hooked_home.erase(n)


func _start_checks() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var wants_shot: bool = false
	var has_project_arg: bool = false
	for a: String in args:
		if a == "--shot" or a.begins_with("--shot=") or a == "--route" or a.begins_with("--route=") or a == "--layout-dump":
			wants_shot = true
		if a == "--project" or a.begins_with("--project="):
			has_project_arg = true
	if has_project_arg:
		var path: String = ""
		for i: int in args.size():
			if args[i] == "--project" and i + 1 < args.size():
				path = args[i + 1]
			elif args[i].begins_with("--project="):
				path = args[i].substr(10)
		if not path.is_empty() and Session.doc == null:
			_open_path(path, false)
		return
	if wants_shot and Session.doc == null:
		Session.set_project(sample_project())
		return
	if not _crash_asked:
		_crash_asked = true
		var crashed: Dictionary = Io.crashed_session()
		if bool(crashed["found"]):
			var main: Node = _main()
			if main != null:
				var answered: Signal = PmUI.confirm(main, "Recover the last session", "The project " + String(crashed["path"]).get_file() + " was open when the app last closed (" + String(crashed["time"]) + "). Open it again?", "Open", "Not now")
				answered.connect(_on_crash_answered.bind(String(crashed["path"])))
				return
		offer_recovery()


func _on_crash_answered(ok: Variant, path: String) -> void:
	if bool(ok):
		_open_path(path, true)
	else:
		var p: Project = Project.new()
		p.path = path
		Io.unlock(p)
	if Session.doc == null:
		offer_recovery()


func offer_recovery() -> bool:
	var main: Node = _main()
	if main == null or _saver == null or not bool(_saver.call("enabled")):
		return false
	var found: Array[Dictionary] = Io.orphan_recoveries()
	if found.is_empty():
		return false
	var info: Dictionary = found[0]
	var answered: Signal = PmUI.choose(main, "Recover unsaved work", SaveAfterEdit.recovery_text(info), [{"id": "delete", "label": "Delete it"}, {"id": "later", "label": "Not now"}, {"id": "open", "label": "Open", "primary": true}])
	answered.connect(_on_recovery_answered.bind(String(info["path"])))
	return true


func _on_recovery_answered(choice: Variant, path: String) -> void:
	var id: String = String(choice)
	if id == "delete":
		Io.remove_recovery(path)
		Events.toast("Deleted the recovery file")
	elif id == "open":
		open_recovery(path)


func open_recovery(path: String) -> bool:
	var p: Project = _saver.call("open_recovery", path)
	if p == null:
		Events.error("Could not open the recovery file", Io.last_error)
		return false
	Session.set_project(p, "")
	_show_editor(p.name)
	Events.notice("Recovered " + p.name, "This project has never been saved. Save it to keep it; the recovery file stays until then.")
	return true


func _cmd(id: String, handler: Callable, scope: String = "global", enabled: Callable = Callable(), toggle: Callable = Callable()) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Edit"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	var spec: Dictionary = {"label": label, "category": category, "scope": scope, "handler": handler, "owner": OWNER}
	if enabled.is_valid():
		spec["enabled"] = enabled
	if toggle.is_valid():
		spec["toggle"] = toggle
	Cmd.register(id, spec)


func _has_doc() -> bool:
	return Session.doc != null


func _can_undo() -> bool:
	return Session.doc != null and Session.doc.undo.can_undo()


func _can_redo() -> bool:
	return Session.doc != null and Session.doc.undo.can_redo()


func _register_commands() -> void:
	var have: PackedStringArray = PackedStringArray()
	for c: Dictionary in Cmd.all():
		have.append(String(c["id"]))
	for id: String in OVERRIDE_IDS:
		_register_override(id)
	if not ("file.save" in have):
		_cmd("file.save", _on_save, "global", _has_doc)
	if not ("file.save_as" in have):
		_cmd("file.save_as", _on_save_as, "global", _has_doc)
	if not ("file.save_copy" in have):
		_cmd("file.save_copy", _on_save_copy, "global", _has_doc)
	if not ("file.import" in have):
		_cmd("file.import", _on_import, "global")
	if not ("file.import_folder" in have):
		_cmd("file.import_folder", _on_import_folder, "global")
	if not ("file.new_sequence" in have):
		_cmd("file.new_sequence", _on_new_sequence, "global", _has_doc)
	if not ("file.new_bin" in have):
		_cmd("file.new_bin", _on_new_bin, "global", _has_doc)
	_cmd("seq.settings", open_sequence_settings, "global", _has_doc)
	_cmd("seq.new_from_clip", new_sequence_from_clip, "global", _has_doc)
	_cmd("seq.duplicate", duplicate_sequence, "global", _has_doc)
	if not ("edit.undo" in have):
		_cmd("edit.undo", _on_undo, "global", _can_undo)
	if not ("edit.redo" in have):
		_cmd("edit.redo", _on_redo, "global", _can_redo)


func _register_override(id: String) -> void:
	if id == "file.new_project":
		_cmd(id, _on_new_project)
	elif id == "file.open":
		_cmd(id, _on_open)
	elif id == "file.close":
		_cmd(id, _on_close, "global", _has_doc)
	elif id == "file.quit":
		_cmd(id, _on_quit)


func _on_registry_changed() -> void:
	if _reasserting:
		return
	var stale: PackedStringArray = PackedStringArray()
	for c: Dictionary in Cmd.all():
		var id: String = String(c["id"])
		if id in OVERRIDE_IDS and String(Cmd.get("_commands")[id]["owner"]) != OWNER:
			stale.append(id)
	if stale.is_empty():
		return
	_reasserting = true
	for id: String in stale:
		_register_override(id)
	_reasserting = false


const AUTO_PROXIES_PATH := "res://engine/auto_proxies.gd"


func _on_project_changed() -> void:
	if Session.doc != null:
		Io.reset_autosave(Session.doc)
		if not Session.doc.path.is_empty():
			Io.lock(Session.doc)
		MediaLoader.instance().open_all(Session.doc)
		var auto: Node = load(AUTO_PROXIES_PATH).call("instance")
		if auto != null:
			auto.call("watch", Session.doc)


func _on_autosave_tick() -> void:
	if Session.doc == null:
		return
	if Io.autosave_tick(Session.doc, float(Prefs.get_value(PREF_AUTOSAVE))):
		Events.info("Autosaved a snapshot", Io.snapshot_dir(Session.doc))


func _show_editor(label: String) -> void:
	var main: Node = _main()
	if main != null and main.has_method("show_editor"):
		main.call("show_editor", label)


func _on_home_new(spec: Dictionary) -> void:
	_create_project(spec)


func _on_home_open(path: String) -> void:
	_open_path(path, false)


func _create_project(spec: Dictionary) -> void:
	var name_: String = String(spec.get("name", "Untitled"))
	var tracks: int = clampi(int(spec.get("tracks", 3)), 1, 32)
	var p: Project = Project.create(name_, tracks, tracks, float(spec.get("fps", 30.0)))
	var s: Sequence = p.active_sequence()
	if s != null:
		s.width = int(spec.get("width", 1920))
		s.height = int(spec.get("height", 1080))
		if not s.video_tracks.is_empty():
			s.video_tracks[0].targeted = true
		if not s.audio_tracks.is_empty():
			s.audio_tracks[0].targeted = true
	var folder: String = String(spec.get("folder", ""))
	var path: String = ""
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		path = folder.path_join(_safe(name_) + "." + PROJECT_EXT)
		_remember_folder(folder)
	Session.set_project(p, path)
	_auto_import_instances(p)
	if not path.is_empty():
		var err: Error = Io.save(p, path)
		if err != OK:
			Events.warn("The project was created but not saved", Io.last_error)
	_show_editor(name_)


func _auto_import_instances(p: Project) -> PackedStringArray:
	var Instances: GDScript = load("res://doc/instances.gd")
	var wanted: Array = Instances.call("paths_for_new_project")
	if wanted.is_empty():
		return PackedStringArray()
	var entries: Array[Dictionary] = []
	for w: Dictionary in wanted:
		var it: Dictionary = w.get("item", {})
		entries.append({"path": String(w["path"]), "bin": String(w.get("bin", "")), "label": String(it.get("label", ""))})
	var ids: PackedStringArray = MediaLoader.instance().import_entries(p, entries, "Import library groups")
	if not ids.is_empty():
		Events.toast(str(ids.size()) + (" instance" if ids.size() == 1 else " instances") + " came in from the library")
		p.undo.clear()
		p.dirty = false
	return ids


static func _safe(text: String) -> String:
	var out: String = ""
	for ch: String in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_" or ch == " ":
			out += ch
		else:
			out += "_"
	out = out.strip_edges()
	if out.is_empty():
		out = "project"
	return out


func _open_path(path: String, show: bool) -> void:
	var p: Project = Io.load(path)
	if p == null:
		Events.error("Could not open " + path.get_file(), Io.last_error)
		return
	Session.set_project(p, path)
	Io.remember_recent(path)
	if show or _main() != null and (_main().get("editor") == null):
		_show_editor(p.name)
	Events.toast("Opened " + p.name)
	if not Io.last_warning.is_empty():
		Events.warn("Opened a project from a newer Purrmiere", Io.last_warning)


func _on_new_project() -> void:
	var main: Node = _main()
	if main == null:
		return
	var HomeScreen: GDScript = load("res://ui/editor/home_screen.gd")
	if bool(HomeScreen.call("auto_create")):
		_create_project(HomeScreen.call("default_spec"))
		return
	var answered: Signal = PmUI.form(main, "New project", HomeScreen.call("form_fields"), "Create", "Cancel")
	answered.connect(_on_new_form)


func _on_new_form(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var HomeScreen: GDScript = load("res://ui/editor/home_screen.gd")
	_create_project(HomeScreen.call("spec_from_answer", result))


func _dialog_for(mode: String, title: String) -> FileDialog:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.file_selected.connect(_on_file_picked)
		_dialog.files_selected.connect(_on_files_picked)
		add_child(_dialog)
	_dialog_mode = mode
	_dialog.title = title
	if mode == "open":
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.filters = PackedStringArray(["*." + PROJECT_EXT + " ; Purrmiere project"])
	elif mode == "import":
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.filters = MediaLoader.filters()
	else:
		_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialog.filters = PackedStringArray(["*." + PROJECT_EXT + " ; Purrmiere project"])
		if Session.doc != null:
			_dialog.current_file = _safe(Session.doc.name) + "." + PROJECT_EXT
	return _dialog


func _on_open() -> void:
	_dialog_for("open", "Open project").popup_centered(Vector2i(900, 600))


func _on_file_picked(path: String) -> void:
	if _dialog_mode == "open":
		_open_path(path, true)
	elif _dialog_mode == "save_as":
		_save_to(path, true)
	elif _dialog_mode == "save_copy":
		_save_to(path, false)
	elif _dialog_mode == "import":
		_on_files_picked(PackedStringArray([path]))


func _on_files_picked(paths: PackedStringArray) -> void:
	if _dialog_mode != "import" or Session.doc == null:
		return
	var ids: PackedStringArray = MediaLoader.instance().import_paths(Session.doc, paths, "")
	if not ids.is_empty():
		Events.toast("Imported " + str(ids.size()) + (" item" if ids.size() == 1 else " items"))


func _remember_folder(folder: String) -> void:
	if folder.is_empty():
		return
	if Prefs.is_registered("project.folder") and String(Prefs.get_value("project.folder")) != folder:
		Prefs.set_value("project.folder", folder)


func open_project_path(path: String) -> void:
	_open_path(path, true)


func _on_import() -> void:
	if Session.doc == null:
		var HomeScreen: GDScript = load("res://ui/editor/home_screen.gd")
		_create_project(HomeScreen.call("default_spec"))
	if Session.doc == null:
		return
	_dialog_for("import", "Import media").popup_centered(Vector2i(900, 600))


func _on_import_folder() -> void:
	if Session.doc == null:
		var HomeScreen: GDScript = load("res://ui/editor/home_screen.gd")
		_create_project(HomeScreen.call("default_spec"))
	if Session.doc == null:
		return
	var bin: Object = Bus.instance().panel("bin")
	if bin != null and bin.has_method("_on_import_folder"):
		bin.call("_on_import_folder")
		return
	if _folder_dialog == null:
		_folder_dialog = FileDialog.new()
		_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.use_native_dialog = true
		_folder_dialog.title = "Import a folder"
		_folder_dialog.dir_selected.connect(_on_folder_picked)
		add_child(_folder_dialog)
	_folder_dialog.popup_centered(Vector2i(900, 600))


func _on_folder_picked(path: String) -> void:
	if Session.doc == null:
		return
	var ids: PackedStringArray = MediaLoader.instance().import_folder(Session.doc, path, "")
	if not ids.is_empty():
		Events.toast("Imported " + str(ids.size()) + (" item" if ids.size() == 1 else " items") + " from " + path.get_file())


func _save_to(path: String, adopt: bool) -> void:
	if Session.doc == null:
		return
	var p: String = path
	if p.get_extension().to_lower() != PROJECT_EXT:
		p += "." + PROJECT_EXT
	if adopt:
		var err: Error = Io.save(Session.doc, p)
		if err != OK:
			Events.error("Save failed", Io.last_error)
			return
		Io.lock(Session.doc)
		Io.remember_recent(p)
		_remember_folder(p.get_base_dir())
		if _saver != null:
			_saver.call("after_save")
		Events.toast("Saved " + p.get_file())
	else:
		var old_path: String = Session.doc.path
		var old_dirty: bool = Session.doc.dirty
		var err2: Error = Io.save(Session.doc, p)
		Session.doc.path = old_path
		Session.doc.dirty = old_dirty
		if err2 != OK:
			Events.error("Save a copy failed", Io.last_error)
			return
		Events.toast("Saved a copy to " + p.get_file())


func _on_save() -> void:
	if Session.doc == null:
		return
	if Session.doc.path.is_empty():
		_on_save_as()
		return
	if Io.NewerFiles.is_held(Session.doc.path):
		Events.warn("Save this project under a new name", Io.NewerFiles.refused_text(Session.doc.path))
		_on_save_as()
		return
	_save_to(Session.doc.path, true)


func _on_save_as() -> void:
	if Session.doc == null:
		return
	_dialog_for("save_as", "Save project as").popup_centered(Vector2i(900, 600))


func _on_save_copy() -> void:
	if Session.doc == null:
		return
	_dialog_for("save_copy", "Save a copy").popup_centered(Vector2i(900, 600))


func _on_close() -> void:
	var main: Node = _main()
	_flush_saver()
	if Session.doc != null and Session.doc.dirty and main != null:
		var answered: Signal = PmUI.choose(main, "Close project", Session.doc.name + " has changes that are not saved.", [{"id": "cancel", "label": "Cancel"}, {"id": "discard", "label": "Close without saving"}, {"id": "save", "label": "Save and close", "primary": true}])
		answered.connect(_on_close_answered)
		return
	_close_now()


func _on_close_answered(choice: Variant) -> void:
	var id: String = String(choice)
	if id == "cancel" or id.is_empty() or id == "false":
		return
	if id == "save":
		if not _save_now():
			return
	elif id == "discard" and _saver != null:
		_saver.call("discard", Session.doc)
	_close_now()


func _save_now() -> bool:
	if Session.doc == null:
		return true
	if Session.doc.path.is_empty():
		var folder: String = String(Prefs.get_value("project.folder")) if Prefs.is_registered("project.folder") else ""
		if folder.is_empty():
			folder = Prefs.data_path("Projects")
		DirAccess.make_dir_recursive_absolute(folder)
		var path: String = folder.path_join(_safe(Session.doc.name) + "." + PROJECT_EXT)
		var n: int = 1
		while FileAccess.file_exists(path):
			n += 1
			path = folder.path_join(_safe(Session.doc.name) + " " + str(n) + "." + PROJECT_EXT)
		_save_to(path, true)
	else:
		_save_to(Session.doc.path, true)
	return Session.doc == null or not Session.doc.dirty


func _on_quit() -> void:
	var main: Node = _main()
	if not _quit_confirmed:
		_flush_saver()
	if Session.doc != null and Session.doc.dirty and main != null and not _quit_confirmed:
		var answered: Signal = PmUI.choose(main, "Quit", Session.doc.name + " has changes that are not saved.", [{"id": "cancel", "label": "Cancel"}, {"id": "discard", "label": "Quit without saving"}, {"id": "save", "label": "Save and quit", "primary": true}])
		answered.connect(_on_quit_answered)
		return
	_release_for_exit()
	_guard_exit()
	get_tree().quit()


func _on_quit_answered(choice: Variant) -> void:
	var id: String = String(choice)
	if id == "cancel" or id.is_empty() or id == "false":
		return
	if id == "save" and not _save_now():
		return
	if id == "discard" and _saver != null:
		_saver.call("discard", Session.doc)
	_quit_confirmed = true
	_release_for_exit()
	_guard_exit()
	get_tree().quit()


func _flush_saver() -> void:
	if _saver != null and Session.doc != null:
		_saver.call("flush")


func save_after_edit() -> Node:
	return _saver


func _guard_exit() -> void:
	if PurrBridge.available:
		PurrBridge.arm_exit_guard(EXIT_GUARD_SECONDS)


func _release_for_exit() -> void:
	if Session.doc == null:
		return
	if Session.doc.dirty:
		Io.snapshot(Session.doc)
	Io.unlock(Session.doc)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not get_tree().auto_accept_quit:
			_on_quit()
			return
		_release_for_exit()


func _close_now() -> void:
	if Session.doc != null:
		Io.unlock(Session.doc)
		for id: String in Session.media_handles.keys():
			PurrBridge.close_media(int(Session.media_handles[id]))
		Session.media_handles.clear()
		for rp: String in Session.render_handles.keys():
			PurrBridge.close_media(int(Session.render_handles[rp]))
		Session.render_handles.clear()
		Session.forget_lanes()
	Session.close_project()
	var main: Node = _main()
	if main != null and main.has_method("show_home"):
		main.call("show_home")


func _on_undo() -> void:
	if Session.doc != null:
		Session.doc.undo.undo()


func _on_redo() -> void:
	if Session.doc != null:
		Session.doc.undo.redo()


func _on_new_sequence() -> void:
	var doc: Project = Session.doc
	if doc == null:
		return
	var main: Node = _main()
	if main == null:
		return
	var fields: Array[Dictionary] = []
	fields.append({"key": "name", "label": "Name", "type": "string", "default": "Sequence " + str(doc.sequences.size() + 1)})
	fields.append({"key": "tracks", "label": "Tracks (video and audio)", "type": "int", "default": 3})
	var answered: Signal = PmUI.form(main, "New sequence", fields, "Create", "Cancel")
	answered.connect(_on_new_sequence_form)


func _on_new_sequence_form(result: Variant) -> void:
	var doc: Project = Session.doc
	if doc == null or typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	var label: String = String(r.get("name", "Sequence")).strip_edges()
	if label.is_empty():
		label = "Sequence"
	var n: int = clampi(int(r.get("tracks", 3)), 1, 32)
	var base: Sequence = Session.seq()
	var s: Sequence = Sequence.new()
	s.id = doc.mint_id("s")
	s.label = label
	if base != null:
		s.fps = base.fps
		s.width = base.width
		s.height = base.height
		s.sample_rate = base.sample_rate
	for i: int in n:
		s.video_tracks.append(doc.make_track("video", "V" + str(i + 1)))
		s.audio_tracks.append(doc.make_track("audio", "A" + str(i + 1)))
	s.video_tracks[0].targeted = true
	s.audio_tracks[0].targeted = true
	var media: Dictionary = {"id": doc.mint_id("m"), "kind": "sequence", "label": label, "sequence_id": s.id, "probed": true}
	var cmd: Command = SequenceCmds.AddSequence.new(s.to_dict(), media, -1, true)
	if Verbs.run(doc, "New sequence", [cmd]):
		Session.set_sequence(s.id)


static func size_choice_labels() -> Array:
	var out: Array = []
	for p: Array in EditTools.SIZE_PRESETS:
		out.append(String(p[2]))
	out.append("Custom")
	return out


static func size_index(w: int, h: int) -> int:
	for i: int in EditTools.SIZE_PRESETS.size():
		var p: Array = EditTools.SIZE_PRESETS[i]
		if int(p[0]) == w and int(p[1]) == h:
			return i
	return EditTools.SIZE_PRESETS.size()


static func rate_label(r: float) -> String:
	if absf(r - round(r)) < 0.0005:
		return str(int(round(r)))
	return String.num(r, 3).trim_suffix("0")


func open_sequence_settings() -> void:
	var s: Sequence = Session.seq()
	var main: Node = _main()
	if s == null:
		return
	var host: Node = main if main != null else get_tree().root
	var rates: Array = EditTools.FRAME_RATES.duplicate()
	if not _has_rate(rates, s.fps):
		rates.append(s.fps)
	var rate_names: Array = []
	var rate_at: int = 0
	for i: int in rates.size():
		rate_names.append(rate_label(float(rates[i])))
		if absf(float(rates[i]) - s.fps) < 0.0005:
			rate_at = i
	var samples: Array = EditTools.SAMPLE_RATES.duplicate()
	if not samples.has(s.sample_rate):
		samples.append(s.sample_rate)
	var sample_names: Array = []
	for sr: Variant in samples:
		sample_names.append(str(int(sr)) + " Hz")
	var fields: Array[Dictionary] = []
	fields.append({"key": "name", "label": "Name", "type": "string", "default": s.label})
	fields.append({"key": "size", "label": "Frame size", "type": "enum", "choices": size_choice_labels(), "default": size_index(s.width, s.height)})
	fields.append({"key": "width", "label": "Custom width", "type": "int", "default": s.width})
	fields.append({"key": "height", "label": "Custom height", "type": "int", "default": s.height})
	fields.append({"key": "fps", "label": "Frame rate", "type": "enum", "choices": rate_names, "default": rate_at})
	fields.append({"key": "sample_rate", "label": "Audio sample rate", "type": "enum", "choices": sample_names, "default": maxi(samples.find(s.sample_rate), 0)})
	fields.append({"key": "note", "type": "note", "default": "The custom width and height are used when Frame size is Custom. Clips keep their place in time; a new size changes what fits the frame."})
	fields.append_array(Verbs.mode_fields(s))
	var answered: Signal = PmUI.form(host, "Sequence settings", fields, "Apply", "Cancel")
	answered.connect(_on_sequence_settings_answer.bind(s.id, rates, samples))


static func _has_rate(rates: Array, r: float) -> bool:
	for v: Variant in rates:
		if absf(float(v) - r) < 0.0005:
			return true
	return false


static func settings_from_answer(r: Dictionary, rates: Array, samples: Array) -> Dictionary:
	var out: Dictionary = {"label": String(r.get("name", "")).strip_edges()}
	var size_i: int = int(r.get("size", 0))
	if size_i >= 0 and size_i < EditTools.SIZE_PRESETS.size():
		var p: Array = EditTools.SIZE_PRESETS[size_i]
		out["width"] = int(p[0])
		out["height"] = int(p[1])
	else:
		out["width"] = int(r.get("width", 1920))
		out["height"] = int(r.get("height", 1080))
	out["fps"] = float(rates[clampi(int(r.get("fps", 0)), 0, rates.size() - 1)])
	out["sample_rate"] = int(samples[clampi(int(r.get("sample_rate", 0)), 0, samples.size() - 1)])
	out.merge(Verbs.mode_answer(r))
	return out


func _on_sequence_settings_answer(result: Variant, seq_id: String, rates: Array, samples: Array) -> void:
	var doc: Project = Session.doc
	if doc == null or typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var s: Sequence = doc.sequence_by_id(seq_id)
	if s == null:
		return
	if EditTools.sequence_settings(doc, s, settings_from_answer(result, rates, samples)):
		Session.sequence_changed.emit(s.id)
		Events.toast(s.label + ": " + str(s.width) + " x " + str(s.height) + ", " + rate_label(s.fps) + " fps, " + str(s.sample_rate) + " Hz")
	else:
		Events.toast("Nothing to change")


func new_sequence_from_clip() -> void:
	var doc: Project = Session.doc
	var s: Sequence = Session.seq()
	if doc == null:
		return
	var media_id: String = ""
	var c: Clip = Bus.selected_clip(s)
	if c != null and not c.is_nest():
		media_id = c.media_id
	if media_id.is_empty():
		var bin: Object = Bus.instance().panel("bin")
		var picked: Variant = bin.get("selected_ids") if bin != null else null
		if typeof(picked) == TYPE_PACKED_STRING_ARRAY:
			for id: String in (picked as PackedStringArray):
				var m: MediaItem = doc.media_by_id(id)
				if m != null and m.kind != "sequence":
					media_id = id
					break
	if media_id.is_empty():
		media_id = Bus.instance().source_media_id
	if media_id.is_empty() or doc.media_by_id(media_id) == null:
		Events.toast("Select a clip on the timeline or in the bin first")
		return
	var made: String = EditTools.new_sequence_from_media(doc, media_id, s)
	if made.is_empty():
		Events.toast("A sequence could not be made from that clip")
		return
	Session.set_sequence(made)


func duplicate_sequence() -> void:
	var doc: Project = Session.doc
	var s: Sequence = Session.seq()
	if doc == null or s == null:
		return
	var made: String = EditTools.duplicate_sequence(doc, s)
	if not made.is_empty():
		Session.set_sequence(made)
		Events.toast("Duplicated " + s.label)


func _on_new_bin() -> void:
	var doc: Project = Session.doc
	if doc == null:
		return
	var n: int = doc.bins.size() + 1
	var path: String = "Bin " + str(n)
	while doc.bins.has(path):
		n += 1
		path = "Bin " + str(n)
	Verbs.run(doc, "New bin", [MediaCmds.AddBin.new(path)])


static func sample_project() -> Project:
	var p: Project = Project.create("Ep12", 3, 3, 29.97)
	p.name = "Ep12"
	var s: Sequence = p.active_sequence()
	s.label = "Sequence 01"
	var seq_media: MediaItem = p.media_for_sequence(s.id)
	if seq_media != null:
		seq_media.label = "Sequence 01"
	s.video_tracks[0].targeted = true
	s.audio_tracks[0].targeted = true
	p.bins.append("Camera B")
	var specs: Array = [
		["A-roll_cam1.mp4", "video", 241.0, 3840, 2160, 59.94, true],
		["A-roll_cam1_take2.mp4", "video", 72.0, 3840, 2160, 59.94, true],
		["intro_music.flac", "audio", 201.0, 0, 0, 0.0, true],
		["Lower third - name", "title", 5.0, 1920, 1080, 0.0, false],
		["overlay_logo.png", "image", 5.0, 1024, 1024, 0.0, false],
		["broll_city.mp4", "video", 130.0, 1920, 1080, 29.97, true],
	]
	var ids: PackedStringArray = PackedStringArray()
	for spec: Array in specs:
		var m: MediaItem = MediaItem.new()
		m.id = p.mint_id("m")
		m.label = String(spec[0])
		m.kind = String(spec[1])
		m.duration = float(spec[2])
		m.width = int(spec[3])
		m.height = int(spec[4])
		m.fps = float(spec[5])
		m.has_audio = bool(spec[6])
		m.probed = true
		if m.kind == "video" or m.kind == "audio":
			m.path = "C:/Footage/" + m.label
			m.missing = true
		if m.has_audio:
			m.audio_streams = [{"index": 0, "channels": 2, "sample_rate": 48000, "lang": "", "title": "", "selected": true}]
		p.media.append(m)
		ids.append(m.id)
	Verbs.place_media(p, s, ids[0], s.video_tracks[0].id, 0.0, "overwrite")
	var first: Clip = s.video_tracks[0].clip_at(1.0)
	if first != null:
		Verbs.trim(p, s, first.id, "tail", 12.0, false)
		Verbs.set_clip_param(p, s, first.id, "transform.pos", [0.0, 0.0], 0.0)
		Verbs.set_clip_param(p, s, first.id, "transform.pos", [120.0, -40.0], 5.0)
	Verbs.place_media(p, s, ids[0], s.video_tracks[0].id, 12.0, "overwrite")
	var second: Clip = s.video_tracks[0].clip_at(13.0)
	if second != null:
		Verbs.trim(p, s, second.id, "tail", 24.0, false)
		Verbs.set_transition(p, s, second.id, {"kind": "dissolve", "duration": 1.5, "offset": 0.5})
	s.audio_tracks[0].targeted = false
	s.audio_tracks[1].targeted = true
	Verbs.place_media(p, s, ids[5], s.video_tracks[1].id, 4.0, "overwrite")
	var broll: Clip = s.video_tracks[1].clip_at(5.0)
	if broll != null:
		Verbs.trim(p, s, broll.id, "tail", 12.0, false)
	s.audio_tracks[1].targeted = false
	s.audio_tracks[0].targeted = true
	Verbs.place_media(p, s, ids[3], s.video_tracks[2].id, 13.0, "overwrite")
	Verbs.place_media(p, s, ids[4], s.video_tracks[2].id, 22.0, "overwrite")
	Verbs.place_media(p, s, ids[2], s.audio_tracks[2].id, 0.0, "overwrite")
	var music: Clip = s.audio_tracks[2].clip_at(1.0)
	if music != null:
		Verbs.trim(p, s, music.id, "tail", 30.0, false)
	Verbs.pin_track(p, s, s.audio_tracks[2].id, true)
	Verbs.add_marker_at(p, s, 6.0)
	Verbs.set_in(p, s, 2.0)
	Verbs.set_out(p, s, 24.0)
	s.playhead = 4.4
	if first != null:
		Verbs.select(p, s, PackedStringArray([first.id]), "replace")
	var shot_time: String = OS.get_environment("PM_SHOT_TIME")
	if not shot_time.is_empty():
		s.playhead = float(shot_time)
	var shot_effect: String = OS.get_environment("PM_SHOT_EFFECT")
	if not shot_effect.is_empty() and first != null:
		var EffectRegistry: GDScript = load("res://engine/effect_registry.gd")
		var reg: RefCounted = EffectRegistry.call("shared")
		var def: Dictionary = reg.call("get_def", shot_effect)
		if not def.is_empty():
			Verbs.add_effect(p, s, PackedStringArray([first.id]), def)
	var shot_select: String = OS.get_environment("PM_SHOT_SELECT")
	if not shot_select.is_empty():
		for c: Clip in s.all_clips():
			var mm: MediaItem = p.media_by_id(c.media_id)
			if mm != null and (mm.kind == shot_select or c.label == shot_select or mm.label == shot_select):
				Verbs.select(p, s, PackedStringArray([c.id]), "replace")
				break
	var shot_tr: String = OS.get_environment("PM_SHOT_TRANSITION")
	if not shot_tr.is_empty() and second != null:
		var treg: RefCounted = load("res://engine/transition_registry.gd").call("shared")
		Verbs.set_transition(p, s, second.id, treg.call("make_spec", shot_tr, 1.5, 0.5))
		Verbs.set_transition_out(p, s, second.id, treg.call("make_spec", "fade", 2.0, 1.0))
		Verbs.select(p, s, PackedStringArray([second.id]), "replace")
	p.undo.clear()
	p.dirty = false
	return p
