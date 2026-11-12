extends RefCounted

const OUTLINE_INK := Color(1.0, 0.45, 0.85, 0.7)
const OUTLINE_SHADE := Color(0.0, 0.0, 0.0, 0.45)
const DASH := 6.0

static var _key: String = ""
static var _edges: PackedInt32Array = PackedInt32Array()


static func outline_edges(mesh: Dictionary) -> PackedInt32Array:
	var key: String = String(mesh.get("key", ""))
	if key == _key and not key.is_empty():
		return _edges
	var tris: PackedInt32Array = mesh["tris"]
	var n: int = (mesh["verts"] as PackedVector2Array).size()
	var uses: Dictionary = {}
	var order: PackedInt64Array = PackedInt64Array()
	for t: int in tris.size() / 3:
		for k: int in 3:
			var a: int = tris[t * 3 + k]
			var b: int = tris[t * 3 + (k + 1) % 3]
			var ek: int = mini(a, b) * n + maxi(a, b)
			if not uses.has(ek):
				order.append(ek)
			uses[ek] = int(uses.get(ek, 0)) + 1
	var out: PackedInt32Array = PackedInt32Array()
	for ek2: int in order:
		if int(uses[ek2]) == 1:
			out.append(ek2 / n)
			out.append(ek2 % n)
	_key = key
	_edges = out
	return out


static func draw_outline(ci: CanvasItem, xf: Transform2D, mesh: Dictionary) -> void:
	var edges: PackedInt32Array = outline_edges(mesh)
	var verts: PackedVector2Array = mesh["verts"]
	for i: int in range(0, edges.size() - 1, 2):
		var a: Vector2 = xf * verts[edges[i]]
		var b: Vector2 = xf * verts[edges[i + 1]]
		ci.draw_line(a, b, OUTLINE_SHADE, 2.5, true)
		ci.draw_line(a, b, OUTLINE_INK, 1.0, true)
