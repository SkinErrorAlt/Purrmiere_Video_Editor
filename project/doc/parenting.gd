extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Undo := preload("res://doc/undo.gd")
const Puppet := preload("res://doc/puppet.gd")
const FIELD := "parent"
const STAB_KEY := "stabilise"
const TRACKING_EVAL := "res://engine/tracking_eval.gd"
const KEY_ID := "id"
const KEY_INV := "inv"
const KEY_PIN := "pin"
const KEY_PIN_ROT := "pin_rot"
const MAX_DEPTH := 64
const MEMO_MAX := 4096
const SAME_EPS := 0.000001

static var _memo: Dictionary = {}
static var _memo_token: int = -1
static var frames_built: int = 0
static var memo_hits: int = 0


static func parent_id(c: Clip) -> String:
	if c == null or c.parent.is_empty():
		return ""
	return String(c.parent.get(KEY_ID, ""))


static func is_parented(c: Clip) -> bool:
	return not parent_id(c).is_empty()


static func pin_of(c: Clip) -> int:
	if c == null or c.parent.is_empty():
		return -1
	return int(c.parent.get(KEY_PIN, -1))


static func parent_of(c: Clip, s: Sequence) -> Clip:
	var pid: String = parent_id(c)
	if pid.is_empty() or s == null:
		return null
	var p: Clip = s.clip_by_id(pid)
	return p if p != c else null


static func forget() -> void:
	_memo = {}
	_memo_token = -1


static func token_of(d: Project) -> int:
	if d == null:
		return -1
	var live: int = d.undo.live_serial if d.undo != null else 0
	return [d.serial, live, Engine.get_process_frames()].hash()


static func local_tf(c: Clip, t: float, fps: float) -> Dictionary:
	var local_t: float = c.anim_time(t - c.start)
	var tr: Dictionary = c.transform
	var own: bool = not c.speeds.is_empty()
	var pos: Vector2 = AnimProp.evaluate_vec2(tr.get("pos", AnimProp.make([0.0, 0.0])), c.inner_time("transform.pos", local_t) if own else local_t, c.duration, fps)
	var anchor: Vector2 = AnimProp.evaluate_vec2(tr.get("anchor", AnimProp.make([0.0, 0.0])), c.inner_time("transform.anchor", local_t) if own else local_t, c.duration, fps)
	var scale: Vector2 = AnimProp.evaluate_vec2(tr.get("scale", AnimProp.make([1.0, 1.0])), c.inner_time("transform.scale", local_t) if own else local_t, c.duration, fps)
	if bool(tr.get("scale_linked", true)):
		scale.y = scale.x
	var rotation: float = AnimProp.evaluate_float(tr.get("rotation", AnimProp.make(0.0)), c.inner_time("transform.rotation", local_t) if own else local_t, c.duration, fps)
	var opacity: float = AnimProp.evaluate_float(tr.get("opacity", AnimProp.make(1.0)), c.inner_time("transform.opacity", local_t) if own else local_t, c.duration, fps)
	var tf: Dictionary = {"pos": pos, "anchor": anchor, "scale": scale, "rotation": rotation, "opacity": clampf(opacity, 0.0, 1.0)}
	if not c.props.is_empty() and c.props.has(STAB_KEY):
		return load(TRACKING_EVAL).call("stabilised", c, tf, t)
	return tf


static func frame_of(tf: Dictionary) -> Transform2D:
	return Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, tf["pos"])


static func world_tf(c: Clip, s: Sequence, t: float, fps: float, token: int = -1) -> Dictionary:
	var tf: Dictionary = local_tf(c, t, fps)
	if c.parent.is_empty():
		return tf
	return apply_xf(tf, parent_xf(c, s, t, fps, token))


static func world_frame(c: Clip, s: Sequence, t: float, fps: float, token: int = -1) -> Transform2D:
	var f: Transform2D = frame_of(local_tf(c, t, fps))
	if c.parent.is_empty():
		return f
	return parent_xf(c, s, t, fps, token) * f


static func parent_xf(c: Clip, s: Sequence, t: float, fps: float, token: int = -1, depth: int = 0) -> Transform2D:
	var p: Clip = parent_of(c, s)
	if p == null or depth >= MAX_DEPTH:
		return Transform2D.IDENTITY
	return link_frame(p, c.parent, s, t, fps, token, depth + 1) * inv_of(c.parent)


static func link_frame(p: Clip, link: Dictionary, s: Sequence, t: float, fps: float, token: int = -1, depth: int = 1) -> Transform2D:
	var tp: float = clampf(t, p.start, p.end())
	var pin: int = int(link.get(KEY_PIN, -1))
	var pin_rot: bool = bool(link.get(KEY_PIN_ROT, false))
	var key: String = ""
	if token >= 0:
		if token != _memo_token or _memo.size() > MEMO_MAX:
			_memo = {}
			_memo_token = token
		key = p.id + "|" + str(tp) + "|" + str(pin) + "|" + str(pin_rot)
		var hit: Variant = _memo.get(key, null)
		if hit is Transform2D:
			memo_hits += 1
			return hit
	frames_built += 1
	var ptf: Dictionary = local_tf(p, tp, fps)
	var out: Transform2D = parent_xf(p, s, tp, fps, token, depth) * frame_of(ptf)
	if pin >= 0:
		out = out * pin_local(p, pin, tp, fps, pin_rot, ptf["anchor"])
	if not key.is_empty():
		_memo[key] = out
	return out


static func pin_local(p: Clip, pin: int, t: float, fps: float, pin_rot: bool, anchor: Vector2) -> Transform2D:
	var got: Variant = Puppet.pin_frame(p, pin, t, fps, pin_rot)
	if not (got is Transform2D):
		return Transform2D.IDENTITY
	var g: Transform2D = got
	return Transform2D(g.x, g.y, g.origin - anchor)


static func inv_of(link: Dictionary) -> Transform2D:
	var v: Variant = link.get(KEY_INV, null)
	if not (v is Array) or (v as Array).size() != 6:
		return Transform2D.IDENTITY
	var a: Array = v
	return Transform2D(Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]), float(a[3])), Vector2(float(a[4]), float(a[5])))


static func pack(m: Transform2D) -> Array:
	return [m.x.x, m.x.y, m.y.x, m.y.y, m.origin.x, m.origin.y]


static func is_identity(m: Transform2D) -> bool:
	return m.x.is_equal_approx(Vector2.RIGHT) and m.y.is_equal_approx(Vector2.DOWN) and m.origin.length() < 0.0001


static func apply_xf(tf: Dictionary, m: Transform2D) -> Dictionary:
	var rot_deg: float = float(tf["rotation"])
	var own: Transform2D = Transform2D(deg_to_rad(rot_deg), tf["scale"], 0.0, Vector2.ZERO)
	var lin: Transform2D = Transform2D(m.x, m.y, Vector2.ZERO) * own
	var parts: Vector3 = split_linear(lin, rot_deg)
	var out: Dictionary = tf.duplicate()
	out["pos"] = m * (tf["pos"] as Vector2)
	out["rotation"] = parts.x
	out["scale"] = Vector2(parts.y, parts.z)
	return out


static func split_linear(lin: Transform2D, near_deg: float) -> Vector3:
	var ax: Vector2 = lin.x
	var ay: Vector2 = lin.y
	var sx: float = ax.length()
	var det: float = ax.x * ay.y - ax.y * ay.x
	var sy: float = det / sx if sx > SAME_EPS else ay.length()
	var ang: float = atan2(ax.y, ax.x) if sx > SAME_EPS else 0.0
	var near: float = deg_to_rad(near_deg)
	var rot: float = near + wrapf(ang - near, -PI, PI)
	return Vector3(rad_to_deg(rot), sx, sy)


static func would_cycle(s: Sequence, child_id: String, new_parent_id: String) -> bool:
	if child_id == new_parent_id:
		return true
	var at: String = new_parent_id
	var steps: int = 0
	while not at.is_empty() and steps < MAX_DEPTH:
		if at == child_id:
			return true
		var c: Clip = s.clip_by_id(at)
		if c == null:
			return false
		at = parent_id(c)
		steps += 1
	return steps >= MAX_DEPTH


static func chain_of(c: Clip, s: Sequence) -> Array[Clip]:
	var out: Array[Clip] = []
	var at: Clip = parent_of(c, s)
	while at != null and out.size() < MAX_DEPTH and not out.has(at):
		out.append(at)
		at = parent_of(at, s)
	return out


static func children_of(s: Sequence, id: String) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	for c: Clip in s.all_clips():
		if parent_id(c) == id:
			out.append(c)
	return out


static func name_of(d: Project, c: Clip) -> String:
	if c == null:
		return ""
	if not c.label.is_empty():
		return c.label
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m != null and not m.label.is_empty():
		return m.label
	return c.id


static func refusal(d: Project, s: Sequence, child_id: String, new_parent_id: String) -> String:
	var c: Clip = s.clip_by_id(child_id) if s != null else null
	var p: Clip = s.clip_by_id(new_parent_id) if s != null else null
	if c == null:
		return "That clip is not in this sequence"
	if p == null:
		return "The parent has to be a clip in the same sequence"
	if c == p:
		return "A clip cannot be its own parent"
	if would_cycle(s, child_id, new_parent_id):
		return "Cannot parent " + name_of(d, c) + " to " + name_of(d, p) + ": " + name_of(d, p) + " already follows " + name_of(d, c) + ", so it would end up following itself"
	return ""


static func link_dict(new_parent_id: String, pin: int, pin_rot: bool) -> Dictionary:
	var out: Dictionary = {KEY_ID: new_parent_id}
	if pin >= 0:
		out[KEY_PIN] = pin
		if pin_rot:
			out[KEY_PIN_ROT] = true
	return out


static func link_commands(s: Sequence, child_id: String, new_parent_id: String, keep: bool, pin: int = -1, pin_rot: bool = false) -> Array[Command]:
	var out: Array[Command] = []
	var c: Clip = s.clip_by_id(child_id)
	var p: Clip = s.clip_by_id(new_parent_id)
	var link: Dictionary = link_dict(new_parent_id, pin, pin_rot)
	if keep:
		var before: Transform2D = parent_xf(c, s, s.playhead, s.fps)
		var pf: Transform2D = link_frame(p, link, s, s.playhead, s.fps)
		var inv: Transform2D = pf.affine_inverse() * before
		if not is_identity(inv):
			link[KEY_INV] = pack(inv)
	out.append(ClipCmds.SetClipField.new(s.id, child_id, FIELD, link))
	return out


static func link(d: Project, s: Sequence, child_id: String, new_parent_id: String, keep: bool = true, pin: int = -1, pin_rot: bool = false) -> String:
	var why: String = refusal(d, s, child_id, new_parent_id)
	if not why.is_empty():
		return why
	var label: String = "Parent to " + name_of(d, s.clip_by_id(new_parent_id))
	run(d, label, link_commands(s, child_id, new_parent_id, keep, pin, pin_rot))
	return ""


static func unlink_commands(s: Sequence, child_id: String, keep: bool) -> Array[Command]:
	var out: Array[Command] = []
	var c: Clip = s.clip_by_id(child_id)
	if c == null or c.parent.is_empty():
		return out
	if keep and parent_of(c, s) != null:
		var m: Transform2D = parent_xf(c, s, s.playhead, s.fps)
		if not is_identity(m):
			out.append(ClipCmds.SetClipField.new(s.id, child_id, "transform", baked_transform(c, m)))
	out.append(ClipCmds.SetClipField.new(s.id, child_id, FIELD, {}))
	return out


static func unlink(d: Project, s: Sequence, child_id: String, keep: bool = true) -> String:
	var c: Clip = s.clip_by_id(child_id) if s != null else null
	if c == null:
		return "That clip is not in this sequence"
	if c.parent.is_empty():
		return "That clip has no parent"
	run(d, "Remove parent", unlink_commands(s, child_id, keep))
	return ""


static func run(d: Project, label: String, cmds: Array[Command]) -> bool:
	if d == null or cmds.is_empty():
		return false
	var tx: Undo.Transaction = d.undo.begin(label)
	for cmd: Command in cmds:
		tx.apply(cmd)
	forget()
	return tx.commit()


static func baked_transform(c: Clip, m: Transform2D) -> Dictionary:
	var tf: Dictionary = c.transform.duplicate(true)
	var parts: Vector3 = split_linear(Transform2D(m.x, m.y, Vector2.ZERO), 0.0)
	var mirrored: bool = parts.z < 0.0
	var turn: float = parts.x
	var k: Vector2 = Vector2(parts.y, absf(parts.z))
	var linked: bool = bool(tf.get("scale_linked", true))
	if linked and (absf(k.x - k.y) > 0.0001 or mirrored):
		tf["scale_linked"] = false
	tf["pos"] = map_prop(tf.get("pos", AnimProp.make([0.0, 0.0])), _map_pos.bind(m))
	tf["rotation"] = map_prop(tf.get("rotation", AnimProp.make(0.0)), _map_rot.bind(turn, mirrored))
	tf["scale"] = map_prop(tf.get("scale", AnimProp.make([1.0, 1.0])), _map_scale.bind(k, linked, mirrored))
	return tf


static func _map_pos(v: Variant, m: Transform2D) -> Variant:
	var q: Vector2 = m * _vec(v, Vector2.ZERO)
	return [q.x, q.y]


static func _map_rot(v: Variant, turn: float, mirrored: bool) -> Variant:
	var r: float = float(v) if (v is float or v is int) else 0.0
	return (turn - r) if mirrored else (turn + r)


static func _map_scale(v: Variant, k: Vector2, linked: bool, mirrored: bool) -> Variant:
	var sc: Vector2 = _vec(v, Vector2.ONE)
	if linked:
		sc.y = sc.x
	return [sc.x * k.x, sc.y * k.y * (-1.0 if mirrored else 1.0)]


static func _vec(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return fallback


static func map_prop(p: Variant, f: Callable) -> Dictionary:
	if not (p is Dictionary):
		return AnimProp.make(f.call(p))
	var out: Dictionary = (p as Dictionary).duplicate(true)
	if not AnimProp.is_animated(out):
		out["v"] = f.call(out.get("v", null))
		return out
	out["base"] = f.call(out.get("base", null))
	var li: int = AnimProp.keys_layer_index(out)
	if li >= 0:
		for k: Variant in (out["layers"][li] as Dictionary).get("keys", []):
			var kd: Dictionary = k
			kd["v"] = f.call(kd.get("v", null))
	return out
