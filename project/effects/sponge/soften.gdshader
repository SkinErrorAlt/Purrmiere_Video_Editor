shader_type canvas_item;
render_mode blend_disabled;

uniform float smoothness : hint_range(1.0, 15.0) = 5.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	float sigma = smoothness * 0.45 * max(px_scale, 0.0001);
	if (sigma < 0.35) {
		COLOR = texture(TEXTURE, UV);
	} else {
		int n = clamp(int(ceil(sigma * 2.0)), 1, 24);
		float stp = sigma * 3.0 / float(n);
		vec2 dv = direction * stp / max(tex_size, vec2(1.0));
		vec4 sum = texture(TEXTURE, UV);
		float total = 1.0;
		for (int i = 1; i <= 24; i++) {
			if (i > n) {
				break;
			}
			float x = float(i) * stp / sigma;
			float w = exp(-0.5 * x * x);
			sum += (texture(TEXTURE, UV + dv * float(i)) + texture(TEXTURE, UV - dv * float(i))) * w;
			total += 2.0 * w;
		}
		COLOR = sum / total;
	}
}
