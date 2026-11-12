shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform sampler2D prof_tex : filter_nearest, repeat_disable;

float cost_at(sampler2D m, int a, bool cols, int s) {
	float r = fp_unpack(texelFetch(m, ivec2(s + FP_SMAX, a * 2 + (cols ? 0 : 1)), 0).rg);
	return r * r;
}

float prof_lin(sampler2D pt, int age, float q, bool cols, int n) {
	int i = clamp(int(floor(q)), 0, n - 2);
	return mix(fp_prof(pt, age, i, cols), fp_prof(pt, age, i + 1, cols), clamp(q - float(i), 0.0, 1.0));
}

float shift_of(sampler2D m, sampler2D pt, int a, bool cols, int n) {
	int smax = clamp(int(ceil(float(n) * 0.16)), 1, FP_SMAX);
	float best = 1e9;
	int bs = 0;
	for (int s = -FP_SMAX; s <= FP_SMAX; s++) {
		if (abs(s) > smax) {
			continue;
		}
		float c = cost_at(m, a, cols, s);
		if (c < best) {
			best = c;
			bs = s;
		}
	}
	float off = 0.0;
	if (abs(bs) < smax) {
		float cm = cost_at(m, a, cols, bs - 1);
		float cp = cost_at(m, a, cols, bs + 1);
		float den = cm - 2.0 * best + cp;
		if (den > 1e-12) {
			off = clamp(0.5 * (cm - cp) / den, -0.5, 0.5);
		}
	}
	float s = float(bs) + off;
	for (int it = 0; it < 4; it++) {
		int lo = int(ceil(max(0.0, s))) + 2;
		int hi = int(floor(min(float(n), float(n) + s))) - 3;
		float ma = 0.0;
		float mb = 0.0;
		float gm = 0.0;
		float cnt = 0.0;
		for (int b = 0; b < FP_NX; b++) {
			if (b < lo || b > hi) {
				continue;
			}
			float q = float(b) - s;
			ma += fp_prof(pt, a, b, cols);
			mb += prof_lin(pt, a + 1, q, cols, n);
			gm += -(prof_lin(pt, a + 1, q + 0.5, cols, n) - prof_lin(pt, a + 1, q - 0.5, cols, n));
			cnt += 1.0;
		}
		if (cnt < 4.0) {
			break;
		}
		ma /= cnt;
		mb /= cnt;
		gm /= cnt;
		float num = 0.0;
		float den2 = 0.0;
		for (int b = 0; b < FP_NX; b++) {
			if (b < lo || b > hi) {
				continue;
			}
			float q = float(b) - s;
			float v = prof_lin(pt, a + 1, q, cols, n) - mb;
			float g = -(prof_lin(pt, a + 1, q + 0.5, cols, n) - prof_lin(pt, a + 1, q - 0.5, cols, n)) - gm;
			float r = (fp_prof(pt, a, b, cols) - ma) - v;
			num += g * r;
			den2 += g * g;
		}
		if (den2 < 1e-12) {
			break;
		}
		float st = clamp(num / den2, -0.5, 0.5);
		s += st;
		if (abs(st) < 0.002) {
			break;
		}
	}
	return clamp(s, float(-smax), float(smax));
}

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	int pairs = min(history_count, FP_MAX_PAIRS);
	if (p.y == 1 && p.x == 0) {
		COLOR = vec4(float(pairs) / 255.0, 0.0, 0.0, 1.0);
	} else if (p.y != 0 || p.x >= pairs) {
		COLOR = fp_pack2(vec2(0.0), FP_DRANGE);
	} else {
		int a = p.x;
		ivec2 ts = fp_tile_size(textureSize(atlas_tex, 0));
		if (!fp_tile_ok(atlas_tex, a, ts) || !fp_tile_ok(atlas_tex, a + 1, ts)) {
			COLOR = fp_pack2(vec2(0.0), FP_DRANGE);
		} else {
			int bx = (ts.x + FP_NX - 1) / FP_NX;
			int by = (ts.y + FP_NY - 1) / FP_NY;
			float dx = shift_of(TEXTURE, prof_tex, a, true, ts.x / bx);
			float dy = shift_of(TEXTURE, prof_tex, a, false, ts.y / by);
			COLOR = fp_pack2(vec2(dx * float(bx) / float(ts.x), dy * float(by) / float(ts.y)), FP_DRANGE);
		}
	}
}
