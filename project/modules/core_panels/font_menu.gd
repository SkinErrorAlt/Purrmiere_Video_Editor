extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const FontLibrary := preload("res://doc/font_library.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const DEFAULT_ID := "font:default"
const PICK := "font:pick:"
const IMPORT_USER := "font:import_user"
const IMPORT_PROJECT := "font:import_project"
const COLLECT := "font:collect"
const BUILT_IN := "Figtree (built in)"
const FILTERS: PackedStringArray = ["*.ttf, *.otf, *.woff, *.woff2 ; Font files"]

static var last_note: String = ""


static func owns(id: String) -> bool:
	return id.begins_with("font:")


static func font_of(doc: Project, c: Clip) -> String:
	if c == null:
		return ""
	var v: Variant = FontLibrary.plain(c.props.get("font", null))
	if v is String:
		return String(v)
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	var mv: Variant = FontLibrary.plain(m.props.get("font", "")) if m != null else ""
	return String(mv) if mv is String else ""


static func shown_name(name_: String) -> String:
	if name_.is_empty():
		return BUILT_IN
	if FontLibrary.is_token(name_):
		return FontLibrary.file_of(name_).get_basename()
	return name_


static func items(doc: Project, current: String) -> Array:
	var out: Array = [PmMenu.check_item(DEFAULT_ID, BUILT_IN, current.is_empty())]
	var lib: Array[Dictionary] = FontLibrary.listing(doc)
	for f: Dictionary in lib:
		var tag: String = "  (this project)" if String(f["scope"]) == FontLibrary.SCOPE_PROJECT else ""
		out.append(PmMenu.check_item(PICK + String(f["token"]), String(f["label"]) + tag, String(f["token"]) == current))
	if not current.is_empty() and not FontLibrary.is_token(current):
		out.append(PmMenu.check_item(PICK + current, current, true))
	out.append(PmMenu.separator())
	out.append(PmMenu.item(IMPORT_USER, "Import a font file for every project"))
	var proj: Dictionary = PmMenu.item(IMPORT_PROJECT, "Import a font file for this project only")
	proj["disabled"] = doc == null or doc.path.is_empty()
	out.append(proj)
	var collect: Dictionary = PmMenu.item(COLLECT, "Copy the fonts this project uses into its folder")
	collect["disabled"] = doc == null or doc.path.is_empty() or FontLibrary.used(doc).is_empty()
	out.append(collect)
	return out


static func set_font(doc: Project, seq: Sequence, clip_id: String, name_: String) -> bool:
	if doc == null or seq == null:
		return false
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null:
		return false
	var cur: Variant = c.props.get("font")
	var keyed: bool = cur is Dictionary and AnimProp.is_animated(cur)
	return Verbs.set_clip_param(doc, seq, clip_id, "props.font", name_, seq.playhead if keyed else -1.0)


static func import_and_use(doc: Project, seq: Sequence, clip_id: String, path: String, scope: String) -> bool:
	var token: String = FontLibrary.import_font(path, scope, doc)
	if token.is_empty():
		last_note = FontLibrary.last_error
		return false
	last_note = "Imported " + FontLibrary.file_of(token)
	return set_font(doc, seq, clip_id, token)


static func on_pick(host: Control, doc: Project, seq: Sequence, clip_id: String, picked: String) -> bool:
	if not owns(picked):
		return false
	if picked == DEFAULT_ID:
		set_font(doc, seq, clip_id, "")
	elif picked.begins_with(PICK):
		set_font(doc, seq, clip_id, picked.substr(PICK.length()))
	elif picked == IMPORT_USER or picked == IMPORT_PROJECT:
		var scope: String = FontLibrary.SCOPE_PROJECT if picked == IMPORT_PROJECT else FontLibrary.SCOPE_USER
		ask_file(host, "Import a font", func(path: String) -> void: import_and_use(doc, seq, clip_id, path, scope))
	elif picked == COLLECT:
		var copied: PackedStringArray = FontLibrary.collect(doc)
		last_note = ("Copied %d fonts into the project folder" % copied.size()) if FontLibrary.last_error.is_empty() else FontLibrary.last_error
	return true


static func ask_file(host: Control, title: String, done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var dlg: FileDialog = FileDialog.new()
	dlg.title = title
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.filters = FILTERS
	dlg.use_native_dialog = true
	host.get_tree().root.add_child(dlg)
	dlg.file_selected.connect(func(path: String) -> void: _picked_file(dlg, path, done))
	dlg.canceled.connect(func() -> void: _drop_dialog(dlg))
	dlg.popup_centered_ratio(0.6)


static func _picked_file(dlg: FileDialog, path: String, done: Callable) -> void:
	_drop_dialog(dlg)
	done.call(path)


static func _drop_dialog(dlg: FileDialog) -> void:
	if dlg != null and is_instance_valid(dlg) and dlg.get_parent() != null:
		dlg.get_parent().remove_child(dlg)
		dlg.queue_free()


static func missing_note(doc: Project, c: Clip) -> String:
	var name_: String = font_of(doc, c)
	if not FontLibrary.is_token(name_) or not FontLibrary.path_of(name_, doc).is_empty():
		return ""
	return "This text uses the font %s, which is not on this computer, so it shows in the built in font until you find the file." % FontLibrary.file_of(name_)


static func relink_with(doc: Project, c: Clip, path: String) -> bool:
	var name_: String = font_of(doc, c)
	if not FontLibrary.is_token(name_):
		return false
	var ok: bool = FontLibrary.relink(name_, path, doc)
	last_note = ("Found " + FontLibrary.file_of(name_)) if ok else FontLibrary.last_error
	if ok and doc != null:
		doc.changed.emit("meta")
	return ok
