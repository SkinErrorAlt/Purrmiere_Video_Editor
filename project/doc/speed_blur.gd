extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const PATH := "motion_blur.shutter_angle"
const MAX_KEYS := 64

static var plant_ignore_speed: bool = false


static func angle_for(speed: float, base: float, curve: float, lo: float, hi: float) -> float:
	var s: float = 1.0 if plant_ignore_speed else absf(speed)
	return clampf(base * pow(s, curve), lo, hi)


static func sample_times(c: Clip, fps: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var dur: float = maxf(c.duration, 0.0)
	if not AnimProp.is_animated(c.speed):
		out.append(0.0)
		return out
	var step: float = maxf(dur / float(MAX_KEYS - 1), 4.0 / maxf(fps, 1.0))
	var t: float = 0.0
	while t < dur - 0.0001 and out.size() < MAX_KEYS - 1:
		out.append(t)
		t += step
	out.append(dur)
	return out


static func baked(c: Clip, fps: float, base: float = 180.0, curve: float = 1.0, lo: float = 0.0, hi: float = 720.0) -> Dictionary:
	var times: PackedFloat64Array = sample_times(c, fps)
	if times.size() == 1:
		return AnimProp.make(angle_for(AnimProp.evaluate_float(c.speed, 0.0, c.duration, fps), base, curve, lo, hi))
	var prop: Dictionary = AnimProp.make(base)
	for t: float in times:
		prop = AnimProp.set_key(prop, t, angle_for(AnimProp.evaluate_float(c.speed, t, c.duration, fps), base, curve, lo, hi), "linear")
	return prop


static func bake(d: Project, s: Sequence, clip_id: String, base: float = 180.0, curve: float = 1.0, lo: float = 0.0, hi: float = 720.0) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var mb: Dictionary = c.motion_blur.duplicate(true)
	var cmds: Array[Command] = []
	if not bool(mb.get("on", false)):
		mb["on"] = true
		cmds.append(ClipCmds.SetClipField.new(s.id, clip_id, "motion_blur", mb))
	cmds.append(ClipCmds.SetClipParam.new(s.id, clip_id, PATH, baked(c, s.fps, base, curve, lo, hi)))
	return Verbs.run(d, "Match the motion blur to the speed", cmds)
