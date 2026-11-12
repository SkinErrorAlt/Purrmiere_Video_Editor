extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const SyncAlign := preload("res://doc/sync_align.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Timecode := preload("res://doc/timecode.gd")
const Tools := preload("res://doc/commands/edit_tools.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const SELF_PATH := "res://modules/core_panels/edit_commands.gd"
const OWNER := "core_panels"
const GAIN_LABELS: PackedStringArray = ["Set gain to", "Adjust gain by", "Normalise the peak to"]

static var _gain_mode: int = 0
static var _gain_value: Dictionary = {"set": 0.0, "adjust": 0.0, "normalise": -1.0}
static var _norm: Dictionary = {}
static var last_form: String = ""


static func _script() -> GDScript:
	return load(SELF_PATH)


static func _cmd(id: String, handler: Callable) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Edit"
	var scope: String = "global"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	Cmd.register(id, {"label": label, "category": category, "scope": scope, "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")})


static func register_all() -> void:
	Tools.register_prefs()
	var script: GDScript = _script()
	_cmd("clip.freeze_frame", Callable(script, "freeze_frame_dialog"))
	_cmd("clip.rewind_buildup", Callable(script, "rewind_buildup_dialog"))
	_cmd("clip.hold_to_end", Callable(script, "hold_to_end"))
	_cmd("clip.match_frame", Callable(script, "match_frame"))
	_cmd("clip.reverse_match_frame", Callable(script, "reverse_match_frame"))
	_cmd("clip.subclip", Callable(script, "make_subclip"))
	_cmd("clip.replace_footage", Callable(script, "replace_footage"))
	_cmd("clip.audio_gain", Callable(script, "audio_gain_dialog"))
	_cmd("nav.next_key", Callable(script, "go_key").bind(1))
	_cmd("nav.prev_key", Callable(script, "go_key").bind(-1))
	_cmd("edit.close_all_gaps", Callable(script, "close_all_gaps_dialog"))
	_cmd("edit.cut_at_markers", Callable(script, "cut_at_markers"))


static func _doc() -> Project:
	return Session.doc


static func _seq() -> Sequence:
	return Session.seq()


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func canvas() -> Control:
	var tl: Object = Bus.instance().panel("timeline")
	if tl == null:
		return null
	var c: Variant = tl.get("canvas")
	return c if c is Control else null


static func show_panel(id: String) -> void:
	var root: Node = _root()
	if root == null:
		return
	var editor: Node = root.find_child("EditorScreen", true, false)
	if editor != null and editor.get("dock") != null:
		var dock: Node = editor.get("dock")
		if dock.has_method("show_panel"):
			dock.call("show_panel", id)


static func _tc(s: Sequence, t: float) -> String:
	return Timecode.format(t, s.fps if s.fps > 0.0 else 30.0, s.drop_frame)


static func _form(title: String, fields: Array[Dictionary], ok: String) -> Signal:
	last_form = title
	return PmUI.form(_root(), title, fields, ok, "Cancel")


static func freeze_frame_dialog() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var c: Clip = Tools.clip_under(s, s.playhead, "video")
	if c == null:
		Events.toast("Put the playhead over a video clip first")
		return
	open_freeze_form(c.id, s.playhead)


static func open_freeze_form(clip_id: String, t: float) -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return
	var at: float = clampf(t, c.start, c.end() - Tools.frame_of(s))
	var item: MediaItem = d.media_by_id(c.media_id)
	var name_: String = c.label if not c.label.is_empty() else (item.label if item != null else "the clip")
	var fields: Array[Dictionary] = []
	fields.append({"key": "seconds", "label": "Hold for (seconds)", "type": "float", "default": float(Tools.pref(Tools.PREF_FREEZE_SECONDS, 2.0))})
	fields.append({"key": "ripple", "label": "Push later clips along", "type": "bool", "default": bool(Tools.pref(Tools.PREF_FREEZE_RIPPLE, true))})
	fields.append({"key": "note", "type": "note", "default": "Holds the frame of " + name_ + " under the playhead. Pushing later clips along leaves the sound after it in step; off, the hold covers what follows."})
	var answered: Signal = _form("Freeze frame at " + _tc(s, at), fields, "Freeze")
	answered.connect(Callable(_script(), "_on_freeze_answer").bind(clip_id, at))


static func _on_freeze_answer(result: Variant, clip_id: String, t: float) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	var secs: float = clampf(float(r.get("seconds", 2.0)), 0.04, 600.0)
	var ripple: bool = bool(r.get("ripple", true))
	Prefs.set_value(Tools.PREF_FREEZE_SECONDS, secs)
	Prefs.set_value(Tools.PREF_FREEZE_RIPPLE, ripple)
	freeze_now(clip_id, t, secs, ripple)


static func freeze_now(clip_id: String, t: float, secs: float, ripple: bool) -> String:
	var hold: String = Tools.freeze_frame(_doc(), _seq(), clip_id, t, secs, ripple)
	if hold.is_empty():
		Events.toast("That frame could not be frozen, check the track is not locked")
	return hold


static func rewind_buildup_dialog() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var c: Clip = Tools.clip_under(s, s.playhead, "video")
	if c == null:
		Events.toast("Put the playhead over a video clip first")
		return
	open_rewind_form(c.id)


static func open_rewind_form(clip_id: String) -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return
	var item: MediaItem = d.media_by_id(c.media_id)
	var name_: String = c.label if not c.label.is_empty() else (item.label if item != null else "the clip")
	var fields: Array[Dictionary] = []
	fields.append({"key": "window", "label": "Rewind back (seconds)", "type": "float", "default": float(Tools.pref(Tools.PREF_REWIND_WINDOW, 6.0))})
	fields.append({"key": "length", "label": "Over how long (seconds)", "type": "float", "default": float(Tools.pref(Tools.PREF_REWIND_LEN, 2.0))})
	fields.append({"key": "slow", "label": "Start speed (0.1 slow, 1 even)", "type": "float", "default": float(Tools.pref(Tools.PREF_REWIND_SLOW, 0.7))})
	fields.append({"key": "note", "type": "note", "default": "Duplicates " + name_ + ", pushes the clips after it along, and plays the copy in reverse from the cut back through the look-back, starting slow and speeding up, before cutting on. For a plain rewind without the copy, use the Rewind transition instead."})
	var answered: Signal = _form("Rewind build-up", fields, "Add rewind")
	answered.connect(Callable(_script(), "_on_rewind_answer").bind(clip_id))


static func _on_rewind_answer(result: Variant, clip_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	var window: float = clampf(float(r.get("window", 6.0)), 0.2, 120.0)
	var length: float = clampf(float(r.get("length", 2.0)), 0.1, 60.0)
	var slow: float = clampf(float(r.get("slow", 0.5)), 0.05, 1.0)
	Prefs.set_value(Tools.PREF_REWIND_WINDOW, window)
	Prefs.set_value(Tools.PREF_REWIND_LEN, length)
	Prefs.set_value(Tools.PREF_REWIND_SLOW, slow)
	rewind_now(clip_id, window, length, slow)


static func rewind_now(clip_id: String, window: float, length: float, slow: float) -> String:
	var copy: String = Tools.rewind_buildup(_doc(), _seq(), clip_id, window, length, slow)
	if copy.is_empty():
		Events.toast("That clip could not get a rewind build-up, check the track is not locked")
	return copy


static func hold_to_end() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var c: Clip = Tools.clip_under(s, s.playhead, "video")
	if c == null:
		Events.toast("Put the playhead over a video clip first")
		return
	hold_to_end_at(c.id, s.playhead)


static func hold_to_end_at(clip_id: String, t: float) -> String:
	var hold: String = Tools.hold_to_end(_doc(), _seq(), clip_id, t)
	if hold.is_empty():
		Events.toast("Nothing to hold there")
	return hold


static func match_frame() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	match_at(s.playhead)


static func match_at(t: float) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var r: Dictionary = Tools.match_frame(d, s, t)
	if r.is_empty():
		Events.toast("No clip under the playhead to match")
		return false
	var nest_id: String = String(r.get("sequence_id", ""))
	if not nest_id.is_empty():
		var cv: Control = canvas()
		if cv != null:
			cv.emit_signal("nest_open_requested", nest_id, String(r.get("clip_id", "")))
		else:
			Session.set_sequence(nest_id)
		Session.set_playhead(float(r.get("time", 0.0)))
		return true
	var src: Object = Bus.instance().panel("source")
	if src != null and src.has_method("show_frame"):
		src.call("show_frame", String(r["media_id"]), float(r["time"]), float(r["in"]), float(r["out"]))
	else:
		Bus.instance().request_source(String(r["media_id"]), float(r["in"]), float(r["out"]))
	show_panel("source")
	return true


static func reverse_match_frame() -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var src: Object = Bus.instance().panel("source")
	if d == null or s == null:
		return
	var media_id: String = String(src.get("media_id")) if src != null else ""
	if media_id.is_empty():
		Events.toast("Open a clip in the Source monitor first")
		return
	reverse_match_to(media_id, float(src.get("time")))


static func reverse_match_to(media_id: String, src_t: float) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var r: Dictionary = Tools.reverse_match(d, s, media_id, src_t, s.playhead if s != null else 0.0)
	if r.is_empty():
		Events.toast("That frame is not used in this sequence")
		return false
	Verbs.select(d, s, Verbs.MoveRule.pick(s, PackedStringArray([String(r["clip_id"])]), Verbs.MoveRule.linked_on()), "replace", PackedStringArray([String(r["clip_id"])]))
	Session.set_playhead(float(r["t"]))
	var cv: Control = canvas()
	if cv != null and cv.has_method("reveal_time"):
		cv.call("reveal_time", float(r["t"]), true)
	show_panel("timeline")
	return true


static func make_subclip() -> void:
	var d: Project = _doc()
	var src: Object = Bus.instance().panel("source")
	if d == null or src == null or String(src.get("media_id")).is_empty():
		Events.toast("Open a clip in the Source monitor and mark an in and out first")
		return
	if float(src.get("in_t")) < 0.0 and float(src.get("out_t")) < 0.0:
		Events.toast("Mark an in or an out in the Source monitor first")
		return
	var id: String = Tools.make_subclip(d, String(src.get("media_id")), float(src.call("range_in")), float(src.call("range_out")))
	if id.is_empty():
		Events.toast("That range is too short for a subclip")
		return
	var loader: RefCounted = load("res://modules/core_panels/media_loader.gd").call("instance")
	loader.call("open_item", d, d.media_by_id(id))
	var bin: Object = Bus.instance().panel("bin")
	if bin != null and bin.has_method("reveal"):
		bin.call("reveal", id)
	Events.toast("Made " + d.media_by_id(id).label)


static func bin_choice() -> String:
	var d: Project = _doc()
	var bin: Object = Bus.instance().panel("bin")
	if d == null or bin == null:
		return ""
	var ids: Variant = bin.get("selected_ids")
	if typeof(ids) != TYPE_PACKED_STRING_ARRAY:
		return ""
	for id: String in (ids as PackedStringArray):
		var m: MediaItem = d.media_by_id(id)
		if m != null and m.kind != "sequence":
			return id
	return ""


static func replace_footage() -> void:
	var s: Sequence = _seq()
	var c: Clip = Bus.selected_clip(s)
	if c == null:
		Events.toast("Select the clip to replace first")
		return
	replace_clip_with_bin(c.id)


static func replace_clip_with_bin(clip_id: String, align: bool = false) -> bool:
	var media_id: String = bin_choice()
	if media_id.is_empty():
		Events.toast("Select the new footage in the bin first")
		return false
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if align and d != null and c != null:
		var why: String = SyncAlign.reason(d.media_by_id(c.media_id), d.media_by_id(media_id))
		if not why.is_empty():
			Events.toast(why)
			return false
	if not Tools.replace_with(d, s, clip_id, media_id, align):
		Events.toast("That bin item cannot replace this clip")
		return false
	if align and d != null and c != null:
		var speed: float = c.static_speed()
		if speed == 0.0:
			speed = 1.0
		var off: float = SyncAlign.drift_of(d.media_by_id(c.media_id), d.media_by_id(media_id), c.in_offset, c.duration * absf(speed))
		if off > 0.0:
			Events.toast("Lined up as far as the new footage reaches, %.2f s short of the mark" % off)
	return true


static func audio_gain_dialog() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var ids: PackedStringArray = Tools.audio_clip_ids(s, Verbs.selection(s))
	if ids.is_empty():
		Events.toast("Select audio clips first")
		return
	var first: Clip = s.clip_by_id(ids[0])
	var mode: String = Tools.GAIN_MODES[_gain_mode]
	var value: float = Tools.gain_of(first) if mode == "set" else float(_gain_value.get(mode, 0.0))
	var fields: Array[Dictionary] = []
	fields.append({"key": "mode", "label": "Do this", "type": "enum", "choices": Array(GAIN_LABELS), "default": _gain_mode})
	fields.append({"key": "db", "label": "Decibels", "type": "float", "default": snappedf(value, 0.1)})
	fields.append({"key": "note", "type": "note", "default": "Gain sits before the volume keys as the first Gain effect on each clip. Now " + String.num(Tools.gain_of(first), 1) + " dB."})
	var title: String = "Audio gain for " + (str(ids.size()) + " clips" if ids.size() > 1 else "1 clip")
	var answered: Signal = _form(title, fields, "Apply")
	answered.connect(Callable(_script(), "_on_gain_answer").bind(ids))


static func _on_gain_answer(result: Variant, ids: PackedStringArray) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	_gain_mode = clampi(int(r.get("mode", 0)), 0, Tools.GAIN_MODES.size() - 1)
	var mode: String = Tools.GAIN_MODES[_gain_mode]
	var value: float = float(r.get("db", 0.0))
	_gain_value[mode] = value
	apply_gain(ids, mode, value)


static func apply_gain(ids: PackedStringArray, mode: String, value: float) -> bool:
	if mode == "normalise":
		return start_normalise(ids, value)
	if not Tools.apply_gain(_doc(), _seq(), ids, mode, value):
		Events.toast("Nothing to change, the gain is already there")
		return false
	return true


static func start_normalise(ids: PackedStringArray, target_db: float) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	if d == null or s == null:
		return false
	if not PurrBridge.available:
		Events.warn("Normalise needs the engine", "Set gain and adjust gain work now. Normalise measures the sound with purrcore, which did not load.")
		return false
	var cb: Callable = Callable(_script(), "_on_stats")
	if not PurrBridge.audio_stats_ready.is_connected(cb):
		PurrBridge.audio_stats_ready.connect(cb)
	_norm = {"seq_id": s.id, "target": target_db, "waiting": {}, "peaks": {}}
	var waiting: Dictionary = _norm["waiting"]
	var stamp: String = str(Time.get_ticks_msec())
	for id: String in ids:
		var job: Dictionary = Tools.measure_job(d, s, id)
		if job.is_empty():
			continue
		var tag: String = "gain:" + id + ":" + stamp
		job["tag"] = tag
		if PurrBridge.audio_stats(job) >= 0:
			waiting[tag] = id
	if waiting.is_empty():
		_norm = {}
		Events.warn("Nothing could be measured", "Normalise measures each clip's file. A nest or a missing file cannot be measured, and an engine without audio_stats needs a rebuild.")
		return false
	Events.toast("Measuring " + str(waiting.size()) + (" clip" if waiting.size() == 1 else " clips"))
	return true


static func _on_stats(result: Dictionary) -> void:
	if _norm.is_empty():
		return
	var waiting: Dictionary = _norm["waiting"]
	var tag: String = String(result.get("tag", ""))
	if not waiting.has(tag):
		return
	var id: String = String(waiting[tag])
	waiting.erase(tag)
	if bool(result.get("ok", false)) and float(result.get("peak", 0.0)) > 0.0:
		var found: Dictionary = _norm["peaks"]
		found[id] = float(result.get("peak_db", 0.0))
	if not waiting.is_empty():
		return
	var done: Dictionary = _norm
	_norm = {}
	var d: Project = _doc()
	var s: Sequence = d.sequence_by_id(String(done["seq_id"])) if d != null else null
	var peaks: Dictionary = done["peaks"]
	if s == null or peaks.is_empty():
		Events.toast("Nothing to normalise, the clips were silent")
		return
	var ids: PackedStringArray = PackedStringArray()
	for k: Variant in peaks.keys():
		ids.append(String(k))
	if Tools.apply_gain(d, s, ids, "normalise", float(done["target"]), peaks):
		Events.toast("Normalised " + str(ids.size()) + (" clip" if ids.size() == 1 else " clips") + " to " + String.num(float(done["target"]), 1) + " dB")


static func go_key(dir: int) -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if ids.is_empty():
		Events.toast("Select a clip first")
		return
	var t: float = Tools.next_key_time(s, ids, s.playhead, dir)
	if t < 0.0:
		Events.toast("No more keyframes that way")
		return
	Session.set_playhead(t)


static func gap_choices(s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var every: PackedStringArray = PackedStringArray()
	for t: Track in s.all_tracks():
		if not t.locked:
			every.append(t.id)
	out.append({"label": "Every track", "ids": every})
	out.append({"label": "Targeted tracks", "ids": Verbs.track_ids(Verbs.working_tracks(s))})
	for kind: String in ["video", "audio"]:
		for t2: Track in Tools.ordered_tracks(s, kind):
			if not t2.locked:
				out.append({"label": t2.label, "ids": PackedStringArray([t2.id])})
	return out


static func close_all_gaps_dialog() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var choices: Array[Dictionary] = gap_choices(s)
	var names: Array = []
	for ch: Dictionary in choices:
		names.append(String(ch["label"]))
	var fields: Array[Dictionary] = []
	fields.append({"key": "tracks", "label": "Tracks", "type": "enum", "choices": names, "default": 0})
	fields.append({"key": "note", "type": "note", "default": "Closes the gaps between clips, not the space before the first clip. Sync locked tracks move with them and nothing is pushed over another clip."})
	var answered: Signal = _form("Close all gaps", fields, "Close gaps")
	answered.connect(Callable(_script(), "_on_gaps_answer").bind(choices))


static func _on_gaps_answer(result: Variant, choices: Array[Dictionary]) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var i: int = clampi(int((result as Dictionary).get("tracks", 0)), 0, choices.size() - 1)
	close_gaps_on(choices[i]["ids"])


static func close_gaps_on(track_ids: PackedStringArray) -> int:
	var had: int = Tools.count_gaps(_seq(), track_ids)
	var n: int = Tools.close_all_gaps(_doc(), _seq(), track_ids)
	if n > 0:
		Events.toast("Closed " + str(n) + (" gap" if n == 1 else " gaps"))
	elif had > 0:
		Events.notice("The gaps are held open", "A sync locked track has a clip across them. Turn that track's sync lock off to close the gaps on this track alone.")
	else:
		Events.toast("No gaps to close")
	return n


static func cut_at_markers() -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	if Tools.markers_in_range(s).is_empty():
		Events.toast("No markers between the in and the out")
		return
	var n: int = Tools.cut_at_markers(_doc(), s)
	Events.toast("Nothing to cut at the markers" if n == 0 else ("Cut at " + str(n) + (" marker" if n == 1 else " markers")))


static func close_selected_gap() -> bool:
	var cv: Control = canvas()
	if cv == null or not cv.has_method("close_selected_gap"):
		return false
	return bool(cv.call("close_selected_gap"))


static func play_kind(kind: String) -> void:
	var s: Sequence = _seq()
	if s == null:
		return
	var span: Dictionary = Tools.play_span(s, kind, float(Tools.pref(Tools.PREF_PREROLL, 2.0)), float(Tools.pref(Tools.PREF_POSTROLL, 2.0)))
	if span.is_empty():
		return
	var from_t: float = float(span["from"])
	var to_t: float = float(span["to"])
	if to_t < 0.0:
		Session.set_rate(1.0)
		Session.set_playing(true)
		return
	if to_t <= from_t + 0.001:
		Events.toast("Nothing to play, the out is before the in")
		return
	Session.play_span(from_t, to_t, float(span["back"]))
