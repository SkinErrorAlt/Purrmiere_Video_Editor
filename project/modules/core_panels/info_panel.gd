extends "res://modules/core_panels/panel_base.gd"

const PropertiesSheet := preload("res://modules/core_panels/properties_sheet.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")

var _grid: GridContainer = null
var _title_label: Label = null
var _queued: bool = false


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_title_label = PmLabel.trim("Nothing selected", "text_bright")
	head.add_child(_title_label)
	var scroll: ScrollContainer = vscroll_area(col)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	rebuild()


func _row(key: String, value: String) -> void:
	_grid.add_child(PmLabel.dim(key))
	var v: Label = PmLabel.trim(value)
	_grid.add_child(v)


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_grid)
	PmUI.clear(_grid)
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null:
		_title_label.text = "No project"
		return
	var c: Clip = Bus.selected_clip(s)
	if c != null:
		_title_label.text = c.label if not c.label.is_empty() else c.id
		var t: Track = s.track_of(c.id)
		_row("Track", t.label if t != null else "")
		_row("Start", tc(c.start))
		_row("End", tc(c.end()))
		_row("Duration", tc(c.duration))
		_row("In point", tc(c.in_offset))
		var sp: float = c.static_speed()
		_row("Speed", (str(int(round(sp * 100.0))) + " %") if sp != 0.0 else "ramped")
		_row("Enabled", "yes" if c.enabled else "no")
		_row("Effects", str(c.effects.size()))
		_row("Linked", "yes" if not c.link_id.is_empty() else "no")
		if c.is_nest():
			var ns: Sequence = d.sequence_by_id(c.sequence_id)
			_row("Nest", ns.label if ns != null else c.sequence_id)
		var m: MediaItem = d.media_by_id(c.media_id)
		if m != null:
			_grid.add_child(PmLabel.small("Media"))
			_grid.add_child(PmLabel.small(""))
			_media_rows(d, m)
		return
	var bin: Object = bus().panel("bin")
	if bin != null:
		var sel: PackedStringArray = bin.get("selected_ids")
		if not sel.is_empty():
			var m2: MediaItem = d.media_by_id(sel[0])
			if m2 != null:
				_title_label.text = m2.label
				_media_rows(d, m2)
				return
	_title_label.text = s.label if s != null else d.name
	if s != null:
		_row("Sequence", s.label)
		_row("Frame size", str(s.width) + " x " + str(s.height))
		_row("Frame rate", String.num(s.fps, 3))
		_row("Duration", tc(s.duration()))
		_row("Video tracks", str(s.video_tracks.size()))
		_row("Audio tracks", str(s.audio_tracks.size()))
		_row("Clips", str(s.all_clips().size()))
		_row("Markers", str(s.markers.size()))
	_row("Project file", d.path if not d.path.is_empty() else "not saved yet")
	_row("Media items", str(d.media.size()))


func _media_rows(d: Project, m: MediaItem) -> void:
	_row("Kind", m.kind)
	if not m.path.is_empty():
		_row("Path", m.path)
	if m.is_timed():
		_row("Duration", tc(d.media_duration(m)))
	if m.width > 0:
		_row("Size", str(m.width) + " x " + str(m.height))
	if m.fps > 0.0:
		_row("Frame rate", String.num(m.fps, 3))
	if m.has_audio or m.kind == "audio":
		_row("Audio streams", str(maxi(m.audio_streams.size(), 1)))
		var roles: String = StreamRoles.summary(m)
		if not roles.is_empty():
			_row("Audio track names", roles)
		_row("Sample rate", PropertiesSheet.sample_text(m))
	_row("Read", "yes" if m.probed else "not yet")
	if m.kind == "video" and PurrBridge.available and m.handle >= 0:
		var info: Dictionary = PurrBridge.media_info(m.handle)
		_row("Decoder", (String(info.get("hw_type", "none")) if bool(info.get("hw", false)) else "software") + " (" + String(info.get("codec", "")) + ")")
		_row("Seek index", String(info.get("index_state", "none")))
		_row("Filmstrip", String(info.get("strip_state", "none")))
	if m.missing:
		_row("Status", "MISSING on disk")
	if not m.bin.is_empty():
		_row("Bin", m.bin)
	var uses: int = 0
	for sq: Sequence in d.sequences:
		for c: Clip in sq.all_clips():
			if c.media_id == m.id:
				uses += 1
	_row("Used by", str(uses) + (" clip" if uses == 1 else " clips"))


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_doc_changed(_kind: String) -> void:
	_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()
