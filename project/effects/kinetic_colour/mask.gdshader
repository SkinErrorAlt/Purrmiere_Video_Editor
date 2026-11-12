shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float span : hint_range(0.3, 2.0) = 1.2;
uniform float threshold : hint_range(0.01, 0.5) = 0.07;
uniform float softness : hint_range(0.005, 0.4) = 0.06;
uniform vec2 tex_size = vec2(2.0);

vec4 soft_at(sampler2D tex, float age, vec2 uv, vec2 px) {
	vec4 acc = vec4(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 q = uv + (vec2(float(i), float(j)) - 0.5) * 2.0 * px;
			vec4 n = texture(tex, q);
			acc += age < 0.5 ? n : history_between(age, q, n);
		}
	}
	return acc * 0.25;
}

float lum(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

float dist(vec4 a, vec4 b) {
	vec4 d = abs(a - b);
	return max(max(d.r, d.g), max(d.b, d.a));
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	float reach = min(span * history_fps, float(history_count));
	vec4 s[11];
	float l[11];
	int have = 1;
	s[0] = soft_at(TEXTURE, 0.0, UV, px);
	l[0] = lum(s[0]);
	if (reach >= 1.0) {
		for (int i = 1; i < 11; i++) {
			s[i] = soft_at(TEXTURE, reach * float(i) / 10.0, UV, px);
			l[i] = lum(s[i]);
			have = i + 1;
		}
	}
	int best = 0;
	int best_score = 1000;
	for (int i = 0; i < 11; i++) {
		if (i >= have) {
			break;
		}
		int below = 0;
		int above = 0;
		for (int j = 0; j < 11; j++) {
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
	vec4 bg = s[best];
	float m = have > 2 ? smoothstep(threshold, threshold + softness, dist(s[0], bg)) : 0.0;
	if (have > 2) {
		float recent = smoothstep(threshold, threshold + softness, dist(s[1], bg));
		m = max(m, recent * 0.6);
	}
	COLOR = vec4(m, m, m, 1.0);
}
