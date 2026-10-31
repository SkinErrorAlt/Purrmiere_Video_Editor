extends RefCounted

const SELF := preload("res://modules/core_panels/section_style.gd")
const PanelPlace := preload("res://modules/core_panels/panel_place.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const PREF := "ui.fold.styles"
const MENU_STYLE := "section_style"
const MENU_CLEAR := "section_style_clear"
const LOOKS: Array = [["none", "None"], ["board", "Board"], ["shade", "Shade"], ["outline", "Outline"], ["pattern", "Pattern"]]
const PATTERNS: Array = [["stripes", "Stripes"], ["dots", "Dots"], ["grid", "Grid"], ["edge", "Soft edge"]]
const TEXT_RATIO := 4.5
const DIM_RATIO := 4.0
const FLUSH_S := 0.6
const CACHE_MAX := 48
const META_HOLDER := "pm_style_holder"
const META_SIG := "pm_style_sig"
const META_BASE := "pm_style_base"
const META_TOKEN := "pm_style_token"
const META_N := "pm_style_n"
const META_REPAINT := "pm_style_repaint"
const LABEL_COUNT := 16
const NOTE := "The words stay readable in the light and dark themes: a strong colour is toned down behind text."

static var _kinds: Dictionary = {}
static var _loaded: bool = false
static var _armed: bool = false
static var _dirty: bool = false
static var _tex: Dictionary = {}
static var paints: int = 0
static var window: Control = null


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not Prefs.is_registered(PREF):
		Prefs.register(PREF, {}, {"label": "Section styles", "type": "dict"})
	var v: Variant = Prefs.get_value(PREF)
	_kinds = (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func reload() -> void:
	_loaded = false
	_load()


static func kind_style(kind: String) -> Dictionary:
	_load()
	var v: Variant = _kinds.get(kind, null)
	return v if v is Dictionary else {}


static func set_kind_style(kind: String, style: Dictionary) -> void:
	_load()
	if style.is_empty() or String(style.get("look", "none")) == "none":
		_kinds.erase(kind)
	else:
		_kinds[kind] = style.duplicate(true)
	_dirty = true
	if _armed:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		flush()
		return
	_armed = true
	tree.create_timer(FLUSH_S).timeout.connect(func() -> void: SELF.flush())


static func flush() -> void:
	_armed = false
	if not _dirty:
		return
	_dirty = false
	Prefs.set_value(PREF, _kinds.duplicate(true))


static func resolve(kind: String, n: int, overrides: Dictionary) -> Dictionary:
	var id: String = kind + "#" + str(n)
	if overrides.has(id) and overrides[id] is Dictionary:
		var o: Dictionary = overrides[id]
		return {} if String(o.get("look", "none")) == "none" else o
	return kind_style(kind)


static func colour_of(style: Dictionary) -> Color:
	var c: String = String(style.get("colour", "label:0"))
	if c.begins_with("label:"):
		return Tk.label_colour(int(c.substr(6)))
	if c.begins_with("#") and c.is_valid_html_color():
		return Color.html(c)
	return Tk.label_colour(0)


static func luminance(c: Color) -> float:
	var out: float = 0.0
	var w: Array[float] = [0.2126, 0.7152, 0.0722]
	var ch: Array[float] = [c.r, c.g, c.b]
	for i: int in 3:
		var v: float = ch[i]
		v = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
		out += v * w[i]
	return out


static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func readable(base: Color, tint: Color, amount: float) -> float:
	var a: float = clampf(amount, 0.0, 1.0)
	var text: Color = Tk.c["text"]
	var dim: Color = Tk.c["text_dim"]
	var floor_text: float = minf(TEXT_RATIO, contrast(text, base))
	var floor_dim: float = minf(DIM_RATIO, contrast(dim, base))
	while a > 0.0:
		var mix: Color = base.lerp(tint, a)
		if contrast(text, mix) >= floor_text - 0.001 and contrast(dim, mix) >= floor_dim - 0.001:
			return a
		a -= 0.02
	return 0.0


static func _base_colour(holder: Control) -> Color:
	var token: String = String(holder.get_meta(META_TOKEN, "bg_panel"))
	return Tk.c[token] if Tk.c.has(token) else Tk.c["bg_panel"]


static func make_box(style: Dictionary, base: Color, base_box: StyleBox) -> StyleBox:
	var look: String = String(style.get("look", "none"))
	var s: float = clampf(float(style.get("strength", 0.5)), 0.0, 1.0)
	var tint: Color = colour_of(style)
	var box: StyleBox = null
	if look == "board":
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = base.lerp(tint, readable(base, tint, 0.10 + 0.40 * s))
		box = flat
	elif look == "outline":
		var ol: StyleBoxFlat = StyleBoxFlat.new()
		ol.bg_color = base if base_box is StyleBoxFlat else Color(base, 0.0)
		ol.draw_center = base_box is StyleBoxFlat
		var w: int = maxi(1, Tk.px(1.0 + roundf(2.0 * s)))
		ol.set_border_width_all(w)
		ol.border_color = Color(tint, 0.55 + 0.45 * s)
		box = ol
	elif look == "shade":
		box = _gradient_box(base, tint, readable(base, tint, 0.15 + 0.45 * s), 0.75)
	elif look == "pattern":
		var pat: String = String(style.get("pattern", "stripes"))
		if pat == "edge":
			box = _gradient_box(base, tint, readable(base, tint, 0.25 + 0.55 * s), 0.14)
		else:
			box = _pattern_box(pat, base, base.lerp(tint, readable(base, tint, 0.12 + 0.43 * s)), base_box is StyleBoxFlat)
	if box == null:
		return base_box
	if base_box != null:
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_content_margin(side, base_box.get_content_margin(side))
	return box


static func _gradient_box(base: Color, tint: Color, a: float, reach: float) -> StyleBox:
	var key: String = "g|" + base.to_html() + "|" + tint.to_html() + "|" + str(snappedf(a, 0.01)) + "|" + str(reach)
	var tex: Texture2D = _tex.get(key, null)
	if tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, base.lerp(tint, a))
		g.set_offset(0, 0.0)
		g.set_color(1, base)
		g.set_offset(1, 1.0)
		g.add_point(reach, base)
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.width = 256
		gt.height = 4
		gt.fill_from = Vector2(0.0, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		tex = gt
		_keep(key, tex)
	var st: StyleBoxTexture = StyleBoxTexture.new()
	st.texture = tex
	return st


static func _pattern_box(pat: String, base: Color, ink: Color, opaque: bool) -> StyleBox:
	var cell: int = maxi(4, Tk.px(11.0 if pat == "stripes" else (9.0 if pat == "dots" else 12.0)))
	var key: String = "p|" + pat + "|" + base.to_html() + "|" + ink.to_html() + "|" + str(cell) + "|" + str(opaque)
	var tex: Texture2D = _tex.get(key, null)
	if tex == null:
		var img: Image = Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		var ground: Color = base if opaque else Color(base, 0.0)
		img.fill(ground)
		var r: float = maxf(1.2, float(cell) * 0.16)
		var half: float = float(cell) * 0.5
		for y: int in cell:
			for x: int in cell:
				var on: float = 0.0
				if pat == "stripes":
					on = 1.0 if (x + y) % cell < int(float(cell) * 0.45) else 0.0
				elif pat == "dots":
					var dist: float = Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length()
					on = clampf(r + 0.5 - dist, 0.0, 1.0)
				else:
					on = 1.0 if x == 0 or y == 0 else 0.0
				if on > 0.0:
					img.set_pixel(x, y, ground.lerp(Color(ink, 1.0), on) if opaque else Color(ink, on))
		tex = ImageTexture.create_from_image(img)
		_keep(key, tex)
	var st: StyleBoxTexture = StyleBoxTexture.new()
	st.texture = tex
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return st


static func _keep(key: String, tex: Texture2D) -> void:
	if _tex.size() >= CACHE_MAX:
		_tex.erase(_tex.keys()[0])
	_tex[key] = tex


static func paint(holder: Control, style: Dictionary) -> void:
	if holder == null or not holder.has_meta(META_HOLDER):
		return
	var base: Color = _base_colour(holder)
	var sig: String = "" if style.is_empty() else str(style) + "|" + base.to_html() + "|" + str(Tk.px(1.0)) + "|" + str(Tk.c["text"].to_html())
	if String(holder.get_meta(META_SIG, "")) == sig:
		return
	holder.set_meta(META_SIG, sig)
	paints += 1
	var base_box: StyleBox = holder.get_meta(META_BASE, null) as StyleBox
	var box: StyleBox = base_box if style.is_empty() else make_box(style, base, base_box)
	if box == null:
		holder.remove_theme_stylebox_override("panel")
	else:
		holder.add_theme_stylebox_override("panel", box)


static func is_styled(holder: Control) -> bool:
	return holder != null and not String(holder.get_meta(META_SIG, "")).is_empty()


static func attach(fold: Control, holder: Control, owner: Object) -> void:
	if fold == null or holder == null:
		return
	holder.set_meta(META_HOLDER, true)
	var sb: StyleBox = holder.get_theme_stylebox("panel")
	var own: bool = holder.has_theme_stylebox_override("panel")
	holder.set_meta(META_BASE, sb if own else null)
	var token: String = "bg_panel"
	if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.is_equal_approx(Tk.c["bg_panel_alt"]):
		token = "bg_panel_alt"
	holder.set_meta(META_TOKEN, token)
	holder.set_meta(META_N, 0)
	if owner != null:
		holder.set_meta(META_REPAINT, Callable(SELF, "repaint_owner").bind(weakref(owner)))
	var header: Control = fold.get("header")
	if header != null:
		header.gui_input.connect(Callable(SELF, "_on_header_input").bind(weakref(holder)))
	paint(holder, kind_style(String(fold.get("key"))))


static func wrap(fold: Control, owner: Object) -> PanelContainer:
	var holder: PanelContainer = PanelContainer.new()
	var sb: StyleBoxEmpty = StyleBoxEmpty.new()
	holder.add_theme_stylebox_override("panel", sb)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(fold)
	attach(fold, holder, owner)
	return holder


static func repaint_owner(ref: WeakRef) -> void:
	var owner: Variant = ref.get_ref()
	if not (owner is Object) or not is_instance_valid(owner):
		return
	var list: Variant = (owner as Object).get("_list")
	if not (list is Control):
		return
	var overrides: Dictionary = PanelPlace.ec_styles(owner) if (owner as Object).get("_scroll") != null else {}
	paint_list(list, overrides)
	if (owner as Object).has_method("paint_values"):
		(owner as Object).call("paint_values")


static func paint_list(list: Control, overrides: Dictionary) -> void:
	if list == null:
		return
	var seen: Dictionary = {}
	for holder: Node in list.get_children():
		if not (holder is Control) or not holder.has_meta(META_HOLDER) or not (holder as Control).visible:
			continue
		var f: Control = PanelPlace.fold_of(holder)
		if f == null:
			continue
		var kind: String = String(f.get("key"))
		var n: int = int(seen.get(kind, 0))
		seen[kind] = n + 1
		holder.set_meta(META_N, n)
		paint(holder, resolve(kind, n, overrides))


static func _holder_for_uid(panel: Object, uid: String) -> Control:
	var list: Variant = panel.get("_list")
	if not (list is Control):
		return null
	for holder: Node in (list as Control).get_children():
		if not holder.has_meta(META_HOLDER):
			continue
		var f: Control = PanelPlace.fold_of(holder)
		if f == null:
			continue
		var header: Control = f.get("header")
		if header != null and String(header.get_meta("uid", "")) == uid:
			return holder as Control
	return null


static func menu_items(panel: Object, uid: String) -> Array:
	var holder: Control = _holder_for_uid(panel, uid)
	var clear: Dictionary = PmMenu.item(MENU_CLEAR, "Clear this section's style")
	if not is_styled(holder):
		clear["disabled"] = true
	return [PmMenu.separator(), PmMenu.item(MENU_STYLE, "Style this section..."), clear]


static func menu_picked(panel: Object, id: String, uid: String) -> bool:
	if id != MENU_STYLE and id != MENU_CLEAR:
		return false
	var holder: Control = _holder_for_uid(panel, uid)
	if holder == null:
		return true
	_picked(id, weakref(holder))
	return true


static func _on_header_input(event: InputEvent, ref: WeakRef) -> void:
	var holder: Variant = ref.get_ref()
	if not (holder is Control) or not is_instance_valid(holder):
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	var f: Control = PanelPlace.fold_of(holder)
	if f == null:
		return
	var header: Control = f.get("header")
	if header == null or header.has_meta("uid"):
		return
	header.accept_event()
	open_menu(holder, header.get_global_mouse_position())


static func open_menu(holder: Control, at: Vector2) -> Control:
	var clear: Dictionary = PmMenu.item(MENU_CLEAR, "Clear this section's style")
	if not is_styled(holder):
		clear["disabled"] = true
	var m: Control = PmMenu.open(holder, [PmMenu.item(MENU_STYLE, "Style this section..."), clear], at)
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(SELF, "_picked").bind(weakref(holder)))
	return m


static func _picked(id: String, ref: WeakRef) -> void:
	var holder: Variant = ref.get_ref()
	if not (holder is Control) or not is_instance_valid(holder):
		return
	if id == MENU_STYLE:
		open_window(holder)
	elif id == MENU_CLEAR:
		clear_style(holder)


static func _owner_of(holder: Control) -> Object:
	var cb: Variant = holder.get_meta(META_REPAINT, null)
	if cb is Callable:
		var args: Array = (cb as Callable).get_bound_arguments()
		if not args.is_empty() and args[0] is WeakRef:
			var o: Variant = (args[0] as WeakRef).get_ref()
			return o as Object
	return null


static func _repaint(holder: Control) -> void:
	var cb: Variant = holder.get_meta(META_REPAINT, null)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	else:
		var f: Control = PanelPlace.fold_of(holder)
		if f != null:
			paint(holder, kind_style(String(f.get("key"))))


static func section_id(holder: Control) -> String:
	var f: Control = PanelPlace.fold_of(holder)
	if f == null:
		return ""
	return String(f.get("key")) + "#" + str(int(holder.get_meta(META_N, 0)))


static func clip_override(holder: Control) -> Dictionary:
	var owner: Object = _owner_of(holder)
	if owner == null or owner.get("_scroll") == null:
		return {}
	var v: Variant = PanelPlace.ec_styles(owner).get(section_id(holder), null)
	return v if v is Dictionary else {}


static func can_style_clip(holder: Control) -> bool:
	var owner: Object = _owner_of(holder)
	return owner != null and owner.get("_scroll") != null and PanelPlace.ec_clip(owner) != null


static func clear_style(holder: Control) -> void:
	var f: Control = PanelPlace.fold_of(holder)
	if f == null:
		return
	var owner: Object = _owner_of(holder)
	if not clip_override(holder).is_empty() and owner != null:
		PanelPlace.set_clip_style(owner, section_id(holder), null)
		_repaint(holder)
	if is_styled(holder) or not kind_style(String(f.get("key"))).is_empty():
		set_kind_style(String(f.get("key")), {})
	_repaint(holder)


static func apply(holder: Control, style: Dictionary, only_clip: bool) -> void:
	var f: Control = PanelPlace.fold_of(holder)
	if f == null:
		return
	var owner: Object = _owner_of(holder)
	if only_clip and owner != null and can_style_clip(holder):
		PanelPlace.set_clip_style(owner, section_id(holder), style.duplicate(true))
	else:
		if owner != null and can_style_clip(holder) and not clip_override(holder).is_empty():
			PanelPlace.set_clip_style(owner, section_id(holder), null)
		set_kind_style(String(f.get("key")), style)
	_repaint(holder)


static func open_window(holder: Control) -> Control:
	var f: Control = PanelPlace.fold_of(holder)
	if f == null:
		return null
	if window != null and is_instance_valid(window):
		window.call("close")
	var ed: _Editor = _Editor.new()
	ed.setup(holder)
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override("margin_left", Tk.px(10.0))
	box.add_theme_constant_override("margin_right", Tk.px(10.0))
	box.add_theme_constant_override("margin_top", Tk.px(6.0))
	box.add_theme_constant_override("margin_bottom", Tk.px(10.0))
	box.add_child(ed)
	var name_: String = String(f.get("title"))
	window = PmWindow.open(holder, "Style: " + name_, box, Vector2(float(Tk.px(340.0)), float(Tk.px(440.0))), "section_style")
	if window != null:
		var header: Control = f.get("header")
		var at: Vector2 = header.global_position + Vector2(0.0, header.size.y) if header != null else holder.global_position
		window.call("place_at", at)
		var tree: SceneTree = window.get_tree()
		if tree != null:
			tree.create_timer(Tk.dur("medium") + 0.03).timeout.connect(Callable(SELF, "_place_again").bind(weakref(window), at))
	return window


static func _place_again(ref: WeakRef, at: Vector2) -> void:
	var w: Variant = ref.get_ref()
	if w is Control and is_instance_valid(w):
		fit_window(w as Control)
		(w as Control).call("place_at", at)


static func fit_window(w: Control) -> void:
	var body: Variant = w.get("body")
	if not (body is Control):
		return
	var content: Control = body as Control
	for ch: Node in content.get_children():
		if ch is MarginContainer:
			content = ch as Control
	var need: float = content.get_combined_minimum_size().y + float(Tk.px(40.0))
	if absf(w.size.y - need) > 1.0:
		w.size.y = need


class _Editor:
	extends VBoxContainer

	var holder: Control = null
	var style: Dictionary = {}
	var only_clip: bool = false
	var look_btns: Dictionary = {}
	var look_previews: Dictionary = {}
	var pattern_btns: Dictionary = {}
	var swatches: Dictionary = {}
	var pattern_row: Control = null
	var strength: Control = null
	var scope_kind: CheckBox = null
	var scope_clip: CheckBox = null
	var picker_window: Control = null

	func setup(h: Control) -> void:
		holder = h
		var over: Dictionary = SELF.clip_override(h)
		only_clip = not over.is_empty()
		var f: Control = SELF.PanelPlace.fold_of(h)
		var kind: String = String(f.get("key"))
		var cur: Dictionary = over if only_clip else SELF.kind_style(kind)
		style = {"look": "none", "colour": "label:0", "strength": 0.5, "pattern": "stripes"}
		for k: Variant in cur.keys():
			style[k] = cur[k]
		add_theme_constant_override("separation", Tk.px(6.0))
		var title: String = String(f.get("title"))
		add_child(SELF.PmLabel.meta("Look"))
		var looks: HFlowContainer = SELF.PmUI.flow(Tk.px(2.0), Tk.px(2.0))
		for pair: Array in SELF.LOOKS:
			looks.add_child(_tile(String(pair[0]), String(pair[1])))
		add_child(looks)
		pattern_row = SELF.PmUI.vbox(Tk.px(4.0))
		pattern_row.add_child(SELF.PmLabel.meta("Pattern"))
		var pats: HFlowContainer = SELF.PmUI.flow()
		for pair2: Array in SELF.PATTERNS:
			var pb: Button = SELF.PmButton.make(String(pair2[1]), "", true)
			pb.set("quiet", true)
			pb.pressed.connect(_on_pattern.bind(String(pair2[0])))
			pats.add_child(pb)
			pattern_btns[String(pair2[0])] = pb
		pattern_row.add_child(pats)
		add_child(pattern_row)
		add_child(SELF.PmLabel.meta("Colour"))
		var sw_row: HFlowContainer = SELF.PmUI.flow(Tk.px(5.0), Tk.px(5.0))
		for i: int in SELF.LABEL_COUNT:
			var sw: Button = _swatch("label:" + str(i), Tk.label_colour(i), Tk.label_name(i))
			sw_row.add_child(sw)
		var choose: Button = SELF.PmButton.make("Choose...")
		choose.pressed.connect(_on_choose.bind(choose))
		sw_row.add_child(choose)
		add_child(sw_row)
		var srow: HBoxContainer = SELF.PmUI.hbox()
		var sl: Label = SELF.PmLabel.trim("Strength")
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(sl)
		strength = SELF.PmField.make(roundf(float(style.get("strength", 0.5)) * 100.0), 0.0, 100.0, 1.0, " %")
		strength.custom_minimum_size = Vector2(float(Tk.px(80.0)), float(Tk.px(24.0)))
		strength.connect("value_changed", _on_strength)
		srow.add_child(strength)
		add_child(srow)
		if SELF.can_style_clip(h):
			add_child(SELF.PmLabel.meta("Show it on"))
			var group: ButtonGroup = ButtonGroup.new()
			scope_kind = CheckBox.new()
			scope_kind.text = "Every " + title + " section"
			scope_kind.button_group = group
			scope_kind.pressed.connect(_on_scope.bind(false))
			add_child(scope_kind)
			scope_clip = CheckBox.new()
			scope_clip.text = "Only this clip's " + title
			scope_clip.button_group = group
			scope_clip.pressed.connect(_on_scope.bind(true))
			add_child(scope_clip)
		var note: Label = SELF.PmLabel.wrap(SELF.NOTE, "text_dim")
		add_child(note)
		var foot: HBoxContainer = SELF.PmUI.hbox()
		var clear: Button = SELF.PmButton.ghost("Clear style")
		clear.pressed.connect(_on_clear)
		foot.add_child(clear)
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap)
		var done: Button = SELF.PmButton.primary("Done")
		done.pressed.connect(_on_done)
		foot.add_child(done)
		add_child(foot)
		_sync()

	func _tile(id: String, label: String) -> Control:
		var col: VBoxContainer = SELF.PmUI.vbox(Tk.px(3.0))
		col.custom_minimum_size.x = float(Tk.px(58.0))
		var pv: Panel = Panel.new()
		pv.name = "Preview"
		pv.mouse_filter = Control.MOUSE_FILTER_STOP
		pv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pv.custom_minimum_size = Vector2(float(Tk.px(46.0)), float(Tk.px(26.0)))
		pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pv.gui_input.connect(_on_tile_input.bind(id))
		SELF.PmUI.tip(pv, label)
		col.add_child(pv)
		var b: Button = SELF.PmButton.make(label, "", true)
		b.set("quiet", true)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_on_look.bind(id))
		col.add_child(b)
		look_btns[id] = b
		look_previews[id] = pv
		return col

	func _on_tile_input(event: InputEvent, id: String) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_look(id)

	func _swatch(id: String, colour: Color, tip: String) -> Button:
		var b: Button = SELF.PmButton.make("", "", true)
		b.set("quiet", true)
		b.custom_minimum_size = Vector2(float(Tk.px(24.0)), float(Tk.px(24.0)))
		SELF.PmUI.tip(b, tip)
		var chip: ColorRect = ColorRect.new()
		chip.color = colour
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inset: float = float(Tk.px(4.0))
		chip.offset_left = inset
		chip.offset_top = inset
		chip.offset_right = -inset
		chip.offset_bottom = -inset
		b.add_child(chip)
		b.pressed.connect(_on_colour.bind(id))
		swatches[id] = b
		return b

	func _preview_box(look: String) -> StyleBox:
		var base: Color = SELF._base_colour(holder)
		var st: Dictionary = style.duplicate(true)
		st["look"] = look
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = base
		flat.border_color = Tk.c["border_soft"]
		flat.set_border_width_all(1)
		if look == "none":
			return flat
		return SELF.make_box(st, base, flat)

	func _sync() -> void:
		var look: String = String(style.get("look", "none"))
		for id: String in look_btns.keys():
			(look_btns[id] as Button).button_pressed = id == look
			(look_previews[id] as Panel).add_theme_stylebox_override("panel", _preview_box(id))
		pattern_row.visible = look == "pattern"
		for pid: String in pattern_btns.keys():
			(pattern_btns[pid] as Button).button_pressed = pid == String(style.get("pattern", "stripes"))
		for sid: String in swatches.keys():
			(swatches[sid] as Button).button_pressed = sid == String(style.get("colour", ""))
		if scope_kind != null:
			scope_kind.button_pressed = not only_clip
			scope_clip.button_pressed = only_clip
		_refit.call_deferred()

	func _refit() -> void:
		var w: Node = get_parent()
		while w != null and not w.has_method("place_at"):
			w = w.get_parent()
		if w is Control:
			SELF.fit_window(w as Control)

	func _commit() -> void:
		if holder == null or not is_instance_valid(holder):
			return
		SELF.apply(holder, style, only_clip)
		_sync()

	func _on_look(id: String) -> void:
		style["look"] = id
		_commit()

	func _on_pattern(id: String) -> void:
		style["pattern"] = id
		_commit()

	func _on_colour(id: String) -> void:
		style["colour"] = id
		if String(style.get("look", "none")) == "none":
			style["look"] = "board"
		_commit()

	func _on_strength(v: float) -> void:
		style["strength"] = clampf(v / 100.0, 0.0, 1.0)
		_commit()

	func _on_scope(clip: bool) -> void:
		if clip == only_clip:
			_sync()
			return
		if not clip and holder != null:
			SELF.PanelPlace.set_clip_style(SELF._owner_of(holder), SELF.section_id(holder), null)
		only_clip = clip
		_commit()

	func _on_choose(anchor: Control) -> void:
		if picker_window != null and is_instance_valid(picker_window):
			picker_window.call("close")
		var picker: ColorPicker = ColorPicker.new()
		picker.edit_alpha = false
		picker.color = SELF.colour_of(style)
		picker.color_changed.connect(_on_picked)
		picker_window = SELF.PmWindow.open(self, "Section colour", picker, Vector2(300.0, 420.0), "section_style.colour")
		if picker_window != null:
			picker_window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))

	func _on_picked(c: Color) -> void:
		style["colour"] = "#" + c.to_html(false)
		if String(style.get("look", "none")) == "none":
			style["look"] = "board"
		_commit()

	func _on_clear() -> void:
		style["look"] = "none"
		_commit()

	func _on_done() -> void:
		if picker_window != null and is_instance_valid(picker_window):
			picker_window.call("close")
		var w: Node = get_parent()
		while w != null and not w.has_method("place_at"):
			w = w.get_parent()
		if w != null:
			w.call("close")
