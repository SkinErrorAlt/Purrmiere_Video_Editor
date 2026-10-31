extends RefCounted

const Project := preload("res://doc/project.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const OrganizerCmds := preload("res://doc/commands/organizer_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Store := preload("res://doc/region_store.gd")
const SourceMarks := preload("res://doc/source_marks.gd")
const HIDDEN_KEY := "regions_off"
const MIN_LENGTH := 0.04
const EPS := 0.0005
const LANE_ALL := ""
const LANE_PICTURE := "video"
const LANE_SOUND := "audio"
const LANES: PackedStringArray = ["", "video", "audio"]
const LANE_LABELS: Dictionary = {"": "Whole clip", "video": "Picture", "audio": "Sound"}

static var enabled: bool = true
static var _ids: int = 0


static func list(item: MediaItem) -> Array:
	if item == null:
		return []
	if not item.path.is_empty() and Store.has(item.path):
		return Store.regions(item.path)
	return item.regions


static func list_for_path(file_path: String) -> Array:
	return Store.regions(file_path)


static func sorted(src: Array) -> Array:
	var out: Array = []
	for r: Variant in src:
		if r is Dictionary:
			out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("from", 0.0)) < float(b.get("from", 0.0)) or (float(a.get("from", 0.0)) == float(b.get("from", 0.0)) and String(a.get("id", "")) < String(b.get("id", ""))))
	return out


static func mint() -> String:
	_ids += 1
	return "rg" + str(Time.get_unix_time_from_system()).replace(".", "").right(9) + "_" + str(_ids) + "_" + str(randi() % 100000)


static func make(kind: String, from: float, to: float, fields: Dictionary = {}) -> Dictionary:
	var r: Dictionary = fields.duplicate(true)
	r["id"] = String(fields.get("id", mint()))
	r["kind"] = kind
	r["from"] = maxf(minf(from, to), 0.0)
	r["to"] = maxf(from, to)
	if not r.has("lane"):
		r["lane"] = LANE_ALL
	return r


static func by_id(src: Array, region_id: String) -> Dictionary:
	for r: Variant in src:
		if r is Dictionary and String((r as Dictionary).get("id", "")) == region_id:
			return r
	return {}


static func acts_as_cut(r: Dictionary) -> bool:
	if r.has("cut"):
		return bool(r["cut"])
	return Kinds.cuts_by_default(String(r.get("kind", "")))


static func fn_of(r: Dictionary) -> String:
	var fn: String = Kinds.fn_of(String(r.get("kind", "")))
	if r.has("cut") and not bool(r["cut"]) and Kinds.CUTTING.has(fn):
		return Kinds.FN_NONE
	if r.has("cut") and bool(r["cut"]) and not Kinds.CUTTING.has(fn):
		return Kinds.FN_SPLIT
	return fn


static func colour_of(r: Dictionary) -> Color:
	var rgb: String = String(r.get("rgb", ""))
	if not rgb.is_empty() and Color.html_is_valid(rgb):
		return Color.from_string(rgb, Color.WHITE)
	return Kinds.colour_of(String(r.get("kind", "")))


static func replace(doc: Project, media_id: String, next: Array, label: String = "Regions") -> bool:
	if doc == null:
		return false
	var item: MediaItem = doc.media_by_id(media_id)
	if item == null:
		return false
	var cmds: Array[Command] = [OrganizerCmds.SetMediaRegions.new(media_id, sorted(next), label, item.path)]
	return Verbs.run(doc, label, cmds)


static func replace_for_path(doc: Project, file_path: String, next: Array, label: String = "Regions") -> bool:
	if doc == null or file_path.is_empty():
		return false
	var mid: String = ""
	for m: MediaItem in doc.media:
		if not m.path.is_empty() and Store.key_of(m.path) == Store.key_of(file_path):
			mid = m.id
			break
	var cmds: Array[Command] = [OrganizerCmds.SetMediaRegions.new(mid, sorted(next), label, file_path)]
	return Verbs.run(doc, label, cmds)


static func add(doc: Project, media_id: String, kind: String, from: float, to: float, fields: Dictionary = {}) -> String:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null or absf(to - from) < MIN_LENGTH:
		return ""
	var r: Dictionary = make(kind, from, to, fields)
	var dur: float = doc.media_duration(item)
	if dur > 0.0:
		r["to"] = minf(float(r["to"]), dur)
		if float(r["to"]) - float(r["from"]) < MIN_LENGTH:
			return ""
	var next: Array = list(item).duplicate(true)
	next.append(r)
	if not replace(doc, media_id, next, "Mark " + Kinds.name_of(kind)):
		return ""
	return String(r["id"])


static func add_many(doc: Project, media_id: String, made: Array, label: String) -> int:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null or made.is_empty():
		return 0
	var next: Array = list(item).duplicate(true)
	next.append_array(made)
	return made.size() if replace(doc, media_id, next, label) else 0


static func remove(doc: Project, media_id: String, region_ids: PackedStringArray) -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null or region_ids.is_empty():
		return false
	var next: Array = []
	for r: Variant in list(item):
		if r is Dictionary and not region_ids.has(String((r as Dictionary).get("id", ""))):
			next.append((r as Dictionary).duplicate(true))
	if next.size() == list(item).size():
		return false
	return replace(doc, media_id, next, "Remove region" if region_ids.size() == 1 else "Remove %d regions" % region_ids.size())


static func change(doc: Project, media_id: String, region_id: String, fields: Dictionary, label: String = "Change region") -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null:
		return false
	var next: Array = []
	var hit: bool = false
	for r: Variant in list(item):
		if not (r is Dictionary):
			continue
		var rd: Dictionary = (r as Dictionary).duplicate(true)
		if String(rd.get("id", "")) == region_id:
			hit = true
			for f: Variant in fields.keys():
				if fields[f] == null:
					rd.erase(f)
				else:
					rd[f] = fields[f]
			var a: float = float(rd.get("from", 0.0))
			var b: float = float(rd.get("to", 0.0))
			rd["from"] = maxf(minf(a, b), 0.0)
			rd["to"] = maxf(a, b)
			if float(rd["to"]) - float(rd["from"]) < MIN_LENGTH:
				return false
		next.append(rd)
	if not hit:
		return false
	return replace(doc, media_id, next, label)


static func swap_kinds(doc: Project, media_id: String, a_id: String, b_id: String) -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null:
		return false
	var a: Dictionary = by_id(list(item), a_id)
	var b: Dictionary = by_id(list(item), b_id)
	if a.is_empty() or b.is_empty():
		return false
	var next: Array = []
	for r: Variant in list(item):
		var rd: Dictionary = (r as Dictionary).duplicate(true)
		if String(rd["id"]) == a_id:
			rd["kind"] = String(b["kind"])
		elif String(rd["id"]) == b_id:
			rd["kind"] = String(a["kind"])
		next.append(rd)
	return replace(doc, media_id, next, "Swap regions")


static func covering(src: Array, t: float, lane: String = "*") -> Array:
	var out: Array = []
	for r: Variant in src:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		if lane != "*" and String(rd.get("lane", "")) != lane and String(rd.get("lane", "")) != LANE_ALL:
			continue
		if float(rd.get("from", 0.0)) <= t + EPS and float(rd.get("to", 0.0)) >= t - EPS:
			out.append(rd)
	return sorted(out)


static func overlapping(src: Array, region: Dictionary) -> Array:
	var out: Array = []
	var a: float = float(region.get("from", 0.0))
	var b: float = float(region.get("to", 0.0))
	for r: Variant in src:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		if String(rd.get("id", "")) == String(region.get("id", "")):
			continue
		if float(rd.get("from", 0.0)) < b - EPS and float(rd.get("to", 0.0)) > a + EPS:
			out.append(rd)
	return sorted(out)


static func stack_rows(src: Array) -> Dictionary:
	var rows: Dictionary = {}
	var ends: PackedFloat64Array = PackedFloat64Array()
	for r: Dictionary in sorted(src):
		var a: float = float(r.get("from", 0.0))
		var placed: int = -1
		for i: int in ends.size():
			if ends[i] <= a + EPS:
				placed = i
				break
		if placed < 0:
			placed = ends.size()
			ends.append(0.0)
		ends[placed] = float(r.get("to", 0.0))
		rows[String(r.get("id", ""))] = placed
	rows["_count"] = ends.size()
	return rows


static func of_kind(src: Array, kind: String) -> Array:
	var out: Array = []
	for r: Variant in src:
		if r is Dictionary and (kind.is_empty() or String((r as Dictionary).get("kind", "")) == kind):
			out.append(r)
	return sorted(out)


static func next_of_kind(src: Array, kind: String, t: float, dir: int) -> Dictionary:
	var pick: Dictionary = {}
	for r: Dictionary in of_kind(src, kind):
		var a: float = float(r.get("from", 0.0))
		if dir > 0 and a > t + EPS:
			return r
		if dir < 0 and a < t - EPS:
			pick = r
	return pick


static func hidden(item: MediaItem) -> PackedStringArray:
	if item == null:
		return PackedStringArray()
	return MediaItem._strings(item.props.get(HIDDEN_KEY, []))


static func is_hidden(item: MediaItem, region_id: String) -> bool:
	return hidden(item).has(region_id)


static func shown(item: MediaItem) -> Array:
	var off: PackedStringArray = hidden(item)
	if off.is_empty():
		return list(item)
	var out: Array = []
	for r: Variant in list(item):
		if r is Dictionary and not off.has(String((r as Dictionary).get("id", ""))):
			out.append(r)
	return out


static func hide_in_project(doc: Project, media_id: String, region_ids: PackedStringArray, on: bool = true) -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	if item == null:
		return false
	var off: PackedStringArray = hidden(item)
	for id: String in region_ids:
		if on and not off.has(id):
			off.append(id)
		elif not on and off.has(id):
			off.remove_at(off.find(id))
	var value: Variant = Array(off) if not off.is_empty() else null
	var cmds: Array[Command] = [OrganizerCmds.SetMediaProp.new(media_id, HIDDEN_KEY, value, "Hide region in the editor" if on else "Show region in the editor")]
	return Verbs.run(doc, String(cmds[0].label), cmds)


static func move_to(doc: Project, from_media_id: String, to_path: String, region_ids: PackedStringArray) -> int:
	var item: MediaItem = doc.media_by_id(from_media_id) if doc != null else null
	if item == null or to_path.is_empty() or Store.key_of(to_path) == Store.key_of(item.path):
		return 0
	var keep: Array = []
	var moving: Array = []
	for r: Variant in list(item):
		if not (r is Dictionary):
			continue
		var rd: Dictionary = (r as Dictionary).duplicate(true)
		if region_ids.is_empty() or region_ids.has(String(rd.get("id", ""))):
			moving.append(rd)
		else:
			keep.append(rd)
	if moving.is_empty():
		return 0
	var target_list: Array = Store.regions(to_path).duplicate(true)
	var target_id: String = ""
	for m: MediaItem in doc.media:
		if not m.path.is_empty() and Store.key_of(m.path) == Store.key_of(to_path):
			target_id = m.id
			if not Store.has(to_path):
				target_list = m.regions.duplicate(true)
			break
	target_list.append_array(moving)
	var cmds: Array[Command] = [
		OrganizerCmds.SetMediaRegions.new(from_media_id, sorted(keep), "Move regions", item.path),
		OrganizerCmds.SetMediaRegions.new(target_id, sorted(target_list), "Move regions", to_path),
	]
	if not Verbs.run(doc, "Move %d regions to %s" % [moving.size(), to_path.get_file()], cmds):
		return 0
	return moving.size()


static func clip_speed(c: Clip) -> float:
	if AnimProp.is_animated(c.speed):
		return 1.0
	return absf(float(c.speed.get("v", 1.0)))


static func on_clip(c: Clip, item: MediaItem, with_hidden: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not enabled or c == null or item == null or c.duration <= 0.0:
		return out
	var src: Array = list(item) if with_hidden else shown(item)
	if src.is_empty():
		return out
	var s0: float = c.source_in()
	var s1: float = c.source_out()
	var lo_s: float = minf(s0, s1)
	var hi_s: float = maxf(s0, s1)
	for r: Variant in src:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		var a: float = float(rd.get("from", 0.0))
		var b: float = float(rd.get("to", 0.0))
		if b <= lo_s + EPS or a >= hi_s - EPS:
			continue
		var ua: float = SourceMarks.local_of(c, maxf(a, lo_s))
		var ub: float = SourceMarks.local_of(c, minf(b, hi_s))
		if ua < -0.001 or ub < -0.001:
			continue
		var l0: float = clampf(minf(ua, ub), 0.0, c.duration)
		var l1: float = clampf(maxf(ua, ub), 0.0, c.duration)
		if l1 - l0 <= EPS:
			continue
		out.append({"region": rd, "from": l0, "to": l1})
	return out


static func at_clip_time(c: Clip, item: MediaItem, local_t: float) -> Array:
	var out: Array = []
	for e: Dictionary in on_clip(c, item):
		if float(e["from"]) <= local_t + EPS and float(e["to"]) >= local_t - EPS:
			out.append(e["region"])
	return out


static func count_in(doc: Project) -> int:
	var n: int = 0
	if doc == null:
		return n
	for m: MediaItem in doc.media:
		n += list(m).size()
	return n


static func kinds_in(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		for r: Variant in list(m):
			if r is Dictionary:
				var n: String = Kinds.name_of(String((r as Dictionary).get("kind", "")))
				if not out.has(n):
					out.append(n)
	return out
