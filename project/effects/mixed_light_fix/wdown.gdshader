shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec4 s = texture(TEXTURE, UV + px * (vec2(float(i), float(j)) - 1.5) * 0.5);
			sum += s.rgb * s.a;
			wsum += s.a;
		}
	}
	COLOR = vec4(wsum > 0.00001 ? sum / wsum : vec3(0.5), wsum / 16.0);
}
