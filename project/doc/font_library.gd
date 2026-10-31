extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const TOKEN := "Imported font: "
const DIR := "fonts"
const PROJECT_DIR := "Fonts"
const EXTENSIONS: PackedStringArray = ["ttf", "otf", "woff", "woff2", "ttc", "pfb", "fnt"]
const SCOPE_USER := "user"
const SCOPE_PROJECT := "project"

static var project_dirs: PackedStringArray = PackedStringArray()
static var library_override: String = ""
static var last_error: String = ""
static var serial: int = 0


static func is_token(name_: String) -> bool:
	return name_.begins_with(TOKEN)


static func token_for(file_name: String) -> String:
	return TOKEN + file_name.get_file()


static func file_of(token: String) -> String:
	return token.substr(TOKEN.length()).get_file() if is_token(token) else ""


static func library_dir() -> String:
	if not library_override.is_empty():
		DirAccess.make_dir_recursive_absolute(library_override)
		return library_override
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("data_path"):
			var d: String = String(prefs.call("data_path", DIR))
			DirAccess.make_dir_recursive_absolute(d)
			return d
	return ""


static func project_dir_of(doc: Project) -> String:
	if doc == null or doc.path.is_empty():
		return ""
	return doc.path.get_base_dir().path_join(PROJECT_DIR)


static func use_project(doc: Project) -> void:
	var d: String = project_dir_of(doc)
	if d.is_empty() or project_dirs.has(d):
		return
	project_dirs.insert(0, d)
	bump()


static func bump() -> void:
	serial += 1
	var ts: GDScript = load("res://doc/title_style.gd")
	if ts != null and ts.has_method("forget_fonts"):
		ts.call("forget_fonts")


static func path_of(token: String, doc: Project = null) -> String:
	var file: String = file_of(token)
	if file.is_empty():
		return ""
	var dirs: PackedStringArray = PackedStringArray()
	var own: String = project_dir_of(doc)
	if not own.is_empty():
		dirs.append(own)
	dirs.append_array(project_dirs)
	var lib: String = library_dir()
	if not lib.is_empty():
		dirs.append(lib)
	for d: String in dirs:
		var p: String = d.path_join(file)
		if FileAccess.file_exists(p):
			return p
	return ""


static func is_font_file(path: String) -> bool:
	return EXTENSIONS.has(path.get_extension().to_lower())


static func loads(path: String) -> bool:
	var ff: FontFile = FontFile.new()
	return ff.load_dynamic_font(path) == OK


static func copy_into(src: String, dir: String, as_name: String = "") -> String:
	last_error = ""
	if not FileAccess.file_exists(src):
		last_error = "the file is not there: " + src
		return ""
	if not is_font_file(src):
		last_error = src.get_file() + " is not a font file (.ttf, .otf, .woff, .woff2)"
		return ""
	if not loads(src):
		last_error = src.get_file() + " could not be read as a font"
		return ""
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		last_error = "could not make the folder " + dir
		return ""
	var name_: String = as_name.get_file() if not as_name.is_empty() else src.get_file()
	var dst: String = dir.path_join(name_)
	if src.simplify_path() != dst.simplify_path():
		if DirAccess.copy_absolute(src, dst) != OK:
			last_error = "could not copy the font into " + dir
			return ""
	bump()
	return dst


static func import_font(src: String, scope: String = SCOPE_USER, doc: Project = null) -> String:
	var dir: String = library_dir()
	if scope == SCOPE_PROJECT:
		dir = project_dir_of(doc)
		if dir.is_empty():
			last_error = "save the project first, so its fonts have a folder to go in"
			return ""
	if dir.is_empty():
		last_error = "there is no data folder for the font library"
		return ""
	var dst: String = copy_into(src, dir)
	if dst.is_empty():
		return ""
	if doc != null and scope == SCOPE_PROJECT:
		use_project(doc)
	return token_for(dst)


static func listing(doc: Project = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var own: String = project_dir_of(doc)
	for pair: Array in [[own, SCOPE_PROJECT], [library_dir(), SCOPE_USER]]:
		var d: String = String(pair[0])
		if d.is_empty():
			continue
		var da: DirAccess = DirAccess.open(d)
		if da == null:
			continue
		var names: PackedStringArray = PackedStringArray()
		for f: String in da.get_files():
			if is_font_file(f):
				names.append(f)
		names.sort()
		for f2: String in names:
			if seen.has(f2):
				continue
			seen[f2] = true
			out.append({"token": token_for(f2), "file": f2, "label": f2.get_basename(), "scope": String(pair[1]), "path": d.path_join(f2)})
	return out


static func tokens(doc: Project = null) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: Dictionary in listing(doc):
		out.append(String(f["token"]))
	return out


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		var out: Array = []
		var layers: Variant = d.get("layers")
		if layers is Array:
			for l: Variant in layers:
				if l is Dictionary:
					for k: Variant in (l as Dictionary).get("keys", []):
						out.append((k as Dictionary).get("v"))
		return out
	return v


static func names_in(v: Variant, into: Dictionary) -> void:
	var p: Variant = plain(v)
	if p is String:
		if is_token(String(p)):
			into[String(p)] = true
	elif p is Array:
		for x: Variant in p:
			names_in(x, into)


static func used(doc: Project) -> PackedStringArray:
	var found: Dictionary = {}
	if doc == null:
		return PackedStringArray()
	for m: MediaItem in doc.media:
		names_in(m.props.get("font"), found)
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				names_in(c.props.get("font"), found)
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in found.keys():
		out.append(String(k))
	out.sort()
	return out


static func missing(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: String in used(doc):
		if path_of(t, doc).is_empty():
			out.append(t)
	return out


static func relink(token: String, src: String, doc: Project = null) -> bool:
	var dir: String = project_dir_of(doc)
	if dir.is_empty():
		dir = library_dir()
	return not copy_into(src, dir, file_of(token)).is_empty()


static func collect(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: String = project_dir_of(doc)
	if dir.is_empty():
		last_error = "save the project first, so its fonts have a folder to go in"
		return out
	for t: String in used(doc):
		var p: String = path_of(t, doc)
		if p.is_empty() or p.get_base_dir().simplify_path() == dir.simplify_path():
			continue
		if not copy_into(p, dir).is_empty():
			out.append(t)
	use_project(doc)
	return out
