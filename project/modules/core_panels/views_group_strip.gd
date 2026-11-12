extends HBoxContainer

const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PvGroups := preload("res://modules/core_panels/pv_groups.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const GROUPS_TIP := "Groups: split the views into up to four groups, each with its own view, and switch between groups"
const SWITCH_TIP := "Shows group %d from the playhead on, keeping the view it was on (%s)"
const MENU_SPLIT := "pv_strip_split"
const MENU_ADD := "pv_strip_add"
const MENU_CLEAR := "pv_strip_clear"

var clip_id: String = ""
var uid: String = ""
var _sig: String = ""
var _buttons: Array[Button] = []
var _menu_btn: Button = null
var rebuilds: int = 0


func _init() -> void:
	name = "ViewsGroups"
	add_theme_constant_override("separation", 4)
	visible = false


func targets() -> Dictionary:
	return {clip_id: uid} if not clip_id.is_empty() else {}


func show_for(s: Sequence, c: Clip, e: Dictionary) -> void:
	if s == null or c == null or e.is_empty() or not ViewMap.grouped(e) or ViewMap.members(e).size() < 2:
		clear_strip()
		return
	clip_id = c.id
	uid = String(e.get("uid", ""))
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	var names: PackedStringArray = ViewMap.region_names(e)
	var parts: PackedStringArray = PackedStringArray()
	for g: PackedInt32Array in m:
		var who: PackedStringArray = PackedStringArray()
		for r: int in g:
			who.append(names[r] if r < names.size() else "View " + str(r + 1))
		parts.append(", ".join(who))
	var sig: String = c.id + "|" + uid + "|" + "\n".join(parts)
	if sig != _sig:
		_sig = sig
		_rebuild(m.size(), parts)
	visible = true
	var lit: int = PvGroups.shown_group(s, c, e)
	for i: int in _buttons.size():
		_buttons[i].set("active", i == lit)


func clear_strip() -> void:
	visible = false
	clip_id = ""
	uid = ""


func buttons() -> Array[Button]:
	return _buttons


func _rebuild(count: int, parts: PackedStringArray) -> void:
	rebuilds += 1
	for ch: Node in get_children():
		remove_child(ch)
		ch.queue_free()
	_buttons.clear()
	add_child(PmLabel.dim("Groups"))
	for g: int in count:
		var b: Button = PmButton.make("Group " + str(g + 1), "")
		b.set("quiet", true)
		b.name = "ViewsGroup" + str(g)
		PmUI.tip(b, SWITCH_TIP % [g + 1, parts[g] if g < parts.size() else ""])
		b.pressed.connect(_on_group.bind(g))
		add_child(b)
		_buttons.append(b)
	add_child(PmUI.spacer())
	_menu_btn = PmButton.make("", "chev_d")
	_menu_btn.set("quiet", true)
	_menu_btn.name = "ViewsGroupsMenu"
	PmUI.tip(_menu_btn, GROUPS_TIP)
	_menu_btn.pressed.connect(_on_menu)
	add_child(_menu_btn)


func _on_group(g: int) -> void:
	PvGroups.switch_group(targets(), g)


func menu_items() -> Array:
	var items: Array = []
	items.append(PmMenu.item(MENU_ADD, "Add a group", "", "plus"))
	if _buttons.size() >= ViewMap.GROUP_MAX:
		(items[0] as Dictionary)["disabled"] = true
	items.append(PmMenu.item(MENU_CLEAR, "One group"))
	return items


func menu_picked(id: String) -> void:
	if id == MENU_ADD:
		PvGroups.add_group(targets())
	elif id == MENU_CLEAR:
		PvGroups.set_groups(targets(), "clear")


func _on_menu() -> void:
	var m: Control = PmMenu.open(_menu_btn, menu_items(), _menu_btn.global_position + Vector2(0.0, _menu_btn.size.y))
	if m != null:
		m.connect("picked", menu_picked)


const MORE_SPLIT_PREFIX := "pv_strip_split:"


static func more_items(c: Clip, e: Dictionary) -> Array:
	var items: Array = []
	if c == null or e.is_empty():
		return items
	var count: int = ViewMap.crop_count(e)
	if count < 2:
		return items
	var sub: Array = []
	for parts: int in range(2, mini(ViewMap.GROUP_MAX, count) + 1):
		sub.append(PmMenu.item(MORE_SPLIT_PREFIX + str(parts), PvGroups.COUNT_WORDS[parts].capitalize() + " groups"))
	if ViewMap.grouped(e):
		sub.append(PmMenu.separator())
		sub.append(PmMenu.item(MORE_SPLIT_PREFIX + "0", "One group"))
	items.append(PmMenu.sub_item(MENU_SPLIT, "Split the views into groups", sub))
	return items


static func more_picked(id: String, clip_id_: String, uid_: String) -> bool:
	if not id.begins_with(MORE_SPLIT_PREFIX):
		return false
	var parts: int = int(id.substr(MORE_SPLIT_PREFIX.length()))
	PvGroups.set_groups({clip_id_: uid_}, "clear" if parts < 2 else "split" + str(parts))
	return true
