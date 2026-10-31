extends RefCounted

const SELF := preload("res://modules/core_panels/pair_offsets.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewOffsets := preload("res://doc/view_offsets.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const MENU_ID := "pair_offset_all"
const COMMAND_ID := "clip.offset_selected"
const WINDOW_KEY := "controls.offset_all"
const MENU_LABEL := "Offset every selected clip"
const SET_LABEL := "Offset every selected clip"
const NUDGE_LABEL := "Nudge every selected clip"
const NUDGES: Array[float] = [-0.1, -0.01, -0.001, 0.001, 0.01, 0.1]
const NO_CLIPS := "Select clips with a Pair View first"

static var window: Control = null


static func clip_total(s: Sequence, ids: PackedStringArray) -> int:
	return ViewOffsets.pair_clips(s, ids).size()


static func region_total(s: Sequence, ids: PackedStringArray) -> int:
	return ViewOffsets.targets(s, ids).size()


static func summary(s: Sequence, ids: PackedStringArray) -> String:
	var clips: int = clip_total(s, ids)
	if clips == 0:
		return "No Pair View clip is selected"
	var views: int = region_total(s, ids)
	var left: String = "1 Pair View clip selected" if clips == 1 else str(clips) + " Pair View clips selected"
	var right: String = "1 view in all" if views == 1 else str(views) + " views in all"
	return left + ", " + right


static func set_all(d: Project, s: Sequence, ids: PackedStringArray, seconds: float, at: float) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = ViewOffsets.set_commands(s, ids, seconds, at)
	if cmds.is_empty():
		return false
	return Verbs.run(d, SET_LABEL, cmds)


static func nudge_all(d: Project, s: Sequence, ids: PackedStringArray, delta: float) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = ViewOffsets.nudge_commands(s, ids, delta)
	if cmds.is_empty():
		return false
	return Verbs.run(d, NUDGE_LABEL, cmds)


static func selection() -> PackedStringArray:
	var s: Sequence = Session.seq()
	return Verbs.selection(s) if s != null else PackedStringArray()


static func set_selected(seconds: float) -> bool:
	var s: Sequence = Session.seq()
	return set_all(Session.doc, s, selection(), seconds, Session.playhead())


static func nudge_selected(delta: float) -> bool:
	var s: Sequence = Session.seq()
	return nudge_all(Session.doc, s, selection(), delta)


static func clip_menu_items(c: Clip) -> Array:
	if ViewOffsets.pair_entries(c).is_empty():
		return []
	return [PmMenu.item(MENU_ID, MENU_LABEL, Cmd.keys_text(COMMAND_ID), "slip")]


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if id != MENU_ID:
		return false
	var s: Sequence = Session.seq()
	if s == null:
		return true
	if not Verbs.selection(s).has(clip_id):
		Verbs.select(Session.doc, s, PackedStringArray([clip_id]))
	open_window(null)
	return true


static func open_for_selection() -> void:
	var s: Sequence = Session.seq()
	if s == null or clip_total(s, Verbs.selection(s)) == 0:
		Events.toast(NO_CLIPS)
		return
	open_window(null)


static func open_window(host: Node) -> Control:
	if window != null and is_instance_valid(window) and window.is_inside_tree():
		window.call("raise")
		return window
	var root: Node = host if host != null and host.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	var panel: Control = _Panel.new()
	var row: float = float(Tk.px(Tk.sz("row_h")))
	var h: float = row * 4.0 + float(Tk.px(Tk.sz("gap"))) * 3.0 + float(Tk.px(26.0))
	window = PmWindow.open(root, "Offsets: every selected clip", panel, Vector2(float(Tk.px(460.0)), h), WINDOW_KEY)
	return window


class _Panel:
	extends VBoxContainer

	var field: Control = null
	var head: Label = null
	var _watched: WeakRef = null

	func _ready() -> void:
		name = "PairOffsetsAll"
		add_theme_constant_override("separation", Tk.px(Tk.sz("gap")))
		_build()
		Session.project_changed.connect(_on_project)
		_watch_doc()

	func _exit_tree() -> void:
		if Session.project_changed.is_connected(_on_project):
			Session.project_changed.disconnect(_on_project)
		var d: Object = _watched.get_ref() if _watched != null else null
		if d != null and (d as Project).changed.is_connected(_on_doc_changed):
			(d as Project).changed.disconnect(_on_doc_changed)

	func _watch_doc() -> void:
		var d: Project = Session.doc
		if d != null and not d.changed.is_connected(_on_doc_changed):
			d.changed.connect(_on_doc_changed)
		_watched = weakref(d) if d != null else null

	func _build() -> void:
		PmUI.clear(self)
		var top: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		head = PmLabel.trim("", "text")
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(head)
		add_child(top)
		var hint: Label = PmLabel.trim("Every view of every selected Pair View clip moves in one step", "text_faint")
		add_child(hint)
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		row.add_child(PmLabel.dim("Offset"))
		field = PmField.make(0.0, -ViewMap.OFFSET_MAX * 1000.0, ViewMap.OFFSET_MAX * 1000.0, 0.1, " ms")
		field.name = "Offset"
		field.set("precision", 1)
		field.custom_minimum_size.x = float(Tk.px(96.0))
		PmUI.tip(field, "The offset to give every selected clip. Positive plays the region later, negative earlier")
		row.add_child(field)
		var set_btn: Button = PmButton.make("Set every one")
		PmUI.tip(set_btn, "Give every view of every selected Pair View clip this offset, as one undo step")
		set_btn.pressed.connect(_on_set)
		row.add_child(set_btn)
		row.add_child(PmUI.spacer())
		var done: Button = PmButton.make("Done")
		done.set("quiet", true)
		done.pressed.connect(_on_done)
		row.add_child(done)
		add_child(row)
		var nudges: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		nudges.add_child(PmLabel.dim("Nudge"))
		for dv: float in NUDGES:
			var ms: int = int(round(absf(dv) * 1000.0))
			var nb: Button = PmButton.make(("+" if dv > 0.0 else "-") + str(ms))
			nb.set("quiet", true)
			PmUI.tip(nb, ("Later" if dv > 0.0 else "Earlier") + " by " + str(ms) + " ms, added to each clip's own offset")
			nb.pressed.connect(_on_nudge.bind(dv))
			nudges.add_child(nb)
		add_child(nudges)
		_refresh()

	func _refresh() -> void:
		var s: Sequence = Session.seq()
		var text: String = SELF.summary(s, SELF.selection())
		if head != null and is_instance_valid(head):
			head.text = text
			PmUI.tip(head, text)

	func _on_project() -> void:
		_watch_doc()
		_refresh()

	func _on_doc_changed(_kind: String) -> void:
		if is_inside_tree():
			_refresh()

	func _on_set() -> void:
		if not SELF.set_selected(float(field.get("value")) / 1000.0):
			Events.toast(NO_CLIPS if SELF.clip_total(Session.seq(), SELF.selection()) == 0 else "Every selected clip already has that offset")
		_refresh()

	func _on_nudge(delta: float) -> void:
		if not SELF.nudge_selected(delta):
			Events.toast(NO_CLIPS)
		_refresh()

	func _on_done() -> void:
		var w: Node = get_parent()
		while w != null and not w.has_method("close"):
			w = w.get_parent()
		if w != null:
			w.call("close")
