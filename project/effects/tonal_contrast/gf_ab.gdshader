shader_type canvas_item;
render_mode blend_disabled;

uniform float gf_eps = 0.004;

vec2 encode(float v) {
	float x = clamp(v, 0.0, 0.99999) * 255.0;
	return vec2(floor(x) / 255.0, fract(x));
}

vec2 decode(vec4 e) {
	return vec2(e.r * 255.0 + e.g, e.b * 255.0 + e.a) / 255.0;
}

void fragment() {
	vec2 m = decode(texture(TEXTURE, UV));
	float v = max(m.y - m.x * m.x, 0.0);
	float a = v / (v + max(gf_eps, 0.000001));
	float b = m.x * (1.0 - a);
	COLOR = vec4(encode(a), encode(b));
}
