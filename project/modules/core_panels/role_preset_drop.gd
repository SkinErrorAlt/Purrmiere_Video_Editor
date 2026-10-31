extends "res://ui/kit/pm_slot.gd"

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const RoleDrop := preload("res://doc/role_drop.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const HitKit := preload("res://ui/timeline/timeline_hit.gd")
const LanesKit := preload("res://ui/timeline/timeline_lanes.gd")
const FxDropHint := preload("res://ui/timeline/timeline_fx_drop.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://modules/core_panels/role_preset_drop.gd"
const BIN_NODE := "RolePresetBinSlot"
const TIMELINE_NODE := "RolePresetTimelineSlot"
const BIN_MODE := "bin"
const TIMELINE_MODE := "timeline"
const OUTLINE_PX := 2.0
const CHIP_GAP := 2.0

var mode: String = BIN_MODE
var host: Object = null
var _at: Vector2 = Vector2.ZERO
var _target: Dictionary = {}
var _whole: bool = false
var _held_id: String = ""
var _held: Dictionary = {}


static func make_slot(mode_: String, node_name: String, host_: Object) -> Control:
	var slot: Control = load(SELF_PATH).new()
	slot.name = node_name
	slot.set("mode", mode_)
	slot.set("host", host_)
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


static func ensure_timeline() -> Control:
	var tl: Object = Bus.instance().panel("timeline")
	if tl == null:
		return null
	var canvas: Variant = tl.get("canvas")
	if not (canvas is Control) or not (canvas as Control).is_inside_tree():
		return null
	return attach_timeline(canvas as Control)


func _init() -> void:
	super()
	name = BIN_NODE
	kinds = PackedStringArray([RoleDrop.DRAG_KIND])
	priority = 2
	draw_highlight = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dropped.connect(_on_dropped)
	hover_moved.connect(_on_hover_moved)
	hover_changed.connect(_on_hover_changed)


func doc() -> Project:
	return Session.doc


func seq() -> Sequence:
	return Session.seq()


func preset_of(payload: Dictionary) -> Dictionary:
	var id: String = String(payload.get("id", ""))
	if id.is_empty():
		return {}
	if id != _held_id:
		_held_id = id
		_held = RoleDrop.by_id(doc(), id)
	return _held


func target_at(local: Vector2) -> Dictionary:
	if mode == TIMELINE_MODE:
		return _timeline_target(local)
	return _bin_target(local)


func _bin_target(local: Vector2) -> Dictionary:
	if host == null or not host.has_method("role_drop_pick"):
		return {}
	var hit: Variant = host.call("role_drop_pick", local)
	return hit if hit is Dictionary else {}


func _timeline_target(local: Vector2) -> Dictionary:
	var canvas: Control = host as Control
	if canvas == null or not canvas.has_method("hit_at"):
		return {}
	var h: Dictionary = canvas.call("hit_at", local)
	var c: Clip = h.get("clip", null)
	if c == null:
		return {}
	return {"kind": "clip", "id": c.id, "media": c.media_id}


func bin_ids(hit: Dictionary, whole: bool) -> PackedStringArray:
	if host == null or not host.has_method("role_drop_targets"):
		return PackedStringArray()
	return host.call("role_drop_targets", String(hit.get("id", "")), whole)


func apply(hit: Dictionary, preset: Dictionary, whole: bool) -> Dictionary:
	var d: Project = doc()
	if d == null or preset.is_empty():
		return RoleDrop.result(false, false, RoleDrop.UNREADABLE, "")
	if mode == TIMELINE_MODE:
		if hit.is_empty():
			return RoleDrop.result(false, false, RoleDrop.NO_TARGET, "")
		return RoleDrop.drop_on_clip(d, seq(), String(hit.get("id", "")), preset, whole)
	var ids: PackedStringArray = bin_ids(hit, whole)
	if ids.is_empty():
		return RoleDrop.result(false, false, RoleDrop.NO_TARGET, "")
	return RoleDrop.drop_on_media(d, ids, preset)


func hint_for(hit: Dictionary, preset: Dictionary, whole: bool) -> Dictionary:
	var d: Project = doc()
	if d == null or preset.is_empty():
		return {"text": RoleDrop.UNREADABLE, "hint": ""}
	if mode == TIMELINE_MODE:
		if hit.is_empty():
			return {"text": RoleDrop.NO_TARGET, "hint": RoleDrop.WHOLE_HINT if not whole else ""}
		return RoleDrop.clip_hint(d, seq(), String(hit.get("id", "")), preset, whole)
	var ids: PackedStringArray = bin_ids(hit, whole)
	if ids.is_empty():
		return {"text": RoleDrop.NO_TARGET, "hint": RoleDrop.BIN_WHOLE_HINT if not whole else ""}
	return RoleDrop.media_hint(d, ids, preset, whole)


func _on_dropped(payload: Dictionary, local: Vector2) -> void:
	var whole: bool = RoleDrop.whole_held()
	var hit: Dictionary = target_at(local)
	_target = {}
	queue_redraw()
	var res: Dictionary = apply(hit, preset_of(payload), whole)
	if not bool(res["ok"]):
		Events.toast(String(res["why"]))
		return
	if not String(res["note"]).is_empty():
		Events.toast(String(res["note"]))


func _on_hover_moved(local: Vector2) -> void:
	var hit: Dictionary = target_at(local)
	var whole: bool = RoleDrop.whole_held()
	if hit == _target and whole == _whole and local.distance_to(_at) < 6.0:
		return
	_target = hit
	_whole = whole
	_at = local
	queue_redraw()


func _on_hover_changed(on: bool) -> void:
	if not on:
		_target = {}
		_held_id = ""
		_held = {}
		queue_redraw()


func payload_now() -> Dictionary:
	var layer: Node = get_tree().get_first_node_in_group("pm_drag_layer") if is_inside_tree() else null
	if layer == null or not bool(layer.get("active")):
		return {}
	var p: Variant = layer.get("payload")
	return p if p is Dictionary else {}


func marks() -> Array[Rect2]:
	if mode == TIMELINE_MODE:
		return _timeline_marks()
	if host == null or not host.has_method("role_drop_rects"):
		return []
	return host.call("role_drop_rects", String(_target.get("id", "")), _whole)


func _timeline_marks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var canvas: Control = host as Control
	var s: Sequence = seq()
	if canvas == null or s == null or _target.is_empty() or not canvas.has_method("geometry"):
		return out
	var ids: PackedStringArray = PackedStringArray([String(_target.get("id", ""))])
	if _whole:
		ids = RoleDrop.clips_of_media(s, String(_target.get("media", "")), true)
	var g: Dictionary = canvas.call("geometry")
	var lanes: Dictionary = canvas.call("lanes")
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		var tr: Track = s.track_of(id)
		if c == null or tr == null:
			continue
		var l: Dictionary = LanesKit.lane_for_track(lanes, tr.id)
		if l.is_empty():
			continue
		var r: Rect2 = HitKit.clip_rect(g, l, c)
		r.position.x = maxf(r.position.x, float(g["header_w"]))
		r.size.x = maxf(r.size.x, 2.0)
		out.append(r)
	return out


func _draw() -> void:
	if not hovering:
		return
	var preset: Dictionary = preset_of(payload_now())
	for r: Rect2 in marks():
		draw_rect(r, Tk.c["selection_fill"], true)
		draw_rect(r.grow(-OUTLINE_PX * 0.5), Tk.c["accent"], false, OUTLINE_PX)
	var said: Dictionary = hint_for(_target, preset, _whole)
	var f: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var at: Vector2 = _at + Vector2(14.0, 14.0)
	FxDropHint.draw_chip(self, at, String(said.get("text", "")), f, fs)
	var hint: String = String(said.get("hint", ""))
	if hint.is_empty():
		return
	FxDropHint.draw_chip(self, at + Vector2(0.0, f.get_height(fs) + PmText.chip_pad() * 2.0 + CHIP_GAP), hint, f, fs)
