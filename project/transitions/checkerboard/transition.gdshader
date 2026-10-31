shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int columns : hint_range(2, 40) = 8;
uniform float sweep : hint_range(0.0, 4.0) = 1.5;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float cols = float(max(columns, 1));
	float rows = max(1.0, floor(cols / tr_ratio() + 0.5));
	vec2 dims = vec2(cols, rows);
	vec2 grid = uv * dims;
	vec2 cell = min(floor(grid), dims - 1.0);
	vec2 f = grid - cell;
	bool vertical = direction == 2 || direction == 3;
	bool reverse = direction == 1 || direction == 3;
	float along_cell = vertical ? cell.y : cell.x;
	float along_count = vertical ? rows : cols;
	float local_f = vertical ? f.y : f.x;
	if (reverse) {
		along_cell = along_count - 1.0 - along_cell;
		local_f = 1.0 - local_f;
	}
	float parity = mod(cell.x + cell.y, 2.0);
	float k = along_count > 1.0 ? along_cell / (along_count - 1.0) : 0.0;
	float sw = max(sweep, 0.0);
	float local = clamp(p * (sw + 1.5) - sw * k - parity * 0.5, 0.0, 1.0);
	float cell_px = vertical ? frame_px.y / rows : frame_px.x / cols;
	float a = 1.0 / max(cell_px, 1.0);
	float e = local * (1.0 + a);
	float m = clamp((e - local_f) / a, 0.0, 1.0);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
