extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const TextRuns := preload("res://doc/text_runs.gd")
const ParaAlign := preload("res://doc/text_paragraphs.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const LABEL := "Align paragraph"
const LABEL_ALL := "Align text"


static func caret_span(block: Object) -> Vector2i:
	var te: RefCounted = block.call("_text_edit")
	if te != null:
		return te.call("selection")
	var fe: TextEdit = block.call("field_edit")
	if fe == null or not (fe.has_focus() or fe.has_selection()):
		return Vector2i(-1, -1)
	var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
	if fe.has_selection():
		return pop.call("selection_of", fe)
	var at: int = int(pop.call("offset_of", fe, fe.get_caret_line(), fe.get_caret_column()))
	return Vector2i(at, at)


static func text_of(props: Dictionary) -> String:
	var raw: Variant = TextRuns.plain(props.get("text", ""))
	return String(raw) if raw is String else ""


static func shown_align(block: Object, props: Dictionary) -> String:
	var sp: Vector2i = caret_span(block)
	if sp.x < 0:
		return ParaAlign.title_align(props)
	return ParaAlign.align_of(props, ParaAlign.index_at(text_of(props), sp.x))


static func apply(block: Object, align: String) -> bool:
	if not ParaAlign.ALIGNS.has(align):
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var c: Clip = block.call("target")
	if d == null or s == null or c == null:
		return false
	var group: Array = block.call("many_targets")
	if group.size() > 1:
		return bool(block.call("write", "align", align))
	var sp: Vector2i = caret_span(block)
	var te: RefCounted = block.call("_text_edit")
	if te != null:
		te.call("commit", Bus.instance().call("panel", "program"))
	if d.undo.has_live():
		d.undo.commit_live("Edit text")
	var props: Dictionary = block.call("props_now")
	block.set("writes", int(block.get("writes")) + 1)
	if sp.x >= 0:
		var next: String = ParaAlign.with_align(props, text_of(props), sp.x, sp.y, align)
		var done: bool = Verbs.set_clip_param(d, s, c.id, ParaAlign.PATH, next, -1.0, false)
		block.call("refresh", true)
		return done
	var key_at: float = float(Bus.instance().call("key_time_for", c, "props.align", s.playhead))
	var changed: bool = Verbs.set_clip_param(d, s, c.id, "props.align", align, key_at, true)
	if not ParaAlign.stored(c.props).is_empty():
		changed = Verbs.set_clip_param(d, s, c.id, ParaAlign.PATH, "", -1.0, true) or changed
	if d.undo.has_live():
		d.undo.commit_live(LABEL_ALL)
	block.call("refresh", true)
	return changed
