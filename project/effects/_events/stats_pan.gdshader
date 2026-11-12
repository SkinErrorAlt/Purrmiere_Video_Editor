shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_events/ev.gdshaderinc"

float match_cost(sampler2D t, int a, vec2 d, float ma, float mb, float sa, float sb, int stride) {
	float acc = 0.0;
	float n = 0.0;
	for (int j = 1; j < EV_NY - 1; j++) {
		for (int i = 1; i < EV_NX - 1; i++) {
			if (((i + j) % stride) != 0) {
				continue;
			}
			vec2 p = ev_point(i, j);
			vec2 q = p + d;
			if (q.x < 0.02 || q.x > 0.98 || q.y < 0.02 || q.y > 0.98) {
				continue;
			}
			float za = (ev_luma(ev_thumb(t, a, p).rgb) - ma) / sa;
			float zb = (ev_luma(ev_thumb(t, a + 1, q).rgb) - mb) / sb;
			acc += abs(za - zb);
			n += 1.0;
		}
	}
	return n >= 12.0 ? acc / n : 9.0;
}

void fragment() {
	int a = ev_age_of(UV);
	bool ok = a < 63 && ev_valid(TEXTURE, a) && ev_valid(TEXTURE, a + 1);
	float ma = 0.0;
	float mb = 0.0;
	float va = 0.0;
	float vb = 0.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			vec2 p = ev_point(i, j);
			float ya = ev_luma(ev_thumb(TEXTURE, a, p).rgb);
			float yb = ev_luma(ev_thumb(TEXTURE, a + 1, p).rgb);
			ma += ya;
			mb += yb;
			va += ya * ya;
			vb += yb * yb;
		}
	}
	ma /= 144.0;
	mb /= 144.0;
	float sa = max(sqrt(max(va / 144.0 - ma * ma, 0.0)), 0.035);
	float sb = max(sqrt(max(vb / 144.0 - mb * mb, 0.0)), 0.035);
	float c0 = match_cost(TEXTURE, a, vec2(0.0), ma, mb, sa, sb, 1);
	vec2 best = vec2(0.0);
	float bc = match_cost(TEXTURE, a, vec2(0.0), ma, mb, sa, sb, 2);
	for (int sy = -4; sy <= 4; sy++) {
		for (int sx = -7; sx <= 7; sx++) {
			vec2 d = vec2(float(sx) * 0.045, float(sy) * 0.05);
			float c = match_cost(TEXTURE, a, d, ma, mb, sa, sb, 2);
			if (c < bc - 0.01) {
				bc = c;
				best = d;
			}
		}
	}
	vec2 coarse = best;
	bc = match_cost(TEXTURE, a, coarse, ma, mb, sa, sb, 1);
	for (int sy = -1; sy <= 1; sy++) {
		for (int sx = -1; sx <= 1; sx++) {
			vec2 d = coarse + vec2(float(sx) * 0.018, float(sy) * 0.02);
			float c = match_cost(TEXTURE, a, d, ma, mb, sa, sb, 1);
			if (c < bc) {
				bc = c;
				best = d;
			}
		}
	}
	float quality = clamp(1.0 - bc / max(c0, 0.05), 0.0, 1.0);
	float raw_contrast = min(sqrt(max(va / 144.0 - ma * ma, 0.0)), sqrt(max(vb / 144.0 - mb * mb, 0.0)));
	quality *= smoothstep(0.025, 0.05, raw_contrast);
	vec2 moved = -best;
	COLOR = ok ? vec4(clamp(moved / 0.8 + 0.5, 0.0, 1.0), quality, 1.0) : vec4(0.5, 0.5, 0.0, 0.0);
}
