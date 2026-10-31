shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 direction = vec2(1.0, 0.0);
uniform float radius = 0.0;
uniform float expand = 0.0;

void fragment() {
	float sigma = max(radius / 3.0, 0.001);
	int taps = int(clamp(ceil(sigma * 3.0), 0.0, 48.0));
	vec2 px = direction / tex_size;
	if (taps <= 0) {
		float a0 = texture(TEXTURE, UV).a;
		COLOR = vec4(vec3(a0), a0);
	} else {
		float sum = 0.0;
		float wsum = 0.0;
		for (int i = -48; i <= 48; i++) {
			if (i < -taps || i > taps) {
				continue;
			}
			float x = float(i);
			float w = exp(-0.5 * x * x / (sigma * sigma));
			vec2 uv = clamp(UV + px * x, vec2(0.0), vec2(1.0));
			sum += texture(TEXTURE, uv).a * w;
			wsum += w;
		}
		float a = sum / max(wsum, 0.0001);
		if (expand != 0.0) {
			float shift = clamp(expand / max(radius, 1.0), -0.49, 0.49);
			a = clamp((a - 0.5 + shift) / max(1.0 - 2.0 * abs(shift), 0.02) + 0.5, 0.0, 1.0);
		}
		COLOR = vec4(vec3(a), a);
	}
}
