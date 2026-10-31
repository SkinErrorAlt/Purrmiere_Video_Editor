extends VBoxContainer

const KeyAnchor := preload("res://doc/key_anchor.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const SELF_PATH := "res://modules/core_panels/speed_preview.gd"
const WINDOW_KEY := "controls.speed_preview"
const SPANS: Array[float] = [1.0, 2.0, 4.0]
const PREF_SOUND := "speed.preview_sound"

static var _open: WeakRef = null

var clip_id: String = ""
var src: float = 0.0
var span: float = 2.0
var looping: bool = true
var sound: bool = false
var loops: int = 0
var _picture: TextureRect = null
var _note: Label = null
var _loop_btn: Button = null
var _sound_btn: Button = null
var _muted_by_me: bool = false
var _back_to: float = -1.0
var _started: bool = false


static func open_for(host: Node) -> Control:
	if _open != null:
		var w: Variant = _open.get_ref()
		if w is Control and is_instance_valid(w):
			(w as Control).call("raise")
			return w
	var body: Control = (load(SELF_PATH) as GDScript).new()
	var root: Node = host if host != null and host.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	var win: Control = PmWindow.open(root, "Speed preview", body, Vector2(float(Tk.px(420.0)), float(Tk.px(300.0))), WINDOW_KEY)
	_open = weakref(win)
	win.connect("closed", func() -> void: body.call("stop"))
	return win


static func pref_sound() -> bool:
	if not Prefs.is_registered(PREF_SOUND):
		Prefs.register(PREF_SOUND, false, {"label": "Speed preview plays the sound too", "type": "bool"})
	return bool(Prefs.get_value(PREF_SOUND))


func _ready() -> void:
	name = "SpeedPreview"
	sound = pref_sound()
	add_theme_constant_override("separation", Tk.px(4.0))
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	var bar: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	_loop_btn = PmButton.make("Loop", "loop", true)
	_loop_btn.set("quiet", true)
	_loop_btn.set_pressed_no_signal(looping)
	PmUI.tip(_loop_btn, "Play the frames around the playhead over and over, so a speed change shows at once")
	_loop_btn.toggled.connect(set_looping)
	bar.add_child(_loop_btn)
	for sv: float in SPANS:
		var b: Button = PmButton.make(str(int(sv)) + " s", "", true)
		b.set("quiet", true)
		b.set_pressed_no_signal(is_equal_approx(sv, span))
		b.pressed.connect(set_span.bind(sv))
		bar.add_child(b)
	_sound_btn = PmButton.make("Sound", "volume", true)
	_sound_btn.set("quiet", true)
	_sound_btn.set_pressed_no_signal(sound)
	PmUI.tip(_sound_btn, "Hear the clip while it loops")
	_sound_btn.toggled.connect(set_sound)
	bar.add_child(_sound_btn)
	add_child(bar)
	_note = PmLabel.dim("")
	add_child(_note)
	pick_here()
	restart()


func pick_here() -> void:
	var s: Sequence = Session.seq()
	if s == null:
		return
	var t: float = Session.playhead()
	var c: Clip = null
	for id: String in s.selected_clip_ids:
		var sc: Clip = s.clip_by_id(id)
		if sc != null and sc.start <= t and t < sc.end():
			c = sc
	if c == null:
		for tr: Track in s.video_tracks:
			for vc: Clip in tr.clips:
				if vc.start <= t and t < vc.end():
					c = vc
	if c == null:
		_note.text = "Put the playhead over a clip"
		return
	clip_id = c.id
	src = c.source_time_exact(t)
	_note.text = "Looping around the frame under the playhead in " + (c.label if not c.label.is_empty() else c.id)


func centre() -> float:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return Session.playhead()
	return c.start + KeyAnchor.local_for_source(c, src)


func set_span(v: float) -> void:
	span = v
	restart()


func set_looping(on: bool) -> void:
	looping = on
	if on:
		restart()
	else:
		stop()


func set_sound(on: bool) -> void:
	sound = on
	Prefs.set_value(PREF_SOUND, on)
	_apply_sound()


func _apply_sound() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	var want_mute: bool = looping and not sound and Session.playing
	if want_mute and not AudioServer.is_bus_mute(bus):
		AudioServer.set_bus_mute(bus, true)
		_muted_by_me = true
	elif not want_mute and _muted_by_me:
		AudioServer.set_bus_mute(bus, false)
		_muted_by_me = false


func restart() -> void:
	if not looping or clip_id.is_empty():
		return
	var mid: float = centre()
	var a: float = maxf(mid - span * 0.5, 0.0)
	Session.play_span(a, a + span, mid)
	_back_to = mid
	_started = true
	loops += 1
	_apply_sound()


func stop() -> void:
	if Session.playing:
		Session.set_playing(false)
	if _muted_by_me:
		var bus: int = AudioServer.get_bus_index("Master")
		if bus >= 0:
			AudioServer.set_bus_mute(bus, false)
		_muted_by_me = false


func _process(_delta: float) -> void:
	var comp: Object = Session.get("compositor")
	if comp != null and is_instance_valid(comp) and comp.has_method("texture"):
		var tex: Texture2D = comp.call("texture")
		if _picture.texture != tex:
			_picture.texture = tex
	if looping and _started and not clip_id.is_empty() and not Session.playing and is_visible_in_tree():
		if absf(Session.playhead() - _back_to) < 0.02:
			restart()
		else:
			_started = false
			looping = false
			if _loop_btn != null:
				_loop_btn.set_pressed_no_signal(false)
			_apply_sound()


func _exit_tree() -> void:
	stop()
