extends Node

const SELF_PATH := "res://engine/react_record.gd"
const TICKER_NAME := "ReactRecord"
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const HAND_KEY := "snd_hand"
const HAND_LEVEL_KEY := "snd_hand_level"
const RECORD_KEY := "snd_record"
const CMDS := "res://doc/commands/clip_cmds.gd"
const VERBS := "res://doc/verbs.gd"
const KEY_EPS := 0.0005
const DRIVER_REC := "rec_id"
const DRIVER_KEPT := "recorded"

static var _buf: Dictionary = {}
static var _ticker: Node = null
static var _seen_playing: bool = false
static var flushes: int = 0
static var forced_stop: bool = false


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/Session")


static func playing() -> bool:
	if forced_stop:
		return false
	var s: Node = _session()
	return s != null and bool(s.get("playing"))


static func pending() -> int:
	return _buf.size()


static func note(doc: Object, clip: Object, uid: String, t: float, v: float) -> void:
	if doc == null or clip == null or uid.is_empty():
		return
	var key: String = "fx|" + String(clip.get("id")) + "|" + uid
	var b: Dictionary = _buf.get(key, {})
	if b.is_empty():
		b = {"kind": "fx", "doc": weakref(doc), "clip": String(clip.get("id")), "uid": uid, "times": PackedFloat64Array(), "vals": PackedFloat32Array()}
		_buf[key] = b
	_add(b, t, v)
	_ensure_ticker()


static func note_driver(doc: Object, rec_id: String, owner_id: String, t: float, raw: float, fps: float) -> void:
	if doc == null or rec_id.is_empty():
		return
	var key: String = "drv|" + rec_id
	var b: Dictionary = _buf.get(key, {})
	if b.is_empty():
		b = {"kind": "drv", "doc": weakref(doc), "clip": owner_id, "rec": rec_id, "fps": fps, "times": PackedFloat64Array(), "vals": PackedFloat32Array()}
		_buf[key] = b
	_add(b, t, raw)
	_ensure_ticker()


static func _add(b: Dictionary, t: float, v: float) -> void:
	var times: PackedFloat64Array = b["times"]
	var vals: PackedFloat32Array = b["vals"]
	b["times"] = PackedFloat64Array()
	b["vals"] = PackedFloat32Array()
	var n: int = times.size()
	if n > 0 and absf(times[n - 1] - t) <= KEY_EPS:
		vals[n - 1] = v
	else:
		times.append(t)
		vals.append(v)
	b["times"] = times
	b["vals"] = vals


static func _ensure_ticker() -> void:
	if _ticker != null and is_instance_valid(_ticker) and _ticker.is_inside_tree():
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	var have: Node = root.get_node_or_null(TICKER_NAME)
	if have != null:
		_ticker = have
		return
	var t: Node = (load(SELF_PATH) as GDScript).new()
	t.name = TICKER_NAME
	root.add_child.call_deferred(t)
	_ticker = t


func _process(_dt: float) -> void:
	if _buf.is_empty():
		return
	if not playing():
		flush()


static func _sorted(b: Dictionary) -> Array:
	var times: PackedFloat64Array = b["times"]
	var vals: PackedFloat32Array = b["vals"]
	var order: Array = range(times.size())
	order.sort_custom(func(x: Variant, y: Variant) -> bool: return times[int(x)] < times[int(y)])
	var ts: PackedFloat64Array = PackedFloat64Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	for i: Variant in order:
		var tt: float = times[int(i)]
		if not ts.is_empty() and absf(ts[ts.size() - 1] - tt) <= KEY_EPS:
			vs[vs.size() - 1] = vals[int(i)]
			continue
		ts.append(tt)
		vs.append(vals[int(i)])
	return [ts, vs]


static func keys_over(p: Dictionary, a: float, b: float, times: PackedFloat64Array, vals: Array, interp: String) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not AnimProp.is_animated(out):
		out = {"a": true, "base": AnimProp.static_value(out), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": []}]}
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		(out["layers"] as Array).insert(0, {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": []})
		li = 0
	var layer: Dictionary = (out["layers"] as Array)[li]
	var kept: Array = []
	for k: Variant in layer.get("keys", []):
		var kt: float = float((k as Dictionary).get("t", 0.0))
		if kt < a - KEY_EPS or kt > b + KEY_EPS:
			kept.append(k)
	for i: int in times.size():
		kept.append({"t": times[i], "v": AnimProp.norm(vals[i]), "i": interp})
	kept.sort_custom(func(x: Variant, y: Variant) -> bool: return float((x as Dictionary)["t"]) < float((y as Dictionary)["t"]))
	layer["keys"] = kept
	return out


static func fx_props(c: Object, uid: String, times_seq: PackedFloat64Array, vals: PackedFloat32Array, fps: float) -> Dictionary:
	var base: String = "effects." + uid + "."
	var start: float = float(c.get("start"))
	var ts: PackedFloat64Array = PackedFloat64Array()
	var lv: Array = []
	for i: int in times_seq.size():
		ts.append(float(c.call("param_time", base + HAND_LEVEL_KEY, times_seq[i] - start)))
		lv.append(clampf(vals[i], 0.0, 1.0) * 100.0)
	var a: float = ts[0]
	var b: float = ts[ts.size() - 1]
	var level: Dictionary = keys_over(c.call("get_param", base + HAND_LEVEL_KEY), a, b, ts, lv, "linear")
	var hand_p: Dictionary = c.call("get_param", base + HAND_KEY)
	if hand_p.is_empty():
		hand_p = AnimProp.make(false)
	var frame: float = 1.0 / maxf(fps, 1.0)
	var after: float = b + frame
	var dur: float = float(c.get("duration"))
	var was_after: bool = bool(AnimProp.evaluate(hand_p, after, dur, fps))
	var hand_t: PackedFloat64Array = PackedFloat64Array([a, after])
	var hand_v: Array = [true, was_after]
	var lead: float = a
	if a > frame * 0.5:
		lead = maxf(a - frame, 0.0)
		hand_t = PackedFloat64Array([lead, a, after])
		hand_v = [bool(AnimProp.evaluate(hand_p, lead, dur, fps)), true, was_after]
	var hand: Dictionary = keys_over(hand_p, lead, after, hand_t, hand_v, "hold")
	return {base + HAND_LEVEL_KEY: level, base + HAND_KEY: hand, base + RECORD_KEY: AnimProp.make(false)}


static func flush() -> int:
	var wrote: int = 0
	var list: Array = _buf.values()
	_buf = {}
	for bv: Variant in list:
		var b: Dictionary = bv
		var doc: Object = (b["doc"] as WeakRef).get_ref()
		if doc == null:
			continue
		var pair: Array = _sorted(b)
		var ts: PackedFloat64Array = pair[0]
		var vs: PackedFloat32Array = pair[1]
		if ts.is_empty():
			continue
		var seq: Object = doc.call("sequence_of_clip", String(b["clip"]))
		if seq == null:
			continue
		var c: Object = seq.call("clip_by_id", String(b["clip"]))
		if c == null:
			continue
		var fps: float = float(seq.get("fps")) if float(seq.get("fps")) > 0.0 else 30.0
		var cmds: Array = []
		var cmd_script: GDScript = load(CMDS)
		var set_param: GDScript = cmd_script.get_script_constant_map()["SetClipParam"]
		if String(b["kind"]) == "fx":
			var props: Dictionary = fx_props(c, String(b["uid"]), ts, vs, fps)
			for path: Variant in props.keys():
				cmds.append(set_param.new(String(seq.get("id")), String(b["clip"]), String(path), props[path]))
		else:
			var found: Dictionary = driver_target(c, String(b["rec"]))
			if found.is_empty():
				continue
			var p: Dictionary = (found["prop"] as Dictionary).duplicate(true)
			var layer: Dictionary = (p["layers"] as Array)[int(found["index"])]
			layer[DRIVER_KEPT] = recorded_of(ts, vs, float(b.get("fps", fps)), layer.get(DRIVER_KEPT, {}))
			layer.erase(DRIVER_REC)
			cmds.append(set_param.new(String(seq.get("id")), String(b["clip"]), String(found["path"]), p))
		if cmds.is_empty():
			continue
		var typed: Array[Command] = []
		for cm: Variant in cmds:
			typed.append(cm)
		var verbs: GDScript = load(VERBS)
		if bool(verbs.call("run", doc, "Record while playing", typed)):
			wrote += 1
	flushes += 1
	return wrote


static func driver_target(c: Object, rec_id: String) -> Dictionary:
	for path: String in c.call("param_paths"):
		var prop: Variant = c.call("get_param", path)
		if not (prop is Dictionary) or not AnimProp.is_animated(prop):
			continue
		var layers: Array = (prop as Dictionary).get("layers", [])
		for i: int in layers.size():
			var l: Variant = layers[i]
			if l is Dictionary and String((l as Dictionary).get(DRIVER_REC, "")) == rec_id:
				return {"path": path, "prop": prop, "index": i}
	return {}


static func recorded_of(ts: PackedFloat64Array, vs: PackedFloat32Array, fps: float, old: Variant) -> Dictionary:
	var rate: float = maxf(fps, 1.0)
	var t0: float = floor(ts[0] * rate + 0.5) / rate
	var t1: float = ts[ts.size() - 1]
	var n: int = maxi(int(floor((t1 - t0) * rate + 0.5)) + 1, 1)
	var out: Array = []
	var j: int = 0
	for i: int in n:
		var t: float = t0 + float(i) / rate
		while j + 1 < ts.size() and ts[j + 1] <= t:
			j += 1
		var v: float = vs[j]
		if j + 1 < ts.size() and ts[j + 1] > ts[j] and t > ts[j]:
			v = lerpf(vs[j], vs[j + 1], clampf((t - ts[j]) / (ts[j + 1] - ts[j]), 0.0, 1.0))
		out.append(v)
	var spans: Array = []
	if old is Dictionary and (old as Dictionary).get("spans", null) is Array:
		for s: Variant in (old as Dictionary)["spans"]:
			var sd: Dictionary = s
			var st: float = float(sd.get("t0", 0.0))
			var en: float = st + float(maxi((sd.get("v", []) as Array).size() - 1, 0)) / maxf(float(sd.get("rate", rate)), 1.0)
			if en < t0 - 0.000001 or st > t0 + float(n - 1) / rate + 0.000001:
				spans.append(sd)
	spans.append({"t0": t0, "rate": rate, "v": out})
	return {"spans": spans}


static func recorded_at(layer: Dictionary, t: float) -> Dictionary:
	var rec: Variant = layer.get(DRIVER_KEPT, null)
	if not (rec is Dictionary):
		return {"ok": false}
	for s: Variant in (rec as Dictionary).get("spans", []):
		var sd: Dictionary = s
		var v: Array = sd.get("v", [])
		if v.is_empty():
			continue
		var rate: float = maxf(float(sd.get("rate", 30.0)), 1.0)
		var t0: float = float(sd.get("t0", 0.0))
		var pos: float = (t - t0) * rate
		if pos < -0.000001 or pos > float(v.size() - 1) + 0.000001:
			continue
		var i0: int = clampi(int(floor(pos)), 0, v.size() - 1)
		var i1: int = mini(i0 + 1, v.size() - 1)
		return {"ok": true, "v": lerpf(float(v[i0]), float(v[i1]), clampf(pos - float(i0), 0.0, 1.0))}
	return {"ok": false}


static func forget() -> void:
	_buf = {}
