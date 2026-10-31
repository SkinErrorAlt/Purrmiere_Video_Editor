shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.8;
uniform int first = 0;
uniform float drips : hint_range(2.0, 80.0) = 18.0;
uniform float raggedness : hint_range(0.0, 1.0) = 0.6;

vec2 fall_dir() {
	if (direction == 1) {
		return vec2(0.0, -1.0);
	} else if (direction == 2) {
		return vec2(-1.0, 0.0);
	} else if (direction == 3) {
		return vec2(1.0, 0.0);
	}
	return vec2(0.0, 1.0);
}

float drop(float across, float t, float salt) {
	float spread = raggedness * 0.4;
	float n = 0.85 * tr_noise(vec2(across * drips, salt)) + 0.15 * tr_noise(vec2(across * drips * 3.1, salt + 7.0));
	float s = clamp((t - spread * n) / (1.0 - spread), 0.0, 1.0);
	return s * s * 1.25;
}

float luma(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec4 lay(vec4 top, float cov, vec4 under, float leak) {
	return top * cov + under * (1.0 - cov + cov * (1.0 - top.a) * leak);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 f = fall_dir();
	float across = abs(f.y) > 0.5 ? uv.x * tr_ratio() : uv.y;
	float t_a = clamp(p / 0.7, 0.0, 1.0);
	float t_b = clamp((p - 0.3) / 0.7, 0.0, 1.0);
	vec2 uv_a = uv - f * drop(across, t_a, 1.3);
	vec2 uv_b = uv - f * drop(across, t_b, 4.1);
	vec4 ca = from_at(uv_a);
	vec4 cb = from_at(uv_b);
	bool a_ok = tr_inside(uv_a) && ((first == 1) ? luma(ca) >= threshold : luma(ca) < threshold);
	bool b_ok = tr_inside(uv_b) && ((first == 1) ? luma(cb) < threshold : luma(cb) >= threshold);
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	vec4 res = to_at(uv);
	if (b_ok) {
		res = lay(cb, 1.0, res, leak);
	}
	if (a_ok) {
		res = lay(ca, 1.0, res, leak);
	}
	return res;
}

void fragment() {
	COLOR = transition(UV);
}
