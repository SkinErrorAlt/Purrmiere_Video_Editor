extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const CW := preload("res://doc/clip_warnings.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://ui/timeline/timeline_warnings.gd"
const PREF_PRESETS := "timeline.warning_presets"
const PANEL_ID := "warnings"
const ID_PREFIX := "warn:"
const PRESET_PREFIX := "warn:p:"
const FILL := Color("#f2b138")
const INK := Color("#1a1204")
const DONE_FILL := Color("#3a3d42")
const BADGE_H := 12.0
const BADGE_GAP := 3.0
const META_RECTS := "warning_badges"
const META_PAINT := "warning_badges_paint"

static var _boxes: Dictionary = {}


static func _ensure_pref() -> void:
	if not Prefs.is_registered(PREF_PRESETS):
		Prefs.register(PREF_PRESETS, [], {"label": "Clip warning presets you made", "type": "list", "hint": "Made with Warning, New warning... on a clip. Forget them from the Warnings panel."})


static func own_presets() -> PackedStringArray:
	_ensure_pref()
	var out: PackedStringArray = PackedStringArray()
	var v: Variant = Prefs.get_value(PREF_PRESETS)
	if v is Array:
		for e: Variant in v:
			var t: String = CW.clean_text(str(e))
			if not t.is_empty() and not _has_text(out, t) and not _has_text(CW.BUILT_IN, t):
				out.append(t)
	return out


static func presets() -> PackedStringArray:
	var out: PackedStringArray = CW.BUILT_IN.duplicate()
	out.append_array(own_presets())
	return out


static func _has_text(list: PackedStringArray, text: String) -> bool:
	for e: String in list:
		if CW.same_text(e, text):
			return true
	return false


static func keep_preset(text: String) -> bool:
	var t: String = CW.clean_text(text)
	if t.is_empty() or _has_text(presets(), t):
		return false
	var mine: PackedStringArray = own_presets()
	mine.append(t)
	Prefs.set_value(PREF_PRESETS, Array(mine))
	return true


static func forget_preset(text: String) -> bool:
	var mine: PackedStringArray = own_presets()
	var kept: Array = []
	var gone: bool = false
	for e: String in mine:
		if CW.same_text(e, text):
			gone = true
		else:
			kept.append(e)
	if gone:
		Prefs.set_value(PREF_PRESETS, kept)
	return gone


static func _targets(s: Sequence, clip_id: String) -> PackedStringArray:
	return CW.targets(s, clip_id, Verbs.selection(s))


static func menu_items(canvas: Control, c: Clip) -> Array:
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null or c == null:
		return []
	var sub: Array = []
	for p: String in presets():
		sub.append(PmMenu.check_item(PRESET_PREFIX + p, p, CW.has_open_live(d, s, c, p)))
	sub.append(PmMenu.separator())
	sub.append(PmMenu.item(ID_PREFIX + "new", "New warning..."))
	var ids: PackedStringArray = _targets(s, c.id)
	var any_open: bool = CW.any_live(d, s, ids, true)
	var any_at_all: bool = CW.any_live(d, s, ids, false)
	if any_open or any_at_all:
		sub.append(PmMenu.separator())
	if any_open:
		sub.append(PmMenu.item(ID_PREFIX + "done", "Mark done"))
	if any_at_all:
		sub.append(PmMenu.item(ID_PREFIX + "remove", "Remove warnings", "", "trash"))
	sub.append(PmMenu.separator())
	sub.append(PmMenu.item(ID_PREFIX + "list", "Show all warnings"))
	return [PmMenu.sub_item("warning", "Warning", sub, "warn")]


static func on_clip_menu(canvas: Control, id: String, clip_id: String, t: float) -> bool:
	if not id.begins_with(ID_PREFIX):
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return true
	var ids: PackedStringArray = _targets(s, clip_id)
	if id.begins_with(PRESET_PREFIX):
		CW.toggle(d, s, ids, id.substr(PRESET_PREFIX.length()), t)
	elif id == ID_PREFIX + "new":
		ask_new(canvas, ids, t)
	elif id == ID_PREFIX + "done":
		CW.done_all(d, s, ids)
	elif id == ID_PREFIX + "remove":
		CW.remove_all(d, s, ids)
	elif id == ID_PREFIX + "list":
		show_list()
	return true


static func ask_new(host: Control, ids: PackedStringArray, t: float) -> void:
	var fields: Array[Dictionary] = [{"key": "text", "label": "Warning", "type": "string", "default": ""}, {"key": "note", "type": "note", "default": "It goes on the clip and is kept as a preset for next time."}]
	var answered: Signal = PmUI.form(host, "New warning", fields, "Add", "Cancel")
	var script: GDScript = load(SELF_PATH)
	answered.connect(Callable(script, "answer_new").bind(ids, t))


static func answer_new(result: Variant, ids: PackedStringArray, t: float) -> bool:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return false
	var text: String = CW.clean_text(String((result as Dictionary).get("text", "")))
	if text.is_empty():
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return false
	keep_preset(text)
	return CW.add(d, s, ids, text, t)


static func show_list() -> void:
	show_panel_of(PANEL_ID)


static func show_panel_of(panel_id: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	if editor == null:
		return
	var dock: Variant = editor.get("dock")
	if dock is Node and (dock as Node).has_method("show_panel"):
		(dock as Node).call("show_panel", panel_id)


static func tip_text(list: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if list.size() == 1:
		lines.append("Warning: " + String(list[0].get("text", "")))
	else:
		lines.append(str(list.size()) + " warnings")
		for w: Dictionary in list:
			lines.append(String(w.get("text", "")))
	return "\n".join(lines)


static func badge_size(count: int) -> Vector2:
	var h: float = float(Tk.px(BADGE_H))
	var w: float = h
	if count > 1:
		w = h + PmText.width_of(Tk.font("body"), str(count), _count_fs()) + float(Tk.px(3.0))
	return Vector2(ceilf(w), h)


static func _count_fs() -> int:
	return Tk.fs(Tk.sz("font_tiny"))


static func draw_badge(canvas: Control, c: Clip, r: Rect2, lane_h: float) -> void:
	if c == null or c.warnings.is_empty():
		return
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var open: Array[Dictionary] = CW.open_live_on(d, s, c)
	if open.is_empty():
		return
	var bs: Vector2 = badge_size(open.size())
	var inset: float = float(Tk.px(BADGE_GAP))
	var x: float = r.position.x + inset
	if c.is_nest() and lane_h >= 34.0 and r.size.x > 24.0:
		x += 12.0
	if r.end.x - x < bs.x + 1.0 or r.size.y < bs.y + 2.0:
		return
	var br: Rect2 = Rect2(Vector2(roundf(x), roundf(r.position.y + inset - 1.0)), bs)
	paint(canvas, br, open.size(), false)
	PmText.keep_out(canvas, [br.grow_individual(0.0, 0.0, float(Tk.px(2.0)), 0.0)])
	PmText._note_tip(canvas, br, tip_text(open))
	_remember(canvas, c.id, br)


static func paint(ci: CanvasItem, br: Rect2, count: int, done: bool) -> void:
	ci.draw_style_box(_box(int(maxf(2.0, roundf(br.size.y * 0.25))), done), br)
	var glyph: Color = Color("#9ba0a7") if done else INK
	var h: float = br.size.y
	var bar_w: float = maxf(1.5, roundf(h * 0.17 * 2.0) * 0.5)
	var gx: float = br.position.x + roundf(h * 0.5) - bar_w * 0.5
	var top: float = br.position.y + roundf(h * 0.22)
	var bar_h: float = maxf(2.0, roundf(h * 0.38))
	ci.draw_rect(Rect2(gx, top, bar_w, bar_h), glyph, true)
	ci.draw_rect(Rect2(gx, top + bar_h + maxf(1.0, roundf(h * 0.1)), bar_w, bar_w), glyph, true)
	if count > 1:
		var fs: int = _count_fs()
		var f: Font = Tk.font("body")
		var tx: float = br.position.x + h - float(Tk.px(1.0))
		PmText.draw_in(ci, f, Rect2(tx, br.position.y, br.end.x - tx, h), str(count), fs, glyph, HORIZONTAL_ALIGNMENT_LEFT, PmText.baseline_in(f, fs, br), PmText.WHOLE)


static func _box(radius: int, done: bool) -> StyleBoxFlat:
	var key: String = str(radius) + ("d" if done else "o")
	var hit: Variant = _boxes.get(key, null)
	if hit is StyleBoxFlat:
		return hit
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = DONE_FILL if done else FILL
	sb.border_color = INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.6
	_boxes[key] = sb
	return sb


static func _remember(canvas: Control, clip_id: String, br: Rect2) -> void:
	var pc: int = int(canvas.get("paint_count"))
	if int(canvas.get_meta(META_PAINT, -1)) != pc:
		canvas.set_meta(META_PAINT, pc)
		canvas.set_meta(META_RECTS, {})
	(canvas.get_meta(META_RECTS) as Dictionary)[clip_id] = br


static func badge_rects(canvas: Control) -> Dictionary:
	if int(canvas.get_meta(META_PAINT, -1)) != int(canvas.get("paint_count")):
		return {}
	return canvas.get_meta(META_RECTS, {})


static func canvas() -> Control:
	var script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var bus: RefCounted = script.call("instance")
	var tl: Object = bus.call("panel", "timeline")
	if tl == null:
		return null
	var cv: Variant = tl.get("canvas")
	return cv if cv is Control else null


static func jump(e: Dictionary) -> bool:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null or e.is_empty():
		return false
	var cid: String = String(e.get("outer_clip_id", e.get("clip_id", "")))
	var c: Clip = s.clip_by_id(cid)
	if c == null:
		return false
	var t: float = CW.shown_time(e)
	Session.set_playhead(t)
	Verbs.select(d, s, PackedStringArray([cid]), "replace")
	var cv: Control = canvas()
	if cv != null and cv.is_inside_tree():
		reveal(cv, s, cid, t)
	return true


static func reveal(cv: Control, s: Sequence, clip_id: String, t: float) -> void:
	cv.call("reveal_time", t, false)
	var tr: Track = s.track_of(clip_id)
	var sc: Variant = cv.get("_scroll")
	if tr == null or not (sc is Node):
		return
	var lane: Dictionary = Lanes.lane_for_track(cv.call("lanes"), tr.id)
	if lane.is_empty():
		return
	var in_main: bool = false
	for l: Dictionary in (cv.call("lanes") as Dictionary)["main"]:
		if l == lane:
			in_main = true
	if not in_main:
		return
	var g: Dictionary = cv.call("geometry")
	var view_h: float = (g["main_rect"] as Rect2).size.y
	var y: float = float(lane["y"])
	var h: float = float(lane["h"])
	var sy: float = float(cv.get("scroll_y"))
	if y >= sy and y + h <= sy + view_h:
		return
	var target: float = maxf(0.0, y - maxf(view_h - h, 0.0) * 0.5)
	(sc as Node).call("scroll_to", float(cv.get("scroll_x")), target, false)


class Badge:
	extends Control

	const WarnKit := preload("res://ui/timeline/timeline_warnings.gd")

	var done: bool = false

	func _init() -> void:
		name = "WarningBadge"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h: float = float(Tk.px(WarnKit.BADGE_H))
		custom_minimum_size = Vector2(h, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		WarnKit.paint(self, Rect2(Vector2.ZERO, custom_minimum_size), 1, done)
