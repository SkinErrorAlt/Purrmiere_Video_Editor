extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const SubProjects := preload("res://doc/sub_projects.gd")
const StreamOff := preload("res://doc/stream_off.gd")
const CaptureTime := preload("res://modules/core_panels/bin_views/capture_time.gd")
const VIDEO_EXT: PackedStringArray = ["mp4", "mov", "mkv", "webm", "avi", "m4v", "mts", "m2ts", "mpg", "mpeg", "wmv", "flv", "gif"]
const AUDIO_EXT: PackedStringArray = ["wav", "mp3", "flac", "ogg", "aac", "m4a", "opus", "aif", "aiff", "wma"]
const IMAGE_EXT: PackedStringArray = ["png", "jpg", "jpeg", "bmp", "webp", "tga", "exr", "hdr", "svg"]
const PREF_STILL := "bin.still_seconds"

static var _instance: RefCounted = null
static var _pending: Dictionary = {}
static var _connected: bool = false
static var _raw_info: Dictionary = {}
static var _profile: Dictionary = {}
static var defer_enabled: bool = true
static var _deferred: PackedStringArray = PackedStringArray()
static var _in_flight: Dictionary = {}
static var _park_on_ready: Dictionary = {}
static var _defer_doc: WeakRef = null
static var _pump_queued: bool = false
static var _defer_stats: Dictionary = {}
static var scope_enabled: bool = true
static var _scoped_out: Dictionary = {}
static var _scope_doc: WeakRef = null
static var _scope_group: String = ""
static var _scope_stats: Dictionary = {}
static var _scope_parked: Dictionary = {}
static var _scope_seen: String = ""


static func profile_reset() -> void:
	_profile = {"add_ms": 0.0, "open_ms": 0.0, "info_ms": 0.0, "apply_ms": 0.0, "opens": 0, "shared": 0, "applies": 0}


static func profile() -> Dictionary:
	if _profile.is_empty():
		profile_reset()
	return _profile.duplicate()


static func _spend(key: String, from_usec: int) -> void:
	if _profile.is_empty():
		profile_reset()
	_profile[key] = float(_profile.get(key, 0.0)) + float(Time.get_ticks_usec() - from_usec) / 1000.0


static func _tick(key: String) -> void:
	if _profile.is_empty():
		profile_reset()
	_profile[key] = int(_profile.get(key, 0)) + 1


static func instance() -> RefCounted:
	if _instance == null:
		var script: GDScript = load("res://modules/core_panels/media_loader.gd")
		_instance = script.new()
	return _instance


static func kind_for(path: String) -> String:
	var ext: String = path.get_extension().to_lower()
	if ext in VIDEO_EXT:
		return "video"
	if ext in AUDIO_EXT:
		return "audio"
	if ext in IMAGE_EXT:
		return "image"
	return ""


static func still_seconds() -> float:
	if not Prefs.is_registered(PREF_STILL):
		Prefs.register(PREF_STILL, 5.0, {"label": "Default still image length (seconds)", "type": "float", "min": 0.1, "max": 600.0})
	return float(Prefs.get_value(PREF_STILL))


static func filters() -> PackedStringArray:
	var all: PackedStringArray = PackedStringArray()
	var v: PackedStringArray = PackedStringArray()
	var a: PackedStringArray = PackedStringArray()
	var i: PackedStringArray = PackedStringArray()
	for e: String in VIDEO_EXT:
		v.append("*." + e)
		all.append("*." + e)
	for e: String in AUDIO_EXT:
		a.append("*." + e)
		all.append("*." + e)
	for e: String in IMAGE_EXT:
		i.append("*." + e)
		all.append("*." + e)
	return PackedStringArray([
		",".join(all) + " ; Media",
		",".join(v) + " ; Video",
		",".join(a) + " ; Audio",
		",".join(i) + " ; Images",
		"* ; All files",
	])


func _ensure_bridge() -> void:
	if _connected:
		return
	_connected = true
	if not PurrBridge.media_ready.is_connected(_on_media_ready):
		PurrBridge.media_ready.connect(_on_media_ready)
	if not PurrBridge.media_failed.is_connected(_on_media_failed):
		PurrBridge.media_failed.connect(_on_media_failed)


const TREE_CAP := 20000


static func is_folder(p: String) -> bool:
	return DirAccess.dir_exists_absolute(p)


static func walk_tree(root: String, bin_root: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stack: Array = [[root, bin_root]]
	while not stack.is_empty() and out.size() < TREE_CAP:
		var top: Array = stack.pop_back()
		var dir_path: String = String(top[0])
		var bin_path: String = String(top[1])
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.include_hidden = false
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		var subs: Array = []
		while not entry.is_empty():
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				subs.append([full, (bin_path + "/" + entry) if not bin_path.is_empty() else entry])
			elif not kind_for(full).is_empty():
				out.append({"path": full, "bin": bin_path})
			entry = dir.get_next()
		dir.list_dir_end()
		subs.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) > String(b[0]))
		for sub: Array in subs:
			stack.append(sub)
	return out


func import_folder(doc: Project, folder: String, bin: String) -> PackedStringArray:
	if doc == null or folder.is_empty():
		return PackedStringArray()
	var name_: String = folder.get_file() if not folder.get_file().is_empty() else folder.trim_suffix("/").get_file()
	if name_.is_empty():
		name_ = "Folder"
	var bin_root: String = (bin + "/" + name_) if not bin.is_empty() else name_
	var entries: Array[Dictionary] = walk_tree(folder, bin_root)
	if entries.is_empty():
		Events.warn("Nothing to import in " + name_, "No video, audio or image files were found")
		return PackedStringArray()
	if entries.size() >= TREE_CAP:
		Events.warn("Folder import stopped at " + str(TREE_CAP) + " files", folder)
	return import_entries(doc, entries, "Import folder " + name_)


func import_paths(doc: Project, paths: PackedStringArray, bin: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or paths.is_empty():
		return out
	var entries: Array[Dictionary] = []
	var folders: PackedStringArray = PackedStringArray()
	for p: String in paths:
		if is_folder(p):
			folders.append(p)
		else:
			entries.append({"path": p, "bin": bin})
	if not entries.is_empty():
		var label: String = "Import " + str(entries.size()) + " items" if entries.size() > 1 else "Import " + String(entries[0]["path"]).get_file()
		out.append_array(import_entries(doc, entries, label))
	for f: String in folders:
		out.append_array(import_folder(doc, f, bin))
	return out


func import_entries(doc: Project, entries: Array[Dictionary], label: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or entries.is_empty():
		return out
	var cmds: Array[Command] = []
	var dicts: Array[Dictionary] = []
	var bins_made: Dictionary = {}
	var by_path: Dictionary = {}
	for m: MediaItem in doc.media:
		by_path[m.path] = m.id
	for e: Dictionary in entries:
		var p: String = String(e.get("path", ""))
		var bin: String = String(e.get("bin", ""))
		var kind: String = kind_for(p)
		if kind.is_empty():
			Events.warn("Skipped " + p.get_file(), "The file type is not one this editor opens")
			continue
		if not bin.is_empty() and not doc.bins.has(bin) and not bins_made.has(bin):
			var parts: PackedStringArray = bin.split("/")
			var acc: String = ""
			for part: String in parts:
				acc = part if acc.is_empty() else acc + "/" + part
				if not doc.bins.has(acc) and not bins_made.has(acc):
					bins_made[acc] = true
					cmds.append(MediaCmds.AddBin.new(acc))
		if by_path.has(p):
			out.append(String(by_path[p]))
			continue
		var d: Dictionary = {"id": doc.mint_id("m"), "path": p, "label": String(e.get("label", "")) if not String(e.get("label", "")).is_empty() else p.get_file(), "kind": kind, "bin": bin}
		if kind == "image":
			d["duration"] = still_seconds()
		by_path[p] = String(d["id"])
		dicts.append(d)
		cmds.append(MediaCmds.AddMedia.new(d))
	if cmds.is_empty() or dicts.is_empty():
		return out
	var t_add: int = Time.get_ticks_usec()
	var ran: bool = Verbs.run(doc, label, cmds)
	_spend("add_ms", t_add)
	if not ran:
		return out
	for d: Dictionary in dicts:
		var id: String = String(d["id"])
		out.append(id)
		open_item(doc, doc.media_by_id(id))
	return out


func open_item(doc: Project, item: MediaItem) -> int:
	if item == null or item.kind == "sequence" or item.path.is_empty():
		return -1
	var queued: int = _deferred.find(item.id)
	if queued >= 0:
		_deferred.remove_at(queued)
	_scoped_out.erase(item.id)
	var existing: Variant = Session.media_handles.get(item.id, -1)
	if typeof(existing) == TYPE_INT and int(existing) >= 0:
		return int(existing)
	if not PurrBridge.available:
		return -1
	for other: MediaItem in doc.media:
		if other != item and other.path == item.path and Session.media_handles.has(other.id) and int(Session.media_handles[other.id]) >= 0:
			var shared: int = int(Session.media_handles[other.id])
			Session.media_handles[item.id] = shared
			item.handle = shared
			_tick("shared")
			if not item.probed and other.probed:
				_copy_probe(doc, other, item)
			return shared
	_ensure_bridge()
	if not Prefs.is_registered("playback.hw_decode"):
		Prefs.register("playback.hw_decode", true, {"label": "Hardware video decode (D3D11VA, DXVA2, VAAPI)", "type": "bool"})
		Prefs.register("media.prepare_on_import", true, {"label": "Build waveforms, thumbnails and the seek index right after import", "type": "bool"})
	preload("res://host/drives.gd").note_path(item.path)
	var t_open: int = Time.get_ticks_usec()
	var h: int = PurrBridge.open_media(item.path, {"hw": bool(Prefs.get_value("playback.hw_decode"))})
	_spend("open_ms", t_open)
	_tick("opens")
	if h < 0:
		Events.warn("Could not open " + item.label, "The engine refused " + item.path)
		return -1
	Session.media_handles[item.id] = h
	item.handle = h
	StreamOff.push(doc, item)
	if Session.playback_quality > 0:
		PurrBridge.set_quality(h, Session.playback_quality)
	_pending[h] = {"media_id": item.id, "doc": weakref(doc)}
	var t_info: int = Time.get_ticks_usec()
	var info: Dictionary = PurrBridge.media_info(h)
	_spend("info_ms", t_info)
	if bool(info.get("ok", false)) and float(info.get("duration", 0.0)) > 0.0:
		_apply_info(doc, item.id, info)
	return h


func _copy_probe(doc: Project, from: MediaItem, to: MediaItem) -> void:
	var cmds: Array[Command] = []
	for f: String in ["fps", "width", "height", "has_audio", "audio_streams"]:
		cmds.append(MediaCmds.SetMediaField.new(to.id, f, from.get(f)))
	if not to.props.has("still_time"):
		cmds.append(MediaCmds.SetMediaField.new(to.id, "duration", from.duration))
	if to.recorded_at < 0.0 and from.handle >= 0:
		var own: float = CaptureTime.from_info(raw_info(from.handle))
		if own >= 0.0:
			cmds.append(MediaCmds.SetMediaField.new(to.id, "recorded_at", own))
	cmds.append(MediaCmds.SetMediaField.new(to.id, "probed", true))
	Verbs.run(doc, "Read " + to.label, cmds)


func make_stills(doc: Project, m: MediaItem, every: int, bin: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or m == null or m.kind != "video" or m.fps <= 0.0 or m.duration <= 0.0:
		return out
	var step: int = maxi(every, 1)
	var frames: int = int(floor(m.duration * m.fps + 0.0001))
	if frames <= 0:
		return out
	var cmds: Array[Command] = []
	var bin_path: String = (bin + "/" if not bin.is_empty() else "") + m.label.get_basename() + " frames"
	if not doc.bins.has(bin_path):
		cmds.append(MediaCmds.AddBin.new(bin_path))
	var count: int = 0
	var i: int = 0
	while i < frames and count < 5000:
		var t: float = float(i) / m.fps
		var d: Dictionary = {"id": doc.mint_id("m"), "path": m.path, "label": m.label.get_basename() + " f" + str(i).pad_zeros(4), "kind": "video", "bin": bin_path, "probed": true, "duration": still_seconds(), "fps": m.fps, "width": m.width, "height": m.height, "has_audio": false, "poster_time": t, "props": {"still_time": t, "still_frame": i}}
		cmds.append(MediaCmds.AddMedia.new(d))
		out.append(String(d["id"]))
		count += 1
		i += step
	if not Verbs.run(doc, "Frames of " + m.label, cmds):
		return PackedStringArray()
	for id: String in out:
		open_item(doc, doc.media_by_id(id))
	return out


static func timeline_first(doc: Project) -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null:
		return out
	var seen: Dictionary = {}
	var seq: Sequence = doc.active_sequence()
	if seq != null:
		for tr: Track in seq.all_tracks():
			for c: Clip in tr.clips:
				if c.media_id.is_empty() or seen.has(c.media_id):
					continue
				var m: MediaItem = doc.media_by_id(c.media_id)
				if m == null:
					continue
				seen[c.media_id] = true
				out.append(m)
	for other: MediaItem in doc.media:
		if not seen.has(other.id):
			out.append(other)
	return out


const OPEN_AT_ONCE := 2
const OPEN_WAIT_MS := 4000
const PUMP_SECONDS := 0.25


func open_all(doc: Project) -> void:
	_cancel_deferred()
	_unhook_scope()
	if doc == null:
		return
	var away: Dictionary = _hook_scope(doc)
	var used: Dictionary = used_media_ids(doc) if defer_enabled else {}
	for m: MediaItem in timeline_first(doc):
		if m.missing:
			continue
		if away.has(m.id) and _scope_away(m):
			continue
		if defer_enabled and _may_defer(m, used):
			_deferred.append(m.id)
			continue
		open_item(doc, m)
	if _deferred.is_empty():
		return
	_defer_stats["deferred"] = int(_defer_stats.get("deferred", 0)) + _deferred.size()
	_defer_doc = weakref(doc)
	if not doc.changed.is_connected(_on_defer_doc_changed):
		doc.changed.connect(_on_defer_doc_changed)
	_pump()


static func defer_stats() -> Dictionary:
	var d: Dictionary = _defer_stats.duplicate()
	d["waiting"] = _deferred.size()
	d["in_flight"] = _in_flight.size()
	return d


static func defer_reset() -> void:
	_defer_stats = {}


static func is_deferred(media_id: String) -> bool:
	return _deferred.has(media_id) or _scoped_out.has(media_id)


static func is_scoped_out(media_id: String) -> bool:
	return _scoped_out.has(media_id)


static func scope_stats() -> Dictionary:
	var d: Dictionary = _scope_stats.duplicate()
	d["unopened"] = _scoped_out.size()
	d["group"] = _scope_group
	return d


static func scope_reset() -> void:
	_scope_stats = {}


static func _bump(key: String, by: int = 1) -> void:
	_scope_stats[key] = int(_scope_stats.get(key, 0)) + by


static func _live_handle(media_id: String) -> int:
	var h: Variant = Session.media_handles.get(media_id, -1)
	return int(h) if typeof(h) == TYPE_INT else -1


static func _scope_away(m: MediaItem) -> bool:
	if m.kind == "sequence" or m.path.is_empty():
		return false
	var h: int = _live_handle(m.id)
	if h >= 0:
		if m.kind == "video" and not _scope_parked.has(m.id):
			PurrBridge.park_media(h)
			_scope_parked[m.id] = true
			_bump("parked")
		return true
	var queued: int = _deferred.find(m.id)
	if queued >= 0:
		_deferred.remove_at(queued)
	_scoped_out[m.id] = true
	return true


static func _hook_scope(doc: Project) -> Dictionary:
	_scoped_out.clear()
	_scope_doc = weakref(doc)
	if not scope_enabled:
		_scope_group = ""
		return {}
	var sc: Dictionary = SubProjects.scope(doc)
	_scope_group = String(sc["group"])
	_scope_seen = _scope_shape(doc)
	if not doc.changed.is_connected(_on_scope_doc_changed):
		doc.changed.connect(_on_scope_doc_changed)
	if not Session.sequence_changed.is_connected(_on_scope_sequence_changed):
		Session.sequence_changed.connect(_on_scope_sequence_changed)
	return sc["elsewhere"] if bool(sc["scoped"]) else {}


static func _unhook_scope() -> void:
	if _scope_doc != null:
		var old: Project = _scope_doc.get_ref()
		if old != null and old.changed.is_connected(_on_scope_doc_changed):
			old.changed.disconnect(_on_scope_doc_changed)
	_scope_doc = null
	_scoped_out.clear()
	_scope_parked.clear()


static func _scope_project() -> Project:
	if _scope_doc == null:
		return null
	return _scope_doc.get_ref()


static func _on_scope_sequence_changed(_seq_id: String) -> void:
	var doc: Project = _scope_project()
	if doc == null or doc != Session.doc:
		return
	if SubProjects.active_group(doc) != _scope_group or not _scoped_out.is_empty():
		rescope(doc)


static func _scope_shape(doc: Project) -> String:
	return str(doc.sequences.size()) + "|" + JSON.stringify(doc.sub_projects)


static func _on_scope_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		return
	var doc: Project = _scope_project()
	if doc == null or doc != Session.doc:
		return
	var shape: String = _scope_shape(doc)
	if shape != _scope_seen or SubProjects.active_group(doc) != _scope_group:
		_scope_seen = shape
		rescope(doc)
		return
	if _scoped_out.is_empty():
		return
	var hits: Array[MediaItem] = []
	for s: Sequence in SubProjects.with_nested(doc, SubProjects.members(doc, _scope_group)):
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if not c.media_id.is_empty() and _scoped_out.has(c.media_id):
					var m: MediaItem = doc.media_by_id(c.media_id)
					_scoped_out.erase(c.media_id)
					if m != null:
						hits.append(m)
	for m2: MediaItem in hits:
		if int(instance().call("open_item", doc, m2)) >= 0:
			_bump("opened")
	if not hits.is_empty() and Session.has_method("push_playback_graph"):
		Session.push_playback_graph()


static func rescope(doc: Project) -> Dictionary:
	var out: Dictionary = {"opened": 0, "parked": 0, "unopened": 0}
	if doc == null or not scope_enabled:
		return out
	var sc: Dictionary = SubProjects.scope(doc)
	var away: Dictionary = sc["elsewhere"] if bool(sc["scoped"]) else {}
	var was_group: String = _scope_group
	_scope_group = String(sc["group"])
	var switched: bool = was_group != _scope_group
	var loader: RefCounted = instance()
	for m: MediaItem in doc.media:
		if m.missing or m.kind == "sequence" or m.path.is_empty():
			continue
		if away.has(m.id):
			if _scoped_out.has(m.id):
				continue
			var h: int = _live_handle(m.id)
			if h < 0:
				out["unopened"] = int(out["unopened"]) + 1
			elif m.kind == "video" and not _scope_parked.has(m.id):
				out["parked"] = int(out["parked"]) + 1
			_scope_away(m)
			continue
		_scope_parked.erase(m.id)
		if _scoped_out.has(m.id):
			_scoped_out.erase(m.id)
			if int(loader.call("open_item", doc, m)) >= 0:
				_bump("opened")
				out["opened"] = int(out["opened"]) + 1
	if int(out["opened"]) > 0 and Session.has_method("push_playback_graph"):
		Session.push_playback_graph()
	if switched:
		_bump("switches")
	return out


static func _may_defer(m: MediaItem, used: Dictionary) -> bool:
	if m.kind != "video" or m.path.is_empty() or used.has(m.id):
		return false
	var h: Variant = Session.media_handles.get(m.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		return false
	return true


static func used_media_ids(doc: Project) -> Dictionary:
	var ids: Dictionary = {}
	if doc == null:
		return ids
	var known: Dictionary = {}
	for m: MediaItem in doc.media:
		known[m.id] = true
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if not c.media_id.is_empty():
					ids[c.media_id] = true
		_collect_ids(s.to_dict(), known, ids)
	for m2: MediaItem in doc.media:
		if not m2.props.is_empty():
			var inner: Dictionary = {}
			_collect_ids(m2.props, known, inner)
			inner.erase(m2.id)
			ids.merge(inner)
	return ids


static func _collect_ids(v: Variant, known: Dictionary, out: Dictionary) -> void:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			if known.has(String(v)):
				out[String(v)] = true
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				_collect_ids(k, known, out)
				_collect_ids((v as Dictionary)[k], known, out)
		TYPE_ARRAY:
			for e: Variant in v:
				_collect_ids(e, known, out)
		TYPE_PACKED_STRING_ARRAY:
			for e2: String in v:
				if known.has(e2):
					out[e2] = true


static func _cancel_deferred() -> void:
	if _defer_doc != null:
		var old: Project = _defer_doc.get_ref()
		if old != null and old.changed.is_connected(_on_defer_doc_changed):
			old.changed.disconnect(_on_defer_doc_changed)
	_deferred = PackedStringArray()
	_in_flight.clear()
	_park_on_ready.clear()
	_defer_doc = null


static func _defer_project() -> Project:
	if _defer_doc == null:
		return null
	return _defer_doc.get_ref()


static func _pump() -> void:
	var doc: Project = _defer_project()
	if doc == null or doc != Session.doc:
		_cancel_deferred()
		return
	var now: int = Time.get_ticks_msec()
	for h: Variant in _in_flight.keys():
		if now - int(_in_flight[h]) > OPEN_WAIT_MS:
			_in_flight.erase(h)
	var loader: RefCounted = instance()
	while _in_flight.size() < OPEN_AT_ONCE and not _deferred.is_empty():
		var id: String = _deferred[0]
		_deferred.remove_at(0)
		var m: MediaItem = doc.media_by_id(id)
		if m == null or m.missing:
			continue
		var before: Variant = Session.media_handles.get(id, -1)
		var h: int = int(loader.call("open_item", doc, m))
		if h < 0 or (typeof(before) == TYPE_INT and int(before) == h):
			continue
		_defer_stats["opened"] = int(_defer_stats.get("opened", 0)) + 1
		if bool(PurrBridge.media_info(h).get("ok", false)) and not _pending.has(h):
			_park_deferred(h)
			continue
		_in_flight[h] = now
		_park_on_ready[h] = true
	if _deferred.is_empty() and _in_flight.is_empty():
		if doc.changed.is_connected(_on_defer_doc_changed):
			doc.changed.disconnect(_on_defer_doc_changed)
		return
	if not _pump_queued:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			_pump_queued = true
			tree.create_timer(PUMP_SECONDS).timeout.connect(_pump_timer)


static func _pump_timer() -> void:
	_pump_queued = false
	_pump()


static func _park_deferred(h: int) -> void:
	_park_on_ready.erase(h)
	PurrBridge.park_media(h)
	_defer_stats["parked"] = int(_defer_stats.get("parked", 0)) + 1


static func _settle_deferred(h: int, ok: bool) -> void:
	if not _in_flight.has(h) and not _park_on_ready.has(h):
		return
	_in_flight.erase(h)
	if ok and _park_on_ready.has(h):
		_park_deferred(h)
	_park_on_ready.erase(h)
	_pump()


static func claim(item: MediaItem) -> int:
	if item != null and _scoped_out.has(item.id):
		var sdoc: Project = _scope_project()
		_scoped_out.erase(item.id)
		if sdoc == null:
			return -1
		_bump("claimed")
		return int(instance().call("open_item", sdoc, item))
	if item == null or not _deferred.has(item.id):
		return -1
	var doc: Project = _defer_project()
	if doc == null:
		return -1
	_defer_stats["claimed"] = int(_defer_stats.get("claimed", 0)) + 1
	return int(instance().call("open_item", doc, item))


static func _on_defer_doc_changed(_kind: String) -> void:
	if _deferred.is_empty():
		return
	var doc: Project = _defer_project()
	if doc == null:
		return
	var now_used: PackedStringArray = PackedStringArray()
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if not c.media_id.is_empty() and _deferred.has(c.media_id) and not now_used.has(c.media_id):
					now_used.append(c.media_id)
	if now_used.is_empty():
		return
	for id: String in now_used:
		var m: MediaItem = doc.media_by_id(id)
		if m != null:
			_defer_stats["claimed"] = int(_defer_stats.get("claimed", 0)) + 1
			instance().call("open_item", doc, m)
	if Session.has_method("push_playback_graph"):
		Session.push_playback_graph()


static func raw_info(h: int) -> Dictionary:
	if h < 0:
		return {}
	if _raw_info.has(h):
		return _raw_info[h]
	return PurrBridge.media_info(h)


func _on_media_ready(h: int, info: Dictionary) -> void:
	_raw_info[h] = info.duplicate(true)
	_settle_deferred(h, true)
	var rec: Variant = _pending.get(h, null)
	if typeof(rec) != TYPE_DICTIONARY:
		return
	_pending.erase(h)
	var wr: WeakRef = rec["doc"]
	var doc: Project = wr.get_ref()
	if doc == null:
		return
	_apply_info(doc, String(rec["media_id"]), info)


func _on_media_failed(h: int, why: String) -> void:
	_settle_deferred(h, false)
	var rec: Variant = _pending.get(h, null)
	if typeof(rec) != TYPE_DICTIONARY:
		return
	_pending.erase(h)
	var wr: WeakRef = rec["doc"]
	var doc: Project = wr.get_ref()
	if doc == null:
		return
	var item: MediaItem = doc.media_by_id(String(rec["media_id"]))
	var label: String = item.label if item != null else "media"
	Events.error("Could not read " + label, why)


func _apply_info(doc: Project, media_id: String, info: Dictionary) -> void:
	var item: MediaItem = doc.media_by_id(media_id)
	if item == null or not bool(info.get("ok", false)):
		return
	var cmds: Array[Command] = []
	var dur: float = float(info.get("duration", 0.0))
	var still: bool = item.kind == "image" or item.props.has("still_time")
	if still and item.duration <= 0.0:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "duration", still_seconds()))
	if not still and dur > 0.0 and absf(item.duration - dur) > 0.0001:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "duration", dur))
	var fps_v: float = float(info.get("fps", 0.0))
	if not still and fps_v > 0.0 and absf(item.fps - fps_v) > 0.0001:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "fps", fps_v))
	var w: int = int(info.get("width", 0))
	var hh: int = int(info.get("height", 0))
	if w > 0 and item.width != w:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "width", w))
	if hh > 0 and item.height != hh:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "height", hh))
	var has_audio: bool = bool(info.get("has_audio", false))
	if item.has_audio != has_audio:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "has_audio", has_audio))
	var streams: Array[Dictionary] = []
	var raw_streams: Variant = info.get("audio_streams", [])
	if typeof(raw_streams) == TYPE_ARRAY:
		for s: Variant in raw_streams:
			if typeof(s) == TYPE_DICTIONARY:
				var sd: Dictionary = s
				var at: int = streams.size()
				var kept: bool = bool(item.audio_streams[at].get("selected", true)) if at < item.audio_streams.size() else true
				streams.append({"index": int(sd.get("index", at)), "channels": int(sd.get("channels", 2)), "sample_rate": int(sd.get("sample_rate", 48000)), "lang": String(sd.get("lang", "")), "title": String(sd.get("title", "")), "selected": kept})
	if not streams.is_empty() and streams != item.audio_streams:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "audio_streams", streams))
	if not bool(info.get("has_video", false)) and has_audio and item.kind == "video":
		cmds.append(MediaCmds.SetMediaField.new(media_id, "kind", "audio"))
	if item.recorded_at < 0.0:
		var own: float = CaptureTime.from_info(info)
		if own >= 0.0:
			cmds.append(MediaCmds.SetMediaField.new(media_id, "recorded_at", own))
	if has_audio and item.handle >= 0 and PurrBridge.available and (not Prefs.is_registered("media.prepare_on_import") or bool(Prefs.get_value("media.prepare_on_import"))):
		StreamOff.push(doc, item)
		for si: int in maxi(1, streams.size()):
			if not StreamOff.is_off(item, si):
				PurrBridge.peaks_request(item.handle, si, 0.0)
	if not item.probed:
		cmds.append(MediaCmds.SetMediaField.new(media_id, "probed", true))
	if cmds.is_empty():
		return
	var t_apply: int = Time.get_ticks_usec()
	Verbs.run(doc, "Read " + item.label, cmds)
	_spend("apply_ms", t_apply)
	_tick("applies")
