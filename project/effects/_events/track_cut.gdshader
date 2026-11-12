shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform sampler2D thumb_tex : filter_linear, repeat_disable;
uniform float sensitivity : hint_range(0.0, 1.0) = 0.5;
uniform float look_back = 1.0;

void fragment() {
	float thr = ev_cut_threshold(sensitivity);
	int lim = min(int(ceil(look_back * history_fps)) + 1, 60);
	int found = -1;
	for (int a = 0; a <= 60; a++) {
		if (a > lim) {
			break;
		}
		if (ev_is_cut(TEXTURE, a, thr)) {
			found = a;
			break;
		}
	}
	int block = int(clamp(floor(UV.x * 4.0), 0.0, 3.0));
	vec4 outv = vec4(1.0, 0.0, 0.5, 0.5);
	if (found >= 0) {
		float hard = clamp((ev_stat(TEXTURE, found).r - thr) / max(1.0 - thr, 0.05) * 0.7 + 0.3, 0.0, 1.0);
		vec2 bright = vec2(0.5);
		float best = -1.0;
		vec3 mo = vec3(0.0);
		vec3 mo2 = vec3(0.0);
		vec3 mn = vec3(0.0);
		float yn2 = 0.0;
		for (int j = 0; j < EV_NY; j++) {
			for (int i = 0; i < EV_NX; i++) {
				vec2 p = ev_point(i, j);
				float y = ev_luma(ev_thumb(thumb_tex, found, p).rgb);
				float w = y - 0.06 * length(p - vec2(0.5));
				if (w > best) {
					best = w;
					bright = p;
				}
				vec3 o = ev_thumb(thumb_tex, found + 1, p).rgb;
				mo += o;
				mo2 += o * o;
				vec3 nw = ev_thumb(thumb_tex, 0, p).rgb;
				mn += nw;
				yn2 += ev_luma(nw) * ev_luma(nw);
			}
		}
		mo /= 144.0;
		mn /= 144.0;
		vec3 so = sqrt(max(mo2 / 144.0 - mo * mo, vec3(0.0)));
		float sn = sqrt(max(yn2 / 144.0 - ev_luma(mn) * ev_luma(mn), 0.0));
		if (block == 0) {
			outv = vec4(float(found) / 63.0, hard, bright);
		} else if (block == 1) {
			outv = vec4(mo, 1.0);
		} else if (block == 2) {
			outv = vec4(mn, 1.0);
		} else {
			outv = vec4(so * 2.0, sn * 2.0);
		}
	}
	COLOR = outv;
}
