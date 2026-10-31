shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform int motion = 0;
uniform float border_width : hint_range(0.0, 100.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0);
uniform float softness : hint_range(0.0, 50.0) = 0.0;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float len = orientation == 0 ? frame_px.x : frame_px.y;
	float c = orientation == 0 ? uv.x : uv.y;
	float v = abs(c - 0.5) * 2.0;
	if (motion == 1) {
		v = 1.0 - v;
	}
	float unit = 2.0 / len;
	float s = max(softness * px_scale, 1.0) * unit;
	float b = border_width * px_scale * unit;
	float e = mix(-b, 1.0 + s, p);
	float c_to = 1.0 - smoothstep(e - s, e, v);
	float c_all = max(1.0 - smoothstep(e + b - s, e + b, v), c_to);
	vec4 bc = vec4(border_colour.rgb * border_colour.a, border_colour.a);
	return from_at(uv) * (1.0 - c_all) + bc * (c_all - c_to) + to_at(uv) * c_to;
}

void fragment() {
	COLOR = transition(UV);
}
