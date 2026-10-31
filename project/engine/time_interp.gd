extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MediaItem := preload("res://doc/media_item.gd")

const FIELD := "time_interp"
const PATH := "props.time_interp"
const SAMPLE := "sample"
const BLEND := "blend"
const FLOW := "flow"
const RIFE := "rife"
const MODES: PackedStringArray = [SAMPLE, BLEND, FLOW, RIFE]
const LABELS: Dictionary = {SAMPLE: "Frame sampling", BLEND: "Frame blending", FLOW: "Optical flow", RIFE: "Frame interpolation (RIFE)"}
const TIP := "How the frames in between are made when the clip is slowed down or sped up. Frame sampling repeats frames. Frame blending mixes the two nearest frames. Optical flow follows the motion to build new frames. At 100 % the picture is the same whatever you pick."
const W_EPS := 1.0 / 512.0
const GRID_SNAP := 0.0001
const NEXT_MIN := 0.25
const NEXT_MAX := 1.75
const FLOW_RANGE := 256.0
const FLOW_LEVELS := 3
const FLOW_RADIUS := 6
const FLOW_LAMBDA := 0.004
const SEARCH_PATCH := 2
const REFINE_PATCH := 1
const FALLBACK_LO := 0.08
const FALLBACK_HI := 0.25

static var providers: Dictionary = {}
static var disabled: bool = false


static func register_provider(mode: String, label: String, provider: Object) -> void:
	if provider == null:
		providers.erase(mode)
		return
	providers[mode] = {"label": label, "provider": provider}


static func provider_for(mode: String) -> Object:
	var e: Variant = providers.get(mode, null)
	if e is Dictionary:
		return (e as Dictionary).get("provider", null)
	return null


static func choices() -> Array:
	var out: Array = []
	for m: String in [SAMPLE, BLEND, FLOW]:
		out.append({"id": m, "label": String(LABELS[m])})
	for k: Variant in providers.keys():
		var e: Dictionary = providers[k]
		out.append({"id": String(k), "label": String(e.get("label", LABELS.get(String(k), String(k))))})
	return out


static func mode_of(c: Clip) -> String:
	if c == null:
		return SAMPLE
	var v: Variant = c.props.get(FIELD, SAMPLE)
	var s: String = String(v) if (v is String or v is StringName) else SAMPLE
	return s if MODES.has(s) or providers.has(s) else SAMPLE


static func retimed(c: Clip) -> bool:
	if c == null:
		return false
	if AnimProp.is_animated(c.speed):
		return true
	var v: Variant = c.speed.get("v", 1.0)
	return not ((v is float or v is int) and float(v) == 1.0)


static func shows_row(m: MediaItem, c: Clip) -> bool:
	return c != null and not c.is_nest() and m != null and m.kind == "video"


static func active_mode(c: Clip, m: MediaItem, media_fps: float) -> String:
	if disabled or c == null or m == null or m.kind != "video" or c.is_nest():
		return ""
	if media_fps <= 0.0 or m.props.has("still_time"):
		return ""
	var mode: String = mode_of(c)
	if mode == SAMPLE or not retimed(c):
		return ""
	if mode != BLEND and mode != FLOW and provider_for(mode) == null:
		return FLOW
	return mode


static func frame_pair(src_t: float, fps: float) -> Dictionary:
	if fps <= 0.0:
		return {"index": 0, "a": src_t, "b": src_t, "w": 0.0}
	var x: float = src_t * fps
	var i: int = int(floor(x + GRID_SNAP))
	var w: float = clampf(x - float(i), 0.0, 1.0)
	if w < W_EPS:
		w = 0.0
	return {"index": i, "a": float(i) / fps, "b": float(i + 1) / fps, "w": w}


static func partner_request_time(pair: Dictionary, fps: float, duration: float) -> float:
	var t: float = float(pair["b"]) + (0.5 / fps if fps > 0.0 else 0.0)
	if duration > 0.0:
		t = minf(t, duration)
	return maxf(t, 0.0)


static func weight_from_pts(src_t: float, pa: float, pb: float, fps: float) -> float:
	if fps <= 0.0:
		return 0.0
	var step: float = 1.0 / fps
	var gap: float = pb - pa
	if gap < step * NEXT_MIN or gap > step * NEXT_MAX:
		return 0.0
	var w: float = clampf((src_t - pa) / gap, 0.0, 1.0)
	if w < W_EPS:
		return 0.0
	if w > 1.0 - W_EPS:
		return 1.0
	return w


static func level_size(chain: Vector2i, level: int) -> Vector2i:
	var f: float = pow(2.0, float(level))
	return Vector2i(maxi(int(round(float(chain.x) / f)), 2), maxi(int(round(float(chain.y) / f)), 2))


static func encode_flow(v: Vector2) -> Color:
	var qx: int = clampi(int(round((v.x + FLOW_RANGE) / (2.0 * FLOW_RANGE) * 65535.0)), 0, 65535)
	var qy: int = clampi(int(round((v.y + FLOW_RANGE) / (2.0 * FLOW_RANGE) * 65535.0)), 0, 65535)
	return Color(float(qx >> 8) / 255.0, float(qx & 255) / 255.0, float(qy >> 8) / 255.0, float(qy & 255) / 255.0)


static func decode_flow(c: Color) -> Vector2:
	var qx: int = int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0))
	var qy: int = int(round(c.b * 255.0)) * 256 + int(round(c.a * 255.0))
	return Vector2(float(qx) / 65535.0 * 2.0 * FLOW_RANGE - FLOW_RANGE, float(qy) / 65535.0 * 2.0 * FLOW_RANGE - FLOW_RANGE)
