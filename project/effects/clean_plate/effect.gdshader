shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float span : hint_range(0.2, 2.0) = 2.0;
uniform int samples : hint_range(5, 31) = 21;
uniform int kind = 0;
uniform float threshold : hint_range(0.01, 0.5) = 0.08;
uniform float softness : hint_range(0.005, 0.4) = 0.06;
uniform float ghost : hint_range(0.0, 1.0) = 0.35;

float lum(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

float dist(vec4 a, vec4 b) {
	vec4 d = abs(a - b);
	return max(max(d.r, d.g), max(d.b, d.a));
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	int n = clamp(samples, 5, 31);
	float reach = min(span * history_fps, float(history_count));
	vec4 s[31];
	float l[31];
	int have = 1;
	s[0] = now;
	l[0] = lum(now);
	if (reach >= 1.0) {
		for (int i = 1; i < 31; i++) {
			if (i >= n) {
				break;
			}
			float age = reach * float(i) / float(n - 1);
			s[i] = history_between(age, UV, now);
			l[i] = lum(s[i]);
			have = i + 1;
		}
	}
	int best = 0;
	int best_score = 1000;
	for (int i = 0; i < 31; i++) {
		if (i >= have) {
			break;
		}
		int below = 0;
		int above = 0;
		for (int j = 0; j < 31; j++) {
			if (j >= have) {
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
	vec4 med = s[best];
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 31; i++) {
		if (i >= have) {
			break;
		}
		float w = 1.0 - smoothstep(0.03, 0.07, dist(s[i], med));
		acc += s[i] * w;
		wsum += w;
	}
	vec4 bg = wsum > 0.0001 ? acc / wsum : med;
	float moved = smoothstep(threshold, threshold + softness, dist(now, bg));
	if (kind == 2) {
		COLOR = mix(bg, now, moved * ghost);
	} else if (kind == 1) {
		COLOR = now * moved;
	} else {
		COLOR = bg;
	}
}
