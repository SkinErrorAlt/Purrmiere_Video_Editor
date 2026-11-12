shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns : hint_range(2, 32) = 10;
uniform int rows : hint_range(1, 16) = 5;
uniform int flaps : hint_range(1, 12) = 5;
uniform float stagger : hint_range(0.0, 0.85) = 0.5;
uniform float seam : hint_range(0.0, 1.0) = 0.6;
uniform float shadow : hint_range(0.0, 1.0) = 0.7;

vec4 tile_pick(vec2 uv, float k, float n) {
	if (k <= 0.5) {
		return from_at(uv);
	}
	if (k >= n - 0.5) {
		return to_at(uv);
	}
	float f = k / max(n, 1.0);
	vec4 mixed = mix(from_at(uv), to_at(uv), f);
	float flick = fract(sin(k * 12.9898) * 43758.5453);
	mixed.rgb *= 0.8 + 0.3 * flick;
	return mixed;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float nx = float(max(columns, 2));
	float ny = float(max(rows, 1));
	vec2 cell = floor(vec2(uv.x * nx, uv.y * ny));
	vec2 within = fract(vec2(uv.x * nx, uv.y * ny));
	float sg = clamp(stagger, 0.0, 0.85);
	float order = (cell.x / max(nx - 1.0, 1.0)) * 0.75 + tr_hash(cell + 6.6) * 0.25;
	float t = clamp((p - order * sg) / max(1.0 - sg, 0.05), 0.0, 1.0);
	float nf = float(max(flaps, 1));
	float pos = t * nf;
	float step_i = min(floor(pos), nf);
	float frac = pos - step_i;
	float next_i = min(step_i + 1.0, nf);
	vec4 col;
	if (within.y >= 0.5) {
		float which = frac < 0.5 ? step_i : next_i;
		col = tile_pick(uv, which, nf);
		float sh = (1.0 - smoothstep(0.0, 0.5, within.y - 0.5)) * (1.0 - abs(frac * 2.0 - 1.0)) * shadow * 0.6;
		col.rgb *= 1.0 - sh;
	} else {
		float fold = frac < 0.5 ? 1.0 - frac * 2.0 : (frac - 0.5) * 2.0;
		float half_h = 0.5 * fold;
		if (within.y > 0.5 - half_h) {
			float sy = (within.y - (0.5 - half_h)) / max(half_h, 0.0001) * 0.5;
			vec2 suv = vec2(uv.x, (cell.y + sy) / ny);
			float which = frac < 0.5 ? step_i : next_i;
			col = tile_pick(suv, which, nf);
			col.rgb *= mix(0.5, 1.0, fold);
		} else {
			col = tile_pick(uv, next_i, nf);
			col.rgb *= mix(0.55, 1.0, smoothstep(0.0, 0.25, 0.5 - half_h - within.y));
		}
	}
	float working = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.93, 1.0, p));
	float seam_line = smoothstep(0.035, 0.0, abs(within.y - 0.5)) * seam * working;
	col.rgb *= 1.0 - seam_line * 0.8;
	float gap = (1.0 - smoothstep(0.0, 0.03, within.x)) + (1.0 - smoothstep(0.0, 0.03, 1.0 - within.x));
	col.rgb *= 1.0 - clamp(gap, 0.0, 1.0) * seam * 0.35 * working;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
