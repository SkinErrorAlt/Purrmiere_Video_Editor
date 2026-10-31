shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int key_from = 0;
uniform int order = 0;
uniform float softness : hint_range(0.02, 1.0) = 0.3;
uniform float lighter : hint_range(0.0, 1.0) = 0.5;

float luma_of(vec4 c) {
	vec3 s = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return clamp(dot(s, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0) * c.a;
}

vec4 transition(vec2 uv) {
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	float k = key_from == 1 ? luma_of(f) : luma_of(t);
	if (order == 1) {
		k = 1.0 - k;
	}
	float s = softness;
	float w = clamp((progress * (1.0 + s) - (1.0 - k)) / s, 0.0, 1.0);
	vec4 m = mix(f, t, w);
	float wf = clamp((1.0 - progress) * 2.0, 0.0, 1.0);
	float wt = clamp(progress * 2.0, 0.0, 1.0);
	vec4 mx = max(f * wf, t * wt);
	vec4 lit = max(m, mx);
	float env = 4.0 * progress * (1.0 - progress);
	return mix(m, lit, lighter * env);
}

void fragment() {
	COLOR = transition(UV);
}
