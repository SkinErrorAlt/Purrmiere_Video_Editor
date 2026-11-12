shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float cells : hint_range(3.0, 40.0) = 11.0;
uniform int order : hint_range(0, 3) = 0;
uniform float pop : hint_range(0.0, 0.5) = 0.12;
uniform float seam : hint_range(0.0, 1.0) = 0.4;
uniform float wander : hint_range(0.0, 1.0) = 0.85;
uniform float overlap : hint_range(0.02, 0.9) = 0.22;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float ar = tr_ratio();
	float n = max(cells, 3.0);
	vec2 pos = vec2(uv.x * ar, uv.y) * (n / ar);
	vec2 base = floor(pos);
	float best = 100.0;
	float second = 100.0;
	vec2 best_cell = base;
	vec2 best_site = pos;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			vec2 jit = tr_hash2(cell + 3.7);
			vec2 site = cell + 0.5 + (jit - 0.5) * clamp(wander, 0.0, 1.0);
			float d = length(pos - site);
			if (d < best) {
				second = best;
				best = d;
				best_cell = cell;
				best_site = site;
			} else if (d < second) {
				second = d;
			}
		}
	}
	vec2 site_uv = vec2(best_site.x / (n / ar) / ar, best_site.y / (n / ar));
	float key = 0.0;
	if (order == 0) {
		key = clamp(length((site_uv - vec2(0.5)) * vec2(ar, 1.0)) / (0.5 * length(vec2(ar, 1.0))), 0.0, 1.0);
	} else if (order == 1) {
		key = 1.0 - clamp(length((site_uv - vec2(0.5)) * vec2(ar, 1.0)) / (0.5 * length(vec2(ar, 1.0))), 0.0, 1.0);
	} else if (order == 2) {
		key = tr_hash(best_cell + 21.5);
	} else {
		key = clamp(site_uv.x, 0.0, 1.0);
	}
	key = mix(key, tr_hash(best_cell + 8.1), 0.12);
	float span = clamp(overlap, 0.02, 0.9);
	float t = clamp((p - key * (1.0 - span)) / span, 0.0, 1.0);
	float m = smoothstep(0.0, 1.0, t);
	float punch = sin(clamp(t, 0.0, 1.0) * TR_PI) * pop;
	vec2 suv = site_uv + (uv - site_uv) * (1.0 - punch);
	vec4 col = mix(from_clamped(uv), to_clamped(suv), m);
	float edge = clamp((second - best) * n * 0.5, 0.0, 1.0);
	float line_light = (1.0 - smoothstep(0.0, 0.14, edge)) * seam * (1.0 - smoothstep(0.88, 1.0, p)) * smoothstep(0.0, 0.25, p);
	col.rgb += vec3(line_light * 0.9, line_light * 0.95, line_light);
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
