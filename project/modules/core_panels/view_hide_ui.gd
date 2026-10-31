extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const MENU_ID := "view_hide"
const LABEL := "Hide from view only (never from exports)"
const TRACK_TIP := "Hide this track from the Program monitor and playback only. Exports always include it. The eye beside it is the one that changes the output"
const DASH := 4.0
const MARK_ALPHA := 0.9


static func clip_menu_items(c: Clip) -> Array:
	var s: Sequence = Session.seq()
	if s == null or c == null:
		return []
	var tr: Track = s.track_of(c.id)
	if tr == null or not tr.is_picture(c):
		return []
	return [PmMenu.check_item(MENU_ID, LABEL, c.view_hidden)]


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if id != MENU_ID:
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return true
	set_hidden(d, s, PackedStringArray([clip_id]) if not s.selected_clip_ids.has(clip_id) else s.selected_clip_ids, not c.view_hidden)
	return true


static func set_hidden(d: Project, s: Sequence, ids: PackedStringArray, on: bool) -> bool:
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		var tr: Track = s.track_of(id)
		if c == null or tr == null or not tr.is_picture(c) or c.view_hidden == on:
			continue
		cmds.append(ClipCmds.SetClipField.new(s.id, id, "view_hidden", on))
	if cmds.is_empty():
		return false
	var tx: RefCounted = d.undo.begin("Hide from view" if on else "Show in view")
	for cmd: Command in cmds:
		tx.call("apply", cmd)
	return bool(tx.call("commit"))


static func draw_mark(ci: CanvasItem, r: Rect2) -> void:
	var col: Color = Tk.c["accent"]
	col.a = MARK_ALPHA
	var inner: Rect2 = r.grow(-1.5)
	var pts: PackedVector2Array = PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y), inner.position])
	for i: int in 4:
		ci.draw_dashed_line(pts[i], pts[i + 1], col, 1.0, DASH)
