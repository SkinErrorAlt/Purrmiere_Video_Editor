extends RefCounted

const VERSION := 1


static func is_drop_frame_rate(fps: float) -> bool:
	return absf(fps - 29.97) < 0.01 or absf(fps - 59.94) < 0.01 or absf(fps - 23.976) < 0.01


static func nominal_fps(fps: float) -> int:
	return int(round(fps))


static func to_frames(seconds: float, fps: float) -> int:
	return int(round(seconds * fps))


static func format(seconds: float, fps: float, drop_frame: bool = false) -> String:
	if fps <= 0.0:
		fps = 30.0
	var negative: bool = seconds < 0.0
	var frames: int = to_frames(absf(seconds), fps)
	var nominal: int = nominal_fps(fps)
	var sep: String = ":"
	var use_drop: bool = drop_frame and (absf(fps - 29.97) < 0.01 or absf(fps - 59.94) < 0.01)
	if use_drop:
		sep = ";"
		var drop: int = int(round(float(nominal) * 0.066666))
		var per_min: int = nominal * 60 - drop
		var per_ten: int = per_min * 10 + drop
		var tens: int = frames / per_ten
		var rem: int = frames % per_ten
		if rem < drop:
			frames += drop * 9 * tens
		else:
			frames += drop * 9 * tens + drop * ((rem - drop) / per_min)
	var ff: int = frames % nominal
	var total_s: int = frames / nominal
	var ss: int = total_s % 60
	var mm: int = (total_s / 60) % 60
	var hh: int = total_s / 3600
	var text: String = "%02d%s%02d%s%02d%s%02d" % [hh, sep, mm, sep, ss, sep, ff]
	if negative:
		return "-" + text
	return text


static func frames_to_seconds(frames: int, fps: float, drop_frame: bool) -> float:
	if fps <= 0.0:
		fps = 30.0
	return float(frames) / fps


static func timecode_to_frames(hh: int, mm: int, ss: int, ff: int, fps: float, drop_frame: bool) -> int:
	var nominal: int = nominal_fps(fps)
	var total_minutes: int = hh * 60 + mm
	var frames: int = ((total_minutes * 60 + ss) * nominal) + ff
	var use_drop: bool = drop_frame and (absf(fps - 29.97) < 0.01 or absf(fps - 59.94) < 0.01)
	if use_drop:
		var drop: int = int(round(float(nominal) * 0.066666))
		frames -= drop * (total_minutes - total_minutes / 10)
	return frames


static func parse(text: String, fps: float, current: float = 0.0) -> float:
	if fps <= 0.0:
		fps = 30.0
	var s: String = text.strip_edges()
	if s.is_empty():
		return NAN
	var relative: int = 0
	if s.begins_with("+"):
		relative = 1
		s = s.substr(1).strip_edges()
	elif s.begins_with("-"):
		relative = -1
		s = s.substr(1).strip_edges()
	var drop: bool = s.contains(";")
	s = s.replace(";", ":")
	var value: float = NAN
	if s.ends_with("f") or s.ends_with("F"):
		var fs: String = s.substr(0, s.length() - 1).strip_edges()
		if not fs.is_valid_int():
			return NAN
		value = float(int(fs)) / fps
	elif s.contains(":"):
		var parts: PackedStringArray = s.split(":")
		for p: String in parts:
			if p.is_empty() or not p.is_valid_int():
				return NAN
		if parts.size() == 2:
			value = float(int(parts[0])) * 60.0 + float(int(parts[1]))
		elif parts.size() == 3:
			value = float(int(parts[0])) * 3600.0 + float(int(parts[1])) * 60.0 + float(int(parts[2]))
		elif parts.size() == 4:
			var frames: int = timecode_to_frames(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]), fps, drop)
			value = float(frames) / fps
		else:
			return NAN
	else:
		if not s.is_valid_float():
			return NAN
		value = float(s)
	if relative != 0:
		return current + float(relative) * value
	return value
