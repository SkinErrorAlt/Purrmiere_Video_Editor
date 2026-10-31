extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const SELF_PATH := "res://modules/core_panels/palette_sheet.gd"
const RECENT_MAX := 6

static var recent_ids: PackedStringArray = PackedStringArray()

var sheet: Control = null
var field: LineEdit = null
var list: Control = null
var foot: Label = null
var results: Array[Dictionary] = []
var _row_commands: Array[Dictionary] = []


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var p: Node = script.new()
	p.call("build", host)
	return p


static func score(c: Dictionary, words: PackedStringArray, whole: String) -> int:
	var label_l: String = String(c.get("label", "")).to_lower()
	var hay: String = label_l + " " + String(c.get("category", "")).to_lower() + " " + String(c.get("id", "")).to_lower() + " " + " ".join(PackedStringArray(c.get("keys", []))).to_lower()
	for w: String in words:
		if not hay.contains(w):
			return -1
	if label_l.begins_with(whole):
		return 0
	for part: String in label_l.split(" ", false):
		if part.begins_with(words[0]):
			return 1
	if label_l.contains(words[0]):
		return 2
	return 3


static func search(commands: Array[Dictionary], query: String) -> Array[Dictionary]:
	var whole: String = query.strip_edges().to_lower()
	var words: PackedStringArray = whole.split(" ", false)
	var scored: Array[Dictionary] = []
	for c: Dictionary in commands:
		if words.is_empty():
			scored.append({"c": c, "s": 0})
			continue
		var s: int = score(c, words, whole)
		if s >= 0:
			scored.append({"c": c, "s": s})
	scored.sort_custom(_before)
	var out: Array[Dictionary] = []
	for e: Dictionary in scored:
		out.append(e["c"])
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["s"]) != int(b["s"]):
		return int(a["s"]) < int(b["s"])
	var ca: Dictionary = a["c"]
	var cb: Dictionary = b["c"]
	var cat_a: String = String(ca.get("category", ""))
	var cat_b: String = String(cb.get("category", ""))
	if cat_a != cat_b:
		return cat_a < cat_b
	return String(ca.get("label", "")).naturalnocasecmp_to(String(cb.get("label", ""))) < 0


static func remember(id: String) -> void:
	var i: int = recent_ids.find(id)
	if i >= 0:
		recent_ids.remove_at(i)
	recent_ids.insert(0, id)
	while recent_ids.size() > RECENT_MAX:
		recent_ids.remove_at(recent_ids.size() - 1)


func build(host: Node) -> void:
	name = "PaletteSheet"
	sheet = Sheet.open(host, "Command palette", 560.0, 430.0, 120.0)
	sheet.set("close_on_veil", true)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	field = PmUI.line_edit("Type a command or a category")
	field.gui_input.connect(_on_field_input)
	field.text_changed.connect(_on_text)
	col.add_child(field)
	list = SheetList.make(30.0, false, 78.0)
	list.set("empty_text", "No command matches")
	list.connect("activated", _on_activated)
	col.add_child(list)
	col.add_child(PmUI.divider())
	foot = PmLabel.faint("")
	col.add_child(foot)
	refresh()
	field.grab_focus.call_deferred()


func set_query(text: String) -> void:
	field.text = text
	refresh()


func refresh() -> void:
	var all: Array[Dictionary] = Cmd.all()
	var q: String = field.text.strip_edges()
	results = search(all, q)
	var rows: Array[Dictionary] = []
	var shown: Array[Dictionary] = []
	if q.is_empty():
		var by_id: Dictionary = {}
		for c: Dictionary in all:
			by_id[String(c["id"])] = c
		var recent_rows: Array[Dictionary] = []
		for id: String in recent_ids:
			if by_id.has(id):
				recent_rows.append(by_id[id])
		if not recent_rows.is_empty():
			rows.append({"head": true, "title": "Recently used"})
			for c: Dictionary in recent_rows:
				rows.append(_row(c))
				shown.append(c)
		var last_cat: String = ""
		for c: Dictionary in results:
			var cat: String = String(c.get("category", ""))
			if cat != last_cat:
				rows.append({"head": true, "title": cat})
				last_cat = cat
			rows.append(_row(c))
			shown.append(c)
	else:
		for c: Dictionary in results:
			rows.append(_row(c))
			shown.append(c)
	results = shown
	var index: Array[Dictionary] = []
	var k: int = 0
	for r: Dictionary in rows:
		if bool(r.get("head", false)):
			index.append({})
		else:
			index.append(shown[k])
			k += 1
	_row_commands = index
	list.call("set_rows", rows)
	var n: int = results.size()
	foot.text = (str(n) + (" command" if n == 1 else " commands")) + "    Up and Down move, Enter runs, Escape closes"


func _row(c: Dictionary) -> Dictionary:
	var keys: Array = c.get("keys", [])
	return {"lead": String(c.get("category", "")), "title": String(c.get("label", "")), "right": String(keys[0]) if not keys.is_empty() else "", "dim": not bool(c.get("enabled", true))}


func command_at(index: int) -> Dictionary:
	if index < 0 or index >= _row_commands.size():
		return {}
	return _row_commands[index]


func cursor_command() -> Dictionary:
	return command_at(int(list.get("cursor")))


func _on_text(_t: String) -> void:
	refresh()


func _on_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		field.accept_event()
		sheet.call("close")
		return
	if bool(list.call("handle_nav_key", k)):
		field.accept_event()


func _on_activated(index: int) -> void:
	var c: Dictionary = command_at(index)
	if c.is_empty():
		return
	run(String(c["id"]))


func run(id: String) -> bool:
	if not Cmd.has(id):
		return false
	if not Cmd.is_enabled(id):
		Events.toast(Cmd.label(id) + " cannot run right now")
		return false
	remember(id)
	sheet.call("close")
	Callable(Cmd, "run").call_deferred(id)
	return true
