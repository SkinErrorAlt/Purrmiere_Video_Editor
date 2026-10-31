shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float choke : hint_range(-40.0, 40.0) = 1.0;

float at_width(vec4 m, float q) {
	if (q >= 0.78) {
		return mix(m.g, m.r, (q - 0.78) / 0.22);
	}
	if (q >= 0.45) {
		return mix(m.b, m.g, (q - 0.45) / 0.33);
	}
	return mix(m.a, m.b, q / 0.45);
}

void fragment() {
	bool grow = choke < 0.0;
	float r = min(abs(choke) * px_scale, 40.0);
	float m = texture(TEXTURE, UV).r;
	float py = 1.0 / max(tex_size.y, 1.0);
	float rr = max(r, 0.0001);
	int n = int(ceil(r));
	for (int i = 1; i <= 40; i++) {
		if (i > n) {
			break;
		}
		float fi = float(i);
		float q = sqrt(max(r * r - fi * fi, 0.0)) / rr;
		vec4 below = texture(TEXTURE, clamp(UV + vec2(0.0, py * fi), vec2(0.0), vec2(1.0)));
		vec4 above = texture(TEXTURE, clamp(UV - vec2(0.0, py * fi), vec2(0.0), vec2(1.0)));
		float t = min(at_width(below, q), at_width(above, q));
		float w = clamp(r - fi + 1.0, 0.0, 1.0);
		m = mix(m, min(m, t), w);
	}
	float alpha = clamp(grow ? 1.0 - m : m, 0.0, 1.0);
	COLOR = vec4(alpha);
}
