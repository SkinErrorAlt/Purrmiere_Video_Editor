extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const TrackGuard := preload("res://doc/track_guard.gd")
const LockCmds := preload("res://doc/commands/lock_cmds.gd")
const SELF_PATH := "res://modules/core_panels/track_lock_sheet.gd"
const YES := "Allowed"
const NO := "No"
const HERE := "on this track"

var sheet: Control = null
var list: Control = null
var apply_button: Button = null
var doc_ref: WeakRef = null
var seq_id: String = ""
var track_id: String = ""
var media_ids: PackedStringArray = PackedStringArray()
var allowed: Dictionary = {}
var here: Dictionary = {}


static func open(host: Node, p_track_id: String) -> Node:
	var d: Project = host.call("doc") if host != null and host.has_method("doc") else Session.doc
	var s: Sequence = host.call("seq") if host != null and host.has_method("seq") else (d.active_sequence() if d != null else null)
	if d == null or s == null or s.track_by_id(p_track_id) == null:
		return null
	var script: GDScript = load(SELF_PATH)
	var u: Node = script.new()
	u.call("build", host, d, s, p_track_id)
	return u


static func start_files(t: Track) -> PackedStringArray:
	if t == null:
		return PackedStringArray()
	if TrackGuard.kind_of(t) == TrackGuard.FILES or not t.lock_files.is_empty():
		return t.lock_files.duplicate()
	return LockCmds.files_on(t)


func track() -> Track:
	var d: Project = doc_ref.get_ref() if doc_ref != null else null
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	return s.track_by_id(track_id) if s != null else null


func build(host: Node, d: Project, s: Sequence, p_track_id: String) -> void:
	name = "TrackLockSheet"
	doc_ref = weakref(d)
	seq_id = s.id
	track_id = p_track_id
	var t: Track = s.track_by_id(p_track_id)
	for id: String in LockCmds.files_on(t):
		here[id] = true
	for id2: String in start_files(t):
		allowed[id2] = true
	var first: Array[MediaItem] = []
	var rest: Array[MediaItem] = []
	for m: MediaItem in d.media:
		if here.has(m.id):
			first.append(m)
		else:
			rest.append(m)
	rest.sort_custom(func(a: MediaItem, b: MediaItem) -> bool: return a.label.naturalnocasecmp_to(b.label) < 0)
	for m2: MediaItem in first + rest:
		media_ids.append(m2.id)
	sheet = Sheet.open(host, "Only these files on " + t.shown_label(), 520.0, 440.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	sheet.call("add_note", t.shown_label() + " takes only the files allowed here. Clips already on it stay; anything else dropped, pasted, moved or overwritten onto it is refused with a note that says why. Click a row to allow or refuse it.")
	list = SheetList.make(36.0, true, 64.0)
	list.set("click_activates", false)
	list.set("auto_cursor", false)
	list.set("empty_text", "The project has no media yet")
	list.connect("pressed_row", _on_row)
	col.add_child(list)
	refresh()
	var row: HBoxContainer = sheet.call("add_buttons")
	var own: Button = sheet.call("add_button", "Allow the files on this track")
	own.pressed.connect(_on_own)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	apply_button = sheet.call("add_button", "Apply", true)
	apply_button.pressed.connect(_on_apply)


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = doc_ref.get_ref() if doc_ref != null else null
	if d == null:
		return out
	for id: String in media_ids:
		var m: MediaItem = d.media_by_id(id)
		if m == null:
			continue
		var on: bool = allowed.has(id)
		out.append({"lead": m.kind, "title": m.label, "detail": HERE if here.has(id) else (m.bin if not m.bin.is_empty() else "Bin"), "right": YES if on else NO, "chip": true, "ink": on, "strong": on, "rule": true})
	return out


func refresh() -> void:
	if list != null:
		list.call("set_rows", rows(), true)
		list.queue_redraw()


func toggle(index: int) -> void:
	if index < 0 or index >= media_ids.size():
		return
	var id: String = media_ids[index]
	if allowed.has(id):
		allowed.erase(id)
	else:
		allowed[id] = true
	refresh()


func chosen() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in media_ids:
		if allowed.has(id):
			out.append(id)
	return out


func apply_now() -> bool:
	var d: Project = doc_ref.get_ref() if doc_ref != null else null
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	if s == null:
		return false
	return LockCmds.set_lock(d, s, track_id, TrackGuard.FILES, chosen())


func _on_row(index: int, _on_right: bool) -> void:
	toggle(index)


func _on_own() -> void:
	allowed = {}
	for id: String in here.keys():
		allowed[id] = true
	refresh()


func _on_apply() -> void:
	apply_now()
	sheet.call("close")


func _on_cancel() -> void:
	sheet.call("close")
