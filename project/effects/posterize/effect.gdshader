shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(2, 64) = 6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float n = float(max(levels, 2)) - 1.0;
	rgb = floor(rgb * n + 0.5) / n;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
