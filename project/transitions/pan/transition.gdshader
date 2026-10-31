shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 2;
uniform int timing = 2;
uniform float gap : hint_range(0.0, 0.5) = 0.08;
uniform float pull_back : hint_range(0.0, 1.0) = 0.12;
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

vec4 transition(vec2 uv) {
	vec2 v = travel_of(direction);
	float span = 1.0 + gap;
	float e = tr_ease(progress, curve_of(timing));
	float k = 1.0 + pull_back * sin(TR_PI * clamp(progress, 0.0, 1.0));
	vec2 c = 0.5 + (uv - 0.5) * k;
	vec2 p = c - v * e * span;
	if (tr_inside(p)) {
		return texture(from_tex, p);
	}
	vec2 q = p + v * span;
	if (tr_inside(q)) {
		return texture(to_tex, q);
	}
	return vec4(background.rgb * background.a, background.a);
}

void fragment() {
	COLOR = transition(UV);
}
