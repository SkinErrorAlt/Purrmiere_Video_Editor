shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float angle : hint_range(-60.0, 60.0) = 15.0;
uniform float line_width : hint_range(0.0, 60.0) = 6.0;
uniform vec4 line_colour : source_color = vec4(1.0);
uniform float softness : hint_range(0.0, 200.0) = 0.0;
uniform int curve = 1;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec2 base = vec2(1.0, 0.0);
	if (direction == 1) {
		base = vec2(-1.0, 0.0);
	} else if (direction == 2) {
		base = vec2(0.0, -1.0);
	} else if (direction == 3) {
		base = vec2(0.0, 1.0);
	}
	vec2 n = tr_rotate(base, radians(angle));
	vec2 w = tr_world(uv);
	float r = abs(n.x) * tr_ratio() * 0.5 + abs(n.y) * 0.5;
	float v = (dot(w, n) + r) / (2.0 * r);
	float unit = 1.0 / (2.0 * r * frame_px.y);
	float s = max(softness * px_scale, 1.0) * unit;
	float b = line_width * px_scale * unit;
	float e = mix(-b, 1.0 + s, p);
	float c_to = 1.0 - smoothstep(e - s, e, v);
	float c_all = max(1.0 - smoothstep(e + b - s, e + b, v), c_to);
	vec4 lc = vec4(line_colour.rgb * line_colour.a, line_colour.a);
	return from_at(uv) * (1.0 - c_all) + lc * (c_all - c_to) + to_at(uv) * c_to;
}

void fragment() {
	COLOR = transition(UV);
}
