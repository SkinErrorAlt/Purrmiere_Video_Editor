extends RefCounted

const MAGIC := "POBJ"
const VERSION := 1

static var _root: String = ""


static func set_root(path: String) -> void:
	_root = path.replace("\\", "/")


static func root() -> String:
	if not _root.is_empty():
		return _root
	var given: String = OS.get_environment("PURR_OBJ_STORE")
	if not given.is_empty():
		_root = given.replace("\\", "/")
		return _root
	var cache: String = ""
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var bridge: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
		if bridge != null and bool(bridge.get("available")):
			cache = String(bridge.call("cache_dir"))
	if cache.is_empty():
		cache = OS.get_user_data_dir()
	_root = cache.replace("\\", "/") + "/purrobj"
	return _root


static func path_for(project_id: String, clip_id: String, mask_id: String) -> String:
	var folder: String = root() + "/" + _safe(project_id)
	return folder + "/" + _safe(clip_id) + "_" + _safe(mask_id) + ".pobj"


static func write(path: String, side: int, frames: Dictionary) -> bool:
	var folder: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
		return false
	var keys: PackedInt32Array = PackedInt32Array()
	for key: Variant in frames.keys():
		keys.append(int(key))
	keys.sort()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(MAGIC.to_utf8_buffer())
	file.store_32(VERSION)
	file.store_32(maxi(side, 0))
	file.store_32(keys.size())
	for frame: int in keys:
		var blob: PackedByteArray = frames[frame]
		file.store_32(frame)
		file.store_32(blob.size())
	for frame2: int in keys:
		var blob2: PackedByteArray = frames[frame2]
		file.store_buffer(blob2)
	file.close()
	return true


static func merge(path: String, side: int, frames: Dictionary) -> bool:
	var index: Dictionary = index_of(path)
	if not bool(index.get("ok", false)):
		return write(path, side, frames)
	var all: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		for key: Variant in (index.get("frames", {}) as Dictionary).keys():
			var spot: Dictionary = (index["frames"] as Dictionary)[key]
			file.seek(int(spot.get("at", 0)))
			all[int(key)] = file.get_buffer(int(spot.get("size", 0)))
		file.close()
	for key2: Variant in frames.keys():
		all[int(key2)] = frames[key2]
	return write(path, maxi(side, int(index.get("side", 0))), all)


static func index_of(path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "side": 0, "frames": {}, "error": ""}
	if not FileAccess.file_exists(path):
		out["error"] = "no store file"
		return out
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		out["error"] = "the store file would not open"
		return out
	var magic: PackedByteArray = file.get_buffer(4)
	if magic.get_string_from_utf8() != MAGIC:
		file.close()
		out["error"] = "the store file is not a POBJ file"
		return out
	var version: int = file.get_32()
	if version != VERSION:
		file.close()
		out["error"] = "the store file is from another version"
		return out
	out["side"] = file.get_32()
	var count: int = file.get_32()
	var frames: Dictionary = {}
	var order: PackedInt32Array = PackedInt32Array()
	var sizes: PackedInt32Array = PackedInt32Array()
	for i: int in count:
		order.append(file.get_32())
		sizes.append(file.get_32())
	var at: int = int(file.get_position())
	for i2: int in count:
		frames[order[i2]] = {"at": at, "size": sizes[i2]}
		at += sizes[i2]
	file.close()
	out["frames"] = frames
	out["ok"] = true
	return out


static func read_frame(path: String, frame: int, index: Dictionary = {}) -> Image:
	var use: Dictionary = index if bool(index.get("ok", false)) else index_of(path)
	if not bool(use.get("ok", false)):
		return null
	var frames: Dictionary = use.get("frames", {})
	if not frames.has(frame):
		return null
	var spot: Dictionary = frames[frame]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	file.seek(int(spot.get("at", 0)))
	var blob: PackedByteArray = file.get_buffer(int(spot.get("size", 0)))
	file.close()
	if blob.is_empty():
		return null
	var img: Image = Image.new()
	if img.load_png_from_buffer(blob) != OK:
		return null
	return img


static func frame_list(path: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var index: Dictionary = index_of(path)
	if not bool(index.get("ok", false)):
		return out
	for key: Variant in (index.get("frames", {}) as Dictionary).keys():
		out.append(int(key))
	out.sort()
	return out


static func nearest(path: String, frame: int, index: Dictionary = {}) -> int:
	var use: Dictionary = index if bool(index.get("ok", false)) else index_of(path)
	if not bool(use.get("ok", false)):
		return -1
	var frames: Dictionary = use.get("frames", {})
	var best: int = -1
	for key: Variant in frames.keys():
		var at: int = int(key)
		if best < 0 or absi(at - frame) < absi(best - frame):
			best = at
	return best


static func drop(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _safe(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var ch: String = text[i]
		out += ch if ch.is_valid_identifier() or ch == "_" or ch == "-" or (ch >= "0" and ch <= "9") else "_"
	return out if not out.is_empty() else "x"
