extends RefCounted
## Locked regions (C-033): fences on a sequence that nothing ripples through. A fence is a stretch of time
## {"id", "start", "end", "label"} in `Sequence.fences`. A ripple edit before a fence moves only the clips between
## the edit and the fence; clips inside the fence and after it stay where they are, and the clips that move may not
## be pushed into it. An edit inside a fence still happens but ripples nothing.

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Command := preload("res://doc/commands/command.gd")
const SeqCmds := preload("res://doc/commands/sequence_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const EPS := 0.0005
const MIN_LEN := 0.04


static func list(s: Sequence) -> Array:
	if s == null:
		return []
	return s.fences


## Where ripples starting at `from_t` must stop: the start of the first fence that ends after it. When `from_t`
## is inside a fence this is `from_t` itself, so nothing moves. INF when no fence is in the way.
static func stop_for(s: Sequence, from_t: float) -> float:
	return EditMath.fence_stop(s, from_t)


static func at(s: Sequence, t: float) -> Dictionary:
	for f: Variant in list(s):
		if f is Dictionary and t >= float((f as Dictionary).get("start", 0.0)) - EPS and t <= float((f as Dictionary).get("end", 0.0)) + EPS:
			return f
	return {}


## The fences with a new one added, overlapping or touching ones merged, sorted by time.
static func with_added(s: Sequence, a: float, b: float, id: String) -> Array:
	var lo: float = minf(a, b)
	var hi: float = maxf(a, b)
	var out: Array = []
	var label: String = ""
	for f: Variant in list(s):
		if not (f is Dictionary):
			continue
		var fa: float = float((f as Dictionary).get("start", 0.0))
		var fb: float = float((f as Dictionary).get("end", 0.0))
		if fb >= lo - EPS and fa <= hi + EPS:
			lo = minf(lo, fa)
			hi = maxf(hi, fb)
			if label.is_empty():
				label = String((f as Dictionary).get("label", ""))
			if id.is_empty():
				id = String((f as Dictionary).get("id", ""))
			continue
		out.append((f as Dictionary).duplicate())
	out.append({"id": id, "start": maxf(lo, 0.0), "end": hi, "label": label})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["start"]) < float(y["start"]))
	return out


## Locks `a` to `b` on the sequence as one undo step.
static func add(doc: Project, s: Sequence, a: float, b: float) -> bool:
	if doc == null or s == null or absf(b - a) < MIN_LEN:
		return false
	var next: Array = with_added(s, a, b, doc.mint_id("fence"))
	var cmds: Array[Command] = [SeqCmds.SetSequenceField.new(s.id, "fences", next)]
	return Verbs.run(doc, "Lock a region", cmds)


## Locks the sequence's in to out.
static func add_in_out(doc: Project, s: Sequence) -> bool:
	if s == null or s.in_point < 0.0 or s.out_point < 0.0:
		return false
	return add(doc, s, s.in_point, s.out_point)


## Takes away the fence at `t`.
static func remove_at(doc: Project, s: Sequence, t: float) -> bool:
	var hit: Dictionary = at(s, t)
	if doc == null or hit.is_empty():
		return false
	var next: Array = []
	for f: Variant in list(s):
		if f is Dictionary and String((f as Dictionary).get("id", "")) != String(hit.get("id", "")):
			next.append((f as Dictionary).duplicate())
	var cmds: Array[Command] = [SeqCmds.SetSequenceField.new(s.id, "fences", next)]
	return Verbs.run(doc, "Unlock a region", cmds)


static func clear(doc: Project, s: Sequence) -> bool:
	if doc == null or s == null or list(s).is_empty():
		return false
	var cmds: Array[Command] = [SeqCmds.SetSequenceField.new(s.id, "fences", [])]
	return Verbs.run(doc, "Unlock every region", cmds)
