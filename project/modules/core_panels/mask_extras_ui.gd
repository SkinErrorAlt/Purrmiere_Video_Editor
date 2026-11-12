extends RefCounted
## Effect Controls mask extras: the Pen, Freehand and Picture buttons beside Rectangle and Ellipse, the points row of
## a drawn shape (smooth, straighten, add a point, copy and paste a shape, which morphs when the point counts
## differ), and the rows of a picture mask (the file, which channel cuts, its black and white points).

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const SELF_PATH := "res://modules/core_panels/mask_extras_ui.gd"

## The copied shape: {"points": PackedVector2Array, "handles": PackedVector2Array}, empty when nothing is copied.
static var clipboard: Dictionary = {}


## Pen, Freehand and Picture buttons for the add row.
static func add_buttons(panel: Object, row: HBoxContainer, many: bool = false) -> void:
	var script: GDScript = load(SELF_PATH)
	var pen: Button = PmButton.make("Pen", "pen")
	pen.set("quiet", true)
	PmUI.tip(pen, "Draw a shape mask on the Program monitor: click points, double click or Enter to finish. Drag from a point to curve it")
	pen.pressed.connect(func() -> void: script.call("start_pen", "polygon"))
	row.add_child(pen)
	var free: Button = PmButton.make("Freehand", "pen")
	free.set("quiet", true)
	PmUI.tip(free, "Draw a mask by hand on the Program monitor: drag round what you want and let go. It is thinned to a few points with smooth curves, so it stays easy to adjust")
	free.pressed.connect(func() -> void: script.call("start_pen", "draw"))
	row.add_child(free)
	var pic: Button = PmButton.make("Picture...", "image")
	pic.set("quiet", true)
	PmUI.tip(pic, "Use a picture as the mask: its brightness (or its see through parts, or one colour) shows the clip. Good for paper textures, painted edges, grunge, light leaks")
	pic.pressed.connect(func() -> void: script.call("ask_picture", panel, many))
	row.add_child(pic)


static func start_pen(kind: String) -> void:
	var mm: GDScript = load("res://modules/core_panels/monitor_mask.gd")
	mm.call("pick_shape", "penshape:" + kind)
	Events.toast("Draw on the Program monitor" + (": drag round the shape and let go" if kind == "draw" else ": click points, double click to finish"))


static func ask_picture(panel: Object, many: bool = false) -> void:
	var dlg: FileDialog = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	var exts: PackedStringArray = PackedStringArray()
	for e: String in MaskShape.PICTURE_EXTS:
		exts.append("*." + e)
	dlg.filters = PackedStringArray([", ".join(exts) + " ; Pictures"])
	dlg.title = "Picture to use as a mask"
	dlg.canceled.connect(dlg.queue_free)
	dlg.file_selected.connect(func(p: String) -> void:
		add_picture(panel, p, many)
		dlg.queue_free())
	(Engine.get_main_loop() as SceneTree).root.add_child(dlg)
	dlg.popup_centered_ratio(0.6)


## Adds a picture mask to the panel's clip (or every selected picture with `many`), sized to keep the picture's
## shape inside the frame.
static func add_picture(panel: Object, path: String, many: bool = false) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var clips: Array = []
	if many:
		clips = panel.call("_many_picture_clips")
	elif panel.call("target_clip") != null:
		clips = [panel.call("target_clip")]
	if clips.is_empty() or d == null or s == null or path.is_empty():
		return false
	var img: Image = null
	if path.begins_with("res://"):
		var tex: Texture2D = load(path) as Texture2D
		img = tex.get_image() if tex != null else null
	elif FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		Events.warn("Could not read " + path.get_file(), "Pick a PNG, JPEG, WebP or other picture file.")
		return false
	var frame_aspect: float = float(s.width) / maxf(float(s.height), 1.0)
	var aspect: float = (float(img.get_width()) / maxf(float(img.get_height()), 1.0)) / maxf(frame_aspect, 0.0001)
	var cmds: Array[Command] = []
	for c: Clip in clips:
		var masks: Array[Dictionary] = c.masks.duplicate(true)
		masks.append(MaskShape.make_picture(d.mint_id("mask"), path, aspect))
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	return Verbs.run(d, "Add picture mask", cmds)


## Rows for one mask: the points row for drawn shapes, the picture rows for picture masks.
static func mask_rows(panel: Object, body: VBoxContainer, mask: Dictionary) -> void:
	var mid: String = String(mask.get("id", ""))
	if mid.is_empty() or not String(mask.get("region_of", "")).is_empty():
		return
	if MaskShape.is_picture(mask):
		_picture_rows(panel, body, mask)
	elif not MaskShape.is_box(mask) and MaskShape.POLY_KINDS.has(String(mask.get("kind", "polygon"))):
		_points_row(panel, body, mask)


static func _row(panel: Object) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(panel.call("_spacer", float(Tk.px(Tk.sz("button_h")))))
	return row


static func _small_button(text: String, tip: String, act: Callable) -> Button:
	var b: Button = PmButton.make(text)
	b.set("quiet", true)
	PmUI.tip(b, tip)
	b.pressed.connect(act)
	return b


static func _points_row(panel: Object, body: VBoxContainer, mask: Dictionary) -> void:
	var script: GDScript = load(SELF_PATH)
	var mid: String = String(mask.get("id", ""))
	var c: Clip = panel.call("target_clip")
	if c == null:
		return
	var count: int = MaskShape.point_count(c.get_param("masks." + mid + ".points"))
	var animated: bool = AnimProp.is_animated(c.get_param("masks." + mid + ".points"))
	var row: HBoxContainer = _row(panel)
	row.add_child(PmLabel.small(str(count) + " points" + (", animated" if animated else "")))
	row.add_child(_small_button("Smooth", "Give every point smooth curves", func() -> void: script.call("smooth", panel, mid, 1.0)))
	row.add_child(_small_button("Straighten", "Take every curve off, so the edges are straight", func() -> void: script.call("smooth", panel, mid, 0.0)))
	row.add_child(_small_button("Add point", "Add a point in the middle of the longest edge (on every key)", func() -> void: script.call("add_point", panel, mid)))
	row.add_child(_small_button("Copy shape", "Copy this shape as it is on this frame", func() -> void: script.call("copy_shape", panel, mid)))
	var paste: Button = _small_button("Paste shape", "Paste the copied shape here. While the shape is animated it is keyed at the playhead and morphs from the keys around it, even with a different number of points", func() -> void: script.call("paste_shape", panel, mid))
	paste.disabled = clipboard.is_empty()
	row.add_child(paste)
	body.add_child(row)
	var lead: Array[Control] = [row.get_child(0) as Control]
	panel.call("_fit_lead_row", row, lead, 1)


static func _picture_rows(panel: Object, body: VBoxContainer, mask: Dictionary) -> void:
	var script: GDScript = load(SELF_PATH)
	var mid: String = String(mask.get("id", ""))
	var path: String = String(mask.get("image", ""))
	var row: HBoxContainer = _row(panel)
	var missing: bool = not path.begins_with("res://") and not FileAccess.file_exists(path)
	row.add_child(PmLabel.small("Picture: " + (path.get_file() if not path.is_empty() else "none") + (" (missing)" if missing and not path.is_empty() else "")))
	row.add_child(PmUI.spacer())
	row.add_child(_small_button("Change...", "Pick another picture for this mask", func() -> void: script.call("ask_change_picture", panel, mid)))
	body.add_child(row)
	var choices: Array = []
	for i: int in MaskShape.PICTURE_CHANNELS.size():
		choices.append(PmDrop.choice(MaskShape.PICTURE_CHANNELS[i], MaskShape.PICTURE_CHANNEL_LABELS[i]))
	var base: String = "masks." + mid + "."
	panel.call("_add_row", body, {"path": base + "channel", "label": "Cut by", "kind": "enum", "choices": choices, "keyable": false, "indent": 1})
	panel.call("_add_row", body, {"path": base + "low", "label": "Black point", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "indent": 1})
	panel.call("_add_row", body, {"path": base + "high", "label": "White point", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "indent": 1})


static func ask_change_picture(panel: Object, mid: String) -> void:
	var dlg: FileDialog = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.title = "Picture for this mask"
	dlg.canceled.connect(dlg.queue_free)
	dlg.file_selected.connect(func(p: String) -> void:
		change_picture(panel, mid, p)
		dlg.queue_free())
	(Engine.get_main_loop() as SceneTree).root.add_child(dlg)
	dlg.popup_centered_ratio(0.6)


static func change_picture(panel: Object, mid: String, path: String) -> bool:
	var c: Clip = panel.call("target_clip")
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if c == null or d == null or s == null:
		return false
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var i: int = MaskShape.index_of(masks, mid)
	if i < 0:
		return false
	masks[i]["image"] = path
	return Verbs.run(d, "Change mask picture", [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)])


## Writes a shape param: a key at the playhead while it is animated or armed, else the plain value.
static func _shape_cmd(panel: Object, c: Clip, s: Sequence, path: String, value: Array) -> Command:
	var bus: Object = panel.call("bus")
	var key_at: float = float(bus.call("key_time_for", c, path, s.playhead)) if bus != null else -1.0
	var current: Dictionary = MaskShape.flatten_prop(c.get_param(path))
	var next: Dictionary = AnimProp.make(value)
	if key_at >= 0.0 and not current.is_empty():
		next = MaskShape.flatten_prop(AnimProp.set_key(current, c.param_time(path, key_at - c.start), value))
	return ClipCmds.SetClipParam.new(s.id, c.id, path, next)


static func _now(panel: Object, mid: String) -> Dictionary:
	var c: Clip = panel.call("target_clip")
	var s: Sequence = panel.call("seq")
	if c == null or s == null:
		return {}
	var i: int = MaskShape.index_of(c.masks, mid)
	if i < 0:
		return {}
	var m: Dictionary = c.masks[i]
	var local: float = s.playhead - c.start
	return {"clip": c, "seq": s, "mask": m, "points": MaskShape.points_at(m, local, c.duration, s.fps), "handles": MaskShape.handles_at(m, local, c.duration, s.fps)}


static func smooth(panel: Object, mid: String, amount: float) -> bool:
	var now: Dictionary = _now(panel, mid)
	var d: Project = panel.call("doc")
	if now.is_empty() or d == null:
		return false
	var pts: PackedVector2Array = now["points"]
	var hs: PackedVector2Array = MaskShape.smooth_handles(pts, amount)
	var cmds: Array[Command] = [_shape_cmd(panel, now["clip"], now["seq"], "masks." + mid + ".handles", MaskShape.flat_of(hs))]
	return Verbs.run(d, "Smooth shape" if amount > 0.0 else "Straighten shape", cmds)


static func add_point(panel: Object, mid: String) -> bool:
	var now: Dictionary = _now(panel, mid)
	var d: Project = panel.call("doc")
	if now.is_empty() or d == null:
		return false
	var c: Clip = now["clip"]
	var s: Sequence = now["seq"]
	var ppath: String = "masks." + mid + ".points"
	var hpath: String = "masks." + mid + ".handles"
	var points: Dictionary = c.get_param(ppath)
	var handles: Dictionary = c.get_param(hpath) if (now["mask"] as Dictionary).has("handles") else {}
	var grown: Dictionary = MaskShape.grow_anim(points, handles, MaskShape.point_count(points) + 1)
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, ppath, grown["points"])]
	if not (grown["handles"] as Dictionary).is_empty():
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, hpath, grown["handles"]))
	return Verbs.run(d, "Add a shape point", cmds)


static func copy_shape(panel: Object, mid: String) -> bool:
	var now: Dictionary = _now(panel, mid)
	if now.is_empty():
		return false
	clipboard = {"points": now["points"], "handles": now["handles"]}
	Events.toast("Copied a shape of " + str((now["points"] as PackedVector2Array).size()) + " points")
	if panel.has_method("rebuild"):
		panel.call("rebuild")
	return true


## Pastes the copied shape. While the shape is animated (or armed) it becomes a key at the playhead, morphing from
## the keys around it whatever their point count; otherwise it replaces the shape.
static func paste_shape(panel: Object, mid: String) -> bool:
	if clipboard.is_empty():
		return false
	var now: Dictionary = _now(panel, mid)
	var d: Project = panel.call("doc")
	if now.is_empty() or d == null:
		return false
	var c: Clip = now["clip"]
	var s: Sequence = now["seq"]
	var ppath: String = "masks." + mid + ".points"
	var hpath: String = "masks." + mid + ".handles"
	var pts: PackedVector2Array = clipboard["points"]
	var hs: PackedVector2Array = clipboard.get("handles", PackedVector2Array())
	var bus: Object = panel.call("bus")
	var key_at: float = float(bus.call("key_time_for", c, ppath, s.playhead)) if bus != null else -1.0
	var cmds: Array[Command] = []
	if key_at >= 0.0:
		var keyed: Dictionary = MaskShape.key_whole_shape(c.get_param(ppath), c.get_param(hpath) if (now["mask"] as Dictionary).has("handles") else {}, c.param_time(ppath, key_at - c.start), c.duration, s.fps, pts, hs)
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, ppath, keyed["points"]))
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, hpath, keyed["handles"]))
	else:
		var full: PackedVector2Array = hs if hs.size() >= pts.size() * 2 else MaskShape.pairs_of(MaskShape.zero_handles(pts.size()))
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, ppath, AnimProp.make(MaskShape.flat_of(pts))))
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, hpath, AnimProp.make(MaskShape.flat_of(full))))
	return Verbs.run(d, "Paste shape", cmds)
