extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Puppet := preload("res://doc/puppet.gd")
const EFFECT_ID := "puppet"
const MESH_NODE := "PuppetMesh"
const SIDE := 256
const PICK_PATH := "res://modules/core_panels/monitor_pick.gd"
const DRAWN_KINDS: PackedStringArray = ["title", "shape", "image"]

static var gpu_reads: int = 0
static var cpu_builds: int = 0
static var last_ms: int = 0


static func follows_file(m: MediaItem) -> bool:
	return m != null and m.kind == "image" and not m.path.is_empty()


static func layer_node(c: Clip, comp: Node = null) -> Node:
	var host: Node = comp if comp != null else _session_compositor()
	if host == null or not is_instance_valid(host):
		return null
	var layers: Variant = host.get("layers")
	if not (layers is Dictionary) or not (layers as Dictionary).has(c.id):
		return null
	var l: Variant = (layers as Dictionary)[c.id]
	return l as Node if l is Node and is_instance_valid(l) else null


static func _session_compositor() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var session: Node = tree.root.get_node_or_null("/root/Session") if tree != null else null
	var v: Variant = session.get("compositor") if session != null else null
	return v as Node if v is Node else null


static func input_texture(c: Clip, e: Dictionary, comp: Node = null) -> Texture2D:
	var l: Node = layer_node(c, comp)
	if l == null:
		return null
	var uid: String = String(e.get("uid", ""))
	var passes: Variant = l.get("passes")
	if not uid.is_empty() and passes is Array:
		for pd: Variant in passes:
			if not (pd is Dictionary):
				continue
			var d: Dictionary = pd
			if String(d.get("effect_id", "")) != EFFECT_ID or String(d.get("uid", "")) != uid:
				continue
			var p: Node = d.get("pass", null)
			var mi: MeshInstance2D = p.get_node_or_null(MESH_NODE) as MeshInstance2D if p != null else null
			if mi != null and mi.texture != null:
				return mi.texture
	var outer: Variant = l.get("outer_tex")
	return outer if outer is Texture2D else null


static func gpu_image(c: Clip, e: Dictionary, comp: Node = null) -> Image:
	var tex: Texture2D = input_texture(c, e, comp)
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	gpu_reads += 1
	return img


static func cpu_image(d: Project, s: Sequence, c: Clip) -> Image:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var drawn: bool = m != null and DRAWN_KINDS.has(m.kind)
	if c.masks.is_empty() and not drawn:
		return null
	var pick: GDScript = load(PICK_PATH)
	var size: Vector2 = pick.call("layer_size", c, m, s, d)
	var k: float = float(SIDE) / maxf(maxf(size.x, size.y), 1.0)
	var w: int = maxi(int(round(size.x * k)), 1)
	var h: int = maxi(int(round(size.y * k)), 1)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var t: float = s.playhead
	var local: float = c.anim_time(t - c.start)
	for y: int in h:
		for x: int in w:
			var uv: Vector2 = Vector2((float(x) + 0.5) / float(w), (float(y) + 0.5) / float(h))
			var a: float = 0.0
			if bool(pick.call("inside_crops", c, uv, local, s.fps)):
				a = float(pick.call("mask_alpha", c, uv, size, local, s.fps))
				if a > 0.0 and drawn:
					a *= float(pick.call("content_alpha", c, m, uv, size, t, s))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	cpu_builds += 1
	return img


static func capture(d: Project, s: Sequence, c: Clip, e: Dictionary, comp: Node = null) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var img: Image = gpu_image(c, e, comp)
	var how: String = "picture"
	if img == null:
		img = cpu_image(d, s, c)
		how = "masks"
	var out: Dictionary = Puppet.encode_shape(img) if img != null else {"full": true}
	out["how"] = how
	out["at"] = s.playhead
	last_ms = Time.get_ticks_msec() - t0
	return out


static func info_with(info: Dictionary, got: Dictionary) -> Dictionary:
	var next: Dictionary = info.duplicate(true)
	next.erase(Puppet.SHAPE_FIELD)
	next.erase("sw")
	next.erase("sh")
	next.erase(Puppet.FRAMES_FIELD)
	next["from"] = float(got.get("at", 0.0))
	if not Puppet.shape_code(got).is_empty():
		next[Puppet.SHAPE_FIELD] = got[Puppet.SHAPE_FIELD]
		next["sw"] = int(got.get("sw", 0))
		next["sh"] = int(got.get("sh", 0))
		next["alpha"] = ""
	elif bool(got.get("full", false)):
		next["alpha"] = ""
	return next


static func first_info(d: Project, s: Sequence, c: Clip, size: Vector2, alpha_path: String) -> Dictionary:
	var info: Dictionary = {"w": size.x, "h": size.y, "alpha": alpha_path}
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if follows_file(m):
		return info
	var got: Dictionary = capture(d, s, c, {})
	if Puppet.shape_code(got).is_empty():
		return info
	return info_with(info, got)


static func describe(info: Dictionary, fps: float) -> String:
	var frames: Variant = info.get(Puppet.FRAMES_FIELD, null)
	if frames is Array and not (frames as Array).is_empty():
		return "Mesh follows the video, " + str((frames as Array).size()) + (" outline" if (frames as Array).size() == 1 else " outlines")
	if not Puppet.shape_code(info).is_empty():
		return "Mesh follows the picture at " + _clock(float(info.get("from", 0.0)), fps)
	if not String(info.get("alpha", "")).is_empty():
		return "Mesh follows the picture file"
	return "Mesh covers the whole picture"


static func _clock(t: float, fps: float) -> String:
	var f: int = int(round(maxf(t, 0.0) * maxf(fps, 1.0)))
	var per: int = maxi(int(round(fps)), 1)
	var secs: int = f / per
	return "%02d:%02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60, f % per]
