shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int style = 0;
uniform int colour = 0;
uniform float hold : hint_range(0.0, 0.6) = 0.12;
uniform float softness : hint_range(0.02, 0.5) = 0.18;
uniform int curve = 1;

const float CROSS = 0.06;

vec3 unpremul(vec4 c) {
	return c.a > 0.0 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

vec3 tone(vec3 c, float flip, float mono) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 x = mix(c, vec3(l), mono);
	float k = softness;
	vec3 s;
	if (style == 1) {
		s = vec3(flip);
	} else {
		float thr = mix(1.0 + k, -k, flip);
		s = smoothstep(vec3(thr - k), vec3(thr + k), x);
	}
	return mix(x, vec3(1.0) - x, s);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (p <= 0.0) {
		return a;
	}
	if (p >= 1.0) {
		return b;
	}
	float h = min(hold, 0.6);
	float edge = 0.5 - h * 0.5 - CROSS * 0.5;
	float ramp = style == 1 ? min(0.1, edge) : edge;
	float start = edge - ramp;
	float out_t = clamp((p - start) / max(ramp, 0.0001), 0.0, 1.0);
	float in_t = clamp((1.0 - p - start) / max(ramp, 0.0001), 0.0, 1.0);
	if (curve == 1) {
		out_t = out_t * out_t * (3.0 - 2.0 * out_t);
		in_t = in_t * in_t * (3.0 - 2.0 * in_t);
	}
	float mono = colour == 1 ? 1.0 : 0.0;
	vec3 fa = tone(unpremul(a), mix(out_t, clamp((out_t - 0.12) / 0.88, 0.0, 1.0), mono), mono * smoothstep(0.0, 0.12, out_t));
	vec3 fb = tone(unpremul(b), mix(in_t, clamp((in_t - 0.12) / 0.88, 0.0, 1.0), mono), mono * smoothstep(0.0, 0.12, in_t));
	float k = clamp((p - (0.5 - CROSS * 0.5)) / CROSS, 0.0, 1.0);
	k = k * k * (3.0 - 2.0 * k);
	vec4 pa = vec4(fa * a.a, a.a);
	vec4 pb = vec4(fb * b.a, b.a);
	return mix(pa, pb, k);
}

void fragment() {
	COLOR = transition(UV);
}
