extends "res://modules/core_panels/panel_base.gd"

const Tracking := preload("res://doc/tracking.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const Ops := preload("res://modules/core_panels/tracker_ops.gd")
const TrackerUi := preload("res://modules/core_panels/tracker_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const LABEL_W := 92.0
const APPLY_LAYER := "layer"
const APPLY_POINT := "point"
const APPLY_MASK := "mask"
const EMPTY_TEXT := "Pick a video clip on the timeline, put the playhead on it, then track a point or two."
const AREA_TEXT := "Without an area the whole picture is searched. Draw one round the part you want to follow, or leave out hands and HUD."

var _list: VBoxContainer = null
var _head_label: Label = null
var _queued: bool = false
var _status: Label = null
var _progress: ProgressBar = null
var _range_bar: Control = null
var _range_text: Label = null
var _stop_btn: Button = null
var _go_btns: Array[Button] = []
var _apply_kind: String = APPLY_LAYER
var _apply_clip: String = ""
var _apply_what: String = ""
var _stab_dragging: bool = false
var _stab_pending: Dictionary = {"mode": "lock", "smooth": 1.0, "position": true, "rotation": true, "scale": true, "edges": "crop"}
var _last_sid: String = ""
var built_sections: PackedStringArray = PackedStringArray()


func _build(root_: Control) -> void:
	TrackerUi.register_commands()
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head_label = PmLabel.trim("Tracker", "text_bright")
	_head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_head_label)
	var more: Button = quiet_icon("more", "More")
	more.pressed.connect(_on_more.bind(more))
	head.add_child(more)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(Tk.px(6.0))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(PmUI.inset(_list, 6.0, 6.0))
	var run: Node = TrackerUi.runner()
	if run != null and not run.is_connected("changed", _on_run_changed):
		run.connect("changed", _on_run_changed)
	rebuild()


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		_refresh_status()
		return
	if kind == "tracking" or kind == "selection" or kind == "structure" or kind == "meta":
		_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	rebuild()


func _on_sequence_changed(_seq_id: String) -> void:
	rebuild()


func _on_playhead(_t: float) -> void:
	var sid: String = current_sid()
	if sid != _last_sid:
		_queue()
		return
	_refresh_status()


func _on_tool(_tool_id: String) -> void:
	_queue()


func _on_run_changed() -> void:
	_refresh_status()


func current_sid() -> String:
	var d: Project = doc()
	var s: Sequence = seq()
	var sid: String = TrackerUi.set_for(d, s)
	if not sid.is_empty():
		return sid
	return ""


func target_clip() -> Clip:
	var s: Sequence = seq()
	if s == null:
		return null
	var d: Project = doc()
	var sid: String = current_sid()
	if not sid.is_empty():
		return s.clip_by_id(String(Tracking.set_by_id(d, sid).get("clip", "")))
	for id: String in s.selected_clip_ids:
		var c: Clip = s.clip_by_id(id)
		if c != null and Ops.can_track(d, c).is_empty():
			return c
	for id2: String in s.selected_clip_ids:
		var c2: Clip = s.clip_by_id(id2)
		if c2 != null:
			return c2
	return null


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	built_sections = PackedStringArray()
	_status = null
	_progress = null
	_range_bar = null
	_range_text = null
	_stop_btn = null
	_go_btns = []
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		_head_label.text = "Tracker"
		_list.add_child(PmUI.empty_state("No project open"))
		return
	var sid: String = current_sid()
	_last_sid = sid
	var c: Clip = target_clip()
	if sid.is_empty():
		_build_start(d, s, c)
		return
	var st: Dictionary = Tracking.set_by_id(d, sid)
	TrackerUi.active_set = sid
	_head_label.text = String(st.get("label", "Tracker"))
	_build_sets(d, c, sid)
	_build_track(d, s, st)
	_build_area(d, s, st)
	_build_range(d, s, st)
	_build_apply(d, s, st)
	_build_stabilise(d, s, st)
	_refresh_status()


func _section(title: String, key: String) -> VBoxContainer:
	var fold: VBoxContainer = PmFold.make(title, "tracker." + key, true)
	_list.add_child(fold)
	built_sections.append(title)
	var body: VBoxContainer = fold.get("body")
	body.add_theme_constant_override("separation", Tk.px(4.0))
	return body


func _row(parent: Control, label: String, tip: String = "") -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var l: Label = PmLabel.trim(label, "text_dim")
	l.custom_minimum_size = Vector2(float(Tk.px(LABEL_W)), 0.0)
	l.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(l)
	if not tip.is_empty():
		PmUI.tip(l, tip)
	parent.add_child(row)
	return row


func _button(parent: Control, text: String, icon: String, tip: String, cb: Callable, keys: String = "") -> Button:
	var b: Button = PmButton.make(text, icon)
	PmUI.tip(b, tip, keys)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_start(d: Project, s: Sequence, c: Clip) -> void:
	_head_label.text = "Tracker"
	var body: VBoxContainer = _section("Start", "start")
	var why: String = Ops.can_track(d, c)
	if c == null or not why.is_empty():
		body.add_child(PmLabel.wrap(EMPTY_TEXT if c == null else why + ".", "text_dim"))
		return
	body.add_child(PmLabel.wrap("Track something on %s. The tracker starts in the middle of the picture: drag it onto a corner, a logo or a bolt, then track." % c.label, "text_dim"))
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	body.add_child(row)
	var one: Button = PmButton.primary("Track a point", "target")
	PmUI.tip(one, "One tracker: what you attach follows its position")
	one.pressed.connect(_on_new.bind(1))
	row.add_child(one)
	_button(row, "Track two points", "target", "Two trackers: what you attach follows their position, turn and size", _on_new.bind(2))
	var others: Array[Dictionary] = []
	for k: Variant in d.tracking.keys():
		others.append(d.tracking[k])
	if not others.is_empty():
		body.add_child(PmLabel.dim("Other trackers in this project: %d (select their clip to see them)" % others.size()))


func _build_sets(d: Project, c: Clip, sid: String) -> void:
	if c == null:
		return
	var sets: Array[Dictionary] = Tracking.sets_for_clip(d, c.id)
	if sets.size() < 2:
		return
	var choices: Array = []
	for st: Dictionary in sets:
		choices.append(PmDrop.choice(String(st["id"]), String(st.get("label", st["id"]))))
	var row: HBoxContainer = _row(_list, "Tracker")
	var drop: Button = PmDrop.make_drop(choices, sid)
	drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop.connect("changed", _on_pick_set)
	row.add_child(drop)


func _build_track(d: Project, s: Sequence, st: Dictionary) -> void:
	var body: VBoxContainer = _section("Track", "track")
	var bar: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	body.add_child(bar)
	_go_btns.append(_tbutton(bar, "to_start", "Track backward to the start of the range", TrackerUi.CMD_BACKWARD, _on_track.bind("backward", false)))
	_go_btns.append(_tbutton(bar, "step_back", "Track backward one frame", TrackerUi.CMD_STEP_BACKWARD, _on_track.bind("backward", true)))
	_stop_btn = _tbutton(bar, "pause", "Stop tracking", TrackerUi.CMD_STOP, _on_stop)
	_go_btns.append(_tbutton(bar, "step_fwd", "Track forward one frame", TrackerUi.CMD_STEP_FORWARD, _on_track.bind("forward", true)))
	_go_btns.append(_tbutton(bar, "to_end", "Track forward to the end of the range", TrackerUi.CMD_FORWARD, _on_track.bind("forward", false)))
	bar.add_child(PmUI.spacer())
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(float(Tk.px(60.0)), float(Tk.px(6.0)))
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_progress)
	_status = PmLabel.wrap("", "text_dim")
	body.add_child(_status)
	var trs: Array = st.get("trackers", [])
	if trs.size() < 2:
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		body.add_child(row)
		_button(row, "Add a second tracker", "plus", "Two trackers give position, turn and size", _on_add_tracker)
	var srow: HBoxContainer = _row(body, "Stop below", "The tracker stops when its match with the pattern drops below this")
	var f: Control = PmField.make(float(st.get("stop_below", Tracking.STOP_BELOW)), 0.3, 0.99, 0.01, "")
	f.set("precision", 2)
	f.connect("value_changed", _on_stop_below)
	srow.add_child(f)


func _tbutton(parent: Control, icon: String, tip: String, cmd: String, cb: Callable) -> Button:
	var b: Button = quiet_icon(icon, tip, Cmd.keys_text(cmd))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_area(d: Project, s: Sequence, st: Dictionary) -> void:
	var body: VBoxContainer = _section("Track area", "area")
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	body.add_child(row)
	var tool: Button = PmButton.make("Track area tool", "region", true)
	tool.button_pressed = TrackerUi.tool_on()
	PmUI.tip(tool, TrackerUi.TOOL_TIP, Cmd.keys_text(TrackerUi.COMMAND_ID))
	tool.pressed.connect(_on_area_tool)
	row.add_child(tool)
	var kinds: Array = []
	for k: String in ["box", "shape", "points"]:
		kinds.append(PmDrop.choice(k, String(TrackerUi.KIND_LABELS[k])))
	var drop: Button = PmDrop.make_drop(kinds, TrackerUi.draw_kind)
	PmUI.tip(drop, "What the Track area tool draws: drag a box, hold and draw round a part, or click points")
	drop.connect("changed", _on_draw_kind)
	row.add_child(drop)
	var leave: Button = PmButton.make("Leave out", "", true)
	leave.button_pressed = TrackerUi.leave_out
	PmUI.tip(leave, "New shapes leave a part out (hands, a HUD) instead of tracking inside it")
	leave.pressed.connect(_on_leave_out.bind(leave))
	row.add_child(leave)
	var w: float = float((st["size"] as Array)[0])
	var h: float = float((st["size"] as Array)[1])
	if w >= h * 2.5:
		var halves: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		body.add_child(halves)
		_button(halves, "Left half", "", "Track only the left player's view", _on_half.bind("left"))
		_button(halves, "Right half", "", "Track only the right player's view", _on_half.bind("right"))
	var areas: Array = st.get("areas", [])
	if areas.is_empty():
		body.add_child(PmLabel.wrap(AREA_TEXT, "text_faint"))
	for i: int in areas.size():
		var a: Dictionary = areas[i]
		var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		body.add_child(line)
		var leave_a: bool = bool(a.get("leave_out", false))
		var kind_label: String = String(TrackerUi.KIND_LABELS.get(String(a.get("kind", "box")), "Shape"))
		var keys: int = (a.get("keys", []) as Array).size()
		var text: String = "%s %d: %s%s" % ["Left out" if leave_a else "Area", i + 1, kind_label.to_lower(), ", keyed %d times" % keys if keys > 1 else ""]
		var l: Label = PmLabel.trim(text, "text" if not leave_a else "text_dim")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		var key_b: Button = quiet_icon("diamond", "Key the area here so it can follow a moving part")
		key_b.pressed.connect(_on_key_area.bind(String(a["id"])))
		line.add_child(key_b)
		var lo: Button = toggle_icon("eye_off", "Leave this area out", leave_a)
		lo.pressed.connect(_on_toggle_leave.bind(String(a["id"])))
		line.add_child(lo)
		var del: Button = quiet_icon("trash", "Remove this area")
		del.pressed.connect(_on_remove_area.bind(String(a["id"])))
		line.add_child(del)


func _build_range(d: Project, s: Sequence, st: Dictionary) -> void:
	var body: VBoxContainer = _section("Track range", "range")
	var c: Clip = d.clip_by_id(String(st.get("clip", "")))
	if c == null:
		return
	_range_bar = RangeBar.new()
	_range_bar.set("panel", self)
	_range_bar.set("sid", String(st["id"]))
	_range_bar.custom_minimum_size = Vector2(0.0, float(Tk.px(22.0)))
	_range_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PmUI.tip(_range_bar, "Drag either end to change what is tracked. Only this part of the file is ever decoded")
	body.add_child(_range_bar)
	_range_text = PmLabel.trim("", "text_dim")
	body.add_child(_range_text)
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	body.add_child(row)
	_button(row, "The clip", "", "Track the part of the clip that is on the timeline", _on_range_clip)
	var io: Button = _button(row, "In to Out", "", "Track between the timeline's In and Out marks", _on_range_in_out)
	io.disabled = s.in_point < 0.0 or s.out_point < 0.0


func _build_apply(d: Project, s: Sequence, st: Dictionary) -> void:
	var body: VBoxContainer = _section("Apply to", "apply")
	var two: bool = (st.get("trackers", []) as Array).size() >= 2
	var krow: HBoxContainer = _row(body, "Attach")
	var kinds: Array = [PmDrop.choice(APPLY_LAYER, "A layer"), PmDrop.choice(APPLY_POINT, "An effect point"), PmDrop.choice(APPLY_MASK, "A mask")]
	var kd: Button = PmDrop.make_drop(kinds, _apply_kind)
	kd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kd.connect("changed", _on_apply_kind)
	krow.add_child(kd)
	var clips: Array = _apply_clips(d, s, st)
	var crow: HBoxContainer = _row(body, "Clip")
	if clips.is_empty():
		crow.add_child(PmLabel.trim(_no_target_text(), "text_faint"))
	else:
		var ids: Array = []
		for ch: Dictionary in clips:
			ids.append(String(ch["id"]))
		if not ids.has(_apply_clip):
			_apply_clip = String(ids[0])
		var cd: Button = PmDrop.make_drop(clips, _apply_clip)
		cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cd.connect("changed", _on_apply_clip)
		crow.add_child(cd)
		var whats: Array = _apply_whats(d, s, two)
		var wrow: HBoxContainer = _row(body, "Follows" if _apply_kind == APPLY_LAYER else ("Point" if _apply_kind == APPLY_POINT else "Mask"))
		if whats.is_empty():
			wrow.add_child(PmLabel.trim("Nothing to attach on that clip", "text_faint"))
		else:
			var wids: Array = []
			for w: Dictionary in whats:
				wids.append(String(w["id"]))
			if not wids.has(_apply_what):
				_apply_what = String(wids[wids.size() - 1]) if _apply_kind == APPLY_LAYER else String(wids[0])
			var wd: Button = PmDrop.make_drop(whats, _apply_what)
			wd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wd.connect("changed", _on_apply_what)
			wrow.add_child(wd)
			var arow: HBoxContainer = PmUI.hbox(Tk.px(6.0))
			body.add_child(arow)
			var go: Button = PmButton.primary("Apply", "link")
			PmUI.tip(go, "Attach it to the tracker. It keeps where it is now and follows from here")
			go.pressed.connect(_on_apply)
			arow.add_child(go)
	var links: Array[Dictionary] = Ops.links(d, String(st["id"]))
	var layer_parts: Dictionary = {}
	for l0: Dictionary in links:
		if String(l0["kind"]) == "layer":
			var parts0: Array = layer_parts.get(String(l0["clip"]), [])
			parts0.append(String(l0["path"]))
			layer_parts[String(l0["clip"])] = parts0
	var shown: Dictionary = {}
	for l: Dictionary in links:
		if String(l["kind"]) == "stabilise":
			continue
		if String(l["kind"]) == "layer":
			if shown.has(String(l["clip"])):
				continue
			shown[String(l["clip"])] = true
		var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		body.add_child(line)
		var what: String = "position"
		if String(l["kind"]) == "mask":
			what = "mask"
		elif String(l["kind"]) == "effect":
			what = "effect point"
		elif (layer_parts.get(String(l["clip"]), []) as Array).size() >= 3:
			what = "position, turn and size"
		var lab: Label = PmLabel.trim("%s follows (%s)" % [String(l["label"]), what], "text")
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(lab)
		var bake: Button = PmButton.make("Bake", "")
		PmUI.tip(bake, "Turn the link into ordinary keyframes")
		bake.pressed.connect(_on_bake.bind(l))
		line.add_child(bake)
		var det: Button = quiet_icon("close", "Detach: stop following the tracker")
		det.pressed.connect(_on_detach.bind(l))
		line.add_child(det)


func _no_target_text() -> String:
	if _apply_kind == APPLY_POINT:
		return "No clip has an effect with a point"
	if _apply_kind == APPLY_MASK:
		return "No clip has a mask: draw one with the Pen"
	return "Put a title, picture or clip above the tracked clip"


func _apply_clips(d: Project, s: Sequence, st: Dictionary) -> Array:
	var out: Array = []
	var tracked: String = String(st.get("clip", ""))
	for tr: Track in s.video_tracks:
		for c: Clip in tr.clips:
			if _apply_kind == APPLY_LAYER and c.id == tracked:
				continue
			if _apply_kind == APPLY_POINT and Ops.effect_points(c).is_empty():
				continue
			if _apply_kind == APPLY_MASK and c.masks.is_empty():
				continue
			out.append(PmDrop.choice(c.id, c.label if not c.label.is_empty() else c.id))
	return out


func _apply_whats(d: Project, s: Sequence, two: bool) -> Array:
	var out: Array = []
	var c: Clip = s.clip_by_id(_apply_clip)
	if c == null:
		return out
	if _apply_kind == APPLY_LAYER:
		out.append(PmDrop.choice("position", "Position"))
		if two:
			out.append(PmDrop.choice("all", "Position, turn and size"))
	elif _apply_kind == APPLY_POINT:
		for p: Dictionary in Ops.effect_points(c):
			out.append(PmDrop.choice(String(p["uid"]) + "|" + String(p["key"]), String(p["label"])))
	else:
		for m: Dictionary in c.masks:
			out.append(PmDrop.choice(String(m.get("id", "")), String(m.get("label", "Mask " + String(m.get("id", ""))))))
	return out


func _build_stabilise(d: Project, s: Sequence, st: Dictionary) -> void:
	var body: VBoxContainer = _section("Stabilise", "stabilise")
	var sid: String = String(st["id"])
	var cur: Dictionary = Ops.stab_settings(d, sid)
	var two: bool = (st.get("trackers", []) as Array).size() >= 2
	var on: bool = not cur.is_empty()
	var opts: Dictionary = cur if on else _stab_pending
	var mrow: HBoxContainer = _row(body, "Mode")
	var md: Button = PmDrop.make_drop([PmDrop.choice("lock", "Lock: the point does not move"), PmDrop.choice("smooth", "Smooth: keep the camera move, lose the shake")], String(opts.get("mode", "lock")))
	md.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	md.connect("changed", _on_stab_mode)
	mrow.add_child(md)
	var srow: HBoxContainer = _row(body, "Smoothness", "How long a wobble is smoothed out, in seconds. Changes do not track again")
	var sf: Control = PmField.make(float(opts.get("smooth", 1.0)), 0.05, 10.0, 0.05, " s")
	sf.set("precision", 2)
	sf.connect("value_changed", _on_stab_smooth)
	sf.connect("edit_begun", _on_stab_begun)
	sf.connect("edit_ended", _on_stab_ended)
	srow.add_child(sf)
	srow.visible = String(opts.get("mode", "lock")) == "smooth"
	var krow: HBoxContainer = _row(body, "Steady")
	for k: String in ["position", "rotation", "scale"]:
		var cb: CheckBox = CheckBox.new()
		cb.text = {"position": "Position", "rotation": "Turn", "scale": "Size"}[k]
		cb.button_pressed = bool(opts.get(k, true)) and (k == "position" or two)
		cb.disabled = k != "position" and not two
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_on_stab_keep.bind(k))
		krow.add_child(cb)
	var erow: HBoxContainer = _row(body, "Edges")
	var ed: Button = PmDrop.make_drop([PmDrop.choice("crop", "Crop to fit"), PmDrop.choice("keep", "Keep edges")], String(opts.get("edges", "crop")))
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.connect("changed", _on_stab_edges)
	erow.add_child(ed)
	var arow: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	body.add_child(arow)
	if on:
		_button(arow, "Remove stabilise", "close", "Stop steadying the clip", _on_unstab)
		var path: Dictionary = TrackingEval.stab_path(st, cur)
		if bool(path.get("ok", false)) and String(cur.get("edges", "crop")) == "crop":
			arow.add_child(PmLabel.dim("Crop zooms %.2fx" % float(path["zoom"])))
	else:
		var go: Button = PmButton.primary("Stabilise", "")
		PmUI.tip(go, "Steady %s on its tracker%s" % ["the clip", "s" if two else ""])
		go.pressed.connect(_on_stab)
		go.disabled = not _tracked(st)
		arow.add_child(go)
		if not _tracked(st):
			body.add_child(PmLabel.wrap("Track first: stabilise uses the tracked frames.", "text_faint"))


func _tracked(st: Dictionary) -> bool:
	for t: Variant in st.get("trackers", []):
		if not String((t as Dictionary).get("rev", "")).is_empty():
			return true
	return false


func status_text() -> String:
	var d: Project = doc()
	var s: Sequence = seq()
	var sid: String = current_sid()
	if d == null or s == null or sid.is_empty():
		return ""
	var st: Dictionary = Tracking.set_by_id(d, sid)
	var c: Clip = d.clip_by_id(String(st.get("clip", "")))
	var run: Node = TrackerUi.runner()
	var parts: PackedStringArray = PackedStringArray()
	if run != null and String(run.call("running_set")) == sid:
		parts.append("Tracking %s, %d percent" % ["forward" if String((run.get("state") as Dictionary).get("direction", "")) == "forward" else "backward", int(round(float(run.call("progress")) * 100.0))])
	var fps: float = float(st.get("fps", 30.0))
	for t: Variant in st.get("trackers", []):
		var tr: Dictionary = t
		var sm: Dictionary = Tracking.samples(tr)
		var n: int = (sm["vt"] as PackedFloat64Array).size()
		var line: String = "%s: %s" % [String(tr.get("name", "")), "not tracked yet" if n == 0 else "%d frames tracked" % n]
		var lost: float = Tracking.lost_at(tr)
		if lost >= 0.0 and c != null:
			line += ", lost at " + tc(TrackingEval.seq_time_of(c, lost))
		if c != null and s.playhead >= c.start and s.playhead < c.end():
			var here: Dictionary = Tracking.position_at(tr, c.source_time(s.playhead), fps)
			if bool(here.get("tracked", false)):
				line += ", match %.2f here" % float(here.get("score", 1.0))
		parts.append(line)
	if c != null and (s.playhead < c.start or s.playhead >= c.end()):
		parts.append("Put the playhead on %s to see and move the trackers" % c.label)
	return "\n".join(parts)


func _refresh_status() -> void:
	if not _alive():
		return
	var run: Node = TrackerUi.runner()
	var running: bool = run != null and bool(run.call("running"))
	if _status != null and is_instance_valid(_status):
		_status.text = status_text()
	if _progress != null and is_instance_valid(_progress):
		_progress.visible = running
		_progress.value = float(run.call("progress")) if running else 0.0
	if _stop_btn != null and is_instance_valid(_stop_btn):
		_stop_btn.disabled = not running
	for b: Button in _go_btns:
		if is_instance_valid(b):
			b.disabled = running
	if _range_bar != null and is_instance_valid(_range_bar):
		_range_bar.queue_redraw()
	if _range_text != null and is_instance_valid(_range_text):
		_range_text.text = range_text()


func range_text() -> String:
	var d: Project = doc()
	var st: Dictionary = Tracking.set_by_id(d, current_sid())
	var c: Clip = d.clip_by_id(String(st.get("clip", ""))) if not st.is_empty() else null
	if c == null:
		return ""
	var r: Array = st.get("range", [0.0, 0.0])
	var a: float = TrackingEval.seq_time_of(c, float(r[0]))
	var b: float = TrackingEval.seq_time_of(c, float(r[1]))
	return "%s to %s (%.1f s of the file)" % [tc(a), tc(b), float(r[1]) - float(r[0])]


func _on_new(points: int) -> void:
	var c: Clip = target_clip()
	var sid: String = Ops.new_set(doc(), seq(), c, points)
	if sid.is_empty():
		Events.toast(Ops.can_track(doc(), c))
		return
	TrackerUi.active_set = sid
	rebuild()


func _on_pick_set(id: String) -> void:
	TrackerUi.active_set = id
	_queue()
	_redraw_program()


func _on_track(direction: String, one: bool) -> void:
	TrackerUi.track(direction, one)
	_refresh_status()


func _on_stop() -> void:
	TrackerUi.stop()


func _on_add_tracker() -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	Ops.add_tracker(doc(), current_sid(), Ops.media_time_at(c, playhead()))


func _on_stop_below(v: float) -> void:
	Ops.set_stop_below(doc(), current_sid(), v)


func _on_area_tool() -> void:
	TrackerUi.toggle_tool()


func _on_draw_kind(id: String) -> void:
	TrackerUi.draw_kind = id
	if not TrackerUi.tool_on():
		TrackerUi.use_tool()


func _on_leave_out(b: Button) -> void:
	TrackerUi.leave_out = b.button_pressed


func _on_half(side: String) -> void:
	var c: Clip = target_clip()
	if c != null:
		Ops.half_area(doc(), current_sid(), side, Ops.media_time_at(c, playhead()))


func _on_key_area(aid: String) -> void:
	var c: Clip = target_clip()
	if c != null:
		Ops.key_area(doc(), current_sid(), aid, Ops.media_time_at(c, playhead()))


func _on_toggle_leave(aid: String) -> void:
	Ops.toggle_leave_out(doc(), current_sid(), aid)


func _on_remove_area(aid: String) -> void:
	Ops.remove_area(doc(), current_sid(), aid)


func _on_range_clip() -> void:
	Ops.range_to_clip(doc(), current_sid())


func _on_range_in_out() -> void:
	if not Ops.range_to_in_out(doc(), seq(), current_sid()):
		Events.toast("Set In and Out marks on the timeline over the tracked clip first")


func _on_apply_kind(id: String) -> void:
	_apply_kind = id
	_apply_what = ""
	_queue()


func _on_apply_clip(id: String) -> void:
	_apply_clip = id
	_apply_what = ""
	_queue()


func _on_apply_what(id: String) -> void:
	_apply_what = id


func apply_now(kind: String, clip_id: String, what: String) -> bool:
	_apply_kind = kind
	_apply_clip = clip_id
	_apply_what = what
	return _apply()


func _on_apply() -> void:
	_apply()


func _apply() -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var target: Clip = s.clip_by_id(_apply_clip) if s != null else null
	if target == null:
		return false
	var sid: String = current_sid()
	var ok: bool = false
	if _apply_kind == APPLY_LAYER:
		ok = Ops.attach_layer(d, s, sid, target, _apply_what == "all")
	elif _apply_kind == APPLY_POINT:
		var parts: PackedStringArray = _apply_what.split("|")
		ok = parts.size() == 2 and Ops.attach_effect_point(d, s, sid, target, parts[0], parts[1])
	else:
		ok = Ops.attach_mask(d, s, sid, target, _apply_what)
	if not ok:
		Events.toast("Nothing was attached")
	return ok


func _on_bake(link: Dictionary) -> void:
	Ops.bake(doc(), link)


func _on_detach(link: Dictionary) -> void:
	Ops.detach(doc(), link)


func _stab_opts() -> Dictionary:
	return Ops.stab_settings(doc(), current_sid())


func _on_stab() -> void:
	Ops.stabilise(doc(), seq(), current_sid(), _stab_pending)


func _stab_change(changes: Dictionary, live: bool) -> void:
	if Ops.stab_settings(doc(), current_sid()).is_empty():
		for k: Variant in changes.keys():
			_stab_pending[k] = changes[k]
		if not live:
			_queue()
		return
	Ops.set_stab(doc(), current_sid(), changes, live)


func _on_unstab() -> void:
	Ops.unstabilise(doc(), current_sid())


func _on_stab_mode(id: String) -> void:
	_stab_change({"mode": id}, false)


func _on_stab_edges(id: String) -> void:
	_stab_change({"edges": id}, false)


func _on_stab_keep(on: bool, key: String) -> void:
	_stab_change({key: on}, false)


func _on_stab_begun() -> void:
	_stab_dragging = true


func _on_stab_smooth(v: float) -> void:
	_stab_change({"smooth": v}, _stab_dragging)


func _on_stab_ended() -> void:
	_stab_dragging = false
	var d: Project = doc()
	if d != null and d.undo.has_live():
		d.undo.commit_live("Stabilise settings")


func _on_more(anchor: Control) -> void:
	var sid: String = current_sid()
	if sid.is_empty():
		return
	var items: Array = [PmMenu.item("clear", "Clear tracked frames"), PmMenu.item("remove", "Remove this tracker")]
	var m: Control = PmMenu.open(anchor, items)
	if m != null:
		m.connect("picked", _on_more_picked)


func _on_more_picked(id: String) -> void:
	var sid: String = current_sid()
	if id == "clear":
		Ops.clear_tracking(doc(), sid)
	elif id == "remove":
		Ops.remove_set(doc(), sid)
		TrackerUi.active_set = ""
	_queue()


func _redraw_program() -> void:
	var p: Object = bus().call("panel", "program")
	var v: Variant = p.get("view") if p != null else null
	if v is Control:
		(v as Control).call("redraw_overlay")


class RangeBar extends Control:
	const PAD := 6.0
	var panel: Object = null
	var sid: String = ""
	var _drag: String = ""
	var _a: float = 0.0
	var _b: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _tset() -> Dictionary:
		var d: Object = Session.doc
		return load("res://doc/tracking.gd").call("set_by_id", d, sid)

	func _clip() -> Object:
		var st: Dictionary = _tset()
		return Session.doc.call("clip_by_id", String(st.get("clip", ""))) if not st.is_empty() else null

	func domain() -> Vector2:
		var c: Object = _clip()
		if c == null:
			return Vector2(0.0, 1.0)
		return Vector2(float(c.call("source_time", float(c.get("start")))), float(c.call("source_time", float(c.call("end")))))

	func range_now() -> Vector2:
		if not _drag.is_empty():
			return Vector2(_a, _b)
		var r: Array = _tset().get("range", [0.0, 1.0])
		return Vector2(float(r[0]), float(r[1]))

	func x_of(mt: float) -> float:
		var dm: Vector2 = domain()
		return PAD + (mt - dm.x) / maxf(dm.y - dm.x, 0.000001) * (size.x - 2.0 * PAD)

	func t_of(x: float) -> float:
		var dm: Vector2 = domain()
		return dm.x + clampf((x - PAD) / maxf(size.x - 2.0 * PAD, 1.0), 0.0, 1.0) * (dm.y - dm.x)

	func _draw() -> void:
		var h: float = size.y
		var mid: float = h * 0.5
		draw_rect(Rect2(PAD, mid - 3.0, size.x - 2.0 * PAD, 6.0), Tk.c["bg_field"], true)
		var r: Vector2 = range_now()
		var x0: float = x_of(r.x)
		var x1: float = x_of(r.y)
		var ink: Color = Color(0.36, 0.84, 1.0, 1.0)
		draw_rect(Rect2(x0, mid - 4.0, maxf(x1 - x0, 1.0), 8.0), Color(ink, 0.45), true)
		var st: Dictionary = _tset()
		var tracking: GDScript = load("res://doc/tracking.gd")
		for t: Variant in st.get("trackers", []):
			var span: Vector2 = tracking.call("tracked_span", t)
			if span.x <= span.y:
				draw_rect(Rect2(x_of(span.x), mid - 4.0, maxf(x_of(span.y) - x_of(span.x), 1.0), 3.0), Color(0.46, 0.9, 0.6, 1.0), true)
		var run: Node = load("res://modules/core_panels/tracker_ui.gd").call("runner")
		if run != null and String(run.call("running_set")) == sid:
			var e: float = float(run.call("latest_time"))
			var stt: Dictionary = run.get("state")
			if not is_nan(e):
				var from: float = float(stt.get("a", 0.0)) if String(stt.get("direction", "forward")) == "forward" else float(stt.get("b", 0.0))
				draw_rect(Rect2(x_of(minf(from, e)), mid + 1.0, maxf(absf(x_of(e) - x_of(from)), 1.0), 3.0), Color(0.46, 0.9, 0.6, 1.0), true)
		for gx: float in [x0, x1]:
			draw_rect(Rect2(gx - 2.0, mid - 7.0, 4.0, 14.0), Tk.c["text_bright"], true)
		var c: Object = _clip()
		var s: Object = Session.seq()
		if c != null and s != null:
			var ph: float = float(s.get("playhead"))
			if ph >= float(c.get("start")) and ph < float(c.call("end")):
				var px: float = x_of(float(c.call("source_time", ph)))
				draw_line(Vector2(px, 1.0), Vector2(px, h - 1.0), Tk.c["accent"], 1.0)

	func _on_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb: InputEventMouseButton = e
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				var r: Vector2 = range_now()
				var near_a: float = absf(mb.position.x - x_of(r.x))
				var near_b: float = absf(mb.position.x - x_of(r.y))
				_drag = "a" if near_a <= near_b else "b"
				_a = r.x
				_b = r.y
				_move(mb.position.x)
				accept_event()
			elif not _drag.is_empty():
				_drag = ""
				var ops: GDScript = load("res://modules/core_panels/tracker_ops.gd")
				ops.call("set_range", Session.doc, sid, _a, _b, "Set track range")
				queue_redraw()
				accept_event()
		elif e is InputEventMouseMotion and not _drag.is_empty():
			_move((e as InputEventMouseMotion).position.x)
			accept_event()

	func _move(x: float) -> void:
		var t: float = t_of(x)
		var st: Dictionary = _tset()
		var gap: float = 2.0 / maxf(float(st.get("fps", 30.0)), 1.0)
		if _drag == "a":
			_a = minf(t, _b - gap)
		else:
			_b = maxf(t, _a + gap)
		queue_redraw()
