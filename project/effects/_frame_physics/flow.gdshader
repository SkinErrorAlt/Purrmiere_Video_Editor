shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	ivec2 ts = fp_tile_size(textureSize(atlas_tex, 0));
	ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
	ivec2 tile = p / fs;
	int a = tile.y * FP_GRID + tile.x;
	int pairs = fp_pairs(TEXTURE);
	if (tile.x >= FP_GRID || a >= pairs) {
		COLOR = fp_flow_pack(vec2(0.0), 0.0, 0.0);
	} else if (!fp_tile_ok(atlas_tex, a, ts) || !fp_tile_ok(atlas_tex, a + 1, ts)) {
		COLOR = fp_flow_pack(vec2(0.0), 0.0, 0.0);
	} else {
		ivec2 l = p - tile * fs;
		vec2 c = (vec2(l) + 0.5) * vec2(ts) / vec2(fs);
		vec2 g = fp_motion(TEXTURE, a) * vec2(ts);
		vec2 u = vec2(0.0);
		float energy = 0.0;
		float trust = 1.0;
		for (int it = 0; it < 3; it++) {
			float sxx = 0.0;
			float sxy = 0.0;
			float syy = 0.0;
			float sxt = 0.0;
			float syt = 0.0;
			float e = 0.0;
			for (int j = 0; j < 4; j++) {
				for (int i = 0; i < 4; i++) {
					vec2 q = c + (vec2(float(i), float(j)) - 1.5) * 1.25;
					vec2 qo = q - g - u;
					float i0 = fp_luma_bl(atlas_tex, a, q, ts);
					float i1 = fp_luma_bl(atlas_tex, a + 1, qo, ts);
					float ix = 0.5 * (fp_luma_bl(atlas_tex, a + 1, qo + vec2(1.0, 0.0), ts) - fp_luma_bl(atlas_tex, a + 1, qo - vec2(1.0, 0.0), ts));
					float iy = 0.5 * (fp_luma_bl(atlas_tex, a + 1, qo + vec2(0.0, 1.0), ts) - fp_luma_bl(atlas_tex, a + 1, qo - vec2(0.0, 1.0), ts));
					float itd = i0 - i1;
					sxx += ix * ix;
					sxy += ix * iy;
					syy += iy * iy;
					sxt += ix * itd;
					syt += iy * itd;
					e += abs(itd);
				}
			}
			if (it == 0) {
				energy = e / 16.0;
				float tr = 0.5 * (sxx + syy);
				float lmin = tr - sqrt(max(tr * tr - (sxx * syy - sxy * sxy), 0.0));
				trust = smoothstep(0.00003, 0.0002, lmin);
			}
			float lam = 0.0004;
			sxx += lam;
			syy += lam;
			float det = sxx * syy - sxy * sxy;
			vec2 du = vec2(syy * -sxt + sxy * syt, sxy * sxt - sxx * syt) / max(det, 1e-9);
			u += du;
			u = clamp(u, vec2(-3.0), vec2(3.0));
		}
		if (energy < 0.004) {
			u = vec2(0.0);
			trust = 1.0;
		}
		u *= trust * smoothstep(0.008, 0.025, energy);
		vec2 v = u / vec2(ts);
		COLOR = fp_flow_pack(v, clamp(energy * 6.0, 0.0, 1.0), trust);
	}
}
