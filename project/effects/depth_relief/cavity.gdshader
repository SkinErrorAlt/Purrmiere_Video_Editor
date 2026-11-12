shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

float unpack(vec4 c) {
	return c.r + c.g / 255.0;
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	float h = unpack(here);
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	float r = max(tex_size.y * 0.012, 2.0);
	float occ = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		vec2 o = vec2(cos(a), sin(a)) * px;
		occ += max(unpack(texture(TEXTURE, UV + o * r)) - h, 0.0) * 0.6;
		occ += max(unpack(texture(TEXTURE, UV + o * r * 2.6)) - h, 0.0) * 0.4;
	}
	COLOR = vec4(here.r, here.g, clamp(occ / 8.0 * 6.0, 0.0, 1.0), 1.0);
}
