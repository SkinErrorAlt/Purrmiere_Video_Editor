extends "res://modules/core_panels/panel_base.gd"

const Instances := preload("res://doc/instances.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const ROW_H := 28.0
const KIND_ICONS: Dictionary = {"video": "film", "audio": "audio", "image": "image", "gif": "image", "font": "type", "text": "type", "preset": "fx", "sequence": "seq", "other": "grid"}

var search: String = ""
var tag_filter: String = ""
var kind_filter: String = ""
var _search: LineEdit = null
var _tags: Button = null
var _kinds: Button = null
var _list: VBoxContainer = null
var _status: Label = null
var _dialog: FileDialog = null
var _folder_dialog: FileDialog = null
var _thumb_dialog: FileDialog = null
var _thumb_target: String = ""
var _press_pos: Vector2 = Vector2.ZERO
var _press_id: String = ""
var _thumbs: Dictionary = {}
var _pending_group: String = ""
var _shot_done: bool = false


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	_kinds = PmDrop.make_drop([PmDrop.choice("all", "Every kind")], "all")
	_kinds.connect("changed", _on_kind)
	head.add_child(_kinds)
	_tags = PmDrop.make_drop([PmDrop.choice("all", "Any tag")], "all")
	_tags.connect("changed", _on_tag)
	head.add_child(_tags)
	var add: Button = PmButton.make("Add files", "import")
	add.set("icon_px", 14.0)
	PmUI.tip(add, "Add files to the library, right click for a folder")
	add.pressed.connect(_on_add_files)
	add.gui_input.connect(_on_add_input.bind(add))
	head.add_child(add)
	var ng: Button = quiet_icon("folder_new", "New group")
	ng.pressed.connect(_on_new_group)
	head.add_child(ng)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(PmUI.divider())
	_status = PmLabel.dim("")
	col.add_child(PmUI.inset(_status))
	_shot_library()
	rebuild()


func _shot_library() -> void:
	if _shot_done or OS.get_environment("PM_SHOT_LIBRARY") != "sample" or doc() == null:
		return
	_shot_done = true
	Instances.use_path(ProjectSettings.globalize_path("user://shot_library/library.json"))
	Instances.reread()
	for it: Dictionary in (Instances.items() as Array).duplicate():
		Instances.remove(String(it["id"]))
	for g: Dictionary in (Instances.groups() as Array).duplicate():
		Instances.remove_group(String(g["id"]), false)
	var d: Project = doc()
	if d == null:
		return
	var reactions: Dictionary = Instances.add_group("Reactions", true)
	var music: Dictionary = Instances.add_group("Music", false)
	var laughs: Dictionary = Instances.add_group("Laughs", false, String(reactions["id"]))
	var i: int = 0
	for m: MediaItem in d.media:
		if m.path.is_empty():
			continue
		var group: String = ""
		var tags: PackedStringArray = PackedStringArray()
		if m.kind == "audio":
			group = String(music["id"])
			tags.append("bed")
		elif m.kind == "image":
			group = String(reactions["id"])
			tags.append("overlay")
		elif i % 2 == 0:
			group = String(laughs["id"])
			tags.append_array(PackedStringArray(["laugh", "edgy"]))
		else:
			tags.append("cam")
		var it: Dictionary = Instances.add_path(m.path, group, tags)
		if not it.is_empty():
			Instances.set_field(String(it["id"]), "label", m.label.get_basename())
		i += 1


func _on_search(text: String) -> void:
	search = text.strip_edges()
	rebuild()


func _on_kind(id: String) -> void:
	kind_filter = "" if id == "all" else id
	rebuild()


func _on_tag(id: String) -> void:
	tag_filter = "" if id == "all" else id
	rebuild()


func _filtered() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in Instances.search(search):
		if not kind_filter.is_empty() and String(it.get("kind", "")) != kind_filter:
			continue
		if not tag_filter.is_empty() and not (it.get("tags", []) as Array).has(tag_filter):
			continue
		out.append(it)
	return out


func rebuild() -> void:
	if not _alive():
		return
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var tag_choices: Array = [PmDrop.choice("all", "Any tag")]
	for t: String in Instances.all_tags():
		tag_choices.append(PmDrop.choice(t, t))
	_tags.call("set_choices", tag_choices)
	_tags.call("set_value", tag_filter if Instances.all_tags().has(tag_filter) else "all", false)
	var kind_choices: Array = [PmDrop.choice("all", "Every kind")]
	for k: String in Instances.KINDS:
		kind_choices.append(PmDrop.choice(k, k.capitalize()))
	_kinds.call("set_choices", kind_choices)
	_kinds.call("set_value", kind_filter if not kind_filter.is_empty() else "all", false)
	var items: Array[Dictionary] = _filtered()
	var by_group: Dictionary = {}
	for it: Dictionary in items:
		var g: String = String(it.get("group", ""))
		if not by_group.has(g):
			by_group[g] = []
		(by_group[g] as Array).append(it)
	var shown: int = 0
	for g: Dictionary in Instances.groups():
		if String(g.get("parent", "")).is_empty():
			shown += _build_group(_list, g, by_group, 0)
	if by_group.has(""):
		var loose: Array = by_group[""]
		var f: VBoxContainer = PmFold.make("Ungrouped  (" + str(loose.size()) + ")", "instances.ungrouped", true)
		var body: VBoxContainer = f.get("body")
		for it: Dictionary in loose:
			body.add_child(_make_row(it))
			shown += 1
		_list.add_child(f)
	if Instances.items().is_empty():
		_list.add_child(PmLabel.wrap("The library is empty. Add files or a folder, then label, tag and group them. Groups marked with the paw come into every new project.", "text_dim"))
	var total: int = Instances.items().size()
	_status.text = str(shown) + " of " + str(total) + (" instance" if total == 1 else " instances") + ", " + str(Instances.groups().size()) + (" group" if Instances.groups().size() == 1 else " groups")


func _build_group(parent: VBoxContainer, g: Dictionary, by_group: Dictionary, depth: int) -> int:
	var gid: String = String(g.get("id", ""))
	var own: Array = by_group.get(gid, [])
	var count: int = Instances.by_group(gid, true).size()
	var f: VBoxContainer = PmFold.make(String(g.get("name", "")) + "  (" + str(count) + ")", "instances.g." + gid, true)
	var header: Button = f.get("header")
	header.set_meta("group_id", gid)
	header.gui_input.connect(_on_group_header_input.bind(gid, header))
	var auto: Button = toggle_icon("paw", "Import this group into every new project", bool(g.get("auto_import", false)))
	auto.pressed.connect(_on_auto_toggle.bind(gid))
	f.call("add_right", auto)
	var imp: Button = PmButton.make("Import")
	imp.set("quiet", true)
	PmUI.tip(imp, "Import everything in this group into the open project")
	imp.pressed.connect(_on_import_group.bind(gid))
	f.call("add_right", imp)
	var more: Button = quiet_icon("more", "Group menu")
	more.pressed.connect(_on_group_menu.bind(gid, more))
	f.call("add_right", more)
	var body: VBoxContainer = f.get("body")
	if depth > 0:
		var wrap: HBoxContainer = PmUI.hbox(0)
		wrap.add_child(_spacer(float(Tk.px(12.0))))
		wrap.add_child(f)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(wrap)
	else:
		parent.add_child(f)
	var shown: int = 0
	for child: Dictionary in Instances.groups():
		if String(child.get("parent", "")) == gid:
			shown += _build_group(body, child, by_group, depth + 1)
	for it: Dictionary in own:
		body.add_child(_make_row(it))
		shown += 1
	return shown


func _spacer(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _make_row(it: Dictionary) -> Control:
	var id: String = String(it.get("id", ""))
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(ROW_H)))
	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = Vector2(float(Tk.px(40.0)), float(Tk.px(ROW_H)) - 4.0)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = _thumb_for(it)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thumb)
	var icon: Control = PmIcon.make(String(KIND_ICONS.get(String(it.get("kind", "other")), "grid")), 14.0)
	row.add_child(icon)
	var b: Button = PmButton.make(String(it.get("label", "")))
	b.set("quiet", true)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("instance_id", id)
	b.gui_input.connect(_on_row_input.bind(id, b))
	PmUI.tip(b, String(it.get("path", "")) + "\nDouble click imports it into the project, drag it onto the bin or the timeline, right click for more")
	row.add_child(b)
	var tags: Array = it.get("tags", [])
	if not tags.is_empty():
		var tl: Label = PmLabel.dim(", ".join(PackedStringArray(tags)))
		row.add_child(tl)
	if Instances.missing(it):
		var miss: Label = PmLabel.tight("missing", "text_dim")
		row.add_child(miss)
	row.add_child(PmUI.spacer())
	var more: Button = quiet_icon("more", "Instance menu")
	more.pressed.connect(_open_item_menu.bind(id, more))
	row.add_child(more)
	return row


func _thumb_for(it: Dictionary) -> Texture2D:
	var id: String = String(it.get("id", ""))
	if _thumbs.has(id):
		return _thumbs[id]
	var tex: Texture2D = null
	var thumb_path: String = String(it.get("thumb", ""))
	var kind: String = String(it.get("kind", ""))
	var src: String = thumb_path if not thumb_path.is_empty() else (String(it.get("path", "")) if kind == "image" else "")
	if not src.is_empty() and FileAccess.file_exists(src):
		var img: Image = Image.new()
		if img.load(src) == OK:
			var w: int = img.get_width()
			var h: int = img.get_height()
			if w > 160:
				img.resize(160, maxi(int(float(h) * 160.0 / float(w)), 1), Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
	_thumbs[id] = tex
	return tex


func _on_row_input(event: InputEvent, id: String, anchor: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			anchor.accept_event()
			_open_item_menu(id, anchor)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					import_items(PackedStringArray([id]))
					return
				_press_pos = mb.position
				_press_id = id
			else:
				_press_id = ""
		return
	if event is InputEventMouseMotion and _press_id == id:
		if ((event as InputEventMouseMotion).position - _press_pos).length() >= float(Tk.px(4.0)):
			_press_id = ""
			begin_drag(PackedStringArray([id]))


func begin_drag(ids: PackedStringArray) -> void:
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return
	var paths: Array = []
	var label: String = ""
	for id: String in ids:
		var it: Dictionary = Instances.item_by_id(id)
		if it.is_empty():
			continue
		paths.append(String(it["path"]))
		if label.is_empty():
			label = String(it.get("label", ""))
	if paths.is_empty():
		return
	if paths.size() > 1:
		label += " and " + str(paths.size() - 1) + " more"
	var ghost: Label = PmLabel.tight(label, "text_bright")
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	card.add_child(ghost)
	layer.call("begin", {"kind": "files", "paths": paths}, card, Vector2(10.0, 10.0))


func _open_item_menu(id: String, anchor: Control) -> void:
	var it: Dictionary = Instances.item_by_id(id)
	if it.is_empty():
		return
	var groups_sub: Array = [PmMenu.check_item("group:", "None", String(it.get("group", "")).is_empty())]
	for g: Dictionary in Instances.groups():
		groups_sub.append(PmMenu.check_item("group:" + String(g["id"]), Instances.group_path(String(g["id"])), String(it.get("group", "")) == String(g["id"])))
	groups_sub.append(PmMenu.separator())
	groups_sub.append(PmMenu.item("group_new", "New group"))
	var items: Array = []
	if Instances.importable(String(it.get("kind", ""))):
		items.append(PmMenu.item("import", "Import into the project", "double click", "import"))
		items.append(PmMenu.item("source", "Show in Source"))
		items.append(PmMenu.separator())
	items.append(PmMenu.item("rename", "Rename"))
	items.append(PmMenu.item("tags", "Tags"))
	items.append(PmMenu.sub_item("group", "Group", groups_sub, "folder"))
	items.append(PmMenu.item("thumb", "Set thumbnail", "", "image"))
	if not String(it.get("thumb", "")).is_empty():
		items.append(PmMenu.item("thumb_clear", "Use the default thumbnail"))
	items.append(PmMenu.item("reveal", "Show file location"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("remove", "Remove from the library", "", "trash"))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_item_menu.bind(id))


func _on_item_menu(pick: String, id: String) -> void:
	var it: Dictionary = Instances.item_by_id(id)
	if it.is_empty():
		return
	if pick == "import":
		import_items(PackedStringArray([id]))
	elif pick == "source":
		var ids: PackedStringArray = import_items(PackedStringArray([id]))
		if not ids.is_empty():
			bus().request_source(ids[0])
	elif pick == "rename":
		var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": String(it.get("label", ""))}]
		PmUI.form(_root, "Rename instance", fields, "Rename", "Cancel").connect(_on_rename_answered.bind(id))
	elif pick == "tags":
		var fields2: Array[Dictionary] = [{"key": "tags", "label": "Tags (comma separated)", "type": "string", "default": ", ".join(PackedStringArray(it.get("tags", [])))}]
		PmUI.form(_root, "Tags for " + String(it.get("label", "")), fields2, "Apply", "Cancel").connect(_on_tags_answered.bind(id))
	elif pick.begins_with("group:"):
		Instances.set_field(id, "group", pick.substr(6))
		rebuild()
	elif pick == "group_new":
		_pending_group = id
		_on_new_group()
	elif pick == "thumb":
		_thumb_target = id
		_open_thumb_dialog()
	elif pick == "thumb_clear":
		Instances.set_field(id, "thumb", "")
		_thumbs.erase(id)
		rebuild()
	elif pick == "reveal":
		OS.shell_show_in_file_manager(String(it.get("path", "")))
	elif pick == "remove":
		Instances.remove(id)
		_thumbs.erase(id)
		rebuild()


func _on_rename_answered(result: Variant, id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var label: String = String((result as Dictionary).get("label", "")).strip_edges()
	if not label.is_empty():
		Instances.set_field(id, "label", label)
		rebuild()


func _on_tags_answered(result: Variant, id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var raw: String = String((result as Dictionary).get("tags", ""))
	var tags: Array = []
	for part: String in raw.split(","):
		var t: String = part.strip_edges()
		if not t.is_empty():
			tags.append(t)
	Instances.set_field(id, "tags", tags)
	rebuild()


func _on_group_header_input(event: InputEvent, gid: String, anchor: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		anchor.accept_event()
		_on_group_menu(gid, anchor)


func _on_group_menu(gid: String, anchor: Control) -> void:
	var g: Dictionary = Instances.group_by_id(gid)
	if g.is_empty():
		return
	var parents: Array = [PmMenu.check_item("parent:", "Top level", String(g.get("parent", "")).is_empty())]
	for other: Dictionary in Instances.groups():
		var oid: String = String(other["id"])
		if oid == gid or Instances.group_path(oid).begins_with(Instances.group_path(gid) + "/"):
			continue
		parents.append(PmMenu.check_item("parent:" + oid, Instances.group_path(oid), String(g.get("parent", "")) == oid))
	var items: Array = [
		PmMenu.item("import", "Import this group into the project", "", "import"),
		PmMenu.check_item("auto", "Import into every new project", bool(g.get("auto_import", false))),
		PmMenu.separator(),
		PmMenu.item("add_files", "Add files to this group"),
		PmMenu.item("add_folder", "Add a folder to this group"),
		PmMenu.item("rename", "Rename group"),
		PmMenu.sub_item("parent", "Inside", parents, "folder"),
		PmMenu.separator(),
		PmMenu.item("remove", "Remove group, keep its instances", "", "trash"),
		PmMenu.item("remove_all", "Remove group and its instances", "", "trash"),
	]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_group_pick.bind(gid))


func _on_group_pick(pick: String, gid: String) -> void:
	if pick == "import":
		_on_import_group(gid)
	elif pick == "auto":
		_on_auto_toggle(gid)
	elif pick == "add_files":
		_pending_group = "group:" + gid
		_on_add_files()
	elif pick == "add_folder":
		_pending_group = "group:" + gid
		_on_add_folder()
	elif pick == "rename":
		var g: Dictionary = Instances.group_by_id(gid)
		var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": String(g.get("name", ""))}]
		PmUI.form(_root, "Rename group", fields, "Rename", "Cancel").connect(_on_group_rename_answered.bind(gid))
	elif pick.begins_with("parent:"):
		Instances.set_group_field(gid, "parent", pick.substr(7))
		rebuild()
	elif pick == "remove":
		Instances.remove_group(gid, true)
		rebuild()
	elif pick == "remove_all":
		Instances.remove_group(gid, false)
		_thumbs.clear()
		rebuild()


func _on_group_rename_answered(result: Variant, gid: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var name_: String = String((result as Dictionary).get("name", "")).strip_edges()
	if not name_.is_empty():
		Instances.set_group_field(gid, "name", name_)
		rebuild()


func _on_auto_toggle(gid: String) -> void:
	var g: Dictionary = Instances.group_by_id(gid)
	if g.is_empty():
		return
	Instances.set_group_field(gid, "auto_import", not bool(g.get("auto_import", false)))
	rebuild()


func _on_new_group() -> void:
	var fields: Array[Dictionary] = [{"key": "name", "label": "Group name", "type": "string", "default": ""}, {"key": "auto", "label": "Import into every new project", "type": "bool", "default": false}]
	PmUI.form(_root, "New group", fields, "Create", "Cancel").connect(_on_new_group_answered)


func _on_new_group_answered(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		_pending_group = ""
		return
	var r: Dictionary = result
	var g: Dictionary = Instances.add_group(String(r.get("name", "")), bool(r.get("auto", false)))
	if not g.is_empty() and not _pending_group.is_empty() and not _pending_group.begins_with("group:"):
		Instances.set_field(_pending_group, "group", String(g["id"]))
	_pending_group = ""
	rebuild()


func _target_group() -> String:
	if _pending_group.begins_with("group:"):
		return _pending_group.substr(6)
	return ""


func _on_add_input(event: InputEvent, anchor: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		anchor.accept_event()
		var items: Array = [PmMenu.item("files", "Add files", "", "import"), PmMenu.item("folder", "Add a folder and its subfolders", "", "folder"), PmMenu.item("project", "Add everything in the open project's bin")]
		var m: Control = PmMenu.open(anchor, items)
		if m != null and m.is_inside_tree():
			m.connect("picked", _on_add_pick)


func _on_add_pick(pick: String) -> void:
	if pick == "files":
		_on_add_files()
	elif pick == "folder":
		_on_add_folder()
	elif pick == "project":
		add_project_media()


func add_project_media() -> PackedStringArray:
	var d: Project = doc()
	var out: PackedStringArray = PackedStringArray()
	if d == null:
		return out
	for m: MediaItem in d.media:
		if m.path.is_empty() or not FileAccess.file_exists(m.path):
			continue
		var it: Dictionary = Instances.add_path(m.path)
		if it.is_empty():
			continue
		if String(it.get("label", "")) != m.label and not m.label.is_empty() and String(it.get("label", "")) == m.path.get_file().get_basename():
			Instances.set_field(String(it["id"]), "label", m.label)
		out.append(String(it["id"]))
	rebuild()
	Events.toast("Added " + str(out.size()) + (" instance" if out.size() == 1 else " instances") + " from the project")
	return out


func _on_add_files() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.use_native_dialog = true
		_dialog.title = "Add to the library"
		_dialog.files_selected.connect(add_files)
		_dialog.file_selected.connect(func(p: String) -> void: add_files(PackedStringArray([p])))
		_dialog.canceled.connect(func() -> void: _pending_group = "")
		_root.add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func add_files(paths: PackedStringArray) -> PackedStringArray:
	var ids: PackedStringArray = Instances.add_paths(paths, _target_group())
	_pending_group = ""
	rebuild()
	return ids


func _on_add_folder() -> void:
	if _folder_dialog == null:
		_folder_dialog = FileDialog.new()
		_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.use_native_dialog = true
		_folder_dialog.title = "Add a folder to the library"
		_folder_dialog.dir_selected.connect(add_folder)
		_folder_dialog.canceled.connect(func() -> void: _pending_group = "")
		_root.add_child(_folder_dialog)
	_folder_dialog.popup_centered(Vector2i(900, 600))


func add_folder(folder: String) -> PackedStringArray:
	var group: String = _target_group()
	if group.is_empty():
		var name_: String = folder.get_file() if not folder.get_file().is_empty() else folder.trim_suffix("/").get_file()
		var g: Dictionary = Instances.add_group(name_)
		group = String(g.get("id", ""))
	var ids: PackedStringArray = Instances.add_folder(folder, group)
	_pending_group = ""
	rebuild()
	Events.toast("Added " + str(ids.size()) + (" instance" if ids.size() == 1 else " instances") + " from " + folder.get_file())
	return ids


func _open_thumb_dialog() -> void:
	if _thumb_dialog == null:
		_thumb_dialog = FileDialog.new()
		_thumb_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_thumb_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_thumb_dialog.use_native_dialog = true
		_thumb_dialog.title = "Pick a thumbnail picture"
		_thumb_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
		_thumb_dialog.file_selected.connect(_on_thumb_picked)
		_root.add_child(_thumb_dialog)
	_thumb_dialog.popup_centered(Vector2i(900, 600))


func _on_thumb_picked(path: String) -> void:
	if _thumb_target.is_empty():
		return
	Instances.set_field(_thumb_target, "thumb", path)
	_thumbs.erase(_thumb_target)
	_thumb_target = ""
	rebuild()


func _bin_folder() -> String:
	var bin: Object = bus().panel("bin")
	if bin != null:
		return String(bin.get("folder"))
	return ""


func import_items(ids: PackedStringArray, bin: String = "") -> PackedStringArray:
	var d: Project = doc()
	if d == null:
		Events.toast("Open a project first")
		return PackedStringArray()
	var list: Array[Dictionary] = []
	for id: String in ids:
		var it: Dictionary = Instances.item_by_id(id)
		if not it.is_empty():
			list.append(it)
	var entries: Array[Dictionary] = Instances.entries_for(list, bin if not bin.is_empty() else _bin_folder())
	if entries.is_empty():
		Events.toast("Nothing importable in that selection")
		return PackedStringArray()
	var label: String = "Import " + (String(entries[0].get("label", "instance")) if entries.size() == 1 else str(entries.size()) + " instances")
	var out: PackedStringArray = MediaLoader.instance().import_entries(d, entries, label)
	var bin_panel: Object = bus().panel("bin")
	if bin_panel != null and not out.is_empty():
		bin_panel.set("selected_ids", out.duplicate())
		bin_panel.call("refresh")
	return out


func import_group(gid: String) -> PackedStringArray:
	var g: Dictionary = Instances.group_by_id(gid)
	if g.is_empty():
		return PackedStringArray()
	var ids: PackedStringArray = PackedStringArray()
	for it: Dictionary in Instances.by_group(gid, true):
		ids.append(String(it["id"]))
	var bin: String = _bin_folder()
	var name_: String = String(g.get("name", "Group"))
	return import_items(ids, (bin + "/" + name_) if not bin.is_empty() else name_)


func import_tag(tag: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for it: Dictionary in Instances.by_tag(tag):
		ids.append(String(it["id"]))
	var bin: String = _bin_folder()
	return import_items(ids, (bin + "/" + tag) if not bin.is_empty() else tag)


func _on_import_group(gid: String) -> void:
	var out: PackedStringArray = import_group(gid)
	if not out.is_empty():
		Events.toast("Imported " + str(out.size()) + (" item" if out.size() == 1 else " items"))


func _on_project_changed() -> void:
	_shot_library()
	rebuild()


func save_state() -> Dictionary:
	return {"search": search, "tag": tag_filter, "kind": kind_filter}


func restore_state(d: Dictionary) -> void:
	search = String(d.get("search", ""))
	tag_filter = String(d.get("tag", ""))
	kind_filter = String(d.get("kind", ""))
	if _search != null:
		_search.text = search
	rebuild()
