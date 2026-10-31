extends "res://modules/core_panels/panel_base.gd"

const KeyframeStrip := preload("res://ui/timeline/keyframe_strip.gd")
const PmSlide := preload("res://ui/kit/pm_slide.gd")
const FrameJobs := preload("res://host/frame_jobs.gd")
const REGION_MAX := 8
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const PREF_LABEL_W := "controls.label_w"
const PREF_SIMPLE := "controls.simple"
const PREF_SPLIT_POS := "controls.split_position"
const BLENDS: Array = [["normal", "Normal"], ["darken", "Darken"], ["multiply", "Multiply"], ["colour_burn", "Colour burn"], ["linear_burn", "Linear burn"], ["lighten", "Lighten"], ["screen", "Screen"], ["colour_dodge", "Colour dodge"], ["add", "Add"], ["overlay", "Overlay"], ["soft_light", "Soft light"], ["hard_light", "Hard light"], ["vivid_light", "Vivid light"], ["linear_light", "Linear light"], ["pin_light", "Pin light"], ["difference", "Difference"], ["exclusion", "Exclusion"], ["subtract", "Subtract"], ["divide", "Divide"], ["hue", "Hue"], ["saturation", "Saturation"], ["colour", "Colour"], ["luminosity", "Luminosity"]]
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const EffectDrop := preload("res://modules/core_panels/effect_drop.gd")
const EffectMoveDrop := preload("res://modules/core_panels/effect_move_drop.gd")
const ValueStyle := preload("res://modules/core_panels/value_style.gd")
const ValueClipboard := preload("res://modules/core_panels/value_clipboard.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const AnimLayerStack := preload("res://modules/core_panels/anim_layer_stack.gd")
const AnimExprSheet := preload("res://modules/core_panels/anim_expr_sheet.gd")
const AnimDrivenSheet := preload("res://modules/core_panels/anim_driven_sheet.gd")
const DriveSheet := preload("res://modules/core_panels/drive_sheet.gd")
const Drive := preload("res://doc/drive.gd")
const DRIVE_KINDS: PackedStringArray = ["float", "int", "vec2", "vec3", "color"]
const DRIVE_TIP := "Drive this value from a sound, a picture or another value"
const StreamRoles := preload("res://doc/stream_roles.gd")
const TokenComplete := preload("res://ui/kit/token_complete.gd")
const DISCRETE_KINDS: PackedStringArray = ["enum", "bool", "string", "texture", "layer"]
const LABEL_MIN := 48.0
const LABEL_MAX := 260.0
const LABEL_ONE_MIN := 20.0
const PREF_LABEL_ONE := "controls.value_label_w"
const INDENT_W := 14.0
const FIELD_W := 90.0
const VEC_W := 72.0
const TEXT_W := 160.0
const TEXT_PAD_H := 6.0
const TEXT_PAD_V := 2.0
const TEXT_BORDER := 2
const TEXT_ROWS_DEFAULT := 8
const PREF_TEXT_ROWS := "controls.text_rows_max"

var label_w: float = 120.0
var simple: bool = false
var search: String = ""
var _head: Label = null
var _simple_btn: Button = null
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _rows: Array[Dictionary] = []
var _open_strips: Dictionary = {}
var _built_for: String = ""
var _built_stamp: String = ""
var _dragging_field: bool = false
var _rebuild_queued: bool = false
var _slot: Control = null
var _colour_window: Control = null
var _texture_dialog: FileDialog = null
var _texture_target: Dictionary = {}
var _label_drag: bool = false
var _label_drag_x: float = 0.0
var _label_drag_from: float = 0.0
var _label_drag_row: Dictionary = {}
var _live_label: String = ""
var _filters: PackedStringArray = PackedStringArray()
var _drive_open: Dictionary = {}
var _follow_tight: bool = false
var _driven_key: String = ""
var _driven_cache: Dictionary = {}
var last_drive_note: String = ""


func _build(root_: Control) -> void:
	for spec: Array in [[PREF_LABEL_W, 120.0, {"label": "Effect Controls label column", "type": "float", "min": LABEL_MIN, "max": LABEL_MAX}], [PREF_SIMPLE, false, {"label": "Effect Controls simple mode", "type": "bool"}], [PREF_SPLIT_POS, false, {"label": "Effect Controls splits position into X and Y rows", "type": "bool"}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	label_w = float(Tk.px(float(Prefs.get_value(PREF_LABEL_W))))
	simple = bool(Prefs.get_value(PREF_SIMPLE))
	if not root_.visibility_changed.is_connected(_on_shown_again):
		root_.visibility_changed.connect(_on_shown_again)
	if not Tk.tokens_changed.is_connected(_on_tokens_changed):
		Tk.tokens_changed.connect(_on_tokens_changed)
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head = PmLabel.trim("No clip selected", "text_bright")
	head.add_child(_head)
	_simple_btn = PmButton.make("Simple", "", true)
	_simple_btn.set("quiet", true)
	_simple_btn.button_pressed = simple
	_simple_btn.pressed.connect(_on_simple)
	head.add_child(_simple_btn)
	_search = PmUI.line_edit("Search")
	_search.custom_minimum_size.x = float(Tk.px(120.0))
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	head.add_child(load("res://modules/core_panels/record_button.gd").call("make_record"))
	var fx_menu: Button = quiet_icon("more", "Effects on this clip: remove all, turn all off or on, paste an effect")
	fx_menu.name = "EffectsMenu"
	fx_menu.pressed.connect(_on_effects_menu.bind(fx_menu))
	head.add_child(fx_menu)
	_fit_head(head)
	_scroll = vscroll_area(col)
	_list = PmUI.vbox(0)
	PmFold.make("Warm", "", true).free()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_list.resized.connect(_fit_label_column)
	_scroll.gui_input.connect(_on_input)
	_list.gui_input.connect(_on_input)
	_slot = PmSlot.make(PackedStringArray(["effect", "preset"]))
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.connect("dropped", _on_dropped)
	root_.add_child(_slot)
	ValueStyle.ensure_pref()
	sync_key_defaults()
	if not Prefs.changed.is_connected(_on_pref_for_keys):
		Prefs.changed.connect(_on_pref_for_keys)
	if not bus().arm_changed.is_connected(_on_arm_changed):
		bus().arm_changed.connect(_on_arm_changed)
	for open_path: String in OS.get_environment("PM_SHOT_OPEN").split(",", false):
		_open_strips[open_path.strip_edges()] = true
	rebuild()


func target_clip() -> Clip:
	return Bus.selected_clip(seq())


func _on_simple() -> void:
	simple = _simple_btn.button_pressed
	Prefs.set_value(PREF_SIMPLE, simple)
	rebuild()


func _on_search(text: String) -> void:
	search = text.strip_edges().to_lower()
	_apply_search()


func _apply_search() -> void:
	for r: Dictionary in _rows:
		var row: Control = r["row"]
		var visible: bool = search.is_empty() or String(r["label"]).to_lower().contains(search)
		row.visible = visible
		if r.get("hold") is Control:
			(r["hold"] as Control).visible = visible
		var holder: Control = r["strip_holder"]
		holder.visible = visible
		holder.call("set_open", _open_strips.has(String(r["path"])) and not _many_on, false)


func _stamp() -> String:
	var many: Array[Clip] = many_clips()
	if not many.is_empty():
		return _many_stamp(many)
	var c: Clip = target_clip()
	if c == null:
		return ""
	return _stamp_of(c)


func _stamp_of(c: Clip) -> String:
	var uids: PackedStringArray = PackedStringArray()
	for e: Dictionary in c.effects:
		var extra: String = ""
		if String(e.get("id", "")) == "pair_view":
			var crops_v: Variant = (e.get("params", {}) as Dictionary).get("crops", null)
			extra = ":" + str(AnimProp.static_value(crops_v)).md5_text() if crops_v is Dictionary else ""
			extra += PairLayouts.stamp(e)
		uids.append(String(e.get("uid", "")) + ":" + String(e.get("id", "")) + extra)
	return c.id + "|" + ",".join(uids) + "|" + _mask_stamp(c) + "|" + _on_stamp(c) + "|" + str(c.props.is_empty()) + "|" + ",".join(visible_speeds(c)) + "|" + TransitionEc.key(c) + "|" + TransitionEc.key_out(c)


func _mask_stamp(c: Clip) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for m: Dictionary in c.masks:
		parts.append(String(m.get("id", "")) + ":" + String(m.get("kind", "")) + ":" + str(bool(m.get("enabled", true))))
	return ",".join(parts)


func _on_stamp(c: Clip) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e: Dictionary in c.effects:
		parts.append("1" if bool(e.get("enabled", true)) else "0")
	parts.append("/")
	for ae: Variant in c.audio_effects():
		parts.append(String((ae as Dictionary).get("uid", "")) + ("1" if bool((ae as Dictionary).get("enabled", true)) else "0"))
	return "".join(parts)


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		_queue_live_values()
	elif kind == "selection" or kind == "structure" or kind == "meta" or kind == "media":
		queue_rebuild()


func _on_history() -> void:
	queue_rebuild()


func _on_project_changed() -> void:
	_open_strips = {}
	for open_path: String in OS.get_environment("PM_SHOT_OPEN").split(",", false):
		_open_strips[open_path.strip_edges()] = true
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()


func _on_playhead(_t: float) -> void:
	if _many_on:
		_refresh_many(_many_moving_rows())
		return
	refresh_values()


func _on_arm_changed(_clip_id: String, _path: String, _on: bool) -> void:
	refresh_values()


func queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	var tree: SceneTree = _root.get_tree()
	if tree == null:
		_rebuild_queued = false
		rebuild()
		return
	FrameJobs.add("effect_controls|" + str(get_instance_id()), _deferred, Input.get_mouse_button_mask() != 0)


func _deferred() -> void:
	_rebuild_queued = false
	if not _alive():
		return
	if _dragging_field:
		refresh_values()
		return
	if _stamp() != _built_stamp:
		_staged = Input.get_mouse_button_mask() != 0 and not plant_no_stage
		rebuild()
		if _staged and _bs.is_empty():
			_unstage()
			if not _pending.is_empty():
				staged_builds += 1
				FrameJobs.add("effect_controls_attach|" + str(get_instance_id()), _drain_job, true)
		_staged = false
	else:
		refresh_values()


const STAGE_SLICE_US := 5000
const STAGE_BUILD_US := 4000

var _bs: Dictionary = {}
var _bs_gen: int = 0
var _gate_gen: int = -1
var _slice_t0: int = 0

static var plant_no_stage: bool = false
var _staged: bool = false
var _stage_bodies: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _pending_scroll: int = -1
var staged_builds: int = 0
var staged_slices: int = 0


func pending_rows() -> int:
	return _pending.size()


func _stage_body(f: VBoxContainer) -> void:
	var body: Variant = f.get("body")
	if not (body is Control):
		return
	var holder: Node = (body as Control).get_parent()
	if holder == null:
		return
	holder.remove_child(body)
	_stage_bodies.append({"holder": holder, "body": body})


func _unstage() -> void:
	for sb: Dictionary in _stage_bodies:
		var body: Control = sb["body"]
		var holder: Node = sb["holder"]
		if not is_instance_valid(body) or not is_instance_valid(holder):
			continue
		var kids: Array[Node] = body.get_children()
		for k: Node in kids:
			body.remove_child(k)
		holder.add_child(body)
		holder.move_child(body, 0)
		for k2: Node in kids:
			_pending.append({"body": body, "child": k2})
	_stage_bodies.clear()


func _drain_pending(budget_us: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	while not _pending.is_empty():
		if budget_us >= 0 and n > 0 and Time.get_ticks_usec() - t0 >= budget_us:
			break
		var p: Dictionary = _pending.pop_front()
		var ch: Variant = p["child"]
		if not is_instance_valid(ch):
			continue
		var body: Variant = p["body"]
		if not is_instance_valid(body) or (body as Node).is_queued_for_deletion():
			if (ch as Node).get_parent() == null:
				(ch as Node).free()
			continue
		(body as Node).add_child(ch)
		n += 1
	staged_slices += 1
	if not _pending.is_empty():
		FrameJobs.add("effect_controls_attach|" + str(get_instance_id()), _drain_job)
		return
	if _pending_scroll > 0 and _alive():
		PmUI.restore_scroll(_scroll, _pending_scroll)
	_pending_scroll = -1


func _drain_job() -> void:
	if not _bs.is_empty():
		return
	_drain_pending(STAGE_SLICE_US)


func _on_pref_changed(key: String) -> void:
	if watches_pref(key):
		_cache_stale = true
	if key == PREF_LABEL_W:
		label_w = float(Tk.px(float(Prefs.get_value(PREF_LABEL_W))))
	elif key == PREF_SIMPLE:
		simple = bool(Prefs.get_value(PREF_SIMPLE))


func live_prefs() -> PackedStringArray:
	return PackedStringArray(["controls.", "ui.precision", "ui.mono_labels"])


func rebuild() -> void:
	if not _alive():
		return
	_abort_steps()
	if not _staged and not _pending.is_empty():
		_drain_pending(-1)
	load("res://modules/core_panels/panel_place.gd").call("ec_leave", self)
	var scroll_y: int = _pending_scroll if _pending_scroll > 0 and not _pending.is_empty() else _scroll.scroll_vertical
	if _staged:
		_pending_scroll = scroll_y
	var keep: Array[Dictionary] = []
	if not _many_on and not _cache_stale:
		keep.append_array(_sections)
		keep.append_array(_spare)
	_cache_stale = false
	_sections = []
	_spare = []
	_rows.clear()
	_many_reset()
	var c: Clip = target_clip()
	_built_stamp = _stamp()
	var now_for: String = c.id if c != null else ""
	if now_for != _built_for:
		_picked = ""
		_flash_pick = ""
	_built_for = now_for
	var s: Sequence = seq()
	if c == null or s == null:
		PmUI.clear(_list)
		_head.text = "No clip selected"
		_list.add_child(PmLabel.dim("Select a clip on the timeline"))
		return
	var many: Array[Clip] = many_clips()
	if not many.is_empty():
		PmUI.clear(_list)
		_build_many(many)
		_apply_search()
		refresh_values()
		if scroll_y > 0:
			PmUI.restore_scroll(_scroll, scroll_y)
		return
	var more: int = Verbs.selection(s).size() - 1
	_head.text = (c.label if not c.label.is_empty() else c.id) + ("  +" + str(more) + " more" if more > 0 else "")
	_build_sections(c, section_plan(c, s), keep)
	if _staged:
		return
	_rebuild_tail(scroll_y)


func _rebuild_tail(scroll_y: int) -> void:
	_apply_search()
	refresh_values()
	if scroll_y > 0:
		PmUI.restore_scroll(_scroll, scroll_y)
	load("res://modules/core_panels/panel_place.gd").call("ec_arrive", self)


const SPARE_MAX := 48

var _sections: Array[Dictionary] = []
var _spare: Array[Dictionary] = []
var _cache_stale: bool = false
var reused_last: int = 0


func _on_tokens_changed() -> void:
	_cache_stale = true


const ONCE := "once"


func _step(key: String, ident: Array, build: Callable) -> Dictionary:
	return {"key": key, "ident": ident, "build": build}


func section_plan(c: Clip, s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: Track = s.track_of(c.id)
	var is_video: bool = t != null and t.is_picture(c)
	var m: MediaItem = doc().media_by_id(c.media_id) if doc() != null else null
	var mode: String = "simple" if simple else "full"
	if ValueStyle.outside_allowed():
		out.append(_step("outside|" + _outside_key(), [], _build_outside.bind(c)))
	if not _many_on and TransitionEc.shown(c, t):
		out.append(_step("transition|" + TransitionEc.key(c), [c.id], TransitionEc.build.bind(self, c)))
	if not _many_on and TransitionEc.shown_out(c, t):
		out.append(_step("transition_out|" + TransitionEc.key_out(c), [c.id], TransitionEc.build_out.bind(self, c)))
	if is_video and m != null and (m.kind == "title" or m.kind == "shape" or m.kind == "generator"):
		var pk: String = "props|" + m.kind + "|" + mode + "|" + str(c.props.is_empty()) + "|" + (m.id if not c.props.is_empty() else "")
		if m.kind == "title":
			for p: Dictionary in _style_presets():
				pk += "|" + String(p.get("id", ""))
		out.append(_step(pk + "|" + _speed_rows_key(c, PackedStringArray(["props"])), [c.id], _build_props.bind(c, m)))
		if m.kind == "title":
			out.append(_step("textfx|" + mode + "|" + str(_many_on) + "|" + TextEcRows.key(c, TextEcRows.members_of(self, c)), [c.id], TextEcRows.build.bind(self, c)))
	if is_video:
		out.append(_step("motion|" + mode + "|" + str(bool(Prefs.get_value(PREF_SPLIT_POS))) + "|" + _speed_rows_key(c, MOTION_SPEEDS) + "|" + ParentUi.key(c), [], _build_motion.bind(c)))
		out.append(_step("opacity|" + mode + "|" + _speed_rows_key(c, PackedStringArray(["transform.opacity"])), [], _build_opacity.bind(c)))
	out.append(_step("time|" + mode + String(load("res://modules/core_panels/time_interp_row.gd").call("key", self, c)), [], _build_time.bind(c)))
	out.append(_step("anim|" + mode, [], _build_anim_speed.bind(c)))
	if t != null and t.is_sound(c) or (t != null and is_video and _has_audio(c)):
		var streams: int = m.audio_streams.size() if m != null and m.audio_streams.size() > 1 else 0
		out.append(_step("audio|" + str(streams) + "|" + _speed_rows_key(c, PackedStringArray(["audio"])), [], _build_audio.bind(c, t)))
	if c.is_nest():
		out.append(_step(ONCE + "|nest|" + c.id + "|" + str(Time.get_ticks_usec()), [c.id], _build_nest.bind(c)))
	if is_video and not simple:
		var mk: PackedStringArray = PackedStringArray()
		for i: int in c.masks.size():
			var mask: Dictionary = c.masks[i]
			mk.append(String(mask.get("id", "")) + ":" + String(mask.get("kind", "")) + ":" + str(bool(mask.get("enabled", true))) + ":" + String(mask.get("region_of", "")) + ":" + MaskShape.label_of(mask, i))
		out.append(_step("masks|" + ",".join(mk) + "|" + _speed_rows_key(c, PackedStringArray(["masks"])), [], _build_masks.bind(c)))
	for i2: int in c.effects.size():
		out.append(_fx_step(c, c.effects, i2, "effects", false))
	var sounds: Array = c.audio_effects()
	for i3: int in sounds.size():
		out.append(_fx_step(c, sounds, i3, "audio_effects", true))
	if is_video and not _many_on:
		for ls: Clip in LinkedSound.sounds(s, c):
			out.append(_step("linked|" + LinkedSound.key(doc(), s, ls), [ls.id], LinkedSound.build.bind(self, ls)))
	return out


func _value_order_key(uid: String) -> String:
	var store: Dictionary = ValueStyle.store_of(self)
	var out: PackedStringArray = PackedStringArray()
	if ValueStyle.outside_allowed():
		for vid: String in ValueStyle.outside_of(store):
			if vid.contains(uid):
				out.append(vid)
	return "v:" + ",".join(ValueStyle.order_of(store, uid)) + "/" + ",".join(out)


func _outside_key() -> String:
	if not ValueStyle.outside_allowed():
		return "off"
	return ",".join(ValueStyle.outside_of(ValueStyle.store_of(self)))


func _fx_step(c: Clip, entries: Array, index: int, prefix: String, sound: bool) -> Dictionary:
	var e: Dictionary = entries[index]
	var uid: String = String(e.get("uid", ""))
	var eid: String = String(e.get("id", ""))
	var def: Dictionary = EffectSource.get_def(eid)
	var parts: PackedStringArray = PackedStringArray([prefix, eid, str(index), str(entries.size()), str(bool(e.get("enabled", true))), str(def.is_empty()), str(EffectSource.param_specs(def).hash())])
	var pairs: PackedStringArray = def.get("pairs_with", PackedStringArray())
	if eid == "pair_view" or eid == "grid" or not pairs.is_empty():
		parts.insert(0, ONCE)
		parts.append(uid + "|" + str(Time.get_ticks_usec()))
	if not sound:
		parts.append(_mask_chip_text(c, e))
		parts.append(str(Clip.mask_spills(e)))
	parts.append(_speed_rows_key(c, PackedStringArray([prefix + "." + uid]), prefix + "." + uid))
	parts.append(_value_order_key(uid))
	parts.append(PuppetUi.key(c, e))
	for p: Dictionary in EffectSource.param_specs(def):
		if String(p.get("type", "")) == "layer":
			var s: Sequence = seq()
			if s != null:
				for lt: Track in Verbs.layer_tracks(s):
					parts.append(lt.id + "=" + lt.shown_label())
			break
	return _step("|".join(parts), [uid], _build_stack_entry.bind(c, entries, index, prefix, sound))


func _build_nest(c: Clip) -> void:
	load("res://modules/core_panels/nest_controls.gd").call("build", self, c)


func _build_sections(c: Clip, plan: Array[Dictionary], keep: Array[Dictionary]) -> void:
	_bs_gen += 1
	_bs = {"c": c, "plan": plan, "keep": keep, "used": {}, "reuse": [], "i": 0}
	reused_last = 0
	if not _staged:
		_build_steps(-1, -1)
		_finish_sections()
		return
	_slice_t0 = Time.get_ticks_usec()
	_run_staged(_bs_gen)


func _run_staged(gen: int) -> void:
	await _build_steps(STAGE_BUILD_US, gen)
	if gen != _bs_gen or _bs.is_empty() or not _alive():
		return
	_staged = true
	_finish_sections()
	_rebuild_tail(_pending_scroll)
	_unstage()
	_staged = false
	if not _pending.is_empty():
		staged_builds += 1
		FrameJobs.add("effect_controls_attach|" + str(get_instance_id()), _drain_job, true)


func _next_frame() -> void:
	var tree: SceneTree = _root.get_tree() if _alive() else null
	if tree == null:
		return
	await tree.process_frame
	_slice_t0 = Time.get_ticks_usec()


func _gate() -> bool:
	if _gate_gen < 0 or Time.get_ticks_usec() - _slice_t0 < STAGE_BUILD_US:
		return false
	var gen: int = _gate_gen
	_gate_gen = -1
	_staged = false
	await _next_frame()
	if gen != _bs_gen or not _alive():
		return true
	_gate_gen = gen
	_staged = true
	return false


func _build_steps(budget_us: int, gen: int) -> bool:
	var plan: Array[Dictionary] = _bs["plan"]
	var keep: Array[Dictionary] = _bs["keep"]
	var used: Dictionary = _bs["used"]
	var made: int = 0
	while int(_bs["i"]) < plan.size():
		if gen >= 0 and made > 0 and Time.get_ticks_usec() - _slice_t0 >= budget_us:
			_staged = false
			await _next_frame()
			if gen != _bs_gen or not _alive():
				return false
			_staged = true
		var step: Dictionary = plan[int(_bs["i"])]
		_bs["i"] = int(_bs["i"]) + 1
		var key: String = String(step["key"])
		var hit: int = -1
		for i: int in keep.size():
			if not used.has(i) and String(keep[i]["key"]) == key:
				hit = i
				break
		if hit >= 0:
			used[hit] = true
			var sec: Dictionary = keep[hit]
			(_bs["reuse"] as Array).append([sec, step["ident"]])
			_sections.append(sec)
			var sec_rows: Array[Dictionary] = sec["rows"]
			_rows.append_array(sec_rows)
			reused_last += 1
			continue
		var n0: int = _list.get_child_count()
		var r0: int = _rows.size()
		_gate_gen = gen
		await (step["build"] as Callable).call()
		_gate_gen = -1
		if gen >= 0 and (gen != _bs_gen or not _alive()):
			_drop_staged_bodies()
			return false
		if _staged:
			_unstage()
		var nodes: Array[Node] = []
		for j: int in range(n0, _list.get_child_count()):
			var made_node: Node = _list.get_child(j)
			nodes.append(made_node)
			if gen >= 0 and made_node is CanvasItem:
				(made_node as CanvasItem).visible = false
		_sections.append({"key": key, "ident": step["ident"], "nodes": nodes, "rows": _rows.slice(r0)})
		made += 1
	return true


func _drop_staged_bodies() -> void:
	for sb: Dictionary in _stage_bodies:
		var body: Variant = sb["body"]
		var holder: Variant = sb["holder"]
		if not is_instance_valid(body):
			continue
		for k: Node in (body as Node).get_children():
			(body as Node).remove_child(k)
			k.free()
		if is_instance_valid(holder) and (body as Node).get_parent() == null:
			(holder as Node).add_child(body)
			(holder as Node).move_child(body, 0)
	_stage_bodies.clear()


func _abort_steps() -> void:
	if _bs.is_empty():
		return
	_bs_gen += 1
	_gate_gen = -1
	_drop_staged_bodies()
	var keep: Array[Dictionary] = _bs["keep"]
	var used: Dictionary = _bs["used"]
	for i: int in keep.size():
		if not used.has(i):
			_sections.append(keep[i])
	_bs = {}


func _finish_sections() -> void:
	var c: Clip = _bs["c"]
	var keep: Array[Dictionary] = _bs["keep"]
	var used: Dictionary = _bs["used"]
	var swap: Dictionary = {}
	var reused_rows: Array[Dictionary] = []
	for pair: Variant in (_bs["reuse"] as Array):
		var sec: Dictionary = (pair as Array)[0]
		var now: Array = (pair as Array)[1]
		var was: Array = sec["ident"]
		for k: int in mini(was.size(), now.size()):
			if String(was[k]) != String(now[k]):
				swap[String(was[k])] = String(now[k])
		sec["ident"] = now
		var sec_rows: Array[Dictionary] = sec["rows"]
		reused_rows.append_array(sec_rows)
	_bs = {}
	for i2: int in keep.size():
		if not used.has(i2) and _spare.size() < SPARE_MAX and not String(keep[i2]["key"]).begins_with(ONCE):
			_spare.append(keep[i2])
	var alive: Dictionary = {}
	for sec2: Dictionary in _sections:
		for n: Node in (sec2["nodes"] as Array[Node]):
			alive[n] = true
			if not (n as CanvasItem).visible:
				(n as CanvasItem).visible = true
	for spare: Dictionary in _spare:
		for sn: Node in (spare["nodes"] as Array[Node]):
			alive[sn] = true
			if (sn as CanvasItem).visible:
				(sn as CanvasItem).visible = false
	for child: Node in _list.get_children():
		if not alive.has(child):
			PmUI.free_node(child)
	var at: int = 0
	for sec3: Dictionary in _sections:
		for n2: Node in (sec3["nodes"] as Array[Node]):
			if n2.get_parent() == _list:
				if n2.get_index() != at:
					_list.move_child(n2, at)
				at += 1
	if not swap.is_empty():
		_swap_bindings(swap)
		for sec4: Dictionary in _sections:
			for n3: Node in (sec4["nodes"] as Array[Node]):
				_swap_header_uid(n3, swap)
		for spare2: Dictionary in _spare:
			var idents: Array = []
			for v: Variant in (spare2["ident"] as Array):
				idents.append(swapped(v, swap))
			spare2["ident"] = idents
			for sn2: Node in (spare2["nodes"] as Array[Node]):
				_swap_header_uid(sn2, swap)
			_swap_paths(spare2["rows"], swap)
	_swap_paths(reused_rows, swap)
	_retarget_rows(c, reused_rows)


static func swapped(a: Variant, swap: Dictionary) -> Variant:
	if not (a is String):
		return a
	var sa: String = a
	if swap.has(sa):
		return swap[sa]
	if not sa.contains("."):
		return a
	var near: bool = false
	for k: Variant in swap:
		if sa.contains(String(k)):
			near = true
			break
	if not near:
		return a
	var parts: PackedStringArray = sa.split(".")
	var hit: bool = false
	for i: int in parts.size():
		if swap.has(parts[i]):
			parts[i] = String(swap[parts[i]])
			hit = true
	return ".".join(parts) if hit else a


func _swap_bindings(swap: Dictionary) -> void:
	for conn: Dictionary in get_incoming_connections():
		var cb: Callable = conn["callable"]
		if cb.get_bound_arguments_count() <= 0:
			continue
		var args: Array = cb.get_bound_arguments()
		var fresh: Array = []
		var changed: bool = false
		for a: Variant in args:
			var b: Variant = swapped(a, swap)
			if a is String and String(b) != String(a):
				changed = true
			fresh.append(b)
		if not changed:
			continue
		var sig: Signal = conn["signal"]
		sig.disconnect(cb)
		sig.connect(Callable(cb.get_object(), cb.get_method()).bindv(fresh), int(conn["flags"]))


func _swap_header_uid(n: Node, swap: Dictionary) -> void:
	if n.get_child_count() == 0:
		return
	var header: Variant = n.get_child(0).get("header")
	if header is Control and (header as Control).has_meta("uid"):
		var uid: String = String((header as Control).get_meta("uid"))
		if swap.has(uid):
			(header as Control).set_meta("uid", String(swap[uid]))


func _swap_paths(rows: Array[Dictionary], swap: Dictionary) -> void:
	if swap.is_empty():
		return
	for r: Dictionary in rows:
		var spec: Dictionary = r["spec"]
		var path: String = String(swapped(String(r["path"]), swap))
		if path != String(r["path"]):
			r["path"] = path
			spec["path"] = path
		if spec.has("uid"):
			spec["uid"] = String(swapped(String(spec["uid"]), swap))
		if spec.has("fx_uid"):
			spec["fx_uid"] = String(swapped(String(spec["fx_uid"]), swap))
		_repick_row(r, spec, path)


func _repick_row(r: Dictionary, spec: Dictionary, path: String) -> void:
	r["pick"] = _pick_id(spec)
	var hold: Variant = r.get("hold")
	if not (hold is Control) or not is_instance_valid(hold as Control):
		return
	var box: Control = hold
	box.set_meta(PICK_META, String(r["pick"]))
	ValueStyle.adopt(box, path, String(spec.get("fx_uid", "")), String(spec.get("fx_key", "")), String(box.get_meta(ValueStyle.META_TOKEN, "bg_panel")))


func _retarget_rows(c: Clip, rows: Array[Dictionary]) -> void:
	for r: Dictionary in rows:
		var spec: Dictionary = r["spec"]
		var path: String = String(r["path"])
		var label: Control = r["label_ctrl"]
		var want: float = _spec_label_width(spec)
		if not is_equal_approx(float(label.get_meta(PmWrapRow.PREF_META, -1.0)), want):
			PmWrapRow.prefer(label, want)
		var strip: Variant = r["strip"]
		if strip is Control:
			KeyframeStrip.retarget(strip, c.id, path)
			if _open_strips.has(path):
				_refresh_mods(r)
		elif _open_strips.has(path) and bool(spec.get("keyable", false)):
			_open_strip(r)
		if not _drive_open.is_empty() or r.get("drive", null) != null:
			_sync_drive(r, [] if _many_on else [c, path])


func _has_audio(c: Clip) -> bool:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return m != null and m.has_audio


func _fold(title: String, key: String) -> VBoxContainer:
	var f: VBoxContainer = PmFold.make(title, "controls." + key, true)
	var bar: PanelContainer = PmUI.panel("bg_panel_alt")
	var sb: StyleBoxFlat = bar.get_theme_stylebox("panel")
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	bar.add_child(f)
	_list.add_child(bar)
	load("res://modules/core_panels/panel_place.gd").call("fold_made", self, f, bar)
	if _many_on and _many_count > 0:
		f.call("add_right", _count_label(_many_count))
	if _staged:
		_stage_body(f)
	return f


func _build_motion(c: Clip) -> void:
	var f: VBoxContainer = _fold("Motion", "motion")
	var body: VBoxContainer = f.get("body")
	_add_section_speed(f, "motion", "Motion")
	f.call("add_right", ParentUi.header_whip(c, many_clips() if _many_on else []))
	if bool(Prefs.get_value(PREF_SPLIT_POS)):
		_add_row(body, {"path": "transform.pos", "label": "Position X", "kind": "float", "step": 1.0, "component": 0, "keyable": true})
		if await _gate():
			return
		_add_row(body, {"path": "transform.pos", "label": "Position Y", "kind": "float", "step": 1.0, "component": 1, "keyable": true})
		if await _gate():
			return
	else:
		_add_row(body, {"path": "transform.pos", "label": "Position", "kind": "vec2", "step": 1.0, "keyable": true})
		if await _gate():
			return
	_add_row(body, {"path": "transform.scale", "label": "Scale", "kind": "vec2", "step": 0.01, "keyable": true, "scale_link": true, "suffix": "", "display_mul": 100.0})
	if await _gate():
		return
	_add_row(body, {"path": "transform.rotation", "label": "Rotation", "kind": "float", "step": 0.5, "suffix": " °", "keyable": true})
	if await _gate():
		return
	body.add_child(ParentUi.row(c, _label_width("Parent", 0), many_clips() if _many_on else []))
	if not simple:
		_add_row(body, {"path": "transform.anchor", "label": "Anchor", "kind": "vec2", "step": 1.0, "keyable": true})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.on", "label": "Motion blur", "kind": "bool", "field": "motion_blur", "key": "on"})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.mode", "label": "Blur type", "kind": "enum", "field": "motion_blur", "key": "mode", "indent": 1, "choices": [PmDrop.choice("smooth", "Smooth (real blur)"), PmDrop.choice("copies", "Copies of the frame")]})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.shutter_angle", "label": "Shutter angle", "kind": "float", "min": 0.0, "max": 720.0, "step": 1.0, "suffix": " °", "indent": 1, "keyable": true})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.shutter_phase", "label": "Shutter phase", "kind": "float", "min": -360.0, "max": 360.0, "step": 1.0, "suffix": " °", "indent": 1, "keyable": true})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.samples", "label": "Samples", "kind": "int", "min": 1.0, "max": 64.0, "step": 1.0, "indent": 1, "keyable": true})
		if await _gate():
			return
		_add_row(body, {"path": "motion_blur.rotation", "label": "Rotation blur", "kind": "bool", "field": "motion_blur", "key": "rotation", "indent": 1})
		if await _gate():
			return


func _build_props(c: Clip, m: MediaItem) -> void:
	var kind: String = m.kind
	var title: String = "Text" if kind == "title" else ("Shape" if kind == "shape" else "Colour matte")
	var f: VBoxContainer = _fold(title, "props." + kind)
	var body: VBoxContainer = f.get("body")
	_add_section_speed(f, "props", title)
	if kind == "title":
		_add_style_row(body, c)
		_add_row(body, {"path": "props.text", "prop": "text", "keyable": true, "label": "Text", "kind": "multiline"})
		body.add_child(_text_preset_row(c) if not _many_on else ManyButtons.text_presets(self))
		_add_row(body, {"path": "props.reveal", "prop": "reveal", "keyable": true, "label": "Revealed", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "indent": 1})
		_add_row(body, {"path": "props.cursor", "prop": "cursor", "keyable": true, "label": "Cursor", "kind": "string", "indent": 1})
		var fonts: Array = [PmDrop.choice("default", "Figtree (built in)")]
		for name_: String in TitleStyle.system_fonts():
			fonts.append(PmDrop.choice(name_, name_))
		_add_row(body, {"path": "props.font", "prop": "font", "keyable": true, "label": "Font", "kind": "enum", "choices": fonts})
		_add_row(body, {"path": "props.size", "prop": "size", "keyable": true, "label": "Size", "kind": "float", "min": 4.0, "max": 600.0, "step": 1.0, "suffix": " px"})
		_add_row(body, {"path": "props.colour", "prop": "colour", "keyable": true, "label": "Colour", "kind": "color"})
		_add_row(body, {"path": "props.bold", "prop": "bold", "keyable": true, "label": "Bold", "kind": "bool"})
		_add_row(body, {"path": "props.italic", "prop": "italic", "keyable": true, "label": "Italic", "kind": "bool"})
		_add_row(body, {"path": "props.uppercase", "prop": "uppercase", "keyable": true, "label": "Uppercase", "kind": "bool"})
		var aligns: Array = [PmDrop.choice("left", "Left"), PmDrop.choice("center", "Centre"), PmDrop.choice("right", "Right")]
		_add_row(body, {"path": "props.align", "prop": "align", "keyable": true, "label": "Align", "kind": "enum", "choices": aligns})
		var valigns: Array = [PmDrop.choice("top", "Top"), PmDrop.choice("center", "Middle"), PmDrop.choice("bottom", "Bottom")]
		_add_row(body, {"path": "props.valign", "prop": "valign", "keyable": true, "label": "Vertical", "kind": "enum", "choices": valigns})
		_add_row(body, {"path": "props.width", "prop": "width", "keyable": true, "label": "Wrap width", "kind": "float", "min": 0.05, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0})
		_add_row(body, {"path": "props.line_spacing", "prop": "line_spacing", "keyable": true, "label": "Line spacing", "kind": "float", "min": -100.0, "max": 400.0, "step": 1.0, "suffix": " px"})
		_add_row(body, {"path": "props.letter_spacing", "prop": "letter_spacing", "keyable": true, "label": "Letter spacing", "kind": "float", "min": -50.0, "max": 200.0, "step": 0.5, "suffix": " px"})
		_add_row(body, {"path": "props.outline", "prop": "outline", "keyable": true, "label": "Outline", "kind": "float", "min": 0.0, "max": 60.0, "step": 0.5, "suffix": " px"})
		_add_row(body, {"path": "props.outline_colour", "prop": "outline_colour", "keyable": true, "label": "Outline colour", "kind": "color", "indent": 1})
		_add_row(body, {"path": "props.shadow_on", "prop": "shadow_on", "keyable": true, "label": "Shadow", "kind": "bool"})
		_add_row(body, {"path": "props.shadow_colour", "prop": "shadow_colour", "keyable": true, "label": "Shadow colour", "kind": "color", "indent": 1})
		_add_row(body, {"path": "props.shadow_distance", "prop": "shadow_distance", "keyable": true, "label": "Distance", "kind": "float", "min": 0.0, "max": 200.0, "step": 0.5, "suffix": " px", "indent": 1})
		_add_row(body, {"path": "props.shadow_angle", "prop": "shadow_angle", "keyable": true, "label": "Angle", "kind": "float", "min": 0.0, "max": 360.0, "step": 1.0, "suffix": " °", "indent": 1})
		_add_row(body, {"path": "props.shadow_softness", "prop": "shadow_softness", "keyable": true, "label": "Softness", "kind": "float", "min": 0.0, "max": 150.0, "step": 0.5, "suffix": " px", "indent": 1})
		_add_row(body, {"path": "props.box_colour", "prop": "box_colour", "keyable": true, "label": "Box colour", "kind": "color"})
		_add_row(body, {"path": "props.box_pad", "prop": "box_pad", "keyable": true, "label": "Box padding", "kind": "float", "min": 0.0, "max": 200.0, "step": 1.0, "suffix": " px", "indent": 1})
		_add_row(body, {"path": "props.box_radius", "prop": "box_radius", "keyable": true, "label": "Box radius", "kind": "float", "min": 0.0, "max": 200.0, "step": 1.0, "suffix": " px", "indent": 1})
	elif kind == "shape":
		var shapes: Array = [PmDrop.choice("rect", "Rectangle"), PmDrop.choice("ellipse", "Ellipse"), PmDrop.choice("line", "Line")]
		_add_row(body, {"path": "props.shape", "prop": "shape", "keyable": true, "label": "Shape", "kind": "enum", "choices": shapes})
		_add_row(body, {"path": "props.colour", "prop": "colour", "keyable": true, "label": "Colour", "kind": "color"})
		_add_row(body, {"path": "props.width", "prop": "width", "keyable": true, "label": "Width", "kind": "float", "min": 0.001, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0})
		_add_row(body, {"path": "props.height", "prop": "height", "keyable": true, "label": "Height", "kind": "float", "min": 0.001, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0})
		_add_row(body, {"path": "props.radius", "prop": "radius", "keyable": true, "label": "Corner radius", "kind": "float", "min": 0.0, "max": 500.0, "step": 1.0, "suffix": " px"})
		_add_row(body, {"path": "props.border", "prop": "border", "keyable": true, "label": "Border", "kind": "float", "min": 0.0, "max": 100.0, "step": 1.0, "suffix": " px"})
		_add_row(body, {"path": "props.border_colour", "prop": "border_colour", "keyable": true, "label": "Border colour", "kind": "color", "indent": 1})
	else:
		_add_row(body, {"path": "props.colour", "prop": "colour", "keyable": true, "label": "Colour", "kind": "color"})
	if not c.props.is_empty() and not _many_on:
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
		row.add_child(PmLabel.dim("This clip has its own values"))
		var push: Button = PmButton.make("Apply to every clip of this " + ("title" if kind == "title" else kind))
		push.set("quiet", true)
		push.pressed.connect(_on_push_props.bind(c.id, m.id))
		row.add_child(push)
		var drop: Button = PmButton.make("Use the shared values")
		drop.set("quiet", true)
		drop.pressed.connect(_on_drop_props.bind(c.id))
		row.add_child(drop)
		body.add_child(row)
	if _many_on:
		ManyButtons.own_values(self, body, kind)


func _style_presets() -> Array[Dictionary]:
	var d: Project = doc()
	var out: Array[Dictionary] = []
	if d != null:
		out.append_array(Presets.list_project(d, "text_style"))
	out.append_array(Presets.list_user("text_style"))
	return out


func _add_style_row(body: VBoxContainer, c: Clip) -> void:
	var row: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	var fold_btn: Button = quiet_icon("chev_r", "")
	fold_btn.set("icon_px", 12.0)
	_ghost(fold_btn)
	row.add_child(fold_btn)
	var label_box: HBoxContainer = PmUI.hbox(0)
	var label: Label = PmLabel.trim("Style")
	label.custom_minimum_size = Vector2(_label_width("Style", 0), 0.0)
	label_box.add_child(label)
	row.add_child(label_box)
	var cluster: HBoxContainer = PmUI.hbox(0)
	var sw: Button = quiet_icon("stopwatch", "")
	sw.set("icon_px", 13.0)
	cluster.add_child(sw)
	cluster.add_child(_spacer(42.0))
	_ghost(cluster)
	row.add_child(cluster)
	var choices: Array = [PmDrop.choice("pick", "Pick a style"), PmDrop.choice("subtitle", "Subtitle default")]
	for p: Dictionary in _style_presets():
		choices.append(PmDrop.choice("preset:" + String(p.get("id", "")), String(p.get("label", "Style"))))
	choices.append(PmDrop.choice("save", "Save these values as a style"))
	var drop: Button = PmDrop.make_drop(choices, "pick")
	drop.name = "StyleDrop"
	drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop.connect("changed", _on_style_pick.bind(c.id, drop))
	row.add_child(drop)
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	body.add_child(row)


func _on_style_pick(id: String, clip_id: String, drop: Button) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	if id == "save":
		var fields: Array[Dictionary] = [{"key": "name", "label": "Style name", "type": "string", "default": ""}]
		var answered: Signal = PmUI.form(_root, "Save text style", fields, "Save", "Cancel")
		answered.connect(_on_style_save_answered.bind(clip_id))
	elif id == "subtitle":
		Subtitles.apply_style(d, s, _style_ids(clip_id), Subtitles.subtitle_style())
	elif id.begins_with("preset:"):
		var pid: String = id.substr(7)
		for p: Dictionary in _style_presets():
			if String(p.get("id", "")) == pid:
				var payload: Dictionary = p.get("payload", {})
				Subtitles.apply_style(d, s, _style_ids(clip_id), payload.get("props", {}))
				break
	if id != "pick" and is_instance_valid(drop):
		drop.call("set_value", "pick", false)


func _on_style_save_answered(result: Variant, clip_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	var name_: String = String((result as Dictionary).get("name", "")).strip_edges()
	if name_.is_empty():
		name_ = "Style " + str(_style_presets().size() + 1)
	if Presets.save_to_project(d, Subtitles.style_from_clip(d, c, name_)):
		Events.notice("Style saved", name_ + " is in this project's presets under Text style.")


func _on_push_props(clip_id: String, media_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	var m: MediaItem = d.media_by_id(media_id)
	if c == null or m == null:
		return
	var merged: Dictionary = m.props.duplicate(true)
	for k: Variant in c.props.keys():
		merged[k] = c.props[k]
	Verbs.run(d, "Apply to every clip", [MediaCmds.SetMediaField.new(m.id, "props", merged), ClipCmds.SetClipField.new(s.id, c.id, "props", {})])


func _on_drop_props(clip_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	Verbs.run(d, "Use the shared values", [ClipCmds.SetClipField.new(s.id, clip_id, "props", {})])


func _text_preset_row(c: Clip) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	row.add_child(PmLabel.dim("Typing"))
	for p: Dictionary in Verbs.text_presets():
		var b: Button = PmButton.make(String(p["label"]), "type")
		b.set("quiet", true)
		PmUI.tip(b, String(p["tip"]))
		b.pressed.connect(_on_text_preset.bind(String(p["id"])))
		row.add_child(b)
	return row


func _on_text_preset(kind: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	if not Verbs.apply_text_preset(d, s, c.id, kind):
		Events.toast("The text already types that way")


func _prop_value(c: Clip, key: String) -> Variant:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var merged: Dictionary = TitleStyle.merged(m.kind if m != null else "title", m.props if m != null else {}, c.props, m.label if m != null else "")
	var v: Variant = merged.get(key, null)
	if v == null:
		v = TextEcRows.default_of(key)
	if key == "font" and (not (v is String or v is StringName) or String(v).is_empty()):
		return "default"
	return v


func _build_opacity(c: Clip) -> void:
	var f: VBoxContainer = _fold("Opacity", "opacity")
	var body: VBoxContainer = f.get("body")
	_add_row(body, {"path": "transform.opacity", "label": "Opacity", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true})
	if await _gate():
		return
	if not simple:
		var choices: Array = []
		for b: Array in BLENDS:
			choices.append(PmDrop.choice(String(b[0]), String(b[1])))
		_add_row(body, {"path": "transform.blend", "label": "Blend", "kind": "enum", "field": "transform", "key": "blend", "choices": choices})
		if await _gate():
			return


func _build_time(c: Clip) -> void:
	var f: VBoxContainer = _fold("Time", "time")
	var body: VBoxContainer = f.get("body")
	f.call("add_right", load("res://modules/core_panels/speed_presets.gd").call("button", self))
	var prev_btn: Button = PmButton.make("Preview", "play")
	prev_btn.name = "SpeedPreviewButton"
	prev_btn.set("quiet", true)
	PmUI.tip(prev_btn, "Open a small window that loops the frames around the playhead, so you see a speed change at once (sound optional)")
	prev_btn.pressed.connect(func() -> void: load("res://modules/core_panels/speed_preview.gd").call("open_for", _root))
	f.call("add_right", prev_btn)
	var pin_btn: Button = PmButton.make("Keys stay on frame", "", true)
	pin_btn.name = "KeysStayButton"
	pin_btn.set("quiet", true)
	pin_btn.set_pressed_no_signal(KeyAnchor.pref_on())
	PmUI.tip(pin_btn, "Keyframes you place from now on stay on their frame of the video when this or any clip's speed changes. Keys already placed are left alone. Also in Settings")
	pin_btn.toggled.connect(func(on: bool) -> void: Prefs.set_value(KeyAnchor.PREF, on))
	f.call("add_right", pin_btn)
	var follow_btn: Button = PmButton.make("Playhead follows", "", true)
	follow_btn.name = "PlayheadFollowsButton"
	follow_btn.set("quiet", true)
	follow_btn.set_pressed_no_signal(SpeedFollow.pref_on())
	PmUI.tip(follow_btn, "When the speed changes, the playhead moves with the clip so the same frame stays under it. Also in Settings")
	follow_btn.toggled.connect(func(on: bool) -> void: Prefs.set_value(SpeedFollow.PREF, on))
	f.call("add_right", follow_btn)
	_add_row(body, {"path": "speed", "label": "Speed", "kind": "float", "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "signed": true})
	if await _gate():
		return
	_add_row(body, {"path": "audio.speed_length", "label": "Resize with speed", "kind": "bool", "field": "audio", "key": "speed_length"})
	if await _gate():
		return
	PmUI.tip((_rows.back() as Dictionary)["label_ctrl"], "Change the clip's length with its speed (moves later clips). Off: the clip keeps its length and only plays faster or slower.")
	_add_row(body, {"path": "time.reverse", "label": "Reverse", "kind": "bool", "special": "reverse"})
	if await _gate():
		return
	load("res://modules/core_panels/time_interp_row.gd").call("add", self, body, c)
	if not simple:
		_add_row(body, {"path": "audio.pitch_keep", "label": "Keep pitch", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true})
		PmUI.tip((_rows.back() as Dictionary)["label_ctrl"], "0 %: the pitch follows the speed. 100 %: the pitch stays. In between it blends, and keys glide from one to the other.")
		if await _gate():
			return


func _build_anim_speed(c: Clip) -> void:
	var f: VBoxContainer = _fold("Animation speed", "anim_speed")
	var body: VBoxContainer = f.get("body")
	_add_row(body, {"path": AnimTime.SPEED_PATH, "label": "Speed", "kind": "float", "step": 0.01, "min": AnimTime.SPEED_MIN, "max": AnimTime.SPEED_MAX, "suffix": " %", "display_mul": 100.0, "keyable": true, "signed": true, "special": "anim_speed"})
	if await _gate():
		return
	if not simple:
		_add_row(body, {"path": AnimTime.START_FIELD, "label": "Starts at", "kind": "float", "step": 0.01, "suffix": " s", "indent": 1})
		if await _gate():
			return
	var row: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	row.name = "AnimSpeedReset"
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	var fold_gap: Button = quiet_icon("chev_r", "")
	fold_gap.set("icon_px", 12.0)
	_ghost(fold_gap)
	row.add_child(fold_gap)
	var gap_label: Label = PmLabel.trim("")
	gap_label.size_flags_horizontal = Control.SIZE_FILL
	gap_label.custom_minimum_size = Vector2(_label_width("", 0), 0.0)
	row.add_child(gap_label)
	var gap_cluster: HBoxContainer = PmUI.hbox(0)
	var gap_sw: Button = quiet_icon("stopwatch", "")
	gap_sw.set("icon_px", 13.0)
	gap_cluster.add_child(gap_sw)
	var gap_nav: HBoxContainer = PmUI.hbox(0)
	for icon: String in ["prev_key", "diamond_o", "next_key"]:
		var gb: Button = quiet_icon(icon, "")
		gb.set("icon_px", 10.0)
		gb.custom_minimum_size = Vector2(14.0, 0.0)
		gap_nav.add_child(gb)
	gap_nav.custom_minimum_size = Vector2(42.0, 0.0)
	gap_cluster.add_child(gap_nav)
	_ghost(gap_cluster)
	row.add_child(gap_cluster)
	var editors: HBoxContainer = PmUI.hbox()
	editors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset: Button = PmButton.make("Reset")
	reset.set("quiet", true)
	PmUI.tip(reset, "Animation speed back to 100 % and Starts at back to 0")
	reset.pressed.connect(reset_anim_speed)
	editors.add_child(reset)
	var note: Label = PmLabel.trim(anim_speed_note(c), "text_faint")
	note.name = "AnimSpeedNote"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editors.add_child(note)
	row.add_child(editors)
	body.add_child(row)
	_fit_lead_row(row, [gap_label] as Array[Control], -1, float(Tk.px(Tk.sz("pad"))))
	_anim_note = note


var _anim_note: Label = null


static func anim_speed_note(c: Clip) -> String:
	if c == null or not c.anim_warped():
		return "Keys play at their own times"
	if AnimProp.is_animated(c.anim_speed):
		return "Keys follow the speed curve"
	var sp: float = float(AnimProp.static_value(c.anim_speed))
	if sp == 0.0:
		return "Keys are held"
	if sp < 0.0:
		return "Keys play backwards"
	return "Keys play slower" if sp < 1.0 else ("Keys play faster" if sp > 1.0 else "The animation starts part way in")


func _refresh_anim_note(c: Clip) -> void:
	if _anim_note == null or not is_instance_valid(_anim_note):
		return
	var want: String = anim_speed_note(c)
	if _anim_note.text != want:
		_anim_note.text = want


func _anim_speed_cmds(c: Clip, value: Variant) -> Array[Command]:
	var cmds: Array[Command] = []
	var s: Sequence = seq()
	if c == null or s == null:
		return cmds
	var p: Dictionary = c.get_param(AnimTime.SPEED_PATH)
	if AnimProp.is_animated(p) or bus().is_armed(c.id, AnimTime.SPEED_PATH):
		return cmds
	var sp: float = clampf(float(value), AnimTime.SPEED_MIN, AnimTime.SPEED_MAX)
	var old: float = float(AnimProp.static_value(p))
	var want_start: float = c.anim_start
	if sp < 0.0 or old < 0.0:
		want_start = AnimTime.reversed_start(sp, c.duration)
	cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.SPEED_PATH, AnimProp.make(sp)))
	if want_start != c.anim_start:
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.START_FIELD, AnimProp.make(want_start)))
	return cmds


func _write_anim_speed(c: Clip, value: Variant) -> bool:
	var d: Project = doc()
	var cmds: Array[Command] = _anim_speed_cmds(c, value)
	if d == null or cmds.is_empty():
		return false
	if _dragging_field:
		for cmd: Command in cmds:
			d.undo.live(cmd)
		_live_label = "Set animation speed"
		return true
	Verbs.run(d, "Set animation speed", cmds)
	return true


func reset_anim_speed() -> bool:
	if _many_on:
		return _reset_anim_speed_many()
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return false
	var cmds: Array[Command] = []
	if c.get_param(AnimTime.SPEED_PATH) != AnimProp.make(1.0):
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.SPEED_PATH, AnimProp.make(1.0)))
	if c.anim_start != 0.0:
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.START_FIELD, AnimProp.make(0.0)))
	if cmds.is_empty():
		return false
	bus().set_armed(c.id, AnimTime.SPEED_PATH, false)
	return Verbs.run(d, "Reset animation speed", cmds)


const SPEED_ROW_TIP := "How fast this value's keys play, inside its section's speed and the clip's Animation speed. A negative speed plays them backwards, 0 holds them."
const MOTION_SPEEDS: PackedStringArray = ["motion", "transform.pos", "transform.scale", "transform.rotation", "transform.anchor", "motion_blur"]
const SHOW_SPEED_ID := "show_speed"

var _open_speeds: Dictionary = {}


func _speed_key(canon: String) -> String:
	var c: Clip = target_clip()
	return ("many" if _many_on else (c.id if c != null else "")) + "|" + canon


func _speed_visible(canon: String, targets: Dictionary) -> bool:
	var key: String = _speed_key(canon)
	if _open_speeds.has(key):
		return true
	var s: Sequence = seq()
	if s == null:
		return false
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null and c.speed_used(String(targets[cid])):
			_open_speeds[key] = true
			return true
	return false


func _speed_in_use(canon: String) -> bool:
	var s: Sequence = seq()
	if s == null:
		return false
	if not _many_on:
		var c: Clip = target_clip()
		return c != null and c.speed_used(canon)
	var r: Dictionary = _row_for(AnimTime.speed_path(canon))
	var members: Dictionary = (r["spec"] as Dictionary).get("members", {}) if not r.is_empty() else {}
	for cid: Variant in members.keys():
		var mc: Clip = s.clip_by_id(String(cid))
		if mc != null and mc.speed_used(AnimTime.target_of(String(members[cid]))):
			return true
	return false


func visible_speeds(c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if c == null:
		return out
	for t: String in c.speed_targets():
		out.append(t)
	var head: String = c.id + "|"
	for k: Variant in _open_speeds.keys():
		var ks: String = String(k)
		if ks.begins_with(head) and not out.has(ks.substr(head.length())):
			out.append(ks.substr(head.length()))
	out.sort()
	return out


func _speed_rows_key(c: Clip, prefixes: PackedStringArray, strip: String = "") -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t: String in visible_speeds(c):
		for p: String in prefixes:
			if t == p or t.begins_with(p + "."):
				parts.append(t.substr(strip.length()) if not strip.is_empty() and t.begins_with(strip) else t)
				break
	return "sp:" + ",".join(parts)


func _speed_spec(path: String, label: String, indent: int) -> Dictionary:
	return {"path": path, "label": label, "kind": "float", "step": 0.01, "min": AnimTime.SPEED_MIN, "max": AnimTime.SPEED_MAX, "suffix": " %", "display_mul": 100.0, "keyable": true, "signed": true, "special": "inner_speed", "indent": indent}


func _add_speed_row_for(body: VBoxContainer, spec: Dictionary) -> void:
	var c: Clip = target_clip()
	if c == null or int(spec.get("component", 1)) == 0 or spec.has("field"):
		return
	var canon: String = String(spec["path"])
	var targets: Dictionary = {}
	if spec.has("members"):
		for cid: Variant in (spec["members"] as Dictionary).keys():
			var real: String = String((spec["members"] as Dictionary)[cid])
			if AnimTime.speed_able(real):
				targets[String(cid)] = real
	elif AnimTime.speed_able(canon):
		targets[c.id] = canon
	if targets.is_empty() or not _speed_visible(canon, targets):
		return
	var sp: Dictionary = _speed_spec(AnimTime.speed_path(canon), "Speed", int(spec.get("indent", 0)) + 1)
	if spec.has("members"):
		var mem: Dictionary = {}
		for cid2: Variant in targets.keys():
			mem[cid2] = AnimTime.speed_path(String(targets[cid2]))
		sp["members"] = mem
	_add_row(body, sp)
	_finish_speed_row(SPEED_ROW_TIP)


func _add_section_speed(f: VBoxContainer, target: String, name_: String, members: Dictionary = {}) -> void:
	var btn: Button = _section_speed_ui(f.get("body"), target, name_, members, 0)
	if btn != null:
		f.call("add_right", btn)


func _section_speed_ui(body: VBoxContainer, target: String, name_: String, members: Dictionary, indent: int) -> Button:
	var c: Clip = target_clip()
	if c == null:
		return null
	var targets: Dictionary = members.duplicate()
	if targets.is_empty():
		if _many_on:
			for m: Clip in _many_members:
				targets[m.id] = target
		else:
			targets[c.id] = target
	var shown: bool = _speed_visible(target, targets)
	var btn: Button = toggle_icon("rate", "Animation speed of " + name_ + ": show or hide its row. A speed in use always shows." + (" It goes to every selected clip." if _many_on else ""), shown)
	btn.name = "SectionSpeed"
	btn.pressed.connect(_on_section_speed.bind(target, btn))
	if not shown:
		return btn
	var sp: Dictionary = _speed_spec(AnimTime.speed_path(target), "Animation speed", indent)
	if _many_on:
		var mem: Dictionary = {}
		for cid: Variant in targets.keys():
			mem[cid] = AnimTime.speed_path(String(targets[cid]))
		sp["members"] = mem
	_add_row(body, sp)
	_finish_speed_row("How fast every keyed value in " + name_ + " plays, inside the clip's Animation speed. A negative speed plays them backwards, 0 holds them.")
	return btn


func _finish_speed_row(tip: String) -> void:
	var rec: Dictionary = _rows[_rows.size() - 1]
	var row: Control = rec["row"]
	var eds: Array = rec["editors"]
	if not eds.is_empty():
		var reset: Button = PmButton.make("Reset")
		reset.name = "SpeedReset"
		reset.set("quiet", true)
		PmUI.tip(reset, "Speed back to 100 %, one undo step")
		reset.pressed.connect(_on_speed_reset.bind(String(rec["path"])))
		(eds[0] as Control).get_parent().add_child(reset)
	PmUI.tip(rec["label_ctrl"], tip)
	rec["speed_row"] = true
	row.draw.connect(_draw_speed_band.bind(row))


func _draw_speed_band(row: Control) -> void:
	row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(Tk.c["bg_panel"], 0.6), true)


func _on_section_speed(target: String, btn: Button) -> void:
	_toggle_speed_row(target)
	if is_instance_valid(btn):
		btn.set_pressed_no_signal(_open_speeds.has(_speed_key(target)))


func _toggle_speed_row(canon: String) -> void:
	var key: String = _speed_key(canon)
	if _open_speeds.has(key):
		if _speed_in_use(canon):
			Events.toast("The speed is in use, so its row stays. Reset it to hide the row.")
			return
		_open_speeds.erase(key)
	else:
		_open_speeds[key] = true
	rebuild()


func _on_speed_reset(path: String) -> void:
	reset_inner_speed(path)


func reset_inner_speed(path: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var r: Dictionary = _row_for(path)
	if d == null or s == null or r.is_empty():
		return false
	var spec: Dictionary = r["spec"]
	var targets: Dictionary = spec.get("members", {})
	if not spec.has("members"):
		var c: Clip = target_clip()
		if c == null:
			return false
		targets = {c.id: path}
	var cmds: Array[Command] = []
	for cid: Variant in targets.keys():
		var tc: Clip = s.clip_by_id(String(cid))
		var real: String = String(targets[cid])
		var tgt: String = AnimTime.target_of(real)
		if tc == null or not tc.speed_used(tgt):
			continue
		cmds.append(ClipCmds.SetClipParam.new(s.id, tc.id, AnimTime.speed_path(tgt), AnimProp.make(1.0)))
		cmds.append(ClipCmds.SetClipParam.new(s.id, tc.id, AnimTime.start_path(tgt), AnimProp.make(0.0)))
		bus().set_armed(tc.id, AnimTime.speed_path(tgt), false)
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Reset speed", cmds)


func inner_speed_cmds(c: Clip, path: String, value: Variant) -> Array[Command]:
	var cmds: Array[Command] = []
	var s: Sequence = seq()
	if c == null or s == null:
		return cmds
	var p: Dictionary = c.get_param(path)
	if p.is_empty() or AnimProp.is_animated(p) or bus().is_armed(c.id, path):
		return cmds
	var sp: float = clampf(float(value), AnimTime.SPEED_MIN, AnimTime.SPEED_MAX)
	var old: float = float(AnimProp.static_value(p))
	var target: String = AnimTime.target_of(path)
	var cur_start: float = AnimTime.entry_start(c.speed_entry(target))
	var want_start: float = cur_start
	if sp < 0.0 or old < 0.0:
		want_start = AnimTime.reversed_entry_start(sp, maxf(c.param_time(path, 0.0), c.param_time(path, c.duration)))
	cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path, AnimProp.make(sp)))
	if want_start != cur_start:
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.start_path(target), AnimProp.make(want_start)))
	return cmds


func _write_inner_speed(c: Clip, path: String, value: Variant) -> bool:
	var d: Project = doc()
	var cmds: Array[Command] = inner_speed_cmds(c, path, value)
	if d == null or cmds.is_empty():
		return false
	if _dragging_field:
		for cmd: Command in cmds:
			d.undo.live(cmd)
		_live_label = "Set speed"
		return true
	Verbs.run(d, "Set speed", cmds)
	return true


func _speed_menu_items(path: String, keyable: bool) -> Array:
	if not keyable or not AnimTime.speed_able(path):
		return []
	var shown: bool = _open_speeds.has(_speed_key(path))
	var item: Dictionary = PmMenu.item(SHOW_SPEED_ID, "Hide the speed row" if shown else "Speed of this value", "", "rate")
	if shown and _speed_in_use(path):
		item["label"] = "Speed row stays while the speed is in use"
		item["disabled"] = true
	return [PmMenu.separator(), item]


func _inner_row_menu(id: String, path: String) -> bool:
	if id == SHOW_SPEED_ID:
		_toggle_speed_row(path)
		return true
	if id == "reset" and AnimTime.is_inner(path):
		reset_inner_speed(path)
		return true
	return false


static func speed_live(paths: PackedStringArray) -> bool:
	for p: String in paths:
		if AnimTime.is_inner(p) or p == AnimTime.SPEED_PATH or p == AnimTime.START_FIELD:
			return true
	return false


func _build_audio(c: Clip, t: Track) -> void:
	var f: VBoxContainer = _fold("Audio", "audio")
	var body: VBoxContainer = f.get("body")
	_add_section_speed(f, "audio", "Audio")
	_add_row(body, {"path": "audio.volume", "label": "Volume", "kind": "float", "min": 0.0, "max": 2.0, "step": 0.01, "suffix": " dB", "keyable": true, "db": true})
	if await _gate():
		return
	_add_row(body, {"path": "audio.pan", "label": "Pan", "kind": "float", "min": -1.0, "max": 1.0, "step": 0.01, "keyable": true})
	if await _gate():
		return
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m != null and m.audio_streams.size() > 1 and not _many_on:
		var choices: Array = []
		for i: int in m.audio_streams.size():
			choices.append(PmDrop.choice(str(i), StreamRoles.menu_label(m, i)))
		_add_row(body, {"path": "audio.stream", "label": "Stream", "kind": "enum", "field": "audio", "key": "stream", "choices": choices, "numeric": true})
		if await _gate():
			return
	elif _many_on:
		ManyButtons.stream_row(self, body)


func _build_masks(c: Clip) -> void:
	var f: VBoxContainer = _fold("Masks", "masks")
	var body: VBoxContainer = f.get("body")
	var row: HBoxContainer = PmUI.hbox()
	row.add_theme_constant_override("separation", Tk.px(Tk.sz("pad")))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(float(Tk.px(60.0)), 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for spec: Array in [["rect", "Rectangle", "grid"], ["ellipse", "Ellipse", "loop"]]:
		var b: Button = PmButton.make(String(spec[1]), String(spec[2]))
		b.set("quiet", true)
		PmUI.tip(b, "Add a centred " + String(spec[1]).to_lower() + " mask, then set its position and size below")
		b.pressed.connect(_on_add_mask.bind(String(spec[0])))
		row.add_child(b)
	body.add_child(row)
	_fit_lead_row(row, [spacer] as Array[Control], 2)
	var modes: Array = [PmDrop.choice("add", "Add"), PmDrop.choice("subtract", "Subtract"), PmDrop.choice("intersect", "Intersect")]
	for i: int in c.masks.size():
		var mask: Dictionary = c.masks[i]
		var mid: String = String(mask.get("id", ""))
		if RegionFxRows.hides_mask(c, mask):
			continue
		var mrow: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		mrow.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
		mrow.add_child(PmLabel.body(MaskShape.label_of(mask, i)))
		mrow.add_child(PmUI.spacer())
		var on: Button = toggle_icon("check", "Mask on", bool(mask.get("enabled", true)))
		on.pressed.connect(_on_mask_enabled.bind(i))
		mrow.add_child(on)
		var del: Button = quiet_icon("trash", "Remove mask")
		del.pressed.connect(_on_remove_mask.bind(i))
		mrow.add_child(del)
		body.add_child(mrow)
		if mid.is_empty():
			continue
		mrow.add_child(_section_speed_ui(body, "masks." + mid, MaskShape.label_of(mask, i), {}, 1))
		var base: String = "masks." + mid + "."
		_add_row(body, {"path": base + "mode", "label": "Mode", "kind": "enum", "choices": modes, "keyable": true, "indent": 1})
		if MaskShape.is_box(mask) and String(mask.get("region_of", "")).is_empty():
			_add_row(body, {"path": base + "centre", "label": "Position", "kind": "vec2", "step": 0.001, "display_mul": 100.0, "suffix": " %", "keyable": true, "indent": 1})
			_add_row(body, {"path": base + "size", "label": "Size", "kind": "vec2", "step": 0.001, "display_mul": 100.0, "suffix": " %", "keyable": true, "indent": 1})
			_add_row(body, {"path": base + "rotation", "label": "Rotation", "kind": "float", "step": 0.5, "suffix": " °", "keyable": true, "indent": 1})
		_add_row(body, {"path": base + "feather", "label": "Feather", "kind": "float", "min": 0.0, "max": 500.0, "step": 0.5, "suffix": " px", "keyable": true, "indent": 1})
		_add_row(body, {"path": base + "expand", "label": "Expand", "kind": "float", "min": -500.0, "max": 500.0, "step": 0.5, "suffix": " px", "keyable": true, "indent": 1})
		_add_row(body, {"path": base + "opacity", "label": "Opacity", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "indent": 1})
		_add_row(body, {"path": base + "invert", "label": "Invert", "kind": "bool", "keyable": true, "indent": 1})


func add_mask(kind: String) -> bool:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null or not MaskShape.BOX_KINDS.has(kind):
		return false
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	masks.append(MaskShape.make(kind, d.mint_id("mask")))
	return Verbs.run(d, "Add mask", [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)])


func _on_add_mask(kind: String) -> void:
	add_mask(kind)


func _on_mask_enabled(index: int) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null or index >= c.masks.size():
		return
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	var was: bool = bool(masks[index].get("enabled", true))
	masks[index]["enabled"] = not was
	Verbs.run(d, "Mask off" if was else "Mask on", [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)])


func _on_remove_mask(index: int) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or index >= c.masks.size():
		return
	var masks: Array[Dictionary] = c.masks.duplicate(true)
	masks.remove_at(index)
	Verbs.run(d, "Remove mask", [ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)])


func _build_effects(c: Clip) -> void:
	_build_stack(c, c.effects, "effects", false)
	var sounds: Array = c.audio_effects()
	if not sounds.is_empty() or Verbs.carries_sound(doc(), seq(), c):
		_build_stack(c, sounds, "audio_effects", true)


func _build_stack(c: Clip, entries: Array, prefix: String, sound: bool) -> void:
	for i: int in entries.size():
		_build_stack_entry(c, entries, i, prefix, sound)


func _mask_chip_text(c: Clip, e: Dictionary) -> String:
	var region_chip: String = RegionFxRows.chip_text(c, e)
	if not region_chip.is_empty():
		return region_chip
	var mask_label: String = String(e.get("mask", ""))
	var bound_at: int = MaskShape.index_of(c.masks, mask_label)
	if bound_at >= 0:
		mask_label = MaskShape.label_of(c.masks[bound_at], bound_at)
	return "Mask: " + (mask_label if not mask_label.is_empty() else "none")


func _shows_mask_edge(c: Clip, e: Dictionary) -> bool:
	if not RegionFxRows.chip_text(c, e).is_empty():
		return false
	return MaskShape.index_of(c.masks, String(e.get("mask", ""))) >= 0


func _mask_edge_row(c: Clip, e: Dictionary, uid: String) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox()
	row.name = "MaskEdge"
	var l: Label = PmLabel.trim("Mask edge")
	l.custom_minimum_size.x = _label_width("Mask edge", 0)
	row.add_child(l)
	var group: ButtonGroup = ButtonGroup.new()
	var spills: bool = Clip.mask_spills(e)
	var keep: Button = PmButton.make("Keep inside", "", true)
	keep.name = "KeepInside"
	keep.button_group = group
	keep.button_pressed = not spills
	PmUI.tip(keep, "The effect stops at the mask edge")
	keep.pressed.connect(_on_mask_edge.bind(c.id, uid, false))
	row.add_child(keep)
	var spill: Button = PmButton.make("Spill out", "", true)
	spill.name = "SpillOut"
	spill.button_group = group
	spill.button_pressed = spills
	PmUI.tip(spill, "Only the masked part gets the effect, but what the effect makes, such as glow, blur or colour fringes, may spread past the edge")
	spill.pressed.connect(_on_mask_edge.bind(c.id, uid, true))
	row.add_child(spill)
	return row


func _on_mask_edge(clip_id: String, uid: String, spill: bool) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null or Clip.mask_spills(c.effect_by_uid(uid)) == spill:
		return
	Verbs.run(doc(), "Spill out" if spill else "Keep inside", [EffectCmds.SetMaskMode.new(s.id, clip_id, uid, spill)])


func _build_stack_entry(c: Clip, entries: Array, index: int, prefix: String, sound: bool) -> void:
	var e: Dictionary = entries[index]
	var uid: String = String(e.get("uid", ""))
	var eid: String = String(e.get("id", ""))
	var def: Dictionary = EffectSource.get_def(eid)
	var title: String = String(def.get("label", eid))
	var f: VBoxContainer = _fold(title + (" (sound)" if sound else ""), ("afx." if sound else "fx.") + eid)
	var header: Button = f.get("header")
	header.set_meta("uid", uid)
	header.gui_input.connect(_on_header_input.bind(uid, header))
	PmUI.tip(header, "Right click for copy, paste, duplicate and reset")
	if not sound:
		MonitorHandles.add_switch(f, c, e)
	var bypass: Button = toggle_icon("check", "Effect on", bool(e.get("enabled", true)))
	bypass.pressed.connect(_on_bypass.bind(uid))
	f.call("add_right", bypass)
	var at: int = EffectOps.stack_index(c, uid, sound)
	var up: Button = quiet_icon("chev_u", "Move it earlier, so it runs before the ones above it")
	up.disabled = at <= 0
	up.pressed.connect(_on_effect_step.bind(uid, -1))
	f.call("add_right", up)
	var down: Button = quiet_icon("chev_d", "Move it later, so it runs after the ones below it")
	down.disabled = at < 0 or at >= entries.size() - 1
	down.pressed.connect(_on_effect_step.bind(uid, 1))
	f.call("add_right", down)
	var grip: Button = quiet_icon("list", "Hold the mouse down here and move to put this effect somewhere else in the stack")
	grip.name = "Grip"
	grip.set("icon_px", 12.0)
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.gui_input.connect(_on_grip_input.bind(grip))
	f.call("add_right", grip)
	if not sound:
		var chip: Button = PmButton.make(_mask_chip_text(c, e))
		chip.set("quiet", true)
		chip.pressed.connect(_on_mask_chip.bind(uid, chip))
		f.call("add_right", chip)
	var fx_drive: Button = PmButton.make("", "follow", true)
	fx_drive.name = "EffectDrive"
	fx_drive.set("quiet", true)
	fx_drive.set("icon_px", 12.0)
	fx_drive.set_meta("uid", uid)
	PmUI.tip(fx_drive, "Drive this effect from a sound, a picture or another value: its amount, or pick which of its values")
	fx_drive.button_pressed = effect_driven(c, uid, sound)
	fx_drive.pressed.connect(_on_effect_drive.bind(uid, sound, fx_drive))
	f.call("add_right", fx_drive)
	var trash: Button = quiet_icon("trash", "Remove effect")
	trash.pressed.connect(_on_remove_effect.bind(uid))
	f.call("add_right", trash)
	_add_section_speed(f, prefix + "." + uid, title)
	var slot: Control = PmSlot.make(PackedStringArray(["effect_reorder"]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set("draw_highlight", false)
	slot.set("can_accept_cb", _can_reorder_onto.bind(slot))
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.connect("dropped", _on_reorder_drop.bind(slot))
	slot.connect("hover_moved", _on_reorder_hover.bind(slot))
	slot.connect("hover_changed", _on_reorder_hover_changed.bind(slot))
	header.add_child(slot)
	var bar: Control = f.get_parent() as Control
	if bar != null:
		bar.draw.connect(_draw_reorder_mark.bind(bar))
	var body: VBoxContainer = f.get("body")
	if def.is_empty():
		body.add_child(PmLabel.dim("The effect \"" + eid + "\" is not installed, its values are kept"))
	var pairs: PackedStringArray = def.get("pairs_with", PackedStringArray())
	if not sound and not pairs.is_empty():
		body.add_child(_pair_note(c, e, pairs))
	if not sound and _shows_mask_edge(c, e):
		body.add_child(_mask_edge_row(c, e, uid))
	if await _build_value_rows(body, c, uid):
		return
	if eid == PuppetUi.TOOL_ID and not sound:
		body.add_child(PuppetUi.rows(c, e, _label_width("Pins", 0)))
	if eid == "pair_view" and not sound:
		await _build_regions(body, c, e)


func _build_value_rows(body: VBoxContainer, c: Clip, uid: String) -> bool:
	var items: Array[Dictionary] = value_items(c, uid)
	var by_key: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	for item: Dictionary in items:
		by_key[String(item["key"])] = item
		keys.append(String(item["key"]))
	var store: Dictionary = ValueStyle.store_of(self)
	var hidden: bool = ValueStyle.outside_allowed()
	var last_group: String = ""
	for key: String in ValueStyle.arrange(store, uid, keys):
		if not by_key.has(key):
			continue
		var item2: Dictionary = by_key[key]
		var spec: Dictionary = item2["spec"]
		if hidden and ValueStyle.is_outside(store, String(spec["path"])):
			continue
		var group: String = String(item2["group"])
		if group != last_group:
			last_group = group
			_add_group_label(body, group)
		_add_row(body, spec)
		if await _gate():
			return true
	return false


func _add_group_label(body: VBoxContainer, group: String) -> void:
	if group.is_empty():
		return
	var gl: Label = PmLabel.dim(group)
	var grow: HBoxContainer = PmUI.hbox(0)
	grow.add_child(_spacer(float(Tk.px(Tk.sz("button_h"))) + 4.0))
	grow.add_child(gl)
	body.add_child(grow)


func _effect_param_spec(p: Dictionary, path: String, uid: String, eid: String, sound: bool, e: Dictionary) -> Dictionary:
	var key: String = String(p.get("key", ""))
	var group: String = String(p.get("group", ""))
	var spec: Dictionary = {"path": path, "label": String(p.get("label", key)), "kind": String(p.get("type", "float")), "uid": uid, "key": key, "eid": eid, "keyable": bool(p.get("keyable", true)), "audio": sound, "fx_uid": uid, "fx_key": key}
	if not group.is_empty():
		spec["indent"] = 1
	if p.has("min"):
		spec["min"] = float(p["min"])
	if p.has("max"):
		spec["max"] = float(p["max"])
	var cap: float = _region_cap(eid, key, e)
	if cap >= 0.0:
		spec["max"] = cap
	spec["step"] = float(p.get("step", 0.1 if spec["kind"] == "float" else 1.0))
	var unit: String = String(p.get("unit", ""))
	if not unit.is_empty():
		spec["suffix"] = unit
	if spins(key, unit, float(spec.get("min", -INF)), float(spec.get("max", INF))) and String(spec["kind"]) == "float":
		spec["turns"] = true
		spec["reach"] = true
	if p.has("choices"):
		var choices: Array = []
		var raw: Array = p["choices"]
		for i: int in raw.size():
			choices.append(PmDrop.choice(str(i), String(raw[i])))
		spec["choices"] = choices
		spec["numeric"] = true
	return spec


func _region_cap(eid: String, key: String, e: Dictionary) -> float:
	if eid == "pair_view" and key == "view":
		return maxf(float(_crops_of(e).size() - 1), 0.0)
	if eid == "grid" and key.begins_with("c") and key.ends_with("_crop"):
		var partner: Dictionary = _paired_entry(e, "pair_view")
		if partner.is_empty():
			return -1.0
		return maxf(float(_crops_of(partner).size()), 0.0)
	return -1.0


func _paired_entry(e: Dictionary, want: String) -> Dictionary:
	var c: Clip = target_clip()
	if c == null:
		return {}
	var at: int = -1
	for i: int in c.effects.size():
		if String(c.effects[i].get("uid", "")) == String(e.get("uid", "")):
			at = i
	for j: int in range(at - 1, -1, -1):
		var other: Dictionary = c.effects[j]
		if String(other.get("id", "")) == want and bool(other.get("enabled", true)):
			return other
	return {}


func _pair_note(c: Clip, e: Dictionary, pairs: PackedStringArray) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	var idx: int = c.effects.find(e)
	var partner: Dictionary = {}
	for k: int in range(idx - 1, -1, -1):
		var other: Dictionary = c.effects[k]
		if bool(other.get("enabled", true)) and pairs.has(String(other.get("id", ""))):
			partner = other
			break
	if partner.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for pid: String in pairs:
			names.append(String(EffectSource.get_def(pid).get("label", pid)))
		row.add_child(PmLabel.dim("Add " + ", ".join(names) + " above this effect to feed it"))
		var add: Button = PmButton.make("Add " + names[0])
		add.set("quiet", true)
		add.pressed.connect(_on_add_partner.bind(c.id, String(e.get("uid", "")), pairs[0]))
		row.add_child(add)
	else:
		var crops: Array = _crops_of(partner)
		var pl: String = String(EffectSource.get_def(String(partner.get("id", ""))).get("label", partner.get("id", "")))
		row.add_child(PmLabel.dim("Paired with " + pl + (" (" + str(crops.size()) + " regions)" if not crops.is_empty() else "")))
	return row


func _on_add_partner(clip_id: String, uid: String, partner_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	var def: Dictionary = EffectSource.get_def(partner_id)
	if c == null or def.is_empty():
		return
	var at: int = -1
	for k: int in c.effects.size():
		if String(c.effects[k].get("uid", "")) == uid:
			at = k
	Verbs.add_effect(d, s, PackedStringArray([clip_id]), def, at)


func _crops_of(e: Dictionary) -> Array:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("crops", null)
	var text: String = ""
	if raw is Dictionary:
		text = String(AnimProp.static_value(raw))
	var out: Array = []
	for cr: Dictionary in LayerChain.parse_crops(text):
		var r: Rect2 = cr["rect"]
		out.append({"name": String(cr["name"]), "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "rot": float(cr.get("rot", 0.0)), "auto": bool(cr.get("auto", false))})
		if bool(cr.get(PairLayouts.PairLayout.OUT_KEY, false)):
			(out[out.size() - 1] as Dictionary)[PairLayouts.PairLayout.OUT_KEY] = true
		PairLayouts.PairLayout.PairCrop.carry(out[out.size() - 1], cr)
	return out


func region_points(cr: Dictionary) -> Array:
	var r: Array = cr.get("rect", [0.0, 0.0, 1.0, 1.0])
	var box: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var ang: float = deg_to_rad(float(cr.get("rot", 0.0)))
	var mid: Vector2 = box.get_center()
	var half: Vector2 = box.size * 0.5
	var out: Array = []
	for sgn: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		var p: Vector2 = mid + (half * sgn).rotated(ang)
		out.append([p.x, p.y])
	return out


func _synced_masks(c: Clip, uid: String, crops: Array, remap: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = c.masks.duplicate(true)
	for m: Dictionary in out:
		if String(m.get("region_of", "")) != uid:
			continue
		var was: int = int(m.get("region_index", -1))
		var now: int = int(remap.get(was, was)) if remap.has(was) else was
		m["region_index"] = now
		if now < 0 or now >= crops.size():
			m["region_index"] = -1
			m["label"] = String(m.get("label", "Region")) + " (region gone)"
			continue
		var cr: Dictionary = crops[now]
		m["points"] = region_points(cr)
		m["label"] = String(cr.get("name", ""))
	return out


func _write_crops(uid: String, crops: Array, label: String, remap: Dictionary = {}) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	var cmds: Array[Command] = []
	var cmd: Command = EffectCmds.SetEffectParam.new(s.id, c.id, uid, "crops", JSON.stringify(crops), -1.0)
	cmd.label = label
	cmds.append(cmd)
	var masks: Array[Dictionary] = _synced_masks(c, uid, crops, remap)
	if masks != c.masks:
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	cmds.append_array(_offset_remap(c, uid, remap))
	cmds.append_array(PvGroups.remap_cmds(s, c, uid, crops.size(), remap))
	Verbs.run(d, label, cmds)


func _build_regions(body: VBoxContainer, c: Clip, e: Dictionary) -> bool:
	var uid: String = String(e.get("uid", ""))
	var crops: Array = _crops_of(e)
	body.add_child(PairLayouts.header_row(c, e, float(Tk.px(Tk.sz("button_h")))))
	var head: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	head.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	head.add_child(PmLabel.dim("Regions (View picks one by its number, 0 is the first)"))
	head.add_child(PmUI.spacer())
	var add: Button = PmButton.make("Add region", "plus")
	add.set("quiet", true)
	add.pressed.connect(_on_add_crop.bind(uid))
	head.add_child(add)
	var save: Button = PmButton.make("Save as preset")
	save.set("quiet", true)
	PmUI.tip(save, "Saves this Pair View with its regions and values as an effect preset")
	save.pressed.connect(_on_save_regions.bind(uid))
	head.add_child(save)
	body.add_child(head)
	var tip_row: HBoxContainer = PmUI.hbox(0)
	tip_row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	tip_row.add_child(PmLabel.dim("Drop an effect on a region to apply it inside that region only"))
	body.add_child(tip_row)
	body.add_child(PvGroups.row({c.id: uid}, float(Tk.px(Tk.sz("button_h")))))
	for i: int in crops.size():
		var cr: Dictionary = crops[i]
		var rect: Array = cr["rect"]
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
		var thumb: Control = _RegionThumb.new()
		thumb.set("clip_id", c.id)
		thumb.set("region", Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
		thumb.custom_minimum_size = Vector2(float(Tk.px(44.0)), float(Tk.px(26.0)))
		row.add_child(thumb)
		row.add_child(PmLabel.mono(str(i), "text_faint"))
		var name_edit: LineEdit = PmUI.line_edit("Name", String(cr["name"]))
		name_edit.custom_minimum_size.x = float(Tk.px(96.0))
		name_edit.text_submitted.connect(_on_crop_name.bind(uid, i))
		name_edit.focus_exited.connect(_on_crop_name_left.bind(name_edit, uid, i))
		row.add_child(name_edit)
		for k: int in 4:
			var f: Control = PmField.make(float(rect[k]) * 100.0, 0.0, 100.0, 0.5, " %")
			f.set("precision", 1)
			f.custom_minimum_size.x = float(Tk.px(64.0))
			f.connect("value_changed", _on_crop_number.bind(uid, i, k))
			PmUI.tip(f, ["Left", "Top", "Width", "Height"][k])
			row.add_child(f)
		var rot_field: Control = PmField.make(float(cr.get("rot", 0.0)), -180.0, 180.0, 1.0, " deg")
		rot_field.set("precision", 1)
		rot_field.custom_minimum_size.x = float(Tk.px(78.0))
		rot_field.connect("value_changed", _on_crop_number.bind(uid, i, 4))
		PmUI.tip(rot_field, "Turn this region, so a tilted part of the picture comes out straight")
		row.add_child(rot_field)
		var place: Button = PmButton.make("Place", "target")
		place.set("quiet", true)
		PmUI.tip(place, "Draw this region on the Program monitor, F11 for full screen")
		place.pressed.connect(_on_crop_place.bind(uid, i))
		row.add_child(place)
		var up: Button = quiet_icon("chev_u", "Move up")
		up.disabled = i == 0
		up.pressed.connect(_on_crop_move.bind(uid, i, -1))
		row.add_child(up)
		var down: Button = quiet_icon("chev_d", "Move down")
		down.disabled = i == crops.size() - 1
		down.pressed.connect(_on_crop_move.bind(uid, i, 1))
		row.add_child(down)
		var del: Button = quiet_icon("trash", "Remove region")
		del.disabled = crops.size() <= 1
		del.pressed.connect(_on_crop_remove.bind(uid, i))
		row.add_child(del)
		PairLayouts.decorate_row(row, c, uid, i, name_edit)
		var wrap: MarginContainer = MarginContainer.new()
		wrap.add_child(row)
		var slot: Control = PmSlot.make(PackedStringArray(["effect"]))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.connect("dropped", _on_region_effect_drop.bind(uid, i))
		slot.set("priority", 1)
		wrap.add_child(slot)
		body.add_child(wrap)
		body.add_child(PvCropRows.make(c, uid, i, float(Tk.px(Tk.sz("button_h"))) * 2.0))
		body.add_child(RegionFxRows.make(c, uid, i, float(Tk.px(Tk.sz("button_h"))) * 2.0))
		if PairLayouts.PairLayout.solo_of(e) < 0:
			body.add_child(_view_audio_row(c, uid, i) if not PvStreamRows.on(e) else PvStreamRows.view_row(self, c, uid, i))
		_add_offset_row(body, uid, i)
		_add_place_rows(body, c, e, uid, i)
		if await _gate():
			return true
	if PairLayouts.PairLayout.solo_of(e) < 0:
		PvStreamRows.add_rows(self, body, c, e)
	body.add_child(PvAudio.always_row({c.id: uid}, float(Tk.px(Tk.sz("button_h")))))
	_add_shared_sound_row(body, c, e)
	body.add_child(_view_tools_row(uid))
	return false


func _view_tools_row(uid: String) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	row.add_child(PmUI.spacer())
	row.add_child(_views_panel_button())
	var tidy: Button = PmButton.make("Rearrange tracks", "list")
	tidy.set("quiet", true)
	PmUI.tip(tidy, "Move this clip's audio so the views read top to bottom in view order")
	tidy.pressed.connect(_on_view_rearrange.bind(uid))
	row.add_child(tidy)
	row.add_child(_view_cuts_button(uid))
	row.add_child(_drop_on_view_button(uid))
	row.add_child(PvOffsetEditor.button(self, uid))
	row.add_child(_sync_button(uid))
	return row


const PvStreamRows := preload("res://modules/core_panels/view_stream_rows.gd")
const PvAudio := preload("res://modules/core_panels/pv_audio.gd")
const PvOffsetEditor := preload("res://modules/core_panels/offset_editor.gd")


func _views_panel_button() -> Button:
	var b: Button = PmButton.make("Views panel", "grid")
	b.set("quiet", true)
	b.name = "ViewsPanelButton"
	PmUI.tip(b, "One button per view: click one to switch to it, with Record on it keys the switch at the playhead", Cmd.keys_text("clip.views_panel"))
	b.pressed.connect(func() -> void: Cmd.run("clip.views_panel"))
	return b


func _on_view_rearrange(uid: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	if not Verbs.rearrange_view_audio(d, s, c.id, uid):
		Events.toast("Nothing to rearrange, or a clip is in the way of the move")


const PvCuts := preload("res://modules/core_panels/pair_view_cuts.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const RegionFxCmds := preload("res://doc/commands/region_fx_cmds.gd")
const RegionFxRows := preload("res://modules/core_panels/region_fx_rows.gd")
const PvCropRows := preload("res://modules/core_panels/pv_crop_rows.gd")
const MonitorHandles := preload("res://modules/core_panels/monitor_handles.gd")
const EffectHandlesUi := preload("res://modules/core_panels/effect_handles_ui.gd")


func _view_cuts_button(uid: String) -> Button:
	var c: Clip = target_clip()
	var on: bool = c != null and PvMap.cuts_on(c.effect_by_uid(uid))
	var b: Button = PmButton.make(PvCuts.LABEL, "razor", true)
	b.set("quiet", true)
	b.set_pressed_no_signal(on)
	PmUI.tip(b, PvCuts.TIP, Cmd.keys_text(PvCuts.TOGGLE_ID))
	b.toggled.connect(_on_view_cuts_toggled.bind(uid))
	return b


func _drop_on_view_button(uid: String) -> Button:
	var c: Clip = target_clip()
	var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
	var b: Button = PmButton.make("Drop on the view", "fx", true)
	b.name = "DropOnView"
	b.set("quiet", true)
	b.set_pressed_no_signal(RegionFxCmds.drops_on_view(e))
	b.visible = PvMap.cuts_on(e)
	PmUI.tip(b, "With Cut on view changes on, an effect dragged onto this clip on the timeline goes on the view showing where it is dropped, not the whole clip. Settings, Pair, can turn this on for every Pair View")
	b.toggled.connect(_on_drop_on_view_toggled.bind(uid))
	return b


func _on_drop_on_view_toggled(on: bool, uid: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null or c.effect_by_uid(uid).is_empty():
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if not ids.has(c.id):
		ids = PackedStringArray([c.id])
	var cmds: Array[Command] = []
	for id: String in ids:
		var pc: Clip = s.clip_by_id(id)
		var pe: Dictionary = RegionFx.first_pair(pc) if pc != null else {}
		if pe.is_empty():
			continue
		var cmd: Command = EffectCmds.SetEffectParam.new(s.id, id, String(pe.get("uid", "")), RegionFxCmds.DROP_KEY, on)
		cmd.label = "Dropped effects go on the view"
		cmds.append(cmd)
	if not cmds.is_empty():
		Verbs.run(d, "Dropped effects go on the view", cmds)


func _on_view_cuts_toggled(on: bool, uid: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null or c.effect_by_uid(uid).is_empty():
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if not ids.has(c.id):
		ids = PackedStringArray([c.id])
	PvCuts.set_on(d, s, ids, on)


func _view_audio_of(e: Dictionary) -> Dictionary:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("view_audio", null)
	if not (raw is Dictionary):
		return {}
	var text: String = String(AnimProp.static_value(raw)).strip_edges()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _view_map_for(uid: String, count: int) -> Dictionary:
	var c: Clip = target_clip()
	if c == null:
		return {}
	var map: Dictionary = _view_audio_of(c.effect_by_uid(uid))
	if map.is_empty():
		map = {"v": 1, "scope": "group", "views": []}
	var views: Array = map.get("views", [])
	while views.size() < count:
		views.append({"tracks": [], "clips": [], "colour": -1})
	while views.size() > count:
		views.remove_at(views.size() - 1)
	map["views"] = views
	return map


func _write_view_audio(uid: String, map: Dictionary, label: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	var cmd: Command = EffectCmds.SetEffectParam.new(s.id, c.id, uid, "view_audio", JSON.stringify(map), -1.0)
	cmd.label = label
	Verbs.run(d, label, [cmd])


func _view_audio_row(c: Clip, uid: String, index: int) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")) + Tk.px(48.0))))
	row.add_child(PmLabel.dim("Hears"))
	var s: Sequence = seq()
	if s == null:
		return row
	var map: Dictionary = _view_map_for(uid, _crops_of(c.effect_by_uid(uid)).size())
	var views: Array = map.get("views", [])
	var mine: Dictionary = views[index] if index < views.size() else {"tracks": []}
	var on: Array = mine.get("tracks", [])
	for tr: Track in s.sound_carriers():
		var chip: Button = PmButton.make(tr.shown_label(), "audio")
		chip.set("quiet", true)
		chip.toggle_mode = true
		chip.button_pressed = on.has(tr.id)
		PmUI.tip(chip, "Hear " + tr.shown_label() + " while this view is on screen")
		chip.toggled.connect(_on_view_track_toggled.bind(uid, index, tr.id))
		row.add_child(chip)
	row.add_child(PmUI.spacer())
	var scope: Button = PmButton.make("Only this group" if String(map.get("scope", "group")) == "group" else "Every track", "link")
	scope.set("quiet", true)
	PmUI.tip(scope, "Whether the views reach only the audio linked to this clip, or every audio track")
	scope.pressed.connect(_on_view_scope.bind(uid))
	if index == 0:
		row.add_child(scope)
	return row


func _on_view_track_toggled(on: bool, uid: String, index: int, track_id: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var map: Dictionary = _view_map_for(uid, _crops_of(c.effect_by_uid(uid)).size())
	var views: Array = map.get("views", [])
	if index >= views.size():
		return
	var mine: Dictionary = views[index]
	var list: Array = mine.get("tracks", [])
	var at: int = list.find(track_id)
	if on and at < 0:
		list.append(track_id)
	elif not on and at >= 0:
		list.remove_at(at)
	mine["tracks"] = list
	_write_view_audio(uid, map, "View audio")


func _on_view_scope(uid: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var map: Dictionary = _view_map_for(uid, _crops_of(c.effect_by_uid(uid)).size())
	map["scope"] = "all" if String(map.get("scope", "group")) == "group" else "group"
	_write_view_audio(uid, map, "View audio reach")


const PvSync := preload("res://modules/core_panels/pair_sync.gd")
const PvCmds := preload("res://doc/commands/pair_cmds.gd")
const PvMap := preload("res://doc/view_map.gd")
const PairLayouts := preload("res://modules/core_panels/pair_layouts.gd")


func _add_place_rows(body: VBoxContainer, c: Clip, e: Dictionary, uid: String, index: int) -> void:
	if not PairLayouts.shows_place(c, e):
		return
	var solo: int = PairLayouts.PairLayout.solo_of(e)
	if solo >= 0 and solo != index:
		return
	var pk: String = PairLayouts.PairLayout.place_key(index)
	_add_row(body, {"path": "effects." + uid + "." + pk, "label": "On screen at", "kind": "vec2", "uid": uid, "key": pk, "eid": "pair_view", "keyable": true, "min": PairLayouts.PairLayout.PLACE_MIN, "max": PairLayouts.PairLayout.PLACE_MAX, "step": 0.001, "display_mul": 100.0, "suffix": " %", "indent": 1})
	var sk: String = PairLayouts.PairLayout.size_key(index)
	_add_row(body, {"path": "effects." + uid + "." + sk, "label": "On screen size", "kind": "float", "uid": uid, "key": sk, "eid": "pair_view", "keyable": true, "min": PairLayouts.PairLayout.SIZE_MIN, "max": PairLayouts.PairLayout.SIZE_MAX, "step": 0.001, "display_mul": 100.0, "suffix": " %", "indent": 1})
	_add_row(body, {"path": "effects." + uid + ".turn" + str(index), "label": "Turn", "kind": "float", "uid": uid, "key": "turn" + str(index), "eid": "pair_view", "keyable": true, "min": -180.0, "max": 180.0, "step": 0.1, "suffix": " deg", "indent": 1})


var _pv_sync_btns: Dictionary = {}
var _pv_eyes: Dictionary = {}
var _pv_sync_seen: String = ""


func _pv_sync_key() -> String:
	var st: RefCounted = PvSync.state()
	if not bool(st.call("active")):
		return ""
	return String(st.get("clip_id")) + "|" + String(st.get("uid"))


func _add_offset_row(body: VBoxContainer, uid: String, index: int) -> void:
	var ms: bool = PvSync.unit() == "ms"
	var key: String = PvMap.offset_key(index)
	_add_row(body, {"path": "effects." + uid + "." + key, "label": "Offset", "kind": "float", "uid": uid, "key": key, "eid": "pair_view", "keyable": true, "min": -PvMap.OFFSET_MAX, "max": PvMap.OFFSET_MAX, "step": 0.001 if ms else 0.01, "suffix": " ms" if ms else " s", "display_mul": 1000.0 if ms else 1.0, "indent": 1})
	var rec: Dictionary = _rows[_rows.size() - 1]
	var editors: Array = rec["editors"]
	if not editors.is_empty():
		var f: Control = editors[0]
		f.set("precision", 1 if ms else 3)
		PmUI.tip(f, "Moves this region's picture and sound in time. Positive plays it later, negative earlier")
	var row: Container = rec["row"]
	var extra: HBoxContainer = PmUI.hbox(0)
	for u: String in ["ms", "s"]:
		var b: Button = PmButton.make(u, "", true)
		b.set("quiet", true)
		b.set_pressed_no_signal((u == "ms") == ms)
		PmUI.tip(b, "Show offsets in milliseconds" if u == "ms" else "Show offsets in seconds")
		b.pressed.connect(_on_offset_unit.bind(u))
		extra.add_child(b)
	var c: Clip = target_clip()
	if c != null and PvSync.active_for(c.id, uid):
		var hidden: bool = bool(PvSync.state().call("is_hidden", index))
		var eye: Button = PmButton.make("", "eye_off" if hidden else "eye", true)
		eye.set("quiet", true)
		eye.set_pressed_no_signal(hidden)
		PmUI.tip(eye, "Hide this region from the picture and its sound from playback while syncing")
		eye.pressed.connect(_on_offset_eye.bind(index, eye))
		extra.add_child(eye)
		_pv_eyes[uid + "|" + str(index)] = eye
	if not editors.is_empty() and (editors[0] as Control).get_parent() != null:
		(editors[0] as Control).get_parent().add_child(extra)
		return
	row.add_child(extra)
	row.move_child(extra, row.get_child_count() - 2)


func _on_offset_unit(u: String) -> void:
	PvSync.set_unit(u)


func _on_offset_eye(index: int, eye: Button) -> void:
	PvSync.state().call("set_hidden", index, eye.button_pressed)


func _offset_remap(c: Clip, uid: String, remap: Dictionary) -> Array[Command]:
	var out: Array[Command] = []
	var s: Sequence = seq()
	var e: Dictionary = c.effect_by_uid(uid)
	if remap.is_empty() or e.is_empty() or s == null:
		return out
	var moved: Dictionary = {}
	for old: Variant in remap.keys():
		var now: int = int(remap[old])
		if now >= 0 and now < PvMap.REGION_MAX:
			moved[now] = PvMap.offset_prop(e, int(old))
	for old2: Variant in remap.keys():
		if int(remap[old2]) < 0 and int(old2) < PvMap.REGION_MAX and not moved.has(int(old2)):
			moved[int(old2)] = {}
	for n: Variant in moved.keys():
		var want: Dictionary = moved[n]
		var have: Dictionary = PvMap.offset_prop(e, int(n))
		if want == have or (want.is_empty() and not PvMap.has_offset(e, int(n))):
			continue
		out.append(ClipCmds.SetClipParam.new(s.id, c.id, "effects." + uid + "." + PvMap.offset_key(int(n)), want if not want.is_empty() else AnimProp.make(0.0)))
	return out


func _add_shared_sound_row(body: VBoxContainer, c: Clip, e: Dictionary) -> void:
	var s: Sequence = seq()
	var map: Dictionary = PvMap.of(e)
	if s == null or map.is_empty():
		return
	var shared: Array[Dictionary] = PvMap.shared_sounds(map, s, c)
	if shared.is_empty():
		return
	var names: PackedStringArray = PvMap.region_names(e)
	var first: Dictionary = shared[0]
	var tr: Track = first["track"]
	var who: PackedStringArray = PackedStringArray()
	for v: int in first["views"]:
		who.append(names[v] if v < names.size() else "View " + str(v + 1))
	var text: String = tr.label + " is heard by " + " and ".join(who) + ", so it follows the offset of the view shown at each moment"
	if shared.size() > 1:
		text += ". " + str(shared.size() - 1) + (" more sound is" if shared.size() == 2 else " more sounds are") + " shared too"
	var note: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	note.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	var l: Label = PmLabel.trim(text, "text_dim")
	PmUI.tip(l, text)
	note.add_child(l)
	body.add_child(note)
	if PvStreamRows.ViewStreams.on(map):
		return
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	row.add_child(PmUI.spacer())
	var split: Button = PmButton.make("Give each view its own copy of this sound", "plus")
	split.set("quiet", true)
	PmUI.tip(split, "Copies each shared sound onto a new track for every other view that hears it, so each view's copy follows its own offset")
	split.pressed.connect(_on_split_sound.bind(String(e.get("uid", ""))))
	row.add_child(split)
	body.add_child(row)


func _on_split_sound(uid: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	if not Verbs.run(d, "Give each view its own sound", [PvCmds.SplitSharedSound.new(s.id, c.id, uid)]):
		Events.toast("Nothing to copy, or the tracks are locked")


func _sync_button(uid: String) -> Button:
	var c: Clip = target_clip()
	var on: bool = c != null and PvSync.active_for(c.id, uid)
	var b: Button = PmButton.make("Stop syncing" if on else "Sync regions", "slide", true)
	b.set("quiet", true)
	b.set_pressed_no_signal(on)
	PmUI.tip(b, "Line the regions up on their own timeline. Press again or Escape to go back", Cmd.keys_text(PvSync.COMMAND_ID))
	b.pressed.connect(_on_sync_regions.bind(uid))
	_pv_sync_btns[uid] = b
	_pv_sync_seen = _pv_sync_key()
	var st: RefCounted = PvSync.state()
	if not st.is_connected("changed", _on_pair_sync_changed):
		st.connect("changed", _on_pair_sync_changed)
	return b


func _on_sync_regions(uid: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	PvSync.toggle(c.id, uid)
	_on_pair_sync_changed()


func _on_pair_sync_changed() -> void:
	if not _alive():
		return
	if _pv_sync_key() != _pv_sync_seen:
		_pv_sync_seen = _pv_sync_key()
		rebuild()
		return
	var c: Clip = target_clip()
	var st: RefCounted = PvSync.state()
	for uid: Variant in _pv_sync_btns.keys():
		var b: Variant = _pv_sync_btns[uid]
		if not is_instance_valid(b):
			_pv_sync_btns.erase(uid)
			continue
		var on: bool = c != null and PvSync.active_for(c.id, String(uid))
		(b as Button).set_pressed_no_signal(on)
		(b as Button).text = "Stop syncing" if on else "Sync regions"
	for key: Variant in _pv_eyes.keys():
		var eye: Variant = _pv_eyes[key]
		if not is_instance_valid(eye):
			_pv_eyes.erase(key)
			continue
		var index: int = int(String(key).get_slice("|", 1))
		var hidden: bool = bool(st.call("is_hidden", index))
		(eye as Button).set_pressed_no_signal(hidden)
		(eye as Button).set("icon_name", "eye_off" if hidden else "eye")


class _RegionThumb:
	extends Control

	var clip_id: String = ""
	var region: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_process(true)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _source_texture() -> Texture2D:
		var comp: Node = Session.compositor
		if comp == null:
			return null
		var layers: Variant = comp.get("layers")
		if not (layers is Dictionary) or not (layers as Dictionary).has(clip_id):
			return null
		var l: Node = (layers as Dictionary)[clip_id]
		var src: Variant = l.get("source")
		if src == null or not (src as Object).has_method("texture"):
			return null
		return (src as Object).call("texture")

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Tk.c["bg_field"], true)
		var tex: Texture2D = _source_texture()
		if tex == null:
			return
		var ts: Vector2 = tex.get_size()
		var src: Rect2 = Rect2(region.position * ts, region.size * ts)
		if src.size.x < 1.0 or src.size.y < 1.0:
			return
		var aspect: float = src.size.x / src.size.y
		var dst: Rect2 = r
		if r.size.x / r.size.y > aspect:
			dst.size.x = r.size.y * aspect
			dst.position.x = (r.size.x - dst.size.x) * 0.5
		else:
			dst.size.y = r.size.x / aspect
			dst.position.y = (r.size.y - dst.size.y) * 0.5
		draw_texture_rect_region(tex, dst, src)


func _on_save_regions(uid: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty():
		return
	var fields: Array[Dictionary] = [
		{"key": "name", "label": "Preset name", "type": "string", "default": "Pair View " + str(_crops_of(e).size()) + " regions"},
		{"key": "with_clips", "label": "Also save the clips", "type": "bool", "default": false},
		{"key": "to_library", "label": "Keep it for every project", "type": "bool", "default": false},
		{"key": "note", "label": "", "type": "note", "default": _save_summary(c, e)},
	]
	var answered: Signal = PmUI.form(_root, "Save Pair View preset", fields, "Save", "Cancel")
	answered.connect(_on_save_regions_answered.bind(uid))


func _save_summary(c: Clip, e: Dictionary) -> String:
	var s: Sequence = seq()
	var crops: Array = _crops_of(e)
	var turned: int = 0
	for cr: Variant in crops:
		if absf(float((cr as Dictionary).get("rot", 0.0))) > 0.01:
			turned += 1
	var parts: PackedStringArray = PackedStringArray()
	parts.append("Saves " + str(crops.size()) + (" region" if crops.size() == 1 else " regions"))
	if turned > 0:
		parts.append(str(turned) + " of them turned")
	parts.append("and every value on this Pair View")
	var keyed: int = 0
	for k: Variant in (e.get("params", {}) as Dictionary).keys():
		if AnimProp.is_animated((e["params"] as Dictionary)[k]):
			keyed += 1
	if keyed > 0:
		parts.append("with keyframes on " + str(keyed) + (" value" if keyed == 1 else " values"))
	var summary: String = ", ".join(parts) + "."
	if s != null:
		var family: PackedStringArray = s.expand_selection(PackedStringArray([c.id]))
		var others: int = maxi(family.size() - 1, 0)
		summary += " With the clips ticked it also saves this clip"
		if others > 0:
			summary += " and the " + str(others) + (" clip" if others == 1 else " clips") + " linked to it"
		summary += ", " + String.num(c.duration, 1) + " s, so the footage comes back with it."
	return summary


func _on_save_regions_answered(result: Variant, uid: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	if c == null or d == null:
		return
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty():
		return
	var name_: String = String((result as Dictionary).get("name", "")).strip_edges()
	if name_.is_empty():
		name_ = "Pair View"
	var s: Sequence = seq()
	var opts: Dictionary = result
	var with_clips: bool = bool(opts.get("with_clips", false))
	var to_library: bool = bool(opts.get("to_library", false))
	var preset: Dictionary = Presets.effect_from_entry(e, name_)
	if with_clips and s != null:
		var keep: PackedStringArray = s.selected_clip_ids.duplicate()
		Verbs.select(d, s, s.expand_selection(PackedStringArray([c.id])), "replace")
		var cb: Dictionary = Verbs.copy(d, s)
		Verbs.select(d, s, keep, "replace")
		if (cb.get("clips", []) as Array).is_empty():
			Events.warn("Nothing to save", "The clips could not be copied, the preset holds the effect only.")
		else:
			preset = Presets.make("composition", name_, {"clips": cb["clips"], "span": float(cb.get("span", 0.0)), "from": "pair_view"})
	var saved: bool = Presets.save_to_user(preset) if to_library else Presets.save_to_project(d, preset)
	if saved:
		var where: String = "your preset library" if to_library else "this project's presets"
		var what: String = "with its clips" if with_clips else "as an effect"
		Events.notice("Preset saved", name_ + " is in " + where + " " + what + ".")


func region_mask_id(c: Clip, uid: String, index: int) -> String:
	for m: Dictionary in c.masks:
		if String(m.get("region_of", "")) == uid and int(m.get("region_index", -1)) == index:
			return String(m.get("id", ""))
	return ""


func _on_region_effect_drop(payload: Dictionary, _local: Vector2, uid: String, index: int) -> void:
	if String(payload.get("kind", "")) != "effect":
		return
	var id: String = String(payload.get("id", ""))
	var def: Dictionary = EffectSource.get_def(id)
	var why: String = RegionFx.refusal(def)
	if not why.is_empty():
		Events.toast(why)
		return
	if add_effect_to_region(uid, index, def):
		EffectSource.note_used(id)


func add_effect_to_region(uid: String, index: int, def: Dictionary) -> bool:
	var c: Clip = target_clip()
	if c == null or doc() == null or seq() == null or def.is_empty():
		return false
	return RegionFxCmds.add(doc(), seq(), c, uid, index, def)


func _on_add_crop(uid: String) -> void:
	set_region_count(uid, _crops_of(target_clip().effect_by_uid(uid)).size() + 1 if target_clip() != null else 1)


func set_region_count(uid: String, want: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	var n: int = clampi(want, 1, REGION_MAX)
	if n == crops.size():
		return
	_write_crops(uid, LayerChain.resplit(crops, n), "Views" if n > crops.size() else "Fewer views")


func _on_region_count(v: float, uid: String) -> void:
	set_region_count(uid, int(round(v)))


func _on_crop_name(text: String, uid: String, index: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	if index < crops.size() and String((crops[index] as Dictionary)["name"]) != text:
		(crops[index] as Dictionary)["name"] = text
		_write_crops(uid, crops, "Rename region")


func _on_crop_name_left(edit: LineEdit, uid: String, index: int) -> void:
	_on_crop_name(edit.text, uid, index)


func _on_crop_number(v: float, uid: String, index: int, k: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	if index >= crops.size():
		return
	var cr: Dictionary = crops[index]
	cr["auto"] = false
	if k == 4:
		cr["rot"] = clampf(v, -180.0, 180.0)
		_write_crops(uid, crops, "Region turn")
		return
	var rect: Array = cr["rect"]
	rect[k] = clampf(v / 100.0, 0.0, 1.0)
	if k >= 2:
		rect[k] = maxf(float(rect[k]), 0.005)
	_write_crops(uid, crops, "Region " + ["left", "top", "width", "height"][k])


func _on_crop_move(uid: String, index: int, dir: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	var j: int = index + dir
	if index < 0 or index >= crops.size() or j < 0 or j >= crops.size():
		return
	var tmp: Variant = crops[index]
	crops[index] = crops[j]
	crops[j] = tmp
	_write_crops(uid, crops, "Reorder regions", {index: j, j: index})


func _on_crop_remove(uid: String, index: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	if crops.size() <= 1 or index >= crops.size():
		return
	crops.remove_at(index)
	var remap: Dictionary = {index: -1}
	for k: int in range(index + 1, index + 1 + crops.size()):
		remap[k] = k - 1
	_write_crops(uid, crops, "Remove region", remap)


func _on_crop_place(uid: String, index: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	if index >= crops.size():
		return
	var prog: Object = bus().panel("program")
	if prog == null or not prog.has_method("begin_region_placement"):
		Events.toast("Open the Program monitor to place a region")
		return
	var rect: Array = (crops[index] as Dictionary)["rect"]
	Cmd.run("window.focus_program")
	prog.call("begin_region_placement", c.id, uid, Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])), String((crops[index] as Dictionary)["name"]), _on_crop_placed.bind(uid, index), float((crops[index] as Dictionary).get("rot", 0.0)))


func _on_crop_placed(rect: Rect2, angle: float, uid: String, index: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var crops: Array = _crops_of(c.effect_by_uid(uid))
	if index >= crops.size():
		return
	(crops[index] as Dictionary)["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	(crops[index] as Dictionary)["rot"] = wrapf(angle, -180.0, 180.0)
	(crops[index] as Dictionary)["auto"] = false
	_write_crops(uid, crops, "Place region")


func _on_bypass(uid: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null:
		return
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	Verbs.run(d, "Effect on", [EffectCmds.SetEffectEnabled.new(s.id, c.id, uid, not bool(e.get("enabled", true)), sound)])


func _on_remove_effect(uid: String) -> void:
	var c: Clip = target_clip()
	if c != null:
		Verbs.remove_effect(doc(), seq(), c.id, uid)


func _on_header_input(event: InputEvent, uid: String, header: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			header.accept_event()
			open_effect_menu(uid, header)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not mb.double_click:
			if EffectHandlesUi.header_pressed(target_clip(), uid, header):
				header.accept_event()


func effect_menu_items(uid: String) -> Array:
	var items: Array = [PmMenu.item("fx_copy", "Copy effect")]
	var paste: Dictionary = PmMenu.item("fx_paste", "Paste " + EffectOps.copied_label() + " onto the selected clips" if EffectOps.has_copied() else "Paste effect onto the selected clips")
	if not EffectOps.has_copied():
		paste["disabled"] = true
	items.append(paste)
	items.append(PmMenu.item("fx_duplicate", "Duplicate effect"))
	items.append(PmMenu.item("fx_reset", "Reset effect"))
	items.append_array(load("res://modules/core_panels/section_style.gd").call("menu_items", self, uid))
	items.append_array(load("res://modules/core_panels/shader_import.gd").call("effect_menu_items", self, uid))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("fx_remove", "Remove effect", "", "trash"))
	return items


func open_effect_menu(uid: String, anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, effect_menu_items(uid), anchor.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", effect_menu_picked.bind(uid))


func effect_menu_picked(id: String, uid: String) -> void:
	if bool(load("res://modules/core_panels/section_style.gd").call("menu_picked", self, id, uid)):
		return
	if bool(load("res://modules/core_panels/shader_import.gd").call("effect_menu_picked", self, id, uid)):
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	if id == "fx_copy":
		if EffectOps.copy_effect(c, uid):
			Events.toast("Copied " + EffectOps.copied_label())
	elif id == "fx_paste":
		if EffectOps.paste_effect(d, s, Verbs.selection(s)) == 0:
			Events.toast("Select clips that can take this effect")
	elif id == "fx_duplicate":
		EffectOps.duplicate_effect(d, s, c.id, uid)
	elif id == "fx_reset":
		if not EffectOps.reset_effect(d, s, c.id, uid):
			Events.toast("The effect already has its default values")
	elif id == "fx_remove":
		_on_remove_effect(uid)


func effects_menu_items() -> Array:
	var s: Sequence = seq()
	var ids: PackedStringArray = Verbs.selection(s) if s != null else PackedStringArray()
	var count: int = EffectOps.effect_count(s, ids)
	var remove: Dictionary = PmMenu.item("all_remove", "Remove all effects", Cmd.keys_text("clip.remove_all_effects"), "trash")
	var toggle: Dictionary = PmMenu.item("all_toggle", "Turn all effects off" if EffectOps.any_on(s, ids) else "Turn all effects on", Cmd.keys_text("clip.toggle_all_effects"))
	if count == 0:
		remove["disabled"] = true
		toggle["disabled"] = true
	var paste: Dictionary = PmMenu.item("all_paste", "Paste " + EffectOps.copied_label() + " onto the selected clips" if EffectOps.has_copied() else "Paste effect onto the selected clips")
	if not EffectOps.has_copied():
		paste["disabled"] = true
	return [remove, toggle, PmMenu.separator(), paste]


func _on_effects_menu(anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, effects_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", effects_menu_picked)


func effects_menu_picked(id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if id == "all_remove":
		EffectOps.remove_all(d, s, ids)
	elif id == "all_toggle":
		EffectOps.toggle_all(d, s, ids)
	elif id == "all_paste":
		if EffectOps.paste_effect(d, s, ids) == 0:
			Events.toast("Select clips that can take this effect")


const DEAD_PASTE_VALUE := "dead_paste_value"
const DEAD_PASTE_KEYS := "dead_paste_keys"
const DEAD_PASTE_EFFECT := "dead_paste_effect"
const DEAD_PASTE_ALL := "dead_paste_all"


func dead_menu_items() -> Array:
	var value: Dictionary = PmMenu.item(DEAD_PASTE_VALUE, ValueClipboard.paste_label(ValueClipboard.held) if ValueClipboard.holding() else "Paste value", "Ctrl+V")
	if not ValueClipboard.holding():
		value["disabled"] = true
	var keys: Dictionary = PmMenu.item(DEAD_PASTE_KEYS, "Paste keyframes")
	if not holding_keys():
		keys["disabled"] = true
	var fx: Dictionary = PmMenu.item(DEAD_PASTE_EFFECT, ("Paste " + EffectOps.copied_label() + " onto the selected clips") if EffectOps.has_copied() else "Paste effect onto the selected clips")
	if not EffectOps.has_copied():
		fx["disabled"] = true
	var all: Dictionary = PmMenu.item(DEAD_PASTE_ALL, "Paste attributes", Cmd.keys_text("edit.paste_attributes"))
	if (bus().clipboard.get("clips", []) as Array).is_empty():
		all["disabled"] = true
	var items: Array = [value, keys, fx, all, PmMenu.separator()]
	items.append_array(effects_menu_items())
	return items


func open_dead_menu(at: Vector2) -> Control:
	var anchor: Control = _scroll if _scroll != null and is_instance_valid(_scroll) else _root
	if anchor == null:
		return null
	var m: Control = PmMenu.open(anchor, dead_menu_items(), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", dead_menu_picked)
	return m


func dead_menu_picked(id: String) -> bool:
	if id == DEAD_PASTE_VALUE:
		pick_value("")
		return paste_picked()
	if id == DEAD_PASTE_KEYS:
		pick_value("")
		return paste_keys_picked()
	if id == DEAD_PASTE_EFFECT or id == DEAD_PASTE_ALL:
		var d: Project = doc()
		var s: Sequence = seq()
		if d == null or s == null:
			Events.toast("Open a project first")
			return true
		if id == DEAD_PASTE_EFFECT:
			if EffectOps.paste_effect(d, s, Verbs.selection(s)) == 0:
				Events.toast("Select clips that can take this effect")
			return true
		EffectOps.open_paste_sheet(_root, d, s, bus().clipboard)
		return true
	effects_menu_picked(id)
	return false


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		pick_value("")
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.accept_event()
	open_dead_menu(_root.get_global_mouse_position() if _root != null else Vector2.ZERO)


func _on_mask_chip(uid: String, anchor: Control) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var items: Array = RegionFxRows.menu_items(c, uid)
	items.append(PmMenu.check_item("mask:", "None", String(c.effect_by_uid(uid).get("mask", "")).is_empty()))
	for i: int in c.masks.size():
		var mid: String = String(c.masks[i].get("id", ""))
		items.append(PmMenu.check_item("mask:" + mid, MaskShape.label_of(c.masks[i], i), String(c.effect_by_uid(uid).get("mask", "")) == mid))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_mask_picked.bind(uid))


func _on_mask_picked(id: String, uid: String) -> void:
	var c: Clip = target_clip()
	if c == null or RegionFxRows.picked(id, c.id, uid) or not id.begins_with("mask:"):
		return
	Verbs.run(doc(), "Set mask", [EffectCmds.SetMask.new(seq().id, c.id, uid, id.substr(5))])


const GRIP_SLOP := 4.0
const REORDER_KIND := "effect_reorder"

var _grip_uid: String = ""
var _grip_at: Vector2 = Vector2.ZERO
var _reorder_from: String = ""
var _reorder_bar: Control = null
var _reorder_below: bool = false


func _uid_above(from: Control) -> String:
	var up: Node = from
	while up != null:
		if up is Control and (up as Control).has_meta("uid"):
			return String((up as Control).get_meta("uid"))
		up = up.get_parent()
	return ""


func _bar_above(from: Control) -> Control:
	var up: Node = from
	while up != null and up.get_parent() != _list:
		up = up.get_parent()
	return up as Control


func _on_grip_input(event: InputEvent, grip: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_grip_uid = _uid_above(grip) if mb.pressed else ""
		_grip_at = grip.get_global_mouse_position()
		grip.accept_event()
		return
	if not (event is InputEventMouseMotion):
		return
	var mm: InputEventMouseMotion = event
	if _grip_uid.is_empty() or mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		return
	if _uid_above(grip) != _grip_uid:
		return
	if grip.get_global_mouse_position().distance_to(_grip_at) < GRIP_SLOP:
		return
	begin_reorder(_grip_uid)
	grip.accept_event()


func begin_reorder(uid: String) -> bool:
	_grip_uid = ""
	var c: Clip = target_clip()
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if c == null or layer == null or bool(layer.get("active")):
		return false
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	if e.is_empty():
		return false
	var eid: String = String(e.get("id", ""))
	var title: String = String(EffectSource.get_def(eid).get("label", eid))
	_reorder_from = uid
	_set_reorder_mark(null, false)
	if not layer.is_connected("drag_ended", _on_reorder_ended):
		layer.connect("drag_ended", _on_reorder_ended)
	EffectMoveDrop.ensure_targets()
	layer.call("begin", drag_payload(c, uid, eid, sound, title), PmLabel.tight(title, "text_bright"), Vector2(8.0, 8.0))
	return true


func drag_payload(c: Clip, uid: String, eid: String, sound: bool, title: String) -> Dictionary:
	return {"kind": REORDER_KIND, "uid": uid, "sound": sound, "clip": c.id if c != null else "", "eid": eid, "label": title}


func _on_reorder_ended(payload: Dictionary, _landed: bool) -> void:
	if String(payload.get("kind", "")) != REORDER_KIND:
		return
	_reorder_from = ""
	_set_reorder_mark(null, false)


func _can_reorder_onto(payload: Dictionary, slot: Control) -> bool:
	var c: Clip = target_clip()
	if c == null:
		return false
	return EffectOps.same_stack(c, String(payload.get("uid", "")), _uid_above(slot))


func _on_reorder_hover(local: Vector2, slot: Control) -> void:
	if _reorder_from.is_empty():
		return
	_set_reorder_mark(_bar_above(slot), local.y > slot.size.y * 0.5)


func _on_reorder_hover_changed(on: bool, slot: Control) -> void:
	if on:
		return
	if _reorder_bar != null and _reorder_bar == _bar_above(slot):
		_set_reorder_mark(null, false)


func _set_reorder_mark(bar: Control, below: bool) -> void:
	if _reorder_bar == bar and _reorder_below == below:
		return
	var was: Control = _reorder_bar
	_reorder_bar = bar
	_reorder_below = below
	if was != null and is_instance_valid(was):
		was.queue_redraw()
	if bar != null and is_instance_valid(bar):
		bar.queue_redraw()


func reorder_mark() -> Dictionary:
	var uid: String = ""
	if _reorder_bar != null and is_instance_valid(_reorder_bar) and _reorder_bar.get_child_count() > 0:
		var header: Variant = _reorder_bar.get_child(0).get("header")
		if header is Control and (header as Control).has_meta("uid"):
			uid = String((header as Control).get_meta("uid"))
	return {"uid": uid, "below": _reorder_below}


func _draw_reorder_mark(bar: Control) -> void:
	if _reorder_bar != bar or not is_instance_valid(bar):
		return
	var thick: float = maxf(2.0, float(Tk.px(2.0)))
	var y: float = bar.size.y - thick if _reorder_below else 0.0
	bar.draw_rect(Rect2(Vector2(0.0, y), Vector2(bar.size.x, thick)), Tk.c["accent"], true)


func _on_reorder_drop(payload: Dictionary, local: Vector2, slot: Control) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	_set_reorder_mark(null, false)
	if c == null or d == null or s == null:
		return
	var uid: String = String(payload.get("uid", ""))
	var target_uid: String = _uid_above(slot)
	if uid.is_empty() or target_uid.is_empty():
		return
	if not EffectOps.same_stack(c, uid, target_uid):
		Events.toast("A sound effect and a picture effect cannot swap places")
		return
	var sound: bool = c.is_audio_effect(uid)
	var at: int = EffectOps.stack_index(c, target_uid, sound)
	EffectOps.move_effect(d, s, c.id, uid, EffectOps.gap_for(at, local.y, slot.size.y), sound)


const VALUE_KIND := "value_reorder"
const OUTSIDE_BAR := "OutsideBar"

var _vgrip_vid: String = ""
var _vgrip_at: Vector2 = Vector2.ZERO
var _value_from: String = ""
var _value_bar: Control = null
var _value_below: bool = false
var _outside_bar: Control = null


func _hold_above(from: Control) -> Control:
	var up: Node = from
	while up != null:
		if up is Control and (up as Control).has_meta(ValueStyle.META_VID):
			return up as Control
		up = up.get_parent()
	return null


func _on_value_grip_input(event: InputEvent, grip: Control) -> void:
	var hold: Control = _hold_above(grip)
	if hold == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_vgrip_vid = String(hold.get_meta(ValueStyle.META_VID, "")) if mb.pressed else ""
		_vgrip_at = grip.get_global_mouse_position()
		grip.accept_event()
		return
	if not (event is InputEventMouseMotion):
		return
	var mm: InputEventMouseMotion = event
	if _vgrip_vid.is_empty() or mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		return
	if String(hold.get_meta(ValueStyle.META_VID, "")) != _vgrip_vid:
		return
	if grip.get_global_mouse_position().distance_to(_vgrip_at) < GRIP_SLOP:
		return
	begin_value_move(hold)
	grip.accept_event()


func _on_value_hold_input(event: InputEvent, path: String, hold: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		pick_value(String(hold.get_meta(PICK_META, "")))
		hold.accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	pick_value(String(hold.get_meta(PICK_META, "")))
	hold.accept_event()
	open_value_menu(path, hold, hold.get_global_mouse_position())


func open_value_menu(path: String, anchor: Control, at: Vector2) -> Control:
	var movable: bool = not String(anchor.get_meta(ValueStyle.META_UID, "")).is_empty()
	var items: Array = value_clip_items(path)
	items.append_array(ValueStyle.menu_items(ValueStyle.store_of(self), path, movable))
	var m: Control = PmMenu.open(anchor, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_value_menu_picked.bind(path, anchor))
	return m


func _on_value_menu_picked(id: String, path: String, anchor: Control) -> void:
	if value_clip_picked(id, path):
		return
	ValueStyle.picked(self, id, path, anchor)


func begin_value_move(hold: Control) -> bool:
	_vgrip_vid = ""
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if hold == null or layer == null or bool(layer.get("active")):
		return false
	var uid: String = String(hold.get_meta(ValueStyle.META_UID, ""))
	var key: String = String(hold.get_meta(ValueStyle.META_KEY, ""))
	var vid: String = String(hold.get_meta(ValueStyle.META_VID, ""))
	if uid.is_empty() or key.is_empty():
		return false
	var rec: Dictionary = _row_for(vid)
	var title: String = String(rec["label"]) if not rec.is_empty() else key
	_value_from = vid
	_set_value_mark(null, false)
	if not layer.is_connected("drag_ended", _on_value_move_ended):
		layer.connect("drag_ended", _on_value_move_ended)
	var bar: Control = outside_bar()
	if bar != null and ValueStyle.outside_allowed() and not _many_on:
		bar.visible = true
	layer.call("begin", {"kind": VALUE_KIND, "uid": uid, "key": key, "vid": vid}, PmLabel.tight(title, "text_bright"), Vector2(8.0, 8.0))
	return true


func _on_value_move_ended(payload: Dictionary, _landed: bool) -> void:
	if String(payload.get("kind", "")) != VALUE_KIND:
		return
	_value_from = ""
	_set_value_mark(null, false)
	var bar: Control = outside_bar()
	if bar != null and not _outside_rows():
		bar.visible = false


func _can_value_onto(payload: Dictionary, hold: Control) -> bool:
	if hold == null or not is_instance_valid(hold):
		return false
	return String(payload.get("uid", "")) == String(hold.get_meta(ValueStyle.META_UID, ""))


func _on_value_hover(local: Vector2, hold: Control) -> void:
	if _value_from.is_empty():
		return
	_set_value_mark(hold, local.y > hold.size.y * 0.5)


func _on_value_hover_changed(on: bool, hold: Control) -> void:
	if on:
		return
	if _value_bar != null and _value_bar == hold:
		_set_value_mark(null, false)


func _set_value_mark(bar: Control, below: bool) -> void:
	if _value_bar == bar and _value_below == below:
		return
	var was: Control = _value_bar
	_value_bar = bar
	_value_below = below
	if was != null and is_instance_valid(was):
		was.queue_redraw()
	if bar != null and is_instance_valid(bar):
		bar.queue_redraw()


func value_mark() -> Dictionary:
	var vid: String = ""
	if _value_bar != null and is_instance_valid(_value_bar):
		vid = String(_value_bar.get_meta(ValueStyle.META_VID, ""))
	return {"vid": vid, "below": _value_below}


func _draw_value_mark(bar: Control) -> void:
	if _value_bar != bar or not is_instance_valid(bar):
		return
	var thick: float = maxf(2.0, float(Tk.px(2.0)))
	var y: float = bar.size.y - thick if _value_below else 0.0
	bar.draw_rect(Rect2(Vector2(0.0, y), Vector2(bar.size.x, thick)), Tk.c["accent"], true)


func _on_value_drop(payload: Dictionary, local: Vector2, hold: Control) -> void:
	_set_value_mark(null, false)
	var c: Clip = target_clip()
	if hold == null or not is_instance_valid(hold):
		return
	if c == null and not _many_on:
		return
	var uid: String = String(payload.get("uid", ""))
	var key: String = String(payload.get("key", ""))
	var target_key: String = String(hold.get_meta(ValueStyle.META_KEY, ""))
	if uid.is_empty() or key.is_empty() or target_key.is_empty():
		return
	if uid != String(hold.get_meta(ValueStyle.META_UID, "")):
		return
	var keys: PackedStringArray = many_value_keys(uid) if _many_on else value_keys(c, uid)
	var at: int = keys.find(target_key)
	move_value(uid, key, EffectOps.gap_for(at, local.y, hold.size.y))


func _on_value_out_drop(payload: Dictionary, _local: Vector2) -> void:
	var vid: String = String(payload.get("vid", ""))
	if vid.is_empty() or not ValueStyle.outside_allowed():
		return
	var store: Dictionary = ValueStyle.store_of(self)
	if ValueStyle.is_outside(store, vid):
		return
	ValueStyle.put(self, ValueStyle.with_outside(store, vid, true))
	rebuild()


const PICK_META := "pm_value_pick"
const FLASH_TIME := 0.9
const KEYS_ONLY := "keys_only"

var _picked: String = ""
var _flash_pick: String = ""
var _flash: float = 0.0
var _last_paste: Dictionary = {}
var _scroll_want: String = ""


func _pick_id(spec: Dictionary) -> String:
	var path: String = String(spec.get("path", ""))
	if spec.has("component"):
		return path + "#" + str(int(spec["component"]))
	return path


func _row_by_pick(pick: String) -> Dictionary:
	if pick.is_empty():
		return {}
	for r: Dictionary in _rows:
		if String(r.get("pick", "")) == pick:
			return r
	return {}


func picked_value() -> String:
	return _picked


func pick_value(pick: String) -> void:
	if _picked == pick:
		return
	_picked = pick
	EffectHandlesUi.pick_path(target_clip(), pick)
	for r: Dictionary in _rows:
		if r.get("hold") is Control and is_instance_valid(r["hold"]):
			(r["hold"] as Control).queue_redraw()


func _draw_value_pick(hold: Control) -> void:
	if hold == null or not is_instance_valid(hold):
		return
	var pick: String = String(hold.get_meta(PICK_META, ""))
	if pick.is_empty():
		return
	if pick == _flash_pick and _flash > 0.0:
		hold.draw_rect(Rect2(Vector2.ZERO, hold.size), Color(Tk.c["accent"], 0.25 * _flash), true)
	if pick != _picked:
		return
	var thick: float = maxf(2.0, float(Tk.px(2.0)))
	hold.draw_rect(Rect2(Vector2(thick * 0.5, thick * 0.5), hold.size - Vector2(thick, thick)), Tk.c["accent"], false, thick)


func flash_value(pick: String) -> void:
	var r: Dictionary = _row_by_pick(pick)
	if r.is_empty() or not (r.get("hold") is Control):
		return
	var hold: Control = r["hold"]
	_flash_pick = pick
	_flash = 1.0
	hold.create_tween().tween_method(_on_flash_step.bind(hold), 1.0, 0.0, FLASH_TIME)


func _on_flash_step(amount: float, hold: Control) -> void:
	_flash = amount
	if is_instance_valid(hold):
		hold.queue_redraw()


func _open_folds_above(hold: Control) -> void:
	var up: Node = hold.get_parent()
	while up != null and up != _list:
		if up is Control and (up as Control).has_method("set_open") and not bool((up as Control).get("open")):
			(up as Control).call("set_open", true, false)
		up = up.get_parent()


func scroll_to_value(pick: String) -> void:
	var r: Dictionary = _row_by_pick(pick)
	if r.is_empty():
		return
	var hold: Control = r.get("hold") as Control
	if hold == null or not is_instance_valid(hold):
		return
	_open_folds_above(hold)
	_scroll_want = pick
	_scroll_to_want.call_deferred()


func _scroll_to_want() -> void:
	var pick: String = _scroll_want
	_scroll_want = ""
	if not _alive() or _scroll == null or not is_instance_valid(_scroll) or pick.is_empty():
		return
	var r: Dictionary = _row_by_pick(pick)
	var hold: Control = r.get("hold") as Control if not r.is_empty() else null
	if hold == null or not is_instance_valid(hold):
		return
	var y: float = hold.position.y
	var up: Node = hold.get_parent()
	while up is Control and up != _list:
		y += (up as Control).position.y
		up = up.get_parent()
	_scroll.scroll_vertical = int(maxf(y - _scroll.size.y * 0.3, 0.0))


func copy_value(pick: String) -> bool:
	var r: Dictionary = _row_by_pick(pick)
	if r.is_empty():
		Events.toast("Click a value first, then copy")
		return false
	var spec: Dictionary = r["spec"]
	var c: Clip = target_clip()
	var prop: Dictionary = c.get_param(String(spec.get("path", ""))) if c != null else {}
	var cb: Dictionary = ValueClipboard.grab(spec, current_value(spec), prop)
	if not ValueClipboard.take(cb):
		Events.toast(ValueClipboard.plain_label(spec) + " cannot be copied on its own")
		return false
	if ValueClipboard.key_count(cb) > 0:
		bus().key_clipboard = (cb["keys"] as Array).duplicate(true)
	DisplayServer.clipboard_set(str(cb["value"]))
	Events.toast(ValueClipboard.copied_note(cb))
	return true


func _row_by_match(cb: Dictionary) -> Dictionary:
	var specs: Array = []
	for r: Dictionary in _rows:
		specs.append(r["spec"])
	var want: Dictionary = ValueClipboard.best_match(specs, cb)
	if want.is_empty():
		return {}
	return _row_by_pick(_pick_id(want))


func copy_picked() -> bool:
	if _picked.is_empty():
		return false
	return copy_value(_picked)


func paste_picked() -> bool:
	var cb: Dictionary = ValueClipboard.held
	if cb.is_empty():
		return false
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		Events.toast("Select a clip first")
		return true
	var aimed: bool = not _picked.is_empty()
	var r: Dictionary = _row_by_pick(_picked) if aimed else _row_by_match(cb)
	if r.is_empty():
		aimed = false
		r = _row_by_match(cb)
	if r.is_empty():
		return paste_adding_effect(d, s, c, cb)
	var spec: Dictionary = r["spec"]
	var why: String = ValueClipboard.refusal(cb, spec)
	if not why.is_empty():
		Events.toast(why)
		return true
	var pick: String = String(r.get("pick", ""))
	if not ValueClipboard.paste(d, s, c, spec, fitted_clipboard(c, spec, cb)):
		Events.toast(ValueClipboard.plain_label(spec) + " already holds that value")
		pick_value(pick)
		return true
	note_paste(pick, ValueClipboard.plain_label(spec), "")
	pick_value(pick)
	refresh_values()
	if not aimed:
		scroll_to_value(pick)
		Events.toast("Pasted into " + ValueClipboard.plain_label(spec))
	flash_value(pick)
	return true


func fitted_clipboard(c: Clip, spec: Dictionary, cb: Dictionary) -> Dictionary:
	if not bool(cb.get(KEYS_ONLY, false)) or c == null:
		return cb
	var p: Dictionary = c.get_param(String(spec.get("path", "")))
	if p.is_empty():
		return cb
	var out: Dictionary = cb.duplicate(true)
	out["under"] = AnimProp.norm(AnimProp.static_value(p))
	return out


func paste_adding_effect(d: Project, s: Sequence, c: Clip, cb: Dictionary) -> bool:
	var made: Dictionary = EffectOps.add_with_value(d, s, c, cb)
	if not bool(made["ok"]):
		Events.toast(String(made["why"]))
		return true
	var pick: String = String(made["path"])
	note_paste(pick, String(made["label"]), String(made["effect"]))
	rebuild()
	pick_value("")
	pick_value(pick)
	scroll_to_value(pick)
	flash_value(pick)
	Events.toast("Added " + String(made["effect"]) + " and pasted " + ValueClipboard.plain_name(cb) + " into " + String(made["label"]))
	return true


func note_paste(pick: String, label: String, added: String) -> void:
	_last_paste = {"pick": pick, "label": label, "effect": added, "added": not added.is_empty()}


func last_paste() -> Dictionary:
	return _last_paste


func holding_keys() -> bool:
	return ValueClipboard.holding() and ValueClipboard.key_count(ValueClipboard.held) > 0


func _strip_of(r: Dictionary) -> Control:
	var strip: Variant = r.get("strip")
	if strip is Control and is_instance_valid(strip as Control):
		return strip
	return null


func _strip_keys(r: Dictionary) -> Array:
	var strip: Control = _strip_of(r)
	if strip == null or not strip.has_method("copy_selected"):
		return []
	var sel: Variant = strip.get("selected")
	if not (sel is PackedFloat64Array) or (sel as PackedFloat64Array).is_empty():
		return []
	var raw: Variant = strip.call("copy_selected")
	return raw if raw is Array else []


func _strip_base(r: Dictionary) -> float:
	var strip: Control = _strip_of(r)
	if strip == null or not strip.has_method("selected_times"):
		return 0.0
	var base: float = INF
	for t: float in (strip.call("selected_times") as PackedFloat64Array):
		base = minf(base, t)
	return 0.0 if is_inf(base) else base


func copy_keys(pick: String) -> bool:
	var r: Dictionary = _row_by_pick(pick)
	if r.is_empty():
		Events.toast("Click a value with keyframes first, then copy them")
		return false
	var spec: Dictionary = r["spec"]
	if not bool(spec.get("keyable", false)):
		Events.toast(ValueClipboard.plain_label(spec) + " cannot hold keyframes")
		return false
	var c: Clip = target_clip()
	if c == null:
		Events.toast("Select a clip first")
		return false
	var cb: Dictionary = ValueClipboard.grab(spec, current_value(spec), c.get_param(String(spec.get("path", ""))))
	if cb.is_empty():
		Events.toast(ValueClipboard.plain_label(spec) + " cannot be copied on its own")
		return false
	var chosen: Array = _strip_keys(r)
	if not chosen.is_empty():
		cb["keys"] = chosen
		cb["base"] = _strip_base(r)
	var n: int = ValueClipboard.key_count(cb)
	if n == 0:
		Events.toast(ValueClipboard.plain_label(spec) + " has no keyframes to copy")
		return false
	cb[KEYS_ONLY] = true
	if not ValueClipboard.take(cb):
		return false
	bus().key_clipboard = (cb["keys"] as Array).duplicate(true)
	Events.toast("Copied " + str(n) + (" keyframe from " if n == 1 else " keyframes from ") + ValueClipboard.plain_label(spec))
	return true


func copy_keys_picked() -> bool:
	if _picked.is_empty():
		return false
	return copy_keys(_picked)


func paste_keys_picked() -> bool:
	if not holding_keys():
		Events.toast("Copy some keyframes first, then paste")
		return true
	return paste_picked()


func value_clip_items(path: String) -> Array:
	var r: Dictionary = _row_for(path)
	var keyable: bool = not r.is_empty() and bool((r["spec"] as Dictionary).get("keyable", false))
	var paste_v: Dictionary = PmMenu.item("paste_value", ValueClipboard.paste_label(ValueClipboard.held) if ValueClipboard.holding() else "Paste value", Cmd.keys_text("edit.paste"))
	if not ValueClipboard.holding():
		paste_v["disabled"] = true
	var out: Array = [PmMenu.item("copy_value", "Copy value", Cmd.keys_text("edit.copy")), paste_v]
	out.append_array(ValueOffsetUi.menu_items(self, path))
	if not r.is_empty() and wants_turns(r["spec"]):
		out.append_array(rotation_typing_items())
	if not r.is_empty() and value_label_widths().has(value_width_key(r["spec"])):
		out.append(PmMenu.item(MENU_LABEL_RESET, "Put this name back in line with the others"))
	if not keyable:
		return out
	out.append_array(key_default_items(KeyDefaults.value_key(target_clip(), path)))
	out.append(PmMenu.item("copy_keys", "Copy keyframes"))
	var paste_k: Dictionary = PmMenu.item("paste_keys", "Paste keyframes")
	if not holding_keys():
		paste_k["disabled"] = true
	out.append(paste_k)
	return out


static func rotation_typing_items() -> Array:
	var mode: String = PmField.pref_rotation_typing()
	var sub: Array = [
		PmMenu.check_item(ROT_TYPING_PREMIERE, "Two turns and 45 degrees, like Premiere", mode == "premiere"),
		PmMenu.check_item(ROT_TYPING_TIMES, "2 times 45, which is 90", mode == "times"),
	]
	return [PmMenu.sub_item("rot_typing", "Typing 2x45 means", sub)]


static func rotation_typing_picked(id: String) -> bool:
	if id == ROT_TYPING_PREMIERE:
		PmField.set_rotation_typing("premiere")
		Events.toast("Typing 2x45 into a rotation now means two turns and 45 degrees")
		return true
	if id == ROT_TYPING_TIMES:
		PmField.set_rotation_typing("times")
		Events.toast("Typing 2x45 into a rotation now means 2 times 45")
		return true
	return false


func _on_pref_for_keys(key: String) -> void:
	if key == PREF_NEW_INTERP or key == PREF_NEW_INTERP_ONE:
		sync_key_defaults()


static func sync_key_defaults() -> void:
	if not Prefs.is_registered(PREF_NEW_INTERP):
		Prefs.register(PREF_NEW_INTERP, KeyDefaults.AUTO, {"label": "New keyframes are made as: auto (eased, hold for on and off values), linear, ease_both, bezier or hold", "type": "enum", "choices": Array(KeyDefaults.CHOICES)})
	if not Prefs.is_registered(PREF_NEW_INTERP_ONE):
		Prefs.register(PREF_NEW_INTERP_ONE, {}, {"label": "New keyframe type set for single values (right click a value)", "type": "dict"})
	KeyDefaults.everywhere = String(Prefs.get_value(PREF_NEW_INTERP))
	var one: Variant = Prefs.get_value(PREF_NEW_INTERP_ONE)
	KeyDefaults.by_value = (one as Dictionary).duplicate() if one is Dictionary else {}


static func key_default_items(vkey: String) -> Array:
	sync_key_defaults()
	var here: Array = []
	var own: String = KeyDefaults.own_choice(vkey)
	var shown: String = KeyDefaults.choice_for(vkey)
	here.append(PmMenu.check_item(MENU_KEYS_HERE + "follow", "Same as every value", own.is_empty() and not KeyDefaults.BUILT_IN.has(vkey)))
	for i: int in KeyDefaults.CHOICES.size():
		var ch: String = KeyDefaults.CHOICES[i]
		here.append(PmMenu.check_item(MENU_KEYS_HERE + ch, KeyDefaults.LABELS[i], shown == ch and (not own.is_empty() or KeyDefaults.BUILT_IN.has(vkey))))
	var all: Array = []
	for i2: int in KeyDefaults.CHOICES.size():
		var ch2: String = KeyDefaults.CHOICES[i2]
		all.append(PmMenu.check_item(MENU_KEYS_ALL + ch2, KeyDefaults.LABELS[i2], KeyDefaults.everywhere == ch2))
	return [PmMenu.sub_item("keys_new_here", "New keyframes on this value", here), PmMenu.sub_item("keys_new_all", "New keyframes on every value", all)]


static func key_default_picked(id: String, vkey: String) -> bool:
	if id.begins_with(MENU_KEYS_ALL):
		sync_key_defaults()
		var ch: String = id.substr(MENU_KEYS_ALL.length())
		if ch in KeyDefaults.CHOICES:
			Prefs.set_value(PREF_NEW_INTERP, ch)
			sync_key_defaults()
			Events.toast("New keyframes on every value: " + KeyDefaults.LABELS[KeyDefaults.CHOICES.find(ch)])
		return true
	if id.begins_with(MENU_KEYS_HERE):
		sync_key_defaults()
		var ch2: String = id.substr(MENU_KEYS_HERE.length())
		var all: Dictionary = KeyDefaults.by_value.duplicate()
		if ch2 == "follow":
			if KeyDefaults.BUILT_IN.has(vkey):
				all[vkey] = KeyDefaults.AUTO
			else:
				all.erase(vkey)
		elif ch2 in KeyDefaults.CHOICES:
			all[vkey] = ch2
		Prefs.set_value(PREF_NEW_INTERP_ONE, all)
		sync_key_defaults()
		Events.toast("New keyframes on this value: " + (KeyDefaults.LABELS[KeyDefaults.CHOICES.find(KeyDefaults.choice_for(vkey))]))
		return true
	return false


func value_clip_picked(id: String, path: String) -> bool:
	if rotation_typing_picked(id):
		return true
	if key_default_picked(id, KeyDefaults.value_key(target_clip(), path)):
		return true
	if id == MENU_LABEL_RESET:
		var rr: Dictionary = _row_for(path)
		if not rr.is_empty():
			set_value_label_width(value_width_key(rr["spec"]), 0.0)
			for r: Dictionary in _rows:
				PmWrapRow.prefer(r["label_ctrl"], _spec_label_width(r["spec"]))
			_relayout_rows()
		return true
	if ValueOffsetUi.picked(self, id, path):
		return true
	if id != "copy_value" and id != "paste_value" and id != "copy_keys" and id != "paste_keys":
		return false
	var pick: String = String(_row_for(path).get("pick", ""))
	pick_value(pick)
	if id == "copy_value":
		copy_value(pick)
	elif id == "paste_value":
		paste_picked()
	elif id == "copy_keys":
		copy_keys(pick)
	else:
		paste_keys_picked()
	return true


func value_keys(c: Clip, uid: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	if c == null or uid.is_empty():
		return keys
	for item: Dictionary in value_items(c, uid):
		keys.append(String(item["key"]))
	return ValueStyle.arrange(ValueStyle.store_of(self), uid, keys)


func value_items(c: Clip, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or uid.is_empty():
		return out
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	if e.is_empty():
		return out
	var eid: String = String(e.get("id", ""))
	var def: Dictionary = EffectSource.get_def(eid)
	var prefix: String = "audio_effects" if sound else "effects"
	if not sound:
		out.append({"key": "mix", "group": "", "spec": _mix_spec(uid)})
	for p: Dictionary in EffectSource.param_specs(def):
		var key: String = String(p.get("key", ""))
		var spec: Dictionary = _effect_param_spec(p, prefix + "." + uid + "." + key, uid, eid, sound, e)
		out.append({"key": key, "group": String(p.get("group", "")), "spec": spec})
	return out


func _mix_spec(uid: String) -> Dictionary:
	return {"path": "effects." + uid + ".mix", "label": "Amount", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "fx_uid": uid, "fx_key": "mix"}


func many_value_keys(uid: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in _rows:
		var spec: Dictionary = r["spec"]
		if String(spec.get("fx_uid", "")) != uid:
			continue
		var k: String = String(spec.get("fx_key", ""))
		if not k.is_empty() and not out.has(k):
			out.append(k)
	return out


func many_fx_members(uid: String) -> Dictionary:
	for r: Dictionary in _rows:
		var spec: Dictionary = r["spec"]
		if String(spec.get("fx_uid", "")) != uid:
			continue
		var m: Variant = spec.get("fx_members", null)
		if m is Dictionary:
			return m
	return {}


func _write_value_order(uids: Dictionary, want: PackedStringArray) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or uids.is_empty() or want.is_empty():
		return false
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		ValueStyle.put_for(d, c, ValueStyle.with_order(ValueStyle.store_for(d, c), String(uids[cid]), want))
	rebuild()
	return true


func move_value(uid: String, key: String, gap: int) -> bool:
	if uid.is_empty() or key.is_empty():
		return false
	if _many_on:
		return _write_value_order(many_fx_members(uid), ValueStyle.moved(many_value_keys(uid), key, gap))
	var c: Clip = target_clip()
	if c == null:
		return false
	var keys: PackedStringArray = value_keys(c, uid)
	var want: PackedStringArray = ValueStyle.moved(keys, key, gap)
	if want.is_empty():
		return false
	ValueStyle.put(self, ValueStyle.with_order(ValueStyle.store_of(self), uid, want))
	rebuild()
	return true


func step_value(uid: String, key: String, delta: int) -> bool:
	if uid.is_empty() or key.is_empty():
		return false
	if _many_on:
		return _write_value_order(many_fx_members(uid), ValueStyle.stepped(many_value_keys(uid), key, delta))
	var c: Clip = target_clip()
	if c == null:
		return false
	var keys: PackedStringArray = value_keys(c, uid)
	var want: PackedStringArray = ValueStyle.stepped(keys, key, delta)
	if want.is_empty():
		return false
	ValueStyle.put(self, ValueStyle.with_order(ValueStyle.store_of(self), uid, want))
	rebuild()
	return true


func _effect_kind_of(c: Clip, uid: String) -> Dictionary:
	var sound: bool = c.is_audio_effect(uid)
	var stack: Array = EffectOps.stack_of(c, sound)
	var seen: Dictionary = {}
	for e: Variant in stack:
		var entry: Dictionary = e
		var kind: String = ("afx." if sound else "fx.") + String(entry.get("id", ""))
		var n: int = int(seen.get(kind, 0))
		seen[kind] = n + 1
		if String(entry.get("uid", "")) == uid:
			return {"kind": kind, "n": n}
	return {}


func _outside_rows() -> bool:
	var c: Clip = target_clip()
	if c == null or not ValueStyle.outside_allowed():
		return false
	return not outside_items(c).is_empty()


func outside_items(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or not ValueStyle.outside_allowed():
		return out
	var store: Dictionary = ValueStyle.store_of(self)
	if ValueStyle.outside_of(store).is_empty():
		return out
	var stacks: Array[Array] = [c.effects, c.audio_effects()]
	for stack: Array in stacks:
		for e: Variant in stack:
			var uid: String = String((e as Dictionary).get("uid", ""))
			for item: Dictionary in value_items(c, uid):
				if ValueStyle.is_outside(store, String((item["spec"] as Dictionary)["path"])):
					out.append(item)
	return out


func outside_bar() -> Control:
	if _outside_bar != null and is_instance_valid(_outside_bar) and _outside_bar.get_parent() == _list:
		return _outside_bar
	_outside_bar = null
	if _list == null or not is_instance_valid(_list):
		return null
	for child: Node in _list.get_children():
		if child.name == OUTSIDE_BAR and child is Control:
			_outside_bar = child as Control
			break
	return _outside_bar


func _build_outside(c: Clip) -> void:
	_outside_bar = null
	if not ValueStyle.outside_allowed():
		return
	var items: Array[Dictionary] = outside_items(c)
	var bar: PanelContainer = PmUI.panel("bg_panel_alt")
	bar.name = OUTSIDE_BAR
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(PmLabel.dim("Values taken out of their effects sit here"))
	bar.add_child(row)
	var slot: Control = PmSlot.make(PackedStringArray([VALUE_KIND]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.connect("dropped", _on_value_out_drop)
	bar.add_child(slot)
	bar.visible = not items.is_empty()
	_list.add_child(bar)
	_outside_bar = bar
	for item: Dictionary in items:
		_add_row(_list, item["spec"])


func paint_values() -> void:
	var c: Clip = target_clip()
	if c == null or _many_on:
		return
	var store: Dictionary = ValueStyle.store_of(self)
	for r: Dictionary in _rows:
		if not (r.get("hold") is Control):
			continue
		var hold: Control = r["hold"]
		var vid: String = String(r["path"])
		var from_effect: Dictionary = {}
		if ValueStyle.is_outside(store, vid):
			var where: Dictionary = _effect_kind_of(c, String(hold.get_meta(ValueStyle.META_UID, "")))
			if not where.is_empty():
				from_effect = ValueStyle.effect_style(store, String(where["kind"]), int(where["n"]))
		ValueStyle.paint(hold, ValueStyle.shown_style(store, vid, from_effect))


func _on_effect_step(uid: String, delta: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	EffectOps.step_effect(doc(), seq(), c.id, uid, delta)


func _on_dropped(payload: Dictionary, _local: Vector2) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		Events.toast("Select a clip first")
		return
	var kind: String = String(payload.get("kind", ""))
	if kind == "effect":
		var def: Dictionary = EffectSource.get_def(String(payload.get("id", "")))
		if def.is_empty():
			return
		if Verbs.drop_effect(d, s, Verbs.drop_targets(s, c.id), def) == 0:
			Events.toast("Sound effects go on clips that have sound" if bool(def.get("audio", false)) else "Picture effects go on clips that have a picture")
	elif kind == "preset":
		var p: Object = bus().panel("presets")
		if p != null and p.has_method("apply_preset_id"):
			p.call("apply_preset_id", String(payload.get("id", "")), Verbs.selection(s), s.playhead, null)


func _add_row(body: VBoxContainer, spec: Dictionary) -> void:
	var c: Clip = target_clip()
	var path: String = String(spec["path"])
	var keyable: bool = bool(spec.get("keyable", false))
	if _many_on:
		_many_adopt(spec)
		path = String(spec["path"])
	var row: Container = _row_box()
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	var indent: int = int(spec.get("indent", 0))
	var btn_w: float = float(Tk.px(Tk.sz("button_h")))
	var fold_btn: Button = quiet_icon("chev_r", "Show the keyframe editor")
	fold_btn.set("icon_px", 12.0)
	fold_btn.visible = keyable
	fold_btn.pressed.connect(_on_fold.bind(path))
	row.add_child(fold_btn)
	if not keyable or _many_on:
		fold_btn.visible = true
		_ghost(fold_btn)
	var label_box: HBoxContainer = PmUI.hbox(0)
	if indent > 0:
		label_box.add_child(_spacer(float(indent) * INDENT_W))
	var label: Label = PmLabel.trim(String(spec["label"]))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PmWrapRow.prefer(label, _spec_label_width(spec))
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(_on_label_input.bind(label))
	label.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	label_box.add_child(label)
	row.add_child(label_box)
	var cluster: HBoxContainer = PmUI.hbox(0)
	var stopwatch: Button = quiet_icon("stopwatch", "Toggle animation, a key is written at the playhead")
	stopwatch.set("icon_px", 13.0)
	stopwatch.pressed.connect(_on_stopwatch.bind(path))
	cluster.add_child(stopwatch)
	var nav: HBoxContainer = PmUI.hbox(0)
	var prev: Button = quiet_icon("prev_key", "Previous key")
	prev.set("icon_px", 10.0)
	prev.custom_minimum_size = Vector2(14.0, 0.0)
	prev.pressed.connect(_on_key_nav.bind(path, -1))
	nav.add_child(prev)
	var diamond: Button = quiet_icon("diamond_o", "Add or remove a key at the playhead")
	diamond.set("icon_px", 10.0)
	diamond.custom_minimum_size = Vector2(14.0, 0.0)
	diamond.pressed.connect(_on_key_toggle.bind(path))
	nav.add_child(diamond)
	var next: Button = quiet_icon("next_key", "Next key")
	next.set("icon_px", 10.0)
	next.custom_minimum_size = Vector2(14.0, 0.0)
	next.pressed.connect(_on_key_nav.bind(path, 1))
	nav.add_child(next)
	nav.custom_minimum_size = Vector2(42.0, 0.0)
	cluster.add_child(nav)
	var mark: Button = quiet_icon("fx", AnimLayerUi.EXPR_MARK_TIP)
	mark.name = "LayerMark"
	mark.set("icon_px", 11.0)
	mark.custom_minimum_size = Vector2(16.0, 0.0)
	mark.visible = false
	mark.pressed.connect(_on_layer_mark.bind(path))
	mark.draw.connect(_draw_layer_mark.bind(mark))
	cluster.add_child(mark)
	var drive_btn: Button = null
	var drive_slot: Control = null
	if drivable(spec):
		drive_btn = PmButton.make("", "follow", true)
		drive_btn.name = "DriveButton"
		drive_btn.set("quiet", true)
		drive_btn.set("icon_px", 12.0)
		PmUI.tip(drive_btn, DRIVE_TIP)
		drive_btn.pressed.connect(toggle_drive.bind(path))
		drive_slot = drive_btn
	else:
		drive_slot = Control.new()
		drive_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_slot.custom_minimum_size = Vector2(16.0, 0.0)
	drive_slot.visible = not _follow_tight
	cluster.add_child(drive_slot)
	if not keyable:
		_ghost(cluster)
	row.add_child(cluster)
	var editors: HBoxContainer = PmUI.hbox()
	editors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editors)
	var rec: Dictionary = {"spec": spec, "path": path, "label": String(spec["label"]), "row": row, "stopwatch": stopwatch, "nav": nav, "diamond": diamond, "editors": [], "label_ctrl": label, "fold": fold_btn, "mark": mark, "sheets": null, "sheet": null}
	_make_editors(editors, spec, rec)
	var dots: Button = quiet_icon("more", "Row menu")
	dots.set("icon_px", 12.0)
	dots.pressed.connect(_on_row_menu.bind(path, dots))
	row.add_child(dots)
	var fx_uid: String = String(spec.get("fx_uid", ""))
	var fx_key: String = String(spec.get("fx_key", ""))
	if not fx_uid.is_empty():
		var vgrip: Button = quiet_icon("list", ("Hold the mouse down here and move to put this value somewhere else in the effect, in every selected clip" if _many_on else "Hold the mouse down here and move to put this value somewhere else in the effect"))
		vgrip.name = "ValueGrip"
		vgrip.set("icon_px", 10.0)
		vgrip.custom_minimum_size = Vector2(16.0, 0.0)
		vgrip.mouse_default_cursor_shape = Control.CURSOR_MOVE
		vgrip.gui_input.connect(_on_value_grip_input.bind(vgrip))
		row.add_child(vgrip)
		row.set("trail", 2)
	var hold: PanelContainer = _value_hold(body, row, path, fx_uid, fx_key)
	var drive_holder: VBoxContainer = PmUI.vbox(0)
	drive_holder.name = "DriveHolder"
	body.add_child(drive_holder)
	rec["drive_holder"] = drive_holder
	rec["drive_btn"] = drive_btn
	rec["drive_slot"] = drive_slot
	rec["drive"] = null
	rec["hold"] = hold
	rec["pick"] = _pick_id(spec)
	hold.set_meta(PICK_META, String(rec["pick"]))
	var holder: Control = PmSlide.make(false)
	body.add_child(holder)
	rec["strip_holder"] = holder
	rec["strip"] = null
	rec["mods"] = null
	_rows.append(rec)
	rec["rec_dot"] = _add_record_dot(label_box, keyable)
	if keyable and _open_strips.has(path) and c != null and not _many_on:
		_open_strip(rec)
	if keyable and not AnimTime.is_inner(path):
		_add_speed_row_for(body, spec)
	if not _drive_open.is_empty():
		_sync_drive(rec, [] if _many_on else [c, path])


func _ghost(c: Control) -> void:
	c.modulate = Color(1.0, 1.0, 1.0, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	if c is Button:
		(c as Button).disabled = true
	for child: Node in c.get_children():
		if child is Control:
			_ghost(child)


func _spacer(w: float) -> Control:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(w, 0.0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


static func value_width_key(spec: Dictionary) -> String:
	var eid: String = String(spec.get("eid", ""))
	var key: String = String(spec.get("key", ""))
	if not eid.is_empty() and not key.is_empty():
		return eid + "." + key
	return String(spec.get("path", ""))


static func value_label_widths() -> Dictionary:
	if not Prefs.is_registered(PREF_LABEL_ONE):
		Prefs.register(PREF_LABEL_ONE, {}, {"label": "Name widths set for single values (Alt drag a name in Effect Controls)", "type": "dict"})
	var v: Variant = Prefs.get_value(PREF_LABEL_ONE)
	return v if v is Dictionary else {}


static func set_value_label_width(vkey: String, w: float) -> void:
	if vkey.is_empty():
		return
	var all: Dictionary = value_label_widths().duplicate()
	if w <= 0.0:
		all.erase(vkey)
	else:
		all[vkey] = w / maxf(Tk.ui_scale, 0.01)
	Prefs.set_value(PREF_LABEL_ONE, all)


func _spec_label_width(spec: Dictionary) -> float:
	var own: Variant = value_label_widths().get(value_width_key(spec), null)
	if own != null:
		return maxf(float(own) * Tk.ui_scale, float(Tk.px(LABEL_ONE_MIN)))
	return _label_width(String(spec.get("label", "")), int(spec.get("indent", 0)))


func _relayout_rows() -> void:
	for r: Dictionary in _rows:
		var row: Variant = r.get("row")
		if row is Container and is_instance_valid(row):
			(row as Container).queue_sort()


func _label_width(text: String, indent: int) -> float:
	var col: float = minf(label_w, _label_fit)
	var want: float = maxf(col - float(indent) * INDENT_W, 20.0)
	if col < label_w:
		return want
	var needed: float = Tk.font("body").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Tk.fs(Tk.sz("font_body"))).x + 6.0
	return maxf(want, needed)


const LABEL_FIT_MIN := 56.0

var _label_fit: float = INF


func _fit_label_column() -> void:
	if _list == null or not is_instance_valid(_list) or _list.size.x <= 1.0:
		return
	var rest: float = INF
	for r: Dictionary in _rows:
		var spec: Dictionary = r["spec"]
		var row: Control = r["row"]
		var kind: String = String(spec.get("kind", ""))
		if (kind == "float" or kind == "int") and int(spec.get("indent", 0)) == 0 and row.has_method("one_line_need"):
			rest = minf(rest, float(row.call("one_line_need")) - PmWrapRow.pref_of(r["label_ctrl"]))
	if is_inf(rest):
		return
	rest = _fit_follow(rest)
	var fit: float = maxf(_list.size.x - rest, float(Tk.px(LABEL_FIT_MIN)))
	if fit >= label_w:
		fit = INF
	if (is_inf(fit) and is_inf(_label_fit)) or absf(fit - _label_fit) < 0.5:
		return
	_label_fit = fit
	for r2: Dictionary in _rows:
		PmWrapRow.prefer(r2["label_ctrl"], _spec_label_width(r2["spec"]))


func _row_box() -> Container:
	var row: Container = PmWrapRow.make(float(Tk.px(2.0)))
	row.set("wrap_from", 3)
	row.set("trail", 1)
	row.set("indent", float(Tk.px(Tk.sz("button_h"))) + float(Tk.px(2.0)))
	return row


func _value_hold(body: VBoxContainer, row: Container, path: String, fx_uid: String, fx_key: String) -> PanelContainer:
	var hold: PanelContainer = PanelContainer.new()
	hold.name = "ValueHold"
	hold.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold.mouse_filter = Control.MOUSE_FILTER_STOP
	ValueStyle.adopt(hold, path, fx_uid, fx_key, "bg_panel" if body == _list else "bg_panel_alt")
	hold.add_child(row)
	body.add_child(hold)
	hold.gui_input.connect(_on_value_hold_input.bind(path, hold))
	hold.draw.connect(_draw_value_pick.bind(hold))
	PmUI.tip(hold, "Click to pick this value. Ctrl+C copies it, Ctrl+V pastes into it, Escape unpicks it. With nothing picked, Ctrl+V pastes into the value of the same name")
	if fx_uid.is_empty():
		return hold
	var slot: Control = PmSlot.make(PackedStringArray([VALUE_KIND]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set("draw_highlight", false)
	slot.set("can_accept_cb", _can_value_onto.bind(hold))
	slot.connect("dropped", _on_value_drop.bind(hold))
	slot.connect("hover_moved", _on_value_hover.bind(hold))
	slot.connect("hover_changed", _on_value_hover_changed.bind(hold))
	hold.add_child(slot)
	hold.draw.connect(_draw_value_mark.bind(hold))
	return hold


func _fit_head(head: HBoxContainer) -> void:
	PmWrapRow.prefer(_search, float(Tk.px(120.0)), PmUI.placeholder_room("Search"))
	PmWrapRow.adopt(head, 1, 1)


func _fit_lead_row(row: HBoxContainer, lead: Array[Control], wrap_from: int, end_gap: float = 0.0) -> void:
	var sep: float = float(row.get_theme_constant("separation"))
	var want: float = 0.0
	for c: Control in lead:
		want += c.custom_minimum_size.x + sep
		PmWrapRow.prefer(c, c.custom_minimum_size.x, 0.0)
	if end_gap > 0.0:
		row.add_child(_spacer(end_gap))
	var inner: Container = PmWrapRow.adopt(row, wrap_from, 0)
	inner.set("indent", want)


func _make_editors(editors: HBoxContainer, spec: Dictionary, rec: Dictionary) -> void:
	var kind: String = String(spec["kind"])
	var path: String = String(spec["path"])
	var list: Array = []
	var mul: float = float(spec.get("display_mul", 1.0))
	if kind == "float" or kind == "int":
		var lo: float = float(spec.get("min", -INF))
		var hi: float = float(spec.get("max", INF))
		if bool(spec.get("db", false)):
			lo = -60.0
			hi = 6.0
		var f: Control = _number_field(lo * mul if lo != -INF else -INF, hi * mul if hi != INF else INF, float(spec.get("step", 1.0)) * mul, String(spec.get("suffix", "")))
		f.set("precision", 0 if kind == "int" else -1)
		if spec.has("min") and spec.has("max"):
			f.set("show_range", true)
		f.set("reach", bool(spec.get("reach", not spec.has("max"))))
		f.set("turns", wants_turns(spec))
		f.custom_minimum_size.x = float(Tk.px(FIELD_W))
		f.connect("value_changed", _on_field.bind(path, 0))
		f.connect("edit_begun", _on_edit_begun)
		f.connect("edit_ended", _on_edit_ended)
		editors.add_child(f)
		list.append(f)
	elif kind == "vec2":
		for i: int in 2:
			var f2: Control = _number_field(-INF, INF, float(spec.get("step", 1.0)) * mul, String(spec.get("suffix", "")))
			f2.custom_minimum_size.x = float(Tk.px(VEC_W))
			f2.connect("value_changed", _on_field.bind(path, i))
			f2.connect("edit_begun", _on_edit_begun)
			f2.connect("edit_ended", _on_edit_ended)
			editors.add_child(f2)
			list.append(f2)
		if bool(spec.get("scale_link", false)):
			var link: Button = toggle_icon("link", "Link X and Y", true)
			link.set("icon_px", 12.0)
			link.pressed.connect(_on_scale_link.bind(link))
			editors.add_child(link)
			rec["link"] = link
	elif kind == "bool":
		var cb: CheckBox = CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_on_bool.bind(path))
		editors.add_child(cb)
		list.append(cb)
	elif kind == "enum":
		var drop: Button = PmDrop.make_drop(spec.get("choices", []), "")
		drop.custom_minimum_size.x = float(Tk.px(110.0))
		drop.connect("changed", _on_enum.bind(path))
		editors.add_child(drop)
		list.append(drop)
	elif kind == "color":
		var cbtn: Button = PmButton.make("Colour")
		cbtn.custom_minimum_size.x = float(Tk.px(90.0))
		cbtn.pressed.connect(_on_colour.bind(path, cbtn))
		editors.add_child(cbtn)
		list.append(cbtn)
	elif kind == "curve":
		var ce: Control = _CurveEdit.new()
		ce.custom_minimum_size = Vector2(float(Tk.px(120.0)), float(Tk.px(60.0)))
		ce.connect("curve_changed", _on_curve.bind(path))
		editors.add_child(ce)
		list.append(ce)
	elif kind == "multiline":
		var te: TextEdit = TextEdit.new()
		te.add_theme_stylebox_override("normal", text_area_box(false))
		te.add_theme_stylebox_override("focus", text_area_box(true))
		te.custom_minimum_size = Vector2(float(Tk.px(TEXT_W)), float(Tk.px(Tk.sz("field_h"))))
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
		te.text_changed.connect(_on_multiline_changed.bind(te, path))
		te.text_set.connect(fit_text_area.bind(te))
		te.resized.connect(fit_text_area.bind(te))
		te.focus_exited.connect(_on_multiline_done)
		if path == "props.text":
			TokenComplete.attach(te, _token_context)
		editors.add_child(te)
		list.append(te)
		fit_text_area.call_deferred(te)
	elif kind == "texture":
		var le: LineEdit = PmUI.line_edit("Image path")
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_submitted.connect(_on_text.bind(path))
		editors.add_child(le)
		list.append(le)
		var browse: Button = quiet_icon("folder", "Browse")
		browse.pressed.connect(_on_browse_texture.bind(path))
		editors.add_child(browse)
		load("res://modules/core_panels/shader_import.gd").call("add_bin_pick", self, editors, path)
	elif kind == "layer":
		var choices: Array = [PmDrop.choice("none", "None")]
		var s: Sequence = seq()
		if s != null:
			for t: Track in Verbs.layer_tracks(s):
				choices.append(PmDrop.choice(t.id, t.shown_label()))
		var ldrop: Button = PmDrop.make_drop(choices, "none")
		ldrop.connect("changed", _on_layer.bind(path))
		editors.add_child(ldrop)
		list.append(ldrop)
	elif kind == "sound":
		list.append_array(SoundWell.add(self, editors, spec))
	else:
		var le2: LineEdit = PmUI.line_edit("")
		le2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le2.text_submitted.connect(_on_text.bind(path))
		editors.add_child(le2)
		list.append(le2)
	rec["editors"] = list


func _row_for(path: String) -> Dictionary:
	for r: Dictionary in _rows:
		if String(r["path"]) == path:
			return r
	return {}


func _rows_for(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _rows:
		if String(r["path"]) == path:
			out.append(r)
	return out


func _clip_time() -> float:
	var c: Clip = target_clip()
	if c == null:
		return 0.0
	return playhead() - c.start


func current_value(spec: Dictionary) -> Variant:
	if spec.has("members"):
		return _many_lead_value(spec)
	var c: Clip = target_clip()
	if c == null:
		return null
	return _value_at(c, spec, String(spec["path"]))


func _value_at(c: Clip, spec: Dictionary, path: String) -> Variant:
	if String(spec.get("special", "")) == TransitionEc.SPECIAL:
		return TransitionEc.value(c, spec)
	var local_t: float = playhead() - c.start
	if spec.has("prop"):
		var own: Dictionary = c.get_param(path)
		if own.is_empty():
			return _prop_value(c, String(spec["prop"]))
		var now: Variant = AnimProp.evaluate(own, c.param_time(path, local_t), c.duration, fps())
		if String(spec["prop"]) == "font" and now is String and String(now).is_empty():
			return "default"
		return now
	if spec.has("field"):
		var dict: Dictionary = c.get(String(spec["field"]))
		return dict.get(String(spec["key"]), spec.get("default", null))
	if String(spec.get("special", "")) == "reverse":
		return c.static_speed() < 0.0
	var p: Dictionary = c.get_param(path)
	if p.is_empty():
		return MonitorHandles.pair_default(c, path)
	return AnimProp.evaluate(p, c.param_time(path, local_t), c.duration, fps())


func refresh_values() -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	if _many_on:
		_refresh_many(_rows)
		return
	_refresh_anim_note(c)
	_sync_record_dots(c)
	_refresh_drives()
	var ph: float = playhead()
	for r: Dictionary in _rows:
		var spec: Dictionary = r["spec"]
		var v: Variant = current_value(spec)
		var kind: String = String(spec["kind"])
		var editors: Array = r["editors"]
		var mul: float = float(spec.get("display_mul", 1.0))
		if kind == "float" or kind == "int":
			var f: Control = editors[0]
			if not bool(f.get("_dragging")) and f.get("_editor") == null:
				var fv: float = 0.0
				if v is Array:
					fv = float((v as Array)[int(spec.get("component", 0))])
				elif v != null:
					fv = float(v)
				if bool(spec.get("db", false)):
					fv = 20.0 * log(maxf(fv, 0.0001)) / log(10.0) if fv > 0.0001 else -60.0
				f.set("value", fv * mul)
		elif kind == "vec2":
			for i: int in 2:
				var f2: Control = editors[i]
				if not bool(f2.get("_dragging")) and f2.get("_editor") == null:
					var comp: float = float((v as Array)[i]) if v is Array and (v as Array).size() > i else 0.0
					f2.set("value", comp * mul)
			if r.has("link"):
				(r["link"] as Button).button_pressed = bool(c.transform.get("scale_linked", true))
		elif kind == "bool":
			var cb: CheckBox = editors[0]
			cb.set_pressed_no_signal(bool(v) if v != null else false)
		elif kind == "enum":
			var drop: Button = editors[0]
			var id: String = str(int(v)) if bool(spec.get("numeric", false)) and v != null else String(v) if v != null else ""
			drop.call("set_value", id, false)
		elif kind == "color":
			var col: Color = _as_colour(v)
			(editors[0] as Button).set("icon_name", "")
			(editors[0] as Button).text = "#" + col.to_html(false)
		elif kind == "curve":
			(editors[0] as Control).call("set_points", v if v is Array else [])
		elif kind == "texture" or kind == "string":
			var le: LineEdit = editors[0]
			if not le.has_focus():
				le.text = String(v) if v != null else ""
		elif kind == "multiline":
			var te: TextEdit = editors[0]
			var want: String = String(v) if v != null else ""
			if not te.has_focus() and te.text != want:
				te.text = want
		elif kind == "layer":
			var lv: String = String(v) if v != null else ""
			(editors[0] as Button).call("set_value", lv if not lv.is_empty() else "none", false)
		elif kind == "sound":
			SoundWell.refresh(editors[0], v, self)
		if bool(spec.get("keyable", false)):
			var p: Dictionary = c.get_param(String(spec["path"]))
			var animated: bool = AnimProp.is_animated(p)
			var armed: bool = animated or bus().is_armed(c.id, String(spec["path"]))
			(r["stopwatch"] as Button).set("active", armed)
			(r["nav"] as Control).modulate.a = 1.0 if animated else 0.35
			if animated:
				var has: bool = AnimProp.has_key_at(p, c.param_time(String(spec["path"]), ph - c.start))
				(r["diamond"] as Button).set("icon_name", "diamond" if has else "diamond_o")
			var strip: Variant = r["strip"]
			if strip is Control:
				(strip as Control).queue_redraw()
			_refresh_mark(r, c)
			if r.get("mods") is Control and bool((r["strip_holder"] as Control).get("open")):
				var mods_box: VBoxContainer = r["mods"]
				var mod_count: int = AnimProp.modifier_indices(p).size()
				if int(mods_box.get_meta("mod_count", -1)) != mod_count and not _dragging_field:
					_refresh_mods(r)
	paint_values()


static func _as_colour(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	if v is Color:
		return v
	return Color.WHITE


func _write(spec: Dictionary, value: Variant) -> void:
	if spec.has("members"):
		_write_many(spec, value)
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	var path: String = String(spec["path"])
	if String(spec.get("special", "")) == TransitionEc.SPECIAL:
		TransitionEc.write(self, c, spec, value)
		return
	if _record_write(spec, c, d, s, path, value):
		return
	if spec.has("prop"):
		var pv: Variant = "" if (String(spec["prop"]) == "font" and String(value) == "default") else value
		var pkey: float = bus().key_time_for(c, path, playhead())
		Verbs.set_clip_param(d, s, c.id, path, pv, pkey, _dragging_field)
		if _dragging_field:
			_live_label = "Set " + String(spec["label"])
		return
	if spec.has("field"):
		var dict: Dictionary = (c.get(String(spec["field"])) as Dictionary).duplicate(true)
		dict[String(spec["key"])] = value
		if spec.has("default") and same_value(value, spec["default"]):
			dict.erase(String(spec["key"]))
		Verbs.run(d, "Set " + String(spec["label"]), [ClipCmds.SetClipField.new(s.id, c.id, String(spec["field"]), dict)])
		return
	if String(spec.get("special", "")) == "reverse":
		var sp: float = c.static_speed()
		if sp == 0.0:
			return
		var want_neg: bool = bool(value)
		if (sp < 0.0) != want_neg:
			Verbs.set_clip_param(d, s, c.id, "speed", -sp)
		return
	if String(spec.get("special", "")) == "anim_speed" and _write_anim_speed(c, value):
		return
	if String(spec.get("special", "")) == "inner_speed" and _write_inner_speed(c, path, value):
		return
	var key_at: float = bus().key_time_for(c, path, playhead())
	var live: bool = _dragging_field
	if spec.has("uid"):
		var ok: bool = false
		if key_at >= 0.0 and DISCRETE_KINDS.has(String(spec["kind"])):
			ok = write_hold_key(c, String(spec["uid"]), String(spec["key"]), value, key_at, live)
		else:
			ok = Verbs.set_effect_param(d, s, c.id, String(spec["uid"]), String(spec["key"]), value, key_at, live)
		if ok and String(spec["kind"]) == "enum":
			var writes: Dictionary = EffectSource.enum_writes(String(spec["eid"]), String(spec["key"]), int(value))
			for wk: String in writes.keys():
				Verbs.set_effect_param(d, s, c.id, String(spec["uid"]), wk, writes[wk], -1.0)
		if live:
			_live_label = "Set " + String(spec["label"])
		return
	if path == AnimTime.MEDIA_SPEED_PATH and key_at < 0.0 and _write_speed(PackedStringArray([c.id]), float(value), []):
		return
	Verbs.set_clip_param(d, s, c.id, path, value, key_at, live)
	if live:
		_live_label = "Set " + String(spec["label"])


func _on_edit_begun() -> void:
	_dragging_field = true
	_live_label = ""


func _on_edit_ended() -> void:
	_dragging_field = false
	var d: Project = doc()
	RecordCmds.finish(d)
	if d != null and d.undo.has_live():
		d.undo.commit_live(_live_label if not _live_label.is_empty() else "Set value")
	_live_label = ""
	queue_rebuild()


func _on_field(v: float, path: String, component: int) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	var spec: Dictionary = r["spec"]
	for rr: Dictionary in _rows_for(path):
		if int((rr["spec"] as Dictionary).get("component", -1)) == component or not (rr["spec"] as Dictionary).has("component"):
			spec = rr["spec"]
	var mul: float = float(spec.get("display_mul", 1.0))
	var real: float = v / mul
	if bool(spec.get("db", false)):
		real = pow(10.0, v / 20.0) if v > -60.0 else 0.0
	var kind: String = String(spec["kind"])
	if spec.has("members"):
		_field_many(spec, real, component)
		return
	if kind == "vec2" or spec.has("component"):
		var cur: Variant = current_value(spec)
		var arr: Array = (cur as Array).duplicate() if cur is Array else [0.0, 0.0]
		var idx: int = int(spec.get("component", component))
		var linked: bool = bool(spec.get("scale_link", false)) and bool(target_clip().transform.get("scale_linked", true))
		if linked and arr.size() >= 2 and float(arr[idx]) != 0.0:
			var ratio: float = real / float(arr[idx])
			arr[0] = float(arr[0]) * ratio
			arr[1] = float(arr[1]) * ratio
		else:
			arr[idx] = real
		_write(spec, arr)
		return
	if kind == "int":
		_write(spec, int(round(real)))
		return
	_write(spec, real)


func text_rows_max() -> int:
	if not Prefs.is_registered(PREF_TEXT_ROWS):
		Prefs.register(PREF_TEXT_ROWS, TEXT_ROWS_DEFAULT, {"label": "Rows a text box in Effect Controls grows to before it scrolls", "type": "int", "min": 1, "max": 40})
	return maxi(1, int(Prefs.get_value(PREF_TEXT_ROWS)))


func text_area_box(focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_field"]
	sb.border_color = Tk.c["accent"] if focused else Tk.c["border_text"]
	sb.set_border_width_all(TEXT_BORDER)
	sb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_field"))))
	sb.anti_aliasing = true
	sb.content_margin_left = TEXT_PAD_H
	sb.content_margin_right = TEXT_PAD_H
	sb.content_margin_top = TEXT_PAD_V
	sb.content_margin_bottom = TEXT_PAD_V
	return sb


func text_area_rows(te: TextEdit) -> int:
	if te == null or not is_instance_valid(te):
		return 1
	return clampi(te.get_total_visible_line_count(), 1, text_rows_max())


func text_area_height(line_h: float, rows: int) -> float:
	var one: float = float(Tk.px(Tk.sz("field_h")))
	if line_h <= 0.0:
		return one
	return maxf(one, line_h * float(maxi(rows, 1)) + TEXT_PAD_V * 2.0)


func fit_text_area(te: TextEdit) -> void:
	if te == null or not is_instance_valid(te):
		return
	var want: float = text_area_height(float(te.get_line_height()), text_area_rows(te))
	if absf(te.custom_minimum_size.y - want) < 0.5:
		return
	te.custom_minimum_size.y = want


func _on_multiline_changed(te: TextEdit, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	if not _dragging_field:
		_dragging_field = true
		_live_label = ""
	fit_text_area(te)
	_write(r["spec"], te.text)


func _token_context() -> Dictionary:
	var s: Sequence = seq()
	return TokenComplete.title_context(doc(), s, target_clip(), s.playhead if s != null else 0.0)


func _on_multiline_done() -> void:
	if _dragging_field:
		_on_edit_ended()


func _on_bool(on: bool, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		_write(r["spec"], on)


func _on_enum(id: String, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	var spec: Dictionary = r["spec"]
	if bool(spec.get("numeric", false)):
		_write(spec, int(id))
	else:
		_write(spec, id)


func focus_text() -> void:
	var loop: SceneTree = _root.get_tree() if _root != null else null
	if loop == null:
		return
	await loop.process_frame
	await loop.process_frame
	var r: Dictionary = _row_for("props.text")
	if r.is_empty():
		return
	var eds: Array = r["editors"]
	if eds.is_empty() or not (eds[0] is TextEdit):
		return
	var te: TextEdit = eds[0]
	te.grab_focus()
	te.select_all()


func _on_text(text: String, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		_write(r["spec"], text)


func _on_layer(id: String, path: String) -> void:
	_on_text("" if id == "none" else id, path)


func _on_curve(points: Array, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		_write(r["spec"], points)


func _on_scale_link(link: Button) -> void:
	if _many_on:
		_scale_link_many(link.button_pressed)
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null:
		return
	var tf: Dictionary = c.transform.duplicate(true)
	tf["scale_linked"] = link.button_pressed
	Verbs.run(d, "Scale link", [ClipCmds.SetClipField.new(s.id, c.id, "transform", tf)])


func _on_colour(path: String, anchor: Control) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.color = _as_colour(current_value(r["spec"]))
	picker.color_changed.connect(_on_colour_changed.bind(path))
	picker.edit_alpha = true
	_colour_window = PmWindow.open(_root, String(r["label"]), picker, Vector2(300.0, 420.0), "controls.colour")
	_colour_window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))


func _on_colour_changed(col: Color, path: String) -> void:
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		_write(r["spec"], [col.r, col.g, col.b, col.a])


func _on_browse_texture(path: String) -> void:
	if _texture_dialog == null:
		_texture_dialog = FileDialog.new()
		_texture_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_texture_dialog.use_native_dialog = true
		_texture_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga,*.cube ; Pictures and LUTs", "*.cube ; LUTs"])
		_texture_dialog.file_selected.connect(_on_texture_picked)
		_root.add_child(_texture_dialog)
	_texture_target = {"path": path}
	_texture_dialog.popup_centered(Vector2i(900, 600))


func _on_texture_picked(file: String) -> void:
	_on_text(file, String(_texture_target.get("path", "")))


func _on_stopwatch(path: String) -> void:
	if _many_on:
		_stopwatch_many(path)
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null:
		return
	var ph: float = playhead()
	var p: Dictionary = c.get_param(path)
	if AnimProp.is_animated(p):
		var v: Variant = AnimProp.evaluate(p, c.param_time(path, ph - c.start), c.duration, s.fps)
		Verbs.set_clip_param(d, s, c.id, path, v, -1.0)
		bus().set_armed(c.id, path, false)
		return
	var cur: Variant = AnimProp.static_value(p) if not p.is_empty() else _seed_for(c, path)
	var r: Dictionary = _row_for(path)
	if not r.is_empty() and DISCRETE_KINDS.has(String((r["spec"] as Dictionary).get("kind", ""))):
		var first: Dictionary = AnimProp.set_key(p if not p.is_empty() else AnimProp.make(cur), c.param_time(path, ph - c.start), cur, "hold")
		Verbs.set_clip_prop(d, s, c.id, path, first, "Start keyframes")
	else:
		Verbs.set_clip_param(d, s, c.id, path, cur, ph)
	bus().set_armed(c.id, path, true)


func write_hold_key(c: Clip, uid: String, key: String, value: Variant, key_at: float, live: bool) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return false
	var cmd: Command = EffectCmds.SetEffectParam.new(s.id, c.id, uid, key, value, c.param_time(("audio_effects." if c.is_audio_effect(uid) else "effects.") + uid + "." + key, key_at - c.start), c.is_audio_effect(uid), "hold", live)
	if live:
		d.undo.live(cmd)
		return cmd.ok
	return Verbs.run(d, cmd.label, [cmd])


func _seed_for(c: Clip, path: String) -> Variant:
	if path.begins_with("props."):
		var v: Variant = _prop_value(c, path.substr(6))
		if v != null:
			return v
	return 0.0


func _on_key_toggle(path: String) -> void:
	if _many_on:
		_key_toggle_many(path)
		return
	var c: Clip = target_clip()
	if c != null:
		Verbs.toggle_keyframe(doc(), seq(), c.id, path, playhead())


func _on_key_nav(path: String, dir: int) -> void:
	if _many_on:
		_key_nav_many(path, dir)
		return
	var c: Clip = target_clip()
	if c == null:
		return
	var lt: float = playhead() - c.start
	var best: float = -INF if dir > 0 else INF
	var found: bool = false
	for kt: float in AnimTime.played_list(c, path):
		if dir > 0 and kt > lt + 0.0001 and (not found or kt < best):
			best = kt
			found = true
		if dir < 0 and kt < lt - 0.0001 and (not found or kt > best):
			best = kt
			found = true
	if found:
		Session.set_playhead(c.start + best)


func _on_fold(path: String) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty() or _many_on:
		return
	if _open_strips.has(path):
		_open_strips.erase(path)
		(r["strip_holder"] as Control).call("set_open", false, true)
		(r["fold"] as Button).set("icon_name", "chev_r")
		return
	_open_strips[path] = true
	_open_strip(r, true)


func _open_strip(r: Dictionary, animate: bool = false) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var holder: Control = r["strip_holder"]
	var inner: VBoxContainer = holder.get("inner")
	var fresh: bool = r["strip"] == null
	if fresh:
		var strip: Control = KeyframeStrip.make(c.id, String(r["path"]))
		var rng: Vector2 = _declared_range(r["spec"])
		strip.set("range_lo", rng.x)
		strip.set("range_hi", rng.y)
		strip.set("display_mul", float((r["spec"] as Dictionary).get("display_mul", 1.0)))
		strip.set("suffix", String((r["spec"] as Dictionary).get("suffix", "")).strip_edges())
		inner.add_child(strip)
		r["strip"] = strip
		var mods: VBoxContainer = PmUI.vbox(0)
		inner.add_child(mods)
		r["mods"] = mods
		var sheets: VBoxContainer = PmUI.vbox(0)
		inner.add_child(sheets)
		r["sheets"] = sheets
	_refresh_mods(r)
	holder.visible = true
	holder.call("set_open", true, animate)
	(r["fold"] as Button).set("icon_name", "chev_d")


func _declared_range(spec: Dictionary) -> Vector2:
	var lo: float = float(spec.get("min", -INF))
	var hi: float = float(spec.get("max", INF))
	if bool(spec.get("db", false)):
		return Vector2(0.0, 2.0)
	return Vector2(lo, hi)


func _refresh_mods(r: Dictionary) -> void:
	var mods: Variant = r.get("mods", null)
	if not (mods is VBoxContainer):
		return
	var box: VBoxContainer = mods
	PmUI.clear(box)
	var c: Clip = target_clip()
	if c == null:
		return
	var path: String = String(r["path"])
	var p: Dictionary = c.get_param(path)
	var idx: PackedInt32Array = AnimProp.modifier_indices(p)
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	head.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
	head.add_child(PmLabel.dim("Modifiers" if not idx.is_empty() else "No modifiers"))
	var add_noise: Button = PmButton.make("Noise", "plus")
	add_noise.set("quiet", true)
	add_noise.pressed.connect(_on_add_modifier.bind(path, "noise"))
	head.add_child(add_noise)
	var add_wave: Button = PmButton.make("Wave", "plus")
	add_wave.set("quiet", true)
	add_wave.pressed.connect(_on_add_modifier.bind(path, "wave"))
	head.add_child(add_wave)
	var add_expr: Button = PmButton.make("Expression", "plus")
	add_expr.name = "AddExpression"
	add_expr.set("quiet", true)
	add_expr.pressed.connect(_on_add_modifier.bind(path, "expr"))
	head.add_child(add_expr)
	var add_driven: Button = PmButton.make("Driven", "plus")
	add_driven.name = "AddDriven"
	add_driven.set("quiet", true)
	add_driven.pressed.connect(_on_add_modifier.bind(path, "driven"))
	head.add_child(add_driven)
	if not idx.is_empty():
		var bake: Button = PmButton.make("Bake to keys")
		bake.set("quiet", true)
		bake.pressed.connect(_on_bake.bind(path))
		head.add_child(bake)
	box.add_child(head)
	var stack_rows: Array[Dictionary] = AnimLayerUi.stack_rows(p)
	if stack_rows.size() > 1:
		var strip: VBoxContainer = AnimLayerStack.make(stack_rows)
		strip.connect("reordered", _on_stack_reorder.bind(path))
		strip.connect("flipped", _on_stack_flip.bind(path))
		strip.connect("opened", _on_stack_open.bind(path))
		box.add_child(strip)
	var layers: Array = p.get("layers", []) if AnimProp.is_animated(p) else []
	for li: int in idx:
		var layer: Dictionary = layers[li]
		var kind: String = str(layer.get("type", ""))
		var mrow: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		mrow.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
		var on: CheckBox = CheckBox.new()
		on.focus_mode = Control.FOCUS_NONE
		on.button_pressed = bool(layer.get("on", true))
		on.toggled.connect(_on_layer_field.bind(path, li, "on"))
		mrow.add_child(on)
		if kind == "noise":
			var kinds: Array = []
			for k: String in ["value", "perlin", "simplex", "fractal", "white", "brownian"]:
				kinds.append(PmDrop.choice(k, k.capitalize()))
			var kd: Button = PmDrop.make_drop(kinds, str(layer.get("kind", "perlin")))
			kd.custom_minimum_size.x = float(Tk.px(84.0))
			kd.connect("changed", _on_layer_text.bind(path, li, "kind"))
			mrow.add_child(kd)
		elif kind == "wave":
			var shapes: Array = []
			for sh: String in ["sine", "triangle", "square", "saw"]:
				shapes.append(PmDrop.choice(sh, sh.capitalize()))
			var sd: Button = PmDrop.make_drop(shapes, str(layer.get("shape", "sine")))
			sd.custom_minimum_size.x = float(Tk.px(84.0))
			sd.connect("changed", _on_layer_text.bind(path, li, "shape"))
			mrow.add_child(sd)
		elif kind == "expr" or kind == "driven":
			mrow.add_child(PmLabel.body("Expression" if kind == "expr" else "Driven"))
			mrow.add_child(PmLabel.dim(_mod_summary(c, layer, kind)))
			var edit: Button = PmButton.make("Edit")
			edit.set("quiet", true)
			edit.pressed.connect(open_anim_sheet.bind(path, kind))
			mrow.add_child(edit)
		else:
			mrow.add_child(PmLabel.body(kind.capitalize()))
		if kind == "noise" or kind == "wave":
			mrow.add_child(PmLabel.dim("Amount"))
			var amp: Control = PmField.make(float(layer.get("amp", 1.0)), -INF, INF, 0.1, "")
			amp.custom_minimum_size.x = float(Tk.px(64.0))
			amp.connect("value_changed", _on_layer_number.bind(path, li, "amp"))
			mrow.add_child(amp)
			mrow.add_child(PmLabel.dim("Speed"))
			var freq: Control = PmField.make(float(layer.get("freq", 1.0)), 0.0, INF, 0.1, " Hz")
			freq.custom_minimum_size.x = float(Tk.px(64.0))
			freq.connect("value_changed", _on_layer_number.bind(path, li, "freq"))
			mrow.add_child(freq)
		if kind == "noise":
			mrow.add_child(PmLabel.dim("Detail"))
			var oct: Control = PmField.make(float(layer.get("oct", 3)), 1.0, 8.0, 1.0, "")
			oct.set("precision", 0)
			oct.custom_minimum_size.x = float(Tk.px(48.0))
			oct.connect("value_changed", _on_layer_number.bind(path, li, "oct"))
			mrow.add_child(oct)
			var reseed: Button = quiet_icon("loop", "New seed")
			reseed.pressed.connect(_on_layer_number.bind(float(randi() % 100000), path, li, "seed"))
			mrow.add_child(reseed)
		elif kind == "wave":
			mrow.add_child(PmLabel.dim("Phase"))
			var ph: Control = PmField.make(float(layer.get("phase", 0.0)), -INF, INF, 0.05, "")
			ph.custom_minimum_size.x = float(Tk.px(56.0))
			ph.connect("value_changed", _on_layer_number.bind(path, li, "phase"))
			mrow.add_child(ph)
		mrow.add_child(PmUI.spacer())
		var del: Button = quiet_icon("trash", "Remove modifier")
		del.pressed.connect(_on_remove_layer.bind(path, li))
		mrow.add_child(del)
		box.add_child(mrow)
	box.set_meta("mod_count", idx.size())


func _mod_summary(c: Clip, layer: Dictionary, kind: String) -> String:
	if kind == "expr":
		return str(layer.get("code", ""))
	var src: Dictionary = AnimProp.driven_source(layer)
	var sp: String = str(src.get("path", ""))
	if sp.is_empty():
		return "nothing picked yet"
	var s: Sequence = seq()
	var from: Clip = s.clip_by_id(str(src.get("clip", ""))) if s != null else null
	var head: String = AnimLayerUi.path_label(from if from != null else c, sp)
	return head + (", switched off by a loop" if AnimLayerUi.struck(layer) else "")


func _write_prop(path: String, prop: Dictionary, label: String) -> void:
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	Verbs.set_clip_prop(d, s, c.id, path, prop, label)
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		_refresh_mods(r)
		if r["strip"] is Control:
			(r["strip"] as Control).queue_redraw()
		_refresh_mark(r, c)
		var sheet: Variant = r.get("sheet", null)
		if sheet is Control and (sheet as Control).has_method("refresh"):
			(sheet as Control).call("refresh")
		_sync_drive(r)


func _on_add_modifier(path: String, kind: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var p: Dictionary = c.get_param(path)
	var r: Dictionary = _row_for(path)
	var rng: Vector2 = _declared_range(r["spec"]) if not r.is_empty() else Vector2(-INF, INF)
	var amp: float = 1.0
	if rng.x > -INF and rng.y < INF:
		amp = (rng.y - rng.x) * 0.1
	else:
		var cur: float = AnimProp.evaluate_float(p, c.param_time(path, playhead() - c.start), c.duration, fps())
		amp = maxf(absf(cur) * 0.1, 1.0)
	var layer: Dictionary = AnimProp.new_noise_layer(amp, 2.0) if kind == "noise" else AnimProp.new_wave_layer(amp, 1.0)
	if kind == "expr":
		layer = AnimProp.new_expr_layer("value")
	elif kind == "driven":
		layer = AnimProp.new_driven_layer(c.id, "")
		layer["out_min"] = rng.x if rng.x > -INF else 0.0
		layer["out_max"] = rng.y if rng.y < INF else 1.0
		var src: Dictionary = layer["src"]
		src["src_start"] = c.start
		src["dst_start"] = c.start
	if not _open_strips.has(path):
		_open_strips[path] = true
		if not r.is_empty():
			_open_strip(r)
	_write_prop(path, AnimProp.add_layer(p, layer), "Add " + kind)
	if kind == "expr" or kind == "driven":
		open_anim_sheet(path, kind)


func _on_layer_field(on: bool, path: String, index: int, key: String) -> void:
	var c: Clip = target_clip()
	if c != null:
		_write_prop(path, AnimProp.set_layer_field(c.get_param(path), index, key, on), "Modifier " + key)


func _on_layer_text(id: String, path: String, index: int, key: String) -> void:
	var c: Clip = target_clip()
	if c != null:
		_write_prop(path, AnimProp.set_layer_field(c.get_param(path), index, key, id), "Modifier " + key)


func _on_layer_number(v: float, path: String, index: int, key: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var value: Variant = v
	if key == "oct" or key == "seed":
		value = int(round(v))
	_write_prop(path, AnimProp.set_layer_field(c.get_param(path), index, key, value), "Modifier " + key)


func _on_remove_layer(path: String, index: int) -> void:
	var c: Clip = target_clip()
	if c != null:
		_write_prop(path, AnimProp.remove_layer(c.get_param(path), index), "Remove modifier")


func _on_bake(path: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var p: Dictionary = c.get_param(path)
	if not AnimProp.has_modifiers(p):
		return
	_write_prop(path, AnimProp.bake(p, c.duration, fps()), "Bake modifiers")


func anim_layer_prop(path: String) -> Dictionary:
	var c: Clip = target_clip()
	return c.get_param(path) if c != null else {}


func anim_sheet_time(path: String) -> Dictionary:
	var c: Clip = target_clip()
	if c == null:
		return {}
	var p: Dictionary = anim_layer_prop(path)
	var t: float = c.param_time(path, playhead() - c.start)
	var below: float = 0.0
	var index: int = AnimLayerUi.layer_index(p, "expr")
	if AnimProp.is_animated(p):
		below = AnimProp.evaluate_float(AnimLayerUi.layers_below(p, index) if index >= 0 else p, t, c.duration, fps())
	elif not p.is_empty():
		below = AnimLayerUi.scalar_of(AnimProp.static_value(p))
	return {"t": t, "dur": c.duration, "value": below, "fps": fps(), "comp": 0}


func set_anim_layer_field(path: String, index: int, key: String, value: Variant, label: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	_write_prop(path, AnimProp.set_layer_field(c.get_param(path), index, key, value), label)


func set_anim_layer_fields(path: String, index: int, fields: Dictionary, label: String) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var p: Dictionary = c.get_param(path)
	for key: String in fields.keys():
		p = AnimProp.set_layer_field(p, index, key, fields[key])
	_write_prop(path, p, label)


func remove_anim_layer(path: String, index: int) -> void:
	_on_remove_layer(path, index)


func move_anim_layer(path: String, from: int, to: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	_write_prop(path, AnimLayerUi.move_layer(c.get_param(path), from, to), "Reorder layers")


func bake_anim_layers(path: String) -> void:
	_on_bake(path)


func _on_stack_reorder(from: int, to: int, path: String) -> void:
	move_anim_layer(path, from, to)


func _on_stack_flip(index: int, on: bool, path: String) -> void:
	set_anim_layer_field(path, index, "on", on, "Layer on")


func _on_stack_open(index: int, path: String) -> void:
	var layer: Dictionary = AnimLayerUi.layer_at(anim_layer_prop(path), index)
	var kind: String = str(layer.get("type", ""))
	if kind == "expr" or kind == "driven":
		open_anim_sheet(path, kind)


func anim_sheet(path: String) -> Control:
	var r: Dictionary = _row_for(path)
	var got: Variant = r.get("sheet", null) if not r.is_empty() else null
	return got if got is Control else null


func open_anim_sheet(path: String, kind: String) -> Control:
	if _many_on:
		return null
	var c: Clip = target_clip()
	if c == null:
		return null
	if AnimLayerUi.layer_index(c.get_param(path), kind) < 0:
		_on_add_modifier(path, kind)
		return anim_sheet(path)
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return null
	if not _open_strips.has(path):
		_open_strips[path] = true
	if r["strip"] == null:
		_open_strip(r)
	close_anim_sheet(path)
	var holder: Variant = r.get("sheets", null)
	if not (holder is VBoxContainer):
		return null
	var sheet: Control = null
	if kind == "expr":
		sheet = AnimExprSheet.make(self, path)
	else:
		sheet = AnimDrivenSheet.make(self, path, String(r.get("label", path)))
	(holder as VBoxContainer).add_child(sheet)
	r["sheet"] = sheet
	return sheet


func drivable(spec: Dictionary) -> bool:
	if not bool(spec.get("keyable", false)) or AnimTime.is_inner(String(spec.get("path", ""))):
		return false
	var kind: String = String(spec.get("kind", ""))
	return DRIVE_KINDS.has(kind) or (kind == "enum" and bool(spec.get("numeric", false)))


func drive_key(path: String) -> String:
	var c: Clip = target_clip()
	return (c.id if c != null else "") + "|" + path


func drive_sheet(path: String) -> Control:
	var r: Dictionary = _row_for(path)
	var got: Variant = r.get("drive", null) if not r.is_empty() else null
	return got if got is Control and is_instance_valid(got as Control) else null


func toggle_drive(path: String) -> void:
	if drive_sheet(path) != null:
		close_drive(path)
	else:
		open_drive(path)


func open_drive(path: String, nth: int = 0) -> Control:
	var r: Dictionary = _row_for(path)
	if r.is_empty() or not drivable(r["spec"]):
		return null
	_drive_open[drive_key(path)] = nth
	_sync_drive(r)
	return drive_sheet(path)


func close_drive(path: String) -> void:
	_drive_open.erase(drive_key(path))
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	var sheet: Variant = r.get("drive", null)
	if sheet is Control and is_instance_valid(sheet as Control):
		PmUI.free_node(sheet as Control)
	r["drive"] = null
	_paint_drive_btn(r, _drive_lead(r))


func _sync_drive(r: Dictionary, lead: Array = []) -> void:
	if r.is_empty() or not r.has("drive_holder"):
		return
	var sheet: Variant = r.get("drive", null)
	if _drive_open.is_empty() and sheet == null:
		_paint_drive_btn(r, lead)
		return
	var path: String = String(r["path"])
	var key: String = drive_key(path)
	var want: bool = _drive_open.has(key)
	var have: bool = sheet is Control and is_instance_valid(sheet as Control)
	if have and (not want or String((sheet as Control).get_meta("drive_key", "")) != key):
		PmUI.free_node(sheet as Control)
		r["drive"] = null
		have = false
	if want and not have:
		var made: Control = DriveSheet.make(self, path, String(r.get("label", path)), int(_drive_open[key]))
		made.set_meta("drive_key", key)
		(r["drive_holder"] as Control).add_child(made)
		r["drive"] = made
	elif want and have:
		(sheet as Control).call("refresh")
	_paint_drive_btn(r, lead)


func _paint_drive_btn(r: Dictionary, lead: Array = []) -> void:
	if r.is_empty():
		return
	var b: Variant = r.get("drive_btn", null)
	if not (b is Button) or not is_instance_valid(b as Button):
		return
	var who: Array = lead if not lead.is_empty() else _drive_lead(r)
	var c: Clip = who[0]
	var open: bool = r.get("drive", null) is Control and is_instance_valid(r["drive"] as Control)
	var on: bool = open or (c != null and _driven_paths(c).has(String(who[1])))
	if (b as Button).button_pressed != on:
		(b as Button).set_pressed_no_signal(on)


func _driven_paths(c: Clip) -> Dictionary:
	var d: Project = doc()
	var key: String = c.id + "|" + str(d.serial if d != null else 0) + "|" + str(d.undo.live_serial if d != null and d.undo != null else 0)
	if key == _driven_key:
		return _driven_cache
	_driven_key = key
	_driven_cache = {}
	for path: String in c.param_paths():
		var p: Dictionary = c.get_param(path)
		if AnimProp.is_animated(p) and Drive.count(p) > 0:
			_driven_cache[path] = true
	return _driven_cache


func _refresh_drives() -> void:
	var c: Clip = target_clip()
	if _drive_open.is_empty() and not _many_on:
		var driven: Dictionary = _driven_paths(c) if c != null else {}
		for r0: Dictionary in _rows:
			var b: Variant = r0.get("drive_btn", null)
			if b == null or r0.get("drive", null) != null:
				continue
			var on: bool = driven.has(String(r0["path"]))
			if (b as Button).button_pressed != on:
				(b as Button).set_pressed_no_signal(on)
		return
	for r: Dictionary in _rows:
		if r.get("drive_btn", null) != null:
			_sync_drive(r, [] if _many_on else [c, String(r["path"])])


func _drive_members(r: Dictionary) -> Dictionary:
	if r.is_empty():
		return {}
	var spec: Dictionary = r["spec"]
	if _many_on and spec.has("members"):
		return spec["members"]
	var c: Clip = target_clip()
	return {c.id: String(r["path"])} if c != null else {}


func _drive_lead(r: Dictionary) -> Array:
	var s: Sequence = seq()
	var members: Dictionary = _drive_members(r)
	var c: Clip = target_clip()
	if c != null and members.has(c.id):
		return [c, String(members[c.id])]
	if s != null:
		for cid: Variant in members.keys():
			var m: Clip = s.clip_by_id(String(cid))
			if m != null:
				return [m, String(members[cid])]
	return [null, String(r.get("path", ""))]


func drive_target(path: String) -> Clip:
	return _drive_lead(_row_for(path))[0]


func drive_time(path: String) -> Dictionary:
	var who: Array = _drive_lead(_row_for(path))
	var c: Clip = who[0]
	if c == null:
		return {}
	var real: String = String(who[1])
	return {"t": c.param_time(real, playhead() - c.start), "dur": c.duration, "fps": fps(), "comp": 0}


func drive_prop(path: String) -> Dictionary:
	var who: Array = _drive_lead(_row_for(path))
	var c: Clip = who[0]
	return c.get_param(String(who[1])) if c != null else {}


func drive_write(path: String, prop: Dictionary, label: String) -> void:
	var r: Dictionary = _row_for(path)
	if not _many_on or r.is_empty():
		_write_prop(path, prop, label)
		return
	var d: Project = doc()
	var s: Sequence = seq()
	var who: Array = _drive_lead(r)
	var lead: Clip = who[0]
	if d == null or s == null or lead == null:
		return
	var layers: Array = []
	for i: int in Drive.indices(prop):
		layers.append((prop["layers"] as Array)[i])
	var cmds: Array[Command] = []
	var members: Dictionary = _drive_members(r)
	for cid: Variant in members.keys():
		var m: Clip = s.clip_by_id(String(cid))
		if m == null:
			continue
		var real: String = String(members[cid])
		var own: Dictionary = prop if m == lead else Drive.with_drivers(Drive.seeded(m.get_param(real), _value_at(m, r["spec"], real)), layers, m.id, m.start, lead.id)
		if m.get_param(real) != own:
			var cmd: Command = ClipCmds.SetClipParam.new(s.id, m.id, real, own)
			cmd.label = label
			cmds.append(cmd)
	if not cmds.is_empty():
		Verbs.run(d, label, cmds)
	_sync_drive(r)


func drive_note(text: String) -> void:
	last_drive_note = text


func drive_info(path: String) -> Dictionary:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return Drive.info(-INF, INF, 1, "", path)
	var spec: Dictionary = r["spec"]
	var kind: String = String(spec.get("kind", "float"))
	var n: int = 2 if kind == "vec2" else (3 if kind == "vec3" else (4 if kind == "color" else 1))
	var lo: float = float(spec.get("min", -INF))
	var hi: float = float(spec.get("max", INF))
	if kind == "color":
		lo = 0.0
		hi = 1.0
	var out: Dictionary = Drive.info(lo, hi, n, String(spec.get("suffix", "")), String(r.get("label", path)))
	out["mul"] = float(spec.get("display_mul", 1.0))
	return out


func _drive_defaults(path: String) -> Array:
	var r: Dictionary = _row_for(path)
	var inf: Dictionary = drive_info(path)
	var n: int = int(inf["comps"])
	var cur: Variant = current_value(r["spec"]) if not r.is_empty() else 0.0
	var lo: float = float(inf["lo"])
	var hi: float = float(inf["hi"])
	if not is_inf(lo) and not is_inf(hi) and hi > lo:
		if n <= 1:
			return [lo, hi]
		var a: Array = []
		var b: Array = []
		for k: int in n:
			a.append(lo)
			b.append(hi)
		return [a, b]
	if n <= 1:
		var v: float = Drive._num(cur, 0)
		return [v, v + maxf(absf(v) * 0.5, 100.0)]
	var from: Array = []
	var to: Array = []
	for k2: int in n:
		var v2: float = Drive._num(cur, k2)
		from.append(v2)
		to.append(v2 + (maxf(absf(v2) * 0.5, 100.0) if k2 == 0 else 0.0))
	return [from, to]


func _drive_seeded(path: String) -> Dictionary:
	var r: Dictionary = _row_for(path)
	var who: Array = _drive_lead(r)
	var c: Clip = who[0]
	if c == null or r.is_empty():
		return {}
	return Drive.seeded(c.get_param(String(who[1])), current_value(r["spec"]))


func add_drive_layer(path: String, kind: String) -> int:
	var c: Clip = drive_target(path)
	if c == null:
		return 0
	var ends: Array = _drive_defaults(path)
	var p: Dictionary = Drive.add(_drive_seeded(path), Drive.new_layer(kind, c.id, c.start, ends[0], ends[1]))
	drive_write(path, p, "Add driver")
	return maxi(Drive.count(drive_prop(path)) - 1, 0)


func copy_drivers(path: String, all: bool = true, nth: int = 0) -> bool:
	var c: Clip = drive_target(path)
	if c == null:
		return false
	return not Drive.copy(drive_prop(path), -1 if all else nth, drive_info(path), c.id).is_empty()


func paste_drivers(path: String) -> String:
	var c: Clip = drive_target(path)
	if c == null or not Drive.has_clip():
		return ""
	var got: Dictionary = Drive.paste(_drive_seeded(path), Drive.clipboard, drive_info(path), c.id, c.start)
	drive_write(path, got["prop"], "Paste drivers")
	last_drive_note = String(got["note"])
	return String(got["note"])


func apply_drive_preset(path: String, preset: Dictionary, source_text: String) -> String:
	var c: Clip = drive_target(path)
	if c == null:
		return ""
	var got: Dictionary = Drive.from_preset(_drive_seeded(path), preset, drive_info(path), c.id, c.start, source_text)
	drive_write(path, got["prop"], "Apply driver preset")
	last_drive_note = String(got["note"])
	return String(got["note"])


func _fit_follow(rest: float) -> float:
	var follow_w: float = float(Tk.px(16.0)) + float(Tk.px(2.0))
	var shown_rest: float = rest + (follow_w if _follow_tight else 0.0)
	var tight: bool = _list.size.x - shown_rest < float(Tk.px(LABEL_FIT_MIN))
	if tight != _follow_tight:
		_follow_tight = tight
		for r: Dictionary in _rows:
			var b: Variant = r.get("drive_slot", null)
			if b is Control and is_instance_valid(b as Control):
				(b as Control).visible = not tight
	return shown_rest - (follow_w if tight else 0.0)


func drive_preset_of_picked() -> Dictionary:
	var pick: String = picked_value()
	var r: Dictionary = _row_by_pick(pick) if not pick.is_empty() else {}
	if r.is_empty():
		return {}
	var path: String = String(r["path"])
	var p: Dictionary = drive_prop(path)
	var layers: Array = []
	for i: int in Drive.indices(p):
		layers.append((p["layers"] as Array)[i])
	if layers.is_empty():
		return {}
	return Presets.make(Drive.PRESET_KIND, "Drivers of " + String(r.get("label", path)), Drive.preset_payload(layers, drive_info(path)))


func effect_driven(c: Clip, uid: String, sound: bool) -> bool:
	if c == null:
		return false
	var head: String = ("audio_effects." if sound else "effects.") + uid + "."
	for path: String in c.param_paths():
		if path.begins_with(head) and Drive.count(c.get_param(path)) > 0:
			return true
	return false


func effect_drive_items(uid: String, sound: bool) -> Array:
	var items: Array = []
	var head: String = ("audio_effects." if sound else "effects.") + uid + "."
	var main: String = head + Drive.MAIN_KEY
	for r: Dictionary in _rows:
		if String(r["path"]) == main and drivable(r["spec"]):
			items.append(PmMenu.item(main, "Amount (the whole effect)"))
	var rest: Array = []
	for r2: Dictionary in _rows:
		var p2: String = String(r2["path"])
		if p2.begins_with(head) and p2 != main and drivable(r2["spec"]):
			rest.append(PmMenu.item(p2, String(r2.get("label", p2))))
	if not items.is_empty() and not rest.is_empty():
		items.append(PmMenu.separator())
	items.append_array(rest)
	return items


func _on_effect_drive(uid: String, sound: bool, anchor: Button) -> void:
	anchor.set_pressed_no_signal(effect_driven(target_clip(), uid, sound))
	var items: Array = effect_drive_items(uid, sound)
	if items.is_empty():
		Events.toast("This effect has no values that can be driven")
		return
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", drive_effect_value)


func drive_effect_value(path: String) -> Control:
	var r: Dictionary = _row_for(path)
	if not r.is_empty():
		var hold: Control = r.get("hold") as Control
		if hold != null:
			_open_folds_above(hold)
	return open_drive(path)


func close_anim_sheet(path: String) -> void:
	var r: Dictionary = _row_for(path)
	if r.is_empty():
		return
	var sheet: Variant = r.get("sheet", null)
	if sheet is Control:
		PmUI.free_node(sheet as Control)
	r["sheet"] = null


func _on_layer_mark(path: String) -> void:
	var p: Dictionary = anim_layer_prop(path)
	if AnimLayerUi.has_layer(p, "driven") and not AnimLayerUi.has_layer(p, "expr"):
		open_anim_sheet(path, "driven")
		return
	open_anim_sheet(path, "expr")


func _draw_layer_mark(mark: Button) -> void:
	if not bool(mark.get_meta("struck", false)):
		return
	var pad: float = mark.size.x * 0.15
	mark.draw_line(Vector2(pad, mark.size.y - pad), Vector2(mark.size.x - pad, pad), Tk.c["key_negative"], 1.5, true)


func _refresh_mark(r: Dictionary, c: Clip) -> void:
	var got: Variant = r.get("mark", null)
	if not (got is Button) or c == null:
		return
	var mark: Button = got
	var marks: Array[Dictionary] = AnimLayerUi.marks(c.get_param(String(r["path"])))
	if marks.is_empty():
		mark.visible = false
		mark.set_meta("struck", false)
		return
	var first: Dictionary = marks[marks.size() - 1]
	mark.visible = true
	mark.set("icon_name", String(first["icon"]))
	mark.set_meta("struck", bool(first["struck"]))
	PmUI.tip(mark, String(first["tip"]))
	mark.queue_redraw()


func _on_row_menu(path: String, anchor: Control) -> void:
	if _many_on:
		_row_menu_many(path, anchor)
		return
	var r: Dictionary = _row_for(path)
	var keyable: bool = not r.is_empty() and bool((r["spec"] as Dictionary).get("keyable", false))
	var items: Array = [PmMenu.item("reset", "Reset to default")]
	items.append_array(value_clip_items(path))
	items.append_array(_speed_menu_items(path, keyable))
	if keyable:
		items.append(PmMenu.separator())
		items.append(PmMenu.item("clear_keys", "Remove every key"))
		items.append(PmMenu.item("open_keys", "Open in the Keyframes panel"))
		items.append(PmMenu.item("adjust", "Adjust keys"))
		items.append(PmMenu.separator())
		if drivable(r["spec"]):
			items.append(PmMenu.item("drive", "Drive this value"))
		items.append(PmMenu.item("add_noise", "Add noise"))
		items.append(PmMenu.item("add_wave", "Add wave"))
		items.append_array(AnimLayerUi.menu_items(anim_layer_prop(path)))
		var c: Clip = target_clip()
		if c != null and AnimProp.has_modifiers(c.get_param(path)):
			items.append(PmMenu.item("bake", "Bake modifiers to keyframes"))
	var hold: Control = r.get("hold") as Control
	if hold != null:
		var movable: bool = not String(hold.get_meta(ValueStyle.META_UID, "")).is_empty()
		items.append_array(ValueStyle.menu_items(ValueStyle.store_of(self), path, movable))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_row_menu_picked.bind(path))


func _on_row_menu_picked(id: String, path: String) -> void:
	if AnimLayerUi.owns_menu(id):
		open_anim_sheet(path, AnimLayerUi.kind_of_menu(id))
		return
	if _inner_row_menu(id, path):
		return
	if value_clip_picked(id, path):
		return
	var rec: Dictionary = _row_for(path)
	if ValueStyle.owns_menu(id):
		ValueStyle.picked(self, id, path, rec.get("hold") as Control)
		return
	var c: Clip = target_clip()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null:
		return
	var r: Dictionary = _row_for(path)
	var parts: PackedStringArray = path.split(".")
	if id == "reset":
		var spec: Dictionary = r["spec"] if not r.is_empty() else {}
		if spec.has("uid"):
			var def: Dictionary = EffectSource.get_def(String(spec["eid"]))
			for p: Dictionary in EffectSource.param_specs(def):
				if String(p.get("key", "")) == String(spec["key"]):
					Verbs.set_effect_param(d, s, c.id, String(spec["uid"]), String(spec["key"]), p.get("default", 0.0), -1.0)
		else:
			var defaults: Dictionary = Clip.default_transform()
			if parts.size() == 2 and parts[0] == "transform" and defaults.has(parts[1]):
				Verbs.set_clip_param(d, s, c.id, path, AnimProp.static_value(defaults[parts[1]]), -1.0)
			elif path == "speed":
				Verbs.set_clip_param(d, s, c.id, path, 1.0, -1.0)
			elif path == "audio.volume":
				Verbs.set_clip_param(d, s, c.id, path, 1.0, -1.0)
			elif path == "audio.pan":
				Verbs.set_clip_param(d, s, c.id, path, 0.0, -1.0)
			elif parts.size() == 2 and parts[0] == "motion_blur":
				Verbs.set_clip_param(d, s, c.id, path, float(Clip.default_motion_blur().get(parts[1], 0.0)), -1.0)
			elif parts.size() == 3 and parts[0] == "masks":
				Verbs.set_clip_param(d, s, c.id, path, MaskShape.make("rect", "").get(parts[2], 0.0), -1.0)
	elif id == "clear_keys":
		var p: Dictionary = c.get_param(path)
		if AnimProp.is_animated(p):
			Verbs.set_clip_param(d, s, c.id, path, AnimProp.evaluate(p, c.param_time(path, playhead() - c.start), c.duration, s.fps), -1.0)
	elif id == "open_keys":
		bus().property_picked.emit(c.id, path)
		var dock: Node = _root.get_tree().get_first_node_in_group("pm_overlay")
		Cmd.run("window.focus_effect_controls")
		var kp: Object = bus().panel("keyframes")
		if kp != null and kp.has_method("show_property"):
			kp.call("show_property", c.id, path)
		if dock != null:
			pass
	elif id == "adjust":
		if not r.is_empty():
			if r["strip"] == null:
				_open_strips[path] = true
				_open_strip(r)
			(r["strip"] as Control).call("open_adjust_sheet")
	elif id == "drive":
		open_drive(path)
	elif id == "add_noise":
		_on_add_modifier(path, "noise")
	elif id == "add_wave":
		_on_add_modifier(path, "wave")
	elif id == "bake":
		_on_bake(path)


func _on_label_input(event: InputEvent, label: Label) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_label_drag = true
				_label_drag_x = mb.global_position.x
				_label_drag_from = label_w
				_label_drag_row = {}
				for r: Dictionary in _rows:
					if r.get("label_ctrl") == label:
						if mb.alt_pressed:
							_label_drag_row = r
							_label_drag_from = _spec_label_width(r["spec"])
						pick_value(String(r.get("pick", "")))
						break
			elif _label_drag:
				_label_drag = false
				if _label_drag_row.is_empty():
					Prefs.set_value(PREF_LABEL_W, label_w / maxf(Tk.ui_scale, 0.01))
				else:
					var spec: Dictionary = _label_drag_row["spec"]
					set_value_label_width(value_width_key(spec), PmWrapRow.pref_of(_label_drag_row["label_ctrl"]))
					_label_drag_row = {}
		return
	if event is InputEventMouseMotion and _label_drag:
		var mm: InputEventMouseMotion = event
		var moved: float = mm.global_position.x - _label_drag_x
		if not _label_drag_row.is_empty():
			var one: float = clampf(_label_drag_from + moved, float(Tk.px(LABEL_ONE_MIN)), float(Tk.px(LABEL_MAX)))
			PmWrapRow.prefer(_label_drag_row["label_ctrl"], one)
			_relayout_rows()
			return
		label_w = clampf(_label_drag_from + moved, float(Tk.px(LABEL_MIN)), float(Tk.px(LABEL_MAX)))
		for r: Dictionary in _rows:
			PmWrapRow.prefer(r["label_ctrl"], _spec_label_width(r["spec"]))
		_relayout_rows()


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	for r: Dictionary in _rows:
		var strip: Variant = r["strip"]
		if strip is Control and (strip as Control).has_focus():
			return bool((strip as Control).call("handle_key", e))
	if key_is(e, KEY_C, true, true):
		return copy_keys_picked()
	if key_is(e, KEY_V, true, true):
		return paste_keys_picked()
	if key_is(e, KEY_V, true, false, true):
		return ValueOffsetUi.paste_picked_offset(self)
	if key_is(e, KEY_C, true):
		return copy_picked()
	if key_is(e, KEY_V, true):
		return paste_picked()
	if key_is(e, KEY_ESCAPE):
		if _picked.is_empty():
			return false
		pick_value("")
		return true
	return false


func save_state() -> Dictionary:
	return {"open": _open_strips.keys(), "simple": simple}


func restore_state(d: Dictionary) -> void:
	_open_strips = {}
	for v: Variant in d.get("open", []):
		_open_strips[String(v)] = true
	if _alive():
		rebuild()


const RecordCmds := preload("res://doc/commands/record_cmds.gd")

var _live_values_queued: bool = false
var _live_values_hidden: bool = false


func _on_shown_again() -> void:
	if not _live_values_hidden or not _alive() or not _root.is_visible_in_tree():
		return
	_live_values_hidden = false
	refresh_values()


func _record_write(spec: Dictionary, c: Clip, d: Project, s: Sequence, path: String, value: Variant) -> bool:
	if not bool(spec.get("keyable", false)) or spec.has("special") or not RecordCmds.recording():
		return false
	var v: Variant = value
	if spec.has("prop") and String(spec["prop"]) == "font" and String(value) == "default":
		v = ""
	var hold: bool = DISCRETE_KINDS.has(String(spec.get("kind", "")))
	if not RecordCmds.write(d, s, c.id, path, v, _dragging_field, hold):
		return false
	if _dragging_field:
		_live_label = "Record " + String(spec["label"]).to_lower()
	return true


func _add_record_dot(label_box: HBoxContainer, keyable: bool) -> Control:
	if not keyable or label_box.get_child_count() == 0:
		return null
	var host: Control = label_box.get_child(label_box.get_child_count() - 1) as Control
	if host == null:
		return null
	var dot := _RecordDot.new()
	dot.visible = false
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -10.0
	dot.offset_right = -2.0
	dot.offset_top = -4.0
	dot.offset_bottom = 4.0
	host.add_child(dot)
	return dot


func _sync_record_dots(c: Clip) -> void:
	var any: bool = RecordCmds.active()
	for r: Dictionary in _rows:
		var dot: Variant = r.get("rec_dot", null)
		if not (dot is Control) or not is_instance_valid(dot):
			continue
		var want: bool = any and RecordCmds.is_writing(c.id, String(r["path"]))
		if (dot as Control).visible != want:
			(dot as Control).visible = want


class _RecordDot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 3.0, Color(0.898, 0.282, 0.302, 1.0), true, -1.0, true)


func _queue_live_values() -> void:
	if _live_values_queued or not _alive() or Session.playing:
		return
	if not _root.is_visible_in_tree():
		_live_values_hidden = true
		return
	_live_values_queued = true
	Callable(self, "_flush_live_values").call_deferred()


func _live_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: Project = doc()
	if d == null:
		return out
	for cmd: Command in d.undo.live_commands():
		var p: Variant = cmd.get("path")
		if p is String:
			out.append(String(p))
			continue
		var uid: Variant = cmd.get("uid")
		var key: Variant = cmd.get("key")
		if uid is String and key is String:
			var a: Variant = cmd.get("audio")
			out.append(("audio_effects." if a is bool and bool(a) else "effects.") + String(uid) + "." + String(key))
	return out


func _flush_live_values() -> void:
	_live_values_queued = false
	if not _alive():
		return
	if not _root.is_visible_in_tree():
		_live_values_hidden = true
		return
	var paths: PackedStringArray = _live_paths()
	if _many_on:
		paths = _many_canon(paths)
	if paths.is_empty() or speed_live(paths):
		refresh_values()
		return
	var all: Array[Dictionary] = _rows
	var some: Array[Dictionary] = []
	for r: Dictionary in all:
		if paths.has(String(r["path"])):
			some.append(r)
	_rows = some
	refresh_values()
	_rows = all


const MultiField := preload("res://modules/core_panels/multi_field.gd")
const ManyButtons := preload("res://modules/core_panels/many_buttons.gd")
const PvGroups := preload("res://modules/core_panels/pv_groups.gd")
const ParentUi := preload("res://modules/core_panels/parent_ui.gd")
const PuppetUi := preload("res://modules/core_panels/puppet_ui.gd")
const LinkedSound := preload("res://modules/core_panels/linked_sound.gd")
const TextEcRows := preload("res://modules/core_panels/text_ec_rows.gd")
const TransitionEc := preload("res://modules/core_panels/transition_ec_rows.gd")
const ValueOffsetUi := preload("res://modules/core_panels/value_offset_ui.gd")
const SoundWell := preload("res://modules/core_panels/sound_well.gd")
const MANY_NOTE :="A change goes to every selected clip that has the value"
const ONE_AT_A_TIME := "Select one clip to edit these"
const MIXED := "mixed"
const CLIPS_DIFFER := "The clips differ"

var _many_on: bool = false
var _many_total: int = 0
var _many_count: int = 0
var _many_members: Array[Clip] = []
var _many_index: Dictionary = {}
var _many_style: PackedStringArray = PackedStringArray()
var _many_pictures: PackedStringArray = PackedStringArray()
var _many_tag: String = ""


func many_clips() -> Array[Clip]:
	var out: Array[Clip] = []
	var s: Sequence = seq()
	if s == null:
		return out
	var ids: PackedStringArray = Verbs.selection(s)
	if Verbs.link_families(s, ids) < 2:
		return out
	for id: String in ids:
		out.append(s.clip_by_id(id))
	return out


func many_on() -> bool:
	return _many_on


func _many_reset() -> void:
	_many_on = false
	_many_total = 0
	_many_count = 0
	_many_members = []
	_many_index = {}
	_many_style = PackedStringArray()
	_many_pictures = PackedStringArray()
	_many_tag = ""


func _many_scope(clips: Array[Clip]) -> void:
	_many_members = clips
	_many_count = clips.size()


func _many_stamp(clips: Array[Clip]) -> String:
	var s: Sequence = seq()
	var parts: PackedStringArray = PackedStringArray()
	for c: Clip in clips:
		var t: Track = s.track_of(c.id) if s != null else null
		parts.append((t.id if t != null else "") + "/" + _stamp_of(c))
	return "many#" + "#".join(parts)


func count_text(n: int) -> String:
	if n >= _many_total:
		return "Both clips" if n == 2 else "All " + str(n) + " clips"
	return str(n) + " of " + str(_many_total) + " clips"


func _count_label(n: int) -> Label:
	var l: Label = PmLabel.dim(count_text(n))
	l.name = "ManyCount"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style_ids(clip_id: String) -> PackedStringArray:
	if _many_on and not _many_style.is_empty():
		return _many_style
	return PackedStringArray([clip_id])


const MENU_LABEL_RESET := "label_w_reset"
const MENU_KEYS_HERE := "keys_new_here_"
const MENU_KEYS_ALL := "keys_new_all_"
const PREF_NEW_INTERP := "keys.new_interp"
const PREF_NEW_INTERP_ONE := "keys.new_interp_by_value"
const KeyDefaults := preload("res://doc/key_defaults.gd")
const KeyAnchor := preload("res://doc/key_anchor.gd")
const SpeedFollow := preload("res://host/speed_follow.gd")
const ROT_TYPING_PREMIERE := "rot_typing_premiere"
const ROT_TYPING_TIMES := "rot_typing_times"
const SPIN_WORDS: PackedStringArray = ["rotation", "spin", "angle", "turn", "yaw", "roll", "twist", "phase", "direction"]


static func wants_turns(spec: Dictionary) -> bool:
	if spec.has("turns"):
		return bool(spec["turns"])
	if spec.has("max"):
		return false
	var path: String = String(spec.get("path", ""))
	return spins(path.get_slice(".", path.get_slice_count(".") - 1), String(spec.get("suffix", "")), -INF, INF)


static func spins(key: String, unit: String, lo: float, hi: float) -> bool:
	if not (unit.contains("°") or unit.contains("deg")):
		return false
	if hi - lo < 359.0:
		return false
	for word: String in SPIN_WORDS:
		if key.ends_with(word):
			return true
	return false


func _number_field(lo: float, hi: float, step_: float, suffix_: String) -> Control:
	if _many_on:
		return MultiField.make_multi(lo, hi, step_, suffix_)
	return PmField.make(0.0, lo, hi, step_, suffix_)


func _many_note_row(text: String) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(0)
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))))
	row.add_child(_spacer(float(Tk.px(Tk.sz("pad")))))
	var l: Label = PmLabel.trim(text, "text_dim")
	PmUI.tip(l, text)
	row.add_child(l)
	row.add_child(_spacer(float(Tk.px(Tk.sz("pad")))))
	return row


func _build_many(clips: Array[Clip]) -> void:
	var s: Sequence = seq()
	var d: Project = doc()
	_many_on = true
	_many_total = clips.size()
	_head.text = str(clips.size()) + " clips selected"
	_list.add_child(_many_note_row(MANY_NOTE))
	var pictures: Array[Clip] = []
	var sounds: Array[Clip] = []
	var nests: Array[Clip] = []
	var kinds: Dictionary = {}
	var heard: Dictionary = {}
	for hc: Clip in clips:
		var ht: Track = s.track_of(hc.id)
		if ht != null and ht.is_sound(hc) and not hc.link_id.is_empty():
			heard[hc.link_id] = true
	for c: Clip in clips:
		var t: Track = s.track_of(c.id)
		var pic: bool = t != null and t.is_picture(c)
		if pic:
			pictures.append(c)
			_many_pictures.append(c.id)
			var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
			if m != null and (m.kind == "title" or m.kind == "shape" or m.kind == "generator"):
				if not kinds.has(m.kind):
					kinds[m.kind] = []
				(kinds[m.kind] as Array).append(c)
		if (t != null and t.is_sound(c)) or (pic and _has_audio(c) and not heard.has(c.link_id)):
			sounds.append(c)
		if c.is_nest():
			nests.append(c)
	for kind: String in ["title", "shape", "generator"]:
		if not kinds.has(kind):
			continue
		var group: Array[Clip] = []
		for g: Variant in kinds[kind]:
			group.append(g as Clip)
		_many_scope(group)
		_many_tag = kind
		if kind == "title":
			for gc: Clip in group:
				_many_style.append(gc.id)
		_build_props(group[0], d.media_by_id(group[0].media_id))
		if kind == "title":
			TextEcRows.build(self, group[0])
		_many_tag = ""
	if not pictures.is_empty():
		_many_scope(pictures)
		_build_motion(pictures[0])
		_build_opacity(pictures[0])
	_many_scope(clips)
	_build_time(clips[0])
	_build_anim_speed(clips[0])
	if not sounds.is_empty():
		_many_scope(sounds)
		_build_audio(sounds[0], s.track_of(sounds[0].id))
	if not nests.is_empty():
		_many_scope(nests)
		var fold: VBoxContainer = _fold("Nest", "nest_many")
		ManyButtons.nest_many(self, fold.get("body"), nests)
	if not pictures.is_empty() and not simple:
		_build_masks_many(pictures)
	_build_effects_many(clips)
	_many_scope([])


func _many_adopt(spec: Dictionary) -> void:
	var path: String = String(spec["path"])
	if not spec.has("members"):
		var members: Dictionary = {}
		for c: Clip in _many_members:
			members[c.id] = path
		spec["members"] = members
	if spec.has("prop") and not _many_tag.is_empty():
		spec["path"] = path + "@" + _many_tag
	var canon: String = String(spec["path"])
	for cid: Variant in (spec["members"] as Dictionary).keys():
		var real: String = String((spec["members"] as Dictionary)[cid])
		var list: PackedStringArray = _many_index.get(real, PackedStringArray())
		if not list.has(canon):
			list.append(canon)
		_many_index[real] = list


func _many_canon(paths: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: String in paths:
		for canon: String in (_many_index.get(p, PackedStringArray()) as PackedStringArray):
			if not out.has(canon):
				out.append(canon)
	return out


func _many_moving_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _rows:
		if bool(r.get("anim", false)):
			out.append(r)
	return out


func _many_lead_value(spec: Dictionary) -> Variant:
	var s: Sequence = seq()
	var members: Dictionary = spec["members"]
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c != null:
			return _value_at(c, spec, String(members[cid]))
	return null


func many_values(spec: Dictionary) -> Array:
	var out: Array = []
	var s: Sequence = seq()
	if s == null or not spec.has("members"):
		return out
	var members: Dictionary = spec["members"]
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null:
			out.append(_value_at(c, spec, String(members[cid])))
	return out


static func same_value(a: Variant, b: Variant) -> bool:
	var na: bool = a is float or a is int
	var nb: bool = b is float or b is int
	if na and nb:
		return absf(float(a) - float(b)) <= 0.000001 * maxf(1.0, absf(float(a)))
	if a is Array and b is Array:
		var aa: Array = a
		var bb: Array = b
		if aa.size() != bb.size():
			return false
		for i: int in aa.size():
			if not same_value(aa[i], bb[i]):
				return false
		return true
	if typeof(a) != typeof(b):
		return false
	return a == b


static func all_same(vals: Array) -> bool:
	for i: int in range(1, vals.size()):
		if not same_value(vals[0], vals[i]):
			return false
	return true


static func _scalar(v: Variant, comp: int) -> float:
	if v is Array:
		var arr: Array = v
		var i: int = comp if comp >= 0 else 0
		return float(arr[i]) if arr.size() > i else 0.0
	if v is float or v is int or v is bool:
		return float(v)
	return 0.0


func _refresh_many(rows: Array[Dictionary]) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var ph: float = playhead()
	var writing: bool = RecordCmds.active()
	_refresh_many_note()
	for r: Dictionary in rows:
		var spec: Dictionary = r["spec"]
		if not spec.has("members"):
			continue
		var members: Dictionary = spec["members"]
		var keyable: bool = bool(spec.get("keyable", false))
		var vals: Array = []
		var any_anim: bool = false
		var armed: bool = false
		var all_keyed: bool = true
		var dot: bool = false
		for cid_v: Variant in members.keys():
			var cid: String = String(cid_v)
			var c: Clip = s.clip_by_id(cid)
			if c == null:
				continue
			var real: String = String(members[cid_v])
			vals.append(_value_at(c, spec, real))
			if not keyable:
				continue
			var p: Dictionary = c.get_param(real)
			if AnimProp.is_animated(p):
				any_anim = true
				if AnimProp.find_key(p, c.param_time(real, ph - c.start)) < 0:
					all_keyed = false
			if bus().is_armed(cid, real):
				armed = true
			if writing and RecordCmds.is_writing(cid, real):
				dot = true
		r["anim"] = any_anim
		if vals.is_empty():
			continue
		_show_many(r, spec, vals)
		if keyable:
			(r["stopwatch"] as Button).set("active", any_anim or armed)
			(r["nav"] as Control).modulate.a = 1.0 if any_anim else 0.35
			if any_anim:
				(r["diamond"] as Button).set("icon_name", "diamond" if all_keyed else "diamond_o")
		var rd: Variant = r.get("rec_dot", null)
		if rd is Control and is_instance_valid(rd) and (rd as Control).visible != dot:
			(rd as Control).visible = dot


func _show_many(r: Dictionary, spec: Dictionary, vals: Array) -> void:
	var kind: String = String(spec["kind"])
	var editors: Array = r["editors"]
	if editors.is_empty():
		return
	var mul: float = float(spec.get("display_mul", 1.0))
	var same: bool = all_same(vals)
	var lead: Variant = vals[0]
	if kind == "float" or kind == "int":
		var f: Control = editors[0]
		if bool(f.get("_dragging")) or f.get("_editor") != null:
			return
		var comp: int = int(spec.get("component", -1))
		var nums: Array = []
		for v: Variant in vals:
			nums.append(_scalar(v, comp))
		var fv: float = float(nums[0])
		if bool(spec.get("db", false)):
			fv = 20.0 * log(maxf(fv, 0.0001)) / log(10.0) if fv > 0.0001 else -60.0
		f.set("value", fv * mul)
		f.set("mixed", not all_same(nums))
	elif kind == "vec2":
		for i: int in 2:
			var f2: Control = editors[i]
			if bool(f2.get("_dragging")) or f2.get("_editor") != null:
				continue
			var comps: Array = []
			for v2: Variant in vals:
				comps.append(_scalar(v2, i))
			f2.set("value", float(comps[0]) * mul)
			f2.set("mixed", not all_same(comps))
		if r.has("link"):
			var lead_clip: Clip = _many_first(spec)
			if lead_clip != null:
				(r["link"] as Button).set_pressed_no_signal(bool(lead_clip.transform.get("scale_linked", true)))
	elif kind == "bool":
		var cb: CheckBox = editors[0]
		var flags: Array = []
		for v3: Variant in vals:
			flags.append(bool(v3) if v3 != null else false)
		cb.set_pressed_no_signal(bool(flags[0]))
		var want_text: String = "" if all_same(flags) else MIXED
		if cb.text != want_text:
			cb.text = want_text
	elif kind == "enum" or kind == "layer":
		var drop: Button = editors[0]
		var ids: Array = []
		for v4: Variant in vals:
			var id: String = str(int(v4)) if bool(spec.get("numeric", false)) and v4 != null else (String(v4) if v4 != null else "")
			if kind == "layer" and id.is_empty():
				id = "none"
			ids.append(id)
		if all_same(ids):
			drop.set("placeholder", "Choose")
			drop.call("set_value", String(ids[0]), false)
		else:
			drop.set("placeholder", MIXED)
			drop.call("set_value", "", false)
	elif kind == "color":
		var btn: Button = editors[0]
		btn.set("icon_name", "")
		btn.text = "#" + _as_colour(lead).to_html(false) if same else MIXED
	elif kind == "curve":
		(editors[0] as Control).call("set_points", lead if lead is Array else [])
	elif kind == "texture" or kind == "string":
		var le: LineEdit = editors[0]
		if not le.has_focus():
			le.text = (String(lead) if lead != null else "") if same else ""
			le.placeholder_text = "" if same else MIXED
	elif kind == "multiline":
		var te: TextEdit = editors[0]
		var want: String = (String(lead) if lead != null else "") if same else ""
		if not te.has_focus() and te.text != want:
			te.text = want
		te.placeholder_text = "" if same else MIXED


func _many_first(spec: Dictionary) -> Clip:
	var s: Sequence = seq()
	if s == null or not spec.has("members"):
		return null
	for cid: Variant in (spec["members"] as Dictionary).keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null:
			return c
	return null


func _refresh_many_note() -> void:
	if _anim_note == null or not is_instance_valid(_anim_note):
		return
	var r: Dictionary = _row_for(AnimTime.SPEED_PATH)
	var s: Sequence = seq()
	if r.is_empty() or s == null:
		return
	var notes: Array = []
	for cid: Variant in ((r["spec"] as Dictionary).get("members", {}) as Dictionary).keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null:
			notes.append(anim_speed_note(c))
	if notes.is_empty():
		return
	var want: String = String(notes[0]) if all_same(notes) else CLIPS_DIFFER
	if _anim_note.text != want:
		_anim_note.text = want


func _field_many(spec: Dictionary, real: float, component: int) -> void:
	var kind: String = String(spec["kind"])
	if not (kind == "vec2" or spec.has("component")):
		_write_many(spec, int(round(real)) if kind == "int" else real)
		return
	var s: Sequence = seq()
	if s == null:
		return
	var members: Dictionary = spec["members"]
	var idx: int = int(spec.get("component", component))
	var per: Dictionary = {}
	for cid_v: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid_v))
		if c == null:
			continue
		var cur: Variant = _value_at(c, spec, String(members[cid_v]))
		var arr: Array = (cur as Array).duplicate() if cur is Array and (cur as Array).size() >= 2 else [0.0, 0.0]
		var linked: bool = bool(spec.get("scale_link", false)) and bool(c.transform.get("scale_linked", true))
		if linked and float(arr[idx]) != 0.0:
			var ratio: float = real / float(arr[idx])
			arr[0] = float(arr[0]) * ratio
			arr[1] = float(arr[1]) * ratio
		else:
			arr[idx] = real
		per[String(cid_v)] = arr
	_write_many(spec, null, per)


func _write_many(spec: Dictionary, value: Variant, per_clip: Dictionary = {}, flat: bool = false, label: String = "") -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var members: Dictionary = spec["members"]
	var what: String = label if not label.is_empty() else "Set " + String(spec["label"])
	var live: bool = _dragging_field
	if not flat and _record_many(spec, members, value, per_clip):
		return
	var special: String = String(spec.get("special", ""))
	var kind: String = String(spec.get("kind", ""))
	var cmds: Array[Command] = []
	if special == "reverse":
		for cid: Variant in members.keys():
			var rc: Clip = s.clip_by_id(String(cid))
			var sp: float = rc.static_speed() if rc != null else 0.0
			if sp != 0.0 and (sp < 0.0) != bool(value):
				cmds.append(ClipCmds.SetClipParam.new(s.id, rc.id, AnimTime.MEDIA_SPEED_PATH, AnimProp.make(-sp)))
		Verbs.run(d, "Reverse", cmds)
		return
	if spec.has("field"):
		var field: String = String(spec["field"])
		var key: String = String(spec["key"])
		for cid2: Variant in members.keys():
			var fc: Clip = s.clip_by_id(String(cid2))
			if fc == null:
				continue
			var dict: Dictionary = (fc.get(field) as Dictionary).duplicate(true)
			if dict.has(key) and same_value(dict[key], value):
				continue
			var to_default: bool = spec.has("default") and same_value(value, spec["default"])
			if to_default and not dict.has(key):
				continue
			dict[key] = value
			if to_default:
				dict.erase(key)
			cmds.append(ClipCmds.SetClipField.new(s.id, fc.id, field, dict))
		Verbs.run(d, what, cmds)
		return
	var writes: Array[Dictionary] = []
	var flat_speed: PackedStringArray = PackedStringArray()
	var ph: float = playhead()
	for cid_v: Variant in members.keys():
		var cid: String = String(cid_v)
		var c: Clip = s.clip_by_id(cid)
		if c == null:
			continue
		var real: String = String(members[cid_v])
		var v: Variant = per_clip.get(cid, value)
		if spec.has("prop") and String(spec["prop"]) == "font" and String(v) == "default":
			v = ""
		var key_at: float = -1.0 if flat else bus().key_time_for(c, real, ph)
		if special == "anim_speed" and key_at < 0.0:
			cmds.append_array(_anim_speed_cmds(c, v))
			continue
		if special == "inner_speed" and key_at < 0.0:
			cmds.append_array(inner_speed_cmds(c, real, v))
			continue
		if real == AnimTime.MEDIA_SPEED_PATH and key_at < 0.0:
			flat_speed.append(cid)
			continue
		var effect: bool = spec.has("uid")
		writes.append({"clip_id": cid, "path": real, "value": v, "key_at": key_at, "effect": effect, "hold": effect and DISCRETE_KINDS.has(kind)})
		if effect and kind == "enum" and v != null:
			var extra: Dictionary = EffectSource.enum_writes(String(spec["eid"]), String(spec["key"]), int(v))
			var base: String = real.substr(0, real.rfind(".") + 1)
			for wk: Variant in extra.keys():
				writes.append({"clip_id": cid, "path": base + String(wk), "value": extra[wk], "key_at": -1.0, "effect": true})
	var batch: Command = Verbs.write_command(s, writes, String(spec["path"]), what)
	if batch != null:
		cmds.append(batch)
	if not flat_speed.is_empty() and _write_speed(flat_speed, float(value), cmds):
		return
	_run_or_live(d, cmds, what, live)


func _run_or_live(d: Project, cmds: Array[Command], label: String, live: bool) -> bool:
	if cmds.is_empty():
		return false
	if live:
		_live_label = label
		return Verbs.live_all(d, cmds)
	return Verbs.run(d, label, cmds)


func _write_speed(ids: PackedStringArray, value: float, extra: Array[Command]) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var cmds: Array[Command] = load("res://doc/speed_length.gd").call("typed_speed_commands", s, ids, value)
	if d == null or cmds.is_empty():
		return false
	cmds.append_array(extra)
	if _dragging_field:
		Verbs.live_all(d, cmds)
		_live_label = "Speed"
		return true
	Verbs.run(d, "Speed", cmds)
	return true


func _record_many(spec: Dictionary, members: Dictionary, value: Variant, per_clip: Dictionary) -> bool:
	if not bool(spec.get("keyable", false)) or spec.has("special") or not RecordCmds.recording():
		return false
	var d: Project = doc()
	var s: Sequence = seq()
	var hold: bool = DISCRETE_KINDS.has(String(spec.get("kind", "")))
	var live: bool = _dragging_field
	var label: String = "Record " + String(spec["label"]).to_lower()
	var sound: bool = false
	var any: bool = false
	var was: bool = Verbs.live_begin(d) if live else false
	var tx: RefCounted = null if live else d.undo.begin(label)
	for cid: Variant in members.keys():
		var v: Variant = per_clip.get(String(cid), value)
		if spec.has("prop") and String(spec["prop"]) == "font" and String(v) == "default":
			v = ""
		var real: String = String(members[cid])
		if RecordCmds.write(d, s, String(cid), real, v, live, hold):
			any = true
			sound = sound or real.begins_with("audio")
	if live:
		Verbs.live_end(d, was, Verbs.live_kind(sound))
		if any:
			_live_label = label
	elif bool(tx.call("is_empty")):
		tx.call("abandon")
	else:
		tx.call("commit")
	return any


func _scale_link_many(on: bool) -> void:
	var r: Dictionary = _row_for("transform.scale")
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return
	var cmds: Array[Command] = []
	for cid: Variant in ((r["spec"] as Dictionary)["members"] as Dictionary).keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null or bool(c.transform.get("scale_linked", true)) == on:
			continue
		var tf: Dictionary = c.transform.duplicate(true)
		tf["scale_linked"] = on
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "transform", tf))
	Verbs.run(d, "Scale link", cmds)


func _many_row(path: String) -> Dictionary:
	var r: Dictionary = _row_for(path)
	if r.is_empty() or not (r["spec"] as Dictionary).has("members"):
		return {}
	return r


func _stopwatch_many(path: String) -> void:
	var r: Dictionary = _many_row(path)
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return
	var spec: Dictionary = r["spec"]
	var members: Dictionary = spec["members"]
	var ph: float = playhead()
	var all_anim: bool = true
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null and not AnimProp.is_animated(c.get_param(String(members[cid]))):
			all_anim = false
	var discrete: bool = DISCRETE_KINDS.has(String(spec.get("kind", "")))
	var cmds: Array[Command] = []
	var b: RefCounted = bus()
	var armed: Dictionary = b.get("armed")
	var lead: Array = []
	for cid2: Variant in members.keys():
		var c2: Clip = s.clip_by_id(String(cid2))
		if c2 == null:
			continue
		var real: String = String(members[cid2])
		var p: Dictionary = c2.get_param(real)
		var local_t: float = c2.param_time(real, ph - c2.start)
		var arm: String = String(b.call("arm_key", c2.id, real))
		if lead.is_empty():
			lead = [c2.id, real]
		if all_anim:
			var cmd: Command = Verbs.clip_param_command(s, c2.id, real, AnimProp.evaluate(p, local_t, c2.duration, s.fps), -1.0)
			if cmd != null:
				cmds.append(cmd)
			armed.erase(arm)
			continue
		armed[arm] = true
		if AnimProp.is_animated(p):
			continue
		var cur: Variant = AnimProp.static_value(p) if not p.is_empty() else _seed_for(c2, real)
		if discrete:
			cmds.append(ClipCmds.SetClipParam.new(s.id, c2.id, real, AnimProp.set_key(p if not p.is_empty() else AnimProp.make(cur), local_t, cur, "hold")))
		else:
			var cmd2: Command = Verbs.clip_param_command(s, c2.id, real, cur, ph)
			if cmd2 != null:
				cmds.append(cmd2)
	Verbs.run(d, "Stop keyframes" if all_anim else "Start keyframes", cmds)
	if not lead.is_empty():
		b.emit_signal("arm_changed", String(lead[0]), String(lead[1]), not all_anim)


func _key_toggle_many(path: String) -> void:
	var r: Dictionary = _many_row(path)
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return
	var members: Dictionary = (r["spec"] as Dictionary)["members"]
	var ph: float = playhead()
	var have_all: bool = true
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if p.is_empty() or AnimProp.find_key(p, c.param_time(real, ph - c.start)) < 0:
			have_all = false
	var cmds: Array[Command] = []
	for cid2: Variant in members.keys():
		var c2: Clip = s.clip_by_id(String(cid2))
		if c2 == null:
			continue
		var real2: String = String(members[cid2])
		var p2: Dictionary = c2.get_param(real2)
		if p2.is_empty() and real2.begins_with("props."):
			p2 = AnimProp.make(_seed_for(c2, real2))
		if p2.is_empty():
			continue
		var local_t: float = c2.param_time(real2, ph - c2.start)
		var next: Dictionary = {}
		if have_all:
			next = AnimProp.remove_key(p2, local_t)
		elif AnimProp.find_key(p2, local_t) < 0:
			next = AnimProp.set_key(p2, local_t, AnimProp.evaluate(p2, local_t, c2.duration, s.fps))
		if not next.is_empty() and next != p2:
			cmds.append(ClipCmds.SetClipParam.new(s.id, c2.id, real2, next))
	Verbs.run(d, "Toggle keyframe", cmds)


func _key_nav_many(path: String, dir: int) -> void:
	var r: Dictionary = _many_row(path)
	var s: Sequence = seq()
	if r.is_empty() or s == null:
		return
	var members: Dictionary = (r["spec"] as Dictionary)["members"]
	var ph: float = playhead()
	var best: float = 0.0
	var found: bool = false
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		for kt: float in AnimTime.played_list(c, String(members[cid])):
			var t: float = c.start + kt
			if dir > 0 and t > ph + 0.0001 and (not found or t < best):
				best = t
				found = true
			elif dir < 0 and t < ph - 0.0001 and (not found or t > best):
				best = t
				found = true
	if found:
		Session.set_playhead(best)


func _row_menu_many(path: String, anchor: Control) -> void:
	var r: Dictionary = _many_row(path)
	if r.is_empty():
		return
	var items: Array = [PmMenu.item("reset", "Reset to default"), PmMenu.item("copy_value", "Copy value")]
	items.append_array(_speed_menu_items_many(path, r))
	if bool((r["spec"] as Dictionary).get("keyable", false)):
		items.append(PmMenu.separator())
		items.append(PmMenu.item("clear_keys", "Remove every key"))
		items.append_array(ManyButtons.row_menu_items(self, r))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", row_menu_many_picked.bind(path))


func row_menu_many_picked(id: String, path: String) -> void:
	if _inner_row_menu(id, path):
		return
	var r: Dictionary = _many_row(path)
	if r.is_empty():
		return
	var spec: Dictionary = r["spec"]
	if ManyButtons.row_menu_picked(self, id, spec):
		return
	if id == "reset":
		var def: Variant = _many_default(spec)
		if def != null:
			_write_many(spec, def, {}, true, "Reset " + String(spec["label"]).to_lower())
	elif id == "copy_value":
		DisplayServer.clipboard_set(str(current_value(spec)))
	elif id == "clear_keys":
		_clear_keys_many(spec)


func _many_default(spec: Dictionary) -> Variant:
	var first: Clip = _many_first(spec)
	if first == null:
		return null
	if spec.has("uid"):
		for p: Dictionary in EffectSource.param_specs(EffectSource.get_def(String(spec["eid"]))):
			if String(p.get("key", "")) == String(spec["key"]):
				return p.get("default", 0.0)
		return null
	var real: String = String((spec["members"] as Dictionary)[first.id])
	var parts: PackedStringArray = real.split(".")
	var defaults: Dictionary = Clip.default_transform()
	if parts.size() == 2 and parts[0] == "transform" and defaults.has(parts[1]) and defaults[parts[1]] is Dictionary:
		return AnimProp.static_value(defaults[parts[1]])
	if real == AnimTime.MEDIA_SPEED_PATH or real == "audio.volume":
		return 1.0
	if real == "audio.pan":
		return 0.0
	if parts.size() == 2 and parts[0] == "motion_blur" and not spec.has("field"):
		return float(Clip.default_motion_blur().get(parts[1], 0.0))
	if parts.size() == 3 and parts[0] == "masks":
		return MaskShape.make("rect", "").get(parts[2], 0.0)
	return null


func _clear_keys_many(spec: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var members: Dictionary = spec["members"]
	var ph: float = playhead()
	var cmds: Array[Command] = []
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if not AnimProp.is_animated(p):
			continue
		var cmd: Command = Verbs.clip_param_command(s, c.id, real, AnimProp.evaluate(p, c.param_time(real, ph - c.start), c.duration, s.fps), -1.0)
		if cmd != null:
			cmds.append(cmd)
	Verbs.run(d, "Remove every key", cmds)


func _reset_anim_speed_many() -> bool:
	var r: Dictionary = _many_row(AnimTime.SPEED_PATH)
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return false
	var cmds: Array[Command] = []
	var b: RefCounted = bus()
	var armed: Dictionary = b.get("armed")
	for cid: Variant in ((r["spec"] as Dictionary)["members"] as Dictionary).keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		if c.get_param(AnimTime.SPEED_PATH) != AnimProp.make(1.0):
			cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.SPEED_PATH, AnimProp.make(1.0)))
		if c.anim_start != 0.0:
			cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, AnimTime.START_FIELD, AnimProp.make(0.0)))
		armed.erase(String(b.call("arm_key", c.id, AnimTime.SPEED_PATH)))
	return Verbs.run(d, "Reset animation speed", cmds)


func _build_masks_many(clips: Array[Clip]) -> void:
	_many_scope(clips)
	var f: VBoxContainer = _fold("Masks", "masks")
	var body: VBoxContainer = f.get("body")
	var row: HBoxContainer = PmUI.hbox()
	row.add_theme_constant_override("separation", Tk.px(Tk.sz("pad")))
	var spacer: Control = _spacer(float(Tk.px(60.0)))
	row.add_child(spacer)
	for spec: Array in [["rect", "Rectangle", "grid"], ["ellipse", "Ellipse", "loop"]]:
		var b: Button = PmButton.make(String(spec[1]), String(spec[2]))
		b.set("quiet", true)
		PmUI.tip(b, "Add a centred " + String(spec[1]).to_lower() + " mask to every selected picture")
		b.pressed.connect(add_mask_many.bind(String(spec[0])))
		row.add_child(b)
	body.add_child(row)
	_fit_lead_row(row, [spacer] as Array[Control], 2)
	var most: int = 0
	for c: Clip in clips:
		most = maxi(most, c.masks.size())
	var modes: Array = [PmDrop.choice("add", "Add"), PmDrop.choice("subtract", "Subtract"), PmDrop.choice("intersect", "Intersect")]
	for n: int in most:
		var holders: Array[Clip] = []
		for c2: Clip in clips:
			if c2.masks.size() > n and not String(c2.masks[n].get("id", "")).is_empty():
				holders.append(c2)
		if holders.is_empty():
			continue
		var mrow: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		mrow.add_child(_spacer(float(Tk.px(Tk.sz("button_h")))))
		mrow.add_child(PmLabel.body(MaskShape.label_of(holders[0].masks[n], n)))
		mrow.add_child(PmUI.spacer())
		mrow.add_child(PmLabel.dim(count_text(holders.size())))
		var all_on: bool = true
		for h: Clip in holders:
			all_on = all_on and bool(h.masks[n].get("enabled", true))
		var on: Button = toggle_icon("check", "Mask on, for every clip that has it", all_on)
		on.pressed.connect(_on_mask_enabled_many.bind(n))
		mrow.add_child(on)
		var del: Button = quiet_icon("trash", "Remove this mask from every clip that has it")
		del.pressed.connect(_on_remove_mask_many.bind(n))
		mrow.add_child(del)
		body.add_child(mrow)
		mrow.add_child(_section_speed_ui(body, "masks.@" + str(n), MaskShape.label_of(holders[0].masks[n], n), _mask_speed_members(holders, n), 1))
		var rows: Array = [
			["mode", {"label": "Mode", "kind": "enum", "choices": modes, "keyable": true, "indent": 1}, false],
			["centre", {"label": "Position", "kind": "vec2", "step": 0.001, "display_mul": 100.0, "suffix": " %", "keyable": true, "indent": 1}, true],
			["size", {"label": "Size", "kind": "vec2", "step": 0.001, "display_mul": 100.0, "suffix": " %", "keyable": true, "indent": 1}, true],
			["rotation", {"label": "Rotation", "kind": "float", "step": 0.5, "suffix": " °", "keyable": true, "indent": 1}, true],
			["feather", {"label": "Feather", "kind": "float", "min": 0.0, "max": 500.0, "step": 0.5, "suffix": " px", "keyable": true, "indent": 1}, false],
			["expand", {"label": "Expand", "kind": "float", "min": -500.0, "max": 500.0, "step": 0.5, "suffix": " px", "keyable": true, "indent": 1}, false],
			["opacity", {"label": "Opacity", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "indent": 1}, false],
			["invert", {"label": "Invert", "kind": "bool", "keyable": true, "indent": 1}, false],
		]
		for entry: Array in rows:
			var param: String = String(entry[0])
			var members: Dictionary = {}
			for h2: Clip in holders:
				var mask: Dictionary = h2.masks[n]
				if bool(entry[2]) and not (MaskShape.is_box(mask) and String(mask.get("region_of", "")).is_empty()):
					continue
				members[h2.id] = "masks." + String(mask.get("id", "")) + "." + param
			if members.is_empty():
				continue
			var spec2: Dictionary = (entry[1] as Dictionary).duplicate(true)
			spec2["path"] = "masks.@" + str(n) + "." + param
			spec2["members"] = members
			_add_row(body, spec2)


func _many_picture_clips() -> Array[Clip]:
	var out: Array[Clip] = []
	var s: Sequence = seq()
	if s == null:
		return out
	for id: String in _many_pictures:
		var c: Clip = s.clip_by_id(id)
		if c != null:
			out.append(c)
	return out


func add_mask_many(kind: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or not MaskShape.BOX_KINDS.has(kind):
		return false
	var cmds: Array[Command] = []
	for c: Clip in _many_picture_clips():
		var masks: Array[Dictionary] = c.masks.duplicate(true)
		masks.append(MaskShape.make(kind, d.mint_id("mask")))
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	return Verbs.run(d, "Add mask", cmds)


func _on_mask_enabled_many(n: int) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var holders: Array[Clip] = []
	var all_on: bool = true
	for c: Clip in _many_picture_clips():
		if c.masks.size() > n:
			holders.append(c)
			all_on = all_on and bool(c.masks[n].get("enabled", true))
	var cmds: Array[Command] = []
	for h: Clip in holders:
		var masks: Array[Dictionary] = h.masks.duplicate(true)
		masks[n]["enabled"] = not all_on
		cmds.append(ClipCmds.SetClipField.new(s.id, h.id, "masks", masks))
	Verbs.run(d, "Mask off" if all_on else "Mask on", cmds)


func _on_remove_mask_many(n: int) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for c: Clip in _many_picture_clips():
		if c.masks.size() <= n:
			continue
		var masks: Array[Dictionary] = c.masks.duplicate(true)
		masks.remove_at(n)
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	Verbs.run(d, "Remove mask", cmds)


static func effect_groups(clips: Array[Clip], sound: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Dictionary = {}
	for c: Clip in clips:
		var list: Array = c.audio_effects() if sound else c.effects
		var seen: Dictionary = {}
		for ev: Variant in list:
			var e: Dictionary = ev
			var eid: String = String(e.get("id", ""))
			var n: int = int(seen.get(eid, 0))
			seen[eid] = n + 1
			var key: String = eid + "#" + str(n)
			if not at.has(key):
				at[key] = out.size()
				out.append({"key": key, "eid": eid, "n": n, "uids": {}, "entries": {}})
			var g: Dictionary = out[int(at[key])]
			(g["uids"] as Dictionary)[c.id] = String(e.get("uid", ""))
			(g["entries"] as Dictionary)[c.id] = e
	return out


func _build_effects_many(clips: Array[Clip]) -> void:
	for sound: bool in [false, true]:
		for g: Dictionary in effect_groups(clips, sound):
			_build_group_many(g, sound)


func _group_paths(uids: Dictionary, prefix: String, key: String) -> Dictionary:
	var out: Dictionary = {}
	for cid: Variant in uids.keys():
		out[String(cid)] = prefix + "." + String(uids[cid]) + "." + key
	return out


func _group_speed_members(uids: Dictionary, prefix: String) -> Dictionary:
	var out: Dictionary = {}
	for cid: Variant in uids.keys():
		out[String(cid)] = prefix + "." + String(uids[cid])
	return out


func _mask_speed_members(holders: Array[Clip], n: int) -> Dictionary:
	var out: Dictionary = {}
	for h: Clip in holders:
		out[h.id] = "masks." + String(h.masks[n].get("id", ""))
	return out


func _speed_menu_items_many(path: String, r: Dictionary) -> Array:
	var spec: Dictionary = r["spec"]
	if not bool(spec.get("keyable", false)) or AnimTime.is_inner(path):
		return []
	var able: bool = false
	for real: Variant in (spec.get("members", {}) as Dictionary).values():
		able = able or AnimTime.speed_able(String(real))
	if not able:
		return []
	var shown: bool = _open_speeds.has(_speed_key(path))
	var item: Dictionary = PmMenu.item(SHOW_SPEED_ID, "Hide the speed row" if shown else "Speed of this value, for every selected clip", "", "rate")
	if shown and _speed_in_use(path):
		item["label"] = "Speed row stays while the speed is in use"
		item["disabled"] = true
	return [PmMenu.separator(), item]


func _many_arrange(uids: Dictionary, keys: PackedStringArray) -> PackedStringArray:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return keys
	var want: PackedStringArray = PackedStringArray()
	var first: bool = true
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var got: PackedStringArray = ValueStyle.arrange(ValueStyle.store_for(d, c), String(uids[cid]), keys)
		if first:
			first = false
			want = got
		elif ",".join(got) != ",".join(want):
			return keys
	return keys if first else want


func _build_group_many(g: Dictionary, sound: bool) -> void:
	var eid: String = String(g["eid"])
	var uids: Dictionary = g["uids"]
	var entries: Dictionary = g["entries"]
	var def: Dictionary = EffectSource.get_def(eid)
	var prefix: String = "audio_effects" if sound else "effects"
	_many_members = []
	_many_count = uids.size()
	var f: VBoxContainer = _fold(String(g.get("title", String(def.get("label", eid)) + (" (sound)" if sound else ""))), ("afx." if sound else "fx.") + eid)
	var all_on: bool = true
	for e: Variant in entries.values():
		all_on = all_on and bool((e as Dictionary).get("enabled", true))
	var bypass: Button = toggle_icon("check", "Effect on, for every clip that has it", all_on)
	bypass.pressed.connect(_on_bypass_many.bind(uids.duplicate(), sound))
	f.call("add_right", bypass)
	ManyButtons.effect_header(self, f, g, sound)
	var trash: Button = quiet_icon("trash", "Remove this effect from every clip that has it")
	trash.pressed.connect(_on_remove_many.bind(uids.duplicate(), sound))
	f.call("add_right", trash)
	_add_section_speed(f, prefix + ".@" + String(g["key"]), String(def.get("label", eid)), _group_speed_members(uids, prefix))
	var body: VBoxContainer = f.get("body")
	if def.is_empty():
		body.add_child(PmLabel.dim("The effect \"" + eid + "\" is not installed, its values are kept"))
	ManyButtons.pair_note(self, body, g, sound)
	var lead_cid: String = String(uids.keys()[0])
	var lead_uid: String = String(uids[lead_cid])
	var lead_e: Dictionary = entries[lead_cid]
	var canon: String = prefix + ".@" + String(g["key"])
	var keys: PackedStringArray = PackedStringArray()
	var by_key: Dictionary = {}
	if not sound:
		keys.append(Clip.MIX_KEY)
		by_key[Clip.MIX_KEY] = {"group": "", "spec": {"path": canon + "." + Clip.MIX_KEY, "label": "Amount", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "members": _group_paths(uids, prefix, Clip.MIX_KEY), "fx_uid": lead_uid, "fx_key": Clip.MIX_KEY, "fx_members": uids.duplicate()}}
	for p: Dictionary in EffectSource.param_specs(def):
		var key: String = String(p.get("key", ""))
		var spec: Dictionary = _effect_param_spec(p, canon + "." + key, lead_uid, eid, sound, lead_e)
		spec["members"] = _group_paths(uids, prefix, key)
		spec["fx_members"] = uids.duplicate()
		keys.append(key)
		by_key[key] = {"group": String(p.get("group", "")), "spec": spec}
	var last_group: String = ""
	for key2: String in _many_arrange(uids, keys):
		if not by_key.has(key2):
			continue
		var item: Dictionary = by_key[key2]
		var group: String = String(item["group"])
		if group != last_group:
			last_group = group
			_add_group_label(body, group)
		_add_row(body, item["spec"])
	if eid == "pair_view" and not sound:
		ManyButtons.pair_view(self, body, g)
	_many_count = 0


func _on_bypass_many(uids: Dictionary, sound: bool) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var all_on: bool = true
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var e: Dictionary = c.audio_effect_by_uid(String(uids[cid])) if sound else c.effect_by_uid(String(uids[cid]))
		all_on = all_on and bool(e.get("enabled", true))
	var cmds: Array[Command] = []
	for cid2: Variant in uids.keys():
		if s.clip_by_id(String(cid2)) != null:
			cmds.append(EffectCmds.SetEffectEnabled.new(s.id, String(cid2), String(uids[cid2]), not all_on, sound))
	Verbs.run(d, "Effect off" if all_on else "Effect on", cmds)


func _on_remove_many(uids: Dictionary, sound: bool) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for cid: Variant in uids.keys():
		if s.clip_by_id(String(cid)) != null:
			cmds.append(EffectCmds.RemoveEffect.new(s.id, String(cid), String(uids[cid]), sound))
	Verbs.run(d, "Remove effect", cmds)


class _CurveEdit:
	extends Control

	signal curve_changed(points: Array)

	var points: Array = [[0.0, 0.0], [1.0, 1.0]]
	var _drag_index: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func set_points(p: Array) -> void:
		if _drag_index >= 0:
			return
		var clean: Array = []
		for e: Variant in p:
			if e is Array and (e as Array).size() >= 2:
				clean.append([float((e as Array)[0]), float((e as Array)[1])])
		if clean.size() < 2:
			clean = [[0.0, 0.0], [1.0, 1.0]]
		points = clean
		queue_redraw()

	func _to_local(p: Array) -> Vector2:
		return Vector2(float(p[0]) * size.x, (1.0 - float(p[1])) * size.y)

	func _index_at(pos: Vector2) -> int:
		for i: int in points.size():
			if _to_local(points[i]).distance_to(pos) <= 7.0:
				return i
		return -1

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				var i: int = _index_at(mb.position)
				if mb.double_click:
					if i > 0 and i < points.size() - 1:
						points.remove_at(i)
					else:
						points.append([clampf(mb.position.x / size.x, 0.0, 1.0), clampf(1.0 - mb.position.y / size.y, 0.0, 1.0)])
						points.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
					curve_changed.emit(points.duplicate(true))
					queue_redraw()
					accept_event()
					return
				_drag_index = i
			else:
				if _drag_index >= 0:
					_drag_index = -1
					curve_changed.emit(points.duplicate(true))
			accept_event()
			return
		if event is InputEventMouseMotion and _drag_index >= 0:
			var mm: InputEventMouseMotion = event
			var p: Array = points[_drag_index]
			p[1] = clampf(1.0 - mm.position.y / maxf(size.y, 1.0), 0.0, 1.0)
			if _drag_index > 0 and _drag_index < points.size() - 1:
				p[0] = clampf(mm.position.x / maxf(size.x, 1.0), float(points[_drag_index - 1][0]) + 0.01, float(points[_drag_index + 1][0]) - 0.01)
			queue_redraw()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
		var pts := PackedVector2Array()
		for p: Array in points:
			pts.append(_to_local(p))
		if pts.size() >= 2:
			draw_polyline(pts, Tk.c["text"], 1.5, true)
		for p: Vector2 in pts:
			draw_circle(p, 3.0, Tk.c["text_bright"])
