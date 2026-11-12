extends RefCounted
## Hide a picture or words in sound: asks what to hide and where in the spectrum, makes the sound, adds it to the
## bin and puts it on a free audio track at the playhead, then shows it in the Spectrogram panel.

const PmUI := preload("res://ui/kit/pm_ui.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const HiddenSound := preload("res://modules/core_panels/spectro/hidden_sound.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const COMMAND := "audio.hide_picture"
const PICTURE_FILTERS: PackedStringArray = ["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Pictures"]
const SOURCES: PackedStringArray = ["Words", "A picture file"]
const SPACINGS: PackedStringArray = ["Even (linear)", "Musical (log)"]
const PLACES: PackedStringArray = ["On the timeline at the playhead", "In the bin only"]

static var last: Dictionary = {"source": 0, "words": "HELLO", "low": 2000.0, "high": 14000.0, "seconds": 6.0, "spacing": 0, "contrast": 50.0, "place": 0}


static func install() -> void:
	var script: GDScript = load("res://modules/core_panels/spectro/hidden_sound_ui.gd")
	Cmd.register(COMMAND, {"label": "Hide a picture or words in sound", "category": "Audio", "scope": "global", "handler": Callable(script, "open_from_command"), "owner": "core_panels", "enabled": Callable(Bus, "has_doc_static")})


static func open_from_command() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		open((loop as SceneTree).root)


static func open(host: Node) -> void:
	if Session.doc == null:
		Events.toast("Open a project first")
		return
	var fields: Array[Dictionary] = [
		{"key": "note", "type": "note", "default": "Makes a sound whose spectrogram draws a picture or words. Bright parts become loud tones, dark parts silence."},
		{"key": "source", "label": "Hide", "type": "enum", "choices": Array(SOURCES), "default": int(last["source"])},
		{"key": "words", "label": "Words (a | starts a new line)", "type": "string", "default": String(last["words"])},
		{"key": "low", "label": "Lowest frequency (Hz)", "type": "float", "default": float(last["low"])},
		{"key": "high", "label": "Highest frequency (Hz)", "type": "float", "default": float(last["high"])},
		{"key": "seconds", "label": "Length (seconds)", "type": "float", "default": float(last["seconds"])},
		{"key": "spacing", "label": "Frequency spacing", "type": "enum", "choices": Array(SPACINGS), "default": int(last["spacing"])},
		{"key": "contrast", "label": "Contrast (dB from bright to dim)", "type": "float", "default": float(last["contrast"])},
		{"key": "place", "label": "Put it", "type": "enum", "choices": Array(PLACES), "default": int(last["place"])},
	]
	var answered: Signal = PmUI.form(host, "Hide a picture in sound", fields, "Make the sound", "Cancel")
	answered.connect(_on_answered.bind(host))


static func _on_answered(result: Variant, host: Node) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	for k: String in last.keys():
		if r.has(k):
			last[k] = r[k]
	var spec: Dictionary = spec_from(r)
	if int(r.get("source", 0)) == 1:
		_pick_picture(host, spec, int(r.get("place", 0)) == 0)
		return
	var words: String = String(r.get("words", "")).strip_edges()
	if words.is_empty():
		Events.toast("Type the words to hide")
		return
	var img: Image = await HiddenSound.text_picture(host, words.replace("|", "\n"), 160)
	await make_and_place(img, spec, words, int(r.get("place", 0)) == 0)


static func spec_from(r: Dictionary) -> Dictionary:
	return {
		"low": float(str(r.get("low", 2000.0)).to_float()),
		"high": float(str(r.get("high", 14000.0)).to_float()),
		"seconds": float(str(r.get("seconds", 6.0)).to_float()),
		"log": int(r.get("spacing", 0)) == 1,
		"contrast": clampf(float(str(r.get("contrast", 50.0)).to_float()), 6.0, 120.0),
	}


static func _pick_picture(host: Node, spec: Dictionary, on_timeline: bool) -> void:
	var dlg := FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.filters = PICTURE_FILTERS
	dlg.title = "Pick the picture to hide"
	dlg.file_selected.connect(func(path: String) -> void:
		dlg.queue_free()
		var img := Image.new()
		if img.load(path) != OK:
			Events.warn("That picture could not be read", path)
			return
		make_and_place(img, spec, path.get_file().get_basename(), on_timeline))
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	host.add_child(dlg)
	dlg.popup_centered_ratio(0.6)


## Makes the sound, saves it, adds it to the bin and (when asked) to the timeline. Returns the saved path.
static func make_and_place(img: Image, spec: Dictionary, name_: String, on_timeline: bool) -> String:
	var made: Dictionary = HiddenSound.synth_picture(img, spec)
	if made.has("error"):
		Events.warn(String(made["error"]))
		return ""
	var path: String = HiddenSound.save(made, "hidden " + name_)
	if path.is_empty():
		Events.error("The hidden sound could not be saved", HiddenSound.out_dir())
		return ""
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null:
		return path
	var loader: RefCounted = load("res://modules/core_panels/media_loader.gd").call("instance")
	var ids: PackedStringArray = loader.call("import_paths", d, PackedStringArray([path]), "")
	if ids.is_empty():
		Events.warn("The hidden sound was saved to " + path + " but it could not be added to the bin")
		return path
	var placed: String = ""
	if on_timeline and s != null:
		await probed(d.media_by_id(ids[0]), 5.0)
		placed = place(d, s, ids[0], s.playhead, float(made["seconds"]))
	var spec_panel: Object = Bus.instance().panel("spectrogram")
	if spec_panel != null and placed.is_empty():
		spec_panel.call("show_file", path)
	if placed.is_empty():
		Events.info("Hidden sound added to the bin: " + path.get_file())
	else:
		Events.info("Hidden sound placed on the timeline. Open the Spectrogram to see it")
	return path


## Waits (up to a few seconds) for the engine to read a new file, so the clip gets the sound's real length.
static func probed(item: MediaItem, seconds: float) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if item == null or not (loop is SceneTree) or not PurrBridge.available:
		return
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not item.probed and Time.get_ticks_msec() < until:
		await (loop as SceneTree).process_frame


## Puts the media on the first unlocked audio track that is free from t for its length, adding a track if none
## is. Selects the new clip so the spectrogram shows it. Returns the clip id, or "" if it could not be placed.
static func place(d: Project, s: Sequence, media_id: String, t: float, seconds: float) -> String:
	var track: Track = null
	for tr: Track in s.audio_tracks:
		if not tr.locked and tr.clips_in_range(t, t + seconds).is_empty():
			track = tr
			break
	if track == null:
		var nt: Track = d.make_track("audio", "A" + str(s.audio_tracks.size() + 1))
		if not Verbs.run(d, "Add track", [TrackCmds.AddTrack.new(s.id, "audio", -1, nt.to_dict())]):
			return ""
		track = s.track_by_id(nt.id)
	if track == null or not Verbs.place_media(d, s, media_id, track.id, t, "overwrite"):
		return ""
	for c: Clip in track.clips_in_range(t, t + 0.001):
		if c.media_id == media_id:
			Verbs.select(d, s, PackedStringArray([c.id]))
			return c.id
	return ""
