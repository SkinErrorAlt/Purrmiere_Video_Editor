shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float start_size : hint_range(0.0, 1.0) = 0.3;
uniform float grow : hint_range(0.0, 3.0) = 0.6;
uniform int timing = 1;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

int curve_of(int t) {
	if (t == 1) {
		return 2;
	} else if (t == 2) {
		return 3;
	} else if (t == 3) {
		return 5;
	}
	return 0;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, curve_of(timing));
	float size_to = max(mix(start_size, 1.0, e), 0.001);
	float size_from = 1.0 + grow * e;
	vec2 pt = centre + (uv - centre) / size_to;
	vec2 pf = centre + (uv - centre) / size_from;
	float o_to = smoothstep(0.0, 0.65, p);
	float o_from = 1.0 - smoothstep(0.1, 0.9, p);
	float bgw = smoothstep(0.0, 0.08, p) * smoothstep(0.0, 0.08, 1.0 - p);
	vec4 bg = vec4(background.rgb * background.a, background.a) * bgw;
	vec4 under = tr_over(from_at(pf) * o_from, bg);
	return tr_over(to_at(pt) * o_to, under);
}

void fragment() {
	COLOR = transition(UV);
}
