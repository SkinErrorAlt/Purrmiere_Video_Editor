extends RefCounted

const SELF := preload("res://modules/core_panels/value_style.gd")
const SectionStyle := preload("res://modules/core_panels/section_style.gd")
const PanelPlace := preload("res://modules/core_panels/panel_place.gd")
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const Project := preload("res://doc/project.gd")
const Clip := preload("res://doc/clip.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const STYLES := "value_styles"
const ORDER := "value_order"
const OUTSIDE := "value_outside"
const SECTIONS := "styles"
const PREF_OUTSIDE := "controls.values_outside"
const MENU_COLOUR := "value_colour"
const MENU_LOOK := "value_look"
const MENU_PICK := "value_colour_pick"
const MENU_CLEAR := "value_colour_off"
const MENU_OUT := "value_take_out"
const MENU_IN := "value_put_back"
const MENU_UP := "value_move_up"
const MENU_DOWN := "value_move_down"
const META_TOKEN := "pm_value_token"
const META_SIG := "pm_value_sig"
const META_VID := "pm_value_id"
const META_UID := "pm_value_uid"
const META_KEY := "pm_value_key"
const LABEL_COUNT := 16
const DEFAULT_LOOK := "board"
const DEFAULT_STRENGTH := 0.5

static var window: Control = null
static var _pref_ready: bool = false


static func ensure_pref() -> void:
	if _pref_ready:
		return
	_pref_ready = true
	if not Prefs.is_registered(PREF_OUTSIDE):
		Prefs.register(PREF_OUTSIDE, false, {"label": "Effect Controls can take a value out of its effect", "type": "bool"})


static func outside_allowed() -> bool:
	ensure_pref()
	return bool(Prefs.get_value(PREF_OUTSIDE))


static func _dict_in(store: Dictionary, key: String) -> Dictionary:
	var v: Variant = store.get(key, null)
	return v if v is Dictionary else {}


static func _list_in(store: Dictionary, key: String) -> PackedStringArray:
	return _as_names(store.get(key, null))


static func _as_names(v: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Array = []
	if v is PackedStringArray:
		raw = Array(v as PackedStringArray)
	elif v is Array:
		raw = v
	for item: Variant in raw:
		if not (item is String):
			continue
		var name_: String = item
		if name_.is_empty() or out.has(name_):
			continue
		out.append(name_)
	return out


static func styles_in(store: Dictionary) -> Dictionary:
	return _dict_in(store, STYLES)


static func style_of(store: Dictionary, vid: String) -> Dictionary:
	var v: Variant = styles_in(store).get(vid, null)
	if not (v is Dictionary):
		return {}
	var style: Dictionary = v
	if String(style.get("look", "none")) == "none":
		return {}
	return style


static func filled(style: Dictionary) -> Dictionary:
	var out: Dictionary = {"look": DEFAULT_LOOK, "colour": "label:0", "strength": DEFAULT_STRENGTH, "pattern": "stripes"}
	for k: Variant in style.keys():
		out[k] = style[k]
	if String(out["look"]) == "none":
		out["look"] = DEFAULT_LOOK
	return out


static func tinted(style: Dictionary, colour: String) -> Dictionary:
	var out: Dictionary = filled(style)
	out["colour"] = colour
	return out


static func looked(style: Dictionary, look: String) -> Dictionary:
	var out: Dictionary = filled(style)
	out["look"] = look
	return out


static func with_style(store: Dictionary, vid: String, style: Variant) -> Dictionary:
	var all: Dictionary = styles_in(store).duplicate(true)
	var drop: bool = style == null or not (style is Dictionary)
	if not drop:
		var want: Dictionary = style
		drop = want.is_empty() or String(want.get("look", "none")) == "none"
	if drop or vid.is_empty():
		all.erase(vid)
	else:
		all[vid] = (style as Dictionary).duplicate(true)
	return {STYLES: all}


static func order_of(store: Dictionary, uid: String) -> PackedStringArray:
	return _as_names(_dict_in(store, ORDER).get(uid, null))


static func arrange(store: Dictionary, uid: String, keys: PackedStringArray) -> PackedStringArray:
	var want: PackedStringArray = order_of(store, uid)
	if want.is_empty():
		return keys
	var have: Dictionary = {}
	for k: String in keys:
		have[k] = true
	var out: PackedStringArray = PackedStringArray()
	for saved: String in want:
		if have.has(saved) and not out.has(saved):
			out.append(saved)
	for k2: String in keys:
		if not out.has(k2):
			out.append(k2)
	return out


static func with_order(store: Dictionary, uid: String, keys: PackedStringArray) -> Dictionary:
	var all: Dictionary = _dict_in(store, ORDER).duplicate(true)
	if uid.is_empty():
		return {ORDER: all}
	if keys.is_empty():
		all.erase(uid)
	else:
		all[uid] = Array(keys)
	return {ORDER: all}


static func moved(keys: PackedStringArray, key: String, gap: int) -> PackedStringArray:
	var from: int = keys.find(key)
	var to: int = EffectOps.drop_index(from, gap, keys.size())
	if to < 0:
		return PackedStringArray()
	var out: PackedStringArray = keys.duplicate()
	out.remove_at(from)
	out.insert(to, key)
	return out


static func stepped(keys: PackedStringArray, key: String, delta: int) -> PackedStringArray:
	var from: int = keys.find(key)
	var to: int = from + delta
	if from < 0 or to < 0 or to >= keys.size():
		return PackedStringArray()
	var out: PackedStringArray = keys.duplicate()
	out.remove_at(from)
	out.insert(to, key)
	return out


static func outside_of(store: Dictionary) -> PackedStringArray:
	return _list_in(store, OUTSIDE)


static func is_outside(store: Dictionary, vid: String) -> bool:
	return outside_of(store).has(vid)


static func with_outside(store: Dictionary, vid: String, out: bool) -> Dictionary:
	var all: PackedStringArray = outside_of(store)
	var at: int = all.find(vid)
	if out and at < 0 and not vid.is_empty():
		all.append(vid)
	elif not out and at >= 0:
		all.remove_at(at)
	return {OUTSIDE: Array(all)}


static func section_styles(store: Dictionary) -> Dictionary:
	return _dict_in(store, SECTIONS)


static func section_id(kind: String, n: int) -> String:
	return kind + "#" + str(n)


static func effect_style(store: Dictionary, kind: String, n: int) -> Dictionary:
	return SectionStyle.resolve(kind, n, section_styles(store))


static func shown_style(store: Dictionary, vid: String, from_effect: Dictionary) -> Dictionary:
	var own: Dictionary = style_of(store, vid)
	if not own.is_empty():
		return own
	if is_outside(store, vid):
		return from_effect
	return {}


static func store_for(d: Project, c: Clip) -> Dictionary:
	if d == null or c == null:
		return {}
	return PanelPlace.for_clip(d, PanelPlace.EC, c)


static func put_for(d: Project, c: Clip, data: Dictionary) -> bool:
	if d == null or c == null:
		return false
	return PanelPlace.put_clip(d, PanelPlace.EC, c, data)


static func store_of(panel: Object) -> Dictionary:
	if panel == null or not is_instance_valid(panel):
		return {}
	return store_for(panel.call("doc") as Project, panel.call("target_clip") as Clip)


static func put(panel: Object, data: Dictionary) -> bool:
	if panel == null or not is_instance_valid(panel):
		return false
	return put_for(panel.call("doc") as Project, panel.call("target_clip") as Clip, data)


static func adopt(hold: Control, vid: String, uid: String, key: String, token: String) -> void:
	if hold == null:
		return
	hold.set_meta(META_VID, vid)
	hold.set_meta(META_UID, uid)
	hold.set_meta(META_KEY, key)
	hold.set_meta(META_TOKEN, token)


static func paint(hold: Control, style: Dictionary) -> void:
	if hold == null or not is_instance_valid(hold):
		return
	var token: String = String(hold.get_meta(META_TOKEN, "bg_panel"))
	var base: Color = Tk.c[token] if Tk.c.has(token) else Tk.c["bg_panel"]
	var sig: String = "" if style.is_empty() else str(style) + "|" + base.to_html() + "|" + str(Tk.px(1.0))
	if String(hold.get_meta(META_SIG, "")) == sig:
		return
	hold.set_meta(META_SIG, sig)
	var box: StyleBox = null
	if not style.is_empty():
		box = SectionStyle.make_box(style, base, null)
	if box == null:
		box = StyleBoxEmpty.new()
	hold.add_theme_stylebox_override("panel", box)


static func is_painted(hold: Control) -> bool:
	return hold != null and not String(hold.get_meta(META_SIG, "")).is_empty()


static func menu_items(store: Dictionary, vid: String, movable: bool) -> Array:
	var cur: Dictionary = style_of(store, vid)
	var tints: Array = []
	for i: int in LABEL_COUNT:
		var cid: String = "label:" + str(i)
		tints.append(PmMenu.check_item(MENU_COLOUR + ":" + cid, Tk.label_name(i), String(cur.get("colour", "")) == cid))
	tints.append(PmMenu.separator())
	tints.append(PmMenu.item(MENU_PICK, "Choose a colour..."))
	var looks: Array = []
	for pair: Array in SectionStyle.LOOKS:
		var look: String = String(pair[0])
		if look == "none":
			continue
		looks.append(PmMenu.check_item(MENU_LOOK + ":" + look, String(pair[1]), String(cur.get("look", "none")) == look))
	var clear: Dictionary = PmMenu.item(MENU_CLEAR, "Clear this value's colour")
	if cur.is_empty():
		clear["disabled"] = true
	var out: Array = [PmMenu.separator(), PmMenu.sub_item(MENU_COLOUR, "Colour this value", tints), PmMenu.sub_item(MENU_LOOK, "How this value's colour looks", looks), clear]
	if movable:
		out.append(PmMenu.separator())
		out.append(PmMenu.item(MENU_UP, "Move this value up"))
		out.append(PmMenu.item(MENU_DOWN, "Move this value down"))
		if outside_allowed():
			if is_outside(store, vid):
				out.append(PmMenu.item(MENU_IN, "Put this value back in its effect"))
			else:
				out.append(PmMenu.item(MENU_OUT, "Take this value out of its effect"))
	return out


static func owns_menu(id: String) -> bool:
	if id == MENU_PICK or id == MENU_CLEAR or id == MENU_OUT or id == MENU_IN:
		return true
	if id == MENU_UP or id == MENU_DOWN:
		return true
	return id.begins_with(MENU_COLOUR + ":") or id.begins_with(MENU_LOOK + ":")


static func picked(panel: Object, id: String, vid: String, anchor: Control) -> bool:
	if not owns_menu(id) or panel == null or not is_instance_valid(panel):
		return false
	var store: Dictionary = store_of(panel)
	if id == MENU_PICK:
		open_picker(panel, vid, anchor)
		return true
	if id == MENU_OUT or id == MENU_IN:
		put(panel, with_outside(store, vid, id == MENU_OUT))
		panel.call("rebuild")
		return true
	if id == MENU_UP or id == MENU_DOWN:
		if anchor == null or not is_instance_valid(anchor):
			return true
		panel.call("step_value", String(anchor.get_meta(META_UID, "")), String(anchor.get_meta(META_KEY, "")), -1 if id == MENU_UP else 1)
		return true
	if id == MENU_CLEAR:
		put(panel, with_style(store, vid, null))
		panel.call("paint_values")
		return true
	if id.begins_with(MENU_COLOUR + ":"):
		put(panel, with_style(store, vid, tinted(style_of(store, vid), id.substr(MENU_COLOUR.length() + 1))))
		panel.call("paint_values")
		return true
	put(panel, with_style(store, vid, looked(style_of(store, vid), id.substr(MENU_LOOK.length() + 1))))
	panel.call("paint_values")
	return true


static func open_picker(panel: Object, vid: String, anchor: Control) -> Control:
	if anchor == null or not is_instance_valid(anchor):
		return null
	if window != null and is_instance_valid(window):
		window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.edit_alpha = false
	picker.color = SectionStyle.colour_of(filled(style_of(store_of(panel), vid)))
	picker.color_changed.connect(Callable(SELF, "_on_picked").bind(weakref(panel), vid))
	window = PmWindow.open(anchor, "Value colour", picker, Vector2(300.0, 420.0), "value_style.colour")
	if window != null:
		window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))
	return window


static func _on_picked(colour: Color, ref: WeakRef, vid: String) -> void:
	var panel: Variant = ref.get_ref()
	if not (panel is Object) or not is_instance_valid(panel):
		return
	var owner: Object = panel
	var store: Dictionary = store_of(owner)
	put(owner, with_style(store, vid, tinted(style_of(store, vid), "#" + colour.to_html(false))))
	owner.call("paint_values")
