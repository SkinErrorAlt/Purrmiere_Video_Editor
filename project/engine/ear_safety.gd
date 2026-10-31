extends Node

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const SELF_PATH := "res://engine/ear_safety.gd"
const BUS_PATH := "res://modules/core_panels/panel_bus.gd"
const LISTEN_PATH := "res://modules/core_panels/stream_listen.gd"
const NODE_NAME := "EarSafety"
const PREF_SCOPE := "ear_safety.scope"
const PREF_CEILING := "ear_safety.ceiling_db"
const PREF_TARGET := "ear_safety.target"
const PREF_ALERT := "ear_safety.alert"
const PREF_COOLDOWN := "ear_safety.alert_cooldown"
const SCOPE_OFF := "Off"
const SCOPE_PROJECT := "Whole project and bin"
const SCOPE_TRACKS := "Marked tracks"
const SCOPE_CLIPS := "Marked clips"
const SCOPES: PackedStringArray = ["Off", "Whole project and bin", "Marked tracks", "Marked clips"]
const TARGET_YOUTUBE := "YouTube, -14 LUFS"
const TARGET_EBU := "EBU R128, -23 LUFS"
const TARGETS: Dictionary = {"YouTube, -14 LUFS": -14.0, "EBU R128, -23 LUFS": -23.0}
const ALERT_VISUAL := "Visual"
const ALERT_TONE := "Tone"
const ALERT_BOTH := "Visual and tone"
const ALERT_OFF := "Off"
const ALERTS: PackedStringArray = ["Visual", "Tone", "Visual and tone", "Off"]
const DEFAULT_CEILING := -1.0
const DEFAULT_COOLDOWN := 60.0
const VIEW_KEY := "ear_safety"
const GAIN_NAME := "PurrEarGain"
const LIMIT_NAME := "PurrEarLimiter"
const MASTER := 0
const WINDOW_SECONDS := 3.0
const MAX_WINDOWS := 12
const MAX_JOBS := 3
const STEREO_OFFSET_DB := 2.32
const ABS_GATE := -70.0
const REL_GATE := -10.0
const SILENT := -200.0
const LOOKAHEAD := 0.25
const RELEASE_DB_PER_SECOND := 6.0
const HARD_OVER_DB := 3.0
const RENEW_QUIET_SECONDS := 2.0
const RENEW_MARGIN_DB := 6.0
const SHOWN_REDUCTION_DB := 0.5
const CACHE_FILE := "ear_safety_loudness.json"
const TAG_PREFIX := "ear:"
const SAVE_DELAY := 2.0
const TONE_HZ := 880.0
const TONE_SECONDS := 0.18
const TONE_LEVEL := 0.06

signal measured(media_id: String)
signal alerted(over_db: float)

static var _inst: Node = null

var gain_db: float = 0.0
var want_db: float = 0.0
var alerts: int = 0
var clamps: int = 0
var _gain_fx: AudioEffectAmplify = null
var _limit_fx: AudioEffectHardLimiter = null
var _fx_on: int = -1
var _cache: Dictionary = {}
var _key_of: Dictionary = {}
var _media_of_key: Dictionary = {}
var _pending: Dictionary = {}
var _partial: Dictionary = {}
var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}
var _jobs_out: int = 0
var _serial: int = 0
var _preview: Dictionary = {}
var _last_alert_ms: int = -1
var _quiet_session: bool = false
var _tone: AudioStreamPlayer = null
var _cache_dirty: bool = false
var _save_wait: float = 0.0
var _watched: WeakRef = null
var renewals: int = 0
var _engaged: bool = false
var _quiet_for: float = 0.0
var _last_playing: bool = false
var _last_owner: String = ""


static func ensure() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var found: Node = root.get_node_or_null(NODE_NAME)
	if found != null:
		_inst = found
		return found
	var script: GDScript = load(SELF_PATH)
	var n: Node = script.new()
	n.name = NODE_NAME
	_inst = n
	root.add_child.call_deferred(n)
	return n


static func instance() -> Node:
	return ensure()


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF_SCOPE):
		Prefs.register(PREF_SCOPE, SCOPE_PROJECT, {"label": "Ear safety: what it protects", "type": "enum", "choices": SCOPES, "hint": "Only what you hear while editing. Exports are never changed. The ceiling holds everything that plays; the loudness turn down covers the whole project and bin, only tracks you mark, or only clips you mark."})
	if not Prefs.is_registered(PREF_CEILING):
		Prefs.register(PREF_CEILING, DEFAULT_CEILING, {"label": "Ear safety: ceiling (dBFS)", "type": "float", "min": -12.0, "max": 0.0, "hint": "Nothing you hear goes above this. -1 dB is the usual safe ceiling."})
	if not Prefs.is_registered(PREF_TARGET):
		Prefs.register(PREF_TARGET, TARGET_YOUTUBE, {"label": "Ear safety: loudest a file may play", "type": "enum", "choices": PackedStringArray(TARGETS.keys()), "hint": "A file measured louder than this plays turned down while you edit. It is never turned up."})
	if not Prefs.is_registered(PREF_ALERT):
		Prefs.register(PREF_ALERT, ALERT_VISUAL, {"label": "Ear safety: tell me when it holds a loud peak", "type": "enum", "choices": ALERTS})
	if not Prefs.is_registered(PREF_COOLDOWN):
		Prefs.register(PREF_COOLDOWN, DEFAULT_COOLDOWN, {"label": "Ear safety: at most one alert every (seconds)", "type": "float", "min": 5.0, "max": 3600.0})


static func scope() -> String:
	register_prefs()
	var v: String = String(Prefs.get_value(PREF_SCOPE))
	return v if v in SCOPES else SCOPE_PROJECT


static func ceiling() -> float:
	register_prefs()
	return clampf(float(Prefs.get_value(PREF_CEILING)), -12.0, 0.0)


static func target_lufs() -> float:
	register_prefs()
	return float(TARGETS.get(String(Prefs.get_value(PREF_TARGET)), -14.0))


static func alert_mode() -> String:
	register_prefs()
	var v: String = String(Prefs.get_value(PREF_ALERT))
	return v if v in ALERTS else ALERT_VISUAL


static func cooldown() -> float:
	register_prefs()
	return maxf(float(Prefs.get_value(PREF_COOLDOWN)), 1.0)


static func lin_to_db(v: float) -> float:
	if v <= 0.0:
		return SILENT
	return 20.0 * log(v) / log(10.0)


static func window_lufs(rms_db: float) -> float:
	if rms_db <= -119.0:
		return SILENT
	return rms_db + STEREO_OFFSET_DB


static func estimate_lufs(windows: Array) -> float:
	var passing: Array[float] = []
	for w: Variant in windows:
		var l: float = window_lufs(float((w as Dictionary).get("rms_db", -120.0)))
		if l > ABS_GATE:
			passing.append(l)
	if passing.is_empty():
		return SILENT
	var gate: float = _energy_mean(passing) + REL_GATE
	var kept: Array[float] = []
	for l2: float in passing:
		if l2 > gate:
			kept.append(l2)
	return _energy_mean(kept if not kept.is_empty() else passing)


static func _energy_mean(list: Array[float]) -> float:
	var sum: float = 0.0
	for l: float in list:
		sum += pow(10.0, l / 10.0)
	return 10.0 * log(sum / float(list.size())) / log(10.0)


static func reduction_db(lufs: float, target: float) -> float:
	if lufs <= SILENT + 1.0:
		return 0.0
	return minf(0.0, target - lufs)


static func windows_for(duration: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if duration <= 0.0:
		return out
	if duration <= WINDOW_SECONDS:
		out.append(Vector2(0.0, duration))
		return out
	var n: int = clampi(int(ceil(duration / WINDOW_SECONDS)), 1, MAX_WINDOWS)
	var span: float = duration - WINDOW_SECONDS
	for i: int in n:
		var a: float = span * float(i) / float(maxi(n - 1, 1))
		out.append(Vector2(a, a + WINDOW_SECONDS))
	return out


static func preview_stream(m: MediaItem) -> int:
	var sel: Array[int] = m.selected_streams()
	return sel[0] if not sel.is_empty() else 0


static func marks(d: Project) -> Dictionary:
	var out: Dictionary = {"tracks": PackedStringArray(), "clips": PackedStringArray()}
	if d == null:
		return out
	var raw: Variant = d.view.get(VIEW_KEY, null)
	if raw is Dictionary:
		for k: String in ["tracks", "clips"]:
			var list: PackedStringArray = PackedStringArray()
			for v: Variant in ((raw as Dictionary).get(k, []) as Array):
				list.append(String(v))
			out[k] = list
	return out


static func is_marked(d: Project, kind: String, id: String) -> bool:
	return (marks(d)[kind] as PackedStringArray).has(id)


static func set_marked(d: Project, kind: String, id: String, on: bool) -> bool:
	if d == null or id.is_empty() or not (kind == "tracks" or kind == "clips"):
		return false
	var m: Dictionary = marks(d)
	var list: PackedStringArray = m[kind]
	if list.has(id) == on:
		return false
	if on:
		list.append(id)
	else:
		list.remove_at(list.find(id))
	m[kind] = list
	d.view[VIEW_KEY] = {"tracks": Array(m["tracks"]), "clips": Array(m["clips"])}
	d.dirty = true
	return true


static func clip_in_scope(d: Project, tr: Track, c: Clip, sc: String) -> bool:
	if sc == SCOPE_PROJECT:
		return true
	if sc == SCOPE_TRACKS:
		return tr != null and is_marked(d, "tracks", tr.id)
	if sc == SCOPE_CLIPS:
		return c != null and is_marked(d, "clips", c.id)
	return false


static func clip_gain_db(tr: Track, c: Clip, t: float, seq_len: float) -> float:
	var lt: float = clampf(t - c.start, 0.0, maxf(c.duration, 0.0))
	var vol: float = AnimProp.evaluate_float(c.audio.get("volume", AnimProp.make(1.0)), lt, c.duration)
	var tv: float = AnimProp.evaluate_float(tr.volume, t, seq_len) if tr != null else 1.0
	var db: float = lin_to_db(absf(vol * tv))
	for e: Variant in c.audio_effects():
		var ed: Dictionary = e
		if String(ed.get("id", "")) != "gain" or not bool(ed.get("enabled", true)):
			continue
		var p: Variant = (ed.get("params", {}) as Dictionary).get("db", null)
		if p is Dictionary:
			db += AnimProp.evaluate_float(p, lt, c.duration)
		elif p is float or p is int:
			db += float(p)
	return db


static func note_preview(owner: String, media_id: String) -> void:
	var n: Node = ensure()
	if n != null:
		n.call("set_preview", owner, media_id)


static func bin_note(m: MediaItem) -> String:
	if m == null or scope() != SCOPE_PROJECT:
		return ""
	var n: Node = ensure()
	if n == null:
		return ""
	var r: float = float(n.call("media_reduction", m))
	if r > -SHOWN_REDUCTION_DB:
		return ""
	return "turned down " + str(int(round(-r))) + " dB for your ears"


func _ready() -> void:
	register_prefs()
	_load_cache()
	_install()
	if not Session.project_changed.is_connected(_on_project):
		Session.project_changed.connect(_on_project)
	if PurrBridge.has_signal("audio_stats_ready") and not PurrBridge.audio_stats_ready.is_connected(_on_stats):
		PurrBridge.audio_stats_ready.connect(_on_stats)
	if not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)
	_on_project()


func _exit_tree() -> void:
	_save_cache()
	if _inst == self:
		_inst = null


func set_preview(owner: String, media_id: String) -> void:
	if owner.is_empty():
		return
	_preview[owner] = media_id
	var d: Project = Session.doc
	if d != null:
		queue_media(d.media_by_id(media_id))


func _on_pref(key: String) -> void:
	if key == PREF_SCOPE and scope() != SCOPE_OFF:
		queue_all()


func _on_project() -> void:
	var was: Object = _watched.get_ref() if _watched != null else null
	var d: Project = Session.doc
	if was != null and was != d and (was as Project).changed.is_connected(_on_doc_changed):
		(was as Project).changed.disconnect(_on_doc_changed)
	if d != null and not d.changed.is_connected(_on_doc_changed):
		d.changed.connect(_on_doc_changed)
	_watched = weakref(d) if d != null else null
	_key_of = {}
	queue_all()


func _on_doc_changed(kind: String) -> void:
	if kind == "media":
		_key_of = {}
		queue_all()


func queue_all() -> void:
	var d: Project = Session.doc
	if d == null or scope() == SCOPE_OFF:
		return
	for m: MediaItem in d.media:
		queue_media(m)


func _measurable(m: MediaItem) -> bool:
	return m != null and not m.path.is_empty() and not m.missing and m.kind != "sequence" and (m.has_audio or m.kind == "audio") and m.duration > 0.0


func key_for(m: MediaItem, stream: int) -> String:
	var mk: String = m.id + "|" + str(stream)
	if _key_of.has(mk):
		return String(_key_of[mk])
	var k: String = m.path + "|" + str(stream) + "|" + str(FileAccess.get_modified_time(m.path))
	_key_of[mk] = k
	var ids: PackedStringArray = _media_of_key.get(k, PackedStringArray())
	if not ids.has(m.id):
		ids.append(m.id)
	_media_of_key[k] = ids
	return k


func queue_media(m: MediaItem, stream: int = -1) -> void:
	if not _measurable(m):
		return
	var s: int = stream if stream >= 0 else preview_stream(m)
	var key: String = key_for(m, s)
	if _cache.has(key) or _queued.has(key):
		return
	_queued[key] = true
	_queue.append({"key": key, "path": m.path, "stream": s, "windows": windows_for(m.duration), "next": 0})


func loudness_of(m: MediaItem, stream: int) -> float:
	if not _measurable(m):
		return SILENT
	var key: String = key_for(m, stream)
	if _cache.has(key):
		return float((_cache[key] as Dictionary).get("lufs", SILENT))
	queue_media(m, stream)
	return SILENT


func measured_info(m: MediaItem, stream: int = -1) -> Dictionary:
	if not _measurable(m):
		return {}
	var key: String = key_for(m, stream if stream >= 0 else preview_stream(m))
	return (_cache.get(key, {}) as Dictionary).duplicate()


func media_reduction(m: MediaItem) -> float:
	if m == null:
		return 0.0
	return reduction_db(loudness_of(m, preview_stream(m)), target_lufs())


func busy() -> bool:
	return _jobs_out > 0 or not _queue.is_empty()


func _pump_jobs() -> void:
	if not PurrBridge.available:
		return
	while _jobs_out < MAX_JOBS and not _queue.is_empty():
		var job: Dictionary = _queue[0]
		var wins: Array[Vector2] = job["windows"]
		var key: String = String(job["key"])
		var i: int = int(job["next"])
		if i == 0:
			_partial[key] = {"need": wins.size(), "got": []}
		_serial += 1
		var tag: String = TAG_PREFIX + str(_serial)
		var w: Vector2 = wins[i]
		var id: int = PurrBridge.audio_stats({"input": String(job["path"]), "stream": int(job["stream"]), "from": w.x, "to": w.y, "tag": tag})
		job["next"] = i + 1
		if int(job["next"]) >= wins.size():
			_queue.pop_front()
		if id < 0:
			(_partial[key] as Dictionary)["need"] = int((_partial[key] as Dictionary)["need"]) - 1
			_finish_if_done(key)
			continue
		_pending[tag] = key
		_jobs_out += 1


func _on_stats(result: Dictionary) -> void:
	var tag: String = String(result.get("tag", ""))
	if not _pending.has(tag):
		return
	var key: String = String(_pending[tag])
	_pending.erase(tag)
	_jobs_out = maxi(_jobs_out - 1, 0)
	if not _partial.has(key):
		return
	var ok: bool = bool(result.get("ok", false))
	((_partial[key] as Dictionary)["got"] as Array).append({"rms_db": float(result.get("rms_db", -120.0)) if ok else -120.0, "peak_db": float(result.get("peak_db", -120.0)) if ok else -120.0})
	_finish_if_done(key)


func _finish_if_done(key: String) -> void:
	var part: Dictionary = _partial.get(key, {})
	if part.is_empty():
		return
	var got: Array = part["got"]
	if got.size() < int(part["need"]):
		return
	var peak: float = -120.0
	for g: Variant in got:
		peak = maxf(peak, float((g as Dictionary).get("peak_db", -120.0)))
	_cache[key] = {"lufs": estimate_lufs(got), "peak_db": peak}
	_partial.erase(key)
	_queued.erase(key)
	_cache_dirty = true
	_save_wait = SAVE_DELAY
	for mid: String in (_media_of_key.get(key, PackedStringArray()) as PackedStringArray):
		measured.emit(mid)


func _cache_path() -> String:
	return Prefs.cache_dir().path_join(CACHE_FILE)


func _load_cache() -> void:
	var p: String = _cache_path()
	if not FileAccess.file_exists(p):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		for k: Variant in (parsed as Dictionary).keys():
			var v: Variant = (parsed as Dictionary)[k]
			if v is Dictionary:
				_cache[String(k)] = {"lufs": float((v as Dictionary).get("lufs", SILENT)), "peak_db": float((v as Dictionary).get("peak_db", -120.0))}


func _save_cache() -> void:
	if not _cache_dirty:
		return
	_cache_dirty = false
	var f: FileAccess = FileAccess.open(_cache_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_cache))
		f.close()


func forget_cache() -> void:
	_cache = {}
	_key_of = {}
	_media_of_key = {}
	_queued = {}
	_queue = []
	_partial = {}


func preview_media(owner: String) -> String:
	if _preview.has(owner):
		return String(_preview[owner])
	if owner == "source":
		var bus_script: Variant = load(BUS_PATH)
		if bus_script is GDScript:
			var bus: Object = (bus_script as GDScript).call("instance")
			var src: Object = bus.call("panel", "source") if bus != null else null
			if src != null:
				return String(src.get("media_id"))
	if owner == "pair_listen":
		var listen_script: Variant = load(LISTEN_PATH)
		if listen_script is GDScript:
			var listen: Object = (listen_script as GDScript).call("instance")
			if listen != null:
				return String(listen.get("media_id"))
	return ""


func preview_want() -> float:
	var owner: String = String(Session.audio_owner)
	if owner.is_empty():
		return NAN
	if scope() != SCOPE_PROJECT:
		return 0.0
	var d: Project = Session.doc
	var m: MediaItem = d.media_by_id(preview_media(owner)) if d != null else null
	return media_reduction(m)


func timeline_want(d: Project, seq: Sequence, t: float) -> float:
	if d == null or seq == null:
		return 0.0
	var sc: String = scope()
	if sc == SCOPE_OFF:
		return 0.0
	var target: float = target_lufs()
	var worst: float = 0.0
	var tracks: Array[Track] = []
	tracks.append_array(seq.audio_tracks)
	tracks.append_array(seq.extra_sound_tracks())
	var any_solo: bool = false
	for tr0: Track in tracks:
		if tr0.solo:
			any_solo = true
	var seq_len: float = seq.duration()
	for tr: Track in tracks:
		if tr.muted or (any_solo and not tr.solo):
			continue
		var seen: Dictionary = {}
		var near: Array[Clip] = tr.clips_at(t)
		near.append_array(tr.clips_at(t + LOOKAHEAD))
		for c: Clip in near:
			if seen.has(c.id) or not c.enabled or not tr.is_sound(c):
				continue
			seen[c.id] = true
			if not clip_in_scope(d, tr, c, sc):
				continue
			var m: MediaItem = d.media_by_id(c.media_id)
			var lufs: float = loudness_of(m, int(c.audio.get("stream", 0.0)))
			if lufs <= SILENT + 1.0:
				continue
			worst = minf(worst, reduction_db(lufs + clip_gain_db(tr, c, clampf(t, c.start, c.end()), seq_len), target))
	return worst


func compute_want() -> float:
	if scope() == SCOPE_OFF:
		return 0.0
	var p: float = preview_want()
	if not is_nan(p):
		return p
	var d: Project = Session.doc
	if d == null:
		return 0.0
	return timeline_want(d, Session.seq(), Session.playhead())


func _fx_index(fx: AudioEffect) -> int:
	if fx == null:
		return -1
	for i: int in AudioServer.get_bus_effect_count(MASTER):
		if AudioServer.get_bus_effect(MASTER, i) == fx:
			return i
	return -1


func _install() -> void:
	if _gain_fx == null:
		_gain_fx = AudioEffectAmplify.new()
		_gain_fx.resource_name = GAIN_NAME
	if _limit_fx == null:
		_limit_fx = AudioEffectHardLimiter.new()
		_limit_fx.resource_name = LIMIT_NAME
		_limit_fx.ceiling_db = ceiling()
	var gi: int = _fx_index(_gain_fx)
	var li: int = _fx_index(_limit_fx)
	if gi >= 0 and li == gi + 1:
		return
	if li >= 0:
		AudioServer.remove_bus_effect(MASTER, li)
	gi = _fx_index(_gain_fx)
	if gi >= 0:
		AudioServer.remove_bus_effect(MASTER, gi)
	AudioServer.add_bus_effect(MASTER, _gain_fx, -1)
	AudioServer.add_bus_effect(MASTER, _limit_fx, -1)
	_fx_on = -1


func installed() -> bool:
	var gi: int = _fx_index(_gain_fx)
	return gi >= 0 and _fx_index(_limit_fx) == gi + 1


func active() -> bool:
	return _fx_on == 1


func _set_enabled(on: bool) -> void:
	var want: int = 1 if on else 0
	if want == _fx_on:
		return
	var gi: int = _fx_index(_gain_fx)
	var li: int = _fx_index(_limit_fx)
	if gi >= 0:
		AudioServer.set_bus_effect_enabled(MASTER, gi, on)
	if li >= 0:
		AudioServer.set_bus_effect_enabled(MASTER, li, on)
	_fx_on = want


func step(dt: float) -> void:
	_install()
	var on: bool = scope() != SCOPE_OFF
	_set_enabled(on)
	want_db = compute_want() if on else 0.0
	if want_db < gain_db:
		gain_db = want_db
	else:
		gain_db = minf(want_db, gain_db + RELEASE_DB_PER_SECOND * dt)
	_gain_fx.volume_db = gain_db
	_limit_fx.ceiling_db = ceiling()
	if on:
		_watch_peaks(dt)
	_watch_transport()
	_pump_jobs()
	if _cache_dirty:
		_save_wait -= dt
		if _save_wait <= 0.0:
			_save_cache()


func _process(dt: float) -> void:
	step(dt)


func _watch_peaks(dt: float) -> void:
	if not PurrBridge.available:
		return
	var mtr: PackedFloat32Array = PurrBridge.meters()
	if mtr.size() < 2:
		return
	var level: float = lin_to_db(maxf(mtr[0], mtr[1])) + gain_db
	if level > ceiling():
		_engaged = true
		_quiet_for = 0.0
	elif _engaged and level < ceiling() - RENEW_MARGIN_DB:
		_quiet_for += dt
		if _quiet_for >= RENEW_QUIET_SECONDS:
			renew_limiter()
	elif _engaged:
		_quiet_for = 0.0
	if level > SILENT + 1.0:
		report_level(level)


func _watch_transport() -> void:
	var playing: bool = bool(Session.playing)
	var owner: String = String(Session.audio_owner)
	if playing == _last_playing and owner == _last_owner:
		return
	_last_playing = playing
	_last_owner = owner
	if _engaged:
		renew_limiter()


func renew_limiter() -> void:
	var li: int = _fx_index(_limit_fx)
	var fresh: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	fresh.resource_name = LIMIT_NAME
	fresh.ceiling_db = ceiling()
	if _limit_fx != null:
		fresh.release = _limit_fx.release
		fresh.pre_gain_db = _limit_fx.pre_gain_db
	_limit_fx = fresh
	_engaged = false
	_quiet_for = 0.0
	renewals += 1
	if li < 0:
		return
	AudioServer.remove_bus_effect(MASTER, li)
	AudioServer.add_bus_effect(MASTER, fresh, li)
	AudioServer.set_bus_effect_enabled(MASTER, li, _fx_on != 0)


func report_level(level_db: float) -> bool:
	var over: float = level_db - ceiling()
	if over <= HARD_OVER_DB:
		return false
	clamps += 1
	return _alert(over)


func _alert(over: float) -> bool:
	var mode: String = alert_mode()
	if mode == ALERT_OFF or _quiet_session:
		return false
	var now: int = Time.get_ticks_msec()
	if _last_alert_ms >= 0 and float(now - _last_alert_ms) < cooldown() * 1000.0:
		return false
	_last_alert_ms = now
	alerts += 1
	alerted.emit(over)
	if mode == ALERT_VISUAL or mode == ALERT_BOTH:
		Events.notice("Held a loud sound down for your ears", "It came in about " + str(int(round(over))) + " dB over the " + String.num(ceiling(), 1) + " dB ceiling. Only what you hear is changed, never the export.", [{"label": "Not again this session", "call": quiet_for_session}], 4.0)
	if mode == ALERT_TONE or mode == ALERT_BOTH:
		_beep()
	return true


func quiet_for_session() -> void:
	_quiet_session = true


func reset_alerts() -> void:
	_quiet_session = false
	_last_alert_ms = -1


func _beep() -> void:
	if _tone == null:
		_tone = AudioStreamPlayer.new()
		_tone.name = "EarSafetyTone"
		_tone.bus = "Master"
		_tone.stream = tone_stream()
		add_child(_tone)
	_tone.play()


static func tone_stream() -> AudioStreamWAV:
	var rate: int = 44100
	var n: int = int(float(rate) * TONE_SECONDS)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i: int in n:
		var env: float = minf(1.0, minf(float(i), float(n - i)) / (float(rate) * 0.01))
		var v: float = sin(TAU * TONE_HZ * float(i) / float(rate)) * TONE_LEVEL * env
		bytes.encode_s16(i * 2, int(round(v * 32767.0)))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w
