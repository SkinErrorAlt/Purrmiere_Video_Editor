shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int timing = 1;
uniform float max_blur : hint_range(4.0, 90.0) = 34.0;

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
	float ba = e * max_blur;
	float bb = (1.0 - e) * max_blur;
	vec4 a = from_blur(uv, ba);
	vec4 b = to_blur(uv, bb);
	float m = smoothstep(0.35, 0.65, e);
	return mix(a, b, m);
}

void fragment() {
	COLOR = transition(UV);
}
