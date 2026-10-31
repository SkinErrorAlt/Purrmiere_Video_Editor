extends RefCounted

const SCREEN_NAME := "effect_tex"
const TIME_NAME := "clip_time"
const STRAIGHT_FN := "pm_straight"
const OVER_FN := "pm_over"
const PROBE_NAME := "pm_compile_probe"
const ENGINE_NAMES: PackedStringArray = ["tex_size", "seq_size", "time", "clip_time", "clip_duration", "source_tex", "layer_tex", "effect_tex", "px_scale", "pass_scale", "mask_tex", "screen_tex", "spill_out", "TEXTURE", "pm_compile_probe"]
const READ_FUNCS := "texture|textureLod|textureGrad|textureProj|textureProjLod|textureProjGrad|texelFetch"
const BLEND_MODES: PackedStringArray = ["blend_mix", "blend_add", "blend_sub", "blend_mul", "blend_premul_alpha", "blend_disabled"]
const SHADER_ERROR_TYPE := 3

static var plant_no_catch: bool = false
const OTHER_KINDS: Dictionary = {
	"spatial": "This is a 3D shader (shader_type spatial). It shades 3D meshes using their lights, normals and depth, and a clip is a flat picture, so it cannot run on a clip. Look for a canvas_item version of it.",
	"particles": "This is a particles shader (shader_type particles). It moves the particles of a particle system and draws no picture, so it cannot run on a clip.",
	"sky": "This is a sky shader (shader_type sky). It draws the sky of a 3D scene, so it cannot run on a clip.",
	"fog": "This is a fog shader (shader_type fog). It fills fog volumes in a 3D scene, so it cannot run on a clip.",
}
const GODOT3_NAMES: Array = [
	["hint_black_albedo", "source_color, hint_default_black"],
	["hint_color", "source_color"],
	["hint_albedo", "source_color"],
	["hint_black", "hint_default_black"],
	["hint_white", "hint_default_white"],
	["hint_aniso", "hint_anisotropy"],
	["WORLD_MATRIX", "MODEL_MATRIX"],
	["PROJECTION_MATRIX", "SCREEN_MATRIX"],
	["EXTRA_MATRIX", "mat4(1.0)"],
	["AT_LIGHT_PASS", "false"],
	["NORMALMAP_DEPTH", "NORMAL_MAP_DEPTH"],
	["NORMALMAP", "NORMAL_MAP"],
]
const SKIPPED_TYPES: PackedStringArray = ["uint", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4", "bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4", "samplerCube", "samplerCubeArray", "sampler2DArray", "sampler3D", "isampler2D", "usampler2D", "isampler2DArray", "usampler2DArray", "isampler3D", "usampler3D", "samplerExternalOES"]
const SPLIT_AXES: PackedStringArray = ["x", "y", "z", "w"]


static func strip_comments(code: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var n: int = code.length()
	var i: int = 0
	var start: int = 0
	while i < n:
		var ch: String = code[i]
		if ch == "\"":
			var q: int = i + 1
			while q < n and code[q] != "\"" and code[q] != "\n":
				q += 1
			i = q + 1 if q < n and code[q] == "\"" else q
			continue
		if ch == "/" and i + 1 < n and code[i + 1] == "/":
			out.append(code.substr(start, i - start))
			var j: int = i
			while j < n and code[j] != "\n":
				j += 1
			out.append(" ".repeat(j - i))
			i = j
			start = i
			continue
		if ch == "/" and i + 1 < n and code[i + 1] == "*":
			out.append(code.substr(start, i - start))
			var close: int = code.find("*" + "/", i + 2)
			var stop: int = n if close < 0 else close + 2
			var chunk: String = code.substr(i, stop - i)
			var blank: PackedStringArray = PackedStringArray()
			for k: int in chunk.length():
				blank.append("\n" if chunk[k] == "\n" else " ")
			out.append("".join(blank))
			i = stop
			start = i
			continue
		i += 1
	out.append(code.substr(start))
	return "".join(out)


static func line_of(text: String, pos: int) -> int:
	return text.substr(0, clampi(pos, 0, text.length())).count("\n") + 1


static func _blank(text: String, from: int, to: int) -> String:
	var mid: String = text.substr(from, to - from)
	var parts: PackedStringArray = PackedStringArray()
	for k: int in mid.length():
		parts.append("\n" if mid[k] == "\n" else " ")
	return text.substr(0, from) + "".join(parts) + text.substr(to)


static func _re(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


static func _word_replace(text: String, word: String, with: String) -> String:
	return _re("\\b" + word + "\\b").sub(text, with, true)


static func _has_word(text: String, word: String) -> bool:
	return _re("\\b" + word + "\\b").search(text) != null


static func _problem(out: Dictionary, line: int, text: String) -> void:
	(out["problems"] as Array).append({"line": line, "text": text})


static func _note(out: Dictionary, text: String) -> void:
	var notes: PackedStringArray = out["notes"]
	if not notes.has(text):
		notes.append(text)
		out["notes"] = notes


static func match_paren(text: String, open_at: int) -> int:
	var depth: int = 0
	var open_ch: String = text[open_at]
	var close_ch: String = ")" if open_ch == "(" else "}"
	for i: int in range(open_at, text.length()):
		var ch: String = text[i]
		if ch == open_ch:
			depth += 1
		elif ch == close_ch:
			depth -= 1
			if depth == 0:
				return i
	return -1


static func convert(code: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "code": "", "problems": [], "notes": PackedStringArray(), "params": [], "mode": "", "blend": "blend_mix"}
	var text: String = code.replace("\r\n", "\n").replace("\r", "\n")
	if text.strip_edges().is_empty():
		_problem(out, 0, "There is no shader code to import.")
		return out
	var src: String = strip_comments(text)
	for m: RegExMatch in _re("(?m)^[ \\t]*#[ \\t]*include\\b[^\\n]*").search_all(src):
		_problem(out, line_of(src, m.get_start()), "It includes another shader file (" + m.get_string().strip_edges() + "). Paste that file's code in place of the #include line and import again.")
	var st: RegExMatch = _re("\\bshader_type\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*;").search(src)
	var kind: String = st.get_string(1) if st != null else ""
	if not kind.is_empty() and kind != "canvas_item":
		var why: String = String(OTHER_KINDS.get(kind, "This is a " + kind + " shader, and only canvas_item shaders can run on a clip."))
		_problem(out, line_of(src, st.get_start()), why)
		return out
	for m2: RegExMatch in _re("\\b(hint_depth_texture|DEPTH_TEXTURE)\\b").search_all(src):
		_problem(out, line_of(src, m2.get_start()), "It reads the depth buffer (" + m2.get_string() + "), which only 3D scenes have. A clip has no depth, so it cannot run here.")
		break
	for m3: RegExMatch in _re("\\b(hint_normal_roughness_texture|NORMAL_ROUGHNESS_TEXTURE)\\b").search_all(src):
		_problem(out, line_of(src, m3.get_start()), "It reads the normal and roughness buffer (" + m3.get_string() + "), which only 3D scenes have, so it cannot run here.")
		break
	if not (out["problems"] as Array).is_empty():
		return out
	if kind.is_empty():
		_note(out, "The code has no shader_type line, so it is read as a canvas_item shader.")
	var renamed: PackedStringArray = PackedStringArray()
	for pair: Array in GODOT3_NAMES:
		if _has_word(src, String(pair[0])):
			src = _word_replace(src, String(pair[0]), String(pair[1]))
			renamed.append(String(pair[0]) + " to " + String(pair[1]))
	if not renamed.is_empty():
		_note(out, "Godot 3 names were updated: " + ", ".join(renamed) + ".")
	var gi: RegExMatch = _re("\\b(global|instance)\\s+uniform\\b").search(src)
	while gi != null:
		_note(out, "A " + gi.get_string(1) + " uniform becomes a normal option of the effect.")
		src = src.substr(0, gi.get_start()) + " ".repeat(gi.get_string(1).length()) + src.substr(gi.get_start() + gi.get_string(1).length())
		gi = _re("\\b(global|instance)\\s+uniform\\b").search(src)
	var screen_hints: PackedStringArray = PackedStringArray()
	var reads_screen: bool = false
	var sdecl: RegEx = _re("\\buniform\\s+(?:(?:lowp|mediump|highp)\\s+)?sampler2D\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*([^;]*\\bhint_screen_texture\\b[^;]*);")
	var sm: RegExMatch = sdecl.search(src)
	var screen_names: PackedStringArray = PackedStringArray()
	while sm != null:
		screen_names.append(sm.get_string(1))
		if screen_hints.is_empty():
			for h: String in sm.get_string(2).split(","):
				var hs: String = h.strip_edges()
				if not hs.is_empty() and hs != "hint_screen_texture":
					screen_hints.append(hs)
		src = _blank(src, sm.get_start(), sm.get_end())
		sm = sdecl.search(src)
	for sname: String in screen_names:
		if sname != SCREEN_NAME:
			src = _word_replace(src, sname, SCREEN_NAME)
		reads_screen = true
	if _has_word(src, "SCREEN_TEXTURE"):
		src = _word_replace(src, "SCREEN_TEXTURE", SCREEN_NAME)
		reads_screen = true
	if reads_screen:
		_note(out, "It reads the screen: here that is the clip's picture as it enters this effect, not the layers below it.")
	if _has_word(src, "TIME"):
		src = _word_replace(src, "TIME", TIME_NAME)
		_note(out, "TIME counts seconds from the start of the clip, so the preview and the export match.")
	var modes: PackedStringArray = PackedStringArray()
	var blend: String = "blend_mix"
	var rm: RegEx = _re("\\brender_mode\\s+([^;]*);")
	var rmm: RegExMatch = rm.search(src)
	while rmm != null:
		for part: String in rmm.get_string(1).split(","):
			var mode: String = part.strip_edges()
			if mode.is_empty():
				continue
			if BLEND_MODES.has(mode):
				blend = mode
			elif mode == "light_only":
				_note(out, "render_mode light_only is left out: clips are not lit by 2D lights, so it would draw nothing.")
			elif not modes.has(mode):
				modes.append(mode)
		src = _blank(src, rmm.get_start(), rmm.get_end())
		rmm = rm.search(src)
	out["blend"] = blend
	if _re("\\bvoid\\s+light\\s*\\(").search(src) != null:
		_note(out, "The light() function does nothing here: clips are not lit by 2D lights.")
	var reads_texture: bool = _has_word(src, "TEXTURE")
	var reads_colour: bool = false
	for cm: RegExMatch in _re("\\bCOLOR\\b").search_all(src):
		var after: String = src.substr(cm.get_end(), 3)
		if not (after.strip_edges(true, false).begins_with("=") and not after.strip_edges(true, false).begins_with("==")):
			reads_colour = true
			break
	var overlay: bool = reads_screen or (not reads_texture and not reads_colour)
	out["mode"] = "over" if overlay else "picture"
	if overlay:
		_note(out, "Draws over the clip's picture, like a screen shader on a ColorRect.")
	else:
		_note(out, "Works on the clip's picture, like a shader on a sprite.")
		if blend == "blend_add" or blend == "blend_sub" or blend == "blend_mul":
			_note(out, "render_mode " + blend + " is left out: the picture it makes replaces the clip's picture. The clip's blend mode in Effect Controls can do the same with the layers below.")
	var reads: Array[RegExMatch] = _re("\\b(" + READ_FUNCS + ")\\s*\\(\\s*(TEXTURE|" + SCREEN_NAME + ")\\b").search_all(src)
	for ri: int in range(reads.size() - 1, -1, -1):
		var rmatch: RegExMatch = reads[ri]
		var open_at: int = src.find("(", rmatch.get_start())
		var close_at: int = match_paren(src, open_at)
		if close_at < 0:
			continue
		src = src.substr(0, rmatch.get_start()) + STRAIGHT_FN + "(" + src.substr(rmatch.get_start(), close_at + 1 - rmatch.get_start()) + ")" + src.substr(close_at + 1)
	var split: Dictionary = _split_vectors(src)
	src = String(split["code"])
	var epilogue: String = ""
	if overlay:
		epilogue = "COLOR = " + OVER_FN + "(COLOR, texture(TEXTURE, SCREEN_UV));"
	elif blend != "blend_premul_alpha":
		epilogue = "COLOR.rgb *= COLOR.a;"
	var fm: RegExMatch = _re("\\bvoid\\s+fragment\\s*\\(\\s*\\)\\s*\\{").search(src)
	if fm != null:
		var body_open: int = fm.get_end() - 1
		var body_close: int = match_paren(src, body_open)
		if body_close < 0:
			_problem(out, line_of(src, fm.get_start()), "The fragment() function has no closing brace.")
			return out
		var body: String = src.substr(body_open + 1, body_close - body_open - 1)
		if not epilogue.is_empty():
			body = _re("\\breturn\\s*;").sub(body, "{ " + epilogue + " return; }", true)
		src = src.substr(0, body_open + 1) + " COLOR = " + STRAIGHT_FN + "(COLOR);" + body + (" " + epilogue + " " if not epilogue.is_empty() else "") + src.substr(body_close)
	elif _re("\\bvoid\\s+vertex\\s*\\(").search(src) == null:
		_note(out, "It has no fragment() function, so it does not change the picture.")
	var header: PackedStringArray = PackedStringArray(["shader_type canvas_item;"])
	var mode_list: PackedStringArray = modes.duplicate()
	mode_list.append("blend_disabled")
	header.append("render_mode " + ", ".join(mode_list) + ";")
	if _has_word(src, SCREEN_NAME) and _re("\\buniform\\s+\\w+\\s+" + SCREEN_NAME + "\\b").search(src) == null:
		header.append("uniform sampler2D " + SCREEN_NAME + (" : " + ", ".join(screen_hints) if not screen_hints.is_empty() else "") + ";")
	if _has_word(src, TIME_NAME) and _re("\\buniform\\s+\\w+\\s+" + TIME_NAME + "\\b").search(src) == null:
		header.append("uniform float " + TIME_NAME + ";")
	header.append(String(split["decls"]))
	header.append("vec4 " + STRAIGHT_FN + "(vec4 c) { return c.a > 0.0001 ? vec4(c.rgb / c.a, c.a) : vec4(0.0); }")
	if overlay:
		header.append("vec4 " + OVER_FN + "(vec4 s, vec4 d) { " + _over_body(blend) + " }")
	var head: String = " ".join(header).strip_edges()
	head = _re("\\s+").sub(head, " ", true)
	if st != null:
		var st2: RegExMatch = _re("\\bshader_type\\s+canvas_item\\s*;").search(src)
		src = src.substr(0, st2.get_start()) + head + src.substr(st2.get_end())
	else:
		src = head + " " + src
	var lines: PackedStringArray = src.split("\n")
	for li: int in lines.size():
		lines[li] = lines[li].rstrip(" \t")
	src = "\n".join(lines)
	if not src.ends_with("\n"):
		src += "\n"
	out["code"] = src
	var found: Dictionary = discover(src, split["split"])
	out["params"] = found["params"]
	for n: String in found["notes"]:
		_note(out, n)
	out["ok"] = true
	return out


static func _over_body(blend: String) -> String:
	if blend == "blend_add":
		return "return vec4(d.rgb + s.rgb * s.a, d.a);"
	if blend == "blend_sub":
		return "return vec4(max(d.rgb - s.rgb * s.a, vec3(0.0)), d.a);"
	if blend == "blend_mul":
		return "return vec4(d.rgb * mix(vec3(1.0), s.rgb, s.a), d.a);"
	if blend == "blend_premul_alpha":
		return "vec4 p = vec4(s.rgb * s.a, s.a); return p + d * (1.0 - p.a);"
	if blend == "blend_disabled":
		return "return vec4(s.rgb * s.a, s.a);"
	return "return vec4(s.rgb * s.a + d.rgb * (1.0 - s.a), s.a + d.a * (1.0 - s.a));"


static func _uniform_regex() -> RegEx:
	return _re("\\buniform\\s+(?:(?:lowp|mediump|highp)\\s+)?([A-Za-z_][A-Za-z0-9_]*)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(\\[[^\\]]*\\])?\\s*(?::\\s*([^;=]*))?(?:=\\s*([^;]*))?;")


static func _split_vectors(src: String) -> Dictionary:
	var out: String = src
	var decls: PackedStringArray = PackedStringArray()
	var split: Dictionary = {}
	var re: RegEx = _uniform_regex()
	var found: Array[RegExMatch] = re.search_all(out)
	for i: int in range(found.size() - 1, -1, -1):
		var m: RegExMatch = found[i]
		var gtype: String = m.get_string(1)
		if gtype != "vec3" and gtype != "vec4":
			continue
		if not m.get_string(3).is_empty() or m.get_string(4).contains("source_color"):
			continue
		var name: String = m.get_string(2)
		if ENGINE_NAMES.has(name):
			continue
		var count: int = 3 if gtype == "vec3" else 4
		var def: Array = _vector_default(gtype, m.get_string(5).strip_edges())
		var comps: PackedStringArray = PackedStringArray()
		var own: PackedStringArray = PackedStringArray()
		for k: int in count:
			var cname: String = name + "_" + SPLIT_AXES[k]
			comps.append(cname)
			own.append("uniform float " + cname + " = " + _float_text(float(def[k])) + ";")
		split[name] = {"type": gtype, "parts": comps, "default": def}
		out = _blank(out, m.get_start(), m.get_end())
		out = _word_replace(out, name, gtype + "(" + ", ".join(comps) + ")")
		decls.append(" ".join(own))
	decls.reverse()
	return {"code": out, "decls": " ".join(decls), "split": split}


static func _float_text(v: float) -> String:
	var s: String = str(v)
	if not s.contains(".") and not s.contains("e"):
		s += ".0"
	return s


static func _vector_default(gtype: String, text: String) -> Array:
	var count: int = 2 if gtype == "vec2" else (3 if gtype == "vec3" else 4)
	var zero: Array = []
	for _i: int in count:
		zero.append(0.0)
	if text.is_empty():
		return zero
	var open: int = text.find("(")
	var close: int = text.rfind(")")
	if open < 0 or close < open:
		var one: Variant = eval_number(text)
		if one == null:
			return zero
		var filled: Array = []
		for _j: int in count:
			filled.append(float(one))
		return filled
	var inner: String = text.substr(open + 1, close - open - 1)
	var args: PackedStringArray = split_args(inner)
	var nums: Array = []
	for a: String in args:
		var v: Variant = eval_number(a)
		if v == null:
			return zero
		nums.append(float(v))
	if nums.size() == 1:
		var out: Array = []
		for _k: int in count:
			out.append(nums[0])
		return out
	if nums.size() == count:
		return nums
	if count == 4 and nums.size() == 3:
		nums.append(1.0)
		return nums
	return zero


static func split_args(inner: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var start: int = 0
	for i: int in inner.length():
		var ch: String = inner[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
		elif ch == "," and depth == 0:
			out.append(inner.substr(start, i - start).strip_edges())
			start = i + 1
	out.append(inner.substr(start).strip_edges())
	return out


static func eval_number(text: String) -> Variant:
	var t: String = text.strip_edges()
	if t.is_empty():
		return null
	var clean: String = _re("(\\d)[fF]\\b").sub(t, "$1", true)
	if clean.is_valid_float():
		return float(clean)
	var e := Expression.new()
	if e.parse(clean) != OK:
		return null
	var v: Variant = e.execute([], null, false)
	if e.has_execute_failed():
		return null
	if v is float or v is int:
		return float(v)
	return null


static func discover(src: String, split: Dictionary = {}) -> Dictionary:
	var params: Array = []
	var notes: PackedStringArray = PackedStringArray()
	var events: Array = []
	for m: RegExMatch in _uniform_regex().search_all(src):
		events.append({"at": m.get_start(), "m": m})
	for g: RegExMatch in _re("\\bgroup_uniforms\\s*([A-Za-z0-9_.]*)\\s*;").search_all(src):
		events.append({"at": g.get_start(), "group": g.get_string(1)})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	var group: String = ""
	var split_done: Dictionary = {}
	for ev: Dictionary in events:
		if ev.has("group"):
			var gname: String = String(ev["group"]).get_slice(".", 0)
			group = gname.capitalize() if not gname.is_empty() else ""
			continue
		var m: RegExMatch = ev["m"]
		var gtype: String = m.get_string(1)
		var name: String = m.get_string(2)
		if ENGINE_NAMES.has(name):
			continue
		var owner: String = _split_owner(split, name)
		if not owner.is_empty():
			if split_done.has(owner):
				continue
			split_done[owner] = true
			var info: Dictionary = split[owner]
			var parts: PackedStringArray = info["parts"]
			var defs: Array = info["default"]
			for k: int in parts.size():
				var dv: float = float(defs[k])
				var fp: Dictionary = _float_param(parts[k], owner.capitalize() + " " + SPLIT_AXES[k].to_upper(), dv, "", group)
				params.append(fp)
			continue
		var hints: String = m.get_string(4).strip_edges()
		var default_text: String = m.get_string(5).strip_edges()
		if not m.get_string(3).is_empty():
			notes.append("The uniform array " + name + " keeps the values written in the shader and is not an option.")
			continue
		if SKIPPED_TYPES.has(gtype):
			notes.append("The uniform " + name + " (" + gtype + ") keeps the value written in the shader and is not an option.")
			continue
		var label: String = name.capitalize()
		var p: Dictionary = {}
		if gtype == "float":
			var dv2: Variant = eval_number(default_text) if not default_text.is_empty() else 0.0
			p = _float_param(name, label, float(dv2) if dv2 != null else 0.0, hints, group)
		elif gtype == "int":
			var di: Variant = eval_number(default_text) if not default_text.is_empty() else 0.0
			var dint: float = float(int(float(di))) if di != null else 0.0
			var en: RegExMatch = _re("hint_enum\\s*\\(([^)]*)\\)").search(hints)
			if en != null:
				var choices: Array = []
				for c: String in split_args(en.get_string(1)):
					choices.append(c.strip_edges().trim_prefix("\"").trim_suffix("\"").get_slice(":", 0))
				p = _base(name, label, "enum", dint, group)
				p["choices"] = choices
				p["max"] = float(maxi(choices.size() - 1, 0))
				p["step"] = 1.0
			else:
				p = _base(name, label, "int", dint, group)
				var hr: Array = _hint_range(hints)
				if not hr.is_empty():
					p["min"] = hr[0]
					p["max"] = hr[1]
					p["step"] = maxf(1.0, float(hr[2]) if hr.size() > 2 else 1.0)
				else:
					p["min"] = minf(0.0, dint * 2.0)
					p["max"] = maxf(10.0, absf(dint) * 2.0)
					p["step"] = 1.0
		elif gtype == "bool":
			p = _base(name, label, "bool", default_text == "true", group)
		elif gtype == "vec2":
			p = _base(name, label, "vec2", _vector_default("vec2", default_text), group)
			p["min"] = -4096.0
			p["max"] = 4096.0
			p["step"] = 0.01
		elif gtype == "vec3" or gtype == "vec4":
			var v: Array = _vector_default(gtype, default_text)
			if v.size() == 3:
				v.append(1.0)
			p = _base(name, label, "color", v, group)
		elif gtype == "sampler2D":
			p = _base(name, label, "texture", "", group)
		else:
			notes.append("The uniform " + name + " (" + gtype + ") keeps the value written in the shader and is not an option.")
			continue
		params.append(p)
	return {"params": params, "notes": notes}


static func _split_owner(split: Dictionary, name: String) -> String:
	for owner: Variant in split.keys():
		if (split[owner]["parts"] as PackedStringArray).has(name):
			return String(owner)
	return ""


static func _base(key: String, label: String, type: String, def: Variant, group: String) -> Dictionary:
	return {"key": key, "label": label, "type": type, "min": 0.0, "max": 1.0, "step": 0.01, "default": def, "keyable": true, "unit": "", "group": group}


static func _hint_range(hints: String) -> Array:
	var hm: RegExMatch = _re("hint_range\\s*\\(([^)]*)\\)").search(hints)
	if hm == null:
		return []
	var out: Array = []
	for a: String in split_args(hm.get_string(1)):
		var v: Variant = eval_number(a)
		if v == null:
			return []
		out.append(float(v))
	if out.size() < 2:
		return []
	return out


static func _float_param(key: String, label: String, dv: float, hints: String, group: String) -> Dictionary:
	var p: Dictionary = _base(key, label, "float", dv, group)
	var hr: Array = _hint_range(hints)
	if not hr.is_empty():
		p["min"] = hr[0]
		p["max"] = hr[1]
		p["step"] = float(hr[2]) if hr.size() > 2 else 0.01
		if hr.size() <= 2 and absf(float(hr[1]) - float(hr[0])) <= 0.2:
			p["step"] = 0.001
		return p
	var top: float = maxf(1.0, absf(dv) * 2.0)
	p["min"] = 0.0 if dv >= 0.0 else -top
	p["max"] = top
	p["step"] = 0.01
	return p


static func option_summary(params: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for p: Variant in params:
		var d: Dictionary = p
		var type: String = String(d.get("type", "float"))
		var what: String = ""
		if type == "float":
			what = "slider " + _num_text(float(d["min"])) + " to " + _num_text(float(d["max"]))
		elif type == "int":
			what = "whole number " + _num_text(float(d["min"])) + " to " + _num_text(float(d["max"]))
		elif type == "enum":
			what = "a choice of " + str((d.get("choices", []) as Array).size())
		elif type == "bool":
			what = "on or off"
		elif type == "vec2":
			what = "two numbers"
		elif type == "color":
			what = "colour"
		elif type == "texture":
			what = "a picture from the bin or a file"
		parts.append(String(d.get("label", d.get("key", ""))) + " (" + what + ")")
	return ", ".join(parts)


static func _num_text(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(snappedf(v, 0.001))


static func can_compile() -> bool:
	return not RenderingServer.get_video_adapter_name().is_empty()


static func compile(code: String) -> Dictionary:
	var out: Dictionary = {"checked": false, "ok": true, "errors": []}
	if not can_compile():
		return out
	out["checked"] = true
	var catcher := Catch.new()
	OS.add_logger(catcher)
	var sh := Shader.new()
	sh.code = code + "\nuniform float " + PROBE_NAME + " = 0.0;\n"
	var found: bool = false
	for u: Dictionary in sh.get_shader_uniform_list(true):
		if String(u.get("name", "")) == PROBE_NAME:
			found = true
			break
	OS.remove_logger(catcher)
	var errors: Array = catcher.take()
	if found and errors.is_empty():
		return out
	out["ok"] = false
	if errors.is_empty():
		errors.append({"line": 0, "text": "The shader did not compile."})
	out["errors"] = errors
	return out


static func caught_uniforms(sh: Shader, code: String) -> Dictionary:
	var catcher := Catch.new()
	if not plant_no_catch:
		OS.add_logger(catcher)
	sh.code = code
	var uniforms: Array = sh.get_shader_uniform_list(true)
	if not plant_no_catch:
		OS.remove_logger(catcher)
	return {"uniforms": uniforms, "errors": catcher.take()}


static func compiler_text(errors: Array, added_after: int, added: int) -> String:
	if errors.is_empty():
		return ""
	var e: Dictionary = errors[0]
	var line: int = int(e.get("line", 0))
	if added > 0 and line > added_after + added:
		line -= added
	elif added > 0 and line > added_after:
		line = added_after
	var text: String = String(e.get("text", "")).strip_edges()
	var more: String = "" if errors.size() <= 1 else " (and " + str(errors.size() - 1) + " more)"
	return ("line " + str(line) + ": " if line > 0 else "") + text + more


static func compiler_text_for(errors: Array, original: String, composed: String) -> String:
	var n: int = mini(original.length(), composed.length())
	var at: int = 0
	while at < n and original.unicode_at(at) == composed.unicode_at(at):
		at += 1
	return compiler_text(errors, line_of(original, at), composed.count("\n") - original.count("\n"))


class Catch extends Logger:
	var _lock: Mutex = Mutex.new()
	var _errors: Array = []

	func _log_error(_function: String, _file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != SHADER_ERROR_TYPE:
			return
		_lock.lock()
		_errors.append({"line": line, "text": code if not code.is_empty() else rationale})
		_lock.unlock()

	func take() -> Array:
		_lock.lock()
		var out: Array = _errors.duplicate(true)
		_lock.unlock()
		return out
