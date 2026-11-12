extends RefCounted

const FAST := "efficienttam_ti_512"
const BEST := "sam2.1_base_plus_1024"
const MODULES: PackedStringArray = ["image_encoder", "memory_attention", "decoder", "memory_encoder"]

static var _cache_dir: String = ""


static func cache_root() -> String:
	if _cache_dir != "":
		return _cache_dir
	var local: String = OS.get_environment("PURR_OBJ_MODELS")
	if local != "":
		_cache_dir = local.replace("\\", "/")
		return _cache_dir
	var app: String = OS.get_environment("LOCALAPPDATA")
	if app == "":
		app = OS.get_user_data_dir()
	_cache_dir = app.replace("\\", "/") + "/Purrmiere/objsel/models"
	return _cache_dir


static func set_cache_root(path: String) -> void:
	_cache_dir = path.replace("\\", "/")


static func model_dir(id: String) -> String:
	return cache_root() + "/" + id


static func installed(id: String, precision: String = "fp16") -> bool:
	return read_manifest(id, precision).get("ok", false)


static func ids() -> PackedStringArray:
	return PackedStringArray([FAST, BEST])


static func label(id: String) -> String:
	if id == BEST:
		return "Best"
	if id == FAST:
		return "Fast"
	return id


static func read_manifest(id: String, precision: String = "fp16") -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "id": id, "dir": "", "precision": precision}
	var dir: String = model_dir(id)
	var path: String = dir + "/manifest_" + precision + ".json"
	if not FileAccess.file_exists(path):
		out["error"] = "the model is not downloaded"
		return out
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		out["error"] = "the model manifest could not be read"
		return out
	var man: Dictionary = parsed
	var files: Dictionary = man.get("files", {})
	for module in MODULES:
		var entry: Dictionary = files.get(module, {})
		var file_name: String = String(entry.get("file", ""))
		if file_name == "" or not FileAccess.file_exists(dir + "/" + file_name):
			out["error"] = "the model file for " + module + " is missing"
			return out
		out[module] = file_name
	out["ok"] = true
	out["dir"] = dir.replace("/", "\\")
	out["image_size"] = int(man.get("image_size", 512))
	out["embed_size"] = int(man.get("embed_size", 32))
	out["hidden_dim"] = int(man.get("hidden_dim", 256))
	out["mem_dim"] = int(man.get("mem_dim", 64))
	out["num_maskmem"] = int(man.get("num_maskmem", 7))
	out["max_obj_ptrs_in_encoder"] = int(man.get("max_obj_ptrs_in_encoder", 16))
	out["multimask_max_pt_num"] = int(man.get("multimask_max_pt_num", 1))
	out["use_high_res_features"] = bool(man.get("use_high_res_features", false))
	out["use_signed_tpos_enc_to_obj_ptrs"] = bool(man.get("use_signed_tpos_enc_to_obj_ptrs", false))
	out["dynamic_multimask_stability_thresh"] = float(man.get("dynamic_multimask_stability_thresh", 0.98))
	out["licence"] = String(man.get("licence", ""))
	out["bytes"] = _total_bytes(files)
	return out


static func _total_bytes(files: Dictionary) -> int:
	var total: int = 0
	for key in files:
		var entry: Dictionary = files[key]
		total += int(entry.get("bytes", 0))
	return total
