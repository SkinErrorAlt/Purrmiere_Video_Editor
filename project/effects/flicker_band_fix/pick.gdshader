shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D band_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float band_size : hint_range(16.0, 270.0) = 160.0;
uniform int direction = 0;

const int STRIPS = 16;

float join16(float h, float l) {
	return (floor(h * 255.0 + 0.5) * 256.0 + floor(l * 255.0 + 0.5)) / 65535.0;
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

float coh_at(sampler2D tex, int k, int h, int cands) {
	float best = 0.0;
	for (int d = -1; d <= 1; d++) {
		int kk = k + d;
		if (kk >= 0 && kk < cands) {
			best = max(best, texelFetch(tex, ivec2(kk / h, kk % h), 0).b);
		}
	}
	return best;
}

void fragment() {
	if (FRAGCOORD.x > 1.0 || FRAGCOORD.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		ivec2 ax = direction == 0 ? ivec2(0, 1) : ivec2(1, 0);
		float count = dot(vec2(textureSize(band_tex, 0)), vec2(ax));
		float ps = px_scale * 8.0;
		float tmin = max(8.0 * ps, 3.0);
		float tmax = clamp(band_size * ps, tmin + 1.0, count * 0.25);
		int h = int(tex_size.y);
		int cands = int(tex_size.x) * h / STRIPS;
		float best_score = -1.0;
		int best_k = 0;
		for (int k = 0; k < cands; k++) {
			vec4 t = texelFetch(TEXTURE, ivec2(k / h, k % h), 0);
			float score = join16(t.r, t.g);
			if (score > best_score) {
				best_score = score;
				best_k = k;
			}
		}
		float span = max(float(cands - 1), 1.0);
		float per = mix(tmin, tmax, float(best_k) / span);
		float best = texelFetch(TEXTURE, ivec2(best_k / h, best_k % h), 0).b;
		for (int m = 3; m >= 2; m--) {
			float cand = per * float(m);
			if (cand <= tmax) {
				int km = int(floor((cand - tmin) / (tmax - tmin) * span + 0.5));
				float c = coh_at(TEXTURE, km, h, cands);
				if (c > 0.3 && c > best * 0.45) {
					per = cand;
					break;
				}
			}
		}
		vec2 p16 = split16(per / count);
		COLOR = vec4(p16.x, p16.y, clamp(best, 0.0, 1.0), 1.0);
	}
}
