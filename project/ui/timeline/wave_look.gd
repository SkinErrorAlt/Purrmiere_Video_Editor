extends RefCounted

const VeryLoud := preload("res://engine/very_loud.gd")
const WaveVolume := preload("res://ui/timeline/wave_volume.gd")
const FLOOR_DB := -48.0
const PREF_STYLE := "waves.style"
const PREF_GROW := "waves.grow_from"
const PREF_COLOUR_FROM := "waves.colour_from"
const PREF_COLOUR := "waves.colour"
const PREF_OPACITY := "waves.opacity"
const PREF_RMS := "waves.show_rms"
const PREF_SMOOTH := "waves.smoothing"
const PREF_BAR_W := "waves.bar_width"
const PREF_BAR_GAP := "waves.bar_gap"
const PREF_LINE := "waves.line_px"
const PREF_GRAD_TOP := "waves.gradient_top"
const PREF_GRAD_BOTTOM := "waves.gradient_bottom"
const PREF_HIGHS := "waves.show_highs"
const PREF_LOWS := "waves.show_lows"
const PREF_HIGH_DB := "waves.high_db"
const PREF_LOW_DB := "waves.low_db"
const PREF_HIGH_COLOUR := "waves.high_colour"
const PREF_LOW_COLOUR := "waves.low_colour"
const PREF_EASE := "waves.ease"
const PREF_EASE_DB := "waves.ease_db"
const PREF_VERY_LOUD := "waves.show_very_loud"
const PREF_VERY_LOUD_COLOUR := "waves.very_loud_colour"
const PREF_SHOW_DUCKED := "waves.show_ducked"
const PREF_SHOW_VOLUME := "waves.show_volume"
const PREF_LOG := "timeline.wave_log"
const PREF_GAIN := "timeline.wave_gain"
const STYLE_MIRRORED := "Mirrored"
const STYLE_BOTTOM := "Bottom up"
const STYLE_TOP := "Top down"
const STYLE_OUTLINE := "Outline"
const STYLE_FILLED_OUTLINE := "Filled with outline"
const STYLE_BARS := "Bars"
const STYLE_DOTS := "Dots"
const STYLE_LINE := "Line"
const STYLE_PEAK_RMS := "Peak plus RMS"
const STYLE_GRADIENT := "Gradient fill"
const STYLE_SPLIT := "Split halves"
const STYLES: PackedStringArray = ["Mirrored", "Bottom up", "Top down", "Outline", "Filled with outline", "Bars", "Dots", "Line", "Peak plus RMS", "Gradient fill", "Split halves"]
const STYLE_BLURBS: Dictionary = {
	"Mirrored": "Grows up and down from the middle, as before",
	"Bottom up": "Flat along the bottom, rising up out of it",
	"Top down": "Flat along the top, hanging down from it",
	"Outline": "Only the edge of the wave, as a line",
	"Filled with outline": "A soft fill with a bright edge",
	"Bars": "Blocky columns with a gap between them",
	"Dots": "A dot at the top of each column",
	"Line": "One line that follows the average loudness (RMS)",
	"Peak plus RMS": "Peaks in a light tone, the average loudness solid inside",
	"Gradient fill": "The colour changes with height",
	"Split halves": "The upper swing and the lower swing in two tones. Waves are read as one channel, so this splits the swings rather than left and right",
}
const GROW_MIDDLE := "Middle"
const GROW_BOTTOM := "Bottom"
const GROW_TOP := "Top"
const GROWS: PackedStringArray = ["Middle", "Bottom", "Top"]
const COLOUR_THEME := "Theme"
const COLOUR_CLIP := "Clip colour"
const COLOUR_TRACK := "Track colour"
const COLOUR_CUSTOM := "Custom"
const COLOUR_FROMS: PackedStringArray = ["Theme", "Clip colour", "Track colour", "Custom"]
const DEFAULT_COLOUR := "#8fd0ffff"
const DEFAULT_GRAD_TOP := "#ffd166ff"
const DEFAULT_GRAD_BOTTOM := "#3a86ffff"
const DEFAULT_HIGH_COLOUR := "#ff4d4dd9"
const DEFAULT_LOW_COLOUR := "#4d8dffd9"
const DEFAULT_VERY_LOUD_COLOUR := "#ff1f9eff"
const DEFAULT_HIGH_DB := -6.0
const DEFAULT_LOW_DB := -40.0
const DEFAULT_EASE_DB := 6.0
const SEGS := 4
const SOFT_FILL := 0.45
const GHOST_ALPHA := 0.5
const MESH_MAX := 3000
const MIN_AMP := 0.006

static var _memo: Dictionary = {}
static var _memo_ok: bool = false
static var _hooked: bool = false
static var _meshes: Dictionary = {}
static var stats: Dictionary = {"built": 0, "drawn": 0, "columns": 0, "hits": 0}
static var last_mesh: Dictionary = {}
static var last_columns: Dictionary = {}


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func pref_specs() -> Array:
	return [
		[PREF_STYLE, STYLE_MIRRORED, {"label": "Wave style", "type": "enum", "choices": STYLES, "hint": "How every sound wave is drawn: the timeline, the audio editor, the Source monitor, the bin and the offset views."}],
		[PREF_GROW, GROW_MIDDLE, {"label": "Wave grows from", "type": "enum", "choices": GROWS, "hint": "Where the wave starts for Outline, Filled with outline, Bars, Dots, Line, Peak plus RMS and Gradient fill. Mirrored, Bottom up and Top down set this themselves."}],
		[PREF_COLOUR_FROM, COLOUR_THEME, {"label": "Wave colour comes from", "type": "enum", "choices": COLOUR_FROMS}],
		[PREF_COLOUR, DEFAULT_COLOUR, {"label": "Wave colour (custom)", "type": "colour"}],
		[PREF_OPACITY, 1.0, {"label": "Wave opacity", "type": "float", "min": 0.1, "max": 1.0}],
		[PREF_RMS, false, {"label": "Show the average loudness (RMS) inside the wave", "type": "bool"}],
		[PREF_SMOOTH, 0.0, {"label": "Wave smoothing", "type": "float", "min": 0.0, "max": 1.0}],
		[PREF_BAR_W, 3.0, {"label": "Wave bar width (px)", "type": "float", "min": 1.0, "max": 24.0}],
		[PREF_BAR_GAP, 1.0, {"label": "Wave bar gap (px)", "type": "float", "min": 0.0, "max": 12.0}],
		[PREF_LINE, 1.5, {"label": "Wave line thickness (px)", "type": "float", "min": 0.5, "max": 6.0}],
		[PREF_GRAD_TOP, DEFAULT_GRAD_TOP, {"label": "Wave gradient top colour", "type": "colour"}],
		[PREF_GRAD_BOTTOM, DEFAULT_GRAD_BOTTOM, {"label": "Wave gradient bottom colour", "type": "colour"}],
		[PREF_HIGHS, false, {"label": "Show highs on waves", "type": "bool", "hint": "Parts louder than the high line take the high colour."}],
		[PREF_LOWS, false, {"label": "Show lows on waves", "type": "bool", "hint": "Parts quieter than the low line take the low colour."}],
		[PREF_HIGH_DB, DEFAULT_HIGH_DB, {"label": "High line (dBFS)", "type": "float", "min": -60.0, "max": 0.0}],
		[PREF_LOW_DB, DEFAULT_LOW_DB, {"label": "Low line (dBFS)", "type": "float", "min": -90.0, "max": -1.0}],
		[PREF_HIGH_COLOUR, DEFAULT_HIGH_COLOUR, {"label": "High colour", "type": "colour"}],
		[PREF_LOW_COLOUR, DEFAULT_LOW_COLOUR, {"label": "Low colour", "type": "colour"}],
		[PREF_EASE, true, {"label": "Ease into the high and low colours", "type": "bool"}],
		[PREF_EASE_DB, DEFAULT_EASE_DB, {"label": "Ease over (dB)", "type": "float", "min": 0.0, "max": 24.0, "hint": "How far before the line the colour starts to blend in."}],
		[PREF_VERY_LOUD, true, {"label": "Mark very loud sounds on waves", "type": "bool"}],
		[PREF_VERY_LOUD_COLOUR, DEFAULT_VERY_LOUD_COLOUR, {"label": "Very loud colour", "type": "colour"}],
		[PREF_SHOW_DUCKED, true, {"label": "Show what the very loud action takes away", "type": "bool", "hint": "The part that is turned down is drawn see through above the kept wave, with a thin line at the very loud line."}],
		[PREF_SHOW_VOLUME, true, {"label": "Waves show the volume", "type": "bool", "hint": "Waves are drawn as you will hear them, after the clip volume, its keys, the fades, simple Gain effects and the track volume. Turn this off to see the level in the file."}],
	]


static func register_prefs() -> void:
	var p: Node = _prefs()
	if p == null:
		return
	for spec: Array in pref_specs():
		if not bool(p.call("is_registered", String(spec[0]))):
			p.call("register", String(spec[0]), spec[1], spec[2])
	VeryLoud.register_prefs()
	if not _hooked:
		_hooked = true
		p.connect("changed", func(key: String) -> void:
			if key.begins_with("waves.") or key.begins_with("timeline.wave_"):
				_memo_ok = false
		)
	_memo_ok = false


static func listen(ci: CanvasItem) -> void:
	var p: Node = _prefs()
	if p == null or ci == null or ci.has_meta("wave_look_listen"):
		return
	ci.set_meta("wave_look_listen", true)
	p.connect("changed", Callable(ci, "queue_redraw").unbind(1))


static func invalidate() -> void:
	_memo_ok = false


static func _pv(p: Node, key: String, fallback: Variant) -> Variant:
	if p == null or not bool(p.call("is_registered", key)):
		return fallback
	return p.call("get_value", key)


static func colour_of(text: String, fallback: Color) -> Color:
	return Color.from_string(text.strip_edges(), fallback)


static func look() -> Dictionary:
	if _memo_ok and not _memo.is_empty():
		return _memo
	var p: Node = _prefs()
	var lk: Dictionary = {
		"style": String(_pv(p, PREF_STYLE, STYLE_MIRRORED)),
		"grow": String(_pv(p, PREF_GROW, GROW_MIDDLE)),
		"colour_from": String(_pv(p, PREF_COLOUR_FROM, COLOUR_THEME)),
		"colour": colour_of(String(_pv(p, PREF_COLOUR, DEFAULT_COLOUR)), Color(0.56, 0.82, 1.0)),
		"opacity": clampf(float(_pv(p, PREF_OPACITY, 1.0)), 0.05, 1.0),
		"rms": bool(_pv(p, PREF_RMS, false)),
		"smooth": clampf(float(_pv(p, PREF_SMOOTH, 0.0)), 0.0, 1.0),
		"bar_w": clampf(float(_pv(p, PREF_BAR_W, 3.0)), 1.0, 24.0),
		"bar_gap": clampf(float(_pv(p, PREF_BAR_GAP, 1.0)), 0.0, 12.0),
		"line": clampf(float(_pv(p, PREF_LINE, 1.5)), 0.5, 6.0),
		"grad_top": colour_of(String(_pv(p, PREF_GRAD_TOP, DEFAULT_GRAD_TOP)), Color(1.0, 0.82, 0.4)),
		"grad_bottom": colour_of(String(_pv(p, PREF_GRAD_BOTTOM, DEFAULT_GRAD_BOTTOM)), Color(0.23, 0.53, 1.0)),
		"highs": bool(_pv(p, PREF_HIGHS, false)),
		"lows": bool(_pv(p, PREF_LOWS, false)),
		"high_db": float(_pv(p, PREF_HIGH_DB, DEFAULT_HIGH_DB)),
		"low_db": float(_pv(p, PREF_LOW_DB, DEFAULT_LOW_DB)),
		"high_col": colour_of(String(_pv(p, PREF_HIGH_COLOUR, DEFAULT_HIGH_COLOUR)), Color(1.0, 0.3, 0.3, 0.85)),
		"low_col": colour_of(String(_pv(p, PREF_LOW_COLOUR, DEFAULT_LOW_COLOUR)), Color(0.3, 0.55, 1.0, 0.85)),
		"ease": bool(_pv(p, PREF_EASE, true)),
		"ease_db": maxf(float(_pv(p, PREF_EASE_DB, DEFAULT_EASE_DB)), 0.0),
		"loud": bool(_pv(p, PREF_VERY_LOUD, true)),
		"loud_col": colour_of(String(_pv(p, PREF_VERY_LOUD_COLOUR, DEFAULT_VERY_LOUD_COLOUR)), Color(1.0, 0.12, 0.62)),
		"ducked": bool(_pv(p, PREF_SHOW_DUCKED, true)),
		"vol": bool(_pv(p, PREF_SHOW_VOLUME, true)),
		"duck": VeryLoud.settings(),
	}
	lk["sig"] = sig_of(lk)
	_memo = lk
	_memo_ok = p != null
	return lk


static func sig_of(lk: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k: String in ["style", "grow", "colour_from", "opacity", "rms", "smooth", "bar_w", "bar_gap", "line", "highs", "lows", "high_db", "low_db", "ease", "ease_db", "loud", "ducked", "vol"]:
		parts.append(str(lk.get(k, "")))
	for k2: String in ["colour", "grad_top", "grad_bottom", "high_col", "low_col", "loud_col"]:
		parts.append((lk.get(k2, Color.WHITE) as Color).to_html(true))
	var duck: Dictionary = lk.get("duck", {})
	for k3: String in ["mode", "db", "down_db", "percent", "gradient_db", "heard"]:
		parts.append(str(duck.get(k3, "")))
	return str("|".join(parts).hash())


static func volume_on() -> bool:
	return bool(look().get("vol", true))


static func vsig_of(vol: Dictionary) -> int:
	if vol.is_empty() or not volume_on():
		return 0
	return int(vol.get("sig", 0))


static func with_volume(pts: PackedVector2Array, vol: Dictionary, sc: Dictionary) -> PackedVector2Array:
	if vsig_of(vol) == 0:
		return pts
	return WaveVolume.apply(pts, vol, sc)


static func with_style(lk: Dictionary, style: String) -> Dictionary:
	var out: Dictionary = lk.duplicate()
	out["style"] = style
	out["sig"] = sig_of(out)
	return out


static func scale(log_mode: bool, gain: float, floor_db: float = FLOOR_DB) -> Dictionary:
	return {"log": log_mode, "gain": maxf(gain, 0.0001), "floor": floor_db}


static func level_of(amp: float, sc: Dictionary) -> float:
	if amp <= MIN_AMP:
		return 0.0
	var lin: float = amp
	if bool(sc.get("log", false)):
		lin = pow(10.0, (1.0 - amp) * float(sc.get("floor", FLOOR_DB)) / 20.0)
	return lin / float(sc.get("gain", 1.0))


static func amp_of(level: float, sc: Dictionary) -> float:
	var lin: float = level * float(sc.get("gain", 1.0))
	if lin <= 0.0:
		return 0.0
	if not bool(sc.get("log", false)):
		return lin
	var db: float = 20.0 * log(lin) / log(10.0)
	return maxf(1.0 - db / float(sc.get("floor", FLOOR_DB)), 0.0)


static func db_of(level: float) -> float:
	return VeryLoud.lin_to_db(level)


static func _ease01(f: float) -> float:
	var u: float = clampf(f, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _ramp_up(db: float, line: float, ease_on: bool, ease_db: float) -> float:
	if not ease_on or ease_db <= 0.0001:
		return 1.0 if db >= line else 0.0
	return _ease01((db - (line - ease_db)) / ease_db)


static func _ramp_down(db: float, line: float, ease_on: bool, ease_db: float) -> float:
	if not ease_on or ease_db <= 0.0001:
		return 1.0 if db <= line else 0.0
	return _ease01(((line + ease_db) - db) / ease_db)


static func weights(db: float, lk: Dictionary) -> Vector3:
	var ease_on: bool = bool(lk.get("ease", true))
	var ease_db: float = float(lk.get("ease_db", DEFAULT_EASE_DB))
	var w := Vector3.ZERO
	if bool(lk.get("lows", false)):
		w.x = _ramp_down(db, float(lk.get("low_db", DEFAULT_LOW_DB)), ease_on, ease_db)
	if bool(lk.get("highs", false)):
		w.y = _ramp_up(db, float(lk.get("high_db", DEFAULT_HIGH_DB)), ease_on, ease_db)
	if bool(lk.get("loud", true)):
		var loud_db: float = float((lk.get("duck", {}) as Dictionary).get("db", VeryLoud.DEFAULT_DB))
		w.z = 1.0 if db >= loud_db else 0.0
	return w


static func _tint(c: Color, to: Color, w: float) -> Color:
	var k: float = clampf(w * to.a, 0.0, 1.0)
	if k <= 0.0:
		return c
	return Color(lerpf(c.r, to.r, k), lerpf(c.g, to.g, k), lerpf(c.b, to.b, k), c.a)


static func paint(c: Color, w: Vector3, lk: Dictionary) -> Color:
	var out: Color = c
	if w.x > 0.0:
		out = _tint(out, lk["low_col"], w.x)
	if w.y > 0.0:
		out = _tint(out, lk["high_col"], w.y)
	if w.z > 0.0:
		out = _tint(out, lk["loud_col"], w.z)
	return out


static func mark_colour(base: Color, db: float, lk: Dictionary) -> Color:
	return paint(base, weights(db, lk), lk)


static func theme_colour() -> Color:
	return Tk.c["wave"]


static func base_colour(lk: Dictionary, clip_colour: int = -1, media_colour: int = -1, track_colour: int = -1) -> Color:
	var from: String = String(lk.get("colour_from", COLOUR_THEME))
	if from == COLOUR_CUSTOM:
		return lk["colour"]
	if from == COLOUR_CLIP:
		for i: int in [clip_colour, media_colour, track_colour]:
			if i >= 0:
				return Tk.label_colour(i).lightened(0.3)
	elif from == COLOUR_TRACK and track_colour >= 0:
		return Tk.label_colour(track_colour).lightened(0.3)
	return theme_colour()


static func anchor_of(lk: Dictionary) -> String:
	var st: String = String(lk.get("style", STYLE_MIRRORED))
	if st == STYLE_MIRRORED or st == STYLE_SPLIT:
		return GROW_MIDDLE
	if st == STYLE_BOTTOM:
		return GROW_BOTTOM
	if st == STYLE_TOP:
		return GROW_TOP
	var g: String = String(lk.get("grow", GROW_MIDDLE))
	return g if GROWS.has(g) else GROW_MIDDLE


static func needs_x(lk: Dictionary) -> bool:
	var st: String = String(lk.get("style", ""))
	return st == STYLE_BARS or st == STYLE_DOTS


static func _smooth(src: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var r: int = int(round(amount * 6.0))
	if r <= 0:
		return src
	var n: int = src.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var acc: float = 0.0
	var lo: int = 0
	var hi: int = -1
	for i: int in n:
		var want_hi: int = mini(i + r, n - 1)
		while hi < want_hi:
			hi += 1
			acc += src[hi]
		var want_lo: int = maxi(i - r, 0)
		while lo < want_lo:
			acc -= src[lo]
			lo += 1
		out[i] = acc / float(hi - lo + 1)
	return out


static func analyse(pts: PackedVector2Array, lk: Dictionary, sc: Dictionary, vol_gains: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	var n: int = pts.size() / 2
	var has_vol: bool = vol_gains.size() == n and n > 0
	var thr_lin: float = VeryLoud.db_to_lin(float((lk.get("duck", {}) as Dictionary).get("db", VeryLoud.DEFAULT_DB)))
	var thrs := PackedFloat32Array()
	if has_vol:
		thrs.resize(n)
	var xs := PackedFloat32Array()
	var up := PackedFloat32Array()
	var dn := PackedFloat32Array()
	var uk := PackedFloat32Array()
	var dk := PackedFloat32Array()
	var rms := PackedFloat32Array()
	var lv := PackedFloat32Array()
	var gains := PackedFloat32Array()
	var ws: Array[Vector3] = []
	xs.resize(n)
	up.resize(n)
	dn.resize(n)
	uk.resize(n)
	dk.resize(n)
	rms.resize(n)
	lv.resize(n)
	gains.resize(n)
	ws.resize(n)
	var lows_on: bool = bool(lk.get("lows", false))
	var highs_on: bool = bool(lk.get("highs", false))
	var loud_on: bool = bool(lk.get("loud", true))
	var ease_on: bool = bool(lk.get("ease", true))
	var ease_db: float = float(lk.get("ease_db", DEFAULT_EASE_DB))
	var low_db: float = float(lk.get("low_db", DEFAULT_LOW_DB))
	var high_db: float = float(lk.get("high_db", DEFAULT_HIGH_DB))
	var duck: Dictionary = lk.get("duck", {})
	var show_duck: bool = bool(lk.get("ducked", true)) and int(duck.get("mode", -1)) >= 0
	var any_duck: bool = false
	var sq := PackedFloat32Array()
	sq.resize(n)
	for i: int in n:
		var a: Vector2 = pts[i * 2]
		var b: Vector2 = pts[i * 2 + 1]
		xs[i] = a.x
		var u_raw: float = maxf(-a.y, 0.0)
		var d_raw: float = maxf(b.y, 0.0)
		var lu: float = level_of(u_raw, sc)
		var ld: float = level_of(d_raw, sc)
		var level: float = maxf(lu, ld)
		lv[i] = level
		sq[i] = level * level
		var ldb: float = db_of(level)
		var src_level: float = level
		if has_vol:
			var gv: float = vol_gains[i]
			src_level = level / gv if gv > 0.000001 else 0.0
			thrs[i] = clampf(amp_of(thr_lin * gv, sc), 0.0, 1.0)
		var w := Vector3.ZERO
		if lows_on:
			w.x = _ramp_down(ldb, low_db, ease_on, ease_db)
		if highs_on:
			w.y = _ramp_up(ldb, high_db, ease_on, ease_db)
		if loud_on:
			w.z = 1.0 if (db_of(src_level) if has_vol else ldb) >= float(duck.get("db", VeryLoud.DEFAULT_DB)) else 0.0
		ws[i] = w
		var g: float = VeryLoud.gain_for(src_level, duck) if show_duck else 1.0
		gains[i] = g
		up[i] = clampf(u_raw, 0.0, 1.0)
		dn[i] = clampf(d_raw, 0.0, 1.0)
		if g < 0.999999:
			any_duck = true
			uk[i] = clampf(amp_of(lu * g, sc), 0.0, up[i])
			dk[i] = clampf(amp_of(ld * g, sc), 0.0, dn[i])
		else:
			uk[i] = up[i]
			dk[i] = dn[i]
	for i2: int in n:
		var acc: float = 0.0
		var cnt: int = 0
		for j: int in range(maxi(i2 - 2, 0), mini(i2 + 3, n)):
			acc += sq[j]
			cnt += 1
		var r_level: float = sqrt(acc / float(maxi(cnt, 1))) * 0.7071
		rms[i2] = clampf(amp_of(r_level, sc), 0.0, 1.0)
	var amount: float = float(lk.get("smooth", 0.0))
	if amount > 0.0:
		up = _smooth(up, amount)
		dn = _smooth(dn, amount)
		uk = _smooth(uk, amount)
		dk = _smooth(dk, amount)
		rms = _smooth(rms, amount)
	var thr_amp: float = clampf(amp_of(VeryLoud.db_to_lin(float(duck.get("db", VeryLoud.DEFAULT_DB))), sc), 0.0, 1.0)
	return {"n": n, "x": xs, "up": up, "dn": dn, "uk": uk, "dk": dk, "rms": rms, "level": lv, "gain": gains, "w": ws, "any_duck": any_duck, "thr": thr_amp, "thrs": thrs}


static func _edges(anchor: String, u: float, d: float) -> Vector2:
	if anchor == GROW_BOTTOM:
		return Vector2(1.0 - 2.0 * maxf(u, d), 1.0)
	if anchor == GROW_TOP:
		return Vector2(-1.0, -1.0 + 2.0 * maxf(u, d))
	return Vector2(-u, d)


static func _new_mesh() -> Dictionary:
	return {"p": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}


static func _ribbon(m: Dictionary, xs: PackedFloat32Array, tops: PackedFloat32Array, bots: PackedFloat32Array, ctop: PackedColorArray, cbot: PackedColorArray) -> void:
	var n: int = xs.size()
	if n < 2:
		return
	var p: PackedVector2Array = m["p"]
	var c: PackedColorArray = m["c"]
	var idx: PackedInt32Array = m["i"]
	var base: int = p.size()
	p.resize(base + n * 2)
	c.resize(base + n * 2)
	for i: int in n:
		p[base + i * 2] = Vector2(xs[i], tops[i])
		p[base + i * 2 + 1] = Vector2(xs[i], bots[i])
		c[base + i * 2] = ctop[i]
		c[base + i * 2 + 1] = cbot[i]
	var w: int = idx.size()
	idx.resize(w + (n - 1) * 6)
	for k: int in n - 1:
		var a: int = base + k * 2
		idx[w] = a
		idx[w + 1] = a + 1
		idx[w + 2] = a + 2
		idx[w + 3] = a + 1
		idx[w + 4] = a + 3
		idx[w + 5] = a + 2
		w += 6
	m["p"] = p
	m["c"] = c
	m["i"] = idx


static func _quad(m: Dictionary, x0: float, x1: float, y0: float, y1: float, ctop: Color, cbot: Color) -> void:
	var p: PackedVector2Array = m["p"]
	var c: PackedColorArray = m["c"]
	var idx: PackedInt32Array = m["i"]
	var base: int = p.size()
	p.append(Vector2(x0, y0))
	p.append(Vector2(x0, y1))
	p.append(Vector2(x1, y0))
	p.append(Vector2(x1, y1))
	c.append(ctop)
	c.append(cbot)
	c.append(ctop)
	c.append(cbot)
	idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	m["p"] = p
	m["c"] = c
	m["i"] = idx


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func _cols(base: Color, ws: Array[Vector3], lk: Dictionary, alpha: float) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(ws.size())
	var b: Color = _alpha(base, alpha)
	for i: int in ws.size():
		out[i] = paint(b, ws[i], lk)
	return out


static func _alt(base: Color) -> Color:
	var h: float = fposmod(base.h + 0.12, 1.0)
	return Color.from_hsv(h, clampf(base.s * 0.9 + 0.1, 0.0, 1.0), clampf(base.v * 0.85, 0.0, 1.0), base.a)


static func _fill(m: Dictionary, an: Dictionary, anchor: String, us: PackedFloat32Array, ds: PackedFloat32Array, cols: PackedColorArray, cols_b: PackedColorArray) -> void:
	var n: int = int(an["n"])
	var tops := PackedFloat32Array()
	var bots := PackedFloat32Array()
	tops.resize(n)
	bots.resize(n)
	for i: int in n:
		var e: Vector2 = _edges(anchor, us[i], ds[i])
		tops[i] = e.x
		bots[i] = e.y
	_ribbon(m, an["x"], tops, bots, cols, cols_b)


static func _edge_lines(m: Dictionary, an: Dictionary, anchor: String, us: PackedFloat32Array, ds: PackedFloat32Array, t: float, cols: PackedColorArray) -> void:
	var n: int = int(an["n"])
	var t0 := PackedFloat32Array()
	var t1 := PackedFloat32Array()
	var b0 := PackedFloat32Array()
	var b1 := PackedFloat32Array()
	t0.resize(n)
	t1.resize(n)
	b0.resize(n)
	b1.resize(n)
	for i: int in n:
		var e: Vector2 = _edges(anchor, us[i], ds[i])
		var top_y: float = e.x if anchor != GROW_TOP else e.y
		t0[i] = top_y - t
		t1[i] = top_y + t
		b0[i] = e.y - t
		b1[i] = e.y + t
	_ribbon(m, an["x"], t0, t1, cols, cols)
	if anchor == GROW_MIDDLE:
		_ribbon(m, an["x"], b0, b1, cols, cols)


static func _gradient(m: Dictionary, an: Dictionary, anchor: String, lk: Dictionary, alpha: float) -> void:
	var n: int = int(an["n"])
	var ws: Array[Vector3] = an["w"]
	var us: PackedFloat32Array = an["uk"]
	var ds: PackedFloat32Array = an["dk"]
	var bottom: Color = _alpha(lk["grad_bottom"], alpha)
	var top: Color = _alpha(lk["grad_top"], alpha)
	var zero := PackedFloat32Array()
	zero.resize(n)
	var c_base := PackedColorArray()
	var c_up := PackedColorArray()
	var c_dn := PackedColorArray()
	var tops := PackedFloat32Array()
	var bots := PackedFloat32Array()
	c_base.resize(n)
	c_up.resize(n)
	c_dn.resize(n)
	tops.resize(n)
	bots.resize(n)
	for i: int in n:
		c_base[i] = paint(bottom, ws[i], lk)
		var a_up: float = us[i]
		var a_dn: float = ds[i]
		if anchor != GROW_MIDDLE:
			a_up = maxf(us[i], ds[i])
			a_dn = a_up
		c_up[i] = paint(bottom.lerp(top, clampf(a_up, 0.0, 1.0)), ws[i], lk)
		c_dn[i] = paint(bottom.lerp(top, clampf(a_dn, 0.0, 1.0)), ws[i], lk)
		var e: Vector2 = _edges(anchor, us[i], ds[i])
		tops[i] = e.x
		bots[i] = e.y
	if anchor == GROW_MIDDLE:
		_ribbon(m, an["x"], tops, zero, c_up, c_base)
		_ribbon(m, an["x"], zero, bots, c_base, c_dn)
	elif anchor == GROW_BOTTOM:
		_ribbon(m, an["x"], tops, bots, c_up, c_base)
	else:
		_ribbon(m, an["x"], tops, bots, c_base, c_dn)


static func _groups(an: Dictionary, x_px: float, lk: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = int(an["n"])
	if n < 1:
		return out
	var xs: PackedFloat32Array = an["x"]
	var px: float = maxf(x_px, 0.000001)
	var period: float = (float(lk.get("bar_w", 3.0)) + float(lk.get("bar_gap", 1.0))) / px
	var bw: float = float(lk.get("bar_w", 3.0)) / px
	var x_lo: float = xs[0]
	var x_hi: float = xs[n - 1]
	var lv: PackedFloat32Array = an["level"]
	var a_up: PackedFloat32Array = an["up"]
	var a_dn: PackedFloat32Array = an["dn"]
	var a_uk: PackedFloat32Array = an["uk"]
	var a_dk: PackedFloat32Array = an["dk"]
	var a_rms: PackedFloat32Array = an["rms"]
	var a_w: Array[Vector3] = an["w"]
	var a_gain: PackedFloat32Array = an["gain"]
	var cur: int = -2147483647
	var g: Dictionary = {}
	for i: int in n:
		var k: int = int(floor(xs[i] / period))
		if k != cur:
			if not g.is_empty():
				out.append(g)
			cur = k
			var gx0: float = float(k) * period
			g = {"x0": maxf(gx0, x_lo), "x1": minf(gx0 + bw, x_hi), "u": 0.0, "d": 0.0, "uk": 0.0, "dk": 0.0, "r": 0.0, "lv": -1.0, "w": Vector3.ZERO, "g": 1.0}
		g["u"] = maxf(float(g["u"]), a_up[i])
		g["d"] = maxf(float(g["d"]), a_dn[i])
		g["uk"] = maxf(float(g["uk"]), a_uk[i])
		g["dk"] = maxf(float(g["dk"]), a_dk[i])
		g["r"] = maxf(float(g["r"]), a_rms[i])
		if lv[i] > float(g["lv"]):
			g["lv"] = lv[i]
			g["w"] = a_w[i]
			g["g"] = a_gain[i]
	if not g.is_empty():
		out.append(g)
	var kept: Array[Dictionary] = []
	for one: Dictionary in out:
		if float(one["x1"]) > float(one["x0"]):
			kept.append(one)
	return kept


static func _ghost(m: Dictionary, an: Dictionary, anchor: String, lk: Dictionary, y_px: float, alpha: float, with_fill: bool) -> void:
	if not bool(an["any_duck"]):
		return
	var n: int = int(an["n"])
	var gains: PackedFloat32Array = an["gain"]
	var ghost: Color = _alpha(lk["loud_col"], GHOST_ALPHA * alpha)
	var clear: Color = Color(ghost, 0.0)
	var gc := PackedColorArray()
	gc.resize(n)
	for i: int in n:
		gc[i] = ghost if gains[i] < 0.999999 else clear
	var up: PackedFloat32Array = an["up"]
	var dn: PackedFloat32Array = an["dn"]
	var uk: PackedFloat32Array = an["uk"]
	var dk: PackedFloat32Array = an["dk"]
	var t0 := PackedFloat32Array()
	var t1 := PackedFloat32Array()
	var b0 := PackedFloat32Array()
	var b1 := PackedFloat32Array()
	t0.resize(n)
	t1.resize(n)
	b0.resize(n)
	b1.resize(n)
	for i2: int in n:
		var full: Vector2 = _edges(anchor, up[i2], dn[i2])
		var kept: Vector2 = _edges(anchor, uk[i2], dk[i2])
		if anchor == GROW_TOP:
			t0[i2] = kept.y
			t1[i2] = full.y
		else:
			t0[i2] = full.x
			t1[i2] = kept.x
		b0[i2] = kept.y
		b1[i2] = full.y
	if with_fill:
		_ribbon(m, an["x"], t0, t1, gc, gc)
		if anchor == GROW_MIDDLE:
			_ribbon(m, an["x"], b0, b1, gc, gc)
	var line_c: Color = _alpha(lk["loud_col"], 0.9 * alpha)
	var lc := PackedColorArray()
	lc.resize(n)
	for i3: int in n:
		lc[i3] = line_c if gains[i3] < 0.999999 else Color(line_c, 0.0)
	var th: float = 0.5 / maxf(y_px, 0.0001)
	var a_t: float = float(an["thr"])
	var thrs: PackedFloat32Array = an.get("thrs", PackedFloat32Array())
	var per_point: bool = thrs.size() == n
	var l0 := PackedFloat32Array()
	var l1 := PackedFloat32Array()
	var l2 := PackedFloat32Array()
	var l3 := PackedFloat32Array()
	l0.resize(n)
	l1.resize(n)
	l2.resize(n)
	l3.resize(n)
	for i4: int in n:
		var at: float = thrs[i4] if per_point else a_t
		var e: Vector2 = _edges(anchor, at, at)
		var y_line: float = e.x if anchor != GROW_TOP else e.y
		l0[i4] = y_line - th
		l1[i4] = y_line + th
		l2[i4] = e.y - th
		l3[i4] = e.y + th
	_ribbon(m, an["x"], l0, l1, lc, lc)
	if anchor == GROW_MIDDLE:
		_ribbon(m, an["x"], l2, l3, lc, lc)


static func _bars(m: Dictionary, an: Dictionary, anchor: String, lk: Dictionary, base: Color, x_px: float, y_px: float, alpha: float, dots: bool) -> void:
	var groups: Array[Dictionary] = _groups(an, x_px, lk)
	var b: Color = _alpha(base, alpha)
	var ghost: Color = _alpha(lk["loud_col"], GHOST_ALPHA * alpha)
	var dot_h: float = float(lk.get("bar_w", 3.0)) * 0.5 / maxf(y_px, 0.0001)
	for g: Dictionary in groups:
		var col: Color = paint(b, g["w"], lk)
		var x0: float = float(g["x0"])
		var x1: float = float(g["x1"])
		var full: Vector2 = _edges(anchor, float(g["u"]), float(g["d"]))
		var kept: Vector2 = _edges(anchor, float(g["uk"]), float(g["dk"]))
		if dots:
			var top_y: float = kept.x if anchor != GROW_TOP else kept.y
			_quad(m, x0, x1, top_y - dot_h, top_y + dot_h, col, col)
			if anchor == GROW_MIDDLE:
				_quad(m, x0, x1, kept.y - dot_h, kept.y + dot_h, col, col)
			continue
		_quad(m, x0, x1, kept.x, kept.y, col, col)
		if bool(lk.get("rms", false)):
			var re: Vector2 = _edges(anchor, float(g["r"]), float(g["r"]))
			var rc: Color = paint(b.lightened(0.3), g["w"], lk)
			_quad(m, x0, x1, re.x, re.y, rc, rc)
		if float(g["g"]) < 0.999999:
			if anchor == GROW_TOP:
				_quad(m, x0, x1, kept.y, full.y, ghost, ghost)
			else:
				_quad(m, x0, x1, full.x, kept.x, ghost, ghost)
				if anchor == GROW_MIDDLE:
					_quad(m, x0, x1, kept.y, full.y, ghost, ghost)


static var _fast_idx: Dictionary = {}
static var fast_builds: int = 0


static func _pair_indices(pairs: int) -> PackedInt32Array:
	var hit: Variant = _fast_idx.get(pairs, null)
	if hit is PackedInt32Array:
		return hit
	var idx := PackedInt32Array()
	idx.resize(maxi(pairs - 1, 0) * 6)
	var w: int = 0
	for k: int in pairs - 1:
		var a: int = k * 2
		idx[w] = a
		idx[w + 1] = a + 1
		idx[w + 2] = a + 2
		idx[w + 3] = a + 1
		idx[w + 4] = a + 3
		idx[w + 5] = a + 2
		w += 6
	if _fast_idx.size() > 64:
		_fast_idx.clear()
	_fast_idx[pairs] = idx
	return idx


static func _fast_mesh(pts: PackedVector2Array, lk: Dictionary, base: Color, sc: Dictionary, vol_gains: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	if String(lk.get("style", "")) != STYLE_MIRRORED or bool(lk.get("highs", false)) or bool(lk.get("lows", false)) or bool(lk.get("rms", false)) or float(lk.get("smooth", 0.0)) > 0.0:
		return {}
	var duck: Dictionary = lk.get("duck", {})
	var watch: bool = bool(lk.get("loud", true)) or (bool(lk.get("ducked", true)) and int(duck.get("mode", -1)) >= 0)
	var thr: float = amp_of(VeryLoud.db_to_lin(float(duck.get("db", VeryLoud.DEFAULT_DB))), sc) if watch else INF
	var limit: float = minf(thr, 1.0)
	var n: int = pts.size() / 2
	if vol_gains.size() == n and n > 0:
		var line_lin: float = VeryLoud.db_to_lin(float(duck.get("db", VeryLoud.DEFAULT_DB))) if watch else INF
		for j: int in n:
			var gv: float = vol_gains[j]
			var heard: float = maxf(level_of(maxf(-pts[j * 2].y, 0.0), sc), level_of(maxf(pts[j * 2 + 1].y, 0.0), sc))
			if gv > 0.000001 and heard / gv >= line_lin * 0.999:
				return {}
			if -pts[j * 2].y >= 1.0 or pts[j * 2 + 1].y >= 1.0:
				return {}
	else:
		for i: int in n:
			if -pts[i * 2].y >= limit or pts[i * 2 + 1].y >= limit:
				return {}
	var c := PackedColorArray()
	c.resize(n * 2)
	c.fill(_alpha(base, float(lk.get("opacity", 1.0))))
	fast_builds += 1
	return {"p": pts, "c": c, "i": _pair_indices(n), "any_duck": false, "anchor": GROW_MIDDLE, "style": STYLE_MIRRORED}


static func mesh(pts: PackedVector2Array, lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float, vol_gains: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	var m: Dictionary = _new_mesh()
	if pts.size() < 4:
		return m
	var quick: Dictionary = _fast_mesh(pts, lk, base, sc, vol_gains)
	if not quick.is_empty():
		stats["built"] = int(stats["built"]) + 1
		last_mesh = quick
		return quick
	var an: Dictionary = analyse(pts, lk, sc, vol_gains)
	var style: String = String(lk.get("style", STYLE_MIRRORED))
	var anchor: String = anchor_of(lk)
	var alpha: float = float(lk.get("opacity", 1.0))
	var ws: Array[Vector3] = an["w"]
	var t: float = float(lk.get("line", 1.5)) * 0.5 / maxf(y_px, 0.0001)
	var solid: PackedColorArray = _cols(base, ws, lk, alpha)
	if style == STYLE_BARS or style == STYLE_DOTS:
		_bars(m, an, anchor, lk, base, x_px, y_px, alpha, style == STYLE_DOTS)
	elif style == STYLE_OUTLINE:
		_edge_lines(m, an, anchor, an["uk"], an["dk"], t, solid)
	elif style == STYLE_LINE:
		_edge_lines(m, an, anchor, an["rms"], an["rms"], t, solid)
	elif style == STYLE_GRADIENT:
		_gradient(m, an, anchor, lk, alpha)
	elif style == STYLE_SPLIT:
		var n: int = int(an["n"])
		var zero := PackedFloat32Array()
		zero.resize(n)
		var tops := PackedFloat32Array()
		tops.resize(n)
		var uk: PackedFloat32Array = an["uk"]
		for i: int in n:
			tops[i] = -uk[i]
		var alt: PackedColorArray = _cols(_alt(base), ws, lk, alpha)
		_ribbon(m, an["x"], tops, zero, solid, solid)
		_ribbon(m, an["x"], zero, an["dk"], alt, alt)
	elif style == STYLE_PEAK_RMS:
		var soft: PackedColorArray = _cols(base.lightened(0.25), ws, lk, alpha * SOFT_FILL)
		_fill(m, an, anchor, an["uk"], an["dk"], soft, soft)
		_fill(m, an, anchor, an["rms"], an["rms"], solid, solid)
	elif style == STYLE_FILLED_OUTLINE:
		var soft2: PackedColorArray = _cols(base, ws, lk, alpha * SOFT_FILL)
		_fill(m, an, anchor, an["uk"], an["dk"], soft2, soft2)
		_edge_lines(m, an, anchor, an["uk"], an["dk"], t, solid)
	else:
		_fill(m, an, anchor, an["uk"], an["dk"], solid, solid)
	if bool(lk.get("rms", false)) and style != STYLE_PEAK_RMS and style != STYLE_LINE and style != STYLE_BARS and style != STYLE_DOTS and style != STYLE_OUTLINE:
		var lit: PackedColorArray = _cols(base.lightened(0.3), ws, lk, alpha)
		_fill(m, an, anchor, an["rms"], an["rms"], lit, lit)
	_ghost(m, an, anchor, lk, y_px, alpha, style != STYLE_BARS and style != STYLE_DOTS and style != STYLE_LINE)
	m["any_duck"] = an["any_duck"]
	m["anchor"] = anchor
	m["style"] = style
	stats["built"] = int(stats["built"]) + 1
	last_mesh = m
	return m


static var _mk_sig: String = ""
static var _mk_base: Color = Color(0.0, 0.0, 0.0, 0.0)
static var _mk_log: bool = false
static var _mk_gain: float = -1.0
static var _mk_y: int = -1
static var _mk_x: int = -100000
static var _mk_out: String = ""


static func mesh_key(lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float) -> String:
	var sig: String = String(lk.get("sig", ""))
	var lg: bool = bool(sc.get("log", false))
	var gn: float = float(sc.get("gain", 1.0))
	var yq: int = int(round(y_px))
	var xq: int = int(round(log(maxf(absf(x_px), 0.0000001)) / log(2.0) * 4.0)) if needs_x(lk) else -100001
	if sig == _mk_sig and base == _mk_base and lg == _mk_log and gn == _mk_gain and yq == _mk_y and xq == _mk_x:
		return _mk_out
	_mk_sig = sig
	_mk_base = base
	_mk_log = lg
	_mk_gain = gn
	_mk_y = yq
	_mk_x = xq
	_mk_out = _mesh_key_text(lk, base, sc, x_px, y_px)
	return _mk_out


static func _mesh_key_text(lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float) -> String:
	var k: String = String(lk.get("sig", "")) + "|" + base.to_html(true) + "|" + str(bool(sc.get("log", false))) + String.num(float(sc.get("gain", 1.0)), 3) + "|" + str(int(round(y_px)))
	if needs_x(lk):
		k += "|" + str(int(round(log(maxf(absf(x_px), 0.0000001)) / log(2.0) * 4.0)))
	return k


static func draw_mesh(ci: CanvasItem, m: Dictionary) -> void:
	var idx: PackedInt32Array = m.get("i", PackedInt32Array())
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, m["p"], m["c"])
	stats["drawn"] = int(stats["drawn"]) + 1


static func draw(ci: CanvasItem, pts: PackedVector2Array, base: Color, sc: Dictionary, x_px: float, y_px: float, key: String = "", vol: Dictionary = {}) -> Dictionary:
	var lk: Dictionary = look()
	var vsig: int = mesh_vsig(lk, vol)
	var m: Dictionary = {}
	var bucket: Dictionary = {}
	if not key.is_empty():
		var mk: String = mesh_key(lk, base, sc, x_px, y_px)
		var got: Variant = _meshes.get(mk, null)
		if got is Dictionary:
			bucket = got
		else:
			if _meshes.size() >= 40:
				_meshes.clear()
			_meshes[mk] = bucket
		var hit: Variant = bucket.get(key, null)
		if hit is Dictionary and int((hit as Dictionary).get("vsig", 0)) == vsig:
			m = hit
			stats["hits"] = int(stats["hits"]) + 1
	if m.is_empty():
		m = _heard_mesh(pts, vol, vsig, lk, base, sc, x_px, y_px)
		if vsig != 0:
			m["vsig"] = vsig
		if not key.is_empty():
			if bucket.size() >= MESH_MAX:
				bucket.clear()
			bucket[key] = m
	draw_mesh(ci, m)
	return m


static func judged_heard(lk: Dictionary) -> bool:
	return bool((lk.get("duck", {}) as Dictionary).get("heard", true))


static func mesh_vsig(lk: Dictionary, vol: Dictionary) -> int:
	if vol.is_empty():
		return 0
	if bool(lk.get("vol", true)) or judged_heard(lk):
		return int(vol.get("sig", 0))
	return 0


static func drawn_and_judge(pts: PackedVector2Array, vol: Dictionary, lk: Dictionary, sc: Dictionary) -> Array:
	var shown: bool = bool(lk.get("vol", true))
	var drawn: PackedVector2Array = WaveVolume.apply(pts, vol, sc)
	var total: PackedFloat32Array = WaveVolume.last_gains.duplicate()
	if not judged_heard(lk):
		return [drawn, total] if shown else [pts, PackedFloat32Array()]
	var down: PackedFloat32Array = WaveVolume.downstream_for(pts, vol)
	if shown:
		return [drawn, down]
	var judge: PackedFloat32Array = PackedFloat32Array()
	judge.resize(down.size())
	for i: int in down.size():
		var t: float = total[i] if i < total.size() else 1.0
		judge[i] = down[i] / t if t > 0.000001 else 1000000000.0
	return [pts, judge]


static func _heard_mesh(pts: PackedVector2Array, vol: Dictionary, vsig: int, lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float) -> Dictionary:
	if vsig == 0:
		return mesh(pts, lk, base, sc, absf(x_px), absf(y_px))
	var dj: Array = drawn_and_judge(pts, vol, lk, sc)
	return mesh(dj[0], lk, base, sc, absf(x_px), absf(y_px), dj[1])


static func columns_heard(pts: PackedVector2Array, vol: Dictionary, lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float) -> Dictionary:
	if mesh_vsig(lk, vol) == 0:
		return columns(pts, lk, base, sc, x_px, y_px)
	var dj: Array = drawn_and_judge(pts, vol, lk, sc)
	return columns(dj[0], lk, base, sc, x_px, y_px, dj[1])


static func draw_in(ci: CanvasItem, holder: Dictionary, pts: PackedVector2Array, base: Color, sc: Dictionary, x_px: float, y_px: float, vol: Dictionary = {}) -> Dictionary:
	var lk: Dictionary = look()
	var k: String = mesh_key(lk, base, sc, x_px, y_px)
	var vsig: int = mesh_vsig(lk, vol)
	var hit: Variant = holder.get("_look_mesh", null)
	var m: Dictionary = {}
	if hit is Dictionary and String((hit as Dictionary).get("key", "")) == k and int((hit as Dictionary).get("vsig", 0)) == vsig:
		m = (hit as Dictionary)["mesh"]
	else:
		m = _heard_mesh(pts, vol, vsig, lk, base, sc, x_px, y_px)
		holder["_look_mesh"] = {"key": k, "mesh": m, "vsig": vsig}
	draw_mesh(ci, m)
	return m


static func clear_cache() -> void:
	_meshes.clear()


static func _seg(p: PackedVector2Array, c: PackedColorArray, at: int, x: float, y0: float, y1: float, col: Color) -> void:
	p[at * 2] = Vector2(x, y0)
	p[at * 2 + 1] = Vector2(x, y1)
	c[at] = col


static func columns(pts: PackedVector2Array, lk: Dictionary, base: Color, sc: Dictionary, x_px: float, y_px: float, vol_gains: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	var n: int = pts.size() / 2
	var p := PackedVector2Array()
	var c := PackedColorArray()
	if n < 1:
		return {"p": p, "c": c, "n": 0}
	p.resize(n * SEGS * 2)
	c.resize(n * SEGS)
	var an: Dictionary = analyse(pts, lk, sc, vol_gains)
	var style: String = String(lk.get("style", STYLE_MIRRORED))
	var anchor: String = anchor_of(lk)
	var alpha: float = float(lk.get("opacity", 1.0))
	var b: Color = _alpha(base, alpha)
	var clear: Color = Color(b, 0.0)
	var ghost: Color = _alpha(lk["loud_col"], GHOST_ALPHA * alpha)
	var t: float = maxf(float(lk.get("line", 1.5)) * 0.5, 0.5) / maxf(y_px, 0.0001)
	var xs: PackedFloat32Array = an["x"]
	var up: PackedFloat32Array = an["up"]
	var dn: PackedFloat32Array = an["dn"]
	var uk: PackedFloat32Array = an["uk"]
	var dk: PackedFloat32Array = an["dk"]
	var rms: PackedFloat32Array = an["rms"]
	var gains: PackedFloat32Array = an["gain"]
	var ws: Array[Vector3] = an["w"]
	var bars: bool = style == STYLE_BARS or style == STYLE_DOTS
	var px: float = maxf(absf(x_px), 0.000001)
	var period: float = float(lk.get("bar_w", 3.0)) + float(lk.get("bar_gap", 1.0))
	var bar_w: float = float(lk.get("bar_w", 3.0))
	var gmax_u := PackedFloat32Array()
	var gmax_d := PackedFloat32Array()
	if bars:
		gmax_u.resize(n)
		gmax_d.resize(n)
		var start: int = 0
		while start < n:
			var k: int = int(floor(xs[start] * px / period))
			var stop: int = start
			var mu: float = 0.0
			var md: float = 0.0
			while stop < n and int(floor(xs[stop] * px / period)) == k:
				mu = maxf(mu, uk[stop])
				md = maxf(md, dk[stop])
				stop += 1
			for j: int in range(start, stop):
				gmax_u[j] = mu
				gmax_d[j] = md
			start = stop
	var grad_b: Color = _alpha(lk["grad_bottom"], alpha)
	var grad_t: Color = _alpha(lk["grad_top"], alpha)
	var show_rms: bool = bool(lk.get("rms", false))
	for i: int in n:
		var x: float = xs[i]
		var w: Vector3 = ws[i]
		var col: Color = paint(b, w, lk)
		for s: int in SEGS:
			_seg(p, c, i * SEGS + s, x, 0.0, 0.0, clear)
		if up[i] <= MIN_AMP and dn[i] <= MIN_AMP:
			continue
		var u: float = uk[i]
		var d: float = dk[i]
		if bars:
			if fposmod(x * px, period) >= bar_w:
				continue
			u = gmax_u[i]
			d = gmax_d[i]
		var e: Vector2 = _edges(anchor, u, d)
		var top_y: float = e.x if anchor != GROW_TOP else e.y
		if style == STYLE_OUTLINE:
			_seg(p, c, i * SEGS, x, top_y - t, top_y + t, col)
			if anchor == GROW_MIDDLE:
				_seg(p, c, i * SEGS + 1, x, e.y - t, e.y + t, col)
		elif style == STYLE_LINE:
			var re: Vector2 = _edges(anchor, rms[i], rms[i])
			var ry: float = re.x if anchor != GROW_TOP else re.y
			_seg(p, c, i * SEGS, x, ry - t, ry + t, col)
			if anchor == GROW_MIDDLE:
				_seg(p, c, i * SEGS + 1, x, re.y - t, re.y + t, col)
		elif style == STYLE_DOTS:
			var dh: float = bar_w * 0.5 / maxf(y_px, 0.0001)
			_seg(p, c, i * SEGS, x, top_y - dh, top_y + dh, col)
			if anchor == GROW_MIDDLE:
				_seg(p, c, i * SEGS + 1, x, e.y - dh, e.y + dh, col)
		elif style == STYLE_SPLIT:
			_seg(p, c, i * SEGS, x, -u, 0.0, col)
			_seg(p, c, i * SEGS + 1, x, 0.0, d, paint(_alpha(_alt(base), alpha), w, lk))
		elif style == STYLE_GRADIENT:
			_seg(p, c, i * SEGS, x, e.x, e.y, paint(grad_b.lerp(grad_t, clampf(maxf(u, d), 0.0, 1.0)), w, lk))
		elif style == STYLE_PEAK_RMS:
			_seg(p, c, i * SEGS, x, e.x, e.y, paint(_alpha(base.lightened(0.25), alpha * SOFT_FILL), w, lk))
			var r2: Vector2 = _edges(anchor, rms[i], rms[i])
			_seg(p, c, i * SEGS + 1, x, r2.x, r2.y, col)
		elif style == STYLE_FILLED_OUTLINE:
			_seg(p, c, i * SEGS, x, e.x, e.y, paint(_alpha(base, alpha * SOFT_FILL), w, lk))
			_seg(p, c, i * SEGS + 1, x, top_y - t, top_y + t, col)
		else:
			_seg(p, c, i * SEGS, x, e.x, e.y, col)
		if show_rms and (style == STYLE_MIRRORED or style == STYLE_BOTTOM or style == STYLE_TOP or style == STYLE_GRADIENT or style == STYLE_BARS):
			var r3: Vector2 = _edges(anchor, rms[i], rms[i])
			_seg(p, c, i * SEGS + 1, x, r3.x, r3.y, paint(_alpha(base.lightened(0.3), alpha), w, lk))
		if gains[i] < 0.999999 and style != STYLE_LINE:
			var full: Vector2 = _edges(anchor, up[i] if not bars else maxf(up[i], u), dn[i] if not bars else maxf(dn[i], d))
			var kept: Vector2 = _edges(anchor, uk[i], dk[i])
			if anchor == GROW_TOP:
				_seg(p, c, i * SEGS + 2, x, kept.y, full.y, ghost)
			else:
				_seg(p, c, i * SEGS + 2, x, full.x, kept.x, ghost)
				if anchor == GROW_MIDDLE:
					_seg(p, c, i * SEGS + 3, x, kept.y, full.y, ghost)
	stats["columns"] = int(stats["columns"]) + 1
	var out: Dictionary = {"p": p, "c": c, "n": n, "anchor": anchor, "style": style, "any_duck": an["any_duck"]}
	last_columns = out
	return out


static func draw_columns(ci: CanvasItem, cols: Dictionary, from_pair: int = 0, to_pair: int = -1) -> void:
	var p: PackedVector2Array = cols.get("p", PackedVector2Array())
	var c: PackedColorArray = cols.get("c", PackedColorArray())
	var n: int = int(cols.get("n", 0))
	if n <= 0 or p.is_empty():
		return
	var a: int = clampi(from_pair, 0, n)
	var z: int = n if to_pair < 0 else clampi(to_pair, a, n)
	if z <= a:
		return
	if a == 0 and z == n:
		ci.draw_multiline_colors(p, c, -1.0)
	else:
		ci.draw_multiline_colors(p.slice(a * SEGS * 2, z * SEGS * 2), c.slice(a * SEGS, z * SEGS), -1.0)
	stats["drawn"] = int(stats["drawn"]) + 1


static func columns_cached(holder: Dictionary, pts: PackedVector2Array, base: Color, sc: Dictionary, x_px: float, y_px: float, vol: Dictionary = {}) -> Dictionary:
	var lk: Dictionary = look()
	var k: String = mesh_key(lk, base, sc, x_px, y_px)
	var vsig: int = mesh_vsig(lk, vol)
	var hit: Variant = holder.get("_look_cols", null)
	if hit is Dictionary and String((hit as Dictionary).get("key", "")) == k and int((hit as Dictionary).get("vsig", 0)) == vsig:
		return (hit as Dictionary)["cols"]
	var cols: Dictionary = columns_heard(pts, vol if vsig != 0 else {}, lk, base, sc, x_px, y_px)
	holder["_look_cols"] = {"key": k, "cols": cols, "vsig": vsig}
	return cols


static func amps_to_pairs(amps: PackedFloat32Array, x0: float = 0.5, step: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(amps.size() * 2)
	for i: int in amps.size():
		var x: float = x0 + float(i) * step
		out[i * 2] = Vector2(x, -amps[i])
		out[i * 2 + 1] = Vector2(x, amps[i])
	return out


static func draw_amp_columns(ci: CanvasItem, amps: PackedFloat32Array, mid: float, half: float, base: Color, sc: Dictionary, vol: Dictionary = {}) -> Dictionary:
	listen(ci)
	if amps.is_empty() or half <= 0.0:
		return {}
	var cols: Dictionary = columns_heard(amps_to_pairs(amps), vol, look(), base, sc, 1.0, half)
	ci.draw_set_transform(Vector2(0.0, mid), 0.0, Vector2(1.0, half))
	draw_columns(ci, cols)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return cols


static func sample_pairs(n: int = 72) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n * 2)
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var env: float = 0.25 + 0.45 * absf(sin(t * 7.0))
		if t > 0.62 and t < 0.74:
			env = 1.0
		if t > 0.86:
			env = 0.004
		var up: float = clampf(env * (0.8 + 0.2 * absf(sin(t * 31.0))), 0.0, 1.0)
		var dn: float = clampf(env * (0.75 + 0.25 * absf(cos(t * 27.0))), 0.0, 1.0)
		out[i * 2] = Vector2(t, -up)
		out[i * 2 + 1] = Vector2(t, dn)
	return out
