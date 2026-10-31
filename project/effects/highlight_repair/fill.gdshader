shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 own = texture(TEXTURE, UV);
	vec3 sum = own.rgb * 4.0;
	float wsum = own.a * 4.0;
	float nb = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			if (i == 0 && j == 0) {
				continue;
			}
			vec4 s = texture(TEXTURE, clamp(UV + vec2(float(i), float(j)) * px, vec2(0.0), vec2(1.0)));
			sum += s.rgb;
			wsum += s.a;
			nb += s.a;
		}
	}
	float w_out = max(own.a, clamp(nb / 24.0 * 3.0, 0.0, 1.0) * 0.9);
	vec3 ratio = wsum > 0.00001 ? sum / wsum : vec3(0.0);
	COLOR = vec4(ratio * w_out, w_out);
}
