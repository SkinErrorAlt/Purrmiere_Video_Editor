extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const REGISTRY_PATH := "res://engine/effect_registry.gd"
const ID_PREFIX := "yt_"
const TAG := "youtube"
const SORT_BASE := 1000000
const KIND := "effect_stack"

static var _cache: Array[Dictionary] = []


static func k(points: Array, interp: String = "ease_both", loop: String = "once") -> Dictionary:
	var p: Dictionary = AnimProp.make(0.0)
	for pt: Variant in points:
		var a: Array = pt
		var how: String = String(a[2]) if a.size() > 2 else interp
		p = AnimProp.set_key(p, float(a[0]), a[1], how)
	if loop != "once":
		var li: int = AnimProp.keys_layer_index(p)
		if li >= 0:
			(p["layers"][li] as Dictionary)["loop"] = loop
	return p


static func fx(effect_id: String, params: Dictionary = {}) -> Dictionary:
	return {"id": effect_id, "params": params.duplicate(true)}


static func stack(id: String, group: String, label: String, effects: Array, tags: Array = [], anchor: String = "start") -> Dictionary:
	var all_tags: Array = [TAG, group.to_lower()]
	for t: Variant in tags:
		all_tags.append(String(t))
	return {"id": ID_PREFIX + id, "kind": KIND, "label": group + ": " + label, "tags": all_tags, "effects": effects, "anchor": anchor}


static func definitions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(stack("zoom_punch_in", "Zoom", "Punch in and stay", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.08, 135.0, "ease_out"]], "ease_out"), "blur": k([[0.0, 0.0], [0.04, 0.6], [0.14, 0.0]])})]))
	out.append(stack("zoom_punch_in_out", "Zoom", "Punch in and back", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.08, 140.0], [0.6, 140.0], [0.75, 100.0]], "ease_out"), "blur": k([[0.0, 0.0], [0.04, 0.6], [0.14, 0.0]])})]))
	out.append(stack("zoom_smooth_in", "Zoom", "Smooth zoom in", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [1.2, 150.0]])})]))
	out.append(stack("zoom_slow_push", "Zoom", "Slow push in", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [6.0, 115.0]], "linear")})]))
	out.append(stack("zoom_out_reveal", "Zoom", "Zoom out reveal", [fx("yt_zoom", {"zoom": k([[0.0, 180.0], [1.0, 100.0]], "ease_out")})]))
	out.append(stack("zoom_double_punch", "Zoom", "Double punch", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.06, 125.0], [0.4, 125.0], [0.46, 160.0]], "ease_out"), "blur": k([[0.0, 0.0], [0.03, 0.5], [0.12, 0.0], [0.4, 0.0], [0.43, 0.5], [0.52, 0.0]])})]))
	out.append(stack("zoom_dramatic", "Zoom", "Dramatic three step", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.35, 130.0], [0.7, 170.0], [1.05, 230.0]], "hold")}), fx("vignette")]))
	out.append(stack("zoom_meme", "Zoom", "Meme zoom", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.1, 260.0, "ease_out"]], "ease_out"), "turn": k([[0.0, 0.0], [0.1, -7.0]], "ease_out")}), fx("deep_fry", {"amount": k([[0.0, 0.0], [0.1, 0.85]], "hold")})], ["meme"]))
	out.append(stack("zoom_bounce", "Zoom", "Springy bounce in", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.12, 132.0], [0.22, 117.0], [0.3, 125.0], [0.4, 121.0], [0.5, 122.0]])})]))
	out.append(stack("zoom_whoosh_out", "Zoom", "Zoom through to the next clip", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.3, 320.0]], "ease_in"), "blur": k([[0.0, 0.0], [0.3, 1.0]], "ease_in")})], ["transition"], "end"))
	out.append(stack("zoom_whoosh_in", "Zoom", "Zoom in from the last clip", [fx("yt_zoom", {"zoom": k([[0.0, 320.0], [0.3, 100.0]], "ease_out"), "blur": k([[0.0, 1.0], [0.3, 0.0]], "ease_out")})], ["transition"]))
	out.append(stack("zoom_tilt_punch", "Zoom", "Punch with a tilt", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.08, 130.0]], "ease_out"), "turn": k([[0.0, 0.0], [0.08, 4.0]], "ease_out")})]))
	out.append(stack("punch_quick", "Zoom", "Quick hit punch", [fx("zoom_punch", {"zoom": 20.0, "hold": 0.1, "release": 0.2})]))
	out.append(stack("punch_beat", "Zoom", "Punch on every beat", [fx("zoom_punch", {"zoom": 12.0, "hold": 0.05, "release": 0.3, "repeat": 0.5})], ["beat"]))
	out.append(stack("punch_big_shaky", "Zoom", "Big shaky punch", [fx("zoom_punch", {"zoom": 45.0, "jolt": 0.6, "turn": 3.0})]))
	out.append(stack("shake_handheld", "Shake", "Handheld", [fx("camera_shake", {"amplitude": 6.0, "rotation": 0.6, "zoom": 2.0, "frequency": 1.2, "octaves": 2, "motion_blur": 0.2})]))
	out.append(stack("shake_walking", "Shake", "Walking", [fx("camera_shake", {"amplitude": 10.0, "rotation": 1.0, "zoom": 3.0, "frequency": 1.8, "octaves": 2})]))
	out.append(stack("shake_earthquake", "Shake", "Earthquake", [fx("camera_shake", {"amplitude": 40.0, "rotation": 2.5, "zoom": 8.0, "frequency": 9.0, "octaves": 4, "motion_blur": 0.8})]))
	out.append(stack("shake_drunk", "Shake", "Dizzy sway", [fx("camera_shake", {"amplitude": 30.0, "rotation": 4.0, "zoom": 6.0, "frequency": 0.4, "octaves": 1})]))
	out.append(stack("shake_rage", "Shake", "Rage", [fx("camera_shake", {"amplitude": 60.0, "rotation": 5.0, "zoom": 10.0, "frequency": 14.0, "octaves": 3, "motion_blur": 0.7})]))
	out.append(stack("shake_impact", "Shake", "Impact that dies away", [fx("camera_shake", {"amplitude": k([[0.0, 70.0], [0.7, 0.0]], "ease_out"), "rotation": k([[0.0, 4.0], [0.7, 0.0]], "ease_out"), "zoom": 8.0, "frequency": 12.0, "octaves": 3, "motion_blur": 0.7})]))
	out.append(stack("shake_explosion", "Shake", "Explosion", [fx("camera_kick", {"style": 1, "strength": 90.0, "duration": 0.8, "rotation": 4.0, "zoom": 6.0}), fx("hit_flash", {"colour": [1.0, 0.75, 0.4, 1.0], "mode": 1, "fade": 0.5})]))
	out.append(stack("shake_recoil", "Shake", "Gun recoil burst", [fx("camera_kick", {"style": 0, "strength": 25.0, "duration": 0.18, "repeat": 0.12, "count": 6})], ["game"]))
	out.append(stack("shake_tension", "Shake", "Subtle tension", [fx("camera_shake", {"amplitude": 3.0, "rotation": 0.3, "zoom": 1.5, "frequency": 0.6, "octaves": 2, "motion_blur": 0.0})]))
	out.append(stack("beat_pulse", "Beat", "Pulse at 120 bpm", [fx("yt_beat_pulse")]))
	out.append(stack("beat_pulse_shake", "Beat", "Pulse and shake", [fx("yt_beat_pulse", {"scale": 4.0}), fx("yt_beat_shake", {"amount": 14.0})]))
	out.append(stack("beat_rainbow", "Beat", "Rainbow flash", [fx("yt_beat_flash", {"cycle": true, "strength": 0.45})]))
	out.append(stack("beat_thump", "Beat", "Strong thump", [fx("yt_beat_pulse", {"scale": 12.0, "brightness": 0.4, "decay": 0.8})]))
	out.append(stack("beat_bar_shake", "Beat", "Shake every bar", [fx("yt_beat_shake", {"every": 2, "amount": 50.0, "rotation": 3.0})]))
	out.append(stack("beat_drop", "Beat", "Bass drop", [fx("yt_invert_flash", {"flips": 3}), fx("yt_rgb_split_hit", {"split": 60.0}), fx("camera_shake", {"amplitude": k([[0.0, 60.0], [0.9, 0.0]], "ease_out"), "frequency": 10.0, "zoom": 8.0, "octaves": 3})]))
	out.append(stack("hit_impact_frame", "Hit", "Anime impact frame", [fx("impact_frame"), fx("camera_shake", {"amplitude": k([[0.0, 50.0], [0.5, 0.0]], "ease_out"), "frequency": 12.0, "zoom": 6.0})], ["anime"]))
	out.append(stack("hit_invert", "Hit", "Invert flicker", [fx("yt_invert_flash")]))
	out.append(stack("hit_white_flash", "Hit", "White flash punch", [fx("hit_flash"), fx("zoom_punch", {"zoom": 18.0, "hold": 0.08, "release": 0.25})]))
	out.append(stack("hit_rgb", "Hit", "RGB split", [fx("yt_rgb_split_hit")]))
	out.append(stack("hit_glitch", "Hit", "Glitch burst", [fx("yt_glitch_hit")]))
	out.append(stack("hit_shockwave", "Hit", "Shockwave", [fx("shockwave"), fx("yt_rgb_split_hit", {"split": 20.0, "jolt": 4.0})]))
	out.append(stack("hit_speed_lines", "Hit", "Anime speed lines", [fx("speed_lines"), fx("zoom_punch", {"zoom": 15.0, "hold": 1.0})], ["anime"]))
	out.append(stack("hit_jump_scare", "Hit", "Jump scare", [fx("yt_zoom", {"zoom": k([[0.0, 100.0], [0.04, 165.0, "ease_out"]], "ease_out")}), fx("yt_rgb_split_hit", {"split": 70.0, "duration": 0.5}), fx("hit_flash", {"colour": [1.0, 0.1, 0.1, 1.0], "mode": 3})]))
	out.append(stack("hit_strobe", "Hit", "Fast strobe", [fx("strobe", {"period": 0.08, "duration": 0.5, "fade": 0.1})]))
	out.append(stack("glitch_vhs", "Glitch", "VHS tape", [fx("vhs", {"amount": 0.8}), fx("chromatic_aberration", {"strength": 3.0})], ["retro"]))
	out.append(stack("glitch_datamosh", "Glitch", "Datamosh build", [fx("datamosh")]))
	out.append(stack("glitch_digital", "Glitch", "Steady digital glitch", [fx("glitch", {"amount": 0.3})]))
	out.append(stack("glitch_repeat", "Glitch", "Glitch every second", [fx("yt_glitch_hit", {"repeat_every": 1.0, "duration": 0.25})]))
	out.append(stack("retro_pixel_in", "Retro", "Pixelate in", [fx("pixelate", {"block": k([[0.0, 64.0], [0.5, 1.0]], "ease_out")})], ["transition"]))
	out.append(stack("retro_pixel_out", "Retro", "Pixelate out", [fx("pixelate", {"block": k([[0.0, 1.0], [0.5, 64.0]], "ease_in")})], ["transition"], "end"))
	out.append(stack("whip_left", "Whip", "Whip left in and out", [fx("whip_pan", {"direction": 0})], ["transition"]))
	out.append(stack("whip_right", "Whip", "Whip right in and out", [fx("whip_pan", {"direction": 1})], ["transition"]))
	out.append(stack("whip_up", "Whip", "Whip up in and out", [fx("whip_pan", {"direction": 2})], ["transition"]))
	out.append(stack("whip_spin", "Whip", "Spin in and out", [fx("whip_pan", {"direction": 4, "duration": 0.4})], ["transition"]))
	out.append(stack("burn_in_out", "Burn", "Film burn in and out", [fx("film_burn")], ["transition"]))
	out.append(stack("burn_fast", "Burn", "Fast white burn", [fx("film_burn", {"duration": 0.35, "white_out": 1.0})], ["transition"]))
	out.append(stack("flash_in", "Burn", "Flash in from white", [fx("exposure_flash", {"when": 1})], ["transition"]))
	out.append(stack("light_warm_leak", "Light", "Warm leak", [fx("light_leak", {"flicker": 0.3})]))
	out.append(stack("light_pink_leak", "Light", "Pink leak", [fx("light_leak", {"colour": [1.0, 0.35, 0.65, 1.0], "flicker": 0.3})]))
	out.append(stack("light_blue_leak", "Light", "Blue leak", [fx("light_leak", {"colour": [0.35, 0.6, 1.0, 1.0], "edge": 0, "flicker": 0.2})]))
	out.append(stack("light_flare_sweep", "Light", "Flare sweep", [fx("lens_flare", {"position": k([[0.0, [0.05, 0.3]], [3.0, [0.95, 0.25]]], "linear")})]))
	out.append(stack("light_sun_flare", "Light", "Sun flare", [fx("lens_flare", {"position": [0.82, 0.18], "brightness": 1.2, "tint": [1.0, 0.85, 0.6, 1.0]})]))
	out.append(stack("burst_confetti", "Burst", "Confetti pop", [fx("yt_confetti")]))
	out.append(stack("burst_cannons", "Burst", "Confetti cannons", [fx("yt_confetti", {"mode": 2})]))
	out.append(stack("game_hitmarker", "Game", "Hit marker", [fx("yt_hitmarker")]))
	out.append(stack("game_final_hit", "Game", "Final hit marker", [fx("yt_hitmarker", {"final_hit": true, "size": 0.06}), fx("yt_rgb_split_hit", {"split": 18.0, "jolt": 3.0})]))
	out.append(stack("game_meme_hitmarker", "Game", "Meme hit markers", [fx("yt_hitmarker", {"size": 0.12, "repeat_every": 0.35, "thickness": 8.0}), fx("camera_shake", {"amplitude": 18.0, "frequency": 10.0})], ["meme"]))
	out.append(stack("game_crosshair", "Game", "Crosshair", [fx("yt_crosshair")]))
	out.append(stack("callout_arrow", "Callout", "Pointing arrow", [fx("yt_arrow_point")]))
	out.append(stack("callout_circle", "Callout", "Circle it", [fx("callout", {"shape": 0})]))
	out.append(stack("callout_spotlight", "Callout", "Spotlight", [fx("focus_area", {"blur": 0.3, "darken": 0.65, "ring_width": 4.0})]))
	out.append(stack("cam_rounded", "Cam", "Rounded with shadow", [fx("rounded_corners", {"radius": 40.0, "border": 4.0, "shadow": 0.6})]))
	out.append(stack("cam_top_right", "Cam", "Face cam top right", [fx("pip_frame", {"corner": 1, "size": 0.28, "roundness": 0.12, "border": 0.004})]))
	out.append(stack("cam_circle", "Cam", "Round face cam bottom left", [fx("pip_frame", {"corner": 2, "shape": 4, "size": 0.25, "border": 0.005})]))
	out.append(stack("cam_reaction_pop", "Cam", "Reaction cam pops in", [fx("pip_frame", {"corner": 3, "size": 0.32, "roundness": 0.1, "animate": 2})]))
	out.append(stack("vertical_blur_fill", "Vertical", "Blurred fill", [fx("blur_fill")]))
	out.append(stack("vertical_mirror_fill", "Vertical", "Mirrored fill", [fx("blur_fill", {"fill": 1})]))
	out.append(stack("cinema_bars_in", "Cinematic", "Bars slide in", [fx("letterbox", {"amount": k([[0.0, 0.0], [0.8, 1.0]])})]))
	out.append(stack("cinema_bars_out", "Cinematic", "Bars slide out", [fx("letterbox", {"amount": k([[0.0, 1.0], [0.8, 0.0]])})], [], "end"))
	out.append(stack("censor_blur", "Censor", "Blur box", [fx("face_blur", {"shape": 1, "style": 0})]))
	out.append(stack("censor_pixels", "Censor", "Pixel box", [fx("face_blur", {"shape": 1, "style": 1})]))
	out.append(stack("censor_bar", "Censor", "Black bar", [fx("face_blur", {"shape": 1, "style": 2, "size": 0.1, "stretch": 3.0, "feather": 0.0})]))
	out.append(stack("cam_border_gradient", "Cam", "Gradient border", [fx("yt_webcam_border")]))
	out.append(stack("cam_border_rainbow", "Cam", "Turning rainbow border", [fx("yt_webcam_border", {"style": 2, "spin": 0.5, "glow": 0.6})]))
	out.append(stack("cam_border_plain", "Cam", "Plain white border", [fx("yt_webcam_border", {"style": 0, "colour_a": [1.0, 1.0, 1.0, 1.0], "border": 6.0, "glow": 0.0})]))
	out.append(stack("callout_blur_box", "Callout", "Blur around a box", [fx("yt_blur_except_box")]))
	out.append(stack("freeze_scratch", "Freeze", "Record scratch", [fx("yt_freeze_frame")], ["meme"]))
	out.append(stack("freeze_mono", "Freeze", "Black and white hold", [fx("yt_freeze_frame", {"drain": 1.0, "tint_amount": 0.0, "tilt": 0.0, "push": 3.0})]))
	out.append(stack("vlog_rec", "Vlog", "Recording dot", [fx("yt_rec_dot")]))
	out.append(stack("vlog_found_footage", "Vlog", "Found footage", [fx("yt_rec_dot", {"blink": 2.0}), fx("vhs", {"amount": 0.6}), fx("camera_shake", {"amplitude": 8.0, "rotation": 0.8, "frequency": 1.5})], ["retro"]))
	out.append(stack("meme_bounce", "Meme", "Screensaver bounce", [fx("yt_screen_bounce")], ["meme"]))
	return out


static func registry() -> RefCounted:
	var script: GDScript = load(REGISTRY_PATH)
	if script == null:
		return null
	return script.call("shared")


static func _value(v: Variant) -> Dictionary:
	if v is Dictionary and (v as Dictionary).has("a"):
		return (v as Dictionary).duplicate(true)
	return AnimProp.make(v)


static func entry(raw: Dictionary, reg: RefCounted) -> Dictionary:
	var id: String = String(raw.get("id", ""))
	var params: Dictionary = {}
	if reg != null and bool(reg.call("has", id)):
		params = reg.call("default_params", id)
	var given: Dictionary = raw.get("params", {})
	for key: Variant in given.keys():
		params[String(key)] = _value(given[key])
	return {"id": id, "enabled": true, "params": params, "group": "", "mask": "", "mix": AnimProp.make(1.0)}


static func build(def: Dictionary, reg: RefCounted, index: int) -> Dictionary:
	var effects: Array = []
	for e: Variant in def.get("effects", []):
		effects.append(entry(e as Dictionary, reg))
	return {
		"id": String(def["id"]),
		"kind": KIND,
		"label": String(def["label"]),
		"tags": (def.get("tags", []) as Array).duplicate(),
		"payload": {"effects": effects},
		"created": "",
		"anchor": String(def.get("anchor", "start")),
		"percent": 0.0,
		"max_length": 0.0,
		"sort": SORT_BASE + index,
		"built_in": true,
	}


static func listing() -> Array[Dictionary]:
	if _cache.is_empty():
		var reg: RefCounted = registry()
		var defs: Array[Dictionary] = definitions()
		for i: int in defs.size():
			_cache.append(build(defs[i], reg, i))
	var out: Array[Dictionary] = []
	for p: Dictionary in _cache:
		out.append(p.duplicate(true))
	return out


static func forget() -> void:
	_cache.clear()


static func ships(id: String) -> bool:
	if not id.begins_with(ID_PREFIX):
		return false
	for d: Dictionary in definitions():
		if String(d["id"]) == id:
			return true
	return false


static func find(id: String) -> Dictionary:
	for p: Dictionary in listing():
		if String(p["id"]) == id:
			return p
	return {}


static func effect_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: Dictionary in definitions():
		for e: Variant in d.get("effects", []):
			var id: String = String((e as Dictionary).get("id", ""))
			if not out.has(id):
				out.append(id)
	return out
