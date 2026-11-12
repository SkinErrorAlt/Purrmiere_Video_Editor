extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const OWNER := "core_panels"
const TOOLS: Dictionary = {
	"tool.select": "select", "tool.track_fwd": "track_select", "tool.track_back": "track_select", "tool.ripple": "ripple",
	"tool.roll": "roll", "tool.rate": "rate", "tool.razor": "razor", "tool.slip": "slip", "tool.slide": "slide",
	"tool.pen": "pen", "tool.hand": "hand", "tool.zoom": "zoom", "tool.type": "type",
	"tool.realign": "realign",
}
const SHUTTLE_RATES: Array = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 100.0]
const SHUTTLE_PATH := "res://modules/core_panels/shuttle.gd"

static var _registered: bool = false


static func doc() -> Project:
	return Session.doc


static func seq() -> Sequence:
	return Session.seq()


static func has_doc() -> bool:
	return Session.doc != null


static func timeline() -> Object:
	return Bus.instance().panel("timeline")


static func canvas() -> Control:
	var tl: Object = timeline()
	if tl == null:
		return null
	var c: Variant = tl.get("canvas")
	if c != null and is_instance_valid(c) and c is Control:
		return c
	return null


static func _cmd(id: String, handler: Callable, scope: String = "global", toggle: Callable = Callable()) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Edit"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	var spec: Dictionary = {"label": label, "category": category, "scope": scope, "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")}
	if toggle.is_valid():
		spec["toggle"] = toggle
	Cmd.register(id, spec)


static func register_all() -> void:
	if _registered:
		return
	_registered = true
	var script: GDScript = load("res://modules/core_panels/commands.gd")
	for id: String in TOOLS.keys():
		_cmd(id, Callable(script, "set_tool").bind(id), "global", Callable(script, "tool_is").bind(id))
	_cmd("play.toggle", Callable(script, "play_toggle"))
	_cmd("app.double_press_report", Callable(load("res://host/key_guard.gd"), "say"))
	_cmd("bin.toggle_shelf", Callable(script, "toggle_bin_shelf"), "global", Callable(script, "bin_shelf_open"))
	load("res://modules/core_panels/space_hold.gd").call("install")
	load("res://modules/core_panels/spectro/hidden_sound_ui.gd").call("install")
	load("res://modules/core_panels/captions_ui.gd").call("install")
	_cmd("play.shuttle_left", Callable(script, "shuttle").bind(-1.0))
	_cmd("play.shuttle_right", Callable(script, "shuttle").bind(1.0))
	_cmd("play.shuttle_stop", Callable(script, "shuttle_stop"))
	_cmd("play.shuttle_slow_left", Callable(script, "shuttle_slow").bind(-1.0))
	_cmd("play.shuttle_slow_right", Callable(script, "shuttle_slow").bind(1.0))
	load(SHUTTLE_PATH).call("register_prefs")
	_cmd("play.around", Callable(script, "play_around"))
	_cmd("play.in_to_out", Callable(script, "play_in_to_out"))
	_cmd("play.in_to_out_roll", Callable(script, "play_in_to_out_roll"))
	_cmd("play.to_out", Callable(script, "play_to_out"))
	_cmd("play.loop", Callable(script, "loop_toggle"), "program", Callable(script, "loop_is"))
	_cmd("play.full_quality", Callable(load("res://engine/full_quality.gd"), "toggle"), "global", Callable(load("res://engine/full_quality.gd"), "is_on"))
	_cmd("play.scrub_audio", Callable(load("res://engine/scrub_audio.gd"), "toggle"), "global", Callable(load("res://engine/scrub_audio.gd"), "is_on"))
	_cmd("nav.step_back", Callable(script, "step").bind(-1))
	_cmd("nav.step_fwd", Callable(script, "step").bind(1))
	_cmd("nav.step_back_5", Callable(script, "step").bind(-5))
	_cmd("nav.step_fwd_5", Callable(script, "step").bind(5))
	_cmd("nav.start", Callable(script, "go_start"))
	_cmd("nav.end", Callable(script, "go_end"))
	_cmd("nav.clip_start", Callable(script, "go_clip").bind(true))
	_cmd("nav.clip_end", Callable(script, "go_clip").bind(false))
	_cmd("nav.prev_edit", Callable(script, "go_edit").bind(-1, false))
	_cmd("nav.next_edit", Callable(script, "go_edit").bind(1, false))
	_cmd("nav.prev_edit_any", Callable(script, "go_edit").bind(-1, true))
	_cmd("nav.next_edit_any", Callable(script, "go_edit").bind(1, true))
	_cmd("nav.to_in", Callable(script, "go_in_out").bind(true))
	_cmd("nav.to_out", Callable(script, "go_in_out").bind(false))
	_cmd("nav.next_marker", Callable(script, "go_marker").bind(1))
	_cmd("nav.prev_marker", Callable(script, "go_marker").bind(-1))
	_cmd("nav.next_warning", Callable(load("res://ui/timeline/warning_steps.gd"), "go").bind(1))
	_cmd("nav.prev_warning", Callable(load("res://ui/timeline/warning_steps.gd"), "go").bind(-1))
	_cmd("nav.next_gap", Callable(script, "go_gap").bind(1))
	_cmd("nav.prev_gap", Callable(script, "go_gap").bind(-1))
	_cmd("select.at_playhead", Callable(script, "select_at_playhead"))
	_cmd("select.prev_clip", Callable(script, "select_neighbour").bind(-1))
	_cmd("select.next_clip", Callable(script, "select_neighbour").bind(1))
	_cmd("mark.in", Callable(script, "mark_in"))
	_cmd("mark.out", Callable(script, "mark_out"))
	_cmd("mark.clip", Callable(script, "mark_clip"))
	_cmd("mark.selection", Callable(script, "mark_clip"))
	_cmd("mark.clear_in", Callable(script, "clear_mark").bind("in"))
	_cmd("mark.clear_out", Callable(script, "clear_mark").bind("out"))
	_cmd("mark.clear_both", Callable(script, "clear_mark").bind("both"))
	_cmd("mark.work_in", Callable(script, "mark_in"))
	_cmd("mark.work_out", Callable(script, "mark_out"))
	_cmd("marker.add", Callable(script, "marker_add"))
	_cmd("marker.add_clip", Callable(script, "marker_add_clip"))
	_cmd("marker.clear_current", Callable(script, "marker_clear_current"))
	_cmd("marker.clear_all", Callable(script, "marker_clear_all"))
	_cmd("marker.edit", Callable(script, "marker_edit"))
	_cmd("edit.ripple_trim_prev", Callable(script, "ripple_trim").bind("head"), "timeline")
	_cmd("edit.ripple_trim_next", Callable(script, "ripple_trim").bind("tail"), "timeline")
	_cmd("edit.extend_selected", Callable(script, "extend_selected"), "timeline")
	_cmd("edit.extend_prev", Callable(script, "extend_selected").bind(-1), "timeline")
	_cmd("edit.extend_next", Callable(script, "extend_selected").bind(1), "timeline")
	_cmd("edit.trim_prev", Callable(script, "trim_to_playhead").bind("head"), "timeline")
	_cmd("edit.trim_next", Callable(script, "trim_to_playhead").bind("tail"), "timeline")
	_cmd("edit.trim_back", Callable(script, "trim_frames").bind(-1), "timeline")
	_cmd("edit.trim_fwd", Callable(script, "trim_frames").bind(1), "timeline")
	_cmd("edit.trim_back_many", Callable(script, "trim_frames").bind(-5), "timeline")
	_cmd("edit.trim_fwd_many", Callable(script, "trim_frames").bind(5), "timeline")
	_cmd("edit.add_edit", Callable(script, "add_edit").bind(false), "timeline")
	_cmd("edit.add_edit_all", Callable(script, "add_edit").bind(true), "timeline")
	_cmd("edit.lift", Callable(script, "lift"))
	_cmd("edit.extract", Callable(script, "extract"))
	_cmd("edit.insert", Callable(script, "source_edit").bind("insert"))
	_cmd("edit.overwrite", Callable(script, "source_edit").bind("overwrite"))
	_cmd("edit.delete", Callable(script, "delete_selection").bind(false))
	_cmd("edit.ripple_delete", Callable(script, "delete_selection").bind(true))
	_cmd("edit.clear_selection", Callable(script, "clear_selection"))
	_cmd("edit.cut", Callable(script, "cut"))
	_cmd("edit.copy", Callable(script, "copy"))
	_cmd("edit.paste", Callable(script, "paste").bind(false))
	_cmd("edit.paste_insert", Callable(script, "paste").bind(true))
	_cmd("edit.paste_attributes", Callable(script, "paste_attributes"))
	_cmd("clip.remove_all_effects", Callable(script, "remove_all_effects"))
	_cmd("clip.toggle_all_effects", Callable(script, "toggle_all_effects"))
	_cmd("edit.duplicate", Callable(script, "duplicate_selection"))
	_cmd("edit.select_all", Callable(script, "select_all"), "timeline")
	_cmd("edit.deselect_all", Callable(script, "clear_selection"), "timeline")
	_cmd("edit.nudge_left", Callable(script, "nudge").bind(-1), "timeline")
	_cmd("edit.nudge_right", Callable(script, "nudge").bind(1), "timeline")
	_cmd("edit.nudge_left_5", Callable(script, "nudge").bind(-5), "timeline")
	_cmd("edit.nudge_right_5", Callable(script, "nudge").bind(5), "timeline")
	_cmd("edit.slip_left", Callable(script, "slip_frames").bind(-1), "timeline")
	_cmd("edit.slip_right", Callable(script, "slip_frames").bind(1), "timeline")
	_cmd("edit.slip_left_5", Callable(script, "slip_frames").bind(-5), "timeline")
	_cmd("edit.slip_right_5", Callable(script, "slip_frames").bind(5), "timeline")
	_cmd("edit.slide_left", Callable(script, "slide_frames").bind(-1), "timeline")
	_cmd("edit.slide_right", Callable(script, "slide_frames").bind(1), "timeline")
	_cmd("edit.slide_left_5", Callable(script, "slide_frames").bind(-5), "timeline")
	_cmd("edit.slide_right_5", Callable(script, "slide_frames").bind(5), "timeline")
	_cmd("edit.move_up", Callable(script, "move_track").bind(1), "timeline")
	_cmd("edit.move_down", Callable(script, "move_track").bind(-1), "timeline")
	_cmd("clip.link", Callable(script, "link_toggle"), "timeline")
	_cmd("clip.group", Callable(script, "group"), "timeline")
	_cmd("clip.ungroup", Callable(script, "ungroup"), "timeline")
	_cmd("clip.enable", Callable(script, "enable_toggle"), "timeline")
	_cmd("clip.nest", Callable(script, "nest"), "timeline")
	_cmd("clip.see_inside", Callable(script, "see_inside_toggle"), "timeline")
	_cmd("clip.see_inside_all", Callable(script, "see_inside_all"), "timeline")
	_cmd("seq.lock_in_out", Callable(script, "lock_in_out"))
	_cmd("seq.unlock_all", Callable(script, "unlock_all"))
	_cmd("clip.reveal_nested", Callable(script, "reveal_nested"), "timeline")
	register_groups_and_nests(script)
	_cmd("clip.speed", Callable(script, "speed_dialog"))
	_cmd("clip.sync_regions", Callable(load("res://modules/core_panels/pair_sync.gd"), "toggle_selected"), "global", Callable(load("res://modules/core_panels/pair_sync.gd"), "active"))
	_cmd("clip.view_cuts", Callable(load("res://modules/core_panels/pair_view_cuts.gd"), "toggle_selected"), "global", Callable(load("res://modules/core_panels/pair_view_cuts.gd"), "selected_on"))
	_cmd("clip.split_view_changes", Callable(load("res://modules/core_panels/pair_view_cuts.gd"), "split_selected"))
	_cmd("clip.offset_selected", Callable(load("res://modules/core_panels/pair_offsets.gd"), "open_for_selection"))
	load("res://modules/core_panels/pair_sync.gd").call("watch_session")
	_cmd("clip.volume_up", Callable(script, "clip_volume").bind(1.0))
	_cmd("clip.volume_down", Callable(script, "clip_volume").bind(-1.0))
	_cmd("clip.volume_up_many", Callable(script, "clip_volume").bind(6.0))
	_cmd("clip.volume_down_many", Callable(script, "clip_volume").bind(-6.0))
	_cmd("seq.snap", Callable(script, "snap_toggle"), "global", Callable(script, "snap_is"))
	_cmd("seq.linked_selection", Callable(script, "linked_toggle"), "global", Callable(script, "linked_is"))
	_cmd("seq.pin_track", Callable(script, "pin_selected_track"), "timeline")
	_cmd("seq.toggle_video_targets", Callable(script, "toggle_targets").bind("video"))
	_cmd("seq.toggle_audio_targets", Callable(script, "toggle_targets").bind("audio"))
	_cmd("seq.default_video_transition", Callable(script, "default_transition").bind("video"))
	_cmd("seq.default_audio_transition", Callable(script, "default_transition").bind("audio"))
	_cmd("seq.default_transitions", Callable(script, "default_transition").bind("both"))
	_cmd("view.zoom_in", Callable(script, "zoom").bind("in"))
	_cmd("view.zoom_out", Callable(script, "zoom").bind("out"))
	_cmd("view.zoom_sequence", Callable(script, "zoom").bind("fit"))
	_cmd("view.zoom_selection", Callable(script, "zoom").bind("selection"))
	_cmd("view.expand_tracks", Callable(script, "all_heights").bind(2.0))
	_cmd("view.minimise_tracks", Callable(script, "all_heights").bind(0.5))
	_cmd("view.video_track_taller", Callable(script, "kind_heights").bind("video", 12.0))
	_cmd("view.video_track_shorter", Callable(script, "kind_heights").bind("video", -12.0))
	_cmd("view.audio_track_taller", Callable(script, "kind_heights").bind("audio", 12.0))
	_cmd("view.audio_track_shorter", Callable(script, "kind_heights").bind("audio", -12.0))
	_cmd("view.next_screen", Callable(script, "screen").bind(1))
	_cmd("view.prev_screen", Callable(script, "screen").bind(-1))
	_cmd("file.export_frame", Callable(script, "export_frame"))
	_cmd("view.program_fullscreen", Callable(script, "program_fullscreen"))
	_cmd("view.program_popout", Callable(script, "program_popout"), "global", Callable(script, "program_popout_is"))
	_cmd("audio.field", Callable(script, "audio_tab").bind("field"))
	_cmd("audio.mixer", Callable(script, "audio_tab").bind("mix"))
	_cmd("audio.voiceover", Callable(script, "voiceover_toggle"), "global", Callable(script, "voiceover_is"))
	_cmd("audio.voiceover_cancel", Callable(script, "voiceover_cancel"))
	load("res://modules/core_panels/edit_commands.gd").call("register_all")
	load("res://modules/core_panels/stack_commands.gd").call("register_all")
	load("res://modules/core_panels/censor_commands.gd").call("register_all")
	load("res://modules/core_panels/record_commands.gd").call("register_all")
	load("res://modules/core_panels/views_commands.gd").call("register_all")
	load("res://modules/core_panels/groups_commands.gd").call("register_all")
	load("res://modules/core_panels/tracker_ui.gd").call("register_commands")
	load("res://modules/core_panels/object_ui.gd").call("register_commands")
	load("res://modules/core_panels/outline_commands.gd").call("register_all")
	load("res://modules/core_panels/monitor_snap.gd").call("register_all")
	load("res://modules/core_panels/pair_layouts.gd").call("register_all")


static var _vo_start: float = 0.0
static var _vo_track: String = ""


static func voiceover_is() -> bool:
	var vo: Node = _voiceover()
	return vo != null and bool(vo.call("recording"))


static func _voiceover() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/VoiceOver")
	return null


static func voiceover_track(seq: Sequence) -> Track:
	if seq == null:
		return null
	var picked: Track = Verbs.target_track(seq, "audio")
	if picked != null:
		return picked
	for t: Track in seq.audio_tracks:
		if t.targeted and not t.locked:
			return t
	for t: Track in seq.audio_tracks:
		if not t.locked:
			return t
	return null


static func voiceover_cancel() -> void:
	var vo: Node = _voiceover()
	if vo != null and bool(vo.call("recording")):
		vo.call("cancel")
		Events.info("Voice over discarded")


static func voiceover_toggle() -> void:
	var vo: Node = _voiceover()
	if vo == null:
		return
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return
	if bool(vo.call("recording")):
		var path: String = String(vo.call("stop_and_save", String(vo.call("take_stem", d))))
		if path.is_empty():
			Events.warn("Voice over: " + String(vo.call("last_error")))
			return
		var loader: RefCounted = load("res://modules/core_panels/media_loader.gd").call("instance")
		var ids: PackedStringArray = loader.call("import_paths", d, PackedStringArray([path]), "")
		if ids.is_empty():
			Events.warn("Voice over recorded to " + path + " but it could not be imported")
			return
		var tr: Track = s.track_by_id(_vo_track)
		if tr == null or tr.locked:
			tr = voiceover_track(s)
		if tr == null:
			Events.warn("Voice over recorded to " + path + " but there is no unlocked audio track to put it on")
			return
		if Verbs.place_media(d, s, ids[0], tr.id, _vo_start, "overwrite"):
			Events.info("Voice over placed on " + tr.label)
		else:
			Events.warn("Voice over recorded but it would not fit on " + tr.label)
		return
	var tr2: Track = voiceover_track(s)
	if tr2 == null:
		Events.warn("Select an audio track to record the voice over onto")
		return
	_vo_start = s.playhead
	_vo_track = tr2.id
	if not bool(vo.call("start")):
		Events.warn("Voice over could not start: " + String(vo.call("last_error")))
		return
	Events.info("Recording voice over onto " + tr2.label)


static func set_tool(id: String) -> void:
	Session.set_tool(String(TOOLS.get(id, "select")))


static func tool_is(id: String) -> bool:
	return Session.tool_id == String(TOOLS.get(id, ""))


static func play_toggle() -> void:
	if Session.playing and Session.rate != 1.0:
		Session.set_rate(1.0)
		load(SHUTTLE_PATH).call("set_pitch", false)
	Session.toggle_play()


static func shuttle(dir: float) -> void:
	var sh: GDScript = load(SHUTTLE_PATH)
	sh.call("apply", float(sh.call("next_fast", Session.rate, dir, Session.playing)))


static func shuttle_slow(dir: float) -> void:
	var sh: GDScript = load(SHUTTLE_PATH)
	sh.call("apply", float(sh.call("next_slow", Session.rate, dir, Session.playing)))


static func shuttle_stop() -> void:
	load(SHUTTLE_PATH).call("stop")


static func play_around() -> void:
	load("res://modules/core_panels/edit_commands.gd").call("play_kind", "around")


static func play_in_to_out() -> void:
	load("res://modules/core_panels/edit_commands.gd").call("play_kind", "in_to_out")


static func play_in_to_out_roll() -> void:
	load("res://modules/core_panels/edit_commands.gd").call("play_kind", "in_to_out_roll")


static func play_to_out() -> void:
	load("res://modules/core_panels/edit_commands.gd").call("play_kind", "to_out")


static func loop_toggle() -> void:
	Session.loop = not Session.loop


static func loop_is() -> bool:
	return Session.loop


static func frame() -> float:
	var s: Sequence = seq()
	if s == null or s.fps <= 0.0:
		return 1.0 / 30.0
	return 1.0 / s.fps


static func step(n: int) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	if Session.playing:
		Session.set_playing(false)
	var f: float = frame()
	var t: float = round(s.playhead / f) * f + float(n) * f
	Session.set_playhead(maxf(t, 0.0))


static func go_start() -> void:
	Session.set_playhead(0.0)


static func go_end() -> void:
	var s: Sequence = seq()
	if s != null:
		Session.set_playhead(s.duration())


static func go_clip(start: bool) -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if c == null:
		return
	Session.set_playhead(c.start if start else c.end())


static func go_edit(dir: int, any: bool) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var t: float = s.next_edit(s.playhead, not any) if dir > 0 else s.prev_edit(s.playhead, not any)
	if t >= 0.0:
		Session.set_playhead(t)


static func go_in_out(to_in: bool) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var t: float = s.in_point if to_in else s.out_point
	if t >= 0.0:
		Session.set_playhead(t)


static func go_marker(dir: int) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var best: float = -1.0
	for m: Marker in s.markers:
		if dir > 0 and m.time > s.playhead + 0.0001 and (best < 0.0 or m.time < best):
			best = m.time
		if dir < 0 and m.time < s.playhead - 0.0001 and (best < 0.0 or m.time > best):
			best = m.time
	if best >= 0.0:
		Session.set_playhead(best)


static func go_gap(dir: int) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var best: float = -1.0
	for t: Track in Verbs.working_tracks(s):
		for i: int in t.clips.size():
			var c: Clip = t.clips[i]
			var gap_start: float = c.end()
			var gap_end: float = t.clips[i + 1].start if i + 1 < t.clips.size() else INF
			if gap_end - gap_start <= 0.0001:
				continue
			if dir > 0 and gap_start > s.playhead + 0.0001 and (best < 0.0 or gap_start < best):
				best = gap_start
			if dir < 0 and gap_start < s.playhead - 0.0001 and (best < 0.0 or gap_start > best):
				best = gap_start
	if best >= 0.0:
		Session.set_playhead(best)


static func select_at_playhead() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = PackedStringArray()
	for t: Track in Verbs.working_tracks(s):
		var c: Clip = t.clip_at(s.playhead)
		if c != null:
			ids.append(c.id)
	Verbs.select(d, s, Verbs.MoveRule.pick(s, ids, Verbs.MoveRule.linked_on()), "replace", ids)


static func select_neighbour(dir: int) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = Bus.selected_clip(s)
	var t: Track = null
	if c != null:
		t = s.track_of(c.id)
	if t == null:
		var wt: Array[Track] = Verbs.working_tracks(s)
		if wt.is_empty():
			return
		t = wt[0]
	var next: Clip = null
	if c == null:
		next = t.clips[0] if not t.clips.is_empty() else null
	else:
		next = t.next_clip(c) if dir > 0 else t.prev_clip(c)
	if next != null:
		Verbs.select(d, s, Verbs.MoveRule.pick(s, PackedStringArray([next.id]), Verbs.MoveRule.linked_on()), "replace", PackedStringArray([next.id]))
		Session.set_playhead(next.start)


static func mark_in() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.set_in(doc(), s, s.playhead)


static func mark_out() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.set_out(doc(), s, s.playhead)


static func mark_clip() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var t0: float = INF
	var t1: float = -INF
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		t0 = minf(t0, c.start)
		t1 = maxf(t1, c.end())
	if t1 <= t0:
		for t: Track in Verbs.working_tracks(s):
			var c2: Clip = t.clip_at(s.playhead)
			if c2 != null:
				t0 = minf(t0, c2.start)
				t1 = maxf(t1, c2.end())
	if t1 > t0:
		Verbs.run(d, "Mark clip", [SequenceCmds.SetInOut.new(s.id, t0, t1)])


static func clear_mark(which: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if which == "both":
		Verbs.clear_in_out(d, s)
	elif which == "in":
		Verbs.run(d, "Clear in", [SequenceCmds.SetInOut.new(s.id, -1.0, s.out_point)])
	else:
		Verbs.run(d, "Clear out", [SequenceCmds.SetInOut.new(s.id, s.in_point, -1.0)])


static func marker_add() -> void:
	var bus: RefCounted = Bus.instance()
	if String(bus.get("focused_panel")) == "source":
		var src: Object = bus.call("panel", "source")
		if src != null and src.has_method("add_source_marker") and not String(src.get("media_id")).is_empty():
			src.call("add_source_marker")
			return
	var s: Sequence = seq()
	if s != null:
		Verbs.add_marker_at(doc(), s, s.playhead)


static func marker_add_clip() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if d == null or c == null:
		return
	Verbs.run(d, "Add clip marker", [MarkerCmds.AddMarker.new(s.id, c.id, {"id": d.mint_id("k"), "time": maxf(s.playhead - c.start, 0.0)})])


static func marker_at_playhead(s: Sequence) -> Marker:
	for m: Marker in s.markers:
		if absf(m.time - s.playhead) < 0.5 / maxf(s.fps, 1.0):
			return m
	return null


static func marker_clear_current() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var m: Marker = marker_at_playhead(s)
	if m != null:
		Verbs.run(d, "Remove marker", [MarkerCmds.RemoveMarker.new(s.id, "", m.id)])


static func marker_clear_all() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for m: Marker in s.markers.duplicate():
		cmds.append(MarkerCmds.RemoveMarker.new(s.id, "", m.id))
	Verbs.run(d, "Clear markers", cmds)


static func marker_edit() -> void:
	var s: Sequence = seq()
	var c: Control = canvas()
	if s == null or c == null:
		return
	var m: Marker = marker_at_playhead(s)
	if m != null:
		c.call("open_marker_editor", m.id)


const TrimAnim := preload("res://ui/timeline/timeline_trim_anim.gd")


static func ripple_trim(side: String) -> void:
	var s: Sequence = seq()
	if s != null:
		var shot: Dictionary = TrimAnim.before(canvas(), doc(), s, side)
		if Verbs.ripple_trim_to_playhead(doc(), s, side):
			TrimAnim.after(shot, side == "head")
		elif not Verbs.last_block.is_empty():
			Events.toast("Ripple trim: " + Verbs.last_block)


static func extend_selected(direction: int = 0) -> void:
	var s: Sequence = seq()
	if s != null:
		var shot: Dictionary = TrimAnim.before(canvas(), doc(), s, "edit")
		if Verbs.extend_edit_to_playhead(doc(), s, direction, Verbs.selection(s) if direction == 0 else PackedStringArray()):
			TrimAnim.after(shot, false)


static func trim_to_playhead(side: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var shot: Dictionary = TrimAnim.before(canvas(), d, s, side)
	var trimmed: bool = false
	var by_lines: int = Verbs.ViewTrims.trim_to_playhead(d, s, side)
	if by_lines >= 0:
		if by_lines == 1:
			TrimAnim.after(shot, false)
		return
	for t: Track in Verbs.working_tracks(s):
		var c: Clip = t.clip_at(s.playhead)
		if c != null and Verbs.trim(d, s, c.id, side, s.playhead, false):
			trimmed = true
	if trimmed:
		TrimAnim.after(shot, false)


static func trim_frames(n: int) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if d == null or c == null:
		return
	var side: String = "head" if absf(s.playhead - c.start) < absf(s.playhead - c.end()) else "tail"
	var edge: float = c.start if side == "head" else c.end()
	Verbs.trim(d, s, c.id, side, edge + float(n) * frame(), false)


static func add_edit(all: bool) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if not all and not Verbs.selection(s).is_empty():
		Verbs.razor(d, s, s.playhead, true, false)
	else:
		Verbs.razor(d, s, s.playhead, false, all)


static func lift() -> void:
	var s: Sequence = seq()
	if s != null and not Verbs.lift(doc(), s):
		Events.toast("Set in and out first")


static func extract() -> void:
	var s: Sequence = seq()
	if s != null and not Verbs.extract(doc(), s):
		Events.toast("Set in and out first")


static func source_edit(mode: String) -> void:
	var src: Object = Bus.instance().panel("source")
	if src != null and src.has_method("edit_to_timeline"):
		src.call("edit_to_timeline", mode)


static func delete_selected_transition() -> bool:
	var s: Sequence = seq()
	var held: Dictionary = Verbs.selected_transition(s)
	if held.is_empty():
		return false
	var took: bool = bool(load("res://modules/core_panels/transition_ops.gd").call("remove", doc(), s, String(held.get("clip_id", "")), String(held.get("side", "in"))))
	if took:
		Verbs.clear_transition(doc(), s)
	return took


static func delete_selected_free_transition() -> bool:
	var s: Sequence = seq()
	if s == null or s.held_free().is_empty():
		return false
	return bool(load("res://modules/core_panels/transition_ops.gd").call("remove_selected_free", doc(), s))


static func delete_selection(ripple: bool) -> void:
	if delete_selected_transition():
		return
	if delete_selected_free_transition():
		return
	if bool(load("res://modules/core_panels/censor_commands.gd").call("delete_selected")):
		return
	if not ripple and bool(load("res://ui/timeline/timeline_keys.gd").call("delete_from_timeline")):
		return
	var s: Sequence = seq()
	if s != null:
		if Verbs.selection(s).is_empty() and bool(load("res://modules/core_panels/edit_commands.gd").call("close_selected_gap")):
			return
		Verbs.delete_selection(doc(), s, ripple)


static func clear_selection() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.select(doc(), s, PackedStringArray(), "replace")


static func select_all() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var ids: PackedStringArray = PackedStringArray()
	for c: Clip in s.all_clips():
		ids.append(c.id)
	Verbs.select(doc(), s, ids, "replace")


static func copy() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var cb: Dictionary = Verbs.copy(doc(), s)
	if (cb["clips"] as Array).is_empty():
		return
	Bus.instance().clipboard = cb


static func cut() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	copy()
	Verbs.delete_selection(doc(), s, false)


static func paste(insert: bool) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var cb: Dictionary = Bus.instance().clipboard
	if cb.is_empty():
		return
	Verbs.paste(doc(), s, cb, s.playhead, insert)


static func paste_attributes() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	EffectOps.open_paste_sheet((loop as SceneTree).root, doc(), s, Bus.instance().clipboard)


static func remove_all_effects() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	if not EffectOps.remove_all(doc(), s, Verbs.selection(s)):
		Events.toast("The selected clips have no effects to remove")


static func toggle_all_effects() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	if not EffectOps.toggle_all(doc(), s, Verbs.selection(s)):
		Events.toast("The selected clips have no effects to turn off or on")


static func duplicate_selection() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cb: Dictionary = Verbs.copy(d, s)
	if (cb["clips"] as Array).is_empty():
		return
	var t1: float = -INF
	for id: String in Verbs.selection(s):
		t1 = maxf(t1, s.clip_by_id(id).end())
	Verbs.paste(d, s, cb, t1, false)


static func nudge(n: int) -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.nudge(doc(), s, n)


static func slip_frames(n: int) -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if c != null:
		Verbs.slip(doc(), s, c.id, float(n) * frame())


static func slide_frames(n: int) -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if c != null:
		Verbs.slide(doc(), s, c.id, float(n) * frame())


static func move_track(dir: int) -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.move_selection(doc(), s, 0.0, dir, "overwrite")


static func link_toggle() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var linked: bool = false
	for id: String in Verbs.selection(s):
		if not s.clip_by_id(id).link_id.is_empty():
			linked = true
	if linked:
		Verbs.unlink_selection(d, s)
	else:
		Verbs.link_selection(d, s)


static func group() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.group_selection(doc(), s)


static func ungroup() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.ungroup_selection(doc(), s)


static func enable_toggle() -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if c != null:
		Verbs.enable_selection(doc(), s, not c.enabled)


static func nest() -> void:
	var s: Sequence = seq()
	if s != null:
		Verbs.nest_selection(doc(), s, "Nested sequence")


static func see_inside_toggle() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		if c.is_nest():
			cmds.append(ClipCmds.SetNestOption.new(s.id, id, "see_inside", not bool(c.nest.get("see_inside", false))))
	if cmds.is_empty():
		Events.toast("Select a nest first")
		return
	Verbs.run(d, "See inside", cmds)


## Opens every nest in the sequence, or closes them all when every one is already open (one undo step).
static func see_inside_all() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var nests: Array[Clip] = []
	var all_open: bool = true
	for tr: Track in s.all_tracks():
		for c: Clip in tr.clips:
			if c.is_nest():
				nests.append(c)
				all_open = all_open and bool(c.nest.get("see_inside", false))
	if nests.is_empty():
		Events.toast("There are no nests in this sequence")
		return
	var cmds: Array[Command] = []
	for c2: Clip in nests:
		if bool(c2.nest.get("see_inside", false)) == all_open:
			cmds.append(ClipCmds.SetNestOption.new(s.id, c2.id, "see_inside", not all_open))
	Verbs.run(d, "See inside every nest" if not all_open else "Close every nest", cmds)


static func lock_in_out() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	if s.in_point < 0.0 or s.out_point <= s.in_point:
		Events.toast("Mark an in and an out first, then lock the region between them")
		return
	load("res://doc/fences.gd").call("add_in_out", doc(), s)


static func unlock_all() -> void:
	load("res://doc/fences.gd").call("clear", doc(), seq())


static func reveal_nested() -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if c != null and c.is_nest():
		var cv: Control = canvas()
		if cv != null and cv.has_signal("nest_open_requested"):
			cv.emit_signal("nest_open_requested", c.sequence_id, c.id)
			return
		Session.set_nest_context(c.sequence_id, s.id, c.id)
		Session.set_sequence(c.sequence_id)


static func register_groups_and_nests(script: GDScript) -> void:
	_cmd("group.select", Callable(script, "group_action").bind("select"), "timeline")
	_cmd("group.rename", Callable(script, "group_action").bind("rename"), "timeline")
	_cmd("group.lock", Callable(script, "group_action").bind("lock"), "timeline", Callable(script, "group_flag_is").bind("locked"))
	_cmd("group.mute", Callable(script, "group_action").bind("mute"), "timeline", Callable(script, "group_flag_is").bind("muted"))
	_cmd("group.add_selection", Callable(script, "group_action").bind("add"), "timeline")
	_cmd("group.remove_selection", Callable(script, "group_action").bind("remove"), "timeline")
	_cmd("group.to_nest", Callable(script, "group_action").bind("nest"), "timeline")
	_cmd("nest.unnest_to_group", Callable(script, "unnest_to_group"), "timeline")
	_cmd("nest.hear_audio", Callable(script, "nest_hear_audio_toggle"), "timeline", Callable(script, "nest_hear_audio_is"))
	_cmd("nest.hear_outside", Callable(script, "hear_outside_toggle"), "global", Callable(script, "hear_outside_is"))
	_cmd("nest.show_whole", Callable(script, "show_whole_toggle"), "global", Callable(script, "show_whole_is"))


static func selected_group_id(s: Sequence) -> String:
	if s == null:
		return ""
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		if c != null and not c.group_id.is_empty():
			return c.group_id
	return ""


static func group_action(action: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var gid: String = selected_group_id(s)
	if d == null or s == null:
		return
	if gid.is_empty():
		Events.toast("Select a clip that is in a group first")
		return
	var groups: GDScript = load("res://ui/timeline/timeline_groups.gd")
	groups.call("apply", d, s, gid, "select_whole" if action == "select" else action, canvas())


static func group_flag_is(key: String) -> bool:
	var s: Sequence = seq()
	var gid: String = selected_group_id(s)
	return not gid.is_empty() and bool(s.group_record(gid).get(key, false))


static func unnest_to_group() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if not bool(Verbs.group_verbs().call("unnest_selection_to_groups", d, s)):
		Events.toast("Select a nest first")


static func nest_hear_audio_toggle() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if d == null or c == null or not c.is_nest():
		Events.toast("Select a nest first")
		return
	Verbs.set_nest_option(d, s, c.id, "hear_audio", not bool(c.nest.get("hear_audio", true)))


static func nest_hear_audio_is() -> bool:
	var c: Clip = Bus.selected_clip(seq())
	return c != null and c.is_nest() and bool(c.nest.get("hear_audio", true))


static func hear_outside_toggle() -> void:
	Session.set_hear_outside(not Session.hear_outside())


static func hear_outside_is() -> bool:
	return Session.hear_outside()


static func show_whole_toggle() -> void:
	Session.set_show_whole(not Session.show_whole())


static func show_whole_is() -> bool:
	return Session.show_whole()


static func speed_dialog() -> void:
	var tl: Object = timeline()
	if tl != null and tl.has_method("open_speed_dialog"):
		tl.call("open_speed_dialog")


static func clip_volume(db: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id)
		if t == null or not t.is_sound(c):
			continue
		var prop: Dictionary = c.get_param("audio.volume")
		var v: float = AnimProp.evaluate_float(prop, c.param_time("audio.volume", maxf(s.playhead - c.start, 0.0)), c.duration)
		var nv: float = clampf(v * pow(10.0, db / 20.0), 0.0, 2.0)
		Verbs.set_clip_param(d, s, id, "audio.volume", nv, s.playhead if AnimProp.is_animated(prop) else -1.0)


static func snap_toggle() -> void:
	var c: Control = canvas()
	if c != null:
		c.set("snapping", not bool(c.get("snapping")))
		Prefs.set_value("timeline.snap", bool(c.get("snapping")))
		var tl: Object = timeline()
		if tl != null and tl.has_method("refresh_toolbar"):
			tl.call("refresh_toolbar")


static func snap_is() -> bool:
	var c: Control = canvas()
	return c != null and bool(c.get("snapping"))


static func linked_toggle() -> void:
	var c: Control = canvas()
	if c != null:
		c.set("linked_selection", not bool(c.get("linked_selection")))
		Prefs.set_value("timeline.linked_selection", bool(c.get("linked_selection")))
		var tl: Object = timeline()
		if tl != null and tl.has_method("refresh_toolbar"):
			tl.call("refresh_toolbar")


static func linked_is() -> bool:
	var c: Control = canvas()
	return c != null and bool(c.get("linked_selection"))


static func pin_selected_track() -> void:
	var c: Control = canvas()
	var s: Sequence = seq()
	if c == null or s == null:
		return
	var hov: Dictionary = c.get("hover")
	var t: Track = hov.get("track", null)
	if t == null:
		var sel: Clip = Bus.selected_clip(s)
		if sel != null:
			t = s.track_of(sel.id)
	if t == null:
		Events.toast("Point at a track header or select a clip first")
		return
	c.call("pin_track", t.id, not t.pinned)


static func toggle_targets(kind: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var any_on: bool = false
	for t: Track in s.tracks_of_kind(kind):
		if t.targeted:
			any_on = true
	var cmds: Array[Command] = []
	for t: Track in s.tracks_of_kind(kind):
		cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "targeted", not any_on))
	Verbs.run(d, "Toggle targets", cmds)


static func default_transition(kind: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if ids.is_empty():
		for t: Track in Verbs.working_tracks(s):
			var c: Clip = t.clip_at(s.playhead)
			if c != null:
				ids.append(c.id)
	for id: String in ids:
		var t2: Track = s.track_of(id)
		var c2: Clip = s.clip_by_id(id)
		if t2 == null or (kind != "both" and t2.clip_kind(c2) != kind):
			continue
		var spec: Dictionary = {"kind": "crossfade", "duration": minf(1.0, c2.duration * 0.5), "align": "centre"}
		if t2.is_picture(c2):
			spec = load("res://engine/transition_registry.gd").call("shared").call("default_spec", c2.duration)
		Verbs.set_transition(d, s, id, spec)


static func zoom(how: String) -> void:
	var c: Control = canvas()
	if c == null:
		return
	if how == "in":
		c.call("zoom_in")
	elif how == "out":
		c.call("zoom_out")
	elif how == "fit":
		c.call("zoom_fit")
	else:
		c.call("zoom_to_selection")


static func all_heights(factor: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Control = canvas()
	if d == null or s == null or c == null:
		return
	var cmds: Array[Command] = []
	for t: Track in s.all_tracks():
		var cur: float = float(c.call("lane_height_of", t.id))
		cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "height", clampf(cur * factor, 22.0, 480.0) / maxf(Tk.ui_scale, 0.01)))
	Verbs.run(d, "Track heights", cmds)


static func kind_heights(kind: String, delta: float) -> void:
	var c: Control = canvas()
	if c != null:
		c.call("_bump_kind_heights", kind, delta)


static func screen(dir: int) -> void:
	var c: Control = canvas()
	if c == null:
		return
	var sc: Node = c.get("_scroll")
	sc.call("scroll_by", float(dir) * float(c.call("view_w")), 0.0)


static func export_frame() -> void:
	var p: Object = Bus.instance().panel("program")
	if p != null and p.has_method("export_frame"):
		p.call("export_frame")


static func program_fullscreen() -> void:
	var p: Object = Bus.instance().panel("program")
	if p != null and p.has_method("toggle_fullscreen"):
		p.call("toggle_fullscreen")


static func program_popout() -> void:
	var p: Object = Bus.instance().panel("program")
	if p != null and p.has_method("toggle_popout"):
		p.call("toggle_popout")


static func program_popout_is() -> bool:
	var p: Object = Bus.instance().panel("program")
	return p != null and p.has_method("popped_out") and bool(p.call("popped_out"))


static func audio_tab(tab: String) -> void:
	var p: Object = Bus.instance().panel("audio")
	if p != null and p.has_method("show_tab"):
		p.call("show_tab", tab)


static func _bin_panel() -> Object:
	return Bus.instance().panel("bin")


static func toggle_bin_shelf() -> void:
	var p: Object = _bin_panel()
	if p != null and p.has_method("toggle_shelf"):
		p.call("toggle_shelf")


static func bin_shelf_open() -> bool:
	var p: Object = _bin_panel()
	return p != null and p.has_method("shelf_open") and bool(p.call("shelf_open"))
