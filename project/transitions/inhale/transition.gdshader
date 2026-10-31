shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float pinch : hint_range(0.0, 1.0) = 0.6;
uniform float twist : hint_range(-360.0, 360.0) = 120.0;
uniform int timing = 2;
uniform float settle : hint_range(0.0, 0.3) = 0.06;

int curve_of(int t) {
	if (t == 1) {
		return 3;
	} else if (t == 2) {
		return 1;
	}
	return 0;
}

float far_corner(vec2 c) {
	vec2 a = tr_world(vec2(0.0, 0.0)) - c;
	vec2 b = tr_world(vec2(1.0, 0.0)) - c;
	vec2 d = tr_world(vec2(0.0, 1.0)) - c;
	vec2 f = tr_world(vec2(1.0, 1.0)) - c;
	return max(max(length(a), length(b)), max(length(d), length(f)));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, curve_of(timing));
	vec2 c = tr_world(centre);
	vec2 w = tr_world(uv) - c;
	vec2 tuv = tr_frame_uv(c + w / (1.0 + settle * (1.0 - e)));
	vec4 under = to_clamped(tuv);
	float k = 1.0 - e;
	if (k <= 0.0001) {
		return under;
	}
	float big = far_corner(c);
	float r = length(w);
	float rn = r / (big * k);
	if (rn >= 1.0) {
		return under;
	}
	float gamma = 1.0 / (1.0 + pinch * 3.0 * e);
	float rs = pow(rn, gamma) * big;
	float a = radians(twist) * e * (1.0 - rn) * (1.0 - rn);
	vec2 dir = r > 0.000001 ? w / r : vec2(0.0);
	vec2 src = c + tr_rotate(dir, a) * rs;
	vec2 suv = tr_frame_uv(src);
	if (tr_inside(suv)) {
		return texture(from_tex, suv);
	}
	return under;
}

void fragment() {
	COLOR = transition(UV);
}
