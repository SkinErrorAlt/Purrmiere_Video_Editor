shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float linear_light : hint_range(0.0, 1.0) = 1.0;
uniform int curve = 0;

vec3 srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec4 to_linear_premul(vec4 c) {
	vec3 s = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	return vec4(srgb_to_linear(s) * c.a, c.a);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	vec4 l = mix(to_linear_premul(f), to_linear_premul(t), p);
	vec3 s = l.a > 0.0001 ? clamp(l.rgb / l.a, 0.0, 1.0) : vec3(0.0);
	vec4 film = vec4(linear_to_srgb(s) * l.a, l.a);
	return mix(mix(f, t, p), film, linear_light);
}

void fragment() {
	COLOR = transition(UV);
}
