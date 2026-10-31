extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextPresets := preload("res://doc/text_presets.gd")
const MAX_DEPTH := 6

static var enabled: bool = true


static func right_ids(cmds: Array, depth: int, into: Dictionary) -> void:
	for cmd: Variant in cmds:
		if not (cmd is Command):
			continue
		var c: Command = cmd
		var r: Variant = c.get("right_ids")
		if r is PackedStringArray:
			for id: String in r:
				into[id] = c.seq_id
		if depth < MAX_DEPTH:
			var inner: Variant = c.get("steps")
			if inner is Array:
				right_ids(inner, depth + 1, into)


static func reseeded(c: Clip) -> Dictionary:
	var out: Dictionary = {}
	var fresh: int = TextPresets.seed_for(c)
	for i: int in TextAnimators.count(c.props):
		var k: String = TextAnimators.key(i, "seed")
		if not c.props.has(k):
			continue
		var v: Variant = c.props[k]
		if v is Dictionary and AnimProp.is_animated(v):
			var ks: Array[Dictionary] = AnimProp.keys(v)
			if ks.is_empty():
				continue
			var delta: float = float(fresh) - float(ks[0].get("v", 0.0))
			var next: Dictionary = v
			for key_d: Dictionary in ks:
				next = AnimProp.set_key(next, float(key_d["t"]), fmod(float(key_d.get("v", 0.0)) + delta, float(TextPresets.SEED_RANGE)), String(key_d.get("i", "hold")))
			out[k] = next
		else:
			var base: Variant = TextAnimators.plain(v)
			if (base is float or base is int) and float(base) != float(fresh):
				out[k] = float(fresh)
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or doc == null:
		return out
	var rights: Dictionary = {}
	right_ids(cmds, 0, rights)
	for id: Variant in rights.keys():
		var s: Sequence = doc.sequence_by_id(String(rights[id]))
		var c: Clip = s.clip_by_id(String(id)) if s != null else null
		if c == null or TextAnimators.count(c.props) == 0:
			continue
		var change: Dictionary = reseeded(c)
		if change.is_empty():
			continue
		var props: Dictionary = c.props.duplicate(true)
		for k: Variant in change.keys():
			props[k] = change[k]
		var cmd: Command = ClipCmds.SetClipField.new(s.id, c.id, "props", props)
		cmd.label = "New random seed after a cut"
		cmd.do(doc)
		if cmd.ok:
			out.append(cmd)
	return out
