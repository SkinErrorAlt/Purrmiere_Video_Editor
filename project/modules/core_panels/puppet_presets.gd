extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Puppet := preload("res://doc/puppet.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const UI_PATH := "res://modules/core_panels/puppet_ui.gd"
const DATA_SUB := "puppet_layouts"
const FILE_NAME := "layouts.json"
const P := Puppet.KIND_POSITION
const B := Puppet.KIND_BEND
const A := Puppet.KIND_ADVANCED
const BUILT_IN: Array = [
	{"name": "Figure", "pins": [[0.0, -0.4, 0], [0.0, -0.18, 1], [-0.32, -0.12, 0], [0.32, -0.12, 0], [-0.18, -0.14, 1], [0.18, -0.14, 1], [0.0, 0.08, 2], [-0.14, 0.42, 0], [0.14, 0.42, 0], [-0.12, 0.24, 1], [0.12, 0.24, 1]]},
	{"name": "Arm or leg", "pins": [[-0.42, 0.0, 0], [0.0, 0.0, 1], [0.42, 0.0, 0]]},
	{"name": "Tail or rope", "pins": [[-0.45, 0.0, 0], [-0.22, 0.0, 1], [0.0, 0.0, 1], [0.22, 0.0, 1], [0.45, 0.0, 0]]},
	{"name": "Flag", "pins": [[-0.45, -0.4, 0], [-0.45, 0.4, 0], [0.0, 0.0, 1], [0.45, -0.4, 0], [0.45, 0.4, 0]]},
	{"name": "Corners", "pins": [[-0.45, -0.45, 0], [0.45, -0.45, 0], [-0.45, 0.45, 0], [0.45, 0.45, 0]]},
	{"name": "Head turn", "pins": [[0.0, 0.42, 0], [0.0, -0.1, 2]]},
]

static var data_dir_override: String = ""


static func _ui() -> GDScript:
	return load(UI_PATH)


static func _file() -> String:
	var dir: String = data_dir_override
	if dir.is_empty():
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		var prefs: Node = tree.root.get_node_or_null("/root/Prefs") if tree != null else null
		dir = String(prefs.call("ensure_dir", DATA_SUB)) if prefs != null else ProjectSettings.globalize_path("user://" + DATA_SUB)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join(FILE_NAME)


static func saved() -> Array:
	var path: String = _file()
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		return []
	var out: Array = []
	for v: Variant in (parsed as Array):
		if v is Dictionary and (v as Dictionary).get("pins") is Array:
			out.append(v)
	return out


static func layouts() -> Array:
	var out: Array = []
	for b: Variant in BUILT_IN:
		out.append(b)
	out.append_array(saved())
	return out


static func layout_of(e: Dictionary, size: Vector2) -> Array:
	var rest: PackedVector2Array = Puppet.rest_of(e)
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var out: Array = []
	for i: int in rest.size():
		out.append([snappedf(rest[i].x / maxf(size.x, 1.0), 0.0001), snappedf(rest[i].y / maxf(size.y, 1.0), 0.0001), kinds[i] if i < kinds.size() else P])
	return out


static func save_layout(e: Dictionary, size: Vector2, name: String) -> bool:
	var pins: Array = layout_of(e, size)
	if pins.is_empty():
		return false
	var list: Array = saved()
	var kept: Array = []
	for v: Variant in list:
		if String((v as Dictionary).get("name", "")) != name:
			kept.append(v)
	kept.append({"name": name, "pins": pins})
	var f: FileAccess = FileAccess.open(_file(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(kept, " "))
	f.close()
	return true


static func next_name() -> String:
	var used: Dictionary = {}
	for v: Variant in saved():
		used[String((v as Dictionary).get("name", ""))] = true
	var n: int = 1
	while used.has("My layout " + str(n)):
		n += 1
	return "My layout " + str(n)


static func apply(d: Project, s: Sequence, c: Clip, layout: Dictionary) -> int:
	var pins_in: Array = layout.get("pins", [])
	var e: Dictionary = Puppet.any_effect_of(c)
	var size: Vector2 = Puppet.size_of(e, _ui().call("layer_size", d, s, c)) if not e.is_empty() else _ui().call("layer_size", d, s, c)
	var rest: PackedVector2Array = PackedVector2Array()
	var kinds: Array = []
	var mesh: Dictionary = Puppet.mesh_of_effect(e, size) if not e.is_empty() else {}
	for row: Variant in pins_in:
		if not (row is Array) or (row as Array).size() < 2:
			continue
		var r: Array = row
		var at: Vector2 = Vector2(float(r[0]) * size.x, float(r[1]) * size.y)
		if not mesh.is_empty():
			var got: Dictionary = Puppet.locate(mesh["verts"], mesh["tris"], at)
			if got.is_empty() or not bool(got["inside"]):
				continue
		rest.append(at)
		kinds.append(clampi(int(r[2]) if r.size() > 2 else P, P, A))
	if rest.is_empty():
		return 0
	var label: String = "Apply pin layout"
	if e.is_empty():
		var entry: Dictionary = _ui().call("new_entry", d, s, c, rest[0])
		var params0: Dictionary = entry["params"]
		_fill(params0, c, entry, rest, kinds, s.playhead)
		var uid: String = d.mint_id("e")
		var cmd: EffectCmds.InsertEffectEntry = EffectCmds.InsertEffectEntry.new(s.id, c.id, entry, uid)
		cmd.label = label
		var first: Array[Command] = [cmd]
		_ui().call("_run", d, label, first)
		return rest.size()
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true)
	for key: Variant in params.keys():
		if String(key).begins_with("link_"):
			params.erase(key)
	params.erase(Puppet.KEY_LINKS)
	params.erase(Puppet.KEY_TURNS)
	_fill(params, c, e, rest, kinds, s.playhead)
	_ui().call("_set_params", d, s, c, e, params, label)
	return rest.size()


static func _fill(params: Dictionary, c: Clip, e: Dictionary, rest: PackedVector2Array, kinds: Array, playhead: float) -> void:
	var flat: Array = Puppet.flat(rest)
	params[Puppet.KEY_REST] = AnimProp.make(flat)
	params[Puppet.KEY_PINS] = AnimProp.set_key(AnimProp.make(flat), Puppet.key_time(c, e, Puppet.KEY_PINS, playhead), flat)
	var any: bool = false
	for k: Variant in kinds:
		if int(k) != P:
			any = true
	if any:
		params[Puppet.KEY_KINDS] = AnimProp.make(kinds)
	else:
		params.erase(Puppet.KEY_KINDS)
