extends RefCounted

const GROUPS: Array = [
	{"id": "level", "label": "Level"},
	{"id": "fades", "label": "Fades and shaping"},
	{"id": "clean", "label": "Clean up"},
	{"id": "tone", "label": "Tone"},
	{"id": "time", "label": "Time and pitch"},
	{"id": "space", "label": "Space and stereo"},
	{"id": "fun", "label": "Character"},
	{"id": "edit", "label": "Cut"},
]

const OPS: Array = [
	{"id": "amplify", "label": "Amplify", "group": "level", "filters": ["volume"], "fields": [{"key": "gain", "label": "Gain (dB)", "type": "float", "default": 3.0}]},
	{"id": "normalize", "label": "Normalize", "group": "level", "filters": ["volume"], "measure": "peak", "fields": [{"key": "target", "label": "Peak target (dB)", "type": "float", "default": -1.0}]},
	{"id": "loudness", "label": "Loudness normalize", "group": "level", "filters": ["loudnorm"], "fields": [{"key": "lufs", "label": "Target loudness (LUFS)", "type": "float", "default": -16.0}, {"key": "tp", "label": "True peak (dBTP)", "type": "float", "default": -1.5}]},
	{"id": "compressor", "label": "Compressor", "group": "level", "filters": ["acompressor"], "fields": [{"key": "threshold", "label": "Threshold (dB)", "type": "float", "default": -18.0}, {"key": "ratio", "label": "Ratio", "type": "float", "default": 3.0}, {"key": "attack", "label": "Attack (ms)", "type": "float", "default": 20.0}, {"key": "release", "label": "Release (ms)", "type": "float", "default": 250.0}, {"key": "makeup", "label": "Makeup gain (dB)", "type": "float", "default": 0.0}]},
	{"id": "limiter", "label": "Limiter", "group": "level", "filters": ["alimiter"], "fields": [{"key": "ceiling", "label": "Ceiling (dB)", "type": "float", "default": -1.0}]},
	{"id": "leveler", "label": "Auto leveler", "group": "level", "filters": ["dynaudnorm"], "fields": [{"key": "frame", "label": "Frame (ms)", "type": "int", "default": 500}, {"key": "peak", "label": "Peak (dB)", "type": "float", "default": -0.5}]},
	{"id": "fade_in", "label": "Fade in", "group": "fades", "filters": ["afade"], "fields": [{"key": "curve", "label": "Curve", "type": "enum", "choices": ["Linear", "Smooth", "Exponential", "Logarithmic"], "default": 1}]},
	{"id": "fade_out", "label": "Fade out", "group": "fades", "filters": ["afade"], "fields": [{"key": "curve", "label": "Curve", "type": "enum", "choices": ["Linear", "Smooth", "Exponential", "Logarithmic"], "default": 1}]},
	{"id": "silence", "label": "Silence", "group": "fades", "filters": ["volume"], "fields": []},
	{"id": "invert", "label": "Invert", "group": "fades", "filters": ["aeval"], "fields": []},
	{"id": "reverse", "label": "Reverse", "group": "fades", "filters": ["areverse"], "fields": []},
	{"id": "noise_reduction", "label": "Noise reduction", "group": "clean", "filters": ["afftdn"], "fields": [{"key": "amount", "label": "Reduction (dB)", "type": "float", "default": 12.0}, {"key": "floor", "label": "Noise floor (dB, from the profile)", "type": "float", "default": -50.0}]},
	{"id": "denoise_nlm", "label": "Denoise (smooth)", "group": "clean", "filters": ["anlmdn"], "fields": [{"key": "strength", "label": "Strength (0.00001 to 10000)", "type": "float", "default": 0.00001}]},
	{"id": "declick", "label": "Remove clicks", "group": "clean", "filters": ["adeclick"], "fields": [{"key": "threshold", "label": "Threshold", "type": "float", "default": 2.0}]},
	{"id": "declip", "label": "Repair clipping", "group": "clean", "filters": ["adeclip"], "fields": [{"key": "threshold", "label": "Threshold", "type": "float", "default": 10.0}]},
	{"id": "deesser", "label": "De-esser", "group": "clean", "filters": ["deesser"], "fields": [{"key": "intensity", "label": "Intensity (0 to 1)", "type": "float", "default": 0.5}]},
	{"id": "gate", "label": "Noise gate", "group": "clean", "filters": ["agate"], "fields": [{"key": "threshold", "label": "Threshold (dB)", "type": "float", "default": -45.0}, {"key": "ratio", "label": "Ratio", "type": "float", "default": 2.0}, {"key": "attack", "label": "Attack (ms)", "type": "float", "default": 20.0}, {"key": "release", "label": "Release (ms)", "type": "float", "default": 250.0}]},
	{"id": "hum", "label": "Remove hum", "group": "clean", "filters": ["bandreject"], "fields": [{"key": "freq", "label": "Frequency (Hz)", "type": "float", "default": 60.0}, {"key": "width", "label": "Width (Hz)", "type": "float", "default": 10.0}]},
	{"id": "bass", "label": "Bass", "group": "tone", "filters": ["bass"], "fields": [{"key": "gain", "label": "Gain (dB)", "type": "float", "default": 3.0}, {"key": "freq", "label": "Below (Hz)", "type": "float", "default": 100.0}]},
	{"id": "treble", "label": "Treble", "group": "tone", "filters": ["treble"], "fields": [{"key": "gain", "label": "Gain (dB)", "type": "float", "default": 3.0}, {"key": "freq", "label": "Above (Hz)", "type": "float", "default": 3000.0}]},
	{"id": "eq_band", "label": "Equalizer band", "group": "tone", "filters": ["equalizer"], "fields": [{"key": "freq", "label": "Frequency (Hz)", "type": "float", "default": 1000.0}, {"key": "width", "label": "Width (octaves)", "type": "float", "default": 1.0}, {"key": "gain", "label": "Gain (dB)", "type": "float", "default": 3.0}]},
	{"id": "highpass", "label": "High pass", "group": "tone", "filters": ["highpass"], "fields": [{"key": "freq", "label": "Cut below (Hz)", "type": "float", "default": 80.0}]},
	{"id": "lowpass", "label": "Low pass", "group": "tone", "filters": ["lowpass"], "fields": [{"key": "freq", "label": "Cut above (Hz)", "type": "float", "default": 8000.0}]},
	{"id": "telephone", "label": "Telephone", "group": "tone", "filters": ["highpass", "lowpass"], "fields": []},
	{"id": "tempo", "label": "Change tempo", "group": "time", "filters": ["atempo"], "duration": "tempo", "fields": [{"key": "percent", "label": "Tempo change (%)", "type": "float", "default": 10.0}]},
	{"id": "pitch", "label": "Change pitch", "group": "time", "filters": ["asetrate", "aresample", "atempo"], "fields": [{"key": "semitones", "label": "Semitones", "type": "float", "default": 2.0}]},
	{"id": "speed", "label": "Change speed", "group": "time", "filters": ["asetrate", "aresample"], "duration": "speed", "fields": [{"key": "percent", "label": "Speed change (%)", "type": "float", "default": 10.0}]},
	{"id": "echo", "label": "Echo", "group": "space", "filters": ["aecho"], "fields": [{"key": "delay", "label": "Delay (ms)", "type": "float", "default": 400.0}, {"key": "decay", "label": "Decay (0 to 1)", "type": "float", "default": 0.4}, {"key": "repeats", "label": "Repeats", "type": "int", "default": 2}]},
	{"id": "reverb", "label": "Room", "group": "space", "filters": ["aecho"], "fields": [{"key": "size", "label": "Size (ms)", "type": "float", "default": 60.0}, {"key": "amount", "label": "Amount (0 to 1)", "type": "float", "default": 0.3}]},
	{"id": "stereo_width", "label": "Stereo width", "group": "space", "filters": ["extrastereo"], "fields": [{"key": "width", "label": "Width (1 is unchanged)", "type": "float", "default": 1.5}]},
	{"id": "to_mono", "label": "Make mono", "group": "space", "filters": ["pan"], "fields": []},
	{"id": "left_only", "label": "Left channel to both", "group": "space", "filters": ["pan"], "fields": []},
	{"id": "right_only", "label": "Right channel to both", "group": "space", "filters": ["pan"], "fields": []},
	{"id": "swap", "label": "Swap channels", "group": "space", "filters": ["channelmap"], "fields": []},
	{"id": "chorus", "label": "Chorus", "group": "fun", "filters": ["chorus"], "fields": [{"key": "depth", "label": "Depth (ms)", "type": "float", "default": 2.0}, {"key": "speed", "label": "Speed (Hz)", "type": "float", "default": 0.25}]},
	{"id": "flanger", "label": "Flanger", "group": "fun", "filters": ["flanger"], "fields": [{"key": "depth", "label": "Depth (ms)", "type": "float", "default": 2.0}, {"key": "speed", "label": "Speed (Hz)", "type": "float", "default": 0.5}]},
	{"id": "tremolo", "label": "Tremolo", "group": "fun", "filters": ["tremolo"], "fields": [{"key": "freq", "label": "Rate (Hz)", "type": "float", "default": 5.0}, {"key": "depth", "label": "Depth (0 to 1)", "type": "float", "default": 0.5}]},
	{"id": "vibrato", "label": "Vibrato", "group": "fun", "filters": ["vibrato"], "fields": [{"key": "freq", "label": "Rate (Hz)", "type": "float", "default": 5.0}, {"key": "depth", "label": "Depth (0 to 1)", "type": "float", "default": 0.5}]},
	{"id": "phaser", "label": "Phaser", "group": "fun", "filters": ["aphaser"], "fields": [{"key": "speed", "label": "Speed (Hz)", "type": "float", "default": 0.5}, {"key": "decay", "label": "Decay (0 to 1)", "type": "float", "default": 0.4}]},
	{"id": "crystalizer", "label": "Crystalizer", "group": "fun", "filters": ["crystalizer"], "fields": [{"key": "amount", "label": "Intensity (-10 to 10)", "type": "float", "default": 2.0}]},
	{"id": "bitcrush", "label": "Bit crush", "group": "fun", "filters": ["acrusher"], "fields": [{"key": "bits", "label": "Bits", "type": "float", "default": 8.0}, {"key": "mix", "label": "Mix (0 to 1)", "type": "float", "default": 0.5}]},
	{"id": "custom", "label": "Custom FFmpeg filter", "group": "fun", "filters": [], "fields": [{"key": "graph", "label": "Filter chain", "type": "string", "default": "volume=1.0"}]},
	{"id": "delete", "label": "Delete the selection", "group": "edit", "filters": ["atrim", "concat"], "kind": "delete", "duration": "delete", "needs_selection": true, "fields": []},
	{"id": "keep", "label": "Trim to the selection", "group": "edit", "filters": ["atrim"], "kind": "keep", "duration": "keep", "needs_selection": true, "fields": []},
]


static func op(id: String) -> Dictionary:
	for o: Dictionary in OPS:
		if String(o["id"]) == id:
			return o
	return {}


static func available(o: Dictionary, filters: PackedStringArray) -> bool:
	if filters.is_empty():
		return true
	for f: Variant in o.get("filters", []):
		if not filters.has(String(f)):
			return false
	return true


static func fnum(v: float) -> String:
	return String.num(v, 4).trim_suffix("0").trim_suffix("0").trim_suffix("0").trim_suffix(".")


static func db_to_lin(db: float) -> float:
	return pow(10.0, db / 20.0)


static func curve_name(i: int) -> String:
	return ["tri", "qsin", "exp", "log"][clampi(i, 0, 3)]


static func graph(id: String, p: Dictionary, range_len: float, rate: int = 48000) -> String:
	var sr: String = str(maxi(rate, 8000))
	if id == "amplify":
		return "volume=" + fnum(float(p.get("gain", 0.0))) + "dB"
	if id == "normalize":
		return "volume=" + fnum(float(p.get("gain", 0.0))) + "dB"
	if id == "loudness":
		return "loudnorm=I=" + fnum(float(p.get("lufs", -16.0))) + ":TP=" + fnum(float(p.get("tp", -1.5))) + ":LRA=11"
	if id == "compressor":
		return "acompressor=threshold=" + fnum(clampf(db_to_lin(float(p.get("threshold", -18.0))), 0.001, 1.0)) + ":ratio=" + fnum(clampf(float(p.get("ratio", 3.0)), 1.0, 20.0)) + ":attack=" + fnum(clampf(float(p.get("attack", 20.0)), 0.01, 2000.0)) + ":release=" + fnum(clampf(float(p.get("release", 250.0)), 0.01, 9000.0)) + ":makeup=" + fnum(clampf(db_to_lin(float(p.get("makeup", 0.0))), 1.0, 64.0))
	if id == "limiter":
		return "alimiter=limit=" + fnum(clampf(db_to_lin(float(p.get("ceiling", -1.0))), 0.0625, 1.0)) + ":level=0"
	if id == "leveler":
		return "dynaudnorm=f=" + str(clampi(int(p.get("frame", 500)), 10, 8000)) + ":p=" + fnum(clampf(db_to_lin(float(p.get("peak", -0.5))), 0.0, 1.0))
	if id == "fade_in":
		return "afade=t=in:st=0:d=" + fnum(maxf(range_len, 0.01)) + ":curve=" + curve_name(int(p.get("curve", 1)))
	if id == "fade_out":
		return "afade=t=out:st=0:d=" + fnum(maxf(range_len, 0.01)) + ":curve=" + curve_name(int(p.get("curve", 1)))
	if id == "silence":
		return "volume=0"
	if id == "invert":
		return "aeval=-val(0)|-val(1):c=same"
	if id == "reverse":
		return "areverse"
	if id == "noise_reduction":
		return "afftdn=nr=" + fnum(clampf(float(p.get("amount", 12.0)), 0.01, 97.0)) + ":nf=" + fnum(clampf(float(p.get("floor", -50.0)), -80.0, -20.0)) + ":tn=1"
	if id == "denoise_nlm":
		return "anlmdn=s=" + fnum(clampf(float(p.get("strength", 0.00001)), 0.00001, 10000.0))
	if id == "declick":
		return "adeclick=t=" + fnum(clampf(float(p.get("threshold", 2.0)), 1.0, 100.0))
	if id == "declip":
		return "adeclip=t=" + fnum(clampf(float(p.get("threshold", 10.0)), 1.0, 100.0))
	if id == "deesser":
		return "deesser=i=" + fnum(clampf(float(p.get("intensity", 0.5)), 0.0, 1.0))
	if id == "gate":
		return "agate=threshold=" + fnum(clampf(db_to_lin(float(p.get("threshold", -45.0))), 0.0, 1.0)) + ":ratio=" + fnum(clampf(float(p.get("ratio", 2.0)), 1.0, 9000.0)) + ":attack=" + fnum(clampf(float(p.get("attack", 20.0)), 0.01, 9000.0)) + ":release=" + fnum(clampf(float(p.get("release", 250.0)), 0.01, 9000.0))
	if id == "hum":
		return "bandreject=f=" + fnum(maxf(float(p.get("freq", 60.0)), 1.0)) + ":w=" + fnum(maxf(float(p.get("width", 10.0)), 0.1)) + ":t=h"
	if id == "bass":
		return "bass=g=" + fnum(float(p.get("gain", 3.0))) + ":f=" + fnum(maxf(float(p.get("freq", 100.0)), 1.0))
	if id == "treble":
		return "treble=g=" + fnum(float(p.get("gain", 3.0))) + ":f=" + fnum(maxf(float(p.get("freq", 3000.0)), 1.0))
	if id == "eq_band":
		return "equalizer=f=" + fnum(maxf(float(p.get("freq", 1000.0)), 1.0)) + ":t=o:w=" + fnum(maxf(float(p.get("width", 1.0)), 0.01)) + ":g=" + fnum(float(p.get("gain", 3.0)))
	if id == "highpass":
		return "highpass=f=" + fnum(maxf(float(p.get("freq", 80.0)), 1.0))
	if id == "lowpass":
		return "lowpass=f=" + fnum(maxf(float(p.get("freq", 8000.0)), 1.0))
	if id == "telephone":
		return "highpass=f=300,lowpass=f=3400"
	if id == "tempo":
		return "atempo=" + fnum(clampf(1.0 + float(p.get("percent", 10.0)) / 100.0, 0.5, 100.0))
	if id == "pitch":
		var f: float = pow(2.0, float(p.get("semitones", 2.0)) / 12.0)
		return "asetrate=" + sr + "*" + fnum(f) + ",aresample=" + sr + ",atempo=" + fnum(clampf(1.0 / f, 0.5, 100.0))
	if id == "speed":
		var f2: float = clampf(1.0 + float(p.get("percent", 10.0)) / 100.0, 0.05, 20.0)
		return "asetrate=" + sr + "*" + fnum(f2) + ",aresample=" + sr
	if id == "echo":
		var n: int = clampi(int(p.get("repeats", 2)), 1, 8)
		var delay: float = clampf(float(p.get("delay", 400.0)), 1.0, 20000.0)
		var decay: float = clampf(float(p.get("decay", 0.4)), 0.01, 0.99)
		var delays: PackedStringArray = PackedStringArray()
		var decays: PackedStringArray = PackedStringArray()
		for i: int in n:
			delays.append(fnum(delay * float(i + 1)))
			decays.append(fnum(pow(decay, float(i + 1))))
		return "aecho=0.8:0.9:" + "|".join(delays) + ":" + "|".join(decays)
	if id == "reverb":
		var size: float = clampf(float(p.get("size", 60.0)), 1.0, 2000.0)
		var amount: float = clampf(float(p.get("amount", 0.3)), 0.01, 0.9)
		return "aecho=0.8:0.88:" + fnum(size) + "|" + fnum(size * 1.7) + "|" + fnum(size * 2.9) + ":" + fnum(amount) + "|" + fnum(amount * 0.6) + "|" + fnum(amount * 0.3)
	if id == "stereo_width":
		return "extrastereo=m=" + fnum(clampf(float(p.get("width", 1.5)), -10.0, 10.0))
	if id == "to_mono":
		return "pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1"
	if id == "left_only":
		return "pan=stereo|c0=c0|c1=c0"
	if id == "right_only":
		return "pan=stereo|c0=c1|c1=c1"
	if id == "swap":
		return "channelmap=map=1|0"
	if id == "chorus":
		return "chorus=0.6:0.9:" + fnum(clampf(float(p.get("depth", 2.0)), 0.1, 30.0) * 20.0) + ":0.4:" + fnum(clampf(float(p.get("speed", 0.25)), 0.01, 5.0)) + ":2"
	if id == "flanger":
		return "flanger=depth=" + fnum(clampf(float(p.get("depth", 2.0)), 0.0, 10.0)) + ":speed=" + fnum(clampf(float(p.get("speed", 0.5)), 0.1, 10.0))
	if id == "tremolo":
		return "tremolo=f=" + fnum(clampf(float(p.get("freq", 5.0)), 0.1, 20000.0)) + ":d=" + fnum(clampf(float(p.get("depth", 0.5)), 0.0, 1.0))
	if id == "vibrato":
		return "vibrato=f=" + fnum(clampf(float(p.get("freq", 5.0)), 0.1, 20000.0)) + ":d=" + fnum(clampf(float(p.get("depth", 0.5)), 0.0, 1.0))
	if id == "phaser":
		return "aphaser=speed=" + fnum(clampf(float(p.get("speed", 0.5)), 0.1, 2.0)) + ":decay=" + fnum(clampf(float(p.get("decay", 0.4)), 0.0, 0.99))
	if id == "crystalizer":
		return "crystalizer=i=" + fnum(clampf(float(p.get("amount", 2.0)), -10.0, 10.0))
	if id == "bitcrush":
		return "acrusher=bits=" + fnum(clampf(float(p.get("bits", 8.0)), 1.0, 64.0)) + ":mix=" + fnum(clampf(float(p.get("mix", 0.5)), 0.0, 1.0))
	if id == "custom":
		var g: String = String(p.get("graph", "")).strip_edges()
		return g if not g.is_empty() else "anull"
	return "anull"


static func duration_factor(id: String, p: Dictionary) -> float:
	if id == "tempo":
		return 1.0 / clampf(1.0 + float(p.get("percent", 10.0)) / 100.0, 0.5, 100.0)
	if id == "speed":
		return 1.0 / clampf(1.0 + float(p.get("percent", 10.0)) / 100.0, 0.05, 20.0)
	return 1.0


static func describe(edit: Dictionary) -> String:
	var o: Dictionary = op(String(edit.get("op", "")))
	var label: String = String(o.get("label", String(edit.get("op", "edit"))))
	var params: Dictionary = edit.get("params", {})
	var parts: PackedStringArray = PackedStringArray()
	for f: Variant in o.get("fields", []):
		var fd: Dictionary = f
		var key: String = String(fd.get("key", ""))
		if not params.has(key):
			continue
		var v: Variant = params[key]
		if String(fd.get("type", "")) == "enum":
			var choices: Array = fd.get("choices", [])
			var i: int = int(v)
			parts.append(String(choices[i]) if i >= 0 and i < choices.size() else str(v))
		elif v is float:
			parts.append(fnum(v))
		else:
			parts.append(str(v))
	if parts.is_empty():
		return label
	return label + " " + ", ".join(parts)
