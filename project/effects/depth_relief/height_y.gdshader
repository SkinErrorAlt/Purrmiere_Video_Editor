shader_type canvas_item;
render_mode blend_disabled;

uniform float smoothness : hint_range(0.0, 60.0) = 6.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float unpack(vec4 c) {
	return c.r + c.g / 255.0;
}

void fragment() {
	float sigma = max(smoothness * max(px_scale, 0.0001), 0.35);
	float reach = sigma * 2.5;
	int n = int(clamp(ceil(reach), 1.0, 20.0));
	float stp = max(reach / float(n), 1.0);
	float py = 1.0 / max(tex_size.y, 1.0);
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = -n; i <= n; i++) {
		float o = float(i) * stp;
		float w = exp(-0.5 * o * o / (sigma * sigma));
		sum += unpack(texture(TEXTURE, UV + vec2(0.0, o * py))) * w;
		wsum += w;
	}
	float v = clamp(sum / max(wsum, 0.0001), 0.0, 1.0);
	float hi = floor(v * 255.0) / 255.0;
	COLOR = vec4(hi, fract(v * 255.0), 0.0, 1.0);
}
