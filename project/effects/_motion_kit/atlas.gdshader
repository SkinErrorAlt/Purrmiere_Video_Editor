shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform bool camera = true;

const int TX = 6;
const int TY = 4;

float luma_at(int age, vec2 uv) {
	return kit_luma(history_frame(age, clamp(uv, vec2(0.0), vec2(1.0)), vec4(0.0)).rgb);
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	vec2 tuv = UV * vec2(float(TX), float(TY));
	ivec2 t = ivec2(floor(tuv));
	vec2 luv = fract(tuv);
	int k = t.y * TX + t.x + 1;
	float range = 64.0 * ps;
	if (k + 1 > history_count) {
		COLOR = vec4(0.5, 0.5, 0.0, 1.0);
	} else {
		vec2 osz = 1.0 / max(fwidth(UV), vec2(1e-6));
		float bs = full.x / (osz.x / float(TX));
		vec2 c = luv * full;
		float ref[16];
		float mean = 0.0;
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				vec2 o = (vec2(float(i), float(j)) - 1.5) * bs * 0.18;
				float l = luma_at(k, (c + o) / full);
				ref[j * 4 + i] = l;
				mean += l;
			}
		}
		mean /= 16.0;
		float var = 0.0;
		for (int i = 0; i < 16; i++) {
			var += abs(ref[i] - mean);
		}
		var /= 16.0;
		vec2 g = camera ? -kit_global(global_tex, luv) : vec2(0.0);
		float best = 1e9;
		vec2 bd = vec2(0.0);
		for (int cand = 0; cand < 2; cand++) {
			vec2 d = cand == 0 ? vec2(0.0) : g;
			float s = 0.0;
			for (int j = 0; j < 4; j++) {
				for (int i = 0; i < 4; i++) {
					vec2 o = (vec2(float(i), float(j)) - 1.5) * bs * 0.18;
					s += abs(luma_at(k + 1, (c + o + d) / full) - ref[j * 4 + i]);
				}
			}
			s /= 16.0;
			if (cand == 1) {
				s -= 0.002;
			}
			if (s < best) {
				best = s;
				bd = d;
			}
		}
		float still_cost = best;
		float step_px = 16.0 * ps;
		for (int level = 0; level < 5; level++) {
			vec2 base = bd;
			for (int sy = -1; sy <= 1; sy++) {
				for (int sx = -1; sx <= 1; sx++) {
					if (sx == 0 && sy == 0) {
						continue;
					}
					vec2 d = base + vec2(float(sx), float(sy)) * step_px;
					float s = 0.0;
					for (int j = 0; j < 4; j++) {
						for (int i = 0; i < 4; i++) {
							vec2 o = (vec2(float(i), float(j)) - 1.5) * bs * 0.18;
							s += abs(luma_at(k + 1, (c + o + d) / full) - ref[j * 4 + i]);
						}
					}
					s = s / 16.0 + 0.0004 * length(d) / ps;
					if (s < best) {
						best = s;
						bd = d;
					}
				}
			}
			step_px *= 0.5;
		}
		vec2 v = -bd - (camera ? -g : vec2(0.0));
		float moved = smoothstep(0.012, 0.04, still_cost - best) * smoothstep(0.01, 0.03, var);
		moved *= smoothstep(0.6 * ps, 1.6 * ps, length(v));
		vec2 enc = clamp(0.5 + v / (2.0 * range), vec2(0.0), vec2(1.0));
		COLOR = vec4(enc, moved, 1.0);
	}
}
