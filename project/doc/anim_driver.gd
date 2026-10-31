extends RefCounted

const SELF := preload("res://doc/anim_driver.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const MAX_DEPTH := 8
const MAX_NODES := 4096
const DERIVED := "res://doc/derived_source.gd"
const DERIVED_PREFIX := "derived."
const SOURCES := "res://engine/drive_sources.gd"
const TRACKING_EVAL := "res://engine/tracking_eval.gd"
const STEP_EPS := 0.000001
const RECORD := "res://engine/react_record.gd"
const REC_KEY := "rec_id"
const KEPT_KEY := "recorded"
const NEAR_PLAYHEAD := 0.5

static var _doc: Object = null
static var _serial: int = -1
static var _scanned: bool = false
static var _blocked: Dictionary = {}
static var _cycles: Array[String] = []
static var _depth: int = 0
static var baking: int = 0


static func bind(d: Object) -> void:
	AnimProp.driver_scope = SELF if d != null else null
	if d == _doc:
		return
	_doc = d
	_serial = -1
	_scanned = false
	_blocked = {}
	_cycles = []


static func bound_doc() -> Object:
	return _doc


static func unbind() -> void:
	_doc = null
	_serial = -1
	_scanned = false
	_blocked = {}
	_cycles = []
	AnimProp.driver_scope = null


static func bound() -> Object:
	return _doc


static func cycles() -> Array[String]:
	_ensure_scan()
	return _cycles.duplicate()


static func blocked(src: Dictionary) -> bool:
	_ensure_scan()
	return _blocked.has(AnimProp.driven_key(src))


static func forget() -> void:
	_serial = -1
	_scanned = false


static func _doc_serial() -> int:
	if _doc == null:
		return -1
	var v: Variant = _doc.get("serial")
	return int(v) if v is int else 0


static func _ensure_scan() -> void:
	if _doc == null:
		_blocked = {}
		_cycles = []
		_scanned = true
		return
	var now: int = _doc_serial()
	if _scanned and now == _serial:
		return
	_serial = now
	_scanned = true
	_scan()


static func _edges() -> Dictionary:
	var out: Dictionary = {}
	if _doc == null:
		return out
	var seqs: Variant = _doc.get("sequences")
	if not (seqs is Array):
		return out
	for s: Variant in seqs:
		if s == null or not (s as Object).has_method("all_tracks"):
			continue
		for tr: Variant in (s as Object).call("all_tracks"):
			if tr == null:
				continue
			var clips: Variant = (tr as Object).get("clips")
			if not (clips is Array):
				continue
			for cv: Variant in clips:
				if cv == null:
					continue
				var clip: Object = cv
				var cid: String = str(clip.get("id"))
				for path: String in clip.call("param_paths"):
					if out.size() >= MAX_NODES:
						return out
					var prop: Variant = clip.call("get_param", path)
					if not (prop is Dictionary) or not AnimProp.is_animated(prop):
						continue
					var targets: Array[String] = []
					for l: Variant in (prop as Dictionary).get("layers", []):
						var layer: Dictionary = l
						if str(layer.get("type", "")) != "driven":
							continue
						var src: Dictionary = AnimProp.driven_source(layer)
						if str(src.get("clip", "")).is_empty():
							continue
						var key: String = AnimProp.driven_key(src)
						targets.append(key)
						_add_warp_edge(out, str(src.get("clip", "")), str(src.get("path", "")))
						if str(src.get("path", "")).begins_with(DERIVED_PREFIX):
							_merge_edges(out, key, load(DERIVED).call("depends", _doc, str(src.get("clip", "")), str(src.get("path", ""))))
					if not targets.is_empty():
						_merge_edges(out, cid + "|" + path, targets)
						_add_warp_edge(out, cid, path)
	return out


static func _merge_edges(out: Dictionary, node: String, targets: Array[String]) -> void:
	var have: Array[String] = out.get(node, [] as Array[String])
	for one: String in targets:
		if not have.has(one):
			have.append(one)
	out[node] = have


static func _add_warp_edge(out: Dictionary, clip_id: String, path: String) -> void:
	if _doc == null or clip_id.is_empty() or path.is_empty() or AnimTime.exempt(path):
		return
	var clip: Object = _doc.call("clip_by_id", clip_id)
	if clip == null:
		return
	if not bool(clip.call("anim_warped")) and not bool(clip.call("has_inner_speeds")):
		return
	_merge_edges(out, clip_id + "|" + path, [clip_id + "|" + AnimTime.SPEED_PATH] as Array[String])


static func _scan() -> void:
	_blocked = {}
	_cycles = []
	var edges: Dictionary = _edges()
	if edges.is_empty():
		return
	for start: Variant in edges.keys():
		var from: String = start
		if _reaches(edges, from, from):
			_blocked[from] = true
			_cycles.append(from)
	_cycles.sort()


static func _reaches(edges: Dictionary, from: String, goal: String) -> bool:
	var seen: Dictionary = {}
	var stack: Array[String] = []
	for first: Variant in edges.get(from, []):
		stack.append(str(first))
	while not stack.is_empty():
		var node: String = stack.pop_back()
		if node == goal:
			return true
		if seen.has(node):
			continue
		seen[node] = true
		for nxt: Variant in edges.get(node, []):
			stack.append(str(nxt))
	return false


static func step_rate(src: Dictionary, fps: float) -> float:
	if _doc != null:
		var id: String = str(src.get("owner", ""))
		if id.is_empty():
			id = str(src.get("clip", ""))
		var s: Object = _doc.call("sequence_of_clip", id) if not id.is_empty() else null
		if s != null and float(s.get("fps")) > 0.0:
			return float(s.get("fps"))
	return fps if fps > 0.0 else 30.0


static func stepped(layer: Dictionary, src: Dictionary, t: float, fps: float) -> float:
	var step: float = float(layer.get("step", 0.0))
	if step <= 0.0:
		return t
	var span: float = step if str(layer.get("step_unit", "frames")) == "seconds" else step / step_rate(src, fps)
	if span <= 0.0:
		return t
	return floor(t / span + STEP_EPS) * span


static func driven_raw(layer: Dictionary, t: float, fps: float) -> Dictionary:
	if layer.has(KEPT_KEY):
		var rec: Dictionary = load(RECORD).call("recorded_at", layer, t)
		if bool(rec["ok"]):
			return {"ok": true, "v": AnimProp.driven_map(layer, float(rec["v"])), "raw": float(rec["v"])}
	var got: Dictionary = _driven_raw(layer, t, fps)
	if not str(layer.get(REC_KEY, "")).is_empty() and baking == 0 and bool(got.get("ok", false)):
		_note_record(layer, t, fps, float(got.get("raw", got.get("v", 0.0))))
	return got


static func _note_record(layer: Dictionary, t: float, fps: float, raw: float) -> void:
	var rec: GDScript = load(RECORD)
	if _doc == null or not bool(rec.call("playing")):
		return
	var src: Dictionary = AnimProp.driven_source(layer)
	var oid: String = str(src.get("owner", ""))
	if oid.is_empty():
		oid = str(src.get("clip", ""))
	var owner: Object = _doc.call("clip_by_id", oid) if not oid.is_empty() else null
	var s: Object = _doc.call("sequence_of_clip", oid) if owner != null else null
	if owner == null or s == null:
		return
	if absf(float(owner.get("start")) + t - float(s.get("playhead"))) > NEAR_PLAYHEAD:
		var loop: MainLoop = Engine.get_main_loop()
		var session: Node = (loop as SceneTree).root.get_node_or_null("/root/Session") if loop is SceneTree else null
		if session == null or absf(float(owner.get("start")) + t - float(session.call("playhead"))) > NEAR_PLAYHEAD:
			return
	rec.call("note_driver", _doc, str(layer.get(REC_KEY, "")), oid, t, raw, step_rate(src, fps))


static func _driven_raw(layer: Dictionary, t: float, fps: float) -> Dictionary:
	var src: Dictionary = AnimProp.driven_source(layer)
	var kind: String = str(src.get("kind", "value"))
	if kind == "tracker":
		if _doc == null or _depth >= MAX_DEPTH:
			return {"ok": false, "v": 0.0}
		_depth += 1
		var tracked: Dictionary = load(TRACKING_EVAL).call("driven_raw", _doc, layer, src, t, fps)
		_depth -= 1
		return tracked
	if kind == "sound" or kind == "picture":
		if _doc == null or _depth >= MAX_DEPTH:
			return {"ok": false, "v": 0.0}
		_depth += 1
		var got: Dictionary = load(SOURCES).call("raw_at", _doc, layer, src, stepped(layer, src, t, fps))
		_depth -= 1
		if not bool(got["ok"]):
			return {"ok": false, "v": 0.0}
		return {"ok": true, "v": AnimProp.driven_map(layer, float(got["v"])), "raw": float(got["v"])}
	if _doc == null or str(src.get("path", "")).is_empty() or str(src.get("clip", "")).is_empty():
		return {"ok": false, "v": 0.0}
	t = stepped(layer, src, t, fps)
	if float(layer.get("attack", 0.0)) > 0.0 or float(layer.get("release", 0.0)) > 0.0 or float(layer.get("hold", 0.0)) > 0.0:
		_ensure_scan()
		if _blocked.has(AnimProp.driven_key(src)) or _depth >= MAX_DEPTH:
			return {"ok": false, "v": 0.0}
		_depth += 1
		var shaped: Dictionary = load(SOURCES).call("value_raw_at", _doc, layer, src, t, fps)
		_depth -= 1
		if not bool(shaped["ok"]):
			return {"ok": false, "v": 0.0}
		return {"ok": true, "v": AnimProp.driven_map(layer, float(shaped["v"])), "raw": float(shaped["v"])}
	_ensure_scan()
	if _blocked.has(AnimProp.driven_key(src)):
		return {"ok": false, "v": 0.0}
	if _depth >= MAX_DEPTH:
		return {"ok": false, "v": 0.0}
	var taps: Array = AnimProp.smooth_taps(layer)
	var offsets: PackedFloat64Array = taps[0]
	var weights: PackedFloat64Array = taps[1]
	var shift: float = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
	_depth += 1
	var acc: float = 0.0
	var got: bool = false
	for i: int in offsets.size():
		var one: Dictionary = _sample_at(src, t + shift + offsets[i], fps)
		if not bool(one["ok"]):
			acc = 0.0
			got = false
			break
		got = true
		acc += float(one["v"]) * weights[i]
	_depth -= 1
	if not got:
		return {"ok": false, "v": 0.0}
	return {"ok": true, "v": AnimProp.driven_map(layer, acc), "raw": acc}


static func driven_window(layer: Dictionary) -> Vector2:
	var src: Dictionary = AnimProp.driven_source(layer)
	if _doc == null or str(src.get("path", "")).is_empty() or str(src.get("clip", "")).is_empty():
		return AnimProp.EMPTY_WINDOW
	_ensure_scan()
	if _blocked.has(AnimProp.driven_key(src)):
		return AnimProp.EMPTY_WINDOW
	var clip: Object = _doc.call("clip_by_id", str(src.get("clip", "")))
	if clip == null:
		return AnimProp.EMPTY_WINDOW
	var source_dur: float = maxf(float(clip.get("duration")), 0.0)
	var shift: float = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
	var offsets: PackedFloat64Array = (AnimProp.smooth_taps(layer) as Array)[0]
	var first: float = 0.0
	var last: float = 0.0
	for i: int in offsets.size():
		first = minf(first, offsets[i])
		last = maxf(last, offsets[i])
	return Vector2(-shift - last, source_dur - shift - first)


static func _sample_at(src: Dictionary, st: float, fps: float) -> Dictionary:
	var clip: Object = _doc.call("clip_by_id", str(src.get("clip", "")))
	if clip == null:
		return {"ok": false, "v": 0.0}
	var path: String = str(src.get("path", ""))
	if path.begins_with(DERIVED_PREFIX):
		return load(DERIVED).call("sample", _doc, clip, path, clampf(st, 0.0, maxf(float(clip.get("duration")), 0.0)), fps)
	var prop: Variant = clip.call("get_param", path)
	if not (prop is Dictionary) or (prop as Dictionary).is_empty():
		return {"ok": false, "v": 0.0}
	var dur: float = float(clip.get("duration"))
	var at: float = clampf(st, 0.0, maxf(dur, 0.0))
	var pt: float = float(clip.call("param_time", path, at))
	var raw: Variant = AnimProp.evaluate(prop, pt, dur, fps)
	var comp: int = int(src.get("comp", -1))
	if raw is Array:
		var a: Array = raw
		if a.is_empty():
			return {"ok": false, "v": 0.0}
		var pick: int = comp if comp >= 0 and comp < a.size() else 0
		return {"ok": true, "v": float(a[pick])}
	if raw is bool:
		return {"ok": true, "v": 1.0 if raw else 0.0}
	if raw is float or raw is int:
		return {"ok": true, "v": float(raw)}
	return {"ok": false, "v": 0.0}
