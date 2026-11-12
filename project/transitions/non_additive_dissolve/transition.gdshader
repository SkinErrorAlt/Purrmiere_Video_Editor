shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float balance : hint_range(0.0, 1.0) = 0.5;
uniform float bite : hint_range(0.02, 1.0) = 0.3;
uniform bool invert = false;
uniform float flare : hint_range(0.0, 1.0) = 0.25;
uniform int curve = 0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	float la = luma(a.rgb);
	float lb = luma(b.rgb);
	float drive = mix(la, 1.0 - lb, clamp(balance, 0.0, 1.0));
	if (invert) {
		drive = 1.0 - drive;
	}
	float s = max(bite, 0.02) * 0.5;
	float t = mix(-s, 1.0 + s, p);
	float m = smoothstep(drive - s, drive + s, t);
	vec4 mixed = mix(a, b, m);
	float lift = flare * 4.0 * p * (1.0 - p) * m * (1.0 - m);
	mixed.rgb += (a.rgb * (1.0 - m) + b.rgb * m) * lift;
	return mixed;
}

void fragment() {
	COLOR = transition(UV);
}
