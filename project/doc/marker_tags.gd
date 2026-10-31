extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Marker := preload("res://doc/marker.gd")
const Follow := preload("res://doc/marker_follow.gd")
const Layers := preload("res://doc/marker_layers.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const KIND := "tag"
const DEFAULT_NAME := "Tag"
const MIN_LENGTH := 0.001
const PREF_REUSE := "markers.tag_reuse_name"

static var enabled: bool = true
static var last_name: String = DEFAULT_NAME


static func is_tag(m: Marker) -> bool:
	return m != null and m.kind == KIND and m.duration > MIN_LENGTH


static func name_of(m: Marker) -> String:
	var n: String = m.label.strip_edges()
	return n if not n.is_empty() else DEFAULT_NAME


static func names(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for m: Marker in Layers.usable(seq):
		if is_tag(m) and not out.has(name_of(m)):
			out.append(name_of(m))
	return out


static func colour_for(seq: Sequence, name: String) -> Dictionary:
	if seq != null:
		for m: Marker in seq.markers:
			if is_tag(m) and name_of(m) == name:
				return {"colour": m.colour, "rgb": m.rgb}
	return {"colour": -1, "rgb": ""}


static func ranges(seq: Sequence, wanted: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null or not enabled:
		return out
	for m: Marker in Layers.usable(seq):
		if not is_tag(m):
			continue
		var n: String = name_of(m)
		if not wanted.is_empty() and not wanted.has(n):
			continue
		var a: float = maxf(Follow.resolved_time(seq, m) if m.follows() else m.time, 0.0)
		out.append({"name": n, "from": a, "to": a + m.duration, "id": m.id})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["from"]) < float(y["from"]) or (float(x["from"]) == float(y["from"]) and String(x["id"]) < String(y["id"])))
	var counts: Dictionary = {}
	for r: Dictionary in out:
		var k: int = int(counts.get(r["name"], 0)) + 1
		counts[r["name"]] = k
		r["index"] = k
	return out


static func spans(seq: Sequence, wanted: PackedStringArray = PackedStringArray()) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for r: Dictionary in ranges(seq, wanted):
		var v: Vector2 = Vector2(float(r["from"]), float(r["to"]))
		var n: int = out.size()
		if n > 0 and v.x <= out[n - 1].y + 0.000001:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, v.y))
		else:
			out.append(v)
	return out


static func fields(seq: Sequence, name: String, from: float, to: float, layer: String = "") -> Dictionary:
	var n: String = name.strip_edges()
	if n.is_empty():
		n = DEFAULT_NAME
	var a: float = maxf(minf(from, to), 0.0)
	var b: float = maxf(from, to)
	var d: Dictionary = {"time": a, "duration": b - a, "kind": KIND, "label": n, "layer": layer}
	var look: Dictionary = colour_for(seq, n)
	if int(look["colour"]) >= 0:
		d["colour"] = int(look["colour"])
	if not String(look["rgb"]).is_empty():
		d["rgb"] = String(look["rgb"])
	return d


static func add(doc: Project, seq: Sequence, name: String, from: float, to: float, layer: String = "", colour: int = -2) -> String:
	if doc == null or seq == null or absf(to - from) <= MIN_LENGTH:
		return ""
	if not layer.is_empty() and (not Layers.has_layer(seq, layer) or Layers.locked(seq, layer)):
		return ""
	var d: Dictionary = fields(seq, name, from, to, layer)
	if colour >= -1:
		d["colour"] = colour
		d.erase("rgb")
	d["id"] = doc.mint_id("k")
	var cmd: Command = MarkerCmds.AddMarker.new(seq.id, "", d)
	if not Verbs.run(doc, "Tag " + String(d["label"]), [cmd]):
		return ""
	last_name = String(d["label"])
	return String(d["id"])


static func register_prefs() -> Node:
	var prefs: Node = Layers.prefs_node()
	if prefs != null and not bool(prefs.call("is_registered", PREF_REUSE)):
		prefs.call("register", PREF_REUSE, false, {"label": "Ctrl drag tags with the last tag name without asking", "type": "bool", "hint": "Off asks for the name each time, with the last name filled in."})
	return prefs


static func reuse_silently() -> bool:
	var prefs: Node = register_prefs()
	return prefs != null and bool(prefs.call("get_value", PREF_REUSE))


static func of_name(seq: Sequence, name: String) -> Array[Marker]:
	var out: Array[Marker] = []
	if seq == null:
		return out
	for m: Marker in seq.markers:
		if is_tag(m) and name_of(m) == name:
			out.append(m)
	return out


static func _run_all(doc: Project, seq: Sequence, name: String, fields: Dictionary, label: String) -> int:
	if doc == null or seq == null:
		return 0
	var cmds: Array[Command] = []
	for m: Marker in of_name(seq, name):
		cmds.append(MarkerCmds.SetMarker.new(seq.id, "", m.id, fields))
	if cmds.is_empty() or not Verbs.run(doc, label, cmds):
		return 0
	return cmds.size()


static func rename_all(doc: Project, seq: Sequence, name: String, to: String) -> int:
	var n: String = to.strip_edges()
	if n.is_empty() or n == name:
		return 0
	var done: int = _run_all(doc, seq, name, {"label": n}, "Rename tag " + name + " to " + n)
	if done > 0 and last_name == name:
		last_name = n
	return done


static func recolour_all(doc: Project, seq: Sequence, name: String, colour: int, rgb: String = "") -> int:
	return _run_all(doc, seq, name, {"colour": colour, "rgb": rgb}, "Colour tag " + name)


static func remove_all(doc: Project, seq: Sequence, name: String) -> int:
	if doc == null or seq == null:
		return 0
	var cmds: Array[Command] = []
	for m: Marker in of_name(seq, name):
		cmds.append(MarkerCmds.RemoveMarker.new(seq.id, "", m.id))
	if cmds.is_empty() or not Verbs.run(doc, "Remove every " + name + " tag", cmds):
		return 0
	return cmds.size()


static func next_time(seq: Sequence, name: String, t: float, dir: int) -> float:
	var best: float = -1.0
	for r: Dictionary in ranges(seq, PackedStringArray([name])):
		var a: float = float(r["from"])
		if dir > 0 and a > t + 0.0005:
			return a
		if dir < 0 and a < t - 0.0005:
			best = a
	return best
