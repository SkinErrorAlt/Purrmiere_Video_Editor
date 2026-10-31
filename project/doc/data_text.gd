extends RefCounted

const MONTHS: PackedStringArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEKDAYS: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const DATE_PRESETS: Dictionary = {
	"short": "MMM D, YYYY",
	"long": "MMMM D, YYYY",
	"day": "DDDD, MMMM D, YYYY",
	"ordinal": "YYYY MMM Do",
	"the": "[The] Do [of] MMMM. YYYY",
	"shout": "MMMM D,",
	"month_day": "MMMM D",
	"day_month": "D MMMM YYYY",
	"iso": "YYYY-MM-DD",
	"us": "MM/DD/YYYY",
	"eu": "DD/MM/YYYY",
	"year": "YYYY",
}
const TIME_PRESETS: Dictionary = {
	"clock": "h:mm A",
	"clock_s": "h:mm:ss A",
	"24": "HH:mm",
	"24s": "HH:mm:ss",
}
const PRESET_LABELS: Dictionary = {
	"short": "Apr 25, 2026",
	"long": "April 25, 2026",
	"day": "Saturday, April 25, 2026",
	"ordinal": "2026 Apr 25th",
	"the": "The 25th of April. 2026",
	"shout": "APRIL 25, (with Uppercase on)",
	"month_day": "April 25",
	"day_month": "25 April 2026",
	"iso": "2026-04-25",
	"us": "04/25/2026",
	"eu": "25/04/2026",
	"year": "2026",
	"clock": "3:07 PM",
	"clock_s": "3:07:09 PM",
	"24": "15:07",
	"24s": "15:07:09",
}
const TOKENS: PackedStringArray = ["date", "time", "clock", "end", "today", "length", "into", "file", "name", "clips", "cuts", "edit_time", "project", "fps", "size"]
const TOKEN_LABELS: Dictionary = {
	"date": "Date the clip under the text was recorded",
	"time": "Time the recording started",
	"clock": "The recording's clock at this frame",
	"end": "Time the recording ended",
	"today": "Today's date",
	"length": "How long the recording is",
	"into": "How far into the recording this frame is",
	"file": "The file name",
	"name": "The clip's name",
	"clips": "How many clips the sequence has",
	"cuts": "How many cuts the sequence has",
	"edit_time": "Time spent editing this project",
	"project": "The project's name",
	"fps": "The recording's frame rate",
	"size": "The recording's size",
}
const NEED_DATE: PackedStringArray = ["date", "time", "clock", "end"]
const CAPTURE_TIME := "res://modules/core_panels/bin_views/capture_time.gd"


static func has_tokens(text: String) -> bool:
	if not text.contains("{"):
		return false
	for t: String in TOKENS:
		if text.contains("{" + t + "}") or text.contains("{" + t + ":"):
			return true
	return false


static func ordinal(n: int) -> String:
	var tail: int = n % 100
	if tail >= 11 and tail <= 13:
		return str(n) + "th"
	var last: int = n % 10
	if last == 1:
		return str(n) + "st"
	if last == 2:
		return str(n) + "nd"
	if last == 3:
		return str(n) + "rd"
	return str(n) + "th"


static func pattern_for(name: String, fallback: String) -> String:
	if name.is_empty():
		return fallback
	if DATE_PRESETS.has(name):
		return String(DATE_PRESETS[name])
	if TIME_PRESETS.has(name):
		return String(TIME_PRESETS[name])
	return name


static func format(local_unix: float, pattern: String) -> String:
	if local_unix < 0.0:
		return "?"
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(floor(local_unix)))
	var y: int = int(d["year"])
	var mo: int = int(d["month"])
	var day: int = int(d["day"])
	var wd: int = int(d["weekday"])
	var hh: int = int(d["hour"])
	var mi: int = int(d["minute"])
	var ss: int = int(d["second"])
	var h12: int = hh % 12
	if h12 == 0:
		h12 = 12
	var table: Array = [
		["YYYY", str(y)], ["YY", "%02d" % (y % 100)],
		["MMMM", MONTHS[mo - 1]], ["MMM", MONTHS[mo - 1].substr(0, 3)], ["MM", "%02d" % mo], ["M", str(mo)],
		["DDDD", WEEKDAYS[wd]], ["DDD", WEEKDAYS[wd].substr(0, 3)], ["Do", ordinal(day)], ["DD", "%02d" % day], ["D", str(day)],
		["HH", "%02d" % hh], ["H", str(hh)], ["hh", "%02d" % h12], ["h", str(h12)],
		["mm", "%02d" % mi], ["ss", "%02d" % ss], ["A", "AM" if hh < 12 else "PM"], ["a", "am" if hh < 12 else "pm"],
	]
	var out: String = ""
	var i: int = 0
	while i < pattern.length():
		if pattern[i] == "[":
			var close: int = pattern.find("]", i + 1)
			if close > i:
				out += pattern.substr(i + 1, close - i - 1)
				i = close + 1
				continue
		var hit: bool = false
		for pair: Array in table:
			var key: String = String(pair[0])
			if pattern.substr(i, key.length()) == key:
				out += String(pair[1])
				i += key.length()
				hit = true
				break
		if not hit:
			out += pattern[i]
			i += 1
	return out


static func duration_text(seconds: float, pattern: String = "") -> String:
	var total: int = int(floor(maxf(seconds, 0.0)))
	var h: int = total / 3600
	var m: int = (total / 60) % 60
	var s: int = total % 60
	if pattern == "words":
		var parts: PackedStringArray = PackedStringArray()
		if h > 0:
			parts.append(str(h) + (" hour" if h == 1 else " hours"))
		if m > 0:
			parts.append(str(m) + (" minute" if m == 1 else " minutes"))
		if s > 0 or parts.is_empty():
			parts.append(str(s) + (" second" if s == 1 else " seconds"))
		return " ".join(parts)
	if pattern == "minutes":
		return str(total / 60) + " min"
	if h > 0 or pattern == "long":
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [total / 60, s]


static func expand(text: String, ctx: Dictionary) -> String:
	if not text.contains("{"):
		return text
	var out: String = ""
	var i: int = 0
	while i < text.length():
		var open: int = text.find("{", i)
		if open < 0:
			out += text.substr(i)
			break
		var close: int = text.find("}", open + 1)
		if close < 0:
			out += text.substr(i)
			break
		out += text.substr(i, open - i)
		var inner: String = text.substr(open + 1, close - open - 1)
		var name: String = inner.get_slice(":", 0)
		var arg: String = inner.substr(name.length() + 1) if inner.contains(":") else ""
		if TOKENS.has(name):
			out += token_value(name, arg, ctx)
		else:
			out += "{" + inner + "}"
		i = close + 1
	return out


static func token_value(name: String, arg: String, ctx: Dictionary) -> String:
	var start: float = float(ctx.get("rec_start", -1.0))
	if name == "date":
		return format(start, pattern_for(arg, "MMMM D, YYYY"))
	if name == "time":
		return format(start, pattern_for(arg, "h:mm A"))
	if name == "clock":
		return format(start + float(ctx.get("into", 0.0)) if start >= 0.0 else -1.0, pattern_for(arg, "h:mm:ss A"))
	if name == "end":
		var end: float = float(ctx.get("rec_end", -1.0))
		return format(end, pattern_for(arg, "h:mm A"))
	if name == "today":
		return format(float(ctx.get("today", -1.0)), pattern_for(arg, "MMMM D, YYYY"))
	if name == "length":
		return duration_text(float(ctx.get("length", 0.0)), arg)
	if name == "into":
		return duration_text(float(ctx.get("into", 0.0)), arg)
	if name == "edit_time":
		return duration_text(float(ctx.get("edit_seconds", 0.0)), arg if not arg.is_empty() else "words")
	if name == "clips" or name == "cuts":
		return str(int(ctx.get(name, 0)))
	if name == "fps":
		var f: float = float(ctx.get("fps", 0.0))
		return str(int(round(f))) if absf(f - round(f)) < 0.005 else String.num(f, 2)
	return String(ctx.get(name, ""))


static var _file_times: Dictionary = {}


static func file_time(path: String) -> int:
	if path.is_empty():
		return 0
	if _file_times.has(path):
		return int(_file_times[path])
	var t: int = int(FileAccess.get_modified_time(path)) if FileAccess.file_exists(path) else 0
	_file_times[path] = t
	return t


static func clip_under(seq: Object, title: Object, t: float) -> Object:
	if seq == null or title == null:
		return null
	var tracks: Array = seq.get("video_tracks")
	var own: int = -1
	for i: int in tracks.size():
		if (tracks[i].get("clips") as Array).has(title):
			own = i
	for j: int in range(own - 1 if own >= 0 else tracks.size() - 1, -1, -1):
		for c: Object in tracks[j].get("clips"):
			if c == title or not bool(c.get("enabled")):
				continue
			if float(c.get("start")) <= t and t < float(c.call("end")):
				return c
	return null


static func cuts_in(seq: Object) -> int:
	var n: int = 0
	for tr: Object in seq.get("video_tracks"):
		var clips: Array = tr.get("clips")
		for k: int in range(1, clips.size()):
			if absf(float(clips[k].get("start")) - float(clips[k - 1].call("end"))) < 0.0005:
				n += 1
	return n


static func context(doc: Object, seq: Object, title: Object, t: float) -> Dictionary:
	var ctx: Dictionary = {"today": float(Time.get_unix_time_from_system()) + float(int(Time.get_time_zone_from_system().get("bias", 0)) * 60), "rec_start": -1.0, "rec_end": -1.0}
	if doc == null or seq == null:
		return ctx
	var clips: int = 0
	for tr: Object in seq.get("video_tracks"):
		clips += (tr.get("clips") as Array).size()
	for tr2: Object in seq.get("audio_tracks"):
		clips += (tr2.get("clips") as Array).size()
	ctx["clips"] = clips
	ctx["cuts"] = cuts_in(seq)
	ctx["project"] = String(doc.get("name"))
	ctx["edit_seconds"] = float(doc.call("edit_seconds")) if doc.has_method("edit_seconds") else 0.0
	var c: Object = clip_under(seq, title, t)
	if c == null:
		return ctx
	var m: Object = doc.call("media_by_id", String(c.get("media_id")))
	if m == null:
		return ctx
	var path: String = String(m.get("path"))
	var dur: float = float(m.get("duration"))
	var CaptureTime: GDScript = load(CAPTURE_TIME)
	var rec: Dictionary = CaptureTime.call("recorded", String(m.get("label")), path, file_time(path), dur, true, float(m.get("recorded_at")))
	ctx["rec_start"] = float(rec.get("start", -1.0))
	ctx["rec_end"] = float(rec.get("end", -1.0))
	ctx["length"] = dur
	ctx["into"] = maxf(float(c.call("source_time", t)), 0.0)
	ctx["file"] = path.get_file()
	ctx["name"] = String(c.get("label")) if not String(c.get("label")).is_empty() else String(m.get("label"))
	ctx["fps"] = float(m.get("fps"))
	ctx["size"] = str(int(m.get("width"))) + " x " + str(int(m.get("height")))
	return ctx
