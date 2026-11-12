extends RefCounted
## File > Import Captions and Export Captions (SRT, WebVTT, ASS), and caption files dropped on the window.

const Captions := preload("res://doc/captions.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const IMPORT_CMD := "file.import_captions"
const EXPORT_CMD := "file.export_captions"
const SELF_PATH := "res://modules/core_panels/captions_ui.gd"


static func install() -> void:
	var script: GDScript = load(SELF_PATH)
	Cmd.register(IMPORT_CMD, {"label": "Import Captions...", "category": "File", "scope": "global", "handler": Callable(script, "ask_import"), "owner": "core_panels", "enabled": Callable(Bus, "has_doc_static")})
	Cmd.register(EXPORT_CMD, {"label": "Export Captions...", "category": "File", "scope": "global", "handler": Callable(script, "ask_export"), "owner": "core_panels", "enabled": Callable(Bus, "has_doc_static")})


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


static func _dialog(mode: FileDialog.FileMode, title: String) -> FileDialog:
	var dlg: FileDialog = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = mode
	dlg.filters = Captions.FILTERS
	dlg.title = title
	dlg.canceled.connect(dlg.queue_free)
	_root().add_child(dlg)
	return dlg


static func ask_import() -> void:
	if Session.doc == null or Session.seq() == null:
		Events.toast("Open a project first")
		return
	var dlg: FileDialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, "Import captions")
	dlg.file_selected.connect(func(p: String) -> void:
		import_path(p)
		dlg.queue_free())
	dlg.popup_centered_ratio(0.6)


## Places the file's captions starting at the playhead.
static func import_path(path: String) -> int:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return 0
	var made: PackedStringArray = Captions.import_file(d, s, path, s.playhead)
	if made.is_empty():
		Events.warn("No captions found in " + path.get_file(), "It should be an SRT, WebVTT or ASS file with timed lines.")
	else:
		Events.toast("Placed " + str(made.size()) + " captions from " + path.get_file())
	return made.size()


static func ask_export() -> void:
	if Session.doc == null or Session.seq() == null:
		Events.toast("Open a project first")
		return
	var dlg: FileDialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export captions")
	dlg.current_file = Session.seq().label + ".srt"
	dlg.file_selected.connect(func(p: String) -> void:
		var path: String = p if Captions.is_caption_file(p) else p + ".srt"
		var n: int = Captions.export_file(Session.doc, Session.seq(), path)
		if n < 0:
			Events.warn("Could not write " + path.get_file(), path)
		elif n == 0:
			Events.toast("There were no text boxes to write; the file is empty")
		else:
			Events.toast("Wrote " + str(n) + " captions to " + path.get_file())
		dlg.queue_free())
	dlg.popup_centered_ratio(0.6)
