extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Marker := preload("res://doc/marker.gd")
const Follow := preload("res://doc/marker_follow.gd")
const Layers := preload("res://doc/marker_layers.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const NAME_STEM := "Run"
const RULE := "A run is markers grouped together. They stay separate markers, but the run is drawn as one bracket with each point marker reaching to the next, and dragging any marker of a run moves the whole run. Hold Alt while dragging to move one marker on its own."


static func time_of(seq: Sequence, m: Marker) -> float:
	return Follow.resolved_time(seq, m) if m.follows() else m.time


static func names(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for m: Marker in seq.markers:
		if not m.run.is_empty() and not out.has(m.run):
			out.append(m.run)
	return out


static func members(seq: Sequence, run: String) -> Array[Marker]:
	var out: Array[Marker] = []
	if seq == null or run.is_empty():
		return out
	for m: Marker in seq.markers:
		if m.run == run:
			out.append(m)
	out.sort_custom(func(a: Marker, b: Marker) -> bool: return time_of(seq, a) < time_of(seq, b) or (time_of(seq, a) == time_of(seq, b) and a.id < b.id))
	return out


static func member_ids(seq: Sequence, run: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: Marker in members(seq, run):
		out.append(m.id)
	return out


static func with_runs(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = ids.duplicate()
	if seq == null:
		return out
	var runs: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var m: Marker = seq.marker_by_id(id)
		if m != null and not m.run.is_empty() and not runs.has(m.run):
			runs.append(m.run)
	for run: String in runs:
		for mid: String in member_ids(seq, run):
			if not out.has(mid):
				out.append(mid)
	return out


static func joined(seq: Sequence, run: String) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var list: Array[Marker] = members(seq, run)
	for i: int in list.size():
		var m: Marker = list[i]
		var a: float = time_of(seq, m)
		var b: float = a + maxf(m.duration, 0.0)
		if m.duration <= 0.0:
			if i + 1 < list.size():
				b = maxf(time_of(seq, list[i + 1]), a)
			else:
				b = a + Layers.length_of(seq, Layers.lane_of(seq, m))
		out.append(Vector2(a, b))
	return out


static func span(seq: Sequence, run: String) -> Vector2:
	var parts: PackedVector2Array = joined(seq, run)
	if parts.is_empty():
		return Vector2(-1.0, -1.0)
	var lo: float = INF
	var hi: float = -INF
	for p: Vector2 in parts:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.y)
	return Vector2(lo, hi)


static func runs_on_lane(seq: Sequence, lane: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	var idx: Dictionary = Layers.index(seq)
	var by: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for m: Marker in seq.markers:
		if m.run.is_empty() or Layers.lane_in(idx, m) != lane:
			continue
		if not by.has(m.run):
			by[m.run] = []
			order.append(m.run)
		(by[m.run] as Array).append(m)
	for run: String in order:
		var list: Array = by[run]
		if list.size() < 1:
			continue
		var whole: Vector2 = span(seq, run)
		out.append({"name": run, "from": whole.x, "to": whole.y, "parts": joined(seq, run), "count": list.size(), "first": list[0]})
	return out


static func next_name(seq: Sequence) -> String:
	var taken: PackedStringArray = names(seq)
	var n: int = 1
	while taken.has(NAME_STEM + " " + str(n)):
		n += 1
	return NAME_STEM + " " + str(n)


static func group(doc: Project, seq: Sequence, ids: PackedStringArray, name: String = "") -> String:
	if doc == null or seq == null or ids.size() < 2:
		return ""
	var run: String = name.strip_edges()
	if run.is_empty():
		run = next_name(seq)
	var cmds: Array[Command] = []
	for id: String in ids:
		var m: Marker = seq.marker_by_id(id)
		if m != null and m.run != run:
			cmds.append(MarkerCmds.SetMarker.new(seq.id, "", id, {"run": run}))
	if cmds.is_empty() or not Verbs.run(doc, "Group markers into " + run, cmds):
		return ""
	return run


static func ungroup(doc: Project, seq: Sequence, ids: PackedStringArray) -> int:
	if doc == null or seq == null:
		return 0
	var cmds: Array[Command] = []
	for id: String in with_runs(seq, ids):
		var m: Marker = seq.marker_by_id(id)
		if m != null and not m.run.is_empty():
			cmds.append(MarkerCmds.SetMarker.new(seq.id, "", id, {"run": ""}))
	if cmds.is_empty() or not Verbs.run(doc, "Ungroup markers", cmds):
		return 0
	return cmds.size()


static func rename(doc: Project, seq: Sequence, run: String, to: String) -> int:
	var n: String = to.strip_edges()
	if doc == null or seq == null or n.is_empty() or n == run:
		return 0
	var cmds: Array[Command] = []
	for m: Marker in members(seq, run):
		cmds.append(MarkerCmds.SetMarker.new(seq.id, "", m.id, {"run": n}))
	if cmds.is_empty() or not Verbs.run(doc, "Rename " + run + " to " + n, cmds):
		return 0
	return cmds.size()


static var _cache_key: String = ""
static var _cache: Dictionary = {}


static func by_lane(seq: Sequence, serial: int) -> Dictionary:
	if seq == null:
		return {}
	var key: String = seq.id + "|" + str(serial) + "|" + str(seq.markers.size())
	if key == _cache_key:
		return _cache
	_cache_key = key
	_cache = {}
	var lanes: PackedStringArray = PackedStringArray()
	var idx: Dictionary = Layers.index(seq)
	for m: Marker in seq.markers:
		if m.run.is_empty():
			continue
		var lane: String = Layers.lane_in(idx, m)
		if not lanes.has(lane):
			lanes.append(lane)
	for lane: String in lanes:
		_cache[lane] = runs_on_lane(seq, lane)
	return _cache
