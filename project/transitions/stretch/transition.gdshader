shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int axis = 0;
uniform float amount : hint_range(1.5, 12.0) = 5.0;
uniform float blur : hint_range(0.0, 1.0) = 0.6;
uniform float blend : hint_range(0.01, 0.3) = 0.08;

const int SAMPLES = 16;

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec2 squash(vec2 uv, float l) {
	vec2 s = uv;
	if (axis == 0) {
		s.x = 0.5 + (uv.x - 0.5) * exp(-l);
	} else {
		s.y = 0.5 + (uv.y - 0.5) * exp(-l);
	}
	return s;
}

vec4 stretched(vec2 uv, float l, float spread, bool use_from, float j) {
	if (spread < 0.00001) {
		vec2 s = squash(uv, l);
		return use_from ? from_clamped(s) : to_clamped(s);
	}
	vec4 acc = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float f = (float(i) + j) / float(SAMPLES) - 0.5;
		vec2 s = squash(uv, l + f * spread);
		acc += use_from ? from_clamped(s) : to_clamped(s);
	}
	return acc / float(SAMPLES);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = p < 0.5 ? 4.0 * p * p * p : 1.0 - 4.0 * (1.0 - p) * (1.0 - p) * (1.0 - p);
	float rate = p < 0.5 ? 12.0 * p * p : 12.0 * (1.0 - p) * (1.0 - p);
	float l = log(max(amount, 1.0001));
	float l_from = 2.0 * l * e;
	float l_to = 2.0 * l * (1.0 - e);
	float spread = blur * 0.08 * 2.0 * l * rate;
	float b = max(blend, 0.005);
	float w = smoothstep(0.5 - b, 0.5 + b, p);
	float j = dither(uv);
	if (w <= 0.0) {
		return stretched(uv, l_from, spread, true, j);
	}
	if (w >= 1.0) {
		return stretched(uv, l_to, spread, false, j);
	}
	return mix(stretched(uv, l_from, spread, true, j), stretched(uv, l_to, spread, false, j), w);
}

void fragment() {
	COLOR = transition(UV);
}
