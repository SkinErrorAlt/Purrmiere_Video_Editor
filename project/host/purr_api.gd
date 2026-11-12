extends RefCounted
## The Purrmiere module API. Every module that declares "purr_api" in its module.json gets one of these in
## register(api), made for it alone. Modules reach Purrmiere only through here, so Purrmiere can change inside
## without breaking them. Adding something is a minor version; a module names the major it was built for and is
## refused politely when it does not match. Everything a module adds through here is removed when it unloads.

const MAJOR := 1
const MINOR := 2
const ModuleExtras := preload("res://host/module_extras.gd")

signal project_changed
signal sequence_changed(seq_id: String)
signal playhead_changed(t: float)
signal edited(kind: String)
signal selection_changed

var module_id: String = ""
var module_label: String = ""
var module_dir: String = ""
var _host: Node = null
var _panels: PackedStringArray = PackedStringArray()
var _commands: PackedStringArray = PackedStringArray()
var _settings: PackedStringArray = PackedStringArray()
var _ifaces: Array[Array] = []
var _windows: Array[WeakRef] = []
var _holds: PackedStringArray = PackedStringArray()
var _wired: bool = false
var _bound_doc: Object = null
var released: bool = false


static func version() -> String:
	return str(MAJOR) + "." + str(MINOR)


## Whether a module built for major.minor can run on this API.
static func accepts(wanted: String) -> bool:
	var parts: PackedStringArray = wanted.strip_edges().split(".")
	if parts.is_empty() or not parts[0].is_valid_int():
		return false
	var major: int = int(parts[0])
	var minor: int = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
	return major == MAJOR and minor <= MINOR


static func make(host: Node, id: String, label: String, dir: String) -> RefCounted:
	var script: GDScript = load("res://host/purr_api.gd")
	var api: RefCounted = script.new()
	api.set("_host", host)
	api.set("module_id", id)
	api.set("module_label", label)
	api.set("module_dir", dir.trim_suffix("/") + "/")
	api.call("_wire")
	return api


func _wire() -> void:
	var s: Node = _node("Session")
	if s == null or _wired:
		return
	_wired = true
	s.connect("project_changed", _on_project_changed)
	s.connect("sequence_changed", _on_sequence_changed)
	s.connect("playhead_changed", _on_playhead_changed)
	_bind_doc()


func _on_project_changed() -> void:
	_bind_doc()
	project_changed.emit()


func _bind_doc() -> void:
	var d: Object = doc()
	if d == _bound_doc:
		return
	_unbind_doc()
	_bound_doc = d
	if d != null and d.has_signal("changed"):
		d.connect("changed", _on_doc_changed)


func _unbind_doc() -> void:
	if _bound_doc != null and is_instance_valid(_bound_doc) and _bound_doc.is_connected("changed", _on_doc_changed):
		_bound_doc.disconnect("changed", _on_doc_changed)
	_bound_doc = null


func _on_doc_changed(kind: String) -> void:
	if kind == "selection":
		selection_changed.emit()
	else:
		edited.emit(kind)


func _on_sequence_changed(id: String) -> void:
	sequence_changed.emit(id)


func _on_playhead_changed(t: float) -> void:
	playhead_changed.emit(t)


func _node(name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/" + name)
	return null


func _extras() -> RefCounted:
	return ModuleExtras.shared()


# Files -----------------------------------------------------------------------------------------------------------

## A path inside the module's own folder.
func module_path(rel: String = "") -> String:
	return module_dir + rel.trim_prefix("/")


## The module's own writable folder for saved data, made on first use.
func data_dir() -> String:
	var io: GDScript = load("res://doc/io.gd")
	var dir: String = String(io.call("data_path", "module_data")).path_join(module_id)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func data_path(rel: String) -> String:
	return data_dir().path_join(rel)


# The open project ------------------------------------------------------------------------------------------------

func doc() -> Object:
	var s: Node = _node("Session")
	return s.get("doc") if s != null else null


func seq() -> Object:
	var s: Node = _node("Session")
	return s.call("seq") if s != null else null


func playhead() -> float:
	var sq: Object = seq()
	return float(sq.get("playhead")) if sq != null else 0.0


## Runs commands as one undo step labelled for the History panel.
func run(label: String, commands: Array) -> bool:
	var d: Object = doc()
	if d == null or commands.is_empty():
		return false
	var verbs: GDScript = load("res://doc/verbs.gd")
	var base: GDScript = load("res://doc/commands/command.gd")
	var typed: Array = Array([], TYPE_OBJECT, &"RefCounted", base)
	for c: Variant in commands:
		if c is RefCounted and (c as RefCounted).get_script() != null and _is_command(c as RefCounted, base):
			typed.append(c)
	if typed.is_empty():
		return false
	return bool(verbs.call("run", d, label, typed))


static func _is_command(c: RefCounted, base: GDScript) -> bool:
	var s: Script = c.get_script()
	while s != null:
		if s == base:
			return true
		s = s.get_base_script()
	return false


func undo() -> bool:
	var d: Object = doc()
	return d != null and bool((d.get("undo") as Object).call("undo"))


func redo() -> bool:
	var d: Object = doc()
	return d != null and bool((d.get("undo") as Object).call("redo"))


## Imports files into the open project's bin; returns the new media ids. With bin (1.2) they go into that bin
## folder, made if needed, whether or not the Bin panel is showing.
func import_files(paths: PackedStringArray, bin: String = "") -> PackedStringArray:
	var bus: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var panel: Object = (bus.call("instance") as Object).call("panel", "bin")
	if bin.is_empty() and panel != null and panel.has_method("import_paths"):
		return panel.call("import_paths", paths)
	var d: Object = doc()
	if d == null or (bin.is_empty() and panel == null):
		return PackedStringArray()
	var loader: Object = load("res://modules/core_panels/media_loader.gd").call("instance")
	return loader.call("import_paths", d, paths, bin)


## The registries modules read: effect and transition definitions.
func effects() -> Array[Dictionary]:
	var reg: GDScript = load("res://engine/effect_registry.gd")
	var out: Array[Dictionary] = []
	for d: Dictionary in (reg.call("shared") as Object).call("list"):
		out.append(d)
	return out


func transitions() -> Array[Dictionary]:
	var reg: GDScript = load("res://engine/transition_registry.gd")
	var out: Array[Dictionary] = []
	for d: Dictionary in (reg.call("shared") as Object).call("list"):
		out.append(d)
	return out


## The compositor of the open sequence, for reading frames (call read_frame on it and await).
func compositor() -> Object:
	var s: Node = _node("Session")
	return s.get("compositor") if s != null else null


# Editing documents (1.1) -----------------------------------------------------------------------------------------

## A fresh id for something new in the open project ("m" media, "c" clip, "t" track, "s" sequence, "e" effect).
func mint_id(prefix: String) -> String:
	var d: Object = doc()
	return String(d.call("mint_id", prefix)) if d != null else ""


## A plain copy of a sequence of the open project (the active one when seq_id is empty), as saved in project files.
func sequence_dict(seq_id: String = "") -> Dictionary:
	var s: Object = _seq_of(seq_id)
	return s.call("to_dict") if s != null else {}


## A plain copy of a media item of the open project.
func media_dict(media_id: String) -> Dictionary:
	var d: Object = doc()
	var m: Object = d.call("media_by_id", media_id) if d != null else null
	return m.call("to_dict") if m != null else {}


## Every sequence of the open project: {id, label, width, height, media_id, props} where props are its bin item's.
func sequence_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Object = doc()
	if d == null:
		return out
	for s: Object in (d.get("sequences") as Array):
		var m: Object = d.call("media_for_sequence", String(s.get("id")))
		out.append({"id": String(s.get("id")), "label": String(s.get("label")), "width": int(s.get("width")), "height": int(s.get("height")), "media_id": String(m.get("id")) if m != null else "", "props": (m.get("props") as Dictionary).duplicate(true) if m != null else {}})
	return out


## A new empty sequence as a dict, ready for command("add_sequence"). Nothing is added until it runs.
func blank_sequence(label: String, width: int, height: int, fps: float = 30.0, video_tracks: int = 1, audio_tracks: int = 0) -> Dictionary:
	var d: Object = doc()
	if d == null:
		return {}
	var tools: GDScript = load("res://doc/commands/edit_tools.gd")
	var sd: Dictionary = tools.call("new_sequence_dict", d, label, maxi(width, 1), maxi(height, 1), fps, 48000, maxi(video_tracks, audio_tracks))
	var vt: Array = sd.get("video_tracks", [])
	var at: Array = sd.get("audio_tracks", [])
	sd["video_tracks"] = vt.slice(0, video_tracks)
	sd["audio_tracks"] = at.slice(0, audio_tracks)
	return sd


## One of Purrmiere's undoable edits, for run(label, [...]). Fields in args by name; sequence_id defaults to the
## active sequence. Returns null for an unknown name or missing fields. Names and their fields:
## add_media {item}, remove_media {media_id, force}, set_media_field {media_id, field, value}, add_bin {path},
## add_sequence {sequence, media, make_active}, remove_sequence {sequence_id, force},
## set_sequence_field {field, value}, add_track {kind, index, track}, remove_track {track_id},
## reorder_track {track_id, index}, set_track_field {track_id, field, value}, place_clip {track_id, clip},
## remove_clips {clip_ids}, set_clip_field {clip_id, field, value}, set_clip_param {clip_id, path, value},
## add_effect {clip_id, effect_id, uid, index}, insert_effect {clip_id, entry, uid, index},
## remove_effect {clip_id, uid}, reorder_effect {clip_id, uid, index}, set_effect_enabled {clip_id, uid, on},
## set_effect_param {clip_id, uid, key, value}.
func command(name: String, args: Dictionary = {}) -> RefCounted:
	var sid: String = String(args.get("sequence_id", ""))
	if sid.is_empty():
		var s: Object = seq()
		sid = String(s.get("id")) if s != null else ""
	var media: GDScript = load("res://doc/commands/media_cmds.gd")
	var seqs: GDScript = load("res://doc/commands/sequence_cmds.gd")
	var tracks: GDScript = load("res://doc/commands/track_cmds.gd")
	var clips: GDScript = load("res://doc/commands/clip_cmds.gd")
	var fx: GDScript = load("res://doc/commands/effect_cmds.gd")
	var anim: GDScript = load("res://doc/anim_prop.gd")
	var cid: String = String(args.get("clip_id", ""))
	match name:
		"add_media":
			return _cmd(media, "AddMedia", [args.get("item", {})])
		"remove_media":
			return _cmd(media, "RemoveMedia", [String(args.get("media_id", "")), bool(args.get("force", false))])
		"set_media_field":
			var d0: Object = doc()
			var m0: Object = d0.call("media_by_id", String(args.get("media_id", ""))) if d0 != null else null
			return _cmd(media, "SetMediaField", [String(args.get("media_id", "")), String(args.get("field", "")), _typed_like(m0.get(String(args.get("field", ""))) if m0 != null else null, args.get("value"))])
		"add_bin":
			return _cmd(media, "AddBin", [String(args.get("path", ""))])
		"add_sequence":
			return _cmd(seqs, "AddSequence", [args.get("sequence", {}), args.get("media", {}), -1, bool(args.get("make_active", false))])
		"remove_sequence":
			return _cmd(seqs, "RemoveSequence", [sid, bool(args.get("force", false))])
		"set_sequence_field":
			return _cmd(seqs, "SetSequenceField", [sid, String(args.get("field", "")), args.get("value")])
		"add_track":
			return _cmd(tracks, "AddTrack", [sid, String(args.get("kind", "video")), int(args.get("index", -1)), args.get("track", {})])
		"remove_track":
			return _cmd(tracks, "RemoveTrack", [sid, String(args.get("track_id", ""))])
		"reorder_track":
			return _cmd(tracks, "ReorderTrack", [sid, String(args.get("track_id", "")), int(args.get("index", 0))])
		"set_track_field":
			return _cmd(tracks, "SetTrackField", [sid, String(args.get("track_id", "")), String(args.get("field", "")), args.get("value")])
		"place_clip":
			return _cmd(clips, "PlaceClip", [sid, String(args.get("track_id", "")), args.get("clip", {})])
		"remove_clips":
			return _cmd(clips, "RemoveClips", [sid, PackedStringArray(args.get("clip_ids", PackedStringArray()))])
		"set_clip_field":
			var target: Object = _clip_in(sid, cid)
			return _cmd(clips, "SetClipField", [sid, cid, String(args.get("field", "")), _typed_like(target.get(String(args.get("field", ""))) if target != null else null, args.get("value"))])
		"set_clip_param":
			return _cmd(clips, "SetClipParam", [sid, cid, String(args.get("path", "")), anim.call("make", args.get("value"))])
		"add_effect":
			var def: Dictionary = (load("res://engine/effect_registry.gd").call("shared") as Object).call("get_def", String(args.get("effect_id", "")))
			if def.is_empty():
				return null
			return _cmd(fx, "AddEffect", [sid, cid, def, String(args.get("uid", "")), int(args.get("index", -1))])
		"insert_effect":
			return _cmd(fx, "InsertEffectEntry", [sid, cid, args.get("entry", {}), String(args.get("uid", "")), int(args.get("index", -1))])
		"remove_effect":
			return _cmd(fx, "RemoveEffect", [sid, cid, String(args.get("uid", ""))])
		"reorder_effect":
			return _cmd(fx, "ReorderEffect", [sid, cid, String(args.get("uid", "")), int(args.get("index", 0))])
		"set_effect_enabled":
			return _cmd(fx, "SetEffectEnabled", [sid, cid, String(args.get("uid", "")), bool(args.get("on", true))])
		"set_effect_param":
			return _cmd(fx, "SetEffectParam", [sid, cid, String(args.get("uid", "")), String(args.get("key", "")), args.get("value")])
	return null


## While a slider is dragged: applies the edit now and keeps replacing it, without filling the history.
## commit_live(label) then makes everything since the drag began one undo step; cancel_live() puts it back.
func live(cmd: RefCounted) -> bool:
	var d: Object = doc()
	if d == null or cmd == null:
		return false
	(d.get("undo") as Object).call("live", cmd)
	return true


func commit_live(label: String) -> void:
	var d: Object = doc()
	if d != null:
		(d.get("undo") as Object).call("commit_live", label)


func cancel_live() -> void:
	var d: Object = doc()
	if d != null:
		(d.get("undo") as Object).call("cancel_live")


func _clip_in(seq_id: String, clip_id: String) -> Object:
	var s: Object = _seq_of(seq_id)
	return s.call("clip_by_id", clip_id) if s != null else null


static func _typed_like(current: Variant, value: Variant) -> Variant:
	if current is Array and value is Array and (current as Array).is_typed() and not (value as Array).is_typed():
		var cur: Array = current
		return Array(value, cur.get_typed_builtin(), cur.get_typed_class_name(), cur.get_typed_script())
	if current is PackedStringArray and value is Array:
		return PackedStringArray(value)
	return value


func _cmd(holder: GDScript, cls: String, args: Array) -> RefCounted:
	var inner: Variant = holder.get(cls)
	if inner == null:
		inner = holder.get_script_constant_map().get(cls, null)
	if not (inner is GDScript):
		return null
	return (inner as GDScript).callv("new", args)


## The plain value of an animatable property as stored in clips and effects ({"v": value} or keyframed).
func static_value(prop: Variant) -> Variant:
	if not (prop is Dictionary):
		return prop
	return load("res://doc/anim_prop.gd").call("static_value", prop)


## An unanimated property holding v, the way clips and effects store values (for clip dicts made by hand).
func prop_value(v: Variant) -> Dictionary:
	return load("res://doc/anim_prop.gd").call("make", v)


## Defaults for things Purrmiere draws itself: "title", "shape" or "generator" props.
func made_defaults(kind: String) -> Dictionary:
	return load("res://doc/title_style.gd").call("defaults_for", kind)


## A new mask, "rect" or "ellipse", for a clip's "masks" list.
func new_mask(kind: String) -> Dictionary:
	return load("res://doc/mask_shape.gd").call("make", kind, mint_id("mask"))


## The blend modes clips can use, in menu order.
func blend_modes() -> PackedStringArray:
	var modes: Dictionary = load("res://engine/layer_chain.gd").get("BLEND_MODES")
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in modes.keys():
		out.append(String(k))
	return out


## Shows a sequence in the Program monitor and timeline, where its clips have Purrmiere's gizmos.
func open_sequence(seq_id: String) -> bool:
	var s: Node = _node("Session")
	if s == null or _seq_of(seq_id) == null:
		return false
	s.call("set_sequence", seq_id)
	return String(s.get("seq_id")) == seq_id


## The clips selected in the active sequence, and selecting some (mode "replace", "add" or "toggle").
func selected_clips() -> PackedStringArray:
	var s: Object = seq()
	return (s.get("selected_clip_ids") as PackedStringArray).duplicate() if s != null else PackedStringArray()


func select_clips(ids: PackedStringArray, mode: String = "replace") -> bool:
	var d: Object = doc()
	var s: Object = seq()
	if d == null or s == null:
		return false
	return bool(load("res://doc/verbs.gd").call("select", d, s, ids, mode))


## The canvas tool: "select", "type", "pen" (masks) or "hand".
func tool() -> String:
	var s: Node = _node("Session")
	return String(s.get("tool_id")) if s != null else ""


func set_tool(id: String) -> void:
	var s: Node = _node("Session")
	if s != null:
		s.call("set_tool", id)


## Switches to a workspace tab, by its full id (a module's own: "<module id>.<id>").
func show_workspace(id: String) -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var screen: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false) if loop is SceneTree else null
	return screen != null and bool(screen.call("switch_workspace", id))


## Renders one frame of a sequence off screen at full size with a clear background and returns it (await it).
## Straight, not premultiplied, alpha. null without a GPU.
func render_image(seq_id: String = "", t: float = 0.0, timeout_ms: int = 8000) -> Image:
	var img: Image = await _render_seq(_seq_of(seq_id), t, 0, timeout_ms)
	return img


## Renders only some clips of a sequence (await it), the rest left out, on a clear background with straight alpha.
## The picture keeps the sequence's frame; max_side above 0 makes it smaller so its longer side fits. For layer
## thumbnails and previews. null without a GPU. (1.2)
func render_parts(seq_id: String, clip_ids: PackedStringArray, t: float = 0.0, max_side: int = 0, timeout_ms: int = 8000) -> Image:
	var s: Object = _seq_of(seq_id)
	if s == null:
		return null
	var sd: Dictionary = s.call("to_dict")
	var tracks: Array = []
	for td: Variant in sd.get("video_tracks", []):
		var t_d: Dictionary = (td as Dictionary).duplicate(true)
		var kept: Array = []
		for c: Variant in t_d.get("clips", []):
			if clip_ids.has(String((c as Dictionary).get("id", ""))):
				kept.append(c)
		t_d["clips"] = kept
		tracks.append(t_d)
	sd["video_tracks"] = tracks
	sd["audio_tracks"] = []
	var part: Object = load("res://doc/sequence.gd").call("from_dict", sd)
	var w: int = int(sd.get("width", 1920))
	var h: int = int(sd.get("height", 1080))
	var q: int = 0
	while max_side > 0 and q < 3 and maxi(w, h) / (2 * (1 << q)) >= max_side:
		q += 1
	var img: Image = await _render_seq(part, t, q, timeout_ms)
	if img != null and max_side > 0 and maxi(img.get_width(), img.get_height()) > max_side:
		var k: float = float(max_side) / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(int(round(float(img.get_width()) * k)), 1), maxi(int(round(float(img.get_height()) * k)), 1), Image.INTERPOLATE_LANCZOS)
	return img


func _render_seq(s: Object, t: float, quality: int, timeout_ms: int) -> Image:
	var d: Object = doc()
	var loop: MainLoop = Engine.get_main_loop()
	var script: GDScript = load("res://engine/compositor.gd")
	if d == null or s == null or not (loop is SceneTree) or not bool(script.call("has_gpu")):
		return null
	var tree: SceneTree = loop
	var comp: Node = script.new()
	comp.set("backdrop_hidden", true)
	tree.root.add_child(comp)
	comp.call("set_sequence", s, d)
	comp.call("set_quality", quality)
	comp.call("render_time", t, true)
	var t0: int = Time.get_ticks_msec()
	for i: int in 2:
		await tree.process_frame
		comp.call("render_time", t, true)
	while Time.get_ticks_msec() - t0 < timeout_ms:
		var st: Dictionary = comp.call("frame_state")
		if int(st.get("pending", 0)) == 0 and int(st.get("approx_layers", 0)) == 0:
			break
		await tree.process_frame
		comp.call("render_time", t, true)
	comp.call("render_time", t, true)
	var img: Image = await comp.call("read_frame")
	tree.root.remove_child(comp)
	comp.queue_free()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	_unpremultiply(img)
	return img


static func _unpremultiply(img: Image) -> void:
	var data: PackedByteArray = img.get_data()
	for i: int in range(0, data.size(), 4):
		var a: int = data[i + 3]
		if a == 0 or a == 255:
			continue
		data[i] = mini(255, int(round(float(data[i]) * 255.0 / float(a))))
		data[i + 1] = mini(255, int(round(float(data[i + 1]) * 255.0 / float(a))))
		data[i + 2] = mini(255, int(round(float(data[i + 2]) * 255.0 / float(a))))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


# Stills, presets, media and screens (1.2) -------------------------------------------------------------------------

## Keeps the playhead of a sequence between from_t and to_t while it shows (to_t below 0 means from_t). When the two
## are the same the sequence is a still: it does not play, and the Program monitor hides its timecode and transport.
## Taken back by release_playhead, or when the module is turned off.
func hold_playhead(seq_id: String, from_t: float = 0.0, to_t: float = -1.0) -> bool:
	var s: Node = _node("Session")
	if s == null or seq_id.is_empty():
		return false
	s.call("hold_playhead", seq_id, from_t, from_t if to_t < 0.0 else to_t)
	if not _holds.has(seq_id):
		_holds.append(seq_id)
	return true


func release_playhead(seq_id: String) -> void:
	var s: Node = _node("Session")
	if s != null:
		s.call("release_playhead", seq_id)
	var i: int = _holds.find(seq_id)
	if i >= 0:
		_holds.remove_at(i)


## Whether a sequence is held as a still by hold_playhead.
func is_still(seq_id: String) -> bool:
	var s: Node = _node("Session")
	return s != null and bool(s.call("is_still", seq_id))


## Presets in Purrmiere's library, the same ones the Effects panel lists. kind is one of Purrmiere's preset kinds,
## for example "effect" (payload {effect}) and "effect_stack" (payload {effects}).
func presets(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in load("res://doc/presets.gd").call("list_user", kind):
		out.append(p)
	return out


## Saves a preset into the library and returns it with its new id, or {} when it could not be saved.
func save_preset(kind: String, label: String, payload: Dictionary, tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var presets_script: GDScript = load("res://doc/presets.gd")
	var p: Dictionary = presets_script.call("make", kind, label, payload, tags)
	if p.is_empty() or not bool(presets_script.call("save_user", p)):
		return {}
	return p


func delete_preset(kind: String, id: String) -> bool:
	return bool(load("res://doc/presets.gd").call("delete_user", kind, id))


## Applies a preset to clips of a sequence as one undo step, the way the Effects panel does.
func apply_preset(preset: Dictionary, clip_ids: PackedStringArray, seq_id: String = "") -> bool:
	var d: Object = doc()
	var s: Object = _seq_of(seq_id)
	if d == null or s == null:
		return false
	return bool(load("res://doc/presets.gd").call("apply", d, s, preset, clip_ids))


## Makes a media item ready to show. Purrmiere opens the videos, GIFs and sounds it imports itself; media a module
## adds with command("add_media") are opened here. Returns false when the file cannot be opened.
func open_media(media_id: String) -> bool:
	var d: Object = doc()
	var m: Object = d.call("media_by_id", media_id) if d != null else null
	if m == null:
		return false
	if String(m.get("kind")) == "image" or String(m.get("kind")) == "sequence":
		return true
	var loader: Object = load("res://modules/core_panels/media_loader.gd").call("instance")
	return int(loader.call("open_item", d, m)) >= 0


## Waits (await it) until Purrmiere has read a media item's size and length, which for videos and GIFs comes a moment
## after import. True when ready, false when the time ran out or the item is gone.
func media_ready(media_id: String, timeout_ms: int = 6000) -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var t0: int = Time.get_ticks_msec()
	while true:
		var md: Dictionary = media_dict(media_id)
		if md.is_empty():
			return false
		var kind: String = String(md.get("kind", ""))
		if kind == "image" or kind == "sequence" or (int(md.get("width", 0)) > 0 and float(md.get("duration", 0.0)) > 0.0):
			return true
		if Time.get_ticks_msec() - t0 > timeout_ms or not (loop is SceneTree):
			return false
		await (loop as SceneTree).process_frame
	return false


## One frame of a video or GIF media item at a time in seconds, width pixels wide (0 for its own width).
## null when the media is not open or has no picture.
func media_frame(media_id: String, seconds: float, width: int = 0) -> Image:
	var s: Node = _node("Session")
	var bridge: Node = _node("PurrBridge")
	if s == null or bridge == null:
		return null
	var h: Variant = (s.get("media_handles") as Dictionary).get(media_id, -1)
	if typeof(h) != TYPE_INT or int(h) < 0:
		return null
	var img: Image = bridge.call("snapshot", int(h), maxf(seconds, 0.0), width)
	if img != null and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## The screens of this computer: {index, label, rect (usable area), here (Purrmiere's window is on it)}.
func screens() -> Array[Dictionary]:
	var sw: GDScript = load("res://ui/kit/pm_screen_window.gd")
	var rects: Array[Rect2i] = sw.call("screen_rects")
	var here: int = DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var out: Array[Dictionary] = []
	for i: int in rects.size():
		out.append({"index": i, "label": String(sw.call("screen_label", i)), "rect": rects[i], "here": i == here})
	return out


## Puts the Program monitor, the canvas with its gizmos, in a window of its own on a screen (-1: the screen used
## last, else one other than Purrmiere's). canvas_back() brings it home; canvas_screen() is -1 while it is home.
func canvas_to_screen(screen: int = -1) -> bool:
	var p: Object = _program()
	if p == null:
		return false
	if screen < 0:
		if not bool(p.call("popped_out")):
			p.call("toggle_popout")
		return bool(p.call("popped_out"))
	return bool(p.call("send_to_screen", screen))


func canvas_back() -> void:
	var p: Object = _program()
	if p != null:
		p.call("bring_back")


func canvas_screen() -> int:
	var p: Object = _program()
	return int(p.call("on_screen")) if p != null else -1


func _program() -> Object:
	var bus: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var p: Object = (bus.call("instance") as Object).call("panel", "program")
	return p if p != null and p.has_method("send_to_screen") else null


## A real window of its own holding the module's control: it can sit on any screen, outside Purrmiere's window.
## options: "screen" (index), "on_top" (stays above other windows), "rect" (Rect2i on the desktop). Returns the
## Window; it closes when its close button is pressed and when the module is turned off.
func open_screen_window(title: String, content: Control, size: Vector2, options: Dictionary = {}) -> Window:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree) or content == null:
		return null
	var tree: SceneTree = loop
	var sw: GDScript = load("res://ui/kit/pm_screen_window.gd")
	var screen: int = int(options.get("screen", DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)))
	var w: Window = sw.call("make", title, screen)
	var rects: Array[Rect2i] = sw.call("screen_rects")
	var r: Rect2i = Rect2i(Vector2i(80, 80), Vector2i(int(size.x), int(size.y)))
	if options.get("rect") is Rect2i:
		r = options["rect"]
	elif not rects.is_empty():
		var area: Rect2i = rects[clampi(screen, 0, rects.size() - 1)]
		var sz: Vector2i = Vector2i(mini(int(size.x), area.size.x), mini(int(size.y), area.size.y))
		r = Rect2i(area.position + (area.size - sz) / 2, sz)
	w.call("place", r)
	w.always_on_top = bool(options.get("on_top", false))
	if tree.root.theme != null:
		w.theme = tree.root.theme
	w.call("set_slot", content)
	w.connect("closed", func() -> void:
		if is_instance_valid(w):
			w.queue_free())
	tree.root.add_child(w)
	w.show()
	_windows.append(weakref(w))
	return w


func _seq_of(seq_id: String) -> Object:
	if seq_id.is_empty():
		return seq()
	var d: Object = doc()
	return d.call("sequence_by_id", seq_id) if d != null else null


# Purrmiere's look (1.1) ------------------------------------------------------------------------------------------

## A colour of the current theme by its token: bg_app, bg_panel, bg_panel_high, bg_field, border, border_soft,
## text, text_bright, text_dim, text_faint, accent, sol, inv and the others in host/tokens.gd.
func colour(token: String) -> Color:
	var tk: Node = _node("Tk")
	return tk.call("col", token) if tk != null else Color.MAGENTA


## A size in screen pixels for the current interface scale.
func ui_px(v: float) -> int:
	var tk: Node = _node("Tk")
	return int(tk.call("px", v)) if tk != null else int(v)


## One of the theme's fonts: "body", "body_medium", "body_semibold", "body_bold" or "mono".
func font(kind: String) -> Font:
	var tk: Node = _node("Tk")
	return tk.call("font", kind) if tk != null else null


## Draws one of Purrmiere's line icons (select, pen, hand, zoom, type, play...) into rect on a canvas item.
func draw_icon(ci: CanvasItem, name: String, rect: Rect2, tint: Color) -> void:
	load("res://ui/kit/icons.gd").call("draw", ci, name, rect, tint, 1.0)


func icon_names() -> PackedStringArray:
	return load("res://ui/kit/icons.gd").call("names")


# Adding things ---------------------------------------------------------------------------------------------------

## A dockable panel. impl is an object with the IPanel functions (id, title, build(parent), and optionally
## handle_key, save_state, restore_state, on_focus), or a script path inside the module. Returns the panel's full
## id, "<module id>.<id>", which workspace layouts use.
func add_panel(id: String, impl: Variant, title: String) -> String:
	var obj: Object = _instance(impl)
	if obj == null or _host == null:
		return ""
	var full: String = _scoped(id)
	if obj.has_method("setup"):
		obj.call("setup", full, title)
	_host.call("register", "IPanel", full, obj, {"title": title, "official": false, "module": module_id})
	_panels.append(full)
	return full


## Any other host interface (ITool, IExporter, IBinView, IPresetKind, IKeymap, ITheme...).
func add_impl(iface: String, id: String, impl: Variant, meta: Dictionary = {}) -> bool:
	var obj: Object = _instance(impl)
	if obj == null or _host == null:
		return false
	var m: Dictionary = meta.duplicate()
	m["module"] = module_id
	_host.call("register", iface, id, obj, m)
	_ifaces.append([iface, id])
	return true


func _instance(impl: Variant) -> Object:
	if impl is Object and not (impl is Script):
		return impl
	var script: Variant = impl if impl is Script else load(module_path(String(impl)) if not String(impl).begins_with("res://") and not String(impl).is_absolute_path() else String(impl))
	if script is GDScript and (script as GDScript).can_instantiate():
		return (script as GDScript).new()
	return null


## A workspace tab at the top (like Editing and Colour). layout is a dock layout, as in ui/dock/layouts/*.json.
func add_workspace(id: String, label: String, layout: Dictionary) -> void:
	_extras().call("add_workspace", module_id, _scoped(id), label, layout)


## A command people can run from menus, keys and the command search.
func add_command(id: String, label: String, handler: Callable, keys: Array = [], category: String = "") -> String:
	var cmd: Node = _node("Cmd")
	var full: String = _scoped(id)
	if cmd == null:
		return ""
	var ks: Array[String] = []
	for k: Variant in keys:
		ks.append(String(k))
	cmd.call("register", full, {"label": label, "category": category if not category.is_empty() else module_label, "scope": "global", "keys": {"premiere": ks, "classic": ks} if not ks.is_empty() else {}, "handler": handler, "owner": module_id})
	_commands.append(full)
	return full


## Puts a command in one of the menus: file, edit, clip, sequence, markers, window or help.
func add_menu_item(menu: String, command_id: String) -> void:
	_extras().call("add_menu_item", module_id, menu, command_id)


## A folder of effects (each a folder with effect.json, as in Purrmiere's own effects).
func add_effects_folder(rel: String = "effects") -> void:
	_extras().call("add_effect_root", module_id, module_path(rel))
	var reg: GDScript = load("res://engine/effect_registry.gd")
	(reg.call("shared") as Object).call("reload")


func add_transitions_folder(rel: String = "transitions") -> void:
	_extras().call("add_transition_root", module_id, module_path(rel))
	var reg: GDScript = load("res://engine/transition_registry.gd")
	(reg.call("shared") as Object).call("reload")


## A file format the module opens (open(path) -> bool) and or saves (save(path, what) -> bool). Dropped files with
## these extensions go to the module.
func add_format(id: String, label: String, exts: PackedStringArray, open: Callable, save: Callable = Callable()) -> void:
	_extras().call("add_format", module_id, _scoped(id), label, exts, open, save)


## Files dropped on Purrmiere's window while the module's workspace (its short id) shows go to handler first:
## handler(paths: PackedStringArray) -> PackedStringArray of the paths it did not take, which go on to the bin. (1.1)
func add_drop_handler(workspace: String, handler: Callable) -> void:
	_extras().call("add_drop_handler", module_id, _scoped(workspace), handler)


## A kind of document the module owns, with how to make a new one and open a saved one.
func add_document_kind(kind: String, label: String, ext: String, make_new: Callable, open: Callable) -> void:
	_extras().call("add_document_kind", module_id, _scoped(kind), label, ext, make_new, open)


## A setting in Settings. why is shown under it, in plain words.
func add_setting(key: String, default: Variant, label: String, why: String = "", type: String = "") -> String:
	var prefs: Node = _node("Prefs")
	var full: String = "module." + _scoped(key)
	if prefs == null:
		return ""
	var spec: Dictionary = {"label": label, "note": why, "module": module_id}
	if not type.is_empty():
		spec["type"] = type
	prefs.call("register", full, default, spec)
	_settings.append(full)
	return full


func setting(key: String) -> Variant:
	var prefs: Node = _node("Prefs")
	var full: String = key if key.begins_with("module.") else "module." + _scoped(key)
	return prefs.call("get_value", full) if prefs != null and bool(prefs.call("is_registered", full)) else null


func set_setting(key: String, v: Variant) -> void:
	var prefs: Node = _node("Prefs")
	var full: String = key if key.begins_with("module.") else "module." + _scoped(key)
	if prefs != null and bool(prefs.call("is_registered", full)):
		prefs.call("set_value", full, v)


func _scoped(id: String) -> String:
	return id if id.begins_with(module_id + ".") else module_id + "." + id


# Telling people things -------------------------------------------------------------------------------------------

func toast(text: String) -> void:
	var ev: Node = _node("Events")
	if ev != null:
		ev.call("toast", text)


func notice(text: String, detail: String = "") -> void:
	var ev: Node = _node("Events")
	if ev != null:
		ev.call("info", text, detail)


## A floating window holding the module's own control (pop outs, reference windows).
func open_window(title: String, content: Control, size: Vector2) -> Control:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	var pm: GDScript = load("res://ui/kit/pm_window.gd")
	var w: Control = pm.call("open", root if root != null else (loop as SceneTree).root, title, content, size, module_id + "." + title.to_lower().replace(" ", "_"))
	if w != null:
		_windows.append(weakref(w))
	return w


## Asks for a file. mode is "open", "open_many", "save" or "folder"; done gets the chosen path(s), nothing if cancelled.
func pick_file(mode: String, filters: PackedStringArray, done: Callable, title: String = "") -> void:
	var dlg: FileDialog = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.filters = filters
	dlg.title = title
	match mode:
		"save":
			dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		"open_many":
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		"folder":
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_:
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.file_selected.connect(func(p: String) -> void: done.call(p))
	dlg.files_selected.connect(func(ps: PackedStringArray) -> void: done.call(ps))
	dlg.dir_selected.connect(func(p: String) -> void: done.call(p))
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).root.add_child(dlg)
		dlg.popup_centered_ratio(0.6)


# Unloading -------------------------------------------------------------------------------------------------------

## Takes back everything this module added. Called by Purrmiere when the module is turned off or reloaded.
func release() -> void:
	if released:
		return
	released = true
	if _host != null:
		for id: String in _panels:
			_host.call("unregister", "IPanel", id)
		for pair: Array in _ifaces:
			_host.call("unregister", String(pair[0]), String(pair[1]))
	var cmd: Node = _node("Cmd")
	if cmd != null:
		for c: String in _commands:
			cmd.call("unregister", c)
	var extras: RefCounted = _extras()
	var dropped: PackedStringArray = extras.call("drop_owner", module_id)
	if dropped.has("effects"):
		(load("res://engine/effect_registry.gd").call("shared") as Object).call("reload")
	if dropped.has("transitions"):
		(load("res://engine/transition_registry.gd").call("shared") as Object).call("reload")
	_unbind_doc()
	for w: WeakRef in _windows:
		var win: Object = w.get_ref()
		if win != null and is_instance_valid(win) and win.has_method("close"):
			win.call("close")
		elif win is Window and is_instance_valid(win):
			(win as Window).queue_free()
	for id: String in _holds.duplicate():
		release_playhead(id)
	var s: Node = _node("Session")
	if s != null and _wired:
		for pair2: Array in [["project_changed", _on_project_changed], ["sequence_changed", _on_sequence_changed], ["playhead_changed", _on_playhead_changed]]:
			if s.is_connected(String(pair2[0]), pair2[1]):
				s.disconnect(String(pair2[0]), pair2[1])
	_panels = PackedStringArray()
	_commands = PackedStringArray()
	_ifaces = []
	_windows = []
	_holds = PackedStringArray()


## Everything this module has added, for the module card and the conformance suite.
func summary() -> Dictionary:
	return {"panels": _panels.duplicate(), "commands": _commands.duplicate(), "settings": _settings.duplicate(), "impls": _ifaces.size(), "extras": int(_extras().call("count_for", module_id))}
