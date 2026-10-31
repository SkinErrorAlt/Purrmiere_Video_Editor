shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float sigma = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool final_pass = false;

void fragment() {
	float a = 0.0;
	if (sigma < 0.3) {
		a = texture(TEXTURE, UV).a;
	} else {
		vec2 px = direction * TEXTURE_PIXEL_SIZE;
		float reach = sigma * 3.0;
		float stride = max(reach / 32.0, 1.0);
		float wsum = 0.0;
		for (int i = -32; i <= 32; i++) {
			float x = float(i) * stride;
			if (abs(x) > reach + 0.001) {
				continue;
			}
			float w = exp(-0.5 * x * x / (sigma * sigma));
			a += texture(TEXTURE, UV + px * x).a * w;
			wsum += w;
		}
		a /= max(wsum, 0.0001);
	}
	if (final_pass) {
		float k = a * tint.a;
		COLOR = vec4(tint.rgb * k, k);
	} else {
		COLOR = vec4(a, a, a, a);
	}
}
