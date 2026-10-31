extends RefCounted

const RATE := 200
const CHUNK := 200
const WARM_K := 8.0
const WARM_MAX := 6000
const BEAT_GAP_S := 0.1
const BEAT_AVG_S := 0.25
const BEAT_RISE := 0.08
const MODE_LEVEL := 0
const MODE_BEAT := 1
const MODE_DRIVER := 2
const LIQUID_DAMP := 0.55
const LIQUID_FAST := 40.0
const LIQUID_SLOW := 5.0
const REF_EPS := 0.000001

static var _plant_no_rearm: bool = false


static func params_of(settings: Dictionary) -> Dictionary:
	return {
		"mode": clampi(int(settings.get("snd_mode", 0.0)), 0, 1),
		"gain": maxf(float(settings.get("snd_gain", 100.0)), 0.0) / 100.0,
		"thr": clampf(float(settings.get("snd_threshold", 0.0)) / 100.0, 0.0, 0.99),
		"attack": maxf(float(settings.get("snd_attack", 0.0)), 0.0) / 1000.0,
		"release": maxf(float(settings.get("snd_release", 0.0)), 0.0) / 1000.0,
		"decay": maxf(float(settings.get("snd_decay", 300.0)), 1.0) / 1000.0,
		"liquid": clampf(float(settings.get("snd_liquid", 0.0)) / 100.0, 0.0, 1.0),
		"peaks": bool(settings.get("snd_peaks", false)),
		"hold": maxf(float(settings.get("snd_peak_hold", 300.0)), 0.0) / 1000.0,
		"fall": maxf(float(settings.get("snd_peak_fall", 60.0)), 1.0) / 100.0,
		"step": 0.0,
	}


static func driver_params(attack_ms: float, release_ms: float, step: float) -> Dictionary:
	return {
		"mode": MODE_DRIVER,
		"gain": 1.0,
		"thr": 0.0,
		"attack": maxf(attack_ms, 0.0) / 1000.0,
		"release": maxf(release_ms, 0.0) / 1000.0,
		"decay": 0.3,
		"liquid": 0.0,
		"peaks": false,
		"hold": 0.0,
		"fall": 1.0,
		"step": maxf(step, 0.0),
	}


static func sig(p: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k: String in ["mode", "gain", "thr", "attack", "release", "decay", "liquid", "hold", "fall", "step"]:
		parts.append(str(snappedf(float(p.get(k, 0.0)), 0.00001)))
	parts.append("p" if bool(p.get("peaks", false)) else "n")
	return ",".join(parts)


static func liquid_w(l: float) -> float:
	return lerpf(LIQUID_FAST, LIQUID_SLOW, clampf(l, 0.0, 1.0))


static func warm_of(p: Dictionary) -> int:
	var tau: float = 0.0
	var mode: int = int(p.get("mode", 0))
	if mode == MODE_BEAT:
		tau = maxf(float(p.get("decay", 0.3)), BEAT_AVG_S)
	else:
		tau = maxf(float(p.get("attack", 0.0)), float(p.get("release", 0.0)))
	var w: float = WARM_K * tau
	if mode == MODE_BEAT:
		w += BEAT_GAP_S * 4.0
	if mode == MODE_DRIVER and float(p.get("step", 0.0)) > 0.0:
		w += 2.0
	var l: float = float(p.get("liquid", 0.0))
	if l > 0.0:
		w += WARM_K / (LIQUID_DAMP * liquid_w(l))
	if bool(p.get("peaks", false)):
		w += float(p.get("hold", 0.0)) + 1.0 / maxf(float(p.get("fall", 1.0)), 0.01)
	return clampi(int(ceil(w * float(RATE))), 0, WARM_MAX)


static func run(raw: PackedFloat32Array, stride: int, base: int, band_from: int, band_n: int, refs: PackedFloat32Array, from: int, count: int, warm: int, p: Dictionary) -> PackedFloat32Array:
	var with_peaks: bool = bool(p.get("peaks", false))
	var bn: int = maxi(band_n, 1)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(count, 0) * bn * (2 if with_peaks else 1))
	if count <= 0:
		return out
	var st: int = maxi(stride, 1)
	var raw_n: int = raw.size() / st
	var start: int = maxi(from - maxi(warm, 0), 0)
	var stop: int = from + count
	var dt: float = 1.0 / float(RATE)
	var mode: int = int(p.get("mode", 0))
	var thr: float = float(p.get("thr", 0.0))
	var span: float = maxf(1.0 - thr, 0.01)
	var attack: float = float(p.get("attack", 0.0))
	var release: float = float(p.get("release", 0.0))
	var a_att: float = exp(-dt / attack) if attack > 0.0 else 0.0
	var a_rel: float = exp(-dt / release) if release > 0.0 else 0.0
	var a_dec: float = exp(-dt / maxf(float(p.get("decay", 0.3)), 0.001))
	var a_avg: float = exp(-dt / BEAT_AVG_S)
	var gap: int = int(ceil(BEAT_GAP_S * float(RATE)))
	var rise_need: float = maxf(BEAT_RISE, thr * 0.5)
	var lq: float = float(p.get("liquid", 0.0))
	var lw: float = liquid_w(lq)
	var lk: float = lw * lw
	var lc: float = 2.0 * LIQUID_DAMP * lw
	var hold_s: float = float(p.get("hold", 0.0))
	var fall: float = float(p.get("fall", 1.0))
	var step_thr: float = float(p.get("step", 0.0))
	var peak_at: int = count * bn
	for b: int in bn:
		var ref: float = refs[b] if b < refs.size() else 0.0
		if ref <= REF_EPS:
			continue
		var gain: float = float(p.get("gain", 1.0)) / ref
		if mode == MODE_DRIVER:
			gain = 100.0 / ref
		var col: int = band_from + b
		var y: float = 0.0
		var avg: float = 0.0
		var last: int = start - gap
		var pos: float = 0.0
		var vel: float = 0.0
		var pk: float = 0.0
		var held_for: float = 0.0
		var held: float = 0.0
		var first: bool = true
		var armed: bool = true
		for i: int in range(start, stop):
			var ri: int = i - base
			var x: float = 0.0
			if ri >= 0 and ri < raw_n:
				x = raw[ri * st + col] * gain
			var v: float = 0.0
			if mode == MODE_DRIVER:
				if first:
					y = x
					held = x
					first = false
				elif x > y:
					y = a_att * y + (1.0 - a_att) * x
				else:
					y = a_rel * y + (1.0 - a_rel) * x
				if step_thr <= 0.0 or absf(y - held) > step_thr:
					held = y
				v = held
			elif mode == MODE_BEAT:
				y *= a_dec
				if x - avg > rise_need:
					if armed and x > thr and i - last >= gap:
						y = maxf(y, clampf((x - thr) / span, 0.0, 1.0))
						last = i
						armed = _plant_no_rearm
					elif not armed and i - last < gap:
						y = maxf(y, clampf((x - thr) / span, 0.0, 1.0))
				elif x <= avg:
					armed = true
				avg = a_avg * avg + (1.0 - a_avg) * x
				v = y
			else:
				var g: float = clampf((x - thr) / span, 0.0, 1.0)
				if g > y:
					y = a_att * y + (1.0 - a_att) * g
				else:
					y = a_rel * y + (1.0 - a_rel) * g
				v = y
			if lq > 0.0 and mode != MODE_DRIVER:
				vel += (lk * (v - pos) - lc * vel) * dt
				pos += vel * dt
				v = clampf(pos, 0.0, 1.0)
			if with_peaks:
				if v >= pk:
					pk = v
					held_for = 0.0
				else:
					held_for += dt
					if held_for > hold_s:
						pk = maxf(pk - fall * dt, v)
			if i >= from:
				var o: int = (i - from) * bn + b
				out[o] = v
				if with_peaks:
					out[peak_at + o] = pk
	return out


static func onsets(raw: PackedFloat32Array, stride: int, base: int, band: int, ref: float, from: int, count: int, warm: int, p: Dictionary) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if ref <= REF_EPS or count <= 0:
		return out
	var st: int = maxi(stride, 1)
	var raw_n: int = raw.size() / st
	var start: int = maxi(from - maxi(warm, 0), 0)
	var thr: float = float(p.get("thr", 0.0))
	var span: float = maxf(1.0 - thr, 0.01)
	var gain: float = float(p.get("gain", 1.0)) / ref
	var a_avg: float = exp(-1.0 / float(RATE) / BEAT_AVG_S)
	var gap: int = int(ceil(BEAT_GAP_S * float(RATE)))
	var rise_need: float = maxf(BEAT_RISE, thr * 0.5)
	var avg: float = 0.0
	var last: int = start - gap
	var armed: bool = true
	for i: int in range(start, from + count):
		var ri: int = i - base
		var x: float = raw[ri * st + band] * gain if ri >= 0 and ri < raw_n else 0.0
		if x <= avg:
			armed = true
		elif x - avg > rise_need and armed and x > thr and i - last >= gap:
			last = i
			armed = _plant_no_rearm
			if i >= from:
				out.append(float(i))
				out.append(clampf((x - thr) / span, 0.0, 1.0))
		elif x - avg > rise_need and not armed and i - last < gap and last >= from and not out.is_empty():
			out[out.size() - 1] = maxf(out[out.size() - 1], clampf((x - thr) / span, 0.0, 1.0))
		avg = a_avg * avg + (1.0 - a_avg) * x
	return out
