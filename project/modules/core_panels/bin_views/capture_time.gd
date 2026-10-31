extends RefCounted

const GAPS: Array[float] = [600.0, 1800.0, 3600.0, 10800.0]
const GAP_LABELS: PackedStringArray = ["10 min", "30 min", "1 h", "3 h"]
const DEFAULT_GAP := 1800.0
const DAY := 86400.0
const MONTHS: PackedStringArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEKDAYS: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const PATTERNS: PackedStringArray = [
	"(?<y>(?:19|20)\\d\\d)[-._](?<mo>\\d\\d)[-._](?<d>\\d\\d)[ _T-]+(?<h>\\d\\d)[-._:h](?<mi>\\d\\d)[-._:m](?<s>\\d\\d)",
	"(?<y>(?:19|20)\\d\\d)-(?<mo>\\d\\d)-(?<d>\\d\\d)[ _](?<h>\\d\\d)(?<mi>\\d\\d)(?<s>\\d\\d)",
	"(?<y>(?:19|20)\\d\\d)(?<mo>\\d\\d)(?<d>\\d\\d)[_-](?<h>\\d\\d)(?<mi>\\d\\d)(?<s>\\d\\d)",
	"(?<![0-9])(?<y>(?:19|20)\\d\\d)(?<mo>\\d\\d)(?<d>\\d\\d)(?<h>\\d\\d)(?<mi>\\d\\d)(?<s>\\d\\d)(?![0-9])",
]

static var _compiled: Array[RegEx] = []


static func _regexes() -> Array[RegEx]:
	if _compiled.is_empty():
		for p: String in PATTERNS:
			var r := RegEx.new()
			if r.compile(p) == OK:
				_compiled.append(r)
	return _compiled


static func from_name(file_name: String) -> float:
	var base: String = file_name.get_file()
	for r: RegEx in _regexes():
		var m: RegExMatch = r.search(base)
		if m == null:
			continue
		var t: float = _stamp(int(m.get_string("y")), int(m.get_string("mo")), int(m.get_string("d")), int(m.get_string("h")), int(m.get_string("mi")), int(m.get_string("s")))
		if t >= 0.0:
			return t
	return -1.0


static func _stamp(y: int, mo: int, d: int, h: int, mi: int, s: int) -> float:
	if mo < 1 or mo > 12 or d < 1 or d > 31 or h > 23 or mi > 59 or s > 60:
		return -1.0
	var dt: Dictionary = {"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": mini(s, 59)}
	return float(Time.get_unix_time_from_datetime_dict(dt))


static func local_from_unix(unix: int) -> float:
	if unix <= 0:
		return -1.0
	var tz: Dictionary = Time.get_time_zone_from_system()
	return float(unix + int(tz.get("bias", 0)) * 60)


static func from_info(info: Dictionary) -> float:
	if not bool(info.get("creation_found", false)):
		return -1.0
	var unix: float = float(info.get("creation_time", 0.0))
	if unix <= 0.0:
		return -1.0
	return local_from_unix(int(floor(unix)))


static func recorded(label: String, path: String, file_time: int, duration: float, timed: bool, own: float = -1.0) -> Dictionary:
	var dur: float = maxf(duration, 0.0) if timed else 0.0
	if own >= 0.0:
		return {"start": own, "end": own + dur, "source": "own"}
	var named: float = from_name(path.get_file() if not path.is_empty() else label)
	if named < 0.0 and not label.is_empty():
		named = from_name(label)
	if named >= 0.0:
		return {"start": named, "end": named + dur, "source": "name"}
	var local: float = local_from_unix(file_time)
	if local >= 0.0:
		return {"start": local - dur, "end": local, "source": "file"}
	return {"start": -1.0, "end": -1.0, "source": ""}


static func sessions(items: Array[Dictionary], gap: float) -> Array[Dictionary]:
	var timed: Array[Dictionary] = []
	for it: Dictionary in items:
		if float(it.get("start", -1.0)) >= 0.0:
			timed.append(it)
	timed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]) or (float(a["start"]) == float(b["start"]) and String(a.get("id", "")) < String(b.get("id", ""))))
	var out: Array[Dictionary] = []
	var cur: Dictionary = {}
	for it: Dictionary in timed:
		var s: float = float(it["start"])
		var e: float = maxf(float(it.get("end", s)), s)
		if cur.is_empty() or s > float(cur["end"]) + gap:
			cur = {"start": s, "end": e, "items": [] as Array[Dictionary], "recorded": 0.0}
			out.append(cur)
		(cur["items"] as Array[Dictionary]).append(it)
		cur["end"] = maxf(float(cur["end"]), e)
		cur["recorded"] = float(cur["recorded"]) + (e - s)
	return out


static func day_of(t: float) -> int:
	return int(floor(t / DAY))


static func clock(t: float, seconds: bool = false) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(floor(t)))
	if seconds:
		return "%02d:%02d:%02d" % [int(d["hour"]), int(d["minute"]), int(d["second"])]
	return "%02d:%02d" % [int(d["hour"]), int(d["minute"])]


static func day_text(t: float, short: bool) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(floor(t)))
	var wd: String = WEEKDAYS[int(d["weekday"]) % 7]
	var mo: String = MONTHS[clampi(int(d["month"]) - 1, 0, 11)]
	if short:
		return wd.substr(0, 3) + " " + str(int(d["day"])) + " " + mo.substr(0, 3) + " " + str(int(d["year"]))
	return wd + " " + str(int(d["day"])) + " " + mo + " " + str(int(d["year"]))


static func span_text(seconds: float) -> String:
	var s: int = int(round(seconds))
	if s < 60:
		return str(s) + " s"
	var m: int = s / 60
	if m < 60:
		return str(m) + " min"
	var h: int = m / 60
	var rest: int = m % 60
	return str(h) + " h" if rest == 0 else str(h) + " h " + str(rest) + " min"


static func gap_index(gap: float) -> int:
	for i: int in GAPS.size():
		if absf(GAPS[i] - gap) < 1.0:
			return i
	return 1
