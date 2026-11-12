extends RefCounted

const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const Brush := preload("res://engine/brush_stroke.gd")
const ObjectUi := preload("res://modules/core_panels/object_ui.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const SELF_PATH := "res://modules/core_panels/mask_brush.gd"
const TOOL_ID := "mask_brush"
const COMMAND_ID := "tool.mask_brush"
const CMD_KIND := "mask_brush.kind"
const PAINT_LABEL := "Paint the mask"
const WIPE_LABEL := "Wipe the mask"
const TOOL_TIP := "Mask Brush: paint the mask on by hand. Alt wipes it off, [ and ] change the size, the kind button picks hard, soft, square or airbrush"
const KIND_NAMES: PackedStringArray = ["Hard", "Soft", "Square", "Airbrush"]
const SIDE := 256
const STROKE_LEAST := 2.0
const INK := Color(0.4, 0.95, 0.5, 0.45)
const OUT_INK := Color(1.0, 0.42, 0.4, 0.45)
const EDGE := Color(1.0, 1.0, 1.0, 0.85)
const RIM := Color(0.0, 0.0, 0.0, 0.7)

static var kind: int = Brush.SOFT
static var _registered: bool = false

var drag: Dictionary = {}


static func _script() -> GDScript:
	return load(SELF_PATH)


static func tool_on() -> bool:
	return Session.tool_id == TOOL_ID


static func use_tool() -> void:
	Session.set_tool(TOOL_ID)
	Events.toast(TOOL_TIP)


static func kind_name() -> String:
	return KIND_NAMES[clampi(kind, 0, KIND_NAMES.size() - 1)]


static func next_kind() -> void:
	kind = (kind + 1) % KIND_NAMES.size()
	Events.toast("Mask Brush: " + kind_name())


static func register_commands() -> void:
	if _registered:
		return
	_registered = true
	var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var me: GDScript = _script()
	var specs: Array = [
		[COMMAND_ID, "Mask Brush tool", "Tools", Callable(me, "use_tool"), Callable(me, "tool_on")],
		[CMD_KIND, "Mask Brush: next kind of brush", "Tools", Callable(me, "next_kind"), Callable()],
	]
	var cat: Dictionary = Cmd.catalogue()
	for sp: Array in specs:
		var id: String = sp[0]
		if Cmd.has(id):
			continue
		var label: String = String(sp[1])
		var category: String = String(sp[2])
		if cat.has(id):
			label = String((cat[id] as Dictionary).get("label", label))
			category = String((cat[id] as Dictionary).get("category", category))
		var spec: Dictionary = {"label": label, "category": category, "scope": "global", "handler": sp[3], "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static")}
		if (sp[4] as Callable).is_valid():
			spec["toggle"] = sp[4]
		Cmd.register(id, spec)


static func radius_in(pic: Rect2, side: int) -> Vector2:
	var px: float = maxf(ObjectUi.brush_px, 1.0) * 0.5
	var w: float = maxf(pic.size.x, 1.0)
	var h: float = maxf(pic.size.y, 1.0)
	return Vector2(px / w * float(side), px / h * float(side))


static func marks_in(marks: PackedVector2Array, pic: Rect2, side: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in marks:
		var u: float = (p.x - pic.position.x) / maxf(pic.size.x, 1.0)
		var v: float = (p.y - pic.position.y) / maxf(pic.size.y, 1.0)
		out.append(Vector2(u * float(side), v * float(side)))
	return out


static func _paint_edit(m: Dictionary, index: int, marks: PackedVector2Array, pic: Rect2, wipe: bool) -> Image:
	var side: int = maxi(int(m.get("edit_side", ObjectMask.EDIT_SIDE)), 16)
	var edit: Image = ObjectMask.edit_at(m, index)
	if edit == null:
		edit = ObjectMask.blank_edit(side)
	else:
		side = edit.get_width()
		if edit.get_format() != Image.FORMAT_RG8:
			edit.convert(Image.FORMAT_RG8)
	var pts: PackedVector2Array = marks_in(marks, pic, side)
	var radius: Vector2 = radius_in(pic, side)
	var stroke: Image = Brush.blank(side)
	Brush.paint(stroke, pts, radius, kind, true)
	var pad: float = maxf(radius.x, radius.y) + 2.0
	var box: Rect2 = Brush.bounds(pts, pad)
	var where: Rect2i = Rect2i(box.position.floor(), box.size.ceil() + Vector2.ONE)
	edit = ObjectMask.stroke_into_edit(edit, stroke, wipe, where)
	ObjectMask.put_edit(m, index, edit, ObjectMask.edit_box(m, index).merge(where) if ObjectMask.has_edit(m, index) else where)
	return ObjectMask.matte_with_edits(m, index)


static func paint_on(doc: Project, seq: Sequence, c: Clip, t: float, marks: PackedVector2Array, pic: Rect2, wipe: bool) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": ""}
	if doc == null or seq == null or c == null or marks.is_empty():
		out["error"] = "there is no clip under the playhead"
		return out
	var index: int = ObjectUi.frame_of(c, seq, t)
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var at: int = -1
	for i: int in masks.size():
		if ObjectMask.is_object(masks[i]) and (ObjectUi.active_mask.is_empty() or str((masks[i] as Dictionary).get("id", "")) == ObjectUi.active_mask):
			at = i
			break
	var m: Dictionary = {}
	if at < 0:
		if wipe:
			out["error"] = "there is no mask on this clip to wipe"
			return out
		m = ObjectMask.make(doc.mint_id("mask"), "Painted mask")
		masks.append(m)
		at = masks.size() - 1
	else:
		m = masks[at]
	var shown: Image = null
	if ObjectMask.is_tracked(m):
		shown = _paint_edit(m, index, marks, pic, wipe)
	else:
		var side: int = maxi(int(m.get("side", SIDE)), 16)
		var matte: Image = ObjectMask.matte_at(m, index)
		if matte == null:
			matte = Brush.blank(side)
		else:
			if matte.get_format() != Image.FORMAT_R8:
				matte.convert(Image.FORMAT_R8)
			side = matte.get_width()
		Brush.paint(matte, marks_in(marks, pic, side), radius_in(pic, side), kind, not wipe)
		ObjectMask.put_matte(m, index, matte)
		shown = matte
	masks[at] = m
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(seq.id, c.id, "masks", masks)]
	if not Verbs.run(doc, WIPE_LABEL if wipe else PAINT_LABEL, cmds):
		out["error"] = "the mask could not be written to the clip"
		return out
	ObjectUi.active_mask = str(m.get("id", ""))
	ObjectMatte.forget(ObjectUi.active_mask)
	ObjectUi.dim_forget()
	out["ok"] = true
	out["mask"] = ObjectUi.active_mask
	out["coverage"] = Brush.coverage(shown)
	return out


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not tool_on() or pic.size.x <= 0.0 or pic.size.y <= 0.0:
		return false
	var doc: Project = panel.call("doc")
	var seq: Sequence = panel.call("seq")
	if doc == null or seq == null:
		return false
	var view: Control = panel.get("view")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.alt_pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
			ObjectUi.step_brush(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			if view != null:
				view.call("redraw_overlay")
			return true
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			var marks: PackedVector2Array = PackedVector2Array()
			marks.append(mb.position)
			drag = {"marks": marks, "alt": mb.alt_pressed}
			if view != null:
				view.call("redraw_overlay")
			return true
		if drag.is_empty():
			return false
		var done_marks: PackedVector2Array = drag.get("marks", PackedVector2Array())
		var wipe: bool = bool(drag.get("alt", false))
		drag = {}
		var c: Clip = panel.call("gizmo_clip") if panel.has_method("gizmo_clip") else null
		if c == null:
			c = ObjectUi._clip_now(doc, seq)
		var done: Dictionary = paint_on(doc, seq, c, Session.playhead(), done_marks, pic, wipe)
		if not bool(done.get("ok", false)):
			Events.toast("Mask Brush: " + String(done.get("error", "it did not work")))
		if view != null:
			view.call("redraw_overlay")
		return true
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not drag.is_empty():
			var marks2: PackedVector2Array = drag.get("marks", PackedVector2Array())
			if marks2.is_empty() or marks2[marks2.size() - 1].distance_to(mm.position) >= STROKE_LEAST:
				marks2.append(mm.position)
				drag["marks"] = marks2
				if view != null:
					view.call("redraw_overlay")
			return true
		if view != null:
			view.call("redraw_overlay")
		return false
	return false


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not tool_on() or not e.pressed:
		return false
	if e.keycode == KEY_BRACKETLEFT or e.keycode == KEY_BRACKETRIGHT:
		ObjectUi.step_brush(1 if e.keycode == KEY_BRACKETRIGHT else -1)
		Events.toast("Mask Brush: " + str(int(round(ObjectUi.brush_px))) + " px")
		var v: Control = panel.get("view")
		if v != null:
			v.call("redraw_overlay")
		return true
	if e.keycode == KEY_ESCAPE and not drag.is_empty():
		drag = {}
		var v2: Control = panel.get("view")
		if v2 != null:
			v2.call("redraw_overlay")
		return true
	return false


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if not tool_on() or pic.size.x <= 0.0:
		return
	var marks: PackedVector2Array = drag.get("marks", PackedVector2Array())
	var ink: Color = OUT_INK if bool(drag.get("alt", false)) else INK
	if marks.size() == 1:
		ci.draw_circle(marks[0], ObjectUi.brush_px * 0.5, ink)
	elif marks.size() > 1:
		ci.draw_polyline(marks, ink, ObjectUi.brush_px, true)
		ci.draw_circle(marks[0], ObjectUi.brush_px * 0.5, ink)
		ci.draw_circle(marks[marks.size() - 1], ObjectUi.brush_px * 0.5, ink)
	var view: Control = panel.get("view")
	if view == null or not view.has_method("get_local_mouse_position"):
		return
	var at: Vector2 = view.call("get_local_mouse_position")
	if not pic.has_point(at):
		return
	ci.draw_arc(at, ObjectUi.brush_px * 0.5, 0.0, TAU, 28, RIM, 2.0, true)
	ci.draw_arc(at, ObjectUi.brush_px * 0.5, 0.0, TAU, 28, EDGE, 1.0, true)
