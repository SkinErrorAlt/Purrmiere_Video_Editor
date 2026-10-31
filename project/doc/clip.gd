extends RefCounted

const SELF := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MIX_KEY := "mix"
const MASK_MODE_KEY := "mask_mode"
const MASK_SPILL := "spill"
const Marker := preload("res://doc/marker.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const SpeedCurve := preload("res://doc/speed_curve.gd")
const TABLE_RATE := 120.0
const TABLE_MAX := 8192
const LOOP_MIN := 0.001
const LOOP_EPS := 0.000001
const LOOP_SEAMS_MAX := 65536
const LOOP_SAMPLES_MAX := 20000
const LOOP_BISECT := 40
const AUTO_LOOP_EXT: PackedStringArray = ["gif"]

var id: String = ""
var media_id: String = ""
var sequence_id: String = ""
var label: String = ""
var start: float = 0.0
var duration: float = 0.0
var in_offset: float = 0.0
var speed: Dictionary = AnimProp.make(1.0)
var enabled: bool = true
var colour: int = -1
var link_id: String = ""
var group_id: String = ""
var tags: PackedStringArray = PackedStringArray()
var role: String = ""
var notes: String = ""
var transform: Dictionary = default_transform()
var motion_blur: Dictionary = default_motion_blur()
var effects: Array[Dictionary] = []
var masks: Array[Dictionary] = []
var transition_in: Dictionary = {}
var transition_out: Dictionary = {}
var audio: Dictionary = default_audio()
var nest: Dictionary = default_nest()
var props: Dictionary = {}
var markers: Array[Marker] = []
var warnings: Array[Dictionary] = []
var placeholder: bool = false
var part: String = ""
var stack: int = 0
var place: String = ""
var loop: bool = false
var loop_in: float = 0.0
var _seam_key: Array = []
var _seam_cache: PackedFloat64Array = PackedFloat64Array()
static var _plant_no_wrap: bool = false
var view_hidden: bool = false:
	set(value):
		view_hidden = value
		if value:
			view_hidden_seen = true
var listen_muted: bool = false:
	set(value):
		listen_muted = value
		if value:
			listen_seen = true
static var listen_seen: bool = false
var parent: Dictionary = {}:
	set(value):
		parent = value
		if not value.is_empty():
			parent_seen = true

var _table: PackedFloat64Array = PackedFloat64Array()
var _table_speed: Dictionary = {}
var _exact_table: PackedFloat64Array = PackedFloat64Array()
var _exact_step: float = 0.0
var _exact_dur: float = -1.0
var _exact_speed: Dictionary = {}
var _table_dur: float = -1.0
var _table_step: float = 0.0
var _map: Dictionary = {}
var _map_speed: Dictionary = {}
var _map_dur: float = 0.0
var _map_set: bool = false
var anim_speed: Dictionary = AnimProp.make(1.0)
var anim_start: float = 0.0
var _anim_table: PackedFloat64Array = PackedFloat64Array()
var _anim_runs: PackedInt32Array = PackedInt32Array()
var _anim_table_speed: Dictionary = {}
var _anim_table_dur: float = -1.0
var speeds: Dictionary = {}
var _inner_cache: Dictionary = {}
var _path_cache: Dictionary = {}
static var speed_length_seen: bool = false
static var parent_seen: bool = false
static var view_hidden_seen: bool = false
const PITCH_KEEP_PATH := "audio.pitch_keep"


func pitch_keep_prop() -> Dictionary:
	var v: Variant = audio.get("pitch_keep", null)
	if v is Dictionary:
		return v
	return AnimProp.make(1.0 if bool(audio.get("keep_pitch", false)) else 0.0)


func _set_pitch_keep(value: Dictionary) -> void:
	if not AnimProp.is_animated(value):
		var sv: Variant = AnimProp.static_value(value)
		var f: float = clampf(float(sv) if (sv is float or sv is int) else 0.0, 0.0, 1.0)
		if f <= 0.0 or f >= 1.0:
			audio.erase("pitch_keep")
			audio["keep_pitch"] = f >= 1.0
			return
		value = AnimProp.make(f)
	audio["pitch_keep"] = value
	audio["keep_pitch"] = true


static func default_transform() -> Dictionary:
	return {
		"pos": AnimProp.make([0.0, 0.0]),
		"anchor": AnimProp.make([0.0, 0.0]),
		"scale": AnimProp.make([1.0, 1.0]),
		"scale_linked": true,
		"rotation": AnimProp.make(0.0),
		"opacity": AnimProp.make(1.0),
		"blend": "normal",
	}


const MOTION_BLUR_NUMERIC: PackedStringArray = ["shutter_angle", "shutter_phase", "samples"]


static func default_motion_blur() -> Dictionary:
	return {"on": false, "mode": "smooth", "shutter_angle": 180.0, "shutter_phase": -90.0, "samples": 8.0, "rotation": false}


static func default_audio() -> Dictionary:
	return {"stream": 0.0, "volume": AnimProp.make(1.0), "fade_in": 0.0, "fade_out": 0.0, "keep_pitch": false, "effects": []}


static func default_nest() -> Dictionary:
	return {"see_inside": false, "hear_audio": true, "audio_allow": [], "show_audio_below": false}


func end() -> float:
	return start + duration


func video_fade_mul(t: float) -> float:
	var local_t: float = t - start
	var mul: float = 1.0
	var fin_v: Variant = props.get("fade_in", 0.0)
	var fout_v: Variant = props.get("fade_out", 0.0)
	var fin: float = float(fin_v) if (fin_v is float or fin_v is int) else 0.0
	var fout: float = float(fout_v) if (fout_v is float or fout_v is int) else 0.0
	if fin > 0.00001 and local_t < fin:
		mul *= clampf(local_t / fin, 0.0, 1.0)
	if fout > 0.00001 and duration - local_t < fout:
		mul *= clampf((duration - local_t) / fout, 0.0, 1.0)
	return mul


const MIN_TRANSITION := 0.04
const TRANSITION_FIELD := "transition"
const TRANSITION_PATH := "transition."
const TRANSITION_OUT_FIELD := "transition_out"
const TRANSITION_OUT_PATH := "transition_out."
const TRANSITION_PARAMS := "params"
const TRANSITION_ALIGN_OFFSET: Dictionary = {"start": 0.0, "centre": 0.5, "center": 0.5, "end": 1.0}


static func transition_offset(tr: Dictionary) -> float:
	if tr.has("offset"):
		return clampf(float(tr["offset"]), 0.0, 1.0)
	return float(TRANSITION_ALIGN_OFFSET.get(str(tr.get("align", "centre")), 0.5))


func has_transition() -> bool:
	if transition_in.is_empty():
		return false
	var kind: String = str(transition_in.get("kind", ""))
	return not kind.is_empty() and kind != "none"


func transition_span() -> Vector2:
	if not has_transition():
		return Vector2(-1.0, -1.0)
	var dur: float = maxf(float(transition_in.get("duration", 0.5)), MIN_TRANSITION)
	var w0: float = start - dur * transition_offset(transition_in)
	return Vector2(w0, w0 + dur)


func has_transition_out() -> bool:
	if transition_out.is_empty():
		return false
	var kind: String = str(transition_out.get("kind", ""))
	return not kind.is_empty() and kind != "none"


func transition_out_span() -> Vector2:
	if not has_transition_out():
		return Vector2(-1.0, -1.0)
	var dur: float = maxf(float(transition_out.get("duration", 0.5)), MIN_TRANSITION)
	var w0: float = end() - dur * transition_offset(transition_out)
	return Vector2(w0, w0 + dur)


static func is_transition_path(path: String) -> bool:
	return path.begins_with(TRANSITION_PATH) or path.begins_with(TRANSITION_OUT_PATH)


func span_for_path(path: String) -> Vector2:
	return transition_out_span() if path.begins_with(TRANSITION_OUT_PATH) else transition_span()


func transition_field(name: String) -> Dictionary:
	return transition_out if name == TRANSITION_OUT_FIELD else transition_in


func local(t: float) -> float:
	return t - start


func anim_time(local_t: float) -> float:
	if anim_start == 0.0 and not AnimProp.is_animated(anim_speed) and float(anim_speed.get("v", 1.0)) == 1.0:
		return local_t
	return anim_start + _anim_integral(local_t)


func anim_warped() -> bool:
	return anim_start != 0.0 or not AnimTime.is_default_speed(anim_speed)


func param_time(path: String, local_t: float) -> float:
	if is_transition_path(path):
		return local_t + start - span_for_path(path).x
	if AnimTime.exempt(path):
		return local_t
	return inner_time(path, anim_time(local_t))


func inner_time(path: String, a: float) -> float:
	if speeds.is_empty() and (not AnimTime.is_fx_target(path) or not _fx_speeds_any()):
		return a
	var x: float = a
	for target: String in AnimTime.chain_of(path):
		var en: Dictionary = speed_entry(target)
		if not en.is_empty():
			x = AnimTime.level(en, x, _cache_for(target), duration)
	return x


func fx_time(e: Dictionary, key: String, local_t: float) -> float:
	return fx_inner(e, key, anim_time(local_t))


func fx_inner(e: Dictionary, key: String, anim_t: float) -> float:
	var a: float = anim_t
	var sp: Variant = e.get(AnimTime.SPEEDS_FIELD, null)
	if not (sp is Dictionary):
		return a
	var uid: String = String(e.get("uid", ""))
	var whole: Variant = (sp as Dictionary).get(AnimTime.WHOLE, null)
	if whole is Dictionary:
		a = AnimTime.level(whole, a, _cache_named(uid + "|" + AnimTime.WHOLE), duration)
	var own: Variant = (sp as Dictionary).get(key, null)
	if own is Dictionary:
		a = AnimTime.level(own, a, _cache_named(uid + "|" + key), duration)
	return a


func _cache_for(target: String) -> Dictionary:
	return _cache_named(AnimTime.cache_key(target))


func _cache_named(key: String) -> Dictionary:
	var hit: Variant = _inner_cache.get(key, null)
	if hit is Dictionary:
		return hit
	var fresh: Dictionary = {}
	_inner_cache[key] = fresh
	return fresh


func speed_entry(target: String) -> Dictionary:
	if AnimTime.is_fx_target(target):
		var e: Dictionary = _fx_of(target)
		var sp: Variant = e.get(AnimTime.SPEEDS_FIELD, null)
		if not (sp is Dictionary):
			return {}
		var en: Variant = (sp as Dictionary).get(AnimTime.fx_key(target), null)
		return en if en is Dictionary else {}
	var en2: Variant = speeds.get(target, null)
	return en2 if en2 is Dictionary else {}


func _fx_of(target: String) -> Dictionary:
	var parts: PackedStringArray = target.split(".")
	if parts.size() < 2:
		return {}
	if parts[0] == "masks":
		var mi: int = MaskShape.index_of(masks, parts[1])
		return masks[mi] if mi >= 0 else {}
	return audio_effect_by_uid(parts[1]) if parts[0] == "audio_effects" else effect_by_uid(parts[1])


func has_inner_speeds() -> bool:
	if not speeds.is_empty():
		return true
	return _fx_speeds_any()


func _fx_speeds_any() -> bool:
	for e: Dictionary in effects:
		if e.has(AnimTime.SPEEDS_FIELD):
			return true
	for m: Dictionary in masks:
		if m.has(AnimTime.SPEEDS_FIELD):
			return true
	for ae: Variant in audio_effects():
		if ae is Dictionary and (ae as Dictionary).has(AnimTime.SPEEDS_FIELD):
			return true
	return false


func chain_used(path: String) -> bool:
	if speeds.is_empty() and (not AnimTime.is_fx_target(path) or not _fx_speeds_any()):
		return false
	for target: String in AnimTime.chain_of(path):
		if not speed_entry(target).is_empty():
			return true
	return false


func path_warped(path: String) -> bool:
	if AnimTime.exempt(path):
		return false
	return anim_warped() or chain_used(path)


func speed_used(target: String) -> bool:
	return not speed_entry(target).is_empty()


func speed_targets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: Variant in speeds.keys():
		out.append(String(t))
	for pair: Array in [["effects", effects], ["audio_effects", audio_effects()], ["masks", masks]]:
		for e: Variant in (pair[1] as Array):
			var sp: Variant = (e as Dictionary).get(AnimTime.SPEEDS_FIELD, null)
			if not (sp is Dictionary):
				continue
			var base: String = String(pair[0]) + "." + String((e as Dictionary).get("id" if String(pair[0]) == "masks" else "uid", ""))
			for k: Variant in (sp as Dictionary).keys():
				out.append(base if String(k) == AnimTime.WHOLE else base + "." + String(k))
	return out


func speed_sig() -> int:
	if not has_inner_speeds():
		return 0
	var parts: Array = [speeds]
	for e: Dictionary in effects:
		if e.has(AnimTime.SPEEDS_FIELD):
			parts.append(e.get("uid", ""))
			parts.append(e[AnimTime.SPEEDS_FIELD])
	for ae: Variant in audio_effects():
		if ae is Dictionary and (ae as Dictionary).has(AnimTime.SPEEDS_FIELD):
			parts.append((ae as Dictionary).get("uid", ""))
			parts.append((ae as Dictionary)[AnimTime.SPEEDS_FIELD])
	for m: Dictionary in masks:
		if m.has(AnimTime.SPEEDS_FIELD):
			parts.append(m.get("id", ""))
			parts.append(m[AnimTime.SPEEDS_FIELD])
	return parts.hash()


func put_speed(target: String, sp: Dictionary, st: float) -> bool:
	if not AnimTime.target_ok(target):
		return false
	var fresh_default: bool = st == 0.0 and AnimTime.is_default_speed(sp)
	if not AnimTime.is_fx_target(target):
		if fresh_default:
			speeds.erase(target)
		else:
			speeds[target] = AnimTime.make_entry(sp, st)
		return true
	var e: Dictionary = _fx_of(target)
	if e.is_empty():
		return false
	var key: String = AnimTime.fx_key(target)
	if fresh_default:
		var had: Variant = e.get(AnimTime.SPEEDS_FIELD, null)
		if had is Dictionary:
			(had as Dictionary).erase(key)
			if (had as Dictionary).is_empty():
				e.erase(AnimTime.SPEEDS_FIELD)
		return true
	if not (e.get(AnimTime.SPEEDS_FIELD) is Dictionary):
		e[AnimTime.SPEEDS_FIELD] = {}
	(e[AnimTime.SPEEDS_FIELD] as Dictionary)[key] = AnimTime.make_entry(sp, st)
	return true


func _inner_get(path: String) -> Dictionary:
	var target: String = AnimTime.target_of(path)
	if not AnimTime.target_ok(target) or (AnimTime.is_fx_target(target) and _fx_of(target).is_empty()):
		return {}
	var en: Dictionary = speed_entry(target)
	if AnimTime.is_start_path(path):
		return AnimProp.make(AnimTime.entry_start(en))
	return AnimTime.entry_speed(en)


func _inner_set(path: String, anim: Dictionary) -> bool:
	var target: String = AnimTime.target_of(path)
	var en: Dictionary = speed_entry(target)
	if AnimTime.is_start_path(path):
		var sv: Variant = AnimProp.static_value(anim)
		return put_speed(target, AnimTime.entry_speed(en), float(sv) if (sv is float or sv is int) else 0.0)
	return put_speed(target, anim, AnimTime.entry_start(en))


func path_speed_at(path: String, u: float) -> float:
	if AnimTime.exempt(path):
		return 1.0
	var k: float = anim_speed_at(u)
	var x: float = anim_time(u)
	for target: String in AnimTime.chain_of(path):
		var en: Dictionary = speed_entry(target)
		if en.is_empty():
			continue
		k *= AnimTime.speed_at(AnimTime.entry_speed(en), x, duration)
		x = AnimTime.level(en, x, _cache_for(target), duration)
	return k


func _path_table(path: String) -> Dictionary:
	var sig: Array = [duration, anim_start, anim_speed]
	var flat: bool = not AnimProp.is_animated(anim_speed)
	for target: String in AnimTime.chain_of(path):
		var en: Dictionary = speed_entry(target)
		sig.append(en)
		if not en.is_empty() and AnimProp.is_animated(AnimTime.entry_speed(en)):
			flat = false
	var hit: Variant = _path_cache.get(path, null)
	if hit is Dictionary and (hit as Dictionary)["sig"] == sig:
		return hit
	var out: Dictionary = {"sig": sig.duplicate(true), "flat": flat}
	if flat:
		out["c0"] = param_time(path, 0.0)
		out["k"] = path_speed_at(path, 0.0)
	else:
		var span: float = maxf(duration, 0.0)
		var n: int = clampi(int(ceil(span * AnimTime.TABLE_RATE)), 2, AnimTime.TABLE_MAX)
		var table: PackedFloat64Array = PackedFloat64Array()
		table.resize(n + 1)
		for i: int in n + 1:
			table[i] = param_time(path, span * float(i) / float(n))
		out["table"] = table
		out["runs"] = AnimTime.runs_of(table)
		out["s0"] = path_speed_at(path, 0.0)
		out["s1"] = path_speed_at(path, span)
	_path_cache[path] = out
	return out


func path_monotonic(path: String) -> bool:
	if not chain_used(path):
		return anim_monotonic()
	var pt: Dictionary = _path_table(path)
	return bool(pt["flat"]) or (pt["runs"] as PackedInt32Array).size() <= 2


func _held_by(chain: PackedStringArray) -> bool:
	for target: String in chain:
		if not speed_entry(target).is_empty():
			return true
	return false


func _shift_keys_inner(delta: float) -> void:
	var moved: Array[Dictionary] = []
	for path: String in param_paths():
		if AnimTime.is_inner(path):
			continue
		var p: Dictionary = get_param(path)
		if AnimProp.is_animated(p) and not _held_by(AnimTime.chain_of(path)):
			moved.append({"path": path, "p": AnimProp.shift_keys(p, delta)})
	var entries: Array[Dictionary] = []
	for target: String in speed_targets():
		if not _held_by(AnimTime.chain_of(AnimTime.speed_path(target))):
			entries.append({"target": target, "en": AnimTime.shifted_entry(speed_entry(target), delta, duration)})
	for m: Dictionary in moved:
		set_param(String(m["path"]), m["p"])
	for te: Dictionary in entries:
		var en: Dictionary = te["en"]
		put_speed(String(te["target"]), AnimTime.entry_speed(en), AnimTime.entry_start(en))
	for mk: Marker in markers:
		mk.time += delta


func anim_speed_at(u: float) -> float:
	return AnimTime.speed_at(anim_speed, u, duration)


func _anim_integral(u: float) -> float:
	if not AnimProp.is_animated(anim_speed):
		return u * float(anim_speed.get("v", 1.0))
	_ensure_anim_table()
	return AnimTime.table_integral(anim_speed, _anim_table, duration, u)


func _ensure_anim_table() -> void:
	if _anim_table_dur == duration and _anim_table_speed == anim_speed and not _anim_table.is_empty():
		return
	_anim_table = AnimTime.build_table(anim_speed, maxf(duration, 0.0))
	_anim_runs = AnimTime.runs_of(_anim_table)
	_anim_table_dur = duration
	_anim_table_speed = anim_speed.duplicate(true)


func anim_time_exact(local_t: float) -> float:
	if not anim_warped():
		return local_t
	return anim_start + AnimTime.integrate(anim_speed, duration, local_t)


func played_times(key_t: float) -> PackedFloat64Array:
	if not anim_warped():
		return PackedFloat64Array([key_t])
	if not AnimProp.is_animated(anim_speed):
		return AnimTime.flat_solve(float(anim_speed.get("v", 1.0)), anim_start, key_t)
	_ensure_anim_table()
	return AnimTime.solve(anim_speed, _anim_table, _anim_runs, duration, anim_start, key_t)


func played_times_for(path: String, key_t: float) -> PackedFloat64Array:
	if is_transition_path(path):
		return PackedFloat64Array([key_t + span_for_path(path).x - start])
	if AnimTime.exempt(path):
		return PackedFloat64Array([key_t])
	if not chain_used(path):
		return played_times(key_t)
	var pt: Dictionary = _path_table(path)
	if bool(pt["flat"]):
		return AnimTime.flat_solve(float(pt["k"]), float(pt["c0"]), key_t)
	return AnimTime.solve_abs(pt["table"], pt["runs"], duration, float(pt["s0"]), float(pt["s1"]), key_t)


func first_played_for(path: String, key_t: float) -> float:
	if is_transition_path(path):
		return key_t + span_for_path(path).x - start
	if anim_start == 0.0 and not AnimProp.is_animated(anim_speed) and float(anim_speed.get("v", 1.0)) == 1.0 and not chain_used(path):
		return key_t
	var times: PackedFloat64Array = played_times_for(path, key_t)
	return times[0] if not times.is_empty() else INF


func anim_monotonic() -> bool:
	if not AnimProp.is_animated(anim_speed):
		return true
	_ensure_anim_table()
	return _anim_runs.size() <= 2


func _shift_keys_warped(delta: float) -> void:
	var new_start: float = anim_time_exact(-delta)
	for path: String in [AnimTime.MEDIA_SPEED_PATH, AnimTime.SPEED_PATH]:
		var p: Dictionary = get_param(path)
		if AnimProp.is_animated(p):
			set_param(path, AnimProp.shift_keys(p, delta))
	anim_start = new_start
	for m: Marker in markers:
		m.time += delta


func _anim_to_dict(d: Dictionary) -> void:
	if not AnimTime.is_default_speed(anim_speed):
		d[AnimTime.SPEED_PATH] = anim_speed.duplicate(true)
	if anim_start != 0.0:
		d[AnimTime.START_FIELD] = anim_start
	if not speeds.is_empty():
		d[AnimTime.SPEEDS_FIELD] = speeds.duplicate(true)


func _anim_from_dict(d: Dictionary) -> void:
	anim_speed = (d[AnimTime.SPEED_PATH] as Dictionary).duplicate(true) if d.get(AnimTime.SPEED_PATH) is Dictionary else AnimProp.make(1.0)
	var st: Variant = d.get(AnimTime.START_FIELD, 0.0)
	anim_start = float(st) if (st is float or st is int) else 0.0
	_anim_table = PackedFloat64Array()
	_anim_table_dur = -1.0
	speeds = AnimTime.normalised(d[AnimTime.SPEEDS_FIELD]) if d.get(AnimTime.SPEEDS_FIELD) is Dictionary else {}
	_inner_cache = {}
	_path_cache = {}


func _normalise_fx_speeds() -> void:
	for list: Array in [effects, audio_effects(), masks]:
		for e: Variant in list:
			if not (e is Dictionary) or not (e as Dictionary).has(AnimTime.SPEEDS_FIELD):
				continue
			var ed: Dictionary = e
			var sp: Variant = ed[AnimTime.SPEEDS_FIELD]
			var kept: Dictionary = AnimTime.normalised(sp) if sp is Dictionary else {}
			if kept.is_empty():
				ed.erase(AnimTime.SPEEDS_FIELD)
			else:
				ed[AnimTime.SPEEDS_FIELD] = kept


func is_nest() -> bool:
	return not sequence_id.is_empty()


func is_speed_static() -> bool:
	return not AnimProp.is_animated(speed)


func static_speed() -> float:
	if AnimProp.is_animated(speed):
		return 0.0
	return float(speed.get("v", 1.0))


func speed_at(u: float) -> float:
	return AnimProp.evaluate_float(speed, u, duration)


static var _table_memo: Dictionary = {}
const TABLE_MEMO_MAX := 512


static func clear_table_memo() -> void:
	_table_memo.clear()


static func _memo_get(kind: String, dur: float, sp: Dictionary) -> Array:
	var hit: Variant = _table_memo.get(hash([kind, dur, sp]), null)
	if hit is Array and float((hit as Array)[0]) == dur and String((hit as Array)[1]) == kind and (hit as Array)[2] == sp:
		return hit
	return []


static func _memo_put(kind: String, dur: float, sp: Dictionary, table: PackedFloat64Array, step: float) -> void:
	if _table_memo.size() >= TABLE_MEMO_MAX:
		_table_memo.clear()
	_table_memo[hash([kind, dur, sp])] = [dur, kind, sp, table, step]


func _ensure_table() -> void:
	if _table_dur == duration and _table_speed == speed and not _table.is_empty():
		return
	var memo: Array = _memo_get("plain", duration, speed)
	if not memo.is_empty():
		_table = memo[3]
		_table_step = float(memo[4])
		_table_dur = duration
		_table_speed = memo[2]
		return
	var n: int = clampi(int(ceil(duration * TABLE_RATE)), 2, TABLE_MAX)
	_table_step = duration / float(n)
	_table = PackedFloat64Array()
	_table.resize(n + 1)
	_table[0] = 0.0
	var prev: float = speed_at(0.0)
	for i: int in n:
		var u: float = float(i + 1) * _table_step
		var cur: float = speed_at(u)
		_table[i + 1] = _table[i] + (prev + cur) * 0.5 * _table_step
		prev = cur
	_table_dur = duration
	_table_speed = speed.duplicate(true)
	_memo_put("plain", duration, _table_speed, _table, _table_step)


func speed_map() -> Dictionary:
	if _map_set and _map_dur == duration and _map_speed == speed:
		return _map
	_map = SpeedCurve.frame_map(speed, duration)
	_map_speed = speed.duplicate(true)
	_map_dur = duration
	_map_set = true
	return _map


func source_time(t: float) -> float:
	var u: float = t - start
	if not AnimProp.is_animated(speed):
		return in_offset + u * float(speed.get("v", 1.0))
	if duration <= 0.0:
		return in_offset + u * speed_at(0.0)
	var m: Dictionary = speed_map()
	if not m.is_empty():
		return in_offset + SpeedCurve.map_source(m, u)
	_ensure_table()
	if u <= 0.0:
		return in_offset + u * speed_at(0.0)
	if u >= duration:
		return in_offset + _table[_table.size() - 1] + (u - duration) * speed_at(duration)
	var x: float = u / _table_step
	var i: int = clampi(int(floor(x)), 0, _table.size() - 2)
	var f: float = x - float(i)
	return in_offset + lerpf(_table[i], _table[i + 1], f)


func _ensure_exact_table() -> void:
	if _exact_dur == duration and _exact_speed == speed and not _exact_table.is_empty():
		return
	var memo: Array = _memo_get("exact", duration, speed)
	if not memo.is_empty():
		_exact_table = memo[3]
		_exact_step = float(memo[4])
		_exact_dur = duration
		_exact_speed = memo[2]
		return
	_exact_table = AnimTime.build_table(speed, maxf(duration, 0.0))
	_exact_step = AnimTime.table_step(_exact_table, duration)
	_exact_dur = duration
	_exact_speed = speed.duplicate(true)
	_memo_put("exact", duration, _exact_speed, _exact_table, _exact_step)


func source_time_exact(t: float) -> float:
	var u: float = t - start
	if not AnimProp.is_animated(speed):
		return in_offset + u * float(speed.get("v", 1.0))
	if duration <= 0.0:
		return in_offset + u * speed_at(0.0)
	var m: Dictionary = speed_map()
	if not m.is_empty():
		return in_offset + SpeedCurve.map_source(m, u)
	_ensure_exact_table()
	if u <= 0.0:
		return in_offset + u * speed_at(0.0)
	if u >= duration:
		return in_offset + _exact_table[_exact_table.size() - 1] + (u - duration) * speed_at(duration)
	var x: float = u / _exact_step
	var i: int = clampi(int(floor(x)), 0, _exact_table.size() - 2)
	return in_offset + lerpf(_exact_table[i], _exact_table[i + 1], x - float(i))


func source_in() -> float:
	return minf(source_time(start), source_time(end()))


func source_out() -> float:
	return maxf(source_time(start), source_time(end()))


func source_span() -> float:
	return source_out() - source_in()


func source_reach() -> Vector2:
	if not AnimProp.is_animated(speed) or duration <= 0.0:
		return Vector2(source_in(), source_out())
	var m: Dictionary = speed_map()
	if not m.is_empty():
		var end_s: float = float(m["end"])
		var plan: Dictionary = m["plan"]
		if bool(plan.get("rising", false)):
			return Vector2(in_offset + minf(0.0, end_s), in_offset + maxf(0.0, end_s))
		var n: int = clampi(int(ceil(duration * TABLE_RATE)), 2, TABLE_MAX)
		var lo_s: float = 0.0
		var hi_s: float = 0.0
		for i: int in range(1, n + 1):
			var at: float = SpeedCurve.integral(plan, duration * float(i) / float(n))
			lo_s = minf(lo_s, at)
			hi_s = maxf(hi_s, at)
		return Vector2(in_offset + lo_s, in_offset + hi_s)
	_ensure_table()
	var lo: float = INF
	var hi: float = -INF
	for v: float in _table:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(in_offset + lo, in_offset + hi)


static func auto_loops(path: String) -> bool:
	return AUTO_LOOP_EXT.has(path.get_extension().to_lower())


static func stamp_auto_loop(path: String, d: Dictionary) -> void:
	if auto_loops(path):
		d["loop"] = true
		d["loop_in"] = float(d.get("in_offset", 0.0))


func loop_forward() -> bool:
	if not AnimProp.is_animated(speed):
		return float(speed.get("v", 1.0)) >= 0.0
	return source_time(end()) >= source_time(start)


func loop_window(media_dur: float) -> Vector2:
	if not loop or media_dur <= LOOP_MIN:
		return Vector2.ZERO
	if loop_forward():
		var lo: float = loop_in if loop_in >= 0.0 and loop_in < media_dur - LOOP_MIN else 0.0
		return Vector2(lo, media_dur)
	var hi: float = loop_in if loop_in > LOOP_MIN and loop_in <= media_dur else media_dur
	return Vector2(0.0, hi)


static func wrap_in(src: float, win: Vector2, forward: bool) -> float:
	var p: float = win.y - win.x
	if p <= LOOP_MIN or _plant_no_wrap:
		return src
	if forward:
		return win.x + fposmod(src - win.x, p)
	return win.y - fposmod(win.y - src, p)


static func cycle_in(src: float, win: Vector2, forward: bool) -> int:
	var p: float = win.y - win.x
	if p <= LOOP_MIN:
		return 0
	if forward:
		return int(floor((src - win.x) / p))
	return int(floor((win.y - src) / p))


func loop_source(src: float, media_dur: float) -> float:
	if not loop:
		return src
	return wrap_in(src, loop_window(media_dur), loop_forward())


func media_time(t: float, media_dur: float) -> float:
	return loop_source(source_time(t), media_dur)


func loop_seams(media_dur: float) -> PackedFloat64Array:
	return loop_seams_in(loop_window(media_dur))


func loop_seams_in(win: Vector2) -> PackedFloat64Array:
	if win.y - win.x <= LOOP_MIN or duration <= LOOP_EPS:
		return PackedFloat64Array()
	var key: Array = [win, duration, in_offset, speed]
	if key == _seam_key:
		return _seam_cache
	var forward: bool = loop_forward()
	var out: PackedFloat64Array = _seams_static(win, forward) if not AnimProp.is_animated(speed) else _seams_sampled(win, forward)
	_seam_key = key.duplicate(true)
	_seam_cache = out
	return out


func _seams_static(win: Vector2, forward: bool) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var v: float = float(speed.get("v", 1.0))
	if absf(v) <= LOOP_EPS:
		return out
	var p: float = win.y - win.x
	var base: float = win.x if forward else win.y
	var s0: float = in_offset
	var s1: float = in_offset + duration * v
	var k0: int = int(floor((minf(s0, s1) - base) / p))
	var k1: int = int(ceil((maxf(s0, s1) - base) / p))
	for k: int in range(k0, k1 + 1):
		var u: float = (base + float(k) * p - in_offset) / v
		if u > LOOP_EPS and u < duration - LOOP_EPS:
			out.append(u)
			if out.size() >= LOOP_SEAMS_MAX:
				break
	out.sort()
	return out


func _seams_sampled(win: Vector2, forward: bool) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var reach: Vector2 = source_reach()
	var p: float = win.y - win.x
	var n: int = clampi(int(ceil((reach.y - reach.x) / p * 8.0)) + 64, 64, LOOP_SAMPLES_MAX)
	var prev_u: float = 0.0
	var prev_c: int = cycle_in(source_time(start), win, forward)
	for i: int in range(1, n + 1):
		var u: float = duration * float(i) / float(n)
		var cur: int = cycle_in(source_time(start + u), win, forward)
		if cur != prev_c:
			var a: float = prev_u
			var b: float = u
			for _j: int in LOOP_BISECT:
				var m: float = (a + b) * 0.5
				if cycle_in(source_time(start + m), win, forward) == prev_c:
					a = m
				else:
					b = m
			if b > LOOP_EPS and b < duration - LOOP_EPS:
				out.append(b)
				if out.size() >= LOOP_SEAMS_MAX:
					break
		prev_u = u
		prev_c = cur
	return out


static func mask_spills(e: Dictionary) -> bool:
	return str(e.get(MASK_MODE_KEY, "")) == MASK_SPILL


func effect_by_uid(uid: String) -> Dictionary:
	for e: Dictionary in effects:
		if str(e.get("uid", "")) == uid:
			return e
	return {}


func effect_index(uid: String) -> int:
	for i: int in effects.size():
		if str(effects[i].get("uid", "")) == uid:
			return i
	return -1


func audio_effects() -> Array:
	var raw: Variant = audio.get("effects", null)
	return raw if raw is Array else []


func audio_effect_by_uid(uid: String) -> Dictionary:
	for e: Variant in audio_effects():
		if str((e as Dictionary).get("uid", "")) == uid:
			return e
	return {}


func is_audio_effect(uid: String) -> bool:
	return not audio_effect_by_uid(uid).is_empty()


func get_param(path: String) -> Dictionary:
	if AnimTime.is_inner(path):
		return _inner_get(path)
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 1 and parts[0] == "speed":
		return speed
	if path == AnimTime.SPEED_PATH:
		return anim_speed
	if path == AnimTime.START_FIELD:
		return AnimProp.make(anim_start)
	if parts.size() == 2 and parts[0] == "transform":
		var v: Variant = transform.get(parts[1])
		return v if v is Dictionary else {}
	if parts.size() == 2 and parts[0] == "audio" and parts[1] == "volume":
		return audio.get("volume", {})
	if path == PITCH_KEEP_PATH:
		return pitch_keep_prop()
	if parts.size() == 2 and parts[0] == "audio" and parts[1] == "pan":
		var pan: Variant = audio.get("pan", 0.0)
		return pan if pan is Dictionary else AnimProp.make(float(pan) if pan is float or pan is int else 0.0)
	if parts.size() == 2 and parts[0] == "motion_blur" and parts[1] in MOTION_BLUR_NUMERIC:
		var mbv: Variant = motion_blur.get(parts[1], default_motion_blur().get(parts[1], 0.0))
		return mbv if mbv is Dictionary else AnimProp.make(float(mbv))
	if parts.size() == 3 and parts[0] == "effects":
		var e: Dictionary = effect_by_uid(parts[1])
		if e.is_empty():
			return {}
		if parts[2] == MIX_KEY:
			var mv: Variant = e.get(MIX_KEY, null)
			return mv if mv is Dictionary else AnimProp.make(1.0)
		var params: Dictionary = e.get("params", {})
		var pv: Variant = params.get(parts[2])
		return pv if pv is Dictionary else {}
	if parts.size() == 3 and parts[0] == "audio_effects":
		for ae: Variant in audio.get("effects", []):
			var aed: Dictionary = ae
			if str(aed.get("uid", "")) == parts[1]:
				var ap: Dictionary = aed.get("params", {})
				var apv: Variant = ap.get(parts[2])
				return apv if apv is Dictionary else {}
	if parts.size() == 2 and parts[0] == "props":
		if not props.has(parts[1]):
			return {}
		return as_prop(props[parts[1]])
	if parts.size() == 3 and parts[0] == "masks":
		return MaskShape.get_param(masks, parts[1], parts[2])
	if parts.size() == 2 and (parts[0] == TRANSITION_FIELD or parts[0] == TRANSITION_OUT_FIELD):
		var tp: Variant = (transition_out if parts[0] == TRANSITION_OUT_FIELD else transition_in).get(TRANSITION_PARAMS, {})
		var tv: Variant = (tp as Dictionary).get(parts[1], null) if tp is Dictionary else null
		return tv if tv is Dictionary else {}
	return {}


static func is_prop_anim(v: Variant) -> bool:
	return v is Dictionary and ((v as Dictionary).has("v") or (v as Dictionary).has("a"))


static func as_prop(v: Variant) -> Dictionary:
	if is_prop_anim(v):
		return v
	return AnimProp.make(v)


func prop_at(key: String, local_t: float, fps: float = 0.0) -> Variant:
	if not props.has(key):
		return null
	var v: Variant = props[key]
	if not is_prop_anim(v):
		return v
	return AnimProp.evaluate(v, param_time("props." + key, local_t), duration, fps)


func props_at(local_t: float, fps: float = 0.0) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in props.keys():
		out[k] = prop_at(String(k), local_t, fps)
	return out


func adopt_param(path: String, anim: Dictionary) -> bool:
	if AnimTime.is_inner(path):
		return _inner_set(path, anim)
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 2 and parts[0] == "transform":
		transform[parts[1]] = anim
		return true
	if path == AnimTime.SPEED_PATH:
		anim_speed = anim
		return true
	if parts.size() == 2 and parts[0] == "props":
		props[parts[1]] = anim
		return true
	if parts.size() == 3 and parts[0] == "effects" and parts[2] != MIX_KEY:
		var e: Dictionary = effect_by_uid(parts[1])
		if e.is_empty():
			return false
		if not e.has("params"):
			e["params"] = {}
		e["params"][parts[2]] = anim
		return true
	return set_param(path, anim)


func set_param(path: String, anim: Dictionary) -> bool:
	var parts: PackedStringArray = path.split(".")
	var value: Dictionary = anim.duplicate(true)
	if AnimTime.is_inner(path):
		return _inner_set(path, value)
	if parts.size() == 1 and parts[0] == "speed":
		speed = value
		return true
	if path == AnimTime.SPEED_PATH:
		anim_speed = value
		return true
	if path == AnimTime.START_FIELD:
		var sv: Variant = AnimProp.static_value(value)
		anim_start = float(sv) if (sv is float or sv is int) else 0.0
		return true
	if parts.size() == 2 and parts[0] == "transform":
		transform[parts[1]] = value
		return true
	if parts.size() == 2 and parts[0] == "audio" and parts[1] == "volume":
		audio["volume"] = value
		return true
	if parts.size() == 2 and parts[0] == "audio" and parts[1] == "pan":
		audio["pan"] = value
		return true
	if path == PITCH_KEEP_PATH:
		_set_pitch_keep(value)
		return true
	if parts.size() == 2 and parts[0] == "motion_blur" and parts[1] in MOTION_BLUR_NUMERIC:
		motion_blur[parts[1]] = value
		return true
	if parts.size() == 3 and parts[0] == "effects":
		var e: Dictionary = effect_by_uid(parts[1])
		if e.is_empty():
			return false
		if parts[2] == MIX_KEY:
			e[MIX_KEY] = value
			return true
		if not e.has("params"):
			e["params"] = {}
		e["params"][parts[2]] = value
		return true
	if parts.size() == 3 and parts[0] == "audio_effects":
		for ae: Variant in audio.get("effects", []):
			var aed: Dictionary = ae
			if str(aed.get("uid", "")) == parts[1]:
				if not aed.has("params"):
					aed["params"] = {}
				aed["params"][parts[2]] = value
				return true
	if parts.size() == 2 and parts[0] == "props":
		props[parts[1]] = value
		return true
	if parts.size() == 3 and parts[0] == "masks":
		return MaskShape.set_param(masks, parts[1], parts[2], value)
	if parts.size() == 2 and (parts[0] == TRANSITION_FIELD or parts[0] == TRANSITION_OUT_FIELD):
		var td: Dictionary = transition_out if parts[0] == TRANSITION_OUT_FIELD else transition_in
		if td.is_empty():
			return false
		if not (td.get(TRANSITION_PARAMS) is Dictionary):
			td[TRANSITION_PARAMS] = {}
		(td[TRANSITION_PARAMS] as Dictionary)[parts[1]] = value
		return true
	return false


func erase_param(path: String) -> void:
	var parts: PackedStringArray = path.split(".")
	if AnimTime.is_inner(path):
		_inner_set(path, AnimProp.make(0.0 if AnimTime.is_start_path(path) else 1.0))
	elif parts.size() == 3 and parts[0] == "effects":
		var e: Dictionary = effect_by_uid(parts[1])
		if e.has("params"):
			(e["params"] as Dictionary).erase(parts[2])
	elif parts.size() == 3 and parts[0] == "audio_effects":
		for ae: Variant in audio.get("effects", []):
			var aed: Dictionary = ae
			if str(aed.get("uid", "")) == parts[1] and aed.has("params"):
				(aed["params"] as Dictionary).erase(parts[2])
	elif parts.size() == 2 and parts[0] == "transform":
		transform[parts[1]] = default_transform().get(parts[1], AnimProp.make(0.0))
	elif path == "speed":
		speed = AnimProp.make(1.0)
	elif path == AnimTime.SPEED_PATH:
		anim_speed = AnimProp.make(1.0)
	elif path == AnimTime.START_FIELD:
		anim_start = 0.0
	elif path == "audio.volume":
		audio["volume"] = AnimProp.make(1.0)
	elif path == PITCH_KEEP_PATH:
		audio.erase("pitch_keep")
	elif path == "audio.pan":
		audio["pan"] = AnimProp.make(0.0)
	elif parts.size() == 2 and parts[0] == "motion_blur":
		motion_blur[parts[1]] = default_motion_blur().get(parts[1], 0.0)
	elif parts.size() == 2 and parts[0] == "props":
		props.erase(parts[1])
	elif parts.size() == 3 and parts[0] == "masks":
		MaskShape.erase_param(masks, parts[1], parts[2])
	elif parts.size() == 2 and parts[0] == TRANSITION_FIELD and transition_in.get(TRANSITION_PARAMS) is Dictionary:
		(transition_in[TRANSITION_PARAMS] as Dictionary).erase(parts[1])
	elif parts.size() == 2 and parts[0] == TRANSITION_OUT_FIELD and transition_out.get(TRANSITION_PARAMS) is Dictionary:
		(transition_out[TRANSITION_PARAMS] as Dictionary).erase(parts[1])


func motion_blur_value(key: String, local_t: float, fps: float = 0.0) -> float:
	var v: Variant = motion_blur.get(key, default_motion_blur().get(key, 0.0))
	if v is Dictionary:
		return AnimProp.evaluate_float(v, param_time("motion_blur." + key, local_t), duration, fps)
	return float(v)


func param_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(["speed", "audio.volume"])
	if audio.get("pitch_keep") is Dictionary:
		out.append(PITCH_KEEP_PATH)
	if not AnimTime.is_default_speed(anim_speed):
		out.append(AnimTime.SPEED_PATH)
	if audio.get("pan") is Dictionary:
		out.append("audio.pan")
	for mk: String in MOTION_BLUR_NUMERIC:
		if motion_blur.get(mk) is Dictionary:
			out.append("motion_blur." + mk)
	for k: String in transform.keys():
		if transform[k] is Dictionary:
			out.append("transform." + k)
	for e: Dictionary in effects:
		if e.get(MIX_KEY) is Dictionary:
			out.append("effects." + str(e.get("uid", "")) + "." + MIX_KEY)
		var params: Dictionary = e.get("params", {})
		for pk: String in params.keys():
			out.append("effects." + str(e.get("uid", "")) + "." + pk)
	for ae: Variant in audio.get("effects", []):
		var aed: Dictionary = ae
		var ap: Dictionary = aed.get("params", {})
		for apk: String in ap.keys():
			out.append("audio_effects." + str(aed.get("uid", "")) + "." + apk)
	for pk2: String in props.keys():
		if is_prop_anim(props[pk2]):
			out.append("props." + pk2)
	out.append_array(MaskShape.param_paths(masks))
	if has_inner_speeds():
		for target: String in speed_targets():
			out.append(AnimTime.speed_path(target))
	return out


func shift_keys(delta: float) -> void:
	if delta == 0.0:
		return
	if anim_warped():
		_shift_keys_warped(delta)
		return
	if has_inner_speeds():
		_shift_keys_inner(delta)
		return
	for path: String in param_paths():
		var p: Dictionary = get_param(path)
		if AnimProp.is_animated(p):
			set_param(path, AnimProp.shift_keys(p, delta))
	for m: Marker in markers:
		m.time += delta


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "media_id": media_id}
	if not sequence_id.is_empty():
		d["sequence_id"] = sequence_id
	if not label.is_empty():
		d["label"] = label
	d["start"] = start
	d["duration"] = duration
	d["in_offset"] = in_offset
	if speed != AnimProp.make(1.0):
		d["speed"] = speed.duplicate(true)
	_anim_to_dict(d)
	if not enabled:
		d["enabled"] = false
	if colour != -1:
		d["colour"] = colour
	if not link_id.is_empty():
		d["link_id"] = link_id
	if not group_id.is_empty():
		d["group_id"] = group_id
	if not tags.is_empty():
		d["tags"] = Array(tags)
	if not role.is_empty():
		d["role"] = role
	if not notes.is_empty():
		d["notes"] = notes
	if transform != default_transform():
		d["transform"] = transform.duplicate(true)
	if motion_blur != default_motion_blur():
		d["motion_blur"] = motion_blur.duplicate(true)
	if not effects.is_empty():
		d["effects"] = effects.duplicate(true)
	if not masks.is_empty():
		d["masks"] = masks.duplicate(true)
	if not transition_in.is_empty():
		d["transition_in"] = transition_in.duplicate(true)
	if not transition_out.is_empty():
		d["transition_out"] = transition_out.duplicate(true)
	if audio != default_audio():
		d["audio"] = audio.duplicate(true)
	if nest != default_nest():
		d["nest"] = nest.duplicate(true)
	if not props.is_empty():
		d["props"] = props.duplicate(true)
	if not markers.is_empty():
		var ms: Array = []
		for m: Marker in markers:
			ms.append(m.to_dict())
		d["markers"] = ms
	if not warnings.is_empty():
		d["warnings"] = warnings.duplicate(true)
	if placeholder:
		d["placeholder"] = true
	if not part.is_empty():
		d["part"] = part
	if stack != 0:
		d["stack"] = stack
	if not place.is_empty():
		d["place"] = place
	if loop:
		d["loop"] = true
		d["loop_in"] = loop_in
	if not parent.is_empty():
		d["parent"] = parent.duplicate(true)
	if view_hidden:
		d["view_hidden"] = true
	if listen_muted:
		d["listen_muted"] = true
	return d


static func from_dict(d: Dictionary) -> SELF:
	var c: SELF = SELF.new()
	c.apply_dict(d, true)
	return c


static func _dicts(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for e: Variant in v:
			if e is Dictionary:
				out.append((e as Dictionary).duplicate(true))
	return out


static func _merged(base: Dictionary, v: Variant) -> Dictionary:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			base[k] = AnimProp.norm((v as Dictionary)[k]) if not ((v as Dictionary)[k] is Dictionary) else (v as Dictionary)[k].duplicate(true)
	return base


func apply_dict(d: Dictionary, fresh: bool = false) -> void:
	id = str(d.get("id", ""))
	media_id = str(d.get("media_id", ""))
	sequence_id = str(d.get("sequence_id", ""))
	label = str(d.get("label", ""))
	start = float(d.get("start", 0.0))
	duration = float(d.get("duration", 0.0))
	in_offset = float(d.get("in_offset", 0.0))
	speed = (d["speed"] as Dictionary).duplicate(true) if d.get("speed") is Dictionary else AnimProp.make(1.0)
	_anim_from_dict(d)
	enabled = bool(d.get("enabled", true))
	colour = int(d.get("colour", -1))
	link_id = str(d.get("link_id", ""))
	group_id = str(d.get("group_id", ""))
	tags = PackedStringArray()
	for t: Variant in d.get("tags", []):
		tags.append(str(t))
	role = str(d.get("role", ""))
	notes = str(d.get("notes", ""))
	if not fresh or d.has("transform"):
		transform = _merged(default_transform(), d.get("transform"))
	if not fresh or d.has("motion_blur"):
		motion_blur = _merged(default_motion_blur(), d.get("motion_blur"))
	if not fresh or d.has("effects"):
		effects = _dicts(d.get("effects", []))
	if not fresh or d.has("masks"):
		masks = _dicts(d.get("masks", []))
	if not fresh or d.has("transition_in"):
		transition_in = (d["transition_in"] as Dictionary).duplicate(true) if d.get("transition_in") is Dictionary else {}
	if not fresh or d.has("transition_out"):
		transition_out = (d["transition_out"] as Dictionary).duplicate(true) if d.get("transition_out") is Dictionary else {}
	if not fresh or d.has("audio"):
		audio = _merged(default_audio(), d.get("audio"))
	if not fresh or d.has("nest"):
		nest = _merged(default_nest(), d.get("nest"))
	if not fresh or d.has("props"):
		props = (d["props"] as Dictionary).duplicate(true) if d.get("props") is Dictionary else {}
	if not fresh or d.has("markers"):
		markers = []
		for m: Variant in d.get("markers", []):
			if m is Dictionary:
				markers.append(Marker.from_dict(m))
	if not fresh or d.has("warnings"):
		warnings = _dicts(d.get("warnings", []))
	placeholder = bool(d.get("placeholder", false))
	part = _part_from(d.get("part", ""))
	stack = int(d.get("stack", 0))
	place = str(d.get("place", ""))
	loop = bool(d.get("loop", false))
	var li: Variant = d.get("loop_in", null)
	loop_in = float(li) if (li is float or li is int) else in_offset
	view_hidden = bool(d.get("view_hidden", false))
	listen_muted = bool(d.get("listen_muted", false))
	if not fresh or d.has("parent"):
		parent = _parent_from(d.get("parent", null))
	if not speed_length_seen and bool(audio.get("speed_length", false)):
		speed_length_seen = true
	_table = PackedFloat64Array()
	_table_dur = -1.0
	_normalise_fx_speeds()


func copy() -> SELF:
	return from_dict(to_dict())


static func _part_from(v: Variant) -> String:
	var s: String = str(v)
	return s if s == "video" or s == "audio" else ""


static func _parent_from(v: Variant) -> Dictionary:
	if not (v is Dictionary) or str((v as Dictionary).get("id", "")).is_empty():
		return {}
	var src: Dictionary = v
	var out: Dictionary = {"id": str(src["id"])}
	var inv: Variant = src.get("inv", null)
	if inv is Array and (inv as Array).size() == 6:
		var nums: Array = []
		for x: Variant in inv:
			nums.append(float(x) if (x is float or x is int) else 0.0)
		out["inv"] = nums
	if int(src.get("pin", -1)) >= 0:
		out["pin"] = int(src["pin"])
		if bool(src.get("pin_rot", false)):
			out["pin_rot"] = true
	return out
