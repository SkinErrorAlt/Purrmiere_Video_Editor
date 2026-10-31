shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float brightening : hint_range(0.0, 1.0) = 1.0;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float k = 1.0 + brightening;
	float wf = clamp((1.0 - p) * k, 0.0, 1.0);
	float wt = clamp(p * k, 0.0, 1.0);
	vec4 c = from_at(uv) * wf + to_at(uv) * wt;
	float a = clamp(c.a, 0.0, 1.0);
	return vec4(min(c.rgb, vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
