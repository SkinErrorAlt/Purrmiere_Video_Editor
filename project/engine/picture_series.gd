extends Node

const SELF_PATH := "res://engine/picture_series.gd"
const TICKER_NAME := "PictureSeries"
const Parenting := preload("res://doc/parenting.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const WIDTH := 32
const HEIGHT := 18
const POLL_MS := 120
const MAX_ENTRIES := 48
const MEASURED_MAX := 256
const BUILD_BUDGET_MS := 6
const SCREEN_DIR := "user://purrseek/screen"
const SCREEN_MAGIC := "PSCR"
const SCREEN_VERSION := 1
const SLOT_EPS := 0.000001
const MEASURES: PackedStringArray = ["colour", "bright", "sat", "hue", "red", "green", "blue", "motion", "cx", "cy"]
const KEEP_LAST: PackedStringArray = ["hue", "cx", "cy"]

static var _entries: Dictionary = {}
static var _measured: Dictionary = {}
static var _sigs: Dictionary = {}
static var _ticker: Node = null
static var _waiters: Dictionary = {}
static var _touched: Dictionary = {}
static var serial: int = 0
static var repaints: int = 0
static var requests: int = 0
static var screen_frames: int = 0
static var screen_loads: int = 0


static func bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
	if b == null or not b.has_method("has_pictures") or not bool(b.call("has_pictures")):
		return null
	return b


static func available() -> bool:
	return bridge() != null


static func measure_index(name: String) -> int:
	return maxi(MEASURES.find(name), 0)


static func _blank(key: String, kind: String, rate: int) -> Dictionary:
	return {"key": key, "kind": kind, "id": -1, "path": "", "rate": rate, "w": WIDTH, "h": HEIGHT, "count": 0, "done": false, "failed": false, "error": "", "pixels": PackedByteArray(), "serial": 0, "pulled_ms": -1000000, "from_disk": false}


static func entry(path: String, rate: int) -> Dictionary:
	var r: int = clampi(rate, 1, 240)
	var key: String = "file|" + path + "|" + str(r)
	var hit: Variant = _entries.get(key, null)
	if hit is Dictionary:
		var he: Dictionary = hit
		if not bool(he["done"]):
			_pull(he, false)
		return he
	var e: Dictionary = _blank(key, "file", r)
	e["path"] = path
	var b: Node = bridge()
	if b == null or path.is_empty() or not FileAccess.file_exists(path):
		e["done"] = true
		e["failed"] = true
		e["error"] = "no picture engine" if b == null else "the file is missing"
	else:
		if _entries.size() >= MAX_ENTRIES:
			_evict()
		e["id"] = int(b.call("picture_request", path, r, WIDTH, HEIGHT))
		requests += 1
		if int(e["id"]) < 0:
			e["done"] = true
			e["failed"] = true
			e["error"] = "the picture reading could not start"
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
				b.call("picture_forget", int(old["id"]))
			_entries.erase(k)
			return


static func forget_all() -> void:
	var b: Node = bridge()
	for k: Variant in _entries.keys():
		var old: Dictionary = _entries[k]
		if b != null and int(old["id"]) >= 0:
			b.call("picture_forget", int(old["id"]))
	_entries = {}
	_measured = {}
	_sigs = {}
	_waiters = {}
	_touched = {}
	serial += 1


static func _pull(e: Dictionary, force: bool) -> bool:
	if bool(e["done"]):
		return false
	if String(e["kind"]) == "screen":
		return _advance_screen(e, BUILD_BUDGET_MS if not force else BUILD_BUDGET_MS * 4)
	if int(e["id"]) < 0:
		return false
	var now: int = Time.get_ticks_msec()
	if not force and now - int(e["pulled_ms"]) < POLL_MS:
		return false
	e["pulled_ms"] = now
	var b: Node = bridge()
	if b == null:
		return false
	var got: Dictionary = b.call("picture_read", int(e["id"]), int(e["count"]))
	var fresh: PackedByteArray = got["pixels"]
	var grew: bool = false
	if int(got["width"]) > 0:
		e["w"] = int(got["width"])
		e["h"] = int(got["height"])
	if not fresh.is_empty():
		var px: PackedByteArray = e["pixels"]
		px.append_array(fresh)
		e["pixels"] = px
		e["count"] = px.size() / maxi(int(e["w"]) * int(e["h"]) * 3, 1)
		grew = true
	if bool(got["done"]):
		e["done"] = true
		e["failed"] = bool(got["failed"])
		e["error"] = String(got["error"])
		e["from_disk"] = bool(got["from_disk"])
		grew = true
	if grew:
		e["serial"] = int(e["serial"]) + 1
		serial += 1
	return grew


static func wait_done(key: String, timeout_ms: int) -> bool:
	var t0: int = Time.get_ticks_msec()
	var e: Variant = _entries.get(key, null)
	while e is Dictionary and not bool((e as Dictionary)["done"]):
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return false
		if String((e as Dictionary)["kind"]) != "screen":
			OS.delay_msec(5)
		_pull(e, true)
		if String((e as Dictionary)["kind"]) == "screen" and not bool((e as Dictionary)["done"]):
			for k: Variant in _entries.keys():
				var other: Dictionary = _entries[k]
				if String(other["kind"]) == "file" and not bool(other["done"]):
					OS.delay_msec(5)
					_pull(other, true)
	return e is Dictionary


static func building() -> bool:
	for k: Variant in _entries.keys():
		if not bool((_entries[k] as Dictionary)["done"]):
			return true
	return false


static func note_waiting(comp: Node, key: String) -> void:
	if comp == null or not is_instance_valid(comp):
		_ensure_ticker()
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


static func spec_sig(spec: Dictionary) -> String:
	var col: Color = spec.get("colour", Color(0.0, 1.0, 0.0))
	var reg: Rect2 = spec.get("region", Rect2(0.0, 0.0, 1.0, 1.0))
	return "%d|%s|%s|%s,%s,%s,%s" % [int(spec.get("measure", 0)), col.to_html(false), str(snappedf(float(spec.get("tol", 0.3)), 0.0001)), str(snappedf(reg.position.x, 0.0001)), str(snappedf(reg.position.y, 0.0001)), str(snappedf(reg.size.x, 0.0001)), str(snappedf(reg.size.y, 0.0001))]


static func measured(e: Dictionary, spec: Dictionary) -> PackedFloat32Array:
	var mkey: String = String(e["key"]) + "#" + spec_sig(spec)
	var count: int = int(e["count"])
	var hit: Variant = _measured.get(mkey, null)
	var values: PackedFloat32Array = PackedFloat32Array()
	if hit is Dictionary:
		values = (hit as Dictionary)["values"]
		if values.size() >= count:
			return values
	var b: Node = bridge()
	var w: int = int(e["w"])
	var h: int = int(e["h"])
	var fb: int = w * h * 3
	var from: int = values.size()
	if from < count and b != null and b.has_method("picture_measure") and fb > 0:
		var px: PackedByteArray = e["pixels"]
		var send: Dictionary = {"measure": int(spec.get("measure", 0)), "colour": spec.get("colour", Color(0.0, 1.0, 0.0)), "tol": float(spec.get("tol", 0.3)), "region": spec.get("region", Rect2(0.0, 0.0, 1.0, 1.0))}
		if from > 0:
			send["prev"] = px.slice((from - 1) * fb, from * fb)
		var fresh: PackedFloat32Array = b.call("picture_measure", px.slice(from * fb, count * fb), w, h, send)
		var keep: bool = KEEP_LAST.has(MEASURES[clampi(int(spec.get("measure", 0)), 0, MEASURES.size() - 1)])
		var last: float = values[from - 1] if from > 0 else 50.0
		if keep and from == 0 and int(spec.get("measure", 0)) == measure_index("hue"):
			last = 0.0
		for i: int in fresh.size():
			var v: float = fresh[i]
			if keep and v < 0.0:
				v = last
			last = v
			values.append(v)
	if _measured.size() >= MEASURED_MAX:
		_measured = {}
	_measured[mkey] = {"values": values}
	return values


static func slot_of(e: Dictionary, at: float) -> int:
	var n: int = int(e["count"])
	if n <= 0:
		return -1
	if n == 1:
		return 0
	return clampi(int(floor(at * float(int(e["rate"])) + SLOT_EPS)), 0, n - 1)


static func screen_sig(doc: Object, seq: Object, owner: Object, rate: int) -> String:
	var dserial: int = int(doc.get("serial")) if doc != null else 0
	var memo_key: String = str(dserial) + "|" + String(owner.get("id")) + "|" + str(rate)
	var hit: Variant = _sigs.get(memo_key, null)
	if hit is String:
		return hit
	var parts: Array = [SCREEN_VERSION, String(seq.get("id")), int(seq.get("width")), int(seq.get("height")), rate, String(owner.get("id")), snappedf(float(owner.get("start")), 0.0001), snappedf(float(owner.get("duration")), 0.0001)]
	var tracks: Array = seq.call("picture_tracks")
	var oi: int = owner_track(tracks, owner)
	var o_start: float = float(owner.get("start"))
	var o_end: float = o_start + float(owner.get("duration"))
	for ti: int in maxi(oi, 0):
		var tr: Object = tracks[ti]
		parts.append([ti, bool(tr.get("muted"))])
		for cv: Variant in tr.get("clips"):
			var c: Object = cv
			var cs: float = float(c.get("start"))
			if cs >= o_end or cs + float(c.get("duration")) <= o_start:
				continue
			var m: Object = doc.call("media_by_id", String(c.get("media_id")))
			var mp: String = String(m.get("path")) if m != null else ""
			parts.append([String(c.get("id")), String(c.get("media_id")), mp, FileAccess.get_modified_time(mp) if not mp.is_empty() and FileAccess.file_exists(mp) else 0, snappedf(cs, 0.0001), snappedf(float(c.get("duration")), 0.0001), snappedf(float(c.get("in_offset")), 0.0001), c.get("speed"), c.get("transform"), bool(c.get("enabled")), c.get("parent"), m.get("props") if m != null else {}, c.get("props")])
	var sig: String = "%08x%08x" % [str(parts).hash() & 0xffffffff, str(parts).sha256_text().hash() & 0xffffffff]
	if _sigs.size() > 512:
		_sigs = {}
	_sigs[memo_key] = sig
	return sig


static func owner_track(tracks: Array, owner: Object) -> int:
	for ti: int in tracks.size():
		if (tracks[ti] as Object).get("clips").has(owner):
			return ti
	return -1


static func screen(doc: Object, seq: Object, owner: Object, rate: int) -> Dictionary:
	var r: int = clampi(rate, 1, 240)
	var sig: String = screen_sig(doc, seq, owner, r)
	var key: String = "screen|" + sig
	var hit: Variant = _entries.get(key, null)
	if hit is Dictionary:
		return hit
	var e: Dictionary = _blank(key, "screen", r)
	var first: int = int(floor(float(owner.get("start")) * float(r) + SLOT_EPS))
	var last: int = int(ceil((float(owner.get("start")) + float(owner.get("duration"))) * float(r) - SLOT_EPS))
	e["first"] = first
	e["slots"] = maxi(last - first, 1)
	e["doc"] = weakref(doc)
	e["seq"] = weakref(seq)
	e["owner"] = weakref(owner)
	e["path"] = ProjectSettings.globalize_path(SCREEN_DIR).path_join(sig + ".bin")
	if _entries.size() >= MAX_ENTRIES:
		_evict()
	_entries[key] = e
	if not _load_screen(e):
		_ensure_ticker()
	return e


static func _load_screen(e: Dictionary) -> bool:
	var path: String = String(e["path"])
	if not FileAccess.file_exists(path):
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var ok: bool = f.get_buffer(4).get_string_from_ascii() == SCREEN_MAGIC
	ok = ok and int(f.get_32()) == SCREEN_VERSION
	ok = ok and int(f.get_32()) == WIDTH and int(f.get_32()) == HEIGHT
	var n: int = int(f.get_32()) if ok else 0
	ok = ok and n == int(e["slots"])
	var px: PackedByteArray = f.get_buffer(n * WIDTH * HEIGHT * 3) if ok else PackedByteArray()
	f.close()
	if not ok or px.size() != n * WIDTH * HEIGHT * 3:
		return false
	e["pixels"] = px
	e["count"] = n
	e["done"] = true
	e["from_disk"] = true
	e["serial"] = int(e["serial"]) + 1
	serial += 1
	screen_loads += 1
	return true


static func _save_screen(e: Dictionary) -> void:
	var path: String = String(e["path"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(SCREEN_MAGIC.to_ascii_buffer())
	f.store_32(SCREEN_VERSION)
	f.store_32(WIDTH)
	f.store_32(HEIGHT)
	f.store_32(int(e["count"]))
	f.store_buffer(e["pixels"])
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(path + ".part", path)


static func _advance_screen(e: Dictionary, budget_ms: int) -> bool:
	var doc: Object = (e["doc"] as WeakRef).get_ref()
	var seq: Object = (e["seq"] as WeakRef).get_ref()
	var owner: Object = (e["owner"] as WeakRef).get_ref()
	if doc == null or seq == null or owner == null:
		e["done"] = true
		e["failed"] = true
		e["error"] = "the sequence is gone"
		return true
	var t0: int = Time.get_ticks_msec()
	var grew: bool = false
	var rate: float = float(int(e["rate"]))
	var px: PackedByteArray = e["pixels"]
	while int(e["count"]) < int(e["slots"]):
		var at: float = float(int(e["first"]) + int(e["count"])) / rate
		var got: Dictionary = compose(doc, seq, owner, at, int(e["rate"]))
		if not bool(got["ok"]):
			break
		px.append_array(got["bytes"])
		e["count"] = int(e["count"]) + 1
		screen_frames += 1
		grew = true
		if Time.get_ticks_msec() - t0 >= budget_ms:
			break
	e["pixels"] = px
	if int(e["count"]) >= int(e["slots"]):
		e["done"] = true
		_save_screen(e)
		grew = true
	if grew:
		e["serial"] = int(e["serial"]) + 1
		serial += 1
	return grew


static func compose(doc: Object, seq: Object, owner: Object, at: float, rate: int) -> Dictionary:
	var out: PackedByteArray = PackedByteArray()
	out.resize(WIDTH * HEIGHT * 3)
	out.fill(0)
	var tracks: Array = seq.call("picture_tracks")
	var oi: int = owner_track(tracks, owner)
	var size: Vector2 = Vector2(float(int(seq.get("width"))), float(int(seq.get("height"))))
	var fps: float = float(seq.get("fps"))
	for ti: int in maxi(oi, 0):
		var tr: Object = tracks[ti]
		if bool(tr.get("muted")):
			continue
		for cv: Variant in tr.call("clips_at", at):
			var c: Object = cv
			if c == owner or not bool(c.get("enabled")):
				continue
			var m: Object = doc.call("media_by_id", String(c.get("media_id")))
			if m == null:
				continue
			var kind: String = String(m.get("kind"))
			var frame: PackedByteArray = PackedByteArray()
			var fw: int = 0
			var fh: int = 0
			var solid: Color = Color(0, 0, 0, 0)
			if kind == "video" or kind == "image":
				var pe: Dictionary = entry(String(m.get("path")), rate)
				if bool(pe["failed"]):
					continue
				var slot: int = 0 if kind == "image" else int(floor(float(c.call("source_time", at)) * float(rate) + SLOT_EPS))
				if slot >= int(pe["count"]):
					if not bool(pe["done"]):
						return {"ok": false, "bytes": PackedByteArray()}
					slot = int(pe["count"]) - 1
				if slot < 0:
					continue
				fw = int(pe["w"])
				fh = int(pe["h"])
				frame = (pe["pixels"] as PackedByteArray).slice(slot * fw * fh * 3, (slot + 1) * fw * fh * 3)
			elif kind == "generator":
				var merged: Dictionary = TitleStyle.merged("generator", m.get("props"), c.call("props_at", at - float(c.get("start")), fps))
				solid = TitleStyle.colour_of(merged.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
			else:
				continue
			_draw_layer(out, size, doc, seq, c, m, at, fps, frame, fw, fh, solid)
	return {"ok": true, "bytes": out}


static func _draw_layer(out: PackedByteArray, size: Vector2, _doc: Object, seq: Object, c: Object, m: Object, at: float, fps: float, frame: PackedByteArray, fw: int, fh: int, solid: Color) -> void:
	var base: Vector2 = size
	if int(m.get("width")) > 0 and int(m.get("height")) > 0:
		base = Vector2(float(int(m.get("width"))), float(int(m.get("height"))))
	var lsize: Vector2 = PairLayout.picture_size(c, base, size)
	var tf: Dictionary = Parenting.world_tf(c, seq, at, fps)
	var opacity: float = clampf(float(tf.get("opacity", 1.0)), 0.0, 1.0)
	if opacity <= 0.0 or lsize.x <= 0.0 or lsize.y <= 0.0:
		return
	var pivot: Vector2 = lsize * 0.5 + (tf["anchor"] as Vector2)
	var centre: Vector2 = size * 0.5 + (tf["pos"] as Vector2)
	var xf: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, centre) * Transform2D(0.0, -pivot)
	if absf(xf.determinant()) < 0.0000001:
		return
	var inv: Transform2D = xf.affine_inverse()
	var use_frame: bool = fw > 0 and fh > 0 and frame.size() >= fw * fh * 3
	var alpha: float = opacity * (solid.a if not use_frame else 1.0)
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var sp: Vector2 = Vector2((float(x) + 0.5) / float(WIDTH) * size.x, (float(y) + 0.5) / float(HEIGHT) * size.y)
			var lp: Vector2 = inv * sp
			var u: float = lp.x / lsize.x
			var v: float = lp.y / lsize.y
			if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
				continue
			var o: int = (y * WIDTH + x) * 3
			var r: float = solid.r * 255.0
			var g: float = solid.g * 255.0
			var b: float = solid.b * 255.0
			if use_frame:
				var k: int = (mini(int(v * float(fh)), fh - 1) * fw + mini(int(u * float(fw)), fw - 1)) * 3
				r = float(frame[k])
				g = float(frame[k + 1])
				b = float(frame[k + 2])
			out[o] = int(roundf(lerpf(float(out[o]), r, alpha)))
			out[o + 1] = int(roundf(lerpf(float(out[o + 1]), g, alpha)))
			out[o + 2] = int(roundf(lerpf(float(out[o + 2]), b, alpha)))


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
