extends RefCounted

signal ready_now
signal failed(why: String)
signal scene_changed(scene: String, at: float)
signal record_changed(active: bool, path: String, at: float)
signal shot(png: PackedByteArray, at: float)

const PROTOCOL := "obswebsocket.json"
const RPC := 1
const OP_HELLO := 0
const OP_IDENTIFY := 1
const OP_IDENTIFIED := 2
const OP_EVENT := 5
const OP_REQUEST := 6
const OP_RESPONSE := 7
const SUB_SCENES := 4
const SUB_OUTPUTS := 64
const CONNECT_LIMIT_MS := 5000
const SHOT_LIMIT_MS := 3000
const DEFAULT_ADDRESS := "127.0.0.1:4455"

var state: String = "idle"
var last_error: String = ""
var scene: String = ""
var recording: bool = false
var record_path: String = ""
var shots_asked: int = 0
var shots_got: int = 0
var _ws: WebSocketPeer = null
var _password: String = ""
var _started_ms: int = 0
var _next_id: int = 0
var _pending: Dictionary = {}
var _clock: Callable = Callable()


static func split_address(text: String) -> Dictionary:
	var t: String = text.strip_edges().trim_prefix("ws://")
	if t.is_empty():
		t = DEFAULT_ADDRESS
	var host: String = t
	var port: int = 4455
	var colon: int = t.rfind(":")
	if colon > 0:
		host = t.substr(0, colon)
		port = t.substr(colon + 1).to_int()
	return {"host": host if not host.is_empty() else "127.0.0.1", "port": port if port > 0 else 4455}


static func auth_answer(password: String, salt: String, challenge: String) -> String:
	var secret: String = Marshalls.raw_to_base64((password + salt).sha256_buffer())
	return Marshalls.raw_to_base64((secret + challenge).sha256_buffer())


func open(address: String, password: String, clock: Callable = Callable()) -> bool:
	close()
	_password = password
	_clock = clock
	var a: Dictionary = split_address(address)
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray([PROTOCOL])
	_ws.inbound_buffer_size = 1 << 20
	var err: Error = _ws.connect_to_url("ws://%s:%d" % [String(a["host"]), int(a["port"])])
	if err != OK:
		_fail("OBS could not be reached at %s:%d" % [String(a["host"]), int(a["port"])])
		return false
	state = "connecting"
	_started_ms = Time.get_ticks_msec()
	return true


func close() -> void:
	if _ws != null:
		_ws.close()
	_ws = null
	_pending = {}
	if state != "failed":
		state = "idle"


func is_ready() -> bool:
	return state == "ready"


func waiting_shot() -> bool:
	for k: Variant in _pending.keys():
		if String((_pending[k] as Dictionary).get("type", "")) == "GetSourceScreenshot":
			return true
	return false


func _now() -> float:
	if _clock.is_valid():
		return float(_clock.call())
	return Time.get_unix_time_from_system()


func _fail(why: String) -> void:
	last_error = why
	state = "failed"
	if _ws != null:
		_ws.close()
	_ws = null
	failed.emit(why)


func _send(op: int, d: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"op": op, "d": d}))


func request(type: String, data: Dictionary = {}) -> String:
	_next_id += 1
	var id: String = "p" + str(_next_id)
	var d: Dictionary = {"requestType": type, "requestId": id}
	if not data.is_empty():
		d["requestData"] = data
	_pending[id] = {"type": type, "at": _now(), "ms": Time.get_ticks_msec()}
	_send(OP_REQUEST, d)
	return id


func ask_shot(width: int, height: int) -> bool:
	if not is_ready() or scene.is_empty() or waiting_shot():
		return false
	shots_asked += 1
	request("GetSourceScreenshot", {"sourceName": scene, "imageFormat": "png", "imageWidth": width, "imageHeight": height})
	return true


func poll() -> void:
	if _ws == null:
		return
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		if state != "failed":
			_fail("OBS closed the link (%s)" % (_ws.get_close_reason() if not _ws.get_close_reason().is_empty() else "is its WebSocket server on, under Tools, WebSocket Server Settings?"))
		return
	if state == "connecting" and Time.get_ticks_msec() - _started_ms > CONNECT_LIMIT_MS:
		_fail("OBS did not answer. In OBS turn on Tools, WebSocket Server Settings, Enable WebSocket server")
		return
	var now_ms: int = Time.get_ticks_msec()
	for k: Variant in _pending.keys():
		if now_ms - int((_pending[k] as Dictionary)["ms"]) > SHOT_LIMIT_MS:
			_pending.erase(k)
	while _ws != null and _ws.get_available_packet_count() > 0:
		var text: String = _ws.get_packet().get_string_from_utf8()
		var msg: Variant = JSON.parse_string(text)
		if msg is Dictionary:
			_handle(msg)


func _handle(msg: Dictionary) -> void:
	var op: int = int(msg.get("op", -1))
	var d: Dictionary = msg.get("d", {}) if msg.get("d") is Dictionary else {}
	if op == OP_HELLO:
		var ident: Dictionary = {"rpcVersion": RPC, "eventSubscriptions": SUB_SCENES | SUB_OUTPUTS}
		var auth: Variant = d.get("authentication", null)
		if auth is Dictionary:
			if _password.is_empty():
				_fail("OBS asks for a password. Copy it from Tools, WebSocket Server Settings, Show connect info")
				return
			ident["authentication"] = auth_answer(_password, String((auth as Dictionary).get("salt", "")), String((auth as Dictionary).get("challenge", "")))
		_send(OP_IDENTIFY, ident)
	elif op == OP_IDENTIFIED:
		state = "ready"
		request("GetCurrentProgramScene")
		request("GetRecordStatus")
	elif op == OP_EVENT:
		_event(String(d.get("eventType", "")), d.get("eventData", {}) if d.get("eventData") is Dictionary else {})
	elif op == OP_RESPONSE:
		_response(d)


func _event(type: String, data: Dictionary) -> void:
	if type == "CurrentProgramSceneChanged":
		var name: String = String(data.get("sceneName", data.get("currentProgramSceneName", "")))
		if not name.is_empty() and name != scene:
			scene = name
			scene_changed.emit(name, _now())
	elif type == "RecordStateChanged":
		var active: bool = bool(data.get("outputActive", false))
		var p: Variant = data.get("outputPath", null)
		if p is String and not (p as String).is_empty():
			record_path = p
		var st: String = String(data.get("outputState", ""))
		if st == "OBS_WEBSOCKET_OUTPUT_STARTED" or st == "OBS_WEBSOCKET_OUTPUT_STOPPED" or (st.is_empty() and active != recording):
			recording = active
			record_changed.emit(active, record_path, _now())


func _response(d: Dictionary) -> void:
	var id: String = String(d.get("requestId", ""))
	var asked: Dictionary = _pending.get(id, {})
	_pending.erase(id)
	var status: Dictionary = d.get("requestStatus", {}) if d.get("requestStatus") is Dictionary else {}
	var data: Dictionary = d.get("responseData", {}) if d.get("responseData") is Dictionary else {}
	var type: String = String(d.get("requestType", asked.get("type", "")))
	if not bool(status.get("result", false)):
		if type == "GetSourceScreenshot":
			last_error = "OBS gave no picture: " + String(status.get("comment", "code %d" % int(status.get("code", 0))))
		return
	if type == "GetCurrentProgramScene":
		var first: bool = scene.is_empty()
		scene = String(data.get("sceneName", data.get("currentProgramSceneName", "")))
		if first:
			ready_now.emit()
	elif type == "GetRecordStatus":
		recording = bool(data.get("outputActive", false))
	elif type == "GetSourceScreenshot":
		var raw: String = String(data.get("imageData", ""))
		var comma: int = raw.find(",")
		var png: PackedByteArray = Marshalls.base64_to_raw(raw.substr(comma + 1) if comma >= 0 else raw)
		if not png.is_empty():
			shots_got += 1
			shot.emit(png, float(asked.get("at", _now())))
