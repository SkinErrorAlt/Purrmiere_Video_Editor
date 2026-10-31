extends RefCounted

const MarkerLayers := preload("res://doc/marker_layers.gd")
const MarkerTags := preload("res://doc/marker_tags.gd")
const Presets := preload("res://doc/presets.gd")
const Sequence := preload("res://doc/sequence.gd")
const Marker := preload("res://doc/marker.gd")
const Timecode := preload("res://doc/timecode.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const PRESET_KIND := "export"
const LADDER: Array[int] = [1080, 900, 720, 540, 480, 360, 240]
const SIZE_PRESETS: Array = [
	["sequence", "Same as sequence", 0, 0],
	["2160p", "3840 x 2160 (4K)", 3840, 2160],
	["1440p", "2560 x 1440", 2560, 1440],
	["1080p", "1920 x 1080", 1920, 1080],
	["720p", "1280 x 720", 1280, 720],
	["540p", "960 x 540", 960, 540],
	["480p", "854 x 480", 854, 480],
	["360p", "640 x 360", 640, 360],
	["vertical_1080", "1080 x 1920 (vertical)", 1080, 1920],
	["square_1080", "1080 x 1080 (square)", 1080, 1080],
	["custom", "Custom", 0, 0],
]
const FPS_PRESETS: Array = [
	["sequence", "Same as sequence", 0.0],
	["60", "60", 60.0],
	["30", "30", 30.0],
	["24", "24", 24.0],
	["23.976", "23.976", 23.976],
	["15", "15", 15.0],
	["12", "12", 12.0],
	["custom", "Custom", 0.0],
]
const PREFER_CHOICES: Array = [["quality", "Quality"], ["fps", "Frame rate"], ["balanced", "Balanced"]]
const RANGE_CHOICES: Array = [["sequence", "Whole sequence"], ["in_out", "In to out"], ["work_area", "Work area"], ["parts", "Parts I picked"], ["tags", "Tags"]]
const RANGE_PARTS := "parts"
const RANGE_TAGS := "tags"
const TAGS_KEY := "tags"
const TAG_STITCHED := "stitched"
const TAG_SECTIONS := "sections"
const TAG_MODE_CHOICES: Array = [["stitched", "Stitched into one file"], ["sections", "One file per tagged range"]]
const RATE_CHOICES: Array = [["crf", "Quality (CRF)"], ["bitrate", "Bitrate"], ["size", "Target size"]]
const THUMB_CHOICES: Array = [["poster", "Poster frame"], ["playhead", "Playhead frame"], ["pick", "Pick a frame"]]
const AUDIO_RATES: Array[int] = [44100, 48000, 96000]
const AUDIO_BITRATES: Array[int] = [64, 96, 128, 160, 192, 256, 320]
const CONTAINER_FALLBACK: Array = [
	{"id": "mp4", "label": "MP4", "ext": "mp4", "video_codecs": ["libx264", "openh264", "libx265"], "audio_codecs": ["aac", "libmp3lame"]},
	{"id": "mov", "label": "MOV", "ext": "mov", "video_codecs": ["prores_ks", "libx264", "dnxhd"], "audio_codecs": ["aac", "pcm_s16le"]},
	{"id": "mkv", "label": "MKV", "ext": "mkv", "video_codecs": ["libx264", "ffv1", "libvpx-vp9", "libsvtav1", "png"], "audio_codecs": ["aac", "libopus", "flac"]},
	{"id": "webm", "label": "WebM", "ext": "webm", "video_codecs": ["libvpx-vp9", "libvpx"], "audio_codecs": ["libopus", "libvorbis"]},
	{"id": "gif", "label": "GIF", "ext": "gif", "video_codecs": ["gif"], "audio_codecs": []},
	{"id": "png_sequence", "label": "PNG sequence", "ext": "png", "video_codecs": ["png"], "audio_codecs": []},
	{"id": "jpg_sequence", "label": "JPG sequence", "ext": "jpg", "video_codecs": ["mjpeg"], "audio_codecs": []},
	{"id": "wav", "label": "WAV (audio only)", "ext": "wav", "video_codecs": [], "audio_codecs": ["pcm_s16le"], "audio_only": true},
	{"id": "mp3", "label": "MP3 (audio only)", "ext": "mp3", "video_codecs": [], "audio_codecs": ["libmp3lame"], "audio_only": true},
	{"id": "flac", "label": "FLAC (audio only)", "ext": "flac", "video_codecs": [], "audio_codecs": ["flac"], "audio_only": true},
]
const ALPHA_FORMATS: Array = [
	["png_sequence", "png", "PNG sequence"],
	["mov", "prores_ks", "MOV ProRes 4444"],
	["mov", "prores", "MOV ProRes 4444"],
	["mov", "png", "MOV PNG"],
	["mkv", "png", "MKV PNG"],
	["webm", "libvpx-vp9", "WebM VP9"],
	["mkv", "libvpx-vp9", "MKV VP9"],
	["mkv", "ffv1", "MKV FFV1"],
	["mov", "ffv1", "MOV FFV1"],
	["gif", "gif", "GIF"],
]
const ALPHA_FORMAT_NAMES := "PNG sequence, MOV ProRes 4444, MOV PNG, WebM VP9, MKV FFV1 or GIF"
const YOUTUBE_MIN_CHAPTERS := 3
const YOUTUBE_MIN_GAP := 10.0
const ENCODER_FALLBACK: Array = [
	{"id": "libx264", "label": "H.264 (x264)", "codec": "h264", "hw": false, "containers": ["mp4", "mov", "mkv"]},
	{"id": "openh264", "label": "H.264 (OpenH264)", "codec": "h264", "hw": false, "containers": ["mp4", "mov", "mkv"]},
	{"id": "libx265", "label": "HEVC (x265)", "codec": "hevc", "hw": false, "containers": ["mp4", "mov", "mkv"]},
	{"id": "prores_ks", "label": "ProRes", "codec": "prores", "hw": false, "containers": ["mov"]},
	{"id": "dnxhd", "label": "DNxHD", "codec": "dnxhd", "hw": false, "containers": ["mov"]},
	{"id": "ffv1", "label": "FFV1", "codec": "ffv1", "hw": false, "containers": ["mkv"]},
	{"id": "libvpx-vp9", "label": "VP9", "codec": "vp9", "hw": false, "containers": ["webm", "mkv"]},
	{"id": "libvpx", "label": "VP8", "codec": "vp8", "hw": false, "containers": ["webm"]},
	{"id": "libsvtav1", "label": "AV1 (SVT)", "codec": "av1", "hw": false, "containers": ["mkv"]},
	{"id": "gif", "label": "GIF", "codec": "gif", "hw": false, "containers": ["gif"]},
	{"id": "png", "label": "PNG", "codec": "png", "hw": false, "containers": ["png_sequence", "mkv"]},
	{"id": "mjpeg", "label": "JPEG", "codec": "mjpeg", "hw": false, "containers": ["jpg_sequence"]},
]


static func default_settings() -> Dictionary:
	return {
		"range": "sequence",
		"container": "mp4",
		"video_codec": "libx264",
		"size": {"preset": "sequence", "width": 1920, "height": 1080, "lock_aspect": true},
		"fps": {"mode": "sequence", "custom": 30.0},
		"rate_control": {"mode": "crf", "crf": 18, "bitrate_kbps": 12000, "max_kbps": 0, "target_mb": 10.0, "prefer": "quality"},
		"pix_fmt": "yuv420p",
		"audio": {"enabled": true, "codec": "aac", "bitrate_kbps": 192, "sample_rate": 48000, "channels": 2, "layout": "mix", "groups": ""},
		"thumbnail": {"source": "poster", "time": 0.0, "embed": true, "sidecar": false},
		"metadata": {"title": "", "comment": ""},
		"chapters_from_markers": true,
		"interpolation": false,
		"transparent": false,
		"max_quality": false,
		"spans": [],
		"passes": [],
		"destination": {"dir": "", "name": ""},
	}


const LOSSLESS_VIDEO: PackedStringArray = ["ffv1", "png", "prores_ks", "libx264", "libx265", "libvpx-vp9"]
const LOSSLESS_AUDIO: PackedStringArray = ["flac", "pcm_s16le", "pcm_s24le"]
const CRF_LOSSLESS: PackedStringArray = ["libx264", "libx265", "libvpx-vp9"]
const ALWAYS_HIGH: PackedStringArray = ["ffv1", "png", "prores_ks", "dnxhd", "mjpeg"]
const BPP_FFV1 := 11.0
const BPP_PNG := 14.0
const BPP_PRORES := 4.0
const BPP_PRORES_4444 := 5.3
const ONE_TO_ONE: Array = [
	{
		"id": "lossless_ffv1",
		"label": "Lossless 1:1 (FFV1)",
		"encoder": "ffv1",
		"container": "mkv",
		"audio": "flac",
		"pix_fmt": "bgr0",
		"bpp": BPP_FFV1,
		"bit_exact": true,
		"what": "Every pixel exactly as the sequence shows it. FFV1 in MKV, written as 8 bit RGB, with the sound as FLAC. Nothing is resampled and nothing is thrown away, so there are no artifacts at all.",
		"plays_in": "Plays in VLC and MPV, and opens in Resolve, Premiere and Shotcut. It is not a format to upload or send straight to someone.",
	},
	{
		"id": "lossless_prores4444",
		"label": "Near lossless 1:1 (ProRes 4444)",
		"encoder": "prores_ks",
		"container": "mov",
		"audio": "pcm_s24le",
		"pix_fmt": "yuv444p10le",
		"bpp": BPP_PRORES_4444,
		"bit_exact": false,
		"what": "The sequence size and frame rate with no resampling, at ProRes 4444 with uncompressed sound. This is not bit for bit identical, it is 12 bit 4:4:4 and nothing visible survives a comparison, but it is about half the size of FFV1 and it carries alpha.",
		"plays_in": "Plays in QuickTime, VLC and MPV, and is the format most editors expect for a master.",
	},
]
const ARTIFACT_RISKS: Array = [
	["mkv", "png", "PNG inside MKV has a known fault: about one frame in sixty in roughly one export in fifty is written with a bad checksum and decodes as a repeat of the frame before it. Use Lossless 1:1 (FFV1) instead, which is the same quality and does not have the fault."],
]


static func tag_names(settings: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var t: Variant = settings.get(TAGS_KEY, {})
	if t is Dictionary:
		for n: Variant in (t as Dictionary).get("names", []):
			if not str(n).is_empty() and not out.has(str(n)):
				out.append(str(n))
	return out


static func tag_mode(settings: Dictionary) -> String:
	var t: Variant = settings.get(TAGS_KEY, {})
	var m: String = String((t as Dictionary).get("mode", TAG_STITCHED)) if t is Dictionary else TAG_STITCHED
	return m if m == TAG_SECTIONS else TAG_STITCHED


static func set_tags(settings: Dictionary, names: PackedStringArray, mode: String) -> void:
	settings[TAGS_KEY] = {"names": Array(names), "mode": TAG_SECTIONS if mode == TAG_SECTIONS else TAG_STITCHED}


static func tag_spans(settings: Dictionary, seq: Sequence) -> PackedVector2Array:
	return MarkerTags.spans(seq, tag_names(settings))


static func tag_sections(settings: Dictionary, seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if String(settings.get("range", "")) != RANGE_TAGS:
		return out
	var dest: Dictionary = settings.get("destination", {})
	var base: String = String(dest.get("name", "")).strip_edges()
	var used: Dictionary = {}
	for r: Dictionary in MarkerTags.ranges(seq, tag_names(settings)):
		var d: Dictionary = settings.duplicate(true)
		d["range"] = RANGE_PARTS
		d["spans"] = [{"from": float(r["from"]), "to": float(r["to"])}]
		var tag: String = (String(r["name"]) + " " + str(int(r["index"]))).validate_filename()
		var nm: String = (base + " " + tag).strip_edges() if not base.is_empty() else tag
		var wanted: String = nm
		var k: int = 2
		while used.has(nm.to_lower()):
			nm = wanted + " " + str(k)
			k += 1
		used[nm.to_lower()] = true
		var dd: Dictionary = d.get("destination", {})
		dd["name"] = nm
		d["destination"] = dd
		d["tag_section"] = {"name": String(r["name"]), "index": int(r["index"])}
		out.append(d)
	return out


static func tags_summary(settings: Dictionary, seq: Sequence) -> String:
	if seq == null:
		return "No sequence open"
	var all_names: PackedStringArray = MarkerTags.names(seq)
	if all_names.is_empty():
		return "No tags yet. Mark in and out, then right click the ruler and pick Tag this range, or Ctrl and drag across a marker lane."
	var picked: PackedStringArray = tag_names(settings)
	var list: Array[Dictionary] = MarkerTags.ranges(seq, picked)
	var fps: float = resolve_fps(settings, seq.fps)
	var which: String = "every tag" if picked.is_empty() else ", ".join(picked)
	var total: float = spans_seconds(MarkerTags.spans(seq, picked))
	var how: String = "stitched into one file" if tag_mode(settings) == TAG_STITCHED else "one file each"
	return str(list.size()) + (" range of " if list.size() == 1 else " ranges of ") + which + ", " + fmt_span(total, fps) + ", " + how


static func span_list(settings: Dictionary, seq: Sequence) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if String(settings.get("range", "sequence")) == RANGE_TAGS:
		out = tag_spans(settings, seq)
		if out.is_empty():
			out.append(Vector2(0.0, seq.duration() if seq != null else 0.0))
		return out
	var raw: Variant = settings.get("spans", [])
	var list: Array = raw if raw is Array else []
	var whole: Vector2 = Vector2(0.0, seq.duration() if seq != null else 0.0) if String(settings.get("range", "sequence")) == RANGE_PARTS else resolve_range(settings, seq)
	var made: Array[Vector2] = []
	for item: Variant in list:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var a: float = float(d.get("from", 0.0))
		var b: float = float(d.get("to", 0.0))
		if b <= a:
			continue
		a = maxf(a, 0.0)
		made.append(Vector2(a, b))
	if made.is_empty():
		out.append(whole)
		return out
	made.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	for v: Vector2 in made:
		var n: int = out.size()
		if n > 0 and v.x <= out[n - 1].y + 0.000001:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, v.y))
		else:
			out.append(v)
	return out


static func spans_chosen(settings: Dictionary, seq: Sequence = null) -> bool:
	if String(settings.get("range", "sequence")) == RANGE_TAGS:
		return seq == null or not tag_spans(settings, seq).is_empty()
	if String(settings.get("range", "sequence")) != RANGE_PARTS:
		return false
	var raw: Variant = settings.get("spans", [])
	return raw is Array and not (raw as Array).is_empty()


static func spans_held(settings: Dictionary) -> bool:
	var raw: Variant = settings.get("spans", [])
	return raw is Array and not (raw as Array).is_empty()


static func spans_seconds(spans: PackedVector2Array) -> float:
	var total: float = 0.0
	for v: Vector2 in spans:
		total += maxf(v.y - v.x, 0.0)
	return total


static func spans_frames(spans: PackedVector2Array, fps: float) -> int:
	if fps <= 0.0:
		return 0
	var total: int = 0
	for v: Vector2 in spans:
		total += int(round(maxf(v.y - v.x, 0.0) * fps))
	return total


static func span_frame_time(n: int, spans: PackedVector2Array, fps: float) -> float:
	if spans.is_empty() or fps <= 0.0:
		return 0.0
	var left: int = maxi(n, 0)
	for v: Vector2 in spans:
		var count: int = int(round(maxf(v.y - v.x, 0.0) * fps))
		if left < count:
			return v.x + float(left) / fps
		left -= count
	var last: Vector2 = spans[spans.size() - 1]
	return maxf(last.y - 1.0 / fps, last.x)


static func parts_summary(settings: Dictionary, seq: Sequence) -> String:
	if seq == null:
		return "No sequence open"
	if not spans_held(settings):
		return "Nothing picked yet. Drag across the ruler to pick a part."
	var picked: PackedVector2Array = span_list(settings, seq)
	var fps: float = resolve_fps(settings, seq.fps)
	var chosen: float = spans_seconds(picked)
	var whole: float = maxf(seq.duration(), 0.0)
	var word: String = "part" if picked.size() == 1 else "parts"
	var text: String = str(picked.size()) + " " + word + ", " + fmt_span(chosen, fps)
	if whole > 0.0:
		text += " of " + fmt_span(whole, fps)
	if not spans_chosen(settings):
		text += ". Set Range to Parts I picked to use them."
	return text


static func pass_summary(settings: Dictionary, one: Dictionary, seq: Sequence) -> String:
	var sp: Array = one.get("spans", [])
	var over: Dictionary = one.get("settings", {}) if one.get("settings") is Dictionary else {}
	var bits: PackedStringArray = PackedStringArray()
	if sp.is_empty():
		bits.append("the parts picked above")
	else:
		var holder: Dictionary = {"range": RANGE_PARTS, "spans": sp}
		var picked: PackedVector2Array = span_list(holder, seq)
		var fps: float = resolve_fps(settings, seq.fps) if seq != null else 30.0
		bits.append(str(picked.size()) + (" part" if picked.size() == 1 else " parts") + ", " + fmt_span(spans_seconds(picked), fps))
	if over.is_empty():
		bits.append("as above")
	else:
		var names: PackedStringArray = PackedStringArray()
		for k: Variant in over.keys():
			names.append(String(k).replace("_", " "))
		names.sort()
		bits.append("own " + ", ".join(names))
	return ", ".join(bits)


static func pass_list(settings: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = settings.get("passes", [])
	var list: Array = raw if raw is Array else []
	for i: int in list.size():
		if not (list[i] is Dictionary):
			continue
		var d: Dictionary = list[i]
		var name_: String = String(d.get("name", ""))
		if name_.is_empty():
			name_ = "Pass " + str(i + 1)
		var over: Variant = d.get("settings", {})
		out.append({
			"index": i + 1,
			"name": name_,
			"spans": (d.get("spans", []) as Array).duplicate(true) if d.get("spans") is Array else [],
			"settings": (over as Dictionary).duplicate(true) if over is Dictionary else {},
		})
	return out


static func settings_for_pass(settings: Dictionary, one: Dictionary) -> Dictionary:
	var out: Dictionary = merge(settings, one.get("settings", {}))
	out["passes"] = []
	var sp: Array = one.get("spans", [])
	if not sp.is_empty():
		out["spans"] = sp.duplicate(true)
	var dest: Dictionary = out.get("destination", {})
	var base: String = String(dest.get("name", ""))
	var tag: String = String(one.get("name", "")).validate_filename()
	if not tag.is_empty():
		dest["name"] = (base + " " + tag).strip_edges() if not base.is_empty() else tag
		out["destination"] = dest
	return out


static func max_quality_on(settings: Dictionary) -> bool:
	return bool(settings.get("max_quality", false))


static func lossless_video_for(container: Dictionary, current: String) -> String:
	var allowed: Array = container.get("video_codecs", [])
	if current in ALWAYS_HIGH or current in CRF_LOSSLESS:
		return current
	for id: String in LOSSLESS_VIDEO:
		if allowed.has(id):
			return id
	return current


static func lossless_audio_for(container: Dictionary, current: String) -> String:
	var allowed: Array = container.get("audio_codecs", [])
	if current in LOSSLESS_AUDIO:
		return current
	for id: String in LOSSLESS_AUDIO:
		if allowed.has(id):
			return id
	return current


static func effective(settings: Dictionary, containers: Array[Dictionary]) -> Dictionary:
	if not max_quality_on(settings):
		return settings
	var out: Dictionary = settings.duplicate(true)
	var container: Dictionary = container_by_id(containers, String(out.get("container", "mp4")))
	out["size"] = {"preset": "sequence", "width": 0, "height": 0, "lock_aspect": true}
	out["fps"] = {"mode": "sequence", "custom": 30.0}
	var vc: String = lossless_video_for(container, String(out.get("video_codec", "")))
	out["video_codec"] = vc
	var rc: Dictionary = out.get("rate_control", {})
	rc["mode"] = "crf"
	rc["crf"] = 0
	out["rate_control"] = rc
	var audio: Dictionary = out.get("audio", {})
	if bool(audio.get("enabled", true)):
		audio["codec"] = lossless_audio_for(container, String(audio.get("codec", "")))
		audio["bitrate_kbps"] = 0 if String(audio["codec"]) in LOSSLESS_AUDIO else int(audio.get("bitrate_kbps", 192))
		out["audio"] = audio
	return out


static func max_quality_note(settings: Dictionary, containers: Array[Dictionary]) -> String:
	if not max_quality_on(settings):
		return ""
	var container: Dictionary = container_by_id(containers, String(settings.get("container", "mp4")))
	var eff: Dictionary = effective(settings, containers)
	var vc: String = String(eff.get("video_codec", ""))
	var parts: PackedStringArray = PackedStringArray()
	parts.append("the sequence size and frame rate, nothing resampled")
	if vc in CRF_LOSSLESS:
		parts.append(vc + " at CRF 0, which is lossless")
	elif vc in ALWAYS_HIGH:
		parts.append(vc + ", which keeps its own high quality")
	elif is_audio_only(container):
		parts.append("audio only")
	else:
		return "Max quality is on, but " + vc + " in " + String(container.get("label", "this format")) + " cannot be lossless. Pick MKV with FFV1, MOV with ProRes, or a PNG sequence for a true untouched export."
	var ac: String = String((eff.get("audio", {}) as Dictionary).get("codec", ""))
	if not ac.is_empty() and ac in LOSSLESS_AUDIO:
		parts.append("sound as " + ac + ", uncompressed")
	return "Max quality: " + ", ".join(parts) + "."


static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over.keys():
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = merge(out[k], over[k])
		else:
			out[k] = over[k] if not (over[k] is Dictionary or over[k] is Array) else (over[k] as Variant).duplicate(true)
	return out


static func normalise(raw: Dictionary) -> Dictionary:
	return merge(default_settings(), raw)


static func destinations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"id": "youtube", "label": "YouTube", "settings": {"container": "mp4", "video_codec": "libx264", "size": {"preset": "1080p", "width": 1920, "height": 1080}, "rate_control": {"mode": "bitrate", "bitrate_kbps": 16000, "max_kbps": 20000}, "audio": {"enabled": true, "codec": "aac", "bitrate_kbps": 192, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "discord", "label": "Discord 10 MB", "settings": {"container": "mp4", "video_codec": "libx264", "rate_control": {"mode": "size", "target_mb": 10.0, "prefer": "quality"}, "audio": {"enabled": true, "codec": "aac", "bitrate_kbps": 96, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "phone", "label": "Phone 720p", "settings": {"container": "mp4", "video_codec": "libx264", "size": {"preset": "720p", "width": 1280, "height": 720}, "rate_control": {"mode": "crf", "crf": 23}, "audio": {"enabled": true, "codec": "aac", "bitrate_kbps": 128, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "archive_prores", "label": "Archive ProRes", "settings": {"container": "mov", "video_codec": "prores_ks", "rate_control": {"mode": "crf", "crf": 0}, "audio": {"enabled": true, "codec": "pcm_s16le", "bitrate_kbps": 0, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "archive_ffv1", "label": "Archive FFV1", "settings": {"container": "mkv", "video_codec": "ffv1", "rate_control": {"mode": "crf", "crf": 0}, "audio": {"enabled": true, "codec": "flac", "bitrate_kbps": 0, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "gif", "label": "GIF", "settings": {"container": "gif", "video_codec": "gif", "size": {"preset": "480p", "width": 854, "height": 480}, "fps": {"mode": "15", "custom": 15.0}, "audio": {"enabled": false}}})
	out.append({"id": "png_sequence", "label": "PNG sequence", "settings": {"container": "png_sequence", "video_codec": "png", "audio": {"enabled": false}}})
	out.append({"id": "audio_wav", "label": "Audio only WAV", "settings": {"container": "wav", "video_codec": "", "audio": {"enabled": true, "codec": "pcm_s16le", "bitrate_kbps": 0, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "audio_mp3", "label": "Audio only MP3", "settings": {"container": "mp3", "video_codec": "", "audio": {"enabled": true, "codec": "libmp3lame", "bitrate_kbps": 192, "sample_rate": 48000, "channels": 2}}})
	out.append({"id": "audio_flac", "label": "Audio only FLAC", "settings": {"container": "flac", "video_codec": "", "audio": {"enabled": true, "codec": "flac", "bitrate_kbps": 0, "sample_rate": 48000, "channels": 2}}})
	return out


static func destination_by_id(id: String) -> Dictionary:
	for d: Dictionary in destinations():
		if String(d["id"]) == id:
			return d
	return {}


static func apply_destination(settings: Dictionary, id: String) -> Dictionary:
	var d: Dictionary = destination_by_id(id)
	if d.is_empty():
		return settings.duplicate(true)
	return merge(settings, d["settings"])


static func one_to_one_spec(id: String) -> Dictionary:
	for spec: Dictionary in ONE_TO_ONE:
		if String(spec["id"]) == id:
			return spec
	return {}


static func one_to_one_settings(spec: Dictionary, containers: Array[Dictionary]) -> Dictionary:
	var container: Dictionary = container_by_id(containers, String(spec["container"]))
	return {
		"container": String(spec["container"]),
		"video_codec": String(spec["encoder"]),
		"size": {"preset": "sequence", "width": 0, "height": 0, "lock_aspect": true},
		"fps": {"mode": "sequence", "custom": 30.0},
		"rate_control": {"mode": "crf", "crf": 0, "bitrate_kbps": 0, "max_kbps": 0, "target_mb": 0.0, "prefer": "quality"},
		"pix_fmt": String(spec["pix_fmt"]),
		"interpolation": false,
		"max_quality": true,
		"audio": {"enabled": true, "codec": lossless_audio_for(container, String(spec["audio"])), "bitrate_kbps": 0, "sample_rate": 48000, "channels": 2},
	}


static func lossless_presets(encoders: Array[Dictionary], containers: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec: Dictionary in ONE_TO_ONE:
		var container: Dictionary = container_by_id(containers, String(spec["container"]))
		if container.is_empty():
			continue
		var vc: String = String(spec["encoder"])
		if encoder_by_id(encoders, vc).is_empty():
			continue
		if not (container.get("video_codecs", []) as Array).has(vc):
			continue
		out.append({
			"id": String(spec["id"]),
			"label": String(spec["label"]),
			"bit_exact": bool(spec["bit_exact"]),
			"settings": one_to_one_settings(spec, containers),
		})
	return out


static func apply_lossless(settings: Dictionary, id: String, containers: Array[Dictionary]) -> Dictionary:
	var spec: Dictionary = one_to_one_spec(id)
	if spec.is_empty():
		return settings.duplicate(true)
	return merge(settings, one_to_one_settings(spec, containers))


static func lossless_note(id: String, width: int, height: int, fps: float, seconds: float) -> String:
	var spec: Dictionary = one_to_one_spec(id)
	if spec.is_empty():
		return ""
	var bits: PackedStringArray = PackedStringArray()
	bits.append(String(spec["what"]))
	bits.append(String(spec["plays_in"]))
	bits.append(lossless_size_line(float(spec["bpp"]), width, height, fps, seconds))
	return " ".join(bits)


static func lossless_size_line(bpp: float, width: int, height: int, fps: float, seconds: float) -> String:
	if width <= 0 or height <= 0 or fps <= 0.0:
		return "Size depends on the sequence."
	var kbps: float = bpp * float(width) * float(height) * fps / 1000.0
	var per_minute_mb: float = kbps * 1000.0 * 60.0 / 8.0 / (1024.0 * 1024.0)
	var line: String = "Expect about " + fmt_mb(per_minute_mb) + " a minute at " + str(height) + "p" + fmt_fps(fps) + "."
	if seconds > 0.0:
		line += " This export is about " + fmt_mb(kbps * 1000.0 * seconds / 8.0 / (1024.0 * 1024.0)) + "."
	return line


static func artifact_risk(container_id: String, codec_id: String) -> String:
	for row: Array in ARTIFACT_RISKS:
		if String(row[0]) == container_id and String(row[1]) == codec_id:
			return String(row[2])
	return ""


static func is_one_to_one(settings: Dictionary) -> bool:
	var size: Dictionary = settings.get("size", {})
	var fps_d: Dictionary = settings.get("fps", {})
	if String(size.get("preset", "")) != "sequence" or String(fps_d.get("mode", "")) != "sequence":
		return false
	if bool(settings.get("interpolation", false)):
		return false
	var codec: String = String(settings.get("video_codec", ""))
	var spec: Dictionary = {}
	for s: Dictionary in ONE_TO_ONE:
		if String(s["encoder"]) == codec and String(s["container"]) == String(settings.get("container", "")):
			spec = s
	if spec.is_empty():
		return false
	if not artifact_risk(String(settings.get("container", "")), codec).is_empty():
		return false
	var audio: Dictionary = settings.get("audio", {})
	if bool(audio.get("enabled", true)) and not (String(audio.get("codec", "")) in LOSSLESS_AUDIO):
		return false
	return int((settings.get("rate_control", {}) as Dictionary).get("crf", 18)) == 0


static func make_preset(label: String, settings: Dictionary) -> Dictionary:
	return Presets.make(PRESET_KIND, label, {"settings": settings.duplicate(true)})


static func settings_of(preset: Dictionary) -> Dictionary:
	var payload: Dictionary = preset.get("payload", {})
	if payload.get("settings") is Dictionary:
		return normalise(payload["settings"])
	return default_settings()


static func save_user_preset(label: String, settings: Dictionary) -> bool:
	return Presets.save_to_user(make_preset(label, settings))


static func list_user_presets() -> Array[Dictionary]:
	return Presets.list_user(PRESET_KIND)


static func containers_available(bridge: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bridge != null and bool(bridge.get("available")):
		out = bridge.call("containers")
	if out.is_empty():
		for c: Dictionary in CONTAINER_FALLBACK:
			out.append(c.duplicate(true))
	return out


static func encoders_available(bridge: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bridge != null and bool(bridge.get("available")):
		out = bridge.call("encoders")
	if out.is_empty():
		for e: Dictionary in ENCODER_FALLBACK:
			out.append(e.duplicate(true))
	return out


static func container_by_id(containers: Array[Dictionary], id: String) -> Dictionary:
	for c: Dictionary in containers:
		if String(c.get("id", "")) == id:
			return c
	return {}


static func encoders_for_container(encoders: Array[Dictionary], container: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var allowed: Array = container.get("video_codecs", [])
	for e: Dictionary in encoders:
		var id: String = String(e.get("id", ""))
		if allowed.has(id):
			out.append(e)
	return out


static func codec_family_of(encoders: Array[Dictionary], id: String) -> String:
	for e: Dictionary in encoders:
		if String(e.get("id", "")) == id:
			return String(e.get("codec", ""))
	for e: Variant in ENCODER_FALLBACK:
		var d: Dictionary = e
		if String(d.get("id", "")) == id:
			return String(d.get("codec", ""))
	return ""


static func nearest_encoder(encoders: Array[Dictionary], allowed: Array[Dictionary], requested: String) -> String:
	if allowed.is_empty():
		return ""
	var family: String = codec_family_of(encoders, requested)
	if family != "":
		var hw_match: String = ""
		for e: Dictionary in allowed:
			if String(e.get("codec", "")) != family:
				continue
			if not bool(e.get("hw", false)):
				return String(e.get("id", ""))
			if hw_match == "":
				hw_match = String(e.get("id", ""))
		if hw_match != "":
			return hw_match
	return String(allowed[0].get("id", ""))


static func encoder_by_id(encoders: Array[Dictionary], id: String) -> Dictionary:
	for e: Dictionary in encoders:
		if String(e.get("id", "")) == id:
			return e
	return {}


static func codec_of(encoders: Array[Dictionary], id: String) -> String:
	var e: Dictionary = encoder_by_id(encoders, id)
	return String(e.get("codec", ""))


static func is_audio_only(container: Dictionary) -> bool:
	return bool(container.get("audio_only", false)) or (container.get("video_codecs", []) as Array).is_empty()


static func is_sequence_container(container_id: String) -> bool:
	return container_id.ends_with("_sequence")


static func even_dim(v: float) -> int:
	var i: int = int(round(v))
	if i < 2:
		i = 2
	return i - (i % 2)


static func ladder_step_below(height: int) -> int:
	for h: int in LADDER:
		if h < height:
			return h
	return 0


static func bits_per_pixel_floor(codec: String) -> float:
	if codec == "prores" or codec == "dnxhd":
		return 0.5
	return 0.05


static func fps_fraction(fps: float) -> Vector2i:
	if absf(fps - 23.976) < 0.002 or absf(fps - 24000.0 / 1001.0) < 0.002:
		return Vector2i(24000, 1001)
	if absf(fps - 29.97) < 0.002 or absf(fps - 30000.0 / 1001.0) < 0.002:
		return Vector2i(30000, 1001)
	if absf(fps - 59.94) < 0.002 or absf(fps - 60000.0 / 1001.0) < 0.002:
		return Vector2i(60000, 1001)
	if is_equal_approx(fps, round(fps)):
		return Vector2i(int(round(fps)), 1)
	return Vector2i(int(round(fps * 1000.0)), 1000)


static func resolve_fps(settings: Dictionary, seq_fps: float) -> float:
	var f: Dictionary = settings.get("fps", {})
	var mode: String = String(f.get("mode", "sequence"))
	if mode == "sequence":
		return seq_fps
	if mode == "custom":
		return maxf(float(f.get("custom", seq_fps)), 1.0)
	for p: Array in FPS_PRESETS:
		if String(p[0]) == mode:
			return float(p[2])
	return seq_fps


static func resolve_size(settings: Dictionary, seq_w: int, seq_h: int) -> Vector2i:
	var s: Dictionary = settings.get("size", {})
	var preset: String = String(s.get("preset", "sequence"))
	if preset == "sequence":
		return Vector2i(even_dim(float(seq_w)), even_dim(float(seq_h)))
	if preset == "custom":
		return Vector2i(even_dim(float(s.get("width", seq_w))), even_dim(float(s.get("height", seq_h))))
	for p: Array in SIZE_PRESETS:
		if String(p[0]) == preset:
			return Vector2i(int(p[2]), int(p[3]))
	return Vector2i(even_dim(float(seq_w)), even_dim(float(seq_h)))


static func resolve_range(settings: Dictionary, seq: Sequence) -> Vector2:
	var mode: String = String(settings.get("range", "sequence"))
	var dur: float = seq.duration() if seq != null else 0.0
	if mode == RANGE_PARTS:
		var picked: PackedVector2Array = span_list(settings, seq)
		if picked.size() > 0 and spans_held(settings):
			return Vector2(picked[0].x, picked[picked.size() - 1].y)
		return Vector2(0.0, dur)
	if mode == RANGE_TAGS:
		var tagged: PackedVector2Array = tag_spans(settings, seq)
		if not tagged.is_empty():
			return Vector2(tagged[0].x, tagged[tagged.size() - 1].y)
		return Vector2(0.0, dur)
	if seq != null and mode == "in_out" and seq.in_point >= 0.0 and seq.out_point > seq.in_point:
		return Vector2(seq.in_point, seq.out_point)
	if seq != null and mode == "work_area" and seq.in_point >= 0.0 and seq.out_point > seq.in_point:
		return Vector2(seq.in_point, seq.out_point)
	return Vector2(0.0, dur)


static func plan_size(codec: String, width: int, height: int, fps: float, total_frames: int, target_mb: float, audio_kbps: int, prefer: String) -> Dictionary:
	var p: Dictionary = {"applies": false, "ignored": false, "video_kbps": 0, "out_width": width, "out_height": height, "fps_divisor": 1, "out_fps": fps, "bits_per_pixel": 0.0, "floor": bits_per_pixel_floor(codec), "ladder_step": height, "ladder_drops": 0, "fps_halvings": 0, "duration": 0.0, "message": ""}
	if target_mb <= 0.0 or fps <= 0.0 or width <= 0 or height <= 0:
		p["message"] = "size target not applied: target, size or frame rate missing"
		return p
	if codec == "prores" or codec == "dnxhd":
		p["ignored"] = true
		p["message"] = "size target ignored: " + codec + " keeps its own quality (bits per pixel floor " + String.num(float(p["floor"]), 1) + ")"
		return p
	p["applies"] = true
	var duration: float = float(total_frames) / fps if total_frames > 0 else 0.0
	if duration <= 0.0:
		duration = 1.0 / fps
	p["duration"] = duration
	var budget_bytes: float = maxf(target_mb * 1024.0 * 1024.0 - (32768.0 + 32.0 * float(total_frames)), 1024.0)
	var total_bits: float = budget_bytes * 8.0 * 0.95
	var video_bps: float = total_bits / duration - float(audio_kbps) * 1000.0
	var note: String = ""
	if video_bps < 50000.0:
		video_bps = 50000.0
		note = "; the audio alone nearly fills the target, video held at 50 kbps"
	p["video_kbps"] = int(round(video_bps / 1000.0))
	var out_w: int = width
	var out_h: int = height
	var out_fps: float = fps
	var floor_v: float = float(p["floor"])
	var guard: int = 0
	var next_is_res: bool = true
	var drops: int = 0
	var halvings: int = 0
	var divisor: int = 1
	var ladder_step: int = height
	while video_bps / (float(out_w) * float(out_h) * out_fps) < floor_v and guard < 32:
		guard += 1
		var moved: bool = false
		var want_res_first: bool = true
		if prefer == "fps":
			want_res_first = false
		elif prefer == "balanced":
			want_res_first = next_is_res
			next_is_res = not next_is_res
		for attempt: int in 2:
			var try_res: bool = want_res_first == (attempt == 0)
			if try_res:
				var step: int = ladder_step_below(out_h)
				if step > 0:
					var scale: float = float(step) / float(height)
					out_h = step
					out_w = even_dim(float(width) * scale)
					ladder_step = step
					drops += 1
					moved = true
			else:
				if out_fps / 2.0 >= 15.0:
					out_fps /= 2.0
					divisor *= 2
					halvings += 1
					moved = true
			if moved:
				break
		if not moved:
			break
	p["out_width"] = out_w
	p["out_height"] = out_h
	p["out_fps"] = out_fps
	p["fps_divisor"] = divisor
	p["ladder_step"] = ladder_step
	p["ladder_drops"] = drops
	p["fps_halvings"] = halvings
	p["bits_per_pixel"] = video_bps / (float(out_w) * float(out_h) * out_fps)
	var ladder: String = "ladder step " + str(ladder_step) + "p (kept)" if drops == 0 else "ladder step " + str(ladder_step) + "p (down " + str(drops) + (" step from " if drops == 1 else " steps from ") + str(height) + "p)"
	var fps_text: String = "fps " + fmt_fps(out_fps) + " (kept)" if halvings == 0 else "fps " + fmt_fps(out_fps) + " (halved from " + fmt_fps(fps) + ")"
	var floor_note: String = ", still under the floor so quality will be low" if float(p["bits_per_pixel"]) < floor_v else ""
	p["message"] = "size target " + String.num(target_mb, 2) + " MB for " + String.num(duration, 1) + " s with prefer " + prefer + ": video " + str(int(p["video_kbps"])) + " kbps, audio " + str(audio_kbps) + " kbps, " + ladder + ", " + fps_text + ", bits per pixel " + String.num(float(p["bits_per_pixel"]), 3) + " against floor " + String.num(floor_v, 3) + floor_note + note
	return p


static func fmt_fps(fps: float) -> String:
	if is_equal_approx(fps, round(fps)):
		return str(int(round(fps)))
	return String.num(fps, 3).rstrip("0").rstrip(".")


static func crf_kbps(codec: String, width: int, height: int, fps: float, crf: int) -> float:
	var base_bpp: float = 0.09
	if codec == "hevc" or codec == "vp9" or codec == "av1":
		base_bpp = 0.06
	elif codec == "prores":
		return BPP_PRORES * float(width) * float(height) * fps / 1000.0
	elif codec == "dnxhd":
		return 0.5 * float(width) * float(height) * fps / 1000.0
	elif codec == "ffv1":
		return BPP_FFV1 * float(width) * float(height) * fps / 1000.0
	elif codec == "png":
		return BPP_PNG * float(width) * float(height) * fps / 1000.0
	elif codec == "gif":
		return 0.6 * float(width) * float(height) * fps / 1000.0
	elif codec == "mjpeg":
		return 1.2 * float(width) * float(height) * fps / 1000.0
	var bpp: float = base_bpp * pow(2.0, (23.0 - float(clampi(crf, 0, 51))) / 6.0)
	return bpp * float(width) * float(height) * fps / 1000.0


static func estimate(settings: Dictionary, seq: Sequence, encoders: Array[Dictionary], containers: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {"text": "", "video_kbps": 0.0, "audio_kbps": 0, "width": 0, "height": 0, "fps": 0.0, "duration": 0.0, "size_mb": 0.0, "plan": {}, "audio_only": false, "warning": ""}
	if seq == null:
		out["text"] = "No sequence open"
		return out
	settings = effective(settings, containers)
	var range_v: Vector2 = resolve_range(settings, seq)
	var duration: float = maxf(range_v.y - range_v.x, 0.0)
	var chosen: PackedVector2Array = span_list(settings, seq) if spans_chosen(settings) else PackedVector2Array()
	if not chosen.is_empty():
		duration = spans_seconds(chosen)
	var container: Dictionary = container_by_id(containers, String(settings.get("container", "mp4")))
	var audio_only: bool = not container.is_empty() and is_audio_only(container)
	var size: Vector2i = resolve_size(settings, seq.width, seq.height)
	var fps: float = resolve_fps(settings, seq.fps)
	var total_frames: int = int(round(duration * fps))
	var audio: Dictionary = settings.get("audio", {})
	var audio_on: bool = bool(audio.get("enabled", true)) and not (container.get("audio_codecs", []) as Array).is_empty()
	var audio_kbps: int = audio_kbps_of(String(audio.get("codec", "")), int(audio.get("bitrate_kbps", 0)), int(audio.get("sample_rate", 48000)), int(audio.get("channels", 2))) if audio_on else 0
	var codec: String = codec_of(encoders, String(settings.get("video_codec", "")))
	var rc: Dictionary = settings.get("rate_control", {})
	var mode: String = String(rc.get("mode", "crf"))
	var video_kbps: float = 0.0
	var out_w: int = size.x
	var out_h: int = size.y
	var out_fps: float = fps
	if audio_only:
		video_kbps = 0.0
	elif mode == "size":
		var plan: Dictionary = plan_size(codec, size.x, size.y, fps, total_frames, float(rc.get("target_mb", 0.0)), audio_kbps, String(rc.get("prefer", "quality")))
		out["plan"] = plan
		if bool(plan["applies"]):
			video_kbps = float(plan["video_kbps"])
			out_w = int(plan["out_width"])
			out_h = int(plan["out_height"])
			out_fps = float(plan["out_fps"])
		else:
			video_kbps = crf_kbps(codec, size.x, size.y, fps, 18)
	elif mode == "bitrate":
		video_kbps = float(rc.get("bitrate_kbps", 0))
	else:
		video_kbps = crf_kbps(codec, size.x, size.y, fps, int(rc.get("crf", 18)))
	var total_kbps: float = video_kbps + float(audio_kbps)
	var size_mb: float = total_kbps * 1000.0 * duration / 8.0 / (1024.0 * 1024.0)
	out["video_kbps"] = video_kbps
	out["audio_kbps"] = audio_kbps
	out["width"] = out_w
	out["height"] = out_h
	out["fps"] = out_fps
	out["duration"] = duration
	out["size_mb"] = size_mb
	out["audio_only"] = audio_only
	out["warning"] = "" if not chosen.is_empty() else empty_note(seq, range_v, out_fps)
	out["spans"] = chosen.size()
	if audio_only:
		out["text"] = "Audio only, " + fmt_span(duration, fps) + " at " + fmt_rate(float(audio_kbps)) + ", about " + fmt_mb(size_mb)
	else:
		out["text"] = str(out_h) + "p at " + fmt_fps(out_fps) + " fps, about " + fmt_rate(total_kbps) + ", about " + fmt_mb(size_mb) + " for " + fmt_span(duration, out_fps)
		if not chosen.is_empty():
			out["text"] += ", the " + str(chosen.size()) + " parts you picked joined into one"
	if not String(out["warning"]).is_empty():
		out["text"] += "\n" + String(out["warning"])
	return out


const PCM_BITS: Dictionary = {
	"pcm_u8": 8, "pcm_s8": 8,
	"pcm_s16le": 16, "pcm_s16be": 16,
	"pcm_s24le": 24, "pcm_s24be": 24,
	"pcm_s32le": 32, "pcm_s32be": 32,
	"pcm_f32le": 32, "pcm_f32be": 32,
	"pcm_f64le": 64, "pcm_f64be": 64,
}
const LOSSLESS_SHARE: Dictionary = {"flac": 0.6, "alac": 0.62, "wavpack": 0.58, "tta": 0.6, "truehd": 0.7, "mlp": 0.7}


static func audio_kbps_of(codec: String, declared_kbps: int, sample_rate: int, channels: int) -> int:
	if declared_kbps > 0:
		return declared_kbps
	var rate: int = sample_rate if sample_rate > 0 else 48000
	var ch: int = channels if channels > 0 else 2
	if PCM_BITS.has(codec):
		return int(round(float(rate) * float(ch) * float(int(PCM_BITS[codec])) / 1000.0))
	if LOSSLESS_SHARE.has(codec):
		return int(round(float(rate) * float(ch) * 16.0 * float(LOSSLESS_SHARE[codec]) / 1000.0))
	return declared_kbps


static func covered_seconds(seq: Sequence, range_v: Vector2) -> float:
	if seq == null or range_v.y <= range_v.x:
		return 0.0
	var spans: Array[Vector2] = []
	for t: Track in seq.all_tracks():
		for c: Clip in t.clips:
			var a: float = maxf(c.start, range_v.x)
			var b: float = minf(c.end(), range_v.y)
			if b > a:
				spans.append(Vector2(a, b))
	if spans.is_empty():
		return 0.0
	spans.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var total: float = 0.0
	var open_from: float = spans[0].x
	var open_to: float = spans[0].y
	for i: int in range(1, spans.size()):
		if spans[i].x <= open_to:
			open_to = maxf(open_to, spans[i].y)
		else:
			total += open_to - open_from
			open_from = spans[i].x
			open_to = spans[i].y
	total += open_to - open_from
	return total


static func empty_note(seq: Sequence, range_v: Vector2, fps: float) -> String:
	var span: float = range_v.y - range_v.x
	if seq == null or span <= 1.0:
		return ""
	var empty: float = span - covered_seconds(seq, range_v)
	if empty < 5.0 or empty < span * 0.25:
		return ""
	return "Warning: " + fmt_span(empty, fps) + " of this range has no clips on any track. The export still writes every frame of it."


static func fmt_span(seconds: float, fps: float) -> String:
	var frames: int = int(round(seconds * fps)) if fps > 0.0 else 0
	if seconds < 60.0:
		return String.num(seconds, 1) + " s (" + str(frames) + " frames)"
	return Timecode.format(seconds, fps) + " (" + str(frames) + " frames)"


static func fmt_rate(kbps: float) -> String:
	if kbps >= 1000.0:
		return String.num(kbps / 1000.0, 1) + " Mbit/s"
	return str(int(round(kbps))) + " kbit/s"


static func fmt_mb(mb: float) -> String:
	if mb >= 1024.0:
		return String.num(mb / 1024.0, 2) + " GB"
	if mb >= 10.0:
		return str(int(round(mb))) + " MB"
	return String.num(mb, 1) + " MB"


static func output_path(settings: Dictionary, seq: Sequence, containers: Array[Dictionary]) -> String:
	var dest: Dictionary = settings.get("destination", {})
	var dir: String = String(dest.get("dir", ""))
	if dir.is_empty():
		dir = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
		if dir.is_empty():
			dir = OS.get_user_data_dir().path_join("exports")
	var name: String = String(dest.get("name", ""))
	if name.is_empty():
		name = seq.label if seq != null and not seq.label.is_empty() else "export"
	name = name.validate_filename()
	var cid: String = String(settings.get("container", "mp4"))
	var container: Dictionary = container_by_id(containers, cid)
	var ext: String = String(container.get("ext", cid))
	if is_sequence_container(cid):
		return dir.path_join(name + "_%05d." + ext)
	return dir.path_join(name + "." + ext)


static func chapters_from(seq: Sequence, range_v: Vector2) -> Array:
	var out: Array = []
	if seq == null:
		return out
	for m: Marker in MarkerLayers.usable(seq):
		if m.kind != "chapter":
			continue
		if m.time >= range_v.x and m.time <= range_v.y:
			out.append({"t": m.time - range_v.x, "label": m.label if not m.label.is_empty() else "Chapter " + str(out.size() + 1)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


static func fmt_clock(t: float) -> String:
	var total: int = int(floor(maxf(t, 0.0) + 0.0005))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var sec: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]


static func chapter_problems(chapters: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if chapters.is_empty():
		return out
	if float((chapters[0] as Dictionary)["t"]) > 0.0005:
		out.append("YouTube needs the first chapter at 0:00, and the first one here is at " + fmt_clock(float((chapters[0] as Dictionary)["t"])) + ".")
	if chapters.size() < YOUTUBE_MIN_CHAPTERS:
		out.append("YouTube needs at least %d chapters, and there %s %d." % [YOUTUBE_MIN_CHAPTERS, "is" if chapters.size() == 1 else "are", chapters.size()])
	for i: int in range(1, chapters.size()):
		var a: Dictionary = chapters[i - 1]
		var b: Dictionary = chapters[i]
		var gap: float = float(b["t"]) - float(a["t"])
		if gap < YOUTUBE_MIN_GAP - 0.0005:
			out.append("YouTube needs chapters at least 10 seconds apart: \"" + String(a["label"]) + "\" and \"" + String(b["label"]) + "\" are " + String.num(gap, 1) + " s apart.")
	return out


static func alpha_format_ok(container_id: String, codec_id: String) -> bool:
	for f: Array in ALPHA_FORMATS:
		if String(f[0]) == container_id and String(f[1]) == codec_id:
			return true
	return false


static func alpha_status(caps: Dictionary, container_id: String, codec_id: String) -> Dictionary:
	if not bool(caps.get("known", false)):
		return {"ok": false, "reason": "Rebuild the engine to export transparency: this build of purrcore cannot keep the see-through parts."}
	if not alpha_format_ok(container_id, codec_id):
		return {"ok": false, "reason": "This format cannot carry transparency. Pick " + ALPHA_FORMAT_NAMES + "."}
	var codecs: Variant = caps.get("alpha_codecs", PackedStringArray())
	var listed: bool = false
	if codecs is PackedStringArray:
		listed = (codecs as PackedStringArray).has(codec_id)
	elif codecs is Array:
		listed = (codecs as Array).has(codec_id)
	if not bool(caps.get("alpha", false)) or not listed:
		return {"ok": false, "reason": "This engine build has no " + codec_id + " encoder that keeps transparency."}
	return {"ok": true, "reason": ""}


static func share_clipboard_command(path: String, os_name: String) -> Dictionary:
	if os_name != "Windows" or path.is_empty() or path.contains("%"):
		return {}
	var quoted: String = "'" + path.replace("/", "\\").replace("'", "''") + "'"
	return {"exe": "powershell", "args": PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", "Set-Clipboard -LiteralPath " + quoted])}


static func is_share_fit(settings: Dictionary) -> bool:
	return String((settings.get("rate_control", {}) as Dictionary).get("mode", "crf")) == "size"


static func build_job(settings: Dictionary, seq: Sequence, encoders: Array[Dictionary], containers: Array[Dictionary], paths: Dictionary) -> Dictionary:
	var range_v: Vector2 = resolve_range(settings, seq)
	var duration: float = maxf(range_v.y - range_v.x, 0.0)
	var size: Vector2i = resolve_size(settings, seq.width, seq.height)
	var fps: float = resolve_fps(settings, seq.fps)
	var job_spans: PackedVector2Array = span_list(settings, seq) if spans_chosen(settings) else PackedVector2Array()
	var frac: Vector2i = fps_fraction(fps)
	var rc: Dictionary = settings.get("rate_control", {})
	var audio: Dictionary = settings.get("audio", {})
	var container: Dictionary = container_by_id(containers, String(settings.get("container", "mp4")))
	var audio_enabled: bool = bool(audio.get("enabled", true)) and not (container.get("audio_codecs", []) as Array).is_empty()
	var thumb: Dictionary = settings.get("thumbnail", {})
	var meta: Dictionary = settings.get("metadata", {})
	var chapters: Array = chapters_from(seq, range_v) if bool(settings.get("chapters_from_markers", true)) else []
	return {
		"path": String(paths.get("output", "")),
		"container": String(settings.get("container", "mp4")),
		"video_codec": String(settings.get("video_codec", "")),
		"width": size.x,
		"height": size.y,
		"fps_num": frac.x,
		"fps_den": frac.y,
		"rate_control": {
			"mode": String(rc.get("mode", "crf")),
			"crf": int(rc.get("crf", 18)),
			"bitrate_kbps": int(rc.get("bitrate_kbps", 0)),
			"max_kbps": int(rc.get("max_kbps", 0)),
			"target_mb": float(rc.get("target_mb", 0.0)),
			"prefer": String(rc.get("prefer", "quality")),
		},
		"pix_fmt": String(settings.get("pix_fmt", "yuv420p")),
		"audio": {
			"codec": String(audio.get("codec", "aac")) if audio_enabled else "",
			"bitrate_kbps": int(audio.get("bitrate_kbps", 192)),
			"sample_rate": int(audio.get("sample_rate", 48000)),
			"channels": int(audio.get("channels", 2)),
			"pcm_path": String(paths.get("pcm", "")) if audio_enabled else "",
			"pcm_paths": (paths.get("pcm_paths", []) as Array) if audio_enabled else [],
		},
		"thumbnail": {"path": String(paths.get("thumbnail", "")), "embed": bool(thumb.get("embed", true))},
		"metadata": {"title": String(meta.get("title", "")), "comment": String(meta.get("comment", ""))},
		"chapters": chapters,
		"total_frames": int(spans_frames(job_spans, fps)) if job_spans.size() > 0 else int(round(duration * fps)),
		"alpha": bool(paths.get("alpha", false)),
		"png_verify": bool(paths.get("png_verify", true)),
	}
