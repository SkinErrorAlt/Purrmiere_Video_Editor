shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int timing = 2;
uniform vec2 center = vec2(0.5, 0.5);
uniform float strength : hint_range(0.0, 0.25) = 0.07;
uniform float width : hint_range(0.02, 0.35) = 0.11;
uniform float flash : hint_range(0.0, 1.0) = 0.4;

int curve_of(int t) {
	if (t == 1) { return 3; }
	else if (t == 2) { return 4; }
	else if (t == 3) { return 2; }
	else if (t == 4) { return 5; }
	else if (t == 5) { return 7; }
	return 0;
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve_of(timing));
	vec2 q = (uv - center) * vec2(tr_ratio(), 1.0);
	float r = length(q);
	float front = e * (0.75 * max(tr_ratio(), 1.0) + width);
	float ring = exp(-pow((r - front) / max(width, 0.001), 2.0));

	vec2 n = r > 0.0001 ? normalize(uv - center) : vec2(0.0);
	vec2 disp = n * ring * strength;
	vec4 a = from_clamped(uv + disp);
	vec4 b = to_clamped(uv + disp);
	float m = 1.0 - smoothstep(front - width, front + width, r);
	vec4 base = mix(a, b, m);
	base.rgb += vec3(ring * flash);
	return vec4(clamp(base.rgb, 0.0, 1.0), base.a);
}

void fragment() {
	COLOR = transition(UV);
}
