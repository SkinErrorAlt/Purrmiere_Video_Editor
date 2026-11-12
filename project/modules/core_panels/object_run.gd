extends Node

const ObjectSelect := preload("res://engine/object_select.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectStore := preload("res://engine/object_store.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const NODE_NAME := "ObjectRun"
const SELF_PATH := "res://modules/core_panels/object_run.gd"
const FRAME_WIDTH := 960
const STEP_MS := 24
const BATCH := 8

signal progress(done: int, total: int)
signal finished(ok: bool, info: Dictionary)

var state: Dictionary = {}
var last_info: Dictionary = {}
var frames_done: int = 0
var frames_total: int = 0
var worst_ms: float = 0.0
var mean_ms: float = 0.0


static func shared() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var n: Node = root.get_node_or_null(NODE_NAME)
	if n == null:
		n = (load(SELF_PATH) as GDScript).new()
		n.name = NODE_NAME
		root.add_child(n)
	return n


func running() -> bool:
	return not state.is_empty()


func running_clip() -> String:
	return String(state.get("clip", "")) if running() else ""


func start(doc: Project, seq: Sequence, clip: Clip, direction: String, limit: int = 0) -> String:
	if running():
		return "the object is already being tracked"
	if doc == null or seq == null or clip == null:
		return "no clip to track"
	var mask: Dictionary = _object_of(clip)
	if mask.is_empty():
		return "nothing has been selected on this clip yet"
	var keys: PackedInt32Array = ObjectMask.key_frames(mask)
	if keys.is_empty():
		return "the object has no picked frame to start from"
	var item: Variant = doc.media_by_id(clip.media_id)
	if item == null or String(item.get("path")).is_empty():
		return "the clip has no file to read"
	var path: String = String(item.get("path"))
	if not FileAccess.file_exists(path):
		return "the clip's file is not there"
	var handle: int = Session.render_handle(path)
	if handle < 0:
		return "the clip's file would not open"
	var ready: Dictionary = ObjectSelect.ensure()
	if not bool(ready.get("ok", false)):
		return String(ready.get("error", "object select is not ready"))
	var fps: float = maxf(seq.fps, 1.0)
	var count: int = maxi(int(round(clip.duration * fps)), 1)
	var back: bool = direction == "backward"
	var from: int = keys[0]
	for k: int in keys:
		if absi(k - int(round((seq.playhead - clip.start) * fps))) < absi(from - int(round((seq.playhead - clip.start) * fps))):
			from = k
	var last: int = 0 if back else count - 1
	if limit > 0:
		last = maxi(0, from - limit) if back else mini(count - 1, from + limit)
	return _begin(doc, seq, clip, mask, handle, from, last, back, fps, count)


func start_span(doc: Project, seq: Sequence, clip: Clip, from: int, to: int) -> String:
	if running():
		return "the object is already being tracked"
	if doc == null or seq == null or clip == null:
		return "no clip to track"
	var mask: Dictionary = _object_of(clip)
	if mask.is_empty():
		return "nothing has been selected on this clip yet"
	if ObjectMask.clicks_at(mask, from).get("labels", []).is_empty():
		return "frame " + str(from) + " has no clicks to work from"
	var item: Variant = doc.media_by_id(clip.media_id)
	if item == null or String(item.get("path")).is_empty():
		return "the clip has no file to read"
	var path: String = String(item.get("path"))
	if not FileAccess.file_exists(path):
		return "the clip's file is not there"
	var handle: int = Session.render_handle(path)
	if handle < 0:
		return "the clip's file would not open"
	var ready: Dictionary = ObjectSelect.ensure()
	if not bool(ready.get("ok", false)):
		return String(ready.get("error", "object select is not ready"))
	var fps: float = maxf(seq.fps, 1.0)
	var count: int = maxi(int(round(clip.duration * fps)), 1)
	var last: int = clampi(to, 0, count - 1)
	var back: bool = last < from
	if last == from:
		return "there is nothing past this frame to work out again"
	return _begin(doc, seq, clip, mask, handle, from, last, back, fps, count)


func _begin(doc: Project, seq: Sequence, clip: Clip, mask: Dictionary, handle: int, from: int, last: int, back: bool, fps: float, count: int) -> String:
	var span: int = absi(last - from)
	if span <= 0:
		return "there is nothing past this frame to track"
	ObjectSelect.reset()
	var seed: Dictionary = ObjectMask.clicks_at(mask, from)
	state = {
		"doc": doc, "seq": seq, "clip": clip.id, "mask": String(mask.get("id", "")),
		"handle": handle, "from": from, "at": from, "last": last, "back": back,
		"fps": fps, "count": count, "in_offset": clip.in_offset, "start": clip.start,
		"side": int(mask.get("side", ObjectMask.MATTE_SIDE)), "frames": {},
		"seed": seed, "seeded": false, "stop": false, "ms": 0.0,
		"marks": {}, "last_area": 0.0, "gone": 0, "check": 0, "feed": {}, "reads": 0, "runs": 0, "read_ms": 0.0,
		"enc_ms": 0.0, "attn_ms": 0.0, "dec_ms": 0.0, "mem_ms": 0.0, "attn_fixed": false,
	}
	frames_done = 0
	frames_total = span + 1
	worst_ms = 0.0
	mean_ms = 0.0
	last_info = {}
	set_process(true)
	return ""


func stop() -> void:
	if running():
		state["stop"] = true


func _process(_delta: float) -> void:
	if not running():
		set_process(false)
		return
	var began: int = Time.get_ticks_msec()
	while running() and Time.get_ticks_msec() - began < STEP_MS:
		if (state["feed"] as Dictionary).is_empty() and Time.get_ticks_msec() - began > STEP_MS / 2:
			break
		if not _step():
			break
	if running():
		progress.emit(frames_done, frames_total)


func _step() -> bool:
	if bool(state.get("stop", false)):
		_land(true, "stopped")
		return false
	var doc: Project = state["doc"]
	var seq: Sequence = state["seq"]
	var clip: Clip = seq.clip_by_id(String(state["clip"])) if seq != null else null
	if doc == null or clip == null:
		_land(false, "the clip went away")
		return false
	var at: int = int(state["at"])
	var read0: float = float(Time.get_ticks_usec()) / 1000.0
	var frame: Image = _frame_at(at)
	state["read_ms"] = float(state.get("read_ms", 0.0)) + float(Time.get_ticks_usec()) / 1000.0 - read0
	if frame == null:
		_land(false, "frame " + str(at) + " could not be read")
		return false
	var t0: float = float(Time.get_ticks_usec()) / 1000.0
	var got: Dictionary = {}
	if not bool(state.get("seeded", false)):
		var seed: Dictionary = state["seed"]
		got = ObjectSelect.pick(frame, seed.get("points", []), seed.get("labels", []), seed.get("box", Rect2(0, 0, 0, 0)), at)
		state["seeded"] = true
	else:
		got = ObjectSelect.follow(frame, at, bool(state["back"]), int(state["count"]))
	var took: float = float(Time.get_ticks_usec()) / 1000.0 - t0
	worst_ms = maxf(worst_ms, took)
	mean_ms = (mean_ms * float(frames_done) + took) / float(frames_done + 1)
	state["enc_ms"] = float(state.get("enc_ms", 0.0)) + float(got.get("ms_enc", 0.0))
	state["attn_ms"] = float(state.get("attn_ms", 0.0)) + float(got.get("ms_attn", 0.0))
	state["dec_ms"] = float(state.get("dec_ms", 0.0)) + float(got.get("ms_dec", 0.0))
	state["mem_ms"] = float(state.get("mem_ms", 0.0)) + float(got.get("ms_mem", 0.0))
	state["attn_fixed"] = bool(got.get("attn_fixed", false))
	if not bool(got.get("ok", false)):
		_land(false, String(got.get("error", "the object could not be followed")))
		return false
	var matte: Image = ObjectSelect.matte_image(got)
	if matte != null:
		var frames: Dictionary = state["frames"]
		frames[at] = matte.save_png_to_buffer()
		state["frames"] = frames
		state["side"] = matte.get_width()
	var area: float = float(got.get("area", 0.0))
	var kind: String = ObjectMask.judge(area, float(got.get("score", 0.0)), float(state.get("last_area", 0.0)))
	state["last_area"] = area
	if not kind.is_empty():
		var marks: Dictionary = state.get("marks", {})
		marks[at] = kind
		state["marks"] = marks
		if kind == ObjectMask.GONE:
			state["gone"] = int(state.get("gone", 0)) + 1
		else:
			state["check"] = int(state.get("check", 0)) + 1
	frames_done += 1
	var last: int = int(state["last"])
	if at == last:
		_land(true, "")
		return false
	state["at"] = at - 1 if bool(state["back"]) else at + 1
	return true


func _time_of(index: int) -> float:
	return maxf(float(state["in_offset"]) + float(index) / float(state["fps"]), 0.0)


func _fill_feed(index: int) -> void:
	var handle: int = int(state["handle"])
	var back: bool = bool(state["back"])
	var last: int = int(state["last"])
	var wanted: PackedInt32Array = PackedInt32Array()
	var step: int = -1 if back else 1
	var at: int = index
	while wanted.size() < BATCH:
		if back and at < last:
			break
		if not back and at > last:
			break
		if at < 0 or at >= int(state["count"]):
			break
		wanted.append(at)
		at += step
	if wanted.is_empty():
		return
	var order: Array[int] = []
	for w: int in wanted:
		order.append(w)
	order.sort()
	var times: PackedFloat64Array = PackedFloat64Array()
	for o: int in order:
		times.append(_time_of(o))
	var got: Array = PurrBridge.snapshot_run(handle, times, FRAME_WIDTH)
	var feed: Dictionary = state["feed"]
	for i: int in mini(got.size(), order.size()):
		if got[i] is Image and not (got[i] as Image).is_empty():
			feed[order[i]] = got[i]
	state["feed"] = feed
	state["runs"] = int(state.get("runs", 0)) + 1


func _frame_at(index: int) -> Image:
	var feed: Dictionary = state["feed"]
	if feed.has(index):
		var kept: Image = feed[index]
		feed.erase(index)
		state["feed"] = feed
		state["reads"] = int(state.get("reads", 0)) + 1
		return kept
	if PurrBridge.has_snapshot_run():
		_fill_feed(index)
		feed = state["feed"]
		if feed.has(index):
			var fresh: Image = feed[index]
			feed.erase(index)
			state["feed"] = feed
			state["reads"] = int(state.get("reads", 0)) + 1
			return fresh
	state["reads"] = int(state.get("reads", 0)) + 1
	return PurrBridge.snapshot(int(state["handle"]), _time_of(index), FRAME_WIDTH)


func _land(ok: bool, why: String) -> void:
	var frames: Dictionary = state.get("frames", {})
	var doc: Project = state.get("doc", null)
	var written: bool = false
	var store_path: String = ""
	if doc != null and not frames.is_empty():
		store_path = ObjectStore.path_for(doc.id, String(state.get("clip", "")), String(state.get("mask", "")))
		written = ObjectStore.merge(store_path, int(state.get("side", ObjectMask.MATTE_SIDE)), frames)
		ObjectMatte.bind(String(state.get("mask", "")), store_path)
		ObjectMatte.forget(String(state.get("mask", "")))
	var marks: Dictionary = state.get("marks", {})
	if doc != null:
		_write_flags(doc, marks)
	last_info = {
		"ok": ok, "error": why, "frames": frames.size(), "from": int(state.get("from", 0)),
		"to": int(state.get("at", 0)), "backward": bool(state.get("back", false)),
		"store": store_path, "written": written, "worst_ms": worst_ms, "mean_ms": mean_ms,
		"gone": int(state.get("gone", 0)), "check": int(state.get("check", 0)),
		"flagged": marks.size(), "reads": int(state.get("reads", 0)), "runs": int(state.get("runs", 0)),
		"read_mean_ms": float(state.get("read_ms", 0.0)) / maxf(float(frames_done), 1.0),
		"enc_mean_ms": float(state.get("enc_ms", 0.0)) / maxf(float(frames_done), 1.0),
		"attn_mean_ms": float(state.get("attn_ms", 0.0)) / maxf(float(frames_done), 1.0),
		"dec_mean_ms": float(state.get("dec_ms", 0.0)) / maxf(float(frames_done), 1.0),
		"mem_mean_ms": float(state.get("mem_ms", 0.0)) / maxf(float(frames_done), 1.0),
		"attn_fixed": bool(state.get("attn_fixed", false)),
	}
	state = {}
	set_process(false)
	progress.emit(frames_done, frames_total)
	finished.emit(ok, last_info)


func _write_flags(doc: Project, marks: Dictionary) -> void:
	var seq: Sequence = state.get("seq", null)
	var clip: Clip = seq.clip_by_id(String(state.get("clip", ""))) if seq != null else null
	if clip == null:
		return
	var from: int = int(state.get("from", 0))
	var at: int = int(state.get("at", 0))
	var m: Dictionary = {}
	for one: Dictionary in clip.masks:
		if ObjectMask.is_object(one) and str(one.get("id", "")) == String(state.get("mask", "")):
			m = one
			break
	if m.is_empty():
		return
	var was: Dictionary = (m.get("flags", {}) as Dictionary).duplicate()
	ObjectMask.clear_flags(m, mini(from, at), maxi(from, at))
	for k: Variant in marks.keys():
		ObjectMask.put_flag(m, int(k), str(marks[k]))
	if m.get("flags", {}) != was:
		doc.dirty = true
		if seq != null:
			seq.invalidate()


static func _object_of(clip: Clip) -> Dictionary:
	if clip == null:
		return {}
	for m: Dictionary in clip.masks:
		if ObjectMask.is_object(m):
			return m
	return {}
