extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Puppet := preload("res://doc/puppet.gd")
const Parenting := preload("res://doc/parenting.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PuppetShape := preload("res://modules/core_panels/puppet_shape.gd")
const PuppetLocks := preload("res://doc/puppet_locks.gd")
const PuppetLockUi := preload("res://modules/core_panels/puppet_lock_ui.gd")
const PuppetRecord := preload("res://modules/core_panels/puppet_record.gd")
const PuppetPresets := preload("res://modules/core_panels/puppet_presets.gd")
const PuppetOverlapUi := preload("res://modules/core_panels/puppet_overlap_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const MODE_PINS := "pins"
const MODE_LOCKS := "locks"
const TURN_RING := 26.0
const TURN_REACH := 6.0
const SCALE_HALF := 4.0
const BEND_INK := Color(1.0, 0.55, 0.15, 1.0)
const ADV_INK := Color(0.45, 0.8, 1.0, 1.0)
const GIZMO_INK := Color(1.0, 1.0, 1.0, 0.9)
const RECORD_INK := Color(1.0, 0.2, 0.2, 0.95)
const MARQUEE_INK := Color(1.0, 1.0, 1.0, 0.8)
const MARQUEE_FILL := Color(1.0, 1.0, 1.0, 0.08)
const MARQUEE_LEAST := 3.0
const NUDGE := 1.0
const NUDGE_BIG := 10.0
const XF_PROBE := 1024.0
const LOCK_TIP := "Lock brush: paint on the picture to lock that part. At full strength it holds still, at lower strength it stays stiff but follows the pins. Alt paints the lock off, Shift drag draws a round lock area, [ and ] change the size, Esc goes back to pins"
const SELF_PATH := "res://modules/core_panels/puppet_ui.gd"
const TOOL_ID := "puppet"
const COMMAND_ID := "tool.puppet"
const PIN_REACH := 8.0
const PIN_RADIUS := 4.5
const HOLD_HALF := 5.5
const RING_REACH := 6.0
const PIN_INK := Color(1.0, 0.82, 0.2, 1.0)
const PIN_ACTIVE := Color(1.0, 0.35, 0.25, 1.0)
const PIN_RIM := Color(0.0, 0.0, 0.0, 0.7)
const PICK_INK := Color(1.0, 1.0, 1.0, 1.0)
const HOLD_INK := Color(0.25, 0.85, 1.0, 1.0)
const OVER_INK := Color(1.0, 0.45, 0.85, 1.0)
const OVER_RING := Color(1.0, 0.45, 0.85, 0.85)
const OVER_HALF := 4.5
const RING_INK := Color(0.25, 0.85, 1.0, 0.85)
const LINK_INK := Color(1.0, 1.0, 1.0, 0.9)
const LINK_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const MESH_INK := Color(1.0, 1.0, 1.0, 0.18)
const ARROW := 9.0
const DASH := 5.0
const SYNC_SECONDS := 0.2
const HOLD_SHARE := 0.15
const HOLD_MIN_RADIUS := 12.0
const TOOL_TIP := "Puppet tool: click the picture to add a pin and drag a pin to bend it. Shift click picks more pins and Shift drag picks with a box, arrows nudge, Ctrl A picks all. Ctrl click adds a hold pin, Ctrl Shift click an overlap pin, Ctrl drag from pin to pin links them, Alt click or Delete removes pins. Bend and Advanced pins show a ring to turn and a square to scale"

static var _registered: bool = false
static var _drag: Dictionary = {}
static var sel_clip: String = ""
static var sel_pins: PackedInt32Array = PackedInt32Array()
static var sel_holds: PackedInt32Array = PackedInt32Array()
static var sel_overs: PackedInt32Array = PackedInt32Array()
static var mode: String = MODE_PINS
static var show_mesh: bool = true
static var show_locks: bool = true
static var new_kind: int = Puppet.KIND_POSITION
static var draw_ms: float = 0.0
static var _poke_due: bool = false
static var _poke_gen: int = 0
static var plant_no_poke: bool = false
static var _memo_key: String = ""
static var _memo: Dictionary = {}
static var _edges_key: String = ""
static var _edges: PackedInt32Array = PackedInt32Array()


static func _script() -> GDScript:
	return load(SELF_PATH)


static func tool_on() -> bool:
	return Session.tool_id == TOOL_ID


static func use_tool() -> void:
	Session.set_tool(TOOL_ID)
	Events.toast(TOOL_TIP)


static func toggle_tool() -> void:
	if tool_on():
		Session.set_tool("select")
	else:
		use_tool()


static func register_command() -> void:
	if _registered:
		return
	_registered = true
	if Cmd.has(COMMAND_ID):
		return
	var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	Cmd.register(COMMAND_ID, {"label": "Puppet tool", "category": "Tools", "scope": "global", "handler": Callable(_script(), "use_tool"), "owner": "core_panels", "enabled": Callable(bus_script, "has_doc_static"), "toggle": Callable(_script(), "tool_on")})


static func path_of(e: Dictionary, key: String) -> String:
	return "effects." + String(e.get("uid", "")) + "." + key


static func layer_size(d: Project, s: Sequence, c: Clip) -> Vector2:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var pick: GDScript = load("res://modules/core_panels/monitor_pick.gd")
	var base: Vector2 = pick.call("layer_size", c, m, s, d)
	return PairLayout.picture_size(c, base, Vector2(float(s.width), float(s.height)))


static func alpha_path(d: Project, c: Clip) -> String:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return m.path if m != null and m.kind == "image" else ""


static func to_layer(s: Sequence, c: Clip, seq_p: Vector2) -> Vector2:
	var w: Transform2D = Parenting.world_frame(c, s, s.playhead, s.fps)
	var anchor: Vector2 = Parenting.local_tf(c, s.playhead, s.fps)["anchor"]
	var centred: Vector2 = seq_p - Vector2(float(s.width), float(s.height)) * 0.5
	if absf(w.determinant()) < 0.000001:
		return anchor
	return w.affine_inverse() * centred + anchor


static func to_seq(s: Sequence, c: Clip, q: Vector2) -> Vector2:
	var w: Transform2D = Parenting.world_frame(c, s, s.playhead, s.fps)
	var anchor: Vector2 = Parenting.local_tf(c, s.playhead, s.fps)["anchor"]
	return Vector2(float(s.width), float(s.height)) * 0.5 + w * (q - anchor)


static func key_time(c: Clip, e: Dictionary, t: float) -> float:
	return Puppet.key_time(c, e, Puppet.KEY_PINS, t)


static func _run(d: Project, label: String, cmds: Array[Command]) -> bool:
	return Parenting.run(d, label, cmds)


static func clear_selection() -> void:
	sel_clip = ""
	sel_pins = PackedInt32Array()
	sel_holds = PackedInt32Array()
	sel_overs = PackedInt32Array()


static func select(clip_id: String, pins: PackedInt32Array, holds: PackedInt32Array, overs: PackedInt32Array = PackedInt32Array()) -> void:
	var changed: bool = sel_clip != clip_id or sel_pins != pins or sel_holds != holds or sel_overs != overs
	sel_clip = clip_id
	sel_pins = pins
	sel_holds = holds
	sel_overs = overs
	if changed:
		poke_controls()


static func poke_controls() -> void:
	if _poke_due or plant_no_poke:
		return
	_poke_gen += 1
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_poke_due = true
	tree.process_frame.connect(_script()._poke_now, CONNECT_ONE_SHOT)


static func _poke_now() -> void:
	_poke_due = false
	var bus: Object = (load("res://modules/core_panels/panel_bus.gd") as GDScript).call("instance")
	var ec: Object = bus.call("panel", "effect_controls") if bus != null else null
	if ec != null and ec.has_method("rebuild"):
		ec.call("rebuild")


static func selected_pins(c: Clip) -> PackedInt32Array:
	if c == null or sel_clip != c.id:
		return PackedInt32Array()
	var n: int = Puppet.rest_of(Puppet.any_effect_of(c)).size()
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in sel_pins:
		if i >= 0 and i < n and not out.has(i):
			out.append(i)
	return out


static func selected_holds(c: Clip) -> PackedInt32Array:
	if c == null or sel_clip != c.id:
		return PackedInt32Array()
	var n: int = Puppet.hold_count(Puppet.any_effect_of(c))
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in sel_holds:
		if i >= 0 and i < n and not out.has(i):
			out.append(i)
	return out


static func selected_overs(c: Clip) -> PackedInt32Array:
	if c == null or sel_clip != c.id:
		return PackedInt32Array()
	var n: int = Puppet.overlap_count(Puppet.any_effect_of(c))
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in sel_overs:
		if i >= 0 and i < n and not out.has(i):
			out.append(i)
	return out


static func new_entry(d: Project, s: Sequence, c: Clip, q: Vector2, hold: bool = false, over: bool = false) -> Dictionary:
	var size: Vector2 = layer_size(d, s, c)
	var entry: Dictionary = {
		"id": Puppet.EFFECT_ID, "enabled": true, "group": "", "mask": "", "mix": AnimProp.make(1.0),
		"params": {Puppet.KEY_DENSITY: AnimProp.make(Puppet.DENSITY_DEFAULT), Puppet.KEY_EXPANSION: AnimProp.make(0.0), PuppetLocks.KEY_AMOUNT: AnimProp.make(PuppetLocks.AMOUNT_DEFAULT)},
		Puppet.MESH_FIELD: PuppetShape.first_info(d, s, c, size, alpha_path(d, c)),
	}
	var params: Dictionary = entry["params"]
	if over:
		params[Puppet.KEY_PINS] = AnimProp.make([])
		params[Puppet.KEY_REST] = AnimProp.make([])
		params[Puppet.KEY_OVERLAPS] = AnimProp.make([q.x, q.y])
		params[Puppet.over_key(0, "f")] = AnimProp.make(Puppet.OVER_FRONT_DEFAULT)
		params[Puppet.over_key(0, "x")] = AnimProp.make(hold_radius_for(size))
		return entry
	if hold:
		params[Puppet.KEY_PINS] = AnimProp.make([])
		params[Puppet.KEY_REST] = AnimProp.make([])
		params[Puppet.KEY_HOLDS] = AnimProp.make([q.x, q.y])
		params[Puppet.hold_key(0, "r")] = AnimProp.make(hold_radius_for(size))
		params[Puppet.hold_key(0, "a")] = AnimProp.make(Puppet.HOLD_AMOUNT_DEFAULT)
		return entry
	var first: Array = [q.x, q.y]
	params[Puppet.KEY_PINS] = AnimProp.set_key(AnimProp.make(first), Puppet.key_time(c, entry, Puppet.KEY_PINS, s.playhead), first)
	params[Puppet.KEY_REST] = AnimProp.make(first)
	return entry


static func hold_radius_for(size: Vector2) -> float:
	return maxf(round(minf(size.x, size.y) * HOLD_SHARE), HOLD_MIN_RADIUS)


static func _bent(d: Project, s: Sequence, c: Clip, e: Dictionary) -> Dictionary:
	var key: String = c.id + "|" + str(s.playhead) + "|" + str(s.fps) + "|" + str(c.start) + "|" + str(c.duration) + "|" + str(hash(e)) + "|" + str(Puppet.draft_ok)
	if key == _memo_key and not _memo.is_empty():
		return _memo
	_memo = Puppet.deformed_at(c, e, s.playhead, s.fps, Puppet.size_of(e, layer_size(d, s, c)))
	_memo_key = key
	return _memo


static func add_pin(d: Project, s: Sequence, c: Clip, q: Vector2, kind: int = -1) -> int:
	var kd: int = new_kind if kind < 0 else clampi(kind, Puppet.KIND_POSITION, Puppet.KIND_ADVANCED)
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		var uid: String = d.mint_id("e")
		var entry: Dictionary = new_entry(d, s, c, q)
		if kd != Puppet.KIND_POSITION:
			(entry["params"] as Dictionary)[Puppet.KEY_KINDS] = AnimProp.make([kd])
		var cmd: EffectCmds.InsertEffectEntry = EffectCmds.InsertEffectEntry.new(s.id, c.id, entry, uid)
		cmd.label = "Add puppet pin"
		var first: Array[Command] = [cmd]
		_run(d, "Add puppet pin", first)
		return 0
	var made: Dictionary = _bent(d, s, c, e)
	var mesh: Dictionary = made["mesh"]
	var rest: PackedVector2Array = Puppet.rest_of(e)
	var keyed: PackedVector2Array = Puppet.keyed_pins_at(c, e, s.playhead, s.fps)
	var rest_q: Vector2 = Puppet.rest_point(mesh, made["verts"], q, made["drawn"])
	var new_rest: PackedVector2Array = rest.duplicate()
	new_rest.append(rest_q)
	var pins_prop: Dictionary = (e.get("params", {}) as Dictionary).get(Puppet.KEY_PINS, AnimProp.make(Puppet.flat(rest)))
	var grown: Dictionary = Parenting.map_prop(pins_prop, _script().grow_pins.bind(mesh, rest, rest_q, Puppet.gains_at(c, e, s.playhead, s.fps), made["holds"]))
	if not AnimProp.is_animated(grown):
		var flat_now: Array = Puppet.flat(keyed)
		flat_now.append(q.x)
		flat_now.append(q.y)
		grown = AnimProp.make(flat_now)
	var cmds: Array[Command] = [
		ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_REST), AnimProp.make(Puppet.flat(new_rest))),
		ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_PINS), grown),
	]
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var params0: Dictionary = e.get("params", {})
	if kd != Puppet.KIND_POSITION or params0.has(Puppet.KEY_KINDS):
		var grown_kinds: Array = Array(kinds)
		grown_kinds.append(kd)
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_KINDS), AnimProp.make(grown_kinds)))
	if params0.has(Puppet.KEY_TURNS):
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_TURNS), Parenting.map_prop(params0[Puppet.KEY_TURNS], _script().grow_turns.bind(rest.size()))))
	_run(d, "Add puppet pin", cmds)
	return new_rest.size() - 1


static func grow_turns(v: Variant, n: int) -> Variant:
	var turns: PackedVector2Array = Puppet.flat_of(v)
	while turns.size() < n:
		turns.append(Puppet.TURN_REST)
	if turns.size() > n:
		turns.resize(n)
	turns.append(Puppet.TURN_REST)
	return Puppet.flat(turns)


static func pick_turns(v: Variant, keep: PackedInt32Array) -> Variant:
	var turns: PackedVector2Array = Puppet.flat_of(v)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in keep:
		out.append(turns[i] if i < turns.size() else Puppet.TURN_REST)
	return Puppet.flat(out)


static func grow_pins(v: Variant, mesh: Dictionary, rest: PackedVector2Array, rest_q: Vector2, gains: PackedFloat64Array = PackedFloat64Array(), holds: Dictionary = {}) -> Variant:
	var pins: PackedVector2Array = Puppet.flat_of(v)
	while pins.size() < rest.size():
		pins.append(rest[pins.size()])
	if pins.size() > rest.size():
		pins.resize(rest.size())
	var bent: PackedVector2Array = Puppet.solve(mesh, rest, Puppet.apply_links(rest, pins, gains), holds)
	var tris: PackedInt32Array = mesh["tris"]
	var got: Dictionary = Puppet.locate(mesh["verts"], tris, rest_q)
	var at: Vector2 = rest_q
	if not got.is_empty():
		var t: int = int(got["tri"])
		var w: Vector3 = got["w"]
		at = bent[tris[t * 3]] * w.x + bent[tris[t * 3 + 1]] * w.y + bent[tris[t * 3 + 2]] * w.z
	var out: Array = Puppet.flat(pins)
	out.append(at.x)
	out.append(at.y)
	return out


static func add_hold(d: Project, s: Sequence, c: Clip, q: Vector2) -> int:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		var uid: String = d.mint_id("e")
		var cmd: EffectCmds.InsertEffectEntry = EffectCmds.InsertEffectEntry.new(s.id, c.id, new_entry(d, s, c, q, true), uid)
		cmd.label = "Add hold pin"
		var first: Array[Command] = [cmd]
		_run(d, "Add hold pin", first)
		return 0
	var made: Dictionary = _bent(d, s, c, e)
	var rest_q: Vector2 = Puppet.rest_point(made["mesh"], made["verts"], q, made["drawn"])
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var holds: PackedVector2Array = Puppet.holds_of(e)
	var j: int = holds.size()
	holds.append(rest_q)
	params[Puppet.KEY_HOLDS] = AnimProp.make(Puppet.flat(holds))
	params[Puppet.hold_key(j, "r")] = AnimProp.make(hold_radius_for(Puppet.size_of(e, layer_size(d, s, c))))
	params[Puppet.hold_key(j, "a")] = AnimProp.make(Puppet.HOLD_AMOUNT_DEFAULT)
	_set_params(d, s, c, e, params, "Add hold pin")
	return j


static func add_overlap(d: Project, s: Sequence, c: Clip, q: Vector2) -> int:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		var uid: String = d.mint_id("e")
		var cmd: EffectCmds.InsertEffectEntry = EffectCmds.InsertEffectEntry.new(s.id, c.id, new_entry(d, s, c, q, false, true), uid)
		cmd.label = "Add overlap pin"
		var first: Array[Command] = [cmd]
		_run(d, "Add overlap pin", first)
		return 0
	var made: Dictionary = _bent(d, s, c, e)
	var rest_q: Vector2 = Puppet.rest_point(made["mesh"], made["verts"], q, made["drawn"])
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var overs: PackedVector2Array = Puppet.overlaps_of(e)
	var j: int = overs.size()
	overs.append(rest_q)
	params[Puppet.KEY_OVERLAPS] = AnimProp.make(Puppet.flat(overs))
	params[Puppet.over_key(j, "f")] = AnimProp.make(Puppet.OVER_FRONT_DEFAULT)
	params[Puppet.over_key(j, "x")] = AnimProp.make(hold_radius_for(Puppet.size_of(e, layer_size(d, s, c))))
	_set_params(d, s, c, e, params, "Add overlap pin")
	return j


static func rebuild_mesh(d: Project, s: Sequence, c: Clip, comp: Node = null) -> String:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return "This clip has no puppet pins"
	var got: Dictionary = PuppetShape.capture(d, s, c, e, comp)
	if bool(got.get("empty", false)):
		return "Nothing of the picture shows at this frame, so the mesh was kept"
	var info: Dictionary = PuppetShape.info_with(Puppet.mesh_info(e), got)
	var cmds: Array[Command] = [EffectCmds.SetEffectEntry.new(s.id, c.id, String(e.get("uid", "")), {Puppet.MESH_FIELD: info}, false, "Rebuild puppet mesh")]
	_run(d, "Rebuild puppet mesh", cmds)
	return ""


static func _set_params(d: Project, s: Sequence, c: Clip, e: Dictionary, params: Dictionary, label: String) -> bool:
	var cmds: Array[Command] = [EffectCmds.SetEffectEntry.new(s.id, c.id, String(e.get("uid", "")), {"params": params}, false, label)]
	return _run(d, label, cmds)


static func params_without(e: Dictionary, pins_gone: PackedInt32Array, holds_gone: PackedInt32Array, overs_gone: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var rest: PackedVector2Array = Puppet.rest_of(e)
	var keep_pins: PackedInt32Array = PackedInt32Array()
	var renumber: Dictionary = {}
	for i: int in rest.size():
		if not pins_gone.has(i):
			renumber[i] = keep_pins.size()
			keep_pins.append(i)
	var new_rest: PackedVector2Array = PackedVector2Array()
	for i2: int in keep_pins:
		new_rest.append(rest[i2])
	params[Puppet.KEY_REST] = AnimProp.make(Puppet.flat(new_rest))
	var pins_prop: Dictionary = params.get(Puppet.KEY_PINS, AnimProp.make(Puppet.flat(rest)))
	params[Puppet.KEY_PINS] = Parenting.map_prop(pins_prop, _script().pick_pins.bind(keep_pins, rest))
	if params.has(Puppet.KEY_KINDS):
		var kinds: PackedInt32Array = Puppet.kinds_of(e)
		var kept_kinds: Array = []
		var any_kind: bool = false
		for i4: int in keep_pins:
			kept_kinds.append(kinds[i4] if i4 < kinds.size() else Puppet.KIND_POSITION)
			if int(kept_kinds[kept_kinds.size() - 1]) != Puppet.KIND_POSITION:
				any_kind = true
		if any_kind:
			params[Puppet.KEY_KINDS] = AnimProp.make(kept_kinds)
		else:
			params.erase(Puppet.KEY_KINDS)
	if params.has(Puppet.KEY_TURNS):
		params[Puppet.KEY_TURNS] = Parenting.map_prop(params[Puppet.KEY_TURNS], _script().pick_turns.bind(keep_pins))
	var links: PackedInt32Array = Puppet.links_of(e)
	var kept_links: Array = []
	var link_props: Array = []
	for k: int in links.size() / 2:
		var a: int = links[k * 2]
		var b: int = links[k * 2 + 1]
		var ab_v: Variant = params.get(Puppet.link_key(k, "ab"), AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT))
		var ba_v: Variant = params.get(Puppet.link_key(k, "ba"), AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT))
		params.erase(Puppet.link_key(k, "ab"))
		params.erase(Puppet.link_key(k, "ba"))
		if not renumber.has(a) or not renumber.has(b):
			continue
		kept_links.append(int(renumber[a]))
		kept_links.append(int(renumber[b]))
		link_props.append([ab_v, ba_v])
	for n: int in link_props.size():
		params[Puppet.link_key(n, "ab")] = link_props[n][0]
		params[Puppet.link_key(n, "ba")] = link_props[n][1]
	if kept_links.is_empty():
		params.erase(Puppet.KEY_LINKS)
	else:
		params[Puppet.KEY_LINKS] = AnimProp.make(kept_links)
	var holds: PackedVector2Array = Puppet.holds_of(e)
	var new_holds: PackedVector2Array = PackedVector2Array()
	var hold_props: Array = []
	for j: int in holds.size():
		var r_v: Variant = params.get(Puppet.hold_key(j, "r"), AnimProp.make(Puppet.HOLD_RADIUS_DEFAULT))
		var a_v: Variant = params.get(Puppet.hold_key(j, "a"), AnimProp.make(Puppet.HOLD_AMOUNT_DEFAULT))
		params.erase(Puppet.hold_key(j, "r"))
		params.erase(Puppet.hold_key(j, "a"))
		if holds_gone.has(j):
			continue
		new_holds.append(holds[j])
		hold_props.append([r_v, a_v])
	for m: int in hold_props.size():
		params[Puppet.hold_key(m, "r")] = hold_props[m][0]
		params[Puppet.hold_key(m, "a")] = hold_props[m][1]
	if new_holds.is_empty():
		params.erase(Puppet.KEY_HOLDS)
	else:
		params[Puppet.KEY_HOLDS] = AnimProp.make(Puppet.flat(new_holds))
	var overs: PackedVector2Array = Puppet.overlaps_of(e)
	var new_overs: PackedVector2Array = PackedVector2Array()
	var over_props: Array = []
	for o: int in overs.size():
		var f_v: Variant = params.get(Puppet.over_key(o, "f"), AnimProp.make(Puppet.OVER_FRONT_DEFAULT))
		var x_v: Variant = params.get(Puppet.over_key(o, "x"), AnimProp.make(Puppet.OVER_EXTENT_DEFAULT))
		params.erase(Puppet.over_key(o, "f"))
		params.erase(Puppet.over_key(o, "x"))
		if overs_gone.has(o):
			continue
		new_overs.append(overs[o])
		over_props.append([f_v, x_v])
	for q: int in over_props.size():
		params[Puppet.over_key(q, "f")] = over_props[q][0]
		params[Puppet.over_key(q, "x")] = over_props[q][1]
	if new_overs.is_empty():
		params.erase(Puppet.KEY_OVERLAPS)
	else:
		params[Puppet.KEY_OVERLAPS] = AnimProp.make(Puppet.flat(new_overs))
	return params


static func pick_pins(v: Variant, keep: PackedInt32Array, rest: PackedVector2Array) -> Variant:
	var pins: PackedVector2Array = Puppet.flat_of(v)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in keep:
		out.append(pins[i] if i < pins.size() else rest[i])
	return Puppet.flat(out)


static func drop_many(d: Project, s: Sequence, c: Clip, pins_gone: PackedInt32Array, holds_gone: PackedInt32Array, overs_gone: PackedInt32Array = PackedInt32Array()) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty() or (pins_gone.is_empty() and holds_gone.is_empty() and overs_gone.is_empty()):
		return false
	var n_pins: int = Puppet.rest_of(e).size()
	var n_holds: int = Puppet.hold_count(e)
	var n_overs: int = Puppet.overlap_count(e)
	var label: String = "Remove puppet pin" if pins_gone.size() + holds_gone.size() + overs_gone.size() == 1 else "Remove puppet pins"
	if holds_gone.size() == 1 and pins_gone.is_empty() and overs_gone.is_empty():
		label = "Remove hold pin"
	if overs_gone.size() == 1 and pins_gone.is_empty() and holds_gone.is_empty():
		label = "Remove overlap pin"
	clear_selection()
	var left_pins: int = 0
	for i: int in n_pins:
		if not pins_gone.has(i):
			left_pins += 1
	var left_holds: int = 0
	for j: int in n_holds:
		if not holds_gone.has(j):
			left_holds += 1
	var left_overs: int = 0
	for o: int in n_overs:
		if not overs_gone.has(o):
			left_overs += 1
	if left_pins == 0 and left_holds == 0 and left_overs == 0:
		var gone: Array[Command] = [EffectCmds.RemoveEffect.new(s.id, c.id, String(e.get("uid", "")))]
		return _run(d, label, gone)
	return _set_params(d, s, c, e, params_without(e, pins_gone, holds_gone, overs_gone), label)


static func drop_pin(d: Project, s: Sequence, c: Clip, index: int) -> bool:
	var rest: PackedVector2Array = Puppet.rest_of(Puppet.any_effect_of(c))
	if index < 0 or index >= rest.size():
		return false
	return drop_many(d, s, c, PackedInt32Array([index]), PackedInt32Array())


static func drop_hold(d: Project, s: Sequence, c: Clip, index: int) -> bool:
	if index < 0 or index >= Puppet.hold_count(Puppet.any_effect_of(c)):
		return false
	return drop_many(d, s, c, PackedInt32Array(), PackedInt32Array([index]))


static func drop_overlap(d: Project, s: Sequence, c: Clip, index: int) -> bool:
	if index < 0 or index >= Puppet.overlap_count(Puppet.any_effect_of(c)):
		return false
	return drop_many(d, s, c, PackedInt32Array(), PackedInt32Array(), PackedInt32Array([index]))


static func shrink_pins(v: Variant, index: int) -> Variant:
	var pins: PackedVector2Array = Puppet.flat_of(v)
	if index < pins.size():
		pins.remove_at(index)
	return Puppet.flat(pins)


static func link_refusal(e: Dictionary, a: int, b: int) -> String:
	var n: int = Puppet.rest_of(e).size()
	if a < 0 or b < 0 or a >= n or b >= n:
		return "Links join two move pins"
	if a == b:
		return "A pin cannot be linked to itself"
	var links: PackedInt32Array = Puppet.links_of(e)
	for k: int in links.size() / 2:
		if (links[k * 2] == a and links[k * 2 + 1] == b) or (links[k * 2] == b and links[k * 2 + 1] == a):
			return "Pin " + str(a + 1) + " and pin " + str(b + 1) + " are already linked"
	return ""


static func link_pins(d: Project, s: Sequence, c: Clip, a: int, b: int) -> String:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return "This clip has no puppet pins"
	var why: String = link_refusal(e, a, b)
	if not why.is_empty():
		return why
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var links: PackedInt32Array = Puppet.links_of(e)
	var k: int = links.size() / 2
	var flat_links: Array = []
	for x: int in links:
		flat_links.append(x)
	flat_links.append(a)
	flat_links.append(b)
	params[Puppet.KEY_LINKS] = AnimProp.make(flat_links)
	params[Puppet.link_key(k, "ab")] = AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT)
	params[Puppet.link_key(k, "ba")] = AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT)
	_set_params(d, s, c, e, params, "Link pins")
	return ""


static func unlink(d: Project, s: Sequence, c: Clip, k: int) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	var links: PackedInt32Array = Puppet.links_of(e)
	if e.is_empty() or k < 0 or k >= links.size() / 2:
		return false
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var flat_links: Array = []
	var props: Array = []
	for i: int in links.size() / 2:
		var ab_v: Variant = params.get(Puppet.link_key(i, "ab"), AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT))
		var ba_v: Variant = params.get(Puppet.link_key(i, "ba"), AnimProp.make(Puppet.LINK_STRENGTH_DEFAULT))
		params.erase(Puppet.link_key(i, "ab"))
		params.erase(Puppet.link_key(i, "ba"))
		if i == k:
			continue
		flat_links.append(links[i * 2])
		flat_links.append(links[i * 2 + 1])
		props.append([ab_v, ba_v])
	for n: int in props.size():
		params[Puppet.link_key(n, "ab")] = props[n][0]
		params[Puppet.link_key(n, "ba")] = props[n][1]
	if flat_links.is_empty():
		params.erase(Puppet.KEY_LINKS)
	else:
		params[Puppet.KEY_LINKS] = AnimProp.make(flat_links)
	return _set_params(d, s, c, e, params, "Remove pin link")


static func link_selected(d: Project, s: Sequence, c: Clip) -> String:
	var picked: PackedInt32Array = selected_pins(c)
	if picked.size() != 2:
		return "Pick two pins first: click one, then Shift click the other"
	return link_pins(d, s, c, picked[0], picked[1])


static func move_pin_live(d: Project, s: Sequence, c: Clip, index: int, q: Vector2, key_at: float) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var path: String = path_of(e, Puppet.KEY_PINS)
	var keyed: PackedVector2Array = Puppet.keyed_pins_at(c, e, s.playhead, s.fps)
	if index < 0 or index >= keyed.size():
		return
	if Puppet.link_count(e) > 0:
		keyed[index] = Puppet.keyed_for(Puppet.rest_of(e), keyed, Puppet.gains_at(c, e, s.playhead, s.fps), index, q)
	else:
		keyed[index] = q
	var value: Array = Puppet.flat(keyed)
	var current: Dictionary = c.get_param(path)
	var next: Dictionary = AnimProp.make(value) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), key_time(c, e, key_at), value)
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))


static func move_hold_live(d: Project, s: Sequence, c: Clip, index: int, q: Vector2) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	var holds: PackedVector2Array = Puppet.holds_of(e)
	if e.is_empty() or index < 0 or index >= holds.size():
		return
	holds[index] = q
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_HOLDS), AnimProp.make(Puppet.flat(holds))))


static func move_over_live(d: Project, s: Sequence, c: Clip, index: int, q: Vector2) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	var overs: PackedVector2Array = Puppet.overlaps_of(e)
	if e.is_empty() or index < 0 or index >= overs.size():
		return
	overs[index] = q
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_OVERLAPS), AnimProp.make(Puppet.flat(overs))))


static func value_live(d: Project, s: Sequence, c: Clip, key: String, v: float) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var path: String = path_of(e, key)
	var current: Dictionary = c.get_param(path)
	var next: Dictionary = AnimProp.make(v)
	if AnimProp.is_animated(current):
		next = AnimProp.set_key(current, Puppet.key_time(c, e, key, s.playhead), v)
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))


static func set_value(d: Project, s: Sequence, c: Clip, key: String, v: float, label: String) -> bool:
	value_live(d, s, c, key, v)
	d.undo.commit_live(label)
	return true


static func set_key_animated(d: Project, s: Sequence, c: Clip, key: String, on: bool, fallback: float) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return false
	var v: float = Puppet.value_at(c, e, key, s.playhead, s.fps, fallback)
	var next: Dictionary = AnimProp.set_key(AnimProp.make(v), Puppet.key_time(c, e, key, s.playhead), v) if on else AnimProp.make(v)
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, key), next)]
	return _run(d, "Animate " + key_label(key) if on else "Stop animating " + key_label(key), cmds)


static func key_label(key: String) -> String:
	var parts: PackedStringArray = key.split("_")
	if parts.size() != 3:
		return key
	var n: String = str(int(parts[1]) + 1)
	if parts[0] == "hold":
		return ("hold " + n + " radius") if parts[2] == "r" else ("hold " + n + " amount")
	if parts[0] == "over":
		return ("overlap " + n + " in front") if parts[2] == "f" else ("overlap " + n + " extent")
	return "link " + n + (" first pull" if parts[2] == "ab" else " second pull")


static func set_animated(d: Project, s: Sequence, c: Clip, on: bool) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return false
	var path: String = path_of(e, Puppet.KEY_PINS)
	var value: Array = Puppet.flat(Puppet.keyed_pins_at(c, e, s.playhead, s.fps))
	var next: Dictionary = AnimProp.set_key(AnimProp.make(value), key_time(c, e, s.playhead), value) if on else AnimProp.make(value)
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path, next)]
	return _run(d, "Animate pins" if on else "Stop animating pins", cmds)


static func reset_pins(d: Project, s: Sequence, c: Clip) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return false
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_PINS), AnimProp.make(Puppet.flat(Puppet.rest_of(e))))]
	return _run(d, "Reset pins", cmds)


static func target_clip(panel: Object, at_seq: Vector2, pic: Rect2, screen: Vector2) -> Clip:
	var s: Sequence = panel.call("seq")
	var focus: Clip = panel.call("gizmo_clip")
	if focus != null:
		if not Puppet.any_effect_of(focus).is_empty() and not hit_at(panel, pic, focus, screen).is_empty():
			return focus
		var q: PackedVector2Array = (panel.call("quad_for", focus) as Dictionary).get("quad", PackedVector2Array())
		if q.size() == 4 and Geometry2D.is_point_in_polygon(at_seq, q):
			return focus
	var hits: PackedStringArray = panel.call("hits_at", screen, pic)
	return s.clip_by_id(hits[0]) if not hits.is_empty() else null


static func _pin_screen(panel: Object, pic: Rect2, c: Clip, q: Vector2) -> Vector2:
	return panel.call("_to_picture", pic, to_seq(panel.call("seq"), c, q))


static func _pin_near(panel: Object, pic: Rect2, c: Clip, screen: Vector2) -> int:
	var s: Sequence = panel.call("seq")
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return -1
	var pins: PackedVector2Array = _bent(panel.call("doc"), s, c, e)["pins"] if Puppet.any_bend(e) else Puppet.linked_pins_at(c, e, s.playhead, s.fps)
	var best: int = -1
	var best_d: float = PIN_REACH
	for i: int in pins.size():
		var dd: float = _pin_screen(panel, pic, c, pins[i]).distance_to(screen)
		if dd <= best_d:
			best_d = dd
			best = i
	return best


static func hold_spots(d: Project, s: Sequence, c: Clip, e: Dictionary) -> PackedVector2Array:
	return spots_of(d, s, c, e, Puppet.holds_of(e))


static func over_spots(_d: Project, _s: Sequence, _c: Clip, e: Dictionary) -> PackedVector2Array:
	return Puppet.overlaps_of(e)


static func spots_of(d: Project, s: Sequence, c: Clip, e: Dictionary, holds: PackedVector2Array) -> PackedVector2Array:
	if holds.is_empty():
		return holds
	var made: Dictionary = _bent(d, s, c, e)
	var mesh: Dictionary = made["mesh"]
	var bent: PackedVector2Array = made["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var out: PackedVector2Array = PackedVector2Array()
	for h: Vector2 in holds:
		var got: Dictionary = Puppet.locate(mesh["verts"], tris, h)
		if got.is_empty() or bent.size() != (mesh["verts"] as PackedVector2Array).size():
			out.append(h)
			continue
		var t: int = int(got["tri"])
		var w: Vector3 = got["w"]
		var rv: PackedVector2Array = mesh["verts"]
		var shift: Vector2 = (bent[tris[t * 3]] - rv[tris[t * 3]]) * w.x + (bent[tris[t * 3 + 1]] - rv[tris[t * 3 + 1]]) * w.y + (bent[tris[t * 3 + 2]] - rv[tris[t * 3 + 2]]) * w.z
		out.append(h + shift)
	return out


static func ring_px(panel: Object, pic: Rect2, c: Clip, centre: Vector2, r: float) -> float:
	var a: Vector2 = _pin_screen(panel, pic, c, centre)
	var b: Vector2 = _pin_screen(panel, pic, c, centre + Vector2(r, 0.0))
	return a.distance_to(b)


static func hit_at(panel: Object, pic: Rect2, c: Clip, screen: Vector2) -> Dictionary:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return {}
	var pin: int = _pin_near(panel, pic, c, screen)
	if pin >= 0:
		return {"kind": "pin", "index": pin}
	var giz: Dictionary = gizmo_hit(panel, pic, c, screen)
	if not giz.is_empty():
		return giz
	var spots: PackedVector2Array = hold_spots(d, s, c, e)
	var best: int = -1
	var best_d: float = PIN_REACH
	for j: int in spots.size():
		var dd: float = _pin_screen(panel, pic, c, spots[j]).distance_to(screen)
		if dd <= best_d:
			best_d = dd
			best = j
	if best >= 0:
		return {"kind": "hold", "index": best}
	var ospots: PackedVector2Array = over_spots(d, s, c, e)
	var best_o: int = -1
	var best_od: float = PIN_REACH
	for o: int in ospots.size():
		var od: float = _pin_screen(panel, pic, c, ospots[o]).distance_to(screen)
		if od <= best_od:
			best_od = od
			best_o = o
	if best_o >= 0:
		return {"kind": "over", "index": best_o}
	var overs: Dictionary = Puppet.overlaps_at(c, e, s.playhead, s.fps)
	var extents: PackedFloat64Array = overs["x"]
	for o2: int in selected_overs(c):
		if o2 >= ospots.size() or o2 >= extents.size():
			continue
		var oc: Vector2 = _pin_screen(panel, pic, c, ospots[o2])
		if absf(oc.distance_to(screen) - ring_px(panel, pic, c, ospots[o2], extents[o2])) <= RING_REACH:
			return {"kind": "over_ring", "index": o2}
	var holds: Dictionary = Puppet.holds_at(c, e, s.playhead, s.fps)
	var radii: PackedFloat64Array = holds["r"]
	for j2: int in selected_holds(c):
		if j2 >= spots.size() or j2 >= radii.size():
			continue
		var centre: Vector2 = _pin_screen(panel, pic, c, spots[j2])
		if absf(centre.distance_to(screen) - ring_px(panel, pic, c, spots[j2], radii[j2])) <= RING_REACH:
			return {"kind": "ring", "index": j2}
	return {}


static func _pick(c: Clip, kind: String, index: int, add: bool) -> void:
	var pins: PackedInt32Array = selected_pins(c)
	var holds: PackedInt32Array = selected_holds(c)
	var overs: PackedInt32Array = selected_overs(c)
	var list: PackedInt32Array = pins if kind == "pin" else (overs if kind == "over" else holds)
	var had: bool = list.has(index)
	if add:
		if had:
			list.remove_at(list.find(index))
		else:
			list.append(index)
	elif not had:
		pins = PackedInt32Array()
		holds = PackedInt32Array()
		overs = PackedInt32Array()
		list = PackedInt32Array([index])
	if kind == "pin":
		select(c.id, list, holds, overs)
	elif kind == "over":
		select(c.id, pins, holds, list)
	else:
		select(c.id, pins, list, overs)


static func layer_xf(panel: Object, pic: Rect2, c: Clip) -> Transform2D:
	var o: Vector2 = _pin_screen(panel, pic, c, Vector2.ZERO)
	var x: Vector2 = (_pin_screen(panel, pic, c, Vector2(XF_PROBE, 0.0)) - o) / XF_PROBE
	var y: Vector2 = (_pin_screen(panel, pic, c, Vector2(0.0, XF_PROBE)) - o) / XF_PROBE
	return Transform2D(x, y, o)


static func screen_to_layer(panel: Object, pic: Rect2, c: Clip, screen: Vector2) -> Vector2:
	var s: Sequence = panel.call("seq")
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	return to_layer(s, c, (screen - pic.position) / maxf(k, 0.0001))


static func set_mode(m: String) -> void:
	mode = MODE_LOCKS if m == MODE_LOCKS else MODE_PINS
	_drag = {}
	PuppetLockUi.clear()
	if mode == MODE_LOCKS and not tool_on():
		Session.set_tool(TOOL_ID)
	Events.toast(LOCK_TIP if mode == MODE_LOCKS else TOOL_TIP)
	redraw_program()
	poke_controls()


static func turn_key_at(panel: Object, c: Clip, e: Dictionary, s: Sequence) -> float:
	var bus: Object = panel.call("bus") if panel != null else null
	var at: float = float(bus.call("key_time_for", c, path_of(e, Puppet.KEY_TURNS), s.playhead)) if bus != null else -1.0
	if at < 0.0 and AnimProp.is_animated((e.get("params", {}) as Dictionary).get(Puppet.KEY_PINS, {})):
		at = s.playhead
	return at


static func turns_live(d: Project, s: Sequence, c: Clip, index: int, turn: Vector2, key_at: float) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var cur: PackedVector2Array = Puppet.turns_at(c, e, s.playhead, s.fps)
	if index < 0 or index >= cur.size():
		return
	cur[index] = Vector2(turn.x, clampf(turn.y, Puppet.SCALE_MIN, Puppet.SCALE_MAX))
	var value: Array = Puppet.flat(cur)
	var path: String = path_of(e, Puppet.KEY_TURNS)
	var current: Dictionary = c.get_param(path)
	var next: Dictionary = AnimProp.make(value)
	if key_at >= 0.0 or AnimProp.is_animated(current):
		var t: float = key_at if key_at >= 0.0 else s.playhead
		next = AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), Puppet.key_time(c, e, Puppet.KEY_TURNS, t), value)
	d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))


static func set_turn(d: Project, s: Sequence, c: Clip, index: int, turn: Vector2, key_at: float, label: String) -> bool:
	turns_live(d, s, c, index, turn, key_at)
	d.undo.commit_live(label)
	return true


static func replace_pin(v: Variant, index: int, at: Vector2) -> Variant:
	var pins: PackedVector2Array = Puppet.flat_of(v)
	if index >= 0 and index < pins.size():
		pins[index] = at
	return Puppet.flat(pins)


static func set_kind(d: Project, s: Sequence, c: Clip, picked: PackedInt32Array, kind: int) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty() or picked.is_empty():
		return false
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var made: Dictionary = _bent(d, s, c, e)
	var shown: PackedVector2Array = made["pins"]
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	var changed: bool = false
	for i: int in picked:
		if i < 0 or i >= kinds.size() or kinds[i] == kind:
			continue
		if kinds[i] == Puppet.KIND_BEND and i < shown.size():
			var pins_prop: Dictionary = params.get(Puppet.KEY_PINS, AnimProp.make(Puppet.flat(Puppet.rest_of(e))))
			params[Puppet.KEY_PINS] = Parenting.map_prop(pins_prop, _script().replace_pin.bind(i, shown[i]))
		kinds[i] = kind
		changed = true
	if not changed:
		return false
	var any: bool = false
	for k: int in kinds:
		if k != Puppet.KIND_POSITION:
			any = true
	if any:
		params[Puppet.KEY_KINDS] = AnimProp.make(Array(kinds))
	else:
		params.erase(Puppet.KEY_KINDS)
	return _set_params(d, s, c, e, params, "Make " + ("pin " if picked.size() == 1 else "pins ") + Puppet.KIND_NAMES[kind].to_lower())


static func move_group_live(d: Project, s: Sequence, c: Clip, group: PackedInt32Array, delta: Vector2, start_keyed: PackedVector2Array, start_shown: PackedVector2Array, start_rest: PackedVector2Array, key_at: float) -> void:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var keyed: PackedVector2Array = start_keyed.duplicate()
	var rest: PackedVector2Array = start_rest.duplicate()
	var linked: bool = Puppet.link_count(e) > 0
	var gains: PackedFloat64Array = Puppet.gains_at(c, e, s.playhead, s.fps) if linked else PackedFloat64Array()
	var moved_rest: bool = false
	var moved_pins: bool = false
	var made: Dictionary = {}
	for i: int in group:
		if i < 0 or i >= keyed.size() or i >= start_shown.size():
			continue
		var target: Vector2 = start_shown[i] + delta
		if i < kinds.size() and kinds[i] == Puppet.KIND_BEND:
			if made.is_empty():
				made = _bent(d, s, c, e)
			rest[i] = Puppet.rest_point(made["mesh"], made["verts"], target, made["drawn"])
			keyed[i] = rest[i]
			moved_rest = true
		else:
			keyed[i] = Puppet.keyed_for(start_rest, keyed, gains, i, target) if linked else target
			moved_pins = true
	if moved_pins or moved_rest:
		var path: String = path_of(e, Puppet.KEY_PINS)
		var value: Array = Puppet.flat(keyed)
		var current: Dictionary = c.get_param(path)
		var next: Dictionary = AnimProp.make(value) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), key_time(c, e, key_at), value)
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))
	if moved_rest:
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_REST), AnimProp.make(Puppet.flat(rest))))


static func nudge(d: Project, s: Sequence, c: Clip, panel: Object, delta: Vector2) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	var group: PackedInt32Array = selected_pins(c)
	if e.is_empty() or group.is_empty():
		return false
	var made: Dictionary = _bent(d, s, c, e)
	var bus: Object = panel.call("bus") if panel != null else null
	var key_at: float = float(bus.call("key_time_for", c, path_of(e, Puppet.KEY_PINS), s.playhead)) if bus != null else -1.0
	move_group_live(d, s, c, group, delta, Puppet.keyed_pins_at(c, e, s.playhead, s.fps), made["pins"], Puppet.rest_of(e), key_at)
	d.undo.commit_live("Nudge puppet pin" if group.size() == 1 else "Nudge puppet pins")
	return true


static func select_all(c: Clip) -> void:
	var all: PackedInt32Array = PackedInt32Array()
	for i: int in Puppet.rest_of(Puppet.any_effect_of(c)).size():
		all.append(i)
	select(c.id, all, PackedInt32Array(), PackedInt32Array())


static func gizmo_hit(panel: Object, pic: Rect2, c: Clip, screen: Vector2) -> Dictionary:
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return {}
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var picked: PackedInt32Array = selected_pins(c)
	if picked.is_empty():
		return {}
	var made: Dictionary = _bent(d, s, c, e)
	var shown: PackedVector2Array = made["pins"]
	var turns: PackedVector2Array = Puppet.turns_at(c, e, s.playhead, s.fps)
	var xf: Transform2D = layer_xf(panel, pic, c)
	for i: int in picked:
		if i >= kinds.size() or kinds[i] == Puppet.KIND_POSITION or i >= shown.size():
			continue
		var centre: Vector2 = xf * shown[i]
		var g: Dictionary = gizmo_shape(xf, centre, shown_turn(made, i, turns[i] if i < turns.size() else Puppet.TURN_REST))
		if screen.distance_to(g["handle"]) <= SCALE_HALF + 3.0:
			return {"kind": "scale", "index": i}
		if absf(screen.distance_to(centre) - TURN_RING) <= TURN_REACH:
			return {"kind": "turn", "index": i}
	return {}


static func shown_turn(made: Dictionary, i: int, turn: Vector2) -> Vector2:
	var rest: PackedVector2Array = made.get("rest", PackedVector2Array())
	if i < 0 or i >= rest.size():
		return turn
	return Vector2(rad_to_deg(Puppet.rotation_at(made["mesh"], made["verts"], rest[i])), turn.y)


static func gizmo_shape(xf: Transform2D, centre: Vector2, turn: Vector2) -> Dictionary:
	var dir: Vector2 = xf.basis_xform(Vector2.from_angle(deg_to_rad(turn.x)))
	dir = dir.normalized() if dir.length() > 0.000001 else Vector2.RIGHT
	var reach: float = TURN_RING * clampf(turn.y / 100.0, 0.35, 2.6)
	return {"dir": dir, "handle": centre + dir * reach, "reach": reach}


static func _angle_deg(v: Vector2) -> float:
	return rad_to_deg(atan2(v.y, v.x))


static func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if not tool_on():
		_drag = {}
		Puppet.draft_ok = false
		return false
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null or pic.size.x <= 0.0:
		return false
	if mode == MODE_LOCKS:
		return PuppetLockUi.input(event, pic, panel)
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not mb.pressed:
			_release(d, s, panel, pic, mb.position)
			Puppet.draft_ok = false
			_redraw(panel)
			return true
		var at_seq: Vector2 = (mb.position - pic.position) / maxf(k, 0.0001)
		var c: Clip = target_clip(panel, at_seq, pic, mb.position)
		if c == null:
			clear_selection()
			_redraw(panel)
			return true
		var hit: Dictionary = hit_at(panel, pic, c, mb.position)
		var kind: String = String(hit.get("kind", ""))
		var index: int = int(hit.get("index", -1))
		var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
		Puppet.draft_ok = true
		if mb.alt_pressed:
			if kind == "pin" or kind == "turn" or kind == "scale":
				drop_pin(d, s, c, index)
			elif kind == "hold" or kind == "ring":
				drop_hold(d, s, c, index)
			elif kind == "over" or kind == "over_ring":
				drop_overlap(d, s, c, index)
		elif kind == "turn" or kind == "scale":
			var e0: Dictionary = Puppet.any_effect_of(c)
			var made0: Dictionary = _bent(d, s, c, e0)
			var centre: Vector2 = layer_xf(panel, pic, c) * (made0["pins"] as PackedVector2Array)[index]
			_drag = {"clip_id": c.id, "kind": kind, "pin": index, "centre": centre, "from": mb.position, "start": Puppet.turns_at(c, e0, s.playhead, s.fps)[index], "key_at": turn_key_at(panel, c, e0, s)}
		elif kind == "pin" and ctrl:
			_drag = {"clip_id": c.id, "kind": "link", "pin": index, "to": mb.position}
		elif kind == "pin" and PuppetRecord.on and Puppet.kind_of(Puppet.any_effect_of(c), index) != Puppet.KIND_BEND:
			select(c.id, PackedInt32Array([index]), PackedInt32Array())
			if PuppetRecord.begin(d, s, c, index, screen_to_layer(panel, pic, c, mb.position)):
				_drag = {"clip_id": c.id, "kind": "record", "pin": index}
		elif kind == "pin":
			_pick(c, "pin", index, mb.shift_pressed)
			_drag = _group_drag(d, s, c, panel, pic, index, mb.position, false)
		elif kind == "hold":
			_pick(c, "hold", index, mb.shift_pressed)
			_drag = {"clip_id": c.id, "kind": "hold", "hold": index}
		elif kind == "ring":
			_drag = {"clip_id": c.id, "kind": "ring", "hold": index}
		elif kind == "over":
			_pick(c, "over", index, mb.shift_pressed)
			_drag = {"clip_id": c.id, "kind": "over", "over": index}
		elif kind == "over_ring":
			_drag = {"clip_id": c.id, "kind": "over_ring", "over": index}
		elif ctrl and mb.shift_pressed:
			var made_o: int = add_overlap(d, s, c, to_layer(s, c, at_seq))
			select(c.id, PackedInt32Array(), PackedInt32Array(), PackedInt32Array([made_o]))
			s.selected_clip_ids = PackedStringArray([c.id])
		elif ctrl:
			var made_h: int = add_hold(d, s, c, to_layer(s, c, at_seq))
			select(c.id, PackedInt32Array(), PackedInt32Array([made_h]))
			s.selected_clip_ids = PackedStringArray([c.id])
		elif mb.shift_pressed and not Puppet.any_effect_of(c).is_empty():
			_drag = {"clip_id": c.id, "kind": "marquee", "from": mb.position, "to": mb.position, "at_seq": at_seq}
		else:
			_add_and_grab(d, s, c, panel, pic, to_layer(s, c, at_seq), mb.position)
		_redraw(panel)
		return true
	if event is InputEventMouseMotion and not _drag.is_empty():
		var mm: InputEventMouseMotion = event
		var dc: Clip = s.clip_by_id(String(_drag["clip_id"]))
		if dc == null:
			_drag = {}
			return true
		var seq_p: Vector2 = (mm.position - pic.position) / maxf(k, 0.0001)
		var dkind: String = String(_drag.get("kind", "pin"))
		if dkind == "link":
			_drag["to"] = mm.position
		elif dkind == "marquee":
			_drag["to"] = mm.position
		elif dkind == "record":
			PuppetRecord.move(to_layer(s, dc, seq_p))
		elif dkind == "turn":
			var cen: Vector2 = _drag["centre"]
			var a0: float = _angle_deg(Vector2(_drag["from"]) - cen)
			var a1: float = _angle_deg(mm.position - cen)
			var st: Vector2 = _drag["start"]
			var turned: float = wrapf(a1 - a0, -180.0, 180.0)
			var step: float = st.x + turned
			if mm.shift_pressed:
				step = snappedf(step, 15.0)
			turns_live(d, s, dc, int(_drag["pin"]), Vector2(step, st.y), float(_drag["key_at"]))
		elif dkind == "scale":
			var cen2: Vector2 = _drag["centre"]
			var st2: Vector2 = _drag["start"]
			var d0: float = maxf(Vector2(_drag["from"]).distance_to(cen2), 1.0)
			var sc: float = st2.y * mm.position.distance_to(cen2) / d0
			turns_live(d, s, dc, int(_drag["pin"]), Vector2(st2.x, snappedf(sc, 0.1)), float(_drag["key_at"]))
		elif dkind == "hold":
			var e3: Dictionary = Puppet.any_effect_of(dc)
			var made3: Dictionary = _bent(d, s, dc, e3)
			move_hold_live(d, s, dc, int(_drag["hold"]), Puppet.rest_point(made3["mesh"], made3["verts"], to_layer(s, dc, seq_p), made3["drawn"]))
		elif dkind == "over":
			move_over_live(d, s, dc, int(_drag["over"]), to_layer(s, dc, seq_p))
		elif dkind == "over_ring":
			var e6: Dictionary = Puppet.any_effect_of(dc)
			var ospots: PackedVector2Array = over_spots(d, s, dc, e6)
			var oj: int = int(_drag["over"])
			if oj < ospots.size():
				var ox: float = maxf(ospots[oj].distance_to(to_layer(s, dc, seq_p)), 1.0)
				value_live(d, s, dc, Puppet.over_key(oj, "x"), snappedf(ox, 0.1))
		elif dkind == "ring":
			var e4: Dictionary = Puppet.any_effect_of(dc)
			var spots: PackedVector2Array = hold_spots(d, s, dc, e4)
			var j: int = int(_drag["hold"])
			if j < spots.size():
				var r: float = maxf(spots[j].distance_to(to_layer(s, dc, seq_p)), 1.0)
				value_live(d, s, dc, Puppet.hold_key(j, "r"), snappedf(r, 0.1))
		else:
			if bool(_drag.get("fresh", false)):
				var e2: Dictionary = Puppet.any_effect_of(dc)
				var bus2: Object = panel.call("bus")
				_drag["key_at"] = float(bus2.call("key_time_for", dc, path_of(e2, Puppet.KEY_PINS), s.playhead)) if bus2 != null else -1.0
				_drag.erase("fresh")
			var now_layer: Vector2 = to_layer(s, dc, seq_p)
			move_group_live(d, s, dc, _drag["group"], now_layer - Vector2(_drag["from_layer"]), _drag["keyed"], _drag["shown"], _drag["rest"], float(_drag["key_at"]))
		_redraw(panel)
		return true
	return false


static func _group_drag(d: Project, s: Sequence, c: Clip, panel: Object, pic: Rect2, index: int, at: Vector2, fresh: bool) -> Dictionary:
	var e: Dictionary = Puppet.any_effect_of(c)
	var picked: PackedInt32Array = selected_pins(c)
	var group: PackedInt32Array = picked if picked.has(index) else PackedInt32Array([index])
	var made: Dictionary = _bent(d, s, c, e)
	var bus: Object = panel.call("bus")
	var key_at: float = float(bus.call("key_time_for", c, path_of(e, Puppet.KEY_PINS), s.playhead)) if bus != null and not fresh else -1.0
	var out: Dictionary = {"clip_id": c.id, "kind": "pin", "pin": index, "group": group, "key_at": key_at, "from_layer": screen_to_layer(panel, pic, c, at), "keyed": Puppet.keyed_pins_at(c, e, s.playhead, s.fps), "shown": (made["pins"] as PackedVector2Array).duplicate(), "rest": Puppet.rest_of(e)}
	if fresh:
		out["fresh"] = true
	return out


static func _add_and_grab(d: Project, s: Sequence, c: Clip, panel: Object, pic: Rect2, q: Vector2, at: Vector2) -> void:
	var made: int = add_pin(d, s, c, q)
	select(c.id, PackedInt32Array([made]), PackedInt32Array())
	s.selected_clip_ids = PackedStringArray([c.id])
	_drag = _group_drag(d, s, c, panel, pic, made, at, true)


static func _release(d: Project, s: Sequence, panel: Object, pic: Rect2, at: Vector2) -> void:
	if _drag.is_empty():
		return
	var was: Dictionary = _drag
	_drag = {}
	var kind: String = String(was.get("kind", "pin"))
	if kind == "record":
		PuppetRecord.end()
		return
	if kind == "link":
		var c: Clip = s.clip_by_id(String(was["clip_id"]))
		if c == null:
			return
		var other: int = _pin_near(panel, pic, c, at)
		if other < 0 or other == int(was["pin"]):
			return
		var why: String = link_pins(d, s, c, int(was["pin"]), other)
		if not why.is_empty():
			Events.toast(why)
		else:
			select(c.id, PackedInt32Array([other]), PackedInt32Array())
		return
	if kind == "marquee":
		var mc: Clip = s.clip_by_id(String(was["clip_id"]))
		if mc == null:
			return
		var from: Vector2 = was["from"]
		if from.distance_to(at) < MARQUEE_LEAST:
			_add_and_grab(d, s, mc, panel, pic, to_layer(s, mc, Vector2(was["at_seq"])), at)
			_drag = {}
			return
		var box: Rect2 = Rect2(from, Vector2.ZERO).expand(at)
		var me: Dictionary = Puppet.any_effect_of(mc)
		var made: Dictionary = _bent(d, s, mc, me)
		var xf: Transform2D = layer_xf(panel, pic, mc)
		var picked: PackedInt32Array = selected_pins(mc)
		var shown: PackedVector2Array = made["pins"]
		for i: int in shown.size():
			if box.has_point(xf * shown[i]) and not picked.has(i):
				picked.append(i)
		select(mc.id, picked, selected_holds(mc), selected_overs(mc))
		return
	if kind == "hold":
		d.undo.commit_live("Move hold pin")
	elif kind == "ring":
		d.undo.commit_live("Change hold radius")
	elif kind == "over":
		d.undo.commit_live("Move overlap pin")
	elif kind == "over_ring":
		d.undo.commit_live("Change overlap extent")
	elif kind == "turn":
		d.undo.commit_live("Turn puppet pin")
	elif kind == "scale":
		d.undo.commit_live("Scale puppet pin")
	else:
		var group: PackedInt32Array = was.get("group", PackedInt32Array())
		d.undo.commit_live("Move puppet pin" if group.size() <= 1 else "Move puppet pins")



static func key_input(e: InputEventKey, panel: Object) -> bool:
	if not tool_on() or not e.pressed:
		return false
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null or d == null:
		return false
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	if mode == MODE_LOCKS:
		if e.keycode == KEY_BRACKETLEFT or e.keycode == KEY_BRACKETRIGHT:
			PuppetLockUi.grow_brush(e.keycode == KEY_BRACKETRIGHT)
			_redraw(panel)
			return true
		if e.echo:
			return false
		if e.keycode == KEY_ESCAPE:
			if PuppetLockUi.sel_areas.is_empty():
				set_mode(MODE_PINS)
			PuppetLockUi.sel_areas = PackedInt32Array()
			_redraw(panel)
			return true
		var lc: Clip = panel.call("gizmo_clip")
		if (e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE) and lc != null and not PuppetLockUi.sel_areas.is_empty():
			var gone: PackedInt32Array = PuppetLockUi.sel_areas.duplicate()
			gone.sort()
			for i: int in range(gone.size() - 1, -1, -1):
				PuppetLockUi.drop_area(d, s, lc, gone[i])
			_redraw(panel)
			return true
		return false
	var c: Clip = s.clip_by_id(sel_clip)
	if c == null:
		var gc: Clip = panel.call("gizmo_clip")
		if gc != null and ctrl and e.keycode == KEY_A and not Puppet.any_effect_of(gc).is_empty():
			select_all(gc)
			_redraw(panel)
			return true
		return false
	var arrows: Dictionary = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
	if arrows.has(e.keycode) and not selected_pins(c).is_empty() and not ctrl and not e.alt_pressed:
		nudge(d, s, c, panel, Vector2(arrows[e.keycode]) * (NUDGE_BIG if e.shift_pressed else NUDGE))
		_redraw(panel)
		return true
	if e.echo:
		return false
	if ctrl and e.keycode == KEY_A and not Puppet.any_effect_of(c).is_empty():
		select_all(c)
		_redraw(panel)
		return true
	if e.keycode == KEY_ESCAPE and (not selected_pins(c).is_empty() or not selected_holds(c).is_empty() or not selected_overs(c).is_empty()):
		clear_selection()
		_redraw(panel)
		return true
	if e.keycode != KEY_DELETE and e.keycode != KEY_BACKSPACE:
		return false
	var pins: PackedInt32Array = selected_pins(c)
	var holds: PackedInt32Array = selected_holds(c)
	var overs: PackedInt32Array = selected_overs(c)
	if pins.is_empty() and holds.is_empty() and overs.is_empty():
		return false
	drop_many(d, s, c, pins, holds, overs)
	_redraw(panel)
	return true


static func mesh_edges(mesh: Dictionary) -> PackedInt32Array:
	var key: String = String(mesh.get("key", ""))
	if key == _edges_key and not _edges.is_empty():
		return _edges
	var tris: PackedInt32Array = mesh["tris"]
	var n: int = (mesh["verts"] as PackedVector2Array).size()
	var seen: Dictionary = {}
	var out: PackedInt32Array = PackedInt32Array()
	for t: int in tris.size() / 3:
		for k: int in 3:
			var a: int = tris[t * 3 + k]
			var b: int = tris[t * 3 + (k + 1) % 3]
			var ek: int = mini(a, b) * n + maxi(a, b)
			if seen.has(ek):
				continue
			seen[ek] = true
			out.append(a)
			out.append(b)
	_edges_key = key
	_edges = out
	return out


static func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null or pic.size.x <= 0.0:
		return
	var c: Clip = panel.call("gizmo_clip")
	if c == null:
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty() or not tool_on():
		return
	var t0: int = Time.get_ticks_usec()
	var made: Dictionary = _bent(d, s, c, e)
	var xf: Transform2D = layer_xf(panel, pic, c)
	var verts: PackedVector2Array = made["verts"]
	var screen: PackedVector2Array = xf * verts
	var locks_mode: bool = mode == MODE_LOCKS
	if locks_mode or show_locks:
		PuppetLockUi.draw_overlay(ci, c, e, made, screen)
	if show_mesh or locks_mode:
		var edges: PackedInt32Array = mesh_edges(made["mesh"])
		var lines: PackedVector2Array = PackedVector2Array()
		lines.resize(edges.size())
		for i: int in edges.size():
			lines[i] = screen[edges[i]]
		if not lines.is_empty():
			ci.draw_multiline(lines, MESH_INK, 1.0)
	if locks_mode or PuppetLocks.area_count(e) > 0:
		PuppetLockUi.draw_marks(ci, panel, pic, d, s, c, e, xf, locks_mode)
	var pins: PackedVector2Array = made["pins"]
	var pin_px: PackedVector2Array = xf * pins
	_draw_links(ci, e, Puppet.strengths_at(c, e, s.playhead, s.fps), pin_px)
	_draw_holds(ci, panel, pic, d, s, c, e)
	if Puppet.overlap_count(e) > 0:
		PuppetOverlapUi.draw_outline(ci, xf, made["mesh"])
	_draw_overs(ci, panel, pic, d, s, c, e)
	var active: int = int(_drag.get("pin", -1)) if String(_drag.get("clip_id", "")) == c.id and String(_drag.get("kind", "pin")) in ["pin", "record", "turn", "scale"] else -1
	var picked: PackedInt32Array = selected_pins(c)
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var turns: PackedVector2Array = Puppet.turns_at(c, e, s.playhead, s.fps) if Puppet.any_bend(e) else PackedVector2Array()
	for j: int in pin_px.size():
		var p2: Vector2 = pin_px[j]
		var kd: int = kinds[j] if j < kinds.size() else Puppet.KIND_POSITION
		var ink: Color = PIN_ACTIVE if j == active else (PIN_INK if kd == Puppet.KIND_POSITION else (BEND_INK if kd == Puppet.KIND_BEND else ADV_INK))
		if kd == Puppet.KIND_BEND:
			ci.draw_circle(p2, PIN_RADIUS + 1.5, PIN_RIM)
			ci.draw_arc(p2, PIN_RADIUS - 0.5, 0.0, TAU, 16, ink, 2.5, true)
		else:
			ci.draw_circle(p2, PIN_RADIUS + 1.5, PIN_RIM)
			ci.draw_circle(p2, PIN_RADIUS, ink)
		if kd != Puppet.KIND_POSITION and j < turns.size():
			var g: Dictionary = gizmo_shape(xf, p2, shown_turn(made, j, turns[j]))
			var dir: Vector2 = g["dir"]
			ci.draw_line(p2, p2 + dir * (PIN_RADIUS + 5.0), PIN_RIM, 3.0, true)
			ci.draw_line(p2, p2 + dir * (PIN_RADIUS + 4.0), ink, 1.5, true)
			if picked.has(j):
				_draw_gizmo(ci, p2, g, ink)
		if picked.has(j):
			ci.draw_arc(p2, PIN_RADIUS + 3.0, 0.0, TAU, 20, PICK_INK, 1.5, true)
	if String(_drag.get("kind", "")) == "link" and String(_drag.get("clip_id", "")) == c.id:
		var from: int = int(_drag["pin"])
		if from >= 0 and from < pin_px.size():
			var to: Vector2 = _drag.get("to", pin_px[from])
			ci.draw_dashed_line(pin_px[from] + Vector2.ONE, to + Vector2.ONE, LINK_SHADOW, 2.0, DASH)
			ci.draw_dashed_line(pin_px[from], to, LINK_INK, 2.0, DASH)
	if String(_drag.get("kind", "")) == "marquee" and String(_drag.get("clip_id", "")) == c.id:
		var box: Rect2 = Rect2(Vector2(_drag["from"]), Vector2.ZERO).expand(Vector2(_drag["to"]))
		ci.draw_rect(box, MARQUEE_FILL, true)
		ci.draw_rect(box, MARQUEE_INK, false, 1.0)
	if PuppetRecord.active() and PuppetRecord.clip_id() == c.id:
		var rp: int = PuppetRecord.pin()
		if rp >= 0 and rp < pin_px.size():
			ci.draw_arc(pin_px[rp], PIN_RADIUS + 7.0, 0.0, TAU, 24, RECORD_INK, 2.0, true)
	draw_ms = float(Time.get_ticks_usec() - t0) / 1000.0


static func _draw_gizmo(ci: CanvasItem, centre: Vector2, g: Dictionary, ink: Color) -> void:
	ci.draw_arc(centre, TURN_RING, 0.0, TAU, 48, LINK_SHADOW, 3.0, true)
	ci.draw_arc(centre, TURN_RING, 0.0, TAU, 48, GIZMO_INK, 1.5, true)
	var handle: Vector2 = g["handle"]
	ci.draw_line(centre, handle, LINK_SHADOW, 3.0, true)
	ci.draw_line(centre, handle, Color(ink, 0.9), 1.5, true)
	var h: float = SCALE_HALF
	ci.draw_rect(Rect2(handle - Vector2(h + 1.5, h + 1.5), Vector2(h + 1.5, h + 1.5) * 2.0), PIN_RIM)
	ci.draw_rect(Rect2(handle - Vector2(h, h), Vector2(h, h) * 2.0), ink)


static func redraw_program() -> void:
	var bus_script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var bus: Object = bus_script.call("instance") if bus_script != null else null
	var pp: Object = bus.call("panel", "program") if bus != null else null
	if pp != null:
		_redraw(pp)


static func _redraw(panel: Object) -> void:
	var v: Variant = panel.get("view")
	if v is Control:
		(v as Control).call("redraw_overlay")


static func _draw_links(ci: CanvasItem, e: Dictionary, strengths: PackedFloat64Array, pin_px: PackedVector2Array) -> void:
	var links: PackedInt32Array = Puppet.links_of(e)
	for k: int in links.size() / 2:
		var a: int = links[k * 2]
		var b: int = links[k * 2 + 1]
		if a < 0 or b < 0 or a >= pin_px.size() or b >= pin_px.size():
			continue
		var pa: Vector2 = pin_px[a]
		var pb: Vector2 = pin_px[b]
		ci.draw_line(pa + Vector2.ONE, pb + Vector2.ONE, LINK_SHADOW, 3.0, true)
		ci.draw_line(pa, pb, LINK_INK, 2.0, true)
		var sab: float = strengths[k * 2] if k * 2 < strengths.size() else 0.5
		var sba: float = strengths[k * 2 + 1] if k * 2 + 1 < strengths.size() else 0.5
		_arrow(ci, pa, pb, sab)
		_arrow(ci, pb, pa, sba)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, strength: float) -> void:
	var span: float = from.distance_to(to)
	if span < PIN_RADIUS * 4.0 or strength <= 0.001:
		return
	var dir: Vector2 = (to - from) / span
	var tip: Vector2 = to - dir * (PIN_RADIUS + 3.0)
	var size: float = ARROW * clampf(0.35 + strength * 0.65, 0.35, 1.0)
	var side: Vector2 = Vector2(-dir.y, dir.x) * size * 0.5
	var back: Vector2 = tip - dir * size
	ci.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), LINK_INK)


static func _draw_holds(ci: CanvasItem, panel: Object, pic: Rect2, d: Project, s: Sequence, c: Clip, e: Dictionary) -> void:
	var spots: PackedVector2Array = hold_spots(d, s, c, e)
	if spots.is_empty():
		return
	var holds: Dictionary = Puppet.holds_at(c, e, s.playhead, s.fps)
	var radii: PackedFloat64Array = holds["r"]
	var picked: PackedInt32Array = selected_holds(c)
	for j: int in spots.size():
		var p: Vector2 = _pin_screen(panel, pic, c, spots[j])
		if picked.has(j) and j < radii.size():
			var rp: float = ring_px(panel, pic, c, spots[j], radii[j])
			ci.draw_arc(p, rp, 0.0, TAU, 64, LINK_SHADOW, 3.0, true)
			ci.draw_arc(p, rp, 0.0, TAU, 64, RING_INK, 1.5, true)
		var h: float = HOLD_HALF
		var rim: PackedVector2Array = PackedVector2Array([p + Vector2(0.0, -h - 1.5), p + Vector2(h + 1.5, 0.0), p + Vector2(0.0, h + 1.5), p + Vector2(-h - 1.5, 0.0)])
		var body: PackedVector2Array = PackedVector2Array([p + Vector2(0.0, -h), p + Vector2(h, 0.0), p + Vector2(0.0, h), p + Vector2(-h, 0.0)])
		ci.draw_colored_polygon(rim, PIN_RIM)
		ci.draw_colored_polygon(body, HOLD_INK)
		if picked.has(j):
			ci.draw_polyline(PackedVector2Array([rim[0], rim[1], rim[2], rim[3], rim[0]]), PICK_INK, 1.5, true)


static func _draw_overs(ci: CanvasItem, panel: Object, pic: Rect2, d: Project, s: Sequence, c: Clip, e: Dictionary) -> void:
	var spots: PackedVector2Array = over_spots(d, s, c, e)
	if spots.is_empty():
		return
	var overs: Dictionary = Puppet.overlaps_at(c, e, s.playhead, s.fps)
	var extents: PackedFloat64Array = overs["x"]
	var fronts: PackedFloat64Array = overs["f"]
	var picked: PackedInt32Array = selected_overs(c)
	for j: int in spots.size():
		var p: Vector2 = _pin_screen(panel, pic, c, spots[j])
		if picked.has(j) and j < extents.size():
			var rp: float = ring_px(panel, pic, c, spots[j], extents[j])
			ci.draw_arc(p, rp, 0.0, TAU, 64, LINK_SHADOW, 3.0, true)
			ci.draw_arc(p, rp, 0.0, TAU, 64, OVER_RING, 1.5, true)
		var h: float = OVER_HALF
		ci.draw_rect(Rect2(p - Vector2(h + 1.5, h + 1.5), Vector2(h + 1.5, h + 1.5) * 2.0), PIN_RIM)
		ci.draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), OVER_INK)
		var front: float = fronts[j] if j < fronts.size() else 0.0
		var bar: float = h * 0.7
		ci.draw_line(p - Vector2(bar, 0.0), p + Vector2(bar, 0.0), PIN_RIM, 1.5)
		if front >= 0.0:
			ci.draw_line(p - Vector2(0.0, bar), p + Vector2(0.0, bar), PIN_RIM, 1.5)
		if picked.has(j):
			ci.draw_rect(Rect2(p - Vector2(h + 3.0, h + 3.0), Vector2(h + 3.0, h + 3.0) * 2.0), PICK_INK, false, 1.5)


static func key(c: Clip, e: Dictionary) -> String:
	if not Puppet.is_puppet(e):
		return ""
	var params: Dictionary = e.get("params", {})
	var animated: PackedStringArray = PackedStringArray()
	for pk: Variant in params.keys():
		if AnimProp.is_animated(params[pk]):
			animated.append(String(pk))
	animated.sort()
	var info: Dictionary = Puppet.mesh_info(e)
	var mesh_sig: String = str(hash(Puppet.shape_code(info))) + "@" + str(info.get("from", "")) + String(info.get("alpha", ""))
	var tool_sig: String = mode + str(new_kind) + str(show_mesh) + str(show_locks) + str(PuppetRecord.on) + str(selected_pins(c)) + str(Puppet.kinds_of(e)) + str(PuppetLocks.area_count(e)) + str(not PuppetLocks.info_of(e).is_empty()) + "#" + str(_poke_gen)
	return str(Puppet.rest_of(e).size()) + ":" + str(Puppet.hold_count(e)) + ":" + str(Puppet.overlap_count(e)) + ":" + str(Puppet.links_of(e)) + ":" + ",".join(animated) + ":" + str(tool_on()) + ":" + mesh_sig + ":" + tool_sig


static func _toggle(text: String, icon: String, on: bool, tip: String, cb: Callable) -> Button:
	var b: Button = PmButton.make(text, icon, true)
	b.set("quiet", true)
	b.button_pressed = on
	PmUI.tip(b, tip)
	b.toggled.connect(cb)
	return b


static func _button(text: String, icon: String, tip: String, cb: Callable) -> Button:
	var b: Button = PmButton.make(text, icon)
	b.set("quiet", true)
	PmUI.tip(b, tip)
	b.pressed.connect(cb)
	return b


static func _line(lead: float, label_w: float, title: String) -> HBoxContainer:
	var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line.add_child(_gap(lead))
	var label: Label = PmLabel.trim(title)
	label.custom_minimum_size = Vector2(label_w, 0.0)
	line.add_child(label)
	return line


static func _tool_field(v: float, lo: float, hi: float, step: float, suffix: String, tip: String, cb: Callable) -> Control:
	var f: Control = PmField.make(v, lo, hi, step, suffix)
	f.custom_minimum_size = Vector2(float(Tk.px(58.0)), 0.0)
	PmUI.tip(f, tip)
	f.connect("value_changed", cb)
	return f


static func _extra_rows(box: VBoxContainer, c: Clip, e: Dictionary, lead: float, label_w: float, fields: Array[Control]) -> void:
	var modes: HBoxContainer = _line(lead, label_w, "Tool")
	modes.add_child(_toggle("Pins", "pin", mode == MODE_PINS, "Place, pick and drag pins", _script()._on_mode.bind(MODE_PINS)))
	modes.add_child(_toggle("Lock brush", "lock", mode == MODE_LOCKS, LOCK_TIP, _script()._on_mode.bind(MODE_LOCKS)))
	modes.add_child(_toggle("Show mesh", "grid", show_mesh, "Show the triangles of the mesh on the Program monitor while the Puppet tool is on", _script()._on_show_mesh))
	modes.add_child(_toggle("Show locks", "eye", show_locks, "Show the locked parts as a coloured overlay on the mesh: red is locked still, amber is stiff but free to move", _script()._on_show_locks))
	box.add_child(modes)
	var kinds_line: HBoxContainer = _line(lead, label_w, "New pins")
	var picked: PackedInt32Array = selected_pins(c)
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var tips: PackedStringArray = ["Position pin: the picture under it goes where you drag it", "Bend pin: turns and scales the picture round it without pinning where it is. Drag its ring to turn, its square to scale", "Advanced pin: position, turn and scale in one pin"]
	for kd: int in 3:
		var on: bool = new_kind == kd
		if not picked.is_empty():
			on = true
			for i: int in picked:
				if i >= kinds.size() or kinds[i] != kd:
					on = false
		kinds_line.add_child(_toggle(Puppet.KIND_NAMES[kd], "pin", on, tips[kd] + (". Applies to the picked pins too" if not picked.is_empty() else ""), _script()._on_kind.bind(c.id, kd)))
	box.add_child(kinds_line)
	var rec: HBoxContainer = _line(lead, label_w, "Record")
	rec.add_child(_toggle("Record pins", "stopwatch", PuppetRecord.on, "When on, dragging a pin plays the clip and records its path as you move it, a key every frame, thinned where the path is straight. Release to stop", _script()._on_record))
	rec.add_child(PmLabel.dim("speed"))
	rec.add_child(_tool_field(PuppetRecord.speed, PuppetRecord.SPEED_MIN, PuppetRecord.SPEED_MAX, 5.0, " %", "Playback speed while recording: below 100 gives you more time for a fast move", _script()._on_record_speed))
	rec.add_child(PmLabel.dim("smooth"))
	rec.add_child(_tool_field(PuppetRecord.smoothing, 0.0, PuppetRecord.SMOOTH_MAX, 1.0, " %", "Smoothing: evens out the shake in a recorded path when you let go. 0 keeps every wobble, 100 gives a calm, flowing path", _script()._on_record_smooth))
	var layouts: Button = _button("Pin layouts", "list", "Put a ready made pin layout on this picture, or save this layout to use on another", _script()._on_layouts.bind(c.id))
	layouts.name = "PinLayouts"
	rec.add_child(layouts)
	box.add_child(rec)
	if picked.size() == 1 and picked[0] < kinds.size() and kinds[picked[0]] != Puppet.KIND_POSITION:
		var i0: int = picked[0]
		var s: Sequence = Session.seq()
		var turn: Vector2 = Puppet.turns_at(c, e, s.playhead if s != null else c.start, s.fps if s != null else 30.0)[i0]
		var pin_line: HBoxContainer = _line(lead, label_w, "Pin " + str(i0 + 1))
		var animated: bool = AnimProp.is_animated((e.get("params", {}) as Dictionary).get(Puppet.KEY_TURNS, {}))
		pin_line.add_child(_toggle("", "stopwatch", animated, "Animate the turn and scale of every bend and advanced pin, one row on the timeline", _script()._on_animate_turns.bind(c.id)))
		var rf: Control = _tool_field(turn.x, -100000.0, 100000.0, 1.0, " deg", "How far this pin turns the picture round it", _script()._on_turn_field.bind(c.id, i0, 0))
		rf.set_meta("puppet_turn", Vector2i(i0, 0))
		pin_line.add_child(rf)
		var sf: Control = _tool_field(turn.y, Puppet.SCALE_MIN, Puppet.SCALE_MAX, 1.0, " %", "How much this pin scales the picture round it", _script()._on_turn_field.bind(c.id, i0, 1))
		sf.set_meta("puppet_turn", Vector2i(i0, 1))
		pin_line.add_child(sf)
		rf.connect("edit_ended", _script()._on_turn_done)
		sf.connect("edit_ended", _script()._on_turn_done)
		fields.append(rf)
		fields.append(sf)
		box.add_child(pin_line)
	var brush: HBoxContainer = _line(lead, label_w, "Lock brush")
	brush.add_child(PmLabel.dim("size"))
	brush.add_child(_tool_field(PuppetLockUi.brush_px, PuppetLockUi.BRUSH_MIN, PuppetLockUi.BRUSH_MAX, 1.0, " px", "Brush size on the screen. [ and ] change it", _script()._on_brush.bind(0)))
	brush.add_child(PmLabel.dim("strength"))
	brush.add_child(_tool_field(PuppetLockUi.strength, 0.0, 100.0, 1.0, " %", "Lock strength: 100 holds the painted part still, lower keeps it stiff but lets it follow the pins", _script()._on_brush.bind(1)))
	brush.add_child(PmLabel.dim("soft"))
	brush.add_child(_tool_field(PuppetLockUi.softness, 0.0, 100.0, 1.0, " %", "Softness: how gently the lock fades out at the edge of the brush", _script()._on_brush.bind(2)))
	brush.add_child(_button("Clear locks", "close", "Remove everything painted with the lock brush on this clip", _script()._on_clear_locks.bind(c.id)))
	box.add_child(brush)
	var av: Dictionary = PuppetLocks.area_values(e)
	for a: int in (av["at"] as PackedVector2Array).size():
		var row: HBoxContainer = _line(lead, label_w, "Lock area " + str(a + 1))
		row.add_child(_value_field(c, e, PuppetLocks.area_key(a, "r"), PuppetLocks.AREA_RADIUS_DEFAULT, 0.0, 100000.0, 1.0, " px", "Size of the lock area, in layer pixels", fields))
		row.add_child(_value_field(c, e, PuppetLocks.area_key(a, "s"), PuppetLocks.AREA_STRENGTH_DEFAULT, 0.0, 100.0, 1.0, " %", "Lock strength: 100 holds it still, lower keeps it stiff but free to move", fields))
		row.add_child(_value_field(c, e, PuppetLocks.area_key(a, "f"), PuppetLocks.AREA_SOFT_DEFAULT, 0.0, 100.0, 1.0, " %", "Softness of its edge", fields))
		row.add_child(_button("", "close", "Remove this lock area", _script()._on_drop_area.bind(c.id, a)))
		box.add_child(row)


static func _on_mode(on: bool, m: String) -> void:
	if on:
		set_mode(m)
	elif m == MODE_LOCKS:
		set_mode(MODE_PINS)


static func _on_show_mesh(on: bool) -> void:
	show_mesh = on
	redraw_program()
	poke_controls()


static func _on_show_locks(on: bool) -> void:
	show_locks = on
	redraw_program()
	poke_controls()


static func _on_kind(on: bool, clip_id: String, kd: int) -> void:
	if not on:
		poke_controls()
		return
	new_kind = kd
	poke_controls()
	var c: Clip = _clip_now(clip_id)
	if c != null and not selected_pins(c).is_empty():
		set_kind(Session.doc, Session.seq(), c, selected_pins(c), kd)


static func _on_record(on: bool) -> void:
	PuppetRecord.on = on
	poke_controls()
	if on and not tool_on():
		use_tool()


static func _on_record_speed(v: float) -> void:
	PuppetRecord.speed = v


static func _on_record_smooth(v: float) -> void:
	PuppetRecord.smoothing = v


static func _on_brush(v: float, which: int) -> void:
	if which == 0:
		PuppetLockUi.brush_px = v
	elif which == 1:
		PuppetLockUi.strength = v
	else:
		PuppetLockUi.softness = v


static func _on_clear_locks(clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		PuppetLockUi.clear_map(Session.doc, Session.seq(), c)


static func _on_drop_area(clip_id: String, a: int) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		PuppetLockUi.drop_area(Session.doc, Session.seq(), c, a)


static func _on_animate_turns(on: bool, clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	var s: Sequence = Session.seq()
	if c == null or s == null:
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var value: Array = Puppet.flat(Puppet.turns_at(c, e, s.playhead, s.fps))
	var next: Dictionary = AnimProp.set_key(AnimProp.make(value), Puppet.key_time(c, e, Puppet.KEY_TURNS, s.playhead), value) if on else AnimProp.make(value)
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path_of(e, Puppet.KEY_TURNS), next)]
	_run(Session.doc, "Animate pin turns" if on else "Stop animating pin turns", cmds)


static func _on_turn_field(v: float, clip_id: String, index: int, part: int) -> void:
	var c: Clip = _clip_now(clip_id)
	var s: Sequence = Session.seq()
	if c == null or s == null:
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	var turn: Vector2 = Puppet.turns_at(c, e, s.playhead, s.fps)[index]
	if part == 0:
		turn.x = v
	else:
		turn.y = v
	turns_live(Session.doc, s, c, index, turn, -1.0)


static func _on_turn_done() -> void:
	if Session.doc != null:
		Session.doc.undo.commit_live("Change pin turn")


static func _on_layouts(clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c == null:
		return
	var items: Array = []
	var all: Array = PuppetPresets.layouts()
	for i: int in all.size():
		items.append(PmMenu.item("layout_" + str(i), String((all[i] as Dictionary).get("name", "Layout"))))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("save", "Save this layout"))
	var anchor: Control = null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var found: Array[Node] = tree.root.find_children("PinLayouts", "Button", true, false)
		anchor = found[0] as Control if not found.is_empty() else null
	if anchor == null:
		return
	var m: Control = PmMenu.open(anchor, items)
	m.connect("picked", _script()._on_layout_picked.bind(clip_id))


static func _on_layout_picked(id: String, clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	var s: Sequence = Session.seq()
	if c == null or s == null:
		return
	if id == "save":
		var e: Dictionary = Puppet.any_effect_of(c)
		if e.is_empty():
			Events.toast("Put some pins on first, then save the layout")
			return
		var name: String = PuppetPresets.next_name()
		if PuppetPresets.save_layout(e, Puppet.size_of(e, layer_size(Session.doc, s, c)), name):
			Events.toast("Saved the pin layout as " + name)
		return
	var all: Array = PuppetPresets.layouts()
	var i: int = int(id.trim_prefix("layout_"))
	if i >= 0 and i < all.size():
		var n: int = PuppetPresets.apply(Session.doc, s, c, all[i])
		if n == 0:
			Events.toast("None of that layout lands on the picture")


static func _gap(w: float) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(w, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


static func rows(c: Clip, e: Dictionary, label_w: float) -> Control:
	var box: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	var lead: float = float(Tk.px(Tk.sz("button_h")))
	var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line.add_child(_gap(lead))
	var n: int = Puppet.rest_of(e).size()
	var nh: int = Puppet.hold_count(e)
	var no: int = Puppet.overlap_count(e)
	var label: Label = PmLabel.trim("Pins")
	label.custom_minimum_size = Vector2(label_w, 0.0)
	line.add_child(label)
	var count: String = str(n) + (" pin" if n == 1 else " pins")
	line.add_child(PmLabel.dim(count))
	if nh > 0:
		line.add_child(PmLabel.dim(str(nh) + (" hold" if nh == 1 else " holds")))
	if no > 0:
		line.add_child(PmLabel.dim(str(no) + (" overlap" if no == 1 else " overlaps")))
	var tool: Button = PmButton.make("Puppet tool", "pin", true)
	tool.set("quiet", true)
	tool.button_pressed = tool_on()
	PmUI.tip(tool, TOOL_TIP)
	tool.pressed.connect(_script().toggle_tool)
	line.add_child(tool)
	box.add_child(line)
	var line2: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line2.add_child(_gap(lead + label_w + float(Tk.px(4.0))))
	var animated: bool = AnimProp.is_animated((e.get("params", {}) as Dictionary).get(Puppet.KEY_PINS, {}))
	var anim: Button = PmButton.make("Animate pins", "stopwatch", true)
	anim.set("quiet", true)
	anim.button_pressed = animated
	PmUI.tip(anim, "When on, dragging a pin writes a key at the playhead")
	anim.toggled.connect(_script()._on_animate.bind(c.id))
	line2.add_child(anim)
	var reset: Button = PmButton.make("Reset pins", "undo")
	reset.set("quiet", true)
	PmUI.tip(reset, "Put every pin back where it was placed, so the picture is unbent")
	reset.pressed.connect(_script()._on_reset.bind(c.id))
	line2.add_child(reset)
	var link: Button = PmButton.make("Link pins", "chain")
	link.set("quiet", true)
	PmUI.tip(link, "Link the two picked pins so moving one pulls the other. Pick them with the Puppet tool: click one, Shift click the other. Or Ctrl drag from one pin to the other")
	link.pressed.connect(_script()._on_link.bind(c.id))
	line2.add_child(link)
	box.add_child(line2)
	var fields: Array[Control] = []
	_extra_rows(box, c, e, lead, label_w, fields)
	var line3: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line3.add_child(_gap(lead + label_w + float(Tk.px(4.0))))
	var seq_now: Sequence = Session.seq()
	line3.add_child(PmLabel.dim(PuppetShape.describe(Puppet.mesh_info(e), seq_now.fps if seq_now != null else 30.0)))
	var rebuild: Button = PmButton.make("Rebuild mesh from this frame", "loop")
	rebuild.set("quiet", true)
	PmUI.tip(rebuild, "Make the mesh follow the outline of the picture at the playhead: its own see through parts, keys and masks. Use it on video, where the outline changes")
	rebuild.pressed.connect(_script()._on_rebuild.bind(c.id))
	line3.add_child(rebuild)
	var med: MediaItem = Session.doc.media_by_id(c.media_id) if Session.doc != null else null
	if not PuppetShape.follows_file(med):
		var follow: Button = PmButton.make("Follow the video", "film")
		follow.set("quiet", true)
		PmUI.tip(follow, "Read the outline of the picture on every frame of the clip, so the mesh changes shape with the video. It steps through the clip once on the Program monitor")
		follow.pressed.connect(_script()._on_follow.bind(c.id))
		line3.add_child(follow)
	box.add_child(line3)
	load("res://modules/core_panels/puppet_pin_rows.gd").call("add", box, c, e, lead, label_w)
	for j: int in nh:
		box.add_child(_hold_row(c, e, j, lead, label_w, fields))
	for o: int in no:
		box.add_child(_over_row(c, e, o, lead, label_w, fields))
	var links: PackedInt32Array = Puppet.links_of(e)
	for k: int in links.size() / 2:
		box.add_child(_link_row(c, e, k, links[k * 2], links[k * 2 + 1], lead, label_w, fields))
	if not fields.is_empty():
		var timer: Timer = Timer.new()
		timer.wait_time = SYNC_SECONDS
		timer.autostart = true
		timer.timeout.connect(_script().sync_fields.bind(c.id, fields))
		box.add_child(timer)
	return box


static func _value_field(c: Clip, e: Dictionary, key: String, fallback: float, lo: float, hi: float, step: float, suffix: String, tip: String, fields: Array[Control]) -> Control:
	var s: Sequence = Session.seq()
	var t: float = s.playhead if s != null else c.start
	var fps: float = s.fps if s != null else 30.0
	var f: Control = PmField.make(Puppet.value_at(c, e, key, t, fps, fallback), lo, hi, step, suffix)
	f.custom_minimum_size = Vector2(float(Tk.px(64.0)), 0.0)
	f.set_meta("puppet_key", key)
	f.set_meta("puppet_fallback", fallback)
	PmUI.tip(f, tip)
	f.connect("value_changed", _script()._on_field.bind(c.id, key))
	f.connect("edit_ended", _script()._on_field_done.bind(key))
	fields.append(f)
	return f


static func _watch(c: Clip, e: Dictionary, key: String, fallback: float) -> Button:
	var on: bool = AnimProp.is_animated((e.get("params", {}) as Dictionary).get(key, {}))
	var b: Button = PmButton.make("", "stopwatch", true)
	b.set("quiet", true)
	b.button_pressed = on
	PmUI.tip(b, "Animate this value: each change writes a key at the playhead")
	b.toggled.connect(_script()._on_watch.bind(c.id, key, fallback))
	return b


static func _hold_row(c: Clip, e: Dictionary, j: int, lead: float, label_w: float, fields: Array[Control]) -> Control:
	var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line.add_child(_gap(lead))
	var label: Label = PmLabel.trim("Hold " + str(j + 1))
	label.custom_minimum_size = Vector2(label_w, 0.0)
	line.add_child(label)
	var rk: String = Puppet.hold_key(j, "r")
	var ak: String = Puppet.hold_key(j, "a")
	line.add_child(_watch(c, e, rk, Puppet.HOLD_RADIUS_DEFAULT))
	line.add_child(_value_field(c, e, rk, Puppet.HOLD_RADIUS_DEFAULT, 0.0, 100000.0, 1.0, " px", "How far round the hold pin the picture is held, in layer pixels", fields))
	line.add_child(_watch(c, e, ak, Puppet.HOLD_AMOUNT_DEFAULT))
	line.add_child(_value_field(c, e, ak, Puppet.HOLD_AMOUNT_DEFAULT, 0.0, 100.0, 1.0, " %", "How firmly the hold keeps that part in place and in shape", fields))
	var drop: Button = PmButton.make("", "close")
	drop.set("quiet", true)
	PmUI.tip(drop, "Remove this hold pin")
	drop.pressed.connect(_script()._on_drop_hold.bind(c.id, j))
	line.add_child(drop)
	return line


static func _over_row(c: Clip, e: Dictionary, j: int, lead: float, label_w: float, fields: Array[Control]) -> Control:
	var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line.add_child(_gap(lead))
	var label: Label = PmLabel.trim("Overlap " + str(j + 1))
	label.custom_minimum_size = Vector2(label_w, 0.0)
	line.add_child(label)
	var fk: String = Puppet.over_key(j, "f")
	var xk: String = Puppet.over_key(j, "x")
	line.add_child(_watch(c, e, fk, Puppet.OVER_FRONT_DEFAULT))
	line.add_child(_value_field(c, e, fk, Puppet.OVER_FRONT_DEFAULT, -Puppet.OVER_FRONT_MAX, Puppet.OVER_FRONT_MAX, 1.0, " %", "In Front: where the bent picture crosses itself, the part round this pin draws in front of parts with a lower value, from minus 100 to 100. Parts no overlap pin reaches count as 0", fields))
	line.add_child(_watch(c, e, xk, Puppet.OVER_EXTENT_DEFAULT))
	line.add_child(_value_field(c, e, xk, Puppet.OVER_EXTENT_DEFAULT, 0.0, 100000.0, 1.0, " px", "Extent: how far round the overlap pin its In Front reaches, in layer pixels", fields))
	var drop: Button = PmButton.make("", "close")
	drop.set("quiet", true)
	PmUI.tip(drop, "Remove this overlap pin")
	drop.pressed.connect(_script()._on_drop_over.bind(c.id, j))
	line.add_child(drop)
	return line


static func _link_row(c: Clip, e: Dictionary, k: int, a: int, b: int, lead: float, label_w: float, fields: Array[Control]) -> Control:
	var box: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	line.add_child(_gap(lead))
	var label: Label = PmLabel.trim("Link " + str(k + 1))
	label.custom_minimum_size = Vector2(label_w, 0.0)
	line.add_child(label)
	line.add_child(PmLabel.dim("pin " + str(a + 1) + " and pin " + str(b + 1)))
	var drop: Button = PmButton.make("", "close")
	drop.set("quiet", true)
	PmUI.tip(drop, "Remove this link")
	drop.pressed.connect(_script()._on_unlink.bind(c.id, k))
	line.add_child(drop)
	box.add_child(line)
	for part: String in ["ab", "ba"]:
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.add_child(_gap(lead))
		var from: int = a if part == "ab" else b
		var to: int = b if part == "ab" else a
		var what: Label = PmLabel.trim("Pin " + str(from + 1) + " pulls pin " + str(to + 1), "text_faint")
		what.custom_minimum_size = Vector2(label_w, 0.0)
		row.add_child(what)
		var lk: String = Puppet.link_key(k, part)
		row.add_child(_watch(c, e, lk, Puppet.LINK_STRENGTH_DEFAULT))
		row.add_child(_value_field(c, e, lk, Puppet.LINK_STRENGTH_DEFAULT, 0.0, 100.0, 1.0, " %", "How much moving pin " + str(from + 1) + " moves pin " + str(to + 1), fields))
		box.add_child(row)
	return box


static func sync_fields(clip_id: String, fields: Array[Control]) -> void:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return
	var e: Dictionary = Puppet.any_effect_of(c)
	if e.is_empty():
		return
	for f: Control in fields:
		if not is_instance_valid(f) or bool(f.get("_dragging")) or bool(f.get("_pressed")) or f.get("_editor") != null:
			continue
		var v: float = 0.0
		if f.has_meta("puppet_turn"):
			var which: Vector2i = f.get_meta("puppet_turn")
			var turns: PackedVector2Array = Puppet.turns_at(c, e, s.playhead, s.fps)
			if which.x >= turns.size():
				continue
			v = turns[which.x].x if which.y == 0 else turns[which.x].y
		else:
			v = Puppet.value_at(c, e, String(f.get_meta("puppet_key", "")), s.playhead, s.fps, float(f.get_meta("puppet_fallback", 0.0)))
		if absf(float(f.get("value")) - v) > 0.0001:
			f.set("value", v)


static func _clip_now(clip_id: String) -> Clip:
	var s: Sequence = Session.seq()
	return s.clip_by_id(clip_id) if s != null else null


static func _on_field(v: float, clip_id: String, key: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		value_live(Session.doc, Session.seq(), c, key, v)


static func _on_field_done(key: String) -> void:
	if Session.doc != null:
		Session.doc.undo.commit_live("Change " + key_label(key))


static func _on_watch(on: bool, clip_id: String, key: String, fallback: float) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		set_key_animated(Session.doc, Session.seq(), c, key, on, fallback)


static func _on_drop_hold(clip_id: String, j: int) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		drop_hold(Session.doc, Session.seq(), c, j)


static func _on_drop_over(clip_id: String, j: int) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		drop_overlap(Session.doc, Session.seq(), c, j)


static func _on_rebuild(clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c == null:
		return
	var why: String = rebuild_mesh(Session.doc, Session.seq(), c)
	if not why.is_empty():
		Events.toast(why)


static func _on_follow(clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c == null:
		return
	Events.toast("Reading the outline on every frame of the clip")
	var why: String = await (load("res://modules/core_panels/puppet_follow.gd") as GDScript).call("bake", Session.doc, Session.seq(), c)
	Events.toast(why if not why.is_empty() else "The mesh now follows the video")


static func _on_unlink(clip_id: String, k: int) -> void:
	var c: Clip = _clip_now(clip_id)
	if c != null:
		unlink(Session.doc, Session.seq(), c, k)


static func _on_link(clip_id: String) -> void:
	var c: Clip = _clip_now(clip_id)
	if c == null:
		return
	var why: String = link_selected(Session.doc, Session.seq(), c)
	if not why.is_empty():
		Events.toast(why)


static func _on_animate(on: bool, clip_id: String) -> void:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c != null:
		set_animated(Session.doc, s, c, on)


static func _on_reset(clip_id: String) -> void:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c != null:
		reset_pins(Session.doc, s, c)
