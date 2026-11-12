extends RefCounted

const PREF := "playback.float_passes"
const PREF_LABEL := "Keep high precision between effect passes, so glows and bright values are not clipped until the picture is finished"
const IN_UNIFORM := "pm_in"
const IN_LINE := "\nuniform sampler2D pm_in : filter_linear, repeat_disable;"
const COPY_SHADER := "res://engine/copy.gdshader"
const PUPPET_ID := "puppet"

static var plant_off: bool = false
static var forced: int = -1
static var _copy: Shader = null


static func on() -> bool:
	if plant_off:
		return false
	if forced >= 0:
		return forced == 1
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("Prefs") if loop is SceneTree else null
	if prefs == null:
		return true
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, true, {"label": PREF_LABEL, "type": "bool"})
	return bool(prefs.call("get_value", PREF))


static func allowed(effect_id: String) -> bool:
	return effect_id != PUPPET_ID


static func float_code(prepared: String) -> String:
	var out: String = prepared
	var hints: Array[Array] = [
		["\\bsource_color\\s*,\\s*", ""],
		["\\s*,\\s*source_color\\b", ""],
		["\\s*:\\s*source_color\\b", ""],
		["\\bTEXTURE\\b", IN_UNIFORM],
	]
	for pair: Array in hints:
		var re: RegEx = RegEx.new()
		re.compile(String(pair[0]))
		out = re.sub(out, String(pair[1]), true)
	var st: RegEx = RegEx.new()
	st.compile("render_mode[^;]*;|shader_type\\s+canvas_item\\s*;")
	var last: int = -1
	for m: RegExMatch in st.search_all(out):
		last = maxi(last, m.get_end())
	if last < 0:
		return out
	return out.substr(0, last) + IN_LINE + out.substr(last)


static func copy_material() -> ShaderMaterial:
	if _copy == null:
		var sh: Shader = Shader.new()
		sh.code = float_code(FileAccess.get_file_as_string(COPY_SHADER))
		_copy = sh
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _copy
	return m
