shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float interval : hint_range(0.03, 1.0) = 0.17;
uniform int flashes : hint_range(2, 12) = 7;
uniform int scene = 0;
uniform float ambient : hint_range(0.0, 1.0) = 0.22;
uniform float decay : hint_range(0.0, 1.0) = 0.86;
uniform float flash_power : hint_range(0.2, 3.0) = 1.15;
uniform float threshold : hint_range(0.01, 0.5) = 0.12;
uniform float softness : hint_range(0.005, 0.4) = 0.07;
uniform vec4 flash_colour : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float clip_time = 0.0;
uniform vec2 tex_size = vec2(2.0);

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float dist(vec4 a, vec4 b) {
	vec4 d = abs(a - b);
	return max(max(d.r, d.g), max(d.b, d.a));
}

vec3 soft_clip(vec3 x) {
	vec3 k = vec3(0.78);
	vec3 over = max(x - k, vec3(0.0));
	return min(x, k) + (1.0 - k) * (1.0 - exp(-over / (1.0 - k)));
}

vec4 soft_at(sampler2D tex, int age, vec2 uv, vec2 px) {
	vec4 acc = vec4(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 q = uv + (vec2(float(i), float(j)) - 0.5) * 5.0 * px;
			vec4 n = texture(tex, q);
			acc += age == 0 ? n : history_frame(age, q, n);
		}
	}
	return acc * 0.25;
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	vec2 px = 1.0 / tex_size;
	vec4 sb[13];
	float fps = max(history_fps, 1.0);
	int step_f = max(int(round(interval * fps)), 1);
	int n = int(floor(max(clip_time, 0.0) * fps + 0.0001));
	int since = n - (n / step_f) * step_f;
	int k_max = clamp(flashes, 2, 12);
	vec4 s[13];
	int have = 0;
	for (int j = 0; j < 12; j++) {
		if (j >= k_max) {
			break;
		}
		int age = since + j * step_f;
		if (age > history_count || age > n) {
			break;
		}
		s[j] = age == 0 ? now : history_frame(age, UV, now);
		sb[j] = scene == 0 ? soft_at(TEXTURE, age, UV, px) : s[j];
		have = j + 1;
	}
	s[have] = now;
	sb[have] = scene == 0 ? soft_at(TEXTURE, 0, UV, px) : now;
	int total = have + 1;
	vec4 bg = now;
	vec4 bgb = sb[have];
	if (scene == 0 && total >= 3) {
		float l[13];
		for (int i = 0; i < 13; i++) {
			if (i >= total) {
				break;
			}
			l[i] = lum(sb[i].rgb);
		}
		int best = 0;
		int best_score = 1000;
		for (int i = 0; i < 13; i++) {
			if (i >= total) {
				break;
			}
			int below = 0;
			int above = 0;
			for (int j = 0; j < 13; j++) {
				if (j >= total) {
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
		bgb = sb[best];
	}
	vec3 light = flash_colour.rgb * flash_power;
	vec3 acc;
	if (scene == 0) {
		acc = bg.rgb * ambient;
		float m_now = smoothstep(threshold, threshold + softness, dist(sb[have], bgb));
		acc = mix(acc, now.rgb * ambient, m_now);
	} else {
		acc = now.rgb * ambient;
	}
	float w = 1.0;
	vec3 top = vec3(0.0);
	vec3 sum = vec3(0.0);
	for (int j = 0; j < 12; j++) {
		if (j >= have) {
			break;
		}
		vec3 c = s[j].rgb;
		if (scene == 0) {
			float m = smoothstep(threshold, threshold + softness, dist(sb[j], bgb));
			acc += c * light * m * w;
		} else {
			vec3 lit = c * c * light * w;
			top = max(top, lit);
			sum += lit;
		}
		w *= decay;
	}
	if (scene == 1) {
		acc = max(acc, top) + 0.18 * (sum - top);
	}
	vec3 rgb = soft_clip(acc);
	COLOR = vec4(min(rgb, vec3(now.a)), now.a);
}
