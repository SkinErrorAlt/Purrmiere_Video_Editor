extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const StreamListen := preload("res://modules/core_panels/stream_listen.gd")
const LEVEL_FLOOR_DB := -48.0
const LEVEL_WINDOW := 0.15
const LEVEL_EVERY := 0.1
const PEAK_RATE := 100.0
const PEAK_CHUNK_SECONDS := 120.0


static func on(e: Dictionary) -> bool:
	return ViewStreams.on(ViewMap.of(e))


static func _lead(panel: Object, extra: float) -> Control:
	return panel.call("_spacer", float(Tk.px(Tk.sz("button_h"))) + extra)


static func _count(panel: Object, c: Clip, uid: String) -> int:
	return (panel.call("_crops_of", c.effect_by_uid(uid)) as Array).size()


static func _map(panel: Object, c: Clip, uid: String) -> Dictionary:
	return ViewStreams.normal(ViewMap.of(c.effect_by_uid(uid)), _count(panel, c, uid))


static func view_row(panel: Object, c: Clip, uid: String, index: int) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "StreamRow" + str(index)
	row.add_child(_lead(panel, float(Tk.px(48.0))))
	row.add_child(PmLabel.dim("Plays"))
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null or d == null:
		return row
	var e: Dictionary = c.effect_by_uid(uid)
	var map: Dictionary = _map(panel, c, uid)
	var item: MediaItem = d.media_by_id(c.media_id)
	var names: PackedStringArray = ViewMap.region_names(e)
	var region: String = names[index] if index < names.size() else "View " + str(index + 1)
	var tracks: Array[Track] = ViewStreams.carriers(s, c, map)
	if tracks.is_empty():
		row.add_child(PmLabel.trim("No sound of this file sits under this clip", "text_faint"))
	for tr: Track in tracks:
		row.add_child(PmLabel.faint(tr.shown_label()))
		var drop: Button = PmDrop.make_drop(choices_for(item), str(current_pick(s, c, map, index, tr)))
		drop.name = "Pick_" + tr.id
		drop.custom_minimum_size.x = float(Tk.px(96.0))
		PmUI.tip(drop, "What " + tr.shown_label() + " plays while " + region + " is on screen")
		drop.connect("changed", _on_pick.bind(panel, uid, index, tr.id))
		row.add_child(drop)
	row.add_child(PmUI.spacer())
	if index == 0:
		var scope: Button = PmButton.make("Only this group" if String(map.get("scope", "group")) == "group" else "Every track", "link")
		scope.set("quiet", true)
		PmUI.tip(scope, "Whether the views reach only the audio linked to this clip, or every audio track")
		scope.pressed.connect(func() -> void: panel.call("_on_view_scope", uid))
		row.add_child(scope)
	return row


static func choices_for(item: MediaItem) -> Array:
	var out: Array = [PmDrop.choice(str(ViewStreams.SILENT), "Silent")]
	for o: int in ViewStreams.count(item):
		out.append(PmDrop.choice(str(o), ViewStreams.name_of(item, o) + " (" + str(o + 1) + ")"))
	return out


static func current_pick(s: Sequence, video: Clip, map: Dictionary, index: int, tr: Track) -> int:
	if not ViewStreams.hears(map, index, tr.id, ""):
		return ViewStreams.SILENT
	var p: int = ViewStreams.pick(map, index, tr.id)
	return p if p >= 0 else ViewStreams.first_stream(s, video, map, tr)


static func _on_pick(id: String, panel: Object, uid: String, index: int, track_id: String) -> void:
	var c: Clip = panel.call("target_clip")
	if c == null:
		return
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var tr: Track = s.track_by_id(track_id) if s != null else null
	if d != null and tr != null and not Verbs.track_accepts(d, s, tr, "pair"):
		Events.toast(Verbs.track_refusal(d, s, tr, "pair"))
		panel.call("rebuild")
		return
	var map: Dictionary = ViewStreams.with_pick(_map(panel, c, uid), index, track_id, int(id))
	panel.call("_write_view_audio", uid, map, "View sound stream")


static func add_rows(panel: Object, body: VBoxContainer, c: Clip, e: Dictionary) -> void:
	var uid: String = String(e.get("uid", ""))
	var map: Dictionary = ViewMap.of(e)
	var streams: bool = ViewStreams.on(map)
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "SoundByRow"
	row.add_child(_lead(panel, 0.0))
	row.add_child(PmLabel.dim("Sound by"))
	for spec: Array in [[false, "By track", "Each view hears whole audio tracks, switched on and off with the view"], [true, "By stream", "Each view picks which of the file's sound streams every audio track plays"]]:
		var b: Button = PmButton.make(String(spec[1]), "", true)
		b.name = "SoundBy" + ("Stream" if bool(spec[0]) else "Track")
		b.set("quiet", true)
		b.set_pressed_no_signal(streams == bool(spec[0]))
		PmUI.tip(b, String(spec[2]))
		b.pressed.connect(_on_mode.bind(panel, uid, bool(spec[0])))
		row.add_child(b)
	row.add_child(PmUI.spacer())
	body.add_child(row)
	if streams:
		_add_streams(panel, body, c)


static func _on_mode(panel: Object, uid: String, streams: bool) -> void:
	var c: Clip = panel.call("target_clip")
	var s: Sequence = panel.call("seq")
	if c == null or s == null:
		return
	var map: Dictionary = _map(panel, c, uid)
	if ViewStreams.on(map) == streams:
		panel.call("rebuild")
		return
	var next: Dictionary = ViewStreams.to_streams(map, s, c) if streams else ViewStreams.to_tracks(map)
	panel.call("_write_view_audio", uid, next, "Sound by stream" if streams else "Sound by track")


static func _add_streams(panel: Object, body: VBoxContainer, c: Clip) -> void:
	var d: Project = panel.call("doc")
	var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if item == null:
		return
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	head.add_child(_lead(panel, 0.0))
	var title: Label = PmLabel.trim("Streams in " + item.label, "text_dim")
	PmUI.tip(title, "Streams in " + item.label)
	head.add_child(title)
	body.add_child(head)
	for o: int in ViewStreams.count(item):
		body.add_child(_stream_row(panel, c, item, o))


static func _stream_row(panel: Object, c: Clip, item: MediaItem, o: int) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "Stream" + str(o)
	row.add_child(_lead(panel, 0.0))
	var num: Label = PmLabel.mono(str(o + 1), "text_faint")
	num.custom_minimum_size.x = float(Tk.px(14.0))
	row.add_child(num)
	var name_edit: LineEdit = PmUI.line_edit(ViewStreams.hint_of(item, o), ViewStreams.given_name(item, o))
	name_edit.name = "Name"
	name_edit.custom_minimum_size.x = float(Tk.px(120.0))
	PmUI.tip(name_edit, "Name this stream (for example Mic, Game or Discord). Every Plays list shows this name")
	name_edit.text_submitted.connect(func(t: String) -> void: rename(panel.call("doc"), item.id, o, t))
	name_edit.focus_exited.connect(func() -> void: rename(panel.call("doc"), item.id, o, name_edit.text))
	row.add_child(name_edit)
	var info: String = ViewStreams.info_of(item, o)
	if not info.is_empty():
		row.add_child(PmLabel.mono(info, "text_faint"))
	var meter: Control = _Meter.new()
	meter.name = "Level"
	meter.set("media_id", item.id)
	meter.set("clip_id", c.id)
	meter.set("stream", o)
	meter.custom_minimum_size = Vector2(float(Tk.px(70.0)), float(Tk.px(10.0)))
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PmUI.tip(meter, "The level of this stream at the playhead")
	row.add_child(meter)
	var listen: Button = PmButton.make("Listen", "play", true)
	listen.name = "Listen"
	listen.set("quiet", true)
	PmUI.tip(listen, "Play this stream alone from the playhead. Press again, Space or play to stop")
	listen.pressed.connect(func() -> void: toggle_listen(panel, c.id, item.id, o))
	row.add_child(listen)
	var st: RefCounted = StreamListen.instance()
	var sync: Callable = func() -> void:
		if not is_instance_valid(listen):
			return
		var on_now: bool = bool(st.call("on_stream", item.id, o))
		listen.set_pressed_no_signal(on_now)
		listen.text = "Stop" if on_now else "Listen"
		listen.set("icon_name", "pause" if on_now else "play")
	st.connect("changed", sync)
	listen.tree_exiting.connect(func() -> void:
		if st.is_connected("changed", sync):
			st.disconnect("changed", sync))
	sync.call()
	return row


static func rename(d: Project, media_id: String, o: int, text: String) -> bool:
	if d == null:
		return false
	var item: MediaItem = d.media_by_id(media_id)
	if item == null or ViewStreams.given_name(item, o) == text.strip_edges():
		return false
	var cmds: Array[Command] = [MediaCmds.SetMediaField.new(media_id, "props", ViewStreams.with_name(item, o, text))]
	return Verbs.run(d, "Name stream", cmds)


static func file_time(c: Clip, t: float) -> float:
	if c == null:
		return 0.0
	if t >= c.start and t < c.end():
		return c.source_time(t)
	return c.source_in()


static func toggle_listen(panel: Object, clip_id: String, media_id: String, o: int) -> void:
	var st: RefCounted = StreamListen.instance()
	if bool(st.call("on_stream", media_id, o)):
		st.call("stop")
		return
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	var item: MediaItem = d.media_by_id(media_id)
	if c == null or item == null:
		return
	if not bool(st.call("play_stream", item, o, file_time(c, Session.playhead()), s.sample_rate)):
		Events.toast("The sound engine is not available, so the stream cannot be played")


static func level_of(bytes: PackedByteArray) -> float:
	var peak: int = 0
	for i: int in bytes.size() / 2:
		var lo: int = bytes[i * 2]
		var hi: int = bytes[i * 2 + 1]
		if lo == 0 and hi == 0:
			continue
		peak = maxi(peak, maxi(128 - lo, hi - 128))
	if peak <= 0:
		return 0.0
	var db: float = 20.0 * log(float(peak) / 127.0) / log(10.0)
	return clampf(1.0 - db / LEVEL_FLOOR_DB, 0.0, 1.0)


static func stream_level(handle: int, o: int, at: float, provider: Callable = Callable()) -> float:
	var from_b: int = maxi(int(floor((at - LEVEL_WINDOW) * PEAK_RATE)), 0)
	var count: int = maxi(int(ceil(LEVEL_WINDOW * 2.0 * PEAK_RATE)), 1)
	if provider.is_valid():
		return level_of(provider.call(handle, o, 0, from_b, count))
	var b: Node = StreamListen._bridge()
	if b == null or handle < 0 or not bool(b.get("available")):
		return -1.0
	var cov: PackedByteArray = b.call("peaks_coverage", handle, o)
	var k: int = int(floor(maxf(at, 0.0) / PEAK_CHUNK_SECONDS))
	if k >= cov.size() or cov[k] == 0:
		Session.want_peaks(handle, o, at)
		return -1.0
	return level_of(b.call("peaks_read", handle, o, 0, from_b, count))


class _Meter:
	extends Control

	const ROWS_PATH := "res://modules/core_panels/view_stream_rows.gd"

	var media_id: String = ""
	var clip_id: String = ""
	var stream: int = 0
	var level: float = -1.0
	var _wait: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_measure()

	func _process(dt: float) -> void:
		_wait -= dt
		if _wait > 0.0:
			return
		_wait = 0.1
		_measure()

	func _measure() -> void:
		var d: Object = Session.doc
		var s: Object = Session.seq()
		if d == null or s == null:
			return
		var item: RefCounted = d.call("media_by_id", media_id)
		var c: RefCounted = s.call("clip_by_id", clip_id)
		if item == null or c == null:
			return
		var ph: float = Session.playhead()
		var at: float = -1.0
		if ph >= float(c.get("start")) and ph < float(c.call("end")):
			at = float(c.call("source_time", ph))
		var was: float = level
		level = -1.0 if at < 0.0 else float((load(ROWS_PATH) as GDScript).call("stream_level", StreamListen.handle_of(item), stream, at))
		if not is_equal_approx(was, level):
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Tk.c["bg_field"], true)
		if level > 0.0:
			var w: float = maxf(r.size.x * level, 1.0)
			draw_rect(Rect2(0.0, 0.0, w, r.size.y), Tk.c["text"], true)
		draw_rect(r, Tk.c["border"], false, 1.0)


static func many_row(panel: Object, clips: Array, uids: Dictionary) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "ManySoundBy"
	row.add_child(_lead(panel, 0.0))
	row.add_child(PmLabel.dim("Sound by"))
	var on_n: int = 0
	for c: Variant in clips:
		if ViewStreams.on(ViewMap.of((c as Clip).effect_by_uid(String(uids.get((c as Clip).id, ""))))):
			on_n += 1
	for spec: Array in [[false, "By track", "Every selected Pair View: each view hears whole audio tracks"], [true, "By stream", "Every selected Pair View: each view picks which of the file's sound streams every audio track plays"]]:
		var b: Button = PmButton.make(String(spec[1]), "", true)
		b.name = "ManySoundBy" + ("Stream" if bool(spec[0]) else "Track")
		b.set("quiet", true)
		b.set_pressed_no_signal(on_n == clips.size() if bool(spec[0]) else on_n == 0)
		PmUI.tip(b, String(spec[2]))
		b.pressed.connect(func() -> void: set_mode_many(panel, uids, bool(spec[0])))
		row.add_child(b)
	if on_n > 0 and on_n < clips.size():
		row.add_child(PmLabel.faint("mixed"))
	row.add_child(PmUI.spacer())
	return row


static func set_mode_many(panel: Object, uids: Dictionary, streams: bool) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for id: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(id))
		if c == null:
			continue
		var uid: String = String(uids[id])
		var map: Dictionary = ViewStreams.normal(ViewMap.of(c.effect_by_uid(uid)), maxi(ViewMap.crop_count(c.effect_by_uid(uid)), 1))
		if ViewStreams.on(map) == streams:
			continue
		var next: Dictionary = ViewStreams.to_streams(map, s, c) if streams else ViewStreams.to_tracks(map)
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, "view_audio", JSON.stringify(next), -1.0))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Sound by stream" if streams else "Sound by track", cmds)


static func many_offset(panel: Object, clips: Array, uids: Dictionary) -> Button:
	var b: Button = PmButton.make("Offset", "slip")
	b.name = "ManyOffset"
	b.set("quiet", true)
	PmUI.tip(b, "Open the offset editor of every selected Pair View, one window each")
	b.pressed.connect(func() -> void: open_offsets(panel, uids))
	return b


static func open_offsets(panel: Object, uids: Dictionary) -> int:
	var editor: GDScript = load("res://modules/core_panels/offset_editor.gd")
	var n: int = 0
	var host: Variant = panel.get("_root")
	for id: Variant in uids.keys():
		var w: Variant = editor.call("open_for", host, String(id), String(uids[id]))
		if w is Control:
			(w as Control).position += Vector2(24.0, 24.0) * float(n)
			n += 1
	return n
