shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform float sensitivity : hint_range(0.0, 1.0) = 0.5;
uniform float hold : hint_range(0.05, 1.0) = 0.25;
uniform float clip_time = 0.0;

vec3 shift_at(sampler2D t, int a, int born) {
	vec4 s = ev_stat(t, a);
	if (s.a < 0.5 || a >= born) {
		return vec3(0.0);
	}
	return vec3((s.rg - 0.5) * 0.8, s.b);
}

void fragment() {
	float fps = max(history_fps, 1.0);
	int born = int(floor(clip_time * fps + 0.001));
	float need = mix(2.4, 0.9, clamp(sensitivity, 0.0, 1.0));
	vec2 v = vec2(0.0);
	float on = 0.0;
	for (int a = 0; a <= 30; a++) {
		float t = float(a) / fps;
		if (t > hold + 0.15) {
			break;
		}
		vec3 s0 = shift_at(TEXTURE, a, born);
		vec3 s1 = shift_at(TEXTURE, a + 1, born);
		vec3 sn = a > 0 ? shift_at(TEXTURE, a - 1, born) : vec3(0.0);
		float sp0 = length(s0.xy) * fps;
		float sp1 = length(s1.xy) * fps;
		float spn = length(sn.xy) * fps;
		bool good = s0.z > 0.25;
		bool pair = (sp1 > need * 0.7 && dot(s0.xy, s1.xy) > 0.0) || (a > 0 && spn > need * 0.7 && dot(s0.xy, sn.xy) > 0.0);
		if (good && sp0 > need && pair) {
			float w = exp(-t / max(hold * 0.5, 0.02));
			float k = smoothstep(need, need * 1.8, sp0) * w;
			if (k > on) {
				on = k;
				v = s0.xy;
			}
		}
	}
	COLOR = vec4(clamp(v / 0.8 + 0.5, 0.0, 1.0), on, 1.0);
}
