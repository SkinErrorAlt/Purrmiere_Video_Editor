extends RefCounted

const MediaItem := preload("res://doc/media_item.gd")
const Io := preload("res://doc/io.gd")
const RATE := 48000
const CHANNELS := 2
const TONE_HZ := 1000.0
const TONE_DB := -20.0
const RAMP_SECONDS := 0.002
const FOLDER := "made_sounds"
const SOUND_PROP := "sound"
const SOUND_TONE := "tone"
const SOUND_POP := "pop"
const POP_AT_PROP := "pop_at"


static func amplitude(db: float) -> float:
	return pow(10.0, db / 20.0)


static func folder() -> String:
	return Io.data_path(FOLDER)


static func tone_name(seconds: float) -> String:
	return "tone_%dhz_%ddb_%dms.wav" % [int(TONE_HZ), int(TONE_DB), int(round(seconds * 1000.0))]


static func pop_name(seconds: float, pop_at: float, frame: float) -> String:
	return "pop_%dhz_%ddb_%dms_at%dms_len%dus.wav" % [int(TONE_HZ), int(TONE_DB), int(round(seconds * 1000.0)), int(round(pop_at * 1000.0)), int(round(frame * 1000000.0))]


static func frame_of(m: MediaItem) -> float:
	return 1.0 / (m.fps if m.fps > 0.0 else 30.0)


static func file_name_for(m: MediaItem) -> String:
	if m == null:
		return ""
	var kind: String = String(m.props.get(SOUND_PROP, ""))
	if kind == SOUND_TONE:
		return tone_name(m.duration)
	if kind == SOUND_POP:
		return pop_name(m.duration, float(m.props.get(POP_AT_PROP, 0.0)), frame_of(m))
	return ""


static func samples_for(m: MediaItem) -> PackedFloat32Array:
	var kind: String = String(m.props.get(SOUND_PROP, ""))
	var n: int = maxi(int(round(m.duration * float(RATE))), 1)
	if kind == SOUND_TONE:
		return sine(n, 0, n)
	var start: int = int(round(float(m.props.get(POP_AT_PROP, 0.0)) * float(RATE)))
	var count: int = int(round(frame_of(m) * float(RATE)))
	return sine(n, start, count)


static func sine(total: int, start: int, count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var a: float = amplitude(TONE_DB)
	var ramp: int = maxi(int(RAMP_SECONDS * float(RATE)), 1)
	var lo: int = clampi(start, 0, total)
	var hi: int = clampi(start + count, 0, total)
	var whole: bool = lo == 0 and hi == total
	for i: int in range(lo, hi):
		var k: float = 1.0
		if not whole:
			k = clampf(float(mini(i - lo, hi - 1 - i)) / float(ramp), 0.0, 1.0)
		out[i] = a * k * sin(TAU * TONE_HZ * float(i) / float(RATE))
	return out


static func wav_bytes(samples: PackedFloat32Array) -> PackedByteArray:
	var frames: int = samples.size()
	var data_size: int = frames * CHANNELS * 2
	var out: PackedByteArray = PackedByteArray()
	out.resize(44 + data_size)
	out.encode_u32(0, 0x46464952)
	out.encode_u32(4, 36 + data_size)
	out.encode_u32(8, 0x45564157)
	out.encode_u32(12, 0x20746d66)
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, CHANNELS)
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * CHANNELS * 2)
	out.encode_u16(32, CHANNELS * 2)
	out.encode_u16(34, 16)
	out.encode_u32(36, 0x61746164)
	out.encode_u32(40, data_size)
	var at: int = 44
	for i: int in frames:
		var v: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		for ch: int in CHANNELS:
			out.encode_s16(at, v)
			at += 2
	return out


static func write_for(m: MediaItem, dir: String = "") -> String:
	var name: String = file_name_for(m)
	if name.is_empty():
		return ""
	var where: String = dir if not dir.is_empty() else folder()
	var path: String = where.path_join(name)
	if FileAccess.file_exists(path):
		return path
	DirAccess.make_dir_recursive_absolute(where)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(wav_bytes(samples_for(m)))
	f.close()
	return path


static func has_sound(m: MediaItem) -> bool:
	return m != null and m.kind == "generator" and not String(m.props.get(SOUND_PROP, "")).is_empty()


static func stamp(md: Dictionary, dir: String = "") -> Dictionary:
	var m: MediaItem = MediaItem.from_dict(md)
	if not has_sound(m):
		return md
	var path: String = write_for(m, dir)
	if path.is_empty():
		return md
	md["path"] = path
	md["has_audio"] = true
	md["audio_streams"] = [{"index": 0, "channels": CHANNELS, "sample_rate": RATE, "lang": "", "title": "", "selected": true}]
	return md


static func heal(items: Array) -> int:
	var fixed: int = 0
	for v: Variant in items:
		var m: MediaItem = v as MediaItem
		if not has_sound(m):
			continue
		if not m.path.is_empty() and FileAccess.file_exists(m.path) and m.path.get_file() == file_name_for(m):
			continue
		var path: String = write_for(m)
		if path.is_empty():
			continue
		m.path = path
		m.missing = false
		fixed += 1
	return fixed
