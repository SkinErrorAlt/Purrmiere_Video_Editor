extends Node

const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")

const BUS_NAME := "VoiceOver"
const PREF_DEVICE := "audio.input_device"
const PREF_PINNED := "audio.input_device_pinned"
const PREF_CLEANUP := "audio.voiceover_cleanup"

signal level_changed(peak: float)
signal state_changed(recording: bool)

var _bus: int = -1
var _capture: AudioEffectCapture = null
var _player: AudioStreamPlayer = null
var _frames: PackedVector2Array = PackedVector2Array()
var _recording: bool = false
var _peak: float = 0.0
var _rate: int = 48000
var _started_at: float = 0.0
var _last_error: String = ""


func _ready() -> void:
	set_process(false)
	for spec: Array in [[PREF_DEVICE, "Default", {"label": "Microphone used for voice over", "type": "string"}], [PREF_PINNED, false, {"label": "Always use that microphone, never follow the system default", "type": "bool"}], [PREF_CLEANUP, false, {"label": "When a project opens, delete its own voice over recordings that no clip is using", "type": "bool"}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	apply_device()


func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func current_device() -> String:
	return AudioServer.input_device


func wanted_device() -> String:
	return String(Prefs.get_value(PREF_DEVICE))


func device_pinned() -> bool:
	return bool(Prefs.get_value(PREF_PINNED))


func set_device(name_: String) -> bool:
	if name_.is_empty():
		return false
	Prefs.set_value(PREF_DEVICE, name_)
	return apply_device()


func apply_device() -> bool:
	var want: String = wanted_device()
	if want.is_empty():
		return false
	var have: PackedStringArray = AudioServer.get_input_device_list()
	if not have.has(want):
		_last_error = "the microphone \"" + want + "\" is not plugged in, using " + AudioServer.input_device
		return false
	if AudioServer.input_device != want:
		AudioServer.input_device = want
	_last_error = ""
	return true


func last_error() -> String:
	return _last_error


func recording() -> bool:
	return _recording


func peak() -> float:
	return _peak


func elapsed() -> float:
	if not _recording:
		return 0.0
	return float(Time.get_ticks_msec()) / 1000.0 - _started_at


func _ensure_bus() -> bool:
	if _bus >= 0 and AudioServer.get_bus_index(BUS_NAME) == _bus and _capture != null:
		return true
	var existing: int = AudioServer.get_bus_index(BUS_NAME)
	if existing < 0:
		AudioServer.add_bus()
		existing = AudioServer.bus_count - 1
		AudioServer.set_bus_name(existing, BUS_NAME)
	_bus = existing
	AudioServer.set_bus_mute(_bus, true)
	_capture = null
	for i: int in range(AudioServer.get_bus_effect_count(_bus)):
		var fx: AudioEffect = AudioServer.get_bus_effect(_bus, i)
		if fx is AudioEffectCapture:
			_capture = fx
	if _capture == null:
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(_bus, _capture)
	return _capture != null


func start() -> bool:
	if _recording:
		return false
	if device_pinned():
		apply_device()
	if not _ensure_bus():
		_last_error = "could not open a recording bus"
		return false
	_frames = PackedVector2Array()
	_peak = 0.0
	_rate = int(AudioServer.get_mix_rate())
	if _player == null:
		_player = AudioStreamPlayer.new()
		add_child(_player)
	_player.bus = BUS_NAME
	_player.stream = AudioStreamMicrophone.new()
	_player.play()
	_capture.clear_buffer()
	_recording = true
	_started_at = float(Time.get_ticks_msec()) / 1000.0
	set_process(true)
	state_changed.emit(true)
	return true


func cancel() -> void:
	if not _recording:
		return
	_stop_capture()
	_frames = PackedVector2Array()
	state_changed.emit(false)


func _stop_capture() -> void:
	_recording = false
	set_process(false)
	if _player != null:
		_player.stop()
		_player.stream = null
	_peak = 0.0
	level_changed.emit(0.0)


func stop_and_save(base_name: String = "") -> String:
	if not _recording:
		return ""
	_pull()
	_stop_capture()
	state_changed.emit(false)
	if _frames.is_empty():
		_last_error = "nothing was recorded, check the microphone"
		return ""
	var dir: String = Io.data_path("voiceover")
	DirAccess.make_dir_recursive_absolute(dir)
	var stem: String = base_name if not base_name.is_empty() else "voiceover"
	var path: String = dir.path_join("%s_%s.wav" % [stem, Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")])
	var n: int = 1
	while FileAccess.file_exists(path):
		n += 1
		path = dir.path_join("%s_%s_%d.wav" % [stem, Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_"), n])
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(_frames.size() * 4)
	var at: int = 0
	for f: Vector2 in _frames:
		var l: int = int(clampf(f.x, -1.0, 1.0) * 32767.0)
		var r: int = int(clampf(f.y, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(at, l)
		pcm.encode_s16(at + 2, r)
		at += 4
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = _rate
	wav.data = pcm
	var err: int = wav.save_to_wav(path)
	_frames = PackedVector2Array()
	if err != OK:
		_last_error = "could not write " + path
		return ""
	_last_error = ""
	return path


func _pull() -> void:
	if _capture == null:
		return
	var available: int = _capture.get_frames_available()
	if available <= 0:
		return
	var got: PackedVector2Array = _capture.get_buffer(available)
	var high: float = 0.0
	for f: Vector2 in got:
		high = maxf(high, maxf(absf(f.x), absf(f.y)))
	_frames.append_array(got)
	_peak = high


func _process(_dt: float) -> void:
	if not _recording:
		return
	_pull()
	level_changed.emit(_peak)


func cleanup_enabled() -> bool:
	return bool(Prefs.get_value(PREF_CLEANUP))


func recordings_dir() -> String:
	return Io.data_path("voiceover")


func recordings_on_disk(dir: String = "") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if dir.is_empty():
		dir = recordings_dir()
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name_: String = d.get_next()
	while not name_.is_empty():
		if not d.current_is_dir() and name_.get_extension().to_lower() == "wav":
			out.append(dir.path_join(name_))
		name_ = d.get_next()
	d.list_dir_end()
	return out


static func take_stem(doc: Project) -> String:
	if doc == null or doc.id.strip_edges().is_empty():
		return "voiceover"
	return "voiceover_" + doc.id.validate_filename()


static func is_take_of(path: String, doc: Project) -> bool:
	if doc == null or doc.id.strip_edges().is_empty():
		return false
	return path.get_file().to_lower().begins_with((take_stem(doc) + "_").to_lower())


func sweep_unused(doc: Project, dir: String = "") -> PackedStringArray:
	var removed: PackedStringArray = PackedStringArray()
	if doc == null or not cleanup_enabled() or doc.id.strip_edges().is_empty():
		return removed
	var used: Dictionary = {}
	for m: MediaItem in doc.media:
		if not m.path.is_empty():
			used[m.path.replace("\\", "/").to_lower()] = true
	for path: String in recordings_on_disk(dir):
		if not is_take_of(path, doc):
			continue
		if used.has(path.replace("\\", "/").to_lower()):
			continue
		if DirAccess.remove_absolute(path) == OK:
			removed.append(path)
	return removed
