extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const Store := preload("res://doc/region_store.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Smart := preload("res://doc/smart_folders.gd")
const BAD_CHARS: PackedStringArray = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]


static func safe_name(text: String) -> String:
	var out: String = text.strip_edges()
	for ch: String in BAD_CHARS:
		out = out.replace(ch, " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges()
	return out if not out.is_empty() else "part"


static func clock_name(t: float) -> String:
	var whole: int = int(floor(maxf(t, 0.0)))
	return "%dm%02ds" % [whole / 60, whole % 60] if whole < 3600 else "%dh%02dm%02ds" % [whole / 3600, (whole % 3600) / 60, whole % 60]


static func part_name(kind: String, n: int, file_path: String, from: float, prefix: String = "") -> String:
	var head: String = prefix.strip_edges() if not prefix.strip_edges().is_empty() else Kinds.name_of(kind)
	return safe_name("%s %02d %s %s" % [head, n, file_path.get_file().get_basename(), clock_name(from)])


static func media_for(doc: Project, file_path: String) -> MediaItem:
	if doc == null:
		return null
	var key: String = Store.key_of(file_path)
	for m: MediaItem in doc.media:
		if not m.path.is_empty() and Store.key_of(m.path) == key and not m.props.has("still_time"):
			return m
	return null


static func media_dict(doc: Project, file_path: String) -> Dictionary:
	var e: Dictionary = Store.entry(file_path)
	var d: Dictionary = {"id": doc.mint_id("m"), "path": file_path, "label": String(e.get("label", file_path.get_file())), "kind": String(e.get("kind", "video"))}
	var dur: float = float(e.get("duration", 0.0))
	if dur > 0.0:
		d["probed"] = true
		d["duration"] = dur
		d["fps"] = float(e.get("fps", 0.0))
		d["width"] = int(e.get("width", 0))
		d["height"] = int(e.get("height", 0))
		d["has_audio"] = bool(e.get("has_audio", false))
		if e.get("audio_streams") is Array:
			d["audio_streams"] = (e["audio_streams"] as Array).duplicate(true)
	if float(e.get("recorded", -1.0)) >= 0.0:
		d["recorded_at"] = float(e["recorded"])
	return d


static func ensure_media(doc: Project, paths: PackedStringArray, label: String = "Bring in videos") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	var cmds: Array[Command] = []
	for p: String in paths:
		var m: MediaItem = media_for(doc, p)
		if m != null:
			out.append(m.id)
			continue
		var d: Dictionary = media_dict(doc, p)
		cmds.append(MediaCmds.AddMedia.new(d))
		out.append(String(d["id"]))
	if not cmds.is_empty():
		var tx: RefCounted = doc.undo.begin(label)
		for c: Command in cmds:
			tx.call("apply", c)
		tx.call("commit")
	return out


static func parts_sequence(doc: Project, kind: String, title: String = "") -> String:
	if doc == null:
		return ""
	var parts: Array[Dictionary] = Smart.parts(kind, doc)
	if parts.is_empty():
		return ""
	var paths: PackedStringArray = PackedStringArray()
	for p: Dictionary in parts:
		if not paths.has(String(p["path"])):
			paths.append(String(p["path"]))
	var name: String = title if not title.strip_edges().is_empty() else Kinds.name_of(kind) + " parts"
	var tx: RefCounted = doc.undo.begin("Put the " + Kinds.name_of(kind) + " parts in a new sequence")
	var ids: Dictionary = {}
	for p: String in paths:
		var m: MediaItem = media_for(doc, p)
		if m == null:
			var d: Dictionary = media_dict(doc, p)
			tx.call("apply", MediaCmds.AddMedia.new(d))
			m = doc.media_by_id(String(d["id"]))
		if m != null:
			ids[p] = m.id
	var model: Sequence = doc.active_sequence()
	var s: Sequence = Sequence.new()
	s.id = doc.mint_id("s")
	s.label = name
	s.fps = model.fps if model != null else 30.0
	if model != null:
		s.width = model.width
		s.height = model.height
	s.video_tracks.append(doc.make_track("video", "V1"))
	s.audio_tracks.append(doc.make_track("audio", "A1"))
	s.audio_tracks.append(doc.make_track("audio", "A2"))
	var seq_item: Dictionary = {"id": doc.mint_id("m"), "kind": "sequence", "label": name, "sequence_id": s.id, "probed": true}
	tx.call("apply", SequenceCmds.AddSequence.new(s.to_dict(), seq_item, -1, true))
	var t: float = 0.0
	for p: Dictionary in parts:
		var mid: String = String(ids.get(String(p["path"]), ""))
		var m2: MediaItem = doc.media_by_id(mid)
		if m2 == null:
			continue
		var r: Dictionary = p["region"]
		var a: float = float(r.get("from", 0.0))
		var b: float = float(r.get("to", 0.0))
		if b - a <= 0.001:
			continue
		var link: String = doc.mint_id("l") if m2.has_audio else ""
		var label: String = part_name(kind, int(p["index"]), String(p["path"]), a)
		var vd: Dictionary = {"id": doc.mint_id("c"), "media_id": mid, "label": label, "start": t, "duration": b - a, "in_offset": a}
		if not link.is_empty():
			vd["link_id"] = link
		if m2.has_picture():
			tx.call("apply", ClipCmds.PlaceClip.new(s.id, s.video_tracks[0].id, vd))
		if m2.has_audio or m2.kind == "audio":
			var ad: Dictionary = {"id": doc.mint_id("c"), "media_id": mid, "label": label, "start": t, "duration": b - a, "in_offset": a, "audio": {"stream": 0.0}}
			if not link.is_empty():
				ad["link_id"] = link
			tx.call("apply", ClipCmds.PlaceClip.new(s.id, s.audio_tracks[0].id, ad))
		t += b - a
	if not bool(tx.call("commit")):
		return ""
	return s.id


static func clipcut_jobs(kind: String, out_root: String, folder_name: String = "", prefix: String = "", doc: Project = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: String = out_root.path_join(safe_name(folder_name if not folder_name.strip_edges().is_empty() else Kinds.name_of(kind)))
	var n: int = 0
	for e: Dictionary in Smart.entries(kind, doc):
		var ranges: Array = []
		for r: Variant in e["regions"]:
			n += 1
			var rd: Dictionary = r
			ranges.append({"name": part_name(kind, n, String(e["path"]), float(rd.get("from", 0.0)), prefix), "in": float(rd.get("from", 0.0)), "out": float(rd.get("to", 0.0))})
		if not ranges.is_empty():
			out.append({"source": String(e["path"]), "ranges": ranges, "out_dir": dir, "mode": "keyframe", "audio": "copy", "container": String(e["path"]).get_extension().to_lower() if ["mp4", "mov", "mkv"].has(String(e["path"]).get_extension().to_lower()) else "mp4"})
	return out


static func frame_plan(kind: String, out_root: String, per_second: float, folder_names: PackedStringArray = PackedStringArray(), doc: Project = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var step: float = 1.0 / maxf(per_second, 0.01)
	var n: int = 0
	var root: String = out_root.path_join(safe_name(Kinds.name_of(kind) + " frames"))
	for p: Dictionary in Smart.parts(kind, doc):
		var r: Dictionary = p["region"]
		var named: String = folder_names[n] if n < folder_names.size() and not folder_names[n].strip_edges().is_empty() else part_name(kind, n + 1, String(p["path"]), float(r.get("from", 0.0)))
		n += 1
		var times: PackedFloat64Array = PackedFloat64Array()
		var t: float = float(r.get("from", 0.0))
		while t < float(r.get("to", 0.0)) - 0.0005 and times.size() < 5000:
			times.append(t)
			t += step
		out.append({"path": String(p["path"]), "dir": root.path_join(safe_name(named)), "times": times})
	return out
