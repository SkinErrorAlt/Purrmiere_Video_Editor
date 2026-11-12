shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform float sensitivity : hint_range(0.0, 1.0) = 0.5;
uniform float look_back = 1.0;

void fragment() {
	float thr = mix(0.85, 0.3, clamp(sensitivity, 0.0, 1.0));
	int lim = min(int(ceil(look_back * history_fps)) + 1, 59);
	vec4 outv = vec4(1.0, 0.0, 0.5, 0.5);
	for (int a = 0; a <= 59; a++) {
		if (a > lim) {
			break;
		}
		vec4 s = ev_stat(TEXTURE, a);
		if (s.a < 0.5 || s.r < thr) {
			continue;
		}
		vec4 before = ev_stat(TEXTURE, a + 1);
		if (s.r > before.r * 1.4 + 0.06) {
			outv = vec4(float(a) / 63.0, clamp((s.r - thr) / max(1.0 - thr, 0.05) * 0.6 + 0.4, 0.0, 1.0), s.gb);
			break;
		}
	}
	COLOR = outv;
}
