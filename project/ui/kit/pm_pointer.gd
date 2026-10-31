extends RefCounted

static var _fake: Object = null
static var _held: bool = false


static func set_fake(driver: Object) -> void:
	_fake = driver
	_held = false


static func fake() -> Object:
	return _fake


static func live() -> bool:
	if _fake != null:
		return true
	return DisplayServer.get_name() != "headless"


static func screen_pos() -> Vector2i:
	if _fake != null:
		return _fake.call("screen_pos")
	return DisplayServer.mouse_get_position()


static func focused_window() -> int:
	if _fake != null and _fake.has_method("focused_window"):
		return int(_fake.call("focused_window"))
	for id: int in DisplayServer.get_window_list():
		if DisplayServer.window_is_focused(id):
			return id
	return DisplayServer.INVALID_WINDOW_ID


static func warp_screen(p: Vector2i) -> bool:
	if _fake != null:
		_fake.call("warp_screen", p)
		return true
	var id: int = focused_window()
	if id == DisplayServer.INVALID_WINDOW_ID:
		return false
	var origin: Vector2i = DisplayServer.window_get_position(id)
	Input.warp_mouse(Vector2(p - origin))
	return true


static func hold(on: bool) -> void:
	_held = on
	if _fake != null:
		_fake.call("set_hidden", on)
		return
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if on else Input.MOUSE_MODE_VISIBLE


static func held() -> bool:
	return _held
