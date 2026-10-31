extends RefCounted

const PREF_ON := "media.proxies"
const PREF_WIDTH := "media.proxy_width"
const PREF_WHERE := "media.proxy_folder"
const PREF_QUALITY := "media.proxy_quality"
const WHERE_CACHE := "The cache folder on this computer"
const WHERE_BESIDE := "Beside the footage"
const WHERE_CHOICES: PackedStringArray = [WHERE_CACHE, WHERE_BESIDE]
const WIDTHS: Array[int] = [480, 640, 960, 1280]
const SEGMENT_SECONDS := 30.0
const FOLDER := "proxies"
const EXT := ".mp4"
const MANIFEST := "segments.json"
const PREF_PLAY := "playback.use_proxies"
const ROUTE_REFRESH_MS := 500
const MISS_RECHECK_MS := 2000
const EDGE_SECONDS := 0.001
const FullQuality := preload("res://engine/full_quality.gd")

static var _route_ms: int = -1000000
static var _route_play: bool = false
static var _route_width: int = 960
static var _route_cache: String = ""
static var _route_beside: bool = false
static var _roots: Dictionary = {}
static var _known: Dictionary = {}
static var _plant_skew_frames: int = 0
static var _lists: Dictionary = {}
const FRAMES_EXT := ".frames"


static func register(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_ON)):
		prefs.call("register", PREF_ON, false, {"label": "Make small copies of footage to edit with (proxies)", "type": "bool"})
	if not bool(prefs.call("is_registered", PREF_WIDTH)):
		prefs.call("register", PREF_WIDTH, 960, {"label": "How wide a proxy is, in pixels", "type": "int", "min": 320, "max": 1920})
	if not bool(prefs.call("is_registered", PREF_WHERE)):
		prefs.call("register", PREF_WHERE, WHERE_CACHE, {"label": "Where proxies are kept", "type": "enum", "choices": Array(WHERE_CHOICES)})
	if not bool(prefs.call("is_registered", PREF_QUALITY)):
		prefs.call("register", PREF_QUALITY, 26, {"label": "Proxy quality (CRF, lower is better and bigger)", "type": "int", "min": 14, "max": 40})
	if not bool(prefs.call("is_registered", PREF_PLAY)):
		prefs.call("register", PREF_PLAY, true, {"label": "Play from proxies where they are built (export always reads the original)", "type": "bool"})


static func on(prefs: Node) -> bool:
	if prefs == null or not bool(prefs.call("is_registered", PREF_ON)):
		return false
	return bool(prefs.call("get_value", PREF_ON))


static func width_for(prefs: Node) -> int:
	if prefs == null or not bool(prefs.call("is_registered", PREF_WIDTH)):
		return 960
	return clampi(int(prefs.call("get_value", PREF_WIDTH)), 320, 1920)


static func quality_for(prefs: Node) -> int:
	if prefs == null or not bool(prefs.call("is_registered", PREF_QUALITY)):
		return 26
	return clampi(int(prefs.call("get_value", PREF_QUALITY)), 14, 40)


static func key_for(media_path: String, width: int) -> String:
	var stem: String = media_path.get_file().get_basename().validate_filename()
	if stem.length() > 40:
		stem = stem.substr(0, 40)
	return stem + "_" + str(width) + "_" + str(media_path.hash())


static func root_for(media_path: String, width: int, cache_dir: String, beside: bool) -> String:
	if beside and not media_path.is_empty():
		return media_path.get_base_dir().path_join(FOLDER).path_join(key_for(media_path, width))
	return cache_dir.path_join(FOLDER).path_join(key_for(media_path, width))


static func segment_index(seconds: float) -> int:
	return maxi(int(floor(maxf(seconds, 0.0) / SEGMENT_SECONDS)), 0)


static func segment_start(index: int) -> float:
	return float(maxi(index, 0)) * SEGMENT_SECONDS


static func segment_count(duration: float) -> int:
	if duration <= 0.0:
		return 0
	return maxi(int(ceil(duration / SEGMENT_SECONDS)), 1)


static func segment_path(root: String, index: int) -> String:
	return root.path_join("seg_" + str(maxi(index, 0)).pad_zeros(5) + EXT)


static func manifest_path(root: String) -> String:
	return root.path_join(MANIFEST)


static func have(root: String, index: int) -> bool:
	var p: String = segment_path(root, index)
	if not FileAccess.file_exists(p):
		return false
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return false
	var size_v: int = int(f.get_length())
	f.close()
	return size_v > 0


static func built_segments(root: String, duration: float, fps: float = 0.0) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in segment_count_for(duration, fps):
		if have(root, i):
			out.append(i)
	return out


static func covers(root: String, seconds: float) -> bool:
	return have(root, segment_index(seconds))


static func bytes_used(root: String, duration: float, fps: float = 0.0) -> int:
	var total: int = 0
	for i: int in segment_count_for(duration, fps):
		var p: String = segment_path(root, i)
		if FileAccess.file_exists(p):
			var f: FileAccess = FileAccess.open(p, FileAccess.READ)
			if f != null:
				total += int(f.get_length())
				f.close()
	return total


static func forget(root: String, index: int) -> bool:
	var p: String = segment_path(root, index)
	_known.erase(p)
	_lists.erase(p)
	if FileAccess.file_exists(frames_path(p)):
		DirAccess.remove_absolute(frames_path(p))
	if not FileAccess.file_exists(p):
		return false
	return DirAccess.remove_absolute(p) == OK


static func forget_all(root: String, duration: float, fps: float = 0.0) -> int:
	var gone: int = 0
	for i: int in segment_count_for(duration, fps):
		if forget(root, i):
			gone += 1
	return gone


static func segment_frames(fps: float) -> int:
	if fps <= 0.0:
		return 0
	return maxi(int(round(SEGMENT_SECONDS * fps)), 1)


static func segment_start_for(index: int, fps: float) -> float:
	var n: int = segment_frames(fps)
	if n <= 0:
		return segment_start(index)
	return float(maxi(index, 0) * n) / fps


static func segment_index_for(seconds: float, fps: float) -> int:
	var n: int = segment_frames(fps)
	if n <= 0:
		return segment_index(seconds)
	return maxi(int(floor((maxf(seconds, 0.0) + EDGE_SECONDS) * fps / float(n))), 0)


static func segment_count_for(duration: float, fps: float) -> int:
	if duration <= 0.0:
		return 0
	var n: int = segment_frames(fps)
	if n <= 0:
		return segment_count(duration)
	return maxi(int(ceil((duration - EDGE_SECONDS) * fps / float(n))), 1)


static func times_for(index: int, fps: float, duration: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if fps <= 0.0 or duration <= 0.0:
		return out
	var first: int = maxi(index, 0) * segment_frames(fps)
	var start: float = float(first) / fps
	if start >= duration - EDGE_SECONDS:
		return out
	var finish: float = minf(float(first + segment_frames(fps)) / fps, duration)
	var n: int = int(round((finish - start) * fps))
	for i: int in n:
		out.append(float(first + i) / fps)
	return out


static func segments_for_span(from_s: float, to_s: float, fps: float, duration: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if fps <= 0.0 or to_s <= from_s:
		return out
	var last: int = segment_count_for(duration, fps) - 1 if duration > 0.0 else segment_index_for(to_s, fps)
	var a: int = segment_index_for(from_s, fps)
	var b: int = mini(segment_index_for(maxf(to_s - EDGE_SECONDS * 2.0, from_s), fps), last)
	for i: int in range(a, b + 1):
		out.append(i)
	return out


static func _prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


static func playback_on(prefs: Node) -> bool:
	if prefs == null or not bool(prefs.call("is_registered", PREF_PLAY)):
		return false
	return bool(prefs.call("get_value", PREF_PLAY))


static func beside_for(prefs: Node) -> bool:
	if prefs == null or not bool(prefs.call("is_registered", PREF_WHERE)):
		return false
	return String(prefs.call("get_value", PREF_WHERE)) == WHERE_BESIDE


static func cache_for(prefs: Node) -> String:
	if prefs == null or not prefs.has_method("cache_dir"):
		return ""
	return String(prefs.call("cache_dir"))


static func root_now(prefs: Node, media_path: String) -> String:
	if prefs == null or media_path.is_empty():
		return ""
	return root_for(media_path, width_for(prefs), cache_for(prefs), beside_for(prefs))


static func refresh_route(force: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	if not force and now - _route_ms < ROUTE_REFRESH_MS:
		return
	_route_ms = now
	var prefs: Node = _prefs_node()
	var width: int = width_for(prefs)
	var beside: bool = beside_for(prefs)
	var cache: String = cache_for(prefs)
	if width != _route_width or beside != _route_beside or cache != _route_cache:
		_roots = {}
		_known = {}
	_route_play = playback_on(prefs) and FullQuality.proxies_allowed(prefs)
	_route_width = width
	_route_beside = beside
	_route_cache = cache


static func playing_from_proxies() -> bool:
	refresh_route()
	return _route_play


static func playback_root(media_path: String) -> String:
	refresh_route()
	if media_path.is_empty() or (_route_cache.is_empty() and not _route_beside):
		return ""
	if _roots.has(media_path):
		return String(_roots[media_path])
	var r: String = root_for(media_path, _route_width, _route_cache, _route_beside)
	_roots[media_path] = r
	return r


static func built_cached(path: String) -> bool:
	var now: int = Time.get_ticks_msec()
	if _known.has(path):
		var v: int = int(_known[path])
		if v < 0:
			return true
		if now - v < MISS_RECHECK_MS:
			return false
	var ok: bool = false
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			ok = int(f.get_length()) > 0
			f.close()
	_known[path] = -1 if ok else now
	return ok


static func note_built(path: String) -> void:
	_known[path] = -1


static func forget_known() -> void:
	_known = {}
	_lists = {}
	_roots = {}
	_route_ms = -1000000


static func playback_segment(media_path: String, fps: float, seconds: float) -> Dictionary:
	if fps <= 0.0 or not playing_from_proxies():
		return {}
	var r: String = playback_root(media_path)
	if r.is_empty():
		return {}
	var idx: int = segment_index_for(seconds, fps)
	var p: String = segment_path(r, idx)
	if not built_cached(p):
		return {}
	return {"path": p, "index": idx, "start": segment_start_for(idx, fps) + float(_plant_skew_frames) / fps, "root": r}


static func job_for(path: String, width: int, height: int, fps: float, frames: int, crf: int, codec: String) -> Dictionary:
	return {
		"path": path,
		"container": "mp4",
		"video_codec": codec,
		"pix_fmt": "yuv420p",
		"width": width,
		"height": height,
		"fps_num": fps_fraction(fps).x,
		"fps_den": fps_fraction(fps).y,
		"total_frames": frames,
		"alpha": false,
		"rate_control": {"mode": "crf", "crf": crf, "bitrate_kbps": 0, "max_kbps": 0},
		"audio": {"codec": "", "pcm_path": "", "pcm_paths": []},
		"thumbnail": {"path": "", "embed": false},
		"metadata": {"title": "", "comment": ""},
		"chapters": [],
	}


static func fps_fraction(fps: float) -> Vector2i:
	var ntsc: float = fps * 1001.0
	var whole: int = int(round(ntsc))
	if fps > 0.0 and whole % 1000 == 0 and absf(ntsc - float(whole)) < 0.002:
		return Vector2i(whole, 1001)
	return Vector2i(int(round(fps * 1000.0)), 1000)


static func reduction_for(source_w: int, want_w: int) -> int:
	if source_w <= 0 or want_w <= 0:
		return 0
	var best: int = 0
	var best_gap: float = 1.0e30
	for k: int in 4:
		var w: int = maxi((source_w >> k) & ~1, 2)
		var gap: float = absf(float(w) - float(want_w))
		if w <= source_w and gap < best_gap:
			best_gap = gap
			best = k
	return best


static func proxy_size(source_w: int, source_h: int, want_w: int) -> Vector2i:
	if source_w <= 0 or source_h <= 0:
		return Vector2i(maxi(want_w & ~1, 2), maxi(int(round(float(want_w) * 9.0 / 16.0)) & ~1, 2))
	var k: int = reduction_for(source_w, want_w)
	return Vector2i(maxi((source_w >> k) & ~1, 2), maxi((source_h >> k) & ~1, 2))


static func codec_for(encoders: Array) -> String:
	for want: String in ["h264_nvenc", "h264_qsv", "h264_amf", "libx264", "openh264"]:
		for e: Variant in encoders:
			if e is Dictionary and String((e as Dictionary).get("id", "")) == want:
				return want
	return ""


static func frames_path(segment: String) -> String:
	return segment + FRAMES_EXT


static func write_frames(segment: String, pts: PackedFloat64Array, starts: PackedFloat64Array) -> bool:
	if pts.is_empty() or pts.size() != starts.size():
		return false
	var f: FileAccess = FileAccess.open(frames_path(segment), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var({"pts": pts, "start": starts})
	f.close()
	_lists.erase(segment)
	return true


static func frame_list(segment: String) -> Dictionary:
	if _lists.has(segment):
		return _lists[segment]
	var out: Dictionary = {}
	var path: String = frames_path(segment)
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var v: Variant = f.get_var()
			f.close()
			if v is Dictionary and (v as Dictionary).get("pts") is PackedFloat64Array and (v as Dictionary).get("start") is PackedFloat64Array:
				var d: Dictionary = v
				if (d["pts"] as PackedFloat64Array).size() == (d["start"] as PackedFloat64Array).size() and not (d["pts"] as PackedFloat64Array).is_empty():
					out = d
	_lists[segment] = out
	return out


static func covering_frame(starts: PackedFloat64Array, seconds: float) -> int:
	var lo: int = 0
	var hi: int = starts.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if starts[mid] <= seconds:
			lo = mid + 1
		else:
			hi = mid
	return lo - 1


static func proxy_pick(segment: String, fps: float, seconds: float) -> Dictionary:
	var list: Dictionary = frame_list(segment)
	if list.is_empty() or fps <= 0.0:
		return {}
	var starts: PackedFloat64Array = list["start"]
	var pts: PackedFloat64Array = list["pts"]
	var j: int = covering_frame(starts, seconds)
	if j < 0:
		return {"before": true}
	while j > 0 and pts[j - 1] == pts[j]:
		j -= 1
	return {"frame": j, "at": float(j - _plant_skew_frames) / fps, "pts": pts[j], "last": j == pts.size() - 1}
