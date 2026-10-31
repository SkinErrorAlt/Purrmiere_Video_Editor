extends Node

const SELF_PATH := "res://modules/core_panels/space_hold.gd"
const PmLabel := preload("res://ui/kit/pm_label.gd")
const AUDIO_GRAPH_PATH := "res://engine/audio_graph.gd"
const NODE_NAME := "SpaceHold"
const COMMAND_ID := "play.toggle"
const PREF_HOLD_MS := "playback.space_hold_ms"
const PREF_SPEED := "playback.space_hold_speed"
const PREF_RELEASE := "playback.space_release"
const PREF_PITCH := "playback.space_keep_pitch"
const RELEASE_STOP := "Stop"
const PITCH_MENU_ID := "space_keep_pitch"
const RELEASE_KEEP := "Keep playing at normal speed"
const DEFAULT_HOLD_MS := 250
const DEFAULT_SPEED := 2.0
const STEPS: Array[float] = [-8.0, -4.0, -2.0, -1.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]
const MAX_SPEED := 8.0
const IDLE := 0
const PENDING := 1
const HOLDING := 2

static var _inst: Node = null

var state: int = IDLE
var speed: float = 1.0
var taps: int = 0
var holds: int = 0
var swallowed: int = 0
var wheel_steps: int = 0
var wheels_taken: int = 0
var down_probe: Callable = Callable()
var clock_probe: Callable = Callable()
var _key: Key = KEY_NONE
var _phys: Key = KEY_NONE
var _press_ms: int = 0
var _target: Object = null
var _wheel_acc: float = 0.0
var _catchers: Array[Node] = []
var _pitch_forced: bool = false


class Catcher:
	extends Node

	var hold: Node = null

	func _init() -> void:
		name = "SpaceHoldCatcher"
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if hold == null or not is_instance_valid(hold):
			return
		if bool(hold.call("catch_event", event)):
			var vp: Viewport = get_viewport()
			if vp != null:
				vp.set_input_as_handled()


class SpeedWatch:
	extends Node

	var rate_of: Callable = Callable()

	func _init() -> void:
		name = "SpeedWatch"

	func _process(_dt: float) -> void:
		var l: Label = get_parent() as Label
		if l == null:
			return
		var r: float = 1.0
		if rate_of.is_valid():
			r = float(rate_of.call())
		var show: bool = not is_equal_approx(r, 1.0)
		if show:
			var mag: String = String.num(absf(r), 2)
			if mag.contains("."):
				mag = mag.rstrip("0").rstrip(".")
			var t: String = ("-" if r < 0.0 else "") + mag + "x"
			if l.text != t:
				l.text = t
		if l.visible != show:
			l.visible = show


static func install() -> void:
	register_prefs()
	var cmd: Node = _autoload("Cmd")
	if cmd != null and cmd.has_method("set_hold"):
		cmd.call("set_hold", COMMAND_ID, Callable(load(SELF_PATH), "key"))


static func register_prefs() -> void:
	var prefs: Node = _autoload("Prefs")
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_HOLD_MS)):
		prefs.call("register", PREF_HOLD_MS, DEFAULT_HOLD_MS, {"label": "Hold Space this long to play sped up (ms)", "type": "int", "min": 100, "max": 1000, "hint": "A shorter press plays or pauses as usual"})
	if not bool(prefs.call("is_registered", PREF_SPEED)):
		prefs.call("register", PREF_SPEED, DEFAULT_SPEED, {"label": "Speed while Space is held", "type": "float", "min": 1.0, "max": MAX_SPEED, "hint": "The wheel changes it while Space is down"})
	if not bool(prefs.call("is_registered", PREF_RELEASE)):
		prefs.call("register", PREF_RELEASE, RELEASE_KEEP, {"label": "After holding Space", "type": "enum", "choices": [RELEASE_STOP, RELEASE_KEEP]})
	if not bool(prefs.call("is_registered", PREF_PITCH)):
		prefs.call("register", PREF_PITCH, true, {"label": "Keep the pitch while Space speeds up the sound", "type": "bool"})


static func _autoload(name_: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null(NodePath(name_))


static func instance() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var loop: MainLoop = Engine.get_main_loop()
	var script: GDScript = load(SELF_PATH)
	var n: Node = script.new()
	n.name = NODE_NAME
	_inst = n
	if loop is SceneTree:
		var root: Window = (loop as SceneTree).root
		var old: Node = root.get_node_or_null(NodePath(NODE_NAME))
		if old != null and old != n:
			old.name = NODE_NAME + "_old"
			old.queue_free()
		root.add_child.call_deferred(n)
	return n


static func _readout(rate_of: Callable) -> Label:
	var l: Label = PmLabel.mono("", "text")
	l.name = "SpeedReadout"
	l.visible = false
	var w: SpeedWatch = SpeedWatch.new()
	w.rate_of = rate_of
	l.add_child(w)
	return l


static func program_readout() -> Label:
	return _readout(Callable(load(SELF_PATH), "program_rate"))


static func source_readout(panel: Object) -> Label:
	var ref: WeakRef = weakref(panel)
	var rate_of: Callable = func() -> float:
		var p: Object = ref.get_ref()
		if p == null or not bool(p.get("_playing")):
			return 1.0
		return float(p.get("play_rate"))
	return _readout(rate_of)


static func pitch_menu_item() -> Dictionary:
	register_prefs()
	var prefs: Node = _autoload("Prefs")
	var on: bool = prefs == null or bool(prefs.call("get_value", PREF_PITCH))
	var PmMenu: GDScript = load("res://ui/kit/pm_menu.gd")
	return PmMenu.call("check_item", PITCH_MENU_ID, "Keep pitch while holding Space", on)


static func pitch_menu_picked(id: String) -> bool:
	if id != PITCH_MENU_ID:
		return false
	register_prefs()
	var prefs: Node = _autoload("Prefs")
	if prefs != null:
		prefs.call("set_value", PREF_PITCH, not bool(prefs.call("get_value", PREF_PITCH)))
	return true


static func program_rate() -> float:
	var s: Node = _autoload("Session")
	if s == null or not bool(s.get("playing")):
		return 1.0
	return float(s.get("rate"))


static func key(e: InputEventKey) -> bool:
	return bool(instance().call("press", e, null))


static func key_for(e: InputEventKey, target: Object) -> bool:
	return bool(instance().call("press", e, target))


static func speed_text(r: float) -> String:
	var mag: String = String.num(absf(r), 2)
	if mag.contains("."):
		mag = mag.rstrip("0").rstrip(".")
	return ("-" if r < 0.0 else "") + mag + "x"


static func step_from(r: float, dir: int) -> float:
	if dir > 0:
		for s: float in STEPS:
			if s > r + 0.0001:
				return s
		return STEPS[STEPS.size() - 1]
	if dir < 0:
		for i: int in range(STEPS.size() - 1, -1, -1):
			if STEPS[i] < r - 0.0001:
				return STEPS[i]
		return STEPS[0]
	return r


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func hold_ms() -> int:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_HOLD_MS)):
		return DEFAULT_HOLD_MS
	return clampi(int(prefs.call("get_value", PREF_HOLD_MS)), 50, 5000)


func start_speed() -> float:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_SPEED)):
		return DEFAULT_SPEED
	return clampf(float(prefs.call("get_value", PREF_SPEED)), 0.25, MAX_SPEED)


func release_keeps_playing() -> bool:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_RELEASE)):
		return false
	return String(prefs.call("get_value", PREF_RELEASE)) == RELEASE_KEEP


func keeps_pitch() -> bool:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_PITCH)):
		return true
	return bool(prefs.call("get_value", PREF_PITCH))


func _now() -> int:
	if clock_probe.is_valid():
		return int(clock_probe.call())
	return Time.get_ticks_msec()


func _is_down() -> bool:
	if down_probe.is_valid():
		return bool(down_probe.call())
	if _key != KEY_NONE and Input.is_key_pressed(_key):
		return true
	return _phys != KEY_NONE and Input.is_physical_key_pressed(_phys)


func press(e: InputEventKey, target: Object) -> bool:
	if e.echo:
		swallowed += 1
		return true
	if not e.pressed:
		return false
	if state != IDLE:
		if _is_down() and _press_ms > 0 and (e.keycode == _key or e.physical_keycode == _phys):
			swallowed += 1
			return true
		if state == HOLDING:
			_end_hold()
		else:
			_finish()
	_target = target
	_key = e.keycode
	_phys = e.physical_keycode
	_press_ms = _now()
	_wheel_acc = 0.0
	speed = start_speed()
	_toggle()
	state = PENDING
	_add_catchers()
	set_process(true)
	return true


func holding() -> bool:
	return state == HOLDING


func _process(_dt: float) -> void:
	tick()


func tick() -> void:
	if state == IDLE:
		set_process(false)
		return
	var down: bool = _is_down()
	if state == PENDING:
		if not down:
			taps += 1
			_finish()
			return
		if _now() - _press_ms >= hold_ms():
			_begin_hold()
		return
	if not down:
		_end_hold()
		return


func catch_event(event: InputEvent) -> bool:
	if state == IDLE:
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
		var down: bool = mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if not (up or down or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT):
			return false
		wheels_taken += 1
		if mb.pressed and (up or down):
			var f: float = mb.factor if mb.factor > 0.0 else 1.0
			_wheel_acc += f if up else -f
			_drain_wheel()
		return true
	if event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		wheels_taken += 1
		_wheel_acc -= pg.delta.y
		_drain_wheel()
		return true
	if event is InputEventMagnifyGesture:
		wheels_taken += 1
		return true
	return false


func _drain_wheel() -> void:
	while _wheel_acc >= 0.999:
		_wheel_acc -= 1.0
		wheel(1)
	while _wheel_acc <= -0.999:
		_wheel_acc += 1.0
		wheel(-1)


func wheel(dir: int) -> void:
	if state == IDLE or dir == 0:
		return
	if state == PENDING:
		_begin_hold()
	var next: float = step_from(speed, dir)
	wheel_steps += 1
	if is_equal_approx(next, speed):
		return
	speed = next
	_apply_speed()


func _source() -> bool:
	return _target != null and is_instance_valid(_target)


func _session() -> Node:
	return _autoload("Session")


func target_playing() -> bool:
	if _source():
		return bool(_target.get("_playing"))
	var s: Node = _session()
	return s != null and bool(s.get("playing"))


func _toggle() -> void:
	if _source():
		_target.call("set_play_rate", 1.0)
		_target.call("set_playing", not bool(_target.get("_playing")))
		return
	var cmd: Node = _autoload("Cmd")
	if cmd != null:
		cmd.call("run", COMMAND_ID)


func _begin_hold() -> void:
	if state != PENDING:
		return
	state = HOLDING
	holds += 1
	_set_pitch(true)
	_apply_speed()


func _apply_speed() -> void:
	if _source():
		_target.call("set_play_rate", speed)
		if not bool(_target.get("_playing")):
			_target.call("set_playing", true)
		return
	var s: Node = _session()
	if s == null:
		return
	s.call("set_rate", speed)
	if not bool(s.get("playing")):
		s.call("set_playing", true)


func _end_hold() -> void:
	var keep: bool = release_keeps_playing()
	if _source():
		if not keep:
			_target.call("set_playing", false)
		_target.call("set_play_rate", 1.0)
	else:
		var s: Node = _session()
		if s != null:
			if not keep:
				s.call("set_playing", false)
			s.call("set_rate", 1.0)
	_set_pitch(false)
	_finish()


func _finish() -> void:
	state = IDLE
	_press_ms = 0
	_wheel_acc = 0.0
	_drop_catchers()
	if _pitch_forced:
		_set_pitch(false)


func _set_pitch(on: bool) -> void:
	if _source():
		return
	var want: bool = on and keeps_pitch()
	if want == _pitch_forced:
		return
	_pitch_forced = want
	var graph: GDScript = load(AUDIO_GRAPH_PATH)
	if graph == null:
		return
	graph.set("hold_keep_pitch", want)
	var s: Node = _session()
	if s != null and s.has_method("push_playback_graph"):
		s.call("push_playback_graph")


func pitch_forced() -> bool:
	return _pitch_forced


func _windows() -> Array[Window]:
	var out: Array[Window] = []
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		out.append((loop as SceneTree).root)
	for id: int in DisplayServer.get_window_list():
		var obj: Object = instance_from_id(DisplayServer.window_get_attached_instance_id(id))
		if obj is Window and is_instance_valid(obj) and not out.has(obj as Window):
			out.append(obj as Window)
	return out


func _add_catchers() -> void:
	_drop_catchers()
	for w: Window in _windows():
		var c: Catcher = Catcher.new()
		c.hold = self
		_catchers.append(c)
		w.add_child.call_deferred(c)


func _drop_catchers() -> void:
	for c: Node in _catchers:
		if is_instance_valid(c):
			if c.is_inside_tree():
				c.queue_free()
			else:
				c.set("hold", null)
				c.queue_free()
	_catchers.clear()


func catcher_count() -> int:
	var n: int = 0
	for c: Node in _catchers:
		if is_instance_valid(c):
			n += 1
	return n


func reset() -> void:
	if state == HOLDING:
		_end_hold()
	else:
		_finish()
	down_probe = Callable()
	clock_probe = Callable()
	taps = 0
	holds = 0
	swallowed = 0
	wheel_steps = 0
	wheels_taken = 0
