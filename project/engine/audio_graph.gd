extends RefCounted

const FADE_SHAPE_CODES: Dictionary = {"linear": 0, "equal_power": 1, "s_curve": 2}
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const CLIP_PROP_KEYS: PackedStringArray = ["volume", "pan", "speed", "pitch_keep"]
const TRACK_PROP_KEYS: PackedStringArray = ["volume", "pan"]
const BAND_LIMIT_ID := "band_limit"
const COMPRESSION_ID := "compression"
const PAIR_VIEW_ID := "pair_view"
const VIEW_GAIN_ID := "gain"
const SILENT_DB := -80.0
const CROSSFEED_ID := "crossfeed"
const PREF_CROSSFEED := "audio.crossfeed"
const PREF_CF_AMOUNT := "audio.crossfeed_amount"
const PREF_CF_CUTOFF := "audio.crossfeed_cutoff"
const PREF_CF_DELAY := "audio.crossfeed_delay"
const LayerChain := preload("res://engine/layer_chain.gd")
const ViewMap := preload("res://doc/view_map.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const NEST_AUDIO_PATH := "res://engine/nest_audio.gd"
const Censor := preload("res://doc/censor.gd")
const LoopAudio := preload("res://engine/loop_audio.gd")
const FxChains := preload("res://engine/audio_fx_chains.gd")
const VeryLoud := preload("res://engine/very_loud.gd")
const DriveBake := preload("res://engine/drive_bake.gd")
const STACK_LANE_SUFFIX := "_lane"
const LANE_COUNT_KEY := "_lanes"
const FEED_KEY := "feed"

static var feed_override: int = -1
static var hold_keep_pitch: bool = false
static var _scan_depth: int = 0
static var _scans: Dictionary = {}
static var _scan_frame: int = -1
static var prepare_stats: Dictionary = {"props": 0, "expr": 0, "driven": 0, "resolved": 0, "baked": 0, "usec": 0}


static func prepare_stats_reset() -> void:
	for key: Variant in prepare_stats.keys():
		prepare_stats[key] = 0


static func has_driven(p: Dictionary) -> bool:
	if not AnimProp.is_animated(p):
		return false
	for l: Variant in p.get("layers", []):
		if l is Dictionary and str((l as Dictionary).get("type", "")) == "driven":
			return true
	return false


static func floats_of(values: PackedFloat64Array) -> Array:
	var out: Array = []
	for v: float in values:
		out.append(v)
	return out


static func set_expr_rates(p: Dictionary, fps: float) -> void:
	for l: Variant in p.get("layers", []):
		if l is Dictionary and str((l as Dictionary).get("type", "")) == "expr":
			(l as Dictionary)["fps"] = fps


static func resolve_driven(layer: Dictionary, fps: float) -> void:
	layer.erase("src_prop")
	prepare_stats["driven"] = int(prepare_stats["driven"]) + 1
	var doc: Object = AnimDriver.bound()
	if doc != null and AnimProp.driven_extended(layer):
		bake_extended(layer, doc, fps)
		return
	var src: Dictionary = AnimProp.driven_source(layer)
	var clip_id: String = str(src.get("clip", ""))
	var path: String = str(src.get("path", ""))
	if doc == null or clip_id.is_empty() or path.is_empty():
		return
	if AnimDriver.blocked(src):
		return
	var found: Variant = doc.call("clip_by_id", clip_id)
	if not (found is RefCounted):
		return
	var clip: RefCounted = found
	var derived: bool = path.begins_with(AnimDriver.DERIVED_PREFIX)
	var raw: Variant = load(AnimDriver.DERIVED).call("bake", doc, clip, path, fps) if derived else clip.call("get_param", path)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return
	var prop: Dictionary = raw
	var src_dur: float = maxf(float(clip.get("duration")), 0.0)
	var ready: Dictionary = {}
	if derived:
		ready = prop
		prepare_stats["baked"] = int(prepare_stats["baked"]) + 1
	elif bool(clip.call("path_warped", path)) or has_driven(prop):
		ready = AnimTime.bake(prop, AnimTime.own_warp_of(clip, path), src_dur, fps)
		prepare_stats["baked"] = int(prepare_stats["baked"]) + 1
	else:
		ready = prop.duplicate(true)
		set_expr_rates(ready, fps)
	var taps: Array = AnimProp.smooth_taps(layer)
	layer["src_prop"] = ready
	layer["src_dur"] = src_dur
	layer["src_comp"] = 0 if derived else maxi(int(src.get("comp", -1)), 0)
	layer["shift"] = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
	layer["taps_at"] = floats_of(taps[0])
	layer["taps_w"] = floats_of(taps[1])
	prepare_stats["resolved"] = int(prepare_stats["resolved"]) + 1


static func bake_extended(layer: Dictionary, doc: Object, fps: float) -> void:
	var got: Dictionary = DriveBake.bake(layer, doc, fps)
	if got.is_empty():
		return
	var keys: Array = got["keys"]
	var last: float = float(got["last"])
	var dur: float = float(got["dur"])
	var weight: float = AnimProp.driven_in(layer, "weight", 1.0)
	layer["src_prop"] = {"a": true, "base": last, "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}]}
	layer["src_dur"] = dur
	layer["src_comp"] = 0
	layer["shift"] = 0.0
	layer["taps_at"] = [0.0]
	layer["taps_w"] = [1.0]
	layer["in_min"] = 0.0
	layer["in_max"] = 1.0
	layer["out_min"] = 0.0
	layer["out_max"] = 1.0
	layer["overshoot"] = true
	layer["curve"] = "linear"
	layer["weight"] = weight
	prepare_stats["baked"] = int(prepare_stats["baked"]) + 1
	prepare_stats["resolved"] = int(prepare_stats["resolved"]) + 1


static func prepare_prop(p: Dictionary, fps: float) -> Dictionary:
	prepare_stats["props"] = int(prepare_stats["props"]) + 1
	if not AnimProp.is_animated(p):
		return p
	for l: Variant in p.get("layers", []):
		if not (l is Dictionary):
			continue
		var layer: Dictionary = l
		var kind: String = str(layer.get("type", ""))
		if kind == "expr":
			layer["fps"] = fps
			prepare_stats["expr"] = int(prepare_stats["expr"]) + 1
		elif kind == "driven":
			resolve_driven(layer, fps)
	return p


static func prepare_params(params: Variant, fps: float) -> void:
	if not (params is Dictionary):
		return
	for k: Variant in (params as Dictionary).keys():
		if (params as Dictionary)[k] is Dictionary:
			prepare_prop((params as Dictionary)[k], fps)


static func prepare_effects(list: Variant, fps: float) -> void:
	if not (list is Array):
		return
	FxChains.expand(list)
	for e: Variant in (list as Array):
		if e is Dictionary:
			prepare_params((e as Dictionary).get("params", null), fps)


static func prepare_entry(entry: Dictionary, keys: PackedStringArray, fps: float) -> Dictionary:
	for key: String in keys:
		if entry.get(key, null) is Dictionary:
			prepare_prop(entry[key], fps)
	prepare_effects(entry.get("effects", null), fps)
	return entry


static func prepare_graph(graph: Dictionary, fps: float) -> void:
	var started: int = Time.get_ticks_usec()
	for t: Variant in graph.get("tracks", []):
		if not (t is Dictionary):
			continue
		var td: Dictionary = t
		prepare_entry(td, TRACK_PROP_KEYS, fps)
		for ce: Variant in td.get("clips", []):
			if ce is Dictionary:
				prepare_entry(ce as Dictionary, CLIP_PROP_KEYS, fps)
	if graph.get("master", null) is Dictionary:
		prepare_entry(graph["master"] as Dictionary, TRACK_PROP_KEYS, fps)
	prepare_stats["usec"] = int(prepare_stats["usec"]) + (Time.get_ticks_usec() - started)


static func feeds_on() -> bool:
	if feed_override >= 0:
		return feed_override == 1
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var bridge: Node = (loop as SceneTree).root.get_node_or_null("/root/PurrBridge")
	return bridge != null and bridge.has_method("has_track_feed") and bool(bridge.call("has_track_feed"))


static func feed_entry(id: String, owner_id: String, feed: String, muted: bool, solo: bool, effects: Array, clips: Array) -> Dictionary:
	return {"id": id, "owner": owner_id, FEED_KEY: feed, "muted": muted, "solo": solo, "volume": AnimProp.make(1.0), "pan": AnimProp.make(0.0), "effects": effects, "clips": clips}


static func owner_entry(tr: Track) -> Dictionary:
	var effects: Array = []
	for te: Dictionary in tr.effects:
		effects.append(te.duplicate(true))
	return {"id": tr.id, "owner": tr.id, "muted": tr.muted, "solo": tr.solo, "volume": tr.volume.duplicate(true), "pan": tr.pan.duplicate(true), "effects": effects, "clips": []}


static func ensure_feed_targets(seq: Sequence, tracks: Array) -> void:
	if seq == null:
		return
	var ids: Dictionary = {}
	for t: Variant in tracks:
		ids[String((t as Dictionary).get("id", ""))] = true
	var missing: PackedStringArray = PackedStringArray()
	for t: Variant in tracks:
		var feed: String = String((t as Dictionary).get(FEED_KEY, ""))
		if not feed.is_empty() and not ids.has(feed) and not missing.has(feed):
			missing.append(feed)
	for id: String in missing:
		var tr: Track = seq.track_by_id(id)
		if tr != null:
			tracks.append(owner_entry(tr))
			ids[id] = true


static func view_audio_of(e: Dictionary) -> Dictionary:
	return ViewMap.of(e)


static func crop_count_of(e: Dictionary) -> int:
	return ViewMap.crop_count(e)


static func view_index_at(value: float, mode: int, count: int) -> int:
	return ViewMap.index_at(value, mode, count)


static func view_steps(e: Dictionary, video: Clip) -> Array[Dictionary]:
	return ViewMap.sound_steps(e, video)


static func view_hears(map: Dictionary, index: int, track_id: String, clip_id: String) -> bool:
	return ViewMap.hears(map, index, track_id, clip_id)


static func view_governs(map: Dictionary, track_id: String, clip_id: String) -> bool:
	return ViewMap.governs(map, track_id, clip_id)


static func pair_view_sources(seq: Sequence) -> Array[Dictionary]:
	if seq != null and _scan_depth > 0:
		return _scan_of(seq)["sources"]
	return _find_pair_sources(seq)


static func _find_pair_sources(seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	for tr: Track in seq.picture_tracks():
		for v: Clip in tr.clips:
			if v.effects.is_empty() or not tr.is_picture(v):
				continue
			for e: Dictionary in v.effects:
				if String(e.get("id", "")) != PAIR_VIEW_ID or not bool(e.get("enabled", true)):
					continue
				var map: Dictionary = view_audio_of(e)
				if map.is_empty():
					continue
				out.append({"clip": v, "entry": e, "map": map})
	ViewMap.share_every(out)
	return out


static func in_family(_seq: Sequence, video: Clip, c: Clip) -> bool:
	return ViewMap.in_family(video, c)


static func view_gain_from(seq: Sequence, c: Clip, track_id: String, stream: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null or c == null:
		return out
	var sources: Array[Dictionary] = pair_view_sources(seq)
	if sources.is_empty():
		return out
	for si: int in reaching_in(reach_for(seq, sources), c):
		var src: Dictionary = sources[si]
		var video: Clip = src["clip"]
		var map: Dictionary = src["map"]
		var scope: String = String(map.get("scope", "group"))
		var named: bool = view_governs(map, track_id, c.id)
		if not named:
			continue
		if scope == "group" and not in_family(seq, video, c) and not _named_clip(map, c.id):
			continue
		if c.end() <= video.start or c.start >= video.end():
			continue
		var steps: Array[Dictionary] = steps_for(seq, sources, si)
		if steps.is_empty():
			continue
		var by_stream: bool = ViewStreams.on(map)
		var db: Dictionary = AnimProp.make(0.0)
		var wrote: bool = false
		var heard: Dictionary = {}
		for i: int in steps.size():
			var step: Dictionary = steps[i]
			var at: float = float(step["t"])
			if at < c.start and i + 1 < steps.size() and float(steps[i + 1]["t"]) <= c.start:
				continue
			var vi: int = int(step["view"])
			if not heard.has(vi):
				heard[vi] = ViewStreams.plays(map, vi, track_id, c, video, stream) if by_stream else view_hears(map, vi, track_id, c.id)
			var on: bool = bool(heard[vi])
			var local: float = clampf(at - c.start, 0.0, maxf(c.duration, 0.0))
			db = hold_key(db, local, SILENT_DB if not on else 0.0)
			wrote = true
		if not wrote:
			continue
		if video.start > c.start:
			db = hold_key(db, 0.0, 0.0)
		if video.end() < c.end():
			db = hold_key(db, clampf(video.end() - c.start, 0.0, c.duration), 0.0)
		out.append({"id": VIEW_GAIN_ID, "uid": view_gain_uid(video, c, stream), "enabled": true, "params": {"db": db}})
	return out


static func _named_clip(map: Dictionary, clip_id: String) -> bool:
	return ViewMap.named_clip(map, clip_id)


const ViewStreams := preload("res://doc/view_streams.gd")
const StreamLanes := preload("res://engine/stream_lanes.gd")
const StreamOff := preload("res://doc/stream_off.gd")
const LIVE_LOOP_PIECES := 64


static func view_gain_uid(video: Clip, c: Clip, stream: int = -1) -> String:
	var base: String = video.id + "_view_" + c.id
	if stream < 0 or stream == ViewStreams.own(c):
		return base
	return base + StreamLanes.GAIN_TAG + str(stream)


static func hold_key(db: Dictionary, t: float, v: float) -> Dictionary:
	if not AnimProp.is_animated(db):
		return AnimProp.set_key(db, t, v, "hold")
	var ks: Array = ((db["layers"] as Array)[AnimProp.keys_layer_index(db)] as Dictionary)["keys"]
	var n: int = ks.size()
	if n > 0:
		var last_t: float = float((ks[n - 1] as Dictionary).get("t", 0.0))
		if last_t < t - AnimProp.KEY_TOLERANCE:
			ks.append({"t": t, "v": v, "i": "hold"})
			return db
		if absf(last_t - t) <= AnimProp.KEY_TOLERANCE and (n == 1 or float((ks[n - 2] as Dictionary).get("t", 0.0)) < t - AnimProp.KEY_TOLERANCE):
			(ks[n - 1] as Dictionary)["v"] = v
			return db
	var at: int = ks.size()
	for i: int in ks.size():
		var k: Dictionary = ks[i]
		var kt: float = float(k.get("t", 0.0))
		if absf(kt - t) <= AnimProp.KEY_TOLERANCE:
			k["v"] = v
			return db
		if kt > t and at == ks.size():
			at = i
	ks.insert(at, {"t": t, "v": v, "i": "hold"})
	return db


static func reach_index(sources: Array[Dictionary]) -> Dictionary:
	var by_link: Dictionary = {}
	var by_group: Dictionary = {}
	var by_named: Dictionary = {}
	var open: PackedInt32Array = PackedInt32Array()
	var spans: PackedFloat64Array = PackedFloat64Array()
	spans.resize(sources.size() * 2)
	for i: int in sources.size():
		var src: Dictionary = sources[i]
		var video: Clip = src["clip"]
		var map: Dictionary = src["map"]
		spans[i * 2] = video.start
		spans[i * 2 + 1] = video.end()
		if String(map.get("scope", "group")) != "group":
			open.append(i)
			continue
		if not video.link_id.is_empty():
			_index_add(by_link, video.link_id, i)
		if not video.group_id.is_empty():
			_index_add(by_group, video.group_id, i)
		for v: Variant in map.get("views", []):
			for cid: Variant in (v as Dictionary).get("clips", []):
				_index_add(by_named, String(cid), i)
	return {"link": by_link, "group": by_group, "named": by_named, "open": open, "spans": spans}


static func _index_add(index: Dictionary, key: String, i: int) -> void:
	var list: PackedInt32Array = index.get(key, PackedInt32Array())
	if list.is_empty() or list[list.size() - 1] != i:
		list.append(i)
	index[key] = list


static func reaching_in(index: Dictionary, c: Clip) -> PackedInt32Array:
	var out: PackedInt32Array = (index["open"] as PackedInt32Array).duplicate()
	if not c.link_id.is_empty():
		out.append_array((index["link"] as Dictionary).get(c.link_id, PackedInt32Array()))
	if not c.group_id.is_empty():
		out.append_array((index["group"] as Dictionary).get(c.group_id, PackedInt32Array()))
	out.append_array((index["named"] as Dictionary).get(c.id, PackedInt32Array()))
	out.sort()
	var spans: PackedFloat64Array = index["spans"]
	var c0: float = c.start
	var c1: float = c.end()
	var kept: PackedInt32Array = PackedInt32Array()
	for i: int in out.size():
		var si: int = out[i]
		if (not kept.is_empty() and kept[kept.size() - 1] == si) or c1 <= spans[si * 2] or c0 >= spans[si * 2 + 1]:
			continue
		kept.append(si)
	return kept


static func reach_for(seq: Sequence, sources: Array[Dictionary]) -> Dictionary:
	if seq != null and _scan_depth > 0:
		var scan: Dictionary = _scan_of(seq)
		if is_same(scan["sources"], sources):
			if not scan.has("reach"):
				scan["reach"] = reach_index(sources)
			return scan["reach"]
	return reach_index(sources)


static func steps_for(seq: Sequence, sources: Array[Dictionary], si: int) -> Array[Dictionary]:
	var src: Dictionary = sources[si]
	if seq == null or _scan_depth <= 0:
		return view_steps(src["entry"], src["clip"])
	var scan: Dictionary = _scan_of(seq)
	if not is_same(scan["sources"], sources):
		return view_steps(src["entry"], src["clip"])
	if not scan.has("steps"):
		scan["steps"] = {}
	var memo: Dictionary = scan["steps"]
	if not memo.has(si):
		memo[si] = view_steps(src["entry"], src["clip"])
	return memo[si]


static func clip_owners(seq: Sequence) -> Dictionary:
	if seq != null and _scan_depth > 0:
		var scan: Dictionary = _scan_of(seq)
		if not scan.has("owners"):
			scan["owners"] = _owners_of(seq)
		return scan["owners"]
	return _owners_of(seq)


static func _owners_of(seq: Sequence) -> Dictionary:
	var by_link: Dictionary = {}
	var by_group: Dictionary = {}
	var by_id: Dictionary = {}
	var every: Array = []
	for tr: Track in seq.all_tracks():
		for c: Clip in tr.clips:
			var pair: Array = [c, tr.id]
			every.append(pair)
			by_id[c.id] = pair
			if not c.link_id.is_empty():
				if not by_link.has(c.link_id):
					by_link[c.link_id] = []
				(by_link[c.link_id] as Array).append(pair)
			if not c.group_id.is_empty():
				if not by_group.has(c.group_id):
					by_group[c.group_id] = []
				(by_group[c.group_id] as Array).append(pair)
	return {"link": by_link, "group": by_group, "id": by_id, "all": every}


static func candidate_clips(owners: Dictionary, video: Clip, map: Dictionary) -> Array:
	if String(map.get("scope", "group")) != "group":
		return owners["all"]
	var out: Array = []
	var seen: Dictionary = {}
	var lists: Array = []
	if not video.link_id.is_empty():
		lists.append((owners["link"] as Dictionary).get(video.link_id, []))
	if not video.group_id.is_empty():
		lists.append((owners["group"] as Dictionary).get(video.group_id, []))
	var named: Array = []
	for v: Variant in map.get("views", []):
		for cid: Variant in (v as Dictionary).get("clips", []):
			var hit: Variant = (owners["id"] as Dictionary).get(String(cid), null)
			if hit is Array:
				named.append(hit)
	lists.append(named)
	var v0: float = video.start
	var v1: float = video.end()
	for list: Variant in lists:
		for pair: Variant in (list as Array):
			var c: Clip = (pair as Array)[0]
			if c.start >= v1 or c.end() <= v0 or seen.has(c.id):
				continue
			seen[c.id] = true
			out.append(pair)
	return out


static func handle_for(m: MediaItem, handles: Dictionary) -> int:
	if m == null:
		return -1
	if handles.has(m.id):
		return int(handles[m.id])
	return m.handle


static func band_limit_from(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in c.effects:
		if str(e.get("id", "")) != COMPRESSION_ID or not bool(e.get("enabled", true)):
			continue
		var params: Dictionary = e.get("params", {})
		var lp: Dictionary = params.get("audio_lowpass_hz", AnimProp.make(20500.0))
		var hp: Dictionary = params.get("audio_highpass_hz", AnimProp.make(0.0))
		var crush: Dictionary = params.get("audio_crush", AnimProp.make(0.0))
		var uid: String = str(e.get("uid", ""))
		out.append({"id": BAND_LIMIT_ID, "uid": uid + "_band", "enabled": true, "params": {"lowpass_hz": lp.duplicate(true), "highpass_hz": hp.duplicate(true), "crush": crush.duplicate(true)}})
	return out


static func link_partner(seq: Sequence, c: Clip) -> Clip:
	if seq == null or c == null or c.link_id.is_empty():
		return null
	if _scan_depth > 0:
		var found: Variant = (_scan_of(seq)["links"] as Dictionary).get(c.link_id, null)
		if found is Clip and found != c:
			return found
		if not (found is Clip):
			return null
	for tr: Track in seq.picture_tracks():
		for v: Clip in tr.clips:
			if v != c and v.link_id == c.link_id and tr.is_picture(v):
				return v
	return null


static func clip_entry(c: Clip, m: MediaItem, handles: Dictionary, seq: Sequence = null) -> Dictionary:
	var effects: Array = []
	for ae: Variant in c.audio.get("effects", []):
		if ae is Dictionary:
			effects.append((ae as Dictionary).duplicate(true))
	for extra: Dictionary in band_limit_from(c):
		effects.append(extra)
	var partner: Clip = link_partner(seq, c)
	if partner != null:
		for extra: Dictionary in band_limit_from(partner):
			effects.append(extra)
	if seq != null:
		var own: Track = seq.track_of(c.id)
		if own != null:
			for extra2: Dictionary in view_gain_from(seq, c, own.id):
				effects.append(extra2)
	for extra3: Dictionary in crossfeed_from(c.audio_effects(), crossfeed_settings(), c.id + "_crossfeed"):
		effects.append(extra3)
	effects = Censor.prepend_gain(c, effects)
	var media_handle: int = handle_for(m, handles)
	var stream: int = int(c.audio.get("stream", 0.0))
	var render_path: String = ""
	var render: String = str(c.audio.get("render", ""))
	if not render.is_empty() and FileAccess.file_exists(render) and not StreamOff.is_off(m, stream):
		media_handle = -1
		stream = 0
		render_path = render
	return LoopAudio.tag(AnimTime.warp_audio_entry(c, {
		"id": c.id,
		"media": media_handle,
		"path": render_path,
		"stream": stream,
		"start": c.start,
		"duration": c.duration,
		"in_offset": c.in_offset,
		"speed": c.speed.duplicate(true),
		"reversed": false,
		"keep_pitch": hold_keep_pitch or bool(c.audio.get("keep_pitch", false)),
		"pitch_keep": AnimProp.make(1.0) if hold_keep_pitch else c.pitch_keep_prop().duplicate(true),
		"volume": (c.audio.get("volume", AnimProp.make(1.0)) as Dictionary).duplicate(true),
		"pan": c.get_param("audio.pan").duplicate(true),
		"fade_in": float(c.audio.get("fade_in", 0.0)),
		"fade_out": float(c.audio.get("fade_out", 0.0)),
		"fade_shape": float(FADE_SHAPE_CODES.get(String(c.audio.get("fade_shape", "linear")), 0)),
		"muted": not c.enabled,
		"effects": effects,
	}, partner, seq.fps if seq != null else 0.0), c, m.duration if m != null else 0.0)


static func static_speed(c: Clip) -> float:
	if AnimProp.is_animated(c.speed):
		return 1.0
	return maxf(absf(float(c.speed.get("v", 1.0))), 0.01)


static func apply_crossfades(tr: Track, clips: Array, doc: Project) -> void:
	var by_id: Dictionary = {}
	for e: Dictionary in clips:
		by_id[String(e["id"])] = e
	for c: Clip in tr.clips:
		if not c.has_transition() or str(c.transition_in.get("kind", "")) != "crossfade":
			continue
		var prev: Clip = tr.prev_clip(c)
		if prev == null or absf(prev.end() - c.start) > 0.002:
			continue
		if not by_id.has(c.id) or not by_id.has(prev.id):
			continue
		var span: Vector2 = c.transition_span()
		var cut: float = c.start
		var head: float = cut - span.x
		var tail: float = span.y - cut
		var inc: Dictionary = by_id[c.id]
		var out: Dictionary = by_id[prev.id]
		var m_in: MediaItem = doc.media_by_id(c.media_id)
		var m_out: MediaItem = doc.media_by_id(prev.media_id)
		var sp_in: float = static_speed(c)
		var sp_out: float = static_speed(prev)
		var head_avail: float = INF if c.loop else c.in_offset / sp_in
		head = minf(head, head_avail)
		if m_out != null and m_out.duration > 0.0 and not prev.loop:
			var left: float = (m_out.duration - prev.in_offset) / sp_out - prev.duration
			tail = clampf(minf(tail, left), 0.0, tail)
		if head <= 0.0 and tail <= 0.0:
			continue
		inc["start"] = cut - head
		inc["in_offset"] = c.in_offset - head * sp_in
		inc["duration"] = c.duration + head
		inc["fade_in"] = maxf(float(inc.get("fade_in", 0.0)), head + tail)
		out["duration"] = prev.duration + tail
		out["fade_out"] = maxf(float(out.get("fade_out", 0.0)), head + tail)


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func register_crossfeed_prefs() -> void:
	var p: Node = _prefs()
	if p == null:
		return
	for spec: Array in [[PREF_CROSSFEED, false, {"label": "Crossfeed on every clip", "type": "bool"}], [PREF_CF_AMOUNT, 0.4, {"label": "Crossfeed amount", "type": "float", "min": 0.0, "max": 1.0}], [PREF_CF_CUTOFF, 700.0, {"label": "Crossfeed only below (Hz)", "type": "float", "min": 200.0, "max": 2000.0}], [PREF_CF_DELAY, 0.3, {"label": "Crossfeed delay (ms)", "type": "float", "min": 0.0, "max": 2.0}]]:
		if not bool(p.call("is_registered", String(spec[0]))):
			p.call("register", String(spec[0]), spec[1], spec[2])


static func crossfeed_settings() -> Dictionary:
	var p: Node = _prefs()
	if p == null or not bool(p.call("is_registered", PREF_CROSSFEED)):
		return {"on": false, "amount": 0.4, "cutoff": 700.0, "delay_ms": 0.3}
	return {
		"on": bool(p.call("get_value", PREF_CROSSFEED)),
		"amount": float(p.call("get_value", PREF_CF_AMOUNT)),
		"cutoff": float(p.call("get_value", PREF_CF_CUTOFF)),
		"delay_ms": float(p.call("get_value", PREF_CF_DELAY)),
	}


static func crossfeed_node(settings: Dictionary, uid: String) -> Dictionary:
	return {
		"uid": uid,
		"id": CROSSFEED_ID,
		"enabled": true,
		"params": {
			"amount": AnimProp.make(clampf(float(settings.get("amount", 0.4)), 0.0, 1.0)),
			"cutoff": AnimProp.make(clampf(float(settings.get("cutoff", 700.0)), 200.0, 2000.0)),
			"delay_ms": AnimProp.make(clampf(float(settings.get("delay_ms", 0.3)), 0.0, 2.0)),
		},
	}


static func has_own_crossfeed(entries: Array) -> bool:
	for e: Variant in entries:
		if String((e as Dictionary).get("id", "")) == CROSSFEED_ID:
			return true
	return false


static func crossfeed_from(entries: Array, settings: Dictionary, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not bool(settings.get("on", false)) or has_own_crossfeed(entries):
		return out
	out.append(crossfeed_node(settings, uid))
	return out


static func monitor_stream(item: MediaItem) -> int:
	return ViewStreams.StreamOrdinals.first_selected(item)


static func source_graph(item: MediaItem, handle: int, stream: int, sample_rate: int = 48000) -> Dictionary:
	var clips: Array = []
	var length: float = item.duration if item != null else 0.0
	if item != null and handle >= 0 and length > 0.0 and (item.has_audio or item.kind == "audio"):
		clips.append({
			"id": "source",
			"media": handle,
			"path": "",
			"stream": maxi(stream, 0),
			"start": 0.0,
			"duration": length,
			"in_offset": 0.0,
			"speed": AnimProp.make(1.0),
			"reversed": false,
			"keep_pitch": false,
			"volume": AnimProp.make(1.0),
			"pan": AnimProp.make(0.0),
			"fade_in": 0.0,
			"fade_out": 0.0,
			"muted": false,
			"effects": crossfeed_from([], crossfeed_settings(), "source_crossfeed"),
		})
	return VeryLoud.stamp({
		"sample_rate": maxi(sample_rate, 8000),
		"tracks": [{
			"id": "source",
			"muted": false,
			"solo": false,
			"volume": AnimProp.make(1.0),
			"pan": AnimProp.make(0.0),
			"effects": [],
			"clips": clips,
		}],
		"master": {"volume": AnimProp.make(1.0), "effects": []},
	})


static func own_tracks(doc: Project, seq: Sequence, handles: Dictionary = {}) -> Array:
	var st: Dictionary = build_begin(doc, seq, handles)
	_own_stage(st, Time.get_ticks_usec(), -1)
	return st["tracks"]


static func split_stack_lanes(entry: Dictionary, tr: Track) -> Array:
	var out: Array = []
	var lane_of: Dictionary = stack_lane_map(tr)
	var lane_count: int = int(lane_of.get(LANE_COUNT_KEY, 1))
	if lane_count < 2:
		return out
	var lanes: Array = []
	for k: int in lane_count:
		lanes.append([])
	for e: Variant in entry.get("clips", []):
		var ed: Dictionary = e
		(lanes[int(lane_of.get(String(ed.get("id", "")), 0))] as Array).append(ed)
	entry["clips"] = lanes[0]
	if feeds_on():
		for k2: int in range(1, lanes.size()):
			out.append(feed_entry(tr.id + STACK_LANE_SUFFIX + str(k2), tr.id, tr.id, bool(entry.get("muted", false)), bool(entry.get("solo", false)), [], lanes[k2]))
		return out
	for k: int in range(1, lanes.size()):
		var copy: Dictionary = {}
		for key: Variant in entry.keys():
			if String(key) != "clips":
				copy[key] = entry[key].duplicate(true) if (entry[key] is Dictionary or entry[key] is Array) else entry[key]
		copy["id"] = tr.id + STACK_LANE_SUFFIX + str(k)
		copy["owner"] = tr.id
		copy["clips"] = lanes[k]
		out.append(copy)
	return out


static func stack_lane_map(tr: Track) -> Dictionary:
	var lane_of: Dictionary = {LANE_COUNT_KEY: 1}
	if tr == null or not tr.has_stack():
		return lane_of
	var lane_ends: Array[float] = []
	for c: Clip in tr.clips:
		if not tr.is_sound(c):
			continue
		var lane: int = -1
		for k: int in lane_ends.size():
			if c.start >= lane_ends[k] - Track.STACK_EPS:
				lane = k
				break
		if lane < 0:
			lane = lane_ends.size()
			lane_ends.append(0.0)
		lane_ends[lane] = c.end()
		lane_of[c.id] = lane
	lane_of[LANE_COUNT_KEY] = maxi(lane_ends.size(), 1)
	return lane_of


static func sounding_media(doc: Project, tr: Track, c: Clip) -> MediaItem:
	if doc == null or tr == null or c == null or not tr.is_sound(c):
		return null
	var m: MediaItem = doc.media_by_id(c.media_id)
	if m == null or m.kind == "sequence" or m.kind == "adjust" or m.kind == "title" or m.kind == "shape":
		return null
	if not m.has_audio and m.kind != "audio":
		return null
	return m


static func has_sound(doc: Project, tr: Track) -> bool:
	for c: Clip in tr.clips:
		if sounding_media(doc, tr, c) != null:
			return true
	return false


static func meter_slots(doc: Project, seq: Sequence) -> Dictionary:
	var out: Dictionary = {}
	if seq == null:
		return out
	var lanes_metered: bool = not feeds_on()
	var i: int = 0
	for tr: Track in seq.audio_tracks:
		out[tr.id] = PackedInt32Array([i])
		i += 1
	for tr: Track in seq.audio_tracks:
		var own: PackedInt32Array = out[tr.id]
		for k: int in range(1, int(stack_lane_map(tr)[LANE_COUNT_KEY])):
			if lanes_metered:
				own.append(i)
			i += 1
		out[tr.id] = own
	for tr: Track in seq.extra_sound_tracks():
		if not has_sound(doc, tr):
			continue
		var slots: PackedInt32Array = PackedInt32Array([i])
		i += 1
		for k: int in range(1, int(stack_lane_map(tr)[LANE_COUNT_KEY])):
			if lanes_metered:
				slots.append(i)
			i += 1
		out[tr.id] = slots
	return out


static func slot_level(meters: PackedFloat32Array, slots: PackedInt32Array, channel: int) -> float:
	var v: float = 0.0
	for slot: int in slots:
		var at: int = 2 + slot * 2 + channel
		if at < meters.size():
			v = maxf(v, meters[at])
	return v


static func free_sound_tracks(doc: Project, seq: Sequence, handles: Dictionary) -> Array:
	var out: Array = []
	for tr: Track in seq.extra_sound_tracks():
		var clips: Array = []
		for c: Clip in tr.clips:
			var m: MediaItem = sounding_media(doc, tr, c)
			if m == null:
				continue
			clips.append(clip_entry(c, m, handles, seq))
		if clips.is_empty():
			continue
		apply_crossfades(tr, clips, doc)
		var effects: Array = []
		for te: Dictionary in tr.effects:
			effects.append(te.duplicate(true))
		var entry: Dictionary = {"id": tr.id, "owner": tr.id, "muted": tr.muted, "solo": tr.solo, "volume": tr.volume.duplicate(true), "pan": tr.pan.duplicate(true), "effects": effects, "clips": clips}
		out.append(entry)
		out.append_array(split_stack_lanes(entry, tr))
	return out


static func nested_tracks(doc: Project, seq: Sequence, handles: Dictionary = {}) -> Array:
	var out: Array = []
	if seq == null or doc == null:
		return out
	var nest_audio: GDScript = load(NEST_AUDIO_PATH)
	if nest_audio == null:
		return out
	out.append_array(nest_audio.call("nest_tracks", doc, seq, handles))
	out.append_array(nest_audio.call("outside_tracks", doc, seq, handles))
	return out


static func _stat(key: String, t0: int) -> int:
	var now: int = Time.get_ticks_usec()
	build_stats[key] = int(build_stats.get(key, 0)) + now - t0
	return now


static func build(doc: Project, seq: Sequence, handles: Dictionary = {}) -> Dictionary:
	var st: Dictionary = build_begin(doc, seq, handles)
	build_step(st, -1)
	return st["graph"]


static func build_begin(doc: Project, seq: Sequence, handles: Dictionary = {}) -> Dictionary:
	return {"doc": doc, "seq": seq, "handles": handles, "handles_was": handles.duplicate(), "serial": doc.serial if doc != null else -1, "stage": 0, "track_i": 0, "clip_i": 0, "clips": [], "tracks": [], "extra": [], "graph": {}, "steps": 0}


static func build_still_good(st: Dictionary, doc: Project, seq: Sequence, handles: Dictionary) -> bool:
	if st.is_empty() or doc == null or st.get("doc") != doc or st.get("seq") != seq:
		return false
	return int(st.get("serial", -1)) == doc.serial and handles == st.get("handles_was", {})


static func build_step(st: Dictionary, budget_usec: int) -> bool:
	_scan_depth += 1
	st["steps"] = int(st["steps"]) + 1
	var done: bool = _build_stages(st, Time.get_ticks_usec(), budget_usec)
	_scan_depth -= 1
	if _scan_depth == 0:
		_scans.clear()
	return done


static func _over(t_start: int, budget_usec: int) -> bool:
	return budget_usec >= 0 and Time.get_ticks_usec() - t_start >= budget_usec


static func _own_stage(st: Dictionary, t_start: int, budget_usec: int) -> bool:
	var doc: Project = st["doc"]
	var seq: Sequence = st["seq"]
	var handles: Dictionary = st["handles"]
	var tracks: Array = st["tracks"]
	if seq == null or doc == null:
		return true
	var made: int = 0
	var extra: Array = st["extra"]
	while int(st["track_i"]) < seq.audio_tracks.size():
		var tr: Track = seq.audio_tracks[int(st["track_i"])]
		var clips: Array = st["clips"]
		while int(st["clip_i"]) < tr.clips.size():
			if made > 0 and _over(t_start, budget_usec):
				return false
			var c: Clip = tr.clips[int(st["clip_i"])]
			st["clip_i"] = int(st["clip_i"]) + 1
			if not tr.is_sound(c):
				continue
			var m: MediaItem = doc.media_by_id(c.media_id)
			if m == null or m.kind == "sequence" or m.kind == "adjust" or m.kind == "title" or m.kind == "shape":
				continue
			if not m.has_audio and m.kind != "audio":
				continue
			var ct: int = Time.get_ticks_usec()
			clips.append(clip_entry(c, m, handles, seq))
			_stat("clip_entry", ct)
			made += 1
		var xt: int = Time.get_ticks_usec()
		apply_crossfades(tr, clips, doc)
		_stat("crossfades", xt)
		var effects: Array = []
		for te: Dictionary in tr.effects:
			effects.append(te.duplicate(true))
		tracks.append({
			"id": tr.id,
			"owner": tr.id,
			"muted": tr.muted,
			"solo": tr.solo,
			"volume": tr.volume.duplicate(true),
			"pan": tr.pan.duplicate(true),
			"effects": effects,
			"clips": clips,
		})
		extra.append_array(split_stack_lanes(tracks[tracks.size() - 1], tr))
		st["track_i"] = int(st["track_i"]) + 1
		st["clip_i"] = 0
		st["clips"] = []
	extra.append_array(free_sound_tracks(doc, seq, handles))
	tracks.append_array(extra)
	tracks.append_array(Censor.sound_tracks(doc, seq, handles))
	return true


static func _build_stages(st: Dictionary, t_start: int, budget_usec: int) -> bool:
	var doc: Project = st["doc"]
	var seq: Sequence = st["seq"]
	var handles: Dictionary = st["handles"]
	var tracks: Array = st["tracks"]
	if int(st["stage"]) == 0:
		var t0: int = Time.get_ticks_usec()
		var own_done: bool = _own_stage(st, t_start, budget_usec)
		_stat("own_tracks", t0)
		if not own_done:
			return false
		st["stage"] = 1
		if _over(t_start, budget_usec):
			return false
	if int(st["stage"]) == 1:
		var t1: int = Time.get_ticks_usec()
		StreamLanes.expand(seq, tracks)
		t1 = _stat("stream_lanes", t1)
		apply_pair_views(seq, tracks)
		_stat("pair_views", t1)
		st["stage"] = 2
		if _over(t_start, budget_usec):
			return false
	var t2: int = Time.get_ticks_usec()
	tracks.append_array(nested_tracks(doc, seq, handles))
	t2 = _stat("nests", t2)
	StreamOff.strip_graph(doc, handles, tracks)
	LoopAudio.split_tracks(tracks, seq.fps if seq != null else 0.0, feeds_on())
	ensure_feed_targets(seq, tracks)
	_stat("rest", t2)
	build_stats["builds"] = int(build_stats.get("builds", 0)) + 1
	var graph: Dictionary = {
		"sample_rate": seq.sample_rate if seq != null else 48000,
		"tracks": tracks,
		"master": {"volume": seq.master_volume.duplicate(true) if seq != null else AnimProp.make(1.0), "effects": []},
	}
	VeryLoud.stamp(graph)
	prepare_graph(graph, seq.fps if seq != null else 0.0)
	st["graph"] = graph
	st["stage"] = 3
	return true


static func live_entries(doc: Project, seq: Sequence, handles: Dictionary, clip_id: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "entries": {}}
	if doc == null or seq == null:
		return out
	var tr: Track = null
	var c: Clip = null
	var m: MediaItem = null
	var found: int = 0
	var sounding: int = 0
	for t: Track in sound_tracks(seq):
		for one: Clip in t.clips:
			if one.id != clip_id:
				continue
			found += 1
			var heard: MediaItem = sounding_media(doc, t, one)
			if heard != null:
				sounding += 1
				tr = t
				c = one
				m = heard
	if found == 0 or sounding > 1:
		return out
	if sounding == 0:
		out["ok"] = true
		return out
	if Censor.has_regions(c):
		return out
	_scan_depth += 1
	var entry: Dictionary = clip_entry(c, m, handles, seq)
	crossfade_read(doc, tr, c, entry)
	var tracks: Array = [{"id": tr.id, "owner": tr.id, "muted": tr.muted, "solo": tr.solo, "volume": tr.volume.duplicate(true), "pan": tr.pan.duplicate(true), "effects": [], "clips": [entry]}]
	StreamLanes.expand(seq, tracks)
	_pair_views_one(seq, tracks, c, tr.id)
	var fps: float = seq.fps
	if not _live_loop_ok(tracks, fps):
		_scan_depth -= 1
		if _scan_depth == 0:
			_scans.clear()
		return out
	var entries: Dictionary = {}
	for t: Variant in tracks:
		for ce: Variant in (t as Dictionary).get("clips", []):
			var cd: Dictionary = ce
			prepare_entry(cd, CLIP_PROP_KEYS, fps)
			entries[String(cd.get("id", ""))] = cd
	StreamOff.strip_entries(doc, handles, entries)
	_scan_depth -= 1
	if _scan_depth == 0:
		_scans.clear()
	out["ok"] = true
	out["entries"] = entries
	return out


static func _live_loop_ok(tracks: Array, fps: float) -> bool:
	var pieces: int = 0
	for t: Variant in tracks:
		var list: Array = (t as Dictionary).get("clips", [])
		for ce: Variant in list:
			var cd: Dictionary = ce
			if not cd.has(LoopAudio.KEY):
				continue
			if feeds_on() and LoopAudio.bus_ok(cd, list):
				return false
			pieces += LoopAudio.probe_of(cd).loop_seams_in(Vector2(float(cd[LoopAudio.KEY][0]), float(cd[LoopAudio.KEY][1]))).size() + 1
	if pieces > LIVE_LOOP_PIECES:
		return false
	LoopAudio.split_tracks(tracks, fps, false)
	return true


static func _pair_views_one(seq: Sequence, tracks: Array, c: Clip, tid: String) -> void:
	var sources: Array[Dictionary] = pair_view_sources(seq)
	if sources.is_empty():
		return
	var by_id: Dictionary = {}
	for tr: Variant in tracks:
		for ce: Variant in (tr as Dictionary).get("clips", []):
			by_id[String((ce as Dictionary).get("id", ""))] = ce
	if not by_id.has(c.id):
		return
	var sync: RefCounted = PairSyncState.instance()
	var index: Dictionary = reach_for(seq, sources)
	var owners: Dictionary = clip_owners(seq)
	for src: Dictionary in sources:
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var map: Dictionary = src["map"]
		var live: bool = bool(sync.call("live_for", video.id, String(e.get("uid", ""))))
		if not live and not ViewMap.any_offset(e):
			continue
		if not _candidate(owners, video, map, c) or not ViewMap.reaches(map, video, c, tid):
			continue
		var shifts: bool = offset_piece(sources, src, c, tid, reaching_in(index, c))
		pair_shift(by_id[c.id], c, tid, video, e, map, live, sync, shifts)
		StreamLanes.shift_copies(by_id, c, tid, video, e, map, live, sync, shifts)


static func _candidate(owners: Dictionary, video: Clip, map: Dictionary, c: Clip) -> bool:
	if String(map.get("scope", "group")) != "group":
		return (owners["id"] as Dictionary).has(c.id)
	if c.start >= video.end() or c.end() <= video.start:
		return false
	if not video.link_id.is_empty() and c.link_id == video.link_id:
		return true
	if not video.group_id.is_empty() and c.group_id == video.group_id:
		return true
	for v: Variant in map.get("views", []):
		for cid: Variant in (v as Dictionary).get("clips", []):
			if String(cid) == c.id:
				return true
	return false


static func driven_sources_in(graph: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for t: Variant in graph.get("tracks", []):
		var td: Dictionary = t
		_driven_sources_of(td, TRACK_PROP_KEYS, out)
		for ce: Variant in td.get("clips", []):
			_driven_sources_of(ce as Dictionary, CLIP_PROP_KEYS, out)
	if graph.get("master", null) is Dictionary:
		_driven_sources_of(graph["master"] as Dictionary, TRACK_PROP_KEYS, out)
	return out


static func _driven_sources_of(entry: Dictionary, keys: PackedStringArray, out: Dictionary) -> void:
	var props: Array = []
	for key: String in keys:
		if entry.get(key, null) is Dictionary:
			props.append(entry[key])
	for fx: Variant in entry.get("effects", []):
		if fx is Dictionary and (fx as Dictionary).get("params", null) is Dictionary:
			for pv: Variant in ((fx as Dictionary)["params"] as Dictionary).values():
				if pv is Dictionary:
					props.append(pv)
	for p: Variant in props:
		for l: Variant in (p as Dictionary).get("layers", []):
			if l is Dictionary and str((l as Dictionary).get("type", "")) == "driven":
				out[str(AnimProp.driven_source(l as Dictionary).get("clip", ""))] = true


static func entry_ids_in(graph: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for t: Variant in graph.get("tracks", []):
		var td: Dictionary = t
		var tid: String = String(td.get("id", ""))
		out[tid] = int(out.get(tid, 0)) + 1
		for ce: Variant in td.get("clips", []):
			var cid: String = String((ce as Dictionary).get("id", ""))
			out[cid] = int(out.get(cid, 0)) + 1
	return out


static func _scan_of(seq: Sequence) -> Dictionary:
	var frame: int = Engine.get_process_frames()
	if frame != _scan_frame:
		_scans.clear()
		_scan_frame = frame
	var key: int = seq.get_instance_id()
	if _scans.has(key):
		return _scans[key]
	var links: Dictionary = {}
	for tr: Track in seq.picture_tracks():
		for v: Clip in tr.clips:
			if not v.link_id.is_empty() and not links.has(v.link_id) and tr.is_picture(v):
				links[v.link_id] = v
	var scan: Dictionary = {"sources": _find_pair_sources(seq), "links": links}
	_scans[key] = scan
	return scan


const PairSyncState := preload("res://engine/pair_sync_state.gd")
const OFFSET_SAMPLES_PER_SECOND := 10.0
static var build_stats: Dictionary = {}
static var _plant_resample: bool = false
const OFFSET_SAMPLES_MAX := 32


static func apply_pair_views(seq: Sequence, tracks: Array) -> void:
	if seq == null:
		return
	var t0: int = Time.get_ticks_usec()
	var sources: Array[Dictionary] = pair_view_sources(seq)
	t0 = _stat("pv_sources", t0)
	if sources.is_empty():
		return
	var by_id: Dictionary = {}
	for tr: Variant in tracks:
		for ce: Variant in (tr as Dictionary).get("clips", []):
			by_id[String((ce as Dictionary).get("id", ""))] = ce
	var sync: RefCounted = PairSyncState.instance()
	var index: Dictionary = reach_for(seq, sources)
	t0 = _stat("pv_reach", t0)
	var owners: Dictionary = clip_owners(seq)
	t0 = _stat("pv_owners", t0)
	for src: Dictionary in sources:
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var map: Dictionary = src["map"]
		var live: bool = bool(sync.call("live_for", video.id, String(e.get("uid", ""))))
		if not live and not ViewMap.any_offset(e):
			continue
		var cands: Array = candidate_clips(owners, video, map)
		t0 = _stat("pv_candidates", t0)
		for pair: Variant in cands:
			var c: Clip = (pair as Array)[0]
			var tid: String = (pair as Array)[1]
			if not by_id.has(c.id) or not ViewMap.reaches(map, video, c, tid):
				continue
			t0 = _stat("pv_reaches", t0)
			var shifts: bool = offset_piece(sources, src, c, tid, reaching_in(index, c))
			t0 = _stat("pv_offset_piece", t0)
			pair_shift(by_id[c.id], c, tid, video, e, map, live, sync, shifts)
			t0 = _stat("pv_pair_shift", t0)
			StreamLanes.shift_copies(by_id, c, tid, video, e, map, live, sync, shifts)
			t0 = _stat("pv_copies", t0)


static func offset_piece(sources: Array[Dictionary], src: Dictionary, c: Clip, track_id: String, among: PackedInt32Array = PackedInt32Array()) -> bool:
	var uid: String = String((src["entry"] as Dictionary).get("uid", ""))
	var best: Clip = null
	var n: int = among.size() if not among.is_empty() else sources.size()
	for j: int in n:
		var other: Dictionary = sources[among[j] if not among.is_empty() else j]
		if String((other["entry"] as Dictionary).get("uid", "")) != uid:
			continue
		var ov: Clip = other["clip"]
		if not ViewMap.reaches(other["map"], ov, c, track_id):
			continue
		if best == null or piece_gap(ov, c.start) < piece_gap(best, c.start) or (piece_gap(ov, c.start) == piece_gap(best, c.start) and ov.start < best.start):
			best = ov
	return best == null or best == src["clip"]


static func piece_gap(video: Clip, t: float) -> float:
	if t >= video.start and t < video.end():
		return 0.0
	return video.start - t if video.start > t else t - video.end()


static func pair_shift(entry: Dictionary, c: Clip, track_id: String, video: Clip, e: Dictionary, map: Dictionary, live: bool, sync: RefCounted, shifts: bool = true, stream: int = -1) -> void:
	var views: PackedInt32Array = ViewStreams.views_playing(map, track_id, c, video, stream) if ViewStreams.on(map) else ViewMap.views_hearing(map, track_id, c.id)
	if views.is_empty():
		return
	if live:
		sync_entry(entry, video, c, views, sync, stream)
	if not shifts:
		return
	var heard: Dictionary = ViewMap.heard_entry(e, video, c, views, live)
	if ViewMap.has_offset(heard, 0):
		offset_entry(entry, c, video, heard, 0)


static func pair_read_entry(doc: Project, seq: Sequence, tr: Track, c: Clip, sources: Array[Dictionary]) -> Dictionary:
	if seq == null or tr == null or c == null or sources.is_empty() or sounding_media(doc, tr, c) == null:
		return {}
	var entry: Dictionary = {"id": c.id, "start": c.start, "duration": c.duration, "in_offset": c.in_offset, "speed": c.speed.duplicate(true), "fade_in": 0.0, "fade_out": 0.0, "muted": false, "effects": []}
	crossfade_read(doc, tr, c, entry)
	var was: Array = [entry["start"], entry["duration"], entry["in_offset"], (entry["speed"] as Dictionary).duplicate(true)]
	var sync: RefCounted = PairSyncState.instance()
	for src: Dictionary in sources:
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var live: bool = bool(sync.call("live_for", video.id, String(e.get("uid", ""))))
		if not live and not ViewMap.any_offset(e):
			continue
		if ViewMap.reaches(src["map"], video, c, tr.id):
			pair_shift(entry, c, tr.id, video, e, src["map"], live, sync, offset_piece(sources, src, c, tr.id))
	if not bool(entry["muted"]) and [entry["start"], entry["duration"], entry["in_offset"], entry["speed"]] == was:
		return {}
	return entry


static func sound_tracks(seq: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	out.append_array(seq.audio_tracks)
	out.append_array(seq.extra_sound_tracks())
	return out


static func view_gain_patch(doc: Project, seq: Sequence, video_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out: Dictionary = {}
	if doc == null or seq == null:
		return out
	_scan_depth += 1
	var sources: Array[Dictionary] = pair_view_sources(seq)
	if not sources.is_empty():
		var index: Dictionary = reach_for(seq, sources)
		var sync: RefCounted = PairSyncState.instance()
		var by_stream: bool = StreamLanes.any_streams(sources)
		for tr: Track in sound_tracks(seq):
			for c: Clip in tr.clips:
				var reach: PackedInt32Array = reaching_in(index, c)
				if reach.is_empty() or not _reached_by(sources, reach, video_ids) or sounding_media(doc, tr, c) == null:
					continue
				for st: int in (StreamLanes.entry_streams(sources, reach, c, tr.id) if by_stream else PackedInt32Array([-1])):
					_patch_entry(doc, seq, tr, c, sources, reach, sync, st, out)
	_scan_depth -= 1
	if _scan_depth == 0:
		_scans.clear()
	return out


static func _patch_entry(doc: Project, seq: Sequence, tr: Track, c: Clip, sources: Array[Dictionary], reach: PackedInt32Array, sync: RefCounted, stream: int, out: Dictionary) -> void:
	var gains: Array[Dictionary] = view_gain_from(seq, c, tr.id, stream)
	if gains.is_empty():
		return
	var entry: Dictionary = {"id": c.id, "start": c.start, "duration": c.duration, "in_offset": c.in_offset, "speed": c.speed.duplicate(true), "fade_in": 0.0, "fade_out": 0.0, "muted": false, "effects": gains}
	crossfade_read(doc, tr, c, entry)
	for si: int in reach:
		var src: Dictionary = sources[si]
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var live: bool = bool(sync.call("live_for", video.id, String(e.get("uid", ""))))
		if not live and not ViewMap.any_offset(e):
			continue
		if not ViewMap.reaches(src["map"], video, c, tr.id):
			continue
		pair_shift(entry, c, tr.id, video, e, src["map"], live, sync, offset_piece(sources, src, c, tr.id, reach), stream)
	if c.loop:
		var heard: MediaItem = sounding_media(doc, tr, c)
		LoopAudio.tag(entry, c, heard.duration if heard != null else 0.0)
		if entry.has(LoopAudio.KEY):
			LoopAudio.view_gains_of(LoopAudio.segments(entry, seq.fps), out)
			return
	for fx: Variant in entry["effects"]:
		var fd: Dictionary = fx
		if String(fd.get("id", "")) == VIEW_GAIN_ID:
			out[String(fd.get("uid", ""))] = (fd["params"] as Dictionary)["db"]


static func _reached_by(sources: Array[Dictionary], reach: PackedInt32Array, video_ids: PackedStringArray) -> bool:
	if video_ids.is_empty():
		return true
	for si: int in reach:
		if video_ids.has(((sources[si] as Dictionary)["clip"] as Clip).id):
			return true
	return false


static func view_gains_in(graph: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for t: Variant in graph.get("tracks", []):
		for ce: Variant in (t as Dictionary).get("clips", []):
			for fx: Variant in (ce as Dictionary).get("effects", []):
				var fd: Dictionary = fx
				var uid: String = String(fd.get("uid", ""))
				if String(fd.get("id", "")) == VIEW_GAIN_ID and uid.contains("_view_"):
					out[uid] = (fd["params"] as Dictionary)["db"]
	return out


static func crossfade_read(doc: Project, tr: Track, c: Clip, entry: Dictionary) -> void:
	var at: int = tr.index_of_clip(c, c.start)
	if at < 0:
		return
	var prev: Clip = tr.clips[at - 1] if at > 0 else null
	var nxt: Clip = tr.clips[at + 1] if at + 1 < tr.clips.size() else null
	var into: bool = c.has_transition() and str(c.transition_in.get("kind", "")) == "crossfade"
	var out_of: bool = nxt != null and nxt.has_transition() and str(nxt.transition_in.get("kind", "")) == "crossfade"
	if not into and not out_of:
		return
	var list: Array = [entry]
	for other: Clip in [prev, nxt]:
		if other != null and sounding_media(doc, tr, other) != null:
			list.append({"id": other.id, "start": other.start, "duration": other.duration, "in_offset": other.in_offset, "fade_in": 0.0, "fade_out": 0.0})
	apply_crossfades(tr, list, doc)


static func sync_entry(entry: Dictionary, video: Clip, c: Clip, views: PackedInt32Array, sync: RefCounted, stream: int = -1) -> void:
	var gain_uid: String = view_gain_uid(video, c, stream)
	var kept: Array = []
	for fx: Variant in entry.get("effects", []):
		if String((fx as Dictionary).get("uid", "")) != gain_uid:
			kept.append(fx)
	entry["effects"] = kept
	var all_hidden: bool = true
	for v: int in views:
		if not bool(sync.call("is_hidden", v)):
			all_hidden = false
	if all_hidden:
		entry["muted"] = true


static func offset_entry(entry: Dictionary, c: Clip, video: Clip, e: Dictionary, index: int) -> void:
	var p: Dictionary = ViewMap.offset_prop(e, index)
	var speed_p: Dictionary = entry.get("speed", AnimProp.make(1.0))
	var shift: float = float(entry.get("start", c.start)) - video.start
	if not AnimProp.is_animated(p) and not AnimProp.is_animated(speed_p):
		var d: float = ViewMap.offset_at(e, index, video, shift)
		var s: float = float(AnimProp.static_value(speed_p))
		var in_off: float = float(entry.get("in_offset", 0.0)) - d
		if s > 0.0 and in_off < 0.0:
			var cut: float = -in_off / s
			if cut >= float(entry.get("duration", 0.0)):
				entry["muted"] = true
				return
			trim_head(entry, cut)
			in_off = 0.0
		entry["in_offset"] = in_off
		return
	if not AnimProp.is_animated(p) and not _plant_resample:
		var d2: float = ViewMap.offset_at(e, index, video, shift)
		var in_off2: float = float(entry.get("in_offset", 0.0)) - d2
		if in_off2 >= 0.0:
			entry["in_offset"] = in_off2
			build_stats["speed_kept"] = int(build_stats.get("speed_kept", 0)) + 1
			return
	offset_by_speed(entry, video, e, index, shift)


static func _rate_at(speed_p: Dictionary, e: Dictionary, index: int, video: Clip, shift: float, x0: float, x1: float, dur: float) -> float:
	var base: float = AnimProp.evaluate_float(speed_p, (x0 + x1) * 0.5, dur)
	var moved: float = ViewMap.offset_at(e, index, video, x1 + shift) - ViewMap.offset_at(e, index, video, x0 + shift)
	return base - moved / maxf(x1 - x0, 0.000001)


static func _flat_span(speed_p: Dictionary, e: Dictionary, index: int, video: Clip, shift: float, a: float, b: float, dur: float) -> bool:
	if b - a <= 1.0 / OFFSET_SAMPLES_PER_SECOND:
		return true
	var q: float = (b - a) * 0.25
	var first: float = _rate_at(speed_p, e, index, video, shift, a, a + q, dur)
	for k: int in range(1, 4):
		if absf(_rate_at(speed_p, e, index, video, shift, a + q * float(k), a + q * float(k + 1), dur) - first) > 0.0000001:
			return false
	return true


static func offset_by_speed(entry: Dictionary, video: Clip, e: Dictionary, index: int, shift: float) -> void:
	build_stats["obs_calls"] = int(build_stats.get("obs_calls", 0)) + 1
	var dur: float = maxf(float(entry.get("duration", 0.0)), 0.0)
	if dur <= 0.0:
		return
	var speed_p: Dictionary = entry.get("speed", AnimProp.make(1.0))
	var marks: Array[float] = [0.0, dur]
	for k: Dictionary in AnimProp.keys(ViewMap.offset_prop(e, index)):
		var u: float = float(k.get("t", 0.0)) - shift
		if u > 0.0 and u < dur:
			marks.append(u)
	for k2: Dictionary in AnimProp.keys(speed_p):
		var u2: float = float(k2.get("t", 0.0))
		if u2 > 0.0 and u2 < dur:
			marks.append(u2)
	marks.sort()
	var keys: Array = []
	var last_v: float = 0.0
	for m: int in marks.size() - 1:
		var a: float = marks[m]
		var b: float = marks[m + 1]
		if b - a < 0.000001:
			continue
		var flat_span: bool = _flat_span(speed_p, e, index, video, shift, a, b, dur)
		build_stats["spans_flat" if flat_span else "spans_dense"] = int(build_stats.get("spans_flat" if flat_span else "spans_dense", 0)) + 1
		var n: int = 1 if flat_span else clampi(int(ceil((b - a) * OFFSET_SAMPLES_PER_SECOND - 0.000000001)), 1, OFFSET_SAMPLES_MAX)
		for j: int in n:
			var x0: float = a + (b - a) * float(j) / float(n)
			var x1: float = a + (b - a) * float(j + 1) / float(n)
			var base: float = AnimProp.evaluate_float(speed_p, (x0 + x1) * 0.5, dur)
			var moved: float = ViewMap.offset_at(e, index, video, x1 + shift) - ViewMap.offset_at(e, index, video, x0 + shift)
			var v: float = base - moved / (x1 - x0)
			if keys.is_empty() or absf(v - last_v) > 0.0000001:
				keys.append({"t": x0, "v": v, "i": "hold"})
				last_v = v
	if keys.is_empty():
		return
	entry["speed"] = {"a": true, "base": float((keys[0] as Dictionary)["v"]), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}]}
	var in_off: float = float(entry.get("in_offset", 0.0)) - ViewMap.offset_at(e, index, video, shift)
	entry["in_offset"] = in_off
	if in_off >= 0.0:
		return
	var pos: float = in_off
	for i: int in keys.size():
		var t0: float = float((keys[i] as Dictionary)["t"])
		var t1: float = float((keys[i + 1] as Dictionary)["t"]) if i + 1 < keys.size() else dur
		var v0: float = float((keys[i] as Dictionary)["v"])
		var span: float = t1 - t0
		if v0 > 0.0 and pos + v0 * span >= 0.0:
			var cut: float = t0 + (-pos) / v0
			if cut >= dur:
				break
			trim_head(entry, cut)
			entry["in_offset"] = 0.0
			return
		pos += v0 * span
	entry["muted"] = true


static func trim_head(entry: Dictionary, cut: float) -> void:
	entry["start"] = float(entry.get("start", 0.0)) + cut
	entry["duration"] = float(entry.get("duration", 0.0)) - cut
	entry["fade_in"] = maxf(float(entry.get("fade_in", 0.0)) - cut, 0.0)
	for key: String in ["volume", "pan", "speed"]:
		var p: Variant = entry.get(key, null)
		if p is Dictionary:
			entry[key] = AnimProp.shift_keys(p, -cut)
	for fx: Variant in entry.get("effects", []):
		var params: Variant = (fx as Dictionary).get("params", null)
		if not (params is Dictionary):
			continue
		var pd: Dictionary = params
		for pk: Variant in pd.keys():
			if pd[pk] is Dictionary:
				pd[pk] = AnimProp.shift_keys(pd[pk], -cut)
