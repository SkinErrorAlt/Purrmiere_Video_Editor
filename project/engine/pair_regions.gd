extends Node

const LayerChain := preload("res://engine/layer_chain.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PairSyncState := preload("res://engine/pair_sync_state.gd")
const PlaybackClock := preload("res://engine/playback_clock.gd")
const RegionBlocks := preload("res://engine/region_blocks.gd")
const PAIR_VIEW_ID := "pair_view"
const LIMIT_EFFECT_ID := "time_fps_limit"
const REGION_MAX := 8
const SAME_TIME := 0.0000005
const SHADOW_FIELDS: PackedStringArray = ["anim_speed", "anim_start"]
const REGION_TEX := "region_tex"
const REGION_BITS := "region_own"
const HINT_PLAY := 1
const HINT_STEP := 2
const HINT_EXPORT := 3
const SOURCE_GAP_FRAMES := 0.5
const LANE_IDLE_MS := 15000
const HOLD_LIMIT_MS := 500
const HOLD_LIMIT_PAUSED_MS := 4000

var sources: Dictionary = {}
var opened_total: int = 0
var closed_total: int = 0
var handovers: int = 0
var prepared: int = 0
var held_cuts: int = 0
var playing: bool = false
var export_ahead: bool = false
var use_proxy: bool = false
var warm_for_play: bool = false
var seq: Sequence = null
var _preparing: bool = false
var _pool: Dictionary = {}
var _serial: int = 0


func _init() -> void:
	name = "PairRegions"


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for key: Variant in sources.keys():
			_free_chain(sources[key])
		sources = {}
		for path: Variant in _pool.keys():
			for lane: Dictionary in _pool[path]:
				_close(int(lane["handle"]))
		_pool = {}


static func pair_entries(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID and bool(e.get("enabled", true)):
			out.append(e)
	return out


static func pass_for(l: LayerChain, uid: String) -> EffectPass:
	for pd: Dictionary in l.passes:
		if String(pd.get("uid", "")) == uid and String(pd.get("kind", "")) == "effect":
			return pd["pass"]
	return null


static func takes_offsets(kind: String) -> bool:
	return kind == FrameSource.KIND_NATIVE or kind == FrameSource.KIND_PATTERN


static func key_of(c: Clip, uid: String, index: int) -> String:
	return c.id + "|" + uid + "|" + str(index)


func begin_frame() -> void:
	_serial += 1


func live_count() -> int:
	var n: int = 0
	for path: Variant in _pool.keys():
		n += (_pool[path] as Array).size()
	return n


func source_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: Variant in sources.keys():
		out.append(String(key))
	return out


func update_layer(l: LayerChain, t: float, quality: int, hint: int) -> Vector2i:
	var counts: Vector2i = Vector2i.ZERO
	var c: Clip = l.clip
	if c == null:
		return counts
	var offsets: PackedFloat64Array = PackedFloat64Array()
	for e: Dictionary in pair_entries(c):
		counts += _update_entry(l, c, e, t, quality, hint, offsets)
	l.source.tap_offsets = offsets
	return counts


func _update_entry(l: LayerChain, c: Clip, e: Dictionary, t: float, quality: int, hint: int, offsets: PackedFloat64Array) -> Vector2i:
	var counts: Vector2i = Vector2i.ZERO
	var uid: String = String(e.get("uid", ""))
	var p: EffectPass = pass_for(l, uid)
	if p == null:
		return counts
	var count: int = mini(ViewMap.crop_count(e), REGION_MAX)
	var bits: int = 0
	var raw: Dictionary = {}
	var pv_index: int = c.effects.find(e)
	if takes_offsets(l.source.kind):
		for i: int in count:
			if not ViewMap.has_offset(e, i):
				continue
			var key: String = key_of(c, uid, i)
			var o: float = _view_offset(c, e, i, t, l.media.fps if l.media != null else 30.0)
			var tap: bool = _tap_ok(l, o, hint)
			var rec: Dictionary = _ensure(key, l.media, l.source.kind, l.source.native_size, l.registry, c, e, i, t, l.track_index, tap)
			rec["touched"] = _serial
			if absf(o) <= SAME_TIME or bool(rec.get("failed", false)):
				continue
			if not tap:
				_end_tap(rec)
			_own_lane(key, rec)
			if tap:
				_use_tap(rec, l.source.handle, i)
				offsets.append(o)
			var chain: LayerChain = rec["chain"]
			var shadow: Clip = rec["shadow"]
			sync_shadow(shadow, c, pv_index)
			RegionBlocks.shape_shadow(shadow, c, e, i)
			shadow.in_offset = c.in_offset - o
			if chain.get_parent() != p:
				if chain.get_parent() != null:
					chain.get_parent().remove_child(chain)
				p.add_child(chain)
			if chain.waiting:
				chain.set_waiting(false)
			chain.quality_scale = l.quality_scale
			chain.px_scale_bias = l.px_scale_bias
			chain.seq_size = l.seq_size
			chain.seq_fps = l.seq_fps
			chain.clip = shadow
			chain.ensure_structure()
			chain.set_visible_in_stage(false)
			chain.source.use_proxy = use_proxy
			chain.source.warm_for_play = warm_for_play
			chain.request_source(t, quality, hint)
			chain.update_passes(t)
			chain.update_masks(t)
			var st: String = chain.state()
			var shown_tex: String = "region_shown" + str(i)
			if not chain.source.primed and _holding(rec, p, shown_tex):
				counts.x += 1
				bits |= 1 << i
				raw[i] = p.get_meta("region_raw" + str(i))
				rec["holding"] = true
				(p.get_meta(shown_tex) as LayerChain).source.hold_picture()
				continue
			rec["holding"] = false
			rec["due_ms"] = -1
			var tex: Texture2D = chain.outer_tex
			if tex == null:
				continue
			p.set_param("region_tex" + str(i), tex)
			bits |= 1 << i
			var raw_tex: Texture2D = chain.source.texture() if chain.source != null else null
			raw[i] = raw_tex if raw_tex != null else tex
			if chain.source.primed:
				p.set_meta(shown_tex, chain)
				p.set_meta("region_raw" + str(i), raw[i])
			if st == "pending" or (st == "none" and int(rec.get("handle", -1)) >= 0):
				counts.x += 1
			elif st == "approx" or st == "near":
				counts.y += 1
	bits = l.regions.merge(e, p, bits, raw)
	p.set_param("region_own", bits)
	feed_paired(l, e, bits, raw)
	var sync: RefCounted = PairSyncState.instance()
	if bool(sync.call("live_for", c.id, uid)):
		p.set_param("sync_mode", int(sync.call("picture_mode")))
		p.set_param("sync_show", int(sync.call("show_mask", count)))
	else:
		p.set_param("sync_mode", 0)
		p.set_param("sync_show", 255)
	return counts


func _holding(rec: Dictionary, p: EffectPass, shown_tex: String) -> bool:
	if not p.has_meta(shown_tex):
		return false
	var was: Variant = p.get_meta(shown_tex)
	if not is_instance_valid(was) or (was as Node).is_queued_for_deletion() or was == rec.get("chain", null):
		return false
	var now: int = Time.get_ticks_msec()
	if int(rec.get("due_ms", -1)) < 0:
		rec["due_ms"] = now
		held_cuts += 1
	return now - int(rec["due_ms"]) <= (HOLD_LIMIT_MS if playing else HOLD_LIMIT_PAUSED_MS)


func prepare(c: Clip, prev: Clip, m: MediaItem, kind: String, size: Vector2i, registry: RefCounted, at: float, quality: int, track_index: int, like: LayerChain, warm: bool = true) -> bool:
	if c == null or not takes_offsets(kind):
		return true
	_preparing = true
	var ready: bool = _prepare_entries(c, prev, m, kind, size, registry, at, quality, track_index, like, warm)
	_preparing = false
	return ready


func _prepare_entries(c: Clip, prev: Clip, m: MediaItem, kind: String, size: Vector2i, registry: RefCounted, at: float, quality: int, track_index: int, like: LayerChain, warm: bool = true) -> bool:
	var ready: bool = true
	for e: Dictionary in pair_entries(c):
		var uid: String = String(e.get("uid", ""))
		var count: int = mini(ViewMap.crop_count(e), REGION_MAX)
		var pv_index: int = c.effects.find(e)
		for i: int in count:
			if not ViewMap.has_offset(e, i):
				continue
			var o: float = _view_offset(c, e, i, at, m.fps if m != null else 30.0)
			if absf(o) <= SAME_TIME:
				continue
			var key: String = key_of(c, uid, i)
			if not sources.has(key) and _will_continue(prev, c, e, i, m):
				continue
			var tap: bool = not export_ahead and like != null and _tap_ok(like, o, HINT_PLAY)
			if not tap and like == null and not export_ahead and taps_enabled and not sources.has(key) and PlayPace.tap_fits(o, m.fps if m != null else 30.0):
				ready = false
				continue
			var rec: Dictionary = _ensure(key, m, kind, size, registry, c, e, i, at, track_index, tap)
			rec["touched"] = _serial
			if bool(rec.get("failed", false)):
				continue
			if not tap:
				_end_tap(rec)
			_own_lane(key, rec)
			if tap:
				_use_tap(rec, like.source.handle, PREP_SLOT + i)
				var offs: PackedFloat64Array = like.source.tap_offsets
				if not offs.has(o):
					offs.append(o)
					like.source.tap_offsets = offs
			var chain: LayerChain = rec["chain"]
			if chain.get_parent() == null:
				add_child(chain)
			if chain.get_parent() == self and not chain.waiting:
				chain.set_waiting(true)
			var shadow: Clip = rec["shadow"]
			sync_shadow(shadow, c, pv_index)
			RegionBlocks.shape_shadow(shadow, c, e, i)
			shadow.in_offset = c.in_offset - o
			chain.clip = shadow
			if like != null:
				chain.quality_scale = like.quality_scale
				chain.px_scale_bias = like.px_scale_bias
				chain.seq_size = like.seq_size
				chain.seq_fps = like.seq_fps
			chain.ensure_structure()
			chain.source.use_proxy = use_proxy
			chain.source.warm_for_play = warm_for_play
			chain.request_source(at, quality, HINT_EXPORT if export_ahead else (HINT_PLAY if warm and chain.source.primed else HINT_STEP))
			rec["asked_ms"] = Time.get_ticks_msec()
			if not chain.source.primed:
				ready = false
	return ready


func _will_continue(prev: Clip, c: Clip, e: Dictionary, index: int, m: MediaItem) -> bool:
	if prev == null:
		return false
	for pe: Dictionary in pair_entries(prev):
		var rec: Dictionary = sources.get(key_of(prev, String(pe.get("uid", "")), index), {})
		if rec.is_empty() or not is_instance_valid(rec.get("chain", null)):
			continue
		var fps: float = (rec["chain"] as LayerChain).seq_fps
		if region_continues(prev, pe, c, e, index, m.fps if m != null else 30.0, fps, m.duration if m != null else 0.0, playing):
			return true
	return false


func ready_for(c: Clip, t: float) -> bool:
	if c == null:
		return true
	for e: Dictionary in pair_entries(c):
		var uid: String = String(e.get("uid", ""))
		for i: int in mini(ViewMap.crop_count(e), REGION_MAX):
			if not ViewMap.has_offset(e, i):
				continue
			var rm: Variant = (sources.get(key_of(c, uid, i), {}) as Dictionary).get("m", null)
			if absf(_view_offset(c, e, i, t, (rm as MediaItem).fps if rm is MediaItem else 30.0)) <= SAME_TIME:
				continue
			var rec: Dictionary = sources.get(key_of(c, uid, i), {})
			if rec.is_empty() or bool(rec.get("failed", false)):
				continue
			var chain: Variant = rec.get("chain", null)
			if not is_instance_valid(chain) or not (chain as LayerChain).source.ready_now():
				return false
	return true


func asked_age_ms(c: Clip) -> int:
	var worst: int = -1
	if c == null:
		return worst
	var now: int = Time.get_ticks_msec()
	for e: Dictionary in pair_entries(c):
		var uid: String = String(e.get("uid", ""))
		for i: int in mini(ViewMap.crop_count(e), REGION_MAX):
			var rec: Dictionary = sources.get(key_of(c, uid, i), {})
			if rec.is_empty():
				continue
			worst = maxi(worst, now - int(rec.get("asked_ms", 0)))
	return worst


static func region_source(c: Clip, e: Dictionary, index: int, t: float, media_fps: float, seq_fps: float, media_duration: float = 0.0, paced: bool = false) -> float:
	if c == null:
		return 0.0
	var o: float = PlayPace.view_offset(c, ViewMap.offset_at(e, index, c, t - c.start), t, media_fps)
	var keep: float = c.in_offset
	c.in_offset = keep - o
	var at: float = PlayPace.grid_time(c, t, seq_fps) if paced and PlayPace.fast(c, t) else t
	var src: float = PlaybackClock.source_time_for(c, at, media_fps, seq_fps)
	if c.loop and media_duration > 0.0:
		src = c.loop_source(src, media_duration)
	c.in_offset = keep
	if media_duration > 0.0:
		src = clampf(src, 0.0, media_duration)
	return maxf(src, 0.0)


static func region_continues(a: Clip, ea: Dictionary, b: Clip, eb: Dictionary, index: int, media_fps: float, seq_fps: float, media_duration: float = 0.0, paced: bool = false) -> bool:
	if a == null or b == null or a == b or a.media_id != b.media_id or absf(a.end() - b.start) > 0.002:
		return false
	var step: float = 1.0 / (media_fps if media_fps > 0.0 else 30.0)
	var end_src: float = region_source(a, ea, index, a.end(), media_fps, seq_fps, media_duration, paced)
	var start_src: float = region_source(b, eb, index, b.start, media_fps, seq_fps, media_duration, paced)
	return absf(end_src - start_src) <= step * SOURCE_GAP_FRAMES


func _adopt(key: String, c: Clip, e: Dictionary, index: int, m: MediaItem, kind: String, path: String, track_index: int, t: float) -> Dictionary:
	var seq_fps: float = 30.0
	var media_fps: float = m.fps if m != null and m.fps > 0.0 else 30.0
	for k: Variant in sources.keys():
		var rec: Dictionary = sources[k]
		if int(rec.get("touched", -1)) == _serial or String(rec.get("kind", "")) != kind or String(rec.get("path", "")) != path:
			continue
		if int(rec.get("track", -1)) != track_index or int(rec.get("index", -1)) != index:
			continue
		var owner: Variant = rec.get("clip", null)
		if not (owner is Clip) or not is_instance_valid(rec.get("chain")):
			continue
		var chain: LayerChain = rec["chain"]
		if not chain.source.primed:
			continue
		seq_fps = chain.seq_fps
		var now_clip: Clip = seq.clip_by_id((owner as Clip).id) if seq != null else null
		var was: Clip = now_clip if now_clip != null else owner
		var ea: Dictionary = was.effect_by_uid(String(rec.get("uid", "")))
		var dur: float = m.duration if m != null else 0.0
		var same_frame: bool = absf(region_source(c, e, index, t, media_fps, seq_fps, dur, playing) - chain.source.last_time) <= 0.5 / media_fps
		if not same_frame and (ea.is_empty() or not region_continues(was, ea, c, e, index, media_fps, seq_fps, dur, playing)):
			continue
		sources.erase(k)
		rec["clip"] = c
		rec["uid"] = String(e.get("uid", ""))
		rec.erase("due_ms")
		_rekey_lane(String(k), key)
		sources[key] = rec
		handovers += 1
		return rec
	return {}


func _ensure(key: String, m: MediaItem, kind: String, size: Vector2i, registry: RefCounted, c: Clip, e: Dictionary, index: int, t: float, track_index: int, tap: bool = false) -> Dictionary:
	var rec: Dictionary = sources.get(key, {})
	var path: String = m.path if m != null else ""
	if not rec.is_empty():
		if String(rec.get("kind", "")) == kind and String(rec.get("path", "")) == path:
			rec["clip"] = c
			rec["track"] = track_index
			if not is_instance_valid(rec.get("chain")):
				rec["chain"] = _new_chain(key, m, kind, size, registry, rec["shadow"], int(rec.get("handle", -1)))
			return rec
		_drop(key)
	var adopted: Dictionary = _adopt(key, c, e, index, m, kind, path, track_index, t)
	if not adopted.is_empty():
		return adopted
	var shadow: Clip = Clip.new()
	sync_shadow(shadow, c, -1)
	rec = {"shadow": shadow, "handle": -1, "path": path, "kind": kind, "failed": false, "touched": _serial, "clip": c, "uid": String(e.get("uid", "")), "index": index, "track": track_index, "m": m, "size": size, "registry": registry}
	sources[key] = rec
	if kind == FrameSource.KIND_NATIVE:
		_own_lane(key, rec)
		rec["failed"] = int(rec["handle"]) < 0 and not tap
	rec["chain"] = _new_chain(key, m, kind, size, registry, shadow, int(rec["handle"]))
	prepared += 1
	return rec


func _new_chain(key: String, m: MediaItem, kind: String, native: Vector2i, registry: RefCounted, shadow: Clip, handle: int) -> LayerChain:
	var chain: LayerChain = LayerChain.new()
	chain.name = "PairRegion_" + key.replace("|", "_")
	var size: Vector2i = native
	if m != null and m.width > 0 and m.height > 0:
		size = Vector2i(m.width, m.height)
	chain.setup(shadow, m, registry, kind, size, handle)
	return chain


func _lanes(path: String) -> Array:
	if not _pool.has(path):
		_pool[path] = []
	return _pool[path]


func _own_lane(key: String, rec: Dictionary) -> void:
	if String(rec.get("kind", "")) != FrameSource.KIND_NATIVE:
		return
	var path: String = String(rec.get("path", ""))
	var lanes: Array = _lanes(path)
	var want: int = int(rec.get("handle", -1))
	var pick: Dictionary = {}
	for lane: Dictionary in lanes:
		if int(lane["handle"]) == want and (_lane_free(lane) or String(lane["owner"]) == key):
			pick = lane
			break
	if pick.is_empty():
		for lane2: Dictionary in lanes:
			if _lane_free(lane2) and (String(lane2["last"]).is_empty() or not sources.has(String(lane2["last"])) or String(lane2["last"]) == key):
				pick = lane2
				break
	if pick.is_empty():
		for lane3: Dictionary in lanes:
			if _lane_free(lane3):
				pick = lane3
				break
	if pick.is_empty():
		var h: int = _open(path)
		if h < 0:
			rec["handle"] = -1
			return
		pick = {"handle": h, "owner": "", "last": "", "free_ms": Time.get_ticks_msec()}
		lanes.append(pick)
	pick["owner"] = key
	pick["last"] = key
	var h2: int = int(pick["handle"])
	if h2 != want:
		rec["handle"] = h2
		var chain: Variant = rec.get("chain", null)
		if is_instance_valid(chain):
			var lc: LayerChain = chain
			if bool(rec.get("from_tap", false)) and lc.source.kind == FrameSource.KIND_NATIVE:
				lc.source.rehandle(h2)
			else:
				lc.setup(rec["shadow"], rec.get("m", lc.media), lc.registry, String(rec["kind"]), lc.source.native_size, h2)
	rec.erase("from_tap")


func _lane_free(lane: Dictionary) -> bool:
	var owner: String = String(lane["owner"])
	if owner.is_empty():
		return true
	if not _preparing:
		return false
	var rec: Dictionary = sources.get(owner, {})
	return rec.is_empty() or int(rec.get("touched", -1)) != _serial


func _rekey_lane(from_key: String, to_key: String) -> void:
	for path: Variant in _pool.keys():
		for lane: Dictionary in _pool[path]:
			if String(lane["owner"]) == from_key:
				lane["owner"] = to_key
			if String(lane["last"]) == from_key:
				lane["last"] = to_key


func _open(path: String) -> int:
	var bridge: Node = _bridge()
	if bridge == null or not bool(bridge.get("available")) or path.is_empty() or not FileAccess.file_exists(path):
		return -1
	var hw: bool = true
	var prefs: Node = _root_node("Prefs")
	if prefs != null and bool(prefs.call("is_registered", "playback.hw_decode")):
		hw = bool(prefs.call("get_value", "playback.hw_decode"))
	var h: int = int(bridge.call("open_media", path, {"hw": hw}))
	if h < 0:
		return -1
	opened_total += 1
	var session: Node = _root_node("Session")
	if session != null:
		var q: int = int(session.get("playback_quality"))
		if q > 0:
			bridge.call("set_quality", h, q)
	return h


func _close(h: int) -> void:
	if h < 0:
		return
	closed_total += 1
	var bridge: Node = _bridge()
	if bridge != null and bool(bridge.get("available")):
		bridge.call("close_media", h)


func _free_chain(rec: Dictionary) -> void:
	var chain: Variant = rec.get("chain")
	if is_instance_valid(chain):
		var n: Node = chain
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()
	rec.erase("chain")


func _drop(key: String) -> void:
	if not sources.has(key):
		return
	var rec: Dictionary = sources[key]
	_free_chain(rec)
	sources.erase(key)
	for path: Variant in _pool.keys():
		for lane: Dictionary in _pool[path]:
			if String(lane["owner"]) == key:
				lane["owner"] = ""
				lane["free_ms"] = Time.get_ticks_msec()
			if String(lane["last"]) == key:
				lane["last"] = ""


func sweep(seq: Sequence) -> void:
	for key: Variant in sources.keys():
		var rec: Dictionary = sources[key]
		if int(rec.get("touched", -1)) == _serial:
			continue
		rec.erase("due_ms")
		if still_wanted(seq, String(key)):
			var chain: Variant = rec.get("chain", null)
			if is_instance_valid(chain) and not (chain as LayerChain).waiting:
				(chain as LayerChain).set_waiting(true)
			continue
		_drop(String(key))
	var now: int = Time.get_ticks_msec()
	for path: Variant in _pool.keys():
		var lanes: Array = _pool[path]
		var any_rec: bool = false
		for k2: Variant in sources.keys():
			if String((sources[k2] as Dictionary).get("path", "")) == String(path):
				any_rec = true
				break
		for i: int in range(lanes.size() - 1, -1, -1):
			var lane: Dictionary = lanes[i]
			var owner: String = String(lane["owner"])
			if not owner.is_empty() and (not sources.has(owner) or int((sources[owner] as Dictionary).get("touched", -1)) != _serial):
				lane["owner"] = ""
				lane["free_ms"] = now
				owner = ""
			if not owner.is_empty() or playing:
				continue
			if not any_rec or now - int(lane["free_ms"]) > LANE_IDLE_MS:
				for k3: Variant in sources.keys():
					var r3: Dictionary = sources[k3]
					if int(r3.get("handle", -1)) == int(lane["handle"]):
						r3["handle"] = -1
						_free_chain(r3)
				_close(int(lane["handle"]))
				lanes.remove_at(i)
		if lanes.is_empty():
			_pool.erase(path)


static func still_wanted(seq: Sequence, key: String) -> bool:
	if seq == null:
		return false
	var parts: PackedStringArray = key.split("|")
	if parts.size() < 3:
		return false
	var c: Clip = seq.clip_by_id(parts[0])
	if c == null:
		return false
	var e: Dictionary = c.effect_by_uid(parts[1])
	if e.is_empty() or not bool(e.get("enabled", true)):
		return false
	return ViewMap.has_offset(e, int(parts[2]))


func prime_all(quality: int) -> int:
	var n: int = 0
	for key: Variant in sources.keys():
		var chain: Variant = (sources[key] as Dictionary).get("chain", null)
		if is_instance_valid(chain) and (chain as LayerChain).is_inside_tree() and not (chain as LayerChain).waiting:
			if (chain as LayerChain).source.prime_for_play(quality):
				n += 1
	return n


func forget_records() -> void:
	for key: Variant in sources.keys():
		_free_chain(sources[key])
	sources = {}
	var now: int = Time.get_ticks_msec()
	for path: Variant in _pool.keys():
		for lane: Dictionary in _pool[path]:
			lane["owner"] = ""
			lane["last"] = ""
			lane["free_ms"] = now


func drop_all() -> void:
	for key: Variant in sources.keys():
		_drop(String(key))
	for path: Variant in _pool.keys():
		for lane: Dictionary in _pool[path]:
			_close(int(lane["handle"]))
	_pool = {}


static func paired_passes(l: LayerChain, e: Dictionary) -> Array[EffectPass]:
	var out: Array[EffectPass] = []
	var c: Clip = l.clip
	if c == null or l.registry == null:
		return out
	var uid: String = String(e.get("uid", ""))
	for pd: Dictionary in l.passes:
		if String(pd.get("kind", "")) != "effect" or String(pd.get("uid", "")) == uid:
			continue
		var gp: EffectPass = pd["pass"]
		if gp == null or not gp.has_uniform(REGION_BITS):
			continue
		var def: Dictionary = l.registry.call("get_def", String(pd.get("effect_id", "")))
		var pairs: PackedStringArray = def.get("pairs_with", PackedStringArray())
		if not pairs.has(PAIR_VIEW_ID):
			continue
		var other: Dictionary = l.paired_effect(int(pd.get("effect_index", -1)), pairs)
		if String(other.get("uid", "")) == uid:
			out.append(gp)
	return out


static func feed_paired(l: LayerChain, e: Dictionary, bits: int, raw: Dictionary) -> int:
	var fed: int = 0
	for gp: EffectPass in paired_passes(l, e):
		for key: Variant in raw.keys():
			gp.set_param(REGION_TEX + str(int(key)), raw[key])
		gp.set_param(REGION_BITS, bits)
		fed += 1
	return fed


static func sync_shadow(shadow: Clip, c: Clip, pv_index: int) -> void:
	shadow.id = c.id
	shadow.media_id = c.media_id
	shadow.start = c.start
	shadow.duration = c.duration
	shadow.speed = c.speed
	shadow.enabled = true
	for field: String in SHADOW_FIELDS:
		var v: Variant = c.get(field)
		if v != null:
			shadow.set(field, v)
	var fx: Array[Dictionary] = []
	for k: int in c.effects.size():
		var e: Dictionary = c.effects[k]
		if (pv_index < 0 or k < pv_index) or String(e.get("id", "")) == LIMIT_EFFECT_ID:
			fx.append(e)
	shadow.effects = fx
	var used: PackedStringArray = LayerChain.effect_mask_ids(shadow)
	var ms: Array[Dictionary] = []
	for m: Dictionary in c.masks:
		if used.has(String(m.get("id", ""))):
			ms.append(m)
	shadow.masks = ms
	shadow.transition_in = {}
	shadow.motion_blur = {"on": false}


func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func _bridge() -> Node:
	return _root_node("PurrBridge")


const PairLayout := preload("res://engine/pair_layout.gd")


static func region_boxes(c: Clip, e: Dictionary, t: float, frame: Vector2i, source: Vector2i, fps: float = 30.0) -> Array[Dictionary]:
	return PairLayout.region_boxes(c, e, t, frame, source, fps)


static func region_at(c: Clip, e: Dictionary, t: float, frame: Vector2i, source: Vector2i, uv: Vector2, fps: float = 30.0) -> int:
	return PairLayout.region_at(PairLayout.region_boxes(c, e, t, frame, source, fps), uv)


const PlayPace := preload("res://engine/play_pace.gd")
const PREP_SLOT := 8

static var taps_enabled: bool = true

var taps_used: int = 0


func _view_offset(c: Clip, e: Dictionary, i: int, t: float, fps: float) -> float:
	return PlayPace.view_offset(c, ViewMap.offset_at(e, i, c, t - c.start), t, fps)


func _tap_ok(l: LayerChain, o: float, hint: int) -> bool:
	if not taps_enabled or not playing or hint == HINT_EXPORT or export_ahead or absf(o) <= SAME_TIME:
		return false
	if l == null or l.source == null or l.source.kind != FrameSource.KIND_NATIVE or l.source.handle < 0 or l.source.proxy_on:
		return false
	if not PlayPace.tap_fits(o, l.media.fps if l.media != null else 30.0):
		return false
	var b: Node = _bridge()
	return b != null and b.has_method("can_tap") and bool(b.call("can_tap"))


func _use_tap(rec: Dictionary, h: int, slot: int) -> void:
	var chain: Variant = rec.get("chain", null)
	if not is_instance_valid(chain):
		return
	var lc: LayerChain = chain
	lc.source.tap_handle = h
	lc.source.tap_slot = slot
	rec["tap"] = true
	rec["failed"] = false
	taps_used += 1


func _end_tap(rec: Dictionary) -> void:
	if not bool(rec.get("tap", false)):
		return
	rec["tap"] = false
	rec["from_tap"] = true
	var chain: Variant = rec.get("chain", null)
	if is_instance_valid(chain):
		(chain as LayerChain).source.tap_handle = -1

