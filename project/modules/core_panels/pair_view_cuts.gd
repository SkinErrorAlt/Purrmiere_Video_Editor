extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ViewCmds := preload("res://doc/commands/view_cmds.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const TOGGLE_ID := "clip.view_cuts"
const SPLIT_ID := "clip.split_view_changes"
const MENU_TOGGLE := "view_cuts"
const MENU_SPLIT := "view_split"
const LABEL := "Cut on view changes"
const SPLIT_LABEL := "Split at view changes"
const TIP := "Show a cut on the timeline at every view change, with each part in its view's colour. Nothing is split. Split at view changes in the clip's menu really splits."


static func pair_entry(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == ViewMap.PAIR_VIEW_ID:
			return e
	return {}


static func pair_clips(s: Sequence, ids: PackedStringArray) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c != null and not pair_entry(c).is_empty() and not out.has(c):
			out.append(c)
	return out


static func is_on(c: Clip) -> bool:
	return ViewMap.cuts_on(pair_entry(c))


static func set_on(d: Project, s: Sequence, ids: PackedStringArray, on: bool) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for c: Clip in pair_clips(s, ids):
		var e: Dictionary = pair_entry(c)
		if ViewMap.cuts_on(e) == on:
			continue
		var cmd: Command = EffectCmds.SetEffectParam.new(s.id, c.id, String(e.get("uid", "")), ViewMap.CUTS_KEY, on)
		cmd.label = LABEL
		cmds.append(cmd)
	if cmds.is_empty():
		return false
	return Verbs.run(d, LABEL, cmds)


static func toggle(d: Project, s: Sequence, ids: PackedStringArray) -> bool:
	var clips: Array[Clip] = pair_clips(s, ids)
	if clips.is_empty():
		return false
	var all_on: bool = true
	for c: Clip in clips:
		if not is_on(c):
			all_on = false
	return set_on(d, s, ids, not all_on)


static func selected_on() -> bool:
	var s: Sequence = Session.seq()
	if s == null:
		return false
	var clips: Array[Clip] = pair_clips(s, s.selected_clip_ids)
	if clips.is_empty():
		return false
	for c: Clip in clips:
		if not is_on(c):
			return false
	return true


static func toggle_selected() -> void:
	var s: Sequence = Session.seq()
	if s == null:
		return
	if pair_clips(s, s.selected_clip_ids).is_empty():
		Events.toast("Select a clip with a Pair View first")
		return
	toggle(Session.doc, s, s.selected_clip_ids)


static func split(d: Project, s: Sequence, ids: PackedStringArray) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for c: Clip in pair_clips(s, ids):
		var cmd: Command = ViewCmds.CutViews.new(s.id, c.id, String(pair_entry(c).get("uid", "")))
		cmd.label = SPLIT_LABEL
		cmds.append(cmd)
	if cmds.is_empty():
		return false
	return Verbs.run(d, SPLIT_LABEL, cmds)


static func split_selected() -> void:
	var s: Sequence = Session.seq()
	if s == null:
		return
	if pair_clips(s, s.selected_clip_ids).is_empty():
		Events.toast("Select a clip with a Pair View first")
		return
	if not split(Session.doc, s, s.selected_clip_ids):
		Events.toast("Nothing to split: key View so the view changes inside the clip")


static func clip_menu_items(c: Clip) -> Array:
	if pair_entry(c).is_empty():
		return []
	return [PmMenu.check_item(MENU_TOGGLE, LABEL, is_on(c), Cmd.keys_text(TOGGLE_ID)), PmMenu.item(MENU_SPLIT, SPLIT_LABEL, Cmd.keys_text(SPLIT_ID), "razor")]


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if id != MENU_TOGGLE and id != MENU_SPLIT:
		return false
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return true
	var ids: PackedStringArray = Verbs.selection(s)
	if not ids.has(clip_id):
		ids = PackedStringArray([clip_id])
	if id == MENU_TOGGLE:
		toggle(d, s, ids)
	elif not split(d, s, ids):
		Events.toast("Nothing to split: key View so the view changes inside the clip")
	return true
