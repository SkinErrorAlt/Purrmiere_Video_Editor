extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const MediaTags := preload("res://doc/media_tags.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PREFIX := "tags_"
const MAX_LISTED := 16


static func is_mine(id: String) -> bool:
	return id.begins_with(PREFIX)


static func menu_item(d: Project, entry_id: String, ids: PackedStringArray) -> Dictionary:
	var sub: Array = []
	if entry_id.begins_with("bin:"):
		var bin: String = entry_id.substr(4)
		sub.append(PmMenu.item("tags_folder", "Folder tags..."))
		var mine: PackedStringArray = MediaTags.bin_tags(d, bin)
		if not mine.is_empty():
			sub.append(PmMenu.separator())
			for i: int in mini(mine.size(), MAX_LISTED):
				sub.append(PmMenu.item("tags_folder_rm:" + mine[i], "Stop tagging with " + mine[i]))
		return PmMenu.sub_item("tags", "Tags", sub)
	sub.append(PmMenu.item("tags_add", "Add tags..."))
	if ids.size() == 1:
		sub.append(PmMenu.item("tags_edit", "Edit tags..."))
	var m: MediaItem = d.media_by_id(entry_id)
	var shown: PackedStringArray = MediaTags.effective(d, m) if m != null else PackedStringArray()
	if not shown.is_empty():
		sub.append(PmMenu.separator())
		for i: int in mini(shown.size(), MAX_LISTED):
			var from_folder: bool = not MediaTags.has_tag(m.tags, shown[i])
			sub.append(PmMenu.item("tags_rm:" + shown[i], "Remove " + shown[i] + (" (from the folder)" if from_folder else "")))
	if m != null and not m.tags_off.is_empty():
		sub.append(PmMenu.separator())
		for i: int in mini(m.tags_off.size(), MAX_LISTED):
			sub.append(PmMenu.item("tags_back:" + m.tags_off[i], "Give back folder tag " + m.tags_off[i]))
	if not shown.is_empty():
		sub.append(PmMenu.separator())
		for i: int in mini(shown.size(), MAX_LISTED):
			sub.append(PmMenu.item("tags_find:" + shown[i], "Show everything tagged " + shown[i]))
	return PmMenu.sub_item("tags", "Tags", sub)


static func on_pick(panel: Object, host: Node, d: Project, id: String, entry_id: String, ids: PackedStringArray) -> bool:
	if not is_mine(id) or d == null:
		return false
	if id == "tags_add":
		_ask(host, "Add tags", "", _on_add.bind(d, ids))
	elif id == "tags_edit":
		var m: MediaItem = d.media_by_id(entry_id)
		if m != null:
			_ask(host, "Tags on " + m.label, MediaTags.joined(MediaTags.effective(d, m)), _on_edit.bind(d, entry_id))
	elif id.begins_with("tags_rm:"):
		MediaTags.remove_tags(d, ids, PackedStringArray([id.substr(8)]))
	elif id.begins_with("tags_back:"):
		MediaTags.give_back(d, entry_id, id.substr(10))
	elif id.begins_with("tags_find:"):
		if panel != null and panel.has_method("search_for"):
			panel.call("search_for", MediaTags.TAG_PREFIX + id.substr(10))
	elif id == "tags_folder":
		var bin: String = entry_id.substr(4)
		_ask(host, "Tags for everything in " + bin.get_file(), MediaTags.joined(MediaTags.bin_tags(d, bin)), _on_folder.bind(d, bin))
	elif id.begins_with("tags_folder_rm:"):
		var bin2: String = entry_id.substr(4)
		MediaTags.set_bin_tags(d, bin2, MediaTags.without(MediaTags.bin_tags(d, bin2), PackedStringArray([id.substr(15)])))
	return true


static func _ask(host: Node, title: String, current: String, done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var how: String = "Separate tags with commas." if MediaTags.split_mode() == MediaTags.SPLIT_COMMAS else "Every word is its own tag."
	var fields: Array[Dictionary] = [{"key": "tags", "label": "Tags", "default": current}, {"key": "note", "type": "note", "default": how + " The way tags are split is in Settings, Bin tags are split by."}]
	var answered: Signal = PmUI.form(host, title, fields, "Apply", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary:
			done.call(String((result as Dictionary).get("tags", "")))
	)


static func _on_add(text: String, d: Project, ids: PackedStringArray) -> void:
	MediaTags.add_tags(d, ids, MediaTags.split(text))


static func _on_edit(text: String, d: Project, id: String) -> void:
	MediaTags.set_tags(d, id, MediaTags.split(text))


static func _on_folder(text: String, d: Project, bin: String) -> void:
	MediaTags.set_bin_tags(d, bin, MediaTags.split(text))
