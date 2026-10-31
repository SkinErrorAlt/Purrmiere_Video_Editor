extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const SELF_PATH := "res://modules/core_panels/stack_commands.gd"
const OWNER := "core_panels"
const PASTE := "edit.paste_overlap"
const FRONT := "clip.bring_to_front"
const BACK := "clip.send_to_back"
const FREE := "seq.free_tracks"
const OVERLAP := "seq.overlap_clips"


static func _cmd(id: String, handler: Callable, toggle: Callable = Callable()) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Edit"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	var spec: Dictionary = {"label": label, "category": category, "scope": "global", "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")}
	if toggle.is_valid():
		spec["toggle"] = toggle
	Cmd.register(id, spec)


static func register_all() -> void:
	var script: GDScript = load(SELF_PATH)
	_cmd(PASTE, Callable(script, "paste_overlapping"))
	_cmd(FRONT, Callable(script, "restack").bind(true))
	_cmd(BACK, Callable(script, "restack").bind(false))
	_cmd(FREE, Callable(script, "toggle_free"), Callable(script, "free_is"))
	_cmd(OVERLAP, Callable(script, "toggle_overlap"), Callable(script, "overlap_is"))


static func paste_overlapping() -> bool:
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return false
	var cb: Dictionary = Bus.instance().clipboard
	if cb.is_empty():
		Events.toast("Copy a clip first, then paste it overlapping")
		return false
	return Verbs.paste_overlapping(d, s, cb, s.playhead)


static func restack(front: bool) -> bool:
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return false
	var c: Clip = Bus.selected_clip(s)
	if c == null:
		return false
	if not Verbs.in_stack(s, c):
		Events.toast("This clip does not overlap another clip on its track")
		return false
	return Verbs.bring_to_front(d, s, c.id) if front else Verbs.send_to_back(d, s, c.id)


static func toggle_free() -> bool:
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return false
	return Verbs.set_free_tracks(d, s, not s.free_tracks)


static func free_is() -> bool:
	var s: Sequence = Session.seq()
	return s != null and s.free_tracks


static func toggle_overlap() -> bool:
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return false
	return Verbs.set_overlap_clips(d, s, not s.overlap_clips)


static func overlap_is() -> bool:
	var s: Sequence = Session.seq()
	return s != null and s.overlap_clips
