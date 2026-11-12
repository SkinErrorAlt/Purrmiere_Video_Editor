extends RefCounted

const SELF := preload("res://modules/core_panels/ec_fx_pick.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Presets := preload("res://doc/presets.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const MANY := "many"
const META := "fx_pick_key"
const MENU_SAVE := "fx_save_picked"
const MENU_GROUP := "fx_group_picked"
const PICK_TIP := "Ctrl click or Shift click more effects to pick several, then right click to save them as one preset"

static var scope: String = ""
static var sound: bool = false
static var keys: PackedStringArray = PackedStringArray()
static var owners: Dictionary = {}
static var _headers: Array = []
static var _known: Dictionary = {}
static var _order: Dictionary = {}
static var last_saved: Dictionary = {}


static func many_key(uids: Dictionary) -> String:
	return String(uids.values()[0]) if not uids.is_empty() else ""


static func clear() -> void:
	scope = ""
	keys = PackedStringArray()
	owners = {}
	repaint()


static func picked(in_scope: String) -> PackedStringArray:
	return keys if in_scope == scope else PackedStringArray()


static func is_picked(in_scope: String, key: String) -> bool:
	return in_scope == scope and keys.has(key)


static func click(in_scope: String, key: String, is_sound: bool, owner: Variant, ctrl: bool, shift: bool, order: PackedStringArray) -> void:
	var same: bool = in_scope == scope and is_sound == sound
	if not same or not (ctrl or shift):
		scope = in_scope
		sound = is_sound
		keys = PackedStringArray([key])
		owners = {key: owner}
		repaint()
		return
	if order.is_empty():
		order = _order.get(in_scope, PackedStringArray())
	if shift and not keys.is_empty():
		var a: int = order.find(keys[keys.size() - 1])
		var b: int = order.find(key)
		if a >= 0 and b >= 0:
			for i: int in range(mini(a, b), maxi(a, b) + 1):
				if not keys.has(order[i]):
					keys.append(order[i])
					owners[order[i]] = owner if order[i] == key else _known.get(in_scope + "|" + order[i], null)
			repaint()
			return
	var at: int = keys.find(key)
	if at >= 0 and ctrl:
		keys.remove_at(at)
		owners.erase(key)
	elif at < 0:
		keys.append(key)
		owners[key] = owner
	repaint()


static func register(header: Control, in_scope: String, key: String, is_sound: bool, owner: Variant = null) -> void:
	header.set_meta(META, [in_scope, key, is_sound])
	_known[in_scope + "|" + key] = owner
	var list: PackedStringArray = _order.get(in_scope, PackedStringArray())
	if not list.has(key):
		list.append(key)
	_order[in_scope] = list
	if _known.size() > 512:
		_known.clear()
		_order.clear()
	if owner != null and is_picked(in_scope, key):
		owners[key] = owner
	if _headers.size() > 256:
		var keep: Array = []
		for w: Variant in _headers:
			var n: Object = (w as WeakRef).get_ref()
			if n != null and is_instance_valid(n):
				keep.append(w)
		_headers = keep
	_headers.append(weakref(header))
	if keys.size() > 1:
		_mark(header)
	if not header.tooltip_text.contains(PICK_TIP):
		header.tooltip_text = (header.tooltip_text + "\n" if not header.tooltip_text.is_empty() else "") + PICK_TIP


static func repaint() -> void:
	for w: Variant in _headers:
		var n: Object = (w as WeakRef).get_ref()
		if n != null and is_instance_valid(n) and n is Control:
			_mark(n as Control)


static func _mark(header: Control) -> void:
	var m: Variant = header.get_meta(META, [])
	var on: bool = m is Array and (m as Array).size() == 3 and is_picked(String(m[0]), String(m[1])) and bool(m[2]) == sound and keys.size() > 1
	if on:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(Tk.c["text_bright"], 0.14)
		sb.border_color = Color(Tk.c["text_bright"], 0.55)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		for st: String in ["normal", "hover", "pressed", "focus"]:
			header.add_theme_stylebox_override(st, sb)
	else:
		for st2: String in ["normal", "hover", "pressed", "focus"]:
			if header.has_theme_stylebox_override(st2):
				header.remove_theme_stylebox_override(st2)


static func handle_press(event: InputEvent, header: Control, in_scope: String, key: String, is_sound: bool, owner: Variant, order: PackedStringArray) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or mb.double_click:
		return false
	var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
	click(in_scope, key, is_sound, owner, ctrl, mb.shift_pressed, order)
	if ctrl or mb.shift_pressed:
		header.accept_event()
		return true
	return false


static func menu_items(in_scope: String, key: String) -> Array:
	var list: PackedStringArray = picked(in_scope)
	if list.size() < 2 or not list.has(key):
		return []
	var out: Array = [PmMenu.item(MENU_SAVE, "Save the " + str(list.size()) + " picked effects as one preset")]
	if in_scope != MANY:
		out.append(PmMenu.item(MENU_GROUP, "Group the " + str(list.size()) + " picked effects"))
	out.append(PmMenu.separator())
	return out


static func entries(s: Sequence, in_scope: String) -> Array:
	var rows: Array = []
	for key: String in picked(in_scope):
		var c: Clip = null
		var uid: String = key
		var owner: Variant = owners.get(key, null)
		if in_scope == MANY and owner is Dictionary:
			for cid: Variant in (owner as Dictionary).keys():
				var fc: Clip = s.clip_by_id(String(cid)) if s != null else null
				if fc != null:
					c = fc
					uid = String((owner as Dictionary)[cid])
					break
		elif s != null:
			c = s.clip_by_id(in_scope)
		if c == null:
			continue
		var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
		if e.is_empty():
			continue
		rows.append([EffectOps.stack_index(c, uid, sound), e])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var out: Array = []
	for r: Array in rows:
		var ed: Dictionary = (r[1] as Dictionary).duplicate(true)
		ed.erase("uid")
		out.append(ed)
	return out


static func preset_for(s: Sequence, in_scope: String, label: String) -> Dictionary:
	var list: Array = entries(s, in_scope)
	if list.is_empty():
		return {}
	if sound:
		return Presets.make("audio_fx", label, {"audio_effects": list})
	return Presets.make("effect_stack", label, {"effects": list})


static func default_name(s: Sequence, in_scope: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for e: Variant in entries(s, in_scope):
		names.append(String(EffectSource.get_def(String((e as Dictionary).get("id", ""))).get("label", (e as Dictionary).get("id", ""))))
	if names.size() <= 3:
		return " + ".join(names)
	return names[0] + " + " + str(names.size() - 1) + " more"


static func save(d: Project, s: Sequence, in_scope: String, label: String, to_library: bool) -> bool:
	var preset: Dictionary = preset_for(s, in_scope, label)
	if preset.is_empty():
		return false
	var ok: bool = Presets.save_to_user(preset) if to_library else Presets.save_to_project(d, preset)
	if ok:
		last_saved = preset
		var where: String = "your preset library" if to_library else "this project's presets"
		Events.notice("Preset saved", label + " is in " + where + ", with " + str(entries(s, in_scope).size()) + " effects in their order.")
	return ok


static func open_save(panel: Object, in_scope: String) -> void:
	var s: Sequence = panel.call("seq")
	var count: int = entries(s, in_scope).size()
	if count < 2:
		Events.toast("Pick two or more effects first")
		return
	var fields: Array[Dictionary] = [
		{"key": "name", "label": "Preset name", "type": "string", "default": default_name(s, in_scope)},
		{"key": "to_library", "label": "Keep it for every project", "type": "bool", "default": false},
		{"key": "note", "label": "", "type": "note", "default": "Saves the " + str(count) + " picked effects with their values and keyframes, in the order they run."},
	]
	var answered: Signal = PmUI.form(panel.call("root"), "Save effects as one preset", fields, "Save", "Cancel")
	answered.connect(Callable(SELF, "_on_save_answered").bind(panel, in_scope))


static func _on_save_answered(result: Variant, panel: Object, in_scope: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var s: Sequence = panel.call("seq")
	var name_: String = String((result as Dictionary).get("name", "")).strip_edges()
	if name_.is_empty():
		name_ = default_name(s, in_scope)
	save(panel.call("doc"), s, in_scope, name_, bool((result as Dictionary).get("to_library", false)))


static func order_of(c: Clip, is_sound: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if c == null:
		return out
	for e: Variant in (c.audio_effects() if is_sound else c.effects):
		if e is Dictionary:
			out.append(String((e as Dictionary).get("uid", "")))
	return out
