extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const MoveAfter := preload("res://doc/commands/move_after_cmds.gd")
const TOOL := "track_select"
const ORIGIN_KEY := "move_after"
const NOTHING_TEXT := "Nothing after this point to move"

static var last_press_us: int = 0
static var last_release_us: int = 0
static var last_count: int = 0


static func press(canvas: Control, h: Dictionary, pos: Vector2, mods: Dictionary) -> bool:
	var t0: int = Time.get_ticks_usec()
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var tr: Track = h.get("track", null)
	if d == null or s == null or tr == null:
		return false
	var t: float = maxf(float(h.get("t", 0.0)), 0.0)
	var back: bool = bool(mods.get("shift", false))
	var one: bool = bool(mods.get("ctrl", false))
	var only: Track = tr if one else null
	var ids: PackedStringArray = MoveAfter.forward_ids(s, t, only, back)
	if one and bool(canvas.get("linked_selection")):
		ids = Verbs.MoveRule.pick(s, ids)
	var movable: PackedStringArray = Verbs.unlocked(s, ids) if not back else PackedStringArray()
	if back or movable.is_empty():
		Verbs.select(d, s, ids, "add" if back else "replace")
		last_press_us = Time.get_ticks_usec() - t0
		return true
	var quiet: bool = _select_quietly(s, ids)
	var anchor: Clip = h.get("clip", null)
	if anchor == null or not movable.has(anchor.id):
		anchor = _earliest(s, movable)
	var hit: Dictionary = h.duplicate()
	hit["clip"] = anchor
	hit["track"] = s.track_of(anchor.id)
	hit["edge"] = ""
	var drag: RefCounted = canvas.get("drag")
	drag.set("preset_ids", movable)
	drag.call("begin", "move", hit, pos, {"ctrl": false, "shift": false, "alt": false})
	var origin: Dictionary = drag.get("origin")
	origin[ORIGIN_KEY] = {"announce": quiet, "t": t, "every": not one, "all": ids.size() == movable.size() + _on_locked(s, ids), "free": MoveAfter.forward_free(s, t, only)}
	last_count = movable.size()
	canvas.queue_redraw()
	last_press_us = Time.get_ticks_usec() - t0
	return true


static func _select_quietly(s: Sequence, ids: PackedStringArray) -> bool:
	var had_transition: bool = not s.selected_transition.is_empty()
	s.selected_transition = {}
	s.picked_clip_ids = ids.duplicate()
	if s.selected_clip_ids == ids and not had_transition:
		return false
	s.selected_clip_ids = ids.duplicate()
	return true


static func finish(drag: RefCounted) -> void:
	var origin: Dictionary = drag.get("origin")
	var info: Dictionary = origin.get(ORIGIN_KEY, {})
	if not bool(info.get("announce", false)):
		return
	info["announce"] = false
	var host: Control = drag.get("host")
	var d: Project = host.call("doc") if host != null else null
	if d != null:
		d.changed.emit("selection")


static func _on_locked(s: Sequence, ids: PackedStringArray) -> int:
	var n: int = 0
	for id: String in ids:
		var t: Track = s.track_of(id)
		if t != null and t.locked:
			n += 1
	return n


static func _earliest(s: Sequence, ids: PackedStringArray) -> Clip:
	var best: Clip = null
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c != null and (best == null or c.start < best.start):
			best = c
	return best


static func owns(drag: RefCounted) -> bool:
	return (drag.get("origin") as Dictionary).has(ORIGIN_KEY)


static func release(drag: RefCounted, d: Project, s: Sequence, place: String) -> bool:
	var t0: int = Time.get_ticks_usec()
	var info: Dictionary = (drag.get("origin") as Dictionary).get(ORIGIN_KEY, {})
	var delta: float = float(drag.get("delta_t"))
	var ids: PackedStringArray = drag.get("ids")
	if absf(delta) < MoveAfter.EPS or ids.is_empty():
		return false
	var did: bool = false
	if bool(info.get("all", false)) and (place != MoveAfter.OVERLAP or delta > 0.0) and MoveAfter.fast_ok(s, ids, bool(info.get("every", false))):
		var free: Array[Dictionary] = []
		free.assign(info.get("free", []))
		did = Verbs.run(d, MoveAfter.LABEL, [MoveAfter.command(s, ids, free, delta, place)])
	else:
		did = Verbs.move_selection(d, s, delta, 0, place, String(drag.get("clip_id")))
	last_release_us = Time.get_ticks_usec() - t0
	return did
