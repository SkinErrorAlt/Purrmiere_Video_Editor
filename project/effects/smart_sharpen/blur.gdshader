shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float radius : hint_range(0.3, 10.0) = 1.0;

void fragment() {
	vec4 centre = texture(TEXTURE, UV);
	float sigma = max(radius * px_scale, 0.2);
	int n = int(min(ceil(3.0 * sigma), 32.0));
	vec2 px = direction / tex_size;
	vec4 sum = centre;
	float wsum = 1.0;
	for (int k = 1; k <= 32; k++) {
		if (k > n) {
			break;
		}
		float x = float(k);
		float w = exp(-0.5 * x * x / (sigma * sigma));
		sum += texture(TEXTURE, clamp(UV + px * x, vec2(0.0), vec2(1.0))) * w;
		sum += texture(TEXTURE, clamp(UV - px * x, vec2(0.0), vec2(1.0))) * w;
		wsum += 2.0 * w;
	}
	COLOR = sum / wsum;
}
