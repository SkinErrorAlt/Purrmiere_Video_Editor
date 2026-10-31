extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const SELF_PATH := "res://modules/core_panels/unused_sheet.gd"

var sheet: Control = null
var list: Control = null
var remove_button: Button = null
var ids: PackedStringArray = PackedStringArray()


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var u: Node = script.new()
	u.call("build", host)
	return u


static func used_ids(doc: Project) -> Dictionary:
	var used: Dictionary = {}
	for s: Sequence in doc.sequences:
		for c: Clip in s.all_clips():
			used[c.media_id] = true
	return used


static func unused(doc: Project) -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null:
		return out
	var used: Dictionary = used_ids(doc)
	for m: MediaItem in doc.media:
		if m.kind == "sequence" or used.has(m.id):
			continue
		out.append(m)
	return out


static func remove(doc: Project, which: PackedStringArray) -> int:
	if doc == null or which.is_empty():
		return 0
	var used: Dictionary = used_ids(doc)
	var cmds: Array[Command] = []
	var gone: PackedStringArray = PackedStringArray()
	for id: String in which:
		var m: MediaItem = doc.media_by_id(id)
		if m == null or m.kind == "sequence" or used.has(id):
			continue
		cmds.append(MediaCmds.RemoveMedia.new(id, false))
		gone.append(id)
	if cmds.is_empty():
		return 0
	var label: String = "Remove " + str(gone.size()) + (" unused item" if gone.size() == 1 else " unused items")
	if not Verbs.run(doc, label, cmds):
		return 0
	for id: String in gone:
		var h: Variant = Session.media_handles.get(id, -1)
		Session.media_handles.erase(id)
		if typeof(h) != TYPE_INT or int(h) < 0:
			continue
		var still: bool = false
		for other: Variant in Session.media_handles.values():
			if typeof(other) == TYPE_INT and int(other) == int(h):
				still = true
				break
		if not still:
			PurrBridge.close_media(int(h))
	return gone.size()


func build(host: Node) -> void:
	name = "UnusedSheet"
	var doc: Project = Session.doc
	var items: Array[MediaItem] = unused(doc)
	for m: MediaItem in items:
		ids.append(m.id)
	sheet = Sheet.open(host, "Remove unused media", 520.0, 420.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var n: int = items.size()
	if n == 0:
		sheet.call("add_note", "Every item in the project is used by at least one clip.")
	else:
		sheet.call("add_note", str(n) + (" item is" if n == 1 else " items are") + " not used by any clip in any sequence. They leave the project; the files on disk stay where they are. Undo brings them back.")
	list = SheetList.make(36.0, true, 64.0)
	list.set("click_activates", false)
	list.set("auto_cursor", false)
	list.set("empty_text", "Nothing to remove")
	var rows: Array[Dictionary] = []
	for m: MediaItem in items:
		rows.append({"lead": m.kind, "title": m.label, "detail": m.bin if not m.bin.is_empty() else "Bin", "rule": true})
	list.call("set_rows", rows)
	col.add_child(list)
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	remove_button = sheet.call("add_button", ("Remove " + str(n) + (" item" if n == 1 else " items")) if n > 0 else "Remove", true)
	remove_button.disabled = n == 0
	remove_button.pressed.connect(_on_remove)


func remove_now() -> int:
	var n: int = remove(Session.doc, ids)
	if n > 0:
		Events.toast("Removed " + str(n) + (" unused item" if n == 1 else " unused items") + ", the files are still on disk")
	return n


func _on_remove() -> void:
	remove_now()
	sheet.call("close")


func _on_cancel() -> void:
	sheet.call("close")
