extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const MoveRule := preload("res://doc/move_rule.gd")
const ViewTrims := preload("res://doc/view_trims.gd")
const RealignCmds := preload("res://doc/commands/realign_cmds.gd")
const Timecode := preload("res://doc/timecode.gd")
const VERBS_PATH := "res://doc/verbs.gd"
const TOOL_ID := "realign"
const DRAG_MODE := "realign"
const PREF_LOOP := "realign.loop"
const PREF_SCOPE := "realign.scope"
const SCOPE_CUTS := "cuts"
const SCOPE_VIEWS := "views"
const SCOPES: PackedStringArray = ["cuts", "views"]
const SCOPE_LABELS: Dictionary = {"cuts": "Real cuts only", "views": "Pair View slices"}
const LOOP_LABEL := "Loop round the ends of the source"
const HINT := "Drag a clip or a view span to move its source under it. Alt: this lane alone. Ctrl: off the frame grid."
const RULE := "Realign moves the source under a section and leaves the clip where it is on the timeline (a slip). The section is the clip, or with Pair View slices and Cut on view changes on, the view span under the pointer: it is cut there for real (at its two view change lines, picture and its own sound together) in the same undo step, then its source moves. What moves follows the move rule: the clip you grab and its own linked clips (the ones under it piece for piece); if the grabbed clip is selected, what a move of the selection would take, so a whole group only when all of it is picked; Alt takes the grabbed lane alone, to fix sync. Steps are whole frames unless Ctrl is held. With Loop on, sliding past the start of the source carries on from its end (and past the end from its start); where that falls inside the section it becomes two pieces."
const EPS := 0.00001

static var monitor_time: float = -1.0


static func pref_specs() -> Array:
	return [
		[PREF_LOOP, false, {"label": "Realign: loop round the ends of the source (for loops and music beds)", "type": "bool"}],
		[PREF_SCOPE, SCOPE_CUTS, {"label": "Realign sections (Cuts: whole clips, Views: Pair View slices when Cut on view changes is on)", "type": "enum", "choices": Array(SCOPES)}],
	]


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var n: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if n != null and n.has_method("register"):
			return n
	return null


static func register_prefs() -> void:
	var p: Node = _prefs()
	if p == null:
		return
	for spec: Array in pref_specs():
		if not bool(p.call("is_registered", String(spec[0]))):
			p.call("register", String(spec[0]), spec[1], spec[2])


static func pref(key: String) -> Variant:
	register_prefs()
	var p: Node = _prefs()
	for spec: Array in pref_specs():
		if String(spec[0]) == key:
			return p.call("get_value", key) if p != null else spec[1]
	return null


static func set_pref(key: String, v: Variant) -> void:
	register_prefs()
	var p: Node = _prefs()
	if p != null:
		p.call("set_value", key, v)


static func loop_on() -> bool:
	return bool(pref(PREF_LOOP))


static func scope() -> String:
	var v: String = String(pref(PREF_SCOPE))
	return v if SCOPES.has(v) else SCOPE_CUTS


static func section(s: Sequence, c: Clip, t: float, scope_: String) -> Dictionary:
	var out: Dictionary = {"a": c.start, "b": c.end(), "span": false}
	if s == null or c == null or scope_ != SCOPE_VIEWS:
		return out
	var lines: PackedFloat64Array = ViewTrims.lines_of(s, c)
	if lines.is_empty():
		return out
	var a: float = c.start
	var b: float = c.end()
	for l: float in lines:
		if l <= t + EPS:
			a = l
		else:
			b = l
			break
	return {"a": a, "b": b, "span": true}


static func targets(s: Sequence, clip_id: String, alone: bool) -> PackedStringArray:
	if s == null or s.clip_by_id(clip_id) == null:
		return PackedStringArray()
	if alone:
		return PackedStringArray([clip_id])
	if s.selected_clip_ids.has(clip_id):
		var now: PackedStringArray = MoveRule.moving(s)
		if now.has(clip_id):
			return now
	return MoveRule.slide_ids(s, clip_id)


static func plan(s: Sequence, clip_id: String, t: float, alone: bool, scope_: String) -> Dictionary:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return {}
	var sec: Dictionary = section(s, c, t, scope_)
	var ids: PackedStringArray = load(VERBS_PATH).call("unlocked", s, targets(s, clip_id, alone))
	if not ids.has(clip_id):
		return {}
	if bool(sec["span"]):
		var keep: PackedStringArray = PackedStringArray()
		for id: String in ids:
			var f: Clip = s.clip_by_id(id)
			if f != null and f.end() > float(sec["a"]) + EPS and f.start < float(sec["b"]) - EPS:
				keep.append(id)
		ids = keep
	return {"clip": clip_id, "t": t, "ids": ids, "a": float(sec["a"]), "b": float(sec["b"]), "span": bool(sec["span"])}


static func command(s: Sequence, p: Dictionary, delta: float, loop: bool) -> Command:
	if s == null or p.is_empty():
		return null
	return RealignCmds.Realign.new(s.id, p["ids"], delta, loop, bool(p["span"]), float(p["a"]), float(p["b"]))


static func run(doc: Project, s: Sequence, p: Dictionary, delta: float, loop: bool) -> Command:
	var cmd: Command = command(s, p, delta, loop)
	if cmd == null or absf(delta) < EPS:
		return null
	var list: Array[Command] = [cmd]
	if not bool(load(VERBS_PATH).call("run", doc, "Realign", list)):
		return null
	return cmd


static func realign(doc: Project, s: Sequence, clip_id: String, t: float, delta: float, alone: bool = false, scope_: String = "", loop: int = -1) -> Command:
	var sc: String = scope_ if SCOPES.has(scope_) else scope()
	var lp: bool = loop_on() if loop < 0 else loop == 1
	return run(doc, s, plan(s, clip_id, t, alone, sc), delta, lp)


static func frames(delta: float, fps: float) -> float:
	var f: float = fps if fps > 0.0 else 30.0
	return round(delta * f) / f


static func chip_text(cmd: Command, asked: float, fps: float) -> String:
	var applied: float = float(cmd.get("applied")) if cmd != null else 0.0
	var f: float = fps if fps > 0.0 else 30.0
	var n: int = int(round(absf(applied) * f))
	var main: String = ("+" if applied >= 0.0 else "-") + ("%.3f s" % absf(applied))
	var rest: String = "no change"
	if absf(applied) > EPS:
		rest = str(n) + (" frame " if n == 1 else " frames ") + ("later" if applied > 0.0 else "earlier")
		if absf(applied * f - round(applied * f)) > 0.01:
			rest = ("later" if applied > 0.0 else "earlier") + ", off the frame grid"
	if cmd != null and bool(cmd.get("looped")):
		rest += ", looped round"
	elif cmd != null and bool(cmd.get("clamped")):
		rest += ", held at the " + ("start" if asked > 0.0 else "end") + " of the source"
	elif cmd == null and absf(asked) > EPS:
		rest = "held at the end of the source"
	return main + "  " + rest


static func notice(cmd: Command, fps: float) -> String:
	if cmd == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var cuts: PackedFloat64Array = cmd.get("cuts")
	var wraps: PackedFloat64Array = cmd.get("wraps")
	if not cuts.is_empty():
		parts.append("Cut at the view " + ("change " if cuts.size() == 1 else "changes ") + _times(cuts, fps) + " and moved that span's source")
	if not wraps.is_empty():
		var start: bool = float(cmd.get("applied")) > 0.0
		parts.append("Looped round the " + ("start" if start else "end") + " of the source: the section is now two pieces, cut at " + _times(wraps, fps))
	var refused: String = String(cmd.get("loop_refused"))
	if not refused.is_empty():
		parts.append(refused)
	return ". ".join(parts)


static func _times(list: PackedFloat64Array, fps: float) -> String:
	var out: PackedStringArray = PackedStringArray()
	for t: float in list:
		out.append(Timecode.format(t, fps))
	return " and ".join(out)


static func shown_time(playhead: float) -> float:
	return monitor_time if monitor_time >= 0.0 else playhead
