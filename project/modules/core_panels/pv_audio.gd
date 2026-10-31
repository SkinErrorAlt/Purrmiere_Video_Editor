extends RefCounted

const SELF := preload("res://modules/core_panels/pv_audio.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const MAP_KEY := "view_audio"
const PREF_EVERY := "pairview.always_every"
const PREF_EVERY_LABEL := "Pair View: Always heard applies to every Pair View"
const PREF_EVERY_HINT := "On: marking a track Always heard marks it on every Pair View in the sequence, including ones added later. Off: it marks only the selected clips. This is one setting for every Pair View, like Key on switch."
const ALWAYS_TIP := "Heard whatever view is on screen. Click to turn it on or off for the selected clips, or for every Pair View when Every Pair View is lit"
const EVERY_TIP := "When lit, Always heard turns a track on or off for every Pair View in this sequence, including ones added later. When off, only for the selected clips. One setting for every Pair View"
const SOUND_TIP := "Plays this view's sound from the playhead on, whatever is on screen. With Record on, Key on switch on, or Sound from already keyed, it writes a hold key"
const FOLLOW_TIP := "The sound follows the view on screen again from the playhead on"

static var last_toast: String = ""


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


static func _node(name: String) -> Node:
	var r: Node = _root()
	return r.get_node_or_null(name) if r != null else null


static func _where() -> Dictionary:
	var s: Node = _node("Session")
	if s == null:
		return {}
	var d: Variant = s.get("doc")
	var sq: Variant = s.call("seq")
	if not (d is Project) or not (sq is Sequence):
		return {}
	return {"doc": d, "seq": sq}


static func _toast(text: String) -> void:
	last_toast = text
	var ev: Node = _node("Events")
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)


static func register_prefs() -> Node:
	var prefs: Node = _node("Prefs")
	if prefs == null:
		return null
	if not bool(prefs.call("is_registered", PREF_EVERY)):
		prefs.call("register", PREF_EVERY, false, {"label": PREF_EVERY_LABEL, "type": "bool", "hint": PREF_EVERY_HINT})
	return prefs


static func every_scope() -> bool:
	var prefs: Node = register_prefs()
	if prefs == null:
		return false
	return bool(prefs.call("get_value", PREF_EVERY))


static func set_every_scope(on: bool) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_EVERY, on)


static func pair_views(s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	for tr: Track in s.picture_tracks():
		for v: Clip in tr.clips:
			if v.effects.is_empty() or not tr.is_picture(v):
				continue
			for e: Dictionary in v.effects:
				if String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID or not bool(e.get("enabled", true)):
					continue
				var map: Dictionary = ViewMap.of(e)
				if not map.is_empty():
					out.append({"clip": v, "entry": e, "map": map})
	return out


static func targets_of(s: Sequence, uids: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var e: Dictionary = c.effect_by_uid(String(uids[cid]))
		if e.is_empty():
			continue
		var map: Dictionary = ViewMap.of(e)
		if not map.is_empty():
			out.append({"clip": c, "entry": e, "map": map})
	return out


static func candidates(s: Sequence, uids: Dictionary) -> Array[Track]:
	var out: Array[Track] = []
	if s == null:
		return out
	var want: Dictionary = {}
	for t: Dictionary in targets_of(s, uids):
		for tr: Track in ViewMap.governed_tracks(t["map"], s):
			want[tr.id] = true
	if want.is_empty():
		return out
	for id: String in ViewMap.every_of(pair_views(s)):
		want[id] = true
	for tr2: Track in s.all_tracks():
		if want.has(tr2.id):
			out.append(tr2)
	return out


static func state(s: Sequence, uids: Dictionary, track_id: String) -> Dictionary:
	var every: bool = ViewMap.every_of(pair_views(s)).has(track_id)
	var on: int = 0
	var total: int = 0
	for t: Dictionary in targets_of(s, uids):
		total += 1
		if every or ViewMap.always_heard(t["map"], track_id):
			on += 1
	return {"on": on, "total": total, "every": every}


static func _map_cmd(s: Sequence, c: Clip, e: Dictionary, map: Dictionary) -> Command:
	return EffectCmds.SetEffectParam.new(s.id, c.id, String(e.get("uid", "")), MAP_KEY, JSON.stringify(map), -1.0)


static func _track_name(s: Sequence, track_id: String) -> String:
	var tr: Track = s.track_by_id(track_id) if s != null else null
	return tr.shown_label() if tr != null else track_id


static func toggle_always(uids: Dictionary, track_id: String) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	return set_always(w["doc"], w["seq"], uids, track_id, every_scope())


static func set_always(d: Project, s: Sequence, uids: Dictionary, track_id: String, every: bool) -> bool:
	if d == null or s == null:
		return false
	var st: Dictionary = state(s, uids, track_id)
	if int(st["total"]) == 0:
		return false
	var want: bool = int(st["on"]) < int(st["total"])
	var name: String = _track_name(s, track_id)
	var cmds: Array[Command] = []
	if every:
		for pv: Dictionary in pair_views(s):
			var raw: Dictionary = pv["map"]
			var next: Dictionary = ViewMap.with_always(raw, ViewMap.ALWAYS_EVERY_KEY, track_id, want)
			if not want:
				next = ViewMap.with_always(next, ViewMap.ALWAYS_KEY, track_id, false)
			if next != raw:
				cmds.append(_map_cmd(s, pv["clip"], pv["entry"], next))
	else:
		if not want and bool(st["every"]):
			_toast(name + " is heard on every Pair View in this sequence. Light Every Pair View to turn it off there")
			return false
		for t: Dictionary in targets_of(s, uids):
			var raw2: Dictionary = t["map"]
			var next2: Dictionary = ViewMap.with_always(raw2, ViewMap.ALWAYS_KEY, track_id, want)
			if next2 != raw2:
				cmds.append(_map_cmd(s, t["clip"], t["entry"], next2))
	if cmds.is_empty():
		return false
	var label: String = ("Always hear " if want else "Stop always hearing ") + name + (" on every Pair View" if every else "")
	return Verbs.run(d, label, cmds)


static func pick_at(s: Sequence, c: Clip, e: Dictionary) -> int:
	if s == null or c == null or e.is_empty():
		return -1
	var u: float = ViewSwitch.local_at(s, c, s.playhead) if ViewSwitch.covers(c, s.playhead) else 0.0
	return ViewMap.heard_view_at(ViewMap.sound_picks(e, c), u)


static func set_sound(uids: Dictionary, pick: int) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var ses: Node = _node("Session")
	var rec: bool = bool(ses.get("recording")) if ses != null else false
	return set_sound_in(w["doc"], w["seq"], uids, pick, rec)


static func set_sound_in(d: Project, s: Sequence, uids: Dictionary, pick: int, record: bool) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	var why: String = ""
	var name: String = "the view on screen"
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(uids[cid])
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty() or ViewMap.of(e).is_empty():
			continue
		var n: int = mini(ViewMap.crop_count(e), ViewMap.REGION_MAX)
		if pick < 0 or pick > n:
			continue
		if pick > 0:
			var names: PackedStringArray = ViewMap.region_names(e)
			name = names[pick - 1] if pick - 1 < names.size() else "View " + str(pick)
		var r: Dictionary = ViewSwitch._plan_prop(s, c, e, ViewMap.SOUND_VIEW_KEY, "", n + 1, pick, s.playhead, record)
		if not bool(r["ok"]):
			why = String(r["why"])
			continue
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, "effects." + uid + "." + ViewMap.SOUND_VIEW_KEY, r["anim"]))
	if cmds.is_empty():
		if why == ViewSwitch.WHY_SAME:
			_toast("The sound already comes from " + name)
		elif why == ViewSwitch.WHY_OUTSIDE:
			_toast("Move the playhead onto the clip to key where its sound comes from")
		return false
	return Verbs.run(d, "Sound from " + name, cmds)


static func toggle_scope(b: Button) -> void:
	set_every_scope(not every_scope())
	if b != null and is_instance_valid(b):
		b.set("active", every_scope())
	_toast("Always heard now applies to " + ("every Pair View in the sequence" if every_scope() else "the selected clips only"))


static func _lead(w: float) -> Control:
	var lead: Control = Control.new()
	lead.custom_minimum_size.x = w
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lead


static func _quiet(text: String, tip: String) -> Button:
	var b: Button = PmButton.make(text, "")
	b.set("quiet", true)
	if not tip.is_empty():
		PmUI.tip(b, tip)
	return b


static func always_row(uids: Dictionary, lead_w: float) -> Control:
	var row: HBoxContainer = PmUI.hbox(4)
	row.name = "PairAlwaysHeard"
	var w: Dictionary = _where()
	var s: Sequence = w.get("seq", null)
	var tracks: Array[Track] = candidates(s, uids)
	if tracks.is_empty():
		row.visible = false
		return row
	row.add_child(_lead(lead_w))
	row.add_child(PmLabel.dim("Always heard"))
	for tr: Track in tracks:
		var st: Dictionary = state(s, uids, tr.id)
		var b: Button = _quiet(tr.shown_label(), "")
		b.name = "PairAlways_" + tr.id
		b.set("elide", true)
		b.set("active", int(st["on"]) > 0 and int(st["on"]) == int(st["total"]))
		var where: String = " (on every Pair View)" if bool(st["every"]) else ((" (on " + str(st["on"]) + " of " + str(st["total"]) + " clips)") if int(st["on"]) > 0 and int(st["on"]) < int(st["total"]) else "")
		PmUI.tip(b, ALWAYS_TIP + where)
		b.pressed.connect(Callable(SELF, "toggle_always").bind(uids, tr.id))
		row.add_child(b)
	row.add_child(PmUI.spacer())
	var scope: Button = _quiet("Every Pair View", EVERY_TIP)
	scope.name = "PairAlwaysScope"
	scope.set("active", every_scope())
	scope.pressed.connect(Callable(SELF, "toggle_scope").bind(scope))
	row.add_child(scope)
	return row


static func sound_row(c: Clip, e: Dictionary, lead_w: float) -> Control:
	var row: HBoxContainer = PmUI.hbox(4)
	row.name = "PairSoundFrom"
	var w: Dictionary = _where()
	var s: Sequence = w.get("seq", null)
	if s == null or c == null or e.is_empty() or ViewMap.of(e).is_empty():
		row.visible = false
		return row
	var uids: Dictionary = {c.id: String(e.get("uid", ""))}
	var lit: int = pick_at(s, c, e)
	row.add_child(_lead(lead_w))
	row.add_child(PmLabel.dim("Sound from"))
	var follow: Button = _quiet("On screen", FOLLOW_TIP)
	follow.name = "PairSound0"
	follow.set("active", lit == 0)
	follow.pressed.connect(Callable(SELF, "set_sound").bind(uids, 0))
	row.add_child(follow)
	var names: PackedStringArray = ViewMap.region_names(e)
	var n: int = mini(ViewMap.crop_count(e), ViewMap.REGION_MAX)
	for i: int in n:
		var b: Button = _quiet(names[i] if i < names.size() else "View " + str(i + 1), SOUND_TIP)
		b.name = "PairSound" + str(i + 1)
		b.set("elide", true)
		b.set("active", lit == i + 1)
		b.pressed.connect(Callable(SELF, "set_sound").bind(uids, i + 1))
		row.add_child(b)
	row.add_child(PmUI.spacer())
	return row


static func strip(c: Clip, e: Dictionary, lead_w: float) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "PairAudio"
	var a: Control = sound_row(c, e, lead_w)
	var b: Control = always_row({c.id: String(e.get("uid", ""))} if c != null else {}, lead_w)
	box.add_child(a)
	box.add_child(b)
	box.visible = a.visible or b.visible
	return box


static func strip_sig(s: Sequence, c: Clip, e: Dictionary) -> String:
	if s == null or c == null or e.is_empty():
		return ""
	var params: Dictionary = e.get("params", {})
	var parts: Array = [c.id, String(e.get("uid", "")), params.get(MAP_KEY), params.get(ViewMap.SOUND_VIEW_KEY), params.get("crops"), pick_at(s, c, e), Array(ViewMap.every_of(pair_views(s))), every_scope()]
	return JSON.stringify(parts, "", false, true)
