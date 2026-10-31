extends RefCounted

const EXE_NAME := "rife-ncnn-vulkan.exe"
const MODELS: PackedStringArray = ["rife-v4.6", "rife-v4"]
const DEFAULT_MODEL := "rife-v4.6"
const GPU_AUTO := "Auto"
const GPU_CPU := "CPU"
const GPU_PROBE_FILE := "purrframes_gpus.json"

static var _dir_override: String = ""


static func set_dir_override(dir: String) -> void:
	_dir_override = dir


static func candidate_dirs() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not _dir_override.is_empty():
		out.append(_dir_override)
	out.append(ProjectSettings.globalize_path("res://addons/rife"))
	var exe_dir: String = OS.get_executable_path().get_base_dir()
	out.append(exe_dir.path_join("rife"))
	out.append(exe_dir.path_join("third_party").path_join("rife"))
	var res_dir: String = ProjectSettings.globalize_path("res://")
	out.append(res_dir.path_join("..").path_join("native").path_join("third_party").path_join("rife").simplify_path())
	return out


static func tool_dir() -> String:
	for d: String in candidate_dirs():
		if FileAccess.file_exists(d.path_join(EXE_NAME)):
			return d
	return ""


static func exe_path() -> String:
	var d: String = tool_dir()
	return "" if d.is_empty() else d.path_join(EXE_NAME)


static func available() -> bool:
	return not exe_path().is_empty()


static func models() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: String = tool_dir()
	for m: String in MODELS:
		if d.is_empty() or FileAccess.file_exists(d.path_join(m).path_join("flownet.param")):
			out.append(m)
	return out


static func model_path(model: String) -> String:
	var d: String = tool_dir()
	var m: String = model if MODELS.has(model) else DEFAULT_MODEL
	return d.path_join(m)


static func gpu_id(choice: String) -> int:
	if choice == GPU_CPU:
		return -1
	if choice.begins_with("GPU "):
		var num: String = choice.substr(4).get_slice(":", 0).strip_edges()
		if num.is_valid_int():
			return int(num)
	return -2


static func gpu_choice(id: int, name_: String) -> String:
	if name_.is_empty():
		return "GPU " + str(id)
	return "GPU " + str(id) + ": " + name_


static func parse_gpus(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var re: RegEx = RegEx.new()
	re.compile("^\\[(\\d+) ([^\\]]+)\\]")
	for line: String in text.split("\n"):
		var m: RegExMatch = re.search(line.strip_edges())
		if m == null:
			continue
		var id: int = int(m.get_string(1))
		if seen.has(id):
			continue
		seen[id] = true
		out.append({"id": id, "name": m.get_string(2).strip_edges()})
	return out


static func gpu_choices(gpus: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([GPU_AUTO, GPU_CPU])
	if gpus.is_empty():
		out.append(gpu_choice(0, ""))
		out.append(gpu_choice(1, ""))
		return out
	for g: Dictionary in gpus:
		out.append(gpu_choice(int(g.get("id", 0)), String(g.get("name", ""))))
	return out


static func dir_args(in_dir: String, out_dir: String, count: int, model: String, gpu: int, uhd: bool) -> PackedStringArray:
	var args: PackedStringArray = PackedStringArray(["-i", in_dir, "-o", out_dir, "-n", str(count), "-m", model_path(model), "-f", "%08d.png"])
	if gpu >= -1:
		args.append("-g")
		args.append(str(gpu))
	if uhd:
		args.append("-u")
	return args


static func probe_args() -> PackedStringArray:
	return PackedStringArray(["-0", "none.png", "-1", "none.png", "-o", "none.png", "-m", model_path(DEFAULT_MODEL)])


static func probe_gpus() -> Array[Dictionary]:
	var exe: String = exe_path()
	if exe.is_empty():
		return []
	var output: Array = []
	OS.execute(exe, probe_args(), output, true, false)
	var text: String = ""
	for o: Variant in output:
		text += str(o)
	return parse_gpus(text)
