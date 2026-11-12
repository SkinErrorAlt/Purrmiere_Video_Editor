shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 s = vec4(0.0);
	float wsum = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) * 0.25);
			s += texture(TEXTURE, clamp(UV + o * px * 1.5, vec2(0.0), vec2(1.0))) * w;
			wsum += w;
		}
	}
	COLOR = s / wsum;
}
