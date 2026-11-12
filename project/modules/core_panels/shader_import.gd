extends RefCounted

const Convert := preload("res://engine/gdshader_convert.gd")
const ImportedShaders := preload("res://doc/imported_shaders.gd")
const ShaderCmds := preload("res://doc/commands/shader_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const Verbs := preload("res://doc/verbs.gd")
const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/shader_import.gd"
const SHEET_PATH := "res://modules/core_panels/shader_sheet.gd"
const SAVE_SHEET_PATH := "res://modules/core_panels/shader_save_sheet.gd"
const EXTENSIONS: PackedStringArray = ["gdshader", "shader"]
const MENU_FILE := "shader_import_file"
const MENU_PASTE := "shader_import_paste"
const ITEM_SAVE := "shader_save_library"
const ITEM_EDIT := "shader_edit_code"
const BIN_PICK_PREFIX := "bin_pick:"
const PICTURE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "tga", "exr", "hdr", "svg"]
const LIBRARY_SHADER := "effect.gdshader"
const LIBRARY_DEF := "effect.json"
const PASTED := "Pasted shader"

static var _dialog: FileDialog = null
static var _dialog_targets: PackedStringArray = PackedStringArray()


static func is_shader_file(path: String) -> bool:
	return EXTENSIONS.has(path.get_extension().to_lower())


static func split_files(files: PackedStringArray) -> Dictionary:
	var shaders: PackedStringArray = PackedStringArray()
	var rest: PackedStringArray = PackedStringArray()
	for f: String in files:
		if is_shader_file(f):
			shaders.append(f)
		else:
			rest.append(f)
	return {"shaders": shaders, "rest": rest}


static func without_shaders(files: PackedStringArray) -> PackedStringArray:
	return split_files(files)["rest"]


static func name_from_path(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges().capitalize()


static func check(name: String, source: String, code: String) -> Dictionary:
	var conv: Dictionary = Convert.convert(code)
	var out: Dictionary = {"ok": false, "conv": conv, "problems": (conv["problems"] as Array).duplicate(true), "compiled": false, "entry": {}}
	if not bool(conv["ok"]):
		return out
	var comp: Dictionary = Convert.compile(String(conv["code"]))
	out["compiled"] = bool(comp["checked"])
	if not bool(comp["ok"]):
		out["problems"] = comp["errors"]
		return out
	out["ok"] = true
	out["entry"] = ImportedShaders.make_entry(name, source, code, conv)
	return out


static func problem_text(problems: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for p: Variant in problems:
		var d: Dictionary = p
		var line: int = int(d.get("line", 0))
		parts.append(("Line " + str(line) + ": " if line > 0 else "") + String(d.get("text", "")))
	return "\n".join(parts)


static func import_entry(doc: Project, seq: Sequence, entry: Dictionary, targets: PackedStringArray) -> int:
	if doc == null or entry.is_empty():
		return -1
	var id: String = String(entry["id"])
	var label: String = "Import " + String(entry.get("label", "shader"))
	var tx: Object = doc.undo.begin(label)
	tx.call("apply", ShaderCmds.SetImportedShader.new(id, entry, label))
	var placed: int = 0
	if seq != null and not targets.is_empty():
		var def: Dictionary = EffectSource.get_def(id)
		if not def.is_empty():
			placed = Verbs.drop_effect(doc, seq, targets, def)
	if bool(tx.call("is_empty")):
		tx.call("abandon")
		return 0
	tx.call("commit")
	return placed


static func library_plan(name: String) -> Dictionary:
	var base: String = ImportedShaders.slug(name)
	var reg: RefCounted = ImportedShaders.registry()
	var root: String = EffectSource.user_root()
	for n: int in range(1, 1000):
		var id: String = base if n == 1 else base + "_" + str(n)
		var def: Dictionary = reg.call("get_def", id)
		if def.is_empty() or bool(def.get("embedded", false)):
			return {"id": id, "replaces": false, "renamed": id != base}
		if String(def.get("source", "")) == "user" and String(def.get("path", "")) == root + id + "/":
			return {"id": id, "replaces": true, "renamed": id != base}
	return {"id": base + "_" + str(Time.get_ticks_msec()), "replaces": false, "renamed": true}


static func library_json(id: String, name: String, category: String, blurb: String, entry: Dictionary) -> String:
	var def: Dictionary = {
		"id": id,
		"label": name,
		"category": category,
		"version": 1,
		"blurb": blurb,
		"imported_from": String(entry.get("source", "")),
		"passes": [{"shader": LIBRARY_SHADER}],
		"params": (entry.get("params", []) as Array).duplicate(true),
	}
	return JSON.stringify(def, "\t", false) + "\n"


static func save_library(doc: Project, source_id: String, name: String, category: String, blurb: String, switch_clips: bool) -> Dictionary:
	var out: Dictionary = {"ok": false, "id": "", "folder": "", "switched": 0, "reason": ""}
	var entry: Dictionary = ImportedShaders.entry_for(doc, source_id) if doc != null else {}
	if entry.is_empty():
		out["reason"] = "This effect was not imported into this project"
		return out
	var clean_name: String = name.strip_edges()
	if clean_name.is_empty():
		out["reason"] = "Give it a name"
		return out
	var plan: Dictionary = library_plan(clean_name)
	var id: String = String(plan["id"])
	var folder: String = EffectSource.user_root() + id + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var e1: Error = Io.write_atomic(folder + LIBRARY_SHADER, String(entry["code"]), false)
	var e2: Error = Io.write_atomic(folder + LIBRARY_DEF, library_json(id, clean_name, category, blurb.strip_edges(), entry), false)
	if e1 != OK or e2 != OK:
		out["reason"] = "Could not write to " + ProjectSettings.globalize_path(folder) + ": " + Io.last_error
		return out
	EffectSource.reload_effects()
	ImportedShaders.refresh(doc)
	out["ok"] = true
	out["id"] = id
	out["folder"] = folder
	out["replaced"] = bool(plan["replaces"])
	var from_ids: PackedStringArray = PackedStringArray([String(entry["id"])])
	if not String(entry.get("library_id", "")).is_empty() and String(entry["library_id"]) != id:
		from_ids.append(String(entry["library_id"]))
	var used: int = 0
	for fid: String in from_ids:
		used += ImportedShaders.used_count(doc, fid)
	if switch_clips and used > 0:
		var linked: Dictionary = entry.duplicate(true)
		linked["library_id"] = id
		linked["library_label"] = clean_name
		linked["library_category"] = category
		var label: String = "Use the saved " + clean_name
		var cmds: Array[Command] = [ShaderCmds.SetImportedShader.new(String(entry["id"]), linked, label)]
		var defaults: Dictionary = defaults_of(EffectSource.get_def(id))
		for fid2: String in from_ids:
			cmds.append(ShaderCmds.SwitchEffectId.new(fid2, id, defaults, label))
		if Verbs.run(doc, label, cmds):
			out["switched"] = used
	_after_library_change()
	return out


static func defaults_of(def: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in def.get("params", []):
		var d: Dictionary = p
		out[String(d["key"])] = d.get("default", 0.0)
	return out


static func update_entry(doc: Project, old_id: String, entry: Dictionary, only_clip: String = "") -> bool:
	if doc == null or entry.is_empty():
		return false
	var new_id: String = String(entry["id"])
	var label: String = "Edit shader " + String(entry.get("label", ""))
	var tx: Object = doc.undo.begin(label)
	tx.call("apply", ShaderCmds.SetImportedShader.new(new_id, entry, label))
	if new_id != old_id:
		tx.call("apply", ShaderCmds.SwitchEffectId.new(old_id, new_id, defaults_of(EffectSource.get_def(new_id)), label, only_clip))
		if old_id.begins_with(ImportedShaders.PREFIX) and ImportedShaders.used_count(doc, old_id) == 0:
			tx.call("apply", ShaderCmds.SetImportedShader.new(old_id, {}, label))
	if bool(tx.call("is_empty")):
		tx.call("abandon")
		return false
	return bool(tx.call("commit"))


static func _bus() -> RefCounted:
	return Bus.instance()


static func _after_library_change() -> void:
	var p: Object = _bus().call("panel", "effects")
	if p != null:
		p.set("_folder_stamp", EffectSource.user_stamp())
		if p.has_method("rebuild"):
			p.call("rebuild")


static func refresh_panels() -> void:
	var p: Object = _bus().call("panel", "effects")
	if p != null and p.has_method("rebuild"):
		p.call("rebuild")


static func selection_targets() -> PackedStringArray:
	var s: Sequence = Session.seq()
	if s == null:
		return PackedStringArray()
	return Verbs.selection(s)


static func targets_at(global_pos: Vector2) -> PackedStringArray:
	var s: Sequence = Session.seq()
	if s == null:
		return PackedStringArray()
	var b: RefCounted = _bus()
	var ec: Object = b.call("panel", "effect_controls")
	if _covers(ec, global_pos):
		var c: Clip = Bus.selected_clip(s)
		return Verbs.drop_targets(s, c.id) if c != null else PackedStringArray()
	var tl: Object = b.call("panel", "timeline")
	if tl != null and tl.has_method("accepts_global") and bool(tl.call("accepts_global", global_pos)):
		var canvas: Variant = tl.get("canvas")
		if canvas is Control and (canvas as Control).has_method("hit_at"):
			var hit: Dictionary = (canvas as Control).call("hit_at", global_pos - (canvas as Control).global_position)
			var hc: Variant = hit.get("clip", null)
			if hc is Clip:
				return Verbs.drop_targets(s, (hc as Clip).id)
		return PackedStringArray()
	var prog: Object = b.call("panel", "program")
	if _covers(prog, global_pos):
		var slot: Node = _find_named((prog as Object).call("root"), "EffectDropSlot")
		if slot is Control and slot.has_method("targets_for"):
			var local: Vector2 = (slot as Control).get_global_transform().affine_inverse() * global_pos
			return slot.call("targets_for", s, local)
	return Verbs.selection(s)


static func _covers(panel: Object, global_pos: Vector2) -> bool:
	if panel == null or not panel.has_method("root"):
		return false
	var r: Variant = panel.call("root")
	if not (r is Control) or not is_instance_valid(r):
		return false
	var rc: Control = r
	return rc.is_visible_in_tree() and rc.get_global_rect().has_point(global_pos)


static func _find_named(from: Variant, want: String) -> Node:
	if not (from is Node):
		return null
	var n: Node = from
	if n.name == want:
		return n
	for ch: Node in n.get_children():
		var f: Node = _find_named(ch, want)
		if f != null:
			return f
	return null


static func target_text(seq: Sequence, targets: PackedStringArray) -> String:
	if seq == null or targets.is_empty():
		return "Nothing is selected, so it goes into the Effects panel under " + ImportedShaders.CATEGORY + ", ready to drop on a clip."
	var names: PackedStringArray = PackedStringArray()
	for id: String in targets:
		var c: Clip = seq.clip_by_id(id)
		var t: Track = seq.track_of(id)
		if c == null or t == null or not t.is_picture(c):
			continue
		names.append(c.label + " (" + t.shown_label() + ")")
	if names.is_empty():
		return "The selected clips have no picture, so it goes into the Effects panel under " + ImportedShaders.CATEGORY + "."
	if names.size() > 3:
		return "Goes on " + ", ".join(names.slice(0, 3)) + " and " + str(names.size() - 3) + " more."
	return "Goes on " + ", ".join(names) + "."


static func done_toast(label: String, placed: int) -> String:
	if placed > 0:
		return "Imported " + label + (" onto " + str(placed) + " clips" if placed > 1 else " onto the clip")
	return "Imported " + label + ", it is in the Effects panel under " + ImportedShaders.CATEGORY


static func import_code(host: Node, name: String, source: String, code: String, targets: PackedStringArray) -> bool:
	var r: Dictionary = check(name, source, code)
	if not bool(r["ok"]):
		open_sheet(host, name, source, code, targets, "", r)
		return false
	var placed: int = import_entry(Session.doc, Session.seq(), r["entry"], targets)
	if placed < 0:
		return false
	Events.toast(done_toast(String((r["entry"] as Dictionary)["label"]), placed))
	refresh_panels()
	return true


static func import_file(host: Node, path: String, targets: PackedStringArray) -> bool:
	if not FileAccess.file_exists(path):
		Events.toast("Could not find " + path.get_file())
		return false
	var code: String = FileAccess.get_file_as_string(path)
	return import_code(host, name_from_path(path), path.get_file(), code, targets)


static func import_files(host: Node, paths: PackedStringArray, targets: PackedStringArray) -> int:
	var done: int = 0
	for p: String in paths:
		if import_file(host, p, targets):
			done += 1
	return done


static func open_sheet(host: Node, name: String, source: String, code: String, targets: PackedStringArray, edit_id: String = "", first: Dictionary = {}) -> Node:
	var script: GDScript = load(SHEET_PATH)
	return script.call("open", host, name, source, code, targets, edit_id, first)


static func open_file_dialog(host: Node, targets: PackedStringArray) -> void:
	if host == null or not host.is_inside_tree():
		return
	if _dialog == null or not is_instance_valid(_dialog):
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.use_native_dialog = true
		_dialog.title = "Import a Godot shader"
		_dialog.filters = PackedStringArray(["*.gdshader,*.shader ; Godot shaders"])
		_dialog.files_selected.connect(_on_files_chosen)
		host.get_tree().root.add_child(_dialog)
	_dialog_targets = targets
	_dialog.popup_centered(Vector2i(900, 600))


static func _on_files_chosen(paths: PackedStringArray) -> void:
	var host: Node = _dialog if _dialog != null and is_instance_valid(_dialog) else null
	import_files(host, paths, _dialog_targets)


static func menu_items() -> Array:
	var out: Array = [PmMenu.item(MENU_FILE, "Import a Godot shader...", "", "import"), PmMenu.item(MENU_PASTE, "Paste Godot shader code...")]
	out.append_array(load("res://modules/core_panels/effect_file.gd").call("panel_menu_items"))
	return out


static func add_menu_button(panel: Object, head: Container) -> Button:
	var b: Button = panel.call("quiet_icon", "more", "Import a Godot shader or an effect file, or paste shader code")
	b.pressed.connect(_on_menu_button.bind(b))
	head.add_child(b)
	return b


static func _on_menu_button(anchor: Button) -> void:
	var m: Control = PmMenu.open(anchor, menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked.bind(anchor))


static func _on_menu_picked(pick: String, anchor: Control) -> void:
	menu_pick(anchor, pick)


static func menu_pick(host: Node, pick: String) -> bool:
	if bool(load("res://modules/core_panels/effect_file.gd").call("panel_menu_picked", host, pick)):
		return true
	if pick == MENU_FILE:
		open_file_dialog(host, selection_targets())
		return true
	if pick == MENU_PASTE:
		open_sheet(host, PASTED, "", "", selection_targets())
		return true
	return false


static func row_menu_items(id: String) -> Array:
	if not ImportedShaders.is_imported(id):
		return []
	return [PmMenu.separator(), PmMenu.item(ITEM_SAVE, "Save to the Effects panel..."), PmMenu.item(ITEM_EDIT, "Edit the shader code...")]


static func row_menu_picked(panel: Object, pick: String, id: String) -> bool:
	if pick != ITEM_SAVE and pick != ITEM_EDIT:
		return false
	var host: Variant = panel.call("root") if panel.has_method("root") else null
	if not (host is Node):
		return true
	if pick == ITEM_SAVE:
		open_save_sheet(host, id)
	else:
		open_edit(host, id, "")
	return true


static func effect_menu_items(panel: Object, uid: String) -> Array:
	var id: String = _effect_id(panel, uid)
	return row_menu_items(id)


static func effect_menu_picked(panel: Object, pick: String, uid: String) -> bool:
	if pick != ITEM_SAVE and pick != ITEM_EDIT:
		return false
	return row_menu_picked(panel, pick, _effect_id(panel, uid))


static func _effect_id(panel: Object, uid: String) -> String:
	if panel == null or not panel.has_method("target_clip"):
		return ""
	var c: Variant = panel.call("target_clip")
	if not (c is Clip):
		return ""
	for e: Dictionary in (c as Clip).effects:
		if String(e.get("uid", "")) == uid:
			return String(e.get("id", ""))
	return ""


static func open_edit(host: Node, id: String, only_clip: String) -> Node:
	var entry: Dictionary = ImportedShaders.entry_for(Session.doc, id)
	if entry.is_empty():
		Events.toast("The code of this effect is not in this project")
		return null
	var label: String = String(entry["label"]) if String(entry.get("library_id", "")) != id else String(entry.get("library_label", entry["label"]))
	return open_sheet(host, label, String(entry.get("source", "")), String(entry["original"]), PackedStringArray([only_clip]) if not only_clip.is_empty() else PackedStringArray(), id)


static func open_save_sheet(host: Node, id: String) -> Node:
	var script: GDScript = load(SAVE_SHEET_PATH)
	return script.call("open", host, id)


static func add_bin_pick(panel: Object, editors: Container, path: String) -> Button:
	var b: Button = panel.call("quiet_icon", "image", "Pick a picture from the bin")
	b.pressed.connect(_on_bin_pick.bind(panel, b, path))
	editors.add_child(b)
	return b


static func bin_pictures(doc: Project) -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		if m.kind == "image" or PICTURE_EXTENSIONS.has(m.path.get_extension().to_lower()):
			out.append(m)
	return out


static func _on_bin_pick(panel: Object, anchor: Button, path: String) -> void:
	var items: Array = []
	for m: MediaItem in bin_pictures(Session.doc):
		items.append(PmMenu.item(BIN_PICK_PREFIX + m.id, m.label if not m.label.is_empty() else m.path.get_file(), "", "image"))
	if items.is_empty():
		var none: Dictionary = PmMenu.item("none", "No pictures in the bin yet")
		none["disabled"] = true
		items.append(none)
	var menu: Control = PmMenu.open(anchor, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_bin_picked.bind(panel, path))


static func _on_bin_picked(pick: String, panel: Object, path: String) -> void:
	if not pick.begins_with(BIN_PICK_PREFIX) or Session.doc == null:
		return
	var m: MediaItem = Session.doc.media_by_id(pick.substr(BIN_PICK_PREFIX.length()))
	if m != null and panel != null and panel.has_method("_on_text"):
		panel.call("_on_text", m.path, path)
