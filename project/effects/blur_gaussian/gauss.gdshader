shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius : hint_range(0.0, 200.0) = 8.0;
uniform int dims = 0;
uniform bool edge = true;
uniform int kernel = 0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool ch_r = true;
uniform bool ch_g = true;
uniform bool ch_b = true;
uniform bool ch_a = true;

float weight_at(float x, float sigma) {
	if (kernel == 1) {
		return x <= sigma * 1.5 ? 1.0 : 0.0;
	}
	if (kernel == 2) {
		return max(1.0 - x / (3.0 * sigma), 0.0);
	}
	return exp(-0.5 * x * x / (sigma * sigma));
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (!edge && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		return vec4(0.0);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec4 centre = texture(TEXTURE, UV);
	bool skip = (dims == 1 && abs(direction.y) > 0.5) || (dims == 2 && abs(direction.x) > 0.5);
	float sigma = radius * px_scale / 3.0;
	if (skip || sigma < 0.15) {
		COLOR = centre;
	} else {
		int n = int(min(ceil(3.0 * sigma), 64.0));
		vec2 px = direction / tex_size;
		float w0 = weight_at(0.0, sigma);
		vec4 sum = centre * w0;
		float wsum = w0;
		for (int k = 1; k <= 63; k += 2) {
			if (k > n) {
				break;
			}
			float w1 = weight_at(float(k), sigma);
			float w2 = (k + 1 <= n) ? weight_at(float(k + 1), sigma) : 0.0;
			float wp = w1 + w2;
			if (wp <= 0.0) {
				continue;
			}
			float off = (float(k) * w1 + float(k + 1) * w2) / wp;
			sum += fetch(TEXTURE, UV + px * off) * wp;
			sum += fetch(TEXTURE, UV - px * off) * wp;
			wsum += 2.0 * wp;
		}
		vec4 blurred = sum / max(wsum, 0.0001);
		vec4 mask = vec4(ch_r ? 1.0 : 0.0, ch_g ? 1.0 : 0.0, ch_b ? 1.0 : 0.0, ch_a ? 1.0 : 0.0);
		COLOR = mix(centre, blurred, mask);
	}
}
