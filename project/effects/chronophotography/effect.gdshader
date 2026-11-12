shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform int copies : hint_range(1, 12) = 6;
uniform float interval : hint_range(0.02, 1.0) = 0.15;
uniform float threshold : hint_range(0.01, 0.5) = 0.09;
uniform float softness : hint_range(0.005, 0.4) = 0.06;
uniform float fade : hint_range(0.0, 1.0) = 0.35;

float lum(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

float dist(vec4 a, vec4 b) {
	vec4 d = abs(a - b);
	return max(max(d.r, d.g), max(d.b, d.a));
}

void fragment() {
	vec4 s[13];
	float l[13];
	s[0] = texture(TEXTURE, UV);
	int n = clamp(copies, 1, 12);
	float step_frames = interval * history_fps;
	int have = 0;
	for (int i = 1; i <= 12; i++) {
		if (i > n) {
			break;
		}
		float age = step_frames * float(i);
		if (age > float(history_count) + 0.001 || history_count == 0) {
			break;
		}
		s[i] = history_between(age, UV, s[0]);
		have = i;
	}
	vec4 bg = s[0];
	if (have >= 1) {
		for (int i = 0; i <= 12; i++) {
			if (i > have) {
				break;
			}
			l[i] = lum(s[i]);
		}
		int best = 0;
		int best_score = 1000;
		for (int i = 0; i <= 12; i++) {
			if (i > have) {
				break;
			}
			int below = 0;
			int above = 0;
			for (int j = 0; j <= 12; j++) {
				if (j > have) {
					break;
				}
				if (l[j] < l[i]) {
					below++;
				} else if (l[j] > l[i]) {
					above++;
				}
			}
			int score = abs(below - above);
			if (score < best_score) {
				best_score = score;
				best = i;
			}
		}
		bg = s[best];
	}
	vec4 out_c = bg;
	for (int i = 12; i >= 1; i--) {
		if (i > have) {
			continue;
		}
		float moved = smoothstep(threshold, threshold + softness, dist(s[i], bg));
		float keep = 1.0 - fade * float(i - 1) / float(max(n, 1));
		out_c = mix(out_c, s[i], moved * keep);
	}
	float now_moved = smoothstep(threshold, threshold + softness, dist(s[0], bg));
	out_c = mix(out_c, s[0], now_moved);
	COLOR = out_c;
}
