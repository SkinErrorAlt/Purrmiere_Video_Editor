shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_events/ev.gdshaderinc"

uniform sampler2D thumb_tex : filter_linear, repeat_disable;

void fragment() {
	int a = ev_age_of(UV);
	bool ok = a < 63 && ev_valid(thumb_tex, a) && ev_valid(thumb_tex, a + 1);
	float ya[144];
	float yb[144];
	float ma = 0.0;
	float mb = 0.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			vec2 p = ev_point(i, j);
			int k = j * EV_NX + i;
			ya[k] = ev_luma(ev_thumb(thumb_tex, a, p).rgb);
			yb[k] = ev_luma(ev_thumb(thumb_tex, a + 1, p).rgb);
			ma += ya[k];
			mb += yb[k];
		}
	}
	ma /= 144.0;
	mb /= 144.0;
	float energy = 0.0;
	vec3 cen = vec3(0.0);
	float region[12];
	for (int r = 0; r < 12; r++) {
		region[r] = 0.0;
	}
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			int k = j * EV_NX + i;
			float e = abs((ya[k] - ma) - (yb[k] - mb));
			energy += e;
			region[(j / 3) * 4 + (i / 4)] += e;
			float w = e * e;
			vec2 p = ev_point(i, j);
			cen += vec3(p * w, w);
		}
	}
	energy /= 144.0;
	float peak = 0.0;
	for (int r = 0; r < 12; r++) {
		peak = max(peak, region[r] / 12.0);
	}
	vec2 c = cen.z > 1e-7 ? cen.xy / cen.z : vec2(0.5);
	COLOR = ok ? vec4(clamp(energy * 4.0, 0.0, 1.0), c, 0.5 + 0.5 * clamp(peak * 2.0, 0.0, 1.0)) : vec4(0.0, 0.5, 0.5, 0.0);
}
