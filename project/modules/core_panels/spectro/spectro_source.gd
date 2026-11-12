extends RefCounted
## Gets the sound of a file as one mono stream of float samples for the spectrogram: decoded once by the engine's
## audio edit job into a float WAV in the cache, read back with one buffer read, and kept in memory for the last
## few sources.

signal source_ready(key: String)
signal source_failed(key: String, why: String)

const KEEP := 2
const MAX_SAMPLES := 1 << 27
const META := "purr_spectro_source"

var _mem: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _pending: Dictionary = {}
var _hooked: bool = false
var decodes_started: int = 0


static func instance() -> RefCounted:
	var loop: MainLoop = Engine.get_main_loop()
	if loop != null and loop.has_meta(META):
		return loop.get_meta(META)
	var me: RefCounted = load("res://modules/core_panels/spectro/spectro_source.gd").new()
	if loop != null:
		loop.set_meta(META, me)
	return me


static func cache_root() -> String:
	return Prefs.cache_dir().path_join("spectrogram")


static func key_for(path: String, stream: int) -> String:
	var stamp: String = str(FileAccess.get_modified_time(path)) if FileAccess.file_exists(path) else "0"
	return (path + "|" + str(stream) + "|" + stamp).md5_text()


## Returns {"samples", "rate", "key"} when the sound is ready, or {"key", "pending": true} while it decodes,
## or {"key", "error"} when it cannot be read.
func request(path: String, stream: int) -> Dictionary:
	if path.is_empty():
		return {"key": "", "error": "No file"}
	var key: String = key_for(path, stream)
	if _mem.has(key):
		_touch(key)
		return _mem[key]
	var direct: Dictionary = read_wav(path) if stream == 0 and path.get_extension().to_lower() == "wav" else {}
	if not direct.is_empty():
		return _keep(key, direct)
	var cached: String = cache_root().path_join(key + ".wav")
	if FileAccess.file_exists(cached):
		var got: Dictionary = read_wav(cached)
		if not got.is_empty():
			return _keep(key, got)
	if _pending.has(key):
		return {"key": key, "pending": true}
	if not FileAccess.file_exists(path):
		return {"key": key, "error": "The file is missing: " + path.get_file()}
	if not PurrBridge.available or not PurrBridge.has_method("audio_edit"):
		return {"key": key, "error": "Reading this sound needs the engine, which did not load"}
	_hook()
	DirAccess.make_dir_recursive_absolute(cache_root())
	var job: int = PurrBridge.audio_edit({"input": path, "stream": stream, "output": cached, "steps": [], "channels": 1, "label": "Spectrogram: reading " + path.get_file()})
	if job < 0:
		return {"key": key, "error": "The sound could not be read"}
	decodes_started += 1
	_pending[key] = cached
	return {"key": key, "pending": true}


func put(key: String, samples: PackedFloat32Array, rate: float) -> Dictionary:
	return _keep(key, {"samples": samples, "rate": rate})


func forget_all() -> void:
	_mem.clear()
	_order.clear()


func _keep(key: String, got: Dictionary) -> Dictionary:
	got["key"] = key
	_mem[key] = got
	_touch(key)
	while _order.size() > KEEP:
		_mem.erase(_order[0])
		_order.remove_at(0)
	return got


func _touch(key: String) -> void:
	var i: int = _order.find(key)
	if i >= 0:
		_order.remove_at(i)
	_order.append(key)


func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	PurrBridge.audio_edit_done.connect(_on_done)


func _on_done(result: Dictionary) -> void:
	var out: String = String(result.get("output", ""))
	var key: String = ""
	for k: String in _pending.keys():
		if String(_pending[k]) == out:
			key = k
	if key.is_empty():
		return
	_pending.erase(key)
	if not bool(result.get("ok", false)):
		source_failed.emit(key, String(result.get("error", "The sound could not be read")))
		return
	var got: Dictionary = read_wav(out)
	if got.is_empty():
		source_failed.emit(key, "The decoded sound could not be read")
		return
	_keep(key, got)
	source_ready.emit(key)


## Reads a mono 32 bit float WAV. Anything else returns an empty dictionary.
static func read_wav(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return {}
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return {}
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return {}
	var fmt_tag: int = 0
	var channels: int = 0
	var rate: int = 0
	var bits: int = 0
	while f.get_position() + 8 <= f.get_length():
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var size: int = f.get_32()
		var body: int = f.get_position()
		if id == "fmt ":
			fmt_tag = f.get_16()
			channels = f.get_16()
			rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
		elif id == "data":
			if fmt_tag != 3 or channels != 1 or bits != 32:
				return {}
			var avail: int = mini(size, int(f.get_length() - body))
			var count: int = mini(avail / 4, MAX_SAMPLES)
			var bytes: PackedByteArray = f.get_buffer(count * 4)
			return {"samples": bytes.to_float32_array(), "rate": float(rate)}
		f.seek(body + size + (size & 1))
	return {}


static func write_wav(path: String, samples: PackedFloat32Array, rate: int) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var data_bytes: int = samples.size() * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_bytes)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 4)
	f.store_16(4)
	f.store_16(32)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_bytes)
	f.store_buffer(samples.to_byte_array())
	f.close()
	return true
