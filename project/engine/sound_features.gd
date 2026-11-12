extends RefCounted

const SoundEnvelopes := preload("res://engine/sound_envelopes.gd")
const EDGES: Array = [0.0, 0.0, 30.0, 120.0, 120.0, 400.0, 400.0, 1500.0, 1500.0, 4000.0, 4000.0, 9000.0, 9000.0, 16000.0]
const OCTAVES: Array = [2.0, 1.737, 1.907, 1.415, 1.170, 0.830]
const BANDS := 7
const RATE := 200
const FRATE := 100
const CH := 12
const C_LEVEL := 0
const C_BASS := 1
const C_MID := 2
const C_TREBLE := 3
const C_VOICE := 4
const C_BRIGHT := 5
const C_NOISE := 6
const C_SUSTAIN := 7
const C_LEVEL_SLOW := 8
const C_VOICE_SLOW := 9
const C_SINCE := 10
const C_DOSE := 11
const FLOATS: PackedStringArray = ["snd_level", "snd_bass", "snd_mid", "snd_treble", "snd_voice", "snd_bright", "snd_noise", "snd_sustain", "snd_level_slow", "snd_voice_slow"]
const GAINED: PackedInt32Array = [C_LEVEL, C_BASS, C_MID, C_TREBLE, C_VOICE, C_NOISE, C_SUSTAIN, C_LEVEL_SLOW, C_VOICE_SLOW]
const RANGE_DB := 39.0
const FLOOR_DB := -36.0
const SILENT := 0.12
const HIT_GAP := 14
const HIT_LAG := 2
const HIT_DELTA := 0.22
const HIT_K := 1.5
const HIT_FULL := 1.4
const HIT_MIN := 0.15
const VOICE_DUCK := 0.75
const HITS_MAX := 64
const PAST_POINTS := 64
const QUIET_MAX := 600.0
const AGE_NONE := 1000.0
const TABLES_MAX := 16
const PREVIEW: Dictionary = {"snd_level": 0.8, "snd_bass": 0.85, "snd_mid": 0.6, "snd_treble": 0.5, "snd_voice": 0.8, "snd_bright": 0.5, "snd_noise": 0.6, "snd_sustain": 0.7, "snd_level_slow": 0.7, "snd_voice_slow": 0.75}
const PREVIEW_AGES: Array = [0.06, 0.45, 0.9, 1.4, 2.1, 2.9, 3.8, 4.6]

static var _tables: Dictionary = {}
static var analyses: int = 0
static var analysis_usec: int = 0
static var _plant_ignore_rate: bool = false
static var _plant_no_trim: bool = false
static var _plant_hit_shift: float = 0.0
static var _plant_flat_level: bool = false
static var _plant_no_voice: bool = false
static var _plant_jitter: bool = false
static var _plant_silence_loud: bool = false
static var _plant_no_floor: bool = false
static var _plant_deaf: bool = false


static func edges() -> PackedFloat64Array:
	return PackedFloat64Array(EDGES)


static func wanted(spec: Dictionary) -> bool:
	var l: Variant = spec.get("listen", null)
	return (l is bool and bool(l)) or l is Dictionary


static func listen_only(spec: Dictionary) -> bool:
	if not wanted(spec):
		return false
	for k: String in ["drive", "level", "wave", "spectrum", "beats"]:
		if spec.has(k):
			return false
	return true


static func _db(x: float, ref: float) -> float:
	return 20.0 * log(maxf(x, 1e-9) / maxf(ref, 1e-9)) / log(10.0)


static func _map(x: float, ref: float) -> float:
	return clampf((_db(x, ref) - FLOOR_DB) / RANGE_DB, 0.0, 1.0)


static func _smooth01(a: float, b: float, x: float) -> float:
	var u: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _coef(tau: float, rate: float) -> float:
	return exp(-1.0 / (maxf(tau, 0.0001) * rate))


static func _percentile(vals: PackedFloat32Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var s: PackedFloat32Array = vals.duplicate()
	s.sort()
	return s[clampi(int(floor(q * float(s.size() - 1))), 0, s.size() - 1)]


static func analyse(raw: PackedFloat32Array, bands: int) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var n: int = raw.size() / maxi(bands, 1)
	var out: Dictionary = {"n": 0, "table": PackedFloat32Array(), "hits": PackedFloat32Array(), "ref": 0.0, "refs": PackedFloat32Array()}
	if bands != BANDS or n < 2:
		return out
	var top: float = 0.0
	for i: int in n:
		top = maxf(top, raw[i * bands])
	if top <= 1e-7:
		var flat: PackedFloat32Array = PackedFloat32Array()
		var fn: int = (n + 1) / 2
		flat.resize(fn * CH)
		for j: int in fn:
			flat[j * CH + C_BRIGHT] = 0.5
			flat[j * CH + C_SINCE] = float(j) / float(FRATE)
		out["n"] = fn
		out["table"] = flat
		out["silent"] = true
		return out
	var step: int = maxi(n / 40000, 1)
	var rows: PackedInt32Array = PackedInt32Array()
	var gate: float = top * 0.01
	var i0: int = 0
	while i0 < n:
		if raw[i0 * bands] > gate:
			rows.append(i0)
		i0 += step
	var refs: PackedFloat32Array = PackedFloat32Array()
	refs.resize(bands)
	var col: PackedFloat32Array = PackedFloat32Array()
	col.resize(rows.size())
	for b: int in bands:
		for r0: int in rows.size():
			col[r0] = raw[rows[r0] * bands + b]
		refs[b] = _percentile(col, 0.9)
	var ref: float = maxf(refs[0], top * 0.1)
	refs[0] = ref
	for b3: int in range(1, bands):
		refs[b3] = maxf(refs[b3], ref * 0.15)
	var fast_a: float = _coef(0.008, RATE)
	var fast_r: float = _coef(0.14, RATE)
	var v_a: float = _coef(0.1, RATE)
	var v_r: float = _coef(0.45, RATE)
	var br_k: float = _coef(0.15, RATE)
	var nz_a: float = _coef(0.03, RATE)
	var nz_r: float = _coef(0.25, RATE)
	var sus_rise: float = 1.0 / (0.5 * float(RATE))
	var sus_r: float = _coef(0.3, RATE)
	var slow_a: float = _coef(1.0, RATE)
	var slow_r: float = _coef(2.5, RATE)
	var vs_r: float = _coef(3.0, RATE)
	var m_fast: float = _coef(0.03, RATE)
	var m_slow: float = _coef(0.4, RATE)
	var m_avg: float = _coef(0.3, RATE)
	var l_avg: float = _coef(0.3, RATE)
	var flux_avg: float = _coef(0.25, RATE)
	var y0: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var y3: float = 0.0
	var mid_ref: float = sqrt(refs[3] * refs[3] + refs[4] * refs[4])
	var top_ref: float = sqrt(refs[5] * refs[5] + refs[6] * refs[6])
	var voice: float = 0.0
	var bright: float = 0.5
	var noise: float = 0.0
	var floor_f: float = 0.0
	var sustain: float = 0.0
	var lslow: float = 0.0
	var vslow: float = 0.0
	var vf: float = -120.0
	var vs: float = -120.0
	var mod: float = 0.0
	var lav: float = 0.0
	var fav: float = 0.0
	var last_hit: int = -HIT_GAP
	var since: float = 0.0
	var dose: float = 0.0
	var fn2: int = (n + 1) / 2
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(fn2 * CH)
	var lv: PackedFloat32Array = PackedFloat32Array()
	lv.resize(n)
	var flux: PackedFloat32Array = PackedFloat32Array()
	flux.resize(n)
	var lows: PackedFloat32Array = PackedFloat32Array()
	lows.resize(n)
	var vox: PackedFloat32Array = PackedFloat32Array()
	vox.resize(n)
	var thr: PackedFloat32Array = PackedFloat32Array()
	thr.resize(n)
	var cl: PackedFloat32Array = PackedFloat32Array()
	cl.resize(n * 6)
	var pw: PackedFloat32Array = PackedFloat32Array()
	pw.resize(6)
	var dt: float = 1.0 / float(RATE)
	for i: int in n:
		var row: int = i * bands
		var full: float = raw[row]
		var lvl: float = _map(full, ref)
		lv[i] = lvl
		var t_b: float = _map(raw[row + 1], refs[1])
		var t_m: float = _map(sqrt(raw[row + 3] * raw[row + 3] + raw[row + 4] * raw[row + 4]), mid_ref)
		var t_t: float = _map(sqrt(raw[row + 5] * raw[row + 5] + raw[row + 6] * raw[row + 6]), top_ref)
		y0 = (fast_a if lvl > y0 else fast_r) * (y0 - lvl) + lvl
		y1 = (fast_a if t_b > y1 else fast_r) * (y1 - t_b) + t_b
		y2 = (fast_a if t_m > y2 else fast_r) * (y2 - t_m) + t_m
		y3 = (fast_a if t_t > y3 else fast_r) * (y3 - t_t) + t_t
		var pt: float = 0.0
		var wsum: float = 0.0
		var lsum: float = 0.0
		var csum: float = 0.0
		for b4: int in 6:
			var x: float = raw[row + 1 + b4]
			var p: float = x * x
			pw[b4] = p
			pt += p
			var po: float = p / float(OCTAVES[b4])
			lsum += log(maxf(po, 1e-20))
			csum += po
			wsum += p * float(b4)
			cl[i * 6 + b4] = log(maxf(x, refs[b4 + 1] * 0.001) / refs[b4 + 1])
		var flat_v: float = 0.0
		if csum > 1e-20:
			flat_v = exp(lsum / 6.0) / (csum / 6.0)
		if pt > 1e-20 and lvl > 0.15:
			var cen: float = clampf(wsum / pt / 5.0, 0.0, 1.0)
			bright = br_k * bright + (1.0 - br_k) * clampf((cen - 0.12) / 0.5, 0.0, 1.0)
		var nz_t: float = _smooth01(0.3, 0.75, flat_v) * _smooth01(0.3, 0.7, lvl)
		var na: float = nz_a if nz_t > noise else nz_r
		noise = na * noise + (1.0 - na) * nz_t
		var pv: float = pw[1] * 0.5 + pw[2] + pw[3]
		var share: float = pv / pt if pt > 1e-20 else 0.0
		var low_share: float = pw[0] / pt if pt > 1e-20 else 0.0
		var vdb: float = 10.0 * log(maxf(pv, 1e-20)) / log(10.0)
		vf = m_fast * vf + (1.0 - m_fast) * vdb if i > 0 else vdb
		vs = m_slow * vs + (1.0 - m_slow) * vdb if i > 0 else vdb
		mod = m_avg * mod + (1.0 - m_avg) * minf(absf(vf - vs), 20.0)
		lav = l_avg * lav + (1.0 - l_avg) * lvl
		var v_t: float = _smooth01(0.45, 0.78, share) * _smooth01(2.0, 5.0, mod) * (1.0 - _smooth01(0.3, 0.6, low_share)) * (1.0 - _smooth01(0.6, 0.85, flat_v)) * _smooth01(0.2, 0.5, lav)
		var va: float = v_a if v_t > voice else v_r
		voice = va * voice + (1.0 - va) * v_t
		vox[i] = voice
		floor_f = minf(lvl, floor_f + sus_rise)
		sustain = floor_f if floor_f > sustain else sus_r * sustain + (1.0 - sus_r) * floor_f
		var sa: float = slow_a if lvl > lslow else slow_r
		lslow = sa * lslow + (1.0 - sa) * lvl
		var vsa: float = slow_a if voice > vslow else vs_r
		vslow = vsa * vslow + (1.0 - vsa) * voice
		since = 0.0 if lvl > SILENT else since + dt
		dose += lvl * dt
		if i >= HIT_LAG:
			var fx: float = 0.0
			var lo_rise: float = 0.0
			for b5: int in 6:
				var r: float = maxf(cl[i * 6 + b5] - cl[(i - HIT_LAG) * 6 + b5], 0.0)
				fx += r
				if b5 < 2:
					lo_rise += r
			flux[i] = fx / 6.0
			lows[i] = lo_rise / fx if fx > 1e-6 else 0.0
		thr[i] = HIT_K * fav + HIT_DELTA
		fav = flux_avg * fav + (1.0 - flux_avg) * flux[i]
		if (i & 1) == 0:
			var o: int = (i / 2) * CH
			table[o + C_LEVEL] = 0.5 if _plant_flat_level else y0
			table[o + C_BASS] = y1
			table[o + C_MID] = y2
			table[o + C_TREBLE] = y3
			table[o + C_VOICE] = 0.0 if _plant_no_voice else voice
			table[o + C_BRIGHT] = bright
			table[o + C_NOISE] = noise
			table[o + C_SUSTAIN] = sustain
			table[o + C_LEVEL_SLOW] = lslow
			table[o + C_VOICE_SLOW] = vslow
			table[o + C_SINCE] = since
			table[o + C_DOSE] = dose
	var hits: PackedFloat32Array = PackedFloat32Array()
	for i2: int in range(HIT_LAG, n - 1):
		var f: float = flux[i2]
		if f < (0.0 if _plant_no_floor else thr[i2]) or f < flux[i2 - 1] or f <= flux[i2 + 1] or i2 - last_hit < (1 if _plant_no_floor else HIT_GAP):
			continue
		var lpk: float = 0.0
		for j2: int in range(i2, mini(i2 + 8, n)):
			lpk = maxf(lpk, lv[j2])
		if lpk < 0.2 and not _plant_no_floor:
			continue
		var strength: float = clampf(f / HIT_FULL, 0.0, 1.0) * _smooth01(0.2, 0.75, lpk) * (1.0 - VOICE_DUCK * vox[mini(i2 + 6, n - 1)])
		if strength < HIT_MIN and not _plant_no_floor:
			continue
		last_hit = i2
		hits.append(float(i2 - HIT_LAG + 1) / float(RATE) + _plant_hit_shift)
		hits.append(strength)
		hits.append(lows[i2])
		hits.append(fmod(float(i2) * 0.6180339887 + 0.1373, 1.0))
	out["n"] = fn2
	out["table"] = table
	out["hits"] = hits
	out["ref"] = ref
	out["refs"] = refs
	analyses += 1
	analysis_usec += Time.get_ticks_usec() - t0
	return out


static func table_for(env: Dictionary) -> Dictionary:
	var key: String = String(env["key"])
	var hit: Variant = _tables.get(key, null)
	if hit is Dictionary and int((hit as Dictionary)["serial"]) == int(env["serial"]):
		return hit
	var a: Dictionary = analyse(env["values"], int(env["bands"]))
	a["serial"] = int(env["serial"])
	if _tables.size() >= TABLES_MAX:
		_tables.erase(_tables.keys()[0])
	_tables[key] = a
	return a


static func forget() -> void:
	_tables = {}


static func sample(a: Dictionary, ch: int, s: float) -> float:
	var n: int = int(a.get("n", 0))
	if n <= 0 or s < 0.0:
		return 0.0
	var tb: PackedFloat32Array = a["table"]
	var pos: float = s * float(FRATE)
	if pos >= float(n):
		pos = float(n - 1)
	var i0: int = int(floor(pos))
	var fr: float = pos - float(i0)
	var i1: int = mini(i0 + 1, n - 1)
	return lerpf(tb[i0 * CH + ch], tb[i1 * CH + ch], fr)


static func _last_hit(hits: PackedFloat32Array, s: float) -> int:
	var lo: int = 0
	var hi: int = hits.size() / 4 - 1
	var found: int = -1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		if hits[mid * 4] <= s + 0.000001:
			found = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return found


static func _post(v: float, gain: float, thr: float) -> float:
	return clampf((v * gain - thr) / maxf(1.0 - thr, 0.01), 0.0, 1.0)


static func blank(values: Dictionary) -> void:
	for k: String in FLOATS:
		values[k] = 0.0
	values["snd_bright"] = 0.5
	values["snd_hit"] = 0.0
	values["snd_hit_age"] = AGE_NONE
	values["snd_hit_strength"] = 0.0
	values["snd_hit_seed"] = 0.0
	values["snd_hit_low"] = 0.0
	values["snd_hits"] = 0.0
	values["snd_hit_sum"] = 0.0
	values["snd_quiet"] = 0.0
	values["snd_dose"] = 0.0


static func state(a: Dictionary, at: float, from: float, rate: float, gain: float, thr: float, decay: float, hits_max: int, past_span: float, past_points: int) -> Dictionary:
	var out: Dictionary = {}
	blank(out)
	var r: float = 1.0 if _plant_ignore_rate else maxf(rate, 0.001)
	var lo: float = 0.0 if _plant_no_trim else maxf(minf(from, at), 0.0)
	for k: int in FLOATS.size():
		var v: float = sample(a, k, at)
		out[FLOATS[k]] = _post(v, gain, thr) if GAINED.has(k) else v
	out["snd_quiet"] = minf(minf(sample(a, C_SINCE, at), at - lo) / r, QUIET_MAX)
	out["snd_dose"] = maxf(sample(a, C_DOSE, at) - sample(a, C_DOSE, lo), 0.0) / r
	var hits: PackedFloat32Array = a.get("hits", PackedFloat32Array())
	var last: int = _last_hit(hits, at)
	var count: int = 0
	var total: float = 0.0
	var list: PackedFloat32Array = PackedFloat32Array()
	var i: int = last
	while i >= 0 and hits[i * 4] >= lo - 0.000001:
		var st: float = minf(hits[i * 4 + 1] * gain, 1.0)
		if st >= thr and st > 0.0:
			var age: float = (at - hits[i * 4]) / r
			if count == 0:
				out["snd_hit_age"] = age
				out["snd_hit_strength"] = st
				out["snd_hit_seed"] = hits[i * 4 + 3]
				out["snd_hit_low"] = hits[i * 4 + 2]
				out["snd_hit"] = st * exp(-age / maxf(decay, 0.001))
			if list.size() < hits_max * 4:
				list.append_array(PackedFloat32Array([age, st, hits[i * 4 + 3], hits[i * 4 + 2]]))
			count += 1
			total += st
		i -= 1
	out["snd_hits"] = float(count)
	out["snd_hit_sum"] = total
	var silent: bool = bool(a.get("silent", false))
	if _plant_silence_loud and silent:
		for k2: String in FLOATS:
			out[k2] = 0.7
		out["snd_hit"] = 0.8
		out["snd_hit_age"] = 0.05
		out["snd_hit_strength"] = 1.0
		out["snd_hits"] = 3.0
		out["snd_dose"] = 6.0
		list = PackedFloat32Array([0.05, 1.0, 0.3, 0.5, 0.4, 0.9, 0.7, 0.2])
	if _plant_deaf and not silent:
		blank(out)
		list = PackedFloat32Array()
		past_points = 0
	if _plant_jitter:
		out["snd_level"] = float(out["snd_level"]) + randf() * 0.6
	out["list"] = list
	if past_points > 0:
		var past: PackedFloat32Array = PackedFloat32Array()
		past.resize(past_points * 4)
		for p: int in past_points:
			var s: float = at - past_span * r * float(p) / float(maxi(past_points - 1, 1))
			if s < lo - 0.000001:
				continue
			past[p * 4] = _post(sample(a, C_LEVEL, s), gain, thr)
			past[p * 4 + 1] = _post(sample(a, C_BASS, s), gain, thr)
			past[p * 4 + 2] = _post(sample(a, C_VOICE, s), gain, thr)
			past[p * 4 + 3] = _post(sample(a, C_TREBLE, s), gain, thr)
		out["past"] = past
	return out


static func preview_state(hits_max: int, past_points: int) -> Dictionary:
	var out: Dictionary = {}
	blank(out)
	for k: Variant in PREVIEW.keys():
		out[k] = PREVIEW[k]
	var list: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for j: int in PREVIEW_AGES.size():
		var st: float = 1.0 - 0.08 * float(j)
		total += st
		if list.size() < hits_max * 4:
			list.append_array(PackedFloat32Array([float(PREVIEW_AGES[j]), st, fmod(float(j) * 0.6180339887 + 0.21, 1.0), 0.5]))
	out["snd_hit_age"] = float(PREVIEW_AGES[0])
	out["snd_hit_strength"] = 1.0
	out["snd_hit_seed"] = 0.21
	out["snd_hit_low"] = 0.5
	out["snd_hit"] = 0.85
	out["snd_hits"] = float(PREVIEW_AGES.size())
	out["snd_hit_sum"] = total
	out["snd_dose"] = 4.0
	out["list"] = list
	if past_points > 0:
		var past: PackedFloat32Array = PackedFloat32Array()
		past.resize(past_points * 4)
		for p: int in past_points:
			var x: float = float(p) / float(maxi(past_points - 1, 1))
			var v: float = 0.5 + 0.45 * sin(x * 21.0)
			past[p * 4] = v
			past[p * 4 + 1] = v
			past[p * 4 + 2] = 0.6
			past[p * 4 + 3] = 0.4
		out["past"] = past
	return out


static func hand_state(level: float, seconds: float, past_points: int) -> Dictionary:
	var out: Dictionary = {}
	blank(out)
	for k: String in FLOATS:
		out[k] = level
	out["snd_bright"] = 0.5
	out["snd_noise"] = 0.0
	out["snd_dose"] = level * maxf(seconds, 0.0)
	out["list"] = PackedFloat32Array()
	if past_points > 0:
		var past: PackedFloat32Array = PackedFloat32Array()
		past.resize(past_points * 4)
		for p: int in past_points:
			for c: int in 4:
				past[p * 4 + c] = level
		out["past"] = past
	return out
