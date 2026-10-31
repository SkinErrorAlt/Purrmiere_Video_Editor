shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 blend_of(vec3 a, vec3 b) {
	if (mode == 1) {
		return a + b - a * b;
	} else if (mode == 2) {
		return min(a, b);
	} else if (mode == 3) {
		return max(a, b);
	} else if (mode == 4) {
		vec3 lo = 2.0 * a * b;
		vec3 hi = 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
		return mix(lo, hi, step(vec3(0.5), b));
	} else if (mode == 5) {
		return abs(a - b);
	}
	return a * b;
}

vec4 blended(vec4 f, vec4 t) {
	vec3 fs = f.a > 0.0001 ? clamp(f.rgb / f.a, 0.0, 1.0) : vec3(0.0);
	vec3 ts = t.a > 0.0001 ? clamp(t.rgb / t.a, 0.0, 1.0) : vec3(0.0);
	vec3 rgb = (1.0 - t.a) * f.rgb + (1.0 - f.a) * t.rgb + f.a * t.a * blend_of(fs, ts);
	float a = f.a + t.a - f.a * t.a;
	return vec4(min(rgb, vec3(a)), a);
}

vec4 transition(vec2 uv) {
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	vec4 mid = mix(mix(f, t, 0.5), blended(f, t), strength);
	if (progress < 0.5) {
		return mix(f, mid, progress * 2.0);
	}
	return mix(mid, t, progress * 2.0 - 1.0);
}

void fragment() {
	COLOR = transition(UV);
}
