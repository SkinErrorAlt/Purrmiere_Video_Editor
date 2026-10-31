extends Node

signal taken(kind_id: String, count: int)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Find := preload("res://doc/picture_find.gd")
const Found := preload("res://doc/found_regions.gd")
const FindJob := preload("res://engine/picture_find_job.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SELF_PATH := "res://modules/core_panels/organizer/sample_take.gd"
const MENU_ID := "org_sample"
const ITEM_PREFIX := "org_sample:"
const MENU_LABEL := "Use this frame as a sample"
const IMAGE_FILTERS: PackedStringArray = ["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga ; Pictures"]

static var last_kind: String = ""
static var last_count: int = 0
static var last_error: String = ""

var kind_id: String = ""
var job: Dictionary = {}
var started_ms: int = 0


static func menu_item(enabled: bool = true) -> Dictionary:
	var sub: Array = []
	for k: Dictionary in Kinds.kinds():
		var n: int = (Found.spec_of(String(k["id"]))["frames"] as Array).size()
		sub.append(PmMenu.item(ITEM_PREFIX + String(k["id"]), "%s (%d sample%s)" % [String(k["name"]), n, "" if n == 1 else "s"]))
	var it: Dictionary = PmMenu.sub_item(MENU_ID, MENU_LABEL, sub, "search")
	if not enabled or sub.is_empty():
		it["disabled"] = true
	return it


static func kind_of_pick(id: String) -> String:
	return id.substr(ITEM_PREFIX.length()) if id.begins_with(ITEM_PREFIX) else ""


static func open_menu(anchor: Control, at: Vector2, on_pick: Callable, enabled: bool = true) -> Control:
	var m: Control = PmMenu.open(anchor, [menu_item(enabled)], at)
	if m != null and m.is_inside_tree():
		m.connect("picked", on_pick)
	return m


static func program_target(doc: Project, seq: Sequence) -> Dictionary:
	if doc == null or seq == null:
		return {}
	var t: float = seq.playhead
	for i: int in range(seq.video_tracks.size() - 1, -1, -1):
		var tr: Track = seq.video_tracks[i]
		if tr.hidden or tr.view_hidden:
			continue
		for c: Clip in tr.clips_at(t):
			if not c.enabled:
				continue
			var m: MediaItem = doc.media_by_id(c.media_id)
			if m == null or m.path.is_empty() or (m.kind != "video" and m.kind != "image"):
				continue
			return {"path": m.path, "t": maxf(c.source_time(t), 0.0), "kind": m.kind, "label": m.label}
	return {}


static func sample_of_image(img: Image) -> Dictionary:
	if img == null or img.is_empty():
		return {}
	var px: PackedByteArray = Find.small_rgb(img)
	if px.size() < Find.FRAME_W * Find.FRAME_H * 3:
		return {}
	return Find.sample_from(px, 0, Find.FRAME_W, Find.FRAME_H)


static func add_image_file(path: String, p_kind: String) -> int:
	last_error = ""
	if Kinds.by_id(p_kind).is_empty():
		last_error = "there is no such kind"
		return 0
	var img: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	var s: Dictionary = sample_of_image(img)
	if s.is_empty():
		last_error = "the picture could not be read"
		return 0
	s["path"] = path
	last_kind = p_kind
	last_count = Found.add_sample(p_kind, s)
	return last_count


static func take(path: String, t: float, p_kind: String, kind_of_file: String = "video") -> Node:
	last_error = ""
	if Kinds.by_id(p_kind).is_empty():
		last_error = "there is no such kind"
		return null
	if kind_of_file == "image":
		if add_image_file(path, p_kind) > 0:
			_toast("Sample added to %s" % Kinds.name_of(p_kind))
		else:
			_toast("No sample: " + last_error)
		return null
	if not FindJob.available():
		last_error = "the picture engine is not loaded"
		_toast("No sample: " + last_error)
		return null
	var j: Dictionary = FindJob.capture(path, t)
	if j.is_empty():
		last_error = "that frame could not be read"
		_toast("No sample: " + last_error)
		return null
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var script: GDScript = load(SELF_PATH)
	var n: Node = script.new()
	n.set("kind_id", p_kind)
	n.set("job", j)
	n.set("started_ms", Time.get_ticks_msec())
	n.name = "SampleTake"
	loop.root.add_child(n)
	return n


static func choose_image(host: Node, p_kind: String) -> void:
	if host == null or not host.is_inside_tree():
		return
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.title = "Choose a picture to use as a sample"
	dialog.filters = IMAGE_FILTERS
	dialog.file_selected.connect(func(p: String) -> void:
		if add_image_file(p, p_kind) > 0:
			_toast("Sample added to %s" % Kinds.name_of(p_kind))
		else:
			_toast("No sample: " + last_error)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	host.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


static func _toast(text: String) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var ev: Node = loop.root.get_node_or_null("/root/Events") if loop != null else null
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)


func _process(_dt: float) -> void:
	if job.is_empty():
		queue_free()
		return
	if not FindJob.capture_ready(job):
		return
	var s: Dictionary = FindJob.capture_take(job)
	job = {}
	if s.is_empty():
		last_error = "that frame could not be read yet"
		_toast("No sample: " + last_error)
	else:
		last_kind = kind_id
		last_count = Found.add_sample(kind_id, s)
		_toast("Sample added to %s (%d now)" % [Kinds.name_of(kind_id), last_count])
		taken.emit(kind_id, last_count)
	queue_free()
