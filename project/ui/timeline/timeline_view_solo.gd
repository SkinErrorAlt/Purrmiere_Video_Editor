extends RefCounted

const SELF := preload("res://ui/timeline/timeline_view_solo.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const ClipFilter := preload("res://doc/clip_filter.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")

const K_SOLO := "solo"
const K_VIEW := "view"
const K_GAPS := "gaps"
const K_MOVE := "move"
const EPS := 0.00001
const MENU_SOLO := "solo:"
const MENU_OFF := "solo_off"
const MENU_GAPS := "solo_gaps"
const MENU_MOVE := "solo_move"
const MENU_NEXT := "solo_next"
const MENU_FIT := "solo_fit"
const MENU_CUT := "solo_cut"
const LOCK_TEXT := "Soloed clips are locked, turn on Let the clips move to drag them"
const OVERLAP_INK := Color("#d8463c")
const OVERLAP_ALPHA := 0.3
const OVERLAP_HATCH := 6.0
const GAP_HATCH := 7.0
const GAP_MIN_PX := 2.0
const CHOICE_KEEP := "keep"
const CHOICE_CUT := "cut"
const CHOICE_FIT := "fit"
const WARN_META := "view_solo_warned"

static var stats: Dictionary = {"plans": 0, "plan_usec": 0, "reused": 0}
static var _plan: Dictionary = {}
static var _plan_key: String = ""
static var last_note: String = ""


class SetView extends "res://doc/commands/command.gd":
	var view_next: Dictionary = {}
	var view_old: Dictionary = {}

	func _init(p_seq_id: String, p_view: Dictionary, p_label: String = "Timeline view") -> void:
		label = p_label
		seq_id = p_seq_id
		view_next = SELF.cleaned_all(p_view)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null or SELF.cleaned_all(s.track_view) == view_next:
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


static func clean(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var src: Dictionary = v
	var name: String = String(src.get(K_VIEW, "")).strip_edges()
	if name.is_empty():
		return {}
	var out: Dictionary = {K_VIEW: name}
	if bool(src.get(K_GAPS, false)):
		out[K_GAPS] = true
	if bool(src.get(K_MOVE, false)):
		out[K_MOVE] = true
	return out


static func cleaned_all(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var out: Dictionary = ClipFilter.clean(v)
	var solo: Dictionary = clean((v as Dictionary).get(K_SOLO, null))
	if not solo.is_empty():
		out[K_SOLO] = solo
	return out


static func of(s: Sequence) -> Dictionary:
	if s == null:
		return {}
	return clean(s.track_view.get(K_SOLO, null))


static func is_on(s: Sequence) -> bool:
	return not of(s).is_empty()


static func view_name(s: Sequence) -> String:
	return String(of(s).get(K_VIEW, ""))


static func gaps_shown(s: Sequence) -> bool:
	return bool(of(s).get(K_GAPS, false))


static func moves_allowed(s: Sequence) -> bool:
	return bool(of(s).get(K_MOVE, false))


static func with_solo(s: Sequence, solo: Dictionary) -> Dictionary:
	var out: Dictionary = s.track_view.duplicate(true) if s != null else {}
	var next: Dictionary = clean(solo)
	if next.is_empty():
		out.erase(K_SOLO)
	else:
		out[K_SOLO] = next
	return out


static func with_solo_into(s: Sequence, view: Dictionary) -> Dictionary:
	var out: Dictionary = view.duplicate(true)
	var solo: Dictionary = of(s)
	if solo.is_empty():
		out.erase(K_SOLO)
	else:
		out[K_SOLO] = solo
	return out


static func pair_sources(s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			var e: Dictionary = ViewSwitch.pair_entry(c)
			if e.is_empty():
				continue
			out.append({"clip": c, "track": t, "entry": e, "map": ViewMap.of(e), "names": ViewMap.region_names(e)})
	return out


static func names_of(s: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for src: Dictionary in pair_sources(s):
		for n: String in (src["names"] as PackedStringArray):
			if not out.has(n):
				out.append(n)
	return out


static func index_in(src: Dictionary, name: String) -> int:
	var names: PackedStringArray = src["names"]
	for i: int in names.size():
		if names[i] == name:
			return i
	return -1


static func single_view(e: Dictionary, video: Clip) -> int:
	var chs: Array[Dictionary] = ViewMap.changes(e, video)
	if chs.size() != 1:
		return -1
	return int(chs[0]["view"])


static func _own(owned: Dictionary, t: Track, c: Clip) -> void:
	if not owned.has(t.id):
		owned[t.id] = []
	var list: Array = owned[t.id]
	for other: Variant in list:
		if (other as Clip).id == c.id:
			return
	list.append(c)


static func _sort_clips(list: Array) -> void:
	list.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start or (a.start == b.start and a.id < b.id))


static func build(_d: Project, s: Sequence) -> Dictionary:
	var solo: Dictionary = of(s)
	var none: Array[Dictionary] = []
	if s == null or solo.is_empty():
		return {"on": false, "name": "", "hidden": {}, "owned": {}, "gaps": {}, "overlaps": none, "by_track": {}}
	var name: String = String(solo[K_VIEW])
	var hidden: Dictionary = {}
	var shown: Dictionary = {}
	var owned: Dictionary = {}
	var srcs: Array[Dictionary] = pair_sources(s)
	for src: Dictionary in srcs:
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var map: Dictionary = src["map"]
		var at: int = index_in(src, name)
		var only: int = single_view(e, video)
		if only >= 0 and at >= 0 and only != at:
			hidden[video.id] = true
		else:
			shown[video.id] = true
			if at >= 0 and only == at:
				_own(owned, src["track"], video)
		if map.is_empty() or at < 0:
			continue
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if c == video or not ViewSwitch.pair_entry(c).is_empty():
					continue
				if not ViewMap.reaches(map, video, c, t.id):
					continue
				if ViewMap.hears(map, at, t.id, c.id):
					shown[c.id] = true
					_own(owned, t, c)
				else:
					hidden[c.id] = true
	for id: Variant in shown.keys():
		hidden.erase(id)
	var gaps: Dictionary = {}
	var by_track: Dictionary = {}
	var overlaps: Array[Dictionary] = []
	for key: Variant in owned.keys():
		var track_id: String = String(key)
		var kept: Array = []
		for c: Variant in (owned[track_id] as Array):
			if not hidden.has((c as Clip).id):
				kept.append(c)
		_sort_clips(kept)
		owned[track_id] = kept
		var lane_gaps: Array = []
		var lane_overlaps: Array[Dictionary] = []
		for i: int in range(1, kept.size()):
			var a: Clip = kept[i - 1]
			var b: Clip = kept[i]
			if b.start > a.end() + EPS:
				lane_gaps.append(Vector2(a.end(), b.start))
			elif b.start < a.end() - EPS:
				var rec: Dictionary = {"track_id": track_id, "a_id": a.id, "b_id": b.id, "from": b.start, "to": minf(a.end(), b.end())}
				lane_overlaps.append(rec)
				overlaps.append(rec)
		gaps[track_id] = lane_gaps
		by_track[track_id] = lane_overlaps
	overlaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["from"]) < float(b["from"]))
	return {"on": true, "name": name, "hidden": hidden, "owned": owned, "gaps": gaps, "overlaps": overlaps, "by_track": by_track}


static func plan(d: Project, s: Sequence) -> Dictionary:
	if s == null:
		return build(d, s)
	var key: String = str(d.get_instance_id() if d != null else 0) + "|" + str(d.serial if d != null else 0) + "|" + s.id + "|" + JSON.stringify(of(s))
	if key == _plan_key and not _plan.is_empty():
		stats["reused"] = int(stats["reused"]) + 1
		return _plan
	var t0: int = Time.get_ticks_usec()
	_plan = build(d, s)
	_plan_key = key
	stats["plans"] = int(stats["plans"]) + 1
	stats["plan_usec"] = int(stats["plan_usec"]) + Time.get_ticks_usec() - t0
	return _plan


static func forget() -> void:
	_plan = {}
	_plan_key = ""


static func hidden_ids(d: Project, s: Sequence) -> Dictionary:
	return plan(d, s)["hidden"]


static func owned_on(d: Project, s: Sequence, track_id: String) -> Array:
	var p: Dictionary = plan(d, s)
	return (p["owned"] as Dictionary).get(track_id, [])


static func gaps_on(d: Project, s: Sequence, track_id: String) -> Array:
	var p: Dictionary = plan(d, s)
	return (p["gaps"] as Dictionary).get(track_id, [])


static func overlaps_of(d: Project, s: Sequence) -> Array[Dictionary]:
	var p: Dictionary = plan(d, s)
	return p["overlaps"]


static func overlaps_on(d: Project, s: Sequence, track_id: String) -> Array:
	var p: Dictionary = plan(d, s)
	return (p["by_track"] as Dictionary).get(track_id, [])


static func overlap_count(d: Project, s: Sequence) -> int:
	return overlaps_of(d, s).size()


static func signature(d: Project, s: Sequence) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for o: Dictionary in overlaps_of(d, s):
		parts.append(String(o["a_id"]) + ">" + String(o["b_id"]) + "@" + String.num(float(o["from"]), 4))
	return "|".join(parts)


static func folds(s: Sequence) -> bool:
	return is_on(s) and not gaps_shown(s)


static func fold_spans(d: Project, s: Sequence) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if s == null or not folds(s):
		return out
	var p: Dictionary = plan(d, s)
	var pictures: Array[Vector2] = []
	var every: Array[Vector2] = []
	for key: Variant in (p["owned"] as Dictionary).keys():
		var t: Track = s.track_by_id(String(key))
		for c: Variant in ((p["owned"] as Dictionary)[key] as Array):
			var clip: Clip = c
			var span: Vector2 = Vector2(clip.start, clip.end())
			every.append(span)
			if t != null and t.is_picture(clip):
				pictures.append(span)
	var spans: Array[Vector2] = pictures if not pictures.is_empty() else every
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var reach: float = -INF
	for span: Vector2 in spans:
		if reach > -INF and span.x > reach + EPS:
			out.append(Vector2(reach, span.x))
		reach = maxf(reach, span.y)
	return out


static func next_overlap(d: Project, s: Sequence, after: float) -> float:
	var list: Array[Dictionary] = overlaps_of(d, s)
	if list.is_empty():
		return -1.0
	for o: Dictionary in list:
		if float(o["from"]) > after + EPS:
			return float(o["from"])
	return float((list[0] as Dictionary)["from"])


static func fit_moves(d: Project, s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = plan(d, s)
	if not bool(p["on"]):
		return out
	for key: Variant in (p["owned"] as Dictionary).keys():
		var track_id: String = String(key)
		var limit: float = -INF
		for c: Variant in ((p["owned"] as Dictionary)[track_id] as Array):
			var clip: Clip = c
			var start: float = clip.start
			if start < limit - EPS:
				start = limit
				out.append({"id": clip.id, "start": start, "track_id": track_id})
			limit = start + clip.duration
	return out


static func cut_moves(d: Project, s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = plan(d, s)
	if not bool(p["on"]):
		return out
	var seen: Dictionary = {}
	for o: Dictionary in (p["overlaps"] as Array[Dictionary]):
		var a: Clip = s.clip_by_id(String(o["a_id"]))
		var b: Clip = s.clip_by_id(String(o["b_id"]))
		if a == null or b == null or seen.has(a.id):
			continue
		seen[a.id] = true
		if b.start <= a.start + EPS:
			out.append({"id": a.id, "side": "gone", "at": a.start})
		else:
			out.append({"id": a.id, "side": "tail", "at": b.start})
	return out


static func toggle(d: Project, s: Sequence, name: String) -> bool:
	if d == null or s == null:
		return false
	if view_name(s) == name:
		return clear(d, s)
	return Verbs.run(d, "Solo " + name, [SetView.new(s.id, with_solo(s, {K_VIEW: name}), "Solo " + name)])


static func clear(d: Project, s: Sequence) -> bool:
	if d == null or s == null or not is_on(s):
		return false
	return Verbs.run(d, "Stop soloing", [SetView.new(s.id, with_solo(s, {}), "Stop soloing")])


static func set_flag(d: Project, s: Sequence, key: String, on: bool, label: String) -> bool:
	if d == null or s == null or not is_on(s):
		return false
	var solo: Dictionary = of(s)
	if on:
		solo[key] = true
	else:
		solo.erase(key)
	return Verbs.run(d, label, [SetView.new(s.id, with_solo(s, solo), label)])


static func set_gaps(d: Project, s: Sequence, on: bool) -> bool:
	return set_flag(d, s, K_GAPS, on, "Deadspace " + ("shown" if on else "hidden"))


static func set_moves(d: Project, s: Sequence, on: bool) -> bool:
	return set_flag(d, s, K_MOVE, on, "Soloed clips " + ("free to move" if on else "locked"))


static func locks_move(s: Sequence) -> bool:
	return is_on(s) and not moves_allowed(s)


static func owns_clip(d: Project, s: Sequence, c: Clip) -> bool:
	if d == null or s == null or c == null or not is_on(s):
		return false
	var t: Track = s.track_of(c.id)
	if t == null:
		return false
	for other: Variant in owned_on(d, s, t.id):
		if (other as Clip).id == c.id:
			return true
	return false


static func locks_clip(d: Project, s: Sequence, c: Clip) -> bool:
	return locks_move(s) and owns_clip(d, s, c)


static func auto_fix(d: Project, s: Sequence) -> int:
	var moves: Array[Dictionary] = fit_moves(d, s)
	if d == null or s == null or moves.is_empty():
		_say("Nothing overlaps")
		return 0
	if not Verbs.run(d, "Nudge the soloed clips to fit", [ClipCmds.MoveClips.new(s.id, moves)]):
		return 0
	_say("Nudged " + ClipFilter.counted(moves.size(), "clip", "clips") + " to fit")
	return moves.size()


static func cut_covered(d: Project, s: Sequence) -> int:
	var cuts: Array[Dictionary] = cut_moves(d, s)
	if d == null or s == null or cuts.is_empty():
		_say("Nothing overlaps")
		return 0
	var cmds: Array[Command] = []
	var gone: PackedStringArray = PackedStringArray()
	for cut: Dictionary in cuts:
		if String(cut["side"]) == "gone":
			gone.append(String(cut["id"]))
		else:
			cmds.append(EditCmds.TrimClip.new(s.id, PackedStringArray([String(cut["id"])]), "tail", float(cut["at"])))
	if not gone.is_empty():
		cmds.append(ClipCmds.RemoveClips.new(s.id, gone))
	if cmds.is_empty() or not Verbs.run(d, "Cut the covered part", cmds):
		return 0
	_say("Cut " + ClipFilter.counted(cuts.size(), "covered clip", "covered clips"))
	return cuts.size()


static func goto_next_overlap(d: Project, s: Sequence) -> bool:
	if d == null or s == null:
		return false
	var at: float = next_overlap(d, s, s.playhead)
	if at < 0.0:
		_say("No overlaps in the soloed view")
		return false
	var loop: MainLoop = Engine.get_main_loop()
	var session: Node = (loop as SceneTree).root.get_node_or_null("/root/Session") if loop is SceneTree else null
	if session != null and session.get("doc") == d and session.call("seq") == s:
		session.call("set_playhead", at)
		return true
	return Verbs.set_playhead(d, s, at)


static func live() -> Array:
	var loop: MainLoop = Engine.get_main_loop()
	var session: Node = (loop as SceneTree).root.get_node_or_null("/root/Session") if loop is SceneTree else null
	if session == null:
		return []
	var d: Project = session.get("doc")
	var s: Sequence = session.call("seq") if d != null else null
	return [d, s] if s != null else []


static func jump_next_overlap() -> bool:
	var parts: Array = live()
	if parts.is_empty():
		return false
	return goto_next_overlap(parts[0], parts[1])


static func soloing_now() -> bool:
	var parts: Array = live()
	return not parts.is_empty() and is_on(parts[1])


static func menu_items(s: Sequence, over: int) -> Array:
	var items: Array = []
	if s == null:
		return items
	var names: PackedStringArray = names_of(s)
	var picked: String = view_name(s)
	var subs: Array = []
	for n: String in names:
		subs.append(PmMenu.check_item(MENU_SOLO + n, n, picked == n))
	if subs.is_empty():
		var none: Dictionary = PmMenu.item("solo_none", "No Pair View in this sequence")
		none["disabled"] = true
		subs.append(none)
	items.append(PmMenu.sub_item("solo_menu", "Solo a view on the timeline", subs))
	if picked.is_empty():
		return items
	items.append(PmMenu.item(MENU_OFF, "Stop soloing " + picked))
	items.append(PmMenu.check_item(MENU_GAPS, "Show the deadspace between clips", gaps_shown(s)))
	items.append(PmMenu.check_item(MENU_MOVE, "Let the soloed clips move", moves_allowed(s)))
	var nxt: Dictionary = PmMenu.item(MENU_NEXT, "Go to the next overlap" + ("" if over <= 0 else " (" + str(over) + ")"))
	var fit: Dictionary = PmMenu.item(MENU_FIT, "Nudge everything to fit")
	var cut: Dictionary = PmMenu.item(MENU_CUT, "Cut the covered parts")
	if over <= 0:
		nxt["disabled"] = true
		fit["disabled"] = true
		cut["disabled"] = true
	items.append(nxt)
	items.append(fit)
	items.append(cut)
	return items


static func on_menu(d: Project, s: Sequence, id: String) -> bool:
	if s == null:
		return false
	if id.begins_with(MENU_SOLO):
		return toggle(d, s, id.substr(MENU_SOLO.length()))
	if id == MENU_OFF:
		return clear(d, s)
	if id == MENU_GAPS:
		return set_gaps(d, s, not gaps_shown(s))
	if id == MENU_MOVE:
		return set_moves(d, s, not moves_allowed(s))
	if id == MENU_NEXT:
		return goto_next_overlap(d, s)
	if id == MENU_FIT:
		return auto_fix(d, s) > 0
	if id == MENU_CUT:
		return cut_covered(d, s) > 0
	return false


static func warn_text(d: Project, s: Sequence) -> String:
	var n: int = overlap_count(d, s)
	if n <= 0:
		return ""
	return ClipFilter.counted(n, "clip of this view now overlaps another", "clips of this view now overlap others") + ". Keep them as they are, cut the covered parts, or nudge everything to fit."


static func warn_choices() -> Array:
	return [
		{"id": CHOICE_KEEP, "label": "Keep overlapping"},
		{"id": CHOICE_CUT, "label": "Cut the covered"},
		{"id": CHOICE_FIT, "label": "Nudge to fit", "primary": true},
	]


static func answer(d: Project, s: Sequence, choice: String) -> bool:
	if choice == CHOICE_CUT:
		return cut_covered(d, s) > 0
	if choice == CHOICE_FIT:
		return auto_fix(d, s) > 0
	return false


static func after_gesture(canvas: Control, d: Project, s: Sequence) -> bool:
	if canvas == null or s == null or not is_on(s) or not moves_allowed(s):
		if canvas != null and canvas.has_meta(WARN_META):
			canvas.remove_meta(WARN_META)
		return false
	var sig: String = signature(d, s)
	var was: String = String(canvas.get_meta(WARN_META)) if canvas.has_meta(WARN_META) else ""
	if sig.is_empty():
		if canvas.has_meta(WARN_META):
			canvas.remove_meta(WARN_META)
		return false
	canvas.set_meta(WARN_META, sig)
	if sig == was:
		return false
	var answered: Signal = PmUI.choose(canvas, "Overlapping clips", warn_text(d, s), warn_choices())
	answered.connect(_on_answered.bind(d, s))
	return true


static func _on_answered(result: Variant, d: Project, s: Sequence) -> void:
	if not (result is String):
		return
	answer(d, s, String(result))


static func draw_lane(canvas: Control, d: Project, s: Sequence, t: Track, lane_y: float, lane_h: float) -> int:
	if canvas == null or t == null or s == null or not is_on(s):
		return 0
	var drawn: int = 0
	var header_w: float = float(canvas.get("header_w"))
	var width: float = canvas.size.x
	if gaps_shown(s):
		for g: Variant in gaps_on(d, s, t.id):
			var span: Vector2 = g
			var r: Rect2 = _band(canvas, header_w, width, span.x, span.y, lane_y, lane_h)
			if r.size.x < GAP_MIN_PX:
				continue
			Paint.hatch(canvas, r, Tk.c["hatch"], GAP_HATCH)
			canvas.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
			drawn += 1
	for o: Variant in overlaps_on(d, s, t.id):
		var rec: Dictionary = o
		var r2: Rect2 = _band(canvas, header_w, width, float(rec["from"]), float(rec["to"]), lane_y, lane_h)
		if r2.size.x < 1.0:
			continue
		canvas.draw_rect(r2, Color(OVERLAP_INK, OVERLAP_ALPHA), true)
		Paint.hatch(canvas, r2, Color(OVERLAP_INK, 0.55), OVERLAP_HATCH)
		canvas.draw_rect(Rect2(r2.position + Vector2(0.5, 0.5), r2.size - Vector2(1.0, 1.0)), OVERLAP_INK, false, 1.5)
		drawn += 1
	return drawn


static func _band(canvas: Control, header_w: float, width: float, a: float, b: float, lane_y: float, lane_h: float) -> Rect2:
	var x0: float = maxf(float(canvas.call("x_of", a)), header_w)
	var x1: float = minf(float(canvas.call("x_of", b)), width)
	return Rect2(x0, lane_y + 1.0, maxf(x1 - x0, 0.0), maxf(lane_h - 2.0, 1.0))


static func _say(text: String) -> void:
	last_note = text
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var ev: Node = tree.root.get_node_or_null("/root/Events") if tree != null else null
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)
