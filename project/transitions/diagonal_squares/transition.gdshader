shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int corner = 0;
uniform int columns : hint_range(2, 64) = 16;
uniform int style = 0;
uniform float square_time : hint_range(0.01, 1.0) = 0.1;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float cols = float(max(columns, 1));
	float rows = max(1.0, floor(cols / tr_ratio() + 0.5));
	vec2 dims = vec2(cols, rows);
	vec2 grid = uv * dims;
	vec2 cell = min(floor(grid), dims - 1.0);
	vec2 f = grid - cell;
	vec2 oc = cell;
	if (corner == 1 || corner == 3) {
		oc.x = cols - 1.0 - cell.x;
	}
	if (corner == 2 || corner == 3) {
		oc.y = rows - 1.0 - cell.y;
	}
	float k = (oc.x + oc.y) / max(cols + rows - 2.0, 1.0);
	float w = clamp(square_time, 0.01, 1.0);
	float local = clamp((p - k * (1.0 - w)) / w, 0.0, 1.0);
	float m = local;
	if (style == 1) {
		vec2 cpx = max(frame_px / dims, vec2(1.0));
		vec2 hh = local * (0.5 + 1.0 / cpx);
		vec2 cov = clamp((hh - abs(f - 0.5)) * cpx, 0.0, 1.0);
		m = cov.x * cov.y;
	}
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
