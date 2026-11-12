shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float reach = 2.0;

void fragment() {
	vec2 px = reach / max(tex_size, vec2(1.0));
	vec4 s = vec4(0.0);
	float wsum = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) * 0.3);
			vec4 c = texture(TEXTURE, clamp(UV + o * px, vec2(0.0), vec2(1.0)));
			float conf = 0.05 + c.z;
			s += vec4((c.xy * 2.0 - 1.0) * conf, c.z, 0.0) * w;
			wsum += w;
		}
	}
	s /= wsum;
	vec2 j = s.xy;
	float m = length(j);
	vec2 dir = m > 0.00001 ? j / m : vec2(1.0, 0.0);
	COLOR = vec4(0.5 + 0.5 * dir, clamp(m * 1.5, 0.0, 1.0), 1.0);
}
