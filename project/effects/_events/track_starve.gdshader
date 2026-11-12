shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform float bitrate : hint_range(0.0, 1.0) = 0.5;
uniform float clip_time = 0.0;

void fragment() {
	float fps = max(history_fps, 1.0);
	int born = int(floor(clip_time * fps + 0.001));
	int n = 0;
	for (int a = 0; a <= 60; a++) {
		if (ev_stat(TEXTURE, a).a < 0.1 || a >= born) {
			break;
		}
		n = a + 1;
	}
	float refill = mix(0.04, 0.35, clamp(bitrate, 0.0, 1.0)) * 30.0 / fps;
	float budget = 1.0;
	float q = 1.0;
	float sent_q = 1.0;
	int dropped = 0;
	for (int a = 60; a >= 0; a--) {
		if (a >= n) {
			continue;
		}
		vec4 s = ev_stat(TEXTURE, a);
		float cost = 0.04 + 0.6 * s.g + 1.1 * smoothstep(0.3, 0.85, s.r);
		budget += refill;
		if (budget < cost * 0.35 && dropped < 6) {
			dropped++;
		} else {
			float allowed = min(max(budget, 0.0), 0.45 + refill * 2.0);
			q = smoothstep(0.12, 1.0, allowed / max(cost, 0.001)) * smoothstep(0.15, 0.95, budget);
			budget -= min(cost, allowed);
			sent_q = q;
			dropped = 0;
		}
		budget = min(budget, 1.0);
	}
	COLOR = vec4(sent_q, float(dropped) / 63.0, sent_q, 1.0);
}
