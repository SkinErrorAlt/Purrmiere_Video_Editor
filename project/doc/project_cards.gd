extends RefCounted

const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const Command := preload("res://doc/commands/command.gd")
const Store := preload("res://doc/region_store.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const DIR := "organizer"
const CARDS_FILE := "cards.json"
const RATINGS_FILE := "ratings.json"
const THUMBS_DIR := "thumbs"
const INFO_RATING := "rating"
const INFO_THUMB := "thumb"
const INFO_FINISHED := "finished"
const PREMADE := "premade:"
const PREMADE_COUNT := 8
const PREMADE_COLOURS: Array = [
	["#2b1d4d", "#d06f9f"], ["#0f3443", "#34e89e"], ["#41295a", "#2f0743"], ["#1f4037", "#99f2c8"],
	["#373b44", "#4286f4"], ["#614385", "#516395"], ["#cb356b", "#bd3f32"], ["#232526", "#f2c84b"],
]
const MAX_SCORE := 10.0
const DEFAULT_PRESET := {"id": "editing", "name": "Editing", "sections": [
	{"id": "story", "name": "Story", "on": true}, {"id": "pacing", "name": "Pacing", "on": true},
	{"id": "cuts", "name": "Cuts", "on": true}, {"id": "sound", "name": "Sound", "on": true},
	{"id": "effects", "name": "Effects", "on": true}, {"id": "colour", "name": "Colour", "on": true},
	{"id": "fun", "name": "Fun to watch", "on": true},
]}

static var _cards: Dictionary = {}
static var _cards_loaded: bool = false
static var _ratings: Dictionary = {}
static var _ratings_loaded: bool = false
static var _root_override: String = ""
static var _facts: Dictionary = {}
static var _task: int = -1
static var _task_out: Array = []
static var serial: int = 0


static func root() -> String:
	return _root_override if not _root_override.is_empty() else Io.data_path(DIR)


static func use_root(p: String) -> void:
	_root_override = p
	_cards_loaded = false
	_ratings_loaded = false
	_cards = {}
	_ratings = {}
	_facts = {}


static func key_of(path: String) -> String:
	return Io.recent_key(path) if not path.is_empty() else ""


static func cards() -> Dictionary:
	if _cards_loaded:
		return _cards
	var d: Dictionary = Io.read_json(root().path_join(CARDS_FILE))
	if not (d.get("cards") is Dictionary):
		d = {"version": 1, "cards": {}}
	_cards = d
	_cards_loaded = true
	return _cards


static func save_cards() -> bool:
	DirAccess.make_dir_recursive_absolute(root())
	serial += 1
	return Io.write_atomic(root().path_join(CARDS_FILE), JSON.stringify(cards(), "\t", false, true), false) == OK


static func card(path: String) -> Dictionary:
	var all: Dictionary = cards()["cards"]
	var k: String = key_of(path)
	var v: Variant = all.get(k, {})
	var c: Dictionary = v if v is Dictionary else {}
	all[k] = c
	return c


static func set_field(path: String, field: String, value: Variant, pending: bool = true) -> void:
	var c: Dictionary = card(path)
	if value == null:
		c.erase(field)
	else:
		c[field] = value
	if pending:
		var p: Array = c.get("pending", []) if c.get("pending") is Array else []
		if not p.has(field):
			p.append(field)
		c["pending"] = p
	c["path"] = path
	save_cards()


static func value(path: String, field: String, facts: Dictionary, fallback: Variant) -> Variant:
	var c: Dictionary = card(path)
	if c.has(field):
		return c[field]
	var info: Dictionary = facts.get("info", {}) if facts.get("info") is Dictionary else {}
	if field == "description":
		return String(facts.get("description", fallback))
	return info.get(field, fallback)


static func adopt(doc: Project) -> int:
	if doc == null or doc.path.is_empty():
		return 0
	var c: Dictionary = card(doc.path)
	var pending: Array = c.get("pending", []) if c.get("pending") is Array else []
	if pending.is_empty():
		return 0
	var fields: Dictionary = {}
	for f: Variant in pending:
		fields[String(f)] = c.get(String(f), null)
	var cmds: Array[Command] = [SetProjectCard.new(fields)]
	var ok: bool = load("res://doc/verbs.gd").call("run", doc, "Project card from the start screen", cmds)
	c.erase("pending")
	save_cards()
	return fields.size() if ok else 0


static func write_to(doc: Project, fields: Dictionary, label: String = "Project card") -> bool:
	if doc == null:
		return false
	var cmds: Array[Command] = [SetProjectCard.new(fields)]
	var ok: bool = load("res://doc/verbs.gd").call("run", doc, label, cmds)
	if ok and not doc.path.is_empty():
		for f: Variant in fields.keys():
			set_field(doc.path, String(f), fields[f], false)
	return ok


static func ratings() -> Dictionary:
	if _ratings_loaded:
		return _ratings
	var d: Dictionary = Io.read_json(root().path_join(RATINGS_FILE))
	if not (d.get("presets") is Array) or (d["presets"] as Array).is_empty():
		d = {"version": 1, "presets": [DEFAULT_PRESET.duplicate(true)], "default": "editing"}
	_ratings = d
	_ratings_loaded = true
	return _ratings


static func save_ratings() -> bool:
	DirAccess.make_dir_recursive_absolute(root())
	serial += 1
	return Io.write_atomic(root().path_join(RATINGS_FILE), JSON.stringify(ratings(), "\t", false, true), false) == OK


static func presets() -> Array:
	return ratings()["presets"]


static func preset(id: String) -> Dictionary:
	for p: Variant in presets():
		if String((p as Dictionary).get("id", "")) == id:
			return p
	return presets()[0]


static func default_preset() -> String:
	return String(ratings().get("default", String((presets()[0] as Dictionary)["id"])))


static func add_preset(name: String, from_id: String = "") -> Dictionary:
	var n: String = name.strip_edges()
	if n.is_empty():
		return {}
	var base: Dictionary = preset(from_id) if not from_id.is_empty() else DEFAULT_PRESET
	var p: Dictionary = {"id": "p" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000), "name": n, "sections": (base["sections"] as Array).duplicate(true)}
	presets().append(p)
	save_ratings()
	return p


static func add_section(preset_id: String, name: String) -> String:
	var n: String = name.strip_edges()
	if n.is_empty():
		return ""
	var p: Dictionary = preset(preset_id)
	var id: String = "s" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	(p["sections"] as Array).append({"id": id, "name": n, "on": true})
	save_ratings()
	return id


static func set_section_on(preset_id: String, section_id: String, on: bool) -> void:
	for s: Variant in preset(preset_id)["sections"]:
		if String((s as Dictionary)["id"]) == section_id:
			(s as Dictionary)["on"] = on
	save_ratings()


static func remove_section(preset_id: String, section_id: String) -> void:
	var list: Array = preset(preset_id)["sections"]
	for i: int in range(list.size() - 1, -1, -1):
		if String((list[i] as Dictionary)["id"]) == section_id:
			list.remove_at(i)
	save_ratings()


static func rating_of(path: String, facts: Dictionary) -> Dictionary:
	var v: Variant = value(path, INFO_RATING, facts, {})
	var r: Dictionary = (v as Dictionary).duplicate(true) if v is Dictionary else {}
	if not r.has("preset"):
		r["preset"] = default_preset()
	if not (r.get("scores") is Dictionary):
		r["scores"] = {}
	if not (r.get("off") is Array):
		r["off"] = []
	if not (r.get("own") is Array):
		r["own"] = []
	return r


static func sections_of(r: Dictionary) -> Array:
	var out: Array = []
	var off: Array = r.get("off", [])
	for s: Variant in preset(String(r.get("preset", "")))["sections"]:
		var sd: Dictionary = s
		if bool(sd.get("on", true)) and not off.has(String(sd["id"])):
			out.append(sd)
	for s: Variant in r.get("own", []):
		if s is Dictionary and not off.has(String((s as Dictionary).get("id", ""))):
			out.append(s)
	return out


static func overall(r: Dictionary) -> float:
	var scores: Dictionary = r.get("scores", {})
	var total: float = 0.0
	var n: int = 0
	for s: Variant in sections_of(r):
		var id: String = String((s as Dictionary)["id"])
		if scores.has(id):
			total += clampf(float(scores[id]), 0.0, MAX_SCORE)
			n += 1
	return total / float(n) if n > 0 else -1.0


static func set_score(r: Dictionary, section_id: String, score: float) -> Dictionary:
	var out: Dictionary = r.duplicate(true)
	var scores: Dictionary = out.get("scores", {})
	if score < 0.0:
		scores.erase(section_id)
	else:
		scores[section_id] = clampf(snappedf(score, 0.5), 0.0, MAX_SCORE)
	out["scores"] = scores
	return out


static func save_rating(path: String, r: Dictionary, doc: Project = null) -> void:
	if doc != null and key_of(doc.path) == key_of(path):
		write_to(doc, {INFO_RATING: r}, "Rate the project")
		return
	set_field(path, INFO_RATING, r)


static func apply_preset(paths: PackedStringArray, preset_id: String, facts: Dictionary, doc: Project = null) -> int:
	var n: int = 0
	for p: String in paths:
		var r: Dictionary = rating_of(p, facts.get(key_of(p), {}))
		r["preset"] = preset_id
		save_rating(p, r, doc)
		n += 1
	return n


static func premade_index(thumb: String) -> int:
	if not thumb.begins_with(PREMADE):
		return -1
	return clampi(int(thumb.substr(PREMADE.length())), 0, PREMADE_COUNT - 1)


static func premade_image(index: int, w: int = 320, h: int = 180) -> Image:
	var pair: Array = PREMADE_COLOURS[clampi(index, 0, PREMADE_COUNT - 1)]
	var a: Color = Color.from_string(String(pair[0]), Color.BLACK)
	var b: Color = Color.from_string(String(pair[1]), Color.WHITE)
	var sw: int = 32
	var sh: int = 18
	var img: Image = Image.create(sw, sh, false, Image.FORMAT_RGB8)
	for y: int in sh:
		for x: int in sw:
			var u: float = (float(x) / float(sw - 1) * 0.7 + float(y) / float(sh - 1) * 0.3)
			img.set_pixel(x, y, a.lerp(b, u))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


static func thumb_path_for(project_id: String) -> String:
	return root().path_join(THUMBS_DIR).path_join((project_id if not project_id.is_empty() else "project") + ".png")


static func save_thumb(project_id: String, img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	var p: String = thumb_path_for(project_id + "_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var small: Image = img.duplicate()
	if small.get_width() > 480:
		small.resize(480, maxi(int(480.0 * float(small.get_height()) / float(small.get_width())), 1), Image.INTERPOLATE_BILINEAR)
	return p if small.save_png(p) == OK else ""


static func facts_of(d: Dictionary, path: String) -> Dictionary:
	var media: Array = d.get("media", []) if d.get("media") is Array else []
	var videos: int = 0
	var tags: PackedStringArray = PackedStringArray()
	var kinds: PackedStringArray = PackedStringArray()
	for m: Variant in media:
		if not (m is Dictionary):
			continue
		var md: Dictionary = m
		var k: String = String(md.get("kind", ""))
		if k == "video" or k == "audio" or k == "image":
			videos += 1
		for t: Variant in md.get("tags", []):
			if not tags.has(str(t)):
				tags.append(str(t))
		for r: Variant in md.get("regions", []):
			if r is Dictionary:
				var kid: String = String((r as Dictionary).get("kind", ""))
				if not kinds.has(kid):
					kinds.append(kid)
	for s: Variant in d.get("sequences", []):
		if not (s is Dictionary):
			continue
		for key: String in ["video_tracks", "audio_tracks"]:
			for t: Variant in (s as Dictionary).get(key, []):
				if not (t is Dictionary):
					continue
				for c: Variant in (t as Dictionary).get("clips", []):
					if c is Dictionary:
						for tg: Variant in (c as Dictionary).get("tags", []):
							if not tags.has(str(tg)):
								tags.append(str(tg))
	for t: Variant in d.get("tags", []):
		if not tags.has(str(t)):
			tags.append(str(t))
	var seqs: Array = d.get("sequences", []) if d.get("sequences") is Array else []
	return {
		"ok": not d.is_empty(), "path": path, "id": String(d.get("id", "")), "name": String(d.get("name", path.get_file().get_basename())),
		"description": String(d.get("description", "")), "info": (d.get("info", {}) as Dictionary).duplicate(true) if d.get("info") is Dictionary else {},
		"clips": Io.count_clips(d), "media": videos, "sequences": seqs.size(), "tags": tags, "kinds": kinds,
		"created": String(d.get("created", "")), "modified": String(d.get("modified", "")),
		"file_time": FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0,
	}


static func region_names(f: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: String in (f.get("kinds", PackedStringArray()) as PackedStringArray):
		out.append(Kinds.name_of(k))
	return out


static func cached(path: String) -> Dictionary:
	var hit: Variant = _facts.get(key_of(path), null)
	return hit if hit is Dictionary else {}


static func want(paths: PackedStringArray) -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		for f: Variant in _task_out:
			_facts[key_of(String((f as Dictionary)["path"]))] = f
		_task_out = []
		serial += 1
	var missing: PackedStringArray = PackedStringArray()
	for p: String in paths:
		var c: Dictionary = cached(p)
		var t: int = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else 0
		if c.is_empty() or int(c.get("file_time", -1)) != t:
			missing.append(p)
	if missing.is_empty():
		return true
	var out: Array = []
	_task_out = out
	_task = WorkerThreadPool.add_task(_read_all.bind(missing, out), false, "Project cards")
	return false


static func _read_all(paths: PackedStringArray, out: Array) -> void:
	for p: String in paths:
		out.append(facts_of(Io.read_json(p), p))


static func busy() -> bool:
	return _task >= 0


class SetProjectCard extends "res://doc/commands/command.gd":
	var fields: Dictionary = {}
	var old_info: Dictionary = {}
	var old_desc: String = ""

	func _init(p_fields: Dictionary) -> void:
		label = "Project card"
		fields = p_fields.duplicate(true)

	func do(doc: Project) -> void:
		old_info = doc.info.duplicate(true)
		old_desc = doc.description
		for f: Variant in fields.keys():
			var k: String = String(f)
			var v: Variant = fields[f]
			if k == "description":
				doc.description = String(v) if v != null else ""
			elif v == null:
				doc.info.erase(k)
			else:
				doc.info[k] = dup(v)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		doc.info = old_info.duplicate(true)
		doc.description = old_desc
		doc.touch("meta")
