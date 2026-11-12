shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

const int FOODS = 24;
const int STEPS = 64;
const float T_RANGE = 120.0;

float ts_at(sampler2D tex, vec2 uv) {
	return sim_field(tex, uv);
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = ivec2(UV * vec2(sz));
	int s = me.x;
	int i = me.y;
	if (i >= FOODS || s >= STEPS) {
		COLOR = vec4(1.0);
	} else {
		int rx = i % 6;
		int ry = i / 6;
		ivec2 lo = ivec2(sz.x * rx / 6, sz.y * ry / 4);
		ivec2 hi = ivec2(sz.x * (rx + 1) / 6, sz.y * (ry + 1) / 4);
		float best = 0.3;
		ivec2 at = ivec2(-1);
		for (int y = lo.y; y < hi.y; y++) {
			for (int x = lo.x; x < hi.x; x++) {
				vec4 c = texelFetch(TEXTURE, ivec2(x, y), 0);
				float score = c.a * (1.0 + 0.05 * sim_hash(vec2(float(x), float(y))));
				if (score > best && sim_unpack(c.rg) < 0.9) {
					best = score;
					at = ivec2(x, y);
				}
			}
		}
		if (at.x < 0) {
			COLOR = vec4(1.0);
		} else {
			vec2 px = 1.0 / vec2(sz);
			vec2 p = (vec2(at) + 0.5) * px;
			float stride = 1.25;
			for (int k = 0; k < STEPS; k++) {
				if (k >= s) {
					break;
				}
				float tx = ts_at(TEXTURE, p + vec2(px.x, 0.0)) - ts_at(TEXTURE, p - vec2(px.x, 0.0));
				float ty = ts_at(TEXTURE, p + vec2(0.0, px.y)) - ts_at(TEXTURE, p - vec2(0.0, px.y));
				vec2 g = vec2(tx, ty);
				float gl = length(g);
				if (gl < 1e-7 || ts_at(TEXTURE, p) < 0.0002) {
					break;
				}
				p -= g / gl * px * stride;
				p = clamp(p, px, 1.0 - px);
			}
			COLOR = vec4(sim_pack(p.x), sim_pack(p.y));
		}
	}
}
