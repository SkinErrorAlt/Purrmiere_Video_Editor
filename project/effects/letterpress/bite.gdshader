shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float bite : hint_range(1.0, 16.0) = 5.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 texel = 1.0 / max(tex_size, vec2(1.0));
	float stride = bite * max(px_scale, 0.0001) / 3.0;
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = -6; i <= 6; i++) {
		float x = float(i);
		float w = exp(-x * x / 18.0);
		sum += texture(TEXTURE, UV + direction * texel * x * stride).r * w;
		wsum += w;
	}
	float h = sum / wsum;
	COLOR = vec4(h, h, h, 1.0);
}
