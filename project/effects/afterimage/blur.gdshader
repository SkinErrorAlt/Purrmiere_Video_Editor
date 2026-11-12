shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(2.0);
uniform float spread = 1.0;

void fragment() {
	vec2 px = spread / tex_size;
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			float w = exp(-float(i * i + j * j) / 6.0);
			acc += texture(TEXTURE, UV + vec2(float(i), float(j)) * px).rgb * w;
			wsum += w;
		}
	}
	COLOR = vec4(acc / wsum, 1.0);
}
