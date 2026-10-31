extends RefCounted

const MarkerLayers := preload("res://doc/marker_layers.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const MediaItem := preload("res://doc/media_item.gd")
const RANGE_MODES: Array = [["in_out", "In to out"], ["markers", "Marker spans"], ["track", "Clips on a track"]]
const CUT_MODES: Array = [["keyframe", "Keyframe cut (fastest, no re-encode)"], ["smart", "Smart cut (frame accurate, re-encodes the first and last group of pictures)"]]
const BLURB := "Cut pieces out of one source file without re-encoding the whole of it. A keyframe cut starts each piece on the keyframe before the in point, so a piece can start early. A smart cut re-encodes only the first and last group of pictures so the in point is exact. If the engine cannot re-encode a stream the cut falls back to a keyframe cut, and the line under the summary says so and by how much."
const AUDIO_MODES: Array = [["copy", "Copy"], ["encode", "Encode"]]
const DEFAULT_TEMPLATE := "{source}_{index}_{in}-{out}"

var settings: Dictionary = default_settings()
var doc: Project = null
var seq: Sequence = null
var root: VBoxContainer = null
var _bridge: Node = null
var _events: Node = null
var _summary: Label = null
var _outcome_label: Label = null
var _labels: Dictionary = {}
var _fields: Dictionary = {}
var _job_id: int = -1
var _last_outcome: Dictionary = {}
var _last_text: String = ""


static func default_settings() -> Dictionary:
	return {"media_id": "", "source": "", "ranges": "in_out", "track_id": "", "mode": "keyframe", "audio": "copy", "template": DEFAULT_TEMPLATE, "out_dir": "", "container": "mp4"}


static func format_time(t: float) -> String:
	var total: int = int(floor(maxf(t, 0.0)))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	var frac: int = int(round((t - floor(t)) * 100.0))
	if frac >= 100:
		frac = 99
	return "%02d%02d%02d%02d" % [h, m, s, frac]


static func expand_template(template: String, source: String, index: int, t_in: float, t_out: float) -> String:
	var out: String = template
	if out.strip_edges().is_empty():
		out = DEFAULT_TEMPLATE
	out = out.replace("{source}", source.get_file().get_basename())
	out = out.replace("{index}", "%02d" % index)
	out = out.replace("{in}", format_time(t_in))
	out = out.replace("{out}", format_time(t_out))
	return out.validate_filename()


static func ranges_for(s: Sequence, media: MediaItem, mode: String, track_id: String, template: String) -> Array:
	var out: Array = []
	if s == null or media == null:
		return out
	var spans: Array[Vector2] = []
	if mode == "in_out":
		if s.in_point >= 0.0 and s.out_point > s.in_point:
			spans.append(Vector2(s.in_point, s.out_point))
	elif mode == "markers":
		var times: Array[float] = []
		for m: Marker in MarkerLayers.usable(s):
			if m.duration > 0.0:
				spans.append(Vector2(m.time, m.time + m.duration))
			else:
				times.append(m.time)
		times.sort()
		for i: int in times.size():
			var t1: float = times[i + 1] if i + 1 < times.size() else s.duration()
			if t1 > times[i]:
				spans.append(Vector2(times[i], t1))
	elif mode == "track":
		var tr: Track = s.track_by_id(track_id)
		if tr != null:
			for c: Clip in tr.clips:
				if c.media_id != media.id:
					continue
				var src_in: float = c.source_in()
				var src_out: float = c.source_out()
				if src_out > src_in:
					out.append({"in": src_in, "out": src_out, "name": expand_template(template, media.path, out.size() + 1, src_in, src_out)})
			return out
	for sp: Vector2 in spans:
		out.append({"in": sp.x, "out": sp.y, "name": expand_template(template, media.path, out.size() + 1, sp.x, sp.y)})
	return out


static func build_job(settings: Dictionary, s: Sequence, media: MediaItem) -> Dictionary:
	var ranges: Array = ranges_for(s, media, String(settings.get("ranges", "in_out")), String(settings.get("track_id", "")), String(settings.get("template", DEFAULT_TEMPLATE)))
	var source: String = String(settings.get("source", ""))
	if source.is_empty() and media != null:
		source = media.path
	var out_dir: String = String(settings.get("out_dir", ""))
	if out_dir.is_empty() and not source.is_empty():
		out_dir = source.get_base_dir().path_join("clips")
	return {
		"source": source,
		"ranges": ranges,
		"out_dir": out_dir,
		"mode": String(settings.get("mode", "keyframe")),
		"audio": String(settings.get("audio", "copy")),
		"container": String(settings.get("container", "mp4")),
	}


static func parse_result(message: String) -> Dictionary:
	if message.strip_edges().is_empty():
		return {}
	var reader: JSON = JSON.new()
	if reader.parse(message) != OK:
		return {}
	var parsed: Variant = reader.data
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func cut_outcome(result: Dictionary) -> Dictionary:
	var asked: String = String(result.get("asked", result.get("mode", "keyframe")))
	var out: Dictionary = {
		"pieces": 0,
		"written": 0,
		"failed": 0,
		"off": 0,
		"frame_accurate": false,
		"fell_back": false,
		"asked": asked,
		"worst_name": "",
		"worst_drift": 0.0,
		"worst_frames": 0,
		"reason": String(result.get("reason", "")),
	}
	var raw: Variant = result.get("pieces", [])
	var list: Array = raw as Array if raw is Array else []
	if list.is_empty():
		var raw_files: Variant = result.get("files", [])
		var written: int = (raw_files as Array).size() if raw_files is Array else 0
		var accurate: bool = bool(result.get("frame_accurate", false))
		out["pieces"] = written
		out["written"] = written
		out["frame_accurate"] = accurate and written > 0
		out["off"] = 0 if accurate else written
		out["fell_back"] = bool(result.get("fell_back", asked == "smart" and not accurate))
		out["worst_name"] = String(result.get("worst_name", ""))
		out["worst_drift"] = float(result.get("worst_in_drift", 0.0))
		out["worst_frames"] = int(result.get("worst_in_drift_frames", 0))
		return out
	for item: Variant in list:
		if not (item is Dictionary):
			continue
		var piece: Dictionary = item as Dictionary
		out["pieces"] = int(out["pieces"]) + 1
		if not bool(piece.get("ok", false)):
			out["failed"] = int(out["failed"]) + 1
			continue
		out["written"] = int(out["written"]) + 1
		if String(piece.get("asked", asked)) == "smart" and String(piece.get("method", "")) != "smart":
			out["fell_back"] = true
		if bool(piece.get("frame_accurate", false)):
			continue
		out["off"] = int(out["off"]) + 1
		var drift: float = float(piece.get("in_drift", 0.0))
		if absf(drift) >= absf(float(out["worst_drift"])):
			out["worst_drift"] = drift
			out["worst_frames"] = int(piece.get("in_drift_frames", 0))
			out["worst_name"] = String(piece.get("name", ""))
			var why: String = String(piece.get("reason", ""))
			if not why.is_empty():
				out["reason"] = why
	out["frame_accurate"] = int(out["written"]) > 0 and int(out["off"]) == 0 and int(out["failed"]) == 0
	return out


static func outcome_text(outcome: Dictionary) -> String:
	var written: int = int(outcome.get("written", 0))
	var failed: int = int(outcome.get("failed", 0))
	var off: int = int(outcome.get("off", 0))
	if written == 0:
		if failed > 0:
			return "No pieces were written: all %d failed." % failed
		return "No pieces were written."
	var head: String = "%d piece%s written" % [written, "" if written == 1 else "s"]
	if failed > 0:
		head += ", %d failed" % failed
	if off == 0:
		return head + ". Every piece starts on the frame you asked for."
	var drift: float = float(outcome.get("worst_drift", 0.0))
	var frames: int = int(outcome.get("worst_frames", 0))
	var name: String = String(outcome.get("worst_name", ""))
	var word: String = "late" if drift > 0.0 else "early"
	var worst: String = "the worst by %.3f s (%d frame%s) %s" % [absf(drift), frames, "" if frames == 1 else "s", word]
	if not name.is_empty():
		worst += ", on " + name
	var body: String = "%s. %d of them do not start on the frame you asked for, %s." % [head, off, worst]
	if bool(outcome.get("fell_back", false)):
		body += " Smart cut fell back to a keyframe cut"
		var why: String = String(outcome.get("reason", ""))
		if not why.is_empty():
			body += ": " + why
		body += ". These pieces are not frame accurate."
	elif String(outcome.get("asked", "keyframe")) == "keyframe":
		body += " A keyframe cut always starts on the keyframe before the in point. Pick smart cut for an exact in point."
	return body


func last_outcome() -> Dictionary:
	return _last_outcome.duplicate(true)


func last_outcome_text() -> String:
	return _last_text


func attach(doc_: Project, seq_: Sequence) -> void:
	doc = doc_
	seq = seq_
	if root != null:
		_refresh()


func _autoload(n: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(n)
	return null


func _video_media() -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		if m.kind == "video" and not m.path.is_empty():
			out.append(m)
	return out


func _current_media() -> MediaItem:
	if doc == null:
		return null
	var m: MediaItem = doc.media_by_id(String(settings.get("media_id", "")))
	if m == null:
		var list: Array[MediaItem] = _video_media()
		if not list.is_empty():
			m = list[0]
			settings["media_id"] = m.id
	return m


func _dropdown(parent: Control, key: String, label: String, choices: Array, on_pick: Callable) -> void:
	var row: HBoxContainer = PmUI.hbox()
	var l: Label = PmLabel.dim(label)
	l.custom_minimum_size.x = float(Tk.px(120.0))
	row.add_child(l)
	var b: Button = PmButton.make("")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(b)
	_labels[key] = b
	b.pressed.connect(func() -> void:
		var items: Array = []
		for c: Array in choices:
			items.append(PmMenu.item(String(c[0]), String(c[1])))
		var menu: Control = PmMenu.open(b, items)
		menu.connect("picked", on_pick))
	parent.add_child(row)


func _set_label(key: String, text: String) -> void:
	if _labels.has(key):
		(_labels[key] as Button).text = text


func _text_row(parent: Control, key: String, label: String, placeholder: String) -> void:
	var row: HBoxContainer = PmUI.hbox()
	var l: Label = PmLabel.dim(label)
	l.custom_minimum_size.x = float(Tk.px(120.0))
	row.add_child(l)
	var le: LineEdit = PmUI.line_edit(placeholder, String(settings.get(key, "")))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		settings[key] = t
		_refresh_summary())
	_fields[key] = le
	row.add_child(le)
	parent.add_child(row)


func build(parent: Control) -> Control:
	_bridge = _autoload("PurrBridge")
	_events = _autoload("Events")
	root = PmUI.vbox()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(PmLabel.wrap(BLURB))
	_dropdown(root, "media", "Source file", [], _on_media_picked)
	_text_row(root, "source", "Or a path", "C:/footage/take.mp4")
	_dropdown(root, "ranges", "Ranges from", RANGE_MODES, _on_ranges_picked)
	_dropdown(root, "track", "Track", [], _on_track_picked)
	_dropdown(root, "mode", "Cut", CUT_MODES, _on_mode_picked)
	_dropdown(root, "audio", "Audio", AUDIO_MODES, _on_audio_picked)
	_dropdown(root, "container", "Container", [["mp4", "MP4"], ["mov", "MOV"], ["mkv", "MKV"]], _on_container_picked)
	_text_row(root, "template", "Naming", DEFAULT_TEMPLATE)
	_text_row(root, "out_dir", "Destination folder", "beside the source in a clips folder")
	_summary = PmLabel.wrap("")
	root.add_child(_summary)
	_outcome_label = PmLabel.wrap("", "text_bright")
	_outcome_label.visible = false
	root.add_child(_outcome_label)
	_listen()
	var buttons: HBoxContainer = PmUI.hbox()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var run: Button = PmButton.make("Cut clips")
	run.pressed.connect(_on_run)
	buttons.add_child(run)
	root.add_child(buttons)
	parent.add_child(root)
	_refresh()
	return root


func _listen() -> void:
	if _bridge == null:
		return
	if _bridge.has_signal("job_progress") and not _bridge.is_connected("job_progress", _on_job_progress):
		_bridge.connect("job_progress", _on_job_progress)
	if _bridge.has_signal("job_done") and not _bridge.is_connected("job_done", _on_job_done):
		_bridge.connect("job_done", _on_job_done)


func _on_job_progress(id: int, _progress: float, message: String) -> void:
	if id != _job_id:
		return
	var result: Dictionary = parse_result(message)
	if result.is_empty() or not (result.has("pieces") or result.has("files")):
		return
	report(result)


func _on_job_done(id: int, ok: bool, message: String) -> void:
	if id != _job_id:
		return
	if ok:
		if _last_outcome.is_empty() and _events != null:
			_events.warn("Clip cut finished but the engine said nothing about the in points")
		return
	var result: Dictionary = parse_result(message)
	if not result.is_empty() and (result.has("pieces") or result.has("files")):
		report(result)
		return
	if _events != null:
		_events.error("Clip cut failed", message)


func report(result: Dictionary) -> Dictionary:
	var outcome: Dictionary = cut_outcome(result)
	_last_outcome = outcome
	_last_text = outcome_text(outcome)
	if _outcome_label != null:
		_outcome_label.text = _last_text
		_outcome_label.visible = true
	if _events != null:
		if bool(outcome.get("frame_accurate", false)):
			_events.info("Clip cut finished", _last_text)
		else:
			_events.warn("Clip cut did not land on the in point you asked for", _last_text)
	return outcome


func _on_media_picked(id: String) -> void:
	settings["media_id"] = id
	var m: MediaItem = _current_media()
	if m != null:
		settings["source"] = m.path
		if _fields.has("source"):
			(_fields["source"] as LineEdit).text = m.path
	_refresh()


func _on_ranges_picked(id: String) -> void:
	settings["ranges"] = id
	_refresh()


func _on_track_picked(id: String) -> void:
	settings["track_id"] = id
	_refresh()


func _on_mode_picked(id: String) -> void:
	settings["mode"] = id
	_refresh()


func _on_audio_picked(id: String) -> void:
	settings["audio"] = id
	_refresh()


func _on_container_picked(id: String) -> void:
	settings["container"] = id
	_refresh()


func _refresh() -> void:
	if root == null:
		return
	var m: MediaItem = _current_media()
	var media_button: Button = _labels.get("media", null)
	if media_button != null:
		media_button.text = m.label if m != null else "No video in the bin"
		var choices: Array = []
		for vm: MediaItem in _video_media():
			choices.append([vm.id, vm.label])
		var items_holder: Array = choices
		for c: Dictionary in media_button.pressed.get_connections():
			media_button.pressed.disconnect(c["callable"])
		media_button.pressed.connect(func() -> void:
			var items: Array = []
			for c: Array in items_holder:
				items.append(PmMenu.item(String(c[0]), String(c[1])))
			if items.is_empty():
				items.append(PmMenu.item("none", "Add a video to the bin first"))
			var menu: Control = PmMenu.open(media_button, items)
			menu.connect("picked", _on_media_picked))
	for pair: Array in RANGE_MODES:
		if String(pair[0]) == String(settings["ranges"]):
			_set_label("ranges", String(pair[1]))
	for pair: Array in CUT_MODES:
		if String(pair[0]) == String(settings["mode"]):
			_set_label("mode", String(pair[1]))
	for pair: Array in AUDIO_MODES:
		if String(pair[0]) == String(settings["audio"]):
			_set_label("audio", String(pair[1]))
	_set_label("container", String(settings["container"]).to_upper())
	var track_button: Button = _labels.get("track", null)
	if track_button != null and seq != null:
		var tr: Track = seq.track_by_id(String(settings.get("track_id", "")))
		if tr == null and not seq.video_tracks.is_empty():
			tr = seq.video_tracks[0]
			settings["track_id"] = tr.id
		track_button.text = tr.label if tr != null else "No track"
		var tchoices: Array = []
		for t: Track in seq.video_tracks:
			tchoices.append([t.id, t.label])
		for c: Dictionary in track_button.pressed.get_connections():
			track_button.pressed.disconnect(c["callable"])
		track_button.pressed.connect(func() -> void:
			var items: Array = []
			for c: Array in tchoices:
				items.append(PmMenu.item(String(c[0]), String(c[1])))
			var menu: Control = PmMenu.open(track_button, items)
			menu.connect("picked", _on_track_picked))
		track_button.get_parent().visible = String(settings["ranges"]) == "track"
	_refresh_summary()


func _refresh_summary() -> void:
	if _summary == null:
		return
	var m: MediaItem = _current_media()
	var job: Dictionary = build_job(settings, seq, m)
	var ranges: Array = job["ranges"]
	if ranges.is_empty():
		_summary.text = "No ranges yet: set in and out, add markers, or pick a track with clips of this file."
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%d piece%s to %s" % [ranges.size(), "" if ranges.size() == 1 else "s", String(job["out_dir"])])
	for i: int in mini(ranges.size(), 6):
		var r: Dictionary = ranges[i]
		lines.append("  " + String(r["name"]) + "  " + String.num(float(r["in"]), 2) + " s to " + String.num(float(r["out"]), 2) + " s")
	if ranges.size() > 6:
		lines.append("  and %d more" % (ranges.size() - 6))
	_summary.text = "\n".join(lines)


func _on_run() -> void:
	var m: MediaItem = _current_media()
	var job: Dictionary = build_job(settings, seq, m)
	if String(job["source"]).is_empty():
		if _events != null:
			_events.warn("Clip cut needs a source file")
		return
	if (job["ranges"] as Array).is_empty():
		if _events != null:
			_events.warn("Clip cut has no ranges to write", "Set in and out points, add markers, or choose a track")
		return
	if _bridge == null or not bool(_bridge.get("available")):
		if _events != null:
			_events.error("Clip cut needs the native engine (purrcore), which is missing")
		return
	DirAccess.make_dir_recursive_absolute(String(job["out_dir"]))
	_last_outcome = {}
	_last_text = ""
	if _outcome_label != null:
		_outcome_label.text = ""
		_outcome_label.visible = false
	var id: int = int(_bridge.call("clipcut", job))
	_job_id = id
	if id < 0:
		if _events != null:
			_events.error("The engine refused the clip cut job", String(job["source"]))
		return
	if _events != null:
		_events.info("Clip cut started: %d pieces from %s" % [(job["ranges"] as Array).size(), String(job["source"]).get_file()], String(job["out_dir"]))
