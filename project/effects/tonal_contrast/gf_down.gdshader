shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 encode(float v) {
	float x = clamp(v, 0.0, 0.99999) * 255.0;
	return vec2(floor(x) / 255.0, fract(x));
}

vec2 decode(vec4 e) {
	return vec2(e.r * 255.0 + e.g, e.b * 255.0 + e.a) / 255.0;
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec2 s = decode(texture(TEXTURE, UV + px * vec2(-0.5, -0.5)));
	s += decode(texture(TEXTURE, UV + px * vec2(0.5, -0.5)));
	s += decode(texture(TEXTURE, UV + px * vec2(-0.5, 0.5)));
	s += decode(texture(TEXTURE, UV + px * vec2(0.5, 0.5)));
	s *= 0.25;
	COLOR = vec4(encode(s.x), encode(s.y));
}
