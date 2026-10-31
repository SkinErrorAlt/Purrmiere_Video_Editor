extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AudioReact := preload("res://engine/audio_react.gd")
const SoundEnvelopes := preload("res://engine/sound_envelopes.gd")
const PictureSeries := preload("res://engine/picture_series.gd")
const ReactShape := preload("res://engine/react_shape.gd")
const DRIVER := "res://doc/anim_driver.gd"
const KIND_VALUE := "value"
const KIND_SOUND := "sound"
const KIND_PICTURE := "picture"
const PIC_OWN := "own"
const PIC_CLIP := "clip"
const PIC_MEDIA := "media"
const PIC_SCREEN := "screen"
const PIC_NONE := "none"
const SHAPED_MAX := 128
const REBUILD_MS := 250
const VALUE_SERIES_MAX := 32
const SLOT_EPS := 0.000001
const DEFAULT_RATE := 30
const MEASURE_LABELS: Dictionary = {
	"colour": "Amount of a colour", "bright": "Brightness", "sat": "Saturation", "hue": "Hue of the main colour",
	"red": "Red", "green": "Green", "blue": "Blue", "motion": "Motion", "cx": "Centre of a colour, across", "cy": "Centre of a colour, down",
}
const MEASURE_UNITS: Dictionary = {"hue": " °"}

static var _shaped: Dictionary = {}
static var _values: Dictionary = {}
static var _parsed: Dictionary = {}
static var _comp: WeakRef = null
static var reads: int = 0
static var builds: int = 0
static var _plant_skip_hold: bool = false


static func reading(comp: Node) -> void:
	_comp = weakref(comp) if comp != null else null


static func current_comp() -> Node:
	if _comp == null:
		return null
	var c: Variant = _comp.get_ref()
	return c if c is Node and is_instance_valid(c) else null


static func forget() -> void:
	_shaped = {}
	_values = {}
	_parsed = {}


static func pic_encode(src: Dictionary) -> String:
	var kind: String = String(src.get("kind", PIC_OWN))
	if kind == PIC_OWN:
		return ""
	if kind == PIC_NONE or kind == PIC_SCREEN:
		return JSON.stringify({"kind": kind})
	if kind == PIC_CLIP:
		return JSON.stringify({"kind": PIC_CLIP, "clip": String(src.get("clip", ""))})
	if kind == PIC_MEDIA:
		return JSON.stringify({"kind": PIC_MEDIA, "media": String(src.get("media", "")), "in": snappedf(float(src.get("in", 0.0)), 0.0001), "out": snappedf(float(src.get("out", -1.0)), 0.0001)})
	return ""


static func pic_parse(text: String) -> Dictionary:
	var hit: Variant = _parsed.get(text, null)
	if hit is Dictionary:
		return hit
	var out: Dictionary = {"kind": PIC_OWN}
	var raw: Variant = JSON.parse_string(text) if not text.strip_edges().is_empty() else null
	if raw is Dictionary:
		var d: Dictionary = raw
		var kind: String = String(d.get("kind", PIC_OWN))
		if kind == PIC_CLIP:
			out = {"kind": PIC_CLIP, "clip": String(d.get("clip", ""))}
		elif kind == PIC_MEDIA:
			out = {"kind": PIC_MEDIA, "media": String(d.get("media", "")), "in": float(d.get("in", 0.0)), "out": float(d.get("out", -1.0))}
		elif kind == PIC_SCREEN or kind == PIC_NONE:
			out = {"kind": kind}
	if _parsed.size() > 1024:
		_parsed = {}
	_parsed[text] = out
	return out


static func pic_from_payload(doc: Object, payload: Dictionary) -> String:
	var kind: String = String(payload.get("kind", ""))
	if kind == "clip":
		var ids: Array = payload.get("ids", [])
		var cid: String = String(ids[0]) if not ids.is_empty() else String(payload.get("id", ""))
		return pic_encode({"kind": PIC_CLIP, "clip": cid}) if not cid.is_empty() else ""
	if kind != "media":
		return ""
	var mids: Array = payload.get("ids", [])
	var mid: String = String(mids[0]) if not mids.is_empty() else String(payload.get("id", ""))
	if mid.is_empty():
		return ""
	var a: float = float(payload.get("in", -1.0))
	var b: float = float(payload.get("out", -1.0))
	if doc != null and doc.call("media_by_id", mid) == null:
		return ""
	return pic_encode({"kind": PIC_MEDIA, "media": mid, "in": maxf(a, 0.0), "out": b if b > maxf(a, 0.0) else -1.0})


static func _has_picture(m: Object) -> bool:
	if m == null:
		return false
	var kind: String = String(m.get("kind"))
	return kind == "video" or kind == "image"


static func pic_resolve(doc: Object, owner: Object, text: String, t: float) -> Dictionary:
	var out: Dictionary = {"ok": false, "path": "", "at": 0.0, "still": false, "label": "No picture", "kind": PIC_NONE}
	if doc == null or owner == null:
		return out
	var src: Dictionary = pic_parse(text)
	var kind: String = String(src["kind"])
	out["kind"] = kind
	if kind == PIC_NONE:
		return out
	if kind == PIC_SCREEN:
		out["ok"] = true
		out["label"] = "The screen under this clip"
		out["at"] = t
		return out
	if kind == PIC_OWN or kind == PIC_CLIP:
		var c: Object = owner
		if kind == PIC_CLIP:
			c = doc.call("clip_by_id", String(src.get("clip", "")))
			if c == null:
				out["label"] = "The clip is gone"
				return out
		var m: Object = doc.call("media_by_id", String(c.get("media_id")))
		if not _has_picture(m):
			out["label"] = "No picture in this clip" if kind == PIC_OWN else "That clip has no picture"
			return out
		out["path"] = String(m.get("path"))
		out["still"] = String(m.get("kind")) == "image"
		var name: String = String(c.get("label")) if not String(c.get("label")).is_empty() else String(m.get("label"))
		out["label"] = ("This clip: " if kind == PIC_OWN else "Clip: ") + name
		var st: float = float(c.get("start"))
		var en: float = st + float(c.get("duration"))
		out["at"] = -1.0 if (t < st or t >= en) else float(c.call("source_time", t))
		out["ok"] = true
		return out
	var mm: Object = doc.call("media_by_id", String(src.get("media", "")))
	if not _has_picture(mm):
		out["label"] = "That media has no picture" if mm != null else "The media is gone"
		return out
	out["path"] = String(mm.get("path"))
	out["still"] = String(mm.get("kind")) == "image"
	var a: float = maxf(float(src.get("in", 0.0)), 0.0)
	var b: float = float(src.get("out", -1.0))
	var at: float = a + (t - float(owner.get("start")))
	if at < a or (b > a and at > b):
		at = -1.0
	out["at"] = at
	out["label"] = "Media: " + String(mm.get("label"))
	out["ok"] = true
	return out


static func rate_of(doc: Object, owner: Object) -> int:
	if doc == null or owner == null:
		return DEFAULT_RATE
	var s: Object = doc.call("sequence_of_clip", String(owner.get("id")))
	if s == null:
		return DEFAULT_RATE
	return clampi(int(roundf(float(s.get("fps")))), 1, 240)


static func shaping_sig(layer: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [str(snappedf(float(layer.get("attack", 0.0)), 0.001)), str(snappedf(float(layer.get("release", 0.0)), 0.001)), str(snappedf(float(layer.get("hold", 0.0)), 0.00001)), str(snappedf(AnimProp.driven_in(layer, "in_min", 0.0), 0.00001)), str(snappedf(AnimProp.driven_in(layer, "in_max", 1.0), 0.00001))]


static func process(values: PackedFloat32Array, rate: float, layer: Dictionary) -> PackedFloat32Array:
	var n: int = values.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	if n == 0:
		return out
	var dt: float = 1.0 / maxf(rate, 1.0)
	var attack: float = maxf(float(layer.get("attack", 0.0)), 0.0) / 1000.0
	var release: float = maxf(float(layer.get("release", 0.0)), 0.0) / 1000.0
	var a_att: float = exp(-dt / attack) if attack > 0.0 else 0.0
	var a_rel: float = exp(-dt / release) if release > 0.0 else 0.0
	var thr: float = 0.0 if _plant_skip_hold else maxf(float(layer.get("hold", 0.0)), 0.0) * absf(AnimProp.driven_in(layer, "in_max", 1.0) - AnimProp.driven_in(layer, "in_min", 0.0))
	var y: float = values[0]
	var held: float = values[0]
	for i: int in n:
		var x: float = values[i]
		if x > y:
			y = a_att * y + (1.0 - a_att) * x
		else:
			y = a_rel * y + (1.0 - a_rel) * x
		if thr <= 0.0 or absf(y - held) > thr:
			held = y
		out[i] = held
	return out


static func shaped(base_key: String, base_serial: int, done: bool, values: PackedFloat32Array, rate: float, layer: Dictionary) -> PackedFloat32Array:
	var key: String = base_key + "#" + shaping_sig(layer)
	var hit: Variant = _shaped.get(key, null)
	var now: int = Time.get_ticks_msec()
	if hit is Dictionary:
		var hd: Dictionary = hit
		if int(hd["serial"]) == base_serial and int(hd["n"]) == values.size():
			return hd["arr"]
		if not done and now - int(hd["ms"]) < REBUILD_MS:
			return hd["arr"]
	builds += 1
	var arr: PackedFloat32Array = process(values, rate, layer)
	if _shaped.size() >= SHAPED_MAX:
		_shaped = {}
	_shaped[key] = {"serial": base_serial, "n": values.size(), "ms": now, "arr": arr}
	return arr


static func sound_params(layer: Dictionary) -> Dictionary:
	var thr: float = 0.0 if _plant_skip_hold else maxf(float(layer.get("hold", 0.0)), 0.0) * absf(AnimProp.driven_in(layer, "in_max", 1.0) - AnimProp.driven_in(layer, "in_min", 0.0))
	return ReactShape.driver_params(float(layer.get("attack", 0.0)), float(layer.get("release", 0.0)), thr)


static func sound_values(env: Dictionary, band: int) -> PackedFloat32Array:
	var key: String = "snd|" + String(env["key"]) + "#" + str(band)
	var hit: Variant = _values.get(key, null)
	if hit is Dictionary and int((hit as Dictionary)["serial"]) == int(env["serial"]):
		return (hit as Dictionary)["arr"]
	var bands: int = maxi(int(env["bands"]), 1)
	var vals: PackedFloat32Array = env["values"]
	var n: int = vals.size() / bands
	var ref: float = AudioReact.band_reference(env["peaks"], clampi(band, 0, bands - 1))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var k: float = 100.0 / ref if ref > 0.000001 else 0.0
	for i: int in n:
		out[i] = vals[i * bands + clampi(band, 0, bands - 1)] * k
	if _values.size() >= VALUE_SERIES_MAX:
		_values = {}
	_values[key] = {"serial": int(env["serial"]), "arr": out}
	return out


static func sound_edges(src: Dictionary) -> PackedFloat64Array:
	var band: int = int(src.get("band", 0))
	return SoundEnvelopes.band_edges(band if band != AudioReact.BAND_CUSTOM else -1, float(src.get("low", 80.0)), float(src.get("high", 2000.0)))


static func measure_spec(src: Dictionary) -> Dictionary:
	var col: Color = Color(0.0, 1.0, 0.0)
	var raw: Variant = src.get("colour", null)
	if raw is Array and (raw as Array).size() >= 3:
		col = Color(float(raw[0]), float(raw[1]), float(raw[2]))
	var reg: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var rr: Variant = src.get("region", null)
	if rr is Array and (rr as Array).size() >= 4:
		reg = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
	return {"measure": PictureSeries.measure_index(String(src.get("measure", "colour"))), "colour": col, "tol": clampf(float(src.get("tol", 0.3)), 0.0, 1.0), "region": reg}


static func owner_of(doc: Object, src: Dictionary) -> Object:
	if doc == null:
		return null
	var id: String = String(src.get("owner", ""))
	if id.is_empty():
		id = String(src.get("clip", ""))
	return doc.call("clip_by_id", id) if not id.is_empty() else null


static func entry_for(doc: Object, src: Dictionary, owner: Object, at_seq: float) -> Dictionary:
	var kind: String = String(src.get("kind", KIND_VALUE))
	if kind == KIND_SOUND:
		var f: Dictionary = AudioReact.feed(doc, owner, String(src.get("sound", "")), sound_edges(src), at_seq)
		if not bool(f["ok"]):
			return {"ok": false, "label": String(f["label"])}
		var waiting: PackedStringArray = f["waiting"]
		var pseudo: Dictionary = f["env"] if f.has("env") else {"done": bool(f["done"]), "failed": false, "count": 1, "key": waiting[0] if not waiting.is_empty() else "", "serial": 0}
		return {"ok": true, "kind": KIND_SOUND, "entry": pseudo, "feed": f, "at": float(f["at"]), "label": String(f["label"])}
	if kind == KIND_PICTURE:
		var rate: int = rate_of(doc, owner)
		var p: Dictionary = pic_resolve(doc, owner, String(src.get("pic", "")), at_seq)
		if not bool(p["ok"]):
			return {"ok": false, "label": String(p["label"])}
		if String(p["kind"]) == PIC_SCREEN:
			var s: Object = doc.call("sequence_of_clip", String(owner.get("id")))
			if s == null:
				return {"ok": false, "label": "The clip is not in a sequence"}
			var se: Dictionary = PictureSeries.screen(doc, s, owner, rate)
			return {"ok": true, "kind": KIND_PICTURE, "entry": se, "at": at_seq, "screen": true, "label": String(p["label"])}
		var pe: Dictionary = PictureSeries.entry(String(p["path"]), rate)
		return {"ok": true, "kind": KIND_PICTURE, "entry": pe, "at": float(p["at"]), "still": bool(p["still"]), "label": String(p["label"])}
	return {"ok": false, "label": ""}


static func raw_at(doc: Object, layer: Dictionary, src: Dictionary, t: float) -> Dictionary:
	reads += 1
	var owner: Object = owner_of(doc, src)
	if owner == null:
		return {"ok": false, "v": 0.0}
	var at_seq: float = float(owner.get("start")) + t + float(src.get("lead", 0.0))
	var got: Dictionary = entry_for(doc, src, owner, at_seq)
	if not bool(got["ok"]):
		return {"ok": false, "v": 0.0}
	var e: Dictionary = got["entry"]
	if bool(e["failed"]) and int(e.get("count", 0)) <= 0:
		return {"ok": false, "v": 0.0}
	if not bool(e["done"]) and String(got["kind"]) != KIND_SOUND:
		PictureSeries.note_waiting(current_comp(), String(e["key"]))
	if String(got["kind"]) == KIND_SOUND:
		var fd: Dictionary = got["feed"]
		for wk: String in fd["waiting"]:
			SoundEnvelopes.note_waiting(current_comp(), wk)
		if float(got["at"]) < 0.0:
			return {"ok": true, "v": 0.0}
		return {"ok": true, "v": AudioReact.values_at(fd, sound_params(layer), 0, 1, float(got["at"]), false)[0]}
	var spec: Dictionary = measure_spec(src)
	var vals: PackedFloat32Array = PictureSeries.measured(e, spec)
	var parr: PackedFloat32Array = shaped("pic|" + String(e["key"]) + "#" + PictureSeries.spec_sig(spec), int(e["serial"]), bool(e["done"]), vals, float(int(e["rate"])), layer)
	if parr.is_empty():
		return {"ok": true, "v": 0.0}
	var slot: int = 0
	if bool(got.get("screen", false)):
		slot = int(floor(float(got["at"]) * float(int(e["rate"])) + SLOT_EPS)) - int(e["first"])
		if slot < 0 or slot >= int(e["slots"]):
			return {"ok": false, "v": 0.0}
	elif bool(got.get("still", false)):
		slot = 0
	else:
		if float(got["at"]) < 0.0:
			return {"ok": false, "v": 0.0}
		slot = PictureSeries.slot_of(e, float(got["at"]))
	if slot >= parr.size():
		slot = parr.size() - 1
	return {"ok": true, "v": parr[slot]}


static func value_raw_at(doc: Object, layer: Dictionary, src: Dictionary, t: float, fps: float) -> Dictionary:
	var c: Object = doc.call("clip_by_id", String(src.get("clip", ""))) if doc != null else null
	if c == null:
		return {"ok": false, "v": 0.0}
	var owner: Object = owner_of(doc, {"owner": String(src.get("owner", "")), "clip": String(src.get("clip", ""))})
	var rate: int = rate_of(doc, owner if owner != null else c)
	var dur: float = maxf(float(c.get("duration")), 0.0)
	var key: String = "val|" + str(int(doc.get("serial"))) + "|" + str(src.hash()) + "|" + str(rate)
	var hit: Variant = _values.get(key, null)
	var base: PackedFloat32Array = PackedFloat32Array()
	if hit is Dictionary:
		base = (hit as Dictionary)["arr"]
	else:
		var n: int = maxi(int(ceil(dur * float(rate))) + 1, 1)
		base.resize(n)
		var drv: GDScript = load(DRIVER)
		var bare: Dictionary = src.duplicate()
		bare["lead"] = 0.0
		for i: int in n:
			var one: Dictionary = drv.call("_sample_at", bare, float(i) / float(rate), fps if fps > 0.0 else float(rate))
			base[i] = float(one["v"]) if bool(one["ok"]) else (base[i - 1] if i > 0 else 0.0)
		if _values.size() >= VALUE_SERIES_MAX:
			_values = {}
		_values[key] = {"serial": 0, "arr": base}
	var arr: PackedFloat32Array = shaped(key, 0, true, base, float(rate), layer)
	var shift: float = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
	var at: float = clampf(t + shift, 0.0, dur)
	var pos: float = at * float(rate)
	var i0: int = clampi(int(floor(pos)), 0, arr.size() - 1)
	var i1: int = mini(i0 + 1, arr.size() - 1)
	var held: bool = float(layer.get("hold", 0.0)) > 0.0
	return {"ok": true, "v": arr[i0] if held else lerpf(arr[i0], arr[i1], pos - float(i0))}


static func ready(doc: Object, layer: Dictionary) -> bool:
	var src: Dictionary = AnimProp.driven_source(layer)
	var kind: String = String(src.get("kind", KIND_VALUE))
	if kind == KIND_VALUE:
		return true
	var owner: Object = owner_of(doc, src)
	if owner == null:
		return true
	var got: Dictionary = entry_for(doc, src, owner, float(owner.get("start")))
	if not bool(got["ok"]):
		return true
	return bool((got["entry"] as Dictionary)["done"])


static func wait_ready(doc: Object, layer: Dictionary, timeout_ms: int) -> bool:
	var src: Dictionary = AnimProp.driven_source(layer)
	var owner: Object = owner_of(doc, src)
	if owner == null or String(src.get("kind", KIND_VALUE)) == KIND_VALUE:
		return true
	var got: Dictionary = entry_for(doc, src, owner, float(owner.get("start")))
	if not bool(got["ok"]):
		return true
	var e: Dictionary = got["entry"]
	if String(got["kind"]) == KIND_SOUND:
		var ok: bool = true
		for wk: String in (got["feed"] as Dictionary)["waiting"]:
			ok = SoundEnvelopes.wait_done(wk, timeout_ms) and ok
		return ok
	return PictureSeries.wait_done(String(e["key"]), timeout_ms) and bool(e["done"])


static func scan(doc: Object, layer: Dictionary, fps: float) -> Dictionary:
	var src: Dictionary = AnimProp.driven_source(layer)
	var owner: Object = owner_of(doc, src)
	if owner == null:
		return {"ok": false, "lo": 0.0, "hi": 1.0, "ready": true}
	var free: Dictionary = layer.duplicate(true)
	free["hold"] = 0.0
	free["step"] = 0.0
	var rate: float = fps if fps > 0.0 else float(rate_of(doc, owner))
	var dur: float = maxf(float(owner.get("duration")), 0.0)
	var n: int = maxi(int(ceil(dur * rate)), 1)
	var lo: float = INF
	var hi: float = -INF
	var kind: String = String(src.get("kind", KIND_VALUE))
	for i: int in n + 1:
		var t: float = minf(float(i) / rate, maxf(dur - 0.0001, 0.0))
		var got: Dictionary = {}
		if kind == KIND_VALUE:
			got = value_raw_at(doc, free, src, t, rate)
		else:
			got = raw_at(doc, free, src, t)
		if not bool(got["ok"]):
			continue
		lo = minf(lo, float(got["v"]))
		hi = maxf(hi, float(got["v"]))
	if is_inf(lo) or is_inf(hi):
		return {"ok": false, "lo": 0.0, "hi": 1.0, "ready": ready(doc, layer)}
	if absf(hi - lo) < 0.000001:
		hi = lo + 1.0
	return {"ok": true, "lo": lo, "hi": hi, "ready": ready(doc, layer)}


static func source_label(doc: Object, layer: Dictionary) -> String:
	var src: Dictionary = AnimProp.driven_source(layer)
	var kind: String = String(src.get("kind", KIND_VALUE))
	var owner: Object = owner_of(doc, src)
	if kind == KIND_SOUND:
		var band: int = clampi(int(src.get("band", 0)), 0, AudioReact.BANDS.size() - 1)
		return "Sound, " + AudioReact.BANDS[band].to_lower() + ": " + (AudioReact.label_of(doc, owner, String(src.get("sound", ""))) if owner != null else "no clip")
	if kind == KIND_PICTURE:
		var what: String = String(MEASURE_LABELS.get(String(src.get("measure", "colour")), "Picture"))
		var p: Dictionary = pic_resolve(doc, owner, String(src.get("pic", "")), float(owner.get("start")) if owner != null else 0.0)
		return what + ": " + String(p["label"])
	return ""


static func unit_of(layer: Dictionary) -> String:
	var src: Dictionary = AnimProp.driven_source(layer)
	var kind: String = String(src.get("kind", KIND_VALUE))
	if kind == KIND_SOUND:
		return " %"
	if kind == KIND_PICTURE:
		return String(MEASURE_UNITS.get(String(src.get("measure", "colour")), " %"))
	return ""
