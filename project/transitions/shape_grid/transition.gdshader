shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int shape = 0;
uniform int cells = 10;
uniform int order = 0;
uniform float stagger : hint_range(0.0, 0.95) = 0.6;
uniform float softness : hint_range(0.0, 60.0) = 1.5;
uniform int curve = 1;

float cell_field(vec2 g) {
	vec2 u = abs(g);
	if (shape == 1) {
		return max(u.x, u.y);
	} else if (shape == 2) {
		return u.x + u.y;
	} else if (shape == 3) {
		return min(max(u.x, u.y / 0.45), max(u.x / 0.45, u.y));
	}
	return length(g);
}

float cell_reach() {
	if (shape == 1) {
		return 0.5;
	} else if (shape == 2) {
		return 1.0;
	} else if (shape == 3) {
		return 0.5 / 0.45;
	}
	return 0.70711;
}

vec4 transition(vec2 uv) {
	float n = float(max(cells, 1));
	float ratio = tr_ratio();
	float rows = ceil(n / ratio);
	vec2 q = vec2(uv.x * n, uv.y * n / ratio);
	vec2 id = floor(q);
	vec2 gv = fract(q) - 0.5;
	vec2 cuv = vec2((id.x + 0.5) / n, (id.y + 0.5) / rows);
	float o = (cuv.x + cuv.y) * 0.5;
	if (order == 1) {
		o = cuv.x;
	} else if (order == 2) {
		o = cuv.y;
	} else if (order == 3) {
		o = length(tr_world(vec2(cuv.x, (id.y + 0.5) * ratio / n))) / (0.5 * sqrt(ratio * ratio + 1.0));
	} else if (order == 4) {
		o = tr_hash(id + vec2(0.5));
	}
	float st = clamp(stagger, 0.0, 0.95);
	float lp = clamp((progress - clamp(o, 0.0, 1.0) * st) / (1.0 - st), 0.0, 1.0);
	lp = tr_ease(lp, curve == 1 ? 3 : 0);
	float cell_px = max(frame_px.x / n, 1.0);
	float s = max(softness * px_scale, 1.0) / cell_px;
	float r = lp * (cell_reach() + s + 0.002);
	float k = 1.0 - smoothstep(r - s, r, cell_field(gv));
	return mix(from_at(uv), to_at(uv), k);
}

void fragment() {
	COLOR = transition(UV);
}
