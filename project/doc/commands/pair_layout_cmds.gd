extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const TrackGuard := preload("res://doc/track_guard.gd")
const NEW_TRACK := "+"
const OWN_LABEL := "Region on its own track"
const EDGE := 0.000001


static func path_of(uid: String, key: String) -> String:
	return "effects." + uid + "." + key


static func frame_px(s: Sequence) -> Vector2i:
	return Vector2i(maxi(s.width, 1), maxi(s.height, 1))


static func source_px(d: Project, s: Sequence, c: Clip) -> Vector2i:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if c.is_nest() or (m != null and m.kind == "sequence"):
		var ns: Sequence = d.sequence_by_id(c.sequence_id if c.is_nest() else m.sequence_id) if d != null else null
		if ns != null:
			return Vector2i(ns.width, ns.height)
	if m != null and m.width > 0 and m.height > 0:
		return Vector2i(m.width, m.height)
	return frame_px(s)


static func free_over(tr: Track, t0: float, t1: float) -> bool:
	for c: Clip in tr.clips:
		if c.start < t1 - EDGE and c.end() > t0 + EDGE:
			return false
	return true


static func track_choices(s: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or c == null:
		return out
	var own: Track = s.track_of(c.id)
	var list: Array[Track] = s.picture_tracks()
	var at: int = list.find(own)
	var above: Array[Dictionary] = []
	var below: Array[Dictionary] = []
	for i: int in list.size():
		var tr: Track = list[i]
		if tr == own or tr.locked or not tr.accepts(Track.PICTURE) or not TrackGuard.accepts(null, s, tr, TrackGuard.PLACE, c.media_id):
			continue
		var row: Dictionary = {"id": tr.id, "label": tr.shown_label(), "free": free_over(tr, c.start, c.end()), "above": i > at}
		if i > at:
			above.append(row)
		else:
			below.push_front(row)
	for r: Dictionary in above:
		if bool(r["free"]):
			out.append(r)
	for r2: Dictionary in below:
		if bool(r2["free"]):
			out.append(r2)
	for r3: Dictionary in above:
		if not bool(r3["free"]):
			out.append(r3)
	for r4: Dictionary in below:
		if not bool(r4["free"]):
			out.append(r4)
	return out


static func default_track(s: Sequence, c: Clip) -> String:
	for r: Dictionary in track_choices(s, c):
		if bool(r["free"]) and bool(r["above"]):
			return String(r["id"])
	return ""


static func shown_box(d: Project, s: Sequence, c: Clip, e: Dictionary, index: int, t: float) -> Dictionary:
	var src: Vector2i = source_px(d, s, c)
	var frame: Vector2i = frame_px(s)
	var at: float = clampf(t, c.start, maxf(c.end() - 0.0001, c.start))
	for b: Dictionary in PairLayout.region_boxes(c, e, at, frame, src, s.fps):
		if int(b["index"]) == index:
			return b
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	var r: Rect2 = (crops[index] as Dictionary)["rect"]
	var canvas: Vector2i = PairLayout.canvas_for(src, frame)
	var ca: float = float(canvas.x) / maxf(float(canvas.y), 1.0)
	var local: float = at - c.start
	var box: Rect2 = PairLayout.inset_box(PairLayout.region_aspect(r, Vector2(src)), ca, PairLayout.place_at(c, e, index, local, s.fps), PairLayout.size_at(c, e, index, local, s.fps))
	return {"index": index, "box": box, "source": r, "role": PairLayout.ROLE_INSET, "rot": float((crops[index] as Dictionary).get("rot", 0.0))}


static func crops_with(e: Dictionary, index: int, field: String, value: Variant) -> String:
	var raw: Variant = JSON.parse_string(PairLayout.crops_text(e).strip_edges())
	var list: Array = raw if raw is Array else []
	if list.is_empty():
		for cr: Dictionary in PairLayout.parse(""):
			var r: Rect2 = cr["rect"]
			list.append({"name": String(cr["name"]), "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
	if index >= 0 and index < list.size() and list[index] is Dictionary:
		var d: Dictionary = list[index]
		if field == PairLayout.OUT_KEY and not bool(value):
			d.erase(field)
		else:
			d[field] = value
	return JSON.stringify(list)


static func own_track_clips(s: Sequence, c: Clip, uid: String) -> Dictionary:
	var out: Dictionary = {}
	if s == null or c == null or c.link_id.is_empty():
		return out
	for other: Clip in s.linked(c):
		if other == c or other.media_id != c.media_id:
			continue
		var oe: Dictionary = other.effect_by_uid(uid)
		if oe.is_empty():
			continue
		var solo: int = PairLayout.solo_of(oe)
		if solo >= 0 and not out.has(solo):
			out[solo] = other
	return out


class RegionOwnTrack extends "res://doc/commands/composite.gd":
	const PairLayout := preload("res://engine/pair_layout.gd")
	const Outer := preload("res://doc/commands/pair_layout_cmds.gd")

	var clip_id: String = ""
	var uid: String = ""
	var index: int = 0
	var track_id: String = ""
	var at: float = 0.0
	var made_clip: String = ""
	var made_track: String = ""

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_index: int, p_track_id: String, p_at: float) -> void:
		label = Outer.OWN_LABEL
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		index = p_index
		track_id = p_track_id
		at = p_at

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		var c: Clip = s.clip_by_id(clip_id) if s != null else null
		if c == null:
			return false
		var e: Dictionary = c.effect_by_uid(uid)
		var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
		if e.is_empty() or index < 0 or index >= mini(crops.size(), PairLayout.REGION_MAX):
			return false
		var shown: Dictionary = Outer.shown_box(doc, s, c, e, index, at)
		var tr: Track = _target(doc, s, c, String((crops[index] as Dictionary).get("name", "")))
		if tr == null:
			return false
		var link: String = c.link_id
		if link.is_empty():
			link = doc.mint_id("l")
			apply(doc, ClipCmds.SetClipField.new(seq_id, c.id, "link_id", link))
		var d: Dictionary = c.to_dict()
		made_clip = doc.mint_id("c")
		d["id"] = made_clip
		d["link_id"] = link
		d["part"] = tr.part_for(Track.PICTURE)
		var name_: String = String((crops[index] as Dictionary).get("name", ""))
		d["label"] = c.label + " (" + (name_ if not name_.strip_edges().is_empty() else "View " + str(index + 1)) + ")"
		_fix_entry(doc, s, c, e, d, shown)
		apply(doc, ClipCmds.PlaceClip.new(seq_id, tr.id, d))
		if s.clip_by_id(made_clip) == null:
			return false
		var out_text: String = Outer.crops_with(e, index, PairLayout.OUT_KEY, true)
		if out_text != PairLayout.crops_text(e):
			apply(doc, ClipCmds.SetClipParam.new(seq_id, c.id, Outer.path_of(uid, "crops"), AnimProp.make(out_text)))
		return true

	func _target(doc: Project, s: Sequence, c: Clip, region_name: String) -> Track:
		var want: String = track_id
		if want.is_empty():
			want = Outer.default_track(s, c)
		if not want.is_empty() and want != Outer.NEW_TRACK:
			var tr: Track = s.track_by_id(want)
			if tr == null or tr.locked or not tr.accepts(Track.PICTURE) or not Outer.free_over(tr, c.start, c.end()):
				return null
			return tr
		var own: Track = s.track_of(c.id)
		var list: Array[Track] = s.tracks_of_kind(Track.PICTURE)
		var at_index: int = list.find(own) + 1 if list.has(own) else list.size()
		var label_: String = region_name.strip_edges()
		if label_.is_empty():
			label_ = "V" + str(list.size() + 1)
		var made: Track = doc.make_track(Track.PICTURE, label_)
		apply(doc, TrackCmds.AddTrack.new(seq_id, Track.PICTURE, at_index, made.to_dict()))
		made_track = made.id
		return s.track_by_id(made.id)

	func _fix_entry(doc: Project, s: Sequence, c: Clip, e: Dictionary, d: Dictionary, shown: Dictionary) -> void:
		var list: Array = d.get("effects", [])
		for k: int in list.size():
			var fx: Dictionary = list[k]
			if String(fx.get("uid", "")) != uid:
				continue
			var params: Dictionary = (fx.get("params", {}) as Dictionary).duplicate(true)
			var src: Vector2i = Outer.source_px(doc, s, c)
			var canvas: Vector2i = PairLayout.canvas_for(src, Outer.frame_px(s))
			var ca: float = float(canvas.x) / maxf(float(canvas.y), 1.0)
			var box: Rect2 = shown["box"]
			var part: Rect2 = shown["source"]
			var role: String = String(shown.get("role", ""))
			var turned: bool = absf(float(shown.get("rot", 0.0))) > 0.01
			var crop_text: String = PairLayout.crops_text(e)
			if role != PairLayout.ROLE_INSET and not turned and part.size.x > 0.0 and part.size.y > 0.0:
				crop_text = Outer.crops_with({"params": {"crops": AnimProp.make(crop_text)}}, index, "rect", [part.position.x, part.position.y, part.size.x, part.size.y])
			else:
				part = (PairLayout.parse(crop_text)[index] as Dictionary)["rect"]
			crop_text = Outer.crops_with({"params": {"crops": AnimProp.make(crop_text)}}, index, PairLayout.OUT_KEY, false)
			params["crops"] = AnimProp.make(crop_text)
			var placed: Dictionary = PairLayout.centre_for_size(PairLayout.region_aspect(part, Vector2(src)), ca, box)
			var place_path: String = PairLayout.place_key(index)
			var size_path: String = PairLayout.size_key(index)
			var pp: Variant = params.get(place_path, null)
			var sp: Variant = params.get(size_path, null)
			var keyed: bool = role == PairLayout.ROLE_INSET and ((pp is Dictionary and AnimProp.is_animated(pp)) or (sp is Dictionary and AnimProp.is_animated(sp)))
			if not keyed:
				var centre: Vector2 = placed["centre"]
				params[place_path] = AnimProp.make([centre.x, centre.y])
				params[size_path] = AnimProp.make(clampf(float(placed["size"]), PairLayout.SIZE_MIN, PairLayout.SIZE_MAX))
			params[PairLayout.SOLO_KEY] = AnimProp.make(float(index))
			params["view"] = AnimProp.make(float(index))
			params["view_mode"] = AnimProp.make(0.0)
			params["view_audio"] = AnimProp.make("")
			params["view_cuts"] = AnimProp.make(false)
			params[PairLayout.LAYOUT_KEY] = AnimProp.make(float(PairLayout.FULL))
			params["grid"] = AnimProp.make(false)
			fx["params"] = params
			list[k] = fx
		d["effects"] = list


class SetSolo extends "res://doc/commands/clip_cmds.gd".SetClipParam:
	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_index: int) -> void:
		super(p_seq_id, p_clip_id, "effects." + p_uid + ".solo", AnimProp.make(float(p_index)))
		label = "Show all regions" if p_index < 0 else "Show one region"
