shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float cell_size : hint_range(20.0, 400.0) = 90.0;
uniform int order = 0;
uniform float randomness : hint_range(0.0, 1.0) = 0.35;
uniform float cell_time : hint_range(0.05, 1.0) = 0.3;
uniform float softness : hint_range(0.0, 60.0) = 1.5;
uniform float lines : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int curve = 1;

float hex_gauge(vec2 g) {
	g = abs(g);
	return max(g.x, dot(g, vec2(0.5, 0.8660254)));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve == 1 ? 3 : 0);
	float cell_px = max(cell_size * px_scale, 4.0);
	vec2 q = uv * frame_px / cell_px;
	vec2 rr = vec2(1.0, 1.7320508);
	vec2 hh = rr * 0.5;
	vec2 a = mod(q, rr) - hh;
	vec2 b = mod(q - hh, rr) - hh;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = q - gv;
	vec2 cuv = id * cell_px / frame_px;
	float rnd = tr_hash(floor(id * 2.0 + 0.5));
	float o = cuv.x;
	if (order == 1) {
		o = 1.0 - cuv.x;
	} else if (order == 2) {
		o = cuv.y;
	} else if (order == 3) {
		o = 1.0 - cuv.y;
	} else if (order == 4) {
		o = length(tr_world(cuv)) / (0.5 * sqrt(tr_ratio() * tr_ratio() + 1.0));
	} else if (order == 5) {
		o = rnd;
	}
	o = mix(clamp(o, 0.0, 1.0), rnd, order == 5 ? 1.0 : clamp(randomness, 0.0, 1.0));
	float win = clamp(cell_time, 0.05, 1.0);
	float lp = clamp((e - o * (1.0 - win)) / win, 0.0, 1.0);
	lp = lp * lp * (3.0 - 2.0 * lp);
	float s = max(softness * px_scale, 1.0) / cell_px;
	float d = hex_gauge(gv);
	float r = lp * (0.5 + s + 0.002);
	float k = 1.0 - smoothstep(r - s, r, d);
	vec4 col = mix(from_at(uv), to_at(uv), k);
	float lw = max(1.5 * px_scale, 1.0) / cell_px;
	float outline = smoothstep(0.5 - lw - 1.0 / cell_px, 0.5 - lw, d) * clamp(lines, 0.0, 1.0) * line_colour.a * 4.0 * progress * (1.0 - progress);
	return tr_over(vec4(line_colour.rgb, 1.0) * outline, col);
}

void fragment() {
	COLOR = transition(UV);
}
