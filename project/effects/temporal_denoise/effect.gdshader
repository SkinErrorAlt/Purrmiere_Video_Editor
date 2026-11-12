shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform int frames : hint_range(1, 12) = 6;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float follow : hint_range(0.0, 4.0) = 1.5;
uniform float detail : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 now = texture(TEXTURE, UV);
	vec4 ref[9];
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 3; i++) {
			ref[j * 3 + i] = texture(TEXTURE, UV + (vec2(float(i), float(j)) - 1.0) * 1.5 * px);
		}
	}
	float h = mix(0.008, 0.25, strength * strength);
	float r = follow * max(px_scale, 0.25);
	vec4 acc = now;
	float wsum = 1.0;
	int n = min(clamp(frames, 1, 12), history_count);
	for (int k = 1; k <= 12; k++) {
		if (k > n) {
			break;
		}
		float best = 1e9;
		float best_tex = 0.0;
		vec2 bo = vec2(0.0);
		for (int sy = -1; sy <= 1; sy++) {
			for (int sx = -1; sx <= 1; sx++) {
				if (r < 0.01 && (sx != 0 || sy != 0)) {
					continue;
				}
				vec2 o = vec2(float(sx), float(sy)) * r;
				vec4 sum_d = vec4(0.0);
				float sum_abs = 0.0;
				for (int j = 0; j < 3; j++) {
					for (int i = 0; i < 3; i++) {
						vec4 c = history_frame(k, UV + ((vec2(float(i), float(j)) - 1.0) * 1.5 + o) * px, now);
						vec4 e = c - ref[j * 3 + i];
						sum_d += e;
						sum_abs += dot(abs(e.rgb), vec3(0.333));
					}
				}
				vec4 m = abs(sum_d) / 9.0;
				float d = max(max(m.r, m.g), max(m.b, m.a)) + 0.0006 * length(o);
				if (d < best) {
					best = d;
					best_tex = sum_abs / 9.0;
					bo = o;
				}
			}
		}
		vec4 c = history_frame(k, UV + bo * px, now);
		float w = exp(-(best * best) / (h * h));
		float structure = max(best_tex - 1.6 * h, 0.0);
		w *= exp(-structure * structure / (h * h) * detail * 4.0);
		acc += c * w;
		wsum += w;
	}
	COLOR = acc / wsum;
}
