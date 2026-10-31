extends Node

const SELF_PATH := "res://engine/sound_envelopes.gd"
const TICKER_NAME := "SoundEnvelopes"
const RATE := 200
const POLL_MS := 120
const SPECTRUM_BANDS := 16
const SPECTRUM_LOW := 40.0
const SPECTRUM_HIGH := 16000.0
const BAND_EDGES: Array = [[0.0, 0.0], [20.0, 250.0], [250.0, 1000.0], [1000.0, 4000.0], [4000.0, 16000.0]]
const MAX_ENTRIES := 64
const MAX_BANDS := 64
const PEAKS_THREAD_MIN := 200000

static var _entries: Dictionary = {}
static var _ticker: Node = null
static var _waiters: Dictionary = {}
static var _touched: Dictionary = {}
static var serial: int = 0
static var repaints: int = 0
static var requests: int = 0
static var _plant_drop_tail: bool = false
static var _peak_mutex: Mutex = Mutex.new()
static var _peak_box: Dictionary = {}
static var peak_jobs: int = 0
static var pull_usec: int = 0
static var _spec_edges: Dictionary = {}
static var _keys: Dictionary = {}


static func bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
	if b == null or not b.has_method("has_envelopes") or not bool(b.call("has_envelopes")):
		return null
	return b


static func available() -> bool:
	return bridge() != null


static func band_edges(band: int, low: float, high: float) -> PackedFloat64Array:
	if band >= 0 and band < BAND_EDGES.size():
		var pair: Array = BAND_EDGES[band]
		return PackedFloat64Array([float(pair[0]), float(pair[1])])
	var lo: float = clampf(minf(low, high), 0.0, 20000.0)
	var hi: float = clampf(maxf(low, high), 0.0, 20000.0)
	return PackedFloat64Array([roundf(lo), roundf(hi)])


static func spectrum_edges(count: int = SPECTRUM_BANDS) -> PackedFloat64Array:
	var n: int = clampi(count, 1, MAX_BANDS)
	var hit: Variant = _spec_edges.get(n, null)
	if hit is PackedFloat64Array:
		return (hit as PackedFloat64Array).duplicate()
	var out: PackedFloat64Array = PackedFloat64Array()
	var ratio: float = SPECTRUM_HIGH / SPECTRUM_LOW
	for i: int in n:
		out.append(roundf(SPECTRUM_LOW * pow(ratio, float(i) / float(n))))
		out.append(roundf(SPECTRUM_LOW * pow(ratio, float(i + 1) / float(n))))
	_spec_edges[n] = out.duplicate()
	return out


static func key_of(path: String, stream: int, edges: PackedFloat64Array) -> String:
	var short: String = path + "|" + str(stream) + "|" + str(edges.size()) + ":" + str(hash(edges))
	var hit: Variant = _keys.get(short, null)
	if hit is String:
		return hit
	var parts: PackedStringArray = PackedStringArray([path, str(stream)])
	for e: float in edges:
		parts.append(str(int(e)))
	var out: String = "|".join(parts)
	if _keys.size() >= 1024:
		_keys = {}
	_keys[short] = out
	return out


static func entry(path: String, stream: int, edges: PackedFloat64Array) -> Dictionary:
	var key: String = key_of(path, stream, edges)
	var hit: Variant = _entries.get(key, null)
	if hit is Dictionary:
		var he: Dictionary = hit
		if not bool(he["done"]):
			_pull(he, false)
		return he
	var b: Node = bridge()
	var bands: int = maxi(edges.size() / 2, 1)
	var e: Dictionary = {"key": key, "id": -1, "path": path, "stream": stream, "bands": bands, "count": 0, "done": false, "failed": false, "values": PackedFloat32Array(), "peaks": PackedFloat32Array(), "serial": 0, "pulled_ms": -1000000, "error": ""}
	var peaks: PackedFloat32Array = PackedFloat32Array()
	peaks.resize(bands)
	e["peaks"] = peaks
	if b == null or path.is_empty() or not FileAccess.file_exists(path):
		e["done"] = true
		e["failed"] = true
		e["error"] = "no sound engine" if b == null else "the file is missing"
	else:
		if _entries.size() >= MAX_ENTRIES:
			_evict()
		e["id"] = int(b.call("envelope_request", path, stream, edges, RATE))
		requests += 1
		if int(e["id"]) < 0:
			e["done"] = true
			e["failed"] = true
			e["error"] = "the envelope could not start"
		else:
			_pull(e, true)
	_entries[key] = e
	if not bool(e["done"]):
		_ensure_ticker()
	return e


static func _evict() -> void:
	var b: Node = bridge()
	for k: Variant in _entries.keys():
		var old: Dictionary = _entries[k]
		if bool(old["done"]):
			if b != null and int(old["id"]) >= 0:
				b.call("envelope_forget", int(old["id"]))
			_entries.erase(k)
			return


static func forget_all() -> void:
	var b: Node = bridge()
	for k: Variant in _entries.keys():
		var old: Dictionary = _entries[k]
		_collect_peaks(old, true)
		if b != null and int(old["id"]) >= 0:
			b.call("envelope_forget", int(old["id"]))
	_entries = {}
	_waiters = {}
	_touched = {}
	serial += 1


static func _peaks_of(fresh: PackedFloat32Array, bands: int) -> PackedFloat32Array:
	var peaks: PackedFloat32Array = PackedFloat32Array()
	peaks.resize(bands)
	var n: int = fresh.size() / maxi(bands, 1)
	for i: int in n:
		for k: int in bands:
			var v: float = fresh[i * bands + k]
			if v > peaks[k]:
				peaks[k] = v
	return peaks


static func _peak_work(job: String, fresh: PackedFloat32Array, bands: int) -> void:
	var got: PackedFloat32Array = _peaks_of(fresh, bands)
	_peak_mutex.lock()
	_peak_box[job] = got
	_peak_mutex.unlock()


static func _merge_peaks(e: Dictionary, got: PackedFloat32Array) -> void:
	var peaks: PackedFloat32Array = e["peaks"]
	for k: int in mini(peaks.size(), got.size()):
		if got[k] > peaks[k]:
			peaks[k] = got[k]
	e["peaks"] = peaks


static func _collect_peaks(e: Dictionary, wait: bool) -> bool:
	var jobs: Array = e.get("peak_jobs", [])
	if jobs.is_empty():
		return true
	var left: Array = []
	for j: Variant in jobs:
		var pair: Array = j
		var id: int = int(pair[0])
		if not wait and not WorkerThreadPool.is_task_completed(id):
			left.append(pair)
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		_peak_mutex.lock()
		var got: Variant = _peak_box.get(String(pair[1]), null)
		_peak_box.erase(String(pair[1]))
		_peak_mutex.unlock()
		if got is PackedFloat32Array:
			_merge_peaks(e, got)
	e["peak_jobs"] = left
	return left.is_empty()


static func _pull(e: Dictionary, force: bool) -> bool:
	if bool(e["done"]) or int(e["id"]) < 0:
		return false
	var t0: int = Time.get_ticks_usec()
	var now: int = Time.get_ticks_msec()
	if not force and now - int(e["pulled_ms"]) < POLL_MS:
		return false
	e["pulled_ms"] = now
	var b: Node = bridge()
	if b == null:
		return false
	var grew: bool = false
	if not bool(e.get("native_done", false)):
		var got: Dictionary = b.call("envelope_read", int(e["id"]), int(e["count"]))
		var fresh: PackedFloat32Array = got["values"]
		var bands: int = int(e["bands"])
		if not fresh.is_empty():
			if fresh.size() >= PEAKS_THREAD_MIN:
				peak_jobs += 1
				var job: String = String(e["key"]) + "#" + str(peak_jobs)
				var jobs: Array = e.get("peak_jobs", [])
				jobs.append([WorkerThreadPool.add_task(Callable(load(SELF_PATH), "_peak_work").bind(job, fresh, bands), false, "Sound peaks"), job])
				e["peak_jobs"] = jobs
			else:
				_merge_peaks(e, _peaks_of(fresh, bands))
			var values: PackedFloat32Array = e["values"]
			e["values"] = PackedFloat32Array()
			values.append_array(fresh)
			e["values"] = values
			e["count"] = values.size() / bands
			grew = true
		if bool(got["done"]):
			e["native_done"] = true
			e["failed"] = bool(got["failed"])
			e["error"] = String(got["error"])
			if _plant_drop_tail and int(e["count"]) > 4:
				var cut: PackedFloat32Array = e["values"]
				cut.resize((int(e["count"]) - 4) * bands)
				e["values"] = cut
				e["count"] = cut.size() / bands
			grew = true
	if bool(e.get("native_done", false)) and _collect_peaks(e, false):
		e["done"] = true
		grew = true
	if grew:
		e["serial"] = int(e["serial"]) + 1
		serial += 1
	pull_usec += Time.get_ticks_usec() - t0
	return grew


static func building() -> bool:
	for k: Variant in _entries.keys():
		if not bool((_entries[k] as Dictionary)["done"]):
			return true
	return false


static func wait_done(key: String, timeout_ms: int) -> bool:
	var t0: int = Time.get_ticks_msec()
	var e: Variant = _entries.get(key, null)
	while e is Dictionary and not bool((e as Dictionary)["done"]):
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return false
		if bool((e as Dictionary).get("native_done", false)):
			_collect_peaks(e, true)
		else:
			OS.delay_msec(5)
		_pull(e, true)
	return e is Dictionary


static func note_waiting(comp: Node, key: String) -> void:
	if comp == null:
		return
	var id: int = comp.get_instance_id()
	_waiters[id] = weakref(comp)
	var keys: Dictionary = _touched.get(id, {})
	keys[key] = true
	_touched[id] = keys
	_ensure_ticker()


static func pending_for(comp: Node) -> bool:
	if comp == null:
		return false
	var id: int = comp.get_instance_id()
	var keys: Dictionary = _touched.get(id, {})
	if keys.is_empty():
		return false
	var still: Dictionary = {}
	for k: Variant in keys.keys():
		var e: Variant = _entries.get(k, null)
		if e is Dictionary and not bool((e as Dictionary)["done"]):
			_pull(e, true)
			if not bool((e as Dictionary)["done"]):
				still[k] = true
	if still.is_empty():
		_touched.erase(id)
		return false
	_touched[id] = still
	return true


static func _ensure_ticker() -> void:
	if _ticker != null and is_instance_valid(_ticker) and _ticker.is_inside_tree():
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	var have: Node = root.get_node_or_null(TICKER_NAME)
	if have != null:
		_ticker = have
		return
	var t: Node = (load(SELF_PATH) as GDScript).new()
	t.name = TICKER_NAME
	root.add_child.call_deferred(t)
	_ticker = t


func _ready() -> void:
	set_process(true)


func _process(_dt: float) -> void:
	var grew: bool = false
	for k: Variant in _entries.keys():
		var e: Dictionary = _entries[k]
		if not bool(e["done"]) and _pull(e, false):
			grew = true
	if grew:
		_repaint()


static func _repaint() -> void:
	var list: Array = _waiters.values()
	_waiters = {}
	for w: Variant in list:
		var comp: Variant = (w as WeakRef).get_ref()
		if comp == null or not is_instance_valid(comp):
			continue
		var c: Node = comp
		if bool(c.get("playing")) or not c.has_method("render_time"):
			continue
		repaints += 1
		c.call_deferred("render_time", float(c.get("last_time")), bool(c.get("last_exact")))
