shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform int band = 1;
uniform float size : hint_range(0.5, 3.0) = 1.0;

float band_sigma(int b) {
	if (b <= 1) {
		return 1.0 * size;
	}
	if (b == 2) {
		return 4.0 * size;
	}
	return 16.0 * size;
}

void fragment() {
	vec4 centre = texture(TEXTURE, UV);
	float s_hi = band_sigma(band);
	float s_lo = band > 1 ? band_sigma(band - 1) : 0.0;
	float sigma = sqrt(max(s_hi * s_hi - s_lo * s_lo, 0.0)) * px_scale;
	if (sigma < 0.2) {
		COLOR = centre;
	} else {
		float stride = max(1.0, sigma / 6.0);
		int n = int(min(ceil(3.0 * sigma / stride), 24.0));
		vec2 px = direction / tex_size;
		vec4 sum = centre;
		float wsum = 1.0;
		for (int k = 1; k <= 24; k++) {
			if (k > n) {
				break;
			}
			float x = float(k) * stride;
			float w = exp(-0.5 * x * x / (sigma * sigma));
			sum += texture(TEXTURE, clamp(UV + px * x, vec2(0.0), vec2(1.0))) * w;
			sum += texture(TEXTURE, clamp(UV - px * x, vec2(0.0), vec2(1.0))) * w;
			wsum += 2.0 * w;
		}
		COLOR = sum / wsum;
	}
}
