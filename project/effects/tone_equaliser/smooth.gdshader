shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float smoothing : hint_range(0.0, 100.0) = 24.0;
uniform float edges : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float centre = texture(TEXTURE, UV).r;
	float sigma = smoothing * px_scale / 3.0;
	if (sigma < 0.3) {
		COLOR = vec4(vec3(centre), 1.0);
	} else {
		float range_sigma = mix(1.0, 0.035, edges);
		float stride = max(1.0, sigma / 8.0);
		int n = int(min(ceil(3.0 * sigma / stride), 24.0));
		vec2 px = direction / tex_size;
		float sum = centre;
		float wsum = 1.0;
		for (int k = 1; k <= 24; k++) {
			if (k > n) {
				break;
			}
			float x = float(k) * stride;
			float ws = exp(-0.5 * x * x / (sigma * sigma));
			float a = texture(TEXTURE, clamp(UV + px * x, vec2(0.0), vec2(1.0))).r;
			float b = texture(TEXTURE, clamp(UV - px * x, vec2(0.0), vec2(1.0))).r;
			float wa = ws * exp(-0.5 * (a - centre) * (a - centre) / (range_sigma * range_sigma));
			float wb = ws * exp(-0.5 * (b - centre) * (b - centre) / (range_sigma * range_sigma));
			sum += a * wa + b * wb;
			wsum += wa + wb;
		}
		COLOR = vec4(vec3(sum / wsum), 1.0);
	}
}
