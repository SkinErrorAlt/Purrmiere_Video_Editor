extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Puppet := preload("res://doc/puppet.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const SELF_PATH := "res://modules/core_panels/puppet_record.gd"
const UI_PATH := "res://modules/core_panels/puppet_ui.gd"
const SPEED_MIN := 10.0
const SPEED_MAX := 400.0
const THIN_TOL := 0.35
const SMOOTH_MAX := 100.0
const SMOOTH_SECONDS := 0.25
const SMOOTH_REACH := 3.0
const LABEL := "Record puppet pin"

static var on: bool = false
static var speed: float = 100.0
static var thin_keys: bool = true
static var smoothing: float = 0.0
static var _rec: Dictionary = {}
static var last_kept: int = 0
static var last_samples: int = 0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func active() -> bool:
	return not _rec.is_empty()


static func clip_id() -> String:
	return String(_rec.get("clip_id", ""))


static func pin() -> int:
	return int(_rec.get("pin", -1))


static func begin(d: Project, s: Sequence, c: Clip, index: int, at_layer: Vector2, drive: bool = true) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	var rest: PackedVector2Array = Puppet.rest_of(e)
	if e.is_empty() or index < 0 or index >= rest.size() or Puppet.kind_of(e, index) == Puppet.KIND_BEND:
		return false
	var path: String = String(_load_ui().call("path_of", e, Puppet.KEY_PINS))
	var base: Dictionary = c.get_param(path)
	if base.is_empty():
		base = AnimProp.make(Puppet.flat(rest))
	_rec = {"doc": d, "seq": s, "clip_id": c.id, "pin": index, "path": path, "base": base, "prop": base, "pos": at_layer, "times": PackedFloat64Array(), "drive": drive, "was_rate": 1.0}
	Puppet.draft_ok = true
	sample(s.playhead)
	if drive:
		var session: Node = _session()
		if session != null:
			_rec["was_rate"] = float(session.get("rate"))
			session.call("set_rate", clampf(speed, SPEED_MIN, SPEED_MAX) / 100.0)
			session.connect("playhead_changed", Callable(_script(), "_on_tick"))
			session.call("set_playing", true)
	return true


static func _load_ui() -> GDScript:
	return load(UI_PATH)


static func _session() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/Session") if tree != null else null


static func move(at_layer: Vector2) -> void:
	if active():
		_rec["pos"] = at_layer


static func _on_tick(t: float) -> void:
	if active():
		sample(t)


static func sample(t: float) -> void:
	var s: Sequence = _rec["seq"]
	var d: Project = _rec["doc"]
	var c: Clip = s.clip_by_id(clip_id())
	if c == null:
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var fps: float = maxf(s.fps, 1.0)
	var ft: float = round(t * fps) / fps
	if ft < c.start or ft > c.start + c.duration:
		return
	var key_t: float = Puppet.key_time(c, e, Puppet.KEY_PINS, ft)
	var rest: PackedVector2Array = Puppet.rest_of(e)
	var vals: PackedVector2Array = Puppet.flat_of(AnimProp.evaluate(_rec["base"], key_t, c.duration, fps))
	while vals.size() < rest.size():
		vals.append(rest[vals.size()])
	if vals.size() > rest.size():
		vals.resize(rest.size())
	var index: int = pin()
	var want: Vector2 = _rec["pos"]
	if Puppet.link_count(e) > 0:
		vals[index] = Puppet.keyed_for(rest, vals, Puppet.gains_at(c, e, ft, fps), index, want)
	else:
		vals[index] = want
	_rec["prop"] = AnimProp.set_key(_rec["prop"], key_t, Puppet.flat(vals), "linear")
	var times: PackedFloat64Array = _rec["times"]
	if not times.has(key_t):
		times.append(key_t)
	_rec["times"] = times
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, String(_rec["path"]), _rec["prop"]))


static func end() -> int:
	if not active():
		return 0
	var was: Dictionary = _rec
	_rec = {}
	Puppet.draft_ok = false
	if bool(was["drive"]):
		var session: Node = _session()
		if session != null:
			session.call("set_playing", false)
			if session.is_connected("playhead_changed", Callable(_script(), "_on_tick")):
				session.disconnect("playhead_changed", Callable(_script(), "_on_tick"))
			session.call("set_rate", float(was.get("was_rate", 1.0)))
	var s: Sequence = was["seq"]
	var d: Project = was["doc"]
	var times: PackedFloat64Array = was["times"]
	last_samples = times.size()
	var prop: Dictionary = was["prop"]
	if smoothing > 0.0:
		prop = smooth(prop, times, int(was["pin"]), smoothing)
	if thin_keys:
		prop = thin(prop, times, THIN_TOL)
	last_kept = _count_kept(prop, times)
	d.undo.live(ClipCmds.SetClipParam.new(s.id, String(was["clip_id"]), String(was["path"]), prop))
	d.undo.commit_live(LABEL)
	return last_kept


static func _count_kept(prop: Dictionary, times: PackedFloat64Array) -> int:
	var n: int = 0
	for t: float in times:
		if AnimProp.has_key_at(prop, t):
			n += 1
	return n


static func _value_at(prop: Dictionary, t: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in AnimProp.keys(prop):
		if absf(float(k.get("t", 0.0)) - t) <= 0.0001:
			for x: Variant in (k.get("v", []) as Array):
				out.append(float(x))
			return out
	return out


static func thin(prop: Dictionary, times: PackedFloat64Array, tol: float) -> Dictionary:
	var ts: PackedFloat64Array = times.duplicate()
	ts.sort()
	if ts.size() < 3:
		return prop
	var vals: Array[PackedFloat64Array] = []
	for t: float in ts:
		vals.append(_value_at(prop, t))
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(ts.size())
	keep[0] = 1
	keep[ts.size() - 1] = 1
	var anchor: int = 0
	var j: int = 2
	while j < ts.size():
		if not _fits(ts, vals, anchor, j, tol):
			keep[j - 1] = 1
			anchor = j - 1
		j += 1
	var out: Dictionary = prop
	for i: int in ts.size():
		if keep[i] == 0:
			out = AnimProp.remove_key(out, ts[i])
	return out


static func _fits(ts: PackedFloat64Array, vals: Array[PackedFloat64Array], a: int, b: int, tol: float) -> bool:
	var va: PackedFloat64Array = vals[a]
	var vb: PackedFloat64Array = vals[b]
	if va.size() != vb.size():
		return false
	var span: float = ts[b] - ts[a]
	if span <= 0.0:
		return false
	for i: int in range(a + 1, b):
		var vi: PackedFloat64Array = vals[i]
		if vi.size() != va.size():
			return false
		var f: float = (ts[i] - ts[a]) / span
		for q: int in va.size() / 2:
			var want: Vector2 = Vector2(vi[q * 2], vi[q * 2 + 1])
			var got: Vector2 = Vector2(lerpf(va[q * 2], vb[q * 2], f), lerpf(va[q * 2 + 1], vb[q * 2 + 1], f))
			if want.distance_to(got) > tol:
				return false
	return true


static func smooth(prop: Dictionary, times: PackedFloat64Array, index: int, amount: float) -> Dictionary:
	var ts: PackedFloat64Array = times.duplicate()
	ts.sort()
	var sigma: float = clampf(amount, 0.0, SMOOTH_MAX) / SMOOTH_MAX * SMOOTH_SECONDS
	if ts.size() < 3 or sigma <= 0.0 or index < 0:
		return prop
	var vals: Array[PackedFloat64Array] = []
	var path: PackedVector2Array = PackedVector2Array()
	for t: float in ts:
		var v: PackedFloat64Array = _value_at(prop, t)
		vals.append(v)
		path.append(Vector2(v[index * 2], v[index * 2 + 1]) if v.size() >= index * 2 + 2 else Vector2(NAN, NAN))
	var out: Dictionary = prop
	var reach: float = sigma * SMOOTH_REACH
	for i: int in range(1, ts.size() - 1):
		if is_nan(path[i].x):
			continue
		var sum: Vector2 = Vector2.ZERO
		var wsum: float = 0.0
		var j0: int = i
		while j0 > 0 and ts[i] - ts[j0 - 1] <= reach:
			j0 -= 1
		var j: int = j0
		while j < ts.size() and ts[j] - ts[i] <= reach:
			if not is_nan(path[j].x):
				var dt: float = (ts[j] - ts[i]) / sigma
				var w: float = exp(-0.5 * dt * dt)
				sum += path[j] * w
				wsum += w
			j += 1
		if wsum <= 0.0:
			continue
		var keep: float = minf(minf(ts[i] - ts[0], ts[ts.size() - 1] - ts[i]) / reach, 1.0)
		var got: Vector2 = path[i].lerp(sum / wsum, keep)
		var nv: PackedFloat64Array = vals[i].duplicate()
		nv[index * 2] = got.x
		nv[index * 2 + 1] = got.y
		out = AnimProp.set_key(out, ts[i], Array(nv), "linear")
	return out
