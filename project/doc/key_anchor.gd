extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const SpeedCurve := preload("res://doc/speed_curve.gd")
const Command := preload("res://doc/commands/command.gd")
const CLIP_CMDS := "res://doc/commands/clip_cmds.gd"
const PIN := "pin"
const AT := "pin_at"
const OWNER := "pin_clip"
const PENDING := -1.0
const PREF := "keys.stay_on_frame"
const MOVE_EPS := 0.0002
const SOLVE_STEPS := 48
const SPEED_PASSES := 12
const LINK_OWNER := "link:"
const ALIGN_EPS := 0.0005

static var plant_ignore: bool = false
static var moved: int = 0
static var slow_solves: int = 0


static func pref_on() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs") if loop is SceneTree else null
	if prefs == null:
		return false
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, true, {"label": "Keyframes you place stay on their frame of the video when the clip's speed changes (keys placed before this was on are left alone)", "type": "bool"})
	return bool(prefs.call("get_value", PREF))


static func pinnable(c: Clip, path: String) -> bool:
	if c == null or path.is_empty():
		return false
	if c.anim_warped() or c.has_inner_speeds() or Clip.is_transition_path(path):
		return false
	return AnimTime.exempt(path) or path == "speed" or c.param_time(path, 1.0) == 1.0


static func stamp_new(c: Clip, path: String, old: Dictionary, next: Dictionary) -> Dictionary:
	if not AnimProp.is_animated(next) or not pinnable(c, path) or not pref_on():
		return next
	var li: int = AnimProp.keys_layer_index(next)
	if li < 0:
		return next
	var ks: Array = ((next["layers"] as Array)[li] as Dictionary).get("keys", [])
	var before: PackedFloat64Array = key_times(old)
	var fresh: PackedFloat64Array = PackedFloat64Array()
	for k: Variant in ks:
		var kd: Dictionary = k
		var t: float = float(kd.get("t", 0.0))
		if kd.has(PIN) or near_any(before, t):
			continue
		fresh.append(t)
	if fresh.is_empty():
		return next
	fresh.sort()
	var out: Dictionary = next.duplicate(true)
	for k2: Variant in ((out["layers"] as Array)[li] as Dictionary).get("keys", []):
		var kd2: Dictionary = k2
		if near_any(fresh, float(kd2.get("t", 0.0))):
			kd2[PIN] = AnimProp.norm(PENDING)
	return out


static func key_times(p: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return out
	for k: Variant in ((p["layers"] as Array)[li] as Dictionary).get("keys", []):
		out.append(float((k as Dictionary).get("t", 0.0)))
	out.sort()
	return out


static func near_any(sorted_times: PackedFloat64Array, t: float) -> bool:
	if sorted_times.is_empty():
		return false
	var i: int = sorted_times.bsearch(t - AnimProp.KEY_TOLERANCE)
	return i < sorted_times.size() and sorted_times[i] <= t + AnimProp.KEY_TOLERANCE


static func positive_speed(c: Clip) -> bool:
	if not AnimProp.is_animated(c.speed):
		return float(c.speed.get("v", 1.0)) > 0.0
	for k: Dictionary in AnimProp.keys(c.speed):
		if float(k.get("v", 1.0)) <= 0.0:
			return false
	return true


static func _bisect_local(c: Clip, src: float) -> float:
	var span: float = maxf(c.duration, 0.001)
	var lo: float = -span
	var hi: float = span * 4.0 + 10.0
	for i: int in SOLVE_STEPS:
		var mid: float = (lo + hi) * 0.5
		if c.source_time_exact(c.start + mid) < src:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func local_for_source(c: Clip, src: float) -> float:
	var m: Dictionary = c.speed_map()
	if m.is_empty():
		return _bisect_local(c, src)
	var span: float = maxf(c.duration, 0.001)
	return SpeedCurve.map_local(m, src - c.in_offset, -span, span * 4.0 + 10.0)


static func owner_of(s: Sequence, c: Clip) -> String:
	if c == null:
		return ""
	if s == null or c.link_id.is_empty():
		return c.id
	return _owner_in(c, s.linked(c))


static func _owner_in(c: Clip, group: Array) -> String:
	if c.link_id.is_empty():
		return c.id
	var any: bool = false
	for p: Variant in group:
		var o: Clip = p
		if o == c:
			continue
		if absf(o.start - c.start) > ALIGN_EPS or absf(o.in_offset - c.in_offset) > ALIGN_EPS:
			return c.id
		any = true
	return LINK_OWNER + c.link_id if any else c.id


static func _kin(c: Clip, owner: String, group: Array) -> Dictionary:
	var out: Dictionary = {owner: true, c.id: true}
	if c.link_id.is_empty():
		return out
	out[LINK_OWNER + c.link_id] = true
	if owner.begins_with(LINK_OWNER):
		for p: Variant in group:
			out[(p as Clip).id] = true
	return out


static func touched_clips(cmds: Array) -> Dictionary:
	var out: Dictionary = {}
	for cmd: Variant in cmds:
		if not (cmd is Object):
			continue
		var o: Object = cmd
		var sid: String = String(o.get("seq_id")) if "seq_id" in o else ""
		if sid.is_empty():
			continue
		if not out.has(sid):
			out[sid] = {}
		if "clip_id" in o and o.get("clip_id") is String:
			(out[sid] as Dictionary)[String(o.get("clip_id"))] = true
		for field: String in ["clip_ids", "ids"]:
			if field in o and (o.get(field) is PackedStringArray or o.get(field) is Array):
				for id: Variant in o.get(field):
					(out[sid] as Dictionary)[String(id)] = true
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if doc == null or cmds.is_empty() or plant_ignore:
		return out
	var touched: Dictionary = touched_clips(cmds)
	for sid: Variant in touched.keys():
		var s: Sequence = doc.sequence_by_id(String(sid))
		if s == null:
			continue
		var by_link: Dictionary = {}
		for one: Clip in s.all_clips():
			if one.link_id.is_empty():
				continue
			if not by_link.has(one.link_id):
				by_link[one.link_id] = []
			(by_link[one.link_id] as Array).append(one)
		var family: Dictionary = {}
		for cid: Variant in (touched[sid] as Dictionary).keys():
			var c0: Clip = s.clip_by_id(String(cid))
			if c0 == null:
				continue
			if c0.link_id.is_empty():
				family[c0.id] = c0
				continue
			for p: Variant in by_link.get(c0.link_id, []):
				family[(p as Clip).id] = p
		var shared: Dictionary = {}
		for c: Variant in family.values():
			var cc: Clip = c
			var group: Array = by_link.get(cc.link_id, []) if not cc.link_id.is_empty() else []
			var owner: String = _owner_in(cc, group)
			out.append_array(_fix_clip(doc, s, cc, owner, _kin(cc, owner, group), shared))
	return out


static func _has_pins(p: Dictionary) -> bool:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return false
	for k: Variant in ((p["layers"] as Array)[li] as Dictionary).get("keys", []):
		if k is Dictionary and (k as Dictionary).has(PIN):
			return true
	return false


static func _src(c: Clip, m: Dictionary, t: float) -> float:
	if m.is_empty():
		return c.source_time_exact(c.start + t)
	return c.in_offset + SpeedCurve.integral(m["plan"], t)


static func _local(c: Clip, m: Dictionary, src: float) -> float:
	if m.is_empty():
		return _bisect_local(c, src)
	var span: float = maxf(c.duration, 0.001)
	return SpeedCurve.curve_local(m["plan"], src - c.in_offset, -span, span * 4.0 + 10.0)


static func _repinned(c: Clip, p: Dictionary, owner: String, kin: Dictionary, m: Dictionary) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return p
	var ks: Array = ((p["layers"] as Array)[li] as Dictionary).get("keys", [])
	var out: Dictionary = {}
	for i: int in ks.size():
		var k: Dictionary = ks[i]
		if not k.has(PIN):
			continue
		var t: float = float(k.get("t", 0.0))
		var src: float = float(k[PIN])
		var at: float = float(k.get(AT, NAN))
		var who: String = String(k.get(OWNER, ""))
		var fields: Dictionary = {}
		if src < 0.0 or is_nan(at) or absf(at - t) > MOVE_EPS or not kin.has(who):
			fields = {PIN: _src(c, m, t), AT: t, OWNER: owner}
		elif who != owner:
			fields = {OWNER: owner}
		if fields.is_empty():
			continue
		if out.is_empty():
			out = p.duplicate(true)
		var ok: Dictionary = (((out["layers"] as Array)[li] as Dictionary)["keys"] as Array)[i]
		for f: String in fields.keys():
			ok[f] = AnimProp.norm(fields[f])
	return p if out.is_empty() else out


static func _moved_keys(c: Clip, p: Dictionary, owner: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	var ks: Array = (out["layers"][li] as Dictionary).get("keys", [])
	var changed: bool = false
	for kv: Variant in ks:
		var k: Dictionary = kv
		if not k.has(PIN) or float(k[PIN]) < 0.0 or String(k.get(OWNER, "")) != owner:
			continue
		var t: float = float(k.get("t", 0.0))
		if absf(_src(c, m, t) - float(k[PIN])) <= MOVE_EPS:
			continue
		var nt: float = _local(c, m, float(k[PIN]))
		k["t"] = nt
		k[AT] = nt
		changed = true
	if not changed:
		return p
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return float((a as Dictionary).get("t", 0.0)) < float((b as Dictionary).get("t", 0.0)))
	(out["layers"][li] as Dictionary)["keys"] = ks
	return out


static func _solve_speed(c: Clip, sp: Dictionary, owner: String, kin: Dictionary) -> Dictionary:
	var m0: Dictionary = SpeedCurve.frame_map(sp, c.duration)
	if m0.is_empty():
		return _solve_speed_slow(c, sp, owner, kin)
	var work: Dictionary = _repinned(c, sp, owner, kin, m0)
	if SpeedCurve.positive(work):
		var res: Dictionary = SpeedCurve.solve_pins(work, c.in_offset, owner)
		if bool(res["ok"]):
			work = res["prop"]
	for pass_i: int in SPEED_PASSES:
		var m: Dictionary = SpeedCurve.frame_map(work, c.duration)
		if m.is_empty():
			break
		var nxt: Dictionary = _moved_keys(c, work, owner, m)
		if nxt == work:
			break
		work = nxt
		moved += 1
	return work


static func _solve_speed_slow(c: Clip, sp: Dictionary, owner: String, kin: Dictionary) -> Dictionary:
	slow_solves += 1
	var work: Dictionary = _repinned(c, sp, owner, kin, {})
	c.set_param("speed", work)
	for pass_i: int in SPEED_PASSES:
		var nxt: Dictionary = _moved_keys(c, work, owner, {})
		if nxt == work:
			break
		work = nxt
		c.set_param("speed", work)
		moved += 1
	c.set_param("speed", sp)
	return work


static func _fix_clip(doc: Project, s: Sequence, c: Clip, owner: String, kin: Dictionary, shared: Dictionary) -> Array[Command]:
	var out: Array[Command] = []
	if c == null or not positive_speed(c):
		return out
	var ClipCmds: GDScript = load(CLIP_CMDS)
	var sp: Dictionary = c.get_param("speed")
	if _has_pins(sp):
		var work: Dictionary = {}
		var memo: Variant = shared.get(owner, null)
		if memo is Array and float((memo as Array)[1]) == c.duration and float((memo as Array)[2]) == c.in_offset and (memo as Array)[0] == sp:
			work = (memo as Array)[3]
		else:
			work = _solve_speed(c, sp, owner, kin)
			shared[owner] = [sp.duplicate(true), c.duration, c.in_offset, work]
		if work != sp:
			out.append(_apply(doc, ClipCmds.SetClipParam.new(s.id, c.id, "speed", work)))
	if not _any_pins(c):
		return _clean(out)
	var cm: Dictionary = c.speed_map()
	for path: String in c.param_paths():
		if path == "speed":
			continue
		var p: Dictionary = c.get_param(path)
		if not _has_pins(p) or not pinnable(c, path):
			continue
		var re: Dictionary = _repinned(c, p, owner, kin, cm)
		var next: Dictionary = _moved_keys(c, re, owner, cm)
		if next != p:
			if next != re:
				moved += 1
			out.append(_apply(doc, ClipCmds.SetClipParam.new(s.id, c.id, path, next)))
	return _clean(out)


static func _clean(out: Array[Command]) -> Array[Command]:
	var clean: Array[Command] = []
	for cmd: Command in out:
		if cmd != null:
			clean.append(cmd)
	return clean


static func _pins_in_values(d: Dictionary) -> bool:
	for v: Variant in d.values():
		if v is Dictionary and _has_pins(v):
			return true
	return false


static func _any_pins(c: Clip) -> bool:
	if not c.masks.is_empty() or c.has_inner_speeds():
		return true
	if _has_pins(c.anim_speed) or _pins_in_values(c.audio) or _pins_in_values(c.transform) or _pins_in_values(c.motion_blur) or _pins_in_values(c.props):
		return true
	for e: Dictionary in c.effects:
		if _pins_in_values(e) or _pins_in_values(e.get("params", {})):
			return true
	for ae: Variant in c.audio.get("effects", []):
		if ae is Dictionary and _pins_in_values((ae as Dictionary).get("params", {})):
			return true
	return false


static func _apply(doc: Project, cmd: Command) -> Command:
	cmd.do(doc)
	return cmd if cmd.ok else null


static func stripped(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			if String(k) == PIN or String(k) == AT or String(k) == OWNER:
				continue
			out[k] = stripped((v as Dictionary)[k])
		return out
	if v is Array:
		var arr: Array = []
		for x: Variant in v:
			arr.append(stripped(x))
		return arr
	return v
