shader_type canvas_item;
render_mode blend_disabled;

uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	rgb = (rgb - 0.5) * contrast + 0.5 + brightness;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
