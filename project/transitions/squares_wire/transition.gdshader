shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns : hint_range(2, 60) = 10;
uniform int rows : hint_range(2, 60) = 10;
uniform float angle : hint_range(-180.0, 180.0) = 27.0;
uniform float smoothness : hint_range(0.0, 3.0) = 1.6;

vec4 transition(vec2 uv) {
	vec2 dir = vec2(cos(radians(angle)), sin(radians(angle)));
	float lo = min(dir.x, 0.0) + min(dir.y, 0.0);
	float hi = max(dir.x, 0.0) + max(dir.y, 0.0);
	float v = (dot(uv, dir) - lo) / max(hi - lo, 0.0001);
	float s = max(smoothness, 0.0001);
	float local = 1.0 - smoothstep(-s, 0.0, v - progress * (1.0 + s));
	vec2 dims = vec2(float(max(columns, 1)), float(max(rows, 1)));
	vec2 grid = uv * dims;
	vec2 f = grid - min(floor(grid), dims - 1.0);
	vec2 cpx = max(frame_px / dims, vec2(1.0));
	vec2 hh = local * (0.5 + 1.0 / cpx);
	vec2 cov = clamp((hh - abs(f - 0.5)) * cpx, 0.0, 1.0);
	return mix(from_at(uv), to_at(uv), cov.x * cov.y);
}

void fragment() {
	COLOR = transition(UV);
}
