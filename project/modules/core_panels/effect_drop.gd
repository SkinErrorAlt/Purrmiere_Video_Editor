extends "res://ui/kit/pm_slot.gd"

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Verbs := preload("res://doc/verbs.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const PAIR_LAYOUT := "res://engine/pair_layout.gd"
const RegionFxCmds := preload("res://doc/commands/region_fx_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const FxDropHint := preload("res://ui/timeline/timeline_fx_drop.gd")
const NODE_NAME := "EffectDropSlot"
const VIEWS_NODE_NAME := "EffectDropViews"
const NONE_SELECTED := "Select a clip first, a dropped effect goes on the selected clips"
const ONLY_PREFIX := "On "
const ONLY_SUFFIX := " only"
const WHOLE_HINT := "Alt: whole clip"
const COPY_HINT := "Ctrl: copy instead of move"
const MOVING_HINT := "Let go to move it, Ctrl to copy"
const OUTLINE_PX := 2.0

var picker: Callable = Callable()
var region_picker: Callable = Callable()
var view_picker: Callable = Callable()
var views_clip: Callable = Callable()
var view_button: Callable = Callable()
var _region: Dictionary = {}
var _hover_clip: String = ""
var _hover_pos: Vector2 = Vector2.ZERO


static func attach(host: Control, pick: Callable = Callable(), region_pick: Callable = Callable()) -> Control:
	if host == null:
		return null
	var have: Node = host.get_node_or_null(NODE_NAME)
	if have is Control:
		if region_pick.is_valid():
			have.set("region_picker", region_pick)
		return have
	var script: GDScript = load("res://modules/core_panels/effect_drop.gd")
	var slot: Control = script.new()
	slot.set("picker", pick)
	slot.set("region_picker", region_pick)
	host.add_child(slot)
	return slot


static func attach_views(host: Control, view_at: Callable, clip_for: Callable, button_for: Callable = Callable()) -> Control:
	if host == null:
		return null
	var have: Node = host.get_node_or_null(VIEWS_NODE_NAME)
	var slot: Control = null
	if have is Control:
		slot = have
	else:
		var script: GDScript = load("res://modules/core_panels/effect_drop.gd")
		slot = script.new()
		slot.name = VIEWS_NODE_NAME
		host.add_child(slot)
	slot.set("view_picker", view_at)
	slot.set("views_clip", clip_for)
	slot.set("view_button", button_for)
	slot.set("priority", 1)
	return slot


static func quad_uv(quad: PackedVector2Array, p: Vector2) -> Vector2:
	var ex: Vector2 = quad[1] - quad[0]
	var ey: Vector2 = quad[3] - quad[0]
	var det: float = ex.x * ey.y - ex.y * ey.x
	if absf(det) < 0.000001:
		return Vector2(-1.0, -1.0)
	var d: Vector2 = p - quad[0]
	return Vector2((d.x * ey.y - d.y * ey.x) / det, (ex.x * d.y - ex.y * d.x) / det)


static func quad_point(quad: PackedVector2Array, uv: Vector2) -> Vector2:
	return quad[0] + (quad[1] - quad[0]) * uv.x + (quad[3] - quad[0]) * uv.y


static func region_under(c: Clip, s: Sequence, d: Project, local_pos: Vector2, pic: Rect2, quad: PackedVector2Array) -> Dictionary:
	if c == null or s == null or quad.size() != 4 or pic.size.x <= 0.0:
		return {}
	var e: Dictionary = RegionFx.first_pair(c)
	if e.is_empty():
		return {}
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var uv: Vector2 = quad_uv(quad, (local_pos - pic.position) / maxf(k, 0.0001))
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return {}
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var src: Vector2i = Vector2i(m.width, m.height) if m != null and m.width > 0 and m.height > 0 else Vector2i(s.width, s.height)
	for bx: Variant in load(PAIR_LAYOUT).call("region_boxes", c, e, s.playhead, Vector2i(s.width, s.height), src, s.fps):
		var box: Rect2 = (bx as Dictionary)["box"]
		if not box.has_point(uv):
			continue
		var index: int = int((bx as Dictionary)["index"])
		var outline: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			outline.append(pic.position + quad_point(quad, corner) * k)
		return {"clip": c.id, "pv": String(e.get("uid", "")), "index": index, "name": RegionFx.region_name(e, index), "outline": outline}
	return {}


static func refusal(def: Dictionary) -> String:
	if bool(def.get("audio", false)):
		return "Sound effects go on clips that have sound"
	return "Picture effects go on clips that have a picture"


func _init() -> void:
	super()
	name = NODE_NAME
	kinds = PackedStringArray(["effect"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dropped.connect(_on_dropped)
	hover_moved.connect(_on_hover_moved)
	hover_changed.connect(_on_hover_changed)


func targets_for(s: Sequence, local_pos: Vector2) -> PackedStringArray:
	var under: String = ""
	if picker.is_valid():
		under = String(picker.call(local_pos))
	if not under.is_empty():
		return Verbs.drop_targets(s, under)
	return Verbs.selection(s)


static func whole_held() -> bool:
	return Input.is_key_pressed(KEY_ALT)


static func copy_held() -> bool:
	return Input.is_key_pressed(KEY_CTRL)


func region_for(local_pos: Vector2) -> Dictionary:
	if view_picker.is_valid():
		return _view_region(local_pos)
	if not region_picker.is_valid() or whole_held():
		return {}
	var hit: Variant = region_picker.call(local_pos)
	return hit if hit is Dictionary else {}


func _view_region(local_pos: Vector2) -> Dictionary:
	var index: int = int(view_picker.call(local_pos))
	var s: Sequence = Session.seq()
	var aim: Variant = views_clip.call() if views_clip.is_valid() else ""
	var clip_id: String = String((aim as Dictionary).get("clip_id", "")) if aim is Dictionary else String(aim)
	var pv_uid: String = String((aim as Dictionary).get("uid", "")) if aim is Dictionary else ""
	var c: Variant = s.clip_by_id(clip_id) if s != null and not clip_id.is_empty() else null
	if index < 0 or c == null:
		return {}
	var e: Dictionary = RegionFx.live_pair(c, pv_uid) if not pv_uid.is_empty() else RegionFx.first_pair(c)
	if e.is_empty() or index >= RegionFx.region_count(e):
		return {}
	var hit: Dictionary = {"clip": clip_id, "pv": String(e.get("uid", "")), "index": index, "name": RegionFx.region_name(e, index)}
	var b: Variant = view_button.call(index) if view_button.is_valid() else null
	if b is Control and is_instance_valid(b):
		var inv: Transform2D = get_global_transform().affine_inverse()
		var g: Rect2 = (b as Control).get_global_rect()
		hit["outline"] = PackedVector2Array([inv * g.position, inv * Vector2(g.end.x, g.position.y), inv * g.end, inv * Vector2(g.position.x, g.end.y)])
	return hit


func drop_on_region(hit: Dictionary, def: Dictionary) -> int:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null or hit.is_empty():
		return 0
	var why: String = RegionFx.refusal(def)
	if not why.is_empty():
		Events.toast(why)
		return 0
	var where: Array[Dictionary] = RegionFxCmds.targets(s, String(hit["clip"]), String(hit["pv"]), int(hit["index"]))
	var n: int = RegionFxCmds.drop(d, s, where, def)
	if n == 0:
		Events.toast("That region's clip is locked or cannot take this effect")
	return n


func _on_dropped(payload: Dictionary, local_pos: Vector2) -> void:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	_region = {}
	queue_redraw()
	if d == null or s == null:
		return
	var id: String = String(payload.get("id", ""))
	var def: Dictionary = EffectSource.get_def(id)
	if def.is_empty():
		return
	var hit: Dictionary = region_for(local_pos)
	if not hit.is_empty():
		if drop_on_region(hit, def) > 0:
			EffectSource.note_used(id)
		return
	if view_picker.is_valid():
		return
	var ids: PackedStringArray = targets_for(s, local_pos)
	if ids.is_empty():
		Events.toast(NONE_SELECTED)
		return
	if Verbs.drop_effect(d, s, ids, def) == 0:
		Events.toast(refusal(def))
		return
	EffectSource.note_used(id)


func _on_hover_moved(local_pos: Vector2) -> void:
	var hit: Dictionary = region_for(local_pos)
	if hit != _region:
		_region = hit
		queue_redraw()
	_note_hover_clip(local_pos)


func _note_hover_clip(local_pos: Vector2) -> void:
	var under: String = String(picker.call(local_pos)) if picker.is_valid() and not view_picker.is_valid() else ""
	if under != _hover_clip or local_pos.distance_to(_hover_pos) > 24.0:
		_hover_clip = under
		_hover_pos = local_pos
		queue_redraw()


func _on_hover_changed(on: bool) -> void:
	if not on and not _region.is_empty():
		_region = {}
		queue_redraw()


func _draw() -> void:
	if not hovering or not draw_highlight:
		return
	if _region.is_empty():
		if view_picker.is_valid():
			return
		super()
		FxDropHint.draw_chip(self, _hover_pos + Vector2(14.0, 14.0), FxDropHint.monitor_hint(Session.seq(), _hover_clip), Tk.font("body"), Tk.fs(Tk.sz("font_body")))
		return
	var outline: PackedVector2Array = _region.get("outline", PackedVector2Array())
	if outline.size() >= 3:
		draw_colored_polygon(outline, Tk.c["selection_fill"])
		var closed: PackedVector2Array = outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, Tk.c["accent"], OUTLINE_PX, true)
	var at: Vector2 = outline[0] if not outline.is_empty() else Vector2.ZERO
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var text: String = ONLY_PREFIX + String(_region.get("name", "")) + ONLY_SUFFIX
	var hint: String = "" if view_picker.is_valid() else WHOLE_HINT
	var gap: float = PmText.pad() * 2.0 if not hint.is_empty() else 0.0
	var tw: float = PmText.width_of(font, text, fs)
	var w: float = tw + gap + PmText.width_of(font, hint, fs) + PmText.pad() * 2.0
	var h: float = font.get_height(fs) + PmText.chip_pad() * 2.0
	var box: Rect2 = Rect2(at + Vector2(OUTLINE_PX * 2.0, OUTLINE_PX * 2.0), Vector2(minf(w, maxf(size.x - at.x - OUTLINE_PX * 4.0, 1.0)), h))
	draw_rect(box, Tk.c["bg_panel_high"], true)
	draw_rect(Rect2(box.position + Vector2(0.5, 0.5), box.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
	var base: float = PmText.baseline_in(font, fs, box)
	var drawn: Rect2 = PmText.draw(self, font, box, text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), base)
	if hint.is_empty() or drawn.size.x < tw - 0.5:
		return
	var rest: Rect2 = Rect2(Vector2(drawn.end.x + gap, box.position.y), Vector2(box.end.x - drawn.end.x - gap, box.size.y))
	if rest.size.x > 1.0:
		PmText.draw(self, font, rest, hint, fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, 0.0, base)
