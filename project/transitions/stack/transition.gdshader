shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 2;
uniform int timing = 1;
uniform float depth : hint_range(0.0, 0.6) = 0.12;
uniform float dim : hint_range(0.0, 1.0) = 0.35;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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
	vec2 q = uv + v * (1.0 - e);
	if (tr_inside(q)) {
		return texture(to_tex, q);
	}
	float back = clamp(progress, 0.0, 1.0);
	float sb = smoothstep(0.0, 1.0, back);
	float k = 1.0 - depth * sb;
	vec2 fp = 0.5 + (uv - 0.5) / max(k, 0.05);
	float fall = 1.0 - smoothstep(0.0, 0.12, outside_by(q));
	float s = shadow * fall * fall * clamp(e * 8.0, 0.0, 1.0);
	vec4 c;
	if (tr_inside(fp)) {
		c = tr_shade(texture(from_tex, fp), 1.0 - dim * sb);
	} else {
		c = vec4(background.rgb * background.a, background.a);
	}
	return tr_shade(c, 1.0 - 0.8 * s);
}

void fragment() {
	COLOR = transition(UV);
}
