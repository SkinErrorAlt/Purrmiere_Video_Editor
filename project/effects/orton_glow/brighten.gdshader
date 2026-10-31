shader_type canvas_item;
render_mode blend_disabled;

uniform float brightness : hint_range(0.0, 3.0) = 1.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	rgb = 1.0 - pow(1.0 - rgb, vec3(1.0 + max(brightness, 0.0)));
	COLOR = vec4(rgb * a, a);
}
