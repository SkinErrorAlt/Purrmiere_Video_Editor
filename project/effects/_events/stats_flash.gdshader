shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_events/ev.gdshaderinc"

void fragment() {
	int a = ev_age_of(UV);
	bool ok = a < 63 && ev_valid(TEXTURE, a) && ev_valid(TEXTURE, a + 1);
	float pos_sum = 0.0;
	float neg_sum = 0.0;
	vec3 cen = vec3(0.0);
	float peak = 0.0;
	float other = 0.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			vec2 p = ev_point(i, j);
			float ya = ev_luma(ev_thumb(TEXTURE, a, p).rgb);
			float yb = ev_luma(ev_thumb(TEXTURE, a + 1, p).rgb);
			float d = ya - yb;
			float lit = max(d - 0.05, 0.0) * smoothstep(0.35, 0.75, ya);
			pos_sum += lit;
			neg_sum += max(-d - 0.05, 0.0);
			other += (abs(d) > 0.08 && lit <= 0.0) ? 1.0 : 0.0;
			float w = lit * lit;
			cen += vec3(p * w, w);
			peak = max(peak, lit);
		}
	}
	float pos = pos_sum / 144.0;
	float neg = neg_sum / 144.0;
	float strength = clamp(peak * 1.6 + pos * 4.0, 0.0, 1.0);
	strength *= 1.0 - smoothstep(0.012, 0.05, neg - pos * 0.15);
	strength *= 1.0 - smoothstep(0.12, 0.3, other / 144.0);
	vec2 c = cen.z > 1e-6 ? cen.xy / cen.z : vec2(0.5);
	COLOR = ok ? vec4(strength, c, 1.0) : vec4(0.0, 0.5, 0.5, 0.0);
}
