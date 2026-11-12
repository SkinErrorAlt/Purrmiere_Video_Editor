extends RefCounted

const Clip := preload("res://doc/clip.gd")

const PANNER_ID := "pan_3d"
const IDS: PackedStringArray = ["pan_3d"]
const ANGLE_KEY := "angle"
const HEIGHT_KEY := "height"
const DISTANCE_KEY := "distance_m"
const NEAR_M := 0.5
const FAR_M := 10.0
const HEIGHT_LOW := -40.0
const HEIGHT_HIGH := 80.0
const DEFAULTS: Dictionary = {"angle": 45.0, "height": 0.0, "distance_m": 1.5}
const LABEL := "3D Panner"


static func find(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for ae: Variant in c.audio.get("effects", []):
		if ae is Dictionary and IDS.has(String((ae as Dictionary).get("id", ""))) and bool((ae as Dictionary).get("enabled", true)):
			return {"entry": ae, "audio": true}
	for e: Dictionary in c.effects:
		if IDS.has(String(e.get("id", ""))) and bool(e.get("enabled", true)):
			return {"entry": e, "audio": false}
	return {}


static func ring_of_metres(m: float) -> float:
	return clampf((m - NEAR_M) / (FAR_M - NEAR_M), 0.0, 1.0)


static func metres_of_ring(r: float) -> float:
	return snappedf(lerpf(NEAR_M, FAR_M, clampf(r, 0.0, 1.0)), 0.01)


static func angle_of_ring(deg: float) -> float:
	return snappedf(wrapf(deg, -180.0, 180.0), 0.1)


static func height_of_slider(v: float) -> float:
	return snappedf(clampf(v, HEIGHT_LOW, HEIGHT_HIGH), 1.0)
