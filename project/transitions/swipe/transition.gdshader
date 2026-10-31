shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float snap : hint_range(2.0, 8.0) = 4.0;
uniform float blur : hint_range(0.0, 1.0) = 0.7;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const int SAMPLES = 24;

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

vec4 strip(vec2 uv, vec2 v, float pos) {
	vec2 p = uv - v * pos;
	if (tr_inside(p)) {
		return texture(from_tex, p);
	}
	vec2 q = p + v;
	if (tr_inside(q)) {
		return texture(to_tex, q);
	}
	return vec4(background.rgb * background.a, background.a);
}

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 transition(vec2 uv) {
	vec2 v = travel_of(direction);
	float k = clamp(snap, 2.0, 8.0);
	float t = clamp(progress, 0.0, 1.0);
	float e;
	float vel;
	if (t < 0.5) {
		e = 0.5 * pow(2.0 * t, k);
		vel = k * pow(2.0 * t, k - 1.0);
	} else {
		e = 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
		vel = k * pow(2.0 - 2.0 * t, k - 1.0);
	}
	float len = blur * 0.06 * vel;
	if (len < 0.00001) {
		return strip(uv, v, e);
	}
	float j = dither(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float s = ((float(i) + j) / float(SAMPLES) - 0.5) * len;
		acc += strip(uv, v, e + s);
	}
	return acc / float(SAMPLES);
}

void fragment() {
	COLOR = transition(UV);
}
