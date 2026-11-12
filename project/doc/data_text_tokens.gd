extends RefCounted

const Timecode := preload("res://doc/timecode.gd")
const CAPTURE_TIME := "res://modules/core_panels/bin_views/capture_time.gd"
const NUMBER_TOKENS: PackedStringArray = ["clips", "cuts", "clip_no"]
const SEQ_TOKENS: PackedStringArray = ["sequence", "seq_size", "seq_fps", "timecode", "marker", "marker_note"]
const CLIP_TOKENS: PackedStringArray = ["track", "folder", "clip_timecode", "clip_no", "file_date"]
const PAD_FILL := "0"


static func rate_text(f: float) -> String:
	return str(int(round(f))) if absf(f - round(f)) < 0.005 else String.num(f, 2)


static func size_text(w: int, h: int) -> String:
	return str(w) + " x " + str(h)


static func number_text(n: int, arg: String) -> String:
	if arg.is_empty():
		return str(n)
	var value: int = n
	var pad: int = 0
	for part: String in arg.split(",", false):
		var p: String = part.strip_edges()
		if p.is_empty():
			continue
		if (p.begins_with("+") or p.begins_with("-")) and p.substr(1).is_valid_int():
			value += int(p.substr(1)) * (-1 if p.begins_with("-") else 1)
			continue
		if p.lstrip(PAD_FILL).is_empty():
			pad = maxi(pad, p.length())
	if pad <= 0:
		return str(value)
	var lead: String = "-" if value < 0 else ""
	return lead + str(absi(value)).lpad(pad, PAD_FILL)


static func is_number_token(name: String) -> bool:
	return NUMBER_TOKENS.has(name)


static func nearest_marker(seq: Object, t: float) -> Object:
	if seq == null:
		return null
	var best: Object = null
	var best_gap: float = INF
	for m: Object in seq.get("markers"):
		var from: float = float(m.get("time"))
		var to: float = from + maxf(float(m.get("duration")), 0.0)
		var gap: float = 0.0 if (t >= from and t <= to) else minf(absf(t - from), absf(t - to))
		if gap < best_gap - 0.000001:
			best_gap = gap
			best = m
	return best


static func track_label(seq: Object, c: Object) -> String:
	if seq == null or c == null:
		return ""
	for pair: Array in [["video_tracks", "V"], ["audio_tracks", "A"]]:
		var tracks: Array = seq.get(String(pair[0]))
		for i: int in tracks.size():
			if not (tracks[i].get("clips") as Array).has(c):
				continue
			var lab: String = String(tracks[i].get("label"))
			return lab if not lab.is_empty() else String(pair[1]) + str(i + 1)
	return ""


static func clip_number(seq: Object, c: Object) -> int:
	if seq == null or c == null:
		return 0
	var at: float = float(c.get("start"))
	var before: int = 0
	var reached: bool = false
	for field: String in ["video_tracks", "audio_tracks"]:
		for tr: Object in seq.get(field):
			for other: Object in tr.get("clips"):
				if other == c:
					reached = true
					continue
				var s: float = float(other.get("start"))
				if s < at or (s == at and not reached):
					before += 1
	return before + 1 if reached else 0


static func sequence_context(seq: Object, t: float) -> Dictionary:
	var out: Dictionary = {}
	if seq == null:
		return out
	var fps: float = float(seq.get("fps"))
	out["sequence"] = String(seq.get("label"))
	out["seq_size"] = size_text(int(seq.get("width")), int(seq.get("height")))
	out["seq_fps"] = rate_text(fps)
	out["timecode"] = Timecode.format(t, fps, bool(seq.get("drop_frame")))
	var m: Object = nearest_marker(seq, t)
	out["marker"] = String(m.get("label")) if m != null else ""
	out["marker_note"] = String(m.get("comment")) if m != null else ""
	return out


static func clip_context(seq: Object, c: Object, media: Object, path: String, into: float, file_unix: int) -> Dictionary:
	var out: Dictionary = {}
	var fps: float = float(media.get("fps")) if media != null else 0.0
	if fps <= 0.0 and seq != null:
		fps = float(seq.get("fps"))
	out["track"] = track_label(seq, c)
	out["folder"] = path.get_base_dir().get_file()
	out["clip_timecode"] = Timecode.format(into, fps, false)
	out["clip_no"] = clip_number(seq, c)
	out["file_date"] = float(load(CAPTURE_TIME).call("local_from_unix", file_unix))
	return out
