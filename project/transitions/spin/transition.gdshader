shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float turn : hint_range(30.0, 720.0) = 180.0;
uniform int way = 0;
uniform float blur : hint_range(0.0, 1.0) = 0.7;
uniform float blend : hint_range(0.01, 0.3) = 0.06;
uniform int edges = 1;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const int SAMPLES = 16;

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 fetch(vec2 suv, bool use_from) {
	if (edges == 0) {
		return use_from ? from_mirrored(suv) : to_mirrored(suv);
	} else if (edges == 1) {
		return use_from ? from_clamped(suv) : to_clamped(suv);
	}
	if (!tr_inside(suv)) {
		return vec4(background.rgb * background.a, background.a);
	}
	return use_from ? texture(from_tex, suv) : texture(to_tex, suv);
}

vec4 turned(vec2 uv, float deg, float spread, bool use_from, float j) {
	vec2 w = tr_world(uv);
	float r = tr_ratio();
	float wide = max(r, 1.0 / r);
	int count = spread < 0.0001 ? 1 : SAMPLES;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < count; i++) {
		float f = count == 1 ? 0.0 : (float(i) + j) / float(SAMPLES) - 0.5;
		float a = radians(deg + f * spread);
		float k = edges == 1 ? abs(cos(a)) + wide * abs(sin(a)) : 1.0;
		vec2 src = tr_rotate(w, -a) / max(k, 1.0);
		acc += fetch(tr_frame_uv(src), use_from);
	}
	return acc / float(count);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = p < 0.5 ? 4.0 * p * p * p : 1.0 - 4.0 * (1.0 - p) * (1.0 - p) * (1.0 - p);
	float rate = p < 0.5 ? 12.0 * p * p : 12.0 * (1.0 - p) * (1.0 - p);
	float sgn = way == 0 ? -1.0 : 1.0;
	float a_from = sgn * 2.0 * turn * e;
	float a_to = sgn * 2.0 * turn * (e - 1.0);
	float spread = blur * 0.035 * 2.0 * turn * rate;
	float b = max(blend, 0.005);
	float w = smoothstep(0.5 - b, 0.5 + b, p);
	float j = dither(uv);
	if (w <= 0.0) {
		return turned(uv, a_from, spread, true, j);
	}
	if (w >= 1.0) {
		return turned(uv, a_to, spread, false, j);
	}
	return mix(turned(uv, a_from, spread, true, j), turned(uv, a_to, spread, false, j), w);
}

void fragment() {
	COLOR = transition(UV);
}
