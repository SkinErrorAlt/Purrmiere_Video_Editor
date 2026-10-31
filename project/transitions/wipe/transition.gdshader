shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float softness : hint_range(0.0, 0.5) = 0.12;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

float wipe_coord(vec2 uv) {
	if (direction == 1) {
		return 1.0 - uv.x;
	} else if (direction == 2) {
		return uv.y;
	} else if (direction == 3) {
		return 1.0 - uv.y;
	} else if (direction == 4) {
		return (uv.x + uv.y) * 0.5;
	} else if (direction == 5) {
		return (1.0 - uv.x + uv.y) * 0.5;
	} else if (direction == 6) {
		return (uv.x + 1.0 - uv.y) * 0.5;
	} else if (direction == 7) {
		return (2.0 - uv.x - uv.y) * 0.5;
	}
	return uv.x;
}

float wipe_pixel() {
	if (direction < 2) {
		return 1.0 / frame_px.x;
	} else if (direction < 4) {
		return 1.0 / frame_px.y;
	}
	return 1.0 / (frame_px.x + frame_px.y);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float m = w_sweep(wipe_coord(uv), p, max(softness, wipe_pixel()));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
