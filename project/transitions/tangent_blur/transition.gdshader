shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float reach : hint_range(0.0, 1.0) = 0.25;
uniform float blur : hint_range(0.0, 1.0) = 0.8;
uniform float blend : hint_range(0.01, 0.3) = 0.06;

const int SAMPLES = 20;
const float BEND = 1.25;

vec2 heading_of(int d) {
	if (d == 1) {
		return vec2(1.0, 0.0);
	} else if (d == 2) {
		return vec2(0.0, -1.0);
	} else if (d == 3) {
		return vec2(0.0, 1.0);
	} else if (d == 4) {
		return normalize(vec2(-1.0, -1.0));
	} else if (d == 5) {
		return normalize(vec2(1.0, -1.0));
	} else if (d == 6) {
		return normalize(vec2(-1.0, 1.0));
	} else if (d == 7) {
		return normalize(vec2(1.0, 1.0));
	}
	return vec2(-1.0, 0.0);
}

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 smeared(vec2 uv, vec2 h, float pos, float len, bool use_from, float j) {
	if (len < 0.00001) {
		vec2 s = uv - h * pos;
		return use_from ? from_mirrored(s) : to_mirrored(s);
	}
	vec4 acc = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float f = (float(i) + j) / float(SAMPLES) - 0.5;
		vec2 s = uv - h * (pos + f * len);
		acc += use_from ? from_mirrored(s) : to_mirrored(s);
	}
	return acc / float(SAMPLES);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec2 h = heading_of(direction);
	h.x /= tr_ratio();
	float top = tan(BEND);
	float u_from = clamp(2.0 * p, 0.0, 1.0);
	float u_to = clamp(2.0 - 2.0 * p, 0.0, 1.0);
	float tf = tan(u_from * BEND);
	float tt = tan(u_to * BEND);
	float pos_from = reach * tf / top;
	float pos_to = -reach * tt / top;
	float v_from = 2.0 * reach * BEND * (1.0 + tf * tf) / top;
	float v_to = 2.0 * reach * BEND * (1.0 + tt * tt) / top;
	float ends = smoothstep(0.0, 0.12, p) * smoothstep(0.0, 0.12, 1.0 - p);
	float len_from = blur * 0.09 * v_from * ends;
	float len_to = blur * 0.09 * v_to * ends;
	float b = max(blend, 0.005);
	float w = smoothstep(0.5 - b, 0.5 + b, p);
	float j = dither(uv);
	if (w <= 0.0) {
		return smeared(uv, h, pos_from, len_from, true, j);
	}
	if (w >= 1.0) {
		return smeared(uv, h, pos_to, len_to, false, j);
	}
	return mix(smeared(uv, h, pos_from, len_from, true, j), smeared(uv, h, pos_to, len_to, false, j), w);
}

void fragment() {
	COLOR = transition(UV);
}
