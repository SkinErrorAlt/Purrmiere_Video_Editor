extends Node

signal changed(running: bool)

const Find := preload("res://doc/picture_find.gd")
const Found := preload("res://doc/found_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Notes := preload("res://doc/desktop_notes.gd")
const ObsLink := preload("res://engine/obs_link.gd")
const SELF_PATH := "res://engine/desktop_watch.gd"
const NODE_NAME := "DesktopWatch"
const PREF_RATE := "organizer.desktop_rate"
const PREF_SCREEN := "organizer.desktop_screen"
const PREF_PART := "organizer.desktop_part"
const PREF_SOURCE := "organizer.desktop_source"
const PREF_OBS_ADDRESS := "organizer.obs_address"
const PREF_OBS_PASSWORD := "organizer.obs_password"
const SOURCES: PackedStringArray = ["screen", "obs"]
const RATE_MIN := 0.5
const RATE_MAX := 8.0
const DEFAULT_RATE := 2.0
const SAVE_EVERY_MS := 120000
const GIVE_UP_AFTER := 6
const FROZEN_AFTER := 120
const SHOT_W := 96
const SHOT_H := 54
const FROZEN_TEXT := "Desktop watch: the screen picture has not changed at all. Games and other windows drawn by the graphics card are often not seen this way; watch through OBS instead (Watch the desktop, Look through)."

var running: bool = false
var rate: float = DEFAULT_RATE
var screen: int = -1
var part: Rect2 = Find.FULL
var source: String = "screen"
var session: Dictionary = {}
var saved_path: String = ""
var captures: int = 0
var failures: int = 0
var fails_in_row: int = 0
var same_in_row: int = 0
var frozen_said: bool = false
var cap_us_total: int = 0
var cap_us_worst: int = 0
var work_us_total: int = 0
var tick_us_worst: int = 0
var tick_us_total: int = 0
var ticks: int = 0
var last_error: String = ""
var link: RefCounted = null
var _prep: Dictionary = {}
var _task: int = -1
var _holder: Array = [{}]
var _next_ms: int = 0
var _saved_ms: int = 0
var _started_ms: int = 0
var _last_grid: PackedByteArray = PackedByteArray()
var _times: PackedFloat64Array = PackedFloat64Array()
var _changes: PackedFloat32Array = PackedFloat32Array()
var _scores: Dictionary = {}
var _shots: Array = []


static func instance(create: bool = true) -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var n: Node = loop.root.get_node_or_null(NODE_NAME)
	if n == null and create:
		var script: GDScript = load(SELF_PATH)
		n = script.new()
		n.name = NODE_NAME
		loop.root.add_child(n)
	return n


static func running_now() -> bool:
	var n: Node = instance(false)
	return n != null and bool(n.get("running"))


static func prefs_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var prefs: Node = loop.root.get_node_or_null("/root/Prefs") if loop != null else null
	return prefs if prefs != null and prefs.has_method("register") else null


static func register_prefs() -> void:
	var prefs: Node = prefs_node()
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_RATE)):
		prefs.call("register", PREF_RATE, DEFAULT_RATE, {"label": "Desktop watch: looks this many times a second", "type": "float", "min": RATE_MIN, "max": RATE_MAX, "step": 0.5})
	if not bool(prefs.call("is_registered", PREF_SOURCE)):
		prefs.call("register", PREF_SOURCE, "screen", {"label": "Desktop watch: looks at", "type": "enum", "choices": Array(SOURCES), "hint": "screen: a screen of this computer (windows drawn by the graphics card, like most games, can look frozen). obs: the picture OBS is making, through its WebSocket server (OBS Tools, WebSocket Server Settings); it also notes when the OBS scene changes and when a recording starts and stops."})
	if not bool(prefs.call("is_registered", PREF_SCREEN)):
		prefs.call("register", PREF_SCREEN, -1, {"label": "Desktop watch: screen to watch (-1 the main screen, 0 the first)", "type": "int", "min": -1, "max": 8})
	if not bool(prefs.call("is_registered", PREF_PART)):
		prefs.call("register", PREF_PART, "", {"label": "Desktop watch: part of the screen, left, top, width, height in percent (empty for all of it)", "type": "string"})
	if not bool(prefs.call("is_registered", PREF_OBS_ADDRESS)):
		prefs.call("register", PREF_OBS_ADDRESS, ObsLink.DEFAULT_ADDRESS, {"label": "Desktop watch: OBS WebSocket address", "type": "string"})
	if not bool(prefs.call("is_registered", PREF_OBS_PASSWORD)):
		prefs.call("register", PREF_OBS_PASSWORD, "", {"label": "Desktop watch: OBS WebSocket password (kept in the settings file as typed)", "type": "string"})


static func pref(key: String, fallback: Variant) -> Variant:
	register_prefs()
	var prefs: Node = prefs_node()
	if prefs == null:
		return fallback
	var v: Variant = prefs.call("get_value", key)
	return fallback if v == null else v


static func part_of(text: String) -> Rect2:
	var bits: PackedStringArray = text.replace(" ", "").split(",", false)
	if bits.size() < 4:
		return Find.FULL
	var r: Rect2 = Rect2(clampf(bits[0].to_float() / 100.0, 0.0, 1.0), clampf(bits[1].to_float() / 100.0, 0.0, 1.0), clampf(bits[2].to_float() / 100.0, 0.0, 1.0), clampf(bits[3].to_float() / 100.0, 0.0, 1.0))
	if r.size.x <= 0.01 or r.size.y <= 0.01:
		return Find.FULL
	r.size = Vector2(minf(r.size.x, 1.0 - r.position.x), minf(r.size.y, 1.0 - r.position.y))
	return r


static func screen_rect(index: int, p: Rect2) -> Rect2i:
	var at: Vector2i = DisplayServer.screen_get_position(index)
	var sz: Vector2i = DisplayServer.screen_get_size(index)
	return Rect2i(at + Vector2i(int(p.position.x * float(sz.x)), int(p.position.y * float(sz.y))), Vector2i(maxi(int(p.size.x * float(sz.x)), 1), maxi(int(p.size.y * float(sz.y)), 1)))


static func prepared_kinds() -> Dictionary:
	var out: Dictionary = {}
	var views: Array[Rect2] = [Find.FULL]
	for k: Dictionary in Kinds.kinds():
		var id: String = String(k["id"])
		var spec: Dictionary = Found.spec_of(id)
		var samples: Array = Found.samples(spec)
		if samples.is_empty():
			continue
		var prep: Array[Dictionary] = Find.prepared(samples, Find.rects(spec.get("focus", [])), Find.rects(spec.get("drop", [])))
		if prep.is_empty():
			continue
		out[id] = {"prep": prep, "maps": Find.view_maps(prep, views, Find.FRAME_W, Find.FRAME_H)}
	return out


func _ready() -> void:
	set_process(running)


func _exit_tree() -> void:
	if running:
		stop()


func start(opts: Dictionary = {}) -> bool:
	if running:
		return true
	rate = clampf(float(opts.get("rate", pref(PREF_RATE, DEFAULT_RATE))), RATE_MIN, RATE_MAX)
	source = String(opts.get("source", pref(PREF_SOURCE, "screen")))
	if not SOURCES.has(source):
		source = "screen"
	screen = int(opts.get("screen", pref(PREF_SCREEN, -1)))
	part = opts.get("part", part_of(String(pref(PREF_PART, ""))))
	last_error = ""
	if source == "screen":
		if screen >= DisplayServer.get_screen_count() or screen < -1:
			screen = -1
		if DisplayServer.get_name() == "headless" or DisplayServer.get_screen_count() < 1:
			last_error = "there is no screen to watch in this run"
			return false
	else:
		link = ObsLink.new()
		link.connect("failed", _on_link_failed)
		link.connect("scene_changed", _on_scene_changed)
		link.connect("record_changed", _on_record_changed)
		link.connect("shot", _on_shot)
		if not bool(link.call("open", String(opts.get("address", pref(PREF_OBS_ADDRESS, ObsLink.DEFAULT_ADDRESS))), String(opts.get("password", pref(PREF_OBS_PASSWORD, ""))), Callable(Notes, "now_local"))):
			last_error = String(link.get("last_error"))
			link = null
			return false
	_prep = prepared_kinds()
	session = Notes.fresh(Notes.now_local(), rate, screen, part, source)
	_times = PackedFloat64Array()
	_changes = PackedFloat32Array()
	_scores = {}
	for id: Variant in _prep.keys():
		_scores[String(id)] = PackedFloat32Array()
	_shots = []
	saved_path = ""
	captures = 0
	failures = 0
	fails_in_row = 0
	same_in_row = 0
	frozen_said = false
	cap_us_total = 0
	cap_us_worst = 0
	work_us_total = 0
	tick_us_worst = 0
	tick_us_total = 0
	ticks = 0
	_last_grid = PackedByteArray()
	_started_ms = Time.get_ticks_msec()
	_next_ms = _started_ms
	_saved_ms = _started_ms
	running = true
	set_process(true)
	changed.emit(true)
	return true


func stop() -> String:
	if not running:
		return saved_path
	running = false
	set_process(false)
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_merge()
	if link != null:
		var recs: Array = session["recordings"]
		if not recs.is_empty() and float((recs[recs.size() - 1] as Dictionary).get("end", -1.0)) < 0.0:
			(recs[recs.size() - 1] as Dictionary)["end"] = Notes.now_local()
		link.call("close")
		link = null
	if not _times.is_empty() or not (session.get("cuts", []) as Array).is_empty():
		saved_path = _save()
	changed.emit(false)
	return saved_path


func _save() -> String:
	session["times"] = _times
	session["changes"] = _changes
	session["kinds"] = _scores
	return Notes.save(session)


func kinds_watched() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in _prep.keys():
		out.append(String(k))
	return out


func seconds() -> float:
	if _times.size() < 2:
		return 0.0
	return _times[_times.size() - 1] - _times[0]


func stats() -> Dictionary:
	var looked: float = maxf(seconds(), float(Time.get_ticks_msec() - _started_ms) / 1000.0 if running else seconds())
	return {"captures": captures, "failures": failures, "rate": rate, "source": source, "cap_ms_mean": float(cap_us_total) / 1000.0 / float(maxi(captures, 1)), "cap_ms_worst": float(cap_us_worst) / 1000.0, "work_ms_mean": float(work_us_total) / 1000.0 / float(maxi(captures, 1)), "tick_ms_worst": float(tick_us_worst) / 1000.0, "tick_ms_mean": float(tick_us_total) / 1000.0 / float(maxi(ticks, 1)), "worker_share": float(work_us_total) / 1000000.0 / maxf(looked, 0.001), "seconds": looked}


func _on_link_failed(why: String) -> void:
	last_error = why
	if running:
		stop()
		_toast("Desktop watch stopped: " + why)


func _on_scene_changed(_scene: String, at: float) -> void:
	if running and not session.is_empty():
		(session["cuts"] as Array).append(at - float(session["start"]))


func _on_record_changed(active: bool, path: String, at: float) -> void:
	if not running or session.is_empty():
		return
	var recs: Array = session["recordings"]
	if active:
		recs.append({"start": at, "end": -1.0, "path": path})
	elif not recs.is_empty():
		var last: Dictionary = recs[recs.size() - 1]
		last["end"] = at
		if not path.is_empty():
			last["path"] = path
	else:
		recs.append({"start": -1.0, "end": at, "path": path})


func _on_shot(png: PackedByteArray, at: float) -> void:
	if running:
		_shots.append({"png": png, "t": at})


func _toast(text: String) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var ev: Node = loop.root.get_node_or_null("/root/Events") if loop != null else null
	if ev != null and ev.has_method("toast"):
		ev.call("toast", text)


func _process(_dt: float) -> void:
	if not running:
		set_process(false)
		return
	var t0: int = Time.get_ticks_usec()
	if link != null:
		link.call("poll")
		if not running:
			return
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_merge()
	var now: int = Time.get_ticks_msec()
	var step: int = int(1000.0 / rate)
	if link == null:
		if running and _task < 0 and now >= _next_ms:
			_next_ms = maxi(_next_ms + step, now + step / 4)
			_holder = [{}]
			_task = WorkerThreadPool.add_task(_grab.bind(_holder, screen, part, _prep, _last_grid), false, "Desktop watch")
	else:
		if running and now >= _next_ms and bool(link.call("ask_shot", SHOT_W, SHOT_H)):
			_next_ms = maxi(_next_ms + step, now + step / 4)
		if running and _task < 0 and not _shots.is_empty():
			var one: Dictionary = _shots.pop_front()
			_holder = [{}]
			_task = WorkerThreadPool.add_task(_read_png.bind(_holder, one["png"], float(one["t"]), _prep, _last_grid), false, "Desktop watch")
	if running and now - _saved_ms >= SAVE_EVERY_MS and captures > 0:
		_saved_ms = now
		saved_path = _save()
	var us: int = Time.get_ticks_usec() - t0
	tick_us_worst = maxi(tick_us_worst, us)
	tick_us_total += us
	ticks += 1


func _merge() -> void:
	var got: Dictionary = _holder[0]
	if got.is_empty() or not bool(got.get("ok", false)):
		failures += 1
		fails_in_row += 1
		last_error = String(got.get("error", "the screen could not be read"))
		if fails_in_row >= GIVE_UP_AFTER and captures == 0:
			stop()
			_toast("Desktop watch stopped: " + last_error)
		return
	fails_in_row = 0
	captures += 1
	cap_us_total += int(got["cap_us"])
	cap_us_worst = maxi(cap_us_worst, int(got["cap_us"]))
	work_us_total += int(got["work_us"])
	_times.append(float(got["t"]) - float(session["start"]))
	var change: float = float(got["change"])
	_changes.append(change)
	var scores: Dictionary = got["scores"]
	for k: Variant in _scores.keys():
		var arr: PackedFloat32Array = _scores[k]
		_scores[k] = PackedFloat32Array()
		arr.append(float(scores.get(k, 0.0)))
		_scores[k] = arr
	_last_grid = got["grid"]
	same_in_row = same_in_row + 1 if change == 0.0 and captures > 1 else 0
	if same_in_row >= FROZEN_AFTER and not frozen_said and link == null:
		frozen_said = true
		_toast(FROZEN_TEXT)


static func _score_all(px: PackedByteArray, prep: Dictionary, last_grid: PackedByteArray) -> Dictionary:
	var grids: Array[PackedByteArray] = Find.frame_grids(px, Find.FRAME_W, Find.FRAME_H, 0, 1)
	var grid: PackedByteArray = grids[0] if not grids.is_empty() else PackedByteArray()
	var scores: Dictionary = {}
	for k: Variant in prep.keys():
		var e: Dictionary = prep[k]
		var list: Array[Dictionary] = e["prep"]
		var per: Array = (e["maps"] as Array)[0]
		var best: float = 0.0
		for si: int in list.size():
			best = maxf(best, Find.score_frame(px, 0, list[si], per[si]))
		scores[k] = best
	return {"grid": grid, "scores": scores, "change": Find.change(last_grid, grid) if not last_grid.is_empty() else 0.0}


static func _grab(holder: Array, which: int, p: Rect2, prep: Dictionary, last_grid: PackedByteArray) -> void:
	var t0: int = Time.get_ticks_usec()
	var when: float = Notes.now_local()
	var index: int = which if which >= 0 else DisplayServer.get_primary_screen()
	var img: Image = null
	if p == Find.FULL:
		img = DisplayServer.screen_get_image(index)
	else:
		img = DisplayServer.screen_get_image_rect(screen_rect(index, p))
	var t1: int = Time.get_ticks_usec()
	if img == null or img.is_empty():
		holder[0] = {"ok": false, "error": "the screen could not be read"}
		return
	var px: PackedByteArray = Find.small_rgb(img, true)
	if px.size() < Find.FRAME_W * Find.FRAME_H * 3:
		holder[0] = {"ok": false, "error": "the screen picture could not be shrunk"}
		return
	var res: Dictionary = _score_all(px, prep, last_grid)
	res["ok"] = true
	res["t"] = when
	res["cap_us"] = t1 - t0
	res["work_us"] = Time.get_ticks_usec() - t0
	holder[0] = res


static func _read_png(holder: Array, png: PackedByteArray, when: float, prep: Dictionary, last_grid: PackedByteArray) -> void:
	var t0: int = Time.get_ticks_usec()
	var img: Image = Image.new()
	if img.load_png_from_buffer(png) != OK or img.is_empty():
		holder[0] = {"ok": false, "error": "the OBS picture could not be read"}
		return
	var t1: int = Time.get_ticks_usec()
	var px: PackedByteArray = Find.small_rgb(img, true)
	if px.size() < Find.FRAME_W * Find.FRAME_H * 3:
		holder[0] = {"ok": false, "error": "the OBS picture could not be shrunk"}
		return
	var res: Dictionary = _score_all(px, prep, last_grid)
	res["ok"] = true
	res["t"] = when
	res["cap_us"] = t1 - t0
	res["work_us"] = Time.get_ticks_usec() - t0
	holder[0] = res
