shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform int teeth : hint_range(2, 60) = 12;
uniform int style = 0;
uniform int curve = 1;

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve == 1 ? 3 : 0);
	float n = float(max(teeth, 1));
	float across = orientation == 0 ? uv.y : uv.x;
	float along = orientation == 0 ? uv.x : uv.y;
	float len = orientation == 0 ? frame_px.x : frame_px.y;
	float idx = min(floor(across * n), n - 1.0);
	bool forward = mod(idx, 2.0) < 0.5;
	float pos = forward ? along : 1.0 - along;
	float cov = clamp((e - pos) * len + 0.5, 0.0, 1.0);
	float to_pos = pos + 1.0 - e;
	float from_pos = style == 1 ? pos - e : pos;
	float ta = forward ? to_pos : 1.0 - to_pos;
	float fa = forward ? from_pos : 1.0 - from_pos;
	vec2 tuv = orientation == 0 ? vec2(ta, uv.y) : vec2(uv.x, ta);
	vec2 fuv = orientation == 0 ? vec2(fa, uv.y) : vec2(uv.x, fa);
	return mix(from_clamped(fuv), to_clamped(tuv), cov);
}

void fragment() {
	COLOR = transition(UV);
}
