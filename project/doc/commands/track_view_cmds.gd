extends RefCounted

const VERSION := 1
const SELF := preload("res://doc/commands/track_view_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const StackCmds := preload("res://doc/commands/stack_cmds.gd")
const ClipFilter := preload("res://doc/clip_filter.gd")
const EPS := 0.00001

static var spill: bool = true


class SetTrackView extends "res://doc/commands/command.gd":
	var view_next: Dictionary = {}
	var view_old: Dictionary = {}

	func _init(p_seq_id: String, p_view: Dictionary, p_label: String = "Timeline view") -> void:
		label = p_label
		seq_id = p_seq_id
		view_next = ClipFilter.clean(p_view)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null or ClipFilter.clean(s.track_view) == view_next:
			ok = false
			return
		view_old = s.track_view.duplicate(true)
		s.track_view = view_next.duplicate(true)
		doc.touch("timeline_view")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			return
		s.track_view = view_old.duplicate(true)
		doc.touch("timeline_view")


class SetClipRole extends "res://doc/commands/command.gd":
	var ids: PackedStringArray = PackedStringArray()
	var role: String = ""
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_ids: PackedStringArray, p_role: String) -> void:
		seq_id = p_seq_id
		ids = p_ids
		role = p_role if ClipFilter.ROLES.has(p_role) else ""
		label = "Sound role " + (ClipFilter.ROLE_NAMES[role] if not role.is_empty() else "worked out")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = {}
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c != null and c.role != role:
				old[id] = c.role
				c.role = role
		if old.is_empty():
			ok = false
			return
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for id: Variant in old.keys():
			var c: Clip = s.clip_by_id(String(id))
			if c != null:
				c.role = String(old[id])
		doc.touch("meta")


class ClearTrack extends "res://doc/commands/composite.gd":
	var track_id: String = ""
	var refusal: String = ""
	var removed: int = 0

	func _init(p_seq_id: String, p_track_id: String) -> void:
		seq_id = p_seq_id
		track_id = p_track_id
		label = "Clear track"

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		var t: Track = s.track_by_id(track_id) if s != null else null
		if t == null:
			refusal = "That track is gone"
			return false
		label = "Clear " + s.display_label(t)
		if t.locked:
			refusal = s.display_label(t) + " is locked, unlock it to clear it"
			return false
		var ids: PackedStringArray = PackedStringArray()
		var held: int = 0
		for c: Clip in t.clips:
			if s.group_locked(c):
				held += 1
			else:
				ids.append(c.id)
		if ids.is_empty():
			refusal = s.display_label(t) + " has nothing to clear" if held == 0 else "Every clip on " + s.display_label(t) + " is in a locked group"
			return false
		apply(doc, ClipCmds.RemoveClips.new(seq_id, ids))
		removed = ids.size()
		if held > 0:
			refusal = ClipFilter.counted(held, "clip in a locked group was", "clips in locked groups were") + " kept"
		return removed > 0


class MoveToTrack extends "res://doc/commands/composite.gd":
	var ids: PackedStringArray = PackedStringArray()
	var target_id: String = ""
	var new_kind: String = ""
	var new_label: String = ""
	var partners: bool = false
	var refusal: String = ""
	var moved: int = 0
	var new_tracks: PackedStringArray = PackedStringArray()
	var skipped_locked: int = 0
	var skipped_kind: int = 0
	var stacked: int = 0

	func _init(p_seq_id: String, p_ids: PackedStringArray, p_target_id: String, p_new_kind: String = "", p_new_label: String = "", p_partners: bool = false) -> void:
		seq_id = p_seq_id
		ids = p_ids
		target_id = p_target_id
		new_kind = p_new_kind
		new_label = p_new_label
		partners = p_partners
		label = "Move to track"

	static func _overlaps(list: Array, a: float, b: float) -> int:
		var top: int = -1
		for o: Vector3 in list:
			if o.y > a + EPS and o.x < b - EPS:
				top = maxi(top, int(o.z))
		return top

	func _new_track(doc: Project, s: Sequence, kind: String, name_: String, after: Track) -> Track:
		var list: Array[Track] = s.tracks_of_kind(kind)
		var at: int = list.find(after) + 1 if after != null else list.size()
		var t: Track = doc.make_track(kind, name_)
		var cmd: Command = apply(doc, TrackCmds.AddTrack.new(seq_id, kind, at, t.to_dict()))
		if not cmd.ok:
			return null
		new_tracks.append(t.id)
		return s.track_by_id(t.id)

	static func _overflow_name(s: Sequence, base: Track, n: int) -> String:
		if Track.is_classic_label(base.label):
			return ("V" if base.kind == "video" else "A") + str(s.tracks_of_kind(base.kind).size() + 1)
		return base.label + " " + str(n)

	func _wanted(s: Sequence) -> Array[Clip]:
		var out: Array[Clip] = []
		var seen: Dictionary = {}
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c != null and not seen.has(c.id):
				seen[c.id] = true
				out.append(c)
		if not partners:
			return out
		var by_link: Dictionary = {}
		for c: Clip in out:
			if not c.link_id.is_empty():
				by_link[c.link_id] = true
		if by_link.is_empty():
			return out
		for other: Clip in s.all_clips():
			if not other.link_id.is_empty() and by_link.has(other.link_id) and not seen.has(other.id):
				seen[other.id] = true
				out.append(other)
		return out

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			refusal = "No sequence"
			return false
		var target: Track = null
		if target_id.is_empty():
			var kind: String = new_kind if new_kind == "audio" else "video"
			var name_: String = new_label if not new_label.is_empty() else ("V" if kind == "video" else "A") + str(s.tracks_of_kind(kind).size() + 1)
			target = _new_track(doc, s, kind, name_, null)
			if target == null:
				refusal = "The new track could not be made"
				return false
		else:
			target = s.track_by_id(target_id)
			if target == null:
				refusal = "That track is gone"
				return false
			if target.locked:
				refusal = s.display_label(target) + " is locked"
				return false
		label = "Move to " + s.display_label(target)
		var movers: Array[Clip] = []
		var mover_set: Dictionary = {}
		var kinds: Dictionary = {}
		for c: Clip in _wanted(s):
			var src: Track = s.track_of(c.id)
			if src == null:
				continue
			if src.locked or s.group_locked(c):
				skipped_locked += 1
				continue
			var ck: String = src.clip_kind(c)
			if not target.accepts(ck):
				skipped_kind += 1
				continue
			movers.append(c)
			mover_set[c.id] = true
			kinds[c.id] = ck
		if movers.is_empty():
			refusal = "Nothing to move"
			if skipped_kind > 0:
				refusal += ", " + s.display_label(target) + " takes " + target.kind + " only"
			if skipped_locked > 0:
				refusal += ", " + ClipFilter.counted(skipped_locked, "clip is", "clips are") + " on a locked track or in a locked group"
			new_tracks = PackedStringArray()
			return false
		movers.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start or (a.start == b.start and a.id < b.id))
		var lanes: Array[Track] = [target]
		var used: Array = [[]]
		for c: Clip in target.clips:
			if not mover_set.has(c.id):
				(used[0] as Array).append(Vector3(c.start, c.end(), float(c.stack)))
		var moves: Array[Dictionary] = []
		var order: Dictionary = {}
		var stack_mode: bool = s.overlap_clips
		for c: Clip in movers:
			var a: float = c.start
			var b: float = c.end()
			var li: int = -1
			var st: int = 0
			if stack_mode:
				li = 0
				var top: int = _overlaps(used[0], a, b)
				st = top + 1 if top >= 0 else 0
				if st > 0:
					stacked += 1
			else:
				for k: int in lanes.size():
					if _overlaps(used[k], a, b) < 0:
						li = k
						break
				if li < 0 and not SELF.spill:
					li = 0
				if li < 0:
					var extra: Track = _new_track(doc, s, target.kind, _overflow_name(s, target, lanes.size() + 1), lanes[lanes.size() - 1])
					if extra == null:
						refusal = "An extra track could not be made"
						return false
					lanes.append(extra)
					used.append([])
					li = lanes.size() - 1
			(used[li] as Array).append(Vector3(a, b, float(st)))
			moves.append({"id": c.id, "start": c.start, "track_id": lanes[li].id})
			if c.stack != st:
				order[c.id] = st
		apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		if not order.is_empty():
			apply(doc, StackCmds.SetStackOrder.new(seq_id, order, "Stack order"))
		moved = movers.size()
		return true
