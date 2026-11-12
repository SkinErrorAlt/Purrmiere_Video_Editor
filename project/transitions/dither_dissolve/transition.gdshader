shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int pattern : hint_range(0, 4) = 1;
uniform float cell : hint_range(1.0, 16.0) = 2.0;
uniform float softness : hint_range(0.0, 0.5) = 0.0;
uniform int curve = 0;

float dith2(vec2 a) {
	vec2 f = floor(mod(a, 2.0));
	return fract(f.x * 0.5 + f.y * f.y * 0.75);
}

float dith4(vec2 a) {
	return dith2(a * 0.5) * 0.25 + dith2(a);
}

float dith8(vec2 a) {
	return dith4(a * 0.5) * 0.25 + dith2(a);
}

float screen_at(vec2 c) {
	if (pattern == 0) {
		return dith2(c) * 1.3333333;
	} else if (pattern == 1) {
		return dith4(c) * 1.0666667;
	} else if (pattern == 2) {
		return dith8(c) * 1.0158730;
	} else if (pattern == 3) {
		return fract(floor(c.y) * 0.3819660 + 0.11);
	}
	return tr_hash(floor(c) + 0.5);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec2 c = uv * frame_px / max(cell * max(px_scale, 0.0001), 0.5);
	float d = clamp(screen_at(c), 0.0, 1.0);
	float s = max(softness, 0.0005);
	float t = mix(-s, 1.0 + s, p);
	float m = smoothstep(d - s, d + s, t);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
