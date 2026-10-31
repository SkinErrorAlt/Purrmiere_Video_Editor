shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D master : filter_linear, repeat_disable;
uniform sampler2D red : filter_linear, repeat_disable;
uniform sampler2D green : filter_linear, repeat_disable;
uniform sampler2D blue : filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

float lut(sampler2D t, float x) {
	return texture(t, vec2(clamp(x, 0.0, 1.0) * (255.0 / 256.0) + 0.5 / 256.0, 0.5)).r;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 o = vec3(lut(red, rgb.r), lut(green, rgb.g), lut(blue, rgb.b));
	o = vec3(lut(master, o.r), lut(master, o.g), lut(master, o.b));
	rgb = mix(rgb, o, amount);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
