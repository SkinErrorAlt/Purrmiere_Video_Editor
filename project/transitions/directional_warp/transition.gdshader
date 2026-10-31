shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 4;
uniform float smoothness : hint_range(0.05, 1.0) = 0.5;
uniform int timing = 0;

vec2 heading_of(int d) {
	if (d == 1) {
		return vec2(1.0, 0.0);
	} else if (d == 2) {
		return vec2(0.0, -1.0);
	} else if (d == 3) {
		return vec2(0.0, 1.0);
	} else if (d == 4) {
		return vec2(-1.0, -1.0);
	} else if (d == 5) {
		return vec2(1.0, -1.0);
	} else if (d == 6) {
		return vec2(-1.0, 1.0);
	} else if (d == 7) {
		return vec2(1.0, 1.0);
	}
	return vec2(-1.0, 0.0);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, timing == 1 ? 3 : 0);
	vec2 h = heading_of(direction);
	h /= abs(h.x) + abs(h.y);
	float s = max(smoothness, 0.0001);
	float x = dot(h, uv - 0.5);
	float front = -0.5 + e * (1.0 + s);
	float m = smoothstep(0.0, s, front - x);
	vec2 fp = 0.5 + (uv - 0.5) * (1.0 - m);
	vec2 tp = 0.5 + (uv - 0.5) * m;
	if (m <= 0.0) {
		return texture(from_tex, uv);
	}
	if (m >= 1.0) {
		return texture(to_tex, uv);
	}
	return mix(texture(from_tex, fp), texture(to_tex, tp), m);
}

void fragment() {
	COLOR = transition(UV);
}
