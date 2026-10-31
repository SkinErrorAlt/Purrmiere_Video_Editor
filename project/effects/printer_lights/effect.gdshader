shader_type canvas_item;
render_mode blend_disabled;

uniform float master : hint_range(-50.0, 50.0) = 0.0;
uniform float red : hint_range(-50.0, 50.0) = 0.0;
uniform float green : hint_range(-50.0, 50.0) = 0.0;
uniform float blue : hint_range(-50.0, 50.0) = 0.0;
uniform float stops_per_point : hint_range(0.01, 0.5) = 0.083;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 lin = pow(max(rgb, vec3(0.0)), vec3(2.2));
	lin *= exp2((vec3(red, green, blue) + master) * stops_per_point);
	vec3 o = pow(lin, vec3(1.0 / 2.2));
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
