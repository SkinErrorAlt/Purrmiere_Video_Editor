extends RefCounted

const DONE_FILE := "done.json"
const IN_DIR := "in"
const OUT_DIR := "out"

var root: String = ""
var entries: Dictionary = {}


func _init(root_: String = "") -> void:
	root = root_


func entry_dir(key: String) -> String:
	return root.path_join(key)


func out_dir(key: String) -> String:
	return entry_dir(key).path_join(OUT_DIR)


func in_dir(key: String) -> String:
	return entry_dir(key).path_join(IN_DIR)


func frame_path(key: String, index: int) -> String:
	return out_dir(key).path_join("%08d.png" % (index + 1))


func has(key: String) -> bool:
	return entries.has(key)


func scan() -> void:
	entries.clear()
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return
	for name_: String in DirAccess.get_directories_at(root):
		var done: String = root.path_join(name_).path_join(DONE_FILE)
		if not FileAccess.file_exists(done):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(done))
		if not (parsed is Dictionary):
			continue
		var d: Dictionary = parsed
		entries[name_] = {"bytes": int(d.get("bytes", 0)), "used": int(d.get("used", 0)), "factor": int(d.get("factor", 0)), "count": int(d.get("count", 0)), "cuts": d.get("cuts", [])}


func add(key: String, info: Dictionary) -> void:
	var e: Dictionary = {"bytes": int(info.get("bytes", 0)), "used": int(info.get("used", int(Time.get_unix_time_from_system()))), "factor": int(info.get("factor", 0)), "count": int(info.get("count", 0)), "cuts": info.get("cuts", [])}
	entries[key] = e


func write_done(key: String, info: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(entry_dir(key).path_join(DONE_FILE), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(info))
	f.close()
	return true


func touch(key: String) -> void:
	if entries.has(key):
		(entries[key] as Dictionary)["used"] = int(Time.get_unix_time_from_system())


func total_bytes() -> int:
	var total: int = 0
	for k: String in entries.keys():
		total += int((entries[k] as Dictionary).get("bytes", 0))
	return total


static func eviction_order(entries_: Dictionary, wanted: Dictionary) -> PackedStringArray:
	var loose: Array = []
	var kept: Array = []
	for k: String in entries_.keys():
		var e: Dictionary = entries_[k]
		var row: Array = [int(e.get("used", 0)), k]
		if wanted.has(k):
			kept.append(row)
		else:
			loose.append(row)
	loose.sort()
	kept.sort()
	var out: PackedStringArray = PackedStringArray()
	for r: Array in loose:
		out.append(String(r[1]))
	for r: Array in kept:
		out.append(String(r[1]))
	return out


static func evictions(entries_: Dictionary, wanted: Dictionary, cap_bytes: int, busy: Dictionary = {}) -> PackedStringArray:
	var total: int = 0
	for k: String in entries_.keys():
		total += int((entries_[k] as Dictionary).get("bytes", 0))
	var out: PackedStringArray = PackedStringArray()
	if total <= cap_bytes:
		return out
	for k: String in eviction_order(entries_, wanted):
		if total <= cap_bytes:
			break
		if busy.has(k):
			continue
		total -= int((entries_[k] as Dictionary).get("bytes", 0))
		out.append(k)
	return out


func enforce(cap_bytes: int, wanted: Dictionary, busy: Dictionary = {}) -> PackedStringArray:
	var gone: PackedStringArray = evictions(entries, wanted, cap_bytes, busy)
	for k: String in gone:
		remove(k)
	return gone


func remove(key: String) -> void:
	entries.erase(key)
	remove_tree(entry_dir(key))


func clear(busy: Dictionary = {}) -> int:
	var n: int = 0
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		entries.clear()
		return 0
	for name_: String in DirAccess.get_directories_at(root):
		if busy.has(name_):
			continue
		remove_tree(root.path_join(name_))
		entries.erase(name_)
		n += 1
	return n


static func dir_bytes(dir: String) -> int:
	var total: int = 0
	if not DirAccess.dir_exists_absolute(dir):
		return 0
	for f: String in DirAccess.get_files_at(dir):
		var fa: FileAccess = FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa != null:
			total += fa.get_length()
			fa.close()
	for d: String in DirAccess.get_directories_at(dir):
		total += dir_bytes(dir.path_join(d))
	return total


static func remove_tree(dir: String) -> void:
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		remove_tree(dir.path_join(d))
	DirAccess.remove_absolute(dir)
