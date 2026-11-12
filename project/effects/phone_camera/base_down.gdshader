shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float to_lin(float v) {
	return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
}

float enc(vec4 s) {
	vec3 rgb = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	float y = dot(vec3(to_lin(rgb.r), to_lin(rgb.g), to_lin(rgb.b)), LUMA);
	return clamp((log2(y + 0.001) + 10.0) / 10.0, 0.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	float e = 0.0;
	e += enc(texture(TEXTURE, UV + px * vec2(-1.0, -1.0)));
	e += enc(texture(TEXTURE, UV + px * vec2(1.0, -1.0)));
	e += enc(texture(TEXTURE, UV + px * vec2(-1.0, 1.0)));
	e += enc(texture(TEXTURE, UV + px * vec2(1.0, 1.0)));
	e *= 0.25;
	COLOR = vec4(e, e, e, 1.0);
}
