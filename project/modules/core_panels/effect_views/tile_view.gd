extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const TILE_GRID := 104.0
const TILE_BIG := 176.0
const SCALE_STEP := 0.15
const TITLES: Dictionary = {"grid": "Grid", "big": "Big tiles"}

var panel: Object = null
var list: VBoxContainer = null
var tiles: int = 0


func setup(panel_: Object, list_: VBoxContainer) -> void:
	panel = panel_
	list = list_
	tiles = 0


func deactivate() -> void:
	panel = null
	list = null
	tiles = 0


func id() -> String:
	if panel == null:
		return "grid"
	return String(panel.get("view"))


func title() -> String:
	return String(TITLES.get(id(), "Grid"))


func glyph() -> String:
	return "grid"


func base_side() -> float:
	return TILE_BIG if id() == "big" else TILE_GRID


func tile_side() -> float:
	var scale: float = 1.0
	if panel != null and panel.has_method("tile_scale"):
		scale = float(panel.call("tile_scale"))
	return round(float(Tk.px(base_side())) * scale)


func filter(defs: Array[Dictionary]) -> Array[Dictionary]:
	return defs


func doc_changed(_kind: String) -> void:
	pass


func meta() -> String:
	return str(tiles) + (" tile" if tiles == 1 else " tiles") + " at " + str(int(tile_side())) + " px"


func build(holder: VBoxContainer, secs: Array) -> void:
	if panel == null or holder == null:
		return
	list = holder
	tiles = 0
	var side: float = tile_side()
	for sec: Variant in secs:
		var section: Dictionary = sec
		var defs: Array = section["defs"]
		var fold: VBoxContainer = panel.call("section_fold", String(section["title"]), defs.size(), String(section["key"]))
		var body: VBoxContainer = fold.get("body")
		var folder_id: String = String(section.get("folder", ""))
		if not folder_id.is_empty():
			panel.call("_dress_folder", fold, folder_id)
		if defs.is_empty():
			var hint: String = String(section.get("hint", ""))
			if not hint.is_empty():
				body.add_child(panel.call("hint_row", hint))
			continue
		var flow: HFlowContainer = PmUI.flow(Tk.px(6.0), Tk.px(8.0))
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mine: bool = String(panel.get("sort_by")) == "mine"
		for d: Variant in defs:
			var tile: Control = panel.call("make_tile", d, side)
			if not folder_id.is_empty():
				tile.set_meta("folder_id", folder_id)
				panel.call("_add_row_slot", tile, folder_id)
			elif mine:
				panel.call("_add_row_slot", tile, "")
			flow.add_child(tile)
			tiles += 1
		var pad: MarginContainer = MarginContainer.new()
		pad.add_theme_constant_override("margin_left", Tk.px(6.0))
		pad.add_theme_constant_override("margin_right", Tk.px(6.0))
		pad.add_theme_constant_override("margin_bottom", Tk.px(4.0))
		pad.add_child(flow)
		body.add_child(pad)


func build_bar(tb: Container) -> void:
	if panel == null or tb == null:
		return
	var smaller: Button = PmButton.make("", "minus")
	smaller.set("quiet", true)
	smaller.set("icon_px", 14.0)
	PmUI.tip(smaller, "Smaller tiles")
	smaller.pressed.connect(_on_step.bind(-1.0))
	tb.call("add_item", smaller, "tile_smaller", "Smaller tiles")
	var bigger: Button = PmButton.make("", "plus")
	bigger.set("quiet", true)
	bigger.set("icon_px", 14.0)
	PmUI.tip(bigger, "Bigger tiles")
	bigger.pressed.connect(_on_step.bind(1.0))
	tb.call("add_item", bigger, "tile_bigger", "Bigger tiles")
	var label: Label = PmLabel.dim(str(int(tile_side())) + " px")
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb.call("add_item", label, "tile_size", "Tile size")


func _on_step(dir: float) -> void:
	if panel == null or not panel.has_method("set_tile_scale"):
		return
	panel.call("set_tile_scale", float(panel.call("tile_scale")) + dir * SCALE_STEP)
