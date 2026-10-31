shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	float ksum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			float kx = (i == 0 || i == 3) ? 1.0 : 3.0;
			float ky = (j == 0 || j == 3) ? 1.0 : 3.0;
			float k = kx * ky;
			vec2 o = vec2(float(i) - 1.5, float(j) - 1.5);
			vec4 s = texture(TEXTURE, clamp(UV + o * px, vec2(0.0), vec2(1.0)));
			sum += s.rgb * k;
			wsum += s.a * k;
			ksum += k;
		}
	}
	float w_out = clamp(wsum / ksum * 3.0, 0.0, 1.0);
	vec3 ratio = wsum > 0.00001 ? sum / wsum : vec3(0.0);
	COLOR = vec4(ratio * w_out, w_out);
}
