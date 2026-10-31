extends "res://ui/kit/pm_slot.gd"

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const EffectDrop := preload("res://modules/core_panels/effect_drop.gd")
const HitKit := preload("res://ui/timeline/timeline_hit.gd")
const LanesKit := preload("res://ui/timeline/timeline_lanes.gd")
const FxDropHint := preload("res://ui/timeline/timeline_fx_drop.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://modules/core_panels/effect_move_drop.gd"
const BIN_NODE := "EffectMoveBinSlot"
const TIMELINE_NODE := "EffectMoveTimelineSlot"
const BIN_MODE := "bin"
const TIMELINE_MODE := "timeline"
const OUTLINE_PX := 2.0
const CHIP_GAP := 2.0

var mode: String = TIMELINE_MODE
var host: Object = null
var _at: Vector2 = Vector2.ZERO
var _target: Dictionary = {}
var _copy: bool = false


static func make_slot(mode_: String, node_name: String, host_: Object) -> Control:
	var slot: Control = load(SELF_PATH).new()
	slot.name = node_name
	slot.set("mode", mode_)
	slot.set("host", host_)
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return slot


static func attach_timeline(canvas: Control) -> Control:
	if canvas == null:
		return null
	var have: Node = canvas.get_node_or_null(TIMELINE_NODE)
	if have is Control:
		have.set("host", canvas)
		return have
	var slot: Control = make_slot(TIMELINE_MODE, TIMELINE_NODE, canvas)
	canvas.add_child(slot)
	return slot


static func attach_bin(body: Control, panel: Object) -> Control:
	if body == null:
		return null
	var have: Node = body.get_node_or_null(BIN_NODE)
	if have is Control:
		have.set("host", panel)
		return have
	var slot: Control = make_slot(BIN_MODE, BIN_NODE, panel)
	body.add_child(slot)
	return slot


static func ensure_timeline() -> Control:
	var tl: Object = Bus.instance().panel("timeline")
	if tl == null:
		return null
	var canvas: Variant = tl.get("canvas")
	if not (canvas is Control) or not (canvas as Control).is_inside_tree():
		return null
	return attach_timeline(canvas as Control)


static func ensure_bin() -> Control:
	var bin: Object = Bus.instance().panel("bin")
	if bin == null:
		return null
	var body: Variant = bin.get("_body")
	if not (body is Control) or not (body as Control).is_inside_tree():
		return null
	return attach_bin(body as Control, bin)


static func ensure_targets() -> Array[Control]:
	var out: Array[Control] = []
	var tl: Control = ensure_timeline()
	if tl != null:
		out.append(tl)
	var bin: Control = ensure_bin()
	if bin != null:
		out.append(bin)
	return out


func _init() -> void:
	super()
	name = TIMELINE_NODE
	kinds = PackedStringArray([EffectOps.MOVE_KIND])
	priority = 2
	draw_highlight = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dropped.connect(_on_dropped)
	hover_moved.connect(_on_hover_moved)
	hover_changed.connect(_on_hover_changed)
	set_process(true)


func doc() -> Project:
	return Session.doc


func seq() -> Sequence:
	return Session.seq()


func from_clip(payload: Dictionary) -> String:
	return String(payload.get("clip", ""))


func effect_uid(payload: Dictionary) -> String:
	return String(payload.get("uid", ""))


func target_at(local: Vector2) -> Dictionary:
	if mode == BIN_MODE:
		return _bin_target(local)
	return _timeline_target(local)


func _timeline_target(local: Vector2) -> Dictionary:
	var canvas: Control = host as Control
	if canvas == null or not canvas.has_method("hit_at"):
		return {}
	var h: Dictionary = canvas.call("hit_at", local)
	var c: Clip = h.get("clip", null)
	if c == null:
		return {}
	return {"kind": "clip", "id": c.id, "media": c.media_id}


func _bin_target(local: Vector2) -> Dictionary:
	if host == null or not host.has_method("role_drop_pick"):
		return {}
	var hit: Variant = host.call("role_drop_pick", local)
	return hit if hit is Dictionary else {}


func ids_for(hit: Dictionary) -> PackedStringArray:
	if hit.is_empty():
		return PackedStringArray()
	if mode == BIN_MODE:
		return EffectOps.clips_of_media(seq(), String(hit.get("id", "")))
	return PackedStringArray([String(hit.get("id", ""))])


func refusal_for(hit: Dictionary) -> String:
	if hit.is_empty():
		return EffectOps.NO_TARGET
	if mode == BIN_MODE and ids_for(hit).is_empty():
		return EffectOps.NO_CLIPS_OF_FILE
	return ""


func hint_for(payload: Dictionary, hit: Dictionary, copy: bool) -> Dictionary:
	var tail: String = "" if copy else EffectDrop.COPY_HINT
	var why: String = refusal_for(hit)
	if not why.is_empty():
		return {"text": why, "hint": tail}
	return EffectOps.move_hint(doc(), seq(), from_clip(payload), effect_uid(payload), ids_for(hit), copy, EffectDrop.COPY_HINT)


func apply(payload: Dictionary, hit: Dictionary, copy: bool) -> Dictionary:
	var why: String = refusal_for(hit)
	if not why.is_empty():
		return EffectOps.result(false, false, why, "")
	return EffectOps.move_to(doc(), seq(), from_clip(payload), effect_uid(payload), ids_for(hit), copy)


func _on_dropped(payload: Dictionary, local: Vector2) -> void:
	var copy: bool = EffectDrop.copy_held()
	var hit: Dictionary = target_at(local)
	_target = {}
	queue_redraw()
	var res: Dictionary = apply(payload, hit, copy)
	if not bool(res["ok"]):
		Events.toast(String(res["why"]))
		return
	if not String(res["note"]).is_empty():
		Events.toast(String(res["note"]))


func _on_hover_moved(local: Vector2) -> void:
	var hit: Dictionary = target_at(local)
	var copy: bool = EffectDrop.copy_held()
	if hit == _target and copy == _copy and local.distance_to(_at) < 6.0:
		return
	_target = hit
	_copy = copy
	_at = local
	queue_redraw()


func _on_hover_changed(on: bool) -> void:
	_copy = EffectDrop.copy_held()
	if not on:
		_target = {}
	queue_redraw()


func _process(_delta: float) -> void:
	if not hovering:
		return
	var copy: bool = EffectDrop.copy_held()
	if copy == _copy:
		return
	_copy = copy
	queue_redraw()


func payload_now() -> Dictionary:
	var layer: Node = get_tree().get_first_node_in_group("pm_drag_layer") if is_inside_tree() else null
	if layer == null or not bool(layer.get("active")):
		return {}
	var p: Variant = layer.get("payload")
	return p if p is Dictionary else {}


func marks() -> Array[Rect2]:
	if _target.is_empty():
		return []
	if mode == BIN_MODE:
		if host == null or not host.has_method("role_drop_rects"):
			return []
		return host.call("role_drop_rects", String(_target.get("id", "")), false)
	return _timeline_marks()


func _timeline_marks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var canvas: Control = host as Control
	var s: Sequence = seq()
	if canvas == null or s == null or not canvas.has_method("geometry"):
		return out
	var c: Clip = s.clip_by_id(String(_target.get("id", "")))
	var tr: Track = s.track_of(String(_target.get("id", ""))) if c != null else null
	if c == null or tr == null:
		return out
	var g: Dictionary = canvas.call("geometry")
	var l: Dictionary = LanesKit.lane_for_track(canvas.call("lanes"), tr.id)
	if l.is_empty():
		return out
	var r: Rect2 = HitKit.clip_rect(g, l, c)
	r.position.x = maxf(r.position.x, float(g["header_w"]))
	r.size.x = maxf(r.size.x, 2.0)
	out.append(r)
	return out


func _draw() -> void:
	if not hovering:
		return
	for r: Rect2 in marks():
		draw_rect(r, Tk.c["selection_fill"], true)
		draw_rect(r.grow(-OUTLINE_PX * 0.5), Tk.c["accent"], false, OUTLINE_PX)
	var said: Dictionary = hint_for(payload_now(), _target, _copy)
	var f: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var at: Vector2 = _at + Vector2(14.0, 14.0)
	FxDropHint.draw_chip(self, at, String(said.get("text", "")), f, fs)
	var hint: String = String(said.get("hint", ""))
	if hint.is_empty():
		return
	FxDropHint.draw_chip(self, at + Vector2(0.0, f.get_height(fs) + PmText.chip_pad() * 2.0 + CHIP_GAP), hint, f, fs)
