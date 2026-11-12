extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Puppet := preload("res://doc/puppet.gd")
const PuppetShape := preload("res://modules/core_panels/puppet_shape.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Parenting := preload("res://doc/parenting.gd")
const LABEL := "Mesh follows the video"
const STEP_DEFAULT := 1

static var busy: bool = false
static var cancelled: bool = false
static var done_frames: int = 0
static var total_frames: int = 0
static var plant_one_frame: bool = false


static func entry_of(got: Dictionary, at: float) -> Dictionary:
	var out: Dictionary = {"at": snappedf(at, 0.000001)}
	if not Puppet.shape_code(got).is_empty():
		out[Puppet.SHAPE_FIELD] = got[Puppet.SHAPE_FIELD]
		out["sw"] = int(got.get("sw", 0))
		out["sh"] = int(got.get("sh", 0))
	elif bool(got.get("empty", false)):
		out["empty"] = true
	else:
		out["full"] = true
	return out


static func same_shape(a: Dictionary, b: Dictionary) -> bool:
	return Puppet.shape_code(a) == Puppet.shape_code(b) and bool(a.get("full", false)) == bool(b.get("full", false)) and bool(a.get("empty", false)) == bool(b.get("empty", false))


static func info_with_frames(info: Dictionary, frames: Array) -> Dictionary:
	var next: Dictionary = info.duplicate(true)
	next.erase(Puppet.SHAPE_FIELD)
	next.erase("sw")
	next.erase("sh")
	next["alpha"] = ""
	next[Puppet.FRAMES_FIELD] = frames
	next["from"] = float((frames[0] as Dictionary).get("at", 0.0)) if not frames.is_empty() else 0.0
	return next


static func bake(d: Project, s: Sequence, c: Clip, comp: Node = null, step: int = STEP_DEFAULT) -> String:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return "This clip has no puppet pins"
	if busy:
		return "The mesh is already following the video"
	var host: Node = comp if comp != null else PuppetShape._session_compositor()
	busy = true
	cancelled = false
	var fps: float = maxf(s.fps, 1.0)
	var count: int = maxi(int(floor(c.duration * fps + 0.0001)), 1)
	var every: int = maxi(step, 1)
	total_frames = (count + every - 1) / every
	done_frames = 0
	var was: float = s.playhead
	var frames: Array = []
	var f: int = 0
	while f < count and not cancelled:
		var local_t: float = float(f) / fps
		s.playhead = c.start + local_t
		var img: Image = null
		if host != null:
			host.call("render_time", c.start + local_t, true)
			await RenderingServer.frame_post_draw
			img = PuppetShape.gpu_image(c, e, host)
		if img == null:
			img = PuppetShape.cpu_image(d, s, c)
		var got: Dictionary = Puppet.encode_shape(img) if img != null else {"full": true}
		var entry: Dictionary = entry_of(got, local_t)
		if frames.is_empty() or not same_shape(frames[frames.size() - 1], entry):
			frames.append(entry)
		done_frames += 1
		if plant_one_frame:
			break
		f += every
	s.playhead = was
	if host != null:
		host.call("render_time", was, true)
	busy = false
	if cancelled:
		return "Following the video was stopped, the mesh was kept"
	var shown: Array = []
	for fr: Variant in frames:
		if not bool((fr as Dictionary).get("empty", false)):
			shown.append(fr)
	if shown.is_empty():
		return "Nothing of the picture shows in this clip, so the mesh was kept"
	var info: Dictionary = info_with_frames(Puppet.mesh_info(e), frames)
	var cmds: Array[Command] = [EffectCmds.SetEffectEntry.new(s.id, c.id, String(e.get("uid", "")), {Puppet.MESH_FIELD: info}, false, LABEL)]
	Parenting.run(d, LABEL, cmds)
	return ""
