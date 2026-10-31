shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int axis = 0;
uniform float colour_split : hint_range(0.0, 0.2) = 0.04;
uniform int timing = 0;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, timing == 1 ? 3 : (timing == 2 ? 1 : 0));
	float k = max(1.0 - e, 0.0001);
	vec2 s = uv;
	vec2 d = vec2(0.0);
	if (axis == 0) {
		s.y = 0.5 + (uv.y - 0.5) / k;
		d = vec2(0.0, colour_split * e);
	} else {
		s.x = 0.5 + (uv.x - 0.5) / k;
		d = vec2(colour_split * e, 0.0);
	}
	if (!tr_inside(s)) {
		return texture(to_tex, uv);
	}
	vec4 g = texture(from_tex, s);
	if (colour_split * e < 0.000001) {
		return g;
	}
	vec4 r = from_clamped(s + d);
	vec4 b = from_clamped(s - d);
	float a = max(g.a, max(r.a, b.a));
	return vec4(min(r.r, a), g.g, min(b.b, a), a);
}

void fragment() {
	COLOR = transition(UV);
}
