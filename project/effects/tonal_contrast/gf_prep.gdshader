shader_type canvas_item;
render_mode blend_disabled;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 encode(float v) {
	float x = clamp(v, 0.0, 0.99999) * 255.0;
	return vec2(floor(x) / 255.0, fract(x));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	float i = dot(rgb, LUMA);
	COLOR = vec4(encode(i), encode(i * i));
}
