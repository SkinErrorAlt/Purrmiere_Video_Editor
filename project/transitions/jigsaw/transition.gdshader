shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int across : hint_range(2, 14) = 6;
uniform int down : hint_range(2, 10) = 4;
uniform float tab : hint_range(0.05, 0.35) = 0.19;
uniform int seed_no : hint_range(0, 999) = 7;
uniform float variety : hint_range(0.0, 1.0) = 0.7;
uniform float travel : hint_range(0.0, 0.25) = 0.12;
uniform float overlap : hint_range(0.05, 0.9) = 0.3;
uniform float relief : hint_range(0.0, 1.0) = 0.7;

float jg_edge(vec2 a, vec2 b, float k) {
	vec2 m = (a + b) * 0.5 + vec2(float(seed_no) * 1.37, float(seed_no) * 0.61);
	return tr_hash(m + vec2(k, k * 2.3) + 31.7);
}

float jg_tab(vec2 d, float r, float sq) {
	float c = length(d) - r;
	vec2 e = abs(d) - vec2(r * 0.72);
	float b = min(max(e.x, e.y), 0.0) + length(max(e, vec2(0.0))) - r * 0.28;
	return mix(c, b, sq);
}

float piece_sdf(vec2 q, vec2 cell, vec2 half_size) {
	vec2 d = abs(q) - half_size;
	float rect = min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0)));
	float base_r = min(half_size.x, half_size.y) * tab * 2.2;
	float nx = float(max(across, 2));
	float ny = float(max(down, 2));
	float vy = clamp(variety, 0.0, 1.0);
	vec2 mids[4] = {vec2(0.0, -half_size.y), vec2(half_size.x, 0.0), vec2(0.0, half_size.y), vec2(-half_size.x, 0.0)};
	vec2 steps[4] = {vec2(0.0, -1.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(-1.0, 0.0)};
	float own[4] = {-1.0, 1.0, 1.0, -1.0};
	for (int i = 0; i < 4; i++) {
		vec2 nbr = cell + steps[i];
		if (nbr.x < 0.0 || nbr.y < 0.0 || nbr.x > nx - 1.0 || nbr.y > ny - 1.0) {
			continue;
		}
		vec2 away = normalize(mids[i]);
		vec2 along = vec2(abs(away.y), abs(away.x));
		float s = (jg_edge(cell, nbr, 0.0) < 0.5 ? -1.0 : 1.0) * own[i];
		float r = base_r * mix(1.0, mix(0.68, 1.3, jg_edge(cell, nbr, 1.0)), vy);
		float neck = mix(0.55, mix(0.34, 0.78, jg_edge(cell, nbr, 2.0)), vy);
		float slide = mix(0.0, (jg_edge(cell, nbr, 3.0) - 0.5) * 1.1, vy);
		float sq = mix(0.0, jg_edge(cell, nbr, 4.0), vy) * 0.85;
		vec2 bump = mids[i] + away * r * neck * s + along * slide * r;
		float shape = jg_tab(q - bump, r, sq);
		if (s > 0.0) {
			rect = min(rect, shape);
		} else {
			rect = max(rect, -shape);
		}
	}
	return rect;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float nx = float(max(across, 2));
	float ny = float(max(down, 2));
	vec2 step_uv = vec2(1.0 / nx, 1.0 / ny);
	vec2 half_size = step_uv * 0.5;
	vec2 base = floor(vec2(uv.x * nx, uv.y * ny));
	vec4 under = from_at(uv);
	vec4 best = under;
	float best_score = -1.0;
	float cover = 0.0;
	float shadow = 0.0;
	float span = clamp(overlap, 0.05, 0.9);
	float relief_now = relief * (1.0 - smoothstep(0.9, 1.0, p));
	float bias = 0.9 / max(frame_px.y, 1.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (cell.x < 0.0 || cell.y < 0.0 || cell.x > nx - 1.0 || cell.y > ny - 1.0) {
				continue;
			}
			float key = tr_hash(cell + vec2(float(seed_no) * 2.11, 17.3));
			float t = clamp((p - key * (1.0 - span)) / span, 0.0, 1.0);
			if (t <= 0.0) {
				continue;
			}
			float ease = 1.0 - pow(1.0 - t, 3.0);
			vec2 dir = normalize(tr_hash2(cell + vec2(float(seed_no) * 3.07, 5.1)) - 0.5 + vec2(0.001, 0.002));
			vec2 off = dir * travel * (1.0 - ease);
			float grow = 1.0 + 0.1 * (1.0 - ease);
			vec2 centre = (cell + 0.5) * step_uv + off;
			vec2 q = (uv - centre) / grow;
			float sd = piece_sdf(q, cell, half_size) - bias;
			float soft = 1.1 / max(frame_px.y, 1.0);
			float ins = 1.0 - smoothstep(-soft, soft, sd);
			cover += ins;
			float score = ins * 2.0 + key;
			if (ins > 0.0 && score > best_score) {
				vec2 suv = clamp(q + (cell + 0.5) * step_uv, vec2(0.0), vec2(1.0));
				vec4 face = to_clamped(suv);
				float lip = clamp(-sd / max(half_size.y * 0.3, 0.0001), 0.0, 1.0);
				float light = mix(1.25, 1.0, smoothstep(0.0, 0.5, lip));
				float dark = mix(0.7, 1.0, smoothstep(0.0, 0.22, lip));
				face.rgb *= mix(1.0, light * dark, relief_now);
				face.rgb *= mix(0.72, 1.0, ease);
				best = face;
				best_score = score;
			}
			float sh = 1.0 - smoothstep(0.0, half_size.y * 0.35, sd);
			shadow = max(shadow, sh * (1.0 - ease) * relief * 0.8);
		}
	}
	cover = clamp(cover, 0.0, 1.0);
	vec4 bed = under;
	bed.rgb *= 1.0 - shadow * 0.5;
	return mix(bed, best, cover);
}

void fragment() {
	COLOR = transition(UV);
}
