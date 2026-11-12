shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/pframe_mosh/mosh.gdshaderinc"

uniform int kind = 0;
uniform float breakthrough = 0.45;

float luma(vec4 c) {
	return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

vec4 frame_at(int k, vec2 uv, vec4 now_c) {
	return k <= 0 ? now_c : history_frame(k, uv, now_c);
}

float cost_at(int k, vec2 c, vec2 d, float bp, vec2 size, float ref[16]) {
	float s = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec2 o = (vec2(float(i), float(j)) - 1.5) * bp * 0.25;
			vec2 uv = clamp((c + o + d) / size, vec2(0.0), vec2(1.0));
			s += abs(luma(history_frame(k + 1, uv, vec4(0.0))) - ref[j * 4 + i]);
		}
	}
	return s / 16.0;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	ivec2 isz = ivec2(size);
	ivec2 tile = isz / TILES;
	ivec2 fc = ivec2(floor(FRAGCOORD.xy));
	ivec2 t = fc / max(tile, ivec2(1));
	ivec2 b = fc - t * tile;
	int k = t.y * TILES + t.x;
	int age = mosh_age();
	int need = kind == 1 ? 1 : age;
	float bp = block_px(size);
	ivec2 nb = ivec2(ceil(size / bp));
	if (t.x >= TILES || t.y >= TILES || k >= need || b.x >= nb.x || b.y >= nb.y || history_count < k + 1) {
		COLOR = vec4(0.5, 0.5, 0.0, 1.0);
	} else {
		vec2 c = (vec2(b) + 0.5) * bp;
		float ref[16];
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				vec2 o = (vec2(float(i), float(j)) - 1.5) * bp * 0.25;
				vec2 uv = clamp((c + o) / size, vec2(0.0), vec2(1.0));
				vec4 n = texture(TEXTURE, uv);
				ref[j * 4 + i] = luma(k == 0 ? n : history_frame(k, uv, n));
			}
		}
		float lambda = 0.0006 / max(px_scale, 0.05);
		float zero_cost = cost_at(k, c, vec2(0.0), bp, size, ref);
		float best = zero_cost - 0.004;
		vec2 bd = vec2(0.0);
		float step_px = 24.0 * max(px_scale, 0.05);
		for (int level = 0; level < 5; level++) {
			vec2 base = bd;
			for (int sy = -1; sy <= 1; sy++) {
				for (int sx = -1; sx <= 1; sx++) {
					if (sx == 0 && sy == 0) {
						continue;
					}
					vec2 d = base + vec2(float(sx), float(sy)) * step_px;
					float cost = cost_at(k, c, d, bp, size, ref) + lambda * length(d);
					if (cost < best) {
						best = cost;
						bd = d;
					}
				}
			}
			step_px *= 0.5;
		}
		float r = mv_range();
		vec2 enc = clamp(0.5 + bd / (2.0 * r), vec2(0.0), vec2(1.0));
		float thr = 0.6 * (1.0 - breakthrough) * (1.0 - breakthrough) + 0.02;
		float is_intra = (breakthrough > 0.0 && best > thr) ? 1.0 : 0.0;
		COLOR = vec4(enc, is_intra, 1.0);
	}
}
