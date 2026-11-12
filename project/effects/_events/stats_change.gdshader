shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_events/ev.gdshaderinc"

void fragment() {
	int a = ev_age_of(UV);
	bool ok = a < 63 && ev_valid(TEXTURE, a) && ev_valid(TEXTURE, a + 1);
	float ya[144];
	vec3 ca[144];
	float ma = 0.0;
	float mb = 0.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			vec2 p = ev_point(i, j);
			vec3 c = ev_thumb(TEXTURE, a, p).rgb;
			ca[j * EV_NX + i] = c;
			float y = ev_luma(c);
			ya[j * EV_NX + i] = y;
			ma += y;
			mb += ev_luma(ev_thumb(TEXTURE, a + 1, p).rgb);
		}
	}
	ma /= 144.0;
	mb /= 144.0;
	float va = 0.0;
	float vb = 0.0;
	float energy = 0.0;
	vec3 cen = vec3(0.0);
	vec2 m2 = vec2(0.0);
	float yb_[144];
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			int k = j * EV_NX + i;
			float yb = ev_luma(ev_thumb(TEXTURE, a + 1, ev_point(i, j)).rgb);
			yb_[k] = yb;
			va += (ya[k] - ma) * (ya[k] - ma);
			vb += (yb - mb) * (yb - mb);
			energy += abs((ya[k] - ma) - (yb - mb));
		}
	}
	float sa = max(sqrt(va / 144.0), 0.035);
	float sb = max(sqrt(vb / 144.0), 0.035);
	energy /= 144.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			int k = j * EV_NX + i;
			float w = abs((ya[k] - ma) / sa - (yb_[k] - mb) / sb);
			w *= w;
			vec2 p = ev_point(i, j);
			cen += vec3(p * w, w);
			m2 += p * p * w;
		}
	}
	vec2 c = cen.z > 1e-6 ? cen.xy / cen.z : vec2(0.5);
	vec2 var2 = cen.z > 1e-6 ? max(m2 / cen.z - c * c, vec2(0.0)) : vec2(0.083);
	float spread = clamp(sqrt(var2.x + var2.y) / 0.41, 0.0, 1.0);
	vec2 step = vec2(0.92 / float(EV_NX), 0.92 / float(EV_NY));
	float best = 1e9;
	for (int sy = -2; sy <= 2; sy++) {
		for (int sx = -2; sx <= 2; sx++) {
			vec2 off = vec2(float(sx), float(sy)) * 0.5 * step;
			float d = 0.0;
			float dc = 0.0;
			for (int j = 1; j < EV_NY - 1; j++) {
				for (int i = 1; i < EV_NX - 1; i++) {
					int k = j * EV_NX + i;
					vec3 cb = ev_thumb(TEXTURE, a + 1, ev_point(i, j) + off).rgb;
					float zb = (ev_luma(cb) - mb) / sb;
					float za = (ya[k] - ma) / sa;
					d += abs(za - zb);
					vec3 xa = ca[k] - vec3(ya[k]);
					vec3 xb = cb - vec3(ev_luma(cb));
					dc += length(xa - xb);
				}
			}
			float n = float((EV_NX - 2) * (EV_NY - 2));
			best = min(best, d / n * 0.8 + min(dc / n / 0.12, 1.0) * 0.25);
		}
	}
	float change = clamp(best / 1.15, 0.0, 1.0);
	COLOR = ok ? vec4(change, clamp(energy * 4.0, 0.0, 1.0), ma, 0.2 + 0.8 * spread) : vec4(0.0, 0.0, ma, 0.0);
}
