extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Io := preload("res://doc/io.gd")
const Find := preload("res://doc/picture_find.gd")
const Found := preload("res://doc/found_regions.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const CaptureTime := preload("res://modules/core_panels/bin_views/capture_time.gd")
const DIR := "organizer/desktop"
const VERSION := 1
const MADE := "desktop"
const MADE_SWITCH := "desktop_switch"
const SWITCH_KIND := "come_back"
const MIN_OVERLAP := 1.0
const CARRY := 1.5
const CUT_NEAR := 1.0
const SOURCE_SCREEN := "screen"
const SOURCE_OBS := "obs"

static var _override_dir: String = ""
static var _cache: Dictionary = {}


static func dir() -> String:
	if not _override_dir.is_empty():
		return _override_dir
	return Io.data_path(DIR)


static func use_dir(p: String) -> void:
	_override_dir = p
	_cache = {}


static func now_local() -> float:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return Time.get_unix_time_from_system() + float(int(tz.get("bias", 0)) * 60)


static func fresh(start: float, rate: float, screen: int, part: Rect2, source: String = SOURCE_SCREEN) -> Dictionary:
	return {"version": VERSION, "start": start, "rate": rate, "screen": screen, "part": Find.rect_array(part), "source": source, "times": PackedFloat64Array(), "changes": PackedFloat32Array(), "kinds": {}, "cuts": [], "recordings": []}


static func file_of(session: Dictionary) -> String:
	return dir().path_join("watch_%d.json" % int(floor(float(session.get("start", 0.0)))))


static func encode(session: Dictionary) -> Dictionary:
	var kinds: Dictionary = {}
	var raw: Dictionary = session.get("kinds", {})
	for k: Variant in raw.keys():
		kinds[String(k)] = Marshalls.raw_to_base64((raw[k] as PackedFloat32Array).to_byte_array())
	return {"version": VERSION, "start": float(session.get("start", 0.0)), "rate": float(session.get("rate", 2.0)), "screen": int(session.get("screen", -1)), "part": session.get("part", [0.0, 0.0, 1.0, 1.0]), "source": String(session.get("source", SOURCE_SCREEN)), "cuts": (session.get("cuts", []) as Array).duplicate(true), "recordings": (session.get("recordings", []) as Array).duplicate(true), "count": (session.get("times", PackedFloat64Array()) as PackedFloat64Array).size(), "times": Marshalls.raw_to_base64((session.get("times", PackedFloat64Array()) as PackedFloat64Array).to_byte_array()), "changes": Marshalls.raw_to_base64((session.get("changes", PackedFloat32Array()) as PackedFloat32Array).to_byte_array()), "kinds": kinds}


static func decode(d: Dictionary) -> Dictionary:
	if d.is_empty() or not d.has("start"):
		return {}
	var times: PackedFloat64Array = Marshalls.base64_to_raw(String(d.get("times", ""))).to_float64_array()
	var changes: PackedFloat32Array = Marshalls.base64_to_raw(String(d.get("changes", ""))).to_float32_array()
	var kinds: Dictionary = {}
	var raw: Variant = d.get("kinds", {})
	if raw is Dictionary:
		for k: Variant in (raw as Dictionary).keys():
			var arr: PackedFloat32Array = Marshalls.base64_to_raw(String((raw as Dictionary)[k])).to_float32_array()
			if arr.size() == times.size():
				kinds[String(k)] = arr
	if changes.size() != times.size():
		changes = PackedFloat32Array()
		changes.resize(times.size())
	var cuts: Array = []
	var raw_cuts: Variant = d.get("cuts", [])
	if raw_cuts is Array:
		for c: Variant in raw_cuts:
			cuts.append(float(c))
	var recs: Array = []
	var raw_recs: Variant = d.get("recordings", [])
	if raw_recs is Array:
		for r: Variant in raw_recs:
			if r is Dictionary:
				recs.append({"start": float((r as Dictionary).get("start", -1.0)), "end": float((r as Dictionary).get("end", -1.0)), "path": String((r as Dictionary).get("path", ""))})
	return {"version": int(d.get("version", VERSION)), "start": float(d["start"]), "rate": float(d.get("rate", 2.0)), "screen": int(d.get("screen", -1)), "part": d.get("part", [0.0, 0.0, 1.0, 1.0]), "source": String(d.get("source", SOURCE_SCREEN)), "times": times, "changes": changes, "kinds": kinds, "cuts": cuts, "recordings": recs}


static func save(session: Dictionary) -> String:
	var p: String = file_of(session)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	if Io.write_atomic(p, JSON.stringify(encode(session)), false) != OK:
		return ""
	_cache.erase(p)
	return p


static func paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: String = dir()
	if not DirAccess.dir_exists_absolute(d):
		return out
	for f: String in DirAccess.get_files_at(d):
		if f.begins_with("watch_") and f.ends_with(".json"):
			out.append(d.path_join(f))
	out.sort()
	return out


static func read(p: String) -> Dictionary:
	var stamp: int = int(FileAccess.get_modified_time(p)) if FileAccess.file_exists(p) else -1
	if _cache.has(p) and int((_cache[p] as Dictionary).get("stamp", -2)) == stamp:
		return (_cache[p] as Dictionary)["session"]
	var s: Dictionary = decode(Io.read_json(p))
	_cache[p] = {"stamp": stamp, "session": s}
	return s


static func sessions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: String in paths():
		var s: Dictionary = read(p)
		if not s.is_empty() and not (s["times"] as PackedFloat64Array).is_empty():
			out.append(s)
	return out


static func forget_all() -> int:
	var n: int = 0
	for p: String in paths():
		if DirAccess.remove_absolute(p) == OK:
			n += 1
	_cache = {}
	return n


static func span_of(session: Dictionary) -> PackedFloat64Array:
	var times: PackedFloat64Array = session.get("times", PackedFloat64Array())
	var a: float = float(session.get("start", 0.0))
	if times.is_empty():
		return PackedFloat64Array([a, a])
	return PackedFloat64Array([a + times[0], a + times[times.size() - 1]])


static func same_file(a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var x: String = a.replace("\\", "/").to_lower()
	var y: String = b.replace("\\", "/").to_lower()
	return x == y or (x.get_file() == y.get_file() and x.get_file().length() > 12)


static func recorded_by_obs(item: MediaItem, list: Array[Dictionary]) -> float:
	for s: Dictionary in list:
		for r: Variant in (s.get("recordings", []) as Array):
			var rd: Dictionary = r
			if float(rd.get("start", -1.0)) >= 0.0 and same_file(String(rd.get("path", "")), item.path):
				return float(rd["start"])
	return -1.0


static func recorded_span(item: MediaItem, dur: float, list: Array[Dictionary] = []) -> PackedFloat64Array:
	var none: PackedFloat64Array = PackedFloat64Array([-1.0, -1.0])
	if item == null or dur <= 0.0:
		return none
	var by_obs: float = recorded_by_obs(item, list)
	if by_obs >= 0.0:
		return PackedFloat64Array([by_obs, by_obs + dur])
	if item.recorded_at >= 0.0:
		return PackedFloat64Array([item.recorded_at, item.recorded_at + dur])
	var file_time: int = int(FileAccess.get_modified_time(item.path)) if not item.path.is_empty() and FileAccess.file_exists(item.path) else 0
	var rec: Dictionary = CaptureTime.recorded(item.label, item.path, file_time, dur, true)
	var a: float = float(rec.get("start", -1.0))
	if a < 0.0:
		return none
	return PackedFloat64Array([a, a + dur])


static func overlapping(list: Array[Dictionary], span: PackedFloat64Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if span.size() < 2 or span[0] < 0.0:
		return out
	for s: Dictionary in list:
		var sv: PackedFloat64Array = span_of(s)
		if minf(sv[1], span[1]) - maxf(sv[0], span[0]) >= MIN_OVERLAP:
			out.append(s)
	return out


static func binned(list: Array[Dictionary], rec_start: float, dur: float, kind: String, rate: float) -> PackedFloat32Array:
	var n: int = maxi(int(ceil(dur * rate)), 0)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var has: PackedByteArray = PackedByteArray()
	has.resize(n)
	for s: Dictionary in list:
		var times: PackedFloat64Array = s["times"]
		var vals: PackedFloat32Array = s["changes"] if kind.is_empty() else (s["kinds"] as Dictionary).get(kind, PackedFloat32Array())
		if vals.size() != times.size():
			continue
		var base: float = float(s["start"]) - rec_start
		for j: int in times.size():
			var i: int = int(floor((base + times[j]) * rate))
			if i < 0 or i >= n:
				continue
			if has[i] == 0 or vals[j] > out[i]:
				out[i] = vals[j]
			has[i] = 1
	var reach: int = maxi(int(ceil(CARRY * rate)), 1)
	var last: int = -1
	for i: int in n:
		if has[i] == 1:
			last = i
		elif last >= 0 and i - last <= reach:
			out[i] = out[last]
	return out


static func made_for(list: Array[Dictionary], rec_start: float, dur: float) -> Array:
	var out: Array = []
	var rate: float = float(Find.RATE)
	var kinds: Dictionary = {}
	for s: Dictionary in list:
		for k: Variant in (s["kinds"] as Dictionary).keys():
			kinds[String(k)] = true
	var when: String = CaptureTime.clock(rec_start, true)
	for k: Variant in kinds.keys():
		var kind: String = String(k)
		if Kinds.by_id(kind).is_empty():
			continue
		var spec: Dictionary = Found.spec_of(kind)
		var scores: PackedFloat32Array = binned(list, rec_start, dur, kind, rate)
		for v: Vector2 in Find.ranges(scores, rate, float(spec["threshold"]), float(spec["min_len"]), float(spec["gap"])):
			out.append(Regions.make(kind, v.x, minf(v.y, dur), {"made": MADE, "cut": bool(spec["cut"]), "note": "Seen by the desktop watch"}))
	var cut_times: PackedFloat64Array = PackedFloat64Array()
	for s: Dictionary in list:
		for c: Variant in (s.get("cuts", []) as Array):
			var ct: float = float(s["start"]) + float(c) - rec_start
			if ct >= 0.0 and ct <= dur:
				cut_times.append(ct)
	cut_times.sort()
	for ct: float in cut_times:
		out.append(Regions.make(SWITCH_KIND, maxf(ct - 0.25, 0.0), minf(ct + Find.SWITCH_LEN - 0.25, dur), {"made": MADE_SWITCH, "note": "The OBS scene changed here", "come_back": true}))
	var changes: PackedFloat32Array = binned(list, rec_start, dur, "", rate)
	for t: float in Find.switches(changes, rate):
		var near: bool = false
		for ct: float in cut_times:
			if absf(ct - t) <= CUT_NEAR:
				near = true
		if near:
			continue
		out.append(Regions.make(SWITCH_KIND, maxf(t - 0.25, 0.0), minf(t + Find.SWITCH_LEN - 0.25, dur), {"made": MADE_SWITCH, "note": "Possible scene switch (desktop watch, recording started %s)" % when, "come_back": true}))
	return out


static func apply_to(doc: Project, item: MediaItem, list: Array[Dictionary] = []) -> int:
	if doc == null or item == null or item.path.is_empty() or item.kind != "video":
		return 0
	var dur: float = doc.media_duration(item)
	if dur <= 0.0:
		return -1
	var all: Array[Dictionary] = list if not list.is_empty() else sessions()
	var span: PackedFloat64Array = recorded_span(item, dur, all)
	var near: Array[Dictionary] = overlapping(all, span)
	if near.is_empty():
		return 0
	var found: Array = made_for(near, span[0], dur)
	var next: Array = []
	for r: Variant in Regions.list(item):
		if r is Dictionary:
			var made: String = String((r as Dictionary).get("made", ""))
			if made != MADE and made != MADE_SWITCH:
				next.append((r as Dictionary).duplicate(true))
	if found.is_empty() and next.size() == Regions.list(item).size():
		return 0
	next.append_array(found)
	if not Regions.replace(doc, item.id, next, "Desktop notes on " + item.label):
		return 0
	return found.size()
