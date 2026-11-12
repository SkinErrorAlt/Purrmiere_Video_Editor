extends RefCounted

const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectSource := preload("res://doc/object_source.gd")
const ObjectStore := preload("res://engine/object_store.gd")
const KEEP := 64

static var _cache: Dictionary = {}
static var _order: Array = []
static var _bound: Dictionary = {}
static var _index: Dictionary = {}
static var _doc: Object = null
static var links_resolved: int = 0
static var links_lost: int = 0


static func bind(mask_id: String, store_path: String) -> void:
	if mask_id.is_empty():
		return
	if store_path.is_empty() or not FileAccess.file_exists(store_path):
		_bound.erase(mask_id)
		_index.erase(mask_id)
		return
	_bound[mask_id] = store_path
	_index[mask_id] = ObjectStore.index_of(store_path)


static func bound(mask_id: String) -> String:
	return String(_bound.get(mask_id, ""))


static func bind_doc(doc: Object) -> void:
	_doc = doc


static func bound_doc() -> Object:
	return _doc


static func target_of(m: Dictionary) -> Dictionary:
	return ObjectSource.resolve(_doc, ObjectSource.mask_link_of(m))


static func refresh(doc: Object) -> void:
	_doc = doc
	if doc == null:
		return
	var project_id: String = String(doc.get("id"))
	var sequences: Variant = doc.get("sequences")
	if not (sequences is Array):
		return
	for s: Variant in sequences:
		var tracks: Variant = s.get("video_tracks")
		if not (tracks is Array):
			continue
		for track: Variant in tracks:
			for c: Variant in track.get("clips"):
				for mask: Dictionary in c.get("masks"):
					if not ObjectMask.is_object(mask) or ObjectSource.is_linked_mask(mask):
						continue
					var mask_id: String = str(mask.get("id", ""))
					bind(mask_id, ObjectStore.path_for(project_id, String(c.get("id")), mask_id))


static func live_id(m: Dictionary) -> String:
	if not ObjectSource.is_linked_mask(m):
		return String(m.get("id", ""))
	var got: Dictionary = target_of(m)
	return String((got.get("mask", {}) as Dictionary).get("id", "")) if bool(got.get("ok", false)) else ""


static func span_of_mask(m: Dictionary) -> Vector2i:
	var id: String = live_id(m)
	if id.is_empty():
		return Vector2i(-1, -1)
	var span: Vector2i = tracked_span(id)
	if span.x < 0 or not ObjectSource.is_linked_mask(m):
		return span
	var off: int = ObjectSource.frame_offset(m)
	return Vector2i(span.x - off, span.y - off)


static func frames_of_mask(m: Dictionary) -> int:
	var id: String = live_id(m)
	return tracked_frames(id) if not id.is_empty() else 0


static func tracked_span(mask_id: String) -> Vector2i:
	var index: Dictionary = _index.get(mask_id, {})
	if not bool(index.get("ok", false)):
		return Vector2i(-1, -1)
	var lo: int = -1
	var hi: int = -1
	for k: Variant in (index.get("frames", {}) as Dictionary).keys():
		var f: int = int(k)
		lo = f if lo < 0 else mini(lo, f)
		hi = maxi(hi, f)
	return Vector2i(lo, hi)


static func tracked_frames(mask_id: String) -> int:
	var index: Dictionary = _index.get(mask_id, {})
	return (index.get("frames", {}) as Dictionary).size() if bool(index.get("ok", false)) else 0


static func texture_for(m: Dictionary, frame: int) -> Texture2D:
	if ObjectSource.is_linked_mask(m):
		var got: Dictionary = target_of(m)
		if not bool(got["ok"]):
			links_lost += 1
			return null
		links_resolved += 1
		return texture_for(got["mask"], frame + ObjectSource.frame_offset(m))
	var id: String = str(m.get("id", ""))
	var key: int = ObjectMask.nearest_key(m, frame)
	var store: String = String(_bound.get(id, ""))
	var from_store: bool = false
	if not store.is_empty():
		var index: Dictionary = _index.get(id, {})
		var frames: Dictionary = index.get("frames", {}) if bool(index.get("ok", false)) else {}
		if frames.has(frame):
			key = frame
			from_store = true
		elif key < 0:
			var near: int = ObjectStore.nearest(store, frame, index)
			if near >= 0:
				key = near
				from_store = true
	if key < 0:
		return null
	var edit: Image = ObjectMask.edit_at(m, frame)
	var stamp: String = id + ("@s" if from_store else "@") + str(key) + "#" + str(int(m.get("side", 0))) + "." + str(_fingerprint(m, key))
	if edit != null:
		stamp += "+e" + str(frame) + "." + str(ObjectMask.edit_stamp(m, frame))
	if _cache.has(stamp):
		return _cache[stamp]
	var img: Image = ObjectStore.read_frame(store, key, _index.get(id, {})) if from_store else ObjectMask.matte_at(m, key)
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_R8:
		img.convert(Image.FORMAT_R8)
	if edit != null:
		img = ObjectMask.apply_edit(img, edit, ObjectMask.edit_box(m, frame))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[stamp] = tex
	_order.append(stamp)
	while _order.size() > KEEP:
		var drop: String = String(_order[0])
		_order.remove_at(0)
		_cache.erase(drop)
	return tex


static func forget(id: String) -> void:
	if _bound.has(id):
		_index[id] = ObjectStore.index_of(String(_bound[id]))
	var keep: Array = []
	for stamp: Variant in _order:
		var text: String = String(stamp)
		if text.begins_with(id + "@"):
			_cache.erase(text)
		else:
			keep.append(text)
	_order = keep


static func clear() -> void:
	_cache = {}
	_order = []
	_bound = {}
	_index = {}
	_doc = null
	links_resolved = 0
	links_lost = 0


static func _fingerprint(m: Dictionary, key: int) -> int:
	var mattes: Dictionary = m.get("mattes", {})
	var text: String = String(mattes.get(str(key), ""))
	return text.hash()
