extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Shelf := preload("res://doc/bin_shelf.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const BIN_PANEL_PATH := "res://modules/core_panels/bin_panel.gd"
const GHOST_W := 132.0
const NAME_ROW := 18.0


static func media_for(doc: Project, path: String) -> String:
	if doc == null or path.is_empty():
		return ""
	for m: MediaItem in doc.media:
		if not m.path.is_empty() and m.kind != "sequence" and Shelf.same(m.path, path) and not m.props.has("still_time"):
			return m.id
	return ""


static func payload_for(doc: Project, path: String) -> Dictionary:
	var id: String = media_for(doc, path)
	if not id.is_empty():
		return {"kind": "media", "ids": [id], "part": "both", "in": -1.0, "out": -1.0}
	return {"kind": "files", "paths": [path]}


static func can_leave(kind: String, path: String) -> bool:
	if kind != Shelf.FILE:
		return false
	var loader: GDScript = load("res://modules/core_panels/media_loader.gd")
	return not String(loader.call("kind_for", path)).is_empty()


static func begin(shelf: Control, panel: Object, path: String, grab: Vector2) -> bool:
	if shelf == null or not shelf.is_inside_tree():
		return false
	var layer: CanvasLayer = PmDragLayer.find(shelf)
	if layer == null:
		return false
	var doc: Project = Session.doc
	var payload: Dictionary = payload_for(doc, path)
	var bin_script: GDScript = load(BIN_PANEL_PATH)
	var ghost: Control = bin_script._Ghost.new()
	ghost.set("label", Shelf.leaf(path))
	var loader: GDScript = load("res://modules/core_panels/media_loader.gd")
	ghost.set("icon", String(bin_script.call("kind_icon", String(loader.call("kind_for", path)))))
	if String(payload["kind"]) == "media" and panel != null and panel.has_method("thumb_for"):
		var m: MediaItem = doc.media_by_id(String((payload["ids"] as Array)[0]))
		ghost.set("picture", panel.call("thumb_for", m, -1.0))
	var w: float = float(Tk.px(GHOST_W))
	ghost.size = Vector2(w, w * 0.6 + float(Tk.px(NAME_ROW)))
	layer.call("begin", payload, ghost, grab.clamp(Vector2.ZERO, ghost.size))
	return bool(layer.get("active"))
