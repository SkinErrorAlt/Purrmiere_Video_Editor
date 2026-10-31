shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int gradient = 0;
uniform float softness : hint_range(0.0, 1.0) = 0.1;
uniform bool invert = false;
uniform float scale : hint_range(0.5, 12.0) = 3.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform int curve = 0;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

float luma(vec4 c) {
	return clamp(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	float v;
	if (gradient == 1) {
		vec2 dir = vec2(cos(radians(angle)), sin(radians(angle)));
		float lo = min(dir.x, 0.0) + min(dir.y, 0.0);
		float hi = max(dir.x, 0.0) + max(dir.y, 0.0);
		v = (dot(uv, dir) - lo) / max(hi - lo, 0.0001);
	} else if (gradient == 2) {
		v = length(tr_world(uv)) / (0.5 * length(vec2(tr_ratio(), 1.0)));
	} else if (gradient == 3) {
		v = luma(a);
	} else if (gradient == 4) {
		v = luma(b);
	} else {
		float n = tr_fbm(tr_world(uv) * scale + vec2(13.7, 5.3));
		v = (n - 0.22) / 0.56;
	}
	v = clamp(v, 0.0, 1.0);
	if (invert) {
		v = 1.0 - v;
	}
	float m = w_sweep(v, p, max(softness, 0.002));
	return mix(a, b, m);
}

void fragment() {
	COLOR = transition(UV);
}
