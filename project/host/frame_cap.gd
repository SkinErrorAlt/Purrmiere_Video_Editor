extends RefCounted

const SELF := preload("res://host/frame_cap.gd")
const PREF := "ui.frame_cap"
const MATCH := "match display"
const UNLIMITED := "unlimited"
const CHOICES: PackedStringArray = ["match display", "unlimited", "30", "60", "120", "144", "240"]
const LABEL := "Frame rate limit"
const HINT := "How many times a second the window is drawn. Match display draws as often as your screen can show and no more. Unlimited draws as fast as the computer allows, which costs power and heat for frames nobody sees. Exports always run unlimited."
const FLOOR_FPS := 30
const IDLE_PREF := "ui.idle_frame_rate"
const IDLE_OFF := "off"
const IDLE_CHOICES: PackedStringArray = ["off", "15", "20", "30", "60"]
const IDLE_LABEL := "Frame rate while idle"
const IDLE_HINT := "After a moment with no mouse, keyboard or playback, the window is drawn this often instead. Any input or pressing play brings the full rate back on the next frame. Off keeps the full rate all the time."
const IDLE_DEFAULT := "30"
const IDLE_AFTER_MS := 1500

static var full_fps: int = 0
static var ours: int = -1
static var active_ms: int = 0


static func register() -> void:
	if not Prefs.is_registered(PREF):
		Prefs.register(PREF, MATCH, {"label": LABEL, "type": "enum", "choices": Array(CHOICES), "hint": HINT})
	if not Prefs.is_registered(IDLE_PREF):
		Prefs.register(IDLE_PREF, IDLE_DEFAULT, {"label": IDLE_LABEL, "type": "enum", "choices": Array(IDLE_CHOICES), "hint": IDLE_HINT})


static func fps_for(choice: String, refresh: float) -> int:
	if choice == UNLIMITED:
		return 0
	if choice.is_valid_int():
		return maxi(int(choice), FLOOR_FPS)
	if refresh <= 1.0:
		return 0
	return maxi(int(ceil(refresh - 0.05)), FLOOR_FPS)


static func refresh_rate() -> float:
	return DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())


static func apply(force: bool = false) -> int:
	register()
	if Prefs.running_suite() and not force:
		return Engine.max_fps
	var fps: int = fps_for(String(Prefs.get_value(PREF)), refresh_rate())
	full_fps = fps
	ours = fps
	active_ms = Time.get_ticks_msec()
	Engine.max_fps = fps
	return fps


static func idle_for(choice: String, full: int) -> int:
	if choice == IDLE_OFF or not choice.is_valid_int():
		return full
	var n: int = maxi(int(choice), 1)
	if full > 0 and n >= full:
		return full
	return n


static func want_fps(now_ms: int, playing: bool, full: int, idle_choice: String) -> int:
	if playing or now_ms - active_ms < IDLE_AFTER_MS:
		return full
	return idle_for(idle_choice, full)


static func touch() -> void:
	active_ms = Time.get_ticks_msec()
	if ours >= 0 and Engine.max_fps == ours and ours != full_fps:
		ours = full_fps
		Engine.max_fps = full_fps


static func tick(playing: bool) -> void:
	if ours < 0 or Engine.max_fps != ours:
		return
	var want: int = want_fps(Time.get_ticks_msec(), playing, full_fps, String(Prefs.get_value(IDLE_PREF)))
	if want != ours:
		ours = want
		Engine.max_fps = want


static func watch() -> void:
	register()
	apply()
	var cb: Callable = Callable(SELF, "_on_pref")
	if not Prefs.changed.is_connected(cb):
		Prefs.changed.connect(cb)


static func _on_pref(key: String) -> void:
	if key == PREF or key == IDLE_PREF:
		apply()
