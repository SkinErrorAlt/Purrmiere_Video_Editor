shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int timing = 1;
uniform float shadow : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_size : hint_range(0.0, 0.5) = 0.08;

vec2 travel_of(int d) {
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

int curve_of(int t) {
	if (t == 1) {
		return 3;
	} else if (t == 2) {
		return 4;
	} else if (t == 3) {
		return 2;
	} else if (t == 4) {
		return 5;
	} else if (t == 5) {
		return 7;
	}
	return 0;
}

float outside_by(vec2 q) {
	vec2 o = max(vec2(0.0), max(-q, q - 1.0));
	o.x *= tr_ratio();
	return length(o);
}

vec4 transition(vec2 uv) {
	vec2 v = travel_of(direction);
	float e = tr_ease(progress, curve_of(timing));
	vec2 p = uv - v * e;
	if (tr_inside(p)) {
		return texture(from_tex, p);
	}
	vec4 c = texture(to_tex, uv);
	float fall = 1.0 - smoothstep(0.0, max(shadow_size, 0.0001), outside_by(p));
	float s = shadow * fall * fall * clamp((1.0 - e) * 8.0, 0.0, 1.0);
	return tr_shade(c, 1.0 - 0.85 * s);
}

void fragment() {
	COLOR = transition(UV);
}
