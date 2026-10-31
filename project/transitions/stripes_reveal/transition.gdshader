shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int stripes = 8;
uniform int orientation = 0;
uniform int order = 0;
uniform float stagger : hint_range(0.0, 0.95) = 0.6;
uniform float softness : hint_range(0.0, 60.0) = 1.5;
uniform int curve = 1;

vec4 transition(vec2 uv) {
	float n = float(max(stripes, 1));
	float x = orientation == 0 ? uv.x : uv.y;
	float x_px = orientation == 0 ? frame_px.x : frame_px.y;
	float q = x * n;
	float id = floor(q);
	float g = fract(q) - 0.5;
	float pos = n > 1.0 ? id / (n - 1.0) : 0.0;
	float o = pos;
	if (order == 1) {
		o = 1.0 - pos;
	} else if (order == 2) {
		o = abs(pos - 0.5) * 2.0;
	} else if (order == 3) {
		o = 1.0 - abs(pos - 0.5) * 2.0;
	} else if (order == 4) {
		o = tr_hash(vec2(id + 0.5, 7.0));
	}
	float st = clamp(stagger, 0.0, 0.95);
	float lp = clamp((progress - clamp(o, 0.0, 1.0) * st) / (1.0 - st), 0.0, 1.0);
	lp = tr_ease(lp, curve == 1 ? 3 : 0);
	float stripe_px = max(x_px / n, 1.0);
	float s = max(softness * px_scale, 1.0) / stripe_px;
	float r = lp * (0.5 + s + 0.002);
	float k = 1.0 - smoothstep(r - s, r, abs(g));
	return mix(from_at(uv), to_at(uv), k);
}

void fragment() {
	COLOR = transition(UV);
}
