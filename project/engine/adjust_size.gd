extends RefCounted

const MediaItem := preload("res://doc/media_item.gd")
const Sequence := preload("res://doc/sequence.gd")
const OWN_SIZE_PROP := "own_size"
const ATLAS_META := "adjust_atlas"
const UNDER_NAME := "AdjustUnder"


static func has_own_size(m: MediaItem) -> bool:
	return m != null and m.kind == "adjust" and bool(m.props.get(OWN_SIZE_PROP, false)) and m.width > 0 and m.height > 0


static func size_of(m: MediaItem, seq: Sequence) -> Vector2i:
	var full: Vector2i = Vector2i(maxi(seq.width, 1), maxi(seq.height, 1)) if seq != null else Vector2i(1920, 1080)
	if not has_own_size(m):
		return full
	return Vector2i(clampi(m.width, 1, full.x), clampi(m.height, 1, full.y))


static func share_of(m: MediaItem, seq: Sequence) -> Rect2:
	var full: Vector2i = Vector2i(maxi(seq.width, 1), maxi(seq.height, 1)) if seq != null else Vector2i(1920, 1080)
	var own: Vector2i = size_of(m, seq)
	var k: Vector2 = Vector2(float(own.x) / float(full.x), float(own.y) / float(full.y))
	return Rect2((Vector2.ONE - k) * 0.5, k)


static func region_of(l: Node, tex: Texture2D, seq: Sequence) -> Texture2D:
	var m: MediaItem = l.get("media") as MediaItem
	if tex == null or not has_own_size(m):
		if l.has_meta(ATLAS_META):
			l.remove_meta(ATLAS_META)
		return tex
	var share: Rect2 = share_of(m, seq)
	var px: Vector2 = tex.get_size()
	var want: Rect2 = Rect2((share.position * px).round(), (share.size * px).round())
	var atlas: AtlasTexture = l.get_meta(ATLAS_META) as AtlasTexture if l.has_meta(ATLAS_META) else null
	if atlas == null:
		atlas = AtlasTexture.new()
		l.set_meta(ATLAS_META, atlas)
	if atlas.atlas != tex:
		atlas.atlas = tex
	if atlas.region != want:
		atlas.region = want
	return atlas


static func under(l: Node, full: Texture2D, seq: Sequence) -> void:
	var rect: TextureRect = l.get_node_or_null(UNDER_NAME) as TextureRect
	var m: MediaItem = l.get("media") as MediaItem
	if full == null or not has_own_size(m) or seq == null:
		if rect != null:
			l.remove_child(rect)
			rect.queue_free()
		return
	if rect == null:
		rect = TextureRect.new()
		rect.name = UNDER_NAME
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_child(rect)
		l.move_child(rect, 0)
	var q: float = float(l.get("quality_scale"))
	rect.texture = full
	rect.position = Vector2.ZERO
	rect.size = Vector2(float(seq.width), float(seq.height)) * q
