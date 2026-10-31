shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int dots = 20;
uniform vec2 origin = vec2(0.0, 1.0);
uniform float spread : hint_range(0.0, 0.95) = 0.6;
uniform float softness : hint_range(0.0, 60.0) = 1.5;
uniform int curve = 0;

float far_corner(vec2 o) {
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float m = max(length(h - o), length(vec2(-h.x, h.y) - o));
	return max(m, max(length(vec2(h.x, -h.y) - o), length(-h - o)));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve == 1 ? 3 : 0);
	float n = float(max(dots, 1));
	float ratio = tr_ratio();
	vec2 q = vec2(uv.x * n, uv.y * n / ratio);
	vec2 id = floor(q);
	vec2 gv = fract(q) - 0.5;
	vec2 cell_uv = vec2((id.x + 0.5) / n, (id.y + 0.5) * ratio / n);
	vec2 o = tr_world(origin);
	float lead = clamp(length(tr_world(cell_uv) - o) / max(far_corner(o), 0.0001), 0.0, 1.0);
	float sp = clamp(spread, 0.0, 0.95);
	float lp = clamp((e - sp * lead) / (1.0 - sp), 0.0, 1.0);
	float cell_px = max(frame_px.x / n, 1.0);
	float s = max(softness * px_scale, 1.0) / cell_px;
	float r = lp * (0.7072 + s);
	float k = 1.0 - smoothstep(r - s, r, length(gv));
	return mix(from_at(uv), to_at(uv), k);
}

void fragment() {
	COLOR = transition(UV);
}
