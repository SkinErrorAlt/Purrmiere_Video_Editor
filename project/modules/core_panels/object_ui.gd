extends RefCounted

const ObjectSelect := preload("res://engine/object_select.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const ObjectStore := preload("res://engine/object_store.gd")
const Contour := preload("res://engine/matte_contour.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Models := preload("res://engine/obj_models.gd")
const Brush := preload("res://engine/brush_stroke.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ObjectSource := preload("res://doc/object_source.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ObjectFx := preload("res://doc/object_fx.gd")
const Verbs := preload("res://doc/verbs.gd")
const SELF_PATH := "res://modules/core_panels/object_ui.gd"
const TOOL_ID := "object_select"
const COMMAND_ID := "tool.object_select"
const CMD_CLEAR := "object.clear"
const CMD_AGAIN := "object.again"
const CMD_FORWARD := "object.track_forward"
const CMD_BACKWARD := "object.track_backward"
const CMD_STOP := "object.track_stop"
const CMD_SOURCE := "object.as_source"
const SOURCE_LABEL := "Cut the object out as its own source"
const RUN_PATH := "res://modules/core_panels/object_run.gd"
const PICK_LABEL := "Select object"
const ADD_LABEL := "Add to the object"
const DROP_LABEL := "Take out of the object"
const CLEAR_LABEL := "Clear the object"
const TOOL_TIP := "Object Select: paint over the thing you want and it works out the object. Shift paints more in, Alt paints a part out, Ctrl+drag boxes it, [ and ] change the brush, Escape clears it"
const OBJECT_INK := Color(0.42, 0.95, 0.72, 1.0)
const KEEP_INK := Color(0.4, 0.95, 0.5, 1.0)
const DROP_INK := Color(1.0, 0.42, 0.4, 1.0)
const BOX_INK := Color(0.36, 0.84, 1.0, 1.0)
const RIM := Color(0.0, 0.0, 0.0, 0.7)
const LABEL_BACK := Color(0.051, 0.055, 0.063, 0.85)
const HOVER_INK := Color(0.42, 0.95, 0.72, 0.55)
const HOVER_RIM := Color(0.0, 0.0, 0.0, 0.4)
const MARK := 4.0
const MIN_BOX := 0.01
const SLOP := 3.0
const FRAME_WIDTH := 960
const HOVER_WAIT := 0.16
const HOVER_CELL := 44.0
const HOVER_SLOW := 90.0
const HOVER_KEEP := 64
const BRUSH_INK := Color(0.4, 0.95, 0.5, 0.5)
const BRUSH_OUT := Color(1.0, 0.42, 0.4, 0.5)
const BRUSH_EDGE := Color(1.0, 1.0, 1.0, 0.85)
const DIM_INK := Color(0.0, 0.0, 0.0, 1.0)
const BRUSH_MIN := 4.0
const BRUSH_MAX := 320.0
const BRUSH_STEP := 1.3
const STROKE_LEAST := 3.0
const BRUSH_LABEL := "Paint the object"

static var active_mask: String = ""
static var busy: bool = false
static var last_ms: float = 0.0
static var last_error: String = ""
static var track_done: int = 0
static var track_total: int = 0
static var hover_lines: Array = []
static var hover_region: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
static var hover_key: String = ""
static var hover_off: bool = false
static var hover_said: bool = false
static var _hover_cache: Dictionary = {}
static var _hover_last: float = 0.0
static var brush_px: float = 36.0
static var dim_back: float = 0.45
static var _dim_tex: ImageTexture = null
static var _dim_for: String = ""
static var _registered: bool = false

var drag: Dictionary = {}
var _lines: Array = []
var _lines_for: String = ""


static func _script() -> GDScript:
	return load(SELF_PATH)


static func tool_on() -> bool:
	return Session.tool_id == TOOL_ID


static func use_tool() -> void:
	Session.set_tool(TOOL_ID)
	hover_forget()
	hover_off = false
	var status: Dictionary = ObjectSelect.status_of()
	if not bool(status.get("ok", false)):
		Events.toast("Object Select needs its download: " + String(status.get("error", "")))
		return
	Events.toast(TOOL_TIP)


static func dim_texture(m: Dictionary, key: int, stamp: String) -> ImageTexture:
	if dim_back <= 0.0:
		return null
	if stamp == _dim_for and _dim_tex != null:
		return _dim_tex
	var matte: Image = ObjectMask.matte_at(m, key)
	if matte == null:
		_dim_tex = null
		_dim_for = stamp
		return null
	if matte.get_format() != Image.FORMAT_R8:
		matte.convert(Image.FORMAT_R8)
	var w: int = matte.get_width()
	var h: int = matte.get_height()
	var veil: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			veil.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0 - matte.get_pixel(x, y).r))
	_dim_tex = ImageTexture.create_from_image(veil)
	_dim_for = stamp
	return _dim_tex


static func dim_forget() -> void:
	_dim_tex = null
	_dim_for = ""


static func screen_at(pic: Rect2, region: Rect2, p: Vector2) -> Vector2:
	return pic.position + (region.position + p * region.size) * pic.size


static func hover_clear() -> void:
	hover_lines = []
	hover_key = ""


static func hover_forget() -> void:
	hover_clear()
	_hover_cache.clear()


static func hover_find(doc: Project, seq: Sequence, c: Clip, t: float, at: Vector2, key: String) -> void:
	if _hover_cache.has(key):
		var hit: Dictionary = _hover_cache[key]
		hover_lines = hit.get("lines", [])
		hover_region = hit.get("region", Rect2(0.0, 0.0, 1.0, 1.0))
		hover_key = key
		return
	var ready: Dictionary = ObjectSelect.ensure()
	if not bool(ready.get("ok", false)):
		hover_off = true
		return
	var frame: Image = source_frame(doc, c, t)
	if frame == null:
		hover_off = true
		return
	hover_from(frame, frame_of(c, seq, t), at, key)


static func hover_from(frame: Image, index: int, at: Vector2, key: String) -> void:
	busy = true
	var got: Dictionary = ObjectSelect.pick(frame, [at], [1], Rect2(0, 0, 0, 0), index)
	busy = false
	var ms: float = float(got.get("ms", 0.0))
	var lines: Array = []
	if bool(got.get("ok", false)) and not bool(got.get("empty", true)):
		var matte: Image = ObjectSelect.matte_image(got)
		if matte != null:
			lines = Contour.lines(matte, 2)
	if _hover_cache.size() >= HOVER_KEEP:
		_hover_cache.clear()
	_hover_cache[key] = {"lines": lines, "region": Rect2(0.0, 0.0, 1.0, 1.0)}
	hover_lines = lines
	hover_region = Rect2(0.0, 0.0, 1.0, 1.0)
	hover_key = key
	if ms > HOVER_SLOW:
		hover_off = true
		hover_clear()
		if not hover_said:
			hover_said = true
			Events.toast("Object Select: the highlight under the pointer is off, working an object out takes " + str(int(round(ms))) + " ms here")


static func toggle_tool() -> void:
	if tool_on():
		Session.set_tool("select")
	else:
		use_tool()


static func register_commands() -> void:
	if _registered:
		return
	_registered = true
	var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var me: GDScript = _script()
	var specs: Array = [
		[COMMAND_ID, "Object Select tool", "Tools", Callable(me, "use_tool"), Callable(me, "tool_on")],
		[CMD_CLEAR, "Object Select: clear the object on this clip", "Clip", Callable(me, "clear_object"), Callable()],
		[CMD_AGAIN, "Object Select: work the object out again on this frame", "Clip", Callable(me, "again"), Callable()],
		[CMD_FORWARD, "Object Select: track the object forward through the clip", "Clip", Callable(me, "track").bind("forward"), Callable()],
		[CMD_BACKWARD, "Object Select: track the object backward through the clip", "Clip", Callable(me, "track").bind("backward"), Callable()],
		[CMD_STOP, "Object Select: stop tracking the object", "Clip", Callable(me, "stop_track"), Callable()],
		[CMD_SOURCE, "Object Select: " + SOURCE_LABEL.to_lower(), "Clip", Callable(me, "cut_out_as_source"), Callable()],
	]
	var cat: Dictionary = Cmd.catalogue()
	for sp: Array in specs:
		var id: String = sp[0]
		if Cmd.has(id):
			continue
		var label: String = String(sp[1])
		var category: String = String(sp[2])
		if cat.has(id):
			label = String((cat[id] as Dictionary).get("label", label))
			category = String((cat[id] as Dictionary).get("category", category))
		var spec: Dictionary = {"label": label, "category": category, "scope": "global", "handler": sp[3], "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static")}
		if (sp[4] as Callable).is_valid():
			spec["toggle"] = sp[4]
		Cmd.register(id, spec)


static func runner() -> Node:
	return (load(RUN_PATH) as GDScript).call("shared")


static func tracking() -> bool:
	var run: Node = runner()
	return run != null and bool(run.call("running"))


static func track(direction: String, limit: int = 0) -> void:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return
	var c: Clip = _clip_now(doc, seq)
	if c == null:
		Events.toast("Object Select: no clip under the playhead")
		return
	if ObjectSource.has_linked_mask(c):
		Events.toast("This clip shows another clip's object; track it on the clip it was cut from and this one follows")
		return
	var run: Node = runner()
	if run == null:
		return
	if not run.is_connected("finished", Callable(_script(), "_on_tracked")):
		run.connect("finished", Callable(_script(), "_on_tracked"))
	if not run.is_connected("progress", Callable(_script(), "_on_progress")):
		run.connect("progress", Callable(_script(), "_on_progress"))
	var why: String = String(run.call("start", doc, seq, c, direction, limit))
	if not why.is_empty():
		last_error = why
		Events.toast("Object Select: " + why)
		return
	Events.toast("Tracking the object " + direction + " through the clip")


static func _on_progress(done: int, total: int) -> void:
	track_done = done
	track_total = total
	_redraw()


static func banner_text() -> String:
	if not tracking():
		return ""
	if track_total <= 0:
		return "Tracking the object"
	return "Tracking the object, " + str(mini(track_done + 1, track_total)) + " of " + str(track_total)


static func banner_part() -> float:
	if track_total <= 0:
		return 0.0
	return clampf(float(track_done) / float(track_total), 0.0, 1.0)


static func _on_tracked(ok: bool, info: Dictionary) -> void:
	var frames: int = int(info.get("frames", 0))
	if ok and String(info.get("error", "")) == "stopped":
		Events.toast("Stopped with " + str(frames) + (" frame" if frames == 1 else " frames") + " of the object kept")
	elif ok:
		Events.toast("The object is cut out through " + str(frames) + (" frame" if frames == 1 else " frames") + ", about %.0f ms a frame" % float(info.get("mean_ms", 0.0)) + _flag_note(info))
	else:
		last_error = String(info.get("error", ""))
		Events.toast("Object Select: " + last_error)
	_redraw()
	var doc: Project = Session.doc
	if doc != null and doc.has_signal("changed"):
		doc.changed.emit("masks")


static func _flag_note(info: Dictionary) -> String:
	var gone: int = int(info.get("gone", 0))
	var check: int = int(info.get("check", 0))
	if gone == 0 and check == 0:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if gone > 0:
		parts.append("%d not in view" % gone)
	if check > 0:
		parts.append("%d to check" % check)
	return ". " + ", ".join(parts) + ", marked on the strip under the clip"


static func hold_as_effect() -> bool:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return false
	var c: Clip = _clip_now(doc, seq)
	if c == null:
		Events.toast("Object Select: no clip under the playhead")
		return false
	if not ObjectFx.entry_of(c).is_empty():
		Events.toast("This clip already holds its object as an effect")
		return false
	var registry: RefCounted = load("res://engine/effect_registry.gd").call("shared")
	var def: Dictionary = registry.call("get_def", ObjectFx.EFFECT_ID)
	if def.is_empty():
		Events.toast("The Object Select effect is not in this build")
		return false
	var cmds: Array[Command] = [EffectCmds.AddEffect.new(seq.id, c.id, def)]
	if not Verbs.run(doc, "Hold the object as an effect", cmds):
		return false
	Events.toast("The object is held as an effect on this clip; point any other effect at it in its Mask row")
	return true


static func span_on(m: Dictionary) -> Vector2i:
	return ObjectSource.span_of(m, ObjectMatte.tracked_span(String(m.get("id", ""))))


static func source_item_for(doc: Project, seq: Sequence, c: Clip, m: Dictionary) -> Dictionary:
	if doc == null or seq == null or c == null or m.is_empty():
		return {}
	var span: Vector2i = span_on(m)
	if span.x < 0:
		return {}
	var src: MediaItem = doc.media_by_id(c.media_id)
	var link: Dictionary = ObjectSource.link_dict(seq.id, c, m, span, seq.fps)
	return ObjectSource.item_dict(doc.mint_id("m"), src, link, ObjectSource.label_for(c, m, src))


static func cut_out_as_source() -> bool:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return false
	var c: Clip = _clip_now(doc, seq)
	if c == null:
		Events.toast("Object Select: no clip under the playhead")
		return false
	var m: Dictionary = mask_on(c)
	if m.is_empty():
		Events.toast("This clip has no object on it yet")
		return false
	if ObjectSource.is_linked_mask(m):
		Events.toast("This clip already shows another clip's object; cut it out from the clip it came from")
		return false
	var item: Dictionary = source_item_for(doc, seq, c, m)
	if item.is_empty():
		Events.toast("Track the object first, so its source knows which frames it covers")
		return false
	var cmds: Array[Command] = [MediaCmds.AddMedia.new(item)]
	if not Verbs.run(doc, SOURCE_LABEL, cmds):
		return false
	var link: Dictionary = (item["props"] as Dictionary)[ObjectSource.PROP]
	var note: String = ". The clip it came from has a speed ramp, so its picture and its object can drift apart" if ObjectSource.ramped(link) else ""
	Events.toast(String(item["label"]) + " is in the bin, " + str(ObjectSource.frames_of(link)) + " frames long; drag it onto a track above and it snaps to the object's timing" + note)
	return true


static func place_object(doc: Project, seq: Sequence, media_id: String, track_id: String, t: float, mode: String = "overwrite") -> bool:
	var item: MediaItem = doc.media_by_id(media_id) if doc != null else null
	var target: Track = seq.track_by_id(track_id) if seq != null else null
	if item == null or target == null or target.locked or t < 0.0 or not target.accepts("video"):
		return false
	var link: Dictionary = ObjectSource.link_of(item)
	if link.is_empty():
		return false
	var got: Dictionary = ObjectSource.resolve(doc, link)
	var from: Dictionary = got["mask"] if bool(got["ok"]) else {}
	var duration: float = ObjectSource.duration_of(link)
	var cmds: Array[Command] = []
	Verbs.clear_for_place(seq, mode, t, duration, PackedStringArray([target.id]), cmds)
	var cid: String = doc.mint_id("c")
	var cd: Dictionary = {"id": cid, "media_id": media_id, "label": item.label, "start": t, "duration": duration, "in_offset": 0.0}
	var extras: Dictionary = ObjectSource.clip_extras(item, doc.mint_id("mask"), from)
	for key: Variant in extras.keys():
		cd[String(key)] = extras[key]
	var fit: Vector2 = Verbs.frame_fit_scale(seq, item)
	if fit != Vector2.ONE:
		cd["transform"] = {"scale": AnimProp.make([fit.x, fit.y]), "scale_linked": is_equal_approx(fit.x, fit.y)}
	Verbs.stamp_place(target, cd, "video", mode)
	cmds.append(ClipCmds.PlaceClip.new(seq.id, target.id, cd))
	if not Verbs.run(doc, "Place " + item.label, cmds):
		return false
	Verbs.select(doc, seq, PackedStringArray([cid]), "replace")
	if not bool(got["ok"]):
		_say(item.label + ": " + String(got["why"]) + ", so it draws nothing")
	return true


static func _say(text: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	if root == null or not root.has_node("Events"):
		return
	root.get_node("Events").call("toast", text)


static func stop_track() -> void:
	var run: Node = runner()
	if run != null:
		run.call("stop")


static func mask_on(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for m: Dictionary in c.masks:
		if ObjectMask.is_object(m) and (active_mask.is_empty() or str(m.get("id", "")) == active_mask):
			return m
	for m: Dictionary in c.masks:
		if ObjectMask.is_object(m):
			return m
	return {}


static func frame_of(c: Clip, seq: Sequence, t: float) -> int:
	if c == null or seq == null:
		return 0
	return int(round((t - c.start) * maxf(seq.fps, 1.0)))


static func source_frame(doc: Project, c: Clip, t: float) -> Image:
	if doc == null or c == null:
		return null
	var item: Variant = doc.media_by_id(c.media_id)
	if item == null:
		return null
	var path: String = String(item.get("path"))
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var h: int = Session.render_handle(path)
	if h < 0:
		return null
	var at: float = maxf(c.in_offset + maxf(t - c.start, 0.0), 0.0)
	return PurrBridge.snapshot(h, at, FRAME_WIDTH)


static func pick_on(doc: Project, seq: Sequence, c: Clip, t: float, points: Array, labels: Array, box: Rect2, label: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "ms": 0.0}
	if doc == null or seq == null or c == null:
		out["error"] = "no clip is under the playhead"
		last_error = String(out["error"])
		return out
	var ready: Dictionary = ObjectSelect.ensure()
	if not bool(ready.get("ok", false)):
		out["error"] = String(ready.get("error", "object select is not ready"))
		last_error = String(out["error"])
		return out
	var frame: Image = source_frame(doc, c, t)
	if frame == null:
		out["error"] = "the frame under the playhead could not be read"
		last_error = String(out["error"])
		return out
	var index: int = frame_of(c, seq, t)
	busy = true
	var got: Dictionary = ObjectSelect.pick(frame, points, labels, box, index)
	busy = false
	last_ms = float(got.get("ms", 0.0))
	if not bool(got.get("ok", false)):
		out["error"] = String(got.get("error", "the object could not be worked out"))
		last_error = String(out["error"])
		return out
	if bool(got.get("empty", true)):
		out["error"] = "nothing was found there"
		last_error = String(out["error"])
		return out
	var matte: Image = ObjectSelect.matte_image(got)
	if matte == null:
		out["error"] = "the matte came back empty"
		last_error = String(out["error"])
		return out
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var at: int = -1
	for i: int in masks.size():
		if ObjectMask.is_object(masks[i]) and (active_mask.is_empty() or str((masks[i] as Dictionary).get("id", "")) == active_mask):
			at = i
			break
	var m: Dictionary = {}
	if at < 0:
		m = ObjectMask.make(doc.mint_id("mask"), "Object " + str(_object_count(c) + 1))
		masks.append(m)
		at = masks.size() - 1
	else:
		m = masks[at]
	m["model"] = ObjectSelect.open_id()
	ObjectMask.put_matte(m, index, matte)
	ObjectMask.put_clicks(m, index, points, labels, box)
	masks[at] = m
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(seq.id, c.id, "masks", masks)]
	if not Verbs.run(doc, label, cmds):
		out["error"] = "the object could not be written to the clip"
		last_error = String(out["error"])
		return out
	active_mask = str(m.get("id", ""))
	ObjectMatte.forget(active_mask)
	last_error = ""
	out["ok"] = true
	out["ms"] = last_ms
	out["mask"] = active_mask
	out["area"] = got.get("area", 0.0)
	return out


static func stale_span(c: Clip, index: int) -> Vector2i:
	var m: Dictionary = mask_on(c)
	if m.is_empty():
		return Vector2i(-1, -1)
	var store: String = ObjectMatte.bound(str(m.get("id", "")))
	if store.is_empty():
		return Vector2i(-1, -1)
	var tracked: PackedInt32Array = ObjectStore.frame_list(store)
	if tracked.is_empty():
		return Vector2i(-1, -1)
	var next_key: int = -1
	for k: int in ObjectMask.key_frames(m):
		if k > index and (next_key < 0 or k < next_key):
			next_key = k
	var last: int = -1
	for f: int in tracked:
		if f <= index:
			continue
		if next_key >= 0 and f >= next_key:
			continue
		if f > last:
			last = f
	if last < 0:
		return Vector2i(-1, -1)
	return Vector2i(index, last)


static func carry_fix(doc: Project, seq: Sequence, c: Clip, index: int) -> String:
	var span: Vector2i = stale_span(c, index)
	if span.x < 0:
		return ""
	var run: Node = runner()
	if run == null:
		return ""
	if bool(run.call("running")):
		return "the object is already being tracked"
	if not run.is_connected("finished", Callable(_script(), "_on_tracked")):
		run.connect("finished", Callable(_script(), "_on_tracked"))
	if not run.is_connected("progress", Callable(_script(), "_on_progress")):
		run.connect("progress", Callable(_script(), "_on_progress"))
	var why: String = String(run.call("start_span", doc, seq, c, span.x, span.y))
	if not why.is_empty():
		last_error = why
		return why
	Events.toast("Carrying the fix through frames %d to %d" % [span.x + 1, span.y + 1])
	return ""


static func _object_count(c: Clip) -> int:
	var n: int = 0
	for m: Dictionary in c.masks:
		if ObjectMask.is_object(m):
			n += 1
	return n


static func clear_object() -> void:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return
	var c: Clip = _clip_now(doc, seq)
	if c == null:
		return
	var masks: Array[Dictionary] = []
	var dropped: bool = false
	for m: Dictionary in c.masks:
		if ObjectMask.is_object(m) and (active_mask.is_empty() or str(m.get("id", "")) == active_mask):
			dropped = true
			ObjectMatte.forget(str(m.get("id", "")))
			continue
		masks.append(m)
	if not dropped:
		return
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(seq.id, c.id, "masks", masks)]
	Verbs.run(doc, CLEAR_LABEL, cmds)
	active_mask = ""
	hover_forget()
	dim_forget()
	ObjectSelect.reset()


static func again() -> void:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return
	var c: Clip = _clip_now(doc, seq)
	if c == null:
		return
	var m: Dictionary = mask_on(c)
	if m.is_empty():
		return
	var t: float = Session.playhead()
	var index: int = frame_of(c, seq, t)
	var near: int = ObjectMask.nearest_key(m, index)
	var clicks: Dictionary = ObjectMask.clicks_at(m, near if near >= 0 else index)
	var points: Array = clicks.get("points", [])
	if points.is_empty() and (clicks.get("box", Rect2()) as Rect2).size.x <= 0.0:
		return
	ObjectSelect.reset()
	pick_on(doc, seq, c, t, points, clicks.get("labels", []), clicks.get("box", Rect2(0, 0, 0, 0)), PICK_LABEL)
	_redraw()


static func _clip_now(doc: Project, seq: Sequence) -> Clip:
	if doc == null or seq == null:
		return null
	for id: String in seq.selected_clip_ids:
		var picked: Clip = seq.clip_by_id(id)
		if picked != null:
			return picked
	var t: float = Session.playhead()
	for track: Variant in seq.video_tracks:
		for c: Clip in track.clips:
			if t >= c.start and t < c.start + c.duration:
				return c
	return null


static func _redraw() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	if root == null:
		return
	var editor: Node = root.find_child("EditorScreen", true, false)
	if editor != null:
		editor.call_deferred("queue_redraw")


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not tool_on() or pic.size.x <= 0.0 or pic.size.y <= 0.0:
		return false
	var doc: Project = panel.call("doc")
	var seq: Sequence = panel.call("seq")
	if doc == null or seq == null:
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			var marks: PackedVector2Array = PackedVector2Array()
			marks.append(mb.position)
			drag = {"from": _uv(pic, mb.position), "moved": false, "shift": mb.shift_pressed, "alt": mb.alt_pressed, "box": mb.ctrl_pressed, "marks": marks}
			hover_clear()
			return true
		if drag.is_empty():
			return false
		var from: Vector2 = drag["from"]
		var to: Vector2 = _uv(pic, mb.position)
		var moved: bool = bool(drag.get("moved", false))
		var shift: bool = bool(drag.get("shift", false))
		var alt: bool = bool(drag.get("alt", false))
		var boxing: bool = bool(drag.get("box", false))
		var marks: PackedVector2Array = drag.get("marks", PackedVector2Array())
		drag = {}
		var c: Clip = _clip_under(doc, seq, panel)
		if c == null:
			Events.toast("Object Select: no clip under the playhead")
			return true
		var box: Rect2 = Rect2(from, to - from).abs()
		if moved and boxing and box.size.x >= MIN_BOX and box.size.y >= MIN_BOX:
			_pick_box(doc, seq, c, panel, box)
		elif moved and marks.size() > 1:
			_pick_stroke(doc, seq, c, panel, pic, marks, shift, alt)
		else:
			_pick_point(doc, seq, c, panel, to, shift, alt)
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var wheel: InputEventMouseButton = event
		if wheel.alt_pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			step_brush(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			var wv: Control = panel.get("view")
			if wv != null:
				wv.call("redraw_overlay")
			return true
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if drag.is_empty():
			_hover(doc, seq, panel, pic, mm.position)
			return false
		var at: Vector2 = _uv(pic, mm.position)
		var start: Vector2 = drag["from"]
		if absf(at.x - start.x) * pic.size.x > SLOP or absf(at.y - start.y) * pic.size.y > SLOP:
			drag["moved"] = true
			drag["to"] = at
			if not bool(drag.get("box", false)):
				var marks: PackedVector2Array = drag.get("marks", PackedVector2Array())
				if marks.is_empty() or marks[marks.size() - 1].distance_to(mm.position) >= STROKE_LEAST:
					marks.append(mm.position)
					drag["marks"] = marks
			var view: Control = panel.get("view")
			if view != null:
				view.call("redraw_overlay")
		return true
	return false


func _hover(doc: Project, seq: Sequence, panel: Object, pic: Rect2, at: Vector2) -> void:
	if hover_off or busy or tracking():
		return
	var view: Control = panel.get("view")
	if not pic.has_point(at):
		if not hover_key.is_empty():
			hover_clear()
			if view != null:
				view.call("redraw_overlay")
		return
	var c: Clip = _clip_under(doc, seq, panel)
	if c == null:
		return
	var index: int = frame_of(c, seq, Session.playhead())
	var cx: int = int(floor((at.x - pic.position.x) / HOVER_CELL))
	var cy: int = int(floor((at.y - pic.position.y) / HOVER_CELL))
	var key: String = str(c.id) + "@" + str(index) + "@" + str(cx) + "," + str(cy)
	if key == hover_key:
		return
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if not _hover_cache.has(key) and now - _hover_last < HOVER_WAIT:
		return
	_hover_last = now
	hover_find(doc, seq, c, Session.playhead(), _uv(pic, at), key)
	if view != null:
		view.call("redraw_overlay")


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not tool_on() or not e.pressed:
		return false
	if e.keycode == KEY_BRACKETLEFT or e.keycode == KEY_BRACKETRIGHT:
		step_brush(1 if e.keycode == KEY_BRACKETRIGHT else -1)
		Events.toast("Object Select: brush " + str(int(round(brush_px))) + " px")
		var bv: Control = panel.get("view")
		if bv != null:
			bv.call("redraw_overlay")
		return true
	if e.keycode == KEY_ESCAPE:
		drag = {}
		if tracking():
			stop_track()
			return true
		clear_object()
		var view: Control = panel.get("view")
		if view != null:
			view.call("redraw_overlay")
		return true
	return false


func _pick_point(doc: Project, seq: Sequence, c: Clip, panel: Object, at: Vector2, shift: bool, alt: bool) -> void:
	var points: Array = []
	var labels: Array = []
	var box: Rect2 = Rect2(0, 0, 0, 0)
	var label: String = PICK_LABEL
	if shift or alt:
		var m: Dictionary = mask_on(c)
		var index: int = frame_of(c, seq, Session.playhead())
		if not m.is_empty():
			var near: int = ObjectMask.nearest_key(m, index)
			var kept: Dictionary = ObjectMask.clicks_at(m, near if near >= 0 else index)
			points = (kept.get("points", []) as Array).duplicate()
			labels = (kept.get("labels", []) as Array).duplicate()
			box = kept.get("box", Rect2(0, 0, 0, 0))
		label = DROP_LABEL if alt else ADD_LABEL
	points.append(at)
	labels.append(0 if alt else 1)
	var done: Dictionary = pick_on(doc, seq, c, Session.playhead(), points, labels, box, label)
	_after(panel, done)


static func step_brush(way: int) -> void:
	if way > 0:
		brush_px = minf(brush_px * BRUSH_STEP, BRUSH_MAX)
	else:
		brush_px = maxf(brush_px / BRUSH_STEP, BRUSH_MIN)


static func set_brush(px: float) -> void:
	brush_px = clampf(px, BRUSH_MIN, BRUSH_MAX)


static func stroke_prompts(marks: PackedVector2Array, pic: Rect2) -> Array:
	return stroke_prompt_spec(marks, pic)["points"]


static func stroke_prompt_spec(marks: PackedVector2Array, pic: Rect2) -> Dictionary:
	var uvs: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in marks:
		uvs.append(Vector2(clampf((p.x - pic.position.x) / maxf(pic.size.x, 1.0), 0.0, 1.0), clampf((p.y - pic.position.y) / maxf(pic.size.y, 1.0), 0.0, 1.0)))
	var thinned: PackedVector2Array = Brush.thin(uvs, STROKE_LEAST / maxf(pic.size.y, 1.0))
	return {"points": Brush.along(thinned, Brush.MOST_PROMPTS), "box": Rect2(0, 0, 0, 0)}


func _pick_stroke(doc: Project, seq: Sequence, c: Clip, panel: Object, pic: Rect2, marks: PackedVector2Array, shift: bool, alt: bool) -> void:
	var spec: Dictionary = stroke_prompt_spec(marks, pic)
	var fresh: Array = spec["points"]
	if fresh.is_empty():
		return
	var points: Array = []
	var labels: Array = []
	var box: Rect2 = spec["box"]
	var label: String = BRUSH_LABEL
	if shift or alt:
		var m: Dictionary = mask_on(c)
		var index: int = frame_of(c, seq, Session.playhead())
		if not m.is_empty():
			var near: int = ObjectMask.nearest_key(m, index)
			var kept: Dictionary = ObjectMask.clicks_at(m, near if near >= 0 else index)
			points = (kept.get("points", []) as Array).duplicate()
			labels = (kept.get("labels", []) as Array).duplicate()
			box = kept.get("box", Rect2(0, 0, 0, 0))
		label = DROP_LABEL if alt else ADD_LABEL
	for p: Variant in fresh:
		points.append(p)
		labels.append(0 if alt else 1)
	var done: Dictionary = pick_on(doc, seq, c, Session.playhead(), points, labels, box, label)
	_after(panel, done)


func _pick_box(doc: Project, seq: Sequence, c: Clip, panel: Object, box: Rect2) -> void:
	var done: Dictionary = pick_on(doc, seq, c, Session.playhead(), [], [], box, PICK_LABEL)
	_after(panel, done)


func _after(panel: Object, done: Dictionary) -> void:
	_lines_for = ""
	hover_forget()
	dim_forget()
	if not bool(done.get("ok", false)):
		Events.toast("Object Select: " + String(done.get("error", "it did not work")))
	else:
		var doc: Project = panel.call("doc")
		var seq: Sequence = panel.call("seq")
		var c: Clip = _clip_under(doc, seq, panel)
		if doc != null and seq != null and c != null:
			var why: String = carry_fix(doc, seq, c, frame_of(c, seq, Session.playhead()))
			if not why.is_empty():
				Events.toast("Object Select: " + why)
	var view: Control = panel.get("view")
	if view != null:
		view.call("redraw_overlay")


func _clip_under(doc: Project, seq: Sequence, panel: Object) -> Clip:
	var c: Variant = panel.call("gizmo_clip") if panel.has_method("gizmo_clip") else null
	if c is Clip:
		return c
	return _clip_now(doc, seq)


func _uv(pic: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf((p.x - pic.position.x) / maxf(pic.size.x, 1.0), 0.0, 1.0), clampf((p.y - pic.position.y) / maxf(pic.size.y, 1.0), 0.0, 1.0))


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if not tool_on() or pic.size.x <= 0.0:
		return
	var doc: Project = panel.call("doc")
	var seq: Sequence = panel.call("seq")
	if doc == null or seq == null:
		return
	var c: Clip = _clip_under(doc, seq, panel)
	if c != null:
		var m: Dictionary = mask_on(c)
		if not m.is_empty():
			_draw_dim(ci, pic, c, seq, m)
	if drag.is_empty() and not hover_lines.is_empty():
		_draw_hover(ci, pic)
	if c != null:
		var m2: Dictionary = mask_on(c)
		if not m2.is_empty():
			_draw_object(ci, pic, c, seq, m2)
	_draw_banner(ci, pic)
	if not drag.is_empty() and bool(drag.get("moved", false)):
		if bool(drag.get("box", false)):
			var from: Vector2 = drag["from"]
			var to: Vector2 = drag.get("to", from)
			var box: Rect2 = Rect2(from, to - from).abs()
			ci.draw_rect(Rect2(pic.position + box.position * pic.size, box.size * pic.size), BOX_INK, false, 1.0)
		else:
			_draw_stroke(ci)
	_draw_brush(ci, pic, panel)


static func live_mask(m: Dictionary) -> Dictionary:
	if not ObjectSource.is_linked_mask(m):
		return m
	var got: Dictionary = ObjectMatte.target_of(m)
	return got["mask"] if bool(got["ok"]) else {}


func _draw_dim(ci: CanvasItem, pic: Rect2, c: Clip, seq: Sequence, shown: Dictionary) -> void:
	if dim_back <= 0.0:
		return
	var m: Dictionary = live_mask(shown)
	if m.is_empty():
		return
	var index: int = frame_of(c, seq, Session.playhead()) + ObjectSource.frame_offset(shown)
	var key: int = ObjectMask.nearest_key(m, index)
	if key < 0:
		return
	var tex: ImageTexture = dim_texture(m, key, str(m.get("id", "")) + "@" + str(key))
	if tex == null:
		return
	var region: Rect2 = ObjectMask.region_of(m)
	var where: Rect2 = Rect2(pic.position + region.position * pic.size, region.size * pic.size)
	ci.draw_texture_rect(tex, where, false, Color(DIM_INK.r, DIM_INK.g, DIM_INK.b, clampf(dim_back, 0.0, 1.0)))


func _draw_stroke(ci: CanvasItem) -> void:
	var marks: PackedVector2Array = drag.get("marks", PackedVector2Array())
	if marks.size() < 1:
		return
	var ink: Color = BRUSH_OUT if bool(drag.get("alt", false)) else BRUSH_INK
	if marks.size() == 1:
		ci.draw_circle(marks[0], brush_px * 0.5, ink)
		return
	ci.draw_polyline(marks, ink, brush_px, true)
	ci.draw_circle(marks[0], brush_px * 0.5, ink)
	ci.draw_circle(marks[marks.size() - 1], brush_px * 0.5, ink)


func _draw_brush(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	var view: Control = panel.get("view")
	if view == null or not view.has_method("get_local_mouse_position"):
		return
	var at: Vector2 = view.call("get_local_mouse_position")
	if not pic.has_point(at):
		return
	ci.draw_arc(at, brush_px * 0.5, 0.0, TAU, 28, RIM, 2.0, true)
	ci.draw_arc(at, brush_px * 0.5, 0.0, TAU, 28, BRUSH_EDGE, 1.0, true)


func _draw_hover(ci: CanvasItem, pic: Rect2) -> void:
	for line: Variant in hover_lines:
		var pts: PackedVector2Array = line
		if pts.size() < 2:
			continue
		var a: Vector2 = screen_at(pic, hover_region, pts[0])
		var b: Vector2 = screen_at(pic, hover_region, pts[1])
		ci.draw_line(a + Vector2.ONE, b + Vector2.ONE, HOVER_RIM, 2.0)
		ci.draw_line(a, b, HOVER_INK, 1.0)


func _draw_banner(ci: CanvasItem, pic: Rect2) -> void:
	var text: String = banner_text()
	if text.is_empty():
		return
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = 8.0
	var height: float = float(fs) + pad * 2.0
	var bar: Rect2 = Rect2(pic.position.x, pic.position.y, pic.size.x, height)
	ci.draw_rect(bar, LABEL_BACK)
	ci.draw_rect(Rect2(bar.position.x, bar.end.y - 2.0, bar.size.x * banner_part(), 2.0), OBJECT_INK)
	PmText.draw(ci, font, bar, text + "   Esc or Stop to end it", fs, OBJECT_INK, HORIZONTAL_ALIGNMENT_LEFT, pad)


func _draw_object(ci: CanvasItem, pic: Rect2, c: Clip, seq: Sequence, shown: Dictionary) -> void:
	var m: Dictionary = live_mask(shown)
	if m.is_empty():
		return
	var index: int = frame_of(c, seq, Session.playhead()) + ObjectSource.frame_offset(shown)
	var key: int = ObjectMask.nearest_key(m, index)
	if key < 0:
		return
	var stamp: String = str(m.get("id", "")) + "@" + str(key)
	if stamp != _lines_for:
		var matte: Image = ObjectMask.matte_at(m, key)
		_lines = Contour.lines(matte, 2)
		_lines_for = stamp
	var region: Rect2 = ObjectMask.region_of(m)
	for line: Variant in _lines:
		var pts: PackedVector2Array = line
		if pts.size() < 2:
			continue
		var a: Vector2 = screen_at(pic, region, pts[0])
		var b: Vector2 = screen_at(pic, region, pts[1])
		ci.draw_line(a + Vector2.ONE, b + Vector2.ONE, RIM, 2.0)
		ci.draw_line(a, b, OBJECT_INK, 1.0)
	var clicks: Dictionary = ObjectMask.clicks_at(m, key)
	var points: Array = clicks.get("points", [])
	var labels: Array = clicks.get("labels", [])
	for i: int in points.size():
		var at: Vector2 = pic.position + (points[i] as Vector2) * pic.size
		var keep: bool = i >= labels.size() or int(labels[i]) == 1
		ci.draw_circle(at, MARK + 1.0, RIM)
		ci.draw_circle(at, MARK, KEEP_INK if keep else DROP_INK)


static func drop_edits(this_frame_only: bool) -> bool:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return false
	var c: Clip = _clip_now(d, s)
	if c == null:
		return false
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var at: int = -1
	for i: int in masks.size():
		var m: Dictionary = masks[i]
		if ObjectMask.is_object(m) and (active_mask.is_empty() or String(m.get("id", "")) == active_mask) and not ObjectMask.edited_frames(m).is_empty():
			at = i
			break
	if at < 0:
		return false
	var mask: Dictionary = masks[at]
	if this_frame_only:
		var frame: int = frame_of(c, s, s.playhead)
		if not ObjectMask.has_edit(mask, frame):
			return false
		ObjectMask.drop_edit(mask, frame)
	else:
		ObjectMask.clear_edits(mask)
	masks[at] = mask
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)]
	if not Verbs.run(d, "Drop the hand edits of this frame" if this_frame_only else "Drop every hand edit", cmds):
		return false
	ObjectMatte.forget(String(mask.get("id", "")))
	dim_forget()
	return true


static func set_edit_holds(on: bool) -> bool:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return false
	var c: Clip = _clip_now(d, s)
	if c == null:
		return false
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var at: int = -1
	for i: int in masks.size():
		var m: Dictionary = masks[i]
		if ObjectMask.is_object(m) and (active_mask.is_empty() or String(m.get("id", "")) == active_mask):
			at = i
			break
	if at < 0 or ObjectMask.holds_on(masks[at]) == on:
		return false
	var mask: Dictionary = masks[at]
	ObjectMask.set_holds(mask, on)
	masks[at] = mask
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)]
	if not Verbs.run(d, "Hold the hand edits on" if on else "Hand edits on their own frame only", cmds):
		return false
	ObjectMatte.forget(String(mask.get("id", "")))
	dim_forget()
	return true
